-- Översikt: status, snabbstart och ett-klicks-setup per spec.

local _, ns = ...
local UI = ns.UI

local SETUPS = {
	{ spec = "Elemental", preset = "elemental", icon = "Interface\\Icons\\Spell_Nature_Lightning",
		text = "Skapar Elemental-, Totem-, PvP- och Verktygsmakron och binder Elemental-layouten." },
	{ spec = "Enhancement", preset = "enhancement", icon = "Interface\\Icons\\Spell_Nature_LightningShield",
		text = "Skapar Enhancement-, Totem-, PvP- och Verktygsmakron och binder Enhancement-layouten." },
	{ spec = "Restoration", preset = "restoration", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity",
		text = "Skapar Restoration-, Totem-, PvP- och Verktygsmakron och binder healer-layouten (mouseover)." },
}

local function runSetup(s)
	if InCombatLockdown() then ns.print("inte i strid.") return end
	for _, cat in ipairs({ s.spec, "Totems", "PvP", "Verktyg" }) do ns.MacroEngine:CreateCategory(cat) end
	local n, errors = ns.BindingEngine:Apply(s.preset)
	ns.print("%s-setup klar: %d keybinds satta.%s", s.spec, n, #errors > 0 and (" Fel: " .. table.concat(errors, "; ")) or "")
	ns.print("Ångra keybinds: Keybinds-fliken -> Återställ, eller /farseer restore.")
	UI.RefreshCurrent()
end

local status

local function build(p)
	local h = UI.Header(p, "Välkommen till Farseer")
	h:SetPoint("TOPLEFT", 4, -4)
	local intro = UI.Label(p,
		"Allt för din shaman på ett ställe: makron från mallar, färdiga keybind-layouter, situationsknappar för totems "
		.. "i PvE och PvP, varningar om vilket totem som behövs, totem-timers, sköld/imbue-påminnelser och BiS-listor.",
		"GameFontHighlight")
	intro:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
	intro:SetWidth(UI.WIDTH - 10)

	-- Ett-klicks-setup
	local sh = UI.Header(p, "Ett-klicks-setup")
	sh:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -16)
	local prev
	for i, s in ipairs(SETUPS) do
		local box = UI.Box(p, 280, 118)
		if i == 1 then box:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -8) else box:SetPoint("LEFT", prev, "RIGHT", 10, 0) end
		local ic = box:CreateTexture(nil, "ARTWORK")
		ic:SetSize(36, 36)
		ic:SetPoint("TOPLEFT", 8, -8)
		ic:SetTexture(s.icon)
		local t = UI.Label(box, s.spec, "GameFontNormalLarge")
		t:SetPoint("LEFT", ic, "RIGHT", 8, 0)
		local d = UI.Label(box, s.text, "GameFontHighlightSmall")
		d:SetPoint("TOPLEFT", ic, "BOTTOMLEFT", 0, -6)
		d:SetWidth(262)
		local b = UI.Button(box, "Kör setup", 120, 22, function()
			UI.Confirm("Skapa " .. s.spec .. "-makron och ersätta dina keybinds med Farseers layout?\n"
				.. "(Det som låg på tangenterna sparas och kan återställas.)", function() runSetup(s) end)
		end)
		b:SetPoint("BOTTOMRIGHT", -8, 8)
		prev = box
	end

	-- Snabbknappar
	local qh = UI.Header(p, "Snabbval")
	qh:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -140)
	local buttons = {
		{ "Lås upp / lås bars", function() ns.setLocked(not ns.char.locked) end,
			"Upplåst: dra i bars och varningsrutan för att flytta dem." },
		{ "Växla PvE / PvP", function() ns.Bars:SetMode(ns.Bars:Mode() == "PVP" and "PVE" or "PVP") end,
			"Byter vilka situationsknappar som visas." },
		{ "Testa varning", function() ns.Alert:Test() end, "Visar en exempelvarning med ljud." },
		{ "Uppdatera makron", function()
			local n = ns.MacroEngine:RefreshExisting()
			ns.print("%d makron uppdaterade.", n)
		end, "Bygger om alla Farseer-makron du redan har med dina nuvarande spells och inställningar." },
	}
	local last
	for i, q in ipairs(buttons) do
		local b = UI.Button(p, q[1], 170, 24, function() q[2](); UI.RefreshCurrent() end, q[3])
		if i == 1 then b:SetPoint("TOPLEFT", qh, "BOTTOMLEFT", 0, -8) else b:SetPoint("LEFT", last, "RIGHT", 8, 0) end
		last = b
	end

	-- Status
	local st = UI.Header(p, "Status")
	st:SetPoint("TOPLEFT", qh, "BOTTOMLEFT", 0, -46)
	status = UI.Label(p, "", "GameFontHighlight")
	status:SetPoint("TOPLEFT", st, "BOTTOMLEFT", 0, -6)
	status:SetWidth(UI.WIDTH - 10)
	status:SetSpacing(3)

	-- Hjälp
	local help = UI.Label(p,
		"|cffffd100Situationsknappar:|r vänsterklick = nästa totem i setet, högerklick = hela setet med Call of the Elements.  "
		.. "|cffffd100Totem-timers:|r högerklick tar bort totemet.  |cffffd100Glödande knapp|r = Farseer tycker att du behöver det totemet nu.  "
		.. "|cffffd100Kommandon:|r /farseer (lock, pvp, pve, test, macros, bind <mall>, restore, debug).",
		"GameFontHighlightSmall")
	help:SetPoint("BOTTOMLEFT", 4, 4)
	help:SetWidth(UI.WIDTH - 10)
end

local function yes(v) return v and "|cff40ff40ja|r" or "|cffff4040nej|r" end

local function refresh()
	if not status then return end
	local lines = {}
	local level = ns.get(UnitLevel, "player") or "?"
	table.insert(lines, "Klass: " .. (ns.isShaman and "Shaman" or "|cffff4040inte shaman|r") .. "   Level: " .. level)
	local calls = {}
	for _, c in ipairs(ns.CALLS) do if ns.Spellbook:Knows(c) then table.insert(calls, c) end end
	table.insert(lines, "Call-spells: " .. (#calls > 0 and table.concat(calls, ", ") or "|cff888888inga ännu (level 20)|r"))
	table.insert(lines, "Läge: " .. (ns.Bars:Mode() == "PVP" and "|cffff6060PvP|r" or "|cff60ff60PvE|r")
		.. "   Auto-läge: " .. yes(ns.char.autoMode) .. "   Bars låsta: " .. yes(ns.char.locked))
	local have, total = 0, 0
	for _, t in ipairs(ns.MACRO_TEMPLATES) do
		total = total + 1
		if ns.MacroEngine:Exists(t.name) then have = have + 1 end
	end
	table.insert(lines, string.format("Farseer-makron i spelet: %d av %d mallar", have, total))
	local preset = ns.char.lastPreset and ns.BindingEngine:Preset(ns.char.lastPreset)
	table.insert(lines, "Keybind-layout: " .. (preset and preset.name or "|cff888888ingen|r")
		.. (ns.BindingEngine:HasBackup() and "   (backup finns — kan återställas)" or ""))
	table.insert(lines, "Totemvarningar: " .. yes(ns.char.advisor.enabled) .. "   Ljud: " .. yes(ns.char.advisor.sound))
	if #ns.errors > 0 then table.insert(lines, "|cffff8040Fel denna session: " .. #ns.errors .. " (/farseer debug)|r") end
	status:SetText(table.concat(lines, "\n"))
end

UI.AddTab("overview", "Översikt", build, refresh)
