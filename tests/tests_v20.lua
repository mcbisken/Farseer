-- v2.1: gemensamma timers, testrapport, testlista, klassiskt utseende, första-gången-fönstret

local ns = FARSEER_NS
local test, check = TEST, CHECK

test("v20: ns.every delar ticker per intervall och fångar fel", function()
	local before = #MOCK.tickers
	local runs = 0
	local a = ns.every(7.5, "test-a", function() runs = runs + 1 end)
	local b = ns.every(7.5, "test-b", function() error("boom-v20") end)
	check(#MOCK.tickers == before + 1, "två uppgifter, samma intervall: en ticker")
	local errs = #ns.errors
	MOCK.tickers[#MOCK.tickers]()
	check(runs == 1, "uppgiften körd")
	check(a.runs == 1 and b.runs == 1, "båda räknade")
	check(#ns.errors == errs + 1 and ns.errors[#ns.errors]:find("boom-v20", 1, true) ~= nil, "felet rapporterat: " .. tostring(ns.errors[#ns.errors]))
	-- väntat fel: ska inte räknas som addon-fel i testet
	for i = #MOCK.errors, 1, -1 do if MOCK.errors[i]:find("boom-v20", 1, true) then table.remove(MOCK.errors, i) end end
	b.paused = true
	MOCK.tickers[#MOCK.tickers]()
	check(b.runs == 1 and a.runs == 2, "pausad uppgift hoppas över")
	local found = 0
	for _, t in ipairs(ns.tasks) do
		if t.name == "advisor" or t.name == "totem-timers" or t.name == "procs-auras" or t.name == "reminders" then found = found + 1 end
	end
	check(found == 4, "modulernas timers registrerade: " .. found)
end)

test("v20: testrapporten", function()
	ns.db.testlist = { look = "ok", shield = "bad" }
	ns.report("v20-report-error\nline two")
	for i = #MOCK.errors, 1, -1 do if MOCK.errors[i]:find("v20-report-error", 1, true) then table.remove(MOCK.errors, i) end end
	local text = ns.Report:Text()
	for _, part in ipairs({ "== Client features ==", "Aura container (Maelstrom)", "Call with any set in combat",
		"Text to speech", "PLAYER_SWING", "== Test checklist ==", "[OK] Settings window looks right",
		"[BROKEN] Shield charges flash red", "== Load ==", "== Errors", "v20-report-error | line two" }) do
		check(text:find(part, 1, true), "rapporten har: " .. part)
	end
	check(text:find("2 of " .. #ns.TEST_PLAN .. " tested, 1 broken", 1, true), "sammanfattning av testlistan")
	ns.Report:Show()
	check(_G.FarseerReport and _G.FarseerReport:IsShown(), "rapportfönstret visas")
	_G.FarseerReport:Hide()
	ns.db.testlist = {}
end)

test("v20: testlistan i fönstret", function()
	local ids = {}
	for _, it in ipairs(ns.TEST_PLAN) do
		check(type(it.id) == "string" and it.title and it.how, "punkt komplett")
		check(not ids[it.id], "unikt id " .. it.id)
		ids[it.id] = true
	end
	check(#ns.TEST_PLAN >= 12, "minst 12 punkter")
	ns.Options:Open("test")
	check(#MOCK.errors == 0 or not MOCK.errors[#MOCK.errors]:find("TabTest"), "fliken byggs utan fel")
	ns.Options:Hide()
	check(ns.UI.TAB_ICONS.test ~= nil, "fliken har en ikon")
end)

test("v20: klassiskt utseende", function()
	local T, UI = ns.Theme, ns.UI
	ns.db.classicUI = true
	T.ResetClassic()
	check(T.Classic() == true, "klassiskt valt")
	check(T.Font("FarseerFontBody") ~= "FarseerFontBody" and T.Font("FarseerFontBody"):find("^GameFont"), "Blizzards typsnitt")
	local f = CreateFrame("Frame", nil, UIParent)
	local ok, err = pcall(function()
		UI.Header(f, "x")
		UI.Label(f, "x")
		UI.Button(f, "x", 80, 22, function() end, "tip")
		UI.Check(f, "x", function() return true end, function() end)
		UI.EditBox(f, 100)
		UI.Scroll(f, 100, 100)
		UI.MultiLine(f, 100, 100)
		UI.Stepper(f, "x", 0, 10, 1, function() return 1 end, function() end)
		UI.Dropdown(f, 100, function() return "a" end, function() return { { text = "a", value = 1 } } end, function() end)
	end)
	check(ok, "alla kontroller byggs klassiskt: " .. tostring(err))
	local b = CreateFrame("Button", nil, UIParent)
	b.icon = b:CreateTexture()
	T.SkinIcon(b)
	check(not b.farseerSkinned, "inga Farseer-ramar på knapparna")
	ns.db.classicUI = false
	T.ResetClassic()
	check(T.Classic() == false, "tillbaka till Farseer-utseendet")
	T.SkinIcon(b)
	check(b.farseerSkinned, "skalet läggs på igen")
	ns.Slash("classic")
	check(ns.db.classicUI == true, "/farseer classic växlar")
	ns.Slash("classic")
	check(ns.db.classicUI == false, "och tillbaka")
	T.ResetClassic()
end)

test("v20: första-gången-fönstret", function()
	local SU = ns.Setup
	MOCK.combat = false
	check(ns.freshChar == true, "testkaraktären räknas som ny")
	SU:Show()
	check(SU:Shown(), "fönstret visas")
	local c = SU:Choice()
	check(c.binds == "none", "förval: rör inte keybinds")
	check(c.spec == "elemental" or c.spec == "enhancement" or c.spec == "restoration", "spec förvald")
	for i = 1, 4 do SU:Step(i) end
	check(SU:Step() == 4, "går att stega till sista sidan")

	-- Shift-lagret: inget hamnar på 1, allt på SHIFT-1
	MOCK.bindings["1"] = "ACTIONBUTTON1"
	MOCK.bindings["SHIFT-1"] = nil
	local ok, lines = SU:Apply({ spec = "elemental", binds = "shift", macros = false, alert = "group", speak = "critical", classic = false })
	check(ok, "klar: " .. table.concat(lines, " / "))
	check(MOCK.bindings["1"] == "ACTIONBUTTON1", "vanliga tangenten orörd")
	check(MOCK.bindings["SHIFT-1"] and MOCK.bindings["SHIFT-1"] ~= "", "layouten på Shift: " .. tostring(MOCK.bindings["SHIFT-1"]))
	check(ns.db.alert.mode == "group" and ns.db.alert.speak == "critical", "varningsvalen sparade")
	check(ns.char.setupDone == true, "markerad som klar")
	check(ns.char.bisSpec == "elemental", "BiS-spec satt")
	ns.BindingEngine:Restore()
	check(MOCK.bindings["SHIFT-1"] == nil or MOCK.bindings["SHIFT-1"] == "", "Restore tar bort det igen")

	-- Byte av utseende kräver /reload
	ok, lines = SU:Apply({ spec = "restoration", binds = "none", macros = false, alert = "always", speak = "off", classic = true })
	check(table.concat(lines, " "):find("/reload"), "säger till om /reload")
	check(ns.db.classicUI == true, "klassiskt sparat")
	ns.db.classicUI = false
	ns.Theme.ResetClassic()

	MOCK.combat = true
	ok = SU:Apply({ spec = "elemental", binds = "plain", alert = "always", speak = "off" })
	check(ok == false, "inte i strid")
	MOCK.combat = false
	ns.db.alert.mode, ns.db.alert.speak = "always", "off"
	ns.char.bisSpec = "elemental"
	_G.FarseerSetup:Hide()
end)

test("v20: nya kommandon", function()
	ns.Slash("report")
	check(_G.FarseerReport:IsShown(), "/farseer report")
	_G.FarseerReport:Hide()
	ns.Slash("setup")
	check(ns.Setup:Shown(), "/farseer setup")
	_G.FarseerSetup:Hide()
end)

test("v20: keybind-läget tar bort alla gamla tangenter", function()
	local KM = ns.KeyMode
	local b = _G.FarseerSit1
	MOCK.combat = false
	MOCK.bindings["F7"] = "CLICK FarseerSit1:LeftButton"
	MOCK.bindings["F8"] = "CLICK FarseerSit1:LeftButton"
	check(KM:Bind(b, "F9"), "binder")
	check(MOCK.bindings["F9"] == "CLICK FarseerSit1:LeftButton", "nya tangenten")
	check((MOCK.bindings["F7"] or "") == "" and (MOCK.bindings["F8"] or "") == "", "båda gamla borta")
	ns.BindingEngine:Restore()
end)

test("v20: bar-knapparna: skal efter etikett och cooldown", function()
	check(_G.FarseerSit1.farseerSkinned, "situationsknapp skinnad")
	check(_G.FarseerCounter1.farseerSkinned, "motknapp skinnad")
	check(_G.FarseerTotemFIRE.textTop ~= nil, "totemtiden ovanför cooldown-svepet")
end)
