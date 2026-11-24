-- T0.5: The Five Thunders-kedjan steg för steg, med status från din questlogg.

local _, ns = ...
local UI = ns.UI

local content, summary
local rows = {}
local ROW_H = 58

local STATE = {
	done = { "|cff40ff40KLAR|r", { 0.15, 0.35, 0.15 } },
	active = { "|cffffd100PÅGÅR|r", { 0.4, 0.35, 0.1 } },
	todo = { "|cff999999kvar|r", { 0.15, 0.18, 0.25 } },
}

local function makeRow(i)
	local r = CreateFrame("Frame", nil, content, "BackdropTemplate")
	r:SetSize(UI.WIDTH - 30, ROW_H - 3)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
	UI.Backdrop(r, 0.45, { 0.15, 0.18, 0.25 })
	r.num = UI.Label(r, "", "GameFontNormalLarge")
	r.num:SetPoint("TOPLEFT", 6, -6)
	r.num:SetWidth(28)
	r.state = UI.Label(r, "", "GameFontHighlightSmall")
	r.state:SetPoint("TOPLEFT", r.num, "BOTTOMLEFT", 0, -4)
	r.state:SetWidth(50)
	r.name = UI.Label(r, "", "GameFontNormal")
	r.name:SetPoint("TOPLEFT", 60, -5)
	r.name:SetWidth(330)
	r.giver = UI.Label(r, "", "GameFontHighlightSmall")
	r.giver:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
	r.giver:SetWidth(UI.WIDTH - 30 - 60 - 340 - 10)
	r.giver:SetMaxLines(1)
	r.task = UI.Label(r, "", "GameFontHighlightSmall")
	r.task:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.task:SetWidth(UI.WIDTH - 30 - 70)
	r.task:SetMaxLines(1)
	r.reward = UI.Label(r, "", "GameFontDisableSmall")
	r.reward:SetPoint("TOPLEFT", r.task, "BOTTOMLEFT", 0, -3)
	r.reward:SetWidth(UI.WIDTH - 30 - 70)
	r.reward:SetMaxLines(1)
	r:EnableMouse(true)
	r:SetScript("OnEnter", function(self)
		local st = self.step
		if not st then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(st.name)
		if st.giver then GameTooltip:AddLine(st.giver, 0.8, 0.8, 1, true) end
		if st.task then GameTooltip:AddLine(st.task, 1, 1, 1, true) end
		if st.reward then GameTooltip:AddLine("Belöning: " .. st.reward, 1, 0.82, 0, true) end
		GameTooltip:AddLine(st.id and ("Quest-ID " .. st.id) or "Okänt quest-ID", 0.6, 0.6, 0.6)
		if st.url then GameTooltip:AddLine("Länk: knappen Källor nedan", 0.6, 0.8, 1) end
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	rows[i] = r
	return r
end

local function refresh()
	if not content then return end
	local list, done, nextIdx = ns.Leveling:T05Progress()
	for i, item in ipairs(list) do
		local r = rows[i] or makeRow(i)
		local st = item.step
		r.step = st
		r.num:SetText(tostring(i))
		local s = STATE[item.state] or STATE.todo
		r.state:SetText(item.state and s[1] or "|cff999999?|r")
		local e = (i == nextIdx) and { 0.3, 0.6, 1 } or s[2]
		r:SetBackdropBorderColor(e[1], e[2], e[3], 1)
		r.name:SetText((i == nextIdx and "|cff40c0ff> |r" or "") .. (st.name or "?"))
		r.giver:SetText(st.giver or "")
		r.task:SetText(st.task or "")
		r.reward:SetText(st.reward and ("Belöning: " .. st.reward) or "")
		r:Show()
	end
	for i = #list + 1, #rows do rows[i]:Hide() end
	content:SetHeight(#list * ROW_H)
	local nxt = nextIdx and list[nextIdx] and list[nextIdx].step.name
	summary:SetText(string.format("|cff40ff40%d|r av %d steg klara.%s  Shamanversionen är Horde (Mokvar, Orgrimmar), level 58+.",
		done, #list, nxt and ("  Nästa: |cff40c0ff" .. nxt .. "|r") or "  |cff40ff40Hela setet klart!|r"))
end

local function build(p)
	local h = UI.Header(p, "The Five Thunders (T0.5)")
	h:SetPoint("TOPLEFT", 4, -6)
	summary = UI.Label(p, "", "GameFontHighlight")
	summary:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
	summary:SetWidth(UI.WIDTH - 10)
	local sf
	sf, content = UI.Scroll(p, UI.WIDTH - 30, UI.HEIGHT - 90)
	sf:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -8)
	local note = UI.Label(p, "Status läses från questloggen. Fyra steg har flera varianter (en per relik/boss) — "
		.. "ett senare klart steg markerar tidigare som klara. Kontrollerat " .. (ns.T05 and ns.T05.checked or "?") .. ".",
		"GameFontDisableSmall")
	note:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -6)
	note:SetWidth(UI.WIDTH - 140)
	local src = UI.Button(p, "Källor", 100, 22, function()
		UI.CopyBox(table.concat(ns.T05 and ns.T05.sources or {}, "  "))
	end)
	src:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
	ns.on("QUEST_TURNED_IN", function() if content and content:IsVisible() then C_Timer.After(1, refresh) end end)
	ns.on("QUEST_ACCEPTED", function() if content and content:IsVisible() then refresh() end end)
end

UI.AddTab("t05", "T0.5", build, function() refresh() end)
