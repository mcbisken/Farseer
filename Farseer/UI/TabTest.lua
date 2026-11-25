-- Testlista: ett första testpass i spelet. Markera varje punkt som fungerar/trasig; rapporten
-- (/farseer report) tar med resultatet, klientens funktioner och felen.

local _, ns = ...
local UI = ns.UI
local T = ns.Theme
local C = T.C

local rows, progress = {}, nil

local function state(id) return ns.db.testlist and ns.db.testlist[id] end

local function setState(id, v)
	ns.db.testlist = ns.db.testlist or {}
	if ns.db.testlist[id] == v then v = nil end   -- samma knapp igen = ångra
	ns.db.testlist[id] = v
end

local function paint(r)
	local st = state(r.id)
	local c = st == "ok" and C.good or st == "bad" and C.bad or C.borderHi
	r.stripe:SetColorTexture(c[1], c[2], c[3], 1)
	r.status:SetText(st == "ok" and "WORKS" or st == "bad" and "BROKEN" or "NOT TESTED")
	r.status:SetTextColor(c[1], c[2], c[3])
	if st == "ok" then r.okB:LockHighlight() else r.okB:UnlockHighlight() end
	if st == "bad" then r.badB:LockHighlight() else r.badB:UnlockHighlight() end
end

local function refresh()
	local okN, badN = 0, 0
	for _, r in ipairs(rows) do
		paint(r)
		local st = state(r.id)
		if st == "ok" then okN = okN + 1 elseif st == "bad" then badN = badN + 1 end
	end
	if progress then
		progress:SetText(string.format("%d of %d tested  ·  |cff4de673%d work|r  ·  |cffff5555%d broken|r",
			okN + badN, #rows, okN, badN))
	end
end

local function build(p)
	local h = UI.Header(p, "First test session")
	h:SetPoint("TOPLEFT", 4, -4)
	local intro = UI.Label(p, "About 15 minutes. The least certain things come first. Mark each one, then press "
		.. "\"Copy test report\" and paste the text — it includes what the game supports and any errors.", "GameFontDisableSmall")
	intro:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -10)
	intro:SetWidth(600)
	progress = UI.Label(p, "", "GameFontHighlight")
	progress:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -8)
	local report = UI.Button(p, "Copy test report", 160, 26, function() ns.Report:Show() end,
		"Opens the report: client features, this checklist, load and errors. Also /farseer report.")
	report:SetPoint("TOPRIGHT", p, "TOPRIGHT", -4, -2)
	local reset = UI.Button(p, "Reset list", 100, 26, function()
		UI.Confirm("Clear all marks in the test list?", function()
			ns.db.testlist = {}
			refresh()
		end)
	end)
	reset:SetPoint("RIGHT", report, "LEFT", -6, 0)

	local sf, content = UI.Scroll(p, UI.WIDTH - 24, UI.HEIGHT - 70)
	sf:SetPoint("TOPLEFT", progress, "BOTTOMLEFT", 0, -10)
	local rowH = 52
	for i, it in ipairs(ns.TEST_PLAN or {}) do
		local r = UI.Box(content, UI.WIDTH - 34, rowH - 4)
		r:SetPoint("TOPLEFT", 0, -(i - 1) * rowH)
		r.id = it.id
		r.stripe = r:CreateTexture(nil, "ARTWORK")
		r.stripe:SetPoint("TOPLEFT", 1, -1)
		r.stripe:SetPoint("BOTTOMLEFT", 1, 1)
		r.stripe:SetWidth(3)
		local num = UI.Label(r, tostring(i), "GameFontDisableSmall")
		num:SetPoint("TOPLEFT", 12, -8)
		num:SetWidth(18)
		local title = UI.Label(r, it.title, "GameFontNormal")
		title:SetPoint("TOPLEFT", 34, -7)
		local how = UI.Label(r, it.how, "GameFontDisableSmall")
		how:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
		how:SetWidth(UI.WIDTH - 330)
		if how.SetWordWrap then how:SetWordWrap(false) end
		r.badB = UI.Button(r, "Broken", 70, 22, function() setState(it.id, "bad"); refresh() end)
		r.badB:SetPoint("RIGHT", -8, 0)
		r.okB = UI.Button(r, "Works", 70, 22, function() setState(it.id, "ok"); refresh() end)
		r.okB:SetPoint("RIGHT", r.badB, "LEFT", -6, 0)
		r.status = UI.Label(r, "", "GameFontDisableSmall")
		r.status:SetPoint("RIGHT", r.okB, "LEFT", -12, 0)
		-- Hela beskrivningen i tooltipen (raden kan vara för kort)
		r:EnableMouse(true)
		r:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
			GameTooltip:SetText(it.title)
			GameTooltip:AddLine(it.how, 1, 1, 1, true)
			GameTooltip:Show()
		end)
		r:SetScript("OnLeave", function() GameTooltip:Hide() end)
		rows[i] = r
	end
	content:SetHeight(#rows * rowH)
	refresh()
end

UI.AddTab("test", "Test plan", build, refresh)
