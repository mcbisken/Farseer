-- Varningar: vilka regler som är på, kontratotem-baren, fear-mob-lista och egna bossregler.

local _, ns = ...
local UI = ns.UI

local checks = {}
local counterChecks = {}
local fearContent, fearRows, bossContent, bossRows = nil, {}, nil, {}
local bossTotem = "Fire Resistance Totem"
local bossDrop

local RULES = {
	{ "enabled", "Totemvarningar på", "Huvudbrytare för alla varningar och glöd." },
	{ "fear", "Fear/charm/sleep på dig -> Tremor", "Läser spelets loss-of-control (fungerar i strid)." },
	{ "fearMobs", "Fear-mobs på target/nameplates -> Tremor", "Listan nedan. Lägg till egna mobs." },
	{ "pvpClass", "PvP: fiendens klass -> kontratotem", "Warlock/Priest -> Tremor, Rogue/Hunter -> Poison Cleansing, Mage -> Grounding, Warrior -> Earthbind osv." },
	{ "dispel", "Gift/sjukdom på gruppen -> Cleansing", "Läser auror på dig och din party. I strid kan spelet låsa auror; då varnas bara det som går att läsa." },
	{ "boss", "Boss/zon -> resist-totem", "Onyxia/Molten Core -> Fire Resistance, Sapphiron -> Frost Resistance osv. + egna regler." },
	{ "noTotems", "Påminn i strid utan totems", "Efter 8 s i strid utan ett enda totem." },
	{ "groupComp", "Rekommendera situation efter gruppen (PvE)", "Grön glöd på Melee eller Caster beroende på gruppens klasser." },
	{ "sound", "Ljud vid ny varning", "Raid warning-ljud, max var 8:e sekund per varning." },
	{ "showText", "Visa orsak under varningen", "Text som förklarar varför totemet behövs." },
}

local refresh

local function refreshFear()
	for _, r in ipairs(fearRows) do r:Hide() end
	local list = ns.Advisor:FearList()
	for i, e in ipairs(list) do
		local r = fearRows[i]
		if not r then
			r = CreateFrame("Frame", nil, fearContent)
			r:SetSize(250, 20)
			r:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
			r.text = UI.Label(r, "", "GameFontHighlightSmall")
			r.text:SetPoint("LEFT", 4, 0)
			r.del = UI.Button(r, "x", 20, 18)
			r.del:SetPoint("RIGHT", -2, 0)
			fearRows[i] = r
		end
		r.text:SetText(e.name .. (e.own and "  |cff40c0ff(egen)|r" or ""))
		r.del:SetScript("OnClick", function() ns.Advisor:RemoveFearMob(e.key); refreshFear() end)
		r:Show()
	end
	fearContent:SetHeight(math.max(10, #list * 20))
end

local function refreshBoss()
	for _, r in ipairs(bossRows) do r:Hide() end
	local list = {}
	for _, b in ipairs(ns.BOSS_RULES) do table.insert(list, { name = b[1], totem = b[2] }) end
	for k, v in pairs(ns.db.bossRules) do table.insert(list, { name = v.name, totem = v.totem, key = k }) end
	for i, e in ipairs(list) do
		local r = bossRows[i]
		if not r then
			r = CreateFrame("Frame", nil, bossContent)
			r:SetSize(300, 20)
			r:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
			r.icon = r:CreateTexture(nil, "ARTWORK")
			r.icon:SetSize(16, 16)
			r.icon:SetPoint("LEFT", 2, 0)
			r.text = UI.Label(r, "", "GameFontHighlightSmall")
			r.text:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
			r.del = UI.Button(r, "x", 20, 18)
			r.del:SetPoint("RIGHT", -2, 0)
			bossRows[i] = r
		end
		r.icon:SetTexture(ns.spellIcon(e.totem))
		r.text:SetText(e.name .. " -> " .. e.totem .. (e.key and "  |cff40c0ff(egen)|r" or ""))
		r.del:SetShown(e.key ~= nil)
		r.del:SetScript("OnClick", function() ns.Advisor:RemoveBossRule(e.key); refreshBoss() end)
		r:Show()
	end
	bossContent:SetHeight(math.max(10, #list * 20))
end

local function build(p)
	local cfg = ns.char.advisor
	local h = UI.Header(p, "Regler")
	h:SetPoint("TOPLEFT", 4, -4)
	local last = h
	for _, r in ipairs(RULES) do
		local cb = UI.Check(p, r[2], function() return cfg[r[1]] end, function(v) cfg[r[1]] = v end, r[3])
		cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, last == h and -6 or 0)
		last = cb
		table.insert(checks, cb)
	end
	local test = UI.Button(p, "Testa varning", 130, 24, function() ns.Alert:Test() end)
	test:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -10)
	local unlock = UI.Button(p, "Flytta varningsrutan", 150, 24, function() ns.setLocked(not ns.char.locked) end,
		"Låser upp alla Farseer-ramar. Dra varningsrutan dit du vill ha den och klicka igen för att låsa.")
	unlock:SetPoint("LEFT", test, "RIGHT", 6, 0)

	-- Kontratotems
	local ch = UI.Header(p, "Kontratotem-baren")
	ch:SetPoint("TOPLEFT", test, "BOTTOMLEFT", 0, -16)
	local cd = UI.Label(p, "Totems som visas som egna knappar och glöder när Farseer varnar.", "GameFontHighlightSmall")
	cd:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -4)
	local all = {}
	for name in pairs(ns.TOTEMS) do table.insert(all, name) end
	table.sort(all)
	local col, row = 0, 0
	for _, name in ipairs(all) do
		local cb = UI.Check(p, (name:gsub(" Totem$", "")), function() return tContains(ns.char.counterTotems, name) end,
			function(v)
				local l = ns.char.counterTotems
				for i = #l, 1, -1 do if l[i] == name then table.remove(l, i) end end
				if v then table.insert(l, name) end
				ns.Bars:ApplyCounter()
			end)
		cb:SetPoint("TOPLEFT", cd, "BOTTOMLEFT", col * 150, -4 - row * 21)
		row = row + 1
		if row >= 7 then row, col = 0, col + 1 end
		table.insert(counterChecks, cb)
	end

	-- Fear-mobs
	local x = 470
	local fh = UI.Header(p, "Fear-mobs (Tremor-varning)")
	fh:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local sf
	sf, fearContent = UI.Scroll(p, 250, 150)
	sf:SetPoint("TOPLEFT", fh, "BOTTOMLEFT", 0, -6)
	local fe = UI.EditBox(p, 170, function(self, text)
		ns.Advisor:AddFearMob(text); self:SetText(""); refreshFear()
	end)
	fe:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 6, -8)
	local fadd = UI.Button(p, "Lägg till", 70, 22, function()
		ns.Advisor:AddFearMob(fe:GetText()); fe:SetText(""); refreshFear()
	end)
	fadd:SetPoint("LEFT", fe, "RIGHT", 6, 0)
	local ftarget = UI.Button(p, "Mitt target", 100, 22, function()
		local name = ns.get(UnitName, "target")
		if name and ns.get(UnitIsPlayer, "target") ~= true then
			ns.Advisor:AddFearMob(name); refreshFear()
			ns.print("%s tillagd som fear-mob.", name)
		else ns.print("ta en mob i target först.") end
	end)
	ftarget:SetPoint("TOPLEFT", fe, "BOTTOMLEFT", -6, -6)

	-- Bossregler
	local bh = UI.Header(p, "Boss -> resist-totem")
	bh:SetPoint("TOPLEFT", ftarget, "BOTTOMLEFT", 0, -16)
	local bsf
	bsf, bossContent = UI.Scroll(p, 300, 130)
	bsf:SetPoint("TOPLEFT", bh, "BOTTOMLEFT", 0, -6)
	local be = UI.EditBox(p, 150)
	be:SetPoint("TOPLEFT", bsf, "BOTTOMLEFT", 6, -8)
	bossDrop = UI.Dropdown(p, 170, function() return bossTotem end, function()
		local items = {}
		for _, el in ipairs(ns.ELEMENTS) do
			for _, name in ipairs(ns.Spellbook:AllTotems(el)) do
				table.insert(items, { text = name, value = name, icon = ns.spellIcon(name) })
			end
		end
		return items
	end, function(v) bossTotem = v end)
	bossDrop:SetPoint("LEFT", be, "RIGHT", 6, 0)
	local badd = UI.Button(p, "Lägg till", 70, 22, function()
		local name = ns.trim(be:GetText())
		if name == "" then name = ns.get(UnitName, "target") or "" end
		if name == "" then ns.print("skriv ett bossnamn eller ta bossen i target.") return end
		ns.Advisor:AddBossRule(name, bossTotem); be:SetText(""); refreshBoss()
	end, "Tomt namn = ditt nuvarande target.")
	badd:SetPoint("TOPLEFT", be, "BOTTOMLEFT", -6, -6)
end

function refresh()
	for _, cb in ipairs(checks) do cb:Refresh() end
	for _, cb in ipairs(counterChecks) do cb:Refresh() end
	if bossDrop then bossDrop:Refresh() end
	refreshFear()
	refreshBoss()
end

UI.AddTab("advisor", "Varningar", build, function() refresh() end)
