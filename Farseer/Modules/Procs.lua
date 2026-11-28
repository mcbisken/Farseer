-- Procs och larm: Maelstrom Weapon-stackar, laddningar på skölden, Windfury-procs, låg mana, purge på
-- target, fiendens casts (kick!), diminishing returns och Blizzards förslag på nästa spell. v1.6:
-- Clearcasting/Stormstrike/Flurry, nedräkning för Mana Tide/Rage of the Farseer och andningsvarning.
-- Allt är vanliga (osäkra) ramar som uppdateras även i strid. När spelet gör värden secret visas de
-- ändå där det går (texter och bars tar emot secret-värden), men logik som jämför tal (ljud, varningar)
-- körs bara när värdet går att läsa.

local _, ns = ...
local PC = ns.module("Procs")

local frame, wfText, castBar, drText
local icons = {}
local mwLast, mwInstance
local shieldInstance = {}   -- [sköld] = auraInstanceID (en per sköld: annars hittar Lightning Shield-uppslaget Water Shield)
local wf = { count = 0, shownAt = -100, at = -100 }
local manaArmed = true
local purgeWarned = {}
local casts = {}         -- [unit] = { name, start, ends, notInt, channel }
local dr = {}            -- [enhet] = { [kategori] = { start, dur, level, immune } }
local procInstance = {}  -- [proc-nyckel] = auraInstanceID (reserv när uppslaget blockeras)
local procSeenAt = {}    -- [proc-nyckel] = GetTime() när buffen senast lästes (utan container: hur länge den får stå)
local procBox = {}       -- [proc-nyckel] = nil inte försökt, false gick inte, annars { container, button, ... }
local procBoxError = {}
local lastShield         -- skölden som senast lästes/castades; false = läst: ingen sköld, nil = okänt
local cdActive = {}      -- [nyckel] = { ends, def, at }
local breath = { token = 0 }
local wbWarned           -- Water Breathing-instansen vi redan varnat för

-- Procs bredvid Maelstrom. ids = buffens spell-ID:n (Stormstrike-buffens ID:n är okända i Forever: bara
-- namnet), file = ikonfilen som sista utväg, requires = spell/talang som måste finnas. Clearcasting och
-- Flurry visas bara när buffen finns, så de behöver ingen kontroll av talangen.
local PROCS = {
	{ key = "clearcast", cfg = "clearcast", name = "Clearcasting", ids = { 16246 }, flash = true,
		talent = "Elemental Focus", dur = 15, box = true,
		file = "Interface\\Icons\\Spell_Shadow_ManaBurn",
		tip = "Elemental Focus: your next damage spell costs less mana." },
	{ key = "stormstrike", cfg = "stormstrike", name = "Stormstrike", ids = {}, requires = "Stormstrike", target = true,
		flash = true,
		file = "Interface\\Icons\\Ability_Shaman_Stormstrike",
		tip = "Stormstrike is up: your next Nature spells (shocks, Lightning Bolt) hit harder." },
	{ key = "flurry", cfg = "flurry", name = "Flurry", ids = { 16257, 16277, 16278, 16279, 16280 }, flash = true,
		talent = "Flurry", dur = 15, box = true,
		file = "Interface\\Icons\\Ability_GhoulFrenzy",
		tip = "Flurry: faster attacks for the next swings. The number is swings left." },
}
PC.PROCS = PROCS

-- Nedräkning efter egna casts. buff = läs tiden ur buffen på dig när den går att läsa.
-- totem = startas/stoppas också av totemspårningen (TOTEMS_CHANGED) när castens ID är secret
local CD_TIMERS = {
	["Mana Tide Totem"] = { key = "manatide", spell = "Mana Tide Totem", dur = 12, totem = true,
		msg = "Mana Tide Totem up (12 s)" },
	["Rage of the Farseer"] = { key = "farseer", spell = "Rage of the Farseer", dur = 15, buff = true,
		msg = "Rage of the Farseer up" },
}
PC.CD_TIMERS = CD_TIMERS

local BREATH_WARN = 20   -- varna när så här många sekunder luft är kvar
local BREATH_ASSUME = 60 -- luft att anta när varken kvarvarande eller max går att läsa (secret)
local RESERVE = 10       -- sekunder en ikon som just doldes behåller sin plats (ingen hoppande rad)
local SS_WINDOW = 12     -- Stormstrike: debuffen (2 laddningar) håller 12 s efter din cast
local SS_GRACE = 1       -- debuffen syns inte direkt efter casten: en läsning som säger "saknas" väntar så länge
local ssCast             -- GetTime() för din senaste lyckade Stormstrike (nil = ingen aktiv)
local WB_LOW = 60        -- Water Breathing: varna när mindre än så här är kvar (simmar, utanför strid)

local function cfg() return ns.char.procs end

-- Egen klocka när cooldownen är secret (i strid): senaste lyckade cast + spellens cooldown
local OWN_CD = { ["Mana Tide Totem"] = 300, ["Grounding Totem"] = 15 }
local ownCast = {}
PC.OWN_CD = OWN_CD

---------------------------------------------------------------------------------------------------
-- Läsning
---------------------------------------------------------------------------------------------------
-- Är aurorna låsta just nu (strid, encounter, PvP-match)? Ett secret svar räknas som ja.
local function aurasSecret()
	if not (C_Secrets and C_Secrets.ShouldAurasBeSecret) then return false end
	local ok, v = pcall(C_Secrets.ShouldAurasBeSecret)
	if not ok then return false end
	return ns.isSecret(v) or v == true
end
PC.aurasSecret = aurasSecret

-- Säger klienten att just den här buffen går att läsa trots låsningen (spellen är aldrig secret)?
local function spellAuraOpen(id)
	local f = C_Secrets and C_Secrets.ShouldSpellAuraBeSecret
	if not f then return false end
	local ok, v = pcall(f, id)
	return ok and not ns.isSecret(v) and v == false
end

-- Auran på dig: tabell (kan innehålla secret-fält), eller nil. instanceID används om uppslaget blockeras.
-- Andra värdet: true när "nil" inte betyder "saknas". I Forever kastar varje auraläsning ett fel i strid
-- ("Auras cannot be accessed when secret while tainted"), även dina egna buffar och per instans
-- (forever-addon-kit, BUG_REPORTS.md "Post 4").
local function playerAura(ids, name, instanceID)
	local U = C_UnitAuras
	if not U then return nil, true end
	local failed = false
	if U.GetPlayerAuraBySpellID then
		for _, id in ipairs(ids or {}) do
			local ok, a = pcall(U.GetPlayerAuraBySpellID, id)
			if not ok then failed = true elseif ns.isSecret(a) or a ~= nil then return a, false end
		end
	end
	if name and U.GetAuraDataBySpellName then
		local ok, a = pcall(U.GetAuraDataBySpellName, "player", ns.L(name), "HELPFUL")
		if not ok then failed = true elseif ns.isSecret(a) or a ~= nil then return a, false end
	end
	if instanceID and U.GetAuraDataByAuraInstanceID then
		local ok, a = pcall(U.GetAuraDataByAuraInstanceID, "player", instanceID)
		if not ok then failed = true elseif ns.isSecret(a) or a ~= nil then return a, false end
	end
	if failed then return nil, true end
	-- Inget fel men aurorna är låsta: "saknas" gäller bara buffar som klienten säger är öppna
	if aurasSecret() then
		local open = false
		for _, id in ipairs(ids or {}) do
			if spellAuraOpen(id) then open = true break end
		end
		if not open then return nil, true end
	end
	return nil, false
end
PC.playerAura = playerAura

-- Finns värdet? Secret räknas som "finns" och jämförs aldrig med nil.
local function present(v) return ns.isSecret(v) or v ~= nil end
PC.present = present

-- Stacks/laddningar: tal, eller nil + det råa secret-värdet (kan bara visas, inte jämföras)
local function applications(a)
	if ns.isSecret(a) then return nil end
	if a == nil then return 0 end
	local ok, v = pcall(function() return a.applications end)
	if not ok then return nil end
	if ns.isSecret(v) then return nil, v end
	return tonumber(v) or 0
end
PC.applications = applications

local function instanceOf(a)
	if ns.isSecret(a) or a == nil then return nil end
	return ns.field(a, "auraInstanceID")
end


---------------------------------------------------------------------------------------------------
-- Ramar
---------------------------------------------------------------------------------------------------
local function makeIcon(key, tip)
	local f = CreateFrame("Frame", "FarseerProc" .. key, frame)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	f.count:SetPoint("BOTTOMRIGHT", -2, 2)
	f.glow = ns.addGlow(f, 0.4, 0.8, 1)
	ns.Theme.SkinIcon(f)
	f.key, f.tip = key, tip
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.title or self.key)
		local t = type(self.tip) == "function" and self.tip(self) or self.tip
		if t then GameTooltip:AddLine(t, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:Hide()
	icons[key] = f
	return f
end

-- Blinkning som alltid går: ritas bara när ramen har något att visa (en statusbar som fylls vid 5 är tom
-- under 5), så vi behöver inte läsa stackarna (secret i strid). Startas om när ramen visas igen.
local function addPulse(region)
	local ok, ag = pcall(region.CreateAnimationGroup, region)
	if not ok or type(ag) ~= "table" then return nil end
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.2)
	a:SetDuration(0.4)
	ag.region = region
	function ag:Set(on)
		self.on = on and true or false
		if self.on then
			if not self:IsPlaying() then self:Play() end
		else
			self:Stop()
			self.region:SetAlpha(1)
		end
	end
	if region.HookScript then
		region:HookScript("OnShow", function() if ag.on and not ag:IsPlaying() then ag:Play() end end)
	end
	return ag
end
PC.addPulse = addPulse

local function flashOn() return cfg().flash ~= false end

-- Statusbar som fylls bara vid max: lyser när stacks == max även om talet är secret
local function makeSensor(parent, max)
	local s = CreateFrame("StatusBar", nil, parent)
	s:SetAllPoints()
	s:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	s:SetStatusBarColor(0.4, 0.8, 1, 0.35)
	s:SetMinMaxValues(max - 1, max)
	s:SetValue(0)
	return s
end

local ORDER = { "maelstrom", "clearcast", "stormstrike", "flurry", "shield", "manatide", "farseer", "purge", "assisted" }

function PC:Build()
	local c = ns.char.bars.procs
	frame = CreateFrame("Frame", "FarseerProcs", UIParent)
	frame:SetSize(200, 40)
	ns.placeFrame(frame, c)
	ns.makeMovable(frame, c, "Farseer: procs and alerts")
	local mw = makeIcon("maelstrom", "Maelstrom Weapon stacks. At 5: glows (and plays a sound when readable) — "
		.. "the next Lightning Bolt/Chain Lightning/heal is instant.")
	mw.title = "Maelstrom Weapon"
	mw.sensor = makeSensor(mw, ns.MAELSTROM_MAX or 5)
	mw.sensor.pulse = addPulse(mw.sensor)
	for _, def in ipairs(PROCS) do makeIcon(def.key, def.tip).title = def.name end
	for _, def in pairs(CD_TIMERS) do
		local f = makeIcon(def.key, def.spell .. " is active. The number is seconds left.")
		f.title = def.spell
		f.timer = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
		f.timer:SetPoint("CENTER", 0, 0)
	end
	local sh = makeIcon("shield", "Charges left on your shield. Red number (flashing) = running out, recast it.")
	sh.title = "Shield"
	makeIcon("purge", function(self)
		local names = {}
		for _, b in ipairs(self.buffs or {}) do table.insert(names, b.name or "?") end
		return "Target has buffs that Purge removes:\n" .. table.concat(names, "\n")
	end).title = "Purge"
	makeIcon("assisted", "Blizzard's suggestion for the next spell (Assisted Combat), if the client has it.").title = "Suggestion"
	wfText = frame:CreateFontString(nil, "OVERLAY", ns.Theme.Font("FarseerFontAlert"))
	wfText:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	wfText:SetTextColor(0.65, 0.87, 1)
	castBar = CreateFrame("StatusBar", nil, frame)
	castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	castBar:SetStatusBarColor(1, 0.7, 0)
	castBar:SetMinMaxValues(0, 1)
	castBar.bg = castBar:CreateTexture(nil, "BACKGROUND")
	castBar.bg:SetAllPoints()
	castBar.bg:SetColorTexture(0, 0, 0, 0.6)
	castBar.text = castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	castBar.text:SetPoint("LEFT", 4, 0)
	castBar.text:SetJustifyH("LEFT")
	ns.Theme.SkinBar(castBar)
	castBar:Hide()
	drText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	drText:SetJustifyH("LEFT")
	self.castBar, self.wfText, self.drText = castBar, wfText, drText
	-- Timers och text 10 ggr/s, auror (Maelstrom, sköld, purge) 2,5 ggr/s
	local full = ns.timed("procs-auras", function() PC:Update() end)
	local fast = ns.timed("procs-timers", function() PC:UpdateFast() end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		frame.acc = (frame.acc or 0) + elapsed
		frame.slow = (frame.slow or 0) + elapsed
		if frame.acc < 0.1 then return end
		frame.acc = 0
		if frame.slow >= 0.4 then
			frame.slow = 0
			full()
		else
			fast()
		end
	end)
end

function PC:Layout()
	if not frame then return end
	-- Spelets aura-behållare kan göra ramen skyddad: då väntar layouten tills strid är över
	if InCombatLockdown() and frame.IsProtected and ns.get(frame.IsProtected, frame) == true then
		ns.afterCombat("procs-layout", function() PC:Layout() end)
		return
	end
	local c = ns.char.bars.procs
	ns.placeFrame(frame, c)
	local size = c.size or 36
	local x = 0
	local now = GetTime()
	self.relayoutAt = nil
	for _, key in ipairs(ORDER) do
		local f = icons[key]
		f:SetSize(size, size)
		f:ClearAllPoints()
		-- En ikon som doldes nyss behåller sin plats en stund, så de andra inte hoppar när t.ex. Flurry blinkar
		local keep = not f:IsShown() and f.hiddenAt and now - f.hiddenAt < RESERVE
		if f:IsShown() or keep then
			f:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
			x = x + size + 4
		end
		if keep then
			local at = f.hiddenAt + RESERVE
			if not self.relayoutAt or at < self.relayoutAt then self.relayoutAt = at end
		end
	end
	local width = math.max(200, x - 4)
	castBar:SetSize(width, 14)
	castBar:ClearAllPoints()
	castBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(size + 4))
	castBar.text:SetWidth(width - 8)
	drText:ClearAllPoints()
	drText:SetPoint("TOPLEFT", castBar, "BOTTOMLEFT", 0, -3)
	drText:SetWidth(width)
	frame:SetSize(width, size + 40)
	frame:SetShown(c.show and ns.isShaman)
end

local function setShown(f, show)
	if f:IsShown() ~= (show and true or false) then
		f.hiddenAt = (not show) and GetTime() or nil
		f:SetShown(show)
		PC.dirty = true
	end
	if not show and f.glow then f.glow:Off() end
end

-- Dold för att funktionen är avstängd: ingen reserverad plats
local function setOff(f)
	setShown(f, false)
	if f.hiddenAt then
		f.hiddenAt = nil
		PC.dirty = true
	end
end

-- Visar ett tal eller ett secret-värde (spelet ritar det, vi kan inte läsa det)
local function showCount(fs, n, raw, low)
	if n then
		fs:SetText(n > 0 and tostring(n) or "")
		if low then fs:SetTextColor(1, 0.25, 0.25) else fs:SetTextColor(1, 1, 1) end
	elseif present(raw) then
		if not pcall(fs.SetText, fs, raw) then fs:SetText("?") end
		fs:SetTextColor(1, 1, 1)
	else
		fs:SetText("")
	end
end

---------------------------------------------------------------------------------------------------
-- Maelstrom Weapon
---------------------------------------------------------------------------------------------------
function PC:Maelstrom()
	local a = playerAura(ns.MAELSTROM_BUFF, "Maelstrom Weapon", mwInstance)
	local inst = instanceOf(a)
	if inst then mwInstance = inst elseif not present(a) then mwInstance = nil end
	local n, raw = applications(a)
	return n, raw, a
end

-- Ikonen: Maelstrom Weapon är en rune/talang och finns ofta inte i spellboken, så namnuppslaget ger
-- ingen ikon. Ordning: buffens egen ikon -> kända spell-ID:n -> namnet -> ikonens fil.
local MW_ICON = "Interface\\Icons\\Spell_Shaman_MaelstromWeapon"
function PC:MaelstromIcon(a)
	if not ns.isSecret(a) and a ~= nil then
		local ok, ic = pcall(function() return a.icon end)
		if ok and present(ic) then return ic end
	end
	local ids = {}
	for _, id in ipairs(ns.MAELSTROM_BUFF or {}) do table.insert(ids, id) end
	for _, id in ipairs((ns.SPELL_IDS and ns.SPELL_IDS["Maelstrom Weapon"]) or {}) do table.insert(ids, id) end
	local known = ns.Spellbook:ID("Maelstrom Weapon")
	if known then table.insert(ids, 1, known) end
	for _, id in ipairs(ids) do
		local t = C_Spell and ns.get(C_Spell.GetSpellTexture, id)
		if t and t ~= 134400 then return t end
	end
	local t = C_Spell and ns.get(C_Spell.GetSpellTexture, ns.L("Maelstrom Weapon"))
	if t and t ~= 134400 then return t end
	return MW_ICON
end

---------------------------------------------------------------------------------------------------
-- Maelstrom via Blizzards aura-container (som ShamanForever gör): i strid är stackarna secret, så vi
-- läser inte buffen alls. Containern får buffens ID och spelets egen kod ritar ikonen, tiden, antalet,
-- en stackbar och en markering vid 5 (en statusbar som bara fylls vid max). Byggs en gång, utanför strid
-- och när auror går att läsa. Går det inte (äldre klient) används den gamla vägen.
---------------------------------------------------------------------------------------------------
local mwBox            -- nil = inte försökt, false = gick inte, annars { container, button, ... }
local MW_GOLD = "|cffffd100"

local function noMouse(b)
	pcall(b.EnableMouse, b, false)
	pcall(b.SetMouseClickEnabled, b, false)
	pcall(b.SetMouseMotionEnabled, b, false)
end

local function immediate()
	return Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
end

-- Prövar en formatter på 0..top: 0 ska ge tom text och varje annat tal måste stå i texten (en formatter
-- som ger "" för allt skulle annars släcka talet helt). Ett fel i formattern stoppar spelets auror.
local function formatterWorks(x, top)
	for n = 0, top do
		local t = x:FormatNumber(n)
		if type(t) ~= "string" or ns.isSecret(t) then return false end
		if n == 0 then
			if t ~= "" then return false end
		elseif not t:find(tostring(n), 1, true) then
			return false
		end
	end
	return true
end
PC.formatterWorks = formatterWorks

-- Talet (reserv när siffer-brickan inte går): inget vid 0, 1-4 vita, 5 i guld. nil = spelets eget tal
-- (som börjar på 2).
local function countFormatter(max)
	if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
	local ok, fm = pcall(function()
		local x = C_StringUtil.CreateNumericRuleFormatter()
		x:SetBreakpoints({
			{ threshold = 0, format = "" },
			{ threshold = 1, format = "%d" },
			{ threshold = max, format = MW_GOLD .. "%d|r" },
		})
		if not formatterWorks(x, max) then error("formatter") end
		return x
	end)
	return ok and fm or nil
end

-- Siffer-brickan: en statusbar per siffra (MW1..MW5.tga), full när stackarna >= siffran. Högre siffror
-- ligger ovanpå och brickan är ogenomskinlig, så den översta fulla visar antalet. Spelet fyller barerna
-- även när stackarna är secret i strid (samma sätt som stackbaren och 5-markeringen). Spelets eget tal
-- visar inget vid 1 och kom aldrig fram i spelet, så det är bara reserv om barerna inte går att sätta.
local MW_DIGIT = "Interface\\AddOns\\Farseer\\Media\\MW%d"
local MW_DIGITS = 5    -- antal bilder i Media

local function badgeSize(size) return math.max(12, math.floor(size * 0.5)) end
local function barHeight(size) return math.max(3, math.floor(size / 8)) end

local function placeBadge(box, size)
	local b = box.badge
	b:SetSize(badgeSize(size), badgeSize(size))
	b:ClearAllPoints()
	b:SetPoint("BOTTOMRIGHT", box.button, "BOTTOMRIGHT", 2, barHeight(size) + 3)
end

local function makeDigitBadge(box, button, size, max)
	if max > MW_DIGITS then return false end
	local badge = CreateFrame("Frame", nil, button)
	badge:SetFrameLevel(button:GetFrameLevel() + 5)
	box.badge = badge
	placeBadge(box, size)
	box.digits = {}
	for k = 1, max do
		local d = CreateFrame("StatusBar", nil, badge)
		d:SetAllPoints(badge)
		d:SetStatusBarTexture(MW_DIGIT:format(k))
		d:SetMinMaxValues(k - 1, k)
		d:SetValue(k - 1)
		d:SetFrameLevel(badge:GetFrameLevel() + k)
		if not pcall(button.SetApplicationBar, button, d,
			{ minApplications = k - 1, maxApplications = k, interpolation = immediate() }) then
			badge:Hide()
			box.badge, box.digits = nil, nil
			return false
		end
		box.digits[k] = d
	end
	return true
end

-- Spelets eget tal (reserv)
local function useGameCount(box, max)
	local fm = countFormatter(max)
	if not pcall(box.button.SetApplicationCount, box.button, box.fs, fm and { formatter = fm } or nil) then
		pcall(box.button.SetApplicationCount, box.button, box.fs)
	end
	box.fs:Show()
	box.countMode = "game text"
end

-- Utanför strid går antalet att läsa: fyller spelet inte brickan (ettans bar tom fast vi har stackar två
-- läsningar i rad) byts den mot spelets tal.
local function checkBadge(box, n)
	if not (box.digits and n and n >= 1) then
		box.badgeMiss = nil
		return
	end
	local v = ns.get(box.digits[1].GetValue, box.digits[1])
	if type(v) ~= "number" or ns.isSecret(v) then return end
	if v >= 1 then box.badgeMiss = nil return end
	box.badgeMiss = (box.badgeMiss or 0) + 1
	if box.badgeMiss < 2 then return end
	box.badge:Hide()
	box.badge, box.digits = nil, nil
	useGameCount(box, ns.MAELSTROM_MAX or 5)
	box.countMode = "game text (badge stayed empty)"
end
PC.checkMaelstromBadge = checkBadge

-- Spelets knapp i containern: våra delar läggs på den, spelet sätter värdena
-- Spelets aura-knapp kan vara skyddad: storlek och plats sätts då efter striden
local function placeGameButton(button, size)
	local function place()
		button:SetSize(size, size)
		button:ClearAllPoints()
		button:SetPoint("TOPLEFT", button:GetParent(), "TOPLEFT", 0, 0)
	end
	if InCombatLockdown() and button.IsProtected and ns.get(button.IsProtected, button) == true then
		ns.afterCombat("procs-btn-" .. tostring(button), place)
	else
		place()
	end
end

local function initMaelstromButton(box, button)
	local f = icons.maelstrom
	local size = f:GetWidth()
	if type(size) ~= "number" or size <= 0 then size = ns.char.bars.procs.size or 36 end
	local max = ns.MAELSTROM_MAX or 5
	placeGameButton(button, size)
	noMouse(button)
	local tex = button:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 1, -1)
	tex:SetPoint("BOTTOMRIGHT", -1, 1)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	tex:SetTexture(MW_ICON)
	pcall(button.SetIcon, button, tex)
	box.icon = tex
	-- Tid kvar på buffen (30 s): svep utan siffror
	local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cd:SetAllPoints()
	pcall(cd.SetHideCountdownNumbers, cd, true)
	pcall(cd.SetDrawEdge, cd, false)
	if not pcall(button.SetDurationCooldown, button, cd) then cd:Hide() end
	box.cd = cd
	-- Markering vid 5: fylls bara när stackarna når max (min = max), annars tom
	local full = CreateFrame("StatusBar", nil, button)
	full:SetPoint("CENTER", button, "CENTER")
	full:SetSize(size * 1.7, size * 1.7)
	full:SetStatusBarTexture("Interface\\Buttons\\UI-ActionButton-Border")
	local ft = full:GetStatusBarTexture()
	if type(ft) == "table" and ft.SetBlendMode then pcall(ft.SetBlendMode, ft, "ADD") end
	full:SetStatusBarColor(1, 0.82, 0.2, 1)
	full:SetFrameLevel(button:GetFrameLevel() + 2)
	if not pcall(button.SetApplicationBar, button, full,
		{ minApplications = max, maxApplications = max, interpolation = immediate() }) then
		full:Hide()
		full = nil
	end
	box.full = full
	if full then box.fullPulse = addPulse(full) end
	-- Blixt över ikonen vid 5 (samma knep: fylls bara vid max)
	local flash = CreateFrame("StatusBar", nil, button)
	flash:SetAllPoints(button)
	flash:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	local lt = flash:GetStatusBarTexture()
	if type(lt) == "table" and lt.SetBlendMode then pcall(lt.SetBlendMode, lt, "ADD") end
	flash:SetStatusBarColor(1, 0.85, 0.3, 0.35)
	flash:SetFrameLevel(button:GetFrameLevel() + 1)
	if pcall(button.SetApplicationBar, button, flash,
		{ minApplications = max, maxApplications = max, interpolation = immediate() }) then
		box.flash = flash
		box.flashPulse = addPulse(flash)
	else
		flash:Hide()
	end
	PC:FlashMaelstromBox(box)
	-- Stackbar längst ned (en ruta per stack)
	local bar = CreateFrame("StatusBar", nil, button)
	bar:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 2)
	bar:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
	bar:SetHeight(barHeight(size))
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(0.52, 0.69, 1, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0, 0, 0, 0.6)
	bar:SetFrameLevel(button:GetFrameLevel() + 3)
	if not pcall(button.SetApplicationBar, button, bar, { minApplications = 0, maxApplications = max }) then
		bar:Hide()
		bar = nil
	end
	box.bar = bar
	-- Ram runt ikonen och plats för spelets tal (reserv)
	local num = CreateFrame("Frame", nil, button)
	num:SetAllPoints(button)
	num:SetFrameLevel(button:GetFrameLevel() + 4)
	local fs = num:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	fs:SetPoint("CENTER", 0, 1)
	pcall(fs.SetFontObject, fs, ns.Theme.Font("FarseerFontCount"))
	ns.Theme.Border(num, { 0, 0, 0, 1 }, "OVERLAY", 0)
	box.fs = fs
	box.button = button
	-- Antalet: siffer-brickan, annars spelets tal
	if makeDigitBadge(box, button, size, max) then
		fs:Hide()
		box.countMode = "digit badge"
	else
		useGameCount(box, max)
	end
	PC.dirty = true
end

-- Bygg containern (en gång). Returnerar boxen, false om klienten inte har den, eller nil (vänta).
function PC:SetupMaelstromBox()
	if mwBox ~= nil then return mwBox end
	if not frame or InCombatLockdown() or aurasSecret() then return nil end
	if not (cfg().maelstrom and ns.Spellbook:Knows("Maelstrom Weapon")) then return nil end
	local ids = {}
	for _, id in ipairs(ns.MAELSTROM_BUFF or {}) do ids[id] = true end
	local box = {}
	local ok, err = pcall(function()
		local f = icons.maelstrom
		-- Föräldern är procs-rutan (inte ikonen, som döljs och visas i strid); ikonen står alltid först
		local c = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
		box.container = c
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		c:SetSize(f:GetWidth(), f:GetHeight())
		c:SetFrameStrata(frame:GetFrameStrata())
		c:SetFrameLevel(f:GetFrameLevel() + 5)
		c:SetUnit("player")
		noMouse(c)
		c:AddAuraSlot("maelstrom", "HELPFUL", {
			candidateFilters = { includeSpellIDs = ids },
			initializeFrame = function(button)
				local ok2, e2 = pcall(initMaelstromButton, box, button)
				if not ok2 then ns.report("Maelstrom container button: " .. tostring(e2)) end
			end,
		})
	end)
	if not ok then
		if box.container then pcall(box.container.Hide, box.container) end
		mwBox = false
		PC.mwBoxError = tostring(err)
		return false
	end
	mwBox = box
	return box
end

-- Släng containern (tester och /farseer debug): byggs om nästa gång utanför strid
function PC:ResetMaelstromBox()
	if InCombatLockdown() then return false end
	if mwBox and mwBox.container then pcall(mwBox.container.Hide, mwBox.container) end
	mwBox = nil
	PC.mwBoxError = nil
	return true
end

-- Containern ritar Maelstrom (spelet har gett den en knapp)
function PC:MaelstromBox() return mwBox and mwBox.button and mwBox or nil end
function PC:MaelstromBoxState()
	if mwBox == nil then return "not built" end
	if mwBox == false then return "unavailable: " .. tostring(PC.mwBoxError) end
	if not mwBox.button then return "waiting for the buff" end
	return "active, number: " .. tostring(mwBox.countMode or "?")
end

-- Blinkningen på containerns markering (av = fast ram, ingen blixt)
function PC:FlashMaelstromBox(b)
	local box = b or mwBox
	if not box then return end
	local on = flashOn()
	if box.fullPulse then pcall(box.fullPulse.Set, box.fullPulse, on) end
	if box.flashPulse then pcall(box.flashPulse.Set, box.flashPulse, on) end
	if box.flash then pcall(box.flash.SetShown, box.flash, on) end
end

-- Storlek och synlighet: bara utanför strid (containerns knapp är spelets)
function PC:StyleMaelstromBox()
	local box = mwBox
	if not box or InCombatLockdown() then return end
	local f = icons.maelstrom
	local on = cfg().maelstrom and ns.Spellbook:Knows("Maelstrom Weapon")
	pcall(box.container.SetShown, box.container, on and true or false)
	self:FlashMaelstromBox()
	local size = f:GetWidth()
	if type(size) ~= "number" or size <= 0 then return end
	pcall(box.container.SetSize, box.container, size, size)
	local b = box.button
	if b then
		pcall(b.SetSize, b, size, size)
		if box.full then pcall(box.full.SetSize, box.full, size * 1.7, size * 1.7) end
		if box.bar then pcall(box.bar.SetHeight, box.bar, barHeight(size)) end
		if box.badge then pcall(placeBadge, box, size) end
	end
end

function PC:UpdateMaelstrom()
	local f = icons.maelstrom
	if not (cfg().maelstrom and ns.Spellbook:Knows("Maelstrom Weapon")) then setOff(f) return end
	local n, raw, aura = self:Maelstrom()
	local max = ns.MAELSTROM_MAX or 5
	-- Buffens ikon kan vara secret i strid: SetTexture tar emot den ändå, annars filen
	if not pcall(function() f.icon:SetTexture(self:MaelstromIcon(aura)) end) then f.icon:SetTexture(MW_ICON) end
	setShown(f, InCombatLockdown() or (n ~= 0))
	local box = self:MaelstromBox()
	if box then
		-- Spelet ritar buffen, talet och markeringen ovanpå: vår ikon är en svag platshållare under
		f.icon:SetDesaturated(true)
		f.icon:SetAlpha(0.35)
		f.count:SetText("")
		f.sensor:Hide()
		if f.sensor.pulse then f.sensor.pulse:Set(false) end
		f.glow:Off()
		checkBadge(box, n)
		-- Ljudet går bara när antalet går att läsa (utanför strid / om spelet visar det)
		if n then
			if n >= max and (mwLast or 0) < max and cfg().maelstromSound then
				pcall(PlaySound, SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889, "Master")
			end
			mwLast = n
		end
		return
	end
	f.icon:SetAlpha(1)
	f.sensor:Show()
	if f.sensor.pulse then f.sensor.pulse:Set(flashOn()) end
	showCount(f.count, n, raw)
	local v = n
	if v == nil then
		if present(raw) then v = raw else v = 0 end
	end
	pcall(f.sensor.SetValue, f.sensor, v)
	if n then
		f.icon:SetDesaturated(n == 0)
		if n >= max then
			if flashOn() then f.glow:On() else f.glow:Off() end
			if (mwLast or 0) < max and cfg().maelstromSound then
				pcall(PlaySound, SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889, "Master")
			end
		else
			f.glow:Off()
		end
		mwLast = n
	else
		f.icon:SetDesaturated(false)
		f.glow:Off()
	end
end

---------------------------------------------------------------------------------------------------
-- Clearcasting, Stormstrike, Flurry
---------------------------------------------------------------------------------------------------
-- Ikonen: buffens egen (kan vara secret, SetTexture tar emot den) -> spell-ID:n -> namnet -> filen
function PC:ProcIcon(def, a)
	if not ns.isSecret(a) and a ~= nil then
		local ok, ic = pcall(function() return a.icon end)
		if ok and (ns.isSecret(ic) or ic ~= nil) then return ic end
	end
	local spell = def.requires or def.name
	local ids = {}
	local known = ns.Spellbook:ID(spell)
	if known then table.insert(ids, known) end
	for _, id in ipairs(def.ids or {}) do table.insert(ids, id) end
	for _, id in ipairs((ns.SPELL_IDS and ns.SPELL_IDS[spell]) or {}) do table.insert(ids, id) end
	for _, id in ipairs(ids) do
		local t = C_Spell and ns.get(C_Spell.GetSpellTexture, id)
		if t and t ~= 134400 then return t end
	end
	local t = C_Spell and ns.get(C_Spell.GetSpellTexture, ns.L(spell))
	if t and t ~= 134400 then return t end
	return def.file
end

-- Markör: auran går inte att läsa just nu (secret eller blockerat uppslag)
local UNKNOWN = setmetatable({}, { __tostring = function() return "<unknown>" end })
PC.UNKNOWN = UNKNOWN

-- Classic: Stormstrike är en debuff på target (+20 % Nature-skada). Leta efter din egen debuff med namnet.
-- Returnerar auran, nil (läsbart: finns inte) eller UNKNOWN (secret/blockerat). Direkt pcall: ns.get gör
-- ett secret-värde till nil, och då går det inte att skilja "saknas" från "okänt".
local function targetDebuff(name)
	local U = C_UnitAuras
	if not (U and U.GetAuraDataByIndex) then return UNKNOWN end
	local want = ns.L(name)
	local unknown = false
	for i = 1, 40 do
		local ok, a = pcall(U.GetAuraDataByIndex, "target", i, "HARMFUL|PLAYER")
		if not ok or ns.isSecret(a) then return UNKNOWN end
		if a == nil then break end
		if type(a) ~= "table" then
			unknown = true
		else
			local okn, n = pcall(function() return a.name end)
			if not okn or ns.isSecret(n) then
				unknown = true
			elseif n == want then
				return a
			end
		end
	end
	if unknown then return UNKNOWN end
	return nil
end
PC.TargetDebuff = targetDebuff

-- Ikonen är bara en plats i raden: spelets knapp (containern) ritar buffen ovanpå
local function placeholder(f)
	f.icon:SetAlpha(0)
	f.count:SetText("")
	f.glow:Off()
end

local function showProc(self, def, f, a)
	f.icon:SetAlpha(1)
	if not pcall(f.icon.SetTexture, f.icon, self:ProcIcon(def, a)) then f.icon:SetTexture(def.file) end
	local n, raw = applications(a)
	-- En laddning (eller ingen) = ingen siffra
	if n and n <= 1 then n = 0 end
	showCount(f.count, n, raw)
	setShown(f, true)
	if def.flash and flashOn() then f.glow:On() else f.glow:Off() end
end

function PC:UpdateProc(def)
	local f = icons[def.key]
	if not cfg()[def.cfg] or (def.requires and not ns.Spellbook:Knows(def.requires)) then
		procInstance[def.key] = nil
		setOff(f)
		return
	end
	local a, blocked = playerAura(def.ids, def.name, procInstance[def.key])
	local box = self:ProcBox(def.key)
	if present(a) then
		procInstance[def.key] = instanceOf(a) or procInstance[def.key]
		procSeenAt[def.key] = GetTime()
		if not ns.isSecret(a) then ns.char.procSeen = ns.char.procSeen or {}; ns.char.procSeen[def.key] = true end
		showProc(self, def, f, a)
		if box then placeholder(f) end
		return
	end
	if blocked and not def.target then
		if box then
			-- I strid ritar spelets knapp buffen. Vår ikon är en osynlig plats i raden så att knappen inte
			-- hamnar ovanpå en annan ikon, men bara när buffen kan komma (setts förut eller talangen finns).
			setShown(f, self:ProcExpected(def))
			placeholder(f)
			return
		end
		-- Utan container: det som syns står kvar som längst buffens längd från den senaste läsningen
		local at = procSeenAt[def.key]
		if f:IsShown() and at and GetTime() - at < (def.dur or 15) then return end
		setShown(f, false)
		return
	end
	procInstance[def.key] = nil
	if not def.target then setShown(f, false) return end
	-- Debuffen på target. Dess auraInstanceID sparas inte: playerAura slår upp den på "player" (fel enhet).
	local t = targetDebuff(def.name)
	local now = GetTime()
	if t == UNKNOWN then
		-- Okänt: din egen cast avgör; annars behåll det som visas (som purge)
		if ssCast and now - ssCast < SS_WINDOW then showProc(self, def, f, nil) return end
		if ssCast then
			ssCast = nil   -- 12 s har gått: debuffen är borta
			setShown(f, false)
		end
		return
	end
	if t == nil then
		-- Läsbart och saknas: göm, utom precis efter casten (debuffen har inte hunnit komma)
		if ssCast and now - ssCast < SS_GRACE then showProc(self, def, f, nil) return end
		ssCast = nil
		setShown(f, false)
		return
	end
	showProc(self, def, f, t)
end

-- Din Stormstrike lyckades: visa ikonen i 12 s om inte en läsbar aura säger något annat
local function isStormstrike(spellID, name)
	if name == "Stormstrike" then return true end
	if spellID == ns.Spellbook:ID("Stormstrike") then return true end
	for _, id in ipairs((ns.SPELL_IDS and ns.SPELL_IDS["Stormstrike"]) or {}) do
		if id == spellID then return true end
	end
	return false
end

function PC:StormstrikeCast()
	ssCast = GetTime()
	for _, def in ipairs(PROCS) do
		if def.key == "stormstrike" and frame then self:UpdateProc(def) end
	end
end

function PC:StormstrikeLeft()
	if not ssCast then return nil end
	return math.max(0, ssCast + SS_WINDOW - GetTime())
end

function PC:UpdateProcs()
	for _, def in ipairs(PROCS) do self:UpdateProc(def) end
end

---------------------------------------------------------------------------------------------------
-- Mana Tide Totem / Rage of the Farseer: nedräkning och meddelande i gruppen
---------------------------------------------------------------------------------------------------
-- Gruppens chattkanal, eller nil (solo)
local function groupChannel()
	local home = LE_PARTY_CATEGORY_HOME
	local inst = LE_PARTY_CATEGORY_INSTANCE
	if inst and IsInGroup and ns.get(IsInGroup, inst) == true and ns.get(IsInGroup, home) ~= true then
		return "INSTANCE_CHAT"
	end
	if ns.get(IsInRaid) == true then return "RAID" end
	local n = ns.get(GetNumGroupMembers) or 0
	if type(n) == "number" and n > 0 then return "PARTY" end
	return nil
end

function PC:Announce(msg)
	local channel = groupChannel()
	if not channel then return false end
	-- Under en bossfight kan chatten vara skyddad: hoppa över (pcall nedan tar resten)
	if IsEncounterInProgress and ns.get(IsEncounterInProgress) == true then return false end
	-- Den globala SendChatMessage är på väg bort i nya klienter
	local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
	if not send then return false end
	return (pcall(send, msg, channel))
end

-- Slutet på buffen om den går att läsa, annars nil
local function buffEnds(def)
	local a = playerAura(ns.SPELL_IDS and ns.SPELL_IDS[def.spell], def.spell)
	if ns.isSecret(a) or a == nil then return nil end
	local now = GetTime()
	local exp = ns.field(a, "expirationTime")
	if type(exp) == "number" and exp > now then return exp end
	local dur = ns.field(a, "duration")
	if type(dur) == "number" and dur > 0 then return now + dur end
	return nil
end

local function startTimer(def, ends, now)
	local c = { ends = ends, def = def, at = now }
	cdActive[def.key] = c
	local f = icons[def.key]
	if f then
		f.icon:SetTexture(ns.spellIcon(def.spell))
		setShown(f, true)
	end
	PC:UpdateTimers(now)
	if cfg().announce then PC:Announce(def.msg) end
	return c
end

function PC:OnPlayerCast(spellID)
	if type(spellID) ~= "number" or ns.isSecret(spellID) then return end
	local name = ns.canon(ns.get(C_Spell.GetSpellName, spellID))
	if name and OWN_CD[name] then ownCast[name] = GetTime() end
	if name then
		for _, s in ipairs(ns.SHIELDS) do if name == s then lastShield = s end end
	end
	if isStormstrike(spellID, name) then self:StormstrikeCast() return end
	local def = name and CD_TIMERS[name]
	if not def or not cfg().cdTimers then return end
	local now = GetTime()
	local cur = cdActive[def.key]
	if cur and now - cur.at < 1 then return end   -- samma cast två gånger (eller totemet hann före)
	startTimer(def, (def.buff and buffEnds(def)) or (now + def.dur), now)
end

-- Andra vägen för totems: castens ID kan vara secret i strid, men totemspårningen ser totemet.
-- Startar timern när totemet dyker upp (utan timer igång) och stoppar den när totemet försvinner
-- (dödat, Totemic Call). seen = totemet har synts under den här timern, så en färsk timer från casten
-- inte stoppas innan totemspårningen hunnit se totemet.
function PC:OnTotemsChanged()
	local TO = ns.Totems
	if not (TO and TO.Active) then return end
	local now = GetTime()
	for _, def in pairs(CD_TIMERS) do
		if def.totem then
			local slot = TO:Active(def.spell)
			local c = cdActive[def.key]
			if slot then
				if c then
					c.seen = true
				elseif cfg().cdTimers then
					-- Totemets egen starttid (via tid kvar) om den finns, annars hela tiden
					local left = TO.Remaining and TO:Remaining(slot)
					local ends = (type(left) == "number" and left > 0) and (now + math.min(left, def.dur)) or (now + def.dur)
					startTimer(def, ends, now).seen = true
				end
			elseif c and c.seen then
				cdActive[def.key] = nil
				self:UpdateTimers(now)
			end
		end
	end
end

-- Sekunder kvar på timern (nil = inte aktiv)
function PC:TimerLeft(key)
	local c = cdActive[key]
	if not c then return nil end
	return math.max(0, c.ends - GetTime())
end

-- Rage of the Farseer: buffen kan komma strax efter casten, läs om tiden medan den går
function PC:RefineTimers()
	for _, c in pairs(cdActive) do
		if c.def.buff then
			local e = buffEnds(c.def)
			if e then c.ends = e end
		end
	end
end

function PC:UpdateTimers(now)
	for _, def in pairs(CD_TIMERS) do
		local f = icons[def.key]
		local c = cdActive[def.key]
		if c and (not cfg().cdTimers or c.ends <= now) then
			cdActive[def.key] = nil
			c = nil
		end
		if f then
			if c then
				f.timer:SetText(string.format("%d", math.ceil(c.ends - now)))
			else
				f.timer:SetText("")
				setShown(f, false)
			end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Under vatten: andningen tar slut, Water Breathing håller på att gå ut
---------------------------------------------------------------------------------------------------
local function reagent(spell)
	for _, r in ipairs(ns.REAGENTS or {}) do
		if r.spell == spell then return r end
	end
end

-- spell (eller nil), text
function PC:BreathAdvice()
	if not ns.Spellbook:Knows("Water Breathing") then return nil, "Swim up for air." end
	local free = ns.Leveling and ns.Leveling.ReagentFree and ns.Leveling:ReagentFree()
	local r = reagent("Water Breathing")
	if free or not r then return "Water Breathing", "Cast Water Breathing — or swim up for air." end
	local n = ns.get(C_Item and C_Item.GetItemCount, r.item)
	if type(n) == "number" and n <= 0 then
		return nil, "Swim up for air — no " .. r.name .. " for Water Breathing."
	end
	return "Water Breathing", "Cast Water Breathing (" .. r.name .. (type(n) == "number" and (": " .. n) or "")
		.. ") — or swim up for air."
end

function PC:BreathWarning()
	if not cfg().breath then return end
	local spell, text = self:BreathAdvice()
	ns.Alert:Flash("breath", spell or "Water Breathing", "BREATH RUNNING OUT", text, { 0.3, 0.7, 1 }, 4, "critical")
end

-- MIRROR_TIMER_START: timer, value (ms kvar), maxvalue, scale (-1 = minskar), paused, label
function PC:OnMirrorStart(timer, value, maxValue, scale, paused)
	if ns.clean(timer) ~= "BREATH" then return end
	breath.token = breath.token + 1
	if not cfg().breath then return end
	paused, scale = ns.clean(paused), ns.clean(scale)
	if paused == true or (type(paused) == "number" and paused ~= 0) then return end
	if type(scale) == "number" and scale > 0 then return end   -- fylls på: du är uppe
	local v = ns.clean(value)
	local left = type(v) == "number" and v / 1000 or nil
	if not left then
		-- Okänt hur mycket luft som är kvar: varna inte direkt, anta full luft (max om det går att läsa)
		local mx = ns.clean(maxValue)
		left = (type(mx) == "number" and mx > 0) and mx / 1000 or BREATH_ASSUME
	end
	local tok = breath.token
	breath.scheduled = math.max(0, left - BREATH_WARN)
	C_Timer.After(breath.scheduled, function()
		if breath.token ~= tok then return end   -- timern stoppades eller startades om
		-- Fortfarande gott om luft (t.ex. pausad en stund): vänta lite till
		local now = GetMirrorTimerProgress and ns.get(GetMirrorTimerProgress, "BREATH")
		if type(now) == "number" and now / 1000 > BREATH_WARN + 2 then
			C_Timer.After(now / 1000 - BREATH_WARN, function()
				if breath.token == tok then PC:BreathWarning() end
			end)
			return
		end
		PC:BreathWarning()
	end)
end

function PC:BreathDelay() return breath.scheduled end

function PC:OnMirrorStop(timer)
	if ns.clean(timer) == "BREATH" then breath.token = breath.token + 1 end
end

-- Simmar utanför strid med Water Breathing som snart går ut: en varning per buff
function PC:CheckWaterBreathing()
	if not cfg().breath or InCombatLockdown() or ns.get(IsSwimming) ~= true then return end
	local a = playerAura(ns.SPELL_IDS and ns.SPELL_IDS["Water Breathing"], "Water Breathing")
	if ns.isSecret(a) or a == nil then return end
	local exp = ns.field(a, "expirationTime")
	if type(exp) ~= "number" or exp <= 0 then return end
	local left = exp - GetTime()
	if left <= 0 or left >= WB_LOW then return end
	local key = ns.field(a, "auraInstanceID") or exp
	if wbWarned == key then return end
	wbWarned = key
	local r = reagent("Water Breathing")
	local n = r and ns.get(C_Item and C_Item.GetItemCount, r.item)
	local text = string.format("%d s left. Recast it or head for the surface.", math.ceil(left))
	if r and type(n) == "number" and n <= 0 and not (ns.Leveling and ns.Leveling.ReagentFree and ns.Leveling:ReagentFree()) then
		text = string.format("%d s left and no %s — head for the surface.", math.ceil(left), r.name)
	end
	ns.Alert:Flash("waterbreathing", "Water Breathing", "WATER BREATHING ENDING", text, { 0.3, 0.7, 1 }, 4, "info")
end

---------------------------------------------------------------------------------------------------
-- Sköldladdningar
---------------------------------------------------------------------------------------------------
-- Returnerar sköldens namn, laddningar (tal eller nil), rått secret-värde
---------------------------------------------------------------------------------------------------
-- Sköldens laddningar via aura-containern (som Maelstrom): i strid är laddningarna secret. Spelet ritar
-- talet, och en täckbild (statusbar med sköldens ikon, full när laddningarna är fler än gränsen) ligger
-- över en röd blinkning. Vid få laddningar är täckbilden tom och det röda syns. Vi läser inget själva.
---------------------------------------------------------------------------------------------------
local shBox            -- nil = inte försökt, false = gick inte, annars { container, button, ... }
local shieldCounts     -- klienten räknar laddningar (vi har sett ett tal > 0); annars ingen röd blinkning

local function shieldLow() return math.max(1, math.floor(tonumber(cfg().shieldLow) or 1)) end

local function shieldIcon(s)
	if not s then
		for _, name in ipairs(ns.SHIELDS) do
			if ns.Spellbook:Knows(name) then s = name break end
		end
	end
	return (s and ns.spellIcon(s)) or "Interface\\Icons\\Spell_Nature_LightningShield"
end

-- Talet: inget vid 0, rött upp till gränsen, vitt över
local function shieldFormatter(low)
	if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
	local ok, fm = pcall(function()
		local x = C_StringUtil.CreateNumericRuleFormatter()
		x:SetBreakpoints({
			{ threshold = 0, format = "" },
			{ threshold = 1, format = "|cffff4040%d|r" },
			{ threshold = low + 1, format = "%d" },
		})
		if not formatterWorks(x, low + 2) then error("formatter") end
		return x
	end)
	return ok and fm or nil
end

-- Gränsen (Charges left to warn): täckbilden är tom vid <= gränsen, full över
local function applyShieldLow(box)
	local low = shieldLow()
	if box.low == low then return end
	box.low = low
	local okBar = box.cover and pcall(box.button.SetApplicationBar, box.button, box.cover,
		{ minApplications = low, maxApplications = low + 1, interpolation = immediate() })
	-- Utan täckbild skulle det röda alltid synas
	box.noBar = not okBar
	if box.noBar and box.cover then box.cover:Hide() end
	local fm = shieldFormatter(low)
	if not pcall(box.button.SetApplicationCount, box.button, box.fs, fm and { formatter = fm } or nil) then
		pcall(box.button.SetApplicationCount, box.button, box.fs)
	end
end

local function setCoverIcon(box, s)
	if not box.cover or box.coverSpell == (s or false) then return end
	box.coverSpell = s or false
	pcall(box.cover.SetStatusBarTexture, box.cover, shieldIcon(s))
	local ct = box.cover:GetStatusBarTexture()
	if type(ct) == "table" and ct.SetTexCoord then pcall(ct.SetTexCoord, ct, 0.08, 0.92, 0.08, 0.92) end
end

local function initShieldButton(box, button)
	local f = icons.shield
	local size = f:GetWidth()
	if type(size) ~= "number" or size <= 0 then size = ns.char.bars.procs.size or 36 end
	placeGameButton(button, size)
	noMouse(button)
	local base = button:CreateTexture(nil, "ARTWORK")
	base:SetPoint("TOPLEFT", 1, -1)
	base:SetPoint("BOTTOMRIGHT", -1, 1)
	base:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	base:SetTexture(shieldIcon())
	pcall(button.SetIcon, button, base)
	box.icon = base
	-- Rött under täckbilden: syns bara när den är tom (få laddningar)
	local red = CreateFrame("Frame", nil, button)
	red:SetAllPoints(button)
	red:SetFrameLevel(button:GetFrameLevel() + 1)
	red.tex = red:CreateTexture(nil, "OVERLAY")
	red.tex:SetAllPoints()
	red.tex:SetColorTexture(1, 0.12, 0.08, 0.6)
	pcall(red.tex.SetBlendMode, red.tex, "ADD")
	box.red = red
	box.redPulse = addPulse(red)
	-- Täckbilden: sköldens ikon som statusbar
	local cover = CreateFrame("StatusBar", nil, button)
	cover:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
	cover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
	cover:SetFrameLevel(button:GetFrameLevel() + 2)
	box.cover = cover
	setCoverIcon(box, nil)
	-- Talet (spelet skriver det)
	local num = CreateFrame("Frame", nil, button)
	num:SetAllPoints(button)
	num:SetFrameLevel(button:GetFrameLevel() + 3)
	local fs = num:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	fs:SetPoint("BOTTOMRIGHT", -2, 2)
	pcall(fs.SetFontObject, fs, ns.Theme.Font("FarseerFontCount"))
	ns.Theme.Border(num, { 0, 0, 0, 1 }, "OVERLAY", 0)
	box.fs = fs
	box.button = button
	applyShieldLow(box)
	PC:FlashShieldBox(box)
	PC.dirty = true
end

function PC:SetupShieldBox()
	if shBox ~= nil then return shBox end
	if not frame or InCombatLockdown() or aurasSecret() then return nil end
	if not cfg().shield then return nil end
	local any = false
	for _, s in ipairs(ns.SHIELDS) do
		if ns.Spellbook:Knows(s) then any = true end
	end
	if not any then return nil end
	local ids = {}
	for _, list in pairs(ns.SHIELD_IDS or {}) do
		for _, id in ipairs(list) do ids[id] = true end
	end
	local box = {}
	local ok, err = pcall(function()
		local f = icons.shield
		-- Föräldern är procs-rutan; ankaret följer sköldikonen när raden flyttar sig
		local c = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
		box.container = c
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		c:SetSize(f:GetWidth(), f:GetHeight())
		c:SetFrameStrata(frame:GetFrameStrata())
		c:SetFrameLevel(f:GetFrameLevel() + 5)
		c:SetUnit("player")
		noMouse(c)
		c:AddAuraSlot("shield", "HELPFUL", {
			candidateFilters = { includeSpellIDs = ids },
			initializeFrame = function(button)
				local ok2, e2 = pcall(initShieldButton, box, button)
				if not ok2 then ns.report("Shield container button: " .. tostring(e2)) end
			end,
		})
	end)
	if not ok then
		if box.container then pcall(box.container.Hide, box.container) end
		shBox = false
		PC.shBoxError = tostring(err)
		return false
	end
	shBox = box
	return box
end

function PC:ResetShieldBox()
	if InCombatLockdown() then return false end
	if shBox and shBox.container then pcall(shBox.container.Hide, shBox.container) end
	shBox = nil
	shieldCounts = nil   -- läses in igen nästa gång skölden syns
	PC.shBoxError = nil
	return true
end

function PC:ShieldBox() return shBox and shBox.button and shBox or nil end

---------------------------------------------------------------------------------------------------
-- Clearcasting och Flurry i spelets aura-container: i strid går buffarna inte att läsa, men containern
-- (Blizzard_CustomAuraContainer) visar dina egna buffar per spell-ID även då, med tid och laddningar.
---------------------------------------------------------------------------------------------------
local function procDef(key)
	for _, d in ipairs(PROCS) do if d.key == key then return d end end
end

local function initProcButton(box, def, button)
	local f = icons[def.key]
	local size = f:GetWidth()
	if type(size) ~= "number" or size <= 0 then size = ns.char.bars.procs.size or 36 end
	placeGameButton(button, size)
	noMouse(button)
	local tex = button:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 1, -1)
	tex:SetPoint("BOTTOMRIGHT", -1, 1)
	tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	if not pcall(tex.SetTexture, tex, PC:ProcIcon(def, nil)) then tex:SetTexture(def.file) end
	pcall(button.SetIcon, button, tex)
	-- Tid kvar: svep utan siffror
	local cd = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
	cd:SetAllPoints()
	pcall(cd.SetHideCountdownNumbers, cd, true)
	pcall(cd.SetDrawEdge, cd, false)
	if not pcall(button.SetDurationCooldown, button, cd) then cd:Hide() end
	-- Ram som blinkar: knappen finns bara medan buffen är uppe, så ramen behöver inget värde
	local glow = CreateFrame("Frame", nil, button)
	glow:SetPoint("CENTER", button, "CENTER")
	glow:SetSize(size * 1.7, size * 1.7)
	glow:SetFrameLevel(button:GetFrameLevel() + 2)
	local gt = glow:CreateTexture(nil, "OVERLAY")
	gt:SetAllPoints()
	gt:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	pcall(gt.SetBlendMode, gt, "ADD")
	gt:SetVertexColor(0.4, 0.8, 1)
	table.insert(box.glows, { frame = glow, pulse = addPulse(glow) })
	-- Laddningarna: spelets eget tal (visas från 2, som vår ikon)
	local num = CreateFrame("Frame", nil, button)
	num:SetAllPoints(button)
	num:SetFrameLevel(button:GetFrameLevel() + 3)
	local fs = num:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	fs:SetPoint("BOTTOMRIGHT", -2, 2)
	pcall(button.SetApplicationCount, button, fs)
	pcall(fs.SetFontObject, fs, ns.Theme.Font("FarseerFontCount"))
	ns.Theme.Border(num, { 0, 0, 0, 1 }, "OVERLAY", 0)
	box.button = button
	PC:FlashProcBox(def.key)
	PC.dirty = true
end

function PC:SetupProcBox(def)
	local cur = procBox[def.key]
	if cur ~= nil then return cur end
	if not frame or InCombatLockdown() or aurasSecret() then return nil end
	if not (def.box and cfg()[def.cfg]) then return nil end
	local ids, any = {}, false
	for _, id in ipairs(def.ids or {}) do ids[id] = true; any = true end
	if not any then return nil end
	local box = { glows = {} }
	local ok, err = pcall(function()
		local f = icons[def.key]
		local c = CreateFrame("AuraContainer", nil, frame, "CustomAuraContainerTemplate")
		box.container = c
		c:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
		c:SetSize(f:GetWidth(), f:GetHeight())
		c:SetFrameStrata(frame:GetFrameStrata())
		c:SetFrameLevel(f:GetFrameLevel() + 5)
		c:SetUnit("player")
		noMouse(c)
		c:AddAuraSlot(def.key, "HELPFUL", {
			candidateFilters = { includeSpellIDs = ids },
			initializeFrame = function(button)
				local ok2, e2 = pcall(initProcButton, box, def, button)
				if not ok2 then ns.report(def.name .. " container button: " .. tostring(e2)) end
			end,
		})
	end)
	if not ok then
		if box.container then pcall(box.container.Hide, box.container) end
		procBox[def.key] = false
		procBoxError[def.key] = tostring(err)
		return false
	end
	procBox[def.key] = box
	return box
end

function PC:SetupProcBoxes()
	for _, def in ipairs(PROCS) do
		if def.box then self:SetupProcBox(def) end
	end
end

function PC:ResetProcBoxes()
	if InCombatLockdown() then return false end
	for key, box in pairs(procBox) do
		if box and box.container then pcall(box.container.Hide, box.container) end
		procBox[key] = nil
	end
	wipe(procBoxError)
	return true
end

-- Containern för en proc när spelet har gett den en knapp
function PC:ProcBox(key)
	local box = procBox[key]
	return box and box.button and box or nil
end
function PC:ProcBoxState(key)
	local box = procBox[key]
	if box == nil then return "not built" end
	if box == false then return "unavailable: " .. tostring(procBoxError[key]) end
	return box.button and "active" or "waiting for the buff"
end

-- Kan buffen komma? Den har setts förut med den här specen, eller talangen finns i spellboken.
function PC:ProcExpected(def)
	if ns.char.procSeen and ns.char.procSeen[def.key] then return true end
	return def.talent ~= nil and ns.Spellbook:Knows(def.talent) == true
end

function PC:FlashProcBox(key)
	local box = procBox[key]
	if not box then return end
	local def = procDef(key)
	local on = def and def.flash and flashOn() or false
	for _, g in ipairs(box.glows) do
		pcall(g.frame.SetShown, g.frame, on)
		if g.pulse then pcall(g.pulse.Set, g.pulse, on) end
	end
end

function PC:StyleProcBoxes()
	if InCombatLockdown() then return end
	for _, def in ipairs(PROCS) do
		local box = procBox[def.key]
		if box then
			local f = icons[def.key]
			pcall(box.container.SetShown, box.container, cfg()[def.cfg] and true or false)
			self:FlashProcBox(def.key)
			local size = f:GetWidth()
			if type(size) == "number" and size > 0 then
				pcall(box.container.SetSize, box.container, size, size)
				if box.button then pcall(box.button.SetSize, box.button, size, size) end
				for _, g in ipairs(box.glows) do pcall(g.frame.SetSize, g.frame, size * 1.7, size * 1.7) end
			end
		end
	end
end
function PC:ShieldBoxState()
	if shBox == nil then return "not built" end
	if shBox == false then return "unavailable: " .. tostring(PC.shBoxError) end
	if not shBox.button then return "waiting for the buff" end
	if shBox.noBar then return "active (no low-charge flash)" end
	return shieldCounts and "active" or "active (charges not counted yet)"
end

-- Det röda: bara när klienten räknar laddningar; blinkar om Flash procs är på, annars fast
function PC:FlashShieldBox(b)
	local box = b or shBox
	if not (box and box.red) then return end
	local on = shieldCounts and not box.noBar and true or false
	pcall(box.red.SetShown, box.red, on)
	if box.redPulse then pcall(box.redPulse.Set, box.redPulse, on and flashOn()) end
end

function PC:StyleShieldBox()
	local box = shBox
	if not box or InCombatLockdown() then return end
	local f = icons.shield
	pcall(box.container.SetShown, box.container, cfg().shield and true or false)
	if box.button then applyShieldLow(box) end
	self:FlashShieldBox()
	local size = f:GetWidth()
	if type(size) ~= "number" or size <= 0 then return end
	pcall(box.container.SetSize, box.container, size, size)
	if box.button then pcall(box.button.SetSize, box.button, size, size) end
end

-- Returnerar skölden, laddningar, rått secret-värde, och true som fjärde värde när auran inte gick att
-- läsa (då är skölden den senast kända: läst före striden eller castad i den)
function PC:Shield()
	local unknown = false
	for _, s in ipairs(ns.SHIELDS) do
		if ns.Spellbook:Knows(s) then
			local a, blocked = playerAura(ns.SHIELD_IDS[s], s, shieldInstance[s])
			if blocked then unknown = true end
			if present(a) then
				lastShield = s
				shieldInstance[s] = instanceOf(a) or shieldInstance[s]
				local n, raw = applications(a)
				-- 0 stacks på en aura som finns = klienten räknar inte laddningar: visa skölden utan siffra
				if n == 0 then return s, nil, nil end
				if n and n > 0 and not shieldCounts then
					shieldCounts = true
					self:FlashShieldBox()
				end
				return s, n, raw
			end
		end
	end
	if unknown then return lastShield or nil, nil, nil, true end
	wipe(shieldInstance)
	lastShield = false
	return nil
end
function PC:LastShield() return lastShield end

function PC:UpdateShield()
	local f = icons.shield
	if not cfg().shield then
		setShown(f, false)
		if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(nil) end
		return
	end
	local s, n, raw, unknown = self:Shield()
	local box = self:ShieldBox()
	if unknown and box then
		-- I strid: spelets knapp visar skölden när den är uppe; under den en blek ikon = ingen sköld.
		-- Platsen står kvar så att knappen inte hamnar ovanpå en annan ikon.
		local shown = s
		if not shown then
			for _, x in ipairs(ns.SHIELDS) do if ns.Spellbook:Knows(x) then shown = x break end end
		end
		f.icon:SetTexture(ns.spellIcon(shown or "Lightning Shield"))
		f.icon:SetDesaturated(true)
		f.icon:SetAlpha(0.35)
		f.title = shown or "Shield"
		f.count:SetText("")
		f.glow:Off()
		setShown(f, true)
		if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(nil) end
		return
	end
	f.icon:SetDesaturated(false)
	f.icon:SetAlpha(1)
	if not s then
		setShown(f, false)
		if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(nil) end
		return
	end
	local low = n ~= nil and n <= shieldLow()
	f.icon:SetTexture(ns.spellIcon(s))
	f.title = s
	setShown(f, true)
	if box then
		-- Spelet skriver talet och visar det röda; vi byter bara ikonen på täckbilden
		setCoverIcon(box, s)
		f.count:SetText("")
	else
		showCount(f.count, n, raw, low)
	end
	if low and flashOn() then f.glow:On() else f.glow:Off() end
	if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(n, raw, low) end
end

---------------------------------------------------------------------------------------------------
-- Windfury
---------------------------------------------------------------------------------------------------
local function wfKind(id)
	local kind = ns.WINDFURY_PROCS[id]
	if kind then return kind end
	local name = ns.canon(ns.get(C_Spell.GetSpellName, id))
	return name and ns.WINDFURY_NAMES[name] or nil
end

local function strictKnown(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown and ns.get(C_SpellBook.IsSpellKnown, id) == true then return true end
	return false
end

local function onGCD(id)
	local info = C_Spell and C_Spell.GetSpellCooldown and ns.get(C_Spell.GetSpellCooldown, id)
	return ns.field(info, "isOnGCD") == true
end

-- SPELL_UPDATE_COOLDOWN med proc-spellens ID = Windfury slog
function PC:OnCooldownEvent(id)
	if not cfg().windfury or not InCombatLockdown() then return end
	if type(id) ~= "number" or ns.isSecret(id) or id == 439431 then return end
	local kind = wfKind(id)
	if not kind or strictKnown(id) or onGCD(id) then return end
	local now = GetTime()
	if now == wf.at then return end
	wf.at = now
	self:WindfuryProc(kind)
end

function PC:WindfuryProc(kind)
	wf.count = wf.count + 1
	wf.shownAt = GetTime()
	wfText:SetText(kind == "totem" and "WINDFURY! (totem)" or "WINDFURY!")
	wfText:SetAlpha(1)
	wfText:Show()
	if cfg().windfurySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_GOLDTRAIT or 8960, "SFX") end
	ns.fire("WINDFURY_PROC", kind, wf.count)
end

function PC:WindfuryCount() return wf.count end

local function updateWindfuryText(now)
	local age = now - wf.shownAt
	if age < 1.2 then
		wfText:SetAlpha(age < 0.6 and 1 or (1.2 - age) / 0.6)
	elseif wfText:IsShown() then
		wfText:Hide()
	end
end

---------------------------------------------------------------------------------------------------
-- Låg mana
---------------------------------------------------------------------------------------------------
function PC:ManaPct()
	local cur, max = ns.get(UnitPower, "player", 0), ns.get(UnitPowerMax, "player", 0)
	if type(cur) == "number" and type(max) == "number" and max > 0 then return cur / max * 100 end
	return nil
end

local function ready(spell)
	if not ns.Spellbook:Knows(spell) then return false end
	local id = ns.Spellbook:ID(spell)
	local info = id and C_Spell and C_Spell.GetSpellCooldown and ns.get(C_Spell.GetSpellCooldown, id)
	local dur = ns.field(info, "duration")
	if dur == nil then
		-- Okänt: Earth Shock via HUD:ens shock-klocka (delas av alla shocks), annars egen klocka
		if spell == "Earth Shock" and ns.HUD and ns.HUD.Ready then return ns.HUD:Ready("Earth Shock") end
		local cd, at = OWN_CD[spell], ownCast[spell]
		if cd and at then return GetTime() - at >= cd end
		return true
	end
	return dur <= 1.5
end
PC.Ready = function(_, spell) return ready(spell) end

-- Bästa förslaget: spell, text
function PC:ManaAdvice()
	if ready("Mana Tide Totem") then return "Mana Tide Totem", "Drop Mana Tide Totem (restores your group's mana over 12 s)." end
	if ns.Spellbook:Knows("Water Shield") then
		local a, blocked = playerAura(ns.SHIELD_IDS["Water Shield"], "Water Shield")
		-- Går auran inte att läsa (strid) gäller den senast kända skölden; ingen känd = inget råd
		local up = present(a) or (blocked and lastShield == "Water Shield")
		local knownOff = (not blocked and not present(a)) or (blocked and lastShield ~= nil and lastShield ~= "Water Shield")
		if not up and knownOff then return "Water Shield", "Switch to Water Shield — it gives mana when you're hit." end
	end
	if ns.Spellbook:Knows("Mana Spring Totem") and not ns.Totems:Active("Mana Spring Totem") then
		return "Mana Spring Totem", "Drop Mana Spring Totem."
	end
	return nil, "Downrank your heals, use a mana potion or drink after the fight."
end

function PC:CheckMana()
	local c = cfg()
	if not c.mana then return end
	local pct = self:ManaPct()
	if not pct then return end
	local limit = c.manaPct or 25
	if pct > limit + 15 or not InCombatLockdown() then
		manaArmed = true
		return
	end
	if pct < limit and manaArmed then
		manaArmed = false
		local spell, text = self:ManaAdvice()
		ns.Alert:Flash("lowmana", spell or "Mana Spring Totem", string.format("LOW MANA (%d %%)", math.floor(pct)), text,
			{ 0.3, 0.55, 1 }, 4, "advice")
	end
end

---------------------------------------------------------------------------------------------------
-- Purge
---------------------------------------------------------------------------------------------------
local function hostile(unit)
	return ns.get(UnitExists, unit) == true and ns.get(UnitCanAttack, "player", unit) == true
		and ns.get(UnitIsDeadOrGhost, unit) ~= true
end
-- Som hostile, men secret (okänt) räknas som kanske fientlig: bara säkert vänliga/döda/saknade sorteras bort
local function maybeHostile(unit)
	return ns.get(UnitExists, unit) ~= false and ns.get(UnitCanAttack, "player", unit) ~= false
		and ns.get(UnitIsDeadOrGhost, unit) ~= true
end

-- Buffar på enheten som Purge tar bort (magiska). nil = går inte att läsa just nu.
function PC:Purgeable(unit)
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not fn then return nil end
	local out = {}
	for i = 1, 40 do
		local ok, a = pcall(fn, unit, i, "HELPFUL")
		if not ok or ns.isSecret(a) then return nil end
		if a == nil then break end
		local okd, disp = pcall(function() return a.dispelName end)
		if not okd or ns.isSecret(disp) then return nil end
		if disp == "Magic" then
			table.insert(out, { name = ns.field(a, "name"), icon = ns.field(a, "icon"), id = ns.field(a, "spellId") })
		end
	end
	return out
end

function PC:UpdatePurge()
	local f = icons.purge
	if not (cfg().purge and ns.Spellbook:Knows("Purge") and maybeHostile("target")) then setShown(f, false) return end
	local list = self:Purgeable("target")
	if list == nil then return end   -- secret: behåll det vi visade
	f.buffs = list
	if #list == 0 then setShown(f, false) return end
	f.icon:SetTexture(list[1].icon or ns.spellIcon("Purge"))
	f.count:SetText(#list > 1 and tostring(#list) or "")
	f.count:SetTextColor(1, 1, 1)
	if flashOn() then f.glow:On() else f.glow:Off() end
	setShown(f, true)
	if cfg().purgeAlertPvp and ns.Bars:Mode() == "PVP" then
		-- Bara buffar som är värda att Purga: i PvP har nästan alla Fortitude/Intellect/Mark
		local worth
		for _, b in ipairs(list) do
			if type(b.name) == "string" and ns.PURGE_PRIORITY and ns.PURGE_PRIORITY[b.name] then worth = b break end
		end
		local guid = ns.get(UnitGUID, "target") or "target"
		local key = worth and (guid .. ":" .. worth.name)
		if key and not purgeWarned[key] then
			purgeWarned[key] = true
			ns.Alert:Flash("purge", "Purge", "PURGE: " .. worth.name:upper(),
				"Target has " .. #list .. " buff(s) that Purge removes.", { 0.75, 0.45, 1 }, 2.5, "info")
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Fiendens casts
---------------------------------------------------------------------------------------------------
local UNIT_LABEL = { target = "Target", focus = "Focus" }

-- Siktar casten på dig eller din grupp? true/false, nil = går inte att läsa (varna då hellre)
local function aimedAtUs(unit)
	local tt = unit .. "target"
	local ex = ns.get(UnitExists, tt)
	if ex == nil then return nil end
	if ex ~= true then return false end
	local me = ns.get(UnitIsUnit, tt, "player")
	if me == nil then return nil end
	if me == true then return true end
	for i = 1, 4 do
		local p = ns.get(UnitIsUnit, tt, "party" .. i)
		if p == nil then return nil end
		if p == true then return true end
	end
	return false
end

-- Earth Shock når fram (20 m)? nil = okänt
local function shockInRange(unit)
	if not (C_Spell and C_Spell.IsSpellInRange) then return nil end
	local v = ns.get(C_Spell.IsSpellInRange, ns.L("Earth Shock"), unit)
	if v == nil then return nil end
	return v == true or v == 1
end

function PC:ReadCast(unit)
	local ok, name, _, _, startMS, endMS, _, _, notInt = ns.getAll(UnitCastingInfo, unit)
	local channel = false
	if not (ok and (name or startMS)) then
		ok, name, _, _, startMS, endMS, _, notInt = ns.getAll(UnitChannelInfo, unit)
		channel = true
		if not (ok and (name or startMS)) then return nil end
	end
	return { name = name, start = startMS and startMS / 1000 or GetTime(), ends = endMS and endMS / 1000 or nil,
		notInt = notInt, channel = channel }
end

function PC:OnUnitCast(event, unit)
	if UNIT_LABEL[unit] == nil or not cfg().enemyCasts then return end
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		if not maybeHostile(unit) then casts[unit] = nil return end
		local c = self:ReadCast(unit) or { start = GetTime(), channel = event == "UNIT_SPELLCAST_CHANNEL_START" }
		c.unit = unit
		casts[unit] = c
		if cfg().enemyCastAlertPvp and ns.Bars:Mode() == "PVP" then
			-- Earth Shock bara om den är redo och casten går att avbryta, annars Grounding Totem om den är
			-- redo, annars ingen varning (inget att trycka på)
			local what = c.name and c.name:upper() or (UNIT_LABEL[unit]:upper() .. " CASTING")
			if c.notInt ~= true and ready("Earth Shock") and shockInRange(unit) ~= false then
				ns.Alert:Flash("cast-" .. unit, "Earth Shock", "KICK! " .. what, "Earth Shock interrupts the cast.",
					{ 1, 0.35, 0.2 }, 1.5, "critical")
			elseif ready("Grounding Totem") and aimedAtUs(unit) ~= false then
				ns.Alert:Flash("cast-" .. unit, "Grounding Totem", "GROUND IT! " .. what,
					"Grounding Totem absorbs a spell aimed at you.", { 1, 0.35, 0.2 }, 1.5, "critical")
			end
		end
	elseif event == "UNIT_SPELLCAST_DELAYED" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
		-- Pushback: ny sluttid (annars försvinner baren medan fienden fortfarande castar)
		local old = casts[unit]
		if old then
			local c = self:ReadCast(unit)
			if c then
				c.unit = unit
				if c.notInt == nil then c.notInt = old.notInt end
				casts[unit] = c
			end
		end
	elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		if casts[unit] then casts[unit].notInt = true end
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
		if casts[unit] then casts[unit].notInt = false end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		-- SUCCEEDED kommer när en channel börjar och FAILED kan gälla ett annat castförsök: de avslutar inget
		casts[unit] = nil
	end
end

function PC:CurrentCast()
	local now = GetTime()
	for _, unit in ipairs({ "target", "focus" }) do
		local c = casts[unit]
		if c then
			if (c.ends and c.ends < now) or now - c.start > 15 then casts[unit] = nil else return c end
		end
	end
end

function PC:UpdateCast(now)
	local c = cfg().enemyCasts and self:CurrentCast()
	if not c then castBar:Hide() return end
	local label = UNIT_LABEL[c.unit] or c.unit
	local kick = c.notInt == true and "  |cff999999(can't be interrupted)|r"
		or (ns.Spellbook:Knows("Earth Shock") and "  |cffff6040Earth Shock!|r" or "")
	local left = c.ends and (c.ends - now)
	castBar.text:SetText(string.format("%s: %s%s%s", label, c.name or "casting", left and string.format(" %.1f", left) or "", kick))
	if c.ends and c.ends > c.start then
		local p = (now - c.start) / (c.ends - c.start)
		castBar:SetValue(c.channel and (1 - p) or p)
	elseif not c.timer then
		-- Secret: spelets duration-objekt driver baren om det går
		c.timer = true
		local fn = c.channel and UnitChannelDuration or UnitCastingDuration
		local ok, d = pcall(fn, c.unit)
		local set = false
		if ok and d and castBar.SetTimerDuration then
			-- Channels töms (återstående tid), vanliga casts fylls
			local dir = c.channel and Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
			if dir ~= nil then set = pcall(castBar.SetTimerDuration, castBar, d, nil, dir) end
			if not set then set = pcall(castBar.SetTimerDuration, castBar, d) end
		end
		if not set then castBar:SetValue(1) end
	end
	castBar:SetStatusBarColor(c.notInt == true and 0.6 or 1, c.notInt == true and 0.6 or 0.7, c.notInt == true and 0.6 or 0)
	castBar:Show()
end

---------------------------------------------------------------------------------------------------
-- Diminishing returns
---------------------------------------------------------------------------------------------------
local function unitKey(unit)
	return ns.get(UnitGUID, unit) or unit
end

local function categoryName(cat)
	local S = C_SpellDiminish
	if S and S.GetSpellDiminishCategoryInfo then
		local info = ns.get(S.GetSpellDiminishCategoryInfo, cat)
		local n = ns.field(info, "name")
		if type(n) == "string" then return n end
	end
	return "Category " .. tostring(cat)
end

function PC:OnDiminish(unit, info)
	if type(unit) ~= "string" or ns.isSecret(unit) then return end
	local cat = ns.field(info, "category")
	if cat == nil then return end
	local key = unitKey(unit)
	dr[key] = dr[key] or {}
	local now = GetTime()
	local cur = dr[key][cat]
	local start = ns.field(info, "startTime")
	local dur = ns.field(info, "duration")
	local level = 1
	if cur and now < cur.start + cur.dur then level = cur.level + ((start == nil or start ~= cur.rawStart) and 1 or 0) end
	dr[key][cat] = {
		rawStart = start, start = (type(start) == "number" and start > 0) and start or now,
		dur = (type(dur) == "number" and dur > 0) and dur or (ns.DR_RESET or 18),
		level = level, immune = ns.field(info, "isImmune") == true,
	}
end

-- DR på enheten: { { name, text, left } }
function PC:Diminish(unit)
	local key = unitKey(unit)
	local list, now = {}, GetTime()
	if dr[key] and next(dr[key]) == nil then dr[key] = nil end
	for cat, d in pairs(dr[key] or {}) do
		local left = d.start + d.dur - now
		if left > 0 then
			local state = (d.immune or d.level >= 3) and "|cffff4040immune|r" or (d.level == 2 and "|cffffd10025 %|r" or "|cff40ff4050 %|r")
			table.insert(list, { name = categoryName(cat), text = state, left = left })
		else
			dr[key][cat] = nil
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

function PC:UpdateDR()
	if not cfg().dr or not ns.get(UnitExists, "target") then drText:SetText("") return end
	local parts = {}
	for _, d in ipairs(self:Diminish("target")) do
		table.insert(parts, string.format("%s %s %d s", d.name, d.text, math.ceil(d.left)))
	end
	drText:SetText(#parts > 0 and ("DR: " .. table.concat(parts, "   ")) or "")
end

---------------------------------------------------------------------------------------------------
-- Blizzards förslag (Assisted Combat)
---------------------------------------------------------------------------------------------------
function PC:Suggestion()
	local A = C_AssistedCombat
	if not (A and A.GetNextCastSpell) then return nil end
	local id = ns.get(A.GetNextCastSpell)
	if type(id) == "number" and id > 0 then return id end
	return nil
end

function PC:UpdateAssisted()
	local f = icons.assisted
	local id = cfg().assisted and self:Suggestion()
	if not id then setShown(f, false) return end
	f.icon:SetTexture(ns.get(C_Spell.GetSpellTexture, id) or 134400)
	f.title = ns.get(C_Spell.GetSpellName, id) or "Suggestion"
	setShown(f, true)
end

---------------------------------------------------------------------------------------------------
-- Det som rör sig: Windfury-texten, castbaren, DR-tider
function PC:UpdateFast()
	if not frame or not frame:IsShown() then return end
	local now = GetTime()
	updateWindfuryText(now)
	if self.relayoutAt and now >= self.relayoutAt then self.dirty = true end   -- en reserverad plats har gått ut
	self:UpdateTimers(now)
	self:UpdateCast(now)
	self:UpdateDR()
	if self.dirty then
		self.dirty = false
		self:Layout()
	end
end

function PC:Update()
	if not frame or not frame:IsShown() then
		if ns.Reminders and ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(nil) end
		return
	end
	self:UpdateMaelstrom()
	self:UpdateProcs()
	self:RefineTimers()
	self:UpdateShield()
	self:UpdatePurge()
	self:UpdateAssisted()
	self:UpdateFast()
end

function PC:SetShown(show)
	ns.char.bars.procs.show = show
	self:Layout()
end

function PC:Refresh()
	self:Layout()
	self:SetupMaelstromBox()
	self:StyleMaelstromBox()
	self:SetupShieldBox()
	self:StyleShieldBox()
	self:SetupProcBoxes()
	self:StyleProcBoxes()
	self:Update()
end

local castFrame = CreateFrame("Frame")
castFrame:SetScript("OnEvent", function(_, event, unit)
	local ok, err = pcall(PC.OnUnitCast, PC, event, unit)
	if not ok then ns.report(err) end
end)

-- Egna casts (egen ram: castFrame ovan är registrerad för target/focus)
local playerCastFrame = CreateFrame("Frame")
playerCastFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
	if event ~= "UNIT_SPELLCAST_SUCCEEDED" or ns.isSecret(unit) or unit ~= "player" then return end
	local ok, err = pcall(PC.OnPlayerCast, PC, spellID)
	if not ok then ns.report(err) end
end)

function PC:OnShamanLogin()
	self:Build()
	self:Layout()
	for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
		"UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_UPDATE" }) do
		pcall(castFrame.RegisterUnitEvent, castFrame, e, "target", "focus")
	end
	pcall(playerCastFrame.RegisterUnitEvent, playerCastFrame, "UNIT_SPELLCAST_SUCCEEDED", "player")
	ns.on("MIRROR_TIMER_START", function(_, ...) PC:OnMirrorStart(...) end)
	ns.on("MIRROR_TIMER_STOP", function(_, timer) PC:OnMirrorStop(timer) end)
	ns.on("PLAYER_TARGET_CHANGED", function()
		casts.target = nil
		-- Purge-ikonen gällde det gamla targetet (i strid kan det nya ofta inte läsas: visa inget hellre än fel)
		if icons.purge then icons.purge.buffs = nil; setShown(icons.purge, false) end
		-- Stormstrike-debuffen sitter på det gamla targetet
		if ssCast then
			ssCast = nil
			if icons.stormstrike then setShown(icons.stormstrike, false) end
		end
		local c = hostile("target") and PC:ReadCast("target")
		if c then c.unit = "target"; casts.target = c end
	end)
	ns.on("PLAYER_FOCUS_CHANGED", function() casts.focus = nil end)
	ns.on("SPELL_UPDATE_COOLDOWN", function(_, id) PC:OnCooldownEvent(id) end)
	ns.on("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", function(_, unit, info) PC:OnDiminish(unit, info) end)
	ns.listen("COMBAT_START", function() wf.count = 0 end)
	ns.listen("COMBAT_END", function()
		wipe(purgeWarned); manaArmed = true
		PC:SetupMaelstromBox()
		PC:StyleMaelstromBox()
		PC:SetupShieldBox()
		PC:StyleShieldBox()
		PC:SetupProcBoxes()
		PC:StyleProcBoxes()
	end)
	-- Ny spec: buffar som setts förut kanske inte kommer längre
	ns.listen("SPEC_CHANGED", function(_, first)
		if not first and ns.char then ns.char.procSeen = {} end
	end)
	ns.on("SPELLS_CHANGED", function()
		if not InCombatLockdown() then
			PC:SetupMaelstromBox(); PC:StyleMaelstromBox()
			PC:SetupShieldBox(); PC:StyleShieldBox()
			PC:SetupProcBoxes(); PC:StyleProcBoxes()
		end
	end)
	-- En encounter- eller PvP-låsning kan släppa efter striden: containrarna byggs när aurorna öppnas
	-- (händelsen kommer efter att låsningen släppt; en kort väntan så att C_Secrets hunnit ändras)
	ns.on("ADDON_RESTRICTION_STATE_CHANGED", function()
		C_Timer.After(0.2, function()
			if InCombatLockdown() or aurasSecret() then return end
			PC:SetupMaelstromBox(); PC:StyleMaelstromBox()
			PC:SetupShieldBox(); PC:StyleShieldBox()
			PC:SetupProcBoxes(); PC:StyleProcBoxes()
		end)
	end)
	ns.listen("BARS_LAYOUT", function() PC:Layout() end)
	ns.listen("PROCS_CHANGED", function() PC:Refresh() end)
	ns.listen("TOTEMS_CHANGED", function() PC:OnTotemsChanged() end)
	ns.listen("SPELLS_CHANGED", function() PC:Refresh() end)
	ns.every(0.5, "procs-mana", function() PC:CheckMana() end)
	ns.every(0.5, "procs-water-breathing", function() PC:CheckWaterBreathing() end)
end
