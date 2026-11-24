-- v1.7: varningsrutans prioritet, var den visas och ljud

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function reset()
	ns.Alert:Hide(true)
	MOCK.runTimers()
	ns.Alert:Hide(true)
end

test("v17: varningsprioritet", function()
	local AL = ns.Alert
	ns.db.alert.mode = "always"
	reset()
	-- info-flash, sedan advice-flash: advice tar över
	check(AL:Flash("a", "Searing Totem", "A", "", nil, 3) == true, "info-flash visas")
	check(AL:Flash("b", "Mana Spring Totem", "B", "", nil, 3, "advice") == true, "advice-flash tar över info")
	check(AL:Current() == "b", "b visas")
	-- info-flash under en advice-flash: släpps
	check(AL:Flash("c", "Searing Totem", "C", "", nil, 3) == false, "info släpps under advice-flash")
	check(AL:Current() == "b", "b ligger kvar")
	-- rådgivaren (advice) trycker inte undan en lika viktig flash
	check(AL:Show("tremor", "Tremor Totem", "TREMOR", "") == false, "advice-Show väntar på advice-flash")
	-- kritisk Show tar över
	check(AL:Show("fear", "Tremor Totem", "FEARED", "", nil, false, "critical") == true, "kritisk Show tar över")
	-- flash under kritisk varning: släpps, även advice
	check(AL:Flash("d", "Searing Totem", "D", "", nil, 3, "advice") == false, "advice-flash släpps under kritisk")
	check(AL:Flash("e", "Tremor Totem", "E", "", nil, 3, "critical") == true, "kritisk flash visas")
	reset()
	-- info-flash över en vanlig rådgivarvarning: visas (rådgivaren kommer tillbaka efteråt)
	AL:Show("adv", "Mana Spring Totem", "ADV", "")
	check(AL:Flash("f", "Searing Totem", "F", "", nil, 3) == true, "info-flash över advice-Show")
	reset()
end)

test("v17: samma flash två gånger får hela sin tid", function()
	local AL = ns.Alert
	reset()
	AL:Flash("x", "Searing Totem", "X", "", nil, 3)
	local first = MOCK.timers
	MOCK.timers = {}
	AL:Flash("x", "Searing Totem", "X", "", nil, 3)
	for _, fn in ipairs(first) do fn() end
	check(AL:Current() == "x", "den första timern döljer inte den andra")
	MOCK.runTimers()
	check(AL:Current() == nil, "den andra timern döljer")
	reset()
end)

test("v17: var varningar visas och ljud", function()
	local AL = ns.Alert
	reset()
	local oldInst, oldNum = IsInInstance, GetNumGroupMembers
	rawset(_G, "IsInInstance", function() return false end)
	rawset(_G, "GetNumGroupMembers", function() return 0 end)
	ns.db.alert.mode = "off"
	check(AL:Flash("o", "Searing Totem", "O", "", nil, 3, "critical") == false, "off: ingenting")
	ns.db.alert.mode = "group"
	check(AL:Flash("g", "Searing Totem", "G", "", nil, 3) == false, "group: solo -> ingenting")
	rawset(_G, "GetNumGroupMembers", function() return 3 end)
	check(AL:Flash("g", "Searing Totem", "G", "", nil, 3) == true, "group: i grupp -> visas")
	reset()
	ns.db.alert.mode = "instance"
	check(AL:Flash("i", "Searing Totem", "I", "", nil, 3) == false, "instance: utanför -> ingenting")
	rawset(_G, "IsInInstance", function() return true end)
	check(AL:Flash("i", "Searing Totem", "I", "", nil, 3) == true, "instance: inne -> visas")
	check(AL:InGroupOrInstance() == true, "InGroupOrInstance")
	reset()
	ns.db.alert.mode = "always"
	rawset(_G, "IsInInstance", oldInst)
	rawset(_G, "GetNumGroupMembers", oldNum)

	-- ljud: info tyst som standard, advice låter
	local played = 0
	local oldPlay = PlaySound
	rawset(_G, "PlaySound", function() played = played + 1 end)
	ns.char.advisor.sound = true
	ns.db.alert.quietInfo = true
	AL:Flash("snd-info", "Searing Totem", "S", "", nil, 3)
	check(played == 0, "info-flash utan ljud")
	reset()
	AL:Flash("snd-adv", "Searing Totem", "S", "", nil, 3, "advice")
	check(played == 1, "advice-flash med ljud")
	reset()
	ns.db.alert.quietInfo = false
	AL:Flash("snd-info2", "Searing Totem", "S", "", nil, 3)
	check(played == 2, "quietInfo av: info låter")
	ns.db.alert.quietInfo = true
	rawset(_G, "PlaySound", oldPlay)
	reset()
end)

test("v17: flash visar alltid sin text", function()
	local AL = ns.Alert
	reset()
	ns.char.advisor.showText = false
	AL:Flash("t", "Searing Totem", "T", "Missing: shield.", nil, 3)
	local f = _G.FarseerAlert
	check(f and f.text:IsShown(), "flash-texten syns trots showText av")
	reset()
	AL:Show("t2", "Searing Totem", "T2", "reason")
	check(not f.text:IsShown(), "rådgivarens text följer showText")
	ns.char.advisor.showText = true
	reset()
end)

test("v17: Alerts-fliken med nya inställningar", function()
	ns.UI.SelectTab("alerts")
	ns.UI.SelectTab("procs")
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)
