-- Situationsbaren (PvE/PvP-set) och kontratotem-baren.
-- Situationsknapp: vänsterklick = nästa totem i setet (/castsequence), högerklick = hela setet med
-- Call of the Elements (Farseer skriver in setets totems i Call-slottarna precis före klicket,
-- utanför strid; i strid används det set som senast laddades).
-- Säkra knappar får bara ändras utanför strid, så allt sådant går via ns.afterCombat.

local _, ns = ...
local BA = ns.module("Bars")

local MAX = ns.MAX_SITUATIONS
local sitBar, cntBar
local sitButtons, cntButtons = {}, {}
local loadedIndex, loadedMode

function BA:OnLoad()
	if type(ns.char.situations) ~= "table" then
		ns.char.situations = ns.copy(ns.DEFAULT_SITUATIONS)
	end
	for mode, list in pairs(ns.DEFAULT_SITUATIONS) do
		if type(ns.char.situations[mode]) ~= "table" then ns.char.situations[mode] = ns.copy(list) end
	end
end

function BA:Mode() return ns.char.mode == "PVP" and "PVP" or "PVE" end
function BA:List(mode) return ns.char.situations[mode or self:Mode()] end
function BA:Situation(i) return self:List()[i] end

-- Setets totems som du kan, i ordning, högst ett per element.
-- Cachas per situation (UpdateMana körs vid varje UNIT_POWER_FREQUENT/SPELL_UPDATE_USABLE): töms i
-- ApplySituations, vid SPELLS_CHANGED/inlärda spells och TOTEMS_CHANGED. Posten kontrollerar också att
-- setets totems inte ändrats på plats (billig jämförelse, ingen ny tabell).
local knownCache = setmetatable({}, { __mode = "k" })   -- [situation] = { src = {...}, list = {...}, key = "a,b" }
local NO_TOTEMS = {}

function BA:InvalidateKnown() wipe(knownCache) end

local function knownEntry(s)
	local src = s and s.totems or NO_TOTEMS
	local e = s and knownCache[s]
	if e and #e.src == #src then
		local same = true
		for i = 1, #src do
			if e.src[i] ~= src[i] then same = false break end
		end
		if same then return e end
	end
	local out, used = {}, {}
	for _, name in ipairs(src) do
		local el = ns.Spellbook:TotemElement(name)
		if name ~= "" and el and not used[el] and ns.Spellbook:Knows(name) then
			used[el] = true
			table.insert(out, name)
		end
	end
	local copy = {}
	for i = 1, #src do copy[i] = src[i] end
	e = { src = copy, list = out, key = table.concat(out, ",") }
	if s then knownCache[s] = e end
	return e
end

-- Publik: en egen kopia (anroparen får ändra i den utan att förstöra cachen)
function BA:KnownTotems(s)
	local list = knownEntry(s).list
	local out = {}
	for i = 1, #list do out[i] = list[i] end
	return out
end

function BA:SequenceText(s)
	local totems = self:KnownTotems(s)
	if #totems == 0 then return nil end
	local loc = {}
	for i, t in ipairs(totems) do loc[i] = ns.L(t) end
	if #loc == 1 then return "/cast " .. loc[1] end
	return string.format("/castsequence reset=combat/%d %s", ns.char.seqReset or 10, table.concat(loc, ", "))
end

-- Vilken Call-spell Farseer använder (vald i inställningarna, annars högsta kända)
function BA:CallSpell()
	local known = ns.Spellbook:CallCount()
	if known == 0 then return nil, 0 end
	local set = math.min(math.max(ns.char.callSet or 1, 1), known)
	return ns.CALLS[set], set
end

---------------------------------------------------------------------------------------------------
-- Call of the Elements: skriv in setet
---------------------------------------------------------------------------------------------------
local refused = false
local watch = CreateFrame("Frame")
watch:RegisterEvent("ADDON_ACTION_FORBIDDEN")
watch:RegisterEvent("ADDON_ACTION_BLOCKED")
watch:SetScript("OnEvent", function(_, _, addon, fn)
	if ns.isSecret(addon) or ns.isSecret(fn) then return end
	if addon == ns.ADDON and type(fn) == "string" and fn:find("SetMultiCastSpell", 1, true) and not refused then
		refused = true
		ns.print("the client blocked Farseer from changing Call of the Elements. Right-click will drop the set already in Call instead.")
	end
end)

-- Skriver totems (namn) till Call-setet. Okända totems hoppas över; tomma slottar töms.
function BA:WriteCall(totems, set)
	if InCombatLockdown() or refused or not SetMultiCastSpell then return false end
	if not set then
		local call
		call, set = self:CallSpell()
		if not call then return false end
	end
	local want = {}
	for _, name in ipairs(totems) do
		if ns.Spellbook:Knows(name) then
			local el = ns.Spellbook:TotemElement(name)
			if el then want[ns.SLOT[el]] = ns.Spellbook:TotemSpellID(name) or ns.Spellbook:ID(name) end
		end
	end
	for slot = 1, 4 do
		pcall(SetMultiCastSpell, ns.Totems:MultiCastAction(set, slot), want[slot] or 0)
	end
	return true
end

function BA:LoadCall(index, mode)
	if InCombatLockdown() or refused or not SetMultiCastSpell then return false end
	local s = self:List(mode)[index]
	local call, set = self:CallSpell()
	if not s or not call then return false end
	self:WriteCall(self:KnownTotems(s), set)
	loadedIndex, loadedMode = index, mode or self:Mode()
	self:UpdateMarks()
	return true
end

function BA:LoadedIndex()
	if loadedMode == self:Mode() then return loadedIndex end
end

---------------------------------------------------------------------------------------------------
-- Knappar
---------------------------------------------------------------------------------------------------
local function makeIcon(b, size)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.border = b:CreateTexture(nil, "OVERLAY")
	b.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
	b.border:SetSize(size * 1.65, size * 1.65)
	b.border:SetPoint("CENTER")
	b.hl = b:CreateTexture(nil, "HIGHLIGHT")
	b.hl:SetAllPoints()
	b.hl:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
	b.hl:SetBlendMode("ADD")
	b.key = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
	b.key:SetPoint("TOPRIGHT", -1, -2)
end

local function sitTooltip(self)
	local s = BA:Situation(self.index)
	if not s then return end
	GameTooltip:SetOwner(self, "ANCHOR_TOP")
	GameTooltip:SetText(s.name .. (BA:Mode() == "PVP" and "  |cffff6060PvP|r" or "  |cff60ff60PvE|r"))
	if s.desc and s.desc ~= "" then GameTooltip:AddLine(s.desc, 1, 1, 1, true) end
	GameTooltip:AddLine(" ")
	for i, name in ipairs(s.totems or {}) do
		local el = ns.Spellbook:TotemElement(name)
		local c = el and ns.ELEMENT_COLOR[el] or { 0.6, 0.6, 0.6 }
		local knows = ns.Spellbook:Knows(name)
		GameTooltip:AddLine(string.format("%d. %s%s", i, name, knows and "" or "  |cffff4040(not learned)|r"), c[1], c[2], c[3])
	end
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: drop the next totem in order", 0.6, 0.8, 1)
	local call = BA:CallSpell()
	if call then
		GameTooltip:AddLine("Right-click: the full set with " .. call, 0.6, 0.8, 1)
	else
		GameTooltip:AddLine("Right-click: same as left (Call of the Elements comes at level 20)", 0.6, 0.6, 0.6)
	end
	local k1 = ns.BindingEngine:KeyFor("CLICK FarseerSit" .. self.index .. ":LeftButton")
	local k2 = ns.BindingEngine:KeyFor("CLICK FarseerSit" .. self.index .. ":RightButton")
	if k1 or k2 then GameTooltip:AddLine("Key: " .. (k1 or "-") .. " / full set: " .. (k2 or "-"), 0.8, 0.8, 0.8) end
	if self.reason then GameTooltip:AddLine("Recommended: " .. self.reason, 0.3, 1, 0.3, true) end
	GameTooltip:Show()
end

function BA:BuildSituationBar()
	local cfg = ns.char.bars.situations
	local size = cfg.size or 36
	sitBar = CreateFrame("Frame", "FarseerSituationBar", UIParent)
	sitBar:SetSize(size, size)
	ns.placeFrame(sitBar, cfg)
	sitBar.handle = ns.makeMovable(sitBar, cfg, "Farseer: situations")
	sitBar.mode = sitBar:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	sitBar.mode:SetPoint("RIGHT", sitBar, "LEFT", -6, 0)
	for i = 1, MAX do
		local b = CreateFrame("Button", "FarseerSit" .. i, sitBar, "SecureActionButtonTemplate")
		b:SetSize(size, size)
		b:RegisterForClicks("AnyUp", "AnyDown")
		b.index = i
		makeIcon(b, size)
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		b.label:SetPoint("TOP", b, "BOTTOM", 0, -2)
		b.label:SetWidth(size + 14)
		b.label:SetWordWrap(false)
		b.dots = {}
		for d = 1, 4 do
			local t = b:CreateTexture(nil, "OVERLAY")
			t:SetSize(size / 4 - 1, 3)
			t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", (d - 1) * size / 4, 1)
			b.dots[d] = t
		end
		b.callMark = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.callMark:SetPoint("TOPLEFT", 2, -2)
		b.callMark:SetText("|cff40c0ffC|r")
		b.callMark:Hide()
		b.glow = ns.addGlow(b, 1, 0.85, 0.2)
		b.rec = ns.addGlow(b, 0.3, 1, 0.3)
		b:SetScript("PreClick", function(self, button, down)
			if not BA:PressCounts(self, button, down) then return end
			if button == "RightButton" then
				if not InCombatLockdown() then BA:LoadCall(self.index) end
				-- Utan Call-spell kör högerklick samma /castsequence som vänsterklick
				if not BA:CallSpell() then BA:SeqPressed(self.index) end
			else
				BA:SeqPressed(self.index)
			end
		end)
		b:SetScript("OnEnter", sitTooltip)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		_G["BINDING_NAME_CLICK FarseerSit" .. i .. ":LeftButton"] = "Situation " .. i .. ": next totem"
		_G["BINDING_NAME_CLICK FarseerSit" .. i .. ":RightButton"] = "Situation " .. i .. ": full set (Call)"
		sitButtons[i] = b
	end
end

function BA:ApplySituations()
	if not sitBar then return end
	if InCombatLockdown() then
		ns.afterCombat("situations", function() BA:ApplySituations() end)
		return
	end
	wipe(knownCache)
	local cfg = ns.char.bars.situations
	local size, gap = cfg.size or 36, 6
	local perRow = math.max(1, cfg.perRow or MAX)
	local list = self:List()
	local shown = 0
	local call = self:CallSpell()
	for i = 1, MAX do
		local b = sitButtons[i]
		local s = list[i]
		b:SetSize(size, size)
		if s and not s.hidden then
			shown = shown + 1
			local col, row = (shown - 1) % perRow, math.floor((shown - 1) / perRow)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", sitBar, "TOPLEFT", col * (size + gap), -row * (size + 16))
			local seq = self:SequenceText(s)
			local totems = self:KnownTotems(s)
			b:SetAttribute("type", seq and "macro" or nil)
			b:SetAttribute("macrotext", seq)
			if call and seq then
				b:SetAttribute("*type2", "spell")
				b:SetAttribute("*spell2", ns.L(call))
				b:SetAttribute("*macrotext2", nil)
			else
				b:SetAttribute("*type2", seq and "macro" or nil)
				b:SetAttribute("*macrotext2", seq)
				b:SetAttribute("*spell2", nil)
			end
			local first = s.icon or (s.totems and s.totems[1])
			b.icon:SetTexture(ns.spellIcon(first))
			b.icon:SetDesaturated(#totems == 0)
			b:SetAlpha(#totems == 0 and 0.45 or 1)
			b.label:SetText(s.name)
			for d = 1, 4 do
				local name = s.totems and s.totems[d]
				local el = name and ns.Spellbook:TotemElement(name)
				local c = el and ns.ELEMENT_COLOR[el]
				if c and ns.Spellbook:Knows(name) then
					b.dots[d]:SetColorTexture(c[1], c[2], c[3], 1)
					b.dots[d]:Show()
				else
					b.dots[d]:Hide()
				end
			end
			b:Show()
		else
			b:Hide()
		end
	end
	local cols = math.min(shown, perRow)
	local rows = math.max(1, math.ceil(shown / perRow))
	sitBar:SetSize(math.max(size, cols * (size + gap) - gap), rows * (size + 16) - 16 + 12)
	sitBar.mode:SetText(self:Mode() == "PVP" and "|cffff6060PvP|r" or "|cff60ff60PvE|r")
	sitBar:SetShown(cfg.show and shown > 0)
	self:UpdateKeys()
	self:UpdateMarks()
	self:UpdateMana()
end

function BA:UpdateKeys()
	for i, b in ipairs(sitButtons) do
		b.key:SetText(ns.BindingEngine:ShortKey(ns.BindingEngine:KeyFor("CLICK FarseerSit" .. i .. ":LeftButton")))
	end
	for i, b in ipairs(cntButtons) do
		b.key:SetText(ns.BindingEngine:ShortKey(ns.BindingEngine:KeyFor("CLICK FarseerCounter" .. i .. ":LeftButton")))
	end
end

function BA:UpdateMarks()
	local idx = self:LoadedIndex()
	for i, b in ipairs(sitButtons) do b.callMark:SetShown(idx == i) end
end

---------------------------------------------------------------------------------------------------
-- Kontratotems
---------------------------------------------------------------------------------------------------
function BA:BuildCounterBar()
	local cfg = ns.char.bars.counter
	local size = cfg.size or 32
	cntBar = CreateFrame("Frame", "FarseerCounterBar", UIParent)
	cntBar:SetSize(size, size)
	ns.placeFrame(cntBar, cfg)
	ns.makeMovable(cntBar, cfg, "Farseer: counter totems")
	for i = 1, 12 do
		local b = CreateFrame("Button", "FarseerCounter" .. i, cntBar, "SecureActionButtonTemplate")
		b:SetSize(size, size)
		b:RegisterForClicks("AnyUp", "AnyDown")
		makeIcon(b, size)
		b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
		b.cd:SetAllPoints()
		b.cd:SetDrawEdge(false)
		b.glow = ns.addGlow(b, 1, 0.85, 0.2)
		b:SetScript("OnEnter", function(self)
			if not self.spell then return end
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			local id = ns.Spellbook:ID(self.spell)
			if not (id and pcall(GameTooltip.SetSpellByID, GameTooltip, id)) then GameTooltip:SetText(self.spell) end
			if self.reason then GameTooltip:AddLine("Farseer: " .. self.reason, 1, 0.85, 0.2, true) end
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		_G["BINDING_NAME_CLICK FarseerCounter" .. i .. ":LeftButton"] = "Counter totem " .. i
		cntButtons[i] = b
	end
end

function BA:ApplyCounter()
	if not cntBar then return end
	if InCombatLockdown() then
		ns.afterCombat("counter", function() BA:ApplyCounter() end)
		return
	end
	local cfg = ns.char.bars.counter
	local size, gap = cfg.size or 32, 4
	local n = 0
	for _, spell in ipairs(ns.char.counterTotems) do
		if n < #cntButtons and ns.Spellbook:Knows(spell) then
			n = n + 1
			local b = cntButtons[n]
			b:SetSize(size, size)
			b:ClearAllPoints()
			b:SetPoint("LEFT", cntBar, "LEFT", (n - 1) * (size + gap), 0)
			b:SetAttribute("type", "spell")
			b:SetAttribute("spell", ns.L(spell))
			b.spell = spell
			b.icon:SetTexture(ns.spellIcon(spell))
			b:Show()
		end
	end
	for i = n + 1, #cntButtons do
		local b = cntButtons[i]
		b:SetAttribute("type", nil)
		b.spell = nil
		b:Hide()
	end
	cntBar:SetSize(math.max(size, n * (size + gap) - gap), size)
	cntBar:SetShown(cfg.show and n > 0)
	self:UpdateKeys()
	self:UpdateCooldowns()
	self:UpdateMana()
end

-- Cooldown-svep på kontratotems (Earthbind, Stoneclaw, Grounding ...). Vanliga ramar: fungerar i strid.
function BA:UpdateCooldowns()
	for _, b in ipairs(cntButtons) do
		if b.spell and b.cd then ns.setSpellCooldown(b.cd, b.spell) end
	end
end

---------------------------------------------------------------------------------------------------
-- /castsequence: vilket totem situationsknappen lägger härnäst
-- Klientens sekvensläge går inte att läsa, så det följs här: ett tryck på knappen följt (inom 1 s) av en
-- cast av ett av setets totems flyttar fram läget. reset=combat/N: börjar om efter strid eller N sekunder.
---------------------------------------------------------------------------------------------------
local seq = {}   -- [index] = { key, pos, at, pressed }
local PRESS_WINDOW = 1
local REARM_GAP = 0.3   -- ett tryck så här snart efter att sekvensen gått fram är samma tryck (släppet)

local function seqFor(index, known)
	local key, totems = known.key, known.list
	local q = seq[index]
	if not q or q.key ~= key then
		q = { key = key, pos = 1, at = -100 }
		seq[index] = q
	end
	if q.pos > 1 and GetTime() - q.at > (ns.char.seqReset or 10) then q.pos = 1 end
	if q.pos > #totems then q.pos = 1 end
	return q
end

-- Totemet vänsterklick på situationen lägger härnäst (nil om du inte kan något i setet)
function BA:NextTotem(index)
	local known = knownEntry(self:Situation(index))
	if #known.list == 0 then return nil end
	return known.list[seqFor(index, known).pos]
end

function BA:SeqPressed(index)
	local known = knownEntry(self:Situation(index))
	if #known.list == 0 then return end
	local q = seqFor(index, known)
	local now = GetTime()
	-- Castens SUCCEEDED kan komma före knappsläppet: släppet ska inte öppna ett nytt fönster
	if now - q.at < REARM_GAP then return end
	q.pressed = now
end

-- Säkra knappar med AnyUp + AnyDown får PreClick två gånger per tryck, men klienten castar bara på en av
-- dem (CVar ActionButtonUseKeyDown). Bara den riktningen räknas. CVar okänd: nedtrycket räknas och
-- släppet av samma knapp hoppas över. down = nil (t.ex. /click): räknas.
function BA:PressCounts(b, button, down)
	if type(down) ~= "boolean" then return true end
	local getBool = (C_CVar and C_CVar.GetCVarBool) or rawget(_G, "GetCVarBool")
	local useDown = ns.get(getBool, "ActionButtonUseKeyDown")
	if type(useDown) == "boolean" then return down == useDown end
	b.heldDown = b.heldDown or {}
	button = button or "LeftButton"
	if down then
		b.heldDown[button] = true
		return true
	end
	if b.heldDown[button] then
		b.heldDown[button] = nil
		return false
	end
	return true
end

function BA:OnCast(name)
	local now = GetTime()
	local changed = false
	for index, q in pairs(seq) do
		if q.pressed and now - q.pressed <= PRESS_WINDOW then
			local known = knownEntry(self:Situation(index))
			local totems = known.list
			-- Har setet ändrats sedan trycket börjar sekvensen om (seqFor byter tabell)
			for i, t in ipairs(seqFor(index, known) == q and totems or {}) do
				if t == name then
					-- Fram till totemet efter det som castades (synkar också om läget var fel)
					q.pos = i % #totems + 1
					q.at, q.pressed = now, nil
					changed = true
					break
				end
			end
		end
	end
	if changed then self:UpdateMana() end
end

function BA:ResetSequences()
	for _, q in pairs(seq) do q.pos, q.pressed = 1, nil end
end

---------------------------------------------------------------------------------------------------
-- Mana: tona knappar blå när du inte har råd med totemet (vanliga texturer, fungerar i strid)
---------------------------------------------------------------------------------------------------
-- true = råd, false = för lite mana, nil = okänt (secret eller API saknas)
function BA:CanAfford(spell)
	if not spell or spell == "" or not C_Spell then return nil end
	local arg = ns.Spellbook:ID(spell) or ns.L(spell)
	if C_Spell.IsSpellUsable then
		local ok, _, noMana = ns.getAll(C_Spell.IsSpellUsable, arg)
		if ok and noMana == true then return false end
		if ok and noMana == false then return true end
	end
	if C_Spell.GetSpellPowerCost then
		local costs = ns.get(C_Spell.GetSpellPowerCost, arg)
		local mana = ns.get(UnitPower, "player", 0)
		if type(costs) ~= "table" or type(mana) ~= "number" then return nil end
		local cost = 0
		for i = 1, 8 do
			local e = ns.field(costs, i)
			if e == nil then break end
			local kind, name = ns.field(e, "type"), ns.field(e, "name")
			if kind == 0 or name == "MANA" then
				local c = ns.field(e, "cost")
				if type(c) ~= "number" then return nil end
				cost = c
			elseif kind == nil and name == nil then
				return nil
			end
		end
		return mana >= cost
	end
	return nil
end

local function tint(b, spell, on)
	local dim = on and spell ~= nil and BA:CanAfford(spell) == false or false
	if b.noMana ~= dim then
		b.noMana = dim
		if dim then b.icon:SetVertexColor(0.4, 0.4, 1) else b.icon:SetVertexColor(1, 1, 1) end
	end
end

function BA:UpdateMana()
	local on = ns.char.totemAlerts == nil or ns.char.totemAlerts.manaDim ~= false
	local list = self:List()
	for i, b in ipairs(sitButtons) do
		local s = list[i]
		tint(b, (s and not s.hidden) and self:NextTotem(i) or nil, on)
	end
	for _, b in ipairs(cntButtons) do tint(b, b.spell, on) end
end

-- UNIT_POWER_FREQUENT kommer många gånger i sekunden: högst var 0,25 s (sista värdet kommer alltid med)
local manaPending, manaAt = false, -100
local MANA_GAP = 0.25
function BA:QueueMana()
	if manaPending then return end
	local wait = MANA_GAP - (GetTime() - manaAt)
	if wait <= 0 then
		manaAt = GetTime()
		self:UpdateMana()
		return
	end
	manaPending = true
	C_Timer.After(wait, function()
		manaPending = false
		manaAt = GetTime()
		local ok, err = pcall(BA.UpdateMana, BA)
		if not ok then ns.report(err) end
	end)
end

local powerFrame = CreateFrame("Frame")
powerFrame:SetScript("OnEvent", function(_, _, unit)
	if ns.isSecret(unit) or unit ~= "player" then return end
	local ok, err = pcall(BA.QueueMana, BA)
	if not ok then ns.report(err) end
end)

---------------------------------------------------------------------------------------------------
-- Markeringar från Advisor (vanliga texturer, fungerar i strid)
---------------------------------------------------------------------------------------------------
-- want: [totemnamn] = orsak
function BA:Highlight(want)
	for _, b in ipairs(cntButtons) do
		local r = b.spell and want[b.spell]
		b.reason = r
		if r then b.glow:On() else b.glow:Off() end
	end
	local list = self:List()
	for i, b in ipairs(sitButtons) do
		local s = list[i]
		local hit = false
		if s and next(want) then
			-- situationen glöder om dess FÖRSTA totem är det som behövs (t.ex. "Fear" -> Tremor)
			local first = s.totems and s.totems[1]
			hit = first ~= nil and want[first] ~= nil
		end
		if hit then b.glow:On() else b.glow:Off() end
	end
end

-- Rekommenderad situation (grön glöd), index eller nil
function BA:Recommend(index, reason)
	for i, b in ipairs(sitButtons) do
		if i == index then b.reason = reason; b.rec:On() else b.reason = nil; b.rec:Off() end
	end
end

-- Index för situationen i nuvarande läge vars första totem är `totem`
function BA:SituationFor(totem)
	for i, s in ipairs(self:List()) do
		if s.totems and s.totems[1] == totem and not s.hidden then return i, s end
	end
end

function BA:FindByName(name)
	for i, s in ipairs(self:List()) do
		if s.name == name then return i, s end
	end
end

---------------------------------------------------------------------------------------------------
-- Läge (PvE/PvP)
---------------------------------------------------------------------------------------------------
function BA:SetMode(mode, quiet)
	mode = mode == "PVP" and "PVP" or "PVE"
	local changed = ns.char.mode ~= mode
	ns.char.mode = mode
	self:ApplySituations()
	if changed and not quiet then
		ns.print("mode: %s%s", mode == "PVP" and "|cffff6060PvP|r" or "|cff60ff60PvE|r",
			InCombatLockdown() and " (switches after combat)" or "")
	end
	ns.fire("MODE_CHANGED", mode)
end

local function autoMode()
	if not ns.char.autoMode then return end
	local inside, kind = IsInInstance()
	if ns.isSecret(inside) or ns.isSecret(kind) then return end
	if kind == "pvp" or kind == "arena" then BA:SetMode("PVP")
	elseif kind == "party" or kind == "raid" then BA:SetMode("PVE") end
end

function BA:Refresh()
	self:ApplySituations()
	self:ApplyCounter()
end

function BA:SetShown(which, show)
	ns.char.bars[which].show = show
	self:Refresh()
end

function BA:OnShamanLogin()
	self:BuildSituationBar()
	self:BuildCounterBar()
	self:Refresh()
	ns.listen("SPELLS_CHANGED", function() wipe(knownCache); BA:Refresh() end)
	-- Nya spells: cachen över kända totems töms (SPELLS_CHANGED kommer också, men först efter skanningen)
	ns.on("LEARNED_SPELL_IN_TAB", function() wipe(knownCache) end)
	ns.on("LEARNED_SPELL_IN_SKILL_LINE", function() wipe(knownCache) end)
	ns.listen("TOTEMS_CHANGED", function() wipe(knownCache) end)
	ns.on("SPELL_UPDATE_COOLDOWN", function() BA:UpdateCooldowns() end)
	ns.listen("BINDINGS_CHANGED", function() BA:UpdateKeys() end)
	ns.on("UPDATE_BINDINGS", function() BA:UpdateKeys() end)
	ns.on("PLAYER_ENTERING_WORLD", autoMode)
	ns.on("ZONE_CHANGED_NEW_AREA", autoMode)
	pcall(powerFrame.RegisterUnitEvent, powerFrame, "UNIT_POWER_FREQUENT", "player")
	ns.on("SPELL_UPDATE_USABLE", function() BA:QueueMana() end)
	ns.listen("PLAYER_CAST", function(name) BA:OnCast(name) end)
	ns.listen("TOTEMS_CHANGED", function() BA:QueueMana() end)
	ns.listen("COMBAT_END", function() BA:ResetSequences(); BA:UpdateMana() end)
	ns.listen("BARS_LAYOUT", function()
		ns.afterCombat("bars-layout", function()
			ns.placeFrame(sitBar, ns.char.bars.situations)
			ns.placeFrame(cntBar, ns.char.bars.counter)
			BA:Refresh()
		end)
	end)
end

_G.BINDING_HEADER_FARSEER = "Farseer"
