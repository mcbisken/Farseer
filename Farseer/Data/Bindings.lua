-- Keybind-mallar. Varje rad: { tangent, macro = mall-id } | { tangent, spell = "Spell" }
-- | { tangent, click = "Knappnamn", button = "LeftButton" } | { tangent, command = "BINDNINGSKOMMANDO" }
-- Makron som saknas skapas automatiskt. Det som låg på tangenterna sparas och kan återställas.
-- OBS: makron med [mod:shift]/[mod:ctrl]/[mod:alt] binds till tangenter UTAN modifier, annars
-- tar modifier-bindningen över.
-- Upplägg (research 2026-11-24, Skill-Capped keybind-guide, Blizzard-forum, Warcraft Tavern Forever):
--   bästa tangenterna 1-4, Q/E/R/F, C och musens sidoknappar -> det som används mest och panikknappar
--   (interrupt, Grounding, Tremor, Nature's Swiftness) utan modifier; 5/6/T/G/V/B/N för sådant som är sällan.
--   Call of the Elements har 3 s cast i Forever: före pull, inte på en PvP-panikknapp.

local _, ns = ...

local function sit(i, key, right)
	return { key, click = "FarseerSit" .. i, button = right and "RightButton" or "LeftButton" }
end

-- Gemensamt för spec-mallarna: situationsknapparna och verktyg
local function common(t)
	for _, b in ipairs({
		sit(1, "T"), sit(2, "G"), sit(3, "Y"), sit(4, "H"),
		sit(1, "SHIFT-T", true), sit(2, "SHIFT-G", true),
		{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" },
	}) do table.insert(t, b) end
	return t
end

ns.BINDING_PRESETS = {
	{
		id = "elemental", name = "Elemental",
		desc = "Damage on 1–4, burst on Q, interrupt on F, Frost Shock on C. Grounding and Tremor on the mouse side "
			.. "buttons. Totems: Earth on E, Call on R, Fire/Air/Water on V/B/N, situations on T/G/Y/H.",
		binds = common({
			{ "1", macro = "ele_bolt" }, { "2", macro = "ele_chain" }, { "3", macro = "ele_flame" },
			{ "4", macro = "ele_earth" }, { "5", macro = "pvp_purge" }, { "6", macro = "pvp_selfheal" },
			{ "Q", macro = "ele_burst" }, { "E", macro = "tot_earth" }, { "R", macro = "tot_calls" },
			{ "F", macro = "pvp_kick" }, { "SHIFT-F", macro = "pvp_fkick" }, { "C", macro = "ele_frost" },
			{ "V", macro = "tot_fire" }, { "B", macro = "tot_air" }, { "N", macro = "tot_water" },
			{ "BUTTON4", macro = "pvp_ground" }, { "BUTTON5", macro = "pvp_tremor" },
		}),
	},
	{
		id = "enhancement", name = "Enhancement",
		desc = "Stormstrike on 1, shocks on 2, Maelstrom bolt on 3, Purge on 4, burst on Q, interrupt on F, Fire Nova on C. "
			.. "Grounding and self-heal on the mouse side buttons, imbue on 6.",
		binds = common({
			{ "1", macro = "enh_ss" }, { "2", macro = "enh_shock" }, { "3", macro = "enh_mw" },
			{ "4", macro = "pvp_purge" }, { "5", macro = "ele_frost" }, { "6", macro = "util_imbue" },
			{ "Q", macro = "enh_burst" }, { "E", macro = "tot_earth" }, { "R", macro = "tot_calls" },
			{ "F", macro = "pvp_kick" }, { "SHIFT-F", macro = "pvp_fkick" }, { "C", macro = "tot_nova" },
			{ "V", macro = "tot_air" }, { "B", macro = "tot_fire" }, { "N", macro = "tot_water" },
			{ "BUTTON4", macro = "pvp_ground" }, { "BUTTON5", macro = "pvp_selfheal" },
		}),
	},
	{
		id = "restoration", name = "Restoration (mouseover)",
		desc = "Mouseover heals on raid/party frames: Chain Heal 1, Healing Wave 2, Lesser Healing Wave 3, Riptide 4. "
			.. "Nature's Swiftness heal on Q (panic), Cure on C, Mana Tide on 6. Grounding/Tremor on the side buttons.",
		binds = common({
			{ "1", macro = "res_ch" }, { "2", macro = "res_hw" }, { "3", macro = "res_lhw" },
			{ "4", macro = "res_rt" }, { "5", macro = "pvp_purge" }, { "6", macro = "res_mt" },
			{ "Q", macro = "res_ns" }, { "E", macro = "tot_water" }, { "R", macro = "tot_calls" },
			{ "F", macro = "pvp_kick" }, { "C", macro = "util_cure" },
			{ "V", macro = "tot_earth" }, { "B", macro = "tot_air" }, { "N", macro = "util_res" },
			{ "BUTTON4", macro = "pvp_ground" }, { "BUTTON5", macro = "pvp_tremor" },
		}),
	},
	{
		id = "pvp", name = "PvP (Elemental / Resto)",
		desc = "Bolt/Flame Shock on 1–2, Purge 3, self-heal 4. Earthbind Q, Tremor E, Frost Shock (focus) R, "
			.. "kick F / focus kick Shift+F. Grounding and Nature's Swiftness on the side buttons, focus on T.",
		binds = {
			{ "1", macro = "ele_bolt" }, { "2", macro = "ele_flame" }, { "3", macro = "pvp_purge" },
			{ "4", macro = "pvp_selfheal" }, { "5", macro = "ele_earth" }, { "6", macro = "tot_water" },
			{ "Q", macro = "pvp_ebind" }, { "E", macro = "pvp_tremor" }, { "R", macro = "pvp_frost" },
			{ "F", macro = "pvp_kick" }, { "SHIFT-F", macro = "pvp_fkick" }, { "C", macro = "util_cure" },
			{ "T", macro = "pvp_focus" }, { "G", macro = "tot_tcall" },
			{ "V", macro = "tot_air" }, { "B", macro = "tot_calls" }, { "N", macro = "tot_earth" },
			{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" },
			{ "BUTTON4", macro = "pvp_ground" }, { "BUTTON5", macro = "res_ns" },
		},
	},
	{
		id = "pvp_enh", name = "PvP (Enhancement)",
		desc = "Stormstrike 1, shocks 2, Maelstrom bolt 3, self-heal 4. Earthbind Q, Tremor E, Frost Shock (focus) R, "
			.. "kick F / focus kick Shift+F, Purge C. Grounding and burst on the side buttons, focus on T.",
		binds = {
			{ "1", macro = "enh_ss" }, { "2", macro = "enh_shock" }, { "3", macro = "enh_mw" },
			{ "4", macro = "pvp_selfheal" }, { "5", macro = "enh_burst" }, { "6", macro = "util_imbue" },
			{ "Q", macro = "pvp_ebind" }, { "E", macro = "pvp_tremor" }, { "R", macro = "pvp_frost" },
			{ "F", macro = "pvp_kick" }, { "SHIFT-F", macro = "pvp_fkick" }, { "C", macro = "pvp_purge" },
			{ "T", macro = "pvp_focus" }, { "G", macro = "tot_tcall" },
			{ "V", macro = "tot_air" }, { "B", macro = "tot_calls" }, { "N", macro = "tot_earth" },
			{ "Z", macro = "util_wolf" }, { "X", macro = "util_shield" },
			{ "BUTTON4", macro = "pvp_ground" }, { "BUTTON5", macro = "tot_nova" },
		},
	},
	{
		-- Gjord för ett Shift/Ctrl-lager: bara makron och spells UTAN egna modifier-grenar
		id = "totems", name = "Totems & counters",
		desc = "Grounding 1, Tremor 2, Earthbind 3, Poison Cleansing 4, Call of the Elements 5, Totemic Call 6, "
			.. "Healing Stream Q, Stoneclaw E, Fire Nova F, situations T/G/Y/H. Made for a Shift or Ctrl layer on top "
			.. "of your own keybinds.",
		layer = "SHIFT",
		binds = {
			{ "1", macro = "pvp_ground" }, { "2", macro = "pvp_tremor" }, { "3", spell = "Earthbind Totem" },
			{ "4", spell = "Poison Cleansing Totem" }, { "5", spell = "Call of the Elements" },
			{ "6", spell = "Totemic Call" },
			{ "Q", spell = "Healing Stream Totem" }, { "E", spell = "Stoneclaw Totem" }, { "F", spell = "Fire Nova" },
			sit(1, "T"), sit(2, "G"), sit(3, "Y"), sit(4, "H"),
		},
	},
	{
		id = "healmouse", name = "Healer mouse buttons",
		desc = "Mouseover heals on the side buttons: 4 = Lesser Healing Wave, 5 = Chain Heal, Shift+4 = Riptide, "
			.. "Shift+5 = Healing Wave, Ctrl+4 = Cure, Ctrl+5 = Nature's Swiftness heal.",
		binds = {
			{ "BUTTON4", macro = "res_lhw" }, { "BUTTON5", macro = "res_ch" },
			{ "SHIFT-BUTTON4", macro = "res_rt" }, { "SHIFT-BUTTON5", macro = "res_hw" },
			{ "CTRL-BUTTON4", macro = "util_cure" }, { "CTRL-BUTTON5", macro = "res_ns" },
		},
	},
	{
		id = "situations", name = "Situation buttons only",
		desc = "Touches nothing else: situation 1–8 on Shift+F1–F8 (drop next totem) and Ctrl+F1–F8 (whole set).",
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
		id = "mouse", name = "Mouse buttons (side buttons)",
		desc = "Side button 4: Kick. Side button 5: Grounding. Shift+side button: Tremor / Earthbind.",
		binds = {
			{ "BUTTON4", macro = "pvp_kick" }, { "BUTTON5", macro = "pvp_ground" },
			{ "SHIFT-BUTTON4", macro = "pvp_tremor" }, { "SHIFT-BUTTON5", spell = "Earthbind Totem" },
		},
	},
}
