-- Översikt: status, snabbstart och ett-klicks-setup per spec.

local _, ns = ...
local UI = ns.UI

local SETUPS = {
	{ spec = "Elemental", preset = "elemental", icon = "Interface\\Icons\\Spell_Nature_Lightning",
		text = "Creates Elemental, Totem, PvP and Utility macros and binds the Elemental layout." },
	{ spec = "Enhancement", preset = "enhancement", icon = "Interface\\Icons\\Spell_Nature_LightningShield",
		text = "Creates Enhancement, Totem, PvP and Utility macros and binds the Enhancement layout." },
	{ spec = "Restoration", preset = "restoration", icon = "Interface\\Icons\\Spell_Nature_MagicImmunity",
		text = "Creates Restoration, Totem, PvP and Utility macros and binds the healer layout (mouseover)." },
}

local function runSetup(s)
	if InCombatLockdown() then ns.print("not in combat.") return end
	for _, cat in ipairs({ s.spec, "Totems", "PvP", "Utility" }) do ns.MacroEngine:CreateCategory(cat) end
	local n, errors = ns.BindingEngine:Apply(s.preset)
	ns.print("%s setup done: %d keybinds set.%s", s.spec, n, #errors > 0 and (" Errors: " .. table.concat(errors, "; ")) or "")
	ns.print("Undo keybinds: Keybinds tab -> Restore all keys, or /farseer restore.")
	UI.RefreshCurrent()
end

local status

local function build(p)
	local h = UI.Header(p, "Welcome to Farseer")
	h:SetPoint("TOPLEFT", 4, -4)
	local intro = UI.Label(p,
		"Everything for your shaman in one place: macros from templates, ready-made keybind layouts, situation buttons for totems "
		.. "in PvE and PvP, warnings about which totem is needed, totem timers, shield/imbue reminders and BiS lists.",
		"GameFontHighlight")
	intro:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
	intro:SetWidth(UI.WIDTH - 10)

	-- Ett-klicks-setup
	local sh = UI.Header(p, "One-click setup")
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
		local b = UI.Button(box, "Run setup", 120, 22, function()
			UI.Confirm("Create " .. s.spec .. " macros and replace your keybinds with Farseer\'s layout?\n"
				.. "(Whatever was on the keys is saved and can be restored.)", function() runSetup(s) end)
		end)
		b:SetPoint("BOTTOMRIGHT", -8, 8)
		prev = box
	end

	-- Snabbknappar
	local qh = UI.Header(p, "Quick actions")
	qh:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -140)
	local buttons = {
		{ "Unlock / lock bars", function() ns.setLocked(not ns.char.locked) end,
			"Unlocked: drag the bars and the warning box to move them." },
		{ "Toggle PvE / PvP", function() ns.Bars:SetMode(ns.Bars:Mode() == "PVP" and "PVE" or "PVP") end,
			"Switches which situation buttons are shown." },
		{ "Test warning", function() ns.Alert:Test() end, "Shows a sample warning with sound." },
		{ "Update macros", function()
			local n = ns.MacroEngine:RefreshExisting()
			ns.print("%d macros updated.", n)
		end, "Rebuilds all Farseer macros you already have with your current spells and settings." },
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
		"|cffffd100Situation buttons:|r left-click = next totem in the set, right-click = whole set with Call of the Elements.  "
		.. "|cffffd100Totem timers:|r right-click removes the totem.  |cffffd100Glowing button|r = Farseer thinks you need that totem now.  "
		.. "|cffffd100Commands:|r /farseer (lock, pvp, pve, test, macros, bind <template>, restore, debug).",
		"GameFontHighlightSmall")
	help:SetPoint("BOTTOMLEFT", 4, 4)
	help:SetWidth(UI.WIDTH - 10)
end

local function yes(v) return v and "|cff40ff40yes|r" or "|cffff4040no|r" end

local function refresh()
	if not status then return end
	local lines = {}
	local level = ns.get(UnitLevel, "player") or "?"
	table.insert(lines, "Class: " .. (ns.isShaman and "Shaman" or "|cffff4040not a shaman|r") .. "   Level: " .. level)
	local calls = {}
	for _, c in ipairs(ns.CALLS) do if ns.Spellbook:Knows(c) then table.insert(calls, c) end end
	table.insert(lines, "Call-spells: " .. (#calls > 0 and table.concat(calls, ", ") or "|cff888888none yet (level 20)|r"))
	table.insert(lines, "Mode: " .. (ns.Bars:Mode() == "PVP" and "|cffff6060PvP|r" or "|cff60ff60PvE|r")
		.. "   Auto mode: " .. yes(ns.char.autoMode) .. "   Bars locked: " .. yes(ns.char.locked))
	local have, total = 0, 0
	for _, t in ipairs(ns.MACRO_TEMPLATES) do
		total = total + 1
		if ns.MacroEngine:Exists(t.name) then have = have + 1 end
	end
	table.insert(lines, string.format("Farseer macros in game: %d of %d templates", have, total))
	local preset = ns.char.lastPreset and ns.BindingEngine:Preset(ns.char.lastPreset)
	table.insert(lines, "Keybind-layout: " .. (preset and preset.name or "|cff888888none|r")
		.. (ns.BindingEngine:HasBackup() and "   (backup exists — can be restored)" or ""))
	table.insert(lines, "Totem warnings: " .. yes(ns.char.advisor.enabled) .. "   Sound: " .. yes(ns.char.advisor.sound))
	if #ns.errors > 0 then table.insert(lines, "|cffff8040Errors this session: " .. #ns.errors .. " (/farseer debug)|r") end
	status:SetText(table.concat(lines, "\n"))
end

UI.AddTab("overview", "Overview", build, refresh)
