-- Tester för v1.7 (procs/bossmods): Stormstrike när target-auran är secret, PvP-kick bara när något är
-- redo, DBM-timertyper/hela ord/spell-ID, totem redan nere, gamla varningar efter wipe, pause/resume/
-- update, off-hand i pull-checken, andning med secret-värden, Mana Tide via totemspårningen, chatt under
-- encounter, stabil ikonrad, prioriteter.

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function aura(t)
	MOCK.auras.player = MOCK.auras.player or {}
	table.insert(MOCK.auras.player, t)
	return t
end
local function clearAuras() MOCK.auras.player = {} end

-- Spelar in Alert:Flash-anrop, med prioriteten
local function recordFlashes()
	local list = {}
	local real = ns.Alert.Flash
	ns.Alert.Flash = function(self, key, spell, title, text, color, seconds, prio, ...)
		table.insert(list, { key = key, spell = spell, title = title, text = text, prio = prio })
		return real(self, key, spell, title, text, color, seconds, prio, ...)
	end
	return list, function() ns.Alert.Flash = real end
end

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

-- Byter en funktion i en tabell och ger tillbaka en återställare
local function stub(t, k, fn)
	local old = t[k]
	t[k] = fn
	return function() t[k] = old end
end

---------------------------------------------------------------------------------------------------
test("v1.7 procs: Stormstrike-debuffen läses med pcall (secret = okänt)", function()
	local PC = ns.Procs
	local mode = "none"
	local restore = stub(C_UnitAuras, "GetAuraDataByIndex", function(unit, i, filter)
		if unit ~= "target" or filter ~= "HARMFUL|PLAYER" then return nil end
		if mode == "error" then error("secret aura") end
		if mode == "secret" then return SECRET end
		if mode == "secretname" and i == 1 then return { name = SECRET } end
		if mode == "found" and i == 1 then return { name = "Stormstrike", auraInstanceID = 555 } end
		if mode == "other" and i == 1 then return { name = "Flame Shock" } end
		return nil
	end)
	mode = "error"
	check(PC.TargetDebuff("Stormstrike") == PC.UNKNOWN, "blockerat uppslag: okänt")
	mode = "secret"
	check(PC.TargetDebuff("Stormstrike") == PC.UNKNOWN, "secret aura: okänt")
	mode = "secretname"
	check(PC.TargetDebuff("Stormstrike") == PC.UNKNOWN, "secret namn: okänt")
	mode = "found"
	local a = PC.TargetDebuff("Stormstrike")
	check(type(a) == "table" and a.name == "Stormstrike", "läsbar: auran")
	mode = "other"
	check(PC.TargetDebuff("Stormstrike") == nil, "läsbar, annan debuff: nil")
	mode = "none"
	check(PC.TargetDebuff("Stormstrike") == nil, "läsbar, inga debuffar: nil")

	-- Ikonen: läsbar debuff visas, okänt behåller läget
	local ss, def = _G.FarseerProcstormstrike, PC.PROCS[2]
	check(def.key == "stormstrike", "Stormstrike-definitionen")
	-- en annan buff på dig med samma auraInstanceID som target-debuffen: får inte förväxlas
	clearAuras()
	aura({ name = "Other Buff", spellId = 4711, auraInstanceID = 555 })
	mode = "found"
	PC:UpdateProc(def)
	check(ss:IsShown(), "debuff på target: visas")
	mode = "error"
	PC:UpdateProc(def)
	check(ss:IsShown(), "okänt: ikonen står kvar")
	mode = "none"
	PC:UpdateProc(def)
	check(not ss:IsShown(), "debuffen borta: dold (target-aurans ID slogs inte upp på player)")
	mode = "secret"
	PC:UpdateProc(def)
	check(not ss:IsShown(), "okänt: dold ikon förblir dold")
	clearAuras()
	restore()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: egen Stormstrike-cast visar ikonen 12 s", function()
	local PC = ns.Procs
	local ss, def = _G.FarseerProcstormstrike, PC.PROCS[2]
	clearAuras()
	local mode = "secret"
	local restore = stub(C_UnitAuras, "GetAuraDataByIndex", function(unit)
		if unit ~= "target" then return nil end
		if mode == "secret" then return SECRET end
		return nil
	end)
	PC:UpdateProc(def)
	check(not ss:IsShown(), "före casten: dold")
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Stormstrike"])
	check(ss:IsShown(), "casten: visas direkt")
	check(PC:StormstrikeLeft() == 12, "12 s: " .. tostring(PC:StormstrikeLeft()))
	check(ss.count:GetText() == "", "ingen siffra (laddningarna går inte att följa)")
	MOCK.time = MOCK.time + 11
	PC:UpdateProc(def)
	check(ss:IsShown(), "11 s, okänd aura: kvar")
	MOCK.time = MOCK.time + 2
	PC:UpdateProc(def)
	check(not ss:IsShown() and PC:StormstrikeLeft() == nil, "12 s har gått: dold")
	-- läsbar aura säger att debuffen saknas: göms (efter en kort marginal)
	mode = "none"
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Stormstrike"])
	check(ss:IsShown(), "casten: visas")
	MOCK.time = MOCK.time + 0.5
	PC:UpdateProc(def)
	check(ss:IsShown(), "direkt efter casten: debuffen har inte hunnit komma")
	MOCK.time = MOCK.time + 1
	PC:UpdateProc(def)
	check(not ss:IsShown(), "läsbar aura säger nej: dold")
	-- byter target: debuffen sitter på det gamla
	mode = "secret"
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Stormstrike"])
	check(ss:IsShown(), "visas")
	MOCK.fire("PLAYER_TARGET_CHANGED")
	check(not ss:IsShown() and PC:StormstrikeLeft() == nil, "nytt target: dold")
	-- någon annans cast, secret ID: inget
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "target", "g", MOCK.known["Stormstrike"])
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", SECRET)
	check(not ss:IsShown(), "target-cast och secret ID: inget")
	restore()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: PvP-kick bara när något är redo", function()
	local flashes, restore = recordFlashes()
	ns.Bars:SetMode("PVP", true)
	MOCK.units.target = { name = "Mage", hostile = true, target = "player" }
	MOCK.casting.target = { name = "Fireball", start = MOCK.time, ends = MOCK.time + 3 }
	-- Andra tester kan ha glömt spellsen: se till att båda finns, och lämna det som det var
	local had = { ["Earth Shock"] = MOCK.known["Earth Shock"] ~= nil, ["Grounding Totem"] = MOCK.known["Grounding Totem"] ~= nil }
	for name, h in pairs(had) do if not h then MOCK.learn(name, MOCK.spellIDs[name]) end end
	ns.Spellbook:Scan()
	MOCK.runTimers()
	local es, gr = ns.Spellbook:ID("Earth Shock"), ns.Spellbook:ID("Grounding Totem")	local function start()
		MOCK.fire("UNIT_SPELLCAST_START", "target")
		MOCK.runTimers()
		return flashes[#flashes]
	end
	local f = start()
	check(f and f.spell == "Earth Shock" and f.title == "KICK! FIREBALL" and f.prio == "critical", "Earth Shock redo: "
		.. tostring(f and f.title))
	MOCK.cooldowns[es] = { MOCK.time, 6 }
	f = start()
	check(#flashes == 2 and f.spell == "Grounding Totem" and f.title:find("^GROUND IT!") and f.prio == "critical",
		"Earth Shock på cd: Grounding " .. tostring(f and f.title))
	MOCK.cooldowns[gr] = { MOCK.time, 15 }
	start()
	check(#flashes == 2, "inget redo: ingen varning")
	MOCK.cooldowns[es], MOCK.cooldowns[gr] = nil, nil
	-- kan inte avbrytas: Grounding även om Earth Shock är redo
	MOCK.casting.target.notInt = true
	f = start()
	check(#flashes == 3 and f.spell == "Grounding Totem", "kan inte avbrytas: Grounding")
	unlearn("Grounding Totem")
	start()
	check(#flashes == 3, "kan inte avbrytas, ingen Grounding: ingen varning")
	relearn("Grounding Totem")
	MOCK.casting.target.notInt = nil
	MOCK.fire("UNIT_SPELLCAST_STOP", "target")
	ns.Bars:SetMode("PVE", true)
	MOCK.casting.target, MOCK.units.target = nil, nil
	for name, h in pairs(had) do if not h then MOCK.unlearn(name) end end
	ns.Spellbook:Scan()
	restore()
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 bossmods: timertyper, hela ord, spell-ID", function()
	local BM = ns.BossMods
	for _, t in ipairs({ "cd", "next", "cast", "cdcount", "nextcount", "castcount", "cdsource", "nextsource",
		"cdspecial", "nextspecial", "CD" }) do
		check(BM.Upcoming(t), "kommande cast: " .. t)
	end
	check(BM.Upcoming(nil) and BM.Upcoming(SECRET), "okänd typ: tillåts")
	for _, t in ipairs({ "target", "active", "fades", "ai", "stage", "break", "achievement", "roleplay" }) do
		check(not BM.Upcoming(t), "ignoreras: " .. t)
	end
	-- DBM-bar som inte är en kommande cast
	local H = BM.DBM_HANDLERS
	H.DBM_TimerStart("DBM_TimerStart", "ty1", "Fear", 20, 136, "target")
	check(BM:Pending("dbm:ty1") == nil, "target-typ (fear på någon): ingen varning")
	H.DBM_TimerStart("DBM_TimerStart", "ty2", "Fear", 20, 136, "fades")
	check(BM:Pending("dbm:ty2") == nil, "fades-typ: ingen varning")
	H.DBM_TimerStart("DBM_TimerStart", "ty3", "Fear", 20, 136, "cdcount")
	check(BM:Pending("dbm:ty3") and BM:Pending("dbm:ty3").totem == "Tremor Totem", "cdcount: varning")
	H.DBM_TimerStop("DBM_TimerStop", "ty3")
	-- hela ord
	local function totem(s) local r = BM:Match(s) return r and r.totem end
	check(totem("Chain Lightning") == nil, "Chain Lightning: inget")
	check(totem("Chains of Kel'Thuzad") == nil, "Chains of Kel'Thuzad: mind control, Tremor hjälper inte")
	check(totem("Fearless Charge") == nil, "Fearless: inget (inte hela ordet)")
	check(totem("Stinger Swarm") == nil, "Stinger: inget")
	check(totem("|cffff0000Fear|r") == "Tremor Totem", "färgkod bort")
	check(totem("|TInterface\\Icons\\Spell_Shadow_Possession:0|t Panic") == "Tremor Totem", "textur bort")
	check(totem("|cFF00FF00Wyvern Sting|r (2)") == "Poison Cleansing Totem", "Wyvern Sting")
	check(totem("Plague Cloud") == "Disease Cleansing Totem", "Plague")
	for _, s in ipairs({ "Intimidating Shout", "Psychic Scream", "Terrify", "Terrifying Screech", "Bellowing Roar",
		"Seduction" }) do
		check(totem(s) == "Tremor Totem", "Tremor: " .. s)
	end
	for _, s in ipairs({ "Dominate Mind", "Mind Control", "Shadow Command", "Cause Insanity" }) do
		check(totem(s) == nil, "mind control, inget totem: " .. s)
	end
	check(BM:MatchSpell(28410) == nil and BM:MatchSpell(20604) == nil, "mind control-ID:n borta")
	check(totem("Death Coil") == nil, "Death Coil (horror): Tremor hjälper inte")
	check(totem("Kelris: Sleep") == "Tremor Totem", "Sleep efter kolon")
	-- spell-ID först
	check(BM:MatchSpell(19408) and BM:MatchSpell(19408).totem == "Tremor Totem", "Panic 19408")
	check(BM:MatchSpell(26180) and BM:MatchSpell(26180).totem == "Poison Cleansing Totem", "Wyvern Sting 26180")
	check(BM:MatchSpell(12345) == nil and BM:MatchSpell(SECRET) == nil and BM:MatchSpell("x") == nil, "okänt ID: nil")
	H.DBM_TimerStart("DBM_TimerStart", "id1", "Next ability", 20, 136, "cd", 19408)
	check(BM:Pending("dbm:id1") and BM:Pending("dbm:id1").totem == "Tremor Totem", "ID utan nyckelord i texten")
	H.DBM_TimerStart("DBM_TimerStart", "id2", "Plague Wave", 20, 136, "cd", 18431)
	check(BM:Pending("dbm:id2") and BM:Pending("dbm:id2").totem == "Tremor Totem", "ID går före texten")
	H.DBM_TimerStop("DBM_TimerStop", "id1")
	H.DBM_TimerStop("DBM_TimerStop", "id2")
	-- secret id: inga fel
	H.DBM_TimerStart("DBM_TimerStart", SECRET, "Fear", 20, 136, "cd")
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 bossmods: totem nere, wipe, pause/resume/update", function()
	local BM = ns.BossMods
	local H = BM.DBM_HANDLERS
	local flashes, restore = recordFlashes()
	local combat = true
	rawset(_G, "UnitAffectingCombat", function() return combat end)
	-- i strid: varning, kritisk
	H.DBM_TimerStart("DBM_TimerStart", "a1", "Panic", 20, 136, "cd", 19408)
	MOCK.runTimers()
	check(#flashes == 1 and flashes[1].title == "TREMOR IN 4s" and flashes[1].prio == "critical", "varning: "
		.. tostring(flashes[1] and flashes[1].title))
	-- totemet redan nere
	local unstub = stub(ns.Totems, "Active", function(_, name) if name == "Tremor Totem" then return 2 end end)
	H.DBM_TimerStart("DBM_TimerStart", "a2", "Panic", 20, 136, "cd", 19408)
	MOCK.runTimers()
	check(#flashes == 1, "Tremor redan nere: ingen varning")
	unstub()
	-- ur strid när den skulle gå (wipe/kill): ingen varning
	H.DBM_TimerStart("DBM_TimerStart", "a3", "Panic", 20, 136, "cd", 19408)
	combat = false
	MOCK.runTimers()
	check(#flashes == 1, "ur strid: ingen varning")
	combat = true
	-- ENCOUNTER_END och PLAYER_REGEN_ENABLED rensar
	H.DBM_TimerStart("DBM_TimerStart", "a4", "Panic", 20, 136, "cd", 19408)
	MOCK.fire("ENCOUNTER_END", 1234, "Magmadar", 9, 40, 0)
	check(BM:Pending("dbm:a4") == nil, "ENCOUNTER_END rensar")
	H.DBM_TimerStart("DBM_TimerStart", "a5", "Panic", 20, 136, "cd", 19408)
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(BM:Pending("dbm:a5") == nil, "ur strid rensar")
	MOCK.runTimers()
	check(#flashes == 1, "rensade: ingen varning")
	-- pause: avbryter; resume: tiden kvar
	H.DBM_TimerStart("DBM_TimerStart", "p1", "Bellowing Roar", 30, 136, "cd", 18431)
	MOCK.timers = {}   -- den här schemaläggningen ska inte köras i testet
	MOCK.time = MOCK.time + 10
	H.DBM_TimerPause("DBM_TimerPause", "p1")
	check(BM:Pending("dbm:p1") == nil, "pausad: ingen schemaläggning")
	MOCK.time = MOCK.time + 60
	H.DBM_TimerResume("DBM_TimerResume", "p1")
	local p = BM:Pending("dbm:p1")
	check(p and p.delay == 16, "resume: 20 s kvar -> 16: " .. tostring(p and p.delay))
	-- update: kvar = total - förfluten
	H.DBM_TimerUpdate("DBM_TimerUpdate", "p1", 5, 40)
	p = BM:Pending("dbm:p1")
	check(p and p.delay == 31, "update: 35 s kvar -> 31: " .. tostring(p and p.delay))
	H.DBM_TimerUpdate("DBM_TimerUpdate", "p1", 40, 40)
	check(BM:Pending("dbm:p1") == nil, "update: slut")
	-- update medan pausad: ny tid vid resume
	H.DBM_TimerUpdate("DBM_TimerUpdate", "p1", 10, 30)
	MOCK.timers = {}
	H.DBM_TimerPause("DBM_TimerPause", "p1")
	H.DBM_TimerUpdate("DBM_TimerUpdate", "p1", 22, 30)
	check(BM:Pending("dbm:p1") == nil, "update medan pausad: väntar")
	H.DBM_TimerResume("DBM_TimerResume", "p1")
	p = BM:Pending("dbm:p1")
	check(p and p.delay == 4, "resume efter update: 8 s kvar -> 4: " .. tostring(p and p.delay))
	MOCK.runTimers()
	check(#flashes == 2 and flashes[2].title == "TREMOR IN 4s", "varning efter resume: " .. tostring(flashes[2] and flashes[2].title))
	-- okänd bar, dubbel resume, secret och skräp: inga fel
	H.DBM_TimerResume("DBM_TimerResume", "p1")
	H.DBM_TimerUpdate("DBM_TimerUpdate", "okand", 1, 10)
	H.DBM_TimerUpdate("DBM_TimerUpdate", "p1", SECRET, SECRET)
	H.DBM_TimerPause("DBM_TimerPause", SECRET)
	H.DBM_TimerResume("DBM_TimerResume", nil)
	check(BM:Pending("dbm:okand") == nil, "okänd bar: inget")
	H.DBM_TimerStop("DBM_TimerStop", "p1")
	MOCK.runTimers()
	check(#flashes == 2, "inga fler varningar")
	rawset(_G, "UnitAffectingCombat", nil)
	restore()
	MOCK.time = MOCK.time + 10
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 bossmods: pull-checken tittar på off-hand-imbuen", function()
	local BM, RE, TO = ns.BossMods, ns.Reminders, ns.Totems
	local offWeapon, offImbue = true, false
	local undo = {
		stub(RE, "ShieldUp", function() return true end),
		stub(RE, "Imbue", function() return true end),
		stub(TO, "Count", function() return 3 end),
		stub(RE, "OffhandWeapon", function() return offWeapon end),
		stub(RE, "OffhandImbue", function() return offImbue end),
	}
	local function has()
		for _, m in ipairs(BM:Missing()) do
			if m.text == "no off-hand imbue" then return m end
		end
	end
	local m = has()
	check(m and m.spell == RE:OffhandSpell(), "off-hand utan imbue: saknas (" .. tostring(m and m.spell) .. ")")
	offImbue = nil
	check(not has(), "okänd imbue: räknas inte")
	offImbue, offWeapon = false, nil
	check(not has(), "okänt vapen: räknas inte")
	offWeapon = false
	check(not has(), "inget off-hand-vapen: räknas inte")
	offWeapon, offImbue = true, true
	check(not has(), "imbue på: inget")
	offImbue = false
	ns.char.reminders.offhand = false
	check(not has(), "off-hand-påminnelsen av: inget")
	ns.char.reminders.offhand = true
	-- pull-varningen: råd-prioritet
	local flashes, restore = recordFlashes()
	MOCK.time = MOCK.time + 10
	BM:Pull(10)
	local f = flashes[1]
	check(f and f.text == "Missing: no off-hand imbue." and f.prio == "advice", "pull: " .. tostring(f and f.text))
	restore()
	for _, u in ipairs(undo) do u() end
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: andning med secret-värden", function()
	local PC = ns.Procs
	local flashes, restore = recordFlashes()
	MOCK.itemCounts[17057] = 5
	-- kvarvarande secret, max läsbart: 30 s -> varna efter 10
	MOCK.fire("MIRROR_TIMER_START", "BREATH", SECRET, 30000, -1, 0, "Breath")
	check(PC:BreathDelay() == 10, "max läsbart: " .. tostring(PC:BreathDelay()))
	MOCK.runTimers()
	check(#flashes == 1 and flashes[1].prio == "critical", "varnar, kritiskt")
	-- allt secret: anta 60 s
	MOCK.fire("MIRROR_TIMER_START", "BREATH", SECRET, SECRET, SECRET, SECRET, SECRET)
	check(PC:BreathDelay() == 40, "allt secret: anta 60 s -> " .. tostring(PC:BreathDelay()))
	MOCK.fire("MIRROR_TIMER_STOP", "BREATH")
	MOCK.runTimers()
	check(#flashes == 1, "uppe igen: ingen varning")
	-- GetMirrorTimerProgress läsbar och gott om luft: väntar i stället för att varna
	local progress = 50000
	rawset(_G, "GetMirrorTimerProgress", function() return progress end)
	MOCK.fire("MIRROR_TIMER_START", "BREATH", SECRET, SECRET, -1, 0, "Breath")
	local list = MOCK.timers
	MOCK.timers = {}
	for _, fn in ipairs(list) do fn() end
	check(#flashes == 1 and #MOCK.timers == 1, "50 s kvar enligt spelet: schemalägger om")
	MOCK.runTimers()
	check(#flashes == 2, "sedan: varning")
	rawset(_G, "GetMirrorTimerProgress", nil)
	MOCK.itemCounts[17057] = nil
	restore()
	MOCK.runTimers()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: Mana Tide via totemspårningen", function()
	local PC, c, TO = ns.Procs, ns.char.procs, ns.Totems
	local mt = _G.FarseerProcmanatide
	clearAuras()
	MOCK.time = MOCK.time + 30
	PC:Update()
	check(PC:TimerLeft("manatide") == nil, "ingen timer före")
	local slot, left = nil, 9
	local undo = {
		stub(TO, "Active", function(_, name) if name == "Mana Tide Totem" then return slot end end),
		stub(TO, "Remaining", function() return left end),
	}
	MOCK.chat = {}
	MOCK.group = 3
	c.announce = true
	-- casten var secret: totemet dyker upp
	slot = 3
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == 9, "startar från totemets tid: " .. tostring(PC:TimerLeft("manatide")))
	check(mt:IsShown(), "ikonen visas")
	check(#MOCK.chat == 1 and MOCK.chat[1][1] == "Mana Tide Totem up (12 s)", "meddelande")
	ns.fire("TOTEMS_CHANGED")
	check(#MOCK.chat == 1 and PC:TimerLeft("manatide") == 9, "redan igång: ingen omstart")
	-- totemet dödat
	slot = nil
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == nil and not mt:IsShown(), "totemet borta: timern stoppas")
	-- tid kvar längre än totemet: högst 12 s; okänd tid: 12 s
	slot, left = 1, 50
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == 12, "högst 12 s")
	slot = nil
	ns.fire("TOTEMS_CHANGED")
	slot, left = 1, nil
	MOCK.time = MOCK.time + 2
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == 12, "okänd tid: 12 s")
	slot = nil
	ns.fire("TOTEMS_CHANGED")
	-- läsbar cast: timern står kvar tills totemspårningen sett totemet
	MOCK.time = MOCK.time + 2
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Mana Tide Totem"])
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == 12, "färsk cast: stoppas inte innan totemet setts")
	slot = 2
	ns.fire("TOTEMS_CHANGED")
	slot = nil
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == nil, "setts och borta (Totemic Call): stoppas")
	-- timrar av
	c.cdTimers = false
	slot = 2
	ns.fire("TOTEMS_CHANGED")
	check(PC:TimerLeft("manatide") == nil, "cdTimers av: ingen timer")
	c.cdTimers = true
	slot = nil
	ns.fire("TOTEMS_CHANGED")
	for _, u in ipairs(undo) do u() end
	c.announce = false
	MOCK.group = 0
	MOCK.chat = {}
	PC:Update()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: inget meddelande under en encounter", function()
	local PC = ns.Procs
	MOCK.chat = {}
	MOCK.group = 3
	local enc = true
	rawset(_G, "IsEncounterInProgress", function() return enc end)
	check(PC:Announce("hej") == false and #MOCK.chat == 0, "encounter: inget")
	enc = false
	check(PC:Announce("hej") == true and #MOCK.chat == 1, "ingen encounter: skickas")
	rawset(_G, "IsEncounterInProgress", function() return SECRET end)
	check(PC:Announce("hej") == true and #MOCK.chat == 2, "secret: pcall skyddar, skickas")
	rawset(_G, "IsEncounterInProgress", nil)
	check(PC:Announce("hej") == true and #MOCK.chat == 3, "utan funktionen: skickas")
	MOCK.group = 0
	MOCK.chat = {}
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: ikonerna hoppar inte", function()
	local PC, c = ns.Procs, ns.char.procs
	local cc, ss = _G.FarseerProcclearcast, _G.FarseerProcstormstrike
	local function x(f) return f.__points[1] and f.__points[1][4] end
	clearAuras()
	MOCK.time = MOCK.time + 30
	PC:Update()
	MOCK.time = MOCK.time + 30
	PC:Update()
	local cca = aura({ name = "Clearcasting", spellId = 16246, applications = 1, auraInstanceID = 181 })
	aura({ name = "Stormstrike", spellId = 999777, auraInstanceID = 182 })
	PC:Update()
	check(cc:IsShown() and ss:IsShown(), "båda visas")
	local ccX, ssX = x(cc), x(ss)
	check(ccX and ssX and ssX > ccX, "Stormstrike efter Clearcasting")
	-- Clearcasting går: Stormstrike står kvar
	table.remove(MOCK.auras.player, 1)
	PC:Update()
	check(not cc:IsShown() and x(ss) == ssX, "Clearcasting borta: Stormstrike står kvar (" .. tostring(x(ss)) .. ")")
	-- kommer tillbaka inom 10 s: samma plats
	MOCK.time = MOCK.time + 5
	table.insert(MOCK.auras.player, 1, cca)
	PC:Update()
	check(cc:IsShown() and x(cc) == ccX and x(ss) == ssX, "tillbaka: samma platser")
	-- borta i mer än 10 s: raden packas
	table.remove(MOCK.auras.player, 1)
	PC:Update()
	MOCK.time = MOCK.time + 9
	PC:Update()
	check(x(ss) == ssX, "9 s: platsen hålls")
	MOCK.time = MOCK.time + 2
	PC:Update()
	check(x(ss) == ccX, "11 s: packas (" .. tostring(x(ss)) .. ")")
	-- avstängd: ingen reserverad plats
	table.insert(MOCK.auras.player, 1, cca)
	PC:Update()
	check(x(ss) == ssX, "tillbaka")
	c.clearcast = false
	PC:Update()
	check(not cc:IsShown() and x(ss) == ccX, "avstängd: packas direkt")
	c.clearcast = true
	clearAuras()
	PC:Update()
	MOCK.time = MOCK.time + 11
	PC:Update()
end)

---------------------------------------------------------------------------------------------------
test("v1.7 procs: prioriteter", function()
	local PC, c = ns.Procs, ns.char.procs
	local flashes, restore = recordFlashes()
	-- låg mana: råd
	MOCK.mana = { 1000, 1000 }
	PC:CheckMana()
	MOCK.combat = true
	MOCK.mana = { 100, 1000 }
	PC:CheckMana()
	local f = flashes[#flashes]
	check(f and f.key == "lowmana" and f.prio == "advice", "låg mana: advice (" .. tostring(f and f.prio) .. ")")
	MOCK.combat = false
	MOCK.mana = { 1000, 1000 }
	PC:CheckMana()
	MOCK.runTimers()
	-- purge i PvP: info
	ns.Bars:SetMode("PVP", true)
	MOCK.units.target = { name = "Priest", hostile = true, guid = "P17" }
	MOCK.auras.target = { { name = "Power Word: Shield", dispelName = "Magic", icon = 555 } }
	PC:Update()
	f = flashes[#flashes]
	check(f and f.key == "purge" and f.prio == "info", "purge: info (" .. tostring(f and f.prio) .. ")")
	ns.Bars:SetMode("PVE", true)
	MOCK.units.target, MOCK.auras.target = nil, {}
	PC:Update()
	MOCK.runTimers()
	-- Water Breathing går ut: info
	MOCK.itemCounts[17057] = 3
	rawset(_G, "IsSwimming", function() return true end)
	aura({ name = "Water Breathing", spellId = 131, expirationTime = MOCK.time + 45, auraInstanceID = 1791 })
	PC:CheckWaterBreathing()
	f = flashes[#flashes]
	check(f and f.key == "waterbreathing" and f.prio == "info", "Water Breathing: info")
	rawset(_G, "IsSwimming", nil)
	clearAuras()
	MOCK.itemCounts[17057] = nil
	c.mana = true
	restore()
	MOCK.runTimers()
end)
