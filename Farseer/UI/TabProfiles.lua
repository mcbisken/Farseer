-- Profiler: spara och ladda hela setupen, och exportera/importera den som text.

local _, ns = ...
local UI = ns.UI

local list, rows, status, nameBox, importName, textBox = nil, {}, nil, nil, nil, nil
local selected
local specWidgets, specLabel = {}, nil

local function say(msg, bad) status:SetText((bad and "|cffff6060" or "|cff40ff40") .. msg .. "|r") end

local refresh

local function makeRow(i)
	local r = CreateFrame("Button", nil, list, "BackdropTemplate")
	r:SetSize(380, 26)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * 28)
	UI.Backdrop(r, 0.45, { 0.15, 0.18, 0.25 })
	r.name = UI.Label(r, "", "GameFontHighlight")
	r.name:SetPoint("LEFT", 8, 0)
	r.name:SetWidth(170)
	r.saved = UI.Label(r, "", "GameFontDisableSmall")
	r.saved:SetPoint("LEFT", r.name, "RIGHT", 4, 0)
	r.load = UI.Button(r, "Ladda", 56, 20, function(self)
		local name = self:GetParent().profile
		UI.Confirm("Ladda profilen \"" .. name .. "\"? Nuvarande inställningar ersätts (spara dem först om du vill ha kvar dem).",
			function()
				local ok, err = ns.Profiles:Load(name)
				if ok then say("Laddade " .. name .. ".") else say(err, true) end
				refresh()
			end)
	end)
	r.load:SetPoint("RIGHT", -64, 0)
	r.del = UI.Button(r, "Ta bort", 56, 20, function(self)
		local name = self:GetParent().profile
		UI.Confirm("Ta bort profilen \"" .. name .. "\"?", function()
			ns.Profiles:Delete(name)
			say("Tog bort " .. name .. ".")
			refresh()
		end)
	end)
	r.del:SetPoint("RIGHT", -4, 0)
	r:SetScript("OnClick", function(self)
		selected = self.profile
		refresh()
	end)
	rows[i] = r
	return r
end

function refresh()
	if not list then return end
	local profiles = ns.Profiles:List()
	for i, p in ipairs(profiles) do
		local r = rows[i] or makeRow(i)
		r.profile = p.name
		local cur = ns.char.profile == p.name
		r.name:SetText((cur and "|cff40c0ff" or "") .. p.name .. (cur and " (aktiv)|r" or ""))
		r.saved:SetText(p.saved or "")
		local e = selected == p.name and { 0.3, 0.6, 1 } or { 0.15, 0.18, 0.25 }
		r:SetBackdropBorderColor(e[1], e[2], e[3], 1)
		r:Show()
	end
	for i = #profiles + 1, #rows do rows[i]:Hide() end
	list:SetHeight(math.max(30, #profiles * 28))
	if #profiles == 0 then list.empty:Show() else list.empty:Hide() end
	for _, w in ipairs(specWidgets) do w:Refresh() end
	if specLabel then
		local spec, how = ns.Spec:Detect()
		specLabel:SetText(spec and ("Avkänd spec: |cff40c0ff" .. ns.SPEC_NAME[spec] .. "|r (" .. how .. ")")
			or ("Avkänd spec: |cffaaaaaa-|r (" .. tostring(how) .. ")"))
	end
end

local function build(p)
	local h = UI.Header(p, "Profiler")
	h:SetPoint("TOPLEFT", 4, -4)
	local d = UI.Label(p, "En profil innehåller situationer, bars och positioner, varningar, HUD, påminnelser, "
		.. "makroinställningar, egna makron och dina fear-mobs/bossregler. Keybinds och spelets makron rörs inte.",
		"GameFontHighlightSmall")
	d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
	d:SetWidth(400)
	local l = UI.Label(p, "Spara nuvarande som:", "GameFontNormalSmall")
	l:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
	nameBox = UI.EditBox(p, 180)
	nameBox:SetPoint("LEFT", l, "RIGHT", 10, 0)
	local save = UI.Button(p, "Spara", 70, 22, function()
		local name = ns.trim(nameBox:GetText())
		local function doSave()
			local ok, err = ns.Profiles:Save(name)
			if ok then say("Sparade " .. name .. ".") else say(err, true) end
			nameBox:ClearFocus()
			refresh()
		end
		if ns.db.profiles[name] then UI.Confirm("Skriva över profilen \"" .. name .. "\"?", doSave) else doSave() end
	end)
	save:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
	-- Rullbar lista: spec-delen börjar vid y=-300
	local sf
	sf, list = UI.Scroll(p, 380, 196)
	sf:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -14)
	list.empty = UI.Label(list, "|cffaaaaaaInga profiler än. Skriv ett namn och tryck Spara.|r", "GameFontHighlightSmall")
	list.empty:SetPoint("TOPLEFT", 4, -6)

	-- Höger: export/import
	local x = 440
	local eh = UI.Header(p, "Dela")
	eh:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local box
	box, textBox = UI.MultiLine(p, 420, 300)
	box:SetPoint("TOPLEFT", eh, "BOTTOMLEFT", 0, -8)
	local exp = UI.Button(p, "Exportera nuvarande", 150, 22, function()
		textBox:SetText(ns.Profiles:Export() or "")
		textBox:HighlightText()
		textBox:SetFocus()
		say("Markerad — kopiera med Ctrl+C.")
	end)
	exp:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -6)
	local expSel = UI.Button(p, "Exportera vald profil", 150, 22, function()
		if not selected then say("Klicka på en profil i listan först.", true) return end
		textBox:SetText(ns.Profiles:Export(selected) or "")
		textBox:HighlightText()
		textBox:SetFocus()
		say("Profilen " .. selected .. " markerad — kopiera med Ctrl+C.")
	end)
	expSel:SetPoint("LEFT", exp, "RIGHT", 6, 0)
	local il = UI.Label(p, "Importera som:", "GameFontNormalSmall")
	il:SetPoint("TOPLEFT", exp, "BOTTOMLEFT", 0, -14)
	importName = UI.EditBox(p, 150)
	importName:SetPoint("LEFT", il, "RIGHT", 10, 0)
	importName:SetText("Import")
	local imp = UI.Button(p, "Importera", 90, 22, function()
		local ok, res = ns.Profiles:Import(textBox:GetText(), importName:GetText())
		if ok then say("Importerade som \"" .. res .. "\". Ladda den i listan till vänster.") else say("Fel: " .. tostring(res), true) end
		refresh()
	end, "Klistra in en FS1:/FS2:-text i rutan ovanför (Ctrl+V) och tryck Importera. Profilen sparas, den laddas inte direkt.")
	imp:SetPoint("LEFT", importName, "RIGHT", 6, 0)
	status = UI.Label(p, "", "GameFontHighlight")
	status:SetPoint("TOPLEFT", il, "BOTTOMLEFT", 0, -12)
	status:SetWidth(420)

	-- Spec: byt profil automatiskt
	local sc = ns.char.spec
	local sh = UI.Header(p, "Spec")
	sh:SetPoint("TOPLEFT", p, "TOPLEFT", 4, -350)
	specLabel = UI.Label(p, "", "GameFontHighlightSmall")
	specLabel:SetPoint("TOPLEFT", sh, "BOTTOMLEFT", 0, -6)
	specLabel:SetWidth(400)
	local c1 = UI.Check(p, "Känn av spec och byt när talangerna ändras", function() return sc.auto end,
		function(v) sc.auto = v; if v then ns.Spec:Check() end end,
		"Forever saknar spec-API: specen läses från talangpoängen, annars från talanger som Stormstrike och Mana Tide. "
			.. "Bytet görs utanför strid. Profilen du väljer nedan laddas när specen byts (inte vid inloggning).")
	c1:SetPoint("TOPLEFT", specLabel, "BOTTOMLEFT", 0, -4)
	local c2 = UI.Check(p, "Byt BiS-listans spec", function() return sc.setBis end, function(v) sc.setBis = v end)
	c2:SetPoint("TOPLEFT", c1, "BOTTOMLEFT", 0, 2)
	table.insert(specWidgets, c1)
	table.insert(specWidgets, c2)
	local function items()
		local out = { { text = "(ingen)", value = "" } }
		for _, pr in ipairs(ns.Profiles:List()) do table.insert(out, { text = pr.name, value = pr.name }) end
		return out
	end
	local prev = c2
	for i, spec in ipairs(ns.SPEC_TABS) do
		local l = UI.Label(p, ns.SPEC_NAME[spec] .. ":", "GameFontNormalSmall")
		l:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", i == 1 and 4 or 0, i == 1 and -10 or -16)
		local dd = UI.Dropdown(p, 180, function() return sc.profiles[spec] ~= "" and sc.profiles[spec] or "(ingen)" end,
			items, function(v) sc.profiles[spec] = v end)
		dd:SetPoint("LEFT", l, "LEFT", 100, 0)
		table.insert(specWidgets, dd)
		prev = l
	end
end

UI.AddTab("profiles", "Profiler", build, function() refresh() end)
