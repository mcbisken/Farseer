-- v1.8: funktioner från andra shaman-addons (Call med valfritt set i strid, återuppliva-knapp,
-- totemtidernas färger, fiskespö, Water Shield i grupp, uppläsning, nedtoning utanför strid)

local ns = FARSEER_NS
local test, check = TEST, CHECK

test("v18: Call med valfritt set i strid via dolda multispell-knappar", function()
	MOCK.combat = false
	ns.Bars:SetMode("PVE", true)
	MOCK.runTimers()
	local b = _G.FarseerSit2
	local s = ns.Bars:Situation(2)
	local m = b:GetAttribute("*macrotext2") or ""
	check(b:GetAttribute("*type2") == "macro", "högerklick = makro")
	check(#m <= 255, "makrot <= 255 tecken (" .. #m .. ")")
	local clicks = 0
	for _ in m:gmatch("/click FarseerMS2_%d") do clicks = clicks + 1 end
	check(clicks == 4, "fyra /click (ett per element): " .. clicks)
	check(m:find("/cast Call of the Elements$"), "castar Call sist")
	-- De dolda knapparna skriver setets totems i rätt Call-slot
	local base = (12 - 1) * 12
	local want = {}
	for _, name in ipairs(ns.Bars:KnownTotems(s)) do
		local slot = MOCK.TOTEM_SLOT[name]
		want[slot] = MOCK.known[name]
	end
	for slot = 1, 4 do
		local hb = _G["FarseerMS2_" .. slot]
		check(hb and hb:GetAttribute("type") == "multispell", "knapp " .. slot .. ": multispell")
		check(hb:GetAttribute("action") == ns.Totems:MultiCastAction(1, slot), "knapp " .. slot .. ": rätt action")
		check(hb:GetAttribute("spell") == (want[slot] or 0), "knapp " .. slot .. ": rätt totem")
	end
	-- ActionButtonUseKeyDown på: /click måste skicka "nedtryckt"
	local oldCVar = C_CVar
	rawset(_G, "C_CVar", { GetCVarBool = function(n) return n == "ActionButtonUseKeyDown" end })
	ns.Bars:ApplySituations()
	check((b:GetAttribute("*macrotext2") or ""):find("/click FarseerMS2_1 LeftButton 1", 1, true), "key down: LeftButton 1")
	rawset(_G, "C_CVar", oldCVar)
	ns.Bars:ApplySituations()

	-- Högerklick i strid: markeras som laddat, kontrolleras efter striden
	MOCK.combat = true
	b:Click("RightButton")
	check(ns.Bars:LoadedIndex() == 2, "set 2 markerat som laddat i Call")
	-- Klienten körde multispell: slottarna innehåller set 2
	for slot = 1, 4 do
		local hb = _G["FarseerMS2_" .. slot]
		MOCK.multicast[hb:GetAttribute("action")] = hb:GetAttribute("spell") ~= 0 and hb:GetAttribute("spell") or nil
	end
	MOCK.combat = false
	ns.Bars:CheckCombatCall()
	check(ns.Bars.combatCallState == "works", "efter striden: fungerar (" .. ns.Bars.combatCallState .. ")")
	ns.Bars.combatCallState = "unverified"
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)

test("v18: totemtidernas färger", function()
	local TO = ns.Totems
	local b = _G.FarseerTotemFIRE
	local slot = ns.SLOT.FIRE
	local last
	local orig = b.time.SetTextColor
	b.time.SetTextColor = function(self, r, g, bl) last = { r, g, bl } end
	local function at(left)
		MOCK.totems[slot] = { name = "Searing Totem", start = MOCK.time - (60 - left), dur = 60 }
		TO:ReadSlot(slot)
		TO:UpdateTimes()
		return last
	end
	local c = at(50)
	check(c[1] == 1 and c[2] == 1 and c[3] == 1, "50 s: vit")
	c = at(20)
	check(c[1] == 1 and c[2] > 0.8 and c[3] < 0.3, "20 s: gul")
	c = at(8)
	check(c[1] == 1 and c[2] < 0.3, "8 s: röd")
	-- Sista 5 s blinkar: två olika färger beroende på tiden
	local seen = {}
	for i = 0, 3 do
		MOCK.time = MOCK.time + 0.25
		c = at(4)
		seen[c[2]] = true
	end
	local n = 0
	for _ in pairs(seen) do n = n + 1 end
	check(n == 2, "4 s: blinkar")
	MOCK.totems[slot] = nil
	TO:ReadSlot(slot)
	TO:UpdateTimes()
	b.time.SetTextColor = orig
end)

test("v18: fiskespö ger ingen imbue-påminnelse", function()
	local RE = ns.Reminders
	local oldItem = C_Item
	local fake = setmetatable({ GetItemInfoInstant = function(id)
		if id == 6256 then return 6256, "Weapon", "Fishing Poles", "INVTYPE_2HWEAPON", 0, 2, 20 end
		return id, "Weapon", "Axes", "INVTYPE_WEAPON", 0, 2, 0
	end }, { __index = oldItem })
	rawset(_G, "C_Item", fake)
	check(RE:FishingPole(6256) == true, "fiskespö känns igen")
	check(RE:FishingPole(1234) == false, "yxa är inget fiskespö")
	rawset(_G, "C_Item", oldItem)
end)

test("v18: Water Shield i grupp, Lightning Shield solo", function()
	local RE = ns.Reminders
	MOCK.learn("Lightning Shield")
	MOCK.learn("Water Shield")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	local rem = ns.char.reminders
	local oldPrefer, oldGroup = rem.preferWaterShield, rem.waterInGroup
	rem.preferWaterShield = false
	rem.waterInGroup = true
	local oldIn = rawget(_G, "IsInGroup")
	rawset(_G, "IsInGroup", function() return false end)
	check(RE:ShieldSpell() == "Lightning Shield", "solo: Lightning Shield")
	rawset(_G, "IsInGroup", function() return true end)
	check(RE:ShieldSpell() == "Water Shield", "grupp: Water Shield")
	rem.waterInGroup = false
	check(RE:ShieldSpell() == "Lightning Shield", "av: Lightning Shield i grupp också")
	rawset(_G, "IsInGroup", oldIn)
	rem.preferWaterShield, rem.waterInGroup = oldPrefer, oldGroup
	MOCK.unlearn("Water Shield")
	MOCK.unlearn("Lightning Shield")
	ns.Spellbook:Scan()
	MOCK.runTimers()
end)

test("v18: läs upp varningar", function()
	local AL = ns.Alert
	local spoken = {}
	local old = rawget(_G, "TextToSpeech_Speak")
	rawset(_G, "TextToSpeech_Speak", function(text) table.insert(spoken, text) end)
	ns.db.alert.mode = "always"
	ns.db.alert.speak = "critical"
	AL:Hide(true); MOCK.runTimers(); AL:Hide(true)
	AL:Flash("s1", "Searing Totem", "INFO", "", nil, 3)
	check(#spoken == 0, "info läses inte upp")
	AL:Hide(true); MOCK.runTimers(); AL:Hide(true)
	AL:Show("s2", "Tremor Totem", "|cffff0000TREMOR!|r", "", nil, false, "critical")
	check(spoken[1] == "TREMOR!", "kritisk läses upp utan färgkoder: " .. tostring(spoken[1]))
	AL:Hide(true); MOCK.runTimers(); AL:Hide(true)
	ns.db.alert.speak = "advice"
	AL:Show("s3", "Mana Spring Totem", "MANA", "")
	check(spoken[2] == "MANA", "råd läses upp i läget advice")
	ns.db.alert.speak = "off"
	AL:Hide(true); MOCK.runTimers(); AL:Hide(true)
	AL:Show("s4", "Tremor Totem", "FEAR", "", nil, false, "critical")
	check(#spoken == 2, "av: inget")
	AL:Hide(true); MOCK.runTimers(); AL:Hide(true)
	rawset(_G, "TextToSpeech_Speak", old)
end)

test("v18: tona ned totembarerna utanför strid", function()
	local BA = ns.Bars
	local frames = BA:FadeFrames()
	check(#frames >= 2, "barerna registrerade (" .. #frames .. ")")
	local sit = _G.FarseerSituationBar
	local alpha
	local orig = sit.SetAlpha
	sit.SetAlpha = function(self, a) alpha = a end
	-- Andra tester har "hovrat" knappar utan att lämna dem: striden börjar = ingen mus över
	ns.fire("COMBAT_START")
	ns.char.fade.enabled = true
	ns.char.fade.alpha = 0.4
	MOCK.combat = false
	BA:ApplyFade()
	check(alpha == 0.4, "utanför strid: 0.4 (" .. tostring(alpha) .. ")")
	MOCK.combat = true
	BA:ApplyFade()
	check(alpha == 1, "i strid: full")
	MOCK.combat = false
	-- Musen över en knapp: full
	local btn = _G.FarseerSit1
	if btn.__scripts and btn.__scripts.OnEnter then
		btn.__scripts.OnEnter(btn)
		check(alpha == 1, "musen över: full")
		btn.__scripts.OnLeave(btn)
		check(alpha == 0.4, "musen bort: nedtonad")
	end
	ns.char.fade.enabled = false
	BA:ApplyFade()
	check(alpha == 1, "av: full")
	sit.SetAlpha = orig
end)

test("v18: återuppliva-knappen", function()
	local RZ = ns.Rez
	MOCK.learn("Ancestral Spirit")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	MOCK.combat = false
	local dead = false
	rawset(_G, "UnitIsDead", function(u) return u == "party1" and dead end)
	rawset(_G, "UnitIsGhost", function() return false end)
	rawset(_G, "UnitIsConnected", function() return true end)
	rawset(_G, "UnitHasIncomingResurrection", function() return false end)
	MOCK.units.party1 = { name = "Jaina", class = "MAGE", player = true }
	local b = _G.FarseerRezButton
	RZ:Update()
	check(not b:IsShown(), "ingen död: dold")
	dead = true
	MOCK.units.party1.dead = true
	RZ:Update()
	check(b:IsShown(), "död i gruppen: knappen syns")
	check(b:GetAttribute("type") == "spell" and b:GetAttribute("spell") == "Ancestral Spirit", "castar Ancestral Spirit")
	check(b:GetAttribute("unit") == "party1", "på den döda")
	check(b.name:GetText() == "Jaina", "namnet visas")
	-- I strid: väntar
	MOCK.combat = true
	dead = false
	MOCK.units.party1.dead = false
	RZ:Update()
	check(b:IsShown(), "i strid: ändras inte")
	MOCK.combat = false
	ns.fire("COMBAT_END")
	RZ:Update()
	check(not b:IsShown(), "levande igen: dold")
	-- Spöke (släppt anden): kan inte återupplivas här
	dead = true
	rawset(_G, "UnitIsGhost", function() return true end)
	RZ:Update()
	check(not b:IsShown(), "spöke: dold")
	MOCK.units.party1 = nil
	for _, k in ipairs({ "UnitIsDead", "UnitIsGhost", "UnitIsConnected", "UnitHasIncomingResurrection" }) do rawset(_G, k, nil) end
	MOCK.unlearn("Ancestral Spirit")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	RZ:Update()
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)
