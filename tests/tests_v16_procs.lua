-- Tester för v1.6 (procs): Clearcasting/Stormstrike/Flurry, Mana Tide/Rage of the Farseer-timer och
-- meddelande, DBM/BigWigs -> kontratotem, pull-påminnelse, andningsvarning.

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function aura(t)
	MOCK.auras.player = MOCK.auras.player or {}
	table.insert(MOCK.auras.player, t)
	return t
end
local function clearAuras() MOCK.auras.player = {} end

-- Spelar in Alert:Flash-anrop (varningen göms i samma runTimers, så Current() räcker inte)
local function recordFlashes()
	local list = {}
	local real = ns.Alert.Flash
	ns.Alert.Flash = function(self, key, spell, title, text, ...)
		table.insert(list, { key = key, spell = spell, title = title, text = text })
		return real(self, key, spell, title, text, ...)
	end
	return list, function() ns.Alert.Flash = real end
end

local dbmCbs = {}   -- DBM kopplas bara en gång: callbacks delas mellan testerna

local function relearn(name)
	MOCK.learn(name, MOCK.spellIDs[name])
	ns.Spellbook:Scan()
	MOCK.runTimers()
end
local function unlearn(name)
	MOCK.unlearn(name)
	ns.Spellbook:Scan()
	MOCK.runTimers()
end

---------------------------------------------------------------------------------------------------
test("v1.6 procs: Clearcasting, Stormstrike, Flurry", function()
	local PC, c = ns.Procs, ns.char.procs
	local cc, ss, fl = _G.FarseerProcclearcast, _G.FarseerProcstormstrike, _G.FarseerProcflurry
	check(cc and ss and fl, "ikonerna finns")
	clearAuras()
	PC:Update()
	check(not cc:IsShown() and not ss:IsShown() and not fl:IsShown(), "inga buffar: dolda")
	aura({ name = "Clearcasting", spellId = 16246, applications = 1, icon = 555, auraInstanceID = 81 })
	PC:Update()
	check(cc:IsShown(), "Clearcasting visas")
	check(cc.count:GetText() == "", "en laddning: ingen siffra")
	-- Stormstrike: bara namnet (ID okänt)
	aura({ name = "Stormstrike", spellId = 999777, auraInstanceID = 82 })
	PC:Update()
	check(ss:IsShown(), "Stormstrike visas (namnet)")
	check(ss.__points[1] and ss.__points[1][4] > cc.__points[1][4], "Stormstrike läggs efter Clearcasting")
	-- Flurry är av som standard
	local f = aura({ name = "Flurry", spellId = 16280, applications = 3, auraInstanceID = 83 })
	PC:Update()
	check(not fl:IsShown(), "Flurry av som standard")
	c.flurry = true
	PC:Update()
	check(fl:IsShown() and fl.count:GetText() == "3", "Flurry 3 laddningar: " .. tostring(fl.count:GetText()))
	f.applications = 2
	PC:Update()
	check(fl.count:GetText() == "2", "laddningarna räknas ned")
	-- secret i strid: fälten är secret, auran finns ändå
	MOCK.combat, MOCK.secretMode = true, true
	PC:Update()
	check(cc:IsShown() and fl:IsShown(), "secret: Clearcasting/Flurry kvar (ID-uppslag)")
	check(fl.count:GetText() == "<secret>", "secret-laddningar till texten: " .. tostring(fl.count:GetText()))
	check(ss:IsShown(), "secret: Stormstrike kvar via auraInstanceID")
	MOCK.combat, MOCK.secretMode = false, false
	-- hela auran secret: finns, men inget går att läsa
	local realGet = C_UnitAuras.GetPlayerAuraBySpellID
	C_UnitAuras.GetPlayerAuraBySpellID = function(id) if id == 16246 then return SECRET end return nil end
	PC:Update()
	check(cc:IsShown() and cc.count:GetText() == "", "secret aura: visas utan siffra")
	C_UnitAuras.GetPlayerAuraBySpellID = realGet
	-- avstängda
	c.clearcast, c.stormstrike, c.flurry = false, false, false
	PC:Update()
	check(not cc:IsShown() and not ss:IsShown() and not fl:IsShown(), "avstängda: dolda")
	c.clearcast, c.stormstrike = true, true
	-- Stormstrike kräver att du kan Stormstrike
	unlearn("Stormstrike")
	PC:Update()
	check(not ss:IsShown(), "kan inte Stormstrike: dold")
	relearn("Stormstrike")
	PC:Update()
	check(ss:IsShown(), "kan Stormstrike igen: visas")
	clearAuras()
	PC:Update()
	check(not cc:IsShown() and not ss:IsShown(), "buffarna borta: dolda")
	-- ikonen: buffens -> spell-ID -> fil
	local def = PC.PROCS[1]
	check(PC:ProcIcon(def, { icon = 4242 }) == 4242, "buffens ikon först")
	check(PC:ProcIcon(def, SECRET) ~= nil, "secret aura: ikon via ID")
	local tex = C_Spell.GetSpellTexture
	C_Spell.GetSpellTexture = function() return nil end
	check(PC:ProcIcon(def, nil) == "Interface\\Icons\\Spell_Shadow_ManaBurn", "Clearcasting-filen sist")
	check(PC:ProcIcon(PC.PROCS[2], nil) == "Interface\\Icons\\Ability_Shaman_Stormstrike", "Stormstrike-filen sist")
	check(PC:ProcIcon(PC.PROCS[3], nil) == "Interface\\Icons\\Ability_GhoulFrenzy", "Flurry-filen sist")
	C_Spell.GetSpellTexture = tex
	c.flurry = false
end)

---------------------------------------------------------------------------------------------------
test("v1.6 procs: Mana Tide / Rage of the Farseer-timer och meddelande", function()
	local PC, c = ns.Procs, ns.char.procs
	local mt, rf = _G.FarseerProcmanatide, _G.FarseerProcfarseer
	local function cast(name, unit) MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", unit or "player", "g", MOCK.known[name]) end
	clearAuras()
	MOCK.chat = {}
	MOCK.group = 3
	c.announce = true
	cast("Mana Tide Totem")
	check(PC:TimerLeft("manatide") == 12, "Mana Tide 12 s: " .. tostring(PC:TimerLeft("manatide")))
	PC:Update()
	check(mt:IsShown() and mt.timer:GetText() == "12", "ikon med 12: " .. tostring(mt.timer:GetText()))
	check(#MOCK.chat == 1 and MOCK.chat[1][1] == "Mana Tide Totem up (12 s)" and MOCK.chat[1][2] == "PARTY",
		"meddelande i gruppen: " .. tostring(MOCK.chat[1] and MOCK.chat[1][1]))
	cast("Mana Tide Totem")
	check(#MOCK.chat == 1, "samma cast meddelas en gång")
	MOCK.time = MOCK.time + 5
	PC:Update()
	check(mt.timer:GetText() == "7", "räknar ned: " .. tostring(mt.timer:GetText()))
	MOCK.time = MOCK.time + 8
	PC:Update()
	check(not mt:IsShown() and PC:TimerLeft("manatide") == nil, "slut: dold")
	-- Rage of the Farseer: buffens tid när den går att läsa
	aura({ name = "Rage of the Farseer", spellId = 425336, duration = 20, expirationTime = MOCK.time + 20 })
	cast("Rage of the Farseer")
	check(PC:TimerLeft("farseer") == 20, "tiden ur buffen: " .. tostring(PC:TimerLeft("farseer")))
	check(#MOCK.chat == 2 and MOCK.chat[2][1] == "Rage of the Farseer up", "Rage-meddelande")
	PC:Update()
	check(rf:IsShown() and rf.timer:GetText() == "20", "Rage-ikonen")
	clearAuras()
	MOCK.time = MOCK.time + 21
	PC:Update()
	check(not rf:IsShown(), "Rage slut")
	cast("Rage of the Farseer")
	check(PC:TimerLeft("farseer") == 15, "utan läsbar buff: 15 s")
	-- buffen kommer strax efter casten: tiden läses om
	aura({ name = "Rage of the Farseer", spellId = 425336, duration = 15, expirationTime = MOCK.time + 14.5 })
	PC:Update()
	check(PC:TimerLeft("farseer") == 14.5, "tiden läses om ur buffen")
	clearAuras()
	MOCK.time = MOCK.time + 16
	PC:Update()
	-- solo, avstängt meddelande, avstängd timer, någon annans cast
	MOCK.chat = {}
	MOCK.group = 0
	cast("Mana Tide Totem")
	check(#MOCK.chat == 0 and PC:TimerLeft("manatide") == 12, "solo: timer men inget meddelande")
	MOCK.time = MOCK.time + 13
	MOCK.group = 3
	c.announce = false
	cast("Mana Tide Totem")
	check(#MOCK.chat == 0, "announce av: inget meddelande")
	MOCK.time = MOCK.time + 13
	PC:Update()
	c.cdTimers = false
	cast("Mana Tide Totem")
	check(PC:TimerLeft("manatide") == nil, "cdTimers av: ingen timer")
	c.cdTimers = true
	cast("Mana Tide Totem", "target")
	check(PC:TimerLeft("manatide") == nil, "target-cast räknas inte")
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", SECRET)
	-- blockerad chatt: inga fel
	c.announce = true
	MOCK.chatBlocked = true
	cast("Mana Tide Totem")
	check(PC:TimerLeft("manatide") == 12, "blockerad chatt: timern ändå")
	MOCK.chatBlocked = nil
	MOCK.time = MOCK.time + 13
	PC:Update()
	c.announce = false
	MOCK.group = 0
	MOCK.chat = {}
end)

---------------------------------------------------------------------------------------------------
test("v1.6 bossmods: DBM-barer -> kontratotem", function()
	local BM, c = ns.BossMods, ns.char.procs
	local cbs = dbmCbs
	rawset(_G, "UnitAffectingCombat", function() return true end)   -- v1.7: bossvarningen visas bara i strid
	rawset(_G, "DBM", { RegisterCallback = function(_, ev, fn) cbs[ev] = fn end })
	MOCK.fire("ADDON_LOADED", "DBM-Core")
	check(type(cbs.DBM_TimerStart) == "function" and type(cbs.DBM_TimerStop) == "function", "DBM-callbacks registrerade")
	check(BM:Hooked() == true, "DBM kopplat")
	MOCK.runTimers()
	local flashes, restore = recordFlashes()
	local start, stop = cbs.DBM_TimerStart, cbs.DBM_TimerStop
	start("DBM_TimerStart", "t1", "Bellowing Roar", 30, 136, "cd", 18431)
	local p = BM:Pending("dbm:t1")
	check(p and p.totem == "Tremor Totem" and p.delay == 26, "schemalagt 4 s innan: " .. tostring(p and p.delay))
	MOCK.runTimers()
	check(#flashes == 1 and flashes[1].title == "TREMOR IN 4s" and flashes[1].spell == "Tremor Totem", "varning: "
		.. tostring(flashes[1] and flashes[1].title))
	check(flashes[1].text:find("Bellowing Roar", 1, true), "barens text i varningen")
	check(BM:Pending("dbm:t1") == nil, "klar")
	-- stopp avbryter
	start("DBM_TimerStart", "t2", "Poison Bolt Volley", 10, 136, "cd")
	check(BM:Pending("dbm:t2") and BM:Pending("dbm:t2").totem == "Poison Cleansing Totem", "gift -> Poison Cleansing")
	stop("DBM_TimerStop", "t2")
	MOCK.runTimers()
	check(#flashes == 1, "stoppad bar: ingen varning")
	-- omstart: bara den senaste schemaläggningen räknas
	start("DBM_TimerStart", "t3", "Psychic Scream", 20, 136, "cd")
	stop("DBM_TimerStop", "t3")
	start("DBM_TimerStart", "t3", "Psychic Scream", 20, 136, "cd")
	start("DBM_TimerStart", "t3", "Psychic Scream", 3, 136, "cd")
	MOCK.runTimers()
	check(#flashes == 2, "omstartad bar varnar en gång: " .. #flashes)
	check(flashes[2].title == "TREMOR IN 3s", "den gamla schemaläggningen ignoreras: " .. tostring(flashes[2].title))
	-- kort bar: direkt, med barens tid
	start("DBM_TimerStart", "t4", "Terrifying Screech", 2, 136, "cast")
	check(BM:Pending("dbm:t4").delay == 0, "kortare än ledtiden: direkt")
	MOCK.runTimers()
	check(flashes[3] and flashes[3].title == "TREMOR IN 2s", "kort bar: " .. tostring(flashes[3] and flashes[3].title))
	-- spellnamnet räcker
	MOCK.spellNames[777001] = "Plague Cloud"
	start("DBM_TimerStart", "t5", "Next ability", 15, 136, "cd", 777001)
	check(BM:Pending("dbm:t5") and BM:Pending("dbm:t5").totem == "Disease Cleansing Totem", "spellnamn -> Disease Cleansing")
	stop("DBM_TimerStop", "t5")
	MOCK.spellNames[777001] = nil
	-- inget nyckelord
	start("DBM_TimerStart", "t6", "Cleave", 8, 136, "cd")
	check(BM:Pending("dbm:t6") == nil, "Cleave: inget")
	-- totemet okänt
	unlearn("Poison Cleansing Totem")
	start("DBM_TimerStart", "t7", "Venom Spit", 8, 136, "cd")
	check(BM:Pending("dbm:t7") == nil, "kan inte totemet: inget")
	relearn("Poison Cleansing Totem")
	-- avstängt
	c.bossmods = false
	start("DBM_TimerStart", "t8", "Fear", 8, 136, "cd")
	check(BM:Pending("dbm:t8") == nil, "bossmods av: inget")
	c.bossmods = true
	-- avstängt efter schemaläggning
	start("DBM_TimerStart", "t9", "Fear", 8, 136, "cd")
	c.bossmods = false
	MOCK.runTimers()
	check(#flashes == 3, "avstängt innan den gick: ingen varning")
	c.bossmods = true
	-- egen ledtid
	c.bossLead = 6
	start("DBM_TimerStart", "t10", "Fear", 20, 136, "cd")
	check(BM:Pending("dbm:t10").delay == 14, "bossLead 6")
	MOCK.runTimers()
	check(flashes[4] and flashes[4].title == "TREMOR IN 6s", "6 s: " .. tostring(flashes[4] and flashes[4].title))
	c.bossLead = 4
	-- secret-värden och skräp: inga fel
	start("DBM_TimerStart", SECRET, SECRET, SECRET)
	start("DBM_TimerStart", nil)
	stop("DBM_TimerStop", SECRET)
	restore()
	rawset(_G, "DBM", nil)
	rawset(_G, "UnitAffectingCombat", nil)
end)

---------------------------------------------------------------------------------------------------
test("v1.6 bossmods: BigWigs-barer och pull-påminnelse", function()
	local BM, c = ns.BossMods, ns.char.procs
	local msgs = {}
	rawset(_G, "UnitAffectingCombat", function() return true end)   -- v1.7: bossvarningen visas bara i strid
	rawset(_G, "BigWigsLoader", { RegisterMessage = function(_, msg, fn) msgs[msg] = fn end })
	MOCK.fire("ADDON_LOADED", "BigWigs")
	check(msgs.BigWigs_StartBar and msgs.BigWigs_StopBar and msgs.BigWigs_StartPull, "BigWigs-meddelanden registrerade")
	local _, bw = BM:Hooked()
	check(bw == true, "BigWigs kopplat")
	MOCK.runTimers()
	local flashes, restore = recordFlashes()
	local mod = {}
	local id = "bw:" .. tostring(mod) .. ":"
	msgs.BigWigs_StartBar("BigWigs_StartBar", mod, 12345, "Psychic Scream", 20, 136)
	check(BM:Pending(id .. "Psychic Scream") and BM:Pending(id .. "Psychic Scream").delay == 16, "schemalagt")
	MOCK.runTimers()
	check(#flashes == 1 and flashes[1].title == "TREMOR IN 4s", "BigWigs-varning")
	msgs.BigWigs_StartBar("BigWigs_StartBar", mod, "venom", "Venom Spit", 20, 136)
	msgs.BigWigs_StopBar("BigWigs_StopBar", mod, "Venom Spit")
	MOCK.runTimers()
	check(#flashes == 1, "StopBar avbryter")
	msgs.BigWigs_StartBar("BigWigs_StartBar", mod, "fear", "Fear", 20, 136)
	msgs.BigWigs_StopBars("BigWigs_StopBars", mod)
	MOCK.runTimers()
	check(#flashes == 1, "StopBars (wipe) avbryter")
	-- pull: vad saknas
	local RE, TO = ns.Reminders, ns.Totems
	local realShield, realImbue, realCount = RE.ShieldUp, RE.Imbue, TO.Count
	local shield, imbue, count = false, true, 0
	RE.ShieldUp = function() return shield end
	RE.Imbue = function() return imbue end
	TO.Count = function() return count end
	MOCK.time = MOCK.time + 10
	msgs.BigWigs_StartPull("BigWigs_StartPull", mod, 10)
	local last = flashes[#flashes]
	check(#flashes == 2 and last.key == "pull" and last.title == "PULL IN 10s", "pull-varning: " .. tostring(last and last.title))
	check(last.text == "Missing: no shield, no totems.", "saknas: " .. tostring(last.text))
	-- DBM och BigWigs samtidigt: en varning
	local cbs = dbmCbs
	check(cbs.DBM_TimerStart ~= nil, "DBM kopplat sedan förra testet")
	cbs.DBM_TimerStart("DBM_TimerStart", "pull", "Pull in", 10, nil, "pull")
	check(#flashes == 2, "en varning per pull")
	-- allt klart: ingen varning
	MOCK.time = MOCK.time + 10
	shield, imbue, count = true, true, 3
	msgs.BigWigs_StartPull("BigWigs_StartPull", mod, 10)
	check(#flashes == 2, "allt klart: ingen varning")
	-- okänt (secret) räknas inte som saknat
	MOCK.time = MOCK.time + 10
	shield, imbue = nil, nil
	msgs.BigWigs_StartPull("BigWigs_StartPull", mod, 10)
	check(#flashes == 2, "okänt: ingen varning")
	-- DBM-pull
	MOCK.time = MOCK.time + 10
	imbue = false
	cbs.DBM_TimerStart("DBM_TimerStart", "pull", "Pull in", 8, nil, "pull")
	last = flashes[#flashes]
	check(#flashes == 3 and last.title == "PULL IN 8s" and last.text == "Missing: no weapon imbue.", "DBM-pull: "
		.. tostring(last and last.text))
	-- avstängt
	MOCK.time = MOCK.time + 10
	c.pullCheck = false
	msgs.BigWigs_StartPull("BigWigs_StartPull", mod, 10)
	check(#flashes == 3, "pullCheck av: ingen varning")
	c.pullCheck = true
	RE.ShieldUp, RE.Imbue, TO.Count = realShield, realImbue, realCount
	restore()
	rawset(_G, "BigWigsLoader", nil)
	rawset(_G, "DBM", nil)
	rawset(_G, "UnitAffectingCombat", nil)
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v1.6 procs: andning och Water Breathing", function()
	local PC, c = ns.Procs, ns.char.procs
	MOCK.runTimers()
	local flashes, restore = recordFlashes()
	MOCK.itemCounts[17057] = 5
	MOCK.fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
	check(PC:BreathDelay() == 40, "varnar 20 s innan: " .. tostring(PC:BreathDelay()))
	MOCK.runTimers()
	local f = flashes[1]
	check(f and f.key == "breath" and f.title == "BREATH RUNNING OUT", "andningsvarning")
	check(f and f.spell == "Water Breathing" and f.text:find("Shiny Fish Scale: 5", 1, true), "föreslår Water Breathing: "
		.. tostring(f and f.text))
	-- stopp avbryter
	MOCK.fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
	MOCK.fire("MIRROR_TIMER_STOP", "BREATH")
	MOCK.runTimers()
	check(#flashes == 1, "upp till ytan: ingen varning")
	-- andra timers, pausad, avstängd
	MOCK.fire("MIRROR_TIMER_START", "EXHAUSTION", 60000, 60000, -1, 0, "Fatigue")
	MOCK.fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 1, "Breath")
	c.breath = false
	MOCK.fire("MIRROR_TIMER_START", "BREATH", 60000, 60000, -1, 0, "Breath")
	MOCK.runTimers()
	check(#flashes == 1, "fatigue, pausad och avstängd: ingen varning")
	c.breath = true
	-- inga fjäll
	MOCK.itemCounts[17057] = 0
	MOCK.fire("MIRROR_TIMER_START", "BREATH", 10000, 60000, -1, 0, "Breath")
	check(PC:BreathDelay() == 0, "lite luft kvar: direkt")
	MOCK.runTimers()
	f = flashes[2]
	check(f and f.text:find("no Shiny Fish Scale", 1, true), "inga fjäll: " .. tostring(f and f.text))
	-- kan inte Water Breathing
	unlearn("Water Breathing")
	MOCK.fire("MIRROR_TIMER_START", "BREATH", 10000, 60000, -1, 0, "Breath")
	MOCK.runTimers()
	f = flashes[3]
	check(f and f.text == "Swim up for air.", "utan spellen: " .. tostring(f and f.text))
	relearn("Water Breathing")
	-- secret värden: varnar direkt, inga fel
	MOCK.fire("MIRROR_TIMER_START", "BREATH", SECRET, SECRET, SECRET, SECRET, SECRET)
	MOCK.runTimers()
	check(#flashes == 4, "secret: varnar ändå")
	-- Water Breathing går snart ut medan du simmar
	MOCK.itemCounts[17057] = 3
	rawset(_G, "IsSwimming", function() return true end)
	local a = aura({ name = "Water Breathing", spellId = 131, expirationTime = MOCK.time + 45, auraInstanceID = 91 })
	PC:CheckWaterBreathing()
	f = flashes[5]
	check(f and f.key == "waterbreathing" and f.title == "WATER BREATHING ENDING", "Water Breathing går ut")
	check(f and f.text:find("45 s left", 1, true), "tid kvar: " .. tostring(f and f.text))
	PC:CheckWaterBreathing()
	check(#flashes == 5, "en gång per buff")
	a.auraInstanceID, a.expirationTime = 92, MOCK.time + 30
	PC:CheckWaterBreathing()
	check(#flashes == 6, "ny buff: ny varning")
	a.auraInstanceID, a.expirationTime = 93, MOCK.time + 300
	PC:CheckWaterBreathing()
	check(#flashes == 6, "gott om tid: ingen varning")
	a.expirationTime = MOCK.time + 30
	MOCK.combat = true
	PC:CheckWaterBreathing()
	check(#flashes == 6, "i strid: ingen varning")
	MOCK.combat = false
	rawset(_G, "IsSwimming", function() return false end)
	PC:CheckWaterBreathing()
	check(#flashes == 6, "simmar inte: ingen varning")
	rawset(_G, "IsSwimming", function() return true end)
	MOCK.tick(1)
	check(#flashes == 7, "tickern kollar")
	rawset(_G, "IsSwimming", nil)
	clearAuras()
	MOCK.itemCounts[17057] = nil
	restore()
	MOCK.runTimers()
end)

test("v16: Stormstrike som debuff på target (Classic-stil)", function()
	local PC = ns.Procs
	local old = C_UnitAuras.GetAuraDataByIndex
	C_UnitAuras.GetAuraDataByIndex = function(unit, i, filter)
		if unit == "target" and i == 1 and filter == "HARMFUL|PLAYER" then return { name = "Stormstrike", applications = 0 } end
	end
	local a = PC.TargetDebuff("Stormstrike")
	check(a and a.name == "Stormstrike", "hittar din Stormstrike-debuff på target")
	check(PC.TargetDebuff("Flame Shock") == nil, "annat namn -> nil")
	C_UnitAuras.GetAuraDataByIndex = old
end)
