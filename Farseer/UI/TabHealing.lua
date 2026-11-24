-- Healing: click-cast-mallar för raidramarna och downranking (rank per heal, mana per rank).

local _, ns = ...
local UI = ns.UI

local status, availLabel
local rankRows = {}

local function say(msg, bad) status:SetText((bad and "|cffff6060" or "|cff40ff40") .. msg .. "|r") end

local DOWN_TEMPLATES = { ["Healing Wave"] = "res_hw_low", ["Lesser Healing Wave"] = "res_lhw_low", ["Chain Heal"] = "res_ch_low" }

local function rankLine(spell)
	local want = ns.MacroEngine:DownRank(spell)
	local list = ns.MacroEngine:Ranks(spell)
	local max = list[#list] and list[#list].rank or want
	local info
	for _, r in ipairs(list) do if r.rank == want then info = r end end
	local parts = { string.format("rank %d of %d", want, max) }
	if info then
		table.insert(parts, "level " .. info.level)
		if info.mana then table.insert(parts, info.mana .. " mana") end
	end
	local top = list[#list]
	if top and top.mana and info and info.mana and top.rank ~= want then
		table.insert(parts, string.format("(max rank: %d mana)", top.mana))
	end
	return table.concat(parts, ", ")
end

local function build(p)
	-- Vänster: click-cast
	local h = UI.Header(p, "Click casting (raid and party frames)")
	h:SetPoint("TOPLEFT", 4, -4)
	availLabel = UI.Label(p, "", "GameFontHighlightSmall")
	availLabel:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
	availLabel:SetWidth(440)
	local last = availLabel
	for _, t in ipairs(ns.CLICKCAST) do
		local name = UI.Label(p, t.name, "GameFontNormal")
		name:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -12)
		local use = UI.Button(p, "Apply", 80, 20, function()
			local ok, n, missing, note = ns.ClickCast:Apply(t.id)
			local extra = (#missing > 0 and (" Missing: " .. table.concat(missing, ", ") .. ".") or "") .. (note and (" " .. note) or "")
			if ok then say(string.format("%s: %d bindings set.%s", t.name, n, extra))
			else say("Failed: " .. tostring(note) .. "." .. extra, true) end
		end, "Applies the template on top of your current click-cast. Same button + modifier is replaced, the rest is kept.")
		use:SetPoint("LEFT", name, "LEFT", 330, 0)
		local d = UI.Label(p, t.desc, "GameFontHighlightSmall")
		d:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -3)
		d:SetWidth(440)
		local lines = {}
		for _, b in ipairs(t.binds) do table.insert(lines, ns.ClickCast:Describe(b)) end
		local bl = UI.Label(p, "|cffaaaaaa" .. table.concat(lines, "   ") .. "|r", "GameFontHighlightSmall")
		bl:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -3)
		bl:SetWidth(440)
		last = bl
	end
	local restore = UI.Button(p, "Restore game click-cast", 200, 22, function()
		local ok, err = ns.ClickCast:Restore()
		if ok then say("Click-cast restored to how it was before Farseer.") else say(tostring(err), true) end
	end)
	restore:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -14)
	status = UI.Label(p, "", "GameFontHighlight")
	status:SetPoint("TOPLEFT", restore, "BOTTOMLEFT", 0, -10)
	status:SetWidth(440)

	-- Höger: downranking
	local x = 480
	local dh = UI.Header(p, "Downranking")
	dh:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local dd = UI.Label(p, "Lower rank = smaller heal but much less mana. Pick a rank per spell; the macros "
		.. "FS HW Low, FS LHW Low and FS CH Low cast that rank on mouseover > target > you.", "GameFontHighlightSmall")
	dd:SetPoint("TOPLEFT", dh, "BOTTOMLEFT", 0, -6)
	dd:SetWidth(390)
	local prev = dd
	for _, spell in ipairs(ns.DOWNRANK_SPELLS) do
		local list = ns.MacroEngine:Ranks(spell)
		local max = list[#list] and list[#list].rank or 10
		local st = UI.Stepper(p, spell, 1, max, 1, function() return ns.MacroEngine:DownRank(spell) end, function(v)
			ns.MacroEngine:SetDownRank(spell, v)
			rankRows[spell].info:SetText(rankLine(spell))
		end)
		st:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
		local info = UI.Label(p, "", "GameFontHighlightSmall")
		info:SetPoint("TOPLEFT", st, "BOTTOMLEFT", 0, -2)
		info:SetWidth(390)
		rankRows[spell] = { stepper = st, info = info }
		prev = info
	end
	local make = UI.Button(p, "Create downrank macros", 180, 22, function()
		local made, errs = 0, {}
		for _, spell in ipairs(ns.DOWNRANK_SPELLS) do
			if ns.Spellbook:Knows(spell) then
				local ok, msg = ns.MacroEngine:CreateFromTemplate(DOWN_TEMPLATES[spell], true)
				if ok then made = made + 1 else table.insert(errs, spell .. ": " .. tostring(msg)) end
			end
		end
		ns.fire("MACROS_CHANGED")
		if #errs > 0 then say(table.concat(errs, "; "), true) else say(made .. " downrank macros created/updated.") end
	end, "Requires the Forever client to understand the rank syntax \"Healing Wave(Rank 4)\". Test the macro before relying on it.")
	make:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -14)
	local note = UI.Label(p, "Mana is read from the game (out of combat). The rank text comes from the client, so the macros "
		.. "also work on non-English clients.", "GameFontDisableSmall")
	note:SetPoint("TOPLEFT", make, "BOTTOMLEFT", 0, -8)
	note:SetWidth(390)
end

local function refresh()
	if ns.ClickCast:Available() then
		local n = #ns.ClickCast:Current()
		availLabel:SetText(string.format("The game's Click Casting is available (%d bindings now). The template is written there and applies to "
			.. "Blizzard's raid and party frames.%s", n, ns.char.clickBackup and " |cffffd100Changed by Farseer — Restore is available.|r" or ""))
	else
		availLabel:SetText("|cffff6060The client doesn't have Click Casting (C_ClickBindings).|r The templates can't be written; "
			.. "use the heal macros with @mouseover instead.")
	end
	for spell, r in pairs(rankRows) do
		r.stepper:Refresh()
		r.info:SetText(rankLine(spell))
	end
end

UI.AddTab("healing", "Healing", build, refresh)
