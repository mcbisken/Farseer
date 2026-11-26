-- BiS: bästa items per spec och fas, med var de fås, alternativ och om du redan har dem.

local _, ns = ...
local UI = ns.UI

local SLOT_NAME = {
	HEAD = "Head", NECK = "Neck", SHOULDER = "Shoulders", BACK = "Back", CHEST = "Chest", WRIST = "Wrists",
	HANDS = "Hands", WAIST = "Waist", LEGS = "Legs", FEET = "Feet", FINGER1 = "Ring 1", FINGER2 = "Ring 2",
	TRINKET1 = "Trinket 1", TRINKET2 = "Trinket 2", MAINHAND = "Weapon", OFFHAND = "Off-hand/shield", RELIC = "Totem",
}
local SOURCE = {
	dungeon = { "Dungeon", { 0.4, 0.8, 1 } }, raid = { "Raid", { 1, 0.5, 0.2 } }, quest = { "Quest", { 1, 0.85, 0.2 } },
	crafted = { "Crafting", { 0.4, 1, 0.4 } }, reputation = { "Reputation", { 0.9, 0.6, 1 } }, vendor = { "Vendor", { 1, 1, 0.6 } },
	pvp = { "PvP", { 1, 0.35, 0.35 } }, world = { "World drop", { 0.8, 0.8, 0.8 } },
}
local SPECS = { { "elemental", "Elemental" }, { "enhancement", "Enhancement" }, { "restoration", "Restoration" } }
local PHASES = { { "prebis", "Pre-raid (dungeons)" }, { "phase1", "Phase 1 (raids)" } }

-- BiS-slot -> utrustningsslottar (ringar/trinkets: båda)
local INV = {
	HEAD = { 1 }, NECK = { 2 }, SHOULDER = { 3 }, BACK = { 15 }, CHEST = { 5 }, WRIST = { 9 }, HANDS = { 10 },
	WAIST = { 6 }, LEGS = { 7 }, FEET = { 8 }, FINGER1 = { 11, 12 }, FINGER2 = { 11, 12 }, TRINKET1 = { 13, 14 },
	TRINKET2 = { 13, 14 }, MAINHAND = { 16 }, OFFHAND = { 17 }, RELIC = { 18 },
}

-- Jämför med det du har på dig: "bis" / "alt" / "other" (annat item) / "empty", plus item-ID:t på dig
local function compare(e)
	local slots = INV[e.slot]
	if not slots or not e.id then return nil end
	local first
	for _, inv in ipairs(slots) do
		local id = ns.get(GetInventoryItemID, "player", inv)
		if id == e.id then return "bis", id end
		if e.alt and e.alt.id and id == e.alt.id then return "alt", id end
		first = first or id
	end
	if #slots == 1 then return first and "other" or "empty", first end
	return first and "other" or "empty", nil
end

local STATUS = {
	bis = "|cff40ff40BiS on|r", alt = "|cffffd100Alt on|r", other = "|cffff6060Upgrade|r", empty = "|cffff6060Empty|r",
}

local content, rows, summary, specButtons, phaseButtons, notes = nil, {}, nil, {}, {}, nil
local ROW_H = 46
local pendingRefresh = false

local function owned(id)
	if not id then return false end
	if C_Item and C_Item.IsEquippedItem and ns.get(C_Item.IsEquippedItem, id) == true then return true, "equipped" end
	local n = C_Item and ns.get(C_Item.GetItemCount, id, true)
	if type(n) == "number" and n > 0 then return true, "in bags/bank" end
	return false
end

local function qualityColor(id)
	local q = id and C_Item and ns.get(C_Item.GetItemQualityByID, id)
	if type(q) == "number" then
		local c = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
		if c then return c.r, c.g, c.b end
	end
	return 0.64, 0.21, 0.93
end

local function itemLink(id)
	if not (id and C_Item and C_Item.GetItemInfo) then return nil end
	local ok, _, link = ns.getAll(C_Item.GetItemInfo, id)
	return ok and link or nil
end

local function sourceLabel(s)
	local src = SOURCE[s or ""]
	if not src then return s or "" end
	return string.format("|cff%02x%02x%02x%s|r", src[2][1] * 255, src[2][2] * 255, src[2][3] * 255, src[1])
end

local function currentList()
	local specs = ns.BIS and ns.BIS.specs or {}
	local spec = specs[ns.char.bisSpec] or {}
	return spec[ns.char.bisPhase]
end

local refresh

local function makeRow(i)
	local r = CreateFrame("Button", nil, content, "BackdropTemplate")
	r:SetSize(UI.WIDTH - 30, ROW_H - 3)
	r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
	UI.Backdrop(r, 0.45, { 0.15, 0.18, 0.25 })
	r.slot = UI.Label(r, "", "GameFontNormalSmall")
	r.slot:SetPoint("TOPLEFT", 6, -8)
	r.slot:SetWidth(84)
	if r.slot.SetWordWrap then r.slot:SetWordWrap(false) end
	r.status = UI.Label(r, "", "GameFontHighlightSmall")
	r.status:SetPoint("TOPLEFT", r.slot, "BOTTOMLEFT", 0, -4)
	r.status:SetWidth(84)
	r.icon = r:CreateTexture(nil, "ARTWORK")
	r.icon:SetSize(34, 34)
	r.icon:SetPoint("LEFT", 92, 0)
	r.name = UI.Label(r, "", "GameFontNormal")
	r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 8, -1)
	r.name:SetWidth(250)
	r.where = UI.Label(r, "", "GameFontHighlightSmall")
	r.where:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
	r.where:SetWidth(420)
	r.where:SetMaxLines(1)
	r.src = UI.Label(r, "", "GameFontHighlightSmall")
	r.src:SetPoint("LEFT", r.name, "RIGHT", 6, 0)
	r.src:SetWidth(120)
	r.alt = UI.Label(r, "", "GameFontDisableSmall")
	r.alt:SetPoint("TOPRIGHT", -8, -6)
	r.alt:SetWidth(270)
	r.alt:SetJustifyH("RIGHT")
	r.altWhere = UI.Label(r, "", "GameFontDisableSmall")
	r.altWhere:SetPoint("TOPRIGHT", r.alt, "BOTTOMRIGHT", 0, -3)
	r.altWhere:SetWidth(270)
	r.altWhere:SetJustifyH("RIGHT")
	r.altWhere:SetMaxLines(1)
	r.have = r:CreateTexture(nil, "OVERLAY")
	r.have:SetSize(18, 18)
	r.have:SetPoint("BOTTOMRIGHT", r.icon, "BOTTOMRIGHT", 4, -4)
	r.have:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r:SetScript("OnEnter", function(self)
		local e = self.entry
		if not e then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		local shown = e.id and pcall(GameTooltip.SetItemByID, GameTooltip, e.id)
		if not shown then GameTooltip:SetText(e.name or "?") end
		GameTooltip:AddLine(" ")
		GameTooltip:AddLine("Source: " .. sourceLabel(e.source), 1, 1, 1)
		GameTooltip:AddLine(e.where or "", 1, 1, 1, true)
		if e.chance then GameTooltip:AddLine("Drop chance: " .. e.chance, 1, 1, 1) end
		if e.verified == false then GameTooltip:AddLine("Not yet confirmed for Forever.", 1, 0.5, 0.3) end
		local a = e.alt
		if a and a.name then
			GameTooltip:AddLine(" ")
			GameTooltip:AddLine("Alternative: " .. a.name, 0.8, 0.8, 0.8)
			if a.where then GameTooltip:AddLine(a.where, 0.7, 0.7, 0.7, true) end
		end
		local has, where = owned(e.id)
		if has then GameTooltip:AddLine("You have it (" .. where .. ")", 0.3, 1, 0.3) end
		local st, cur = compare(e)
		if st == "other" and cur then
			local ok, name = ns.getAll(C_Item.GetItemInfo, cur)
			GameTooltip:AddLine("Equipped now: " .. ((ok and name) or ("item " .. cur)), 1, 0.5, 0.5)
		elseif st == "empty" then
			GameTooltip:AddLine("Nothing in this slot.", 1, 0.5, 0.5)
		end
		GameTooltip:AddLine("Shift-click: link in chat  ·  Right-click: alternative's tooltip", 0.6, 0.8, 1)
		GameTooltip:Show()
	end)
	r:SetScript("OnLeave", function() GameTooltip:Hide() end)
	r:SetScript("OnClick", function(self, button)
		local e = self.entry
		if not e then return end
		if button == "RightButton" and e.alt and e.alt.id then
			GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
			if pcall(GameTooltip.SetItemByID, GameTooltip, e.alt.id) then GameTooltip:Show() end
			return
		end
		if IsShiftKeyDown() then
			local link = itemLink(e.id)
			if link and ChatEdit_InsertLink then pcall(ChatEdit_InsertLink, link) end
		end
	end)
	rows[i] = r
	return r
end

function refresh()
	if not content then return end
	for _, b in ipairs(specButtons) do
		if b.key == ns.char.bisSpec then b:LockHighlight() else b:UnlockHighlight() end
	end
	local specs = ns.BIS and ns.BIS.specs or {}
	local spec = specs[ns.char.bisSpec] or {}
	for _, b in ipairs(phaseButtons) do
		local has = spec[b.key] ~= nil
		b:SetEnabled(has)
		if b.key == ns.char.bisPhase then b:LockHighlight() else b:UnlockHighlight() end
	end
	for _, r in ipairs(rows) do r:Hide() end
	local list = currentList()
	if not list then
		summary:SetText("|cffffb040No list published for this phase yet.|r The Forever raids (Onyxia's Lair, Hyjal Summit, "
			.. "Barrow Deeps) open December 9; the list will be filled in once the loot tables are known.")
		content:SetHeight(10)
		return
	end
	local have, total = 0, 0
	local upgrades = {}
	for i, e in ipairs(list) do
		local r = rows[i] or makeRow(i)
		r.entry = e
		r.slot:SetText(SLOT_NAME[e.slot] or e.slot or "")
		if e.id then
			r.icon:SetTexture((C_Item and ns.get(C_Item.GetItemIconByID, e.id)) or 134400)
			if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, e.id) end
		else
			r.icon:SetTexture(134400)
		end
		r.name:SetText(e.name or "|cff888888(not used)|r")
		r.name:SetTextColor(qualityColor(e.id))
		r.src:SetText(sourceLabel(e.source) .. (e.verified == false and "  |cffff8040?|r" or ""))
		r.where:SetText((e.where or "") .. (e.chance and ("  |cffaaaaaa(" .. e.chance .. ")|r") or ""))
		local a = e.alt
		r.alt:SetText(a and a.name and ("Alt: " .. a.name) or "")
		r.altWhere:SetText(a and a.where or "")
		local has = owned(e.id)
		r.have:SetShown(has)
		local st = compare(e)
		r.status:SetText(st and STATUS[st] or "")
		if st == "other" or st == "empty" then table.insert(upgrades, SLOT_NAME[e.slot] or e.slot) end
		if e.id then
			total = total + 1
			if has then have = have + 1 end
		end
		r:Show()
	end
	content:SetHeight(#list * ROW_H)
	summary:SetText(string.format("You have |cff40ff40%d|r of %d BiS items.  %s", have, total,
		#upgrades > 0 and ("Next upgrades: |cffff8080" .. table.concat(upgrades, ", ") .. "|r")
			or "|cff40ff40All BiS or alternatives equipped!|r"))
end

local function build(p)
	local h = UI.Header(p, "BiS")
	h:SetPoint("TOPLEFT", 4, -6)
	local last = h
	for _, s in ipairs(SPECS) do
		local b = UI.Button(p, s[2], 120, 24, function() ns.char.bisSpec = s[1]; refresh() end)
		b.key = s[1]
		b:SetPoint("LEFT", last, "RIGHT", last == h and 12 or 4, 0)
		last = b
		table.insert(specButtons, b)
	end
	local sep = UI.Label(p, "|", "GameFontDisable")
	sep:SetPoint("LEFT", last, "RIGHT", 10, 0)
	last = sep
	for _, ph in ipairs(PHASES) do
		local b = UI.Button(p, ph[2], 150, 24, function() ns.char.bisPhase = ph[1]; refresh() end)
		b.key = ph[1]
		b:SetPoint("LEFT", last, "RIGHT", 10, 0)
		last = b
		table.insert(phaseButtons, b)
	end
	summary = UI.Label(p, "", "GameFontHighlight")
	summary:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -12)
	summary:SetWidth(UI.WIDTH - 10)
	local sf
	sf, content = UI.Scroll(p, UI.WIDTH - 30, UI.HEIGHT - 110)
	sf:SetPoint("TOPLEFT", summary, "BOTTOMLEFT", 0, -8)
	notes = UI.Label(p, "", "GameFontDisableSmall")
	notes:SetPoint("TOPLEFT", sf, "BOTTOMLEFT", 0, -6)
	notes:SetWidth(UI.WIDTH - 140)
	notes:SetMaxLines(3)
	local meta = ns.BIS and ns.BIS.meta or {}
	notes:SetText("Sources checked " .. (meta.checked or "?") .. ". Forever has its own items (Five Thunders T0.5, Pix Xizzix in "
		.. "Stranglethorn, new dungeons) — lists may change with patches. Hit cap per the guides: 17 % spell hit (caster), 8 % melee hit.")
	local src = UI.Button(p, "Sources", 100, 22, function()
		UI.CopyBox(table.concat(meta.sources or {}, "  "))
	end, "Show links to the guides the list is based on.")
	src:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)

	ns.on("ITEM_DATA_LOAD_RESULT", function()
		if pendingRefresh then return end
		pendingRefresh = true
		C_Timer.After(0.3, function()
			pendingRefresh = false
			if content and content:IsVisible() then refresh() end
		end)
	end)
	ns.on("BAG_UPDATE_DELAYED", function() if content and content:IsVisible() then refresh() end end)
	ns.on("PLAYER_EQUIPMENT_CHANGED", function() if content and content:IsVisible() then refresh() end end)
end

UI.AddTab("bis", "BiS", build, function() refresh() end)
