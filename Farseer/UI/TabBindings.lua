-- Keybinds: välj mall, se exakt vad som binds (och vad som ligger där nu), applicera eller återställ.

local _, ns = ...
local UI = ns.UI
local BE

local sel = "elemental"
local presetButtons = {}
local title, desc, backupText, content, rows, layerDrop, keepCheck, summary
local LAYER_TEXT = { [""] = "No modifier", SHIFT = "Shift + key", CTRL = "Ctrl + key", ALT = "Alt + key" }
local ROW_H = 22

local function refreshDetails()
	if not content then return end
	local p = BE:Preset(sel)
	if not p then return end
	title:SetText(p.name)
	desc:SetText(p.desc or "")
	for _, r in ipairs(rows) do r:Hide() end
	local plan = BE:Plan(sel)
	local binds, kept, warn = 0, 0, 0
	for i, e in ipairs(plan) do
		local b = e.b
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
		local keyText = GetBindingText and GetBindingText(e.key) or e.key
		r.key:SetText(e.skip and ("|cff888888" .. keyText .. "|r") or keyText)
		r.what:SetText((e.skip and "|cff888888" or "") .. BE:Describe(b) .. (e.skip and "|r" or "")
			.. (e.modWarn and " |cffffb040(*)|r" or ""))
		local cur = e.cur
		local curName = cur and (GetBindingName and GetBindingName(cur) or cur) or "—"
		if e.skip == "kept" then
			r.now:SetText("|cff40ff40kept:|r " .. tostring(curName))
		elseif e.skip then
			r.now:SetText("|cffff6060skipped:|r " .. e.skip)
		elseif cur then
			r.now:SetText("|cffffb040replaces:|r " .. tostring(curName))
		else
			r.now:SetText("|cff888888free|r")
		end
		if e.skip then kept = kept + 1 else binds = binds + 1 end
		if e.modWarn then warn = warn + 1 end
		r:Show()
	end
	content:SetHeight(#plan * ROW_H)
	summary:SetText(string.format("%d keys will be bound, %d left as they are.%s", binds, kept,
		warn > 0 and "  |cffffb040(*)|r = macro with its own Shift/Ctrl/Alt part: on a key with that modifier it always does that part." or ""))
	layerDrop:Refresh()
	keepCheck:Refresh()
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
		local b = UI.Button(p, preset.name, 220, 24, function()
			sel = preset.id
			-- Mallar som är gjorda för ett lager föreslår det (går att ändra)
			-- Förslaget gäller bara så länge mallen är vald: en annan mall tar bort det igen
			local o = BE:Options()
			if preset.layer and o.mod == "" then
				o.mod, o.keep, o.suggested = preset.layer, true, preset.id
			elseif not preset.layer and o.suggested then
				o.mod, o.keep, o.suggested = "", false, nil
			end
			refreshDetails()
		end)
		b.id = preset.id
		if i == 1 then b:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8) else b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -3) end
		last = b
		table.insert(presetButtons, b)
	end
	local note = UI.Label(p,
		"The templates create the macros needed and bind them right away. Whatever was on the keys is saved first.\n\n"
		.. "Keep your own keybinds: pick \"Shift + key\" and tick \"Keep my keybinds\". Farseer then only uses free "
		.. "Shift keys (1 -> Shift+1).\n\n"
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
	-- Lager och "behåll mina"
	local ll = UI.Label(p, "Put on:", "GameFontNormalSmall")
	ll:SetPoint("TOPLEFT", desc, "BOTTOMLEFT", 0, -12)
	layerDrop = UI.Dropdown(p, 130, function() return LAYER_TEXT[BE:Options().mod] or "No modifier" end, function()
		local items = {}
		for _, m in ipairs(BE.LAYERS) do table.insert(items, { text = LAYER_TEXT[m], value = m }) end
		return items
	end, function(v) BE:Options().mod = v; BE:Options().suggested = nil; refreshDetails() end)
	layerDrop:SetPoint("LEFT", ll, "RIGHT", 6, 0)
	keepCheck = UI.Check(p, "Keep my keybinds (only bind free keys)", function() return BE:Options().keep end,
		function(v) BE:Options().keep = v; BE:Options().suggested = nil; refreshDetails() end,
		"Keys that already do something (not Farseer) are left alone. Keys Farseer bound earlier may be updated.")
	keepCheck:SetPoint("LEFT", layerDrop, "RIGHT", 12, 0)
	local hk = UI.Label(p, "Key", "GameFontNormalSmall")
	hk:SetPoint("TOPLEFT", ll, "BOTTOMLEFT", 6, -14)
	local hw = UI.Label(p, "Farseer binds", "GameFontNormalSmall")
	hw:SetPoint("LEFT", hk, "LEFT", 114, 0)
	local hn = UI.Label(p, "Currently bound", "GameFontNormalSmall")
	hn:SetPoint("LEFT", hw, "LEFT", 244, 0)
	local sf
	sf, content = UI.Scroll(p, 580, 270)
	sf:SetPoint("TOPLEFT", hk, "BOTTOMLEFT", -6, -4)
	summary = UI.Label(p, "", "GameFontHighlightSmall")
	summary:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -6)
	summary:SetWidth(600)

	local apply = UI.Button(p, "Apply template", 170, 28, function()
		local preset = BE:Preset(sel)
		local o = BE:Options()
		UI.Confirm("Bind \"" .. preset.name .. "\"" .. (o.mod ~= "" and (" on " .. LAYER_TEXT[o.mod]) or "") .. "? "
			.. (o.keep and "Only free keys are used." or "The keys in the list are overwritten.") .. " A backup is saved.", function()
			local n, errors, kept = BE:Apply(sel)
			ns.print("%s: %d keybinds set%s.%s", preset.name, n, (kept or 0) > 0 and (", " .. kept .. " kept") or "",
				#errors > 0 and (" Errors: " .. table.concat(errors, "; ")) or "")
			refreshDetails()
		end)
	end)
	apply:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -10)
	local restore = UI.Button(p, "Restore all keys", 190, 28, function()
		UI.Confirm("Restore all keys Farseer has changed to how they were before?", function()
			local n, errors = BE:Restore()
			ns.print("%d keys restored.%s", n, (errors and #errors > 0) and (" Not restored (kept for next try): " .. table.concat(errors, "; ")) or "")
			refreshDetails()
		end)
	end)
	restore:SetPoint("LEFT", apply, "RIGHT", 8, 0)
	local kb = UI.Button(p, "Key binding mode", 160, 28, function() ns.KeyMode:Toggle() end,
		"Hover any Farseer button and press a key to bind it (Shift/Ctrl/Alt work). Delete clears it, Escape is done. Also /farseer kb.")
	kb:SetPoint("LEFT", restore, "RIGHT", 8, 0)
	local mk = UI.Button(p, "Create macros only", 170, 28, function()
		local preset = BE:Preset(sel)
		local n = 0
		for _, b in ipairs(preset.binds) do
			if b.macro and ns.MacroEngine:CreateFromTemplate(b.macro, true) then n = n + 1 end
		end
		ns.print("%d macros created/updated (no keybinds changed).", n)
		refreshDetails()
	end, "Creates the template's macros without touching your keybinds — drag them to your bars yourself.")
	mk:SetPoint("TOPLEFT", apply, "BOTTOMLEFT", 0, -6)
	backupText = UI.Label(p, "", "GameFontHighlightSmall")
	backupText:SetPoint("TOPLEFT", mk, "BOTTOMLEFT", 0, -8)
	backupText:SetWidth(580)
end

UI.AddTab("bindings", "Keybinds", build, refreshDetails)
