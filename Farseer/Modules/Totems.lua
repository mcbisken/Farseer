-- Aktiva totems: följer dina egna casts (alltid läsbara) och klientens totemslottar (när de inte är
-- secret). Visar en timer-bar med en knapp per element; högerklick tar bort totemet.

local _, ns = ...
local TO = ns.module("Totems")

local state = {}   -- [slot] = { name, start, dur }
local lastCast, destroyed = {}, {}   -- [slot] = GetTime() för egen cast / högerklick-borttagning
local lastRecall = -100

local function baseName(name)
	if type(name) ~= "string" then return nil end
	-- Klassiska klienter lägger till rank i romerska siffror: "Searing Totem VI". Tillbaka till engelska.
	return ns.canon((name:gsub("%s+[IVXL]+$", "")))
end
TO.baseName = baseName

local function defaultDur(name)
	local learned = ns.char and ns.char.learnedDur[name]
	if learned then return learned end
	local t = ns.TOTEMS[name]
	return t and t.dur or 60
end

local function setSlot(slot, name, start, dur)
	if not name then state[slot] = nil return end
	state[slot] = { name = name, start = start or GetTime(), dur = dur or defaultDur(name) }
end

-- Läs klientens slot. Returnerar true om läsningen gick (inte secret).
function TO:ReadSlot(slot)
	if not GetTotemInfo then return false end
	local ok, have, name, start, dur = ns.getAll(GetTotemInfo, slot)
	if not ok or have == nil then return false end
	name = baseName(name)
	if not have or not name or name == "" then
		state[slot] = nil
		return true
	end
	if start and dur and dur > 0 then
		setSlot(slot, name, start, dur)
		if not InCombatLockdown() then ns.char.learnedDur[name] = math.floor(dur + 0.5) end
	elseif not state[slot] or state[slot].name ~= name then
		setSlot(slot, name)
	end
	return true
end

function TO:ReadAll()
	for slot = 1, 4 do self:ReadSlot(slot) end
end

local function expire()
	local now = GetTime()
	for slot, s in pairs(state) do
		if s.start + s.dur < now then state[slot] = nil end
	end
end

-- Är ett totem med det namnet ute? Returnerar slot eller nil.
function TO:Active(name)
	expire()
	for slot, s in pairs(state) do
		if s.name == name then return slot end
	end
	return nil
end

function TO:SlotTotem(slot)
	expire()
	local s = state[slot]
	return s and s.name or nil
end

function TO:Remaining(slot)
	local s = state[slot]
	if not s then return nil end
	return math.max(0, s.start + s.dur - GetTime())
end

function TO:Count()
	expire()
	local n = 0
	for _ in pairs(state) do n = n + 1 end
	return n
end

-- Sekunder till Tremor Totems nästa puls (pulsar direkt när den sätts, sedan var 4:e sekund)
function TO:TremorPulse(now)
	local slot = self:Active("Tremor Totem")
	if not slot then return nil end
	local p = ns.TREMOR_PULSE or 4
	local since = (now or GetTime()) - state[slot].start
	return p - (since % p)
end

---------------------------------------------------------------------------------------------------
-- Totemet dog i förtid (förstört, eller Grounding åt en spell)
---------------------------------------------------------------------------------------------------
local IMPORTANT = { ["Grounding Totem"] = true, ["Tremor Totem"] = true, ["Earthbind Totem"] = true,
	["Poison Cleansing Totem"] = true, ["Disease Cleansing Totem"] = true, ["Windfury Totem"] = true,
	["Mana Spring Totem"] = true, ["Healing Stream Totem"] = true, ["Strength of Earth Totem"] = true,
	["Grace of Air Totem"] = true, ["Stoneclaw Totem"] = false, ["Searing Totem"] = false, ["Magma Totem"] = false }
TO.IMPORTANT = IMPORTANT

function TO:CheckDeath(slot, prev)
	local cfg = ns.char.totemAlerts
	if not prev or not cfg or not cfg.death then return end
	local now = GetTime()
	if prev.start + prev.dur - now < 2 then return end                 -- gick ut av sig själv
	if now - (lastCast[slot] or -100) < 1.5 then return end           -- du satte ett nytt
	if now - lastRecall < 1.5 or now - (destroyed[slot] or -100) < 1.5 then return end
	if ns.get(UnitIsDeadOrGhost, "player") == true then return end
	-- Går slotten att läsa och totemet står kvar är allt som det ska
	if self:ReadSlot(slot) and state[slot] and state[slot].name == prev.name then return end
	state[slot] = nil
	self:UpdateBar()
	ns.fire("TOTEMS_CHANGED")
	if not cfg.allTotems and IMPORTANT[prev.name] ~= true then return end
	local grounding = prev.name == "Grounding Totem"
	local el = ns.Spellbook:TotemElement(prev.name)
	ns.Alert:Flash("died-" .. prev.name, prev.name,
		grounding and "GROUNDING ÅT EN SPELL!" or (prev.name:upper() .. " DOG!"),
		grounding and "Lägg ett nytt Grounding Totem (cooldown 15 s)." or "Totemet förstördes i förtid — lägg om det.",
		el and ns.ELEMENT_COLOR[el] or { 1, 0.4, 0.3 }, 3)
	ns.fire("TOTEM_DIED", prev.name, slot)
end

---------------------------------------------------------------------------------------------------
-- Utom räckhåll: ett buff-totem står kvar men dess buff finns inte på dig
-- Totemet väntar tills buffen setts på dig en gång (annars kan ett fel buff-ID ge falsklarm), och
-- auror som spelet gör secret (i strid) räknas som okänt: då ändras ingenting.
---------------------------------------------------------------------------------------------------
local range = {}   -- [slot] = { name, start, seen, miss, out, warned }

-- true = buffen är på dig, false = inte, nil = går inte att läsa
function TO:BuffState(name)
	local b = ns.TOTEM_BUFFS[name]
	local U = C_UnitAuras
	if not b or not U then return nil end
	if C_Secrets and C_Secrets.ShouldAurasBeSecret and ns.get(C_Secrets.ShouldAurasBeSecret) ~= false then return nil end
	if U.GetPlayerAuraBySpellID then
		for _, id in ipairs(b.ids) do
			local ok, a = pcall(U.GetPlayerAuraBySpellID, id)
			if not ok or ns.isSecret(a) then return nil end
			if a ~= nil then return true end
		end
	end
	if U.GetAuraDataBySpellName then
		local loc = ns.get(C_Spell.GetSpellName, b.ids[1])
		local names = (type(loc) == "string" and loc ~= b.name) and { loc, b.name } or { b.name }
		for _, n in ipairs(names) do
			local ok, a = pcall(U.GetAuraDataBySpellName, "player", n, "HELPFUL")
			if not ok or ns.isSecret(a) then return nil end
			if a ~= nil then return true end
		end
	end
	return false
end

function TO:OutOfRange(slot) return range[slot] and range[slot].out or false end

function TO:AnyOutOfRange()
	for slot in pairs(range) do if range[slot].out then return true end end
	return false
end

function TO:CheckRange()
	local cfg = ns.char.totemAlerts
	local now = GetTime()
	expire()
	for slot = 1, 4 do
		local s = state[slot]
		local r = range[slot]
		if not s or not ns.TOTEM_BUFFS[s.name] or not cfg.range then
			range[slot] = nil
		else
			if not r or r.name ~= s.name or math.abs(r.start - s.start) > 1 then
				r = { name = s.name, start = s.start, seen = false, miss = 0, out = false }
				range[slot] = r
			end
			if now - s.start >= 3 then
				local st = self:BuffState(s.name)
				if st == true then
					r.seen, r.miss, r.out = true, 0, false
				elseif st == false and r.seen then
					r.miss = r.miss + 1
					if r.miss >= 2 and not r.out then
						r.out = true
						if cfg.rangeAlert and not r.warned then
							r.warned = true
							local el = ns.Spellbook:TotemElement(s.name)
							local call = ns.Spellbook:Knows(ns.TOTEMIC_CALL)
							ns.Alert:Flash("range-" .. slot, call and ns.TOTEMIC_CALL or s.name, "UTOM TOTEMRÄCKHÅLL",
								s.name .. " når dig inte. " .. (call and "Tryck Totemic Call (flyttar totems till dig) eller gå närmare."
									or "Gå närmare eller lägg om det."),
								el and ns.ELEMENT_COLOR[el] or { 1, 0.5, 0.2 }, 3)
							ns.fire("TOTEM_OUT_OF_RANGE", s.name, slot)
						end
					end
				end
			end
		end
	end
	self:UpdateRangeMarks()
end

-- Multicast-actionslotten för Call-set (1-3) och totemslot (1-4)
function TO:MultiCastAction(set, slot)
	local bar = C_ActionBar and ns.get(C_ActionBar.GetMultiCastBarIndex)
	if type(bar) ~= "number" then bar = 12 end
	return (bar - 1) * 12 + (set - 1) * 4 + slot
end

-- Vad Call-setet innehåller just nu: [slot] = totemnamn
function TO:CallSetContents(set)
	local out = {}
	for slot = 1, 4 do
		local ok, kind, id = ns.getAll(GetActionInfo, self:MultiCastAction(set, slot))
		if ok and kind == "spell" and type(id) == "number" then
			out[slot] = baseName(ns.get(C_Spell.GetSpellName, id))
		end
	end
	return out
end

---------------------------------------------------------------------------------------------------
-- Egna casts
---------------------------------------------------------------------------------------------------
local function onCast(spellID)
	if type(spellID) ~= "number" or ns.isSecret(spellID) then return end
	local name = baseName(ns.get(C_Spell.GetSpellName, spellID))
	if not name then return end
	local now = GetTime()
	if name == ns.RECALL then
		wipe(state)
		lastRecall = now
	elseif name == ns.TOTEMIC_CALL then
		-- Totemen flyttas till dig: räckvidden börjar om (buffen kommer vid nästa puls)
		for _, r in pairs(range) do r.out, r.miss, r.warned = false, 0, false end
	elseif ns.Spellbook:IsTotem(name) then
		local el = ns.Spellbook:TotemElement(name)
		if el then
			setSlot(ns.SLOT[el], name)
			lastCast[ns.SLOT[el]] = now
		end
	else
		for set, call in ipairs(ns.CALLS) do
			if name == call then
				for slot, totem in pairs(TO:CallSetContents(set)) do
					setSlot(slot, totem)
					lastCast[slot] = now
				end
			end
		end
	end
	ns.fire("PLAYER_CAST", name, spellID)
	TO:UpdateBar()
	ns.fire("TOTEMS_CHANGED")
end

local castFrame = CreateFrame("Frame")
castFrame:SetScript("OnEvent", function(_, event, unit, _, spellID)
	if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" then
		local ok, err = pcall(onCast, spellID)
		if not ok then ns.report(err) end
	end
end)

---------------------------------------------------------------------------------------------------
-- Timer-bar
---------------------------------------------------------------------------------------------------
local bar, buttons = nil, {}

local function fmtTime(s)
	if s >= 60 then return string.format("%d:%02d", math.floor(s / 60), math.floor(s % 60)) end
	return string.format("%d", math.floor(s + 0.5))
end

function TO:BuildBar()
	local cfg = ns.char.bars.totems
	bar = CreateFrame("Frame", "FarseerTotemBar", UIParent)
	local size = cfg.size or 34
	bar:SetSize(size * 4 + 3 * 3, size)
	ns.placeFrame(bar, cfg)
	ns.makeMovable(bar, cfg, "Farseer: totem-timers")
	for i, el in ipairs(ns.ELEMENTS) do
		local slot = ns.SLOT[el]
		local b = CreateFrame("Button", "FarseerTotem" .. el, bar, "SecureActionButtonTemplate")
		b:SetSize(size, size)
		b:SetPoint("LEFT", bar, "LEFT", (i - 1) * (size + 3), 0)
		b:RegisterForClicks("AnyUp", "AnyDown")
		b:SetAttribute("*type2", "destroytotem")
		b:SetAttribute("totem-slot", slot)
		local c = ns.ELEMENT_COLOR[el]
		b.bg = b:CreateTexture(nil, "BACKGROUND")
		b.bg:SetAllPoints()
		b.bg:SetColorTexture(c[1] * 0.3, c[2] * 0.3, c[3] * 0.3, 0.8)
		b.icon = b:CreateTexture(nil, "ARTWORK")
		b.icon:SetPoint("TOPLEFT", 2, -2)
		b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
		b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		b.edge = b:CreateTexture(nil, "BORDER")
		b.edge:SetAllPoints()
		b.edge:SetColorTexture(c[1], c[2], c[3], 0.9)
		b.cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
		b.cd:SetAllPoints(b.icon)
		b.cd:SetDrawEdge(false)
		pcall(b.cd.SetHideCountdownNumbers, b.cd, true)
		b.time = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
		b.time:SetPoint("BOTTOM", b, "BOTTOM", 0, 2)
		b.slot, b.el = slot, el
		b.pulse = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.pulse:SetPoint("TOP", b, "TOP", 0, -2)
		b:SetScript("PreClick", function(self, button)
			if button == "RightButton" then destroyed[self.slot] = GetTime() end
		end)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			local name = TO:SlotTotem(self.slot)
			if not (GameTooltip.SetTotem and pcall(GameTooltip.SetTotem, GameTooltip, self.slot)) or not name then
				GameTooltip:SetText(ns.ELEMENT_NAME[self.el] .. "-totem")
				GameTooltip:AddLine(name or "Inget totem ute", 1, 1, 1)
			end
			GameTooltip:AddLine("Högerklick: ta bort totemet", 0.6, 0.8, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		b.range = b:CreateTexture(nil, "OVERLAY")
		b.range:SetAllPoints(b.icon)
		b.range:SetColorTexture(1, 0, 0, 0.35)
		b.range:Hide()
		b.rangeText = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		b.rangeText:SetPoint("CENTER", b, "CENTER", 0, 0)
		b.rangeText:SetTextColor(1, 0.3, 0.3)
		buttons[slot] = b
	end
	-- Totemic Call (flytta totems till dig), högerklick Totemic Recall
	local cb = CreateFrame("Button", "FarseerTotemicCall", bar, "SecureActionButtonTemplate")
	cb:SetSize(size, size)
	cb:SetPoint("LEFT", bar, "LEFT", 4 * (size + 3) + 4, 0)
	cb:RegisterForClicks("AnyUp", "AnyDown")
	cb.icon = cb:CreateTexture(nil, "ARTWORK")
	cb.icon:SetAllPoints()
	cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	cb.glow = ns.addGlow(cb, 1, 0.3, 0.3)
	cb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText("Totemic Call")
		GameTooltip:AddLine("Klick: flytta dina aktiva totems till dig. Lyser när ett totem är utom räckhåll.", 1, 1, 1, true)
		GameTooltip:AddLine("Högerklick: Totemic Recall (plocka upp dem)", 0.6, 0.8, 1)
		GameTooltip:Show()
	end)
	cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
	cb:Hide()
	self.callButton = cb
	_G["BINDING_NAME_CLICK FarseerTotemicCall:LeftButton"] = "Totemic Call"
	bar:SetShown(cfg.show)
	self:ApplyCallButton()
	-- Timertext uppdateras ofta, ikoner/cooldown bara vid ändringar
	C_Timer.NewTicker(0.25, function() TO:UpdateTimes() end)
	C_Timer.NewTicker(1, function()
		local ok, err = pcall(TO.CheckRange, TO)
		if not ok then ns.report(err) end
	end)
end

-- Totemic Call-knappen: spells och synlighet (skyddad knapp: bara utanför strid)
function TO:ApplyCallButton()
	local cb = self.callButton
	if not cb then return end
	ns.afterCombat("totemic-call", function()
		local show = ns.char.totemAlerts.callButton and ns.Spellbook:Knows(ns.TOTEMIC_CALL)
		cb:SetAttribute("type1", show and "spell" or nil)
		cb:SetAttribute("spell1", show and ns.L(ns.TOTEMIC_CALL) or nil)
		local recall = ns.Spellbook:Knows(ns.RECALL)
		cb:SetAttribute("type2", recall and "spell" or nil)
		cb:SetAttribute("spell2", recall and ns.L(ns.RECALL) or nil)
		cb.icon:SetTexture(ns.spellIcon(ns.TOTEMIC_CALL))
		cb:SetShown(show and true or false)
		local size = ns.char.bars.totems.size or 34
		bar:SetSize(size * 4 + 3 * 3 + (show and (size + 4) or 0), size)
	end)
end

function TO:UpdateRangeMarks()
	if not bar then return end
	for slot, b in pairs(buttons) do
		local out = self:OutOfRange(slot)
		b.range:SetShown(out)
		b.rangeText:SetText(out and "UTOM" or "")
	end
	if self.callButton then
		if self:AnyOutOfRange() then self.callButton.glow:On() else self.callButton.glow:Off() end
	end
end

function TO:UpdateTimes()
	if not bar then return end
	expire()
	local now = GetTime()
	local pulseOn = ns.char.totemAlerts == nil or ns.char.totemAlerts.tremorPulse ~= false
	for slot, b in pairs(buttons) do
		local r = self:Remaining(slot)
		b.time:SetText(r and fmtTime(r) or "")
		local s = state[slot]
		if pulseOn and s and s.name == "Tremor Totem" then
			b.pulse:SetText(string.format("|cffffd100%.1f|r", self:TremorPulse(now)))
		else
			b.pulse:SetText("")
		end
	end
end

function TO:UpdateBar()
	if not bar then return end
	expire()
	for slot, b in pairs(buttons) do
		local s = state[slot]
		if s then
			b.icon:SetTexture(ns.spellIcon(s.name))
			b.icon:SetDesaturated(false)
			b:SetAlpha(1)
			local done = false
			if GetTotemDuration and b.cd.SetCooldownFromDurationObject then
				local ok, d = pcall(GetTotemDuration, slot)
				if ok and d then done = pcall(b.cd.SetCooldownFromDurationObject, b.cd, d) end
			end
			if not done then pcall(b.cd.SetCooldown, b.cd, s.start, s.dur) end
		else
			b.icon:SetTexture(nil)
			b:SetAlpha(0.35)
			pcall(b.cd.Clear, b.cd)
		end
	end
	self:UpdateTimes()
end

---------------------------------------------------------------------------------------------------
function TO:OnShamanLogin()
	self:ReadAll()
	self:BuildBar()
	self:UpdateBar()
	castFrame:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
	ns.on("PLAYER_TOTEM_UPDATE", function(_, slot)
		if type(slot) == "number" and not ns.isSecret(slot) then
			local prev = state[slot] and ns.copy(state[slot])
			TO:ReadSlot(slot)
			-- Kolla strax efteråt: castens händelse kan komma efter slot-uppdateringen
			if prev then C_Timer.After(0.25, function() TO:CheckDeath(slot, prev) end) end
		else
			TO:ReadAll()
		end
		TO:UpdateBar()
		ns.fire("TOTEMS_CHANGED")
	end)
	ns.on("PLAYER_ENTERING_WORLD", function()
		TO:ReadAll()
		TO:UpdateBar()
	end)
	ns.on("PLAYER_DEAD", function()
		wipe(state)
		TO:UpdateBar()
		ns.fire("TOTEMS_CHANGED")
	end)
	ns.listen("COMBAT_END", function()
		TO:ReadAll()
		TO:UpdateBar()
	end)
	ns.listen("BARS_LAYOUT", function()
		ns.afterCombat("totembar-layout", function()
			local cfg = ns.char.bars.totems
			ns.placeFrame(bar, cfg)
			bar:SetShown(cfg.show)
		end)
		TO:ApplyCallButton()
	end)
	ns.listen("SPELLS_CHANGED", function() TO:ApplyCallButton() end)
end

function TO:SetShown(show)
	ns.char.bars.totems.show = show
	ns.afterCombat("totembar-show", function() if bar then bar:SetShown(show) end end)
end
