-- Makron: mallbibliotek per kategori, förhandsvisning/redigering och egna makron.

local _, ns = ...
local UI = ns.UI
local ME

local CUSTOM = "Egna"
-- Visningsnamn för kategorinycklar (nycklarna själva ändras inte)
local CAT_LABEL = { Egna = "Custom" }
local state = { cat = "Elemental", sel = nil, customIndex = nil }
local p, rows, content, scroll
local catButtons = {}
local preview, previewEdit, counter, nameBox, perCharCheck, createBtn, pickBtn, deleteBtn, saveCustomBtn, previewTitle, previewInfo
local optChecks = {}

local ROW_H = 58

local function templatesIn(cat)
	local out = {}
	for _, t in ipairs(ns.MACRO_TEMPLATES) do if t.cat == cat then table.insert(out, t) end end
	return out
end

local function setCounter(text)
	local n = #(text or "")
	local c = n > ME.MAX_BODY and "|cffff4040" or (n > 230 and "|cffffb040" or "|cff80ff80")
	counter:SetText(string.format("%s%d|r / %d chars", c, n, ME.MAX_BODY))
end

local refreshList

local function selectTemplate(t)
	state.edited = false   -- egna ändringar i rutorna (behålls när fliken visas igen)
	state.sel, state.customIndex = t, nil
	local body, missing = ME:Render(t)
	previewTitle:SetText(t.name .. (t.experimental and "  |cffffb040(experimental)|r" or ""))
	nameBox:SetText(t.name)
	perCharCheck:SetChecked(ns.db.macros.perCharacter and true or false)
	previewEdit:SetText(body)
	setCounter(body)
	local info = t.desc or ""
	if #missing > 0 then info = info .. "\n|cffff6060Missing: " .. table.concat(missing, ", ") .. "|r" end
	previewInfo:SetText(info)
	createBtn:SetText(ME:Exists(t.name) and "Update in game" or "Create in game")
	deleteBtn:SetShown(ME:Exists(t.name) ~= nil)
	saveCustomBtn:SetText("Save as custom")
	refreshList()
end

local function selectCustom(i)
	local c = ns.db.custom[i]
	state.edited = false
	state.sel, state.customIndex = nil, i
	if not c then
		c = { name = "", body = "#showtooltip\n/cast ", perChar = ns.db.macros.perCharacter }
	end
	previewTitle:SetText(i and c.name or "New macro")
	nameBox:SetText(c.name or "")
	previewEdit:SetText(c.body or "")
	setCounter(c.body)
	perCharCheck:SetChecked(c.perChar and true or false)
	local spells = ME:SpellsIn(c.body or "")
	local missing = {}
	for _, s in ipairs(spells) do if not ns.Spellbook:Knows(s) then table.insert(missing, s) end end
	previewInfo:SetText(#missing > 0 and ("|cffff6060Unknown/missing: " .. table.concat(missing, ", ") .. "|r") or
		"Write your macro. Name max 16 chars, body max 255.")
	createBtn:SetText(c.name ~= "" and ME:Exists(c.name) and "Update in game" or "Create in game")
	deleteBtn:SetShown(i ~= nil)
	saveCustomBtn:SetText("Save")
	refreshList()
end

local function makeRow(i)
	local r = CreateFrame("Button", nil, content, "BackdropTemplate")
	r:SetSize(430, ROW_H - 4)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
	UI.Backdrop(r, 0.5, { 0.15, 0.18, 0.25 })
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(36, 36)
	r.icon:SetPoint("LEFT", 8, 0)
	r.name = UI.Label(r, "", "GameFontNormal")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, 0)
	r.desc = UI.Label(r, "", "GameFontHighlightSmall")
	r.desc:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -2)
	r.desc:SetWidth(270)
	r.desc:SetMaxLines(2)
	r.status = UI.Label(r, "", "GameFontHighlightSmall")
	r.status:SetPoint("TOPRIGHT", -8, -6)
	r.make = UI.Button(r, "Create", 76, 20)
	r.make:SetPoint("BOTTOMRIGHT", -8, 6)
	r.sel = r:CreateTexture(nil, "BORDER")
	r.sel:SetAllPoints()
	r.sel:SetColorTexture(0.2, 0.45, 0.9, 0.18)
	r:SetScript("OnEnter", function(self)
		if not self.body then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(self.title or "")
		GameTooltip:AddLine(self.body, 0.9, 0.9, 0.9, true)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = r
	return r
end

function refreshList()
	if not content then return end
	for _, r in ipairs(rows) do r:Hide() end
	local i = 0
	if state.cat == CUSTOM then
		for idx, c in ipairs(ns.db.custom) do
			i = i + 1
			local r = rows[i] or makeRow(i)
			r.title, r.body = c.name, c.body
			r.icon:SetTexture(ns.spellIcon(ME:SpellsIn(c.body or "")[1]))
			r.name:SetText(c.name)
			r.desc:SetText(((c.body or ""):gsub("\n", "  ")))
			local exists = ME:Exists(c.name)
			r.status:SetText(exists and "|cff40ff40in game|r" or "|cff888888not created|r")
			r.make:SetText(exists and "Update" or "Create")
			r.make:SetScript("OnClick", function()
				local ok, msg = ME:Save(c.name, c.body, c.perChar)
				ns.print("%s: %s", c.name, ok and msg or ("|cffff4040" .. msg .. "|r"))
				refreshList()
			end)
			r:SetScript("OnClick", function() selectCustom(idx) end)
			r.sel:SetShown(state.customIndex == idx)
			r:Show()
		end
		i = i + 1
		local r = rows[i] or makeRow(i)
		r.title, r.body = nil, nil
		r.icon:SetTexture("Interface\\PaperDollInfoFrame\\Character-Plus")
		r.name:SetText("+ New macro")
		r.desc:SetText("Write a custom macro in the box on the right.")
		r.status:SetText("")
		r.make:SetText("New")
		r.make:SetScript("OnClick", function() selectCustom(nil) end)
		r:SetScript("OnClick", function() selectCustom(nil) end)
		r.sel:SetShown(false)
		r:Show()
	else
		for _, t in ipairs(templatesIn(state.cat)) do
			i = i + 1
			local r = rows[i] or makeRow(i)
			local body, missing = ME:Render(t)
			r.title, r.body = t.name, body
			local first = ME:SpellsIn(body)[1]
			r.icon:SetTexture(ns.spellIcon(first))
			r.icon:SetDesaturated(#missing > 0)
			r.name:SetText(t.name .. (t.experimental and "  |cffffb040exp.|r" or ""))
			r.desc:SetText(t.desc or "")
			local exists = ME:Exists(t.name)
			local st = exists and "|cff40ff40in game|r" or "|cff888888not created|r"
			if #missing > 0 then st = st .. "  |cffff6060missing " .. #missing .. "|r" end
			r.status:SetText(st)
			r.make:SetText(exists and "Update" or "Create")
			r.make:SetScript("OnClick", function()
				ME:CreateFromTemplate(t.id)
				refreshList()
				if state.sel == t then selectTemplate(t) end
			end)
			r:SetScript("OnClick", function() selectTemplate(t) end)
			r.sel:SetShown(state.sel == t)
			r:Show()
		end
	end
	content:SetHeight(math.max(10, i * ROW_H))
	for _, b in ipairs(catButtons) do
		if b.cat == state.cat then b:LockHighlight() else b:UnlockHighlight() end
	end
end

local function build(panel)
	ME = ns.MacroEngine
	p = panel
	rows = {}

	-- Kategorier
	local ch = UI.Header(p, "Categories")
	ch:SetPoint("TOPLEFT", 4, -4)
	local cats = {}
	for _, c in ipairs(ns.MACRO_CATEGORIES) do table.insert(cats, c) end
	table.insert(cats, CUSTOM)
	local last
	for i, c in ipairs(cats) do
		local b = UI.Button(p, CAT_LABEL[c] or c, 140, 24, function()
			state.cat = c
			if c == CUSTOM then selectCustom(ns.db.custom[1] and 1 or nil) else
				local first = templatesIn(c)[1]
				if first then selectTemplate(first) else refreshList() end
			end
		end)
		b.cat = c
		if i == 1 then b:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -8) else b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4) end
		last = b
		table.insert(catButtons, b)
	end
	local all = UI.Button(p, "Create category", 140, 24, function()
		if state.cat == CUSTOM then
			for _, c in ipairs(ns.db.custom) do ME:Save(c.name, c.body, c.perChar) end
			ns.print("custom macros saved in game.")
		else
			ME:CreateCategory(state.cat)
		end
		refreshList()
	end, "Creates/updates all (non-experimental) macros in the category.")
	all:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -14)
	local open = UI.Button(p, "Open macro window", 140, 24, function()
		-- Makrofönstret ligger lägre än Farseer: stäng Farseer så att det syns
		if ShowMacroFrame then ns.Options:Toggle(); pcall(ShowMacroFrame) end
	end, "Blizzard's macro window, for dragging macros to action bars.")
	open:SetPoint("TOPLEFT", all, "BOTTOMLEFT", 0, -4)

	-- Inställningar för rendering
	local oh = UI.Label(p, "Macro settings", "GameFontNormal")
	oh:SetPoint("TOPLEFT", open, "BOTTOMLEFT", 0, -16)
	local mo = ns.db.macros
	local opts = {
		{ "mouseover", "Mouseover", "Damage/heals go to your mouseover first ([@mouseover])." },
		{ "focus", "Focus", "Interrupt and Purge go to focus first." },
		{ "selfcast", "Self-cast heals", "Heal macros cast on you if you have no friendly target." },
		{ "downrankKick", "Earth Shock rank 1", "Interrupt with rank 1 (cheaper). Experimental: requires the client to support rank syntax." },
		{ "perCharacter", "Character macros", "New macros are created as character macros instead of account macros." },
	}
	local prevC = oh
	for _, o in ipairs(opts) do
		local cb = UI.Check(p, o[2], function() return mo[o[1]] end, function(v)
			mo[o[1]] = v
			refreshList()
			if state.sel then selectTemplate(state.sel) end
		end, o[3])
		cb:SetPoint("TOPLEFT", prevC, "BOTTOMLEFT", prevC == oh and 0 or 0, -4)
		prevC = cb
		table.insert(optChecks, cb)
	end

	-- Lista
	scroll, content = UI.Scroll(p, 430, UI.HEIGHT - 10)
	scroll:SetPoint("TOPLEFT", p, "TOPLEFT", 158, -4)

	-- Förhandsvisning / redigering
	local px = 158 + 430 + 30
	previewTitle = UI.Header(p, "")
	previewTitle:SetPoint("TOPLEFT", p, "TOPLEFT", px, -4)
	local nl = UI.Label(p, "Name:", "GameFontNormalSmall")
	nl:SetPoint("TOPLEFT", previewTitle, "BOTTOMLEFT", 0, -10)
	nameBox = UI.EditBox(p, 110)
	nameBox:HookScript("OnTextChanged", function(_, user) if user then state.edited = true end end)
	nameBox:SetMaxLetters(16)
	nameBox:SetPoint("LEFT", nl, "RIGHT", 10, 0)
	perCharCheck = UI.Check(p, "Character", function() return ns.db.macros.perCharacter end, function() end,
		"Save as a character macro (otherwise an account macro).")
	perCharCheck:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
	preview, previewEdit = UI.MultiLine(p, 258, 190, function(text, user)
		setCounter(text)
		if user then state.edited = true end
	end)
	preview:SetPoint("TOPLEFT", nl, "BOTTOMLEFT", 0, -10)
	counter = UI.Label(p, "", "GameFontHighlightSmall")
	counter:SetPoint("TOPRIGHT", preview, "BOTTOMRIGHT", 0, -4)
	previewInfo = UI.Label(p, "", "GameFontHighlightSmall")
	previewInfo:SetPoint("TOPLEFT", preview, "BOTTOMLEFT", 0, -22)
	previewInfo:SetWidth(258)

	createBtn = UI.Button(p, "Create in game", 126, 24, function()
		local name, body = ns.trim(nameBox:GetText()), previewEdit:GetText()
		local perChar = perCharCheck:GetChecked() and true or false
		local ok, msg = ME:Save(name, body, perChar)
		ns.print("%s: %s", name, ok and msg or ("|cffff4040" .. tostring(msg) .. "|r"))
		refreshList()
	end, "Creates or updates the macro in game with the text in the box (including your edits).")
	createBtn:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", px, 60)
	pickBtn = UI.Button(p, "Pick up", 126, 24, function()
		local name = ns.trim(nameBox:GetText())
		if not ME:Pickup(name) then ns.print("create the macro first.") end
	end, "Puts the macro on your cursor — drop it on an action bar.")
	pickBtn:SetPoint("LEFT", createBtn, "RIGHT", 6, 0)
	saveCustomBtn = UI.Button(p, "Save as custom", 126, 24, function()
		local name, body = ns.trim(nameBox:GetText()), previewEdit:GetText()
		if name == "" then ns.print("give the macro a name.") return end
		local entry = { name = name, body = body, perChar = perCharCheck:GetChecked() and true or false }
		if state.customIndex then
			ns.db.custom[state.customIndex] = entry
		else
			table.insert(ns.db.custom, entry)
			state.customIndex = #ns.db.custom
		end
		state.cat = CUSTOM
		selectCustom(state.customIndex)
		ns.print("saved to custom macros: %s", name)
	end, "Saves the text as a custom macro in Farseer (kept between sessions).")
	saveCustomBtn:SetPoint("TOPLEFT", createBtn, "BOTTOMLEFT", 0, -6)
	deleteBtn = UI.Button(p, "Delete", 126, 24, function()
		local name = ns.trim(nameBox:GetText())
		if InCombatLockdown() then ns.print("macros can't be deleted in combat.") return end
		UI.Confirm("Delete the macro \"" .. name .. "\"" .. (state.customIndex and " (also from Farseer's custom macros)" or "") .. "?", function()
			if InCombatLockdown() then ns.print("macros can't be deleted in combat.") return end
			ME:Delete(name)
			if state.customIndex then
				table.remove(ns.db.custom, state.customIndex)
				state.customIndex = nil
				selectCustom(ns.db.custom[1] and 1 or nil)
			else
				refreshList()
				if state.sel then selectTemplate(state.sel) end
			end
		end)
	end)
	deleteBtn:SetPoint("LEFT", saveCustomBtn, "RIGHT", 6, 0)
end

local function refresh()
	for _, cb in ipairs(optChecks) do cb:Refresh() end
	-- Något du skrivit i rutorna skrivs inte över bara för att fliken visas igen (zonbyte, flikbyte)
	if state.edited then
		refreshList()
	elseif state.cat == CUSTOM then
		selectCustom(state.customIndex)
	elseif state.sel then
		selectTemplate(state.sel)
	else
		local first = templatesIn(state.cat)[1]
		if first then selectTemplate(first) end
	end
	local exists = 0
	if InCombatLockdown() then previewInfo:SetText("|cffff4040In combat: macros can't be changed right now.|r") end
	return exists
end

UI.AddTab("macros", "Macros", build, refresh)
