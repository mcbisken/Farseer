-- Standardsituationer. totems = läggordning (max 4, en per element). Redigeras på Situationer-fliken.
-- Vänsterklick på en situationsknapp lägger NÄSTA totem i ordningen (/castsequence),
-- högerklick lägger hela setet på en gång med Call of the Elements (från level 20).

local _, ns = ...

ns.MAX_SITUATIONS = 10

ns.DEFAULT_SITUATIONS = {
	PVE = {
		{ name = "Melee", desc = "Melee-grupp: Windfury + Strength of Earth.",
			totems = { "Windfury Totem", "Strength of Earth Totem", "Mana Spring Totem", "Searing Totem" } },
		{ name = "Caster", desc = "Caster-/healergrupp: mana och skydd.",
			totems = { "Mana Spring Totem", "Stoneskin Totem", "Searing Totem", "Windwall Totem" } },
		{ name = "Tank", desc = "Tanka/boss: armor, agility, heal.",
			totems = { "Stoneskin Totem", "Grace of Air Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "AoE", desc = "Trash-pack: Magma + Healing Stream.",
			totems = { "Magma Totem", "Strength of Earth Totem", "Healing Stream Totem", "Windfury Totem" } },
		{ name = "Fear", desc = "Fear-boss/mobs: Tremor först.",
			totems = { "Tremor Totem", "Mana Spring Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Gift", desc = "Gift-skada (spindlar, ormar, rogues): Poison Cleansing.",
			totems = { "Poison Cleansing Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Sjukdom", desc = "Sjukdomar (odöda, Scholomance/Stratholme): Disease Cleansing.",
			totems = { "Disease Cleansing Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Eld-resist", desc = "Eld-bossar (Onyxia, Molten Core): Fire Resistance.",
			totems = { "Fire Resistance Totem", "Strength of Earth Totem", "Windfury Totem", "Searing Totem" } },
		{ name = "Frost-resist", desc = "Frost-bossar: Frost Resistance.",
			totems = { "Frost Resistance Totem", "Strength of Earth Totem", "Mana Spring Totem", "Windfury Totem" } },
		{ name = "Natur-resist", desc = "Nature-bossar: Nature Resistance.",
			totems = { "Nature Resistance Totem", "Strength of Earth Totem", "Mana Spring Totem", "Searing Totem" } },
	},
	PVP = {
		{ name = "vs Melee", desc = "Warrior/Paladin/Feral: Earthbind för att kita.",
			totems = { "Earthbind Totem", "Healing Stream Totem", "Grace of Air Totem", "Searing Totem" } },
		{ name = "vs Rogue", desc = "Rogue: Poison Cleansing tar bort gifterna, Earthbind slowar.",
			totems = { "Poison Cleansing Totem", "Earthbind Totem", "Grace of Air Totem", "Searing Totem" } },
		{ name = "vs Mage", desc = "Mage/caster: Grounding äter Polymorph/Frostbolt.",
			totems = { "Grounding Totem", "Earthbind Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "vs Fear", desc = "Warlock/Priest: Tremor bryter fear, Grounding äter Fear/Death Coil.",
			totems = { "Tremor Totem", "Grounding Totem", "Healing Stream Totem", "Searing Totem" } },
		{ name = "vs Hunter", desc = "Hunter: Poison Cleansing mot stings, Windwall mot pilar, Earthbind.",
			totems = { "Earthbind Totem", "Poison Cleansing Totem", "Windwall Totem", "Searing Totem" } },
		{ name = "Flagga/Def", desc = "Försvara en punkt/flagga: Earthbind + Magma + Grounding.",
			totems = { "Earthbind Totem", "Magma Totem", "Grounding Totem", "Healing Stream Totem" } },
		{ name = "Burst", desc = "Gå på offensiv med melee-gruppen.",
			totems = { "Windfury Totem", "Strength of Earth Totem", "Searing Totem", "Mana Spring Totem" } },
		{ name = "Healer", desc = "Du healar: Tremor, Grounding och mana.",
			totems = { "Tremor Totem", "Grounding Totem", "Mana Spring Totem", "Searing Totem" } },
	},
}
