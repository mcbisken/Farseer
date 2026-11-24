-- Farseer: kärna. Laddas först.
-- WoW: Forever kör retail-klienten med Midnights addon-begränsningar: i strid kan många värden vara
-- "secret". Att jämföra, räkna med eller ens testa ett secret-värde kastar fel, så ALL läsning av
-- spel-data går via ns.get / ns.getAll / ns.clean nedan, som byter secret-värden mot nil.

local ADDON, ns = ...
ns.ADDON = ADDON
ns.NAME = "Farseer"

local meta = C_AddOns and C_AddOns.GetAddOnMetadata
ns.VERSION = (meta and meta(ADDON, "Version")) or "dev"

local PREFIX = "|cff0070ddFarseer|r: "
function ns.print(fmt, ...)
	if select("#", ...) > 0 then fmt = string.format(fmt, ...) end
	print(PREFIX .. tostring(fmt))
end

---------------------------------------------------------------------------------------------------
-- Secret-säker läsning
---------------------------------------------------------------------------------------------------
local issecret = issecretvalue
function ns.isSecret(v)
	if issecret then return issecret(v) == true end
	return false
end
local isSecret = ns.isSecret

-- v om det är ett vanligt värde, annars nil
function ns.clean(v)
	if isSecret(v) then return nil end
	return v
end

-- Första returvärdet från fn(...) om anropet lyckades och värdet inte är secret
function ns.get(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, v = pcall(fn, ...)
	if ok and not isSecret(v) then return v end
	return nil
end

-- Alla returvärden; secret-värden blir nil. Första returvärdet är true om anropet lyckades.
function ns.getAll(fn, ...)
	if type(fn) ~= "function" then return false end
	local r = { n = 0 }
	local function pack(ok, ...)
		r.ok = ok
		r.n = select("#", ...)
		for i = 1, r.n do
			local v = select(i, ...)
			if isSecret(v) then v = nil end
			r[i] = v
		end
	end
	pack(pcall(fn, ...))
	if not r.ok then return false end
	return true, unpack(r, 1, r.n)
end

-- Fält ur en tabell som kan innehålla secret-värden
function ns.field(t, key)
	if type(t) ~= "table" or isSecret(t) then return nil end
	local ok, v = pcall(function() return t[key] end)
	if ok then return ns.clean(v) end
	return nil
end

function ns.inCombat()
	return InCombatLockdown() and true or false
end

---------------------------------------------------------------------------------------------------
-- Händelser
---------------------------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}

-- Fel rapporteras via spelets felhanterare, men max 10 gånger per session: klienten slutar leverera
-- fel efter 100 och tickers som felar varje sekund skulle annars dränka allt.
local reported, seen = 0, {}
ns.errors = {}
local function report(err)
	err = tostring(err)
	if seen[err] then return end
	seen[err] = true
	table.insert(ns.errors, err)
	reported = reported + 1
	if reported > 10 then
		if reported == 11 then ns.print("many errors — not showing more. /farseer debug lists them.") end
		return
	end
	local h = geterrorhandler and geterrorhandler()
	if h then h(err) else ns.print("error: %s", err) end
end
ns.report = report

-- ns.on(event, fn): fn(event, ...). Okända händelser kastar i Forever, så registreringen skyddas.
function ns.on(event, fn)
	if not handlers[event] then
		local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
		if not ok then return false end
		handlers[event] = {}
	end
	table.insert(handlers[event], fn)
	return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
	local list = handlers[event]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], event, ...)
		if not ok then report(err) end
	end
end)

-- Interna meddelanden mellan moduler
local listeners = {}
function ns.listen(msg, fn)
	listeners[msg] = listeners[msg] or {}
	table.insert(listeners[msg], fn)
end
function ns.fire(msg, ...)
	local list = listeners[msg]
	if not list then return end
	for i = 1, #list do
		local ok, err = pcall(list[i], ...)
		if not ok then report(err) end
	end
end

---------------------------------------------------------------------------------------------------
-- Efter strid: skyddade ändringar (säkra knappar, keybinds, makron) väntar tills striden är slut
---------------------------------------------------------------------------------------------------
local queue, order = {}, {}
function ns.afterCombat(key, fn)
	if not InCombatLockdown() then
		queue[key] = nil
		local ok, err = pcall(fn)
		if not ok then report(err) end
		return true
	end
	if not queue[key] then table.insert(order, key) end
	queue[key] = fn
	return false
end

ns.on("PLAYER_REGEN_ENABLED", function()
	local keys = order
	order = {}
	for _, key in ipairs(keys) do
		local fn = queue[key]
		queue[key] = nil
		if fn then
			local ok, err = pcall(fn)
			if not ok then report(err) end
		end
	end
	ns.fire("COMBAT_END")
end)
ns.on("PLAYER_REGEN_DISABLED", function() ns.fire("COMBAT_START") end)

---------------------------------------------------------------------------------------------------
-- Hjälpare
---------------------------------------------------------------------------------------------------
function ns.copy(t)
	if type(t) ~= "table" then return t end
	local out = {}
	for k, v in pairs(t) do out[k] = ns.copy(v) end
	return out
end

-- Fyller i saknade nycklar från defaults (rör aldrig det användaren har satt)
function ns.merge(dst, defaults)
	for k, v in pairs(defaults) do
		if dst[k] == nil then
			dst[k] = ns.copy(v)
		elseif type(v) == "table" and type(dst[k]) == "table" and not v[1] then
			ns.merge(dst[k], v)
		end
	end
	return dst
end

-- Gör dst till en kopia av src men behåller befintliga undertabeller: flikar, flyttbara ramar och moduler
-- håller referenser till dem, så de får inte bytas ut (t.ex. när en profil laddas).
function ns.assign(dst, src)
	for k in pairs(dst) do
		if src[k] == nil then dst[k] = nil end
	end
	for k, v in pairs(src) do
		if type(v) == "table" and type(dst[k]) == "table" then ns.assign(dst[k], v) else dst[k] = ns.copy(v) end
	end
	return dst
end

function ns.trim(s) return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", "")) end

function ns.colorText(text, r, g, b)
	return string.format("|cff%02x%02x%02x%s|r", r * 255, g * 255, b * 255, text)
end

function ns.spellIcon(name)
	if not name or name == "" then return 134400 end
	local tex = C_Spell and ns.get(C_Spell.GetSpellTexture, name)
	return tex or 134400
end

---------------------------------------------------------------------------------------------------
-- Flyttbara ramar (bars, varningsrutan). Upplåsta visar de ett handtag som man drar i.
---------------------------------------------------------------------------------------------------
ns.movers = {}

function ns.placeFrame(frame, cfg)
	if frame.fsDragging then return end   -- dras just nu: släpp först, annars hoppar ramen tillbaka
	frame:ClearAllPoints()
	local p = cfg.point or "CENTER"
	frame:SetPoint(p, UIParent, cfg.relPoint or p, cfg.x or 0, cfg.y or 0)
	frame:SetScale(cfg.scale or 1)
end

function ns.makeMovable(frame, cfg, label)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)
	local h = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	h:SetAllPoints()
	h:SetFrameLevel(frame:GetFrameLevel() + 20)
	h:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
	h:SetBackdropColor(0, 0.44, 0.87, 0.35)
	h:SetBackdropBorderColor(0.2, 0.6, 1, 0.9)
	local t = h:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	t:SetPoint("BOTTOM", h, "TOP", 0, 2)
	t:SetText(label or "")
	h:EnableMouse(true)
	h:RegisterForDrag("LeftButton")
	h:SetScript("OnDragStart", function()
		if InCombatLockdown() then return end
		frame.fsDragging = true
		frame:StartMoving()
	end)
	h:SetScript("OnDragStop", function()
		frame:StopMovingOrSizing()
		frame.fsDragging = nil
		-- Snäpp mot rutnätet (håll Shift för fri placering)
		if ns.Grid:SnapOn() and not (IsShiftKeyDown and IsShiftKeyDown()) and ns.Grid:Snap(frame, cfg) then return end
		local p, _, rp, x, y = frame:GetPoint()
		cfg.point, cfg.relPoint, cfg.x, cfg.y = p, rp, x, y
	end)
	h:Hide()
	table.insert(ns.movers, h)
	return h
end

function ns.setLocked(locked)
	if InCombatLockdown() then
		ns.print("can't unlock/lock in combat.")
		return
	end
	ns.char.locked = locked and true or false
	for _, h in ipairs(ns.movers) do h:SetShown(not ns.char.locked) end
	ns.Grid:Update()
	ns.fire("LOCK_CHANGED", ns.char.locked)
end

---------------------------------------------------------------------------------------------------
-- Rutnät: visas när ramarna är upplåsta, och ramar som släpps snäpper mot det
---------------------------------------------------------------------------------------------------
local Grid = {}
ns.Grid = Grid
local gridFrame, gridLines, gridBuilt = nil, {}, nil

function Grid:Config() return (ns.db and ns.db.grid) or { show = true, snap = true, size = 16 } end
function Grid:Size()
	local s = tonumber(self:Config().size) or 16
	return math.max(4, math.min(64, s))
end
function Grid:SnapOn() return self:Config().snap ~= false end

local function line(i)
	local t = gridLines[i]
	if not t then
		t = gridFrame:CreateTexture(nil, "BACKGROUND")
		gridLines[i] = t
	end
	t:ClearAllPoints()
	t:Show()
	return t
end

function Grid:Build()
	if not gridFrame then
		gridFrame = CreateFrame("Frame", "FarseerGrid", UIParent)
		gridFrame:SetAllPoints(UIParent)
		gridFrame:SetFrameStrata("BACKGROUND")
		gridFrame:EnableMouse(false)
		gridFrame:Hide()
		gridFrame:SetScript("OnSizeChanged", function() gridBuilt = nil; if gridFrame:IsShown() then Grid:Build() end end)
	end
	local size = self:Size()
	local w, h = UIParent:GetWidth(), UIParent:GetHeight()
	if gridBuilt == size .. ":" .. w .. ":" .. h then return end
	gridBuilt = size .. ":" .. w .. ":" .. h
	local n = 0
	local function draw(vertical, offset)
		n = n + 1
		local t = line(n)
		local center = offset == 0
		local major = (offset / size) % 4 == 0
		if center then t:SetColorTexture(1, 0.25, 0.25, 0.75)
		elseif major then t:SetColorTexture(0.3, 0.65, 1, 0.35)
		else t:SetColorTexture(1, 1, 1, 0.12) end
		if vertical then
			t:SetWidth(center and 2 or 1)
			t:SetPoint("TOP", gridFrame, "TOP", offset, 0)
			t:SetPoint("BOTTOM", gridFrame, "BOTTOM", offset, 0)
		else
			t:SetHeight(center and 2 or 1)
			t:SetPoint("LEFT", gridFrame, "LEFT", 0, offset)
			t:SetPoint("RIGHT", gridFrame, "RIGHT", 0, offset)
		end
	end
	-- Linjerna utgår från skärmens mitt, så att mittlinjen och snäppet stämmer överens
	for k = 0, math.floor(w / 2 / size) do
		draw(true, k * size)
		if k > 0 then draw(true, -k * size) end
	end
	for k = 0, math.floor(h / 2 / size) do
		draw(false, k * size)
		if k > 0 then draw(false, -k * size) end
	end
	for i = n + 1, #gridLines do gridLines[i]:Hide() end
end

function Grid:Update()
	local show = ns.char and not ns.char.locked and self:Config().show ~= false and not InCombatLockdown()
	if show then
		self:Build()
		gridFrame:Show()
	elseif gridFrame then
		gridFrame:Hide()
	end
end

-- Flyttar ramens mitt till närmaste rutnätspunkt (räknat från skärmens mitt) och sparar positionen
function Grid:Snap(frame, cfg)
	local cx, cy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not (cx and cy and ux and uy) then return false end
	local s = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local size = self:Size()
	local dx = math.floor((cx * s - ux) / size + 0.5) * size
	local dy = math.floor((cy * s - uy) / size + 0.5) * size
	cfg.point, cfg.relPoint, cfg.x, cfg.y = "CENTER", "CENTER", dx / s, dy / s
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", cfg.x, cfg.y)
	return true
end

-- I strid kan ramarna inte flyttas: göm rutnätet så länge
ns.listen("COMBAT_START", function() if gridFrame then gridFrame:Hide() end end)
ns.listen("COMBAT_END", function() Grid:Update() end)

---------------------------------------------------------------------------------------------------
-- Moduler
---------------------------------------------------------------------------------------------------
ns.modules = {}
function ns.module(name)
	local m = { name = name }
	table.insert(ns.modules, m)
	ns[name] = m
	return m
end

local function runAll(method)
	for _, m in ipairs(ns.modules) do
		if m[method] then
			local ok, err = pcall(m[method], m)
			if not ok then report(err) end
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Sparad data
---------------------------------------------------------------------------------------------------
ns.DEFAULTS = {
	account = {
		macros = {
			mouseover = true,     -- [@mouseover] i skada/heal-makron
			focus = true,         -- [@focus] i interrupt/purge
			selfcast = true,      -- heal faller tillbaka på dig själv
			downrankKick = false, -- Earth Shock(Rank 1) som interrupt (experimentellt)
			perCharacter = false, -- karaktärsmakron (bara 18 platser) i stället för kontomakron (120)
			ranks = {},           -- downranking: [spell] = rank (tomt = Data/ClickCast.lua DOWNRANK_DEFAULT)
		},
		custom = {},              -- egna makron: { name, body, perChar }
		alert = { point = "TOP", x = 0, y = -160, scale = 1, sound = true },
		grid = { show = true, snap = true, size = 16 },   -- rutnät + snäpp när ramarna är upplåsta
		fearMobs = {},            -- egna tillägg: [lowername] = "Namn"
		fearMobsRemoved = {},
		bossRules = {},           -- egna: [lowername] = { name = "...", totem = "..." }
		minimap = true,
		profiles = {},            -- sparade profiler: [namn] = ögonblicksbild (Modules/Profiles.lua)
	},
	char = {
		mode = "PVE",
		autoMode = true,          -- PvP i BG/arena, PvE i dungeon/raid
		locked = true,
		situations = nil,         -- fylls från Data/Situations vid första inloggning
		callSet = 1,              -- vilken Call-spell addonet får skriva totems till (1-3)
		seqReset = 10,            -- /castsequence reset (sekunder)
		bars = {
			situations = { point = "BOTTOM", x = 0, y = 210, scale = 1, show = true, size = 36, perRow = 10 },
			counter = { point = "BOTTOM", x = 0, y = 256, scale = 1, show = true, size = 32 },
			totems = { point = "BOTTOM", x = -260, y = 210, scale = 1, show = true, size = 34 },
			reminders = { point = "BOTTOM", x = 260, y = 210, scale = 1, show = true, size = 34 },
			hud = { point = "BOTTOM", x = 0, y = 310, scale = 1, show = true, size = 30 },
			gear = { point = "BOTTOM", x = -260, y = 262, scale = 1, show = true, size = 28 },
			procs = { point = "BOTTOM", x = 0, y = 392, scale = 1, show = true, size = 36 },
		},
		counterTotems = {
			"Tremor Totem", "Poison Cleansing Totem", "Disease Cleansing Totem", "Grounding Totem",
			"Earthbind Totem", "Stoneclaw Totem", "Fire Resistance Totem", "Frost Resistance Totem",
			"Nature Resistance Totem", "Windwall Totem",
		},
		advisor = {
			enabled = true,
			fear = true,          -- fear/charm/sleep på dig -> Tremor
			fearMobs = true,      -- fear-mobs på target/nameplates -> Tremor
			pvpClass = true,      -- fiendens klass i PvP -> kontratotem
			pvpNearby = false,    -- även fiender som bara syns i närheten (annars: bara target/focus/de som targetar dig)
			dispel = true,        -- gift/sjukdom på gruppen -> Cleansing
			boss = true,          -- boss/zon -> resist-totem
			noTotems = true,      -- i strid utan totems
			groupComp = true,     -- rekommendera situation efter gruppens sammansättning
			sound = true,
			showText = true,
		},
		reminders = {
			shield = true,
			imbue = true,
			imbueMinutes = 5,
			preferWaterShield = false,
			imbueSpell = "auto",
			offhand = true,           -- påminn om imbue på off-hand (dual wield)
			offhandSpell = "auto",    -- "auto" = Flametongue Weapon om du har den, annars samma som main hand
			oil = true,               -- vapenolja/slipsten (checklistan + påminnelse före pull)
		},
		hud = {
			cooldowns = true,     -- cooldown-ikoner
			hidden = {},          -- [spell eller "trinket13"] = true: dölj ikonen
			range = true,         -- räckvidd mot target (text + röda ikoner)
			flameShock = true,    -- Flame Shock-timer på target
			riptide = true,       -- Riptide per mål
			chainHealHint = true, -- "Chain Heal +25 %" när Riptide är ute
			swing = true,         -- swing timer
			swingCombatOnly = true,
		},
		totemAlerts = {
			death = true,         -- varna när ett totem dör i förtid (Grounding åt en spell ...)
			allTotems = false,    -- alla totems, inte bara de viktiga
			tremorPulse = true,   -- nedräkning till Tremor Totems nästa puls
			range = true,         -- markera totems vars buff inte når dig (utom räckhåll)
			rangeAlert = true,    -- ...och varna en gång per totem
			callButton = true,    -- Totemic Call-knapp på totembaren
			expire = true,        -- varna innan totems går ut
			expireSec = 20,       -- ...så här många sekunder innan
			expireLongOnly = true,-- bara totems som varar minst en minut (inte Searing/Magma)
			party = true,         -- vilka i gruppen saknar dina totembuffar (utanför strid)
			manaDim = true,       -- tona ned totemknappar du inte har mana till
		},
		procs = {
			maelstrom = true,     -- Maelstrom Weapon-stackar
			maelstromSound = true,-- ljud vid 5 stackar
			shield = true,        -- laddningar på Lightning/Water Shield
			shieldLow = 1,        -- varna vid så här få laddningar
			windfury = true,      -- "WINDFURY!" när det procar
			windfurySound = false,
			purge = true,         -- target har en buff som kan purgas
			purgeAlertPvp = true, -- ...och varna i PvP-läge
			mana = true,          -- låg mana: förslag (Mana Tide, Water Shield ...)
			manaPct = 25,
			enemyCasts = true,    -- target/focus castar: castbar + "Earth Shock!"
			enemyCastAlertPvp = true,
			dr = true,            -- diminishing returns på target
			assisted = true,      -- Blizzards förslag på nästa spell (om klienten har det)
			clearcast = true,     -- Elemental Focus (Clearcasting)
			stormstrike = true,   -- Stormstrike-buffen (nästa shock/bolt +20 %)
			flurry = false,       -- Flurry
			cdTimers = true,      -- nedräkning för Mana Tide Totem och Rage of the Farseer
			announce = false,     -- ...och meddelande i grupp-/raidchatten
			bossmods = true,      -- DBM/BigWigs: lys upp Tremor/Cleansing innan bossens fear/gift
			bossLead = 4,         -- ...så här många sekunder innan
			pullCheck = true,     -- pull-timer: påminnelse om totems, imbue och sköld
			breath = true,        -- under vatten: Water Breathing / andning tar slut
		},
		spec = {
			auto = true,          -- känn av spec (talanger) och byt BiS-spec + profil
			setBis = true,
			profiles = { elemental = "", enhancement = "", restoration = "" },
			last = nil,           -- senast avkända spec
		},
		clickBackup = nil,        -- spelets click-cast-profil innan Farseer ändrade den
		gear = { auto = false, pve = "", pvp = "" },
		leveling = {
			announce = true,      -- skriv i chatten när nya ranker väntar hos trainern
			reagents = true,      -- varna när reagens tar slut
			readyCheck = true,    -- checklistan vid ready check
			checklist = true,     -- checklistan när du går in i en raid
			hitSpell = 17,
			hitMelee = 8,
		},
		profile = nil,            -- senast laddade/sparade profil
		bisSpec = "elemental",
		bisPhase = "prebis",
		learnedDur = {},          -- totemtider inlärda utanför strid
		bindLayer = { mod = "", keep = false },  -- keybind-mallar: lägg på Shift/Ctrl/Alt, behåll egna bindningar
	},
}

ns.on("ADDON_LOADED", function(_, name)
	if name ~= ADDON then return end
	FarseerDB = ns.merge(type(FarseerDB) == "table" and FarseerDB or {}, ns.DEFAULTS.account)
	FarseerCharDB = ns.merge(type(FarseerCharDB) == "table" and FarseerCharDB or {}, ns.DEFAULTS.char)
	ns.db = FarseerDB
	ns.char = FarseerCharDB
	runAll("OnLoad")
end)

ns.on("PLAYER_LOGIN", function()
	local _, class = UnitClass("player")
	ns.isShaman = (class == "SHAMAN")
	runAll("OnLogin")
	if ns.isShaman then
		runAll("OnShamanLogin")
		-- Upplåst vid /reload: visa handtagen och rutnätet igen
		if not ns.char.locked and not InCombatLockdown() then ns.setLocked(false) end
		ns.print("v%s loaded. Type |cffffd100/farseer|r for settings.", ns.VERSION)
	else
		ns.print("you're not playing a shaman: bars and warnings are disabled (macros and BiS still work).")
	end
end)
