-- Återuppliva: en knapp som dyker upp när någon i gruppen är död (utanför strid), som ShamUI.
-- Klick = Ancestral Spirit på den döda. Säkra attribut ändras bara utanför strid (då återupplivar man ändå).

local _, ns = ...
local RZ = ns.module("Rez")

local SPELL = "Ancestral Spirit"
local frame, button
local current, currentName     -- unit/namn som knappen pekar på
local announced = {}           -- [namn] = true: redan sagt till om den döda
local queued = false

local function cfg() return ns.char.bars.rez end

local function groupUnits()
	local list = {}
	if ns.get(IsInRaid) == true then
		for i = 1, 40 do list[#list + 1] = "raid" .. i end
	else
		for i = 1, 4 do list[#list + 1] = "party" .. i end
	end
	return list
end

-- Första döda gruppmedlemmen (inte spöke: kroppen måste finnas) som ingen redan återupplivar
function RZ:Target()
	for _, u in ipairs(groupUnits()) do
		if ns.get(UnitExists, u) == true and ns.get(UnitIsUnit, u, "player") ~= true
			and ns.get(UnitIsDead, u) == true and ns.get(UnitIsGhost, u) ~= true
			and ns.get(UnitIsConnected, u) ~= false
			and ns.get(UnitHasIncomingResurrection, u) ~= true then
			return u, ns.get(UnitName, u)
		end
	end
	return nil
end

function RZ:Current() return current, currentName end

function RZ:Update()
	if not button then return end
	if InCombatLockdown() then
		ns.afterCombat("rez", function() RZ:Update() end)
		return
	end
	local c = cfg()
	local u, name
	if c.show ~= false and ns.Spellbook:Knows(SPELL) and ns.get(UnitIsDeadOrGhost, "player") ~= true then
		u, name = self:Target()
	end
	if u then
		button:SetAttribute("type", "spell")
		button:SetAttribute("spell", ns.L(SPELL))
		button:SetAttribute("unit", u)
		local _, class = ns.getAll(UnitClass, u)
		local col = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
		button.name:SetText(name or u)
		if col then button.name:SetTextColor(col.r, col.g, col.b) else button.name:SetTextColor(1, 1, 1) end
		button:Show()
		button.glow:On()
		if name and not announced[name] then
			announced[name] = true
			ns.Alert:Flash("rez", SPELL, "RESURRECT", name .. " is dead. Click the resurrect button (Ancestral Spirit).", { 0.6, 1, 0.6 }, 4)
		end
	else
		button:SetAttribute("unit", nil)
		button.glow:Off()
		button:Hide()
	end
	current, currentName = u, name
	-- De som lever igen kan sägas till om nästa gång
	for n in pairs(announced) do
		local alive = true
		for _, gu in ipairs(groupUnits()) do
			if ns.get(UnitName, gu) == n and ns.get(UnitIsDeadOrGhost, gu) == true then alive = false end
		end
		if alive then announced[n] = nil end
	end
end

-- UNIT_HEALTH kommer ofta: samla ihop till en uppdatering
function RZ:Queue()
	if queued then return end
	queued = true
	C_Timer.After(0.3, function()
		queued = false
		local ok, err = pcall(RZ.Update, RZ)
		if not ok then ns.report(err) end
	end)
end

function RZ:Build()
	local c = cfg()
	local size = c.size or 34
	frame = CreateFrame("Frame", "FarseerRezBar", UIParent)
	frame:SetSize(size, size)
	ns.placeFrame(frame, c)
	ns.makeMovable(frame, c, "Farseer: resurrect")
	button = CreateFrame("Button", "FarseerRezButton", frame, "SecureActionButtonTemplate")
	button:SetSize(size, size)
	button:SetPoint("CENTER")
	button:RegisterForClicks("AnyUp", "AnyDown")
	button.icon = button:CreateTexture(nil, "ARTWORK")
	button.icon:SetAllPoints()
	button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon:SetTexture(ns.spellIcon(SPELL))
	button.name = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	button.name:SetPoint("TOP", button, "BOTTOM", 0, -2)
	button.glow = ns.addGlow(button, 0.5, 1, 0.5)
	button:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(SPELL)
		GameTooltip:AddLine((currentName or "?") .. " is dead. Click to resurrect.", 1, 1, 1, true)
		GameTooltip:Show()
	end)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:Hide()
	_G["BINDING_NAME_CLICK FarseerRezButton:LeftButton"] = "Resurrect dead party member (Ancestral Spirit)"
end

function RZ:OnShamanLogin()
	self:Build()
	self:Update()
	for _, e in ipairs({ "GROUP_ROSTER_UPDATE", "UNIT_FLAGS", "UNIT_HEALTH", "INCOMING_RESURRECT_CHANGED",
		"PLAYER_ALIVE", "PLAYER_UNGHOST", "PLAYER_DEAD" }) do
		ns.on(e, function() RZ:Queue() end)
	end
	ns.listen("SPELLS_CHANGED", function() RZ:Queue() end)
	ns.listen("COMBAT_END", function() RZ:Queue() end)
	ns.listen("BARS_LAYOUT", function()
		ns.afterCombat("rez-layout", function()
			ns.placeFrame(frame, cfg())
			local size = cfg().size or 34
			frame:SetSize(size, size)
			button:SetSize(size, size)
			RZ:Update()
		end)
	end)
end
