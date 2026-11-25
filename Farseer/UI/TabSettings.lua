-- Inställningar: bars, minimap, påminnelser och återställning — allt på ett ställe.

local _, ns = ...
local UI = ns.UI

local widgets = {}
local function track(w) table.insert(widgets, w); return w end

local BARS = {
	{ "situations", "Situation buttons", true },
	{ "counter", "Counter totems", true },
	{ "totems", "Totem timers", false },
	{ "reminders", "Reminders (shield/imbue)", false },
	{ "rez", "Resurrect button (dead party member)", false },
}
-- HUD och utrustningsset ställs in på Strid-fliken, procs-rutan och totemräckvidd på Larm-fliken

local function relayout() ns.fire("BARS_LAYOUT") end

local function build(p)
	local h = UI.Header(p, "Bars")
	h:SetPoint("TOPLEFT", 4, -4)
	local last = h
	for i, b in ipairs(BARS) do
		local cfg = ns.char.bars[b[1]]
		local box = UI.Box(p, 420, b[1] == "situations" and 116 or (b[3] and 92 or 64))
		box:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -8 or -6)
		local show = track(UI.Check(box, b[2], function() return cfg.show end, function(v) cfg.show = v; relayout() end))
		show:SetPoint("TOPLEFT", 6, -6)
		local scale = track(UI.Stepper(box, "Scale", 0.5, 2, 0.05, function() return cfg.scale or 1 end,
			function(v) cfg.scale = v; relayout() end, "%.2f"))
		scale:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 4, -4)
		if b[3] then
			local size = track(UI.Stepper(box, "Button size", 20, 64, 2, function() return cfg.size or 36 end,
				function(v) cfg.size = v; relayout() end))
			size:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -2)
			if b[1] == "situations" then
				local per = track(UI.Stepper(box, "Per row", 1, 10, 1, function() return cfg.perRow or 10 end,
					function(v) cfg.perRow = v; relayout() end))
				per:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -2)
			end
		end
		last = box
	end
	local pos = UI.Button(p, "Reset positions", 160, 24, function()
		for key, cfg in pairs(ns.char.bars) do
			local d = ns.DEFAULTS.char.bars[key]
			cfg.point, cfg.relPoint, cfg.x, cfg.y, cfg.scale = d.point, nil, d.x, d.y, d.scale
		end
		local a = ns.DEFAULTS.account.alert
		ns.db.alert.point, ns.db.alert.relPoint, ns.db.alert.x, ns.db.alert.y = a.point, nil, a.x, a.y
		relayout()
		ns.print("positions reset.")
	end)
	pos:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
	local lock = UI.Button(p, "Unlock / lock", 120, 24, function() ns.setLocked(not ns.char.locked) end,
		"When unlocked you can drag all Farseer frames.")
	lock:SetPoint("LEFT", pos, "RIGHT", 6, 0)

	-- Höger kolumn
	local x = 450
	local gh = UI.Header(p, "General")
	gh:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local mm = track(UI.Check(p, "Minimap icon", function() return ns.db.minimap ~= false end,
		function(v) ns.Options:SetMinimapShown(v) end, "Left-click: settings. Right-click: unlock. Middle-click: PvE/PvP."))
	mm:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -6)
	local auto = track(UI.Check(p, "Auto PvE/PvP by zone", function() return ns.char.autoMode end,
		function(v) ns.char.autoMode = v end))
	auto:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 0, 0)
	-- Rutnät när ramarna är upplåsta
	local grid = ns.db.grid
	local gs = track(UI.Check(p, "Show grid when unlocked", function() return grid.show ~= false end,
		function(v) grid.show = v; ns.Grid:Update() end, "A grid over the screen while you move Farseer frames. Red lines mark the screen center."))
	gs:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, 0)
	local gsn = track(UI.Check(p, "Snap frames to the grid", function() return grid.snap ~= false end,
		function(v) grid.snap = v end, "Frames snap to the nearest grid point when you let go. Hold Shift while dropping for free placement."))
	gsn:SetPoint("TOPLEFT", gs, "BOTTOMLEFT", 0, 0)
	local gsz = track(UI.Stepper(p, "Grid size", 4, 64, 4, function() return grid.size or 16 end,
		function(v) grid.size = v; ns.Grid:Update() end))
	gsz:SetPoint("TOPLEFT", gsn, "BOTTOMLEFT", 4, -2)

	local fd = ns.char.fade
	local fc = track(UI.Check(p, "Fade totem bars out of combat", function() return fd.enabled end, function(v)
		fd.enabled = v
		ns.Bars:ApplyFade()
	end, "Situation, counter and timer bars are see-through out of combat. Full in combat and under the mouse."))
	fc:SetPoint("TOPLEFT", gsz, "BOTTOMLEFT", -4, -4)
	local fa = track(UI.Stepper(p, "Faded opacity", 0, 0.9, 0.05, function() return fd.alpha or 0.35 end,
		function(v) fd.alpha = v; ns.Bars:ApplyFade() end, "%.2f"))
	fa:SetPoint("TOPLEFT", fc, "BOTTOMLEFT", 4, -2)
	local rh = UI.Header(p, "Reminders")
	rh:SetPoint("TOPLEFT", fa, "BOTTOMLEFT", -4, -12)
	local rem = ns.char.reminders
	local c1 = track(UI.Check(p, "Remind about shield", function() return rem.shield end, function(v) rem.shield = v end))
	c1:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -6)
	local c2 = track(UI.Check(p, "Remind about weapon imbue", function() return rem.imbue end, function(v) rem.imbue = v end))
	c2:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, 0)
	local c4 = track(UI.Check(p, "Remind about off-hand imbue", function() return rem.offhand ~= false end, function(v)
		rem.offhand = v
		ns.Reminders:Refresh()
	end, "Dual wield: a third button lights up when your off-hand weapon has no imbue. Click it to cast the imbue on the off-hand."))
	c4:SetPoint("TOPLEFT", c2, "BOTTOMLEFT", 0, 0)
	local c3 = track(UI.Check(p, "Prefer Water Shield", function() return rem.preferWaterShield end, function(v)
		rem.preferWaterShield = v
		ns.Reminders:Refresh()
	end, "The shield button and the FS Shield macro use Water Shield (if you have the talent)."))
	c3:SetPoint("TOPLEFT", c4, "BOTTOMLEFT", 0, 0)
	local c6 = track(UI.Check(p, "Water Shield in groups", function() return rem.waterInGroup end, function(v)
		rem.waterInGroup = v
		ns.Reminders:Refresh()
	end, "Solo: Lightning Shield. In a group: Water Shield (if you have it). Switches after combat."))
	c6:SetPoint("TOPLEFT", c3, "BOTTOMLEFT", 0, 0)
	local c5 = track(UI.Check(p, "Weapon oil/stone in checklist", function() return rem.oil ~= false end,
		function(v) rem.oil = v end,
		"In Forever oils and sharpening stones stack with imbues. Casters: Wizard/Mana Oil. Enhancement: sharpening stones or weightstones."))
	c5:SetPoint("TOPLEFT", c6, "BOTTOMLEFT", 0, 0)
	local mins = track(UI.Stepper(p, "Warn when imbue < (min)", 1, 30, 1, function() return rem.imbueMinutes or 5 end,
		function(v) rem.imbueMinutes = v end))
	mins:SetPoint("TOPLEFT", c5, "BOTTOMLEFT", 4, -4)
	local il = UI.Label(p, "Imbue button casts:", "GameFontNormalSmall")
	il:SetPoint("TOPLEFT", mins, "BOTTOMLEFT", 0, -8)
	local drop = track(UI.Dropdown(p, 190, function()
		return rem.imbueSpell == "auto" and "Automatic (best)" or rem.imbueSpell
	end, function()
		local items = { { text = "Automatic (best)", value = "auto" } }
		for _, s in ipairs(ns.IMBUES) do
			local k = ns.Spellbook:Knows(s)
			table.insert(items, { text = s, value = s, icon = ns.spellIcon(s), color = k and nil or { 0.55, 0.55, 0.55 } })
		end
		return items
	end, function(v) rem.imbueSpell = v; ns.Reminders:Refresh() end))
	drop:SetPoint("LEFT", il, "RIGHT", 6, 0)
	-- Off-hand: samma lista, "auto" = Flametongue Weapon. Dropdownerna står i linje under varandra.
	local ol = UI.Label(p, "Off-hand casts:", "GameFontNormalSmall")
	ol:SetPoint("TOPLEFT", il, "BOTTOMLEFT", 0, -16)
	local odrop = track(UI.Dropdown(p, 190, function()
		return rem.offhandSpell == "auto" and "Automatic (Flametongue)" or rem.offhandSpell
	end, function()
		local items = { { text = "Automatic (Flametongue)", value = "auto" } }
		for _, s in ipairs(ns.IMBUES) do
			local k = ns.Spellbook:Knows(s)
			table.insert(items, { text = s, value = s, icon = ns.spellIcon(s), color = k and nil or { 0.55, 0.55, 0.55 } })
		end
		return items
	end, function(v) rem.offhandSpell = v; ns.Reminders:Refresh() end))
	odrop:SetPoint("TOPLEFT", drop, "BOTTOMLEFT", 0, -4)

	local dh = UI.Header(p, "Maintenance")
	dh:SetPoint("TOPLEFT", ol, "BOTTOMLEFT", -4, -14)
	local dbg = UI.Button(p, "Test report", 110, 24, function() ns.Report:Show() end,
		"Client features, test list, load and errors in one box to copy. Also /farseer report.")
	dbg:SetPoint("TOPLEFT", dh, "BOTTOMLEFT", 0, -6)
	local wiz = UI.Button(p, "Setup wizard", 110, 24, function() ns.Options:Hide(); ns.Setup:Show() end,
		"The first-time questions again: spec, keybinds, alerts, look. Nothing changes until Finish.")
	wiz:SetPoint("LEFT", dbg, "RIGHT", 6, 0)
	local wipeChar = UI.Button(p, "Reset character", 130, 24, function()
		if InCombatLockdown() then ns.print("can't reset in combat."); return end
		UI.Confirm("Reset ALL Farseer settings for this character (situations, bars, warnings)? "
			.. "Macros and keybinds in the game are not touched. Type /reload afterwards.", function()
			if InCombatLockdown() then ns.print("can't reset in combat."); return end
			-- Säkerhetskopiorna av spelets keybinds och click-cast ska finnas kvar, annars går de inte att återställa
			local keep = { bindBackup = ns.copy(FarseerCharDB.bindBackup), clickBackup = ns.copy(FarseerCharDB.clickBackup),
				lastPreset = FarseerCharDB.lastPreset }
			ns.assign(FarseerCharDB, ns.DEFAULTS.char)
			for k, v in pairs(keep) do FarseerCharDB[k] = v end
			if type(FarseerCharDB.bindBackup) ~= "table" then FarseerCharDB.bindBackup = {} end
			ns.Bars:OnLoad()
			ns.BindingEngine:OnLoad()
			ns.print("settings reset — type /reload.")
		end)
	end)
	wipeChar:SetPoint("LEFT", wiz, "RIGHT", 6, 0)
	local cl = track(UI.Check(p, "Classic look (Blizzard style, needs /reload)", function() return ns.db.classicUI == true end,
		function(v)
			ns.db.classicUI = v
			ns.print("look: %s after /reload.", v and "classic" or "Farseer")
		end, "Blizzard's own buttons, checkboxes and fonts, and no Farseer borders on the bars. Use it if the new look renders badly."))
	cl:SetPoint("TOPLEFT", dbg, "BOTTOMLEFT", -4, -4)
	local info = UI.Label(p,
		"Secure buttons, keybinds and macros can't change in combat — Farseer applies changes when combat ends.",
		"GameFontHighlightSmall")
	info:SetPoint("TOPLEFT", cl, "BOTTOMLEFT", 4, -2)
	info:SetWidth(400)
end

local function refresh()
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

UI.AddTab("settings", "Settings", build, refresh)
