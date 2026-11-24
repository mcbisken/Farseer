-- Click-cast-mallar för Blizzards inbyggda Click Casting (raid-/gruppramar).
-- binds: { musknapp, modifierare ("", "shift", "ctrl", "alt", "shift-ctrl" ...), spell }
-- eller { musknapp, modifierare, interaction = "target" | "menu" } för vanligt klick (välj mål / meny).

local _, ns = ...

ns.CLICKCAST = {
	{ id = "heal_mods", name = "Healer: modifiers",
		desc = "Plain click targets and opens the menu as before. Shift, Ctrl and Alt + click heal and cleanse.",
		binds = {
			{ "LeftButton", "shift", "Lesser Healing Wave" },
			{ "RightButton", "shift", "Healing Wave" },
			{ "LeftButton", "ctrl", "Chain Heal" },
			{ "RightButton", "ctrl", "Riptide" },
			{ "LeftButton", "alt", "Cure Poison" },
			{ "RightButton", "alt", "Cure Disease" },
			{ "MiddleButton", "", "Riptide" },
		} },
	{ id = "heal_direct", name = "Healer: direct click",
		desc = "Click heals directly (left LHW, right Chain Heal, middle Riptide). Ctrl + left targets, Ctrl + right opens the menu.",
		binds = {
			{ "LeftButton", "", "Lesser Healing Wave" },
			{ "RightButton", "", "Chain Heal" },
			{ "MiddleButton", "", "Riptide" },
			{ "LeftButton", "shift", "Healing Wave" },
			{ "RightButton", "shift", "Cure Poison" },
			{ "RightButton", "alt", "Cure Disease" },
			{ "LeftButton", "ctrl", interaction = "target" },
			{ "RightButton", "ctrl", interaction = "menu" },
		} },
	{ id = "offheal", name = "Elemental/Enhancement: emergency heal",
		desc = "For DPS shamans: Shift + click Lesser Healing Wave, Shift + right Healing Wave, Alt + click cleanses.",
		binds = {
			{ "LeftButton", "shift", "Lesser Healing Wave" },
			{ "RightButton", "shift", "Healing Wave" },
			{ "LeftButton", "alt", "Cure Poison" },
			{ "RightButton", "alt", "Cure Disease" },
		} },
}

-- Downranking: spells och standardrank för makrona "FS ... Down" (ändras på Healing-fliken)
ns.DOWNRANK_SPELLS = { "Healing Wave", "Lesser Healing Wave", "Chain Heal" }
ns.DOWNRANK_DEFAULT = { ["Healing Wave"] = 4, ["Lesser Healing Wave"] = 3, ["Chain Heal"] = 1 }
