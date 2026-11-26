-- Regeldata för totemvarningarna. Listorna kan utökas i spelet (Varningar-fliken).

local _, ns = ...

-- Fientlig spelare av klassen -> kontratotems (högst prioritet först)
ns.PVP_CLASS_RULES = {
	WARLOCK = { { "Tremor Totem", 75, "Warlock: Fear / Howl of Terror / Seduction" }, { "Grounding Totem", 55, "Warlock: Fear / Death Coil" } },
	PRIEST = { { "Tremor Totem", 75, "Priest: Psychic Scream / Mind Control" }, { "Grounding Totem", 45, "Priest: Mind Blast / Mana Burn" } },
	ROGUE = { { "Poison Cleansing Totem", 65, "Rogue: poisons" }, { "Earthbind Totem", 50, "Rogue: keep your distance" } },
	HUNTER = { { "Poison Cleansing Totem", 60, "Hunter: Serpent/Viper Sting" }, { "Earthbind Totem", 50, "Hunter: pet & kiting" },
		{ "Windwall Totem", 40, "Hunter: reduces arrow damage" }, { "Stoneclaw Totem", 30, "Hunter: Stoneclaw taunts the pet" },
		{ "Tremor Totem", 25, "Hunter: Wyvern Sting / Scare Beast" } },
	MAGE = { { "Grounding Totem", 70, "Mage: Polymorph / Frostbolt" }, { "Frost Resistance Totem", 40, "Mage: frost damage" },
		{ "Earthbind Totem", 35, "Mage: blink-kiting" } },
	WARRIOR = { { "Earthbind Totem", 60, "Warrior: kite with Earthbind" }, { "Tremor Totem", 45, "Warrior: Intimidating Shout" } },
	PALADIN = { { "Earthbind Totem", 50, "Paladin: kite" }, { "Grounding Totem", 30, "Paladin: Hammer of Justice" } },
	DRUID = { { "Grounding Totem", 55, "Druid: Entangling Roots / Hibernate" }, { "Earthbind Totem", 45, "Druid: feral" } },
	SHAMAN = { { "Grounding Totem", 60, "Shaman: Lightning Bolt / Purge" }, { "Earthbind Totem", 30, "Shaman: Ghost Wolf" } },
}

-- Mobs/bossar som fearar, charmar eller söver (namn som i spelet, engelska klienten)
ns.FEAR_MOBS = {
	"Magmadar", "Onyxia", "Nefarian", "Lord Victor Nefarius", "Princess Yauj", "Flamewaker Protector",
	"Lady Illucia Barov", "Balnazzar", "Archimonde", "Anetheron", "Dreadlord", "Highborne Apparition",
	"Scarlet Enchanter", "Death Singer", "Blighted Horror", "Dread Weaver", "Mist Howler",
	"Pterrordax", "Frenzied Pterrordax", "Mosh'Ogg Lord", "Crushridge Enforcer",
	-- WoW: Forever-dungeons och klassiska 55-60 (research 2026-11-24: Warcraft Tavern, method.gg)
	"Withermaw",
	"Titanosaur",
	"Min'loth the Serpent",
	"Brinescale Sorceress",
	"Zarla Ober",
	"Blazeroar",
	"Nar'gurk",
	"Mindless Horror",
	"Shadetooth",
	"Durgen Dirgehammer",
	"Ras Frostwhisper",
	"Hearthsinger Forresten",
	"Baroness Anastari",
	"The Beast",
	"Urok Doomhowl",
	"High Interrogator Gerstahn",
	"Magister Kalendris",
	"Captain Kromcrush",
	"King Gordok",
	"Cho'Rush the Observer",
}

-- Förmåga och plats per fear-mob (visas i varningen)
ns.FEAR_INFO = {
	["Withermaw"] = "Fear (fear, Blackmaw Hold (55-60))",
	["Titanosaur"] = "Fear (fear, Shaper's Terrace (58-60))",
	["Min'loth the Serpent"] = "Fear (fear, The Drowned City (35-42))",
	["Brinescale Sorceress"] = "Fear (fear, The Drowned City (35-42))",
	["Zarla Ober"] = "AoE fear (Blazeroar form) (fear, Alcaz Island Prison (48-55))",
	["Blazeroar"] = "AoE fear (fear, Alcaz Island Prison (48-55))",
	["Nar'gurk"] = "Convert (charm/MC, Krol'dok Stronghold (40-47))",
	["Mindless Horror"] = "Fear (fear, City of Dalaran (28-35))",
	["Shadetooth"] = "AoE fear (fear, Excavation Site: Wetlands (26-33))",
	["Durgen Dirgehammer"] = "AoE fear (fear, Hall of Thanes (13-20))",
	["Onyxia"] = "Bellowing Roar (fear, Onyxia's Lair (40, Forever))",
	["Ras Frostwhisper"] = "Fear (fear, Scholomance)",
	["Lady Illucia Barov"] = "Dominate Mind (charm/MC, Scholomance)",
	["Hearthsinger Forresten"] = "Enchanting Lullaby (sleep, Stratholme (Main Gate))",
	["Balnazzar"] = "Deep Sleep (sleep, Stratholme (Main Gate))",
	["Baroness Anastari"] = "Possess (charm/MC, Stratholme (Service Gate))",
	["The Beast"] = "Fear (fear, Upper Blackrock Spire)",
	["Urok Doomhowl"] = "Intimidating Roar (fear, Lower Blackrock Spire)",
	["High Interrogator Gerstahn"] = "Psychic Scream (fear, Blackrock Depths)",
	["Magister Kalendris"] = "Dominate Mind (charm/MC, Dire Maul (West))",
	["Captain Kromcrush"] = "Intimidating Shout (fear, Dire Maul (North))",
	["King Gordok"] = "Psychic Scream (fear, Dire Maul (North))",
	["Cho'Rush the Observer"] = "Fear (ability not named) (fear, Dire Maul (North))",
}

-- Boss/target-namn -> resist-totem
ns.BOSS_RULES = {
	{ "Onyxia", "Fire Resistance Totem", "Onyxia: Flame Breath / Deep Breath" },
	{ "Vaelastrasz the Corrupt", "Fire Resistance Totem", "Vaelastrasz: Fire Nova" },
	{ "Firemaw", "Fire Resistance Totem", "Firemaw: Flame Buffet" },
	{ "Ebonroc", "Fire Resistance Totem", "Ebonroc: Wing Buffet" },
	{ "Flamegor", "Fire Resistance Totem", "Flamegor: Fire Nova" },
	{ "Ragnaros", "Fire Resistance Totem", "Ragnaros: fire damage" },
	{ "Sapphiron", "Frost Resistance Totem", "Sapphiron: Frost Aura" },
	{ "Viscidus", "Nature Resistance Totem", "Viscidus: Poison Bolt Volley / Toxin" },
	{ "Azuregos", "Frost Resistance Totem", "Azuregos: frost damage" },
	{ "Rage Winterchill", "Frost Resistance Totem", "Winterchill: Frost Nova / Icebolt" },
	{ "Princess Huhuran", "Nature Resistance Totem", "Huhuran: Poison Bolt Volley" },
	{ "Ysondre", "Nature Resistance Totem", "Ysondre: Lightning Wave" },
	{ "Emeriss", "Nature Resistance Totem", "Emeriss: Volatile Infection" },
	-- WoW: Forever (research 2026-11-24)
	{ "Cinder", "Fire Resistance Totem", "Cinder: Fire damage (unnamed) (Shaper's Terrace)" },
	{ "Tor'Rel", "Fire Resistance Totem", "Tor'Rel: Fire damage (unnamed) (Shaper's Terrace)" },
	{ "Izha'Rel", "Frost Resistance Totem", "Izha'Rel: Frost damage (unnamed) (Shaper's Terrace)" },
	{ "Snowtalon", "Frost Resistance Totem", "Snowtalon: Frost Nova, Cone of Cold (Shaper's Terrace)" },
	{ "Thunderhoof", "Nature Resistance Totem", "Thunderhoof: Lightning attacks (unnamed) (Shaper's Terrace)" },
	{ "Bolt", "Nature Resistance Totem", "Bolt: Chain Lightning (Shaper's Terrace)" },
	{ "Zarla Ober", "Fire Resistance Totem", "Zarla Ober: Fireball, Flamestrike (Alcaz Island Prison (48-55))" },
	{ "Blazeroar", "Fire Resistance Totem", "Blazeroar: AoE fire breath (Alcaz Island Prison (48-55))" },
	{ "Tidemistress Ca'zass", "Frost Resistance Totem", "Tidemistress Ca'zass: Frostbolt Volley, Blizzard (Alcaz Island Prison (48-55))" },
	{ "Magmatus", "Fire Resistance Totem", "Magmatus: Fire pulse (unnamed) (Hall of Thanes (13-20))" },
	{ "The Abandoned", "Frost Resistance Totem", "The Abandoned: Frost Nova (Ruins of Lordaeron (15-22))" },
	{ "Rath'mael", "Fire Resistance Totem", "Rath'mael: Flamestrike (Ruins of Lordaeron (15-22))" },
	{ "Vectus", "Fire Resistance Totem", "Vectus: Flamestrike, Blast Wave (Scholomance)" },
	{ "Archivist Galford", "Fire Resistance Totem", "Archivist Galford: Burning Winds (Stratholme (Main Gate))" },
	{ "Pyromancer Loregrain", "Fire Resistance Totem", "Pyromancer Loregrain: Scorching Totem (Blackrock Depths)" },
	{ "Phalanx", "Fire Resistance Totem", "Phalanx: Fireball Volley (Blackrock Depths)" },
	{ "Magmus", "Fire Resistance Totem", "Magmus: Room fire (unnamed) (Blackrock Depths)" },
}

-- Mobs som lägger gift/sjukdom -> Cleansing-totem innan auran syns (auror kan vara secret i strid)
ns.DISPEL_MOBS = {
	["Withermaw"] = { { "Disease Cleansing Totem", "Withermaw: Disease (unnamed) (Blackmaw Hold (55-60))" } },
	["Bloated Grizzly"] = { { "Disease Cleansing Totem", "Bloated Grizzly: Death explosion (unnamed) (Blackmaw Hold (55-60))" } },
	["Venomridge"] = { { "Poison Cleansing Totem", "Venomridge: Party poison (unnamed) (Shaper's Terrace (58-60))" } },
	["Min'loth the Serpent"] = { { "Poison Cleansing Totem", "Min'loth the Serpent: Poison Bolt Volley (The Drowned City (35-42))" } },
	["Brinescale Explorer"] = { { "Poison Cleansing Totem", "Brinescale Explorer: Poisonous Stab (The Drowned City (35-42))" } },
	["Slavering Hound"] = { { "Disease Cleansing Totem", "Slavering Hound: Disease (unnamed) (Alcaz Island Prison (48-55))" } },
	["Highland Spider"] = { { "Disease Cleansing Totem", "Highland Spider: Highland Venom (Excavation Site: Wetlands (26-33))" }, { "Poison Cleansing Totem", "Highland Spider: Poison (unnamed) (Excavation Site: Wetlands (26-33))" } },
	["Bloodhound Runt"] = { { "Disease Cleansing Totem", "Bloodhound Runt: Infected Wounds (Hall of Thanes (13-20))" } },
	["Witherfang"] = { { "Poison Cleansing Totem", "Witherfang: Poison (unnamed) (Ruins of Lordaeron (15-22))" } },
	["Viktor the Vile"] = { { "Poison Cleansing Totem", "Viktor the Vile: Poison (unnamed) (Ruins of Lordaeron (15-22))" } },
	["Mother Smolderweb"] = { { "Poison Cleansing Totem", "Mother Smolderweb: Mother's Milk (Lower Blackrock Spire)" } },
	["Hedrum the Creeper"] = { { "Poison Cleansing Totem", "Hedrum the Creeper: Baneful Poison (Blackrock Depths)" } },
}

-- Instans/zon -> resist-totem (lägre prioritet än bossregler)
ns.ZONE_RULES = {
	["Molten Core"] = { "Fire Resistance Totem", "Molten Core: fire damage everywhere" },
	["Onyxia's Lair"] = { "Fire Resistance Totem", "Onyxia's Lair: fire breath" },
}

-- Gruppsammansättning (för "rekommenderad situation" i PvE)
ns.MELEE_CLASSES = { WARRIOR = true, ROGUE = true, PALADIN = true }
ns.CASTER_CLASSES = { MAGE = true, WARLOCK = true, PRIEST = true }

-- Kontroll-typer (C_LossOfControl) som Tremor Totem bryter
-- Debuffar som inte ska renas: raiden behöver dem (Hakkar: Poisonous Blood skyddar mot Blood Siphon;
-- Grobbulus: Mutating Injection exploderar i gruppen om den tas bort)
ns.NEVER_CLEANSE = { ["Poisonous Blood"] = true, ["Mutating Injection"] = true }

-- Purge-varningen i PvP: bara buffar som är värda en Purge (inte Fortitude, Arcane Intellect osv.)
ns.PURGE_PRIORITY = { ["Power Word: Shield"] = true, ["Blessing of Protection"] = true, ["Blessing of Freedom"] = true,
	["Ice Barrier"] = true, ["Mana Shield"] = true, ["Fear Ward"] = true, ["Innervate"] = true,
	["Arcane Power"] = true, ["Nature's Swiftness"] = true, ["Renew"] = true, ["Rejuvenation"] = true,
	["Regrowth"] = true, ["Power Infusion"] = true, ["Presence of Mind"] = true, ["Divine Favor"] = true,
	["Blessing of Sacrifice"] = true, ["Hand of Freedom"] = true }

-- Tremor tar bort fear, charm och sleep. Inte possess (Mind Control, se BossMods) och inte horror:
-- Death Coil räknas som fear i klientens förlust-av-kontroll-data men går inte att pulsa bort.
ns.TREMOR_LOC_TYPES = { FEAR = true, FEAR_MECHANIC = true, CHARM = true, POSSESS = false, SLEEP = true, CONFUSE = false }
ns.TREMOR_LOC_IGNORE = { [6789] = true, [17925] = true, [17926] = true }   -- Death Coil (warlock), horror
