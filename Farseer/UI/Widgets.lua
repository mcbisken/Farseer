-- Byggstenar för inställningsfönstret: platta, mörka kontroller med shamanblå accent (UI\Theme.lua).
-- Samma API som tidigare (Button, Check, Stepper, Dropdown ...), så flikarna behöver inte ändras.

local _, ns = ...
local UI = {}
ns.UI = UI
local T = ns.Theme
local C = T.C

UI.GOLD = { 1, 0.82, 0 }
UI.BLUE = { 0, 0.44, 0.87 }
UI.ACCENT = C.accent
UI.Theme = T

local function tipOn(owner, title, tip)
	GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
	GameTooltip:SetText(title or "")
	if tip then GameTooltip:AddLine(tip, 1, 1, 1, true) end
	GameTooltip:Show()
end

function UI.Backdrop(f, alpha, edge)
	-- Rader i listor (alpha < 0,7) får panelfärgen, fönster den mörka bakgrunden
	local bg = (alpha and alpha < 0.7) and C.panel or C.bg
	T.Skin(f, bg, C.border, (alpha and alpha < 0.7) and 0.9 or (alpha or 0.96))
end

function UI.Box(parent, w, h)
	local f = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	f:SetSize(w, h)
	T.Skin(f, C.panel, C.border, 0.85)
	return f
end

function UI.Label(parent, text, font, color)
	local fs = parent:CreateFontString(nil, "OVERLAY", T.Map(font or "GameFontHighlight"))
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	if color then fs:SetTextColor(color[1], color[2], color[3]) end
	return fs
end

-- Rubrik: vit text med en blå linje under som tonar ut
function UI.Header(parent, text)
	local fs = parent:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontHeader"))
	fs:SetText(text or "")
	fs:SetJustifyH("LEFT")
	local line = parent:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -3)
	line:SetSize(220, 1)
	line:SetColorTexture(1, 1, 1, 1)
	if not T.Gradient(line, "HORIZONTAL", { C.accent[1], C.accent[2], C.accent[3], 0.9 }, { C.accent[1], C.accent[2], C.accent[3], 0 }) then
		line:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.6)
	end
	fs.line = line
	return fs
end

---------------------------------------------------------------------------------------------------
-- Knapp: platt, ljusare vid hover (HIGHLIGHT-lagret), blå vid LockHighlight (vald flik/knapp)
---------------------------------------------------------------------------------------------------
local function addHighlight(b)
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", -1, 1)
	hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.16)
	local edge = T.Border(b, { C.accent[1], C.accent[2], C.accent[3], 0.85 }, "HIGHLIGHT", 0)
	b.hlEdge = edge
	return hl
end

function UI.Button(parent, text, w, h, onClick, tip)
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w or 120, h or 22)
	T.Skin(b, C.panelHi, C.borderHi)
	-- Toning uppifrån (lite "lyft")
	local sheen = b:CreateTexture(nil, "BORDER")
	sheen:SetPoint("TOPLEFT", 1, -1)
	sheen:SetPoint("BOTTOMRIGHT", -1, 1)
	sheen:SetColorTexture(1, 1, 1, 1)
	if not T.Gradient(sheen, "VERTICAL", { 1, 1, 1, 0 }, { 1, 1, 1, 0.05 }) then sheen:Hide() end
	local fs = b:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontButton"))
	fs:SetPoint("CENTER", 0, 0)
	if b.SetFontString then b:SetFontString(fs) end
	pcall(b.SetNormalFontObject, b, T.Font("FarseerFontButton"))
	pcall(b.SetHighlightFontObject, b, T.Font("FarseerFontButton"))
	pcall(b.SetDisabledFontObject, b, T.Font("FarseerFontButtonOff"))
	pcall(b.SetPushedTextOffset, b, 1, -1)
	b:SetText(text)
	addHighlight(b)
	if onClick then
		b:SetScript("OnClick", function(self, ...)
			PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
			onClick(self, ...)
		end)
	end
	if tip then
		b:SetScript("OnEnter", function(self) tipOn(self, text, tip) end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	end
	return b
end

-- Liten ikonknapp (t.ex. stäng): bara symbol, färgad hover
function UI.IconButton(parent, size, symbol, onClick, hover)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(size, size)
	local fs = b:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontHeader"))
	fs:SetPoint("CENTER", 0, 1)
	fs:SetText(symbol)
	fs:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
	b.fs = fs
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	local c = hover or C.accent
	hl:SetColorTexture(c[1], c[2], c[3], 0.28)
	b:SetScript("OnEnter", function() fs:SetTextColor(1, 1, 1) end)
	b:SetScript("OnLeave", function() fs:SetTextColor(C.dim[1], C.dim[2], C.dim[3]) end)
	if onClick then b:SetScript("OnClick", onClick) end
	return b
end

---------------------------------------------------------------------------------------------------
-- Kryssruta: 16 px ruta med blå fyllning, hela texten är klickbar
---------------------------------------------------------------------------------------------------
function UI.Check(parent, label, get, set, tip)
	local cb = CreateFrame("CheckButton", nil, parent)
	cb:SetSize(24, 24)
	-- Rutan ritas med texturer på själva knappen: en egen barnram skulle hamna ovanpå bocken och hovern
	local box = cb:CreateTexture(nil, "BACKGROUND")
	box:SetSize(16, 16)
	box:SetPoint("LEFT", 4, 0)
	box:SetColorTexture(C.input[1], C.input[2], C.input[3], 1)
	cb.box = box
	local edges = {}
	for i = 1, 4 do
		local e = cb:CreateTexture(nil, "BORDER")
		e:SetColorTexture(C.borderHi[1], C.borderHi[2], C.borderHi[3], 1)
		edges[i] = e
	end
	edges[1]:SetPoint("TOPLEFT", box, "TOPLEFT"); edges[1]:SetPoint("TOPRIGHT", box, "TOPRIGHT"); edges[1]:SetHeight(1)
	edges[2]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT"); edges[2]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT"); edges[2]:SetHeight(1)
	edges[3]:SetPoint("TOPLEFT", box, "TOPLEFT"); edges[3]:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT"); edges[3]:SetWidth(1)
	edges[4]:SetPoint("TOPRIGHT", box, "TOPRIGHT"); edges[4]:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT"); edges[4]:SetWidth(1)
	cb.edges = edges
	local ck = cb:CreateTexture(nil, "OVERLAY")
	ck:SetPoint("TOPLEFT", box, "TOPLEFT", 3, -3)
	ck:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	ck:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
	cb:SetCheckedTexture(ck)
	local hl = cb:CreateTexture(nil, "HIGHLIGHT")
	hl:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
	hl:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
	hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.25)
	local fs = UI.Label(cb, label)
	fs:SetPoint("LEFT", box, "RIGHT", 7, 0)
	cb.label = fs
	-- Texten är en del av knappen
	local w = (fs.GetStringWidth and tonumber(fs:GetStringWidth())) or 0
	if w <= 0 then w = 200 end
	pcall(cb.SetHitRectInsets, cb, 0, -(w + 10), 0, 0)
	cb:SetScript("OnClick", function(self)
		set(self:GetChecked() and true or false)
		PlaySound(SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or 856)
	end)
	cb.Refresh = function(self) self:SetChecked(get() and true or false) end
	cb:SetScript("OnEnter", function(self)
		fs:SetTextColor(1, 1, 1)
		if tip then tipOn(self, label, tip) end
	end)
	cb:SetScript("OnLeave", function()
		fs:SetTextColor(C.text[1], C.text[2], C.text[3])
		GameTooltip:Hide()
	end)
	cb:Refresh()
	return cb
end

---------------------------------------------------------------------------------------------------
-- Textfält
---------------------------------------------------------------------------------------------------
local function focusEdge(e, frame)
	local f = frame or e
	e:HookScript("OnEditFocusGained", function() pcall(f.SetBackdropBorderColor, f, C.accent[1], C.accent[2], C.accent[3], 1) end)
	e:HookScript("OnEditFocusLost", function() pcall(f.SetBackdropBorderColor, f, C.borderHi[1], C.borderHi[2], C.borderHi[3], 1) end)
end

function UI.EditBox(parent, w, onEnter)
	local e = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	e:SetSize(w or 160, 22)
	T.Skin(e, C.input, C.borderHi)
	e:SetFontObject(T.Font("FarseerFontBody"))
	pcall(e.SetTextInsets, e, 7, 7, 0, 0)
	e:SetAutoFocus(false)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self)
		if onEnter then onEnter(self, self:GetText()) end
		self:ClearFocus()
	end)
	focusEdge(e)
	return e
end

-- Smal rullningslist: pilarna bort, en tunn tumme
local function skinScrollBar(sf)
	local bar = sf.ScrollBar or (sf.GetName and sf:GetName() and _G[sf:GetName() .. "ScrollBar"])
	if type(bar) ~= "table" then return end
	for _, k in ipairs({ "ScrollUpButton", "ScrollDownButton", "Back", "Forward" }) do
		local x = bar[k]
		if type(x) == "table" then pcall(x.SetAlpha, x, 0); pcall(x.EnableMouse, x, false) end
	end
	pcall(function()
		local thumb = bar.ThumbTexture or (bar.GetThumbTexture and bar:GetThumbTexture())
		if thumb and thumb.SetColorTexture then
			thumb:SetColorTexture(C.borderHi[1], C.borderHi[2], C.borderHi[3], 1)
			thumb:SetWidth(5)
		end
		local track = bar:CreateTexture(nil, "BACKGROUND")
		track:SetPoint("TOP", 0, 0)
		track:SetPoint("BOTTOM", 0, 0)
		track:SetWidth(5)
		track:SetColorTexture(0, 0, 0, 0.35)
	end)
end
UI.SkinScrollBar = skinScrollBar

-- Rullbar yta. Returnerar scrollFrame, content (sätt content:SetHeight själv)
function UI.Scroll(parent, w, h)
	local sf = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	sf:SetSize(w, h)
	local content = CreateFrame("Frame", nil, sf)
	content:SetSize(w, 10)
	sf:SetScrollChild(content)
	skinScrollBar(sf)
	return sf, content
end

-- Flerradig textruta med rullning
function UI.MultiLine(parent, w, h, onChange)
	local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetSize(w, h)
	T.Skin(box, C.input, C.borderHi)
	local sf = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 7, -7)
	sf:SetPoint("BOTTOMRIGHT", -26, 7)
	skinScrollBar(sf)
	local e = CreateFrame("EditBox", nil, sf)
	e:SetMultiLine(true)
	e:SetAutoFocus(false)
	e:SetFontObject(T.fonts.FarseerFontSmall and "FarseerFontSmall" or ChatFontNormal)
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
	focusEdge(e, box)
	box:EnableMouse(true)
	box:SetScript("OnMouseDown", function() e:SetFocus() end)
	box.edit = e
	return box, e
end

---------------------------------------------------------------------------------------------------
-- Stegare: Etikett   [ – ]  värde  [ + ]
---------------------------------------------------------------------------------------------------
function UI.Stepper(parent, label, min, max, step, get, set, fmt)
	local f = CreateFrame("Frame", nil, parent)
	f:SetSize(260, 24)
	local l = UI.Label(f, label)
	l:SetPoint("LEFT", 0, 0)
	l:SetWidth(150)
	local pill = CreateFrame("Frame", nil, f, "BackdropTemplate")
	pill:SetSize(96, 22)
	pill:SetPoint("LEFT", l, "RIGHT", 4, 0)
	T.Skin(pill, C.input, C.borderHi)
	local minus = UI.Button(pill, "–", 22, 22)
	minus:SetPoint("LEFT", 0, 0)
	local plus = UI.Button(pill, "+", 22, 22)
	plus:SetPoint("RIGHT", 0, 0)
	local v = UI.Label(pill, "", "GameFontHighlight")
	v:SetPoint("LEFT", minus, "RIGHT", 0, 0)
	v:SetPoint("RIGHT", plus, "LEFT", 0, 0)
	v:SetJustifyH("CENTER")
	v:SetTextColor(C.accent[1] * 0.4 + 0.6, C.accent[2] * 0.4 + 0.6, 1)
	local function show() v:SetText(string.format(fmt or "%s", get())) end
	local function change(d)
		local n = math.min(max, math.max(min, (get() or min) + d))
		n = math.floor(n / step + 0.5) * step
		set(n)
		show()
	end
	minus:SetScript("OnClick", function() change(-step) end)
	plus:SetScript("OnClick", function() change(step) end)
	-- Mushjulet över värdet ändrar också
	pcall(pill.EnableMouseWheel, pill, true)
	pill:SetScript("OnMouseWheel", function(_, delta) change(delta > 0 and step or -step) end)
	f.Refresh = show
	f.minus, f.plus, f.value = minus, plus, v
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
		menu = CreateFrame("Frame", "FarseerMenu", UIParent, "BackdropTemplate")
		menu:SetFrameStrata("FULLSCREEN_DIALOG")
		menu:SetClampedToScreen(true)
		T.Skin(menu, C.side, C.borderHi, 0.98)
		T.Shadow(menu, 4)
		menu.rows = {}
		menu:EnableMouse(true)
		menu:SetScript("OnHide", function(self) self.anchor = nil end)
		local closer = CreateFrame("Button", nil, menu)
		closer:SetAllPoints(UIParent)
		closer:SetFrameStrata("FULLSCREEN")
		closer:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		closer:SetScript("OnClick", hideMenu)
		menu.closer = closer
		closer:SetParent(menu)
		closer:SetFrameStrata("FULLSCREEN")
		-- ESC stänger menyn (och den ska inte bli kvar när fönstret stängs)
		if UISpecialFrames then table.insert(UISpecialFrames, "FarseerMenu") end
	end
	if menu:IsShown() and menu.anchor == anchor then hideMenu() return end
	for _, r in ipairs(menu.rows) do r:Hide() end
	local rowH, width = 22, 196
	local maxRows = 24
	local cols = math.ceil(#items / maxRows)
	for i, it in ipairs(items) do
		local r = menu.rows[i]
		if not r then
			r = CreateFrame("Button", nil, menu)
			r:SetHeight(rowH)
			r.hl = r:CreateTexture(nil, "HIGHLIGHT")
			r.hl:SetAllPoints()
			r.hl:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 0.22)
			r.bar = r:CreateTexture(nil, "HIGHLIGHT")
			r.bar:SetPoint("TOPLEFT")
			r.bar:SetPoint("BOTTOMLEFT")
			r.bar:SetWidth(2)
			r.bar:SetColorTexture(C.accent[1], C.accent[2], C.accent[3], 1)
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(16, 16)
			r.icon:SetPoint("LEFT", 6, 0)
			r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			r.text = r:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontSmall"))
			r.text:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
			r.text:SetPoint("RIGHT", r, "RIGHT", -6, 0)
			r.text:SetJustifyH("LEFT")
			if r.text.SetWordWrap then r.text:SetWordWrap(false) end
			r.sep = r:CreateTexture(nil, "ARTWORK")
			r.sep:SetPoint("BOTTOMLEFT", 6, 2)
			r.sep:SetPoint("BOTTOMRIGHT", -6, 2)
			r.sep:SetHeight(1)
			r.sep:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)
			menu.rows[i] = r
		end
		local col, row = math.floor((i - 1) / maxRows), (i - 1) % maxRows
		r:SetWidth(width)
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", menu, "TOPLEFT", 4 + col * (width + 2), -4 - row * rowH)
		r.icon:SetTexture(it.icon)
		r.icon:SetShown(it.icon ~= nil)
		r.text:ClearAllPoints()
		r.text:SetPoint("LEFT", r, "LEFT", it.icon and 28 or 10, 0)
		r.text:SetPoint("RIGHT", r, "RIGHT", -6, 0)
		r.text:SetText(it.header and string.upper(it.text or "") or it.text)
		local c = it.header and { 0.45, 0.7, 1 } or it.color or C.text
		r.text:SetTextColor(c[1], c[2], c[3])
		r.sep:SetShown(it.header and true or false)
		r:SetEnabled(not it.disabled and not it.header)
		r.text:SetAlpha(it.disabled and 0.45 or 1)
		r:SetScript("OnClick", function()
			hideMenu()
			PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
			if onPick then onPick(it.value, it) end
		end)
		r:Show()
	end
	local rows = math.min(#items, maxRows)
	menu:SetSize(8 + cols * (width + 2) - 2, 8 + rows * rowH)
	menu:ClearAllPoints()
	menu:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -2)
	menu.anchor = anchor
	menu:Show()
end

-- Knapp som öppnar en meny och visar valt värde (text till vänster, pil till höger)
function UI.Dropdown(parent, w, getText, getItems, onPick)
	local b = UI.Button(parent, "", w, 22)
	T.Skin(b, C.input, C.borderHi)
	b:SetScript("OnClick", function(self)
		PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115)
		UI.Menu(self, getItems(), function(v, it) onPick(v, it); self:Refresh() end)
	end)
	local fs = b.GetFontString and b:GetFontString()
	if fs then
		fs:ClearAllPoints()
		fs:SetPoint("LEFT", 8, 0)
		fs:SetPoint("RIGHT", -20, 0)
		fs:SetJustifyH("LEFT")
		if fs.SetWordWrap then fs:SetWordWrap(false) end
	end
	local arrow = b:CreateTexture(nil, "OVERLAY")
	arrow:SetSize(12, 12)
	arrow:SetPoint("RIGHT", -6, 0)
	arrow:SetTexture("Interface\\Buttons\\Arrow-Down-Up")
	arrow:SetVertexColor(C.accent[1] * 0.5 + 0.5, C.accent[2] * 0.5 + 0.5, 1)
	b.arrow = arrow
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
