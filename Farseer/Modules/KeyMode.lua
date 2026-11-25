-- Keybind-läge (som ShamanForevers /kb): håll musen över en Farseer-knapp och tryck en tangent.
-- Shift/Ctrl/Alt fungerar, Delete/Backspace tar bort knappens tangent, Escape avslutar.
-- Det som låg på tangenten innan sparas i samma backup som mallarna (Restore all keys).

local _, ns = ...
local KM = ns.module("KeyMode")

local panel, marker
local active = false
local hovered

-- Knappar som går att binda (globala namn på säkra knappar)
function KM:Candidates()
	local list = {}
	local function add(name)
		local b = _G[name]
		if type(b) == "table" and b.IsShown then table.insert(list, b) end
	end
	for i = 1, (ns.MAX_SITUATIONS or 10) do add("FarseerSit" .. i) end
	for i = 1, 12 do add("FarseerCounter" .. i) end
	for _, el in ipairs(ns.ELEMENTS or {}) do add("FarseerTotem" .. el) end
	for _, n in ipairs({ "FarseerTotemicCall", "FarseerShieldButton", "FarseerImbueButton",
		"FarseerImbueOffButton", "FarseerRezButton" }) do add(n) end
	return list
end

local function commandFor(b, mouse) return "CLICK " .. b:GetName() .. ":" .. (mouse or "LeftButton") end
KM.CommandFor = commandFor

local function bindingSet()
	local set = ns.get(GetCurrentBindingSet)
	if set ~= 1 and set ~= 2 then set = 2 end
	return set
end

-- Tangenter som inte är egna tangenter
local IGNORE = { LSHIFT = true, RSHIFT = true, LCTRL = true, RCTRL = true, LALT = true, RALT = true,
	UNKNOWN = true, LMETA = true, RMETA = true }

function KM:FullKey(key)
	if type(key) ~= "string" or IGNORE[key] then return nil end
	local mods = ""
	if ns.get(IsAltKeyDown) == true then mods = mods .. "ALT-" end
	if ns.get(IsControlKeyDown) == true then mods = mods .. "CTRL-" end
	if ns.get(IsShiftKeyDown) == true then mods = mods .. "SHIFT-" end
	return mods .. key
end

-- Bind tangenten till knappen. Knappens gamla tangent tas bort; det som låg på tangenten sparas.
function KM:Bind(b, key, mouse)
	if InCombatLockdown() or not (b and key) then return false end
	local cmd = commandFor(b, mouse)
	local backup = ns.char.bindBackup
	local old = ns.get(GetBindingAction, key)
	if backup[key] == nil then backup[key] = (type(old) == "string" and old) or "" end
	-- Knappens tidigare tangenter bort (alla utom den nya)
	local okKeys, k1, k2, k3, k4 = ns.getAll(GetBindingKey, cmd)
	if okKeys then
		for _, prev in ipairs({ k1, k2, k3, k4 }) do
			if type(prev) == "string" and prev ~= key then
				if backup[prev] == nil then backup[prev] = cmd end
				pcall(SetBinding, prev)
			end
		end
	end
	local ok = pcall(SetBindingClick, key, b:GetName(), mouse or "LeftButton")
	if not ok then ok = pcall(SetBinding, key, cmd) end
	pcall(SaveBindings, bindingSet())
	ns.fire("BINDINGS_CHANGED")
	return ok
end

function KM:Clear(b)
	if InCombatLockdown() or not b then return false end
	local cmd = commandFor(b)
	local backup = ns.char.bindBackup
	for _ = 1, 4 do
		local prev = ns.get(GetBindingKey, cmd)
		if type(prev) ~= "string" then break end
		if backup[prev] == nil then backup[prev] = cmd end
		pcall(SetBinding, prev)
	end
	pcall(SaveBindings, bindingSet())
	ns.fire("BINDINGS_CHANGED")
	return true
end

function KM:Hovered()
	for _, b in ipairs(self:Candidates()) do
		if b:IsShown() and b:IsVisible() and b:IsMouseOver() then return b end
	end
	return nil
end

local function label(b)
	if not b then return "Hover a Farseer button" end
	local key = ns.BindingEngine:KeyFor(commandFor(b))
	local name = b:GetName():gsub("^Farseer", "")
	return string.format("|cffffffff%s|r  —  key: |cff40c0ff%s|r", name, key or "none")
end

function KM:Build()
	panel = CreateFrame("Frame", "FarseerKeyMode", UIParent, "BackdropTemplate")
	panel:SetSize(460, 64)
	panel:SetPoint("TOP", UIParent, "TOP", 0, -90)
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	ns.Theme.Skin(panel, ns.Theme.C.bg, ns.Theme.C.accentDim, 0.96)
	ns.Theme.Shadow(panel, 6)
	panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	panel.title:SetPoint("TOP", 0, -10)
	panel.title:SetText("|cff40c0ffFarseer|r key binding mode")
	panel.info = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	panel.info:SetPoint("TOP", panel.title, "BOTTOM", 0, -5)
	panel.hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	panel.hint:SetPoint("TOP", panel.info, "BOTTOM", 0, -4)
	panel.hint:SetText("Press a key to bind  ·  Delete clears  ·  Escape: done")
	panel:EnableKeyboard(true)
	pcall(panel.SetPropagateKeyboardInput, panel, false)
	panel:SetScript("OnKeyDown", function(_, key) KM:OnKey(key) end)
	panel:SetScript("OnUpdate", function(_, elapsed)
		panel.acc = (panel.acc or 0) + elapsed
		if panel.acc < 0.05 then return end
		panel.acc = 0
		KM:Track()
	end)
	marker = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
	marker:SetFrameStrata("FULLSCREEN_DIALOG")
	if marker.SetBackdrop then
		marker:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 2 })
		marker:SetBackdropBorderColor(0.25, 0.75, 1, 1)
	end
	marker:Hide()
	panel:Hide()
end

function KM:Track()
	local b = self:Hovered()
	hovered = b
	if b then
		marker:ClearAllPoints()
		marker:SetPoint("TOPLEFT", b, "TOPLEFT", -3, 3)
		marker:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 3, -3)
		marker:Show()
	else
		marker:Hide()
	end
	panel.info:SetText(label(b))
end

function KM:OnKey(key)
	if key == "ESCAPE" then self:Stop() return end
	local b = hovered or self:Hovered()
	if not b then return end
	if key == "DELETE" or key == "BACKSPACE" then
		self:Clear(b)
	else
		local full = self:FullKey(key)
		if full then self:Bind(b, full) end
	end
	panel.info:SetText(label(b))
end

function KM:Active() return active end

function KM:Start()
	if InCombatLockdown() then ns.print("key binding mode can't start in combat.") return false end
	if not panel then self:Build() end
	active = true
	panel:Show()
	self:Track()
	return true
end

function KM:Stop()
	active = false
	hovered = nil
	if panel then panel:Hide() end
	if marker then marker:Hide() end
end

function KM:Toggle()
	if active then self:Stop() else self:Start() end
end

function KM:OnShamanLogin()
	ns.listen("COMBAT_START", function() if active then KM:Stop() end end)
end
