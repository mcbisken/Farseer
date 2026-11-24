-- Utrustningsset: en knapp per set från spelets Equipment Manager, och valfritt automatiskt byte
-- när Farseer byter PvE/PvP-läge. Byten görs bara utanför strid (spelet tillåter inget annat).

local _, ns = ...
local GE = ns.module("Gear")

local bar
local buttons = {}

function GE:Sets()
	local out = {}
	local E = C_EquipmentSet
	if not (E and E.GetEquipmentSetIDs) then return out end
	local ok, ids = pcall(E.GetEquipmentSetIDs)
	if not ok or type(ids) ~= "table" then return out end
	for _, id in ipairs(ids) do
		local okI, name, icon, setID, equipped = ns.getAll(E.GetEquipmentSetInfo, id)
		if okI and name then
			table.insert(out, { id = setID or id, name = name, icon = icon or 134400, equipped = equipped == true })
		end
	end
	table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
	return out
end

function GE:Find(name)
	if not name then return nil end
	local want = name:lower()
	for _, s in ipairs(self:Sets()) do
		if s.name:lower() == want then return s end
	end
	for _, s in ipairs(self:Sets()) do
		if s.name:lower():find(want, 1, true) then return s end
	end
end

function GE:Equip(name, quiet)
	local s = type(name) == "table" and name or self:Find(name)
	if not s then
		if not quiet then ns.print("no equipment set named \"%s\" found.", tostring(name)) end
		return false
	end
	if InCombatLockdown() then
		if not quiet then ns.print("can't change equipment in combat.") end
		return false
	end
	if s.equipped then return true end
	local ok = pcall(C_EquipmentSet.UseEquipmentSet, s.id)
	if ok and not quiet then ns.print("equipment: |cffffd100%s|r", s.name) end
	return ok
end

---------------------------------------------------------------------------------------------------
function GE:Build()
	local c = ns.char.bars.gear
	bar = CreateFrame("Frame", "FarseerGearBar", UIParent)
	bar:SetSize(30, 30)
	ns.placeFrame(bar, c)
	ns.makeMovable(bar, c, "Farseer: equipment")
end

function GE:Layout()
	if not bar then return end
	local c = ns.char.bars.gear
	ns.placeFrame(bar, c)
	local size, gap = c.size or 28, 4
	local sets = self:Sets()
	for i, s in ipairs(sets) do
		if i > 8 then break end
		local b = buttons[i]
		if not b then
			b = CreateFrame("Button", "FarseerGear" .. i, bar)
			b.icon = b:CreateTexture(nil, "ARTWORK")
			b.icon:SetAllPoints()
			b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
			b.mark = b:CreateTexture(nil, "OVERLAY")
			b.mark:SetPoint("BOTTOMLEFT", 1, 1)
			b.mark:SetPoint("BOTTOMRIGHT", -1, 1)
			b.mark:SetHeight(3)
			b.mark:SetColorTexture(0.3, 1, 0.3, 1)
			b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
			b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
			b:SetScript("OnClick", function(self) GE:Equip(self.set) end)
			b:SetScript("OnEnter", function(self)
				GameTooltip:SetOwner(self, "ANCHOR_TOP")
				GameTooltip:SetText(self.set.name)
				GameTooltip:AddLine(self.set.equipped and "Currently equipped" or "Click: switch to this set (out of combat)", 1, 1, 1)
				GameTooltip:Show()
			end)
			b:SetScript("OnLeave", function() GameTooltip:Hide() end)
			buttons[i] = b
		end
		b.set = s
		b:SetSize(size, size)
		b:ClearAllPoints()
		b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (size + gap), 0)
		b.icon:SetTexture(s.icon)
		b.mark:SetShown(s.equipped)
		b.label:SetText(s.name:sub(1, 8))
		b:Show()
	end
	local n = math.min(#sets, 8)
	for i = n + 1, #buttons do buttons[i]:Hide() end
	bar:SetSize(math.max(size, n * (size + gap) - gap), size)
	bar:SetShown(c.show and n > 0)
end

local lastMode
function GE:OnModeChanged(mode)
	local g = ns.char.gear
	local changed = lastMode ~= nil and lastMode ~= mode
	lastMode = mode
	if not g.auto or not changed then return end
	local name = mode == "PVP" and g.pvp or g.pve
	if not name or name == "" then return end
	ns.afterCombat("gear-mode", function() GE:Equip(name, false) end)
end

function GE:Refresh() self:Layout() end

function GE:OnLogin()
	lastMode = ns.char.mode
	self:Build()
	self:Layout()
	ns.on("EQUIPMENT_SETS_CHANGED", function() GE:Layout() end)
	ns.on("PLAYER_EQUIPMENT_CHANGED", function() GE:Layout() end)
	ns.on("EQUIPMENT_SWAP_FINISHED", function() GE:Layout() end)
	ns.listen("BARS_LAYOUT", function() GE:Layout() end)
	ns.listen("MODE_CHANGED", function(mode) GE:OnModeChanged(mode) end)
end
