-- Farseer-tester mot wowmock.lua. Körs av run_tests.py.

local results = { pass = 0, fail = 0, lines = {} }
local function out(s) table.insert(results.lines, s) end
local current
local function check(cond, msg)
	if cond then results.pass = results.pass + 1 return true end
	results.fail = results.fail + 1
	out("  FAIL [" .. tostring(current) .. "] " .. tostring(msg))
	return false
end
local function test(name, fn)
	current = name
	local before = #MOCK.errors
	local ok, err = pcall(fn)
	if not ok then
		results.fail = results.fail + 1
		out("  ERROR [" .. name .. "] " .. tostring(err))
	end
	for i = before + 1, #MOCK.errors do
		results.fail = results.fail + 1
		out("  ADDON-FEL [" .. name .. "] " .. MOCK.errors[i])
	end
	MOCK.errors = {}
	MOCK.combat = false
	out((ok and "ok   " or "FEL  ") .. name)
end

local ns = FARSEER_NS
local SHAMAN_SPELLS = {
	"Lightning Bolt", "Chain Lightning", "Earth Shock", "Flame Shock", "Frost Shock", "Purge", "Lightning Shield",
	"Water Shield", "Healing Wave", "Lesser Healing Wave", "Chain Heal", "Riptide", "Nature's Swiftness",
	"Lightning Mastery", "Stormstrike", "Rage of the Farseer", "Ghost Wolf", "Fire Nova", "Call of the Elements",
	"Call of the Ancestors", "Call of the Spirits", "Totemic Recall", "Totemic Call", "Rockbiter Weapon",
	"Flametongue Weapon", "Frostbrand Weapon", "Windfury Weapon", "Cure Poison", "Cure Disease", "Ancestral Spirit",
	"Water Walking", "Water Breathing", "Astral Recall", "Far Sight", "Reincarnation", "Mana Tide Totem",
}

local function learnAll()
	for _, s in ipairs(SHAMAN_SPELLS) do if not MOCK.known[s] then MOCK.learn(s) end end
	for name in pairs(MOCK.TOTEM_SLOT) do if not MOCK.known[name] then MOCK.learn(name) end end
	ns.Spellbook:Scan()
	MOCK.runTimers()
end

---------------------------------------------------------------------------------------------------
test("laddning och inloggning", function()
	check(ns.isShaman == true, "spelaren är shaman")
	check(_G.FarseerSit1 ~= nil, "situationsknapp 1 finns")
	check(_G.FarseerTotemEARTH ~= nil, "totemknapp finns")
	check(SlashCmdList.FARSEER ~= nil, "slashkommando registrerat")
	check(ns.char.situations.PVE[1] ~= nil and ns.char.situations.PVP[1] ~= nil, "situationer kopierade")
end)

test("level 1: inga spells -> inga fel", function()
	MOCK.tick(4)
	ns.Bars:ApplySituations()
	check(_G.FarseerSit1:GetAttribute("type") == nil, "inga kända totems -> ingen action")
end)

test("spellbok och totemelement", function()
	learnAll()
	check(ns.Spellbook:Knows("Lightning Bolt"), "känner Lightning Bolt")
	check(not ns.Spellbook:Knows("Lava Burst"), "inte Lava Burst")
	check(ns.Spellbook:TotemElement("Fire Resistance Totem") == "WATER", "Fire Resistance = vatten (från klienten)")
	check(ns.Spellbook:TotemElement("Nature Resistance Totem") == "AIR", "Nature Resistance = luft")
	check(ns.Spellbook:CallCount() == 3, "tre Call-spells")
	local earth = ns.Spellbook:KnownTotems("EARTH")
	check(#earth == 5, "5 jordtotems, fick " .. #earth)
end)

---------------------------------------------------------------------------------------------------
local function allTemplatesValid(label)
	local names = {}
	for _, t in ipairs(ns.MACRO_TEMPLATES) do
		local body, missing = ns.MacroEngine:Render(t)
		check(type(body) == "string" and #body > 0, label .. ": " .. t.id .. " har kropp")
		check(#body <= 255, label .. ": " .. t.id .. " är " .. #body .. " tecken")
		check(#t.name <= 16, t.id .. " namn > 16: " .. t.name)
		check(not body:find("{%w+}"), label .. ": " .. t.id .. " har orenderad token: " .. body)
		check(not body:find("%-%- fel i mall"), label .. ": " .. t.id .. " mallfel: " .. body)
		check(not body:find("%[%]%[%]"), label .. ": " .. t.id .. " dubbla tomma villkor")
		check(not body:find("/cast%s*$") and not body:find("/cast%s*\n"), label .. ": " .. t.id .. " tom /cast")
		check(not names[t.name], "dubblettnamn " .. t.name)
		names[t.name] = true
		if t.cat ~= "Verktyg" or t.id ~= "pvp_focus" then
			for _, s in ipairs(missing) do
				if not s:find("Hearthstone") then check(false, label .. ": " .. t.id .. " saknar " .. s) end
			end
		end
	end
end

test("makromallar: standardinställningar", function() allTemplatesValid("std") end)

test("makromallar: allt av / allt på", function()
	local o = ns.db.macros
	o.mouseover, o.focus, o.selfcast, o.downrankKick = false, false, false, false
	allTemplatesValid("av")
	o.mouseover, o.focus, o.selfcast, o.downrankKick = true, true, true, true
	ns.char.reminders.preferWaterShield = true
	allTemplatesValid("på")
	o.downrankKick = false
	ns.char.reminders.preferWaterShield = false
end)

test("makrorendering: innehåll", function()
	local body = ns.MacroEngine:Render(ns.MacroEngine:Template("ele_bolt"))
	check(body == "#showtooltip Lightning Bolt\n/cast [@mouseover,harm,nodead][] Lightning Bolt", "FS Bolt: " .. body)
	body = ns.MacroEngine:Render(ns.MacroEngine:Template("res_hw"))
	check(body:find("%[@mouseover,help,nodead%]%[help,nodead%]%[@player%] Healing Wave"), "FS HW: " .. body)
	body = ns.MacroEngine:Render(ns.MacroEngine:Template("tot_earth"))
	check(body:find("%[mod:shift%] Tremor Totem; %[mod:ctrl%] Earthbind Totem; %[mod:alt%] Stoneclaw Totem; Strength of Earth Totem"),
		"FS Earth: " .. body)
	body = ns.MacroEngine:Render(ns.MacroEngine:Template("util_cure"))
	check(body:find("%[mod:shift,@mouseover,help,nodead%]%[mod:shift,help,nodead%]%[mod:shift,@player%] Cure Disease;"), "FS Cure: " .. body)
	body = ns.MacroEngine:Render(ns.MacroEngine:Template("pvp_kick"))
	check(body:find("%[@focus,harm,nodead%]%[@mouseover,harm,nodead%]%[%] Earth Shock"), "FS Kick: " .. body)
	-- utan Water Shield blir sköldmakrot en enkel cast
	MOCK.unlearn("Water Shield")
	ns.Spellbook:Scan()
	body = ns.MacroEngine:Render(ns.MacroEngine:Template("util_shield"))
	check(body == "#showtooltip Lightning Shield\n/cast Lightning Shield", "FS Shield utan Water Shield: " .. body)
	MOCK.learn("Water Shield")
	ns.Spellbook:Scan()
	local sp = ns.MacroEngine:SpellsIn("/castsequence [@mouseover] reset=12 Riptide, Chain Heal\n/cast [mod:shift] A(Rank 1); !B")
	check(#sp == 4 and sp[1] == "Riptide" and sp[3] == "A" and sp[4] == "B", "SpellsIn: " .. table.concat(sp, "|"))
end)

test("makron skapas, uppdateras, inga dubbletter", function()
	ns.MacroEngine:CreateCategory("Elemental")
	ns.MacroEngine:CreateCategory("Totems")
	local n = #MOCK.macros
	check(n >= 10, "skapade makron: " .. n)
	ns.MacroEngine:CreateCategory("Elemental")
	check(#MOCK.macros == n, "andra körningen skapar inga dubbletter")
	check(ns.MacroEngine:RefreshExisting() == 0, "inget att uppdatera (trailing whitespace tolereras)")
	ns.db.macros.mouseover = false
	check(ns.MacroEngine:RefreshExisting() > 0, "ändrad inställning uppdaterar makron")
	ns.db.macros.mouseover = true
	ns.MacroEngine:RefreshExisting()
	local ok, msg = ns.MacroEngine:Save("FS Lång", string.rep("x", 300), true)
	check(not ok and msg:find("300"), "för långt makro nekas: " .. tostring(msg))
	ok = ns.MacroEngine:Save("Ett namn som är för långt", "/cast X", true)
	check(not ok, "för långt namn nekas")
	MOCK.combat = true
	ok, msg = ns.MacroEngine:Save("FS X", "/cast X", true)
	check(not ok, "i strid nekas")
	MOCK.combat = false
end)

---------------------------------------------------------------------------------------------------
test("keybind-mallar: applicera och återställ", function()
	MOCK.bindings = { ["1"] = "ACTIONBUTTON1", ["Q"] = "STRAFELEFT", ["T"] = "" }
	for _, p in ipairs(ns.BINDING_PRESETS) do
		local n, errors = ns.BindingEngine:Apply(p.id)
		check(n == #p.binds, p.id .. ": " .. n .. "/" .. #p.binds .. " " .. table.concat(errors, ";"))
		for _, b in ipairs(p.binds) do
			if b.macro then
				local t = ns.MacroEngine:Template(b.macro)
				check(t ~= nil, p.id .. ": okänd mall " .. b.macro)
				if t then
					check(MOCK.bindings[b[1]] == "MACRO " .. t.name, p.id .. ": " .. b[1] .. " = " .. tostring(MOCK.bindings[b[1]]))
					check(ns.MacroEngine:Exists(t.name), p.id .. ": makro " .. t.name .. " skapat")
				end
			elseif b.click then
				check(_G[b.click] ~= nil, p.id .. ": knapp " .. b.click .. " finns")
			end
		end
		-- dubbla tangenter i samma mall?
		local seen = {}
		for _, b in ipairs(p.binds) do
			check(not seen[b[1]], p.id .. ": tangent " .. b[1] .. " två gånger")
			seen[b[1]] = true
		end
	end
	check(MOCK.saved > 0, "SaveBindings anropad")
	ns.BindingEngine:Restore()
	check(MOCK.bindings["1"] == "ACTIONBUTTON1", "1 återställd: " .. tostring(MOCK.bindings["1"]))
	check(MOCK.bindings["Q"] == "STRAFELEFT", "Q återställd")
	check(MOCK.bindings["T"] == nil, "T tom igen")
	check(MOCK.bindings["Z"] == nil, "Z (var obunden) rensad")
	check(not ns.BindingEngine:HasBackup(), "backup tömd")
end)

---------------------------------------------------------------------------------------------------
test("situationsknappar och Call of the Elements", function()
	ns.Bars:SetMode("PVE", true)
	MOCK.runTimers()
	local b = _G.FarseerSit1
	local s = ns.Bars:Situation(1)
	check(b:GetAttribute("type") == "macro", "typ macro")
	local seq = b:GetAttribute("macrotext")
	check(seq and seq:find("^/castsequence reset=combat/10 "), "sekvens: " .. tostring(seq))
	check(seq:find(s.totems[1], 1, true), "första totemet i sekvensen")
	check(#seq <= 255, "sekvens <= 255")
	check(b:GetAttribute("*type2") == "spell" and b:GetAttribute("*spell2") == "Call of the Elements", "högerklick = Call")
	-- högerklick utanför strid skriver in setet
	MOCK.multicast = {}
	b:Click("RightButton", true)
	local base = (12 - 1) * 12
	for _, name in ipairs(s.totems) do
		local slot = MOCK.TOTEM_SLOT[name]
		check(MOCK.multicast[base + slot] == MOCK.known[name], "Call-slot " .. slot .. " = " .. name)
	end
	check(ns.Bars:LoadedIndex() == 1, "set 1 laddat")
	-- alla standardsituationer: max ett per element
	for mode, list in pairs(ns.DEFAULT_SITUATIONS) do
		for _, sit in ipairs(list) do
			local seen = {}
			for _, name in ipairs(sit.totems) do
				local el = ns.Spellbook:TotemElement(name)
				check(el ~= nil, mode .. "/" .. sit.name .. ": okänt totem " .. name)
				check(not seen[el], mode .. "/" .. sit.name .. ": två " .. tostring(el))
				seen[el] = true
			end
			check(#sit.name <= 14, "namn kort nog: " .. sit.name)
		end
	end
	ns.Bars:SetMode("PVP", true)
	check(_G.FarseerSit1:GetAttribute("macrotext"):find(ns.DEFAULT_SITUATIONS.PVP[1].totems[1], 1, true), "PvP-läge byter knappar")
	check(not _G.FarseerSit9:IsShown(), "PvP har 8 situationer: knapp 9 dold")
	ns.Bars:SetMode("PVE", true)
	check(_G.FarseerSit10:IsShown(), "PvE har 10")
end)

test("strid: skyddade ändringar väntar", function()
	MOCK.combat = true
	MOCK.fire("PLAYER_REGEN_DISABLED")
	ns.Bars:SetMode("PVP", true)
	check(_G.FarseerSit1:GetAttribute("macrotext"):find(ns.DEFAULT_SITUATIONS.PVE[1].totems[1], 1, true), "inget ändrat i strid")
	local before = MOCK.multicast[133]
	_G.FarseerSit1:Click("RightButton", true)
	check(MOCK.multicast[133] == before, "Call ändras inte i strid")
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(_G.FarseerSit1:GetAttribute("macrotext"):find(ns.DEFAULT_SITUATIONS.PVP[1].totems[1], 1, true), "ändrat efter striden")
	ns.Bars:SetMode("PVE", true)
end)

test("auto-läge efter zon", function()
	MOCK.instanceType = "pvp"
	MOCK.fire("ZONE_CHANGED_NEW_AREA")
	check(ns.Bars:Mode() == "PVP", "battleground -> PvP")
	MOCK.instanceType = "raid"
	MOCK.fire("ZONE_CHANGED_NEW_AREA")
	check(ns.Bars:Mode() == "PVE", "raid -> PvE")
	MOCK.instanceType = "none"
end)

---------------------------------------------------------------------------------------------------
test("totemspårning via egna casts", function()
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Tremor Totem"])
	check(ns.Totems:Active("Tremor Totem") == 2, "Tremor i jordslot")
	check(ns.Totems:Count() == 1, "ett totem")
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Call of the Elements"])
	check(ns.Totems:Count() == 4, "Call lägger fyra: " .. ns.Totems:Count())
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Totemic Recall"])
	check(ns.Totems:Count() == 0, "Recall tar bort alla")
	-- klientens slot (rank-suffix)
	MOCK.totems[1] = { name = "Searing Totem VI", start = MOCK.time, dur = 55 }
	MOCK.fire("PLAYER_TOTEM_UPDATE", 1)
	check(ns.Totems:Active("Searing Totem") == 1, "Searing via GetTotemInfo, rank borttagen")
	check(ns.char.learnedDur["Searing Totem"] == 55, "duration inlärd")
	MOCK.totems[1] = nil
	MOCK.fire("PLAYER_TOTEM_UPDATE", 1)
	check(ns.Totems:Active("Searing Totem") == nil, "borta när slot töms")
	-- utgång
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Grounding Totem"])
	MOCK.time = MOCK.time + 50
	check(ns.Totems:Active("Grounding Totem") == nil, "Grounding gått ut efter 45 s")
end)

---------------------------------------------------------------------------------------------------
local function advise()
	return ns.Advisor:Evaluate()
end

test("varning: fientlig warlock -> Tremor", function()
	MOCK.units.target = { name = "Gul'dan", class = "WARLOCK", hostile = true, player = true }
	local recs = advise()
	check(recs["Tremor Totem"] ~= nil, "Tremor rekommenderad")
	check(recs["Grounding Totem"] ~= nil, "Grounding rekommenderad")
	check(ns.Alert:Current() == "Tremor Totem", "varning visar Tremor: " .. tostring(ns.Alert:Current()))
	check(_G.FarseerCounter1.glow:IsShown() or _G.FarseerCounter2.glow:IsShown(), "kontraknapp glöder")
	check(MOCK.played > 0, "ljud spelat")
	-- Tremor redan ute -> ingen Tremor-varning
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Tremor Totem"])
	recs = advise()
	check(recs["Tremor Totem"] == nil, "ingen Tremor när den är ute")
	check(ns.Alert:Current() == "Grounding Totem", "nästa: Grounding")
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Totemic Recall"])
	MOCK.units.target = nil
end)

test("varning: fearad -> Tremor högst", function()
	MOCK.loc = { { locType = "FEAR", displayText = "Feared" } }
	MOCK.units.target = { name = "Rogue", class = "ROGUE", hostile = true, player = true }
	local recs = advise()
	check(recs["Tremor Totem"] and recs["Tremor Totem"].prio == 100, "Tremor prio 100")
	check(ns.Alert:Current() == "Tremor Totem", "Tremor visas före rogue-regeln")
	MOCK.loc = {}
	MOCK.time = MOCK.time + 10
	recs = advise()
	check(recs["Poison Cleansing Totem"] ~= nil, "rogue -> Poison Cleansing")
	MOCK.units.target = nil
end)

test("varning: fear-mob, boss, zon, gift", function()
	MOCK.units.target = { name = "Magmadar", hostile = true }
	local recs = advise()
	check(recs["Tremor Totem"] ~= nil, "Magmadar -> Tremor")
	MOCK.units.target = { name = "Onyxia", hostile = true }
	recs = advise()
	check(recs["Fire Resistance Totem"] ~= nil, "Onyxia -> Fire Resistance")
	check(recs["Tremor Totem"] ~= nil, "Onyxia -> Tremor (fear)")
	MOCK.units.target = nil
	MOCK.instanceName = "Molten Core"
	recs = advise()
	check(recs["Fire Resistance Totem"] ~= nil, "Molten Core -> Fire Resistance")
	MOCK.instanceName = nil
	MOCK.units.party1 = { name = "Jaina", class = "MAGE", player = true }
	MOCK.auras.party1 = { { name = "Deadly Poison", harmful = true, dispelName = "Poison" } }
	MOCK.fire("UNIT_AURA", "party1")
	recs = advise()
	check(recs["Poison Cleansing Totem"] ~= nil and recs["Poison Cleansing Totem"].reason:find("Jaina"), "gift på Jaina")
	MOCK.auras.party1 = nil
	MOCK.fire("UNIT_AURA", "party1")
	recs = advise()
	check(recs["Poison Cleansing Totem"] == nil, "giftet borta")
	MOCK.units.party1 = nil
	-- egen fear-mob och bossregel
	ns.Advisor:AddFearMob("Testmob")
	ns.Advisor:AddBossRule("Testboss", "Nature Resistance Totem")
	MOCK.units.target = { name = "Testmob", hostile = true }
	check(advise()["Tremor Totem"] ~= nil, "egen fear-mob")
	MOCK.units.target = { name = "Testboss", hostile = true }
	check(advise()["Nature Resistance Totem"] ~= nil, "egen bossregel")
	ns.Advisor:RemoveFearMob("testmob")
	MOCK.units.target = { name = "Testmob", hostile = true }
	check(advise()["Tremor Totem"] == nil, "fear-mob borttagen")
	MOCK.units.target = nil
	advise()
	check(ns.Alert:Current() == nil, "ingen varning utan orsak")
end)

test("varning: inga totems i strid", function()
	MOCK.combat = true
	MOCK.fire("PLAYER_REGEN_DISABLED")
	MOCK.time = MOCK.time + 10
	advise()
	check(ns.Alert:Current() == "nototems", "påminnelse: " .. tostring(ns.Alert:Current()))
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	advise()
	check(ns.Alert:Current() == nil, "borta efter strid")
end)

test("gruppsammansättning -> grön situation", function()
	MOCK.group = 3
	MOCK.units.party1 = { name = "A", class = "WARRIOR", player = true }
	MOCK.units.party2 = { name = "B", class = "ROGUE", player = true }
	advise()
	check(_G.FarseerSit1.rec:IsShown(), "Melee (1) rekommenderad")
	MOCK.units.party1.class, MOCK.units.party2.class = "MAGE", "PRIEST"
	advise()
	check(_G.FarseerSit2.rec:IsShown() and not _G.FarseerSit1.rec:IsShown(), "Caster (2) rekommenderad")
	MOCK.group = 0
	MOCK.units.party1, MOCK.units.party2 = nil, nil
end)

test("secret values: allt låst -> inga fel", function()
	MOCK.secretMode = true
	MOCK.combat = true
	MOCK.units.target = { name = "X", class = "WARLOCK", hostile = true, player = true }
	MOCK.loc = { { locType = "FEAR" } }
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	MOCK.fire("UNIT_AURA", "player")
	MOCK.tick(6)
	advise()
	ns.Reminders:Check()
	ns.Totems:UpdateBar()
	MOCK.secretMode = false
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	MOCK.units.target = nil
	MOCK.loc = {}
	MOCK.time = MOCK.time + 10
	advise()
end)

test("påminnelser: sköld och imbue", function()
	MOCK.auras.player = {}
	MOCK.weaponEnchant = { false, 0 }
	ns.Reminders:Refresh()
	check(_G.FarseerShieldButton.glow:IsShown(), "ingen sköld -> glöd")
	check(_G.FarseerImbueButton.glow:IsShown(), "ingen imbue -> glöd")
	check(_G.FarseerShieldButton:GetAttribute("spell") == "Lightning Shield", "sköldknapp castar Lightning Shield")
	check(_G.FarseerImbueButton:GetAttribute("spell") == "Windfury Weapon", "imbue = Windfury")
	MOCK.auras.player = { { name = "Lightning Shield" } }
	MOCK.weaponEnchant = { true, 120000 }
	ns.Reminders:Check()
	check(not _G.FarseerShieldButton.glow:IsShown(), "sköld uppe -> ingen glöd")
	check(_G.FarseerImbueButton.glow:IsShown(), "imbue < 5 min -> glöd")
	MOCK.weaponEnchant = { true, 3600000 }
	ns.Reminders:Check()
	check(not _G.FarseerImbueButton.glow:IsShown(), "imbue 60 min -> ingen glöd")
	ns.char.reminders.preferWaterShield = true
	ns.Reminders:Refresh()
	check(_G.FarseerShieldButton:GetAttribute("spell") == "Water Shield", "föredrar Water Shield")
	ns.char.reminders.preferWaterShield = false
	ns.Reminders:Refresh()
end)

---------------------------------------------------------------------------------------------------
test("UI: alla flikar byggs och uppdateras", function()
	ns.Options:Open()
	for _, id in ipairs({ "overview", "macros", "bindings", "situations", "advisor", "bis", "settings" }) do
		ns.UI.SelectTab(id)
	end
	check(_G.FarseerOptions:IsShown(), "fönstret visas")
	-- BiS: alla specs
	for _, spec in ipairs({ "elemental", "enhancement", "restoration" }) do
		ns.char.bisSpec = spec
		ns.char.bisPhase = "prebis"
		ns.UI.SelectTab("bis")
		ns.char.bisPhase = "phase1"
		ns.UI.SelectTab("bis")
	end
	ns.char.bisPhase = "prebis"
	ns.UI.SelectTab("overview")
	ns.Options:Toggle()
	check(not _G.FarseerOptions:IsShown(), "toggle stänger")
end)

test("UI: ett-klicks-setup via popup", function()
	MOCK.autoAccept = true
	ns.Options:Open("overview")
	-- hitta "Kör setup"-knappar och klicka den första (Elemental)
	local found
	local function walk(w)
		for _, c in ipairs(w.__children or {}) do
			if c.__fs == nil and c.__text == "Kör setup" then found = found or c end
			if c.__kind == "Button" and c.__text == "Kör setup" then found = found or c end
			walk(c)
		end
	end
	walk(_G.FarseerOptions)
	check(found ~= nil, "Kör setup-knapp hittad")
	if found then found:Click() end
	check(MOCK.bindings["1"] == "MACRO FS Bolt", "Elemental-layout bunden: " .. tostring(MOCK.bindings["1"]))
	ns.BindingEngine:Restore()
	MOCK.autoAccept = false
	ns.Options:Toggle()
end)

test("BiS-data", function()
	local B = ns.BIS
	check(B and B.specs, "BiS finns")
	local slots = { "HEAD", "NECK", "SHOULDER", "BACK", "CHEST", "WRIST", "HANDS", "WAIST", "LEGS", "FEET", "FINGER1",
		"FINGER2", "TRINKET1", "TRINKET2", "MAINHAND", "OFFHAND", "RELIC" }
	for _, spec in ipairs({ "elemental", "enhancement", "restoration" }) do
		local list = B.specs[spec] and B.specs[spec].prebis
		check(list and #list == 17, spec .. ": 17 slots")
		local have = {}
		for _, e in ipairs(list or {}) do have[e.slot] = e end
		for _, s in ipairs(slots) do check(have[s] ~= nil, spec .. " saknar " .. s) end
	end
end)

test("slashkommandon", function()
	for _, c in ipairs({ "help", "lock", "unlock", "lock", "pvp", "pve", "test", "macros pvp", "macros okänd",
		"bind okänd", "bind mouse", "restore", "debug", "bis", "nonsens", "" }) do
		SlashCmdList.FARSEER(c)
	end
	MOCK.runTimers()
	check(#MOCK.printed > 5, "skrev ut text")
end)

test("lås upp/lås i strid nekas", function()
	MOCK.combat = true
	ns.setLocked(false)
	check(ns.char.locked == true, "förblev låst i strid")
	MOCK.combat = false
end)

---------------------------------------------------------------------------------------------------
TEST, CHECK = test, check
function FINISH()
	out(string.format("%d ok, %d fel", results.pass, results.fail))
	RESULTS = results
end
