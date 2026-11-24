-- Standardsituationer. totems = läggordning (max 4, en per element). Redigeras på Situationer-fliken.
-- Vänsterklick på en situationsknapp lägger NÄSTA totem i ordningen (/castsequence),
-- högerklick lägger hela setet på en gång med Call of the Elements (från level 20).

local _, ns = ...

ns.MAX_SITUATIONS = 10

ns.DEFAULT_SITUATIONS = {
	PVE = {
		{ name = "Melee", desc = "Melee group: Windfury + Strength of Earth.",
			totems = { "Windfury Totem", "Strength of Earth Totem", "Mana Spring Totem", "Searing Totem" } },
		{ name = "Caster", desc = "Caster/healer group: mana and protection.",
			totems = { "Mana Spring Totem", "Stoneskin Totem", "Searing Totem", "Windwall Totem" } },
		{ name = "Tank", desc = "Tank/boss: armor, agility, healing.",
			totems = { "Stoneskin Totem", "Grace of Air Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "AoE", desc = "Trash-pack: Magma + Healing Stream.",
			totems = { "Magma Totem", "Strength of Earth Totem", "Healing Stream Totem", "Windfury Totem" } },
		{ name = "Fear", desc = "Fear bosses/mobs: Tremor first.",
			totems = { "Tremor Totem", "Mana Spring Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Poison", desc = "Poison damage (spiders, snakes, rogues): Poison Cleansing.",
			totems = { "Poison Cleansing Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Disease", desc = "Diseases (undead, Scholomance/Stratholme): Disease Cleansing.",
			totems = { "Disease Cleansing Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Fire resist", desc = "Fire bosses (Onyxia, Molten Core): Fire Resistance.",
			totems = { "Fire Resistance Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Frost resist", desc = "Frost bosses: Frost Resistance.",
			totems = { "Frost Resistance Totem", "Strength of Earth Totem", "Mana Spring Totem", "Windfury Totem" } },
		{ name = "Nature resist", desc = "Nature bosses: Nature Resistance.",
			totems = { "Nature Resistance Totem", "Strength of Earth Totem", "Mana Spring Totem", "Searing Totem" } },
	},
	PVP = {
		{ name = "vs Melee", desc = "Warrior/Paladin/Feral: Earthbind to kite.",
			totems = { "Earthbind Totem", "Healing Stream Totem", "Grace of Air Totem", "Searing Totem" } },
		{ name = "vs Rogue", desc = "Rogue: Poison Cleansing removes poisons, Earthbind slows.",
			totems = { "Poison Cleansing Totem", "Earthbind Totem", "Grace of Air Totem", "Searing Totem" } },
		{ name = "vs Mage", desc = "Mage/caster: Grounding eats Polymorph/Frostbolt.",
			totems = { "Grounding Totem", "Earthbind Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "vs Fear", desc = "Warlock/Priest: Tremor breaks fear, Grounding eats Fear/Death Coil.",
			totems = { "Tremor Totem", "Grounding Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "vs Hunter", desc = "Hunter: Poison Cleansing vs stings, Windwall vs arrows, Earthbind.",
			totems = { "Earthbind Totem", "Poison Cleansing Totem", "Windwall Totem", "Searing Totem" } },
		{ name = "Flag/Def", desc = "Defend a node/flag: Earthbind + Magma + Grounding.",
			totems = { "Earthbind Totem", "Magma Totem", "Grounding Totem", "Healing Stream Totem" } },
		{ name = "Burst", desc = "Go on the offensive with the melee group.",
			totems = { "Windfury Totem", "Strength of Earth Totem", "Searing Totem", "Mana Spring Totem" } },
		{ name = "Healer", desc = "You are healing: Tremor, Grounding and mana.",
			totems = { "Tremor Totem", "Grounding Totem", "Mana Spring Totem", "Searing Totem" } },
	},
}
