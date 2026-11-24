-- Situationer: redigera PvE- och PvP-seten som visas på situationsbaren.

local _, ns = ...
local UI = ns.UI
local BA

local editMode
local rows = {}
local p, modeButtons, autoCheck, callDrop, resetStep, info
local ROW_H = 40

local function list() return ns.char.situations[editMode] end

local function apply()
	ns.Bars:ApplySituations()
end

-- Meny med alla totems grupperade per element
local function totemItems()
	local items = { { text = "(inget)", value = "" } }
	for _, el in ipairs(ns.ELEMENTS) do
		local c = ns.ELEMENT_COLOR[el]
		table.insert(items, { text = ns.ELEMENT_NAME[el], header = true })
		for _, name in ipairs(ns.Spellbook:AllTotems(el)) do
			local knows = ns.Spellbook:Knows(name)
			table.insert(items, { text = name .. (knows and "" or "  (kan inte)"), value = name, icon = ns.spellIcon(name),
				color = knows and { c[1], c[2], c[3] } or { 0.55, 0.55, 0.55 } })
		end
	end
	return items
end

local refresh

local function duplicateElements(s)
	local seen, dup = {}, {}
	for _, name in ipairs(s.totems or {}) do
		local el = name ~= "" and ns.Spellbook:TotemElement(name)
		if el then
			if seen[el] then dup[el] = true end
			seen[el] = true
		end
	end
	local out = {}
	for el in pairs(dup) do table.insert(out, ns.ELEMENT_NAME[el]) end
	return out
end

local function makeRow(i)
	local r = CreateFrame("Frame", nil, p, "BackdropTemplate")
	r:SetSize(UI.WIDTH - 4, ROW_H - 2)
	UI.Backdrop(r, 0.5, { 0.15, 0.18, 0.25 })
	r.num = UI.Label(r, i .. ".", "GameFontNormal")
	r.num:SetPoint("LEFT", 6, 0)
	r.up = UI.Button(r, "^", 20, 18, function()
		local l = list()
		if i > 1 then l[i], l[i - 1] = l[i - 1], l[i]; apply(); refresh() end
	end, "Flytta upp")
	r.up:SetPoint("LEFT", 24, 8)
	r.down = UI.Button(r, "v", 20, 18, function()
		local l = list()
		if l[i + 1] then l[i], l[i + 1] = l[i + 1], l[i]; apply(); refresh() end
	end, "Flytta ned")
	r.down:SetPoint("LEFT", 24, -9)
	r.name = UI.EditBox(r, 110, function(_, text)
		local s = list()[i]
		if s then s.name = ns.trim(text); apply(); refresh() end
	end)
	r.name:SetMaxLetters(14)
	r.name:SetPoint("LEFT", 54, 8)
	r.name:SetScript("OnEditFocusLost", function(self)
		local s = list()[i]
		if s and ns.trim(self:GetText()) ~= "" and ns.trim(self:GetText()) ~= s.name then
			s.name = ns.trim(self:GetText()); apply(); refresh()
		end
	end)
	r.desc = UI.EditBox(r, 110, function(_, text)
		local s = list()[i]
		if s then s.desc = text end
	end)
	r.desc:SetPoint("LEFT", 54, -9)
	r.desc:SetScript("OnEditFocusLost", function(self)
		local s = list()[i]
		if s then s.desc = self:GetText() end
	end)
	r.desc:SetFontObject(GameFontHighlightSmall)
	r.drops = {}
	for d = 1, 4 do
		local drop = UI.Dropdown(r, 140, function()
			local s = list()[i]
			local name = s and s.totems and s.totems[d]
			return (name and name ~= "") and (name:gsub(" Totem$", "")) or "(inget)"
		end, totemItems, function(value)
			local s = list()[i]
			if not s then return end
			s.totems = s.totems or {}
			for k = #s.totems + 1, d - 1 do s.totems[k] = "" end
			s.totems[d] = value
			-- ta bort tomma på slutet
			while #s.totems > 0 and s.totems[#s.totems] == "" do table.remove(s.totems) end
			apply(); refresh()
		end)
		drop:SetPoint("LEFT", r, "LEFT", 176 + (d - 1) * 146, 0)
		r.drops[d] = drop
	end
	r.hide = UI.Check(r, "Dold", function() local s = list()[i]; return s and s.hidden end, function(v)
		local s = list()[i]
		if s then s.hidden = v or nil; apply() end
	end, "Dölj situationen från baren utan att ta bort den.")
	r.hide:SetPoint("LEFT", r, "LEFT", 176 + 4 * 146 + 2, 0)
	r.del = UI.Button(r, "X", 22, 20, function()
		local s = list()[i]
		if not s then return end
		UI.Confirm("Ta bort situationen \"" .. (s.name or "") .. "\"?", function()
			table.remove(list(), i); apply(); refresh()
		end)
	end, "Ta bort")
	r.del:SetPoint("RIGHT", -6, 0)
	rows[i] = r
	return r
end

function refresh()
	if not p then return end
	for _, b in ipairs(modeButtons) do
		if b.mode == editMode then b:LockHighlight() else b:UnlockHighlight() end
	end
	autoCheck:Refresh()
	callDrop:Refresh()
	resetStep:Refresh()
	local l = list()
	for i = 1, ns.MAX_SITUATIONS do
		local r = rows[i] or makeRow(i)
		local s = l[i]
		if s then
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -78 - (i - 1) * ROW_H)
			r.name:SetText(s.name or "")
			r.desc:SetText(s.desc or "")
			for d = 1, 4 do r.drops[d]:Refresh() end
			r.hide:Refresh()
			local dup = duplicateElements(s)
			-- Röd ram = två totems av samma element (bara det första används)
			if #dup > 0 then
				r:SetBackdropBorderColor(1, 0.25, 0.25, 1)
				r.num:SetText("|cffff4040" .. i .. "!|r")
			else
				r:SetBackdropBorderColor(0.15, 0.18, 0.25, 1)
				r.num:SetText(i .. ".")
			end
			r:Show()
		else
			r:Hide()
		end
	end
	local active = BA:Mode() == editMode
	info:SetText((active and "|cff40ff40Det här läget visas på baren nu.|r" or "|cffaaaaaaDet här läget visas inte just nu.|r")
		.. "  Ordningen är läggordningen (vänsterklick). Högerklick lägger alla med Call."
		.. "  Röd ram = två totems av samma element (bara det första används)."
		.. (InCombatLockdown() and "  |cffff4040Ändringar slår igenom efter striden.|r" or ""))
end

local function build(panel)
	BA = ns.Bars
	p = panel
	editMode = BA:Mode()
	modeButtons = {}
	local h = UI.Header(p, "Läge:")
	h:SetPoint("TOPLEFT", 4, -6)
	local pve = UI.Button(p, "PvE", 70, 24, function() editMode = "PVE"; refresh() end)
	pve:SetPoint("LEFT", h, "RIGHT", 8, 0)
	pve.mode = "PVE"
	local pvp = UI.Button(p, "PvP", 70, 24, function() editMode = "PVP"; refresh() end)
	pvp:SetPoint("LEFT", pve, "RIGHT", 4, 0)
	pvp.mode = "PVP"
	modeButtons = { pve, pvp }
	local show = UI.Button(p, "Visa detta läge på baren", 180, 24, function() BA:SetMode(editMode); refresh() end)
	show:SetPoint("LEFT", pvp, "RIGHT", 12, 0)
	autoCheck = UI.Check(p, "Auto-läge", function() return ns.char.autoMode end, function(v) ns.char.autoMode = v end,
		"Byter automatiskt till PvP i battlegrounds/arenor och till PvE i dungeons/raider.")
	autoCheck:SetPoint("LEFT", show, "RIGHT", 12, 0)

	local cl = UI.Label(p, "Call att använda:", "GameFontNormalSmall")
	cl:SetPoint("LEFT", autoCheck.label, "RIGHT", 18, 0)
	callDrop = UI.Dropdown(p, 170, function()
		return ns.CALLS[ns.char.callSet or 1]
	end, function()
		local items = {}
		for i, c in ipairs(ns.CALLS) do
			local knows = ns.Spellbook:Knows(c)
			table.insert(items, { text = c .. (knows and "" or "  (lvl " .. ns.CALL_LEVEL[i] .. ")"), value = i,
				icon = ns.spellIcon(c), color = knows and nil or { 0.55, 0.55, 0.55 } })
		end
		return items
	end, function(v) ns.char.callSet = v; apply() end)
	callDrop:SetPoint("LEFT", cl, "RIGHT", 6, 0)

	resetStep = UI.Stepper(p, "Sekvens-reset (s)", 3, 60, 1, function() return ns.char.seqReset or 10 end,
		function(v) ns.char.seqReset = v; apply() end)
	resetStep:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12)
	info = UI.Label(p, "", "GameFontHighlightSmall")
	info:SetPoint("LEFT", resetStep, "RIGHT", 10, 0)
	info:SetWidth(600)

	local add = UI.Button(p, "+ Ny situation", 140, 24, function()
		local l = list()
		if #l >= ns.MAX_SITUATIONS then ns.print("max %d situationer per läge.", ns.MAX_SITUATIONS) return end
		table.insert(l, { name = "Ny", desc = "", totems = {} })
		apply(); refresh()
	end)
	add:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
	local reset = UI.Button(p, "Återställ standard", 150, 24, function()
		UI.Confirm("Återställa alla " .. (editMode == "PVP" and "PvP" or "PvE") .. "-situationer till Farseers standard?", function()
			ns.char.situations[editMode] = ns.copy(ns.DEFAULT_SITUATIONS[editMode])
			apply(); refresh()
		end)
	end)
	reset:SetPoint("LEFT", add, "RIGHT", 8, 0)
end

UI.AddTab("situations", "Situationer", build, function() refresh() end)
