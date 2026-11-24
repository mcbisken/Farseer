-- Raid: totemfördelning mellan shamans (förslag att kopiera eller skicka i chatten).

local _, ns = ...
local UI = ns.UI

local list, status, mineLabel
local rows = {}

local function say(msg, bad) status:SetText((bad and "|cffff6060" or "|cff40ff40") .. msg .. "|r") end

local function refresh()
	if not list then return end
	local plan = ns.RaidTotems:Plan()
	for i, p in ipairs(plan) do
		local r = rows[i]
		if not r then
			r = UI.Label(list, "", "GameFontHighlight")
			r:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
			r:SetWidth(860)
			rows[i] = r
		end
		local names = {}
		for _, t in ipairs(p.totems) do
			local el = ns.Spellbook:TotemElement(t)
			local c = el and ns.ELEMENT_COLOR[el] or { 1, 1, 1 }
			table.insert(names, ns.colorText((t:gsub(" Totem$", "")), c[1], c[2], c[3]))
		end
		r:SetText(string.format("%sGrupp %d|r (%s, %d melee/%d casters) — %s%s|r: %s",
			"|cffffd100", p.group, p.kind == "melee" and "melee" or "casters", p.melee, p.caster,
			p.me and "|cff40c0ff" or "|cffffffff", p.shaman, table.concat(names, ", ")))
		r:Show()
	end
	for i = #plan + 1, #rows do rows[i]:Hide() end
	list:SetHeight(math.max(20, #plan * 20))
	if #plan == 0 then
		list.empty:Show()
	else
		list.empty:Hide()
	end
	local mine = ns.RaidTotems:Mine(plan)
	if mine then
		local names = {}
		for _, t in ipairs(mine.totems) do table.insert(names, t) end
		mineLabel:SetText("Ditt set: |cff40c0ff" .. table.concat(names, ", ") .. "|r")
	else
		mineLabel:SetText("")
	end
end

local function build(p)
	local h = UI.Header(p, "Totemfördelning")
	h:SetPoint("TOPLEFT", 4, -4)
	local d = UI.Label(p, "Totems når bara din egen grupp. Förslaget ger varje shaman ett set efter gruppens "
		.. "sammansättning (melee: Strength of Earth + Windfury, casters: Mana Spring + Stoneskin); flera shamans i samma "
		.. "grupp får olika set. Addons får inte skicka meddelanden till varandra i instanser, så förslaget skickas som "
		.. "vanlig chatt när du klickar.", "GameFontHighlightSmall")
	d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
	d:SetWidth(860)
	list = CreateFrame("Frame", nil, p)
	list:SetSize(860, 20)
	list:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
	list.empty = UI.Label(list, "|cffaaaaaaInga shamans i gruppen. Gå med i en grupp eller raid och tryck Uppdatera.|r",
		"GameFontHighlightSmall")
	list.empty:SetPoint("TOPLEFT", 0, 0)
	mineLabel = UI.Label(p, "", "GameFontHighlight")
	mineLabel:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -14)
	mineLabel:SetWidth(860)
	local upd = UI.Button(p, "Uppdatera", 100, 22, refresh)
	upd:SetPoint("TOPLEFT", mineLabel, "BOTTOMLEFT", 0, -10)
	local send = UI.Button(p, "Skicka i chatten", 130, 22, function()
		local ok, err = ns.RaidTotems:Send()
		if ok then say(err or "Skickat.") else say(tostring(err), true) end
	end, "Raid- eller gruppchatten. Blockeras chatten i instansen: kopiera texten i stället.")
	send:SetPoint("LEFT", upd, "RIGHT", 6, 0)
	local copy = UI.Button(p, "Kopiera", 100, 22, function()
		UI.CopyBox(table.concat(ns.RaidTotems:Lines(), " | "))
	end)
	copy:SetPoint("LEFT", send, "RIGHT", 6, 0)
	local load = UI.Button(p, "Lägg mitt set i Call", 160, 22, function()
		local ok, err = ns.RaidTotems:LoadMine()
		if ok then say("Ditt set ligger nu i Call of the Elements.") else say(tostring(err), true) end
	end, "Skriver ditt föreslagna set till Call-spellen du valt på Situationer-fliken.")
	load:SetPoint("LEFT", copy, "RIGHT", 6, 0)
	status = UI.Label(p, "", "GameFontHighlight")
	status:SetPoint("TOPLEFT", upd, "BOTTOMLEFT", 0, -10)
	status:SetWidth(860)
	ns.on("GROUP_ROSTER_UPDATE", function() if list and list:IsVisible() then refresh() end end)
end

UI.AddTab("raid", "Raid", build, refresh)
