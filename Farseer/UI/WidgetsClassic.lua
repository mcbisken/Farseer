-- Klassiskt utseende (Blizzards egna templates, som före v2.0). Används när "Classic look" är på
-- (ns.db.classicUI, kräver /reload): varje kontroll i UI\Widgets.lua lämnar då över hit.

local _, ns = ...
local UI = {}
local NEW = ns.UI

UI.GOLD = { 1, 0.82, 0 }
UI.BLUE = { 0, 0.44, 0.87 }

function UI.Backdrop(f, alpha, edge)
	if not f.SetBackdrop then Mixin(f, BackdropTemplateMixin) end
	f:SetBackdrop({
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	f:SetBackdropColor(0.05, 0.06, 0.09, alpha or 0.92)
	local e = edge or { 0.2, 0.32, 0.5 }
	f:SetBackdropBorderColor(e[1], e[2], e[3], 1)
end

function UI.Box(parent, w, h)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(w, h)
	UI.Backdrop(f, 0.6, { 0.16, 0.2, 0.28 })
	return f
end

function UI.Label(parent, text, font, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	if color then fs:SetTextColor(color[1], color[2], color[3]) end
	return fs
end

function UI.Header(parent, text)
	return UI.Label(parent, text, "GameFontNormalLarge", UI.GOLD)
end

function UI.Button(parent, text, w, h, onClick, tip)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(w or 120, h or 22)
	b:SetText(text)
	if onClick then b:SetScript("OnClick", function(self, ...) onClick(self, ...) end) end
	if tip then
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(text)
			GameTooltip:AddLine(tip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	return b
end

-- get() -> bool, set(bool)
function UI.Check(parent, label, get, set, tip)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	local fs = UI.Label(cb, label)
	fs:SetPoint("LEFT", cb, "RIGHT", 2, 1)
	cb.label = fs
	if cb.Text then cb.Text:SetText("") end
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	end)
	cb.Refresh = function(self) self:SetChecked(get() and true or false) end
	if tip then
		cb:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			GameTooltip:SetText(label)
			GameTooltip:AddLine(tip, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	cb:Refresh()
	return cb
end

function UI.EditBox(parent, w, onEnter)
	local e = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	e:SetSize(w or 160, 20)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self)
		if onEnter then onEnter(self, self:GetText()) end
		self:ClearFocus()
	end)
	return e
end

-- Rullbar yta. Returnerar scrollFrame, content (sätt content:SetHeight själv)
function UI.Scroll(parent, w, h)
	local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	sf:SetSize(w, h)
	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(w, 10)
	sf:SetScrollChild(content)
	return sf, content
end

-- Flerradig textruta med rullning
function UI.MultiLine(parent, w, h, onChange)
	local box = UI.Box(parent, w, h)
	local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 6, -6)
	sf:SetPoint("BOTTOMRIGHT", -26, 6)
	local e = CreateFrame("EditBox", nil, sf)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetFontObject(ChatFontNormal)
	e:SetWidth(w - 36)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnTextChanged", function(self, user)
		if ScrollingEdit_OnTextChanged then ScrollingEdit_OnTextChanged(self, sf) end
		if onChange then onChange(self:GetText(), user) end
	end)
	-- Rulla med markören när texten blir längre än rutan
	if ScrollingEdit_OnCursorChanged then
		e:SetScript("OnCursorChanged", ScrollingEdit_OnCursorChanged)
		e:SetScript("OnUpdate", function(self, elapsed) ScrollingEdit_OnUpdate(self, elapsed, sf) end)
	end
	sf:SetScrollChild(e)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() e:SetFocus() end)
	box.edit = e
	return box, e
end

-- Stegare: [-] värde [+]
function UI.Stepper(parent, label, min, max, step, get, set, fmt)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(260, 24)
	local l = UI.Label(f, label)
	l:SetPoint("LEFT", 0, 0)
	l:SetWidth(150)
	local minus = UI.Button(f, "-", 24, 20)
	minus:SetPoint("LEFT", l, "RIGHT", 4, 0)
	local v = UI.Label(f, "", "GameFontHighlight")
	v:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	v:SetWidth(44)
	v:SetJustifyH("CENTER")
	local plus = UI.Button(f, "+", 24, 20)
	plus:SetPoint("LEFT", v, "RIGHT", 4, 0)
	local function show() v:SetText(string.format(fmt or "%s", get())) end
	local function change(d)
		local n = math.min(max, math.max(min, (get() or min) + d))
		n = math.floor(n / step + 0.5) * step
		set(n)
		show()
	end
	minus:SetScript("OnClick", function() change(-step) end)
	plus:SetScript("OnClick", function() change(step) end)
	f.Refresh = show
	show()
	return f
end

---------------------------------------------------------------------------------------------------
-- Popupmeny: items = { { text, value, icon, color, disabled, header } }
---------------------------------------------------------------------------------------------------
local menu
local function hideMenu() if menu then menu:Hide() end end
UI.HideMenu = hideMenu

function UI.Menu(anchor, items, onPick)
	if not menu then
		menu = CreateFrame("Frame", "FarseerMenuClassic", UIParent, "BackdropTemplate")
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:SetClampedToScreen(true)
		UI.Backdrop(menu, 0.97, { 0.3, 0.45, 0.7 })
		menu.rows = {}
		menu:EnableMouse(true)
		menu:SetScript("OnShow", function() if NEW.HoldEscape then NEW.HoldEscape(true) end end)
		menu:SetScript("OnHide", function(self) self.anchor = nil; if NEW.HoldEscape then NEW.HoldEscape(false) end end)
		local closer = CreateFrame("Button", nil, menu)
		closer:SetAllPoints(UIParent)
		closer:SetFrameStrata("FULLSCREEN")
		closer:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		closer:SetScript("OnClick", hideMenu)
		menu.closer = closer
		closer:SetParent(menu)
		closer:SetFrameStrata("FULLSCREEN")
		-- ESC stänger menyn (och den ska inte bli kvar när fönstret stängs)
		if UISpecialFrames then table.insert(UISpecialFrames, "FarseerMenuClassic") end
	end
	if menu:IsShown() and menu.anchor == anchor then hideMenu() return end
	for _, r in ipairs(menu.rows) do r:Hide() end
	local rowH, width = 18, 180
	local maxRows = 26
	local cols = math.ceil(#items / maxRows)
	for i, it in ipairs(items) do
		local r = menu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, menu)
			r:SetHeight(rowH)
			r.hl = r:CreateTexture(nil, "HIGHLIGHT")
			r.hl:SetAllPoints()
			r.hl:SetColorTexture(0.3, 0.5, 0.9, 0.35)
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(16, 16)
			r.icon:SetPoint("LEFT", 2, 0)
			r.text = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
			r.text:SetJustifyH("LEFT")
			menu.rows[i] = r
		end
		local col, row = math.floor((i - 1) / maxRows), (i - 1) % maxRows
		r:SetWidth(width)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", menu, "TOPLEFT", 6 + col * (width + 4), -6 - row * rowH)
		r.icon:SetTexture(it.icon)
		r.icon:SetShown(it.icon ~= nil)
		r.text:SetText(it.text)
		local c = it.header and UI.GOLD or it.color or { 1, 1, 1 }
		r.text:SetTextColor(c[1], c[2], c[3])
		r:SetEnabled(not it.disabled and not it.header)
		r.text:SetAlpha(it.disabled and 0.45 or 1)
		r:SetScript("OnClick", function()
			hideMenu()
			if onPick then onPick(it.value, it) end
		end)
		r:Show()
	end
	local rows = math.min(#items, maxRows)
	menu:SetSize(12 + cols * (width + 4) - 4, 12 + rows * rowH)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu.anchor = anchor
	menu:Show()
end

-- Knapp som öppnar en meny och visar valt värde
function UI.Dropdown(parent, w, getText, getItems, onPick)
	local b = UI.Button(parent, "", w, 22)
	b:SetScript("OnClick", function(self) UI.Menu(self, getItems(), function(v, it) onPick(v, it); self:Refresh() end) end)
	local fs = b.GetFontString and b:GetFontString()
	if fs then
		fs:SetWidth(w - 12)
		if fs.SetWordWrap then fs:SetWordWrap(false) end
	end
	function b:Refresh()
		self:SetText(getText() or "-")
	end
	b:Refresh()
	return b
end

---------------------------------------------------------------------------------------------------
-- Bekräftelse
---------------------------------------------------------------------------------------------------
function UI.Confirm(text, onYes)
	StaticPopupDialogs.FARSEER_CONFIRM = {
		text = (tostring(text):gsub("%%", "%%%%")), -- texten formateras av StaticPopup: "%" i namn får inte tolkas
		button1 = YES or "Yes",
		button2 = NO or "No",
		OnAccept = function() onYes() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("FARSEER_CONFIRM")
end

-- Text som kan kopieras (t.ex. en länk)
function UI.CopyBox(text)
	StaticPopupDialogs.FARSEER_COPY = {
		text = "Press Ctrl+C to copy:",
		button1 = CLOSE or "Close",
		hasEditBox = true,
		editBoxWidth = 320,
		OnShow = function(self)
			local e = self.editBox or self.EditBox
			if e then e:SetText(text); e:HighlightText(); e:SetFocus() end
		end,
		EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
	}
	StaticPopup_Show("FARSEER_COPY")
end

---------------------------------------------------------------------------------------------------
-- Koppla in: den nya kontrollen används om inte klassiskt utseende är valt
---------------------------------------------------------------------------------------------------
UI.GOLD, UI.BLUE = NEW.GOLD, NEW.BLUE
NEW.Classic = UI
for _, name in ipairs({ "Backdrop", "Box", "Label", "Header", "Button", "Check", "EditBox", "Scroll", "MultiLine",
	"Stepper", "Menu", "Dropdown", "HideMenu" }) do
	local modern, classic = NEW[name], UI[name]
	if modern and classic then
		NEW[name] = function(...)
			if ns.Theme.Classic() then return classic(...) end
			return modern(...)
		end
	end
end
