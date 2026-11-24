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
	local hh = UI.Header(p, "Strids-HUD")
	hh:SetPoint("TOPLEFT", 4, -4)
	local rows = {
		{ "Visa HUD:en", function() return bar.show end, function(v) bar.show = v; hudChanged() end,
			"Cooldowns, räckvidd och timers ovanför dina bars. Flytta den genom att låsa upp (minimap-ikonen, högerklick)." },
		{ "Cooldown-ikoner", function() return h.cooldowns end, function(v) h.cooldowns = v; hudChanged() end },
		{ "Räckvidd mot target", function() return h.range end, function(v) h.range = v; hudChanged() end,
			"Visar Shock/Bolt/Melee i grönt eller rött, och ikoner med räckvidd blir röda när target är för långt bort." },
		{ "Flame Shock-timer", function() return h.flameShock end, function(v) h.flameShock = v; hudChanged() end,
			"Räknas från din egen cast (12 s) och visas när du har samma target." },
		{ "Riptide per mål", function() return h.riptide end, function(v) h.riptide = v; hudChanged() end,
			"Vem som har din Riptide och hur länge (15 s)." },
		{ "Tips: Chain Heal +25 % på Riptide-målet", function() return h.chainHealHint end, function(v) h.chainHealHint = v end },
		{ "Swing timer", function() return h.swing end, function(v) h.swing = v; hudChanged() end,
			"Tid till nästa slag med huvudvapnet (Forevers PLAYER_SWING)." },
		{ "Swing timer bara i strid", function() return h.swingCombatOnly end, function(v) h.swingCombatOnly = v end },
	}
	local last = hh
	for i, r in ipairs(rows) do
		local cb = track(UI.Check(p, r[1], r[2], r[3], r[4]))
		cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -6 or 2)
		last = cb
	end
	local size = track(UI.Stepper(p, "Ikonstorlek", 18, 56, 2, function() return bar.size or 30 end,
		function(v) bar.size = v; hudChanged() end))
	size:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -6)
	local scale = track(UI.Stepper(p, "Skala", 0.5, 2, 0.05, function() return bar.scale or 1 end,
		function(v) bar.scale = v; hudChanged() end, "%.2f"))
	scale:SetPoint("TOPLEFT", size, "BOTTOMLEFT", 0, -2)

	local ih = UI.Label(p, "Ikoner (bara de du kan visas):", "GameFontNormal")
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
	local t1 = track(UI.Check(p, "Varna när ett totem dör i förtid", function() return ta.death end,
		function(v) ta.death = v end, "T.ex. när Grounding Totem äter en spell eller fienden slår sönder Tremor. "
			.. "Inte när det går ut av sig självt, när du byter det eller tar bort det."))
	t1:SetPoint("TOPLEFT", th, "BOTTOMLEFT", 0, -6)
	local t2 = track(UI.Check(p, "...för alla totems (inte bara viktiga)", function() return ta.allTotems end,
		function(v) ta.allTotems = v end, "Annars: Grounding, Tremor, Earthbind, Cleansing, Windfury, Mana Spring, "
			.. "Healing Stream, Strength of Earth, Grace of Air."))
	t2:SetPoint("TOPLEFT", t1, "BOTTOMLEFT", 0, 2)
	local t3 = track(UI.Check(p, "Tremor-puls (nedräkning på totembaren)", function() return ta.tremorPulse end,
		function(v) ta.tremorPulse = v end, "Tremor Totem pulsar var 4:e sekund: siffran visar när fearen bryts nästa gång."))
	t3:SetPoint("TOPLEFT", t2, "BOTTOMLEFT", 0, 2)
	local tinfo = UI.Label(p, "Kontratotem-baren visar nu också cooldowns (Earthbind, Stoneclaw, Grounding ...).",
		"GameFontHighlightSmall")
	tinfo:SetPoint("TOPLEFT", t3, "BOTTOMLEFT", 4, -4)
	tinfo:SetWidth(380)

	local gh = UI.Header(p, "Utrustningsset")
	gh:SetPoint("TOPLEFT", tinfo, "BOTTOMLEFT", -4, -16)
	local g = ns.char.gear
	local gbar = ns.char.bars.gear
	local g1 = track(UI.Check(p, "Visa knappar för mina set", function() return gbar.show end,
		function(v) gbar.show = v; ns.Gear:Layout() end, "Seten skapar du i spelets Equipment Manager (karaktärsfönstret)."))
	g1:SetPoint("TOPLEFT", gh, "BOTTOMLEFT", 0, -6)
	local g2 = track(UI.Check(p, "Byt set automatiskt vid PvE/PvP-byte", function() return g.auto end,
		function(v) g.auto = v end, "Bytet görs när striden är slut om du är i strid."))
	g2:SetPoint("TOPLEFT", g1, "BOTTOMLEFT", 0, 2)
	local function setItems()
		local items = { { text = "(inget)", value = "" } }
		for _, s in ipairs(ns.Gear:Sets()) do table.insert(items, { text = s.name, value = s.name, icon = s.icon }) end
		return items
	end
	local l1 = UI.Label(p, "PvE-set:", "GameFontNormalSmall")
	l1:SetPoint("TOPLEFT", g2, "BOTTOMLEFT", 4, -10)
	local d1 = track(UI.Dropdown(p, 180, function() return g.pve ~= "" and g.pve or "(inget)" end, setItems,
		function(v) g.pve = v end))
	d1:SetPoint("LEFT", l1, "LEFT", 60, 0)
	local l2 = UI.Label(p, "PvP-set:", "GameFontNormalSmall")
	l2:SetPoint("TOPLEFT", l1, "BOTTOMLEFT", 0, -16)
	local d2 = track(UI.Dropdown(p, 180, function() return g.pvp ~= "" and g.pvp or "(inget)" end, setItems,
		function(v) g.pvp = v end))
	d2:SetPoint("LEFT", l2, "LEFT", 60, 0)
	local gl = UI.Label(p, "", "GameFontHighlightSmall")
	gl:SetPoint("TOPLEFT", l2, "BOTTOMLEFT", 0, -14)
	gl:SetWidth(380)
	p.gearList = gl
	local gsize = track(UI.Stepper(p, "Knappstorlek", 18, 48, 2, function() return gbar.size or 28 end,
		function(v) gbar.size = v; ns.Gear:Layout() end))
	gsize:SetPoint("TOPLEFT", gl, "BOTTOMLEFT", 0, -8)
	local slash = UI.Label(p, "Makro/keybind: |cffffd100/farseer gear <setnamn>|r byter set.", "GameFontHighlightSmall")
	slash:SetPoint("TOPLEFT", gsize, "BOTTOMLEFT", 0, -8)
end

local function refresh(p)
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
	if p.gearList then
		local names = {}
		for _, s in ipairs(ns.Gear:Sets()) do
			table.insert(names, (s.equipped and "|cff40ff40" or "|cffffffff") .. s.name .. "|r")
		end
		p.gearList:SetText(#names > 0 and ("Dina set: " .. table.concat(names, ", "))
			or "|cffaaaaaaInga set ännu — skapa dem i karaktärsfönstrets Equipment Manager.|r")
	end
end

UI.AddTab("combat", "Strid", build, refresh)
