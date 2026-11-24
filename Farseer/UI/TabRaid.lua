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
		r:SetText(string.format("%sGroup %d|r (%s, %d melee/%d casters) — %s%s|r: %s",
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
		mineLabel:SetText("Your set: |cff40c0ff" .. table.concat(names, ", ") .. "|r")
	else
		mineLabel:SetText("")
	end
end

local function build(p)
	local h = UI.Header(p, "Totem assignments")
	h:SetPoint("TOPLEFT", 4, -4)
	local d = UI.Label(p, "Totems only reach your own group. The suggestion gives each shaman a set based on the group's "
		.. "makeup (melee: Strength of Earth + Windfury, casters: Mana Spring + Stoneskin); several shamans in the same "
		.. "group get different sets. Addons can't message each other in instances, so the suggestion is sent as "
		.. "regular chat when you click.", "GameFontHighlightSmall")
	d:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -6)
	d:SetWidth(860)
	list = CreateFrame("Frame", nil, p)
	list:SetSize(860, 20)
	list:SetPoint("TOPLEFT", d, "BOTTOMLEFT", 0, -12)
	list.empty = UI.Label(list, "|cffaaaaaaNo shamans in the group. Join a group or raid and press Refresh.|r",
		"GameFontHighlightSmall")
	list.empty:SetPoint("TOPLEFT", 0, 0)
	mineLabel = UI.Label(p, "", "GameFontHighlight")
	mineLabel:SetPoint("TOPLEFT", list, "BOTTOMLEFT", 0, -14)
	mineLabel:SetWidth(860)
	local upd = UI.Button(p, "Refresh", 100, 22, refresh)
	upd:SetPoint("TOPLEFT", mineLabel, "BOTTOMLEFT", 0, -10)
	local send = UI.Button(p, "Send to chat", 130, 22, function()
		local ok, err = ns.RaidTotems:Send()
		if ok then say(err or "Sent.") else say(tostring(err), true) end
	end, "Raid or party chat. If chat is blocked in the instance, copy the text instead.")
	send:SetPoint("LEFT", upd, "RIGHT", 6, 0)
	local copy = UI.Button(p, "Copy", 100, 22, function()
		UI.CopyBox(table.concat(ns.RaidTotems:Lines(), " | "))
	end)
	copy:SetPoint("LEFT", send, "RIGHT", 6, 0)
	local load = UI.Button(p, "Put my set in Call", 160, 22, function()
		local ok, err = ns.RaidTotems:LoadMine()
		if ok then say("Your set is now in Call of the Elements.") else say(tostring(err), true) end
	end, "Writes your suggested set to the Call spell you chose on the Situations tab.")
	load:SetPoint("LEFT", copy, "RIGHT", 6, 0)
	status = UI.Label(p, "", "GameFontHighlight")
	status:SetPoint("TOPLEFT", upd, "BOTTOMLEFT", 0, -10)
	status:SetWidth(860)
	ns.on("GROUP_ROSTER_UPDATE", function() if list and list:IsVisible() then refresh() end end)
end

UI.AddTab("raid", "Raid", build, refresh)
