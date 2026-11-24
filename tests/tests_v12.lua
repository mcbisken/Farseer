-- Tester för v1.2: Maelstrom, sköldladdningar, Windfury, låg mana, purge, fiendens casts, DR, Blizzards
-- förslag, totemräckvidd + Totemic Call, spec, click-cast, raid-totems, downranking och nya flikar.

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function aura(t)
	MOCK.auras.player = MOCK.auras.player or {}
	table.insert(MOCK.auras.player, t)
	return t
end
local function clearAuras() MOCK.auras.player = {} end

---------------------------------------------------------------------------------------------------
test("procs: Maelstrom Weapon", function()
	MOCK.learn("Maelstrom Weapon")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	local f = _G.FarseerProcmaelstrom
	MOCK.combat = true
	ns.Procs:Update()
	check(f:IsShown(), "visas i strid när talangen finns")
	check(f.count:GetText() == "", "0 stacks: ingen siffra")
	local a = aura({ name = "Maelstrom Weapon", spellId = 408505, applications = 3, auraInstanceID = 71 })
	ns.Procs:Update()
	check(f.count:GetText() == "3", "3 stacks: " .. tostring(f.count:GetText()))
	check(not f.glow:IsShown(), "ingen glöd under 5")
	local played = MOCK.played
	a.applications = 5
	ns.Procs:Update()
	check(f.glow:IsShown(), "glöd vid 5")
	check(MOCK.played == played + 1, "ljud vid 5")
	ns.Procs:Update()
	check(MOCK.played == played + 1, "ljudet spelas bara en gång")
	-- secret: siffran ritas av spelet, ingen logik
	MOCK.secretMode = true
	ns.Procs:Update()
	MOCK.secretMode = false
	check(f.count:GetText() == "<secret>", "secret-värdet skickas till texten: " .. tostring(f.count:GetText()))
	check(not f.glow:IsShown(), "ingen glöd på secret")
	clearAuras()
	MOCK.combat = false
	ns.Procs:Update()
	check(not f:IsShown(), "dold utanför strid utan stacks")
	ns.char.procs.maelstrom = false
	MOCK.combat = true
	ns.Procs:Update()
	check(not f:IsShown(), "avstängd")
	ns.char.procs.maelstrom = true
	MOCK.unlearn("Maelstrom Weapon")
	ns.Spellbook:Scan()
	MOCK.runTimers()
end)

test("procs: sköldladdningar", function()
	local f = _G.FarseerProcshield
	ns.Procs:Update()
	check(not f:IsShown(), "ingen sköld: dold")
	local a = aura({ name = "Lightning Shield", spellId = 999001, applications = 3 })
	ns.Procs:Update()
	check(f:IsShown() and f.count:GetText() == "3", "3 laddningar: " .. tostring(f.count:GetText()))
	check(_G.FarseerShieldButton.count:GetText() == "3", "siffran på påminnelseknappen")
	a.applications = 1
	ns.Procs:Update()
	check(f.glow:IsShown(), "1 laddning: varning")
	ns.Reminders:Check()
	check(_G.FarseerShieldButton.why and _G.FarseerShieldButton.why:find("laddning"), "påminnelsen säger till: "
		.. tostring(_G.FarseerShieldButton.why))
	a.applications = 0
	ns.Procs:Update()
	check(f:IsShown() and f.count:GetText() == "", "0 = klienten räknar inte: ingen siffra")
	clearAuras()
	ns.Procs:Update()
	ns.Reminders:Check()
end)

test("procs: Windfury", function()
	local before = ns.Procs:WindfuryCount()
	MOCK.fire("SPELL_UPDATE_COOLDOWN", 8233)
	check(ns.Procs:WindfuryCount() == before, "utanför strid: inget")
	MOCK.combat = true
	MOCK.fire("SPELL_UPDATE_COOLDOWN", 8233)
	check(ns.Procs:WindfuryCount() == before + 1, "proc räknad")
	check(ns.Procs.wfText:IsShown() and ns.Procs.wfText:GetText() == "WINDFURY!", "text visas")
	MOCK.fire("SPELL_UPDATE_COOLDOWN", 8233)
	check(ns.Procs:WindfuryCount() == before + 1, "samma ögonblick räknas en gång")
	MOCK.time = MOCK.time + 0.1
	MOCK.fire("SPELL_UPDATE_COOLDOWN", 8516)
	check(ns.Procs.wfText:GetText() == "WINDFURY! (totem)", "totem-proc")
	MOCK.time = MOCK.time + 0.1
	MOCK.fire("SPELL_UPDATE_COOLDOWN", 439431)
	MOCK.fire("SPELL_UPDATE_COOLDOWN", MOCK.known["Earth Shock"])
	MOCK.fire("SPELL_UPDATE_COOLDOWN", SECRET)
	MOCK.fire("SPELL_UPDATE_COOLDOWN")
	check(ns.Procs:WindfuryCount() == before + 2, "förtrollningen, andra spells och secret räknas inte")
	MOCK.time = MOCK.time + 2
	ns.Procs:Update()
	check(not ns.Procs.wfText:IsShown(), "texten tonar bort")
	MOCK.combat = false
end)

test("procs: låg mana", function()
	MOCK.combat = true
	MOCK.mana = { 900, 1000 }
	ns.Procs:CheckMana()
	check(ns.Alert:Current() ~= "lowmana", "90 %: ingen varning")
	MOCK.mana = { 200, 1000 }
	ns.Procs:CheckMana()
	check(ns.Alert:Current() == "lowmana", "20 %: varning")
	local spell = ns.Procs:ManaAdvice()
	check(spell == "Mana Tide Totem", "förslag Mana Tide: " .. tostring(spell))
	MOCK.cooldowns[MOCK.known["Mana Tide Totem"]] = { MOCK.time, 300 }
	spell = ns.Procs:ManaAdvice()
	check(spell == "Water Shield", "Mana Tide på cooldown -> Water Shield: " .. tostring(spell))
	MOCK.cooldowns = {}
	MOCK.runTimers()
	ns.Procs:CheckMana()
	check(ns.Alert:Current() ~= "lowmana", "bara en gång per dip")
	MOCK.mana = { 500, 1000 }
	ns.Procs:CheckMana()
	MOCK.mana = { 200, 1000 }
	ns.Procs:CheckMana()
	check(ns.Alert:Current() == "lowmana", "ny varning efter att manan gått upp")
	MOCK.runTimers()
	MOCK.secretMode = true
	ns.Procs:CheckMana()
	check(ns.Procs:ManaPct() == nil, "secret mana = okänt")
	MOCK.secretMode = false
	MOCK.mana = { 1000, 1000 }
	MOCK.combat = false
	ns.Procs:CheckMana()
end)

test("procs: purge", function()
	local f = _G.FarseerProcpurge
	MOCK.units.target = { name = "Priest", hostile = true, guid = "P1" }
	MOCK.auras.target = { { name = "Power Word: Fortitude" }, { name = "Power Word: Shield", dispelName = "Magic", icon = 555 } }
	ns.Procs:Update()
	check(f:IsShown(), "purge-ikon")
	check(f.buffs and #f.buffs == 1 and f.buffs[1].name == "Power Word: Shield", "rätt buff")
	check(ns.Alert:Current() ~= "purge", "PvE: ingen stor varning")
	ns.Bars:SetMode("PVP", true)
	ns.Procs:Update()
	check(ns.Alert:Current() == "purge", "PvP: varning")
	MOCK.runTimers()
	ns.Procs:Update()
	check(ns.Alert:Current() ~= "purge", "varnar en gång per buff")
	-- secret i strid: behåller det som visades, inga fel
	MOCK.combat, MOCK.secretMode = true, true
	ns.Procs:Update()
	check(f:IsShown(), "secret: ikonen står kvar")
	MOCK.combat, MOCK.secretMode = false, false
	MOCK.auras.target = {}
	ns.Procs:Update()
	check(not f:IsShown(), "ingen buff: dold")
	ns.Bars:SetMode("PVE", true)
	MOCK.units.target = nil
	ns.Procs:Update()
end)

test("procs: fiendens casts", function()
	local bar = ns.Procs.castBar
	MOCK.units.target = { name = "Mage", hostile = true }
	MOCK.casting.target = { name = "Fireball", start = MOCK.time, ends = MOCK.time + 3 }
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	ns.Procs:Update()
	check(bar:IsShown(), "castbar visas")
	check(bar.text:GetText():find("Fireball", 1, true) and bar.text:GetText():find("Earth Shock", 1, true), "namn + kick: "
		.. bar.text:GetText())
	check(ns.Alert:Current() ~= "cast-target", "PvE: ingen stor varning")
	MOCK.fire("UNIT_SPELLCAST_STOP", "target")
	ns.Procs:Update()
	check(not bar:IsShown(), "stopp: dold")
	-- PvP: stor varning; kan inte avbrytas: ingen varning
	ns.Bars:SetMode("PVP", true)
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	check(ns.Alert:Current() == "cast-target", "PvP: KICK-varning")
	MOCK.runTimers()
	MOCK.casting.target.notInt = true
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	check(ns.Alert:Current() ~= "cast-target", "kan inte avbrytas: ingen varning")
	ns.Procs:Update()
	check(bar.text:GetText():find("kan inte avbrytas", 1, true), "visar att den inte kan avbrytas")
	-- secret: bara att fienden castar, spelets timer driver baren
	MOCK.secretMode = true
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	ns.Procs:Update()
	MOCK.secretMode = false
	check(bar:IsShown() and bar.text:GetText():find("castar", 1, true), "secret: " .. bar.text:GetText())
	MOCK.fire("UNIT_SPELLCAST_INTERRUPTED", "target")
	-- vänlig target: inget
	MOCK.units.target = { name = "Vän", hostile = false }
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	ns.Procs:Update()
	check(not bar:IsShown(), "vänlig target ignoreras")
	ns.Bars:SetMode("PVE", true)
	MOCK.casting.target, MOCK.units.target = nil, nil
	MOCK.runTimers()
end)

test("procs: diminishing returns", function()
	MOCK.units.target = { name = "Rogue", hostile = true, guid = "R1" }
	local ev = "UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED"
	MOCK.fire(ev, "target", { category = 1, startTime = MOCK.time, duration = 18 })
	local d = ns.Procs:Diminish("target")
	check(#d == 1 and d[1].text:find("50"), "första: 50 %")
	MOCK.fire(ev, "target", { category = 1, startTime = MOCK.time, duration = 18 })
	check(ns.Procs:Diminish("target")[1].text:find("50"), "samma start räknas inte två gånger")
	MOCK.time = MOCK.time + 2
	MOCK.fire(ev, "target", { category = 1, startTime = MOCK.time, duration = 18 })
	check(ns.Procs:Diminish("target")[1].text:find("25"), "andra: 25 %")
	MOCK.time = MOCK.time + 2
	MOCK.fire(ev, "target", { category = 1, startTime = MOCK.time, duration = 18 })
	check(ns.Procs:Diminish("target")[1].text:find("immun"), "tredje: immun")
	ns.Procs:Update()
	check(ns.Procs.drText:GetText():find("DR:", 1, true), "visas på HUD:en")
	MOCK.time = MOCK.time + 19
	check(#ns.Procs:Diminish("target") == 0, "återställs")
	MOCK.fire(ev, "target", SECRET)
	MOCK.fire(ev, SECRET, { category = 2 })
	MOCK.units.target = nil
end)

test("procs: Blizzards förslag", function()
	local f = _G.FarseerProcassisted
	ns.Procs:Update()
	check(not f:IsShown(), "utan API: dold")
	rawset(_G, "C_AssistedCombat", { GetNextCastSpell = function() return MOCK.known["Lightning Bolt"] end })
	ns.Procs:Update()
	check(f:IsShown(), "med API: visas")
	rawset(_G, "C_AssistedCombat", nil)
	ns.Procs:Update()
	check(not f:IsShown(), "borta igen")
end)

---------------------------------------------------------------------------------------------------
test("totems: utom räckhåll + Totemic Call", function()
	local cb = _G.FarseerTotemicCall
	ns.Totems:ApplyCallButton()
	check(cb:IsShown() and cb:GetAttribute("spell1") == "Totemic Call" and cb:GetAttribute("spell2") == "Totemic Recall",
		"Totemic Call-knapp")
	local function cast(name) MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known[name]) end
	aura({ name = "Strength of Earth", spellId = 777 })
	MOCK.totems[2] = { name = "Strength of Earth Totem", start = MOCK.time, dur = 300 }
	cast("Strength of Earth Totem")
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	MOCK.runTimers()
	ns.Totems:CheckRange()
	check(not ns.Totems:OutOfRange(2), "nysatt: inte utom räckhåll")
	MOCK.time = MOCK.time + 4
	ns.Totems:CheckRange()
	check(not ns.Totems:OutOfRange(2), "buffen på dig")
	clearAuras()
	ns.Totems:CheckRange()
	check(not ns.Totems:OutOfRange(2), "en miss räcker inte")
	ns.Totems:CheckRange()
	check(ns.Totems:OutOfRange(2), "två missar: utom räckhåll")
	check(ns.Alert:Current() == "range-2", "varning: " .. tostring(ns.Alert:Current()))
	check(_G.FarseerTotemEARTH.rangeText:GetText() == "UTOM", "markering på totembaren")
	check(cb.glow:IsShown(), "Totemic Call lyser")
	MOCK.runTimers()
	ns.Totems:CheckRange()
	check(ns.Alert:Current() ~= "range-2", "varnar en gång")
	cast("Totemic Call")
	check(not ns.Totems:OutOfRange(2), "Totemic Call nollställer")
	ns.Totems:UpdateRangeMarks()
	check(not cb.glow:IsShown(), "slutar lysa")
	-- i strid (auror secret): ingenting ändras
	MOCK.combat = true
	ns.Totems:CheckRange()
	ns.Totems:CheckRange()
	check(not ns.Totems:OutOfRange(2), "secret auror: okänt, ingen markering")
	MOCK.combat = false
	-- totem vars buff aldrig setts: inget larm (kan vara fel buff-ID)
	cast("Totemic Recall")
	MOCK.totems[2] = nil
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	MOCK.runTimers()
	MOCK.time = MOCK.time + 2
	MOCK.totems[3] = { name = "Mana Spring Totem", start = MOCK.time, dur = 300 }
	cast("Mana Spring Totem")
	MOCK.fire("PLAYER_TOTEM_UPDATE", 3)
	MOCK.runTimers()
	MOCK.time = MOCK.time + 5
	for _ = 1, 3 do ns.Totems:CheckRange() end
	check(not ns.Totems:OutOfRange(3), "aldrig sedd buff: inget larm")
	cast("Totemic Recall")
	MOCK.totems[3] = nil
	MOCK.fire("PLAYER_TOTEM_UPDATE", 3)
	MOCK.runTimers()
	-- knappen av
	ns.char.totemAlerts.callButton = false
	ns.Totems:ApplyCallButton()
	check(not cb:IsShown(), "knappen kan stängas av")
	ns.char.totemAlerts.callButton = true
	ns.Totems:ApplyCallButton()
end)

---------------------------------------------------------------------------------------------------
test("spec: avkänning och profilbyte", function()
	local sc = ns.char.spec
	local pts = { 5, 31, 15 }
	rawset(_G, "GetTalentTabInfo", function(i) return "Tab" .. i, "icon", pts[i], "file" end)
	check(ns.Spec:Detect() == "enhancement", "vanilla-format: enhancement")
	rawset(_G, "GetTalentTabInfo", function(i) return 100 + i, "Tab", "desc", 1234, pts[i] end)
	check(ns.Spec:Detect() == "enhancement", "senare format: enhancement")
	pts = { 31, 20, 0 }
	check(ns.Spec:Detect() == "elemental", "elemental")
	pts = { 10, 10, 0 }
	local spec, how = ns.Spec:Detect()
	check(spec == "enhancement" and how:find("Stormstrike"), "lika: talangen avgör: " .. tostring(how))
	-- profil per spec
	ns.Profiles:Save("EnhProf")
	sc.profiles.enhancement = "EnhProf"
	sc.last = "elemental"
	ns.char.profile = nil
	ns.char.bisSpec = "elemental"
	pts = { 0, 31, 20 }
	ns.Spec:Check()
	check(sc.last == "enhancement", "spec sparad")
	check(ns.char.bisSpec == "enhancement", "BiS-spec bytt")
	check(ns.char.profile == "EnhProf", "profilen laddad: " .. tostring(ns.char.profile))
	-- i strid: väntar
	pts = { 31, 0, 20 }
	MOCK.combat = true
	ns.Spec:Check()
	check(sc.last == "enhancement", "i strid: väntar")
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(sc.last == "elemental", "efter strid: bytt")
	-- första avkänningen laddar ingen profil
	sc.last = nil
	sc.profiles.elemental = "EnhProf"
	ns.char.profile = nil
	ns.Spec:Check()
	check(sc.last == "elemental" and ns.char.profile == nil, "första gången: ingen profil")
	-- av
	sc.auto = false
	pts = { 0, 31, 0 }
	ns.Spec:Check()
	check(sc.last == "elemental", "avstängd")
	sc.auto = true
	sc.profiles.elemental, sc.profiles.enhancement = "", ""
	ns.Profiles:Delete("EnhProf")
	rawset(_G, "GetTalentTabInfo", nil)
	ns.char.bisSpec = "elemental"
end)

---------------------------------------------------------------------------------------------------
test("click-cast: mallar", function()
	check(not ns.ClickCast:Available(), "utan C_ClickBindings: inte tillgänglig")
	local ok, _, _, err = ns.ClickCast:Apply("heal_mods")
	check(not ok and err:find("Click Casting"), "säger ifrån: " .. tostring(err))
	local profile = {
		{ type = 3, actionID = 1, button = "LeftButton", modifiers = 0 },
		{ type = 3, actionID = 2, button = "RightButton", modifiers = 0 },
	}
	local MAP = { [1] = "ALT", [2] = "CTRL", [4] = "SHIFT", [8] = "LALT", [16] = "RALT" }
	rawset(_G, "C_ClickBindings", {
		GetProfileInfo = function() return profile end,
		SetProfileByInfo = function(list) profile = list end,
		GetStringFromModifiers = function(m) return MAP[m] or "" end,
	})
	check(ns.ClickCast:Mask("shift-ctrl") == 6, "modifierare läses ur klienten: " .. tostring(ns.ClickCast:Mask("shift-ctrl")))
	local n, missing
	ok, n, missing = ns.ClickCast:Apply("heal_mods")
	check(ok and n == 7 and #missing == 0, "7 bindningar: " .. tostring(n))
	check(#profile == 9, "vanligt klick behålls (2 + 7): " .. #profile)
	local found = false
	for _, b in ipairs(profile) do
		if b.button == "LeftButton" and b.modifiers == 4 and b.actionID == MOCK.known["Lesser Healing Wave"] then found = true end
	end
	check(found, "Shift + vänster = Lesser Healing Wave")
	check(ns.char.clickBackup and #ns.char.clickBackup == 2, "spelets profil sparad")
	-- direktklick ersätter vanligt klick
	ok = ns.ClickCast:Apply("heal_direct")
	local plainLeft
	for _, b in ipairs(profile) do if b.button == "LeftButton" and b.modifiers == 0 then plainLeft = b end end
	check(ok and plainLeft and plainLeft.type == 1, "vänster = heal")
	check(#ns.char.clickBackup == 2, "backupen är den första")
	ok = ns.ClickCast:Restore()
	check(ok and #profile == 2 and profile[1].actionID == 1, "återställd")
	check(ns.char.clickBackup == nil, "backup borta")
	-- i strid och okända spells
	MOCK.combat = true
	check(not ns.ClickCast:Apply("offheal"), "inte i strid")
	MOCK.combat = false
	MOCK.unlearn("Cure Disease")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	ok, n, missing = ns.ClickCast:Apply("offheal")
	check(ok and n == 3 and missing[1] == "Cure Disease", "okänd spell hoppas över")
	ns.ClickCast:Restore()
	MOCK.learn("Cure Disease")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	-- klienten sparar inte: säger ifrån
	C_ClickBindings.SetProfileByInfo = function() end
	ok, _, _, err = ns.ClickCast:Apply("heal_mods")
	check(not ok and err:find("sparade inte"), "läser tillbaka: " .. tostring(err))
	C_ClickBindings.SetProfileByInfo = function() error("ADDON_ACTION_FORBIDDEN") end
	ok, _, _, err = ns.ClickCast:Apply("heal_mods")
	check(not ok and err:find("nekade"), "nekad: " .. tostring(err))
	ns.char.clickBackup = nil
	check(ns.ClickCast:Describe({ "LeftButton", "shift-ctrl", "Chain Heal" }) == "Shift+Ctrl + Vänster: Chain Heal", "beskrivning: "
		.. ns.ClickCast:Describe({ "LeftButton", "shift-ctrl", "Chain Heal" }))
	rawset(_G, "C_ClickBindings", nil)
end)

---------------------------------------------------------------------------------------------------
test("raid: totemfördelning", function()
	check(#ns.RaidTotems:Plan() == 1, "solo: bara du")
	MOCK.group = 3
	MOCK.units.party1 = { name = "Drek", class = "SHAMAN" }
	MOCK.units.party2 = { name = "Grom", class = "WARRIOR" }
	local plan = ns.RaidTotems:Plan()
	check(#plan == 2 and plan[1].shaman == "Drek" and plan[1].kind == "melee", "två shamans, melee-grupp")
	local mine = ns.RaidTotems:Mine(plan)
	check(mine and mine.totems[1] == "Stoneskin Totem", "du får andra setet: " .. tostring(mine and mine.totems[1]))
	check(plan[1].totems[4] == "Windfury Totem", "första får Windfury")
	local lines = ns.RaidTotems:Lines(plan)
	check(#lines == 2 and lines[2]:find("Thrall: Stoneskin, Flametongue", 1, true), "text: " .. tostring(lines[2]))
	MOCK.multicast = {}
	local ok = ns.RaidTotems:LoadMine()
	check(ok and MOCK.multicast[ns.Totems:MultiCastAction(1, 2)] == MOCK.known["Stoneskin Totem"], "ditt set i Call")
	MOCK.chat = {}
	ok = ns.RaidTotems:Send()
	check(ok and #MOCK.chat == 2 and MOCK.chat[1][2] == "PARTY", "skickat i gruppchatten")
	MOCK.chatBlocked = true
	local err
	ok, err = ns.RaidTotems:Send()
	check(not ok and err:find("kopiera"), "blockerad chatt: " .. tostring(err))
	MOCK.chatBlocked = nil
	-- raid: grupper
	local roster = {
		{ "Thrall", 1, "SHAMAN" }, { "Grom", 1, "WARRIOR" }, { "Jaina", 2, "MAGE" }, { "Rehgar", 2, "SHAMAN" },
		{ "Ner", 2, "WARLOCK" },
	}
	local realRaid = IsInRaid
	rawset(_G, "IsInRaid", function() return true end)
	rawset(_G, "GetRaidRosterInfo", function(i)
		local r = roster[i]
		if r then return r[1], 0, r[2], 60, r[3], r[3] end
	end)
	MOCK.group = #roster
	plan = ns.RaidTotems:Plan()
	check(#plan == 2 and plan[2].group == 2 and plan[2].kind == "caster", "grupp 2 casters")
	check(plan[2].totems[3] == "Mana Spring Totem", "casters får Mana Spring")
	MOCK.chat = {}
	ns.RaidTotems:Send()
	check(MOCK.chat[1] and MOCK.chat[1][2] == "RAID", "raidchatten")
	rawset(_G, "IsInRaid", realRaid)
	rawset(_G, "GetRaidRosterInfo", nil)
	MOCK.group = 0
	MOCK.units.party1, MOCK.units.party2 = nil, nil
	MOCK.multicast = {}
end)

---------------------------------------------------------------------------------------------------
test("downranking", function()
	local ME = ns.MacroEngine
	local body = ME:Render(ME:Template("res_lhw_low"))
	check(body:find("Lesser Healing Wave(Rank 3)", 1, true), "standardrank 3: " .. body)
	ME:SetDownRank("Lesser Healing Wave", 2)
	body = ME:Render(ME:Template("res_lhw_low"))
	check(body:find("Lesser Healing Wave(Rank 2)", 1, true), "vald rank 2")
	local real = C_Spell.GetSpellSubtext
	C_Spell.GetSpellSubtext = function(id) if id == 8008 then return "Rang 2" end return "Rank 1" end
	body = ME:Render(ME:Template("res_lhw_low"))
	check(body:find("(Rang 2)", 1, true), "klientens rank-text: " .. body)
	C_Spell.GetSpellSubtext = real
	local spells = ME:SpellsIn(body)
	check(spells[1] == "Lesser Healing Wave", "parentes rensas för saknas-kollen: " .. tostring(spells[1]))
	local ranks = ME:Ranks("Chain Heal")
	check(#ranks == 3 and ranks[1].rank == 1 and ranks[1].mana == 100, "Chain Heal: 3 ranker med mana")
	check(ME:Render(ME:Template("res_ch_low")):find("Chain Heal(Rank 1)", 1, true), "Chain Heal rank 1")
	ns.db.macros.downrankKick = true
	check(ME:Context().kick == "Earth Shock(Rank 1)", "kick rank 1: " .. ME:Context().kick)
	ns.db.macros.downrankKick = false
	ns.db.macros.ranks = {}
	local ok = ME:CreateFromTemplate("res_hw_low", true)
	check(ok and ME:Exists("FS HW Low"), "makrot skapas")
	ME:Delete("FS HW Low")
end)

---------------------------------------------------------------------------------------------------
test("v1.2: flikar, slash, profiler, secret", function()
	ns.Options:Open()
	for _, id in ipairs({ "alerts", "healing", "raid", "profiles" }) do ns.UI.SelectTab(id) end
	rawset(_G, "C_ClickBindings", { GetProfileInfo = function() return {} end, SetProfileByInfo = function() end })
	ns.UI.SelectTab("healing")
	rawset(_G, "C_ClickBindings", nil)
	ns.UI.SelectTab("raid")
	for _, c in ipairs({ "spec", "click", "click heal_mods", "click restore", "raid", "raid send", "help" }) do
		SlashCmdList.FARSEER(c)
	end
	ns.Options:Toggle()
	-- profiler tar med procs men inte spec eller click-cast-backup
	local snap = ns.Profiles:Snapshot()
	check(snap.char.procs ~= nil, "procs i profilen")
	check(snap.char.spec == nil and snap.char.clickBackup == nil, "spec/backup inte i profilen")
	-- allt i strid med secret-värden: inga fel
	MOCK.combat, MOCK.secretMode = true, true
	MOCK.units.target = { name = "X", hostile = true }
	MOCK.learn("Maelstrom Weapon")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	aura({ name = "Maelstrom Weapon", spellId = 408505, applications = 2 })
	ns.Procs:Update()
	ns.Procs:CheckMana()
	ns.Totems:CheckRange()
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	MOCK.fire("SPELL_UPDATE_COOLDOWN", SECRET)
	MOCK.fire("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", "target", { category = SECRET })
	ns.Procs:Update()
	MOCK.combat, MOCK.secretMode = false, false
	MOCK.unlearn("Maelstrom Weapon")
	clearAuras()
	MOCK.units.target = nil
	ns.Spellbook:Scan()
	MOCK.runTimers()
	ns.Procs:Update()
end)

---------------------------------------------------------------------------------------------------
test("granskning: profiler behåller tabeller, återställning, delade makron", function()
	-- En profil skrivs in i befintliga tabeller (flikar och flyttbara ramar har referenser till dem)
	local procsRef, barsRef, sitRef = ns.char.procs, ns.char.bars, ns.char.bars.situations
	ns.char.procs.manaPct = 40
	check(ns.Profiles:Save("granskning"), "profil sparad")
	ns.char.procs.manaPct = 10
	check(ns.Profiles:Load("granskning"), "profil laddad")
	check(ns.char.procs == procsRef and ns.char.bars == barsRef and ns.char.bars.situations == sitRef, "samma tabeller efter laddning")
	check(ns.char.procs.manaPct == 40, "värdet från profilen")
	ns.Profiles:Delete("granskning")
	ns.char.procs.manaPct = 25
	-- ns.assign: tar bort nycklar som inte finns i källan, behåller undertabeller
	local dst = { a = 1, sub = { x = 1, y = 2 }, gone = true }
	local sub = dst.sub
	ns.assign(dst, { a = 2, sub = { x = 3 } })
	check(dst.a == 2 and dst.sub == sub and dst.sub.x == 3 and dst.sub.y == nil and dst.gone == nil, "assign")
	-- Kontomakron: en annan karaktär skriver inte över dem automatiskt
	ns.db.macros.perCharacter = false
	ns.MacroEngine:CreateFromTemplate(ns.MACRO_TEMPLATES[1].id, true)
	local name = ns.MACRO_TEMPLATES[1].name
	local idx = ns.MacroEngine:Exists(name)
	check(idx ~= nil, "kontomakro skapat")
	ns.db.macros.owner = "Någon-Annan"
	EditMacro(idx, name, nil, "/say gammalt")
	ns.MacroEngine:RefreshExisting(true)
	check(ns.trim(GetMacroBody(name)) == "/say gammalt", "auto rör inte andras kontomakron")
	check(ns.MacroEngine:RefreshExisting() > 0 and ns.trim(GetMacroBody(name)) ~= "/say gammalt", "manuell uppdatering tar över")
	check(ns.MacroEngine:OwnsAccountMacros(), "äger kontomakron efter manuell uppdatering")
	-- Call-setets ordning: Earth, Fire, Water, Air
	check(ns.Totems:SlotOffset(ns.SLOT.EARTH) == 1 and ns.Totems:SlotOffset(ns.SLOT.FIRE) == 2
		and ns.Totems:SlotOffset(ns.SLOT.WATER) == 3 and ns.Totems:SlotOffset(ns.SLOT.AIR) == 4, "multicast-ordning")
	rawset(_G, "TOTEM_PRIORITIES", { 1, 2, 3, 4 })
	check(ns.Totems:SlotOffset(ns.SLOT.EARTH) == 2, "klientens TOTEM_PRIORITIES används")
	rawset(_G, "TOTEM_PRIORITIES", nil)
	-- Bekräftelse med % i texten
	ns.UI.Confirm("Ta bort 100% av \"x\"?", function() end)
	check(StaticPopupDialogs.FARSEER_CONFIRM.text == "Ta bort 100%% av \"x\"?", "% skyddas i bekräftelsen")
	-- Enemy cast: SUCCEEDED (channel-start) avslutar inte baren
	ns.char.procs.enemyCasts = true
	MOCK.units.target = { name = "X", hostile = true }
	MOCK.casting.target = { name = "Drain Life", channel = true, start = GetTime(), ends = GetTime() + 5 }
	MOCK.fire("UNIT_SPELLCAST_CHANNEL_START", "target")
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "target")
	check(ns.Procs:CurrentCast() ~= nil, "channel kvar efter SUCCEEDED")
	MOCK.fire("UNIT_SPELLCAST_CHANNEL_STOP", "target")
	check(ns.Procs:CurrentCast() == nil, "borta efter CHANNEL_STOP")
	MOCK.casting.target = nil
	MOCK.units.target = nil
	-- Glöden följer knappens storlek
	local f = CreateFrame("Button", nil, UIParent)
	local g = ns.addGlow(f)
	f:SetSize(40, 40)
	check(g ~= nil, "glöd skapad")
end)
