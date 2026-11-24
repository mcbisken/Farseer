-- Procs och larm: Maelstrom Weapon-stackar, laddningar på skölden, Windfury-procs, låg mana, purge på
-- target, fiendens casts (kick!), diminishing returns och Blizzards förslag på nästa spell.
-- Allt är vanliga (osäkra) ramar som uppdateras även i strid. När spelet gör värden secret visas de
-- ändå där det går (texter och bars tar emot secret-värden), men logik som jämför tal (ljud, varningar)
-- körs bara när värdet går att läsa.

local _, ns = ...
local PC = ns.module("Procs")

local frame, wfText, castBar, drText
local icons = {}
local mwLast, mwInstance, shieldInstance
local wf = { count = 0, shownAt = -100, at = -100 }
local manaArmed = true
local purgeWarned = {}
local casts = {}         -- [unit] = { name, start, ends, notInt, channel }
local dr = {}            -- [enhet] = { [kategori] = { start, dur, level, immune } }

local function cfg() return ns.char.procs end

---------------------------------------------------------------------------------------------------
-- Läsning
---------------------------------------------------------------------------------------------------
-- Auran på dig: tabell (kan innehålla secret-fält), eller nil. instanceID används om uppslaget blockeras.
local function playerAura(ids, name, instanceID)
	local U = C_UnitAuras
	if not U then return nil end
	if U.GetPlayerAuraBySpellID then
		for _, id in ipairs(ids or {}) do
			local ok, a = pcall(U.GetPlayerAuraBySpellID, id)
			if ok and (ns.isSecret(a) or a ~= nil) then return a end
		end
	end
	if name and U.GetAuraDataBySpellName then
		local ok, a = pcall(U.GetAuraDataBySpellName, "player", ns.L(name), "HELPFUL")
		if ok and (ns.isSecret(a) or a ~= nil) then return a end
	end
	if instanceID and U.GetAuraDataByAuraInstanceID then
		local ok, a = pcall(U.GetAuraDataByAuraInstanceID, "player", instanceID)
		if ok and (ns.isSecret(a) or a ~= nil) then return a end
	end
	return nil
end
PC.playerAura = playerAura

-- Stacks/laddningar: tal, eller nil + det råa secret-värdet (kan bara visas, inte jämföras)
local function applications(a)
	if a == nil then return 0 end
	if ns.isSecret(a) then return nil end
	local ok, v = pcall(function() return a.applications end)
	if not ok then return nil end
	if ns.isSecret(v) then return nil, v end
	return tonumber(v) or 0
end
PC.applications = applications

local function instanceOf(a)
	if a == nil or ns.isSecret(a) then return nil end
	return ns.field(a, "auraInstanceID")
end

local function aurasSecret()
	return C_Secrets and C_Secrets.ShouldAurasBeSecret and ns.get(C_Secrets.ShouldAurasBeSecret) == true
end

---------------------------------------------------------------------------------------------------
-- Ramar
---------------------------------------------------------------------------------------------------
local function makeIcon(key, tip)
	local f = CreateFrame("Frame", "FarseerProc" .. key, frame)
	f.icon = f:CreateTexture(nil, "ARTWORK")
	f.icon:SetAllPoints()
	f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.count = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	f.count:SetPoint("BOTTOMRIGHT", -2, 2)
	f.glow = ns.addGlow(f, 0.4, 0.8, 1)
	f.key, f.tip = key, tip
	f:EnableMouse(true)
	f:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.title or self.key)
		local t = type(self.tip) == "function" and self.tip(self) or self.tip
		if t then GameTooltip:AddLine(t, 1, 1, 1, true) end
		GameTooltip:Show()
	end)
	f:SetScript("OnLeave", function() GameTooltip:Hide() end)
	f:Hide()
	icons[key] = f
	return f
end

-- Statusbar som fylls bara vid max: lyser när stacks == max även om talet är secret
local function makeSensor(parent, max)
	local s = CreateFrame("StatusBar", nil, parent)
	s:SetAllPoints()
	s:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
	s:SetStatusBarColor(0.4, 0.8, 1, 0.35)
	s:SetMinMaxValues(max - 1, max)
	s:SetValue(0)
	return s
end

local ORDER = { "maelstrom", "shield", "purge", "assisted" }

function PC:Build()
	local c = ns.char.bars.procs
	frame = CreateFrame("Frame", "FarseerProcs", UIParent)
	frame:SetSize(200, 40)
	ns.placeFrame(frame, c)
	ns.makeMovable(frame, c, "Farseer: procs och larm")
	local mw = makeIcon("maelstrom", "Maelstrom Weapon-stackar. Vid 5: lyser (och ljud om det går att läsa) — "
		.. "nästa Lightning Bolt/Chain Lightning/heal blir instant.")
	mw.title = "Maelstrom Weapon"
	mw.sensor = makeSensor(mw, ns.MAELSTROM_MAX or 5)
	local sh = makeIcon("shield", "Laddningar kvar på skölden. Röd siffra = snart slut, lägg om.")
	sh.title = "Sköld"
	makeIcon("purge", function(self)
		local names = {}
		for _, b in ipairs(self.buffs or {}) do table.insert(names, b.name or "?") end
		return "Target har buffar som Purge tar bort:\n" .. table.concat(names, "\n")
	end).title = "Purge"
	makeIcon("assisted", "Blizzards förslag på nästa spell (Assisted Combat), om klienten har det.").title = "Förslag"
	wfText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	wfText:SetPoint("BOTTOM", frame, "TOP", 0, 4)
	wfText:SetTextColor(0.65, 0.87, 1)
	castBar = CreateFrame("StatusBar", nil, frame)
	castBar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
	castBar:SetStatusBarColor(1, 0.7, 0)
	castBar:SetMinMaxValues(0, 1)
	castBar.bg = castBar:CreateTexture(nil, "BACKGROUND")
	castBar.bg:SetAllPoints()
	castBar.bg:SetColorTexture(0, 0, 0, 0.6)
	castBar.text = castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	castBar.text:SetPoint("LEFT", 4, 0)
	castBar.text:SetJustifyH("LEFT")
	castBar:Hide()
	drText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	drText:SetJustifyH("LEFT")
	self.castBar, self.wfText, self.drText = castBar, wfText, drText
	-- Timers och text 10 ggr/s, auror (Maelstrom, sköld, purge) 2,5 ggr/s
	frame:SetScript("OnUpdate", function(_, elapsed)
		frame.acc = (frame.acc or 0) + elapsed
		frame.slow = (frame.slow or 0) + elapsed
		if frame.acc < 0.1 then return end
		frame.acc = 0
		local full = frame.slow >= 0.4
		if full then frame.slow = 0 end
		local ok, err = pcall(full and PC.Update or PC.UpdateFast, PC)
		if not ok then ns.report(err) end
	end)
end

function PC:Layout()
	if not frame then return end
	local c = ns.char.bars.procs
	ns.placeFrame(frame, c)
	local size = c.size or 36
	local x = 0
	for _, key in ipairs(ORDER) do
		local f = icons[key]
		f:SetSize(size, size)
		f:ClearAllPoints()
		if f:IsShown() then
			f:SetPoint("TOPLEFT", frame, "TOPLEFT", x, 0)
			x = x + size + 4
		end
	end
	local width = math.max(200, x - 4)
	castBar:SetSize(width, 14)
	castBar:ClearAllPoints()
	castBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(size + 4))
	castBar.text:SetWidth(width - 8)
	drText:ClearAllPoints()
	drText:SetPoint("TOPLEFT", castBar, "BOTTOMLEFT", 0, -3)
	drText:SetWidth(width)
	frame:SetSize(width, size + 40)
	frame:SetShown(c.show and ns.isShaman)
end

local function setShown(f, show)
	if f:IsShown() ~= (show and true or false) then
		f:SetShown(show)
		PC.dirty = true
	end
end

-- Visar ett tal eller ett secret-värde (spelet ritar det, vi kan inte läsa det)
local function showCount(fs, n, raw, low)
	if n then
		fs:SetText(n > 0 and tostring(n) or "")
		if low then fs:SetTextColor(1, 0.25, 0.25) else fs:SetTextColor(1, 1, 1) end
	elseif raw ~= nil then
		if not pcall(fs.SetText, fs, raw) then fs:SetText("?") end
		fs:SetTextColor(1, 1, 1)
	else
		fs:SetText("")
	end
end

---------------------------------------------------------------------------------------------------
-- Maelstrom Weapon
---------------------------------------------------------------------------------------------------
function PC:Maelstrom()
	local a = playerAura(ns.MAELSTROM_BUFF, "Maelstrom Weapon", mwInstance)
	local inst = instanceOf(a)
	if inst then mwInstance = inst elseif a == nil then mwInstance = nil end
	return applications(a)
end

function PC:UpdateMaelstrom()
	local f = icons.maelstrom
	if not (cfg().maelstrom and ns.Spellbook:Knows("Maelstrom Weapon")) then setShown(f, false) return end
	local n, raw = self:Maelstrom()
	local max = ns.MAELSTROM_MAX or 5
	f.icon:SetTexture(ns.spellIcon("Maelstrom Weapon"))
	setShown(f, InCombatLockdown() or (n ~= 0))
	showCount(f.count, n, raw)
	pcall(f.sensor.SetValue, f.sensor, n or raw or 0)
	if n then
		f.icon:SetDesaturated(n == 0)
		if n >= max then
			f.glow:On()
			if (mwLast or 0) < max and cfg().maelstromSound then
				pcall(PlaySound, SOUNDKIT and SOUNDKIT.ALARM_CLOCK_WARNING_3 or 12889, "Master")
			end
		else
			f.glow:Off()
		end
		mwLast = n
	else
		f.icon:SetDesaturated(false)
		f.glow:Off()
	end
end

---------------------------------------------------------------------------------------------------
-- Sköldladdningar
---------------------------------------------------------------------------------------------------
-- Returnerar sköldens namn, laddningar (tal eller nil), rått secret-värde
function PC:Shield()
	for _, s in ipairs(ns.SHIELDS) do
		if ns.Spellbook:Knows(s) then
			local a = playerAura(ns.SHIELD_IDS[s], s, shieldInstance)
			if a ~= nil then
				shieldInstance = instanceOf(a) or shieldInstance
				local n, raw = applications(a)
				-- 0 stacks på en aura som finns = klienten räknar inte laddningar: visa skölden utan siffra
				if n == 0 then return s, nil, nil end
				return s, n, raw
			end
		end
	end
	shieldInstance = nil
	return nil
end

function PC:UpdateShield()
	local f = icons.shield
	if not cfg().shield then
		setShown(f, false)
		if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(nil) end
		return
	end
	local s, n, raw = self:Shield()
	if not s then
		setShown(f, false)
		if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(nil) end
		return
	end
	local low = n ~= nil and n <= (cfg().shieldLow or 1)
	f.icon:SetTexture(ns.spellIcon(s))
	f.title = s
	setShown(f, true)
	showCount(f.count, n, raw, low)
	if low then f.glow:On() else f.glow:Off() end
	if ns.Reminders.SetShieldCharges then ns.Reminders:SetShieldCharges(n, raw, low) end
end

---------------------------------------------------------------------------------------------------
-- Windfury
---------------------------------------------------------------------------------------------------
local function wfKind(id)
	local kind = ns.WINDFURY_PROCS[id]
	if kind then return kind end
	local name = ns.canon(ns.get(C_Spell.GetSpellName, id))
	return name and ns.WINDFURY_NAMES[name] or nil
end

local function strictKnown(id)
	if C_SpellBook and C_SpellBook.IsSpellKnown and ns.get(C_SpellBook.IsSpellKnown, id) == true then return true end
	return false
end

local function onGCD(id)
	local info = C_Spell and C_Spell.GetSpellCooldown and ns.get(C_Spell.GetSpellCooldown, id)
	return ns.field(info, "isOnGCD") == true
end

-- SPELL_UPDATE_COOLDOWN med proc-spellens ID = Windfury slog
function PC:OnCooldownEvent(id)
	if not cfg().windfury or not InCombatLockdown() then return end
	if type(id) ~= "number" or ns.isSecret(id) or id == 439431 then return end
	local kind = wfKind(id)
	if not kind or strictKnown(id) or onGCD(id) then return end
	local now = GetTime()
	if now == wf.at then return end
	wf.at = now
	self:WindfuryProc(kind)
end

function PC:WindfuryProc(kind)
	wf.count = wf.count + 1
	wf.shownAt = GetTime()
	wfText:SetText(kind == "totem" and "WINDFURY! (totem)" or "WINDFURY!")
	wfText:SetAlpha(1)
	wfText:Show()
	if cfg().windfurySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.UI_70_ARTIFACT_FORGE_TRAIT_GOLDTRAIT or 8960, "SFX") end
	ns.fire("WINDFURY_PROC", kind, wf.count)
end

function PC:WindfuryCount() return wf.count end

local function updateWindfuryText(now)
	local age = now - wf.shownAt
	if age < 1.2 then
		wfText:SetAlpha(age < 0.6 and 1 or (1.2 - age) / 0.6)
	elseif wfText:IsShown() then
		wfText:Hide()
	end
end

---------------------------------------------------------------------------------------------------
-- Låg mana
---------------------------------------------------------------------------------------------------
function PC:ManaPct()
	local cur, max = ns.get(UnitPower, "player", 0), ns.get(UnitPowerMax, "player", 0)
	if type(cur) == "number" and type(max) == "number" and max > 0 then return cur / max * 100 end
	return nil
end

local function ready(spell)
	if not ns.Spellbook:Knows(spell) then return false end
	local id = ns.Spellbook:ID(spell)
	local info = id and C_Spell and C_Spell.GetSpellCooldown and ns.get(C_Spell.GetSpellCooldown, id)
	local dur = ns.field(info, "duration")
	if dur == nil then return true end   -- okänt: föreslå ändå
	return dur <= 1.5
end

-- Bästa förslaget: spell, text
function PC:ManaAdvice()
	if ready("Mana Tide Totem") then return "Mana Tide Totem", "Lägg Mana Tide Totem (fyller gruppens mana i 12 s)." end
	if ns.Spellbook:Knows("Water Shield") then
		local a = playerAura(ns.SHIELD_IDS["Water Shield"], "Water Shield")
		if a == nil then return "Water Shield", "Byt till Water Shield — den ger mana när du blir träffad." end
	end
	if ns.Spellbook:Knows("Mana Spring Totem") and not ns.Totems:Active("Mana Spring Totem") then
		return "Mana Spring Totem", "Lägg Mana Spring Totem."
	end
	return nil, "Downranka healen, använd en mana potion eller drick efter striden."
end

function PC:CheckMana()
	local c = cfg()
	if not c.mana then return end
	local pct = self:ManaPct()
	if not pct then return end
	local limit = c.manaPct or 25
	if pct > limit + 15 or not InCombatLockdown() then
		manaArmed = true
		return
	end
	if pct < limit and manaArmed then
		manaArmed = false
		local spell, text = self:ManaAdvice()
		ns.Alert:Flash("lowmana", spell or "Mana Spring Totem", string.format("LÅG MANA (%d %%)", math.floor(pct)), text,
			{ 0.3, 0.55, 1 }, 4)
	end
end

---------------------------------------------------------------------------------------------------
-- Purge
---------------------------------------------------------------------------------------------------
local function hostile(unit)
	return ns.get(UnitExists, unit) == true and ns.get(UnitCanAttack, "player", unit) == true
		and ns.get(UnitIsDeadOrGhost, unit) ~= true
end
-- Som hostile, men secret (okänt) räknas som kanske fientlig: bara säkert vänliga/döda/saknade sorteras bort
local function maybeHostile(unit)
	return ns.get(UnitExists, unit) ~= false and ns.get(UnitCanAttack, "player", unit) ~= false
		and ns.get(UnitIsDeadOrGhost, unit) ~= true
end

-- Buffar på enheten som Purge tar bort (magiska). nil = går inte att läsa just nu.
function PC:Purgeable(unit)
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
	if not fn then return nil end
	local out = {}
	for i = 1, 40 do
		local ok, a = pcall(fn, unit, i, "HELPFUL")
		if not ok or ns.isSecret(a) then return nil end
		if a == nil then break end
		local disp = ns.field(a, "dispelName")
		if disp == "Magic" then
			table.insert(out, { name = ns.field(a, "name"), icon = ns.field(a, "icon"), id = ns.field(a, "spellId") })
		end
	end
	return out
end

function PC:UpdatePurge()
	local f = icons.purge
	if not (cfg().purge and ns.Spellbook:Knows("Purge") and maybeHostile("target")) then setShown(f, false) return end
	local list = self:Purgeable("target")
	if list == nil then return end   -- secret: behåll det vi visade
	f.buffs = list
	if #list == 0 then setShown(f, false) return end
	f.icon:SetTexture(list[1].icon or ns.spellIcon("Purge"))
	f.count:SetText(#list > 1 and tostring(#list) or "")
	f.count:SetTextColor(1, 1, 1)
	f.glow:On()
	setShown(f, true)
	if cfg().purgeAlertPvp and ns.Bars:Mode() == "PVP" then
		local guid = ns.get(UnitGUID, "target") or "target"
		local key = guid .. ":" .. tostring(list[1].name)
		if not purgeWarned[key] then
			purgeWarned[key] = true
			ns.Alert:Flash("purge", "Purge", "PURGE: " .. tostring(list[1].name or "buff"):upper(),
				"Target har " .. #list .. " buff(ar) som Purge tar bort.", { 0.75, 0.45, 1 }, 2.5)
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Fiendens casts
---------------------------------------------------------------------------------------------------
local UNIT_LABEL = { target = "Target", focus = "Focus" }

function PC:ReadCast(unit)
	local ok, name, _, _, startMS, endMS, _, _, notInt = ns.getAll(UnitCastingInfo, unit)
	local channel = false
	if not (ok and (name or startMS)) then
		ok, name, _, _, startMS, endMS, _, notInt = ns.getAll(UnitChannelInfo, unit)
		channel = true
		if not (ok and (name or startMS)) then return nil end
	end
	return { name = name, start = startMS and startMS / 1000 or GetTime(), ends = endMS and endMS / 1000 or nil,
		notInt = notInt, channel = channel }
end

function PC:OnUnitCast(event, unit)
	if UNIT_LABEL[unit] == nil or not cfg().enemyCasts then return end
	if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
		if not maybeHostile(unit) then casts[unit] = nil return end
		local c = self:ReadCast(unit) or { start = GetTime(), channel = event == "UNIT_SPELLCAST_CHANNEL_START" }
		c.unit = unit
		casts[unit] = c
		if cfg().enemyCastAlertPvp and ns.Bars:Mode() == "PVP" and c.notInt ~= true then
			local kick = ns.Spellbook:Knows("Earth Shock") and "Earth Shock" or "Grounding Totem"
			ns.Alert:Flash("cast-" .. unit, kick, "KICK! " .. (c.name and c.name:upper() or (UNIT_LABEL[unit]:upper() .. " CASTAR")),
				"Earth Shock avbryter. Grounding Totem tar en spell som riktas mot dig.", { 1, 0.35, 0.2 }, 1.5)
		end
	elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
		if casts[unit] then casts[unit].notInt = true end
	elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
		if casts[unit] then casts[unit].notInt = false end
	elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		-- SUCCEEDED kommer när en channel börjar och FAILED kan gälla ett annat castförsök: de avslutar inget
		casts[unit] = nil
	end
end

function PC:CurrentCast()
	local now = GetTime()
	for _, unit in ipairs({ "target", "focus" }) do
		local c = casts[unit]
		if c then
			if (c.ends and c.ends < now) or now - c.start > 15 then casts[unit] = nil else return c end
		end
	end
end

function PC:UpdateCast(now)
	local c = cfg().enemyCasts and self:CurrentCast()
	if not c then castBar:Hide() return end
	local label = UNIT_LABEL[c.unit] or c.unit
	local kick = c.notInt == true and "  |cff999999(kan inte avbrytas)|r"
		or (ns.Spellbook:Knows("Earth Shock") and "  |cffff6040Earth Shock!|r" or "")
	local left = c.ends and (c.ends - now)
	castBar.text:SetText(string.format("%s: %s%s%s", label, c.name or "castar", left and string.format(" %.1f", left) or "", kick))
	if c.ends and c.ends > c.start then
		local p = (now - c.start) / (c.ends - c.start)
		castBar:SetValue(c.channel and (1 - p) or p)
	elseif not c.timer then
		-- Secret: spelets duration-objekt driver baren om det går
		c.timer = true
		local fn = c.channel and UnitChannelDuration or UnitCastingDuration
		local ok, d = pcall(fn, c.unit)
		local set = false
		if ok and d and castBar.SetTimerDuration then
			-- Channels töms (återstående tid), vanliga casts fylls
			local dir = c.channel and Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime
			if dir ~= nil then set = pcall(castBar.SetTimerDuration, castBar, d, nil, dir) end
			if not set then set = pcall(castBar.SetTimerDuration, castBar, d) end
		end
		if not set then castBar:SetValue(1) end
	end
	castBar:SetStatusBarColor(c.notInt == true and 0.6 or 1, c.notInt == true and 0.6 or 0.7, c.notInt == true and 0.6 or 0)
	castBar:Show()
end

---------------------------------------------------------------------------------------------------
-- Diminishing returns
---------------------------------------------------------------------------------------------------
local function unitKey(unit)
	return ns.get(UnitGUID, unit) or unit
end

local function categoryName(cat)
	local S = C_SpellDiminish
	if S and S.GetSpellDiminishCategoryInfo then
		local info = ns.get(S.GetSpellDiminishCategoryInfo, cat)
		local n = ns.field(info, "name")
		if type(n) == "string" then return n end
	end
	return "Kategori " .. tostring(cat)
end

function PC:OnDiminish(unit, info)
	if type(unit) ~= "string" or ns.isSecret(unit) then return end
	local cat = ns.field(info, "category")
	if cat == nil then return end
	local key = unitKey(unit)
	dr[key] = dr[key] or {}
	local now = GetTime()
	local cur = dr[key][cat]
	local start = ns.field(info, "startTime")
	local dur = ns.field(info, "duration")
	local level = 1
	if cur and now < cur.start + cur.dur then level = cur.level + ((start == nil or start ~= cur.rawStart) and 1 or 0) end
	dr[key][cat] = {
		rawStart = start, start = (type(start) == "number" and start > 0) and start or now,
		dur = (type(dur) == "number" and dur > 0) and dur or (ns.DR_RESET or 18),
		level = level, immune = ns.field(info, "isImmune") == true,
	}
end

-- DR på enheten: { { name, text, left } }
function PC:Diminish(unit)
	local key = unitKey(unit)
	local list, now = {}, GetTime()
	for cat, d in pairs(dr[key] or {}) do
		local left = d.start + d.dur - now
		if left > 0 then
			local state = (d.immune or d.level >= 3) and "|cffff4040immun|r" or (d.level == 2 and "|cffffd10025 %|r" or "|cff40ff4050 %|r")
			table.insert(list, { name = categoryName(cat), text = state, left = left })
		else
			dr[key][cat] = nil
		end
	end
	table.sort(list, function(a, b) return a.name < b.name end)
	return list
end

function PC:UpdateDR()
	if not cfg().dr or not ns.get(UnitExists, "target") then drText:SetText("") return end
	local parts = {}
	for _, d in ipairs(self:Diminish("target")) do
		table.insert(parts, string.format("%s %s %d s", d.name, d.text, math.ceil(d.left)))
	end
	drText:SetText(#parts > 0 and ("DR: " .. table.concat(parts, "   ")) or "")
end

---------------------------------------------------------------------------------------------------
-- Blizzards förslag (Assisted Combat)
---------------------------------------------------------------------------------------------------
function PC:Suggestion()
	local A = C_AssistedCombat
	if not (A and A.GetNextCastSpell) then return nil end
	local id = ns.get(A.GetNextCastSpell)
	if type(id) == "number" and id > 0 then return id end
	return nil
end

function PC:UpdateAssisted()
	local f = icons.assisted
	local id = cfg().assisted and self:Suggestion()
	if not id then setShown(f, false) return end
	f.icon:SetTexture(ns.get(C_Spell.GetSpellTexture, id) or 134400)
	f.title = ns.get(C_Spell.GetSpellName, id) or "Förslag"
	setShown(f, true)
end

---------------------------------------------------------------------------------------------------
-- Det som rör sig: Windfury-texten, castbaren, DR-tider
function PC:UpdateFast()
	if not frame or not frame:IsShown() then return end
	local now = GetTime()
	updateWindfuryText(now)
	self:UpdateCast(now)
	self:UpdateDR()
	if self.dirty then
		self.dirty = false
		self:Layout()
	end
end

function PC:Update()
	if not frame or not frame:IsShown() then return end
	self:UpdateMaelstrom()
	self:UpdateShield()
	self:UpdatePurge()
	self:UpdateAssisted()
	self:UpdateFast()
end

function PC:SetShown(show)
	ns.char.bars.procs.show = show
	self:Layout()
end

function PC:Refresh() self:Layout(); self:Update() end

local castFrame = CreateFrame("Frame")
castFrame:SetScript("OnEvent", function(_, event, unit)
	local ok, err = pcall(PC.OnUnitCast, PC, event, unit)
	if not ok then ns.report(err) end
end)

function PC:OnShamanLogin()
	self:Build()
	self:Layout()
	for _, e in ipairs({ "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START",
		"UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
		"UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" }) do
		pcall(castFrame.RegisterUnitEvent, castFrame, e, "target", "focus")
	end
	ns.on("PLAYER_TARGET_CHANGED", function()
		casts.target = nil
		local c = hostile("target") and PC:ReadCast("target")
		if c then c.unit = "target"; casts.target = c end
	end)
	ns.on("PLAYER_FOCUS_CHANGED", function() casts.focus = nil end)
	ns.on("SPELL_UPDATE_COOLDOWN", function(_, id) PC:OnCooldownEvent(id) end)
	ns.on("UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED", function(_, unit, info) PC:OnDiminish(unit, info) end)
	ns.listen("COMBAT_START", function() wf.count = 0 end)
	ns.listen("COMBAT_END", function() wipe(purgeWarned); manaArmed = true end)
	ns.listen("BARS_LAYOUT", function() PC:Layout() end)
	ns.listen("PROCS_CHANGED", function() PC:Refresh() end)
	ns.listen("SPELLS_CHANGED", function() PC:Refresh() end)
	C_Timer.NewTicker(0.5, function()
		local ok, err = pcall(PC.CheckMana, PC)
		if not ok then ns.report(err) end
	end)
end
