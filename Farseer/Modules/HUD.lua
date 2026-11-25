-- Strids-HUD: cooldowns (shocks, Stormstrike, Chain Lightning, Riptide, Nature's Swiftness, Lightning Mastery,
-- Mana Tide, Rage of the Farseer, Reincarnation, rasförmågor, trinkets), räckvidd mot target, Flame Shock-timer,
-- Riptide per mål (med Chain Heal-tips) och swing timer.
-- Allt här är vanliga (osäkra) ramar: inget är klickbart, så det fungerar och uppdateras även i strid.
-- Timers räknas från dina egna casts (alltid läsbara); cooldowns via spelets cooldown-ram.

local _, ns = ...
local HU = ns.module("HUD")

local MAIN_HAND = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.MainHand or 0
local OFF_HAND = Enum and Enum.PlayerSwingType and Enum.PlayerSwingType.OffHand or 1

-- Glöd när de är redo. cd = grundcooldown (egen klocka); family = delar cooldown (alla shocks)
local READY = {
	["Earth Shock"] = { cd = 6, family = "shock" },
	["Stormstrike"] = { cd = 20 },
	["Lava Burst"] = { cd = 8 },
}
local SHOCKS = { ["Earth Shock"] = true, ["Flame Shock"] = true, ["Frost Shock"] = true }
HU.READY = READY

local frame, rangeText, fsBar, swingBar, offBar
local swingOff               -- { start, dur } för off-hand
local busy = {}              -- [spell] = { at = casttid } medan spellen har cooldown (egen klocka)
local icons, ripRows = {}, {}
local riptides = {}          -- [mål] = starttid
local flame                  -- { start, dur, guid }
local swing                  -- { start, dur }
local sent = {}              -- [castGUID] = målets namn
local lastSentTarget

local function cfg() return ns.char.hud end

---------------------------------------------------------------------------------------------------
-- Vad som visas
---------------------------------------------------------------------------------------------------
local function trinketUsable(slot)
	local id = ns.get(GetInventoryItemID, "player", slot)
	if not id then return false end
	if C_Item and C_Item.GetItemSpell then
		local ok, name, spellID = ns.getAll(C_Item.GetItemSpell, id)
		if ok then return name ~= nil or spellID ~= nil end
	end
	return true
end

function HU:Entries()
	local out = {}
	for _, e in ipairs(ns.HUD_SPELLS) do
		local key = e.spell or ("trinket" .. e.trinket)
		if not cfg().hidden[key] then
			if e.spell and ns.Spellbook:Knows(e.spell) then
				table.insert(out, { key = key, spell = e.spell, range = e.range })
			elseif e.trinket and trinketUsable(e.trinket) then
				table.insert(out, { key = key, trinket = e.trinket })
			end
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Bygg
---------------------------------------------------------------------------------------------------
local function makeBar(parent, r, g, b)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	bar:SetStatusBarColor(r, g, b)
	bar:SetMinMaxValues(0, 1)
	bar.bg = bar:CreateTexture(nil, "BACKGROUND")
	bar.bg:SetAllPoints()
	bar.bg:SetColorTexture(0, 0, 0, 0.55)
	bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	bar.text:SetPoint("CENTER")
	ns.Theme.SkinBar(bar)
	bar:Hide()
	return bar
end

local function makeIcon(i)
	local f = CreateFrame("Frame", "FarseerHUDIcon" .. i, frame)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.cd = CreateFrame("Cooldown", nil, f, "CooldownFrameTemplate")
	f.cd:SetAllPoints()
	f.cd:SetDrawEdge(false)
	-- Cooldown-ramen säger till när den är klar (även när tiden är secret). Efter GCD:n (1,5 s) räknas inte.
	f.cd:SetScript("OnCooldownDone", function()
		local e = f.entry
		local b = e and e.spell and busy[e.spell]
		if b and GetTime() - b.at > 2 then busy[e.spell] = nil end
	end)
	f.ready = ns.addGlow(f, 0.4, 0.8, 1)
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		if not self.entry then return end
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		local e = self.entry
		if e.spell then
			local id = ns.Spellbook:ID(e.spell)
			if not (id and pcall(GameTooltip.SetSpellByID, GameTooltip, id)) then GameTooltip:SetText(e.spell) end
		else
			if not pcall(GameTooltip.SetInventoryItem, GameTooltip, "player", e.trinket) then GameTooltip:SetText("Trinket") end
		end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	ns.Theme.SkinIcon(f)
	icons[i] = f
	return f
end

function HU:Build()
	local c = ns.char.bars.hud
	frame = CreateFrame("Frame", "FarseerHUD", UIParent)
	frame:SetSize(200, 40)
	ns.placeFrame(frame, c)
	ns.makeMovable(frame, c, "Farseer: combat HUD")
	rangeText = frame:CreateFontString(nil, "OVERLAY", ns.Theme.Font("FarseerFontLabel"))
	rangeText:SetPoint("BOTTOM", frame, "TOP", 0, 2)
	fsBar = makeBar(frame, 0.95, 0.4, 0.1)
	swingBar = makeBar(frame, 0.85, 0.85, 0.85)
	offBar = makeBar(frame, 0.65, 0.65, 0.75)
	-- Flurry-laddningar till höger på swing-baren (spelet skriver talet även när det är secret)
	swingBar.flurry = swingBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	swingBar.flurry:SetPoint("RIGHT", swingBar, "RIGHT", -3, 0)
	swingBar.flurry:SetTextColor(1, 0.82, 0.3)
	for i = 1, 6 do
		local r = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
		r:SetJustifyH("LEFT")
		ripRows[i] = r
	end
	local update = ns.timed("hud-timers", function() HU:UpdateTimers() end)
	frame:SetScript("OnUpdate", function(_, elapsed)
		frame.acc = (frame.acc or 0) + elapsed
		if frame.acc < 0.1 then return end
		frame.acc = 0
		update()
	end)
end

function HU:Layout()
	if not frame then return end
	local c, h = ns.char.bars.hud, cfg()
	ns.placeFrame(frame, c)
	local size, gap = c.size or 30, 3
	local list = h.cooldowns and self:Entries() or {}
	for i, e in ipairs(list) do
		local f = icons[i] or makeIcon(i)
		f.entry = e
		f:SetSize(size, size)
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", frame, "TOPLEFT", (i - 1) * (size + gap), 0)
		if e.spell then
			f.icon:SetTexture(ns.spellIcon(e.spell))
		else
			f.icon:SetTexture(ns.get(GetInventoryItemTexture, "player", e.trinket) or 134400)
		end
		f:Show()
	end
	for i = #list + 1, #icons do icons[i].entry = nil; icons[i]:Hide() end
	local width = math.max(160, #list * (size + gap) - gap)
	local y = #list > 0 and -(size + 4) or 0
	fsBar:SetSize(width, 12)
	fsBar:ClearAllPoints()
	fsBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, y)
	swingBar:SetSize(width, 8)
	swingBar:ClearAllPoints()
	swingBar:SetPoint("TOPLEFT", fsBar, "BOTTOMLEFT", 0, -3)
	offBar:SetSize(width, 5)
	offBar:ClearAllPoints()
	offBar:SetPoint("TOPLEFT", swingBar, "BOTTOMLEFT", 0, -2)
	for i, r in ipairs(ripRows) do
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", offBar, "BOTTOMLEFT", 0, -3 - (i - 1) * 12)
	end
	frame:SetSize(width, math.max(size, -y + 24))
	frame:SetShown(c.show and ns.isShaman)
	self:UpdateCooldowns()
	self:UpdateTimers()
end

---------------------------------------------------------------------------------------------------
-- Uppdatering
---------------------------------------------------------------------------------------------------
function HU:UpdateCooldowns()
	for _, f in ipairs(icons) do
		local e = f.entry
		if e and f:IsShown() then
			if e.spell then
				ns.setSpellCooldown(f.cd, e.spell)
			else
				local ok, start, dur, enable = ns.getAll(GetInventoryItemCooldown, "player", e.trinket)
				if ok and start and dur then
					if dur > 1.5 and enable ~= 0 then pcall(f.cd.SetCooldown, f.cd, start, dur) else pcall(f.cd.Clear, f.cd) end
				end
			end
		end
	end
end

local function inRange(spell)
	if not (C_Spell and C_Spell.IsSpellInRange) or not ns.Spellbook:Knows(spell) then return nil end
	local v = ns.get(C_Spell.IsSpellInRange, ns.L(spell), "target")
	if v == nil then return nil end
	return v == true or v == 1
end
HU.InRange = inRange

local function hostileTarget()
	return ns.get(UnitExists, "target") == true and ns.get(UnitCanAttack, "player", "target") == true
		and ns.get(UnitIsDeadOrGhost, "target") ~= true
end

local function fmt(s) return string.format(s >= 10 and "%d" or "%.1f", s) end

function HU:UpdateTimers()
	if not frame or not frame:IsShown() then return end
	local h, now = cfg(), GetTime()
	-- Räckvidd
	local hostile = h.range and hostileTarget()
	local parts = {}
	if hostile then
		for _, sp in ipairs({ { "Earth Shock", "Shock" }, { "Lightning Bolt", "Bolt" }, { "Stormstrike", "Melee" } }) do
			local r = inRange(sp[1])
			if r ~= nil then table.insert(parts, (r and "|cff40ff40" or "|cffff4040") .. sp[2] .. "|r") end
		end
	end
	rangeText:SetText(table.concat(parts, "   "))
	local glowOn = h.readyGlow ~= false and InCombatLockdown() and hostileTarget()
	for _, f in ipairs(icons) do
		local e = f.entry
		local r
		if e and e.range and hostile then
			r = inRange(e.spell)
			if r == false then f.icon:SetVertexColor(1, 0.3, 0.3) else f.icon:SetVertexColor(1, 1, 1) end
		elseif e then
			f.icon:SetVertexColor(1, 1, 1)
		end
		if f.ready then
			if glowOn and e and e.spell and READY[e.spell] and r ~= false and self:Ready(e.spell, now) then
				f.ready:On()
			else
				f.ready:Off()
			end
		end
	end
	-- Flame Shock på ditt target
	local fs = h.flameShock and flame and flame.start + flame.dur - now
	if fs and fs > 0 then
		local tg = ns.get(UnitGUID, "target")
		if flame.guid and tg and tg ~= flame.guid then fs = nil end
	end
	if fs and fs > 0 then
		fsBar:SetValue(fs / flame.dur)
		fsBar.text:SetText("Flame Shock  " .. fmt(fs))
		fsBar:Show()
	else
		if flame and now > flame.start + flame.dur then flame = nil end
		fsBar:Hide()
	end
	-- Swing
	local inCombat = InCombatLockdown()
	if h.swing and swing and (inCombat or not h.swingCombatOnly) then
		local left = swing.start + swing.dur - now
		if left > 0 then
			swingBar:SetValue(1 - left / swing.dur)
			swingBar.text:SetText(fmt(left))
			swingBar:Show()
		else
			swingBar:SetValue(1)
			swingBar.text:SetText("")
			swingBar:SetShown(inCombat)
		end
		if h.flurrySwing ~= false then self:ShowFlurry() else swingBar.flurry:SetText("") end
	else
		swingBar:Hide()
	end
	if h.swing and h.offSwing ~= false and swingOff and (inCombat or not h.swingCombatOnly) then
		local left = swingOff.start + swingOff.dur - now
		if left > 0 then offBar:SetValue(1 - left / swingOff.dur) else offBar:SetValue(1) end
		offBar.text:SetText("")
		offBar:SetShown(left > 0 or inCombat)
	else
		offBar:Hide()
	end
	-- Riptide per mål
	local list = {}
	if h.riptide then
		for who, start in pairs(riptides) do
			local left = start + (ns.RIPTIDE_DUR or 15) - now
			if left > 0 then table.insert(list, { who, left }) else riptides[who] = nil end
		end
		table.sort(list, function(a, b) return a[2] > b[2] end)
	end
	for i, r in ipairs(ripRows) do
		local row = list[i]
		if row then
			local hint = (i == 1 and h.chainHealHint and ns.Spellbook:Knows("Chain Heal")) and "  |cff40ff40Chain Heal +25 %|r" or ""
			r:SetText(string.format("|cff40c0ffRiptide|r %s  %s%s", row[1], fmt(row[2]), hint))
			r:Show()
		else
			r:Hide()
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Händelser
---------------------------------------------------------------------------------------------------
function HU:OnCast(name, castGUID)
	if type(name) ~= "string" then return end
	local now = GetTime()
	local who = (castGUID and sent[castGUID]) or lastSentTarget
	if castGUID then sent[castGUID] = nil end
	self:OnReadyCast(name)
	if name == "Flame Shock" then
		flame = { start = now, dur = ns.FLAME_SHOCK_DUR or 12, guid = ns.get(UnitGUID, "target") }
	elseif name == "Riptide" then
		riptides[who or "target"] = now
	elseif name == "Chain Heal" and who then
		riptides[who] = nil   -- Chain Heal förbrukar Riptiden på första målet
	end
end

HU.swingSeen = { main = 0, off = 0 }   -- för /farseer report: kommer PLAYER_SWING alls?

function HU:OnSwing(dur, kind)
	if ns.isSecret(kind) then return end
	if kind ~= nil and kind == OFF_HAND and kind ~= MAIN_HAND then
		self.swingSeen.off = self.swingSeen.off + 1
	else
		self.swingSeen.main = self.swingSeen.main + 1
	end
	local off = kind ~= nil and kind == OFF_HAND and kind ~= MAIN_HAND
	if kind ~= nil and kind ~= MAIN_HAND and not off then return end
	if ns.isSecret(dur) or type(dur) ~= "number" or dur <= 0 then
		-- Secret: läs vapnets hastighet i stället (main hand, off-hand)
		local ok, speed, offSpeed = ns.getAll(UnitAttackSpeed, "player")
		dur = ok and (off and offSpeed or speed) or nil
		if type(dur) ~= "number" or dur <= 0 then dur = nil end
	end
	local t = dur and { start = GetTime(), dur = dur } or nil
	if off then swingOff = t else swing = t end
end

-- Flurry-laddningar: tal när det går att läsa, annars det råa secret-värdet (spelet ritar det)
function HU:ShowFlurry()
	local PC = ns.Procs
	local fs = swingBar.flurry
	if not (PC and PC.playerAura) then fs:SetText("") return end
	local def
	for _, d in ipairs(PC.PROCS or {}) do if d.key == "flurry" then def = d end end
	local a = def and PC.playerAura(def.ids, def.name)
	if a == nil then fs:SetText("") return end
	local n, raw = PC.applications(a)
	if n and n > 0 then
		fs:SetText("Flurry " .. n)
	elseif raw ~= nil then
		if not pcall(fs.SetText, fs, raw) then fs:SetText("Flurry") end
	else
		fs:SetText("Flurry")
	end
end

-- Redo? Egen klocka från din cast; cooldown-ramen kan säga "klar" tidigare (talanger som kortar den)
function HU:Ready(spell, now)
	local b = busy[spell]
	if not b then return true end
	local def = READY[spell]
	if def and (now or GetTime()) - b.at >= def.cd then
		busy[spell] = nil
		return true
	end
	return false
end

function HU:OnReadyCast(name)
	if READY[name] then busy[name] = { at = GetTime() } end
	-- Alla shocks delar cooldown med Earth Shock
	if SHOCKS[name] then busy["Earth Shock"] = { at = GetTime() } end
end

local castFrame = CreateFrame("Frame")
castFrame:SetScript("OnEvent", function(_, event, unit, a2, a3, a4)
	local ok, err = pcall(function()
		if event == "UNIT_SPELLCAST_SENT" then
			-- unit, målets namn, castGUID, spellID
			local target = ns.clean(a2)
			if type(target) == "string" and target ~= "" then lastSentTarget = target else lastSentTarget = nil end
			local guid = ns.clean(a3)
			if guid then sent[guid] = lastSentTarget end
		elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
			local id = ns.clean(a3)
			if type(id) == "number" then
				HU:OnCast(ns.canon(ns.get(C_Spell.GetSpellName, id)), ns.clean(a2))
			end
		elseif event == "UNIT_SPELLCAST_START" then
			if swing and InCombatLockdown() then swing, swingOff = nil, nil end
		end
	end)
	if not ok then ns.report(err) end
end)

function HU:SetShown(show)
	ns.char.bars.hud.show = show
	self:Layout()
end

function HU:Refresh() self:Layout() end

function HU:OnShamanLogin()
	self:Build()
	for _, e in ipairs({ "UNIT_SPELLCAST_SENT", "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_START" }) do
		pcall(castFrame.RegisterUnitEvent, castFrame, e, "player")
	end
	ns.on("PLAYER_SWING", function(_, dur, kind) HU:OnSwing(dur, kind) end)
	ns.on("PLAYER_LEAVE_COMBAT", function() swing, swingOff = nil, nil end)
	ns.on("PLAYER_DEAD", function() swing, swingOff, flame = nil, nil, nil; wipe(riptides); wipe(busy) end)
	for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "BAG_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN" }) do
		ns.on(e, function() HU:UpdateCooldowns() end)
	end
	ns.on("PLAYER_EQUIPMENT_CHANGED", function() ns.afterCombat("hud-layout", function() HU:Layout() end) end)
	ns.listen("SPELLS_CHANGED", function() HU:Layout() end)
	ns.listen("BARS_LAYOUT", function() HU:Layout() end)
	ns.listen("HUD_CHANGED", function() HU:Layout() end)
	ns.every(1, "hud-cooldowns", function() HU:UpdateCooldowns() end)
	self:Layout()
end
