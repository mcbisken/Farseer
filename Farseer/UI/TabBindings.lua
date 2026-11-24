-- Keybinds: välj mall, se exakt vad som binds (och vad som ligger där nu), applicera eller återställ.

local _, ns = ...
local UI = ns.UI
local BE

local sel = "elemental"
local presetButtons = {}
local title, desc, backupText, content, rows
local ROW_H = 22

local function refreshDetails()
	if not content then return end
	local p = BE:Preset(sel)
	if not p then return end
	title:SetText(p.name)
	desc:SetText(p.desc or "")
	for _, r in ipairs(rows) do r:Hide() end
	for i, b in ipairs(p.binds) do
		local r = rows[i]
		if not r then
			r = CreateFrame("Frame", nil, content)
			r:SetSize(560, ROW_H)
			r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
			r.bg = r:CreateTexture(nil, "BACKGROUND")
			r.bg:SetAllPoints()
			r.key = UI.Label(r, "", "GameFontNormal")
			r.key:SetPoint("LEFT", 6, 0)
			r.key:SetWidth(110)
			r.what = UI.Label(r, "", "GameFontHighlight")
			r.what:SetPoint("LEFT", r.key, "RIGHT", 4, 0)
			r.what:SetWidth(240)
			r.now = UI.Label(r, "", "GameFontDisableSmall")
			r.now:SetPoint("LEFT", r.what, "RIGHT", 4, 0)
			r.now:SetWidth(190)
			rows[i] = r
		end
		r.bg:SetColorTexture(1, 1, 1, i % 2 == 0 and 0.04 or 0)
		r.key:SetText(GetBindingText and GetBindingText(b[1]) or b[1])
		r.what:SetText(BE:Describe(b))
		local cur = BE:Current(b[1])
		local curName = cur and (GetBindingName and GetBindingName(cur) or cur) or "—"
		r.now:SetText("now: " .. tostring(curName))
		r:Show()
	end
	content:SetHeight(#p.binds * ROW_H)
	for _, pb in ipairs(presetButtons) do
		if pb.id == sel then pb:LockHighlight() else pb:UnlockHighlight() end
	end
	local n = 0
	for _ in pairs(ns.char.bindBackup) do n = n + 1 end
	backupText:SetText(n > 0 and string.format("Backup: %d keys can be restored to how they were before Farseer.", n)
		or "No backup: Farseer hasn't changed any keys.")
end

local function build(p)
	BE = ns.BindingEngine
	rows = {}
	local h = UI.Header(p, "Keybind templates")
	h:SetPoint("TOPLEFT", 4, -4)
	local last
	for i, preset in ipairs(ns.BINDING_PRESETS) do
		local b = UI.Button(p, preset.name, 220, 26, function() sel = preset.id; refreshDetails() end)
		b.id = preset.id
		if i == 1 then b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8) else b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -4) end
		last = b
		table.insert(presetButtons, b)
	end
	local note = UI.Label(p,
		"The templates create the macros needed and bind them right away. Whatever was on the keys is saved first.\n\n"
		.. "The situation buttons, counter totems, shield and imbue are also under the game's Keybindings -> Farseer, "
		.. "if you want to bind them yourself.",
		"GameFontHighlightSmall")
	note:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -16)
	note:SetWidth(220)

	local x = 250
	title = UI.Header(p, "")
	title:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	desc = UI.Label(p, "", "GameFontHighlight")
	desc:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	desc:SetWidth(600)
	local hk = UI.Label(p, "Key", "GameFontNormalSmall")
	hk:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 6, -12)
	local hw = UI.Label(p, "Farseer binds", "GameFontNormalSmall")
	hw:SetPoint("LEFT", hk, "LEFT", 114, 0)
	local hn = UI.Label(p, "Currently bound", "GameFontNormalSmall")
	hn:SetPoint("LEFT", hw, "LEFT", 244, 0)
	local sf
	sf, content = UI.Scroll(p, 580, 330)
	sf:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -30)

	local apply = UI.Button(p, "Apply template", 170, 28, function()
		local preset = BE:Preset(sel)
		UI.Confirm("Bind \"" .. preset.name .. "\"? The keys in the list will be overwritten (a backup is saved).", function()
			local n, errors = BE:Apply(sel)
			ns.print("%s: %d keybinds set.%s", preset.name, n, #errors > 0 and (" Errors: " .. table.concat(errors, "; ")) or "")
			refreshDetails()
		end)
	end)
	apply:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -14)
	local restore = UI.Button(p, "Restore all keys", 190, 28, function()
		UI.Confirm("Restore all keys Farseer has changed to how they were before?", function()
			local n = BE:Restore()
			ns.print("%d keys restored.", n)
			refreshDetails()
		end)
	end)
	restore:SetPoint("LEFT", apply, "RIGHT", 8, 0)
	local mk = UI.Button(p, "Create macros only", 170, 28, function()
		local preset = BE:Preset(sel)
		local n = 0
		for _, b in ipairs(preset.binds) do
			if b.macro and ns.MacroEngine:CreateFromTemplate(b.macro, true) then n = n + 1 end
		end
		ns.print("%d macros created/updated (no keybinds changed).", n)
		refreshDetails()
	end, "Creates the template's macros without touching your keybinds — drag them to your bars yourself.")
	mk:SetPoint("LEFT", restore, "RIGHT", 8, 0)
	backupText = UI.Label(p, "", "GameFontHighlightSmall")
	backupText:SetPoint("TOPLEFT", apply, "BOTTOMLEFT", 0, -8)
	backupText:SetWidth(580)
end

UI.AddTab("bindings", "Keybinds", build, refreshDetails)
