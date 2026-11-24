-- Shaman-spells och totems i WoW: Forever 1.60.1.
-- Totemelementen läses i spelet (GetMultiCastTotemSpells), tabellen nedan är bara reserv
-- (vanilla-indelningen: Fire Resistance = vatten, Frost Resistance = eld, Nature Resistance = luft).

local _, ns = ...

-- Klientens totemslottar
ns.SLOT = { FIRE = 1, EARTH = 2, WATER = 3, AIR = 4 }
ns.SLOT_ELEMENT = { [1] = "FIRE", [2] = "EARTH", [3] = "WATER", [4] = "AIR" }
ns.ELEMENTS = { "EARTH", "FIRE", "WATER", "AIR" }
ns.ELEMENT_NAME = { EARTH = "Earth", FIRE = "Fire", WATER = "Water", AIR = "Air" }
ns.ELEMENT_COLOR = {
	EARTH = { 0.78, 0.55, 0.25 },
	FIRE = { 0.95, 0.38, 0.15 },
	WATER = { 0.25, 0.65, 0.95 },
	AIR = { 0.65, 0.85, 0.95 },
}

-- Totems: element (reserv) och livstid i sekunder (reserv; riktiga tider lärs in i spelet)
ns.TOTEMS = {
	["Stoneskin Totem"] = { el = "EARTH", dur = 300 },
	["Earthbind Totem"] = { el = "EARTH", dur = 45 },
	["Stoneclaw Totem"] = { el = "EARTH", dur = 15 },
	["Strength of Earth Totem"] = { el = "EARTH", dur = 300 },
	["Tremor Totem"] = { el = "EARTH", dur = 300 },

	["Searing Totem"] = { el = "FIRE", dur = 30 },
	["Magma Totem"] = { el = "FIRE", dur = 20 },
	["Flametongue Totem"] = { el = "FIRE", dur = 300 },
	["Frost Resistance Totem"] = { el = "FIRE", dur = 300 },

	["Healing Stream Totem"] = { el = "WATER", dur = 300 },
	["Mana Spring Totem"] = { el = "WATER", dur = 300 },
	["Poison Cleansing Totem"] = { el = "WATER", dur = 300 },
	["Disease Cleansing Totem"] = { el = "WATER", dur = 300 },
	["Fire Resistance Totem"] = { el = "WATER", dur = 300 },
	["Mana Tide Totem"] = { el = "WATER", dur = 12 },

	["Grounding Totem"] = { el = "AIR", dur = 45 },
	["Windfury Totem"] = { el = "AIR", dur = 300 },
	["Grace of Air Totem"] = { el = "AIR", dur = 300 },
	["Windwall Totem"] = { el = "AIR", dur = 300 },
	["Nature Resistance Totem"] = { el = "AIR", dur = 300 },
	["Sentry Totem"] = { el = "AIR", dur = 300 },
}

-- Spells som drar ner flera totems / plockar upp dem
ns.CALLS = { "Call of the Elements", "Call of the Ancestors", "Call of the Spirits" }
ns.CALL_LEVEL = { 20, 30, 40 }
ns.RECALL = "Totemic Recall"
ns.TOTEMIC_CALL = "Totemic Call"

ns.SHIELDS = { "Lightning Shield", "Water Shield" }
ns.IMBUES = { "Windfury Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Rockbiter Weapon" }

-- Kända spell-ID:n (från klientdata, för självtest och reserv när namnuppslag misslyckas)
ns.SPELL_IDS = {
	["Lightning Shield"] = { 324, 325, 905, 945, 8134, 10431, 10432 },
	["Water Shield"] = { 408510 },
	["Earth Shock"] = { 8042 },
	["Flame Shock"] = { 8050, 8052, 8053, 10447, 10448, 29228 },
	["Frost Shock"] = { 8056, 8058, 10472, 10473 },
	["Purge"] = { 370, 8012 },
	["Earthbind Totem"] = { 2484 },
	["Stoneclaw Totem"] = { 5730 },
	["Fire Nova"] = { 408341 },
	["Rockbiter Weapon"] = { 8017 },
	["Flametongue Weapon"] = { 8024 },
	["Frostbrand Weapon"] = { 8033 },
	["Windfury Weapon"] = { 8232 },
	["Call of the Elements"] = { 66842 },
	["Call of the Ancestors"] = { 66843 },
	["Call of the Spirits"] = { 66844 },
	["Totemic Recall"] = { 36936 },
	["Tremor Totem"] = { 8143 },
	["Cure Poison"] = { 526 },
	["Cure Disease"] = { 2870 },
	["Nature's Swiftness"] = { 16188 },
	["Lightning Mastery"] = { 16166 },
	["Mana Tide Totem"] = { 16190 },
	["Grounding Totem"] = { 8177 },
	["Stormstrike"] = { 17364 },
	["Riptide"] = { 408521, 1239242, 1239243 },
	["Rage of the Farseer"] = { 425336 },
	["Totemic Call"] = { 437009 },
	["Reincarnation"] = { 20608 },
	["Water Walking"] = { 546 },
	["Water Breathing"] = { 131 },
	["Chain Lightning"] = { 421, 930, 2860, 10605 },
}

-- Fler seed-ID:n (talanger, rasförmågor, Forever-nytt). Trainerns ranker finns i Data/Ranks.lua.
local EXTRA_IDS = {
	["Lightning Bolt"] = { 403 }, ["Healing Wave"] = { 331 }, ["Lesser Healing Wave"] = { 8004 }, ["Chain Heal"] = { 1064 },
	["Ghost Wolf"] = { 2645 }, ["Ancestral Spirit"] = { 2008 }, ["Astral Recall"] = { 556 }, ["Far Sight"] = { 6196 },
	["Stoneskin Totem"] = { 8071 }, ["Strength of Earth Totem"] = { 8075 }, ["Searing Totem"] = { 3599 },
	["Magma Totem"] = { 8190 }, ["Flametongue Totem"] = { 8227 }, ["Frost Resistance Totem"] = { 8181 },
	["Healing Stream Totem"] = { 5394 }, ["Mana Spring Totem"] = { 5675 }, ["Poison Cleansing Totem"] = { 8166 },
	["Disease Cleansing Totem"] = { 8170 }, ["Fire Resistance Totem"] = { 8184 }, ["Windfury Totem"] = { 8512 },
	["Grace of Air Totem"] = { 8835 }, ["Windwall Totem"] = { 15107 }, ["Nature Resistance Totem"] = { 10595 },
	["Sentry Totem"] = { 6495 }, ["Maelstrom Weapon"] = { 408498 },
	["Blood Fury"] = { 20572 }, ["Berserking"] = { 20554 }, ["War Stomp"] = { 20549 }, ["Stoneform"] = { 20594 },
}
for name, ids in pairs(EXTRA_IDS) do
	if not ns.SPELL_IDS[name] then ns.SPELL_IDS[name] = ids end
end

-- Rasförmågor som makron kan använda
ns.RACIAL_OFFENSIVE = { "Blood Fury", "Berserking" }
ns.RACIALS = { "Blood Fury", "Berserking", "War Stomp", "Stoneform" }

-- Strids-HUD: cooldowns i den här ordningen (bara de du kan visas). range = tonas röd utom räckhåll.
ns.HUD_SPELLS = {
	{ spell = "Earth Shock", range = true, note = "Shocks share a cooldown" },
	{ spell = "Stormstrike", range = true },
	{ spell = "Chain Lightning", range = true },
	{ spell = "Riptide" },
	{ spell = "Fire Nova" },
	{ spell = "Nature's Swiftness" },
	{ spell = "Lightning Mastery" },
	{ spell = "Rage of the Farseer" },
	{ spell = "Mana Tide Totem" },
	{ spell = "Reincarnation" },
	{ spell = "Blood Fury" }, { spell = "Berserking" }, { spell = "War Stomp" }, { spell = "Stoneform" },
	{ trinket = 13 }, { trinket = 14 },
}

-- Reagens (ShamanForever + Wowhead Forever). Perken Reagent Economy tar bort dem.
ns.REAGENTS = {
	{ spell = "Reincarnation", item = 17030, name = "Ankh", low = 1 },
	{ spell = "Water Walking", item = 17058, name = "Fish Oil", low = 2 },
	{ spell = "Water Breathing", item = 17057, name = "Shiny Fish Scale", low = 2 },
}
ns.REAGENT_PERK = 1225503

-- Durationer som Farseer räknar själv (sekunder)
ns.FLAME_SHOCK_DUR = 12
ns.RIPTIDE_DUR = 15
ns.TREMOR_PULSE = 4

-- Hit-cap enligt conquestcapped (WoW: Forever): 17 % spell mot raidbossar, 8 % melee
ns.HIT_CAP = { spell = 17, melee = 8 }

---------------------------------------------------------------------------------------------------
-- v1.2: procs, sköldladdningar, totembuffar, spec
---------------------------------------------------------------------------------------------------
-- Maelstrom Weapon: buffens ID (talangen är 408498), max stacks
ns.MAELSTROM_BUFF = { 408505 }
ns.MAELSTROM_MAX = 5
-- Lightning/Water Shield: laddningar när skölden är ny
ns.SHIELD_CHARGES = 3
ns.SHIELD_IDS = {
	["Lightning Shield"] = { 324, 325, 905, 945, 8134, 10431, 10432 },
	["Water Shield"] = { 408510 },
}

-- Windfury-procs: spell-ID:n som får en cooldown när Windfury slår (ShamanForever). 439431 är
-- själva vapenförtrollningen och räknas inte.
ns.WINDFURY_PROCS = {
	[439440] = "weapon", [439441] = "weapon", [461636] = "weapon", [8233] = "weapon", [8236] = "weapon",
	[10484] = "weapon", [16361] = "weapon", [16363] = "weapon",
	[8516] = "totem", [10608] = "totem", [10610] = "totem",
}
ns.WINDFURY_NAMES = { ["Windfury Attack"] = "weapon", ["Windfury Weapon"] = "weapon", ["Windfury Totem"] = "totem" }

-- Totems som ger dig en buff (för "utom räckhåll"): buffens namn och ID:n (Classic, alla ranker)
ns.TOTEM_BUFFS = {
	["Strength of Earth Totem"] = { name = "Strength of Earth", ids = { 8076, 8162, 8163, 10441, 25362 } },
	["Stoneskin Totem"] = { name = "Stoneskin", ids = { 8072, 8156, 8157, 10403, 10404, 10405 } },
	["Frost Resistance Totem"] = { name = "Frost Resistance", ids = { 8182, 10476, 10477 } },
	["Healing Stream Totem"] = { name = "Healing Stream", ids = { 5672, 6371, 6372, 10460, 10461 } },
	["Mana Spring Totem"] = { name = "Mana Spring", ids = { 5677, 10491, 10493, 10494 } },
	["Fire Resistance Totem"] = { name = "Fire Resistance", ids = { 8185, 10534, 10535 } },
	["Grace of Air Totem"] = { name = "Grace of Air", ids = { 8836, 10626, 25360 } },
	["Nature Resistance Totem"] = { name = "Nature Resistance", ids = { 10596, 10598, 10599 } },
	["Windwall Totem"] = { name = "Windwall", ids = { 15108, 15109, 15110 } },
}

-- Spec: talangflikarnas ordning och talanger som avslöjar specen (om talangpoängen inte går att läsa)
ns.SPEC_TABS = { "elemental", "enhancement", "restoration" }
ns.SPEC_NAME = { elemental = "Elemental", enhancement = "Enhancement", restoration = "Restoration" }
ns.SPEC_SIGNATURE = {
	{ "enhancement", "Stormstrike" },
	{ "restoration", "Mana Tide Totem" },
	{ "restoration", "Riptide" },
	{ "elemental", "Lightning Mastery" },
}

-- Diminishing returns: återställs efter så här många sekunder utan ny CC
ns.DR_RESET = 18

-- Låg mana: förslag i den här ordningen
ns.MANA_HELP = { "Mana Tide Totem", "Water Shield", "Mana Spring Totem" }
