-- v2.4: så som WoW: Forever (1.60.1) och andra addons gör: talangträdet via C_Traits, räckvidd utan
-- UnitInRange, multicast-slottar, totemets duration-objekt, makroägare per GUID, imbue runt
-- laddningsskärmar och låsta auror i strid (varje läsning kastar ett fel).

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

local function saveGlobals(names)
	local saved = {}
	for _, n in ipairs(names) do saved[n] = { v = rawget(_G, n) } end
	return function()
		for n, s in pairs(saved) do rawset(_G, n, s.v) end
	end
end

-- Falsk aura-container (som i v17): spelet ger knappen direkt
local function fakeContainer(calls)
	local realCreate = CreateFrame
	rawset(_G, "CreateFrame", function(kind, name, parent, template)
		if kind ~= "AuraContainer" then return realCreate(kind, name, parent, template) end
		calls.template = template
		local c = realCreate("Frame", name, parent)
		function c:SetUnit(u) calls.unit = u end
		function c:AddAuraSlot(slot, filter, o)
			calls.slot, calls.filter, calls.opts = slot, filter, o
			local b = realCreate("Frame", nil, c)
			function b:SetIcon(t) calls.icon = t end
			function b:SetApplicationCount(fs) calls.count = fs end
			function b:SetApplicationBar() end
			function b:SetDurationCooldown(cd) calls.cd = cd end
			o.initializeFrame(b)
		end
		return c
	end)
	return function() rawset(_G, "CreateFrame", realCreate) end
end

-- Sköldarna med kända ID:n (tidigare tester kan ha glömt dem); returnerar en återställning
local function learnShields()
	local did = {}
	for name, id in pairs({ ["Lightning Shield"] = 324, ["Water Shield"] = 408510 }) do
		if not ns.Spellbook:Knows(name) then MOCK.learn(name, id); table.insert(did, name) end
	end
	ns.Spellbook:Scan()
	MOCK.runTimers()
	return function()
		for _, name in ipairs(did) do MOCK.unlearn(name) end
		ns.Spellbook:Scan()
		MOCK.runTimers()
	end
end

local function procDef(key)
	for _, d in ipairs(ns.Procs.PROCS) do if d.key == key then return d end end
end

---------------------------------------------------------------------------------------------------
test("v23: talangpoäng från talangträdet (C_Traits), som Forevers egen talangruta", function()
	local SP = ns.Spec
	local restore = saveGlobals({ "C_ClassTalents", "C_Traits", "C_SpecializationInfo", "GetTalentTabInfo" })
	rawset(_G, "GetTalentTabInfo", nil)
	rawset(_G, "C_ClassTalents", {
		GetActiveConfigID = function() return 77 end,
		HasUnspentTalentPoints = function() return true, 2, 1 end,
	})
	local names = { "Restoration", "Elemental", "Enhancement" }
	rawset(_G, "C_Traits", {
		GetConfigInfo = function(id) return id == 77 and { treeIDs = { 900 } } or nil end,
		GetGroupDisplayInfoByTreeID = function()
			return {
				{ groupID = 3, treeID = 900, orderIndex = 2, displayName = names[1] },
				{ groupID = 1, treeID = 900, orderIndex = 0, displayName = names[2] },
				{ groupID = 2, treeID = 900, orderIndex = 1, displayName = names[3] },
			}
		end,
		GetGroupCurrencyInfo = function(cfg, ids)
			check(cfg == 77, "configID skickas")
			local spent = { [1] = 5, [2] = 31, [3] = 0 }
			local out = {}
			for _, g in ipairs(ids) do table.insert(out, { traitNodeGroupID = g, currencyInfos = { { spent = spent[g] } } }) end
			return out
		end,
	})
	local p = SP:TalentPoints()
	check(p and p[1] == 5 and p[2] == 31 and p[3] == 0, "ele 5, enh 31, resto 0: " .. tostring(p and table.concat(p, ",")))
	check(SP:Unspent() == 3, "ospenderade = klass + spec: " .. tostring(SP:Unspent()))
	-- Översatta namn: ordningen avgör
	names = { "Wiederherstellung", "Elementar", "Verstärkung" }
	p = SP:TalentPoints()
	check(p and p[1] == 5 and p[2] == 31 and p[3] == 0, "ordningen när namnen är översatta")
	-- Utan C_Traits: specialiseringarnas pointsSpent (7:e värdet)
	rawset(_G, "C_Traits", nil)
	rawset(_G, "C_ClassTalents", { HasUnspentTalentPoints = function() return false, 0, 0 end })
	local d = { { "Elemental", 0 }, { "Enhancement", 21 }, { "Restoration", 30 } }
	rawset(_G, "C_SpecializationInfo", {
		GetSpecializationInfo = function(i) return 260 + i, d[i][1], "", 0, "DAMAGER", 4, d[i][2] end,
	})
	p = SP:TalentPoints()
	check(p and p[1] == 0 and p[2] == 21 and p[3] == 30, "pointsSpent: " .. tostring(p and table.concat(p, ",")))
	check(SP:Unspent() == 0, "inga ospenderade")
	-- Inget går att läsa: nil (ingen gissning)
	rawset(_G, "C_SpecializationInfo", nil)
	check(SP:TalentPoints() == nil, "inget API -> nil")
	restore()
end)

test("v23: gruppens räckvidd utan UnitInRange (alltid secret i Forever)", function()
	local TO = ns.Totems
	local restore = saveGlobals({ "UnitInRange" })
	MOCK.units.party1 = { name = "Bob", class = "WARRIOR", player = true }
	rawset(_G, "UnitInRange", function() return SECRET, SECRET end)
	MOCK.range["Healing Wave"] = true
	check(TO.MemberOK("party1") == true, "secret UnitInRange: Healing Wave inom räckhåll")
	MOCK.range["Healing Wave"] = false
	check(TO.MemberOK("party1") == false, "Healing Wave utom räckhåll")
	rawset(_G, "UnitInRange", function() return true, true end)
	check(TO.MemberOK("party1") == true, "läsbar UnitInRange gäller")
	rawset(_G, "UnitInRange", nil)
	MOCK.range["Healing Wave"] = nil
	check(TO.MemberOK("party1") == false, "inget går att mäta -> räknas inte")
	MOCK.units.party1 = nil
	restore()
end)

test("v23: Call-setets actionslot = sidan + totemslotten (Blizzards MultiCastActionBarFrame)", function()
	local TO = ns.Totems
	check(TO:MultiCastAction(1, ns.SLOT.FIRE) == 11 * 12 + 1, "set 1 fire")
	check(TO:MultiCastAction(2, ns.SLOT.EARTH) == 11 * 12 + 4 + 2, "set 2 earth")
	check(TO:MultiCastAction(3, ns.SLOT.AIR) == 11 * 12 + 8 + 4, "set 3 air")
end)

test("v23: spell-cooldown via duration-objektet hoppar över GCD:n", function()
	local spell = "Earth Shock"
	local learned = not ns.Spellbook:Knows(spell)
	if learned then MOCK.learn(spell); ns.Spellbook:Scan(); MOCK.runTimers() end
	local real = C_Spell.GetSpellCooldownDuration
	local args
	C_Spell.GetSpellCooldownDuration = function(...) args = { ... }; return { spell = true } end
	local got
	local cd = { Clear = function() end, SetCooldownFromDurationObject = function(_, d) got = d end }
	MOCK.secretMode = true
	ns.setSpellCooldown(cd, spell)
	MOCK.secretMode = false
	C_Spell.GetSpellCooldownDuration = real
	check(args and args[2] == true, "ignoreGCD = true skickas")
	check(got and got.spell, "objektet ges till ramen")
	if learned then MOCK.unlearn(spell); ns.Spellbook:Scan(); MOCK.runTimers() end
end)

test("v23: totemets duration-objekt avgör om det står kvar när slotten är secret", function()
	local TO = ns.Totems
	local slot = ns.SLOT.WATER
	ns.char.totemAlerts.death = true
	ns.char.totemAlerts.allTotems = true
	MOCK.time = MOCK.time + 100
	local restore = saveGlobals({ "GetTotemInfo", "GetTotemDuration" })
	rawset(_G, "GetTotemInfo", function() return SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET end)
	local prev = { name = "Mana Spring Totem", start = MOCK.time - 10, dur = 300 }
	ns.Alert:Hide(true)
	local flashes, restoreFlash = recordFlashes()
	rawset(_G, "GetTotemDuration", function() return { live = true } end)
	TO:CheckDeath(slot, prev)
	check(#flashes == 0, "objekt finns: står kvar, ingen varning")
	-- Ett objekt som läsbart mäter noll är en tom slot
	rawset(_G, "GetTotemDuration", function() return { IsZero = function() return true end } end)
	TO:CheckDeath(slot, prev)
	check(#flashes == 1 and flashes[1].title:find("DIED"), "noll-objekt: varning")
	restoreFlash()
	restore()
	ns.Alert:Hide(true)
	ns.char.totemAlerts.allTotems = false
end)

test("v23: totembaren ritar ett okänt totem från spelets ikon och nedräkning", function()
	local TO = ns.Totems
	local slot = ns.SLOT.WATER
	MOCK.totems[slot] = nil
	TO:ReadAll()
	local restore = saveGlobals({ "GetTotemInfo", "GetTotemDuration" })
	rawset(_G, "GetTotemInfo", function() return SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET end)
	rawset(_G, "GetTotemDuration", function(s) if s == slot then return { live = true } end return nil end)
	local b = _G.FarseerTotemWATER
	check(b ~= nil, "knappen finns")
	local got
	b.cd.SetCooldownFromDurationObject = function(_, d) got = d end
	TO:UpdateBar()
	check(got and got.live, "nedräkningen kommer från objektet")
	check(b:GetAlpha() == 1, "knappen är tänd")
	rawset(_G, "GetTotemDuration", function() return nil end)
	TO:UpdateBar()
	check(b:GetAlpha() < 1, "tom slot: släckt")
	b.cd.SetCooldownFromDurationObject = nil
	restore()
	TO:UpdateBar()
end)

test("v23: slottens spell-ID före namnet, och en nyss castad post behålls", function()
	local TO = ns.Totems
	MOCK.time = MOCK.time + 100
	local restore = saveGlobals({ "GetTotemInfo" })
	MOCK.spellNames[990001] = "Searing Totem"
	rawset(_G, "GetTotemInfo", function(s)
		if s == ns.SLOT.FIRE then return true, "Fire Nova Totem", MOCK.time, 55, 1000, 1, 990001 end
		return false, "", 0, 0, 0, 1, 0
	end)
	TO:ReadSlot(ns.SLOT.FIRE)
	check(TO:Active("Searing Totem") == ns.SLOT.FIRE, "namnet från spell-ID:t")
	-- Du castar Tremor; slotten säger fortfarande det förra totemet
	MOCK.totems[ns.SLOT.EARTH] = { name = "Tremor Totem", start = MOCK.time, dur = 120 }
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Tremor Totem"])
	rawset(_G, "GetTotemInfo", function(s)
		if s == ns.SLOT.EARTH then return true, "Stoneclaw Totem", MOCK.time - 5, 15, 1000, 1, 0 end
		return false, "", 0, 0, 0, 1, 0
	end)
	TO:ReadSlot(ns.SLOT.EARTH)
	check(TO:Active("Tremor Totem") == ns.SLOT.EARTH, "nyss castat: Tremor behålls")
	MOCK.time = MOCK.time + 2
	TO:ReadSlot(ns.SLOT.EARTH)
	check(TO:Active("Stoneclaw Totem") == ns.SLOT.EARTH, "senare: slotten gäller")
	restore()
	MOCK.spellNames[990001] = nil
	MOCK.totems = {}
	MOCK.timers = {}
	TO:ReadAll()
	ns.Alert:Hide(true)
end)

test("v23: Water Shields andra ID och Windfury/Flametongue Totems buffar", function()
	local function has(list, id) for _, v in ipairs(list or {}) do if v == id then return true end end return false end
	check(has(ns.SHIELD_IDS["Water Shield"], 408510) and has(ns.SHIELD_IDS["Water Shield"], 408511), "Water Shield 408510 + 408511")
	check(has(ns.TOTEM_BUFFS["Windfury Totem"].ids, 8515) and has(ns.TOTEM_BUFFS["Windfury Totem"].ids, 10612), "Windfury Totem-buffen")
	check(has(ns.TOTEM_BUFFS["Flametongue Totem"].ids, 8230) and has(ns.TOTEM_BUFFS["Flametongue Totem"].ids, 15036), "Flametongue Totem-buffen")
end)

test("v23: kontomakronas ägare är karaktärens GUID (gamla namn-realm byts ut)", function()
	local ME = ns.MacroEngine
	local p = MOCK.units.player
	local savedOwner, savedGuid, savedName = ns.db.macros.owner, p.guid, p.name
	p.guid = "Player-4701-0ABCDEF0"
	ns.db.macros.owner = p.name .. "-?"   -- gammal nyckel (realmnamnet gick inte att läsa)
	check(ME:OwnsAccountMacros(), "gammal nyckel godtas")
	check(ns.db.macros.owner == "Player-4701-0ABCDEF0", "och byts mot GUID:t: " .. tostring(ns.db.macros.owner))
	ns.db.macros.owner = "Player-4701-00000001"
	check(not ME:OwnsAccountMacros(), "annan karaktär äger dem")
	-- Precis vid inloggningen: inget GUID och namnet "Unknown" -> ingen ägare skrivs
	p.guid, p.name = false, "Unknown"
	ns.db.macros.owner = nil
	ME:ClaimAccountMacros()
	check(ns.db.macros.owner == nil, "ingen nyckel utan GUID och namn")
	p.guid, p.name = savedGuid, savedName
	ns.db.macros.owner = savedOwner
end)

test("v23: imbuen läses tom runt en laddningsskärm -> det gamla läget gäller", function()
	MOCK.time = MOCK.time + 100
	local pick = ns.char.reminders.imbueSpell
	local learnedWF = not ns.Spellbook:Knows("Windfury Weapon")
	if learnedWF then MOCK.learn("Windfury Weapon"); ns.Spellbook:Scan(); MOCK.runTimers() end
	ns.char.reminders.imbueSpell = "Windfury Weapon"   -- specen kan vara resto efter tidigare tester
	MOCK.weaponEnchant = { true, 3600000 }
	ns.Reminders:Refresh()
	check(not _G.FarseerImbueButton.glow:IsShown(), "imbue uppe")
	MOCK.fire("PLAYER_ENTERING_WORLD")
	check(ns.zoning(), "zonbyte just nu")
	MOCK.weaponEnchant = { false, 0 }
	ns.Reminders:Check()
	check(not _G.FarseerImbueButton.glow:IsShown(), "direkt efter laddningsskärmen: ingen varning")
	MOCK.time = MOCK.time + 4
	check(not ns.zoning(), "zonbytet är över")
	ns.Reminders:Check()
	check(_G.FarseerImbueButton.glow:IsShown(), "sedan: varning")
	MOCK.weaponEnchant = { true, 3600000 }
	ns.char.reminders.imbueSpell = pick
	if learnedWF then MOCK.unlearn("Windfury Weapon"); ns.Spellbook:Scan(); MOCK.runTimers() end
	ns.Reminders:Refresh()
end)

test("v23: ett secret svar från ShouldAurasBeSecret betyder låst", function()
	local real = C_Secrets.ShouldAurasBeSecret
	C_Secrets.ShouldAurasBeSecret = function() return SECRET end
	check(ns.Procs.aurasSecret() == true, "secret -> låst")
	C_Secrets.ShouldAurasBeSecret = function() return false end
	check(ns.Procs.aurasSecret() == false, "false -> öppet")
	C_Secrets.ShouldAurasBeSecret = real
end)

test("v23: låsta auror i strid: okänt är inte 'saknas' (sköld, manaråd)", function()
	local PC = ns.Procs
	local unlearnShields = learnShields()
	MOCK.combat, MOCK.auraLock = false, false
	MOCK.auras.player = { { name = "Water Shield", spellId = 408510, applications = 3, auraInstanceID = 501 } }
	check(PC:Shield() == "Water Shield", "läst före striden")
	MOCK.combat, MOCK.auraLock = true, true
	MOCK.auras.player = {}
	local a, blocked = PC.playerAura({ 16246 }, "Clearcasting")
	check(a == nil and blocked == true, "läsningen blockeras")
	local s, n, raw, unknown = PC:Shield()
	check(s == "Water Shield" and n == nil and unknown == true, "senast kända skölden: " .. tostring(s))
	local mt = MOCK.known["Mana Tide Totem"]
	MOCK.cooldowns[mt] = { MOCK.time, 300 }
	local spell = PC:ManaAdvice()
	check(spell ~= "Water Shield", "Water Shield uppe: inget sköldråd: " .. tostring(spell))
	-- Du byter till Lightning Shield i strid: casten syns
	PC:OnPlayerCast(MOCK.known["Lightning Shield"])
	check(PC:LastShield() == "Lightning Shield", "casten följs")
	spell = PC:ManaAdvice()
	check(spell == "Water Shield", "nu: byt till Water Shield: " .. tostring(spell))
	MOCK.cooldowns[mt] = nil
	MOCK.combat, MOCK.auraLock = false, false
	PC:Shield()
	check(PC:LastShield() == false, "läsbart igen: ingen sköld")
	unlearnShields()
end)

test("v23: Clearcasting utan container står kvar som längst buffens längd när aurorna är låsta", function()
	local PC = ns.Procs
	local def = procDef("clearcast")
	local f = _G.FarseerProcclearcast
	local saved = ns.char.procs.clearcast
	ns.char.procs.clearcast = true
	check(PC:ProcBox("clearcast") == nil, "ingen container med knapp")
	MOCK.combat, MOCK.auraLock = false, false
	MOCK.auras.player = { { name = "Clearcasting", spellId = 16246, applications = 2, auraInstanceID = 601 } }
	PC:UpdateProc(def)
	check(f:IsShown(), "syns")
	check(ns.char.procSeen and ns.char.procSeen.clearcast, "setts")
	MOCK.combat, MOCK.auraLock = true, true
	MOCK.auras.player = {}
	MOCK.time = MOCK.time + 5
	PC:UpdateProc(def)
	check(f:IsShown(), "låst efter 5 s: står kvar")
	MOCK.time = MOCK.time + 11
	PC:UpdateProc(def)
	check(not f:IsShown(), "efter 16 s: borta")
	MOCK.combat, MOCK.auraLock = false, false
	ns.char.procs.clearcast = saved
	PC:UpdateProc(def)
end)

test("v23: Clearcasting i spelets aura-container (syns i strid)", function()
	local PC = ns.Procs
	local def = procDef("clearcast")
	local f = _G.FarseerProcclearcast
	local saved = ns.char.procs.clearcast
	ns.char.procs.clearcast = true
	MOCK.combat, MOCK.auraLock = false, false
	PC:ResetProcBoxes()
	local calls = {}
	local restoreCF = fakeContainer(calls)
	local box = PC:SetupProcBox(def)
	restoreCF()
	check(type(box) == "table", "byggd")
	check(calls.template == "CustomAuraContainerTemplate" and calls.unit == "player", "spelets container på dig")
	check(calls.filter == "HELPFUL" and calls.opts.candidateFilters.includeSpellIDs[16246] == true, "filtrerar på Clearcastings ID")
	check(calls.cd ~= nil and calls.count ~= nil and calls.icon ~= nil, "svep, tal och ikon kopplade")
	check(PC:ProcBox("clearcast") ~= nil and PC:ProcBoxState("clearcast") == "active", "aktiv")
	check(PC:SetupProcBox(def) == box, "samma box nästa gång")
	-- Låst: platsen hålls (osynlig) när buffen kan komma
	MOCK.combat, MOCK.auraLock = true, true
	MOCK.auras.player = {}
	ns.char.procSeen = { clearcast = true }
	PC:UpdateProc(def)
	check(f:IsShown() and f.icon:GetAlpha() == 0, "setts förut: osynlig plats i raden")
	ns.char.procSeen = {}
	PC:UpdateProc(def)
	check(not f:IsShown(), "aldrig setts och ingen talang: ingen plats")
	ns.char.procSeen = { clearcast = true }
	ns.fire("SPEC_CHANGED", "elemental", false)
	check(ns.char.procSeen.clearcast == nil, "ny spec glömmer det som setts")
	-- Läsbart igen: vår ikon är platshållare under spelets knapp
	MOCK.combat, MOCK.auraLock = false, false
	MOCK.auras.player = { { name = "Clearcasting", spellId = 16246, applications = 2, auraInstanceID = 602 } }
	PC:UpdateProc(def)
	check(f:IsShown() and f.icon:GetAlpha() == 0, "spelets knapp ritar, vår ikon är osynlig")
	MOCK.auras.player = {}
	PC:ResetProcBoxes()
	PC:UpdateProc(def)
	check(not f:IsShown(), "borta")
	ns.char.procs.clearcast = saved
end)

test("v23: skölden i strid med container: blek ikon under spelets knapp", function()
	local PC = ns.Procs
	local f = _G.FarseerProcshield
	local saved = ns.char.procs.shield
	local unlearnShields = learnShields()
	ns.char.procs.shield = true
	MOCK.combat, MOCK.auraLock = false, false
	PC:ResetShieldBox()
	local calls = {}
	local restoreCF = fakeContainer(calls)
	PC:SetupShieldBox()
	restoreCF()
	check(PC:ShieldBox() ~= nil, "containern har en knapp")
	MOCK.combat, MOCK.auraLock = true, true
	PC:UpdateShield()
	check(f:IsShown(), "platsen står kvar i strid")
	check(math.abs(f.icon:GetAlpha() - 0.35) < 0.01, "blek: " .. tostring(f.icon:GetAlpha()))
	MOCK.combat, MOCK.auraLock = false, false
	MOCK.auras.player = { { name = "Lightning Shield", spellId = 324, applications = 3, auraInstanceID = 701 } }
	PC:UpdateShield()
	check(f.icon:GetAlpha() == 1, "läsbart: full ikon")
	MOCK.auras.player = {}
	PC:ResetShieldBox()
	PC:UpdateShield()
	unlearnShields()
	ns.char.procs.shield = saved
end)

test("v23: Tremor varnar inte för Mind Control (possess) eller Death Coil (horror)", function()
	ns.Alert:Hide(true)
	MOCK.loc = { { locType = "POSSESS", displayText = "Possessed" } }
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() ~= "Tremor Totem", "possess: ingen Tremor")
	MOCK.loc = { { locType = "FEAR", displayText = "Horrified", spellID = 17926 } }
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() ~= "Tremor Totem", "Death Coil: ingen Tremor")
	MOCK.loc = { { locType = "FEAR", displayText = "Feared", spellID = 5782 } }
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "Tremor Totem", "vanlig fear: Tremor: " .. tostring(ns.Alert:Current()))
	MOCK.loc = {}
	MOCK.time = MOCK.time + 10
	ns.Advisor:Evaluate()
	ns.Alert:Hide(true)
end)

test("v23: containrarna byggs när en låsning släpper efter striden", function()
	local PC = ns.Procs
	local saved = ns.char.procs.clearcast
	ns.char.procs.clearcast = true
	MOCK.combat, MOCK.auraLock = false, true   -- t.ex. encounter: utanför strid men låst
	PC:ResetProcBoxes()
	PC:SetupProcBoxes()
	check(PC:ProcBoxState("clearcast") == "not built", "låst: byggs inte")
	MOCK.auraLock = false
	local calls = {}
	local restoreCF = fakeContainer(calls)
	MOCK.fire("ADDON_RESTRICTION_STATE_CHANGED", 1, 0)
	MOCK.runTimers()
	restoreCF()
	check(PC:ProcBoxState("clearcast") == "active", "byggd när låsningen släppt: " .. PC:ProcBoxState("clearcast"))
	PC:ResetProcBoxes()
	ns.char.procs.clearcast = saved
end)
