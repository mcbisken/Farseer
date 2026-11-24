-- Huvudfönstret (/farseer eller minimap-ikonen): flikar som byggs första gången de visas.

local _, ns = ...
local UI = ns.UI
local OP = ns.module("Options")

local W, H = 900, 620
local main
local tabs, tabButtons = {}, {}
local current

-- Flikmoduler registrerar sig här: build(panel) en gång, refresh(panel) varje gång fliken visas
function UI.AddTab(id, title, build, refresh)
	table.insert(tabs, { id = id, title = title, build = build, refresh = refresh })
end

local function selectTab(id)
	for i, t in ipairs(tabs) do
		local sel = t.id == id
		if sel and not t.panel then
			t.panel = CreateFrame("Frame", nil, main.body)
			t.panel:SetAllPoints()
			local ok, err = pcall(t.build, t.panel)
			if not ok then ns.report(err) end
		end
		if t.panel then t.panel:SetShown(sel) end
		local b = tabButtons[i]
		if sel then b:LockHighlight() else b:UnlockHighlight() end
		b.sel:SetShown(sel)
		if sel and t.refresh then
			local ok, err = pcall(t.refresh, t.panel)
			if not ok then ns.report(err) end
		end
	end
	current = id
end
UI.SelectTab = selectTab

function UI.RefreshCurrent()
	if main and main:IsShown() and current then selectTab(current) end
end

local function build()
	main = CreateFrame("Frame", "FarseerOptions", UIParent, "BackdropTemplate")
	main:SetSize(W, H)
	main:SetPoint("CENTER")
	main:SetFrameStrata("DIALOG")
	main:SetToplevel(true)
	main:SetClampedToScreen(true)
	main:SetMovable(true)
	main:EnableMouse(true)
	main:RegisterForDrag("LeftButton")
	main:SetScript("OnDragStart", main.StartMoving)
	main:SetScript("OnDragStop", main.StopMovingOrSizing)
	UI.Backdrop(main, 0.96, { 0.25, 0.4, 0.65 })
	table.insert(UISpecialFrames, "FarseerOptions")

	local icon = main:CreateTexture(nil, "ARTWORK")
	icon:SetSize(34, 34)
	icon:SetPoint("TOPLEFT", 12, -10)
	icon:SetTexture("Interface\\Icons\\Spell_Nature_BloodLust")
	local title = UI.Label(main, "Farseer", "GameFontNormalHuge", { 0.2, 0.6, 1 })
	title:SetPoint("LEFT", icon, "RIGHT", 10, 4)
	local sub = UI.Label(main, "Shaman-addon för WoW: Forever  ·  v" .. ns.VERSION, "GameFontDisableSmall")
	sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -2)

	local close = UI.Button(main, "X", 26, 24, function() main:Hide() end)
	close:SetPoint("TOPRIGHT", -8, -8)

	-- Flikrad (bryts till två rader om flikarna inte får plats)
	local x, y = 12, -54
	for i, t in ipairs(tabs) do
		local b = UI.Button(main, t.title, 0, 26, function() selectTab(t.id) end)
		b:SetWidth(math.max(74, (b:GetFontString() and b:GetFontString():GetStringWidth() or 60) + 24))
		if x + b:GetWidth() > W - 12 then
			x, y = 12, y - 28
		end
		b:SetPoint("TOPLEFT", main, "TOPLEFT", x, y)
		x = x + b:GetWidth() + 4
		b.sel = b:CreateTexture(nil, "OVERLAY")
		b.sel:SetColorTexture(0.2, 0.6, 1, 1)
		b.sel:SetHeight(2)
		b.sel:SetPoint("BOTTOMLEFT", 4, 1)
		b.sel:SetPoint("BOTTOMRIGHT", -4, 1)
		b.sel:Hide()
		tabButtons[i] = b
	end

	-- Fler rader: fönstret blir högre, så flikarnas yta är lika stor
	local extra = -54 - y
	main:SetHeight(H + extra)
	main.body = CreateFrame("Frame", nil, main)
	main.body:SetPoint("TOPLEFT", 12, -88 - extra)
	main.body:SetPoint("BOTTOMRIGHT", -12, 12)

	main:SetScript("OnShow", function() if current then selectTab(current) end end)
	main:Hide()
end

function OP:Toggle(tab)
	if not main then build() end
	if main:IsShown() and (not tab or tab == current) then
		main:Hide()
		return
	end
	main:Show()
	selectTab(tab or current or tabs[1].id)
end
function OP:Open(tab)
	if not main then build() end
	main:Show()
	selectTab(tab or current or tabs[1].id)
end

UI.WIDTH, UI.HEIGHT = W - 24, H - 100

---------------------------------------------------------------------------------------------------
-- Minimap-ikon (egen, dras runt kartan)
---------------------------------------------------------------------------------------------------
local mini
local function placeMini()
	local a = math.rad(ns.db.minimapAngle or 215)
	local r = (Minimap:GetWidth() / 2) + 6
	mini:ClearAllPoints()
	mini:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

function OP:BuildMinimap()
	if mini or not Minimap then return end
	mini = CreateFrame("Button", "FarseerMinimapButton", Minimap)
	mini:SetSize(31, 31)
	mini:SetFrameStrata("MEDIUM")
	mini:SetFrameLevel(8)
	mini:RegisterForClicks("LeftButtonUp", "RightButtonUp", "MiddleButtonUp")
	mini:RegisterForDrag("LeftButton")
	mini:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	local bg = mini:CreateTexture(nil, "BACKGROUND")
	bg:SetSize(20, 20)
	bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
	bg:SetPoint("TOPLEFT", 7, -5)
	local ic = mini:CreateTexture(nil, "ARTWORK")
	ic:SetSize(18, 18)
	ic:SetTexture("Interface\\Icons\\Spell_Nature_BloodLust")
	ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	ic:SetPoint("TOPLEFT", 7, -6)
	local border = mini:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")
	mini:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			ns.setLocked(not ns.char.locked)
			ns.print(ns.char.locked and "bars låsta." or "bars upplåsta — dra för att flytta, högerklicka ikonen igen för att låsa.")
		elseif button == "MiddleButton" then
			if ns.Bars then ns.Bars:SetMode(ns.Bars:Mode() == "PVP" and "PVE" or "PVP") end
		else
			OP:Toggle()
		end
	end)
	mini:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", function()
			local mx, my = Minimap:GetCenter()
			local cx, cy = GetCursorPosition()
			local s = Minimap:GetEffectiveScale()
			ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
			placeMini()
		end)
	end)
	mini:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	mini:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		Farseer_OnCompartmentEnter(nil, self, true)
	end)
	mini:SetScript("OnLeave", function() GameTooltip:Hide() end)
	placeMini()
	mini:SetShown(ns.db.minimap ~= false)
end

function OP:SetMinimapShown(show)
	ns.db.minimap = show and true or false
	if mini then mini:SetShown(show) end
end

---------------------------------------------------------------------------------------------------
-- Spelets Settings-panel och addon-facket
---------------------------------------------------------------------------------------------------
function OP:RegisterSettings()
	if not (Settings and Settings.RegisterCanvasLayoutCategory) then return end
	local panel = CreateFrame("Frame")
	local t = UI.Label(panel, "Farseer", "GameFontNormalHuge", { 0.2, 0.6, 1 })
	t:SetPoint("TOPLEFT", 16, -16)
	local d = UI.Label(panel, "Alla inställningar finns i Farseers eget fönster.")
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
	local b = UI.Button(panel, "Öppna Farseer", 160, 26, function()
		if SettingsPanel and SettingsPanel.Close then pcall(SettingsPanel.Close, SettingsPanel, true) end
		OP:Open()
	end)
	b:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
	local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, panel, "Farseer")
	if ok and cat then pcall(Settings.RegisterAddOnCategory, cat) end
end

function Farseer_OnCompartmentClick(_, button)
	if button == "RightButton" then ns.setLocked(not ns.char.locked) else OP:Toggle() end
end

function Farseer_OnCompartmentEnter(_, frame, owned)
	if not owned then GameTooltip:SetOwner(frame or UIParent, "ANCHOR_LEFT") end
	GameTooltip:SetText("Farseer")
	local mode = ns.Bars and ns.Bars:Mode() or "PVE"
	GameTooltip:AddLine("Läge: " .. (mode == "PVP" and "|cffff6060PvP|r" or "|cff60ff60PvE|r"), 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Vänsterklick: inställningar", 0.6, 0.8, 1)
	GameTooltip:AddLine("Högerklick: lås upp / lås bars", 0.6, 0.8, 1)
	GameTooltip:AddLine("Mittenklick: växla PvE/PvP", 0.6, 0.8, 1)
	GameTooltip:AddLine("Dra: flytta ikonen", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function Farseer_OnCompartmentLeave() GameTooltip:Hide() end

function OP:OnLogin()
	self:BuildMinimap()
	self:RegisterSettings()
	ns.listen("MODE_CHANGED", function() UI.RefreshCurrent() end)
end
