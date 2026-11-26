-- v2.3: fixar från den andra genomgången

local ns = FARSEER_NS
local test, check = TEST, CHECK

local function recordFlashes()
	local list = {}
	local real = ns.Alert.Flash
	ns.Alert.Flash = function(self, key, spell, title, text, ...)
		table.insert(list, { key = key, spell = spell, title = title, text = text })
		return real(self, key, spell, title, text, ...)
	end
	return list, function() ns.Alert.Flash = real end
end

test("v22: profil med kortare lista fylls inte ut med standardlistan", function()
	local PR = ns.Profiles
	local saved = ns.copy(ns.char.counterTotems)
	ns.char.counterTotems = { "Tremor Totem", "Grounding Totem" }
	PR:Save("v22test")
	ns.char.counterTotems = ns.copy(saved)
	local ok = PR:Load("v22test")
	check(ok, "laddad")
	check(#ns.char.counterTotems == 2, "två totems kvar: " .. #ns.char.counterTotems)
	ns.char.counterTotems = saved
	ns.db.profiles["v22test"] = nil
	MOCK.runTimers()
end)

test("v22: totem som står kvar med oläsbart namn är inte dött", function()
	local TO = ns.Totems
	local slot = ns.SLOT.WATER
	ns.char.totemAlerts.death = true
	ns.char.totemAlerts.allTotems = true
	local prev = { name = "Mana Spring Totem", start = MOCK.time - 10, dur = 300 }
	local orig = GetTotemInfo
	rawset(_G, "GetTotemInfo", function() return true, SECRET, SECRET, SECRET, 1000 end)
	ns.Alert:Hide(true)
	local flashes, restore = recordFlashes()
	TO:CheckDeath(slot, prev)
	check(#flashes == 0, "ingen DIED-varning")
	rawset(_G, "GetTotemInfo", orig)
	-- borta på riktigt: varning
	MOCK.totems[slot] = nil
	TO:CheckDeath(slot, prev)
	check(#flashes == 1 and flashes[1].title:find("DIED"), "tom slot: varning " .. tostring(flashes[1] and flashes[1].title))
	restore()
	ns.Alert:Hide(true)
	ns.char.totemAlerts.allTotems = false
end)

test("v22: ingen DIED-varning direkt efter en laddningsskärm", function()
	local TO = ns.Totems
	local slot = ns.SLOT.WATER
	ns.char.totemAlerts.death = true
	ns.char.totemAlerts.allTotems = true
	MOCK.time = MOCK.time + 100
	MOCK.fire("PLAYER_LEAVING_WORLD")
	local flashes, restore = recordFlashes()
	MOCK.totems[slot] = nil
	TO:CheckDeath(slot, { name = "Mana Spring Totem", start = MOCK.time - 10, dur = 300 })
	check(#flashes == 0, "zonbyte: ingen varning")
	MOCK.time = MOCK.time + 10
	TO:CheckDeath(slot, { name = "Mana Spring Totem", start = MOCK.time - 10, dur = 300 })
	check(#flashes == 1, "senare: varning igen")
	restore()
	ns.Alert:Hide(true)
	ns.char.totemAlerts.allTotems = false
end)

test("v22: /farseer test visas även när varningar bara får visas i grupp", function()
	local AL = ns.Alert
	local mode = ns.db.alert.mode
	ns.db.alert.mode = "group"
	MOCK.group = 0
	AL:Hide(true)
	AL:Test()
	check(AL:Current() == "test", "testet visas: " .. tostring(AL:Current()))
	check(AL:Allowed() == false, "vanliga varningar fortfarande begränsade")
	AL:Hide(true)
	ns.db.alert.mode = mode
end)

test("v22: raidplanen lägger raid-vida totems en gång", function()
	local plan = ns.RaidTotems:Plan({
		{ name = "A", group = 1, class = "SHAMAN", me = true }, { name = "W1", group = 1, class = "WARRIOR" },
		{ name = "B", group = 2, class = "SHAMAN" }, { name = "W2", group = 2, class = "ROGUE" },
		{ name = "C", group = 3, class = "SHAMAN" }, { name = "W3", group = 3, class = "WARRIOR" },
	})
	check(#plan == 3, "tre shamans")
	local count = {}
	for _, p in ipairs(plan) do
		for _, t in ipairs(p.totems) do count[t] = (count[t] or 0) + 1 end
	end
	for t in pairs(ns.RaidTotems.RAID_WIDE) do
		check((count[t] or 0) <= 1, t .. " högst en gång: " .. tostring(count[t]))
	end
	check(count["Windfury Totem"] == 1 and count["Strength of Earth Totem"] == 1, "Windfury och SoE finns")
	check(not count["Flametongue Totem"], "ingen Flametongue (krockar med Windfury)")
	check(plan[1].group == 1 and plan[3].group == 3, "sorterad på grupp")
	for _, p in ipairs(plan) do check(#p.totems == 4, "fyra totems: " .. p.shaman) end
	-- melee-grupp efter en castergrupp får ändå Windfury
	plan = ns.RaidTotems:Plan({
		{ name = "A", group = 1, class = "SHAMAN" }, { name = "M1", group = 1, class = "MAGE" },
		{ name = "B", group = 2, class = "SHAMAN" }, { name = "W2", group = 2, class = "WARRIOR" },
	})
	check(plan[2].group == 2 and plan[2].totems[4] == "Windfury Totem", "melee-gruppen får Windfury")
end)

test("v22: Poisonous Blood och Mutating Injection renas inte", function()
	ns.char.advisor.dispel = true
	MOCK.units.party1 = { name = "Jaina", class = "MAGE", player = true }
	MOCK.auras.party1 = { { name = "Poisonous Blood", harmful = true, dispelName = "Poison" } }
	MOCK.fire("UNIT_AURA", "party1")
	local recs = ns.Advisor:Evaluate()
	check(recs["Poison Cleansing Totem"] == nil, "Hakkar-giftet ger inget förslag")
	MOCK.auras.party1 = { { name = "Deadly Poison", harmful = true, dispelName = "Poison" } }
	MOCK.fire("UNIT_AURA", "party1")
	recs = ns.Advisor:Evaluate()
	check(recs["Poison Cleansing Totem"] ~= nil, "vanligt gift: förslag")
	MOCK.auras.party1, MOCK.units.party1 = nil, nil
	MOCK.fire("UNIT_AURA", "party1")
	ns.Alert:Hide(true)
	check(ns.NEVER_CLEANSE["Mutating Injection"], "Grobbulus på listan")
end)

test("v22: data som spelet visar", function()
	local vis
	for _, r in ipairs(ns.BOSS_RULES or {}) do if r[1] == "Viscidus" then vis = r end end
	check(vis and vis[2] == "Nature Resistance Totem", "Viscidus: Nature Resistance")
	check(ns.ZONE_RULES["Blackwing Lair"] == nil, "BWL: ingen eld för hela zonen")
	local mouse
	for _, p in ipairs(ns.BINDING_PRESETS) do if p.id == "mouse" then mouse = p end end
	local eb
	for _, b in ipairs(mouse.binds) do if b[1] == "SHIFT-BUTTON5" then eb = b end end
	check(eb and eb.spell == "Earthbind Totem", "Shift+knapp 5 = Earthbind (inte Shift-grenen i makrot)")
	local ss = ns.MacroEngine:Template("enh_ss")
	check(ss.desc:find("20 s", 1, true), "Stormstrike 20 s")
end)

test("v22: Burst-makrot för casters tar inte Blood Fury", function()
	local ME = ns.MacroEngine
	MOCK.learn("Blood Fury")
	ns.Spellbook:Scan()
	local body = ME:Render(ME:Template("ele_burst"))
	check(not body:find("Blood Fury", 1, true), "ingen Blood Fury: " .. body)
	local enh = ME:Render(ME:Template("enh_burst"))
	check(enh:find("Blood Fury", 1, true), "enhancement behåller den")
	MOCK.unlearn("Blood Fury")
	ns.Spellbook:Scan()
	MOCK.runTimers()
end)

test("v22: Purge-varning i PvP bara för viktiga buffar", function()
	local PC = ns.Procs
	local flashes, restore = recordFlashes()
	ns.Bars:SetMode("PVP", true)
	ns.char.procs.purgeAlertPvp = true
	MOCK.learn("Purge")
	ns.Spellbook:Scan()
	MOCK.units.target = { name = "Priest", hostile = true, player = true }
	MOCK.auras.target = { { name = "Arcane Intellect", dispelName = "Magic" } }
	PC:UpdatePurge()
	local n = 0
	for _, f in ipairs(flashes) do if f.key == "purge" then n = n + 1 end end
	check(n == 0, "Arcane Intellect: ingen varning")
	MOCK.auras.target = { { name = "Arcane Intellect", dispelName = "Magic" }, { name = "Power Word: Shield", dispelName = "Magic" } }
	PC:UpdatePurge()
	local last = flashes[#flashes]
	check(last and last.key == "purge" and last.title == "PURGE: POWER WORD: SHIELD", "sköld: varning " .. tostring(last and last.title))
	restore()
	MOCK.auras.target = nil
	MOCK.units.target = nil
	ns.Bars:SetMode("PVE", true)
	ns.Alert:Hide(true)
	MOCK.runTimers()
end)

test("v22: GROUND IT bara när casten siktar på din grupp", function()
	local flashes, restore = recordFlashes()
	ns.Bars:SetMode("PVP", true)
	for _, s in ipairs({ "Earth Shock", "Grounding Totem" }) do MOCK.learn(s, MOCK.spellIDs[s]) end
	ns.Spellbook:Scan()
	MOCK.runTimers()
	local es = ns.Spellbook:ID("Earth Shock")
	MOCK.cooldowns[es] = { MOCK.time, 6 }
	MOCK.units.stranger = { name = "Someone" }
	MOCK.units.target = { name = "Mage", hostile = true, target = "stranger" }
	MOCK.casting.target = { name = "Fireball", start = MOCK.time, ends = MOCK.time + 3 }
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	MOCK.runTimers()
	check(#flashes == 0, "siktar på någon annan: ingen varning")
	MOCK.units.target.target = "player"
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	MOCK.runTimers()
	check(#flashes == 1 and flashes[1].title:find("^GROUND IT"), "på dig: varning")
	-- Earth Shock utom räckhåll: ingen KICK
	MOCK.cooldowns[es] = nil
	MOCK.range["Earth Shock"] = false
	ns.Alert:Hide(true)
	MOCK.fire("UNIT_SPELLCAST_START", "target")
	MOCK.runTimers()
	check(flashes[#flashes].spell ~= "Earth Shock", "utom räckhåll: ingen KICK")
	MOCK.range["Earth Shock"] = nil
	restore()
	MOCK.casting.target = nil
	MOCK.units.target, MOCK.units.stranger = nil, nil
	ns.Bars:SetMode("PVE", true)
	ns.Alert:Hide(true)
	MOCK.runTimers()
end)

test("v22: boss-varningar finns kvar när du lämnar strid mitt i en encounter", function()
	local BM = ns.BossMods
	MOCK.fire("ENCOUNTER_START", 1, "Boss")
	BM:StartBar("v22bar", "Psychic Scream", 20)
	check(BM:Pending("v22bar") ~= nil, "schemalagd")
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(BM:Pending("v22bar") ~= nil, "död/ur strid under encountern: kvar")
	MOCK.fire("ENCOUNTER_END", 1, "Boss")
	check(BM:Pending("v22bar") == nil, "encountern slut: borta")
	BM:StartBar("v22bar", "Psychic Scream", 20)
	check(BM:Pending("v22bar") ~= nil, "schemalagd igen")
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(BM:Pending("v22bar") == nil, "ingen encounter: rensas när du lämnar strid")
	MOCK.runTimers()
end)

test("v22: raid-checklistan bara när du kommer in i raiden", function()
	local LV = ns.Leveling
	local shown = 0
	local real = LV.ShowChecklist
	LV.ShowChecklist = function() shown = shown + 1 end
	ns.char.leveling.checklist = true
	MOCK.instanceType = "raid"
	MOCK.fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.runTimers()
	check(shown == 1, "in i raiden: visas")
	MOCK.fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.runTimers()
	check(shown == 1, "laddningsskärm i samma raid (spöke efter wipe): inte igen")
	MOCK.instanceType = "none"
	MOCK.fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.instanceType = "raid"
	MOCK.fire("PLAYER_ENTERING_WORLD", false, true)
	MOCK.runTimers()
	check(shown == 1, "/reload i raiden: inte")
	MOCK.instanceType = "none"
	MOCK.fire("PLAYER_ENTERING_WORLD", false, false)
	MOCK.runTimers()
	LV.ShowChecklist = real
end)

test("v22: byte av läge i strid väntar på att striden tar slut", function()
	local BA = ns.Bars
	BA:SetMode("PVE", true)
	MOCK.combat = true
	MOCK.fire("PLAYER_REGEN_DISABLED")
	BA:SetMode("PVP", true)
	check(BA:Mode() == "PVE", "i strid: samma läge")
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	MOCK.runTimers()
	check(BA:Mode() == "PVP", "efter strid: PvP")
	BA:SetMode("PVE", true)
	MOCK.runTimers()
end)

test("v22: installationen skriver inte om en annan karaktärs kontomakron", function()
	local ME = ns.MacroEngine
	local saved = ns.db.macros.owner
	ME:CreateFromTemplate("util_wolf", true)
	local idx = ME:Exists("FS Wolf")
	if idx then MOCK.macros[idx].body = "MAIN" end
	ns.db.macros.owner = "Mainchar-Realm"
	ME:CreateCategory("Utility", true)
	check(idx and MOCK.macros[idx].body == "MAIN", "makrot orört: " .. tostring(idx and MOCK.macros[idx].body))
	check(ns.db.macros.owner == "Mainchar-Realm", "ägaren kvar")
	ns.db.macros.owner = saved
end)

test("v22: automatisk imbue påminner inte Elemental/Restoration", function()
	local RE = ns.Reminders
	local c = ns.char.spec
	local last, pick = c.last, ns.char.reminders.imbueSpell
	ns.char.reminders.imbueSpell = "auto"
	MOCK.learn("Rockbiter Weapon")
	ns.Spellbook:Scan()
	c.last = "restoration"
	check(RE:ImbueSpell() == nil, "Restoration: ingen imbue")
	c.last = "elemental"
	check(RE:ImbueSpell() == nil, "Elemental: ingen imbue")
	c.last = "enhancement"
	check(RE:ImbueSpell() ~= nil, "Enhancement: imbue")
	c.last = "restoration"
	ns.char.reminders.imbueSpell = "Rockbiter Weapon"
	check(RE:ImbueSpell() == "Rockbiter Weapon", "vald imbue gäller även för casters")
	c.last, ns.char.reminders.imbueSpell = last, pick
	MOCK.runTimers()
end)

test("v22: situationer med cooldown-totem före ett annat varnas", function()
	local warn = ns.SituationOrderWarning
	check(warn({ totems = { "Grounding Totem", "Healing Stream Totem" } }) ~= nil, "Grounding först: varning")
	check(warn({ totems = { "Healing Stream Totem", "Grounding Totem", "Earthbind Totem" } }) == nil, "sist: ingen varning")
	for _, s in ipairs(ns.DEFAULT_SITUATIONS.PVP) do
		check(warn(s) == nil, "standardsetet " .. s.name .. " har cooldown-totems sist")
	end
	for _, s in ipairs(ns.DEFAULT_SITUATIONS.PVE) do
		check(warn(s) == nil, "standardsetet " .. s.name)
	end
end)

test("v22: Burst-makrot tar Elemental Mastery om talangen heter så", function()
	local ME = ns.MacroEngine
	local hadLM = MOCK.known["Lightning Mastery"]
	MOCK.unlearn("Lightning Mastery")
	MOCK.learn("Elemental Mastery")
	ns.Spellbook:Scan()
	local body = ME:Render(ME:Template("ele_burst"))
	check(body:find("/cast Elemental Mastery", 1, true), "Elemental Mastery: " .. body)
	MOCK.unlearn("Elemental Mastery")
	if hadLM then MOCK.learn("Lightning Mastery", hadLM) end
	ns.Spellbook:Scan()
	MOCK.runTimers()
end)
