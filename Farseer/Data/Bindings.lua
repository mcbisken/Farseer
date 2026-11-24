-- Keybind-mallar. Varje rad: { tangent, macro = mall-id } | { tangent, spell = "Spell" }
-- | { tangent, click = "Knappnamn", button = "LeftButton" } | { tangent, command = "BINDNINGSKOMMANDO" }
-- Makron som saknas skapas automatiskt. Det som låg på tangenterna sparas och kan återställas.
-- OBS: makron med [mod:shift]/[mod:ctrl]/[mod:alt] binds till tangenter UTAN modifier, annars
-- tar modifier-bindningen över.

local _, ns = ...

local function sit(i, key, right)
	return { key, click = "FarseerSit" .. i, button = right and "RightButton" or "LeftButton" }
end

ns.BINDING_PRESETS = {
	{
		id = "elemental", name = "Elemental (WASD)",
		desc = "Caster-layout: skada på 1–6, burst på Q, totems på E/R/F, situationer på T/G/Y/H.",
		binds = {
			{ "1", macro = "ele_bolt" }, { "2", macro = "ele_chain" }, { "3", macro = "ele_flame" },
			{ "4", macro = "pvp_kick" }, { "5", macro = "ele_frost" }, { "6", macro = "pvp_purge" },
			{ "Q", macro = "ele_burst" }, { "E", macro = "tot_earth" }, { "R", macro = "tot_calls" },
			{ "F", macro = "ele_aoe" },
			sit(1, "T"), sit(2, "G"), sit(3, "Y"), sit(4, "H"),
			sit(1, "SHIFT-T", true), sit(2, "SHIFT-G", true),
			{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" }, { "C", macro = "pvp_selfheal" },
			{ "V", macro = "tot_fire" }, { "B", macro = "tot_air" }, { "N", macro = "tot_water" },
		},
	},
	{
		id = "enhancement", name = "Enhancement (WASD)",
		desc = "Melee-layout: Stormstrike på 1, shocks på 2, Maelstrom-bolt på 3, burst på Q.",
		binds = {
			{ "1", macro = "enh_ss" }, { "2", macro = "enh_shock" }, { "3", macro = "enh_mw" },
			{ "4", macro = "pvp_kick" }, { "5", macro = "pvp_purge" }, { "6", macro = "tot_nova" },
			{ "Q", macro = "enh_burst" }, { "E", macro = "tot_earth" }, { "R", macro = "tot_calls" },
			{ "F", macro = "tot_air" },
			sit(1, "T"), sit(2, "G"), sit(3, "Y"), sit(4, "H"),
			sit(1, "SHIFT-T", true), sit(2, "SHIFT-G", true),
			{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" }, { "C", macro = "pvp_selfheal" },
			{ "V", macro = "util_imbue" }, { "B", macro = "tot_fire" }, { "N", macro = "tot_water" },
		},
	},
	{
		id = "restoration", name = "Restoration (mouseover)",
		desc = "Healer-layout för mouseover på raid-/partyramar. Heals på 1–5, cleanse på 6.",
		binds = {
			{ "1", macro = "res_hw" }, { "2", macro = "res_lhw" }, { "3", macro = "res_ch" },
			{ "4", macro = "res_rt" }, { "5", macro = "res_ns" }, { "6", macro = "util_cure" },
			{ "Q", macro = "res_mt" }, { "E", macro = "tot_water" }, { "R", macro = "tot_calls" },
			{ "F", macro = "pvp_kick" },
			sit(1, "T"), sit(2, "G"), sit(3, "Y"), sit(4, "H"),
			sit(1, "SHIFT-T", true), sit(2, "SHIFT-G", true),
			{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" }, { "C", macro = "pvp_purge" },
			{ "V", macro = "tot_earth" }, { "B", macro = "tot_air" }, { "N", macro = "util_res" },
		},
	},
	{
		id = "pvp", name = "PvP (alla specs)",
		desc = "Snabba kontratotems (Grounding, Tremor, Earthbind) och focus-interrupt nära WASD.",
		binds = {
			{ "1", macro = "ele_bolt" }, { "2", macro = "pvp_frost" }, { "3", macro = "pvp_kick" },
			{ "4", macro = "pvp_purge" }, { "5", macro = "pvp_ground" }, { "6", macro = "pvp_tremor" },
			{ "Q", macro = "pvp_ebind" }, { "E", macro = "pvp_selfheal" }, { "R", macro = "tot_calls" },
			{ "F", macro = "pvp_focus" },
			sit(1, "T"), sit(2, "G"), sit(3, "Y"), sit(4, "H"),
			sit(1, "SHIFT-T", true), sit(2, "SHIFT-G", true),
			{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" }, { "C", macro = "util_cure" },
			{ "V", macro = "tot_earth" }, { "B", macro = "tot_air" }, { "N", macro = "tot_water" },
		},
	},
	{
		id = "situations", name = "Bara situationsknappar",
		desc = "Rör inget annat: situation 1–8 på Shift+F1–F8 (lägg nästa totem) och Ctrl+F1–F8 (hela setet).",
		binds = (function()
			local t = {}
			for i = 1, 8 do
				table.insert(t, sit(i, "SHIFT-F" .. i))
				table.insert(t, sit(i, "CTRL-F" .. i, true))
			end
			return t
		end)(),
	},
	{
		id = "mouse", name = "Musknappar (sidoknappar)",
		desc = "Sidoknapp 4: Kick. Sidoknapp 5: Grounding. Shift+sidoknapp: Tremor / Earthbind.",
		binds = {
			{ "BUTTON4", macro = "pvp_kick" }, { "BUTTON5", macro = "pvp_ground" },
			{ "SHIFT-BUTTON4", macro = "pvp_tremor" }, { "SHIFT-BUTTON5", macro = "pvp_ebind" },
		},
	},
}
