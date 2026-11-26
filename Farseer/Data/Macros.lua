-- Makromallar. Varje mall har antingen `body` (text med {tokens}) eller `build(ctx)`.
-- Tokens (styrs av inställningarna på Makron-fliken):
--   {harm}      [@mouseover,harm,nodead][]                         (skada på mouseover, annars target)
--   {fharm}     [@focus,harm,nodead][@mouseover,harm,nodead][]     (focus först: interrupt/purge)
--   {help}      [@mouseover,help,nodead][help,nodead][@player]     (heal på mouseover > target > dig)
--   {kick}      Earth Shock eller Earth Shock(Rank 1)
--   {racial}    "/cast Blood Fury\n" eller "/cast Berserking\n" om du har den
-- ctx i build(ctx): ctx.known(spell), ctx.pick(a, b, ...), ctx.opt.<inställning>,
--   ctx.modcast({ {mod, spell, mål}, ... }, standardmål) -> "/cast [mod:shift] A; B"
--   mål är "@player" eller en lista villkor (ctx.helpTargets / ctx.harmTargets)
-- Tokens som inte är tomma slutar med ett mellanslag.
-- Namn får vara högst 16 tecken och kroppen högst 255 tecken (klientens gränser).

local _, ns = ...

ns.MACRO_CATEGORIES = { "Elemental", "Enhancement", "Restoration", "Totems", "PvP", "Utility" }

local T = {}
ns.MACRO_TEMPLATES = T
local function add(t) table.insert(T, t) end

---------------------------------------------------------------------------------------------------
-- Elemental
---------------------------------------------------------------------------------------------------
add({ id = "ele_bolt", cat = "Elemental", name = "FS Bolt",
	desc = "Lightning Bolt on mouseover, otherwise target.",
	body = "#showtooltip Lightning Bolt\n/cast {harm}Lightning Bolt" })
add({ id = "ele_chain", cat = "Elemental", name = "FS Chain",
	desc = "Chain Lightning on mouseover, otherwise target.",
	body = "#showtooltip Chain Lightning\n/cast {harm}Chain Lightning" })
add({ id = "ele_flame", cat = "Elemental", name = "FS FlameShock",
	desc = "Flame Shock (DoT) on mouseover — good for dotting several targets.",
	body = "#showtooltip Flame Shock\n/cast {harm}Flame Shock" })
add({ id = "ele_earth", cat = "Elemental", name = "FS EarthShock",
	desc = "Earth Shock for damage (max rank).",
	body = "#showtooltip Earth Shock\n/cast {harm}Earth Shock" })
add({ id = "ele_frost", cat = "Elemental", name = "FS FrostShock",
	desc = "Frost Shock: 50% slow for 8 s. Kiting.",
	body = "#showtooltip Frost Shock\n/cast {harm}Frost Shock" })
add({ id = "ele_burst", cat = "Elemental", name = "FS Burst",
	desc = "Lightning/Elemental Mastery + Berserking (troll) + both trinkets, then Chain Lightning.",
	build = function(ctx)
		-- Talangen heter Lightning Mastery i Forevers listor och Elemental Mastery i Classic: den du har
		local em = (ctx.known("Lightning Mastery") and "Lightning Mastery")
			or (ctx.known("Elemental Mastery") and "Elemental Mastery")
		local first = em or "Chain Lightning"
		return "#showtooltip " .. first .. "\n"
			.. (em and ("/cast " .. em .. "\n") or "")
			.. ctx.racialCaster .. "/use 13\n/use 14\n/cast " .. ctx.harm .. "Chain Lightning"
	end })
add({ id = "ele_aoe", cat = "Elemental", name = "FS AoE",
	desc = "No modifier: Chain Lightning. Shift: Fire Nova (at your fire totem). Ctrl: Magma Totem.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Fire Nova" }, { "ctrl", "Magma Totem" }, { nil, "Chain Lightning" } })
	end })
add({ id = "ele_bolt_r1", cat = "Elemental", name = "FS BoltR1", experimental = true,
	desc = "Lightning Bolt rank 1 (cheap, for mana-efficient poking/pulling). Requires rank syntax in the client.",
	body = "#showtooltip Lightning Bolt\n/cast {harm}Lightning Bolt(Rank 1)" })

---------------------------------------------------------------------------------------------------
-- Enhancement
---------------------------------------------------------------------------------------------------
add({ id = "enh_ss", cat = "Enhancement", name = "FS Strike",
	desc = "Starts auto-attack and casts Stormstrike (20 s cd, +20% on the next Lightning/Earth Shock).",
	body = "#showtooltip Stormstrike\n/startattack\n/cast Stormstrike" })
add({ id = "enh_shock", cat = "Enhancement", name = "FS EnhShock",
	desc = "No modifier: Earth Shock. Shift: Frost Shock. Ctrl: Flame Shock. Starts auto-attack.",
	build = function(ctx)
		return "#showtooltip\n/startattack\n" .. ctx.modcast({
			{ "shift", "Frost Shock" }, { "ctrl", "Flame Shock" }, { nil, "Earth Shock" } }, ctx.harmTargets)
	end })
add({ id = "enh_mw", cat = "Enhancement", name = "FS Maelstrom",
	desc = "Use at 5 Maelstrom stacks: instant Lightning Bolt (in Forever, Maelstrom Weapon only affects Lightning Bolt).",
	body = "#showtooltip Lightning Bolt\n/cast {harm}Lightning Bolt" })
add({ id = "enh_burst", cat = "Enhancement", name = "FS Farseer",
	desc = "Rage of the Farseer (+30% attack speed) + racial + trinkets + auto-attack.",
	build = function(ctx)
		local main = ctx.known("Rage of the Farseer") and "Rage of the Farseer" or "Stormstrike"
		return "#showtooltip " .. main .. "\n"
			.. (ctx.known("Rage of the Farseer") and "/cast Rage of the Farseer\n" or "")
			.. ctx.racial .. "/use 13\n/use 14\n/startattack"
	end })

---------------------------------------------------------------------------------------------------
-- Restoration
---------------------------------------------------------------------------------------------------
add({ id = "res_hw", cat = "Restoration", name = "FS HW",
	desc = "Healing Wave on mouseover > friendly target > yourself.",
	body = "#showtooltip Healing Wave\n/cast {help}Healing Wave" })
add({ id = "res_lhw", cat = "Restoration", name = "FS LHW",
	desc = "Lesser Healing Wave (fast heal) on mouseover > target > yourself.",
	body = "#showtooltip Lesser Healing Wave\n/cast {help}Lesser Healing Wave" })
add({ id = "res_ch", cat = "Restoration", name = "FS ChainHeal",
	desc = "Chain Heal on mouseover > target > yourself.",
	body = "#showtooltip Chain Heal\n/cast {help}Chain Heal" })
add({ id = "res_rt", cat = "Restoration", name = "FS Riptide",
	desc = "Riptide (HoT, short cd, makes the next Chain Heal on the target 25% stronger).",
	body = "#showtooltip Riptide\n/cast {help}Riptide" })
add({ id = "res_ns", cat = "Restoration", name = "FS NS Heal",
	desc = "Nature's Swiftness + instant Healing Wave. Panic button.",
	body = "#showtooltip Nature's Swiftness\n/cast Nature's Swiftness\n/cast {help}Healing Wave" })
add({ id = "res_mt", cat = "Restoration", name = "FS ManaTide",
	desc = "Mana Tide Totem.",
	body = "#showtooltip Mana Tide Totem\n/cast Mana Tide Totem" })
add({ id = "res_combo", cat = "Restoration", name = "FS RTChain",
	desc = "Riptide, then Chain Heal twice on the same target (castsequence, starts over after 12 s). While Riptide is on cooldown it waits: use FS ChainHeal then.",
	body = "#showtooltip\n/castsequence {help}reset=12 Riptide, Chain Heal, Chain Heal" })
add({ id = "res_hw_low", cat = "Restoration", name = "FS HW Low", experimental = true,
	desc = "Downrank: Healing Wave at the rank you chose on the Healing tab (default rank 4). Requires rank syntax in the client.",
	build = function(ctx) return "#showtooltip Healing Wave\n/cast " .. ctx.help .. ctx.rank("Healing Wave") end })
add({ id = "res_lhw_low", cat = "Restoration", name = "FS LHW Low", experimental = true,
	desc = "Downrank: Lesser Healing Wave at the chosen rank (default rank 3). Requires rank syntax in the client.",
	build = function(ctx) return "#showtooltip Lesser Healing Wave\n/cast " .. ctx.help .. ctx.rank("Lesser Healing Wave") end })
add({ id = "res_ch_low", cat = "Restoration", name = "FS CH Low", experimental = true,
	desc = "Downrank: Chain Heal at the chosen rank (default rank 1). Requires rank syntax in the client.",
	build = function(ctx) return "#showtooltip Chain Heal\n/cast " .. ctx.help .. ctx.rank("Chain Heal") end })

---------------------------------------------------------------------------------------------------
-- Totems
---------------------------------------------------------------------------------------------------
add({ id = "tot_calls", cat = "Totems", name = "FS Calls",
	desc = "Call of the Elements. Ctrl: Ancestors. Alt: Spirits. Shift: Totemic Recall (25% mana back).",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Totemic Recall" }, { "ctrl", "Call of the Ancestors" }, { "alt", "Call of the Spirits" },
			{ nil, "Call of the Elements" } })
	end })
add({ id = "tot_earth", cat = "Totems", name = "FS Earth",
	desc = "Earth: Strength of Earth. Shift: Tremor. Ctrl: Earthbind. Alt: Stoneclaw.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Tremor Totem" }, { "ctrl", "Earthbind Totem" }, { "alt", "Stoneclaw Totem" },
			{ nil, ctx.pick("Strength of Earth Totem", "Stoneskin Totem") } })
	end })
add({ id = "tot_fire", cat = "Totems", name = "FS Fire",
	desc = "Fire: Searing. Shift: Magma. Ctrl: Flametongue Totem. Alt: Frost Resistance.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Magma Totem" }, { "ctrl", "Flametongue Totem" }, { "alt", "Frost Resistance Totem" },
			{ nil, "Searing Totem" } })
	end })
add({ id = "tot_water", cat = "Totems", name = "FS Water",
	desc = "Water: Mana Spring. Shift: Healing Stream. Ctrl: Poison Cleansing. Alt: Disease Cleansing.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Healing Stream Totem" }, { "ctrl", "Poison Cleansing Totem" },
			{ "alt", "Disease Cleansing Totem" }, { nil, ctx.pick("Mana Spring Totem", "Healing Stream Totem") } })
	end })
add({ id = "tot_air", cat = "Totems", name = "FS Air",
	desc = "Air: Windfury. Shift: Grace of Air. Ctrl: Grounding. Alt: Nature Resistance.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Grace of Air Totem" }, { "ctrl", "Grounding Totem" }, { "alt", "Nature Resistance Totem" },
			{ nil, ctx.pick("Windfury Totem", "Grace of Air Totem", "Windwall Totem") } })
	end })
add({ id = "tot_drop", cat = "Totems", name = "FS DropAll",
	desc = "Classic castsequence: press 4 times for Strength of Earth, Searing, Mana Spring, Windfury.",
	body = "#showtooltip\n/castsequence reset=combat/15 Strength of Earth Totem, Searing Totem, Mana Spring Totem, Windfury Totem" })
add({ id = "tot_tcall", cat = "Totems", name = "FS TotemCall",
	desc = "Totemic Call: moves your active totems to you (30 s cd). Shift: Totemic Recall.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({ { "shift", "Totemic Recall" }, { nil, "Totemic Call" } })
	end })
add({ id = "tot_nova", cat = "Totems", name = "FS Nova",
	desc = "Fire Nova (at your fire totem). Shift: drop Magma Totem first.",
	build = function(ctx)
		return "#showtooltip Fire Nova\n" .. ctx.modcast({ { "shift", "Magma Totem" }, { nil, "Fire Nova" } })
	end })

---------------------------------------------------------------------------------------------------
-- PvP
---------------------------------------------------------------------------------------------------
add({ id = "pvp_kick", cat = "PvP", name = "FS Kick", pvp = true,
	desc = "Stops your own cast and interrupts mouseover > target with Earth Shock. Use FS FocusKick for your focus.",
	body = "#showtooltip Earth Shock\n/stopcasting\n/cast {harm}{kick}" })
add({ id = "pvp_fkick", cat = "PvP", name = "FS FocusKick", pvp = true,
	desc = "Stops your own cast and interrupts your focus with Earth Shock (falls back to target if you have no focus).",
	body = "#showtooltip Earth Shock\n/stopcasting\n/cast [@focus,harm,nodead][harm,nodead] {kick}" })
add({ id = "pvp_ground", cat = "PvP", name = "FS Ground", pvp = true,
	desc = "Stops your cast and drops Grounding Totem instantly (catches the next harmful spell).",
	body = "#showtooltip Grounding Totem\n/stopcasting\n/cast Grounding Totem" })
add({ id = "pvp_tremor", cat = "PvP", name = "FS Tremor", pvp = true,
	desc = "Stops your cast and drops Tremor Totem (breaks fear/charm/sleep).",
	body = "#showtooltip Tremor Totem\n/stopcasting\n/cast Tremor Totem" })
add({ id = "pvp_ebind", cat = "PvP", name = "FS Earthbind", pvp = true,
	desc = "Earthbind Totem. Shift: Stoneclaw (draws attacks).",
	build = function(ctx)
		return "#showtooltip\n/stopcasting\n" .. ctx.modcast({ { "shift", "Stoneclaw Totem" }, { nil, "Earthbind Totem" } })
	end })
add({ id = "pvp_purge", cat = "PvP", name = "FS Purge", pvp = true,
	desc = "Purge on mouseover > target.",
	body = "#showtooltip Purge\n/cast {harm}Purge" })
add({ id = "pvp_frost", cat = "PvP", name = "FS FrostFocus", pvp = true,
	desc = "Frost Shock on focus > mouseover > target (slow without switching target).",
	body = "#showtooltip Frost Shock\n/cast {fharm}Frost Shock" })
add({ id = "pvp_selfheal", cat = "PvP", name = "FS SelfHeal", pvp = true,
	desc = "Lesser Healing Wave on yourself. Shift: Healing Wave on yourself.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({
			{ "shift", "Healing Wave", "@player" }, { nil, "Lesser Healing Wave", "@player" } })
	end })
add({ id = "pvp_focus", cat = "PvP", name = "FS Focus", pvp = true,
	desc = "Sets focus on mouseover/target. Shift: clears focus.",
	body = "/focus [mod:shift] none; [@mouseover,harm,nodead][harm]\n/clearfocus [mod:shift]" })

---------------------------------------------------------------------------------------------------
-- Verktyg
---------------------------------------------------------------------------------------------------
add({ id = "util_wolf", cat = "Utility", name = "FS Wolf",
	desc = "Ghost Wolf on/off (cancels the form if you are already a wolf).",
	body = "#showtooltip Ghost Wolf\n/cast [noform] Ghost Wolf\n/cancelform [form]" })
add({ id = "util_shield", cat = "Utility", name = "FS Shield",
	desc = "Your main shield. Shift: the other shield (Water/Lightning Shield).",
	build = function(ctx)
		local main, other = "Lightning Shield", "Water Shield"
		if ctx.known("Water Shield") and ctx.opt.preferWaterShield then main, other = other, main end
		if not ctx.known(other) then return "#showtooltip " .. main .. "\n/cast " .. main end
		return "#showtooltip\n/cast [mod:shift] " .. other .. "; " .. main
	end })
add({ id = "util_imbue", cat = "Utility", name = "FS Imbue",
	desc = "Weapon imbue. No modifier: best known (Windfury > Flametongue > Rockbiter). Shift/Ctrl/Alt: the others.",
	build = function(ctx)
		local order = { "Windfury Weapon", "Flametongue Weapon", "Frostbrand Weapon", "Rockbiter Weapon" }
		local list, mods = {}, { "shift", "ctrl", "alt" }
		for _, s in ipairs(order) do if ctx.known(s) then table.insert(list, s) end end
		if #list == 0 then list = order end
		local entries = {}
		for i = 2, math.min(#list, 4) do table.insert(entries, { mods[i - 1], list[i] }) end
		table.insert(entries, { nil, list[1] })
		return "#showtooltip\n" .. ctx.modcast(entries)
	end })
add({ id = "util_cure", cat = "Utility", name = "FS Cure",
	desc = "Cure Poison on mouseover > target > yourself. Shift: Cure Disease.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({ { "shift", "Cure Disease", ctx.helpTargets },
			{ nil, "Cure Poison", ctx.helpTargets } })
	end })
add({ id = "util_res", cat = "Utility", name = "FS Res",
	desc = "Ancestral Spirit on dead mouseover or target.",
	body = "#showtooltip Ancestral Spirit\n/cast [@mouseover,help,dead][help,dead][] Ancestral Spirit" })
add({ id = "util_water", cat = "Utility", name = "FS WaterWalk",
	desc = "Water Walking on mouseover > target > yourself. Shift: Water Breathing.",
	build = function(ctx)
		return "#showtooltip\n" .. ctx.modcast({ { "shift", "Water Breathing", ctx.helpTargets },
			{ nil, "Water Walking", ctx.helpTargets } })
	end })
add({ id = "util_hearth", cat = "Utility", name = "FS Hearth",
	desc = "Astral Recall (15 min cd). Shift: Hearthstone.",
	body = "#showtooltip\n/use [mod:shift] Hearthstone\n/cast [nomod] Astral Recall" })
add({ id = "util_farsight", cat = "Utility", name = "FS FarSight",
	desc = "Far Sight — scout around corners in PvP/dungeons.",
	body = "#showtooltip Far Sight\n/cast Far Sight" })
