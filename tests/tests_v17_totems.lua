-- Tester för v1.7 (rådgivare/totems/bars): fear-varning critical, fear-mobs bara i strid, buff från
-- någon annan, resist-regler bara i strid, soloQuiet, Totemic Call-glöd, cache av kända totems och
-- castsequence-spårning med AnyUp+AnyDown.

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function cast(name) MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known[name]) end

local function clearTotems()
	cast("Totemic Recall")
	for s = 1, 4 do MOCK.totems[s] = nil end
	MOCK.fire("PLAYER_TOTEM_UPDATE")
	MOCK.runTimers()
end

local function resetAlert()
	MOCK.runTimers()
	ns.Alert:Hide(true)
end

-- Byt en global tillfälligt; returnerar en funktion som återställer den
local function swapGlobal(name, value)
	local old = rawget(_G, name)
	rawset(_G, name, value)
	return function() rawset(_G, name, old) end
end

-- Spionera på ns.Alert:Show / :Flash
local function spyAlert()
	local calls = { show = {}, flash = {} }
	local origShow, origFlash = ns.Alert.Show, ns.Alert.Flash
	ns.Alert.Show = function(self, key, spell, title, text, color, force, prio)
		if not force then table.insert(calls.show, { key = key, prio = prio }) end
		return origShow(self, key, spell, title, text, color, force, prio)
	end
	ns.Alert.Flash = function(self, key, ...)
		table.insert(calls.flash, { key = key })
		return origFlash(self, key, ...)
	end
	calls.restore = function() ns.Alert.Show, ns.Alert.Flash = origShow, origFlash end
	return calls
end

local function solo()
	MOCK.instanceType, MOCK.group = "none", 0
	ns.char.advisor.soloQuiet = true
end

---------------------------------------------------------------------------------------------------
test("v17 rådgivare: fear på dig = critical, annat = advice", function()
	resetAlert()
	local spy = spyAlert()
	MOCK.loc = { { locType = "FEAR", displayText = "Feared" } }
	ns.Advisor:Evaluate()
	local last = spy.show[#spy.show]
	check(last and last.key == "Tremor Totem" and last.prio == "critical", "fear: critical: " .. tostring(last and last.prio))
	MOCK.loc = {}
	MOCK.time = MOCK.time + 10
	MOCK.units.target = { name = "Gul'dan", class = "WARLOCK", hostile = true, player = true }
	ns.Advisor:Evaluate()
	last = spy.show[#spy.show]
	check(last and last.key == "Tremor Totem" and last.prio == "advice", "warlock: advice: " .. tostring(last and last.prio))
	MOCK.units.target = nil
	spy.restore()
	ns.Advisor:Evaluate()
	resetAlert()
end)

---------------------------------------------------------------------------------------------------
test("v17 rådgivare: fear-mobs bara när de är i strid med dig", function()
	resetAlert()
	local inCombat = {}
	local restore = swapGlobal("UnitAffectingCombat", function(u) return inCombat[u] end)
	local function tremor() return ns.Advisor:Evaluate()["Tremor Totem"] ~= nil end
	-- Nameplate i närheten
	MOCK.units.nameplate1 = { name = "Magmadar", hostile = true }
	MOCK.fire("NAME_PLATE_UNIT_ADDED", "nameplate1")
	check(not tremor(), "nameplate utan strid: ingen Tremor")
	check(ns.Alert:Current() ~= "Tremor Totem", "ingen TREMOR-ruta")
	inCombat.nameplate1 = true
	check(tremor(), "nameplate i strid: Tremor")
	inCombat.nameplate1 = SECRET
	check(not tremor(), "secret strid: inte i strid")
	inCombat.nameplate1 = nil
	MOCK.units.nameplate1.target = "player"
	check(tremor(), "moben har dig som target: Tremor")
	MOCK.fire("NAME_PLATE_UNIT_REMOVED", "nameplate1")
	MOCK.units.nameplate1 = nil
	-- Target: bara att ha den som target räcker inte
	MOCK.units.target = { name = "Magmadar", hostile = true }
	check(not tremor(), "target utan strid: ingen Tremor")
	inCombat.target = true
	check(tremor(), "target i strid: Tremor")
	MOCK.units.target = nil
	MOCK.units.focus = { name = "Magmadar", hostile = true }
	inCombat.focus = true
	check(tremor(), "focus i strid: Tremor")
	MOCK.units.focus = nil
	restore()
	ns.Advisor:Evaluate()
	resetAlert()
end)

---------------------------------------------------------------------------------------------------
test("v17 rådgivare: buffen från någon annan, resist bara i strid", function()
	resetAlert()
	local pc = false
	local restore = swapGlobal("UnitAffectingCombat", function(u) if u == "player" then return pc end end)
	local spy = spyAlert()
	local want
	local origHL = ns.Bars.Highlight
	ns.Bars.Highlight = function(self, w) want = w; return origHL(self, w) end
	MOCK.instanceName = "Molten Core"
	MOCK.auras.player = {}
	-- I strid: rutan visas
	pc = true
	local recs = ns.Advisor:Evaluate()
	check(recs["Fire Resistance Totem"] ~= nil, "Molten Core i strid: Fire Resistance")
	check(ns.Alert:Current() == "Fire Resistance Totem", "ruta i strid: " .. tostring(ns.Alert:Current()))
	-- En annan shamans Fire Resistance på dig: inget förslag
	MOCK.auras.player = { { name = "Fire Resistance", spellId = 8185 } }
	recs = ns.Advisor:Evaluate()
	check(recs["Fire Resistance Totem"] == nil, "buffen finns redan: inget förslag")
	check(ns.Alert:Current() ~= "Fire Resistance Totem", "ingen ruta när buffen finns")
	check(want and want["Fire Resistance Totem"] == nil, "ingen glöd när buffen finns")
	MOCK.auras.player = {}
	-- Utanför strid: bara glöd
	pc = false
	local before = #spy.show
	recs = ns.Advisor:Evaluate()
	check(recs["Fire Resistance Totem"] ~= nil, "utanför strid: fortfarande förslag")
	check(want and want["Fire Resistance Totem"] ~= nil, "utanför strid: glöd")
	check(ns.Alert:Current() ~= "Fire Resistance Totem", "utanför strid: ingen ruta: " .. tostring(ns.Alert:Current()))
	check(#spy.show == before, "ingen Show utanför strid")
	-- InCombatLockdown räcker också
	MOCK.combat = true
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "Fire Resistance Totem", "InCombatLockdown: ruta")
	MOCK.combat = false
	-- Bossregel (target) utanför strid: bara glöd
	MOCK.instanceName = nil
	MOCK.units.target = { name = "Ragnaros", hostile = true }
	recs = ns.Advisor:Evaluate()
	check(recs["Fire Resistance Totem"] ~= nil and ns.Alert:Current() ~= "Fire Resistance Totem", "bossregel utanför strid: tyst")
	pc = true
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "Fire Resistance Totem", "bossregel i strid: ruta")
	MOCK.units.target = nil
	ns.Bars.Highlight = origHL
	spy.restore()
	restore()
	MOCK.auras.player = {}
	ns.Advisor:Evaluate()
	resetAlert()
end)

---------------------------------------------------------------------------------------------------
test("v17 rådgivare: DROP TOTEMS tyst solo (soloQuiet)", function()
	resetAlert()
	clearTotems()
	solo()
	MOCK.combat = true
	MOCK.fire("PLAYER_REGEN_DISABLED")
	MOCK.time = MOCK.time + 10
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() ~= "nototems", "solo: ingen påminnelse: " .. tostring(ns.Alert:Current()))
	MOCK.group = 2
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "nototems", "i grupp: påminnelse: " .. tostring(ns.Alert:Current()))
	MOCK.group = 0
	MOCK.instanceType = "party"
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "nototems", "i instans: påminnelse")
	MOCK.instanceType = "none"
	ns.char.advisor.soloQuiet = false
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "nototems", "soloQuiet av: påminnelse även solo")
	ns.char.advisor.soloQuiet = true
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	ns.Advisor:Evaluate()
	resetAlert()
end)

---------------------------------------------------------------------------------------------------
test("v17 totems: räckvidd/utgång tyst solo, OOR-totem varnas inte för utgång", function()
	resetAlert()
	clearTotems()
	solo()
	local ta = ns.char.totemAlerts
	ta.range, ta.rangeAlert, ta.expire, ta.expireSec, ta.expireLongOnly = true, true, true, 20, true
	local cb = _G.FarseerTotemicCall
	local spy = spyAlert()
	local t0 = MOCK.time
	MOCK.auras.player = { { name = "Strength of Earth", spellId = 8076 } }
	MOCK.totems[2] = { name = "Strength of Earth Totem", start = t0, dur = 300 }
	cast("Strength of Earth Totem")
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	MOCK.runTimers()
	MOCK.time = t0 + 4
	ns.Totems:CheckRange()
	MOCK.auras.player = {}
	ns.Totems:CheckRange()
	ns.Totems:CheckRange()
	check(ns.Totems:OutOfRange(2), "utom räckhåll")
	check(_G.FarseerTotemEARTH.rangeText:GetText() == "OOR" and cb.glow:IsShown(), "OOR och Call-glöd finns kvar solo")
	check(#spy.flash == 0 and ns.Alert:Current() ~= "range-2", "solo: ingen räckviddsvarning")
	-- Utgång: OOR-totemet hoppas över, Mana Spring varnas (men tyst solo)
	MOCK.totems[3] = { name = "Mana Spring Totem", start = t0 + 1, dur = 300 }
	MOCK.fire("PLAYER_TOTEM_UPDATE", 3)
	MOCK.runTimers()
	MOCK.time = t0 + 281
	local list = ns.Totems:CheckExpiry()
	check(list and #list == 1 and list[1].name == "Mana Spring Totem", "bara Mana Spring (SoE är OOR): " .. tostring(list and #list))
	check(#spy.flash == 0, "solo: ingen utgångsvarning")
	-- I grupp: varningarna kommer
	clearTotems()
	MOCK.group = 2
	t0 = MOCK.time
	MOCK.auras.player = { { name = "Strength of Earth", spellId = 8076 } }
	MOCK.totems[2] = { name = "Strength of Earth Totem", start = t0, dur = 300 }
	cast("Strength of Earth Totem")
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	MOCK.runTimers()
	MOCK.time = t0 + 4
	ns.Totems:CheckRange()
	MOCK.auras.player = {}
	ns.Totems:CheckRange()
	ns.Totems:CheckRange()
	check(ns.Alert:Current() == "range-2", "grupp: räckviddsvarning: " .. tostring(ns.Alert:Current()))
	MOCK.runTimers()
	MOCK.auras.player = { { name = "Strength of Earth", spellId = 8076 } }
	ns.Totems:CheckRange()
	check(not ns.Totems:OutOfRange(2), "tillbaka inom räckhåll")
	MOCK.time = t0 + 281
	list = ns.Totems:CheckExpiry()
	check(list and #list == 1 and ns.Alert:Current() == "expire", "grupp: utgångsvarning")
	MOCK.runTimers()
	spy.restore()
	MOCK.group = 0
	MOCK.auras.player = {}
	clearTotems()
	ns.Totems:CheckRange()
	resetAlert()
end)

---------------------------------------------------------------------------------------------------
test("v17 totems: täckning tänder inte Totemic Call", function()
	local ta = ns.char.totemAlerts
	ta.party = true
	clearTotems()
	local cb = _G.FarseerTotemicCall
	local cover = _G.FarseerTotemBar.cover
	MOCK.units.party1 = { name = "Bob", player = true }
	local restore = swapGlobal("UnitInRange", function() return true, true end)
	MOCK.auras.player = { { name = "Strength of Earth", spellId = 8076 } }
	MOCK.auras.party1 = {}
	MOCK.totems[2] = { name = "Strength of Earth Totem", start = MOCK.time, dur = 300 }
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	MOCK.runTimers()
	MOCK.time = MOCK.time + 4
	ns.Totems:CheckRange()
	ns.Totems:UpdateCoverage()
	check(cover:IsShown() and cover.text:GetText() == "1 missing buff", "etiketten finns kvar")
	check(not cb.glow:IsShown(), "ingen Call-glöd av täckningen")
	-- Tooltipen nämner inte gruppen längre
	local lines = {}
	rawset(GameTooltip, "AddLine", function(_, t) table.insert(lines, t) end)
	cb:GetScript("OnEnter")(cb)
	rawset(GameTooltip, "AddLine", nil)
	check(lines[1] and lines[1]:find("isn't reaching you", 1, true) and not lines[1]:find("party", 1, true),
		"Call-tooltip: " .. tostring(lines[1]))
	MOCK.units.party1, MOCK.auras.party1 = nil, nil
	MOCK.auras.player = {}
	restore()
	clearTotems()
	ns.Totems:UpdateCoverage()
end)

---------------------------------------------------------------------------------------------------
test("v17 bars: kända totems cachas", function()
	ns.Bars:SetMode("PVE", true)
	ns.Bars:ApplySituations()
	ns.Bars:ResetSequences()
	local SB = ns.Spellbook
	local origKnows, origEl = SB.Knows, SB.TotemElement
	local n, block = 0, {}
	SB.Knows = function(self, name)
		if block[name] then return false end
		return origKnows(self, name)
	end
	-- TotemElement anropas bara när listan räknas om (CanAfford använder den inte)
	SB.TotemElement = function(self, name)
		n = n + 1
		return origEl(self, name)
	end
	ns.Bars:UpdateMana()
	n = 0
	ns.Bars:UpdateMana()
	ns.Bars:UpdateMana()
	check(n == 0, "UpdateMana igen: ingen omräkning: " .. n)
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "Windfury först")
	-- Ändras setet på plats: cachen märker det
	local s = ns.Bars:Situation(1)
	local orig1 = s.totems[1]
	s.totems[1] = "Grace of Air Totem"
	check(ns.Bars:NextTotem(1) == "Grace of Air Totem", "ändrat set syns: " .. tostring(ns.Bars:NextTotem(1)))
	s.totems[1] = orig1
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "tillbaka")
	-- Spellbook ändras: cachad lista tills SPELLS_CHANGED
	block["Windfury Totem"] = true
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "cachad tills SPELLS_CHANGED")
	ns.fire("SPELLS_CHANGED")
	check(ns.Bars:NextTotem(1) == "Strength of Earth Totem", "efter SPELLS_CHANGED: " .. tostring(ns.Bars:NextTotem(1)))
	block["Windfury Totem"] = nil
	-- TOTEMS_CHANGED och ApplySituations tömmer också
	ns.Bars:UpdateMana()
	n = 0
	ns.fire("TOTEMS_CHANGED")
	ns.Bars:UpdateMana()
	check(n > 0 and ns.Bars:NextTotem(1) == "Windfury Totem", "TOTEMS_CHANGED tömmer")
	n = 0
	ns.Bars:ApplySituations()
	local after = n
	n = 0
	ns.Bars:UpdateMana()
	check(after > 0 and n == 0, "ApplySituations räknar om, sedan cachat")
	-- Publika KnownTotems är en kopia
	local k = ns.Bars:KnownTotems(s)
	k[1] = "x"
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "kopian påverkar inte cachen")
	SB.Knows, SB.TotemElement = origKnows, origEl
	ns.fire("SPELLS_CHANGED")
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v17 bars: castsequence räknar ett tryck en gång", function()
	ns.Bars:SetMode("PVE", true)
	ns.Bars:ApplySituations()
	ns.Bars:ResetSequences()
	local sit = _G.FarseerSit1
	local W, S = "Windfury Totem", "Strength of Earth Totem"
	local function step() MOCK.time = MOCK.time + 1 end
	-- CVar okänd: nedtrycket räknas, släppet (efter castens SUCCEEDED) öppnar inget nytt fönster
	step()
	sit:Click("LeftButton", true)
	cast(W)
	sit:Click("LeftButton", false)
	check(ns.Bars:NextTotem(1) == S, "framflyttad till SoE")
	cast(S)   -- från en annan knapp
	check(ns.Bars:NextTotem(1) == S, "släppet armade inte om: " .. tostring(ns.Bars:NextTotem(1)))
	-- CVar = cast på nedtryck
	ns.Bars:ResetSequences()
	local cvar = true
	local restore = swapGlobal("GetCVarBool", function(name) if name == "ActionButtonUseKeyDown" then return cvar end end)
	step()
	sit:Click("LeftButton", true)
	cast(W)
	step()
	sit:Click("LeftButton", false)
	cast(S)
	check(ns.Bars:NextTotem(1) == S, "keydown: släppet räknas inte ens efter 1 s")
	-- CVar = cast på släpp
	ns.Bars:ResetSequences()
	cvar = false
	step()
	sit:Click("LeftButton", true)
	cast(W)
	check(ns.Bars:NextTotem(1) == W, "keyup: nedtrycket räknas inte")
	sit:Click("LeftButton", false)
	cast(W)
	check(ns.Bars:NextTotem(1) == S, "keyup: släppet räknas")
	-- CVar secret: tillbaka till parningen
	ns.Bars:ResetSequences()
	cvar = SECRET
	step()
	sit:Click("LeftButton", true)
	cast(W)
	sit:Click("LeftButton", false)
	cast(S)
	check(ns.Bars:NextTotem(1) == S, "secret CVar: släppet hoppas över")
	restore()
	-- Utan riktning (/click): ett tryck < 0,3 s efter att sekvensen gått fram armar inte
	ns.Bars:ResetSequences()
	step()
	sit:Click("LeftButton")
	cast(W)
	MOCK.time = MOCK.time + 0.1
	sit:Click("LeftButton")
	cast(S)
	check(ns.Bars:NextTotem(1) == S, "dubbeltryck direkt efter cast räknas inte")
	MOCK.time = MOCK.time + 0.5
	sit:Click("LeftButton")
	cast(S)
	check(ns.Bars:NextTotem(1) == "Mana Spring Totem", "nästa riktiga tryck räknas: " .. tostring(ns.Bars:NextTotem(1)))
	ns.Bars:ResetSequences()
	clearTotems()
end)
