-- Standardsituationer. totems = läggordning (max 4, en per element). Redigeras på Situationer-fliken.
-- Vänsterklick på en situationsknapp lägger NÄSTA totem i ordningen (/castsequence),
-- högerklick lägger hela setet på en gång med Call of the Elements (från level 20).
-- Research 2026-11-24 (Blizzards deep dive, patchnoter 15/10, 2/11, 10/11, Conquestcapped, Warcraft Tavern):
--   * Windfury, Flametongue, Strength of Earth, Grace of Air och resist-totemen når hela raiden (30 m);
--     Mana Spring, Healing Stream, Mana Tide, Stoneskin, Windwall, Grounding och Tremor bara din grupp.
--   * Bara Windfury och Flametongue krockar. Grace of Air staplar med båda. Tranquil Air är borttaget.
--   * Fire Nova är en spell som exploderar vid ditt eld-totem: AoE-set behöver ett eld-totem.
--   * Läggordning: reaktiva totems först, 5-minuterstotems sedan, Searing/Magma (kort livslängd) sist.
--   * Totems med cooldown (Earthbind, Grounding, Stoneclaw, Mana Tide) allra sist: /castsequence väntar på
--     ett steg som har cooldown, så de spärrar resten av setet. De har egna tangenter (FS Ground/FS Earthbind).
-- Namnen "Melee" och "Caster" används av gruppsammansättningen (Advisor) och ska inte bytas.

local _, ns = ...

ns.MAX_SITUATIONS = 10

ns.DEFAULT_SITUATIONS = {
	PVE = {
		{ name = "Melee", desc = "Melee group: Windfury + Strength of Earth (raid-wide), Mana Spring, Searing last.",
			totems = { "Windfury Totem", "Strength of Earth Totem", "Mana Spring Totem", "Searing Totem" } },
		{ name = "Caster", desc = "Caster/healer/hunter group: Mana Spring, raid-wide Strength of Earth and Grace of Air.",
			totems = { "Mana Spring Totem", "Strength of Earth Totem", "Grace of Air Totem", "Searing Totem" } },
		{ name = "Tank", desc = "Tank group: Stoneskin, Windfury for threat/rage, Healing Stream. Grace of Air if another shaman has Windfury.",
			totems = { "Stoneskin Totem", "Windfury Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "AoE", desc = "Trash packs: buffs first, Magma last in the pack (20 s) — Fire Nova explodes at it.",
			totems = { "Strength of Earth Totem", "Windfury Totem", "Healing Stream Totem", "Magma Totem" } },
		{ name = "Solo", desc = "Leveling/solo: cheap set, Searing for damage, Healing Stream to save downtime.",
			totems = { "Strength of Earth Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "Raid support", desc = "Second shaman in the raid: Windfury/Strength of Earth already raid-wide, so Grace of Air (stacks) and party totems.",
			totems = { "Grace of Air Totem", "Mana Spring Totem", "Stoneskin Totem", "Searing Totem" } },
		{ name = "Fear", desc = "Fear bosses/mobs: Tremor first (party only).",
			totems = { "Tremor Totem", "Mana Spring Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Poison", desc = "Poison damage (spiders, snakes, rogues): Poison Cleansing.",
			totems = { "Poison Cleansing Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Fire resist", desc = "Fire bosses (Onyxia, Molten Core): Fire Resistance. No fire totem — many fire mobs are immune.",
			totems = { "Fire Resistance Totem", "Windfury Totem", "Strength of Earth Totem" } },
		{ name = "Frost/Nature", desc = "Frost (Azuregos) or nature (Hakkar, AQ) fights: both resist totems (raid-wide).",
			totems = { "Frost Resistance Totem", "Nature Resistance Totem", "Strength of Earth Totem", "Mana Spring Totem" } },
	},
	PVP = {
		{ name = "vs Melee", desc = "Warrior/Paladin/Feral: Earthbind to kite.",
			totems = { "Healing Stream Totem", "Grace of Air Totem", "Searing Totem", "Earthbind Totem" } },
		{ name = "vs Rogue", desc = "Rogue: Poison Cleansing removes poisons, Earthbind slows, Magma pulses break stealth/Vanish.",
			totems = { "Poison Cleansing Totem", "Grace of Air Totem", "Magma Totem", "Earthbind Totem" } },
		{ name = "vs Mage", desc = "Mage: Grounding eats Polymorph/Frostbolt, Frost Resistance, Earthbind vs Blink-kiting.",
			totems = { "Frost Resistance Totem", "Healing Stream Totem", "Grounding Totem", "Earthbind Totem" } },
		{ name = "vs Fear", desc = "Warlock/Priest: Tremor breaks fear/charm, Grounding eats Fear/Death Coil.",
			totems = { "Tremor Totem", "Healing Stream Totem", "Searing Totem", "Grounding Totem" } },
		{ name = "vs Hunter", desc = "Hunter: Poison Cleansing vs stings, Windwall vs arrows, Earthbind.",
			totems = { "Poison Cleansing Totem", "Windwall Totem", "Searing Totem", "Earthbind Totem" } },
		{ name = "Flag/Def", desc = "Defend a node/flag: Earthbind + Magma + Grounding.",
			totems = { "Magma Totem", "Healing Stream Totem", "Grounding Totem", "Earthbind Totem" } },
		{ name = "Burst", desc = "Go on the offensive with the melee group: buffs first, Searing last.",
			totems = { "Windfury Totem", "Strength of Earth Totem", "Mana Spring Totem", "Searing Totem" } },
		{ name = "Healer", desc = "You are healing: Tremor, Grounding and mana.",
			totems = { "Tremor Totem", "Mana Spring Totem", "Searing Totem", "Grounding Totem" } },
	},
}

-- Totems med cooldown (sekunder): på Situationer-fliken varnas det om de står före ett totem utan
ns.COOLDOWN_TOTEMS = { ["Earthbind Totem"] = 15, ["Grounding Totem"] = 15, ["Stoneclaw Totem"] = 30,
	["Mana Tide Totem"] = 300 }

-- Totems som inte fungerar tillsammans (samma buff-slot): varnas för på Situationer-fliken
ns.TOTEM_CONFLICTS = {
	{ "Windfury Totem", "Flametongue Totem", "Windfury and Flametongue Totem don't work together — only one of them counts." },
}
