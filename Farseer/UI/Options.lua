-- Huvudfönstret (/farseer eller minimap-ikonen): titelrad, sidomeny med grupperade flikar (ikon + namn)
-- och en yta där flikarna byggs första gången de visas.

local _, ns = ...
local UI = ns.UI
local T = ns.Theme
local C = T.C
local OP = ns.module("Options")

local SIDE = 188            -- sidomenyns bredd
local TOP = 52              -- titelradens höjd
local BODY_W, BODY_H = 876, 548
local W, H = SIDE + BODY_W + 28, TOP + BODY_H + 28
local main
local tabs, tabButtons = {}, {}
local current

-- Grupper och ikoner i sidomenyn (flikar som inte står här hamnar sist under "More")
local GROUPS = {
	{ "General", { "overview", "settings", "profiles", "test" } },
	{ "Totems", { "situations", "advisor", "raid" } },
	{ "Combat", { "combat", "procs", "alerts", "healing" } },
	{ "Setup", { "macros", "bindings" } },
	{ "Progress", { "leveling", "t05", "bis" } },
}
local ICONS = {
	overview = "Interface\\Icons\\INV_Misc_Book_09",
	settings = "Interface\\Icons\\INV_Misc_Gear_01",
	profiles = "Interface\\Icons\\INV_Misc_Note_02",
	test = "Interface\\Icons\\INV_Misc_Spyglass_02",
	situations = "Interface\\Icons\\Spell_Nature_StoneSkinTotem",
	advisor = "Interface\\Icons\\Spell_Nature_TremorTotem",
	raid = "Interface\\Icons\\Spell_Nature_GroundingTotem",
	combat = "Interface\\Icons\\Spell_Nature_EarthShock",
	procs = "Interface\\Icons\\Spell_Nature_LightningShield",
	alerts = "Interface\\Icons\\Ability_Warrior_BattleShout",
	healing = "Interface\\Icons\\Spell_Nature_HealingWaveGreater",
	macros = "Interface\\Icons\\INV_Misc_Note_01",
	bindings = "Interface\\Icons\\INV_Misc_Key_03",
	leveling = "Interface\\Icons\\INV_Misc_Map_01",
	t05 = "Interface\\Icons\\Spell_Nature_Lightning",
	bis = "Interface\\Icons\\INV_Misc_Bag_10",
}
UI.TAB_ICONS = ICONS

-- Flikmoduler registrerar sig här: build(panel) en gång, refresh(panel) varje gång fliken visas
function UI.AddTab(id, title, build, refresh)
	table.insert(tabs, { id = id, title = title, build = build, refresh = refresh })
end

local function paintTab(b, sel, hover)
	b.sel:SetShown(sel)
	b.bar:SetShown(sel)
	b.hover:SetShown(hover and not sel)
	if sel then
		b.text:SetTextColor(1, 1, 1)
		b.icon:SetDesaturated(false)
		b.icon:SetAlpha(1)
	else
		local c = hover and C.text or C.dim
		b.text:SetTextColor(c[1], c[2], c[3])
		b.icon:SetDesaturated(not hover)
		b.icon:SetAlpha(hover and 1 or 0.7)
	end
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
		b.selected = sel
		paintTab(b, sel, false)
		if sel then
			main.crumb:SetText(t.title)
			if sel and t.refresh then
				local ok, err = pcall(t.refresh, t.panel)
				if not ok then ns.report(err) end
			end
		end
	end
	current = id
end
UI.SelectTab = selectTab

-- Automatisk uppdatering (t.ex. PvE/PvP-byte vid zonbyte) får inte skriva över något man håller på att skriva
function UI.RefreshCurrent()
	if not (main and main:IsShown() and current) then return end
	local focus = GetCurrentKeyBoardFocus and GetCurrentKeyBoardFocus()
	if focus then return end
	selectTab(current)
end

-- Flikarna i sidomenyns ordning, med grupprubriker
local function ordered()
	local byId, used, out = {}, {}, {}
	for i, t in ipairs(tabs) do byId[t.id] = i end
	for _, g in ipairs(GROUPS) do
		local first = true
		for _, id in ipairs(g[2]) do
			if byId[id] then
				if first then table.insert(out, { group = g[1] }); first = false end
				table.insert(out, { index = byId[id] })
				used[id] = true
			end
		end
	end
	local rest = false
	for i, t in ipairs(tabs) do
		if not used[t.id] then
			if not rest then table.insert(out, { group = "More" }); rest = true end
			table.insert(out, { index = i })
		end
	end
	return out
end

local function makeTab(parent, i, t)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(SIDE - 16, 24)
	b.sel = b:CreateTexture(nil, "BACKGROUND")
	b.sel:SetAllPoints()
	b.sel:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.14)
	b.hover = b:CreateTexture(nil, "BACKGROUND")
	b.hover:SetAllPoints()
	b.hover:SetColorTexture(1, 1, 1, 0.04)
	b.bar = b:CreateTexture(nil, "ARTWORK")
	b.bar:SetPoint("TOPLEFT")
	b.bar:SetPoint("BOTTOMLEFT")
	b.bar:SetWidth(3)
	b.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetSize(16, 16)
	b.icon:SetPoint("LEFT", 12, 0)
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.icon:SetTexture(ICONS[t.id] or "Interface\\Icons\\INV_Misc_QuestionMark")
	b.text = b:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontTab"))
	b.text:SetPoint("LEFT", b.icon, "RIGHT", 9, 0)
	b.text:SetText(t.title)
	b:SetScript("OnEnter", function(self) paintTab(self, self.selected, true) end)
	b:SetScript("OnLeave", function(self) paintTab(self, self.selected, false) end)
	b:SetScript("OnClick", function()
		PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB or 841)
		selectTab(t.id)
	end)
	paintTab(b, false, false)
	tabButtons[i] = b
	return b
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
	T.Skin(main, C.bg, C.border, 0.97)
	T.Shadow(main, 8)
	table.insert(UISpecialFrames, "FarseerOptions")

	-- Titelrad (dra i den för att flytta fönstret)
	local bar = CreateFrame("Frame", nil, main)
	bar:SetPoint("TOPLEFT", 1, -1)
	bar:SetPoint("TOPRIGHT", -1, -1)
	bar:SetHeight(TOP)
	bar:EnableMouse(true)
	bar:RegisterForDrag("LeftButton")
	bar:SetScript("OnDragStart", function() main:StartMoving() end)
	bar:SetScript("OnDragStop", function() main:StopMovingOrSizing() end)
	local barBg = bar:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints()
	barBg:SetColorTexture(1, 1, 1, 1)
	if not T.Gradient(barBg, "VERTICAL", { C.side[1], C.side[2], C.side[3], 1 }, { 0.07, 0.09, 0.13, 1 }) then
		barBg:SetColorTexture(C.side[1], C.side[2], C.side[3], 1)
	end
	local glowLine = bar:CreateTexture(nil, "ARTWORK")
	glowLine:SetPoint("BOTTOMLEFT")
	glowLine:SetPoint("BOTTOMRIGHT")
	glowLine:SetHeight(1)
	glowLine:SetColorTexture(1, 1, 1, 1)
	if not T.Gradient(glowLine, "HORIZONTAL", { C.accent[1], C.accent[2], C.accent[3], 0.9 }, { C.accent[1], C.accent[2], C.accent[3], 0.05 }) then
		glowLine:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.5)
	end

	local iconFrame = CreateFrame("Frame", nil, bar)
	iconFrame:SetSize(32, 32)
	iconFrame:SetPoint("LEFT", 14, 0)
	local icon = iconFrame:CreateTexture(nil, "ARTWORK")
	icon:SetPoint("TOPLEFT", 1, -1)
	icon:SetPoint("BOTTOMRIGHT", -1, 1)
	icon:SetTexture("Interface\\Icons\\Spell_Nature_BloodLust")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	T.Border(iconFrame, { C.accent[1], C.accent[2], C.accent[3], 0.9 }, "OVERLAY", 0)
	local title = bar:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontTitle"))
	title:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 12, -1)
	title:SetText("FARSEER")
	pcall(title.SetSpacing, title, 0)
	local sub = bar:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontDim"))
	sub:SetPoint("BOTTOMLEFT", iconFrame, "BOTTOMRIGHT", 12, 0)
	sub:SetText("Shaman toolkit for WoW: Forever")
	-- Versionen i en liten bricka
	local pill = CreateFrame("Frame", nil, bar, "BackdropTemplate")
	T.Skin(pill, { C.accent[1] * 0.25, C.accent[2] * 0.25, C.accent[3] * 0.3 }, C.accentDim, 1)
	local ver = pill:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontAccent"))
	ver:SetPoint("CENTER", 0, 0)
	ver:SetText("v" .. tostring(ns.VERSION))
	local vw = tonumber(ver:GetStringWidth()) or 40
	pill:SetSize(math.max(40, vw + 14), 18)
	pill:SetPoint("LEFT", title, "RIGHT", 10, 0)
	-- Var du är: flikens namn till höger
	main.crumb = bar:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontHeader"))
	main.crumb:SetPoint("RIGHT", bar, "RIGHT", -52, 0)
	main.crumb:SetTextColor(C.dim[1], C.dim[2], C.dim[3])

	local close = UI.IconButton(bar, 28, "×", function() main:Hide() end, C.bad)
	close:SetPoint("RIGHT", -12, 0)

	-- Sidomeny
	local side = CreateFrame("Frame", nil, main)
	side:SetPoint("TOPLEFT", 1, -(TOP + 1))
	side:SetPoint("BOTTOMLEFT", 1, 1)
	side:SetWidth(SIDE)
	local sideBg = side:CreateTexture(nil, "BACKGROUND")
	sideBg:SetAllPoints()
	sideBg:SetColorTexture(C.side[1], C.side[2], C.side[3], 1)
	local sideEdge = side:CreateTexture(nil, "BORDER")
	sideEdge:SetPoint("TOPRIGHT")
	sideEdge:SetPoint("BOTTOMRIGHT")
	sideEdge:SetWidth(1)
	sideEdge:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

	local y = -10
	for _, row in ipairs(ordered()) do
		if row.group then
			local g = side:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontGroup"))
			g:SetPoint("TOPLEFT", side, "TOPLEFT", 20, y - 6)
			g:SetText(string.upper(row.group))
			y = y - 20
		else
			local b = makeTab(side, row.index, tabs[row.index])
			b:SetPoint("TOPLEFT", side, "TOPLEFT", 8, y)
			y = y - 25
		end
	end

	-- Fot i sidomenyn
	local foot = side:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontGroup"))
	foot:SetPoint("BOTTOMLEFT", side, "BOTTOMLEFT", 20, 10)
	foot:SetJustifyH("LEFT")
	foot:SetText("/farseer  ·  kb  ·  setup  ·  report")

	-- Flikarnas yta
	main.body = CreateFrame("Frame", nil, main)
	main.body:SetPoint("TOPLEFT", main, "TOPLEFT", SIDE + 14, -(TOP + 14))
	main.body:SetSize(BODY_W, BODY_H)

	-- Mjuk intoning
	local ok, fade = pcall(function()
		local g = main:CreateAnimationGroup()
		local a = g:CreateAnimation("Alpha")
		a:SetFromAlpha(0)
		a:SetToAlpha(1)
		a:SetDuration(0.14)
		return g
	end)
	main.fadeIn = ok and fade or nil
	main:SetScript("OnShow", function()
		if main.fadeIn then main.fadeIn:Play() end
		PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_OPEN or 839)
	end)
	main:SetScript("OnHide", function()
		UI.HideMenu()
		PlaySound(SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_CLOSE or 840)
	end)
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
function OP:Hide() if main then main:Hide() end end
function OP:Open(tab)
	if not main then build() end
	main:Show()
	selectTab(tab or current or tabs[1].id)
end

UI.WIDTH, UI.HEIGHT = BODY_W, BODY_H - 28

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
			ns.print(ns.char.locked and "bars locked." or "bars unlocked — drag to move, right-click the icon again to lock.")
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
	local d = UI.Label(panel, "All settings are in Farseer's own window.")
	d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -8)
	local b = UI.Button(panel, "Open Farseer", 160, 26, function()
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
	GameTooltip:AddLine("Mode: " .. (mode == "PVP" and "|cffff6060PvP|r" or "|cff60ff60PvE|r"), 1, 1, 1)
	GameTooltip:AddLine(" ")
	GameTooltip:AddLine("Left-click: settings", 0.6, 0.8, 1)
	GameTooltip:AddLine("Right-click: unlock / lock bars", 0.6, 0.8, 1)
	GameTooltip:AddLine("Middle-click: toggle PvE/PvP", 0.6, 0.8, 1)
	GameTooltip:AddLine("Drag: move the icon", 0.6, 0.6, 0.6)
	GameTooltip:Show()
end

function Farseer_OnCompartmentLeave() GameTooltip:Hide() end

function OP:OnLogin()
	self:BuildMinimap()
	self:RegisterSettings()
	ns.listen("MODE_CHANGED", function() UI.RefreshCurrent() end)
end
