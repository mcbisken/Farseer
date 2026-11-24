-- Tester för v1.1: språk, HUD, totemdöd, Tremor-puls, profiler, utrustning, trainer, reagens, hit,
-- checklista, T0.5, BiS-jämförelse och nya flikar. Körs efter tests.lua (samma test()/check()).

local ns = FARSEER_NS
local test, check = TEST, CHECK

---------------------------------------------------------------------------------------------------
test("språk: tysk klient", function()
	-- Seed-ID:n får tyska namn; Farseer ska skriva tyska och förstå tyska tillbaka
	MOCK.spellNames[403] = "Blitzschlag"
	MOCK.spellNames[8042] = "Erdschock"
	MOCK.spellNames[8143] = "Totem des Erdstoßes"
	ns.Spellbook:BuildLocale()
	check(ns.L("Lightning Bolt") == "Blitzschlag", "L: " .. tostring(ns.L("Lightning Bolt")))
	check(ns.canon("Erdschock") == "Earth Shock", "canon")
	check(ns.L("Chain Lightning") == "Chain Lightning", "okänd förblir engelsk")
	local t = ns.localizeText("#showtooltip Lightning Bolt\n/cast [mod:shift] Earth Shock(Rank 1); Lightning Bolt")
	check(t == "#showtooltip Blitzschlag\n/cast [mod:shift] Erdschock(Rank 1); Blitzschlag", "makrotext: " .. t)
	check(ns.localizeText("/cast Lesser Healing Wave") == "/cast Lesser Healing Wave", "rör inte delar av andra namn")
	local body = ns.MacroEngine:Render(ns.MacroEngine:Template("ele_bolt"))
	check(body:find("Blitzschlag", 1, true) and not body:find("Lightning Bolt", 1, true), "mall på tyska: " .. body)
	-- totem castad med tyskt namn spåras som engelskt
	MOCK.learn("Totem des Erdstoßes", 8143)
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", 8143)
	check(ns.Totems:Active("Tremor Totem") == 2, "tyskt totemnamn spårat")
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "guid", MOCK.known["Totemic Recall"])
	MOCK.unlearn("Totem des Erdstoßes")
	MOCK.spellNames[403], MOCK.spellNames[8042], MOCK.spellNames[8143] = nil, nil, nil
	ns.Spellbook:Scan()
	MOCK.runTimers()
	check(not ns.localized(), "tillbaka till engelska")
end)

---------------------------------------------------------------------------------------------------
test("HUD: ikoner, cooldowns, räckvidd", function()
	ns.HUD:Layout()
	check(_G.FarseerHUD:IsShown(), "HUD visas")
	local found = {}
	for i = 1, 30 do
		local f = _G["FarseerHUDIcon" .. i]
		if f and f:IsShown() and f.entry then found[f.entry.key] = f end
	end
	check(found["Earth Shock"] and found["Stormstrike"] and found["Riptide"], "kända spells har ikoner")
	check(not found["Blood Fury"], "okänd rasförmåga visas inte")
	check(not found["trinket13"], "trinket utan use-effekt visas inte")
	-- dölj en ikon
	ns.char.hud.hidden["Stormstrike"] = true
	ns.HUD:Layout()
	local still = false
	for i = 1, 30 do
		local f = _G["FarseerHUDIcon" .. i]
		if f and f:IsShown() and f.entry and f.entry.key == "Stormstrike" then still = true end
	end
	check(not still, "dold ikon borta")
	ns.char.hud.hidden["Stormstrike"] = nil
	-- trinket med use
	MOCK.inventory[13] = 7777
	MOCK.useItems = { [7777] = true }
	ns.HUD:Layout()
	local trink
	for i = 1, 30 do
		local f = _G["FarseerHUDIcon" .. i]
		if f and f:IsShown() and f.entry and f.entry.key == "trinket13" then trink = f end
	end
	check(trink ~= nil, "trinket med use visas")
	MOCK.itemCooldowns = { [13] = { MOCK.time, 120 } }
	ns.HUD:UpdateCooldowns()
	MOCK.inventory[13], MOCK.useItems, MOCK.itemCooldowns = nil, nil, nil
	-- cooldowns: GCD hoppas över, riktig cooldown sätts
	local es = found["Earth Shock"]
	local set, cleared = 0, 0
	es.cd.SetCooldown = function() set = set + 1 end
	es.cd.Clear = function() cleared = cleared + 1 end
	MOCK.cooldowns[MOCK.known["Earth Shock"]] = { MOCK.time, 1.5, true }
	ns.HUD:UpdateCooldowns()
	check(set == 0 and cleared > 0, "GCD visas inte")
	MOCK.cooldowns[MOCK.known["Earth Shock"]] = { MOCK.time, 6 }
	ns.HUD:UpdateCooldowns()
	check(set == 1, "shock-cooldown satt")
	-- secret: duration-objekt i stället
	local viaObject = 0
	es.cd.SetCooldownFromDurationObject = function() viaObject = viaObject + 1 end
	MOCK.secretMode = true
	ns.HUD:UpdateCooldowns()
	MOCK.secretMode = false
	check(viaObject > 0, "secret cooldown via duration-objekt")
	MOCK.cooldowns = {}
	-- räckvidd
	MOCK.units.target = { name = "Dummy", hostile = true }
	MOCK.range = { ["Earth Shock"] = false, ["Lightning Bolt"] = true }
	ns.HUD:UpdateTimers()
	check(ns.HUD.InRange("Earth Shock") == false and ns.HUD.InRange("Lightning Bolt") == true, "räckvidd läst")
	MOCK.secretMode = true
	ns.HUD:UpdateTimers()
	check(ns.HUD.InRange("Earth Shock") == nil, "secret räckvidd = okänd")
	MOCK.secretMode = false
	MOCK.range = {}
	MOCK.units.target = nil
end)

test("HUD: Flame Shock, Riptide, swing", function()
	MOCK.units.target = { name = "Dummy", hostile = true, guid = "G1" }
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "cast1", MOCK.known["Flame Shock"])
	ns.HUD:UpdateTimers()
	local fs = _G.FarseerHUD
	-- hitta Flame Shock-baren via texten
	local bar
	local function walk(w)
		for _, c in ipairs(w.__children or {}) do
			if c.text and type(c.text.__text) == "string" and c.text.__text:find("Flame Shock") then bar = c end
			walk(c)
		end
	end
	walk(fs)
	check(bar ~= nil and bar:IsShown(), "Flame Shock-bar visas")
	MOCK.units.target = { name = "Annan", hostile = true, guid = "G2" }
	ns.HUD:UpdateTimers()
	check(not bar:IsShown(), "annat target: dold")
	MOCK.units.target = { name = "Dummy", hostile = true, guid = "G1" }
	MOCK.time = MOCK.time + 13
	ns.HUD:UpdateTimers()
	check(not bar:IsShown(), "efter 12 s: borta")
	MOCK.units.target = nil
	-- Riptide: målet från UNIT_SPELLCAST_SENT
	MOCK.fire("UNIT_SPELLCAST_SENT", "player", "Jaina", "castR", MOCK.known["Riptide"])
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "castR", MOCK.known["Riptide"])
	ns.HUD:UpdateTimers()
	local rip
	local function walk2(w)
		for _, c in ipairs(w.__children or {}) do
			if c.__kind == "FontString" and type(c.__text) == "string" and c.__text:find("Riptide") then rip = c end
			walk2(c)
		end
	end
	walk2(fs)
	check(rip and rip.__text:find("Jaina") and rip.__text:find("Chain Heal"), "Riptide på Jaina: " .. tostring(rip and rip.__text))
	MOCK.fire("UNIT_SPELLCAST_SENT", "player", "Jaina", "castC", MOCK.known["Chain Heal"])
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "castC", MOCK.known["Chain Heal"])
	ns.HUD:UpdateTimers()
	check(not rip:IsShown(), "Chain Heal förbrukade Riptiden")
	-- secret målnamn: "mål"
	MOCK.fire("UNIT_SPELLCAST_SENT", "player", SECRET, "castR2", MOCK.known["Riptide"])
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "castR2", MOCK.known["Riptide"])
	ns.HUD:UpdateTimers()
	check(rip.__text:find("target"), "okänt mål: " .. tostring(rip.__text))
	MOCK.time = MOCK.time + 16
	ns.HUD:UpdateTimers()
	-- swing
	MOCK.combat = true
	MOCK.fire("PLAYER_SWING", 2.6, 0)
	ns.HUD:UpdateTimers()
	local sw
	local function walk3(w)
		for _, c in ipairs(w.__children or {}) do
			if c.__kind == "StatusBar" and c.text and type(c.text.__text) == "string" and c.text.__text:match("^%d") then sw = c end
			walk3(c)
		end
	end
	walk3(fs)
	check(sw and sw:IsShown(), "swing-bar visas")
	MOCK.fire("PLAYER_SWING", SECRET, 0)  -- secret duration: vapnets hastighet
	ns.HUD:UpdateTimers()
	check(sw:IsShown(), "secret swing använder vapenhastighet")
	MOCK.fire("PLAYER_SWING", 2.6, 1)  -- offhand ignoreras
	MOCK.combat = false
	MOCK.fire("PLAYER_LEAVE_COMBAT")
	ns.HUD:UpdateTimers()
	check(not sw:IsShown(), "swing borta efter strid")
end)

---------------------------------------------------------------------------------------------------
test("totems: dog i förtid / Grounding åt en spell", function()
	local function cast(name) MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known[name]) end
	-- som klienten: casten fyller slotten och ger en slot-uppdatering
	local function place(name)
		local slot = MOCK.TOTEM_SLOT[name]
		MOCK.totems[slot] = { name = name, start = MOCK.time, dur = ns.TOTEMS[name].dur }
		cast(name)
		MOCK.fire("PLAYER_TOTEM_UPDATE", slot)
	end
	local function clear(slot)
		MOCK.totems[slot] = nil
		MOCK.fire("PLAYER_TOTEM_UPDATE", slot)
	end
	local function settle()
		local p = MOCK.timers
		MOCK.timers = {}
		for _, fn in ipairs(p) do fn() end
	end
	cast("Grounding Totem")
	MOCK.totems[4] = { name = "Grounding Totem", start = MOCK.time, dur = 45 }
	MOCK.fire("PLAYER_TOTEM_UPDATE", 4)
	MOCK.runTimers()
	check(ns.Alert:Current() ~= "died-Grounding Totem", "ingen varning när totemet sätts")
	MOCK.time = MOCK.time + 5
	MOCK.totems[4] = nil
	MOCK.fire("PLAYER_TOTEM_UPDATE", 4)
	MOCK.runTimers()
	check(ns.Alert:Current() == nil, "varningen har gått ut efter sin tid (timers kördes): " .. tostring(ns.Alert:Current()))
	-- kör igen utan att låta flash-timern gå
	cast("Grounding Totem")
	MOCK.time = MOCK.time + 5
	MOCK.fire("PLAYER_TOTEM_UPDATE", 4)
	local pending = MOCK.timers
	MOCK.timers = {}
	for _, fn in ipairs(pending) do fn() end
	check(ns.Alert:Current() == "died-Grounding Totem", "Grounding-varning: " .. tostring(ns.Alert:Current()))
	check(ns.Totems:Active("Grounding Totem") == nil, "borttaget ur spårningen")
	-- rådgivaren skriver inte över varningen direkt
	ns.Advisor:Evaluate()
	check(ns.Alert:Current() == "died-Grounding Totem", "flash ligger kvar")
	MOCK.runTimers()
	ns.Advisor:Evaluate()
	-- byte till annat lufttotem: ingen varning
	place("Windfury Totem")
	settle()
	MOCK.time = MOCK.time + 5
	place("Grace of Air Totem")
	settle()
	check(ns.Alert:Current() ~= "died-Windfury Totem", "byte ger ingen varning")
	check(ns.Totems:SlotTotem(4) == "Grace of Air Totem", "Grace of Air ute")
	-- Recall: slottarna töms, ingen varning
	MOCK.time = MOCK.time + 5
	cast("Totemic Recall")
	clear(4)
	settle()
	check(not tostring(ns.Alert:Current()):find("died"), "recall ger ingen varning")
	-- utgång av sig själv: ingen varning
	place("Stoneclaw Totem")
	settle()
	MOCK.time = MOCK.time + 14.5
	clear(2)
	settle()
	check(not tostring(ns.Alert:Current()):find("died"), "utgång ger ingen varning")
	-- högerklick-borttagning: ingen varning
	place("Tremor Totem")
	settle()
	MOCK.time = MOCK.time + 3
	_G.FarseerTotemEARTH:Click("RightButton", false)
	clear(2)
	settle()
	check(not tostring(ns.Alert:Current()):find("died"), "egen borttagning ger ingen varning")
	-- fienden slår sönder Tremor i strid (slotten secret): varning bara på händelsen
	place("Tremor Totem")
	settle()
	MOCK.time = MOCK.time + 10
	MOCK.secretMode = true
	MOCK.fire("PLAYER_TOTEM_UPDATE", 2)
	settle()
	MOCK.secretMode = false
	check(ns.Alert:Current() == "died-Tremor Totem", "secret slot: Tremor dog: " .. tostring(ns.Alert:Current()))
	MOCK.totems[2] = nil
	cast("Totemic Recall")
	MOCK.runTimers()
end)

test("Tremor-puls", function()
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Tremor Totem"])
	MOCK.time = MOCK.time + 1
	local p = ns.Totems:TremorPulse()
	check(p and math.abs(p - 3) < 0.01, "3 s till puls: " .. tostring(p))
	ns.Totems:UpdateTimes()
	check(_G.FarseerTotemEARTH.pulse.__text:find("3.0"), "pulstext: " .. tostring(_G.FarseerTotemEARTH.pulse.__text))
	MOCK.time = MOCK.time + 3.5
	check(math.abs(ns.Totems:TremorPulse() - 3.5) < 0.01, "nästa puls")
	ns.char.totemAlerts.tremorPulse = false
	ns.Totems:UpdateTimes()
	check(_G.FarseerTotemEARTH.pulse.__text == "", "avstängd")
	ns.char.totemAlerts.tremorPulse = true
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", "g", MOCK.known["Totemic Recall"])
	check(ns.Totems:TremorPulse() == nil, "ingen puls utan Tremor")
end)

test("kontratotems har cooldown-svep", function()
	ns.Bars:ApplyCounter()
	local b = _G.FarseerCounter1
	check(b.cd ~= nil, "cooldown-ram finns")
	local set = 0
	b.cd.SetCooldown = function() set = set + 1 end
	MOCK.cooldowns[MOCK.known[b.spell]] = { MOCK.time, 15 }
	MOCK.fire("SPELL_UPDATE_COOLDOWN")
	check(set > 0, "cooldown satt för " .. tostring(b.spell))
	MOCK.cooldowns = {}
end)

---------------------------------------------------------------------------------------------------
test("profiler: serialisering", function()
	local P = ns.Profiles
	local t = { a = 1, b = "x:y{}s3:", c = { true, false, 2.5, "åäö\nrad" }, [5] = -3, d = {} }
	local back = P.Deserialize(P.Serialize(t))
	check(back and back.a == 1 and back.b == "x:y{}s3:" and back.c[1] == true and back.c[2] == false
		and back.c[3] == 2.5 and back.c[4] == "åäö\nrad" and back[5] == -3 and type(back.d) == "table", "rundtur")
	for _, s in ipairs({ "", "a", "M", "ma", "man", "Farseer!", string.rep("xyz", 50) .. "\0\255" }) do
		check(P.FromBase64(P.ToBase64(s)) == s, "base64 " .. #s)
	end
	check(P.ToBase64("Man") == "TWFu" and P.ToBase64("Ma") == "TWE=", "base64 standard")
	for _, bad in ipairs({ "{", "s5:ab", "n;", "{s1:a}", "Q", "{s1:as1:b}x" }) do
		local v, err = P.Deserialize(bad)
		check(v == nil and err, "trasig data nekas: " .. bad)
	end
end)

test("profiler: spara, ladda, exportera, importera", function()
	local P = ns.Profiles
	ns.char.seqReset = 7
	ns.char.situations.PVE[1].name = "Min Melee"
	ns.db.macros.mouseover = false
	check(P:Save("Raid"), "sparad")
	ns.char.seqReset = 12
	ns.char.situations.PVE[1].name = "Ändrad"
	ns.db.macros.mouseover = true
	check(P:Load("Raid"), "laddad")
	check(ns.char.seqReset == 7 and ns.char.situations.PVE[1].name == "Min Melee" and ns.db.macros.mouseover == false, "värden tillbaka")
	check(ns.char.profile == "Raid", "aktiv profil")
	check(_G.FarseerSit1:GetAttribute("macrotext"):find("reset=combat/7", 1, true), "bars uppdaterade")
	local text = P:Export("Raid")
	check(text:find("^FS1:"), "FS1 utan C_EncodingUtil")
	local ok, name = P:Import(text, "Kopia")
	check(ok and name == "Kopia" and ns.db.profiles["Kopia"], "importerad")
	check(ns.db.profiles["Kopia"].char.seqReset == 7, "importens innehåll")
	check(not P:Import("hej"), "fel prefix")
	check(not P:Import("FS1:@@@@"), "trasig base64")
	check(not P:Import("FS1:" .. P.ToBase64(P.Serialize({ x = 1 }))), "inte en profil")
	-- med klientens komprimering
	C_EncodingUtil = {
		CompressString = function(s) return "Z" .. s end, DecompressString = function(s) return s:sub(2) end,
		EncodeBase64 = function(s) return P.ToBase64(s) end, DecodeBase64 = function(s) return P.FromBase64(s) end,
	}
	-- (Profiles.lua läste C_EncodingUtil vid laddning: FS2 testas därför via Decode med egen text)
	local z = "FS2:" .. P.ToBase64("Z" .. P.Serialize(P:Snapshot()))
	local pz, err = P:Decode(z)
	check(pz == nil and err, "FS2 utan uppackning vid laddning ger fel, inte krasch")
	C_EncodingUtil = nil
	-- skadlig profil: fel typer ignoreras
	local evil = P:Snapshot()
	evil.char.bars = "inte en tabell"
	evil.char.seqReset = 9
	check(P:Apply(evil), "apply")
	check(type(ns.char.bars) == "table" and ns.char.seqReset == 9, "fel typ ignorerad")
	MOCK.combat = true
	check(not P:Load("Raid"), "inte i strid")
	MOCK.combat = false
	P:Delete("Kopia")
	check(ns.db.profiles["Kopia"] == nil, "borttagen")
	ns.char.seqReset = 10
	ns.db.macros.mouseover = true
	ns.char.situations.PVE[1].name = "Melee"
	ns.Bars:Refresh()
end)

---------------------------------------------------------------------------------------------------
test("utrustningsset", function()
	MOCK.equipSets = { [1] = { name = "PvE Resto", equipped = true }, [2] = { name = "PvP" } }
	MOCK.fire("EQUIPMENT_SETS_CHANGED")
	check(_G.FarseerGear1 and _G.FarseerGear1:IsShown() and _G.FarseerGear2:IsShown(), "knappar")
	_G.FarseerGear2:Click()
	check(MOCK.usedSet == 2, "klick byter")
	check(ns.Gear:Equip("pve"), "delnamn hittar PvE Resto")
	check(MOCK.usedSet == 1, "PvE på")
	ns.char.gear.auto, ns.char.gear.pvp, ns.char.gear.pve = true, "PvP", "PvE Resto"
	MOCK.usedSet = nil
	ns.Bars:SetMode("PVP", true)
	check(MOCK.usedSet == 2, "auto: PvP-set vid PvP-läge")
	ns.Bars:SetMode("PVP", true)
	MOCK.usedSet = nil
	ns.Bars:SetMode("PVP", true)
	check(MOCK.usedSet == nil, "samma läge igen: inget byte")
	MOCK.combat = true
	MOCK.fire("PLAYER_REGEN_DISABLED")
	ns.Bars:SetMode("PVE", true)
	check(MOCK.usedSet == nil, "i strid: väntar")
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(MOCK.usedSet == 1, "efter strid: PvE-set")
	check(not ns.Gear:Equip("finns inte"), "okänt set")
	ns.char.gear.auto = false
	SlashCmdList.FARSEER("gear")
	SlashCmdList.FARSEER("gear pvp")
	check(MOCK.usedSet == 2, "slash byter")
	MOCK.equipSets = {}
	MOCK.fire("EQUIPMENT_SETS_CHANGED")
	check(not _G.FarseerGearBar:IsShown(), "inga set: dold")
end)

---------------------------------------------------------------------------------------------------
test("trainer: nya ranker", function()
	-- Lär dig exakt de ranker som finns på level 20 med trainertabellens ID:n
	local saved = {}
	for k, v in pairs(MOCK.known) do saved[k] = v end
	wipe(MOCK.known)
	local best = {}
	for _, r in ipairs(ns.TRAINER.ranks) do
		if r.level <= 20 and not r.talentUpgrade and (not best[r.spell] or r.rank > best[r.spell].rank) then best[r.spell] = r end
	end
	for spell, r in pairs(best) do MOCK.learn(spell, r.id) end
	MOCK.level = 20
	ns.Spellbook:Scan()
	local missing = ns.Spellbook:TrainerMissing(20)
	check(#missing == 0, "allt inlärt: " .. ns.Leveling:TrainerText(missing))
	-- level 26: nya ranker av sådant du kan, inte spells du aldrig lärt dig
	local m26 = ns.Spellbook:TrainerMissing(26)
	check(#m26 > 0, "nya ranker på 26")
	for _, r in ipairs(m26) do
		check(r.level <= 26, "inom level: " .. r.spell)
		if best[r.spell] then check(r.rank > best[r.spell].rank, "högre rank: " .. r.spell) end
	end
	local lb
	for _, r in ipairs(m26) do if r.spell == "Lightning Bolt" then lb = r end end
	check(lb and lb.rank > best["Lightning Bolt"].rank, "Lightning Bolt ny rank")
	-- kommande
	local up = ns.Spellbook:TrainerUpcoming(20, 24)
	local n = 0
	for _ in pairs(up) do n = n + 1 end
	check(n > 0, "kommande levels")
	-- chattmeddelande vid level up
	local before = #MOCK.printed
	MOCK.level = 26
	MOCK.fire("PLAYER_LEVEL_UP", 26)
	MOCK.runTimers()
	local said = false
	for i = before + 1, #MOCK.printed do if MOCK.printed[i]:find("trainer") then said = true end end
	check(said, "meddelande vid level up")
	-- tillbaka
	wipe(MOCK.known)
	for k, v in pairs(saved) do MOCK.known[k] = v end
	MOCK.level = 60
	ns.Spellbook:Scan()
	MOCK.runTimers()
end)

test("reagens, hit och checklista", function()
	local LV = ns.Leveling
	MOCK.itemCounts[17030] = 0
	local r = LV:Reagents()
	local ankh
	for _, x in ipairs(r) do if x.def.item == 17030 then ankh = x end end
	check(ankh and ankh.low and ankh.count == 0, "Ankh saknas")
	local before = #MOCK.printed
	LV:WarnReagents()
	LV:WarnReagents()
	local n = 0
	for i = before + 1, #MOCK.printed do if MOCK.printed[i]:find("Ankh") then n = n + 1 end end
	check(n == 1, "varnar en gång: " .. n)
	MOCK.itemCounts[17030] = 5
	-- perken tar bort reagens
	MOCK.learn("Reagent Economy", ns.REAGENT_PERK)
	check(#LV:Reagents() == 0, "Reagent Economy")
	MOCK.unlearn("Reagent Economy")
	MOCK.spellNames[ns.REAGENT_PERK] = nil
	-- hit
	MOCK.spellHit, MOCK.meleeHit = 3, 5
	MOCK.ratings = { [8] = 12 }
	local sh, mh = LV:Hit()
	check(sh == 15 and mh == 5, "hit: " .. tostring(sh) .. "/" .. tostring(mh))
	MOCK.secretMode = true
	sh = LV:Hit()
	check(sh == 0, "secret hit räknas som 0, inget fel")
	MOCK.secretMode = false
	-- checklista
	MOCK.auras.player = { { name = "Lightning Shield" }, { name = "Well Fed" }, { name = "Flask of Supreme Power" } }
	MOCK.weaponEnchant = { true, 30 * 60000 }
	MOCK.durability = { [1] = { 50, 100 }, [5] = { 10, 100 } }
	ns.char.bisSpec = "elemental"
	local list = LV:ShowChecklist()
	local byText = {}
	for _, it in ipairs(list) do byText[it.text:match("^[^%(]+")] = it.ok end
	check(byText["Shield up "] == true, "sköld OK")
	check(byText["Food buff "] == true and byText["Flask/elixir "] == true, "mat och flaska")
	local dur
	for _, it in ipairs(list) do if it.text:find("Durability") then dur = it end end
	check(dur and dur.ok == false and dur.text:find("10"), "hållbarhet 10 %")
	local hit
	for _, it in ipairs(list) do if it.text:find("Spell hit") then hit = it end end
	check(hit and hit.ok == false, "spell hit under cap")
	check(_G.FarseerChecklist:IsShown(), "fönster visas")
	LV:HideChecklist()
	MOCK.fire("READY_CHECK")
	check(_G.FarseerChecklist:IsShown(), "ready check visar checklistan")
	LV:HideChecklist()
	-- i strid: auror okända, inget fel
	MOCK.combat = true
	MOCK.secretMode = true
	list = LV:Checklist()
	check(#list > 3, "checklista i strid")
	MOCK.combat = false
	MOCK.secretMode = false
	MOCK.auras.player, MOCK.durability, MOCK.ratings, MOCK.spellHit, MOCK.meleeHit = {}, {}, nil, nil, nil
	MOCK.weaponEnchant = { true, 3600000 }
end)

test("T0.5-kedjan", function()
	local LV = ns.Leveling
	local list, done, nxt = LV:T05Progress()
	check(#list == 29 and done == 0 and nxt == 1, "start")
	MOCK.quests[list[3].step.id] = true
	list, done, nxt = LV:T05Progress()
	check(done == 3 and nxt == 4, "senare klart steg markerar tidigare: " .. done .. "/" .. tostring(nxt))
	MOCK.questLog[list[4].step.id] = 7
	list = LV:T05Progress()
	check(list[4].state == "active", "pågår")
	for _, r in ipairs(list) do if r.step.id then MOCK.quests[r.step.id] = true end end
	list, done, nxt = LV:T05Progress()
	check(done == 29 and nxt == nil, "allt klart")
	MOCK.quests, MOCK.questLog = {}, {}
	for _, st in ipairs(ns.T05.steps) do
		check(type(st.name) == "string" and st.name ~= "", "steg har namn")
	end
end)

test("BiS: jämförelse med utrustningen", function()
	ns.char.bisSpec = "elemental"
	ns.char.bisPhase = "prebis"
	local list = ns.BIS.specs.elemental.prebis
	local head
	for _, e in ipairs(list) do if e.slot == "HEAD" then head = e end end
	MOCK.inventory[1] = head.id
	MOCK.inventory[3] = 111
	ns.Options:Open("bis")
	local foundBis, foundUp = false, false
	local function walk(w)
		for _, c in ipairs(w.__children or {}) do
			if c.__kind == "FontString" and type(c.__text) == "string" then
				if c.__text:find("BiS on") then foundBis = true end
				if c.__text:find("Next upgrades") and c.__text:find("Shoulders") and not c.__text:find("Head") then foundUp = true end
			end
			walk(c)
		end
	end
	walk(_G.FarseerOptions)
	check(foundBis, "BiS på-markering")
	check(foundUp, "Axlar som uppgradering, inte Huvud")
	MOCK.inventory[1], MOCK.inventory[3] = nil, nil
	ns.Options:Toggle()
end)

---------------------------------------------------------------------------------------------------
test("UI: nya flikar och flikrader", function()
	ns.Options:Open()
	for _, id in ipairs({ "combat", "leveling", "t05", "profiles", "settings", "overview" }) do ns.UI.SelectTab(id) end
	check(_G.FarseerOptions:GetHeight() > 620, "två flikrader gör fönstret högre: " .. _G.FarseerOptions:GetHeight())
	-- alla kryssrutor på Strid-fliken går att klicka
	ns.UI.SelectTab("combat")
	ns.Options:Toggle()
	for _, c in ipairs({ "check", "trainer", "t05", "profile", "profile save Test", "profile load Test", "profile load Saknas" }) do
		SlashCmdList.FARSEER(c)
	end
	ns.Profiles:Delete("Test")
	ns.Leveling:HideChecklist()
	if _G.FarseerOptions:IsShown() then ns.Options:Toggle() end
end)

test("secret values: nya moduler", function()
	MOCK.secretMode = true
	MOCK.combat = true
	MOCK.units.target = { name = "X", hostile = true }
	MOCK.fire("SPELL_UPDATE_COOLDOWN")
	MOCK.fire("PLAYER_SWING", SECRET, SECRET)
	MOCK.fire("UNIT_SPELLCAST_SENT", "player", SECRET, SECRET, SECRET)
	MOCK.fire("UNIT_SPELLCAST_SUCCEEDED", "player", SECRET, SECRET)
	MOCK.fire("PLAYER_TOTEM_UPDATE", 4)
	MOCK.runTimers()
	ns.HUD:UpdateTimers()
	ns.HUD:UpdateCooldowns()
	ns.Leveling:Checklist()
	ns.Gear:Layout()
	MOCK.secretMode = false
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	MOCK.units.target = nil
	MOCK.runTimers()
end)
