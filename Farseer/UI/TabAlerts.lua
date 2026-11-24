-- Larm: procs (Maelstrom, Windfury, sköld), låg mana, purge, fiendens casts, DR, Blizzards förslag och
-- totemräckvidd.

local _, ns = ...
local UI = ns.UI

local widgets = {}
local function track(w) table.insert(widgets, w); return w end
local function changed() ns.fire("PROCS_CHANGED") end

-- En kolumn: rader läggs under varandra (y räknas uppifrån), checkboxar, stegare, rubriker och text
local function column(p, x, header, rows)
	local h = UI.Header(p, header)
	h:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local y = -28
	for _, r in ipairs(rows) do
		local w
		if r.stepper then
			w = track(UI.Stepper(p, r[1], r.min, r.max, r.step, r[2], r[3], r.fmt))
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x + 28, y)
			y = y - 26
		elseif r.label then
			w = UI.Label(p, r[1], "GameFontHighlightSmall")
			w:SetWidth(400)
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x + 4, y - 2)
			y = y - 46
		elseif r.header then
			w = UI.Label(p, r[1], "GameFontNormal")
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x, y - 8)
			y = y - 26
		else
			w = track(UI.Check(p, r[1], r[2], r[3], r[4]))
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
			y = y - 24
		end
	end
end

local function build(p)
	local c = ns.char.procs
	local bar = ns.char.bars.procs
	local ta = ns.char.totemAlerts
	column(p, 4, "Procs and alerts", {
		{ "Show procs box", function() return bar.show end, function(v) bar.show = v; changed() end,
			"The box above the HUD. Move it by unlocking (minimap icon, right-click)." },
		{ "Maelstrom Weapon stacks", function() return c.maelstrom end, function(v) c.maelstrom = v; changed() end,
			"Icon with stack count. Lights up at 5. Only shown if you have the talent." },
		{ "Sound at 5 stacks", function() return c.maelstromSound end, function(v) c.maelstromSound = v end,
			"Only when the count can be read (the game may hide it in combat; the icon still lights up)." },
		{ "Windfury proc (\"WINDFURY!\")", function() return c.windfury end, function(v) c.windfury = v end,
			"Shown when Windfury Weapon or Windfury Totem procs. Read from the game's cooldown event." },
		{ "Sound on Windfury", function() return c.windfurySound end, function(v) c.windfurySound = v end },
		{ "Shield charges", function() return c.shield end, function(v) c.shield = v; changed() end,
			"Lightning/Water Shield: the number is shown on the shield icon and the reminder button." },
		{ "Charges left to warn", stepper = true, min = 1, max = 2, step = 1,
			function() return c.shieldLow or 1 end, function(v) c.shieldLow = v end },
		{ "Low mana: suggestion", function() return c.mana end, function(v) c.mana = v end,
			"In combat: warning with suggestions in the order Mana Tide Totem, Water Shield, Mana Spring Totem." },
		{ "Threshold (% mana)", stepper = true, min = 5, max = 60, step = 5,
			function() return c.manaPct or 25 end, function(v) c.manaPct = v end },
		{ "Purge: target has magic buffs", function() return c.purge end, function(v) c.purge = v; changed() end,
			"Icon of the buff Purge removes. Works when the game shows enemy buffs (usually out of combat)." },
		{ "...warn in PvP mode", function() return c.purgeAlertPvp end, function(v) c.purgeAlertPvp = v end },
		{ "Enemy casts (castbar + \"Earth Shock!\")", function() return c.enemyCasts end, function(v) c.enemyCasts = v end,
			"Target and focus. Name and time are shown when the game provides them; otherwise just that the enemy is casting." },
		{ "...big KICK warning in PvP mode", function() return c.enemyCastAlertPvp end, function(v) c.enemyCastAlertPvp = v end },
		{ "Diminishing returns on target", function() return c.dr end, function(v) c.dr = v end,
			"50 % / 25 % / immune per CC category, from the game's DR event (if the client sends it)." },
		{ "Blizzard's next spell suggestion", function() return c.assisted end, function(v) c.assisted = v; changed() end,
			"Assisted Combat: only shown if the Forever client has the feature." },
		{ "Icon size", stepper = true, min = 20, max = 64, step = 2,
			function() return bar.size or 36 end, function(v) bar.size = v; changed() end },
	})
	column(p, 470, "Totem range", {
		{ "Mark totems that don't reach you", function() return ta.range end, function(v) ta.range = v end,
			"Buff totems (Strength of Earth, Mana Spring, Grace of Air ...): red box and OOR on the totem bar when the buff "
				.. "isn't on you. Only when the game shows your buffs (usually out of combat)." },
		{ "...and warn once per totem", function() return ta.rangeAlert end, function(v) ta.rangeAlert = v end },
		{ "Totemic Call button on totem bar", function() return ta.callButton end,
			function(v) ta.callButton = v; ns.Totems:ApplyCallButton() end,
			"Click: Totemic Call (moves your totems to you). Right-click: Totemic Recall. Lights up when something is out of range." },
		{ "How it works", header = true },
		{ "A totem is only marked once its buff has been seen on you, so an unknown buff ID in Forever gives no "
			.. "false alarms. Windfury Totem and Flametongue Totem give weapon enchants and can't be checked.", label = true },
	})
end

local function refresh(p)
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

UI.AddTab("alerts", "Alerts", build, refresh)
