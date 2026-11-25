-- v1.9: off-hand-swing, Flurry på swing-baren, glöd när spells är redo, keybind-läge

local ns = FARSEER_NS
local test, check = TEST, CHECK

test("v19: off-hand-swing", function()
	local HU = ns.HUD
	local oldSpeed = UnitAttackSpeed
	rawset(_G, "UnitAttackSpeed", function() return 2.6, 1.8 end)
	HU:OnSwing(nil, 1)   -- off-hand, secret tid: vapnets hastighet
	HU:OnSwing(2.6, 0)
	MOCK.combat = true
	ns.char.hud.swing = true
	ns.char.hud.offSwing = true
	ns.char.bars.hud.show = true
	HU:Layout()
	HU:UpdateTimers()
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
	MOCK.combat = false
	rawset(_G, "UnitAttackSpeed", oldSpeed)
end)

test("v19: glöd när spells är redo", function()
	local HU = ns.HUD
	local t0 = MOCK.time
	check(HU:Ready("Earth Shock", t0) == true, "inte castad: redo")
	HU:OnReadyCast("Frost Shock")
	check(HU:Ready("Earth Shock", t0 + 1) == false, "Frost Shock delar cooldown med Earth Shock")
	check(HU:Ready("Earth Shock", t0 + 6.1) == true, "6 s senare: redo")
	HU:OnReadyCast("Stormstrike")
	check(HU:Ready("Stormstrike", t0 + 10) == false, "Stormstrike 10 s: inte redo")
	check(HU:Ready("Stormstrike", t0 + 20.5) == true, "20 s: redo")
	check(HU:Ready("Chain Heal", t0) == true, "okänd spell: redo")
end)

test("v19: keybind-läge", function()
	local KM = ns.KeyMode
	MOCK.combat = false
	check(KM:Start() == true, "startar utanför strid")
	check(KM:Active(), "aktivt")
	local b = _G.FarseerSit1
	check(KM:Bind(b, "SHIFT-F") == true, "binder")
	check(GetBindingAction("SHIFT-F") == "CLICK FarseerSit1:LeftButton", "tangenten pekar på knappen")
	check(ns.char.bindBackup["SHIFT-F"] ~= nil, "gamla tangenten sparad")
	-- Ny tangent: den gamla tas bort
	check(KM:Bind(b, "SHIFT-G") == true, "binder om")
	check(GetBindingAction("SHIFT-F") == "", "gamla tangenten borttagen")
	check(GetBindingAction("SHIFT-G") == "CLICK FarseerSit1:LeftButton", "nya tangenten")
	KM:Clear(b)
	check(GetBindingAction("SHIFT-G") == "", "Delete tar bort")
	check(KM:FullKey("LSHIFT") == nil, "bara Shift: ingen tangent")
	local oldShift = IsShiftKeyDown
	rawset(_G, "IsShiftKeyDown", function() return true end)
	check(KM:FullKey("T") == "SHIFT-T", "Shift+T")
	rawset(_G, "IsShiftKeyDown", oldShift)
	ns.fire("COMBAT_START")
	check(not KM:Active(), "striden avslutar läget")
	MOCK.combat = true
	check(KM:Start() == false, "kan inte starta i strid")
	MOCK.combat = false
	ns.BindingEngine:Restore()
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)
