-- Tester för v1.6 (totems): varning innan totems går ut, gruppens täckning av totembuffar (+ Totemic Call-glöd)
-- och blåtonade totemknappar när manan inte räcker.

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function cast(name) MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known[name]) end

local function clearTotems()
	cast("Totemic Recall")
	for s = 1, 4 do MOCK.totems[s] = nil end
	MOCK.fire("PLAYER_TOTEM_UPDATE")
	MOCK.runTimers()
end

local function drop(slot, name, start, dur)
	MOCK.totems[slot] = { name = name, start = start or MOCK.time, dur = dur or 300 }
	MOCK.fire("PLAYER_TOTEM_UPDATE", slot)
	MOCK.runTimers()
end

---------------------------------------------------------------------------------------------------
test("totems: varning innan de går ut", function()
	local ta = ns.char.totemAlerts
	ta.expire, ta.expireSec, ta.expireLongOnly = true, 20, true
	clearTotems()
	local fired
	ns.listen("TOTEMS_EXPIRING", function(list) fired = list end)
	local t0 = MOCK.time
	drop(3, "Mana Spring Totem", t0)
	drop(2, "Strength of Earth Totem", t0 + 1)
	drop(1, "Searing Totem", t0 + 270, 30)   -- går ut samtidigt men är kort: hoppas över
	MOCK.time = t0 + 270
	check(ns.Totems:CheckExpiry() == nil, "30 s kvar: ingen varning")
	MOCK.time = t0 + 280.5
	local list = ns.Totems:CheckExpiry()
	check(list and #list == 2, "Mana Spring + Strength of Earth i samma varning: " .. tostring(list and #list))
	check(list and list[1].name == "Mana Spring Totem", "först den som går ut först")
	check(ns.Alert:Current() == "expire", "varning visas: " .. tostring(ns.Alert:Current()))
	check(_G.FarseerAlert.title:GetText() == "TOTEMS EXPIRE IN 20s", "rubrik: " .. tostring(_G.FarseerAlert.title:GetText()))
	local text = _G.FarseerAlert.text:GetText()
	check(text:find("Mana Spring Totem", 1, true) and text:find("Strength of Earth Totem", 1, true), "namnen i texten: " .. text)
	check(not text:find("Searing", 1, true), "Searing (30 s) inte med")
	check(text:find("Right-click a situation", 1, true) and text:find("Totemic Call", 1, true), "tips i texten")
	check(fired == list, "TOTEMS_EXPIRING skickas")
	MOCK.runTimers()
	MOCK.time = t0 + 285
	check(ns.Totems:CheckExpiry() == nil, "en varning per totem")
	-- Kort totem när filtret är av
	ta.expireLongOnly = false
	list = ns.Totems:CheckExpiry()
	check(list and #list == 1 and list[1].name == "Searing Totem", "utan filtret: Searing varnas")
	check(_G.FarseerAlert.title:GetText() == "TOTEM EXPIRES IN 15s", "singular: " .. tostring(_G.FarseerAlert.title:GetText()))
	ta.expireLongOnly = true
	MOCK.runTimers()
	-- Nytt totem i samma slot = ny cast: varnas igen
	drop(3, "Mana Spring Totem", MOCK.time)
	MOCK.time = MOCK.time + 285
	list = ns.Totems:CheckExpiry()
	check(list and #list == 1 and list[1].name == "Mana Spring Totem", "nysatt totem varnas igen")
	MOCK.runTimers()
	-- Död: ingen varning
	drop(3, "Mana Spring Totem", MOCK.time)
	MOCK.time = MOCK.time + 285
	MOCK.units.player.dead = true
	check(ns.Totems:CheckExpiry() == nil, "död: ingen varning")
	MOCK.units.player.dead = nil
	local taxi = UnitOnTaxi
	rawset(_G, "UnitOnTaxi", function() return true end)
	check(ns.Totems:CheckExpiry() == nil, "taxi: ingen varning")
	rawset(_G, "UnitOnTaxi", taxi)
	ta.expire = false
	check(ns.Totems:CheckExpiry() == nil, "avstängd")
	ta.expire = true
	check(ns.Totems:CheckExpiry() ~= nil, "på igen: varnar")
	MOCK.runTimers()
	clearTotems()
end)

---------------------------------------------------------------------------------------------------
test("totems: gruppens buffar", function()
	local ta = ns.char.totemAlerts
	ta.party = true
	clearTotems()
	local cb = _G.FarseerTotemicCall
	local cover = _G.FarseerTotemBar.cover
	MOCK.units.party1 = { name = "Bob", player = true }
	MOCK.units.party2 = { name = "Alice", player = true }
	MOCK.units.party3 = { name = "Faraway", player = true }
	MOCK.units.party4 = { name = "Ghost", player = true, dead = true }
	local inRange = { party1 = true, party2 = true, party3 = false, party4 = true }
	rawset(_G, "UnitInRange", function(u) return inRange[u], true end)
	MOCK.auras.player = { { name = "Strength of Earth", spellId = 8076 } }
	MOCK.auras.party1 = { { name = "Strength of Earth" } }
	MOCK.auras.party2 = {}
	drop(2, "Strength of Earth Totem", MOCK.time)
	drop(4, "Windfury Totem", MOCK.time)   -- buffen har aldrig setts på någon: rapporteras inte
	check(#ns.Totems:PartyCoverage() == 0, "nysatt: väntar på första pulsen")
	MOCK.time = MOCK.time + 4
	ns.Totems:CheckRange()
	local list = ns.Totems:PartyCoverage()
	check(#list == 1 and list[1].totem == "Strength of Earth Totem", "bara Strength of Earth: " .. tostring(#list))
	check(list[1] and #list[1].missing == 1 and list[1].missing[1] == "Alice",
		"Alice saknar buffen (Faraway utom räckhåll, Ghost död)")
	ns.Totems:UpdateCoverage()
	check(cover:IsShown() and cover.text:GetText() == "1 missing buff", "text under baren: " .. tostring(cover.text:GetText()))
	check(not ns.Totems:AnyOutOfRange() and cb.glow:IsShown(), "Totemic Call lyser")
	-- Tooltip
	local lines = {}
	rawset(GameTooltip, "AddLine", function(_, t) table.insert(lines, t) end)
	cover:GetScript("OnEnter")(cover)
	rawset(GameTooltip, "AddLine", nil)
	check(lines[1] == "Strength of Earth Totem: Alice", "tooltip: " .. tostring(lines[1]))
	-- Två saknar
	MOCK.auras.party1 = {}
	ns.Totems:UpdateCoverage()
	check(cover.text:GetText() == "2 missing buffs", "två: " .. tostring(cover.text:GetText()))
	check(table.concat(ns.Totems:Coverage()[1].missing, ",") == "Bob,Alice", "Bob och Alice")
	-- Räckvidden okänd (secret / inte kontrollerad): hoppas över
	rawset(_G, "UnitInRange", function() return SECRET, SECRET end)
	check(#ns.Totems:PartyCoverage() == 0, "secret räckvidd: ingen räknas")
	rawset(_G, "UnitInRange", function() return false, false end)
	check(#ns.Totems:PartyCoverage() == 0, "räckvidd inte kontrollerad: ingen räknas")
	rawset(_G, "UnitInRange", function(u) return inRange[u], true end)
	-- Offline
	rawset(_G, "UnitIsConnected", function(u) return u ~= "party2" end)
	list = ns.Totems:PartyCoverage()
	check(#list == 1 and #list[1].missing == 1 and list[1].missing[1] == "Bob", "offline hoppas över")
	rawset(_G, "UnitIsConnected", nil)
	-- Secret auror
	local orig = C_Secrets.ShouldAurasBeSecret
	C_Secrets.ShouldAurasBeSecret = function() return SECRET end
	check(ns.Totems:PartyCoverage() == nil, "secret auror: okänt")
	C_Secrets.ShouldAurasBeSecret = orig
	-- Strid: körs inte, texten och glöden försvinner
	ns.Totems:UpdateCoverage()
	check(cb.glow:IsShown(), "lyser före strid")
	MOCK.combat = true
	check(ns.Totems:PartyCoverage() == nil, "i strid: körs inte")
	ns.fire("COMBAT_START")
	check(not cover:IsShown() and not cb.glow:IsShown(), "strid: dold, ingen glöd")
	MOCK.combat = false
	ns.Totems:UpdateCoverage()
	check(cover:IsShown(), "efter strid igen")
	-- Avstängd
	ta.party = false
	ns.Totems:UpdateCoverage()
	check(ns.Totems:PartyCoverage() == nil and not cover:IsShown() and not cb.glow:IsShown(), "avstängd")
	ta.party = true
	-- Alla har buffen
	MOCK.auras.party1 = { { name = "Strength of Earth" } }
	MOCK.auras.party2 = { { name = "Strength of Earth" } }
	ns.Totems:UpdateCoverage()
	check(not cover:IsShown() and not cb.glow:IsShown(), "alla har buffen: inget")
	-- Städa
	for i = 1, 4 do MOCK.units["party" .. i] = nil; MOCK.auras["party" .. i] = nil end
	MOCK.auras.player = {}
	rawset(_G, "UnitInRange", nil)
	clearTotems()
	ns.Totems:UpdateCoverage()
end)

---------------------------------------------------------------------------------------------------
test("bars: blåtonade knappar utan mana", function()
	local ta = ns.char.totemAlerts
	ta.manaDim = true
	ns.Bars:SetMode("PVE", true)
	ns.Bars:ApplySituations()
	ns.Bars:ApplyCounter()
	ns.Bars:ResetSequences()
	local oldCost = MOCK.manaCost
	MOCK.manaCost = {}
	MOCK.mana = { 1000, 1000 }
	local sit = _G.FarseerSit1
	check(ns.Bars:Situation(1).name == "Melee", "situation 1 = Melee")
	local vc
	rawset(sit.icon, "SetVertexColor", function(_, r, g, b) vc = { r, g, b } end)
	local function blue() return vc and vc[1] == 0.4 and vc[2] == 0.4 and vc[3] == 1 end
	local function white() return vc and vc[1] == 1 and vc[2] == 1 and vc[3] == 1 end
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "första totemet: " .. tostring(ns.Bars:NextTotem(1)))
	MOCK.manaCost[MOCK.known["Windfury Totem"]] = 2000
	ns.Bars:UpdateMana()
	check(sit.noMana == true and blue(), "Windfury för dyrt: blå")
	-- Tryck + cast: sekvensen går fram till Strength of Earth (har råd)
	sit:Click("LeftButton")
	cast("Windfury Totem")
	check(ns.Bars:NextTotem(1) == "Strength of Earth Totem", "nästa: " .. tostring(ns.Bars:NextTotem(1)))
	check(sit.noMana == false and white(), "Strength of Earth: inte blå")
	-- Cast utan tryck på knappen flyttar inte sekvensen
	cast("Strength of Earth Totem")
	check(ns.Bars:NextTotem(1) == "Strength of Earth Totem", "cast utanför knappen räknas inte")
	-- reset=N
	MOCK.time = MOCK.time + 11
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "börjar om efter seqReset")
	sit:Click("LeftButton")
	cast("Windfury Totem")
	ns.fire("COMBAT_END")
	check(ns.Bars:NextTotem(1) == "Windfury Totem", "börjar om efter strid")
	check(sit.noMana == true and blue(), "blå igen")
	-- Kontratotems
	local tremor
	for i = 1, 12 do
		local b = _G["FarseerCounter" .. i]
		if b.spell == "Tremor Totem" then tremor = b end
	end
	check(tremor ~= nil, "Tremor på kontrabaren")
	MOCK.manaCost[MOCK.known["Tremor Totem"]] = 5000
	ns.Bars:UpdateMana()
	check(tremor and tremor.noMana == true, "kontratotem blå")
	-- Okänt (secret): ingen toning
	MOCK.secretMode = true
	ns.Bars:UpdateMana()
	MOCK.secretMode = false
	check(sit.noMana == false and white() and tremor.noMana == false, "secret: ingen toning")
	-- C_Spell.IsSpellUsable föredras
	local usable, noMana = false, true
	rawset(C_Spell, "IsSpellUsable", function() return usable, noMana end)
	MOCK.manaCost = {}
	ns.Bars:UpdateMana()
	check(sit.noMana == true, "IsSpellUsable säger för lite mana")
	usable, noMana = true, false
	MOCK.manaCost[MOCK.known["Windfury Totem"]] = 2000
	ns.Bars:UpdateMana()
	check(sit.noMana == false, "IsSpellUsable säger ok (kostnaden ignoreras)")
	usable, noMana = SECRET, SECRET
	ns.Bars:UpdateMana()
	check(sit.noMana == true, "IsSpellUsable secret: kostnad mot mana")
	rawset(C_Spell, "IsSpellUsable", nil)
	-- Avstängd
	ta.manaDim = false
	ns.Bars:UpdateMana()
	check(sit.noMana == false and white() and tremor.noMana == false, "avstängd: ingen toning")
	ta.manaDim = true
	-- UNIT_POWER_FREQUENT: strypt till 0,25 s, sista värdet kommer med
	MOCK.runTimers()
	MOCK.time = MOCK.time + 1
	MOCK.manaCost = {}
	MOCK.fire("UNIT_POWER_FREQUENT", "player")
	check(sit.noMana == false, "billigt: inte blå")
	MOCK.manaCost[MOCK.known["Windfury Totem"]] = 2000
	MOCK.fire("UNIT_POWER_FREQUENT", "player")
	check(sit.noMana == false, "strypt: väntar")
	MOCK.fire("UNIT_POWER_FREQUENT", "target")
	MOCK.runTimers()
	check(sit.noMana == true, "efter 0,25 s: blå")
	MOCK.time = MOCK.time + 1
	MOCK.manaCost = {}
	MOCK.fire("SPELL_UPDATE_USABLE")
	check(sit.noMana == false, "SPELL_UPDATE_USABLE uppdaterar")
	-- Städa
	rawset(sit.icon, "SetVertexColor", nil)
	MOCK.manaCost = oldCost
	clearTotems()
	ns.Bars:UpdateMana()
end)
