-- Första gången: ett litet fönster med fyra frågor (spec, keybinds, varningar, utseende).
-- Inget ändras förrän man trycker Finish. Visas en gång för nya karaktärer, annars /farseer setup.

local _, ns = ...
local SU = ns.module("Setup")

local SPECS = {
	{ id = "elemental", name = "Elemental", cat = "Elemental", preset = "elemental",
		icon = "Interface\\Icons\\Spell_Nature_Lightning" },
	{ id = "enhancement", name = "Enhancement", cat = "Enhancement", preset = "enhancement",
		icon = "Interface\\Icons\\Spell_Nature_LightningShield" },
	{ id = "restoration", name = "Restoration", cat = "Restoration", preset = "restoration",
		icon = "Interface\\Icons\\Spell_Nature_MagicImmunity" },
}
SU.SPECS = SPECS

local BINDS = {
	{ id = "plain", name = "Bind the layout on normal keys", mod = "", keep = false,
		desc = "Uses the spec's layout as it is. Keys you had are saved and can be restored." },
	{ id = "shift", name = "Bind it on Shift + key", mod = "SHIFT", keep = false,
		desc = "Your normal keys stay as they are; Farseer goes on Shift." },
	{ id = "free", name = "Only use keys that are free", mod = "", keep = true,
		desc = "Never replaces a key that already does something." },
	{ id = "none", name = "Don't touch my keybinds",
		desc = "You can bind later on the Keybinds tab or with /farseer kb." },
}
local ALERTS = {
	{ id = "always", name = "Always" },
	{ id = "group", name = "In a group" },
	{ id = "instance", name = "Only in dungeons and raids" },
	{ id = "off", name = "Never" },
}
local SPEAK = { { id = "off", name = "No" }, { id = "critical", name = "Critical only" }, { id = "advice", name = "Advice and critical" } }

local win, choice
local STEPS = 4
local step = 1

-- Förval: det som redan gäller (spec gissas från talangerna)
function SU:Defaults()
	local spec = ns.Spec and ns.Spec:Detect()
	if spec ~= "elemental" and spec ~= "enhancement" and spec ~= "restoration" then spec = "elemental" end
	return {
		spec = spec, binds = "none", macros = true,
		alert = ns.db.alert.mode or "always", speak = ns.db.alert.speak or "off",
		classic = ns.db.classicUI == true,
	}
end

local function specById(id)
	for _, s in ipairs(SPECS) do if s.id == id then return s end end
	return SPECS[1]
end
local function byId(list, id)
	for _, x in ipairs(list) do if x.id == id then return x end end
end

-- Lägg på valen. Returnerar raderna som skrivs ut (och används av testerna).
function SU:Apply(c)
	local out = {}
	if InCombatLockdown() then
		table.insert(out, "can't finish setup in combat.")
		return false, out
	end
	local s = specById(c.spec)
	ns.char.bisSpec = s.id
	if c.macros then
		for _, cat in ipairs({ s.cat, "Totems", "PvP", "Utility" }) do ns.MacroEngine:CreateCategory(cat) end
	end
	local b = byId(BINDS, c.binds)
	if b and b.id ~= "none" then
		local opts = ns.BindingEngine:Options()
		opts.mod, opts.keep = b.mod, b.keep
		local n, errors, kept = ns.BindingEngine:Apply(s.preset, opts)
		table.insert(out, string.format("%s keybinds: %d set%s.%s", s.name, n or 0,
			(kept or 0) > 0 and (", " .. kept .. " kept") or "",
			errors and #errors > 0 and (" Errors: " .. table.concat(errors, "; ")) or ""))
	end
	ns.db.alert.mode = c.alert
	ns.db.alert.speak = c.speak
	local wasClassic = ns.db.classicUI == true
	ns.db.classicUI = c.classic == true
	ns.char.setupDone = true
	if wasClassic ~= ns.db.classicUI then table.insert(out, "type /reload to switch the look.") end
	table.insert(out, "setup done. Everything can be changed later in /farseer.")
	ns.fire("BARS_LAYOUT")
	if ns.UI and ns.UI.RefreshCurrent then ns.UI.RefreshCurrent() end
	return true, out
end

---------------------------------------------------------------------------------------------------
-- Fönstret
---------------------------------------------------------------------------------------------------
local function option(parent, w, text, desc, icon, onClick)
	local UI, T = ns.UI, ns.Theme
	local C = T.C
	local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
	b:SetSize(w, desc and 42 or 30)
	T.Skin(b, C.panel, C.border, 1)
	b.edge = T.Border(b, C.accent, "OVERLAY", 0)
	b.edge:SetShown(false)
	local x = 12
	if icon then
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetSize(24, 24)
		b.icon:SetPoint("LEFT", 10, 0)
		b.icon:SetTexture(icon)
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		x = 44
	end
	b.text = b:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontStrong"))
	b.text:SetPoint(desc and "TOPLEFT" or "LEFT", x, desc and -7 or 0)
	b.text:SetText(text)
	if desc then
		b.desc = b:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontDim"))
		b.desc:SetPoint("TOPLEFT", b.text, "BOTTOMLEFT", 0, -3)
		b.desc:SetPoint("RIGHT", b, "RIGHT", -10, 0)
		b.desc:SetJustifyH("LEFT")
		b.desc:SetText(desc)
	end
	local hl = b:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 1, 1, 0.04)
	b:SetScript("OnClick", function() PlaySound(SOUNDKIT and SOUNDKIT.U_CHAT_SCROLL_BUTTON or 1115); onClick() end)
	function b:SetSelected(on)
		self.edge:SetShown(on)
		local c = on and C.accent or C.border
		if self.SetBackdropBorderColor then self:SetBackdropBorderColor(c[1], c[2], c[3], 1) end
		local t = on and { 1, 1, 1 } or C.text
		self.text:SetTextColor(t[1], t[2], t[3])
	end
	return b
end

local pages = {}

local function paint()
	for i, pg in ipairs(pages) do
		pg:SetShown(i == step)
		if i == step and pg.paint then pg.paint() end
	end
	win.stepText:SetText(string.format("Step %d of %d", step, STEPS))
	for i, d in ipairs(win.dots) do
		local c = i <= step and ns.Theme.C.accent or ns.Theme.C.borderHi
		d:SetColorTexture(c[1], c[2], c[3], 1)
	end
	win.back:SetShown(step > 1)
	win.next.label = step == STEPS and "Finish" or "Next"
	if win.next.SetText then win.next:SetText(win.next.label) end
end

local function page(title, sub)
	local UI = ns.UI
	local p = CreateFrame("Frame", nil, win)
	p:SetPoint("TOPLEFT", 24, -78)
	p:SetPoint("BOTTOMRIGHT", -24, 56)
	local h = UI.Header(p, title)
	h:SetPoint("TOPLEFT", 0, 0)
	local s = UI.Label(p, sub, "GameFontDisableSmall")
	s:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
	s:SetWidth(460)
	p.top = s
	table.insert(pages, p)
	return p
end

-- En grupp knappar där en är vald: list = { {id, name, desc?, icon?} }, key = fältet i choice
local function choices(p, anchor, list, key, w, gap)
	local btns = {}
	local last = anchor
	for i, it in ipairs(list) do
		local b = option(p, w or 460, it.name, it.desc, it.icon, function()
			choice[key] = it.id
			for _, x in ipairs(btns) do x:SetSelected(x.id == choice[key]) end
		end)
		b.id = it.id
		b:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, i == 1 and -12 or -(gap or 6))
		btns[i] = b
		last = b
	end
	local function paintAll() for _, x in ipairs(btns) do x:SetSelected(x.id == choice[key]) end end
	return last, paintAll
end

function SU:Build()
	local UI, T = ns.UI, ns.Theme
	local C = T.C
	win = CreateFrame("Frame", "FarseerSetup", UIParent, "BackdropTemplate")
	win:SetSize(520, 470)
	win:SetPoint("CENTER", 0, 40)
	win:SetFrameStrata("DIALOG")
	win:SetToplevel(true)
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	T.Skin(win, C.bg, C.border, 0.98)
	T.Shadow(win, 8)
	table.insert(UISpecialFrames, "FarseerSetup")

	local icon = win:CreateTexture(nil, "ARTWORK")
	icon:SetSize(30, 30)
	icon:SetPoint("TOPLEFT", 22, -18)
	icon:SetTexture("Interface\\Icons\\Spell_Nature_BloodLust")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	local title = win:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontTitle"))
	title:SetPoint("TOPLEFT", icon, "TOPRIGHT", 12, 0)
	title:SetText("Welcome to Farseer")
	win.stepText = win:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontDim"))
	win.stepText:SetPoint("BOTTOMLEFT", icon, "BOTTOMRIGHT", 12, 0)
	win.dots = {}
	for i = 1, STEPS do
		local d = win:CreateTexture(nil, "ARTWORK")
		d:SetSize(22, 3)
		d:SetPoint("TOPRIGHT", win, "TOPRIGHT", -24 - (STEPS - i) * 26, -34)
		win.dots[i] = d
	end
	local line = win:CreateTexture(nil, "ARTWORK")
	line:SetPoint("TOPLEFT", 1, -64)
	line:SetPoint("TOPRIGHT", -1, -64)
	line:SetHeight(1)
	line:SetColorTexture(C.border[1], C.border[2], C.border[3], 1)

	-- 1: spec
	local p1 = page("Which spec do you play?", "Picks the macros, keybind layout and BiS list. Farseer also follows talent changes later.")
	local _, paint1 = choices(p1, p1.top, SPECS, "spec", 460, 8)
	local mac = UI.Check(p1, "Create the macros for this spec (and Totems, PvP, Utility)",
		function() return choice.macros end, function(v) choice.macros = v end)
	mac:SetPoint("BOTTOMLEFT", p1, "BOTTOMLEFT", -4, 0)
	p1.paint = function() paint1(); if mac.Refresh then mac:Refresh() end end
	-- 2: keybinds
	local p2 = page("Keybinds", "Farseer has a ready-made key layout per spec. Whatever you choose, \"Restore all keys\" on the Keybinds tab undoes it.")
	local _, paint2 = choices(p2, p2.top, BINDS, "binds")
	p2.paint = paint2
	-- 3: varningar
	local p3 = page("Alerts", "Big alerts in the middle of the screen: missing shield or imbue, totems out of range, Tremor/Grounding when needed.")
	local l3, paint3a = choices(p3, p3.top, ALERTS, "alert", 225, 4)
	local sl = UI.Label(p3, "Read critical alerts aloud?", "GameFontNormal")
	sl:SetPoint("TOPLEFT", l3, "BOTTOMLEFT", 0, -16)
	local _, paint3b = choices(p3, sl, SPEAK, "speak", 225, 4)
	p3.paint = function() paint3a(); paint3b() end
	-- 4: utseende
	local p4 = page("Look", "The Farseer look is flat and dark. Classic uses Blizzard's own buttons and fonts. Switching needs a /reload.")
	local _, paint4 = choices(p4, p4.top, {
		{ id = false, name = "Farseer (modern)", desc = "Dark panels, blue accent, thin black borders on your buttons." },
		{ id = true, name = "Classic", desc = "Blizzard-style controls and fonts. Pick this if something looks broken." },
	}, "classic", 460, 8)
	p4.paint = paint4

	win.back = UI.Button(win, "Back", 90, 26, function() step = math.max(1, step - 1); paint() end)
	win.back:SetPoint("BOTTOMLEFT", 22, 16)
	win.next = UI.Button(win, "Next", 110, 26, function()
		if step < STEPS then
			step = step + 1
			paint()
			return
		end
		local ok, lines = SU:Apply(choice)
		for _, l in ipairs(lines) do ns.print(l) end
		if ok then win:Hide() end
	end)
	win.next:SetPoint("BOTTOMRIGHT", -22, 16)
	local skip = UI.Button(win, "Skip", 80, 26, function()
		ns.char.setupDone = true
		win:Hide()
		ns.print("setup skipped. /farseer setup brings it back.")
	end, "Close without changing anything.")
	skip:SetPoint("RIGHT", win.next, "LEFT", -8, 0)
	win:Hide()
end

function SU:Show()
	if InCombatLockdown() then ns.print("setup opens after combat.") return end
	choice = self:Defaults()
	if not win then self:Build() end
	step = 1
	win:Show()
	paint()
end
function SU:Shown() return win ~= nil and win:IsShown() end
function SU:Choice() return choice end
function SU:Step(n) if n then step = n; paint() end return step end

-- Nya karaktärer: visa en gång, några sekunder efter inloggning och utanför strid
function SU:OnShamanLogin()
	if ns.char.setupDone or not ns.freshChar then return end
	C_Timer.After(4, function()
		if ns.char.setupDone then return end
		if InCombatLockdown() then
			ns.afterCombat("setup", function() SU:Show() end)
		else
			SU:Show()
		end
	end)
end
