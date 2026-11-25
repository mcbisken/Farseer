-- Utseende: färger, typsnitt och skal (pixelramar, ikoner, statusbarer) för hela Farseer.
-- Laddas direkt efter Core så att alla moduler kan använda ns.Theme när de bygger sina ramar.

local _, ns = ...
local T = {}
ns.Theme = T

---------------------------------------------------------------------------------------------------
-- Färger (mörk skiffer med shamanblå accent)
---------------------------------------------------------------------------------------------------
T.C = {
	bg        = { 0.035, 0.043, 0.060 },   -- fönstret
	side      = { 0.047, 0.057, 0.078 },   -- sidomenyn
	panel     = { 0.063, 0.077, 0.104 },   -- rutor
	panelHi   = { 0.085, 0.103, 0.138 },   -- knappar
	input     = { 0.028, 0.034, 0.048 },   -- textfält, kryssrutor
	border    = { 0.125, 0.152, 0.200 },
	borderHi  = { 0.200, 0.245, 0.320 },
	accent    = { 0.000, 0.560, 1.000 },   -- shamanblå
	accentDim = { 0.000, 0.300, 0.560 },
	text      = { 0.900, 0.920, 0.950 },
	dim       = { 0.540, 0.590, 0.670 },
	gold      = { 1.000, 0.820, 0.300 },
	good      = { 0.300, 0.900, 0.450 },
	bad       = { 1.000, 0.330, 0.330 },
	black     = { 0, 0, 0 },
}
local C = T.C

---------------------------------------------------------------------------------------------------
-- Typsnitt: Arial Narrow för text (rent och kompakt), Friz för rubriker. Andra språk: spelets eget.
---------------------------------------------------------------------------------------------------
local WESTERN = { enUS = true, enGB = true, deDE = true, frFR = true, esES = true, esMX = true, itIT = true, ptBR = true }
local function locale() local ok, l = pcall(GetLocale) return ok and l or "enUS" end
local BODY = WESTERN[locale()] and "Fonts\\ARIALN.TTF" or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
local HEAD = WESTERN[locale()] and "Fonts\\FRIZQT__.TTF" or (STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF")
T.BODY, T.HEAD = BODY, HEAD

-- name, fil, storlek, flaggor, färg, skugga
local FONTS = {
	{ "FarseerFontTitle",   HEAD, 19, "",        C.text },
	{ "FarseerFontHeader",  HEAD, 13, "",        C.text },
	{ "FarseerFontStrong",  HEAD, 12, "",        C.text },
	{ "FarseerFontBody",    BODY, 14, "",        C.text },
	{ "FarseerFontSmall",   BODY, 13, "",        C.text },
	{ "FarseerFontDim",     BODY, 13, "",        C.dim },
	{ "FarseerFontAccent",  BODY, 14, "",        { 0.35, 0.75, 1 } },
	{ "FarseerFontGold",    BODY, 14, "",        C.gold },
	{ "FarseerFontButton",  BODY, 14, "",        C.text },
	{ "FarseerFontButtonOff", BODY, 14, "",      { 0.4, 0.43, 0.48 } },
	{ "FarseerFontTab",     BODY, 14, "",        C.dim },
	{ "FarseerFontGroup",   BODY, 11, "",        { 0.36, 0.42, 0.52 } },
	-- I spelet: kontur så att siffror syns på ikoner
	{ "FarseerFontKey",     BODY, 11, "OUTLINE", { 0.85, 0.88, 0.92 } },
	{ "FarseerFontCount",   BODY, 15, "OUTLINE", { 1, 1, 1 } },
	{ "FarseerFontTimer",   BODY, 13, "OUTLINE", { 1, 1, 1 } },
	{ "FarseerFontLabel",   BODY, 12, "OUTLINE", { 0.9, 0.92, 0.95 } },
	{ "FarseerFontAlert",   HEAD, 22, "OUTLINE", { 1, 1, 1 } },
	{ "FarseerFontAlertText", BODY, 15, "",      C.text },
}

T.fonts = {}
for _, f in ipairs(FONTS) do
	local ok, obj = pcall(CreateFont, f[1])
	if ok and obj then
		pcall(obj.SetFont, obj, f[2], f[3], f[4])
		local c = f[5]
		pcall(obj.SetTextColor, obj, c[1], c[2], c[3])
		if f[4] == "" then
			pcall(obj.SetShadowColor, obj, 0, 0, 0, 0.8)
			pcall(obj.SetShadowOffset, obj, 1, -1)
		else
			pcall(obj.SetShadowOffset, obj, 0, 0)
		end
		T.fonts[f[1]] = f[1]
	end
end

-- Namnet på ett typsnitt (eller Blizzards motsvarighet om det inte gick att skapa)
local FALLBACK = {
	FarseerFontTitle = "GameFontNormalHuge", FarseerFontHeader = "GameFontNormalLarge",
	FarseerFontStrong = "GameFontNormal", FarseerFontBody = "GameFontHighlight",
	FarseerFontSmall = "GameFontHighlightSmall", FarseerFontDim = "GameFontDisableSmall",
	FarseerFontAccent = "GameFontNormal", FarseerFontGold = "GameFontNormal",
	FarseerFontButton = "GameFontHighlight", FarseerFontButtonOff = "GameFontDisable",
	FarseerFontTab = "GameFontHighlight", FarseerFontGroup = "GameFontDisableSmall",
	FarseerFontKey = "NumberFontNormalSmallGray", FarseerFontCount = "NumberFontNormalLarge",
	FarseerFontTimer = "NumberFontNormal", FarseerFontLabel = "GameFontHighlightSmall",
	FarseerFontAlert = "GameFontNormalHuge", FarseerFontAlertText = "GameFontHighlight",
}
function T.Font(name) return T.fonts[name] or FALLBACK[name] or "GameFontHighlight" end

-- Blizzards typsnitt i inställningsfönstret -> Farseers (samma roll, nytt utseende)
T.MAP = {
	GameFontHighlight = "FarseerFontBody",
	GameFontHighlightSmall = "FarseerFontSmall",
	GameFontHighlightLarge = "FarseerFontHeader",
	GameFontNormal = "FarseerFontStrong",
	GameFontNormalSmall = "FarseerFontAccent",
	GameFontNormalLarge = "FarseerFontHeader",
	GameFontNormalHuge = "FarseerFontTitle",
	GameFontDisable = "FarseerFontDim",
	GameFontDisableSmall = "FarseerFontDim",
	GameFontWhite = "FarseerFontBody",
}
function T.Map(font)
	local m = font and T.MAP[font]
	if m and T.fonts[m] then return m end
	return font
end

---------------------------------------------------------------------------------------------------
-- Ramar
---------------------------------------------------------------------------------------------------
local WHITE = "Interface\\Buttons\\WHITE8x8"
T.WHITE = WHITE
T.BAR = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill"

-- 1 px bakgrund + ram
function T.Skin(f, bg, border, alpha)
	if not f.SetBackdrop and BackdropTemplateMixin then Mixin(f, BackdropTemplateMixin) end
	if not f.SetBackdrop then return f end
	pcall(f.SetBackdrop, f, { bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
	local b = bg or C.panel
	pcall(f.SetBackdropColor, f, b[1], b[2], b[3], alpha or 1)
	local e = border or C.border
	pcall(f.SetBackdropBorderColor, f, e[1], e[2], e[3], e[4] or 1)
	return f
end

-- Fyra 1 px-linjer runt en region (fungerar på vilken ram som helst, även säkra knappar)
function T.Border(f, color, layer, inset)
	local c = color or C.black
	inset = inset or 0
	local edges = {}
	local function line()
		local t = f:CreateTexture(nil, layer or "OVERLAY", nil, 7)
		t:SetColorTexture(c[1], c[2], c[3], c[4] or 1)
		table.insert(edges, t)
		return t
	end
	local top, bottom, left, right = line(), line(), line(), line()
	top:SetPoint("TOPLEFT", f, "TOPLEFT", -inset, inset)
	top:SetPoint("TOPRIGHT", f, "TOPRIGHT", inset, inset)
	top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -inset, -inset)
	bottom:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", inset, -inset)
	bottom:SetHeight(1)
	left:SetPoint("TOPLEFT", f, "TOPLEFT", -inset, inset)
	left:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -inset, -inset)
	left:SetWidth(1)
	right:SetPoint("TOPRIGHT", f, "TOPRIGHT", inset, inset)
	right:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", inset, -inset)
	right:SetWidth(1)
	function edges:SetColor(r, g, b, a) for _, t in ipairs(self) do t:SetColorTexture(r, g, b, a or 1) end end
	function edges:SetShown(v) for _, t in ipairs(self) do t:SetShown(v) end end
	return edges
end

-- Mjuk skugga runt ett fönster (några lager svart med fallande alpha)
function T.Shadow(f, size)
	size = size or 6
	f.shadow = f.shadow or {}
	-- En linje per pixel utanför ramen, allt svagare utåt
	for i = 1, size do
		local a = 0.45 * (1 - (i - 1) / size) ^ 1.6
		table.insert(f.shadow, T.Border(f, { 0, 0, 0, a }, "BACKGROUND", i))
	end
	return f.shadow
end

-- Vertikal toning på en textur (nyare och äldre API)
function T.Gradient(tex, dir, c1, c2)
	if CreateColor and tex.SetGradient then
		if pcall(tex.SetGradient, tex, dir, CreateColor(c1[1], c1[2], c1[3], c1[4] or 1), CreateColor(c2[1], c2[2], c2[3], c2[4] or 1)) then
			return true
		end
	end
	if tex.SetGradientAlpha then
		return pcall(tex.SetGradientAlpha, tex, dir, c1[1], c1[2], c1[3], c1[4] or 1, c2[1], c2[2], c2[3], c2[4] or 1)
	end
	return false
end

---------------------------------------------------------------------------------------------------
-- Ikonknappar i spelet: svart pixelram, en svag ljus kant inuti och mörk bakgrund. Blizzards
-- Quickslot-ram (b.border) döljs. Fungerar på säkra knappar (bara texturer läggs till).
---------------------------------------------------------------------------------------------------
function T.SkinIcon(b, opts)
	if not b or b.farseerSkinned then return b end
	b.farseerSkinned = true
	opts = opts or {}
	if b.border and b.border.SetTexture then b.border:SetTexture(nil); b.border:Hide() end
	if not opts.noBg then
		local bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
		bg:SetAllPoints()
		bg:SetColorTexture(0, 0, 0, 0.6)
		b.skinBg = bg
	end
	b.skinEdge = T.Border(b, opts.color or { 0, 0, 0, 1 }, "OVERLAY", 0)
	-- Inre ljus kant (ger "glas"-känsla)
	local hi = b:CreateTexture(nil, "OVERLAY", nil, 6)
	hi:SetPoint("TOPLEFT", 1, -1)
	hi:SetPoint("TOPRIGHT", -1, -1)
	hi:SetHeight(1)
	hi:SetColorTexture(1, 1, 1, 0.08)
	b.skinHi = hi
	-- Toning nedtill: siffror och tider syns bättre
	local shade = b:CreateTexture(nil, "ARTWORK", nil, 7)
	shade:SetPoint("BOTTOMLEFT", 1, 1)
	shade:SetPoint("BOTTOMRIGHT", -1, 1)
	shade:SetHeight(12)
	shade:SetColorTexture(1, 1, 1, 1)
	if not T.Gradient(shade, "VERTICAL", { 0, 0, 0, 0.55 }, { 0, 0, 0, 0 }) then shade:Hide() end
	b.skinShade = shade
	if b.icon and b.icon.SetTexCoord then
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		if not opts.keepIconPoints then
			b.icon:ClearAllPoints()
			b.icon:SetPoint("TOPLEFT", 1, -1)
			b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
		end
	end
	-- Hover: ljus ram (HIGHLIGHT-lagret syns av sig självt på knappar)
	if b.hl and b.hl.SetColorTexture then
		b.hl:SetTexture(nil)
		b.hl:SetColorTexture(1, 1, 1, 0.12)
	end
	if b.key and b.key.SetFontObject then pcall(b.key.SetFontObject, b.key, T.Font("FarseerFontKey")) end
	if b.count and b.count.SetFontObject then pcall(b.count.SetFontObject, b.count, T.Font("FarseerFontCount")) end
	if b.time and b.time.SetFontObject then pcall(b.time.SetFontObject, b.time, T.Font("FarseerFontTimer")) end
	if b.label and b.label.SetFontObject then pcall(b.label.SetFontObject, b.label, T.Font("FarseerFontLabel")) end
	if b.text and b.text.SetFontObject then pcall(b.text.SetFontObject, b.text, T.Font("FarseerFontLabel")) end
	if b.cd then
		pcall(b.cd.SetDrawEdge, b.cd, false)
		pcall(b.cd.SetSwipeColor, b.cd, 0, 0, 0, 0.72)
	end
	return b
end

-- Statusbar: jämn textur, mörk bakgrund och svart pixelram
function T.SkinBar(bar)
	if not bar or bar.farseerSkinned then return bar end
	bar.farseerSkinned = true
	pcall(bar.SetStatusBarTexture, bar, T.BAR)
	if bar.bg then bar.bg:SetColorTexture(0.02, 0.025, 0.035, 0.85) end
	bar.skinEdge = T.Border(bar, { 0, 0, 0, 1 }, "OVERLAY", 1)
	local hi = bar:CreateTexture(nil, "OVERLAY", nil, 6)
	hi:SetPoint("TOPLEFT")
	hi:SetPoint("TOPRIGHT")
	hi:SetHeight(1)
	hi:SetColorTexture(1, 1, 1, 0.1)
	if bar.text and bar.text.SetFontObject then pcall(bar.text.SetFontObject, bar.text, T.Font("FarseerFontLabel")) end
	return bar
end

-- Ruta bakom en grupp ikoner i spelet (svagt mörk, syns bara när den är upplåst eller valt)
function T.SkinPanel(f, alpha)
	return T.Skin(f, C.bg, { 0, 0, 0 }, alpha or 0.75)
end
