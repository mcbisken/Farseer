-- Inställningar: bars, minimap, påminnelser och återställning — allt på ett ställe.

local _, ns = ...
local UI = ns.UI

local widgets = {}
local function track(w) table.insert(widgets, w); return w end

local BARS = {
	{ "situations", "Situationsknappar", true },
	{ "counter", "Kontratotems", true },
	{ "totems", "Totem-timers", false },
	{ "reminders", "Påminnelser (sköld/imbue)", false },
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
		local scale = track(UI.Stepper(box, "Skala", 0.5, 2, 0.05, function() return cfg.scale or 1 end,
			function(v) cfg.scale = v; relayout() end, "%.2f"))
		scale:SetPoint("TOPLEFT", show, "BOTTOMLEFT", 4, -4)
		if b[3] then
			local size = track(UI.Stepper(box, "Knappstorlek", 20, 64, 2, function() return cfg.size or 36 end,
				function(v) cfg.size = v; relayout() end))
			size:SetPoint("TOPLEFT", scale, "BOTTOMLEFT", 0, -2)
			if b[1] == "situations" then
				local per = track(UI.Stepper(box, "Per rad", 1, 10, 1, function() return cfg.perRow or 10 end,
					function(v) cfg.perRow = v; relayout() end))
				per:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -2)
			end
		end
		last = box
	end
	local pos = UI.Button(p, "Återställ positioner", 160, 24, function()
		for key, cfg in pairs(ns.char.bars) do
			local d = ns.DEFAULTS.char.bars[key]
			cfg.point, cfg.relPoint, cfg.x, cfg.y, cfg.scale = d.point, nil, d.x, d.y, d.scale
		end
		local a = ns.DEFAULTS.account.alert
		ns.db.alert.point, ns.db.alert.relPoint, ns.db.alert.x, ns.db.alert.y = a.point, nil, a.x, a.y
		relayout()
		ns.print("positioner återställda.")
	end)
	pos:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
	local lock = UI.Button(p, "Lås upp / lås", 120, 24, function() ns.setLocked(not ns.char.locked) end,
		"Upplåst kan du dra i alla Farseer-ramar.")
	lock:SetPoint("LEFT", pos, "RIGHT", 6, 0)

	-- Höger kolumn
	local x = 450
	local gh = UI.Header(p, "Allmänt")
	gh:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local mm = track(UI.Check(p, "Minimap-ikon", function() return ns.db.minimap ~= false end,
		function(v) ns.Options:SetMinimapShown(v) end, "Vänsterklick: inställningar. Högerklick: lås upp. Mittenklick: PvE/PvP."))
	mm:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -6)
	local auto = track(UI.Check(p, "Auto PvE/PvP efter zon", function() return ns.char.autoMode end,
		function(v) ns.char.autoMode = v end))
	auto:SetPoint("TOPLEFT", mm, "BOTTOMLEFT", 0, 0)

	local rh = UI.Header(p, "Påminnelser")
	rh:SetPoint("TOPLEFT", auto, "BOTTOMLEFT", 0, -14)
	local rem = ns.char.reminders
	local c1 = track(UI.Check(p, "Påminn om sköld", function() return rem.shield end, function(v) rem.shield = v end))
	c1:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -6)
	local c2 = track(UI.Check(p, "Påminn om vapen-imbue", function() return rem.imbue end, function(v) rem.imbue = v end))
	c2:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, 0)
	local c3 = track(UI.Check(p, "Föredra Water Shield", function() return rem.preferWaterShield end, function(v)
		rem.preferWaterShield = v
		ns.Reminders:Refresh()
	end, "Sköldknappen och FS Shield-makrot använder Water Shield (om du har talangen)."))
	c3:SetPoint("TOPLEFT", c2, "BOTTOMLEFT", 0, 0)
	local mins = track(UI.Stepper(p, "Varna när imbue < (min)", 1, 30, 1, function() return rem.imbueMinutes or 5 end,
		function(v) rem.imbueMinutes = v end))
	mins:SetPoint("TOPLEFT", c3, "BOTTOMLEFT", 4, -4)
	local il = UI.Label(p, "Imbue-knappen castar:", "GameFontNormalSmall")
	il:SetPoint("TOPLEFT", mins, "BOTTOMLEFT", 0, -8)
	local drop = track(UI.Dropdown(p, 190, function()
		return rem.imbueSpell == "auto" and "Automatiskt (bästa)" or rem.imbueSpell
	end, function()
		local items = { { text = "Automatiskt (bästa)", value = "auto" } }
		for _, s in ipairs(ns.IMBUES) do
			local k = ns.Spellbook:Knows(s)
			table.insert(items, { text = s, value = s, icon = ns.spellIcon(s), color = k and nil or { 0.55, 0.55, 0.55 } })
		end
		return items
	end, function(v) rem.imbueSpell = v; ns.Reminders:Refresh() end))
	drop:SetPoint("LEFT", il, "RIGHT", 6, 0)

	local dh = UI.Header(p, "Underhåll")
	dh:SetPoint("TOPLEFT", il, "BOTTOMLEFT", -4, -24)
	local dbg = UI.Button(p, "Visa fel/debug", 140, 24, function() ns.Slash("debug") end)
	dbg:SetPoint("TOPLEFT", dh, "BOTTOMLEFT", 0, -6)
	local wipeChar = UI.Button(p, "Återställ karaktären", 160, 24, function()
		if InCombatLockdown() then ns.print("kan inte återställa i strid."); return end
		UI.Confirm("Återställa ALLA Farseer-inställningar för den här karaktären (situationer, bars, varningar)? "
			.. "Makron och keybinds i spelet rörs inte. Skriv /reload efteråt.", function()
			if InCombatLockdown() then ns.print("kan inte återställa i strid."); return end
			-- Säkerhetskopiorna av spelets keybinds och click-cast ska finnas kvar, annars går de inte att återställa
			local keep = { bindBackup = ns.copy(FarseerCharDB.bindBackup), clickBackup = ns.copy(FarseerCharDB.clickBackup),
				lastPreset = FarseerCharDB.lastPreset }
			ns.assign(FarseerCharDB, ns.DEFAULTS.char)
			for k, v in pairs(keep) do FarseerCharDB[k] = v end
			if type(FarseerCharDB.bindBackup) ~= "table" then FarseerCharDB.bindBackup = {} end
			ns.Bars:OnLoad()
			ns.BindingEngine:OnLoad()
			ns.print("inställningarna återställda — skriv /reload.")
		end)
	end)
	wipeChar:SetPoint("LEFT", dbg, "RIGHT", 6, 0)
	local info = UI.Label(p,
		"Ändringar av säkra knappar (bars, totems, keybinds, makron) kan inte göras i strid — de görs automatiskt när striden är slut.",
		"GameFontHighlightSmall")
	info:SetPoint("TOPLEFT", dbg, "BOTTOMLEFT", 0, -10)
	info:SetWidth(400)
end

local function refresh()
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

UI.AddTab("settings", "Inställningar", build, refresh)
