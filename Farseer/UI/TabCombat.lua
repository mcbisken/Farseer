-- Strid: strids-HUD (cooldowns, räckvidd, Flame Shock, Riptide, swing), totemvarningar och utrustningsset.

local _, ns = ...
local UI = ns.UI

local widgets = {}
local function track(w) table.insert(widgets, w); return w end
local function hudChanged() ns.fire("HUD_CHANGED") end

local ICON_NAMES = { trinket13 = "Trinket 1", trinket14 = "Trinket 2" }

local function build(p)
	local h = ns.char.hud
	local bar = ns.char.bars.hud

	-- Vänster: HUD
	local hh = UI.Header(p, "Combat HUD")
	hh:SetPoint("TOPLEFT", 4, -4)
	local rows = {
		{ "Show HUD", function() return bar.show end, function(v) bar.show = v; hudChanged() end,
			"Cooldowns, range and timers above your bars. Move it by unlocking (minimap icon, right-click)." },
		{ "Cooldown icons", function() return h.cooldowns end, function(v) h.cooldowns = v; hudChanged() end },
		{ "Range to target", function() return h.range end, function(v) h.range = v; hudChanged() end,
			"Shows Shock/Bolt/Melee in green or red, and icons with a range turn red when the target is too far away." },
		{ "Flame Shock timer", function() return h.flameShock end, function(v) h.flameShock = v; hudChanged() end,
			"Counted from your own cast (12 s) and shown when you have the same target." },
		{ "Riptide per target", function() return h.riptide end, function(v) h.riptide = v; hudChanged() end,
			"Who has your Riptide and for how long (15 s)." },
		{ "Hint: Chain Heal +25 % on Riptide target", function() return h.chainHealHint end, function(v) h.chainHealHint = v end },
		{ "Swing timer", function() return h.swing end, function(v) h.swing = v; hudChanged() end,
			"Time until the next main-hand swing (Forever's PLAYER_SWING)." },
		{ "Swing timer only in combat", function() return h.swingCombatOnly end, function(v) h.swingCombatOnly = v end },
		{ "Off-hand swing (dual wield)", function() return h.offSwing ~= false end, function(v) h.offSwing = v; hudChanged() end,
			"A second bar for the off-hand weapon." },
		{ "Flurry charges on the swing bar", function() return h.flurrySwing ~= false end, function(v) h.flurrySwing = v end,
			"Shows \"Flurry 3\" while Flurry is up (the game writes the number even when it is hidden in combat)." },
		{ "Glow when ready (shocks, Stormstrike, Lava Burst)", function() return h.readyGlow ~= false end,
			function(v) h.readyGlow = v end,
			"In combat with a hostile target in range: the HUD icon glows when the spell is off cooldown." },
	}
	local last = hh
	for i, r in ipairs(rows) do
		local cb = track(UI.Check(p, r[1], r[2], r[3], r[4]))
		cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -6 or 2)
		last = cb
	end
	local size = track(UI.Stepper(p, "Icon size", 18, 56, 2, function() return bar.size or 30 end,
		function(v) bar.size = v; hudChanged() end))
	size:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -6)
	local scale = track(UI.Stepper(p, "Scale", 0.5, 2, 0.05, function() return bar.scale or 1 end,
		function(v) bar.scale = v; hudChanged() end, "%.2f"))
	scale:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -2)

	local ih = UI.Label(p, "Icons (only ones you know are shown):", "GameFontNormal")
	ih:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", -4, -12)
	for i, e in ipairs(ns.HUD_SPELLS) do
		local key = e.spell or ("trinket" .. e.trinket)
		local label = ICON_NAMES[key] or key
		local cb = track(UI.Check(p, label, function() return not h.hidden[key] end, function(v)
			h.hidden[key] = (not v) or nil
			hudChanged()
		end))
		local col, row = (i - 1) % 3, math.floor((i - 1) / 3)
		cb:SetPoint("TOPLEFT", ih, "BOTTOMLEFT", col * 150, -4 - row * 22)
		cb.label:SetWidth(122)
	end

	-- Höger: totemvarningar och utrustning
	local x = 470
	local th = UI.Header(p, "Totems")
	th:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local ta = ns.char.totemAlerts
	local t1 = track(UI.Check(p, "Warn when a totem dies early", function() return ta.death end,
		function(v) ta.death = v end, "E.g. when Grounding Totem eats a spell or the enemy destroys Tremor. "
			.. "Not when it expires on its own, or when you replace or remove it."))
	t1:SetPoint("TOPLEFT", th, "BOTTOMLEFT", 0, -6)
	local t2 = track(UI.Check(p, "...for all totems (not just key ones)", function() return ta.allTotems end,
		function(v) ta.allTotems = v end, "Otherwise: Grounding, Tremor, Earthbind, Cleansing, Windfury, Mana Spring, "
			.. "Healing Stream, Strength of Earth, Grace of Air."))
	t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, 2)
	local t3 = track(UI.Check(p, "Tremor pulse (countdown on totem bar)", function() return ta.tremorPulse end,
		function(v) ta.tremorPulse = v end, "Tremor Totem pulses every 4 seconds: the number shows when fear will next be broken."))
	t3:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", 0, 2)
	local tinfo = UI.Label(p, "The counter totem bar now also shows cooldowns (Earthbind, Stoneclaw, Grounding ...).",
		"GameFontHighlightSmall")
	tinfo:SetPoint("TOPLEFT", t3, "BOTTOMLEFT", 4, -4)
	tinfo:SetWidth(380)

	local gh = UI.Header(p, "Equipment sets")
	gh:SetPoint("TOPLEFT", tinfo, "BOTTOMLEFT", -4, -16)
	local g = ns.char.gear
	local gbar = ns.char.bars.gear
	local g1 = track(UI.Check(p, "Show buttons for my sets", function() return gbar.show end,
		function(v) gbar.show = v; ns.Gear:Layout() end, "You create the sets in the game's Equipment Manager (character window)."))
	g1:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -6)
	local g2 = track(UI.Check(p, "Swap set automatically on PvE/PvP switch", function() return g.auto end,
		function(v) g.auto = v end, "If you are in combat, the swap happens when combat ends."))
	g2:SetPoint("TOPLEFT", g1, "BOTTOMLEFT", 0, 2)
	local function setItems()
		local items = { { text = "(none)", value = "" } }
		for _, s in ipairs(ns.Gear:Sets()) do table.insert(items, { text = s.name, value = s.name, icon = s.icon }) end
		return items
	end
	local l1 = UI.Label(p, "PvE set:", "GameFontNormalSmall")
	l1:SetPoint("TOPLEFT", g2, "BOTTOMLEFT", 4, -10)
	local d1 = track(UI.Dropdown(p, 180, function() return g.pve ~= "" and g.pve or "(none)" end, setItems,
		function(v) g.pve = v end))
	d1:SetPoint("LEFT", l1, "LEFT", 60, 0)
	local l2 = UI.Label(p, "PvP set:", "GameFontNormalSmall")
	l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -16)
	local d2 = track(UI.Dropdown(p, 180, function() return g.pvp ~= "" and g.pvp or "(none)" end, setItems,
		function(v) g.pvp = v end))
	d2:SetPoint("LEFT", l2, "LEFT", 60, 0)
	local gl = UI.Label(p, "", "GameFontHighlightSmall")
	gl:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -14)
	gl:SetWidth(380)
	p.gearList = gl
	local gsize = track(UI.Stepper(p, "Button size", 18, 48, 2, function() return gbar.size or 28 end,
		function(v) gbar.size = v; ns.Gear:Layout() end))
	gsize:SetPoint("TOPLEFT", gl, "BOTTOMLEFT", 0, -8)
	local slash = UI.Label(p, "Macro/keybind: |cffffd100/farseer gear <set name>|r swaps set.", "GameFontHighlightSmall")
	slash:SetPoint("TOPLEFT", gsize, "BOTTOMLEFT", 0, -8)
end

local function refresh(p)
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
	if p.gearList then
		local names = {}
		for _, s in ipairs(ns.Gear:Sets()) do
			table.insert(names, (s.equipped and "|cff40ff40" or "|cffffffff") .. s.name .. "|r")
		end
		p.gearList:SetText(#names > 0 and ("Your sets: " .. table.concat(names, ", "))
			or "|cffaaaaaaNo sets yet — create them in the character window's Equipment Manager.|r")
	end
end

UI.AddTab("combat", "Combat", build, refresh)
