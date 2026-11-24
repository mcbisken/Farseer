-- Påminnelser: saknad sköld (Lightning/Water Shield) och saknad/utgående vapen-imbue (main hand och,
-- med dual wield, off-hand). Klickbara knappar som lyser upp när något saknas; klick castar rätt spell.

local _, ns = ...
local RE = ns.module("Reminders")

local MAIN_HAND = Enum and Enum.WeaponSlot and Enum.WeaponSlot.MainHand or 0
local OFF_HAND = Enum and Enum.WeaponSlot and Enum.WeaponSlot.OffHand or 1
local IMBUE_TYPE = Enum and Enum.ItemEnchantType and Enum.ItemEnchantType.Imbue or 3
local WEAPON_CLASS = Enum and Enum.ItemClass and Enum.ItemClass.Weapon or 2
-- Reserv om klassen inte går att läsa: utrustningsplatser som bara vapen har
local WEAPON_LOC = { INVTYPE_WEAPON = true, INVTYPE_WEAPONOFFHAND = true, INVTYPE_WEAPONMAINHAND = true, INVTYPE_2HWEAPON = true }

local bar, shieldBtn, imbueBtn, offBtn
local offActive = false   -- off-hand-knappen visas (sätts utanför strid i ApplySpells)
local status = { shield = nil, imbue = nil, imbueLeft = nil, off = nil, offLeft = nil }

-- true/false = har/har inte, nil = går inte att läsa just nu
local function hasAura(name)
	local fn = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
	if not fn then return nil end
	local ok, a = pcall(fn, "player", ns.L(name), "HELPFUL")
	if not ok or ns.isSecret(a) then return nil end
	return a ~= nil
end

function RE:ShieldUp()
	local any, unknown = false, false
	for _, s in ipairs(ns.SHIELDS) do
		local v = hasAura(s)
		if v == nil then unknown = true elseif v then any = true end
	end
	if any then return true end
	if unknown then return nil end
	return false
end

-- Temporär imbue på ett vapen. slot = Enum.WeaponSlot-värdet för C_Item-API:t, offset = var i
-- GetWeaponEnchantInfo()s returvärden vapnet börjar (0 = main hand, 4 = off-hand).
local function readImbue(slot, offset)
	if C_Item and C_Item.GetWeaponEnchantInfo then
		local ok, list = pcall(C_Item.GetWeaponEnchantInfo, slot)
		if ok and type(list) == "table" and not ns.isSecret(list) then
			for _, w in ipairs(list) do
				local has, kind, left = ns.field(w, "hasEnchant"), ns.field(w, "enchantType"), ns.field(w, "timeLeft")
				if has == nil or kind == nil then return nil end
				if has and kind == IMBUE_TYPE then return true, left and left / 1000 or nil end
			end
			return false
		end
	end
	if GetWeaponEnchantInfo then
		-- hasMainHandEnchant, mainHandExpiration (ms), mainHandCharges, mainHandEnchantID, hasOffHandEnchant, ...
		local r = { ns.getAll(GetWeaponEnchantInfo) }
		local has, exp = r[offset + 2], r[offset + 3]
		if r[1] and has ~= nil then
			return has and true or false, type(exp) == "number" and exp / 1000 or nil
		end
	end
	return nil
end

-- returnerar har (bool/nil), sekunder kvar (eller nil)
function RE:Imbue() return readImbue(MAIN_HAND, 0) end
function RE:OffhandImbue() return readImbue(OFF_HAND, 4) end

-- true = vapen i off-hand, false = inget vapen (tomt, sköld, off-hand-föremål), nil = okänt
function RE:OffhandWeapon()
	local pd = C_PaperDollInfo and C_PaperDollInfo.OffhandHasWeapon
	if pd then
		local v = ns.get(pd)
		if v ~= nil then return v and true or false end
	end
	local id = ns.get(GetInventoryItemID, "player", 17)
	if id == nil then return false end
	local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if not info then return nil end
	-- itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
	local ok, _, _, _, equipLoc, _, classID = ns.getAll(info, id)
	if not ok then return nil end
	if classID ~= nil then return classID == WEAPON_CLASS end
	if type(equipLoc) == "string" and equipLoc ~= "" then return WEAPON_LOC[equipLoc] == true end
	return nil
end

function RE:ShieldSpell()
	local cfg = ns.char.reminders
	if cfg.preferWaterShield and ns.Spellbook:Knows("Water Shield") then return "Water Shield" end
	if ns.Spellbook:Knows("Lightning Shield") then return "Lightning Shield" end
	if ns.Spellbook:Knows("Water Shield") then return "Water Shield" end
end

function RE:ImbueSpell()
	local pick = ns.char.reminders.imbueSpell
	if pick and pick ~= "auto" and ns.Spellbook:Knows(pick) then return pick end
	for _, s in ipairs({ "Windfury Weapon", "Flametongue Weapon", "Rockbiter Weapon" }) do
		if ns.Spellbook:Knows(s) then return s end
	end
end

-- Off-hand: "auto" = Flametongue Weapon (klassisk WF/FT-dual wield), annars samma som main hand
function RE:OffhandSpell()
	local pick = ns.char.reminders.offhandSpell
	if pick and pick ~= "auto" and ns.Spellbook:Knows(pick) then return pick end
	if ns.Spellbook:Knows("Flametongue Weapon") then return "Flametongue Weapon" end
	return self:ImbueSpell()
end

-- /cast lägger imbuen på markören, /use 17 lägger den på off-hand-vapnet
function RE:OffhandMacro(spell)
	spell = spell or self:OffhandSpell()
	if not spell then return nil end
	return "/cast " .. ns.L(spell) .. "\n/use 17"
end

local function hasWeapon()
	local id = ns.get(GetInventoryItemID, "player", 16)
	return id ~= nil
end

---------------------------------------------------------------------------------------------------
local function makeButton(name, label)
	local cfg = ns.char.bars.reminders
	local size = cfg.size or 34
	local b = CreateFrame("Button", name, bar, "SecureActionButtonTemplate")
	b:SetSize(size, size)
	b:RegisterForClicks("AnyUp", "AnyDown")
	b.icon = b:CreateTexture(nil, "ARTWORK")
	b.icon:SetAllPoints()
	b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
	b.text:SetPoint("TOP", b, "BOTTOM", 0, -2)
	b.text:SetText(label)
	b.glow = ns.addGlow(b, 1, 0.3, 0.3)
	b.count = b:CreateFontString(nil, "OVERLAY", "NumberFontNormalLarge")
	b.count:SetPoint("BOTTOMRIGHT", -2, 2)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_TOP")
		GameTooltip:SetText(self.spell or label)
		GameTooltip:AddLine(self.why or "All good.", 1, 1, 1, true)
		GameTooltip:AddLine("Click: cast " .. (self.spell or "-") .. (self.hint or ""), 0.6, 0.8, 1)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	return b
end

function RE:Build()
	local cfg = ns.char.bars.reminders
	local size = cfg.size or 34
	bar = CreateFrame("Frame", "FarseerReminderBar", UIParent)
	bar:SetSize(size * 2 + 8, size)
	ns.placeFrame(bar, cfg)
	ns.makeMovable(bar, cfg, "Farseer: reminders")
	shieldBtn = makeButton("FarseerShieldButton", "Shield")
	shieldBtn:SetPoint("LEFT", bar, "LEFT", 0, 0)
	imbueBtn = makeButton("FarseerImbueButton", "Imbue")
	imbueBtn:SetPoint("LEFT", shieldBtn, "RIGHT", 8, 0)
	offBtn = makeButton("FarseerImbueOffButton", "Off-hand")
	offBtn:SetPoint("LEFT", imbueBtn, "RIGHT", 8, 0)
	offBtn.hint = " on your off-hand"
	offBtn:Hide()
	_G["BINDING_NAME_CLICK FarseerShieldButton:LeftButton"] = "Shield (Lightning/Water Shield)"
	_G["BINDING_NAME_CLICK FarseerImbueButton:LeftButton"] = "Weapon imbue"
	_G["BINDING_NAME_CLICK FarseerImbueOffButton:LeftButton"] = "Off-hand imbue"
end

function RE:ApplySpells()
	if not bar then return end
	if InCombatLockdown() then
		ns.afterCombat("reminder-spells", function() RE:ApplySpells() end)
		return
	end
	local s, i = self:ShieldSpell(), self:ImbueSpell()
	shieldBtn:SetAttribute("type", s and "spell" or nil)
	shieldBtn:SetAttribute("spell", ns.L(s))
	shieldBtn.spell = s
	shieldBtn.icon:SetTexture(ns.spellIcon(s or "Lightning Shield"))
	imbueBtn:SetAttribute("type", i and "spell" or nil)
	imbueBtn:SetAttribute("spell", ns.L(i))
	imbueBtn.spell = i
	imbueBtn.icon:SetTexture(ns.spellIcon(i or "Rockbiter Weapon"))
	-- Off-hand: bara med ett vapen i off-hand och påslagen påminnelse
	local o = self:OffhandSpell()
	offActive = o ~= nil and ns.char.reminders.offhand ~= false and self:OffhandWeapon() == true
	offBtn:SetAttribute("type", offActive and "macro" or nil)
	offBtn:SetAttribute("macrotext", offActive and self:OffhandMacro(o) or nil)
	offBtn.spell = offActive and o or nil
	offBtn.icon:SetTexture(ns.spellIcon(o or "Flametongue Weapon"))
	local cfg = ns.char.bars.reminders
	local size = cfg.size or 34
	shieldBtn:SetShown(s ~= nil)
	imbueBtn:SetShown(i ~= nil)
	offBtn:SetShown(offActive)
	bar:SetSize(offActive and (size * 3 + 16) or (size * 2 + 8), size)
	bar:SetShown(cfg.show and (s ~= nil or i ~= nil or offActive))
end

local function paint(b, need, why)
	b.why = why
	if need then
		b:SetAlpha(1)
		b.icon:SetDesaturated(false)
		b.glow:On()
	else
		b:SetAlpha(0.3)
		b.icon:SetDesaturated(true)
		b.glow:Off()
	end
end

function RE:Check()
	if not bar then return end
	local cfg = ns.char.reminders
	local dead = ns.get(UnitIsDeadOrGhost, "player") == true or ns.get(UnitOnTaxi, "player") == true
	if cfg.shield and shieldBtn.spell then
		local up = self:ShieldUp()
		if up ~= nil then status.shield = up end
		local low = status.shield ~= false and status.chargesLow and ns.char.procs and ns.char.procs.shield
		local why = status.shield == false and "No shield up!"
			or (low and string.format("Only %d charge(s) left — recast your shield.", status.charges or 0)) or nil
		paint(shieldBtn, (status.shield == false or low) and not dead, why)
	else
		paint(shieldBtn, false)
	end
	if cfg.imbue and imbueBtn.spell and hasWeapon() then
		local has, left = self:Imbue()
		if has ~= nil then status.imbue, status.imbueLeft = has, left end
		local low = status.imbue and status.imbueLeft and status.imbueLeft < (cfg.imbueMinutes or 5) * 60
		local why
		if status.imbue == false then why = "No imbue on your weapon!"
		elseif low then why = string.format("Imbue expires in %d min", math.ceil(status.imbueLeft / 60)) end
		paint(imbueBtn, (status.imbue == false or low) and not dead, why)
	else
		paint(imbueBtn, false)
	end
	-- Vapenbyte i strid: knappen kan inte döljas förrän striden är slut, men den lyser inte utan vapen
	if cfg.offhand ~= false and offActive and offBtn.spell and self:OffhandWeapon() ~= false then
		local has, left = self:OffhandImbue()
		if has ~= nil then status.off, status.offLeft = has, left end
		local low = status.off and status.offLeft and status.offLeft < (cfg.imbueMinutes or 5) * 60
		local why
		if status.off == false then why = "No imbue on your off-hand weapon!"
		elseif low then why = string.format("Off-hand imbue expires in %d min", math.ceil(status.offLeft / 60)) end
		paint(offBtn, (status.off == false or low) and not dead, why)
	else
		paint(offBtn, false)
	end
end

-- Laddningar på skölden (från Procs): tal, eller rått secret-värde som bara visas
function RE:SetShieldCharges(n, raw, low)
	if not shieldBtn then return end
	local fs = shieldBtn.count
	if n then
		fs:SetText(tostring(n))
		if low then fs:SetTextColor(1, 0.25, 0.25) else fs:SetTextColor(1, 1, 1) end
	elseif raw ~= nil then
		if not pcall(fs.SetText, fs, raw) then fs:SetText("") end
	else
		fs:SetText("")
	end
	status.charges, status.chargesLow = n, low
end

function RE:OnShamanLogin()
	self:Build()
	self:ApplySpells()
	self:Check()
	ns.listen("SPELLS_CHANGED", function() RE:ApplySpells() end)
	ns.on("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then RE:Check() end end)
	-- Nytt vapen i main hand/off-hand: visa/dölj off-hand-knappen (väntar till efter strid vid behov)
	ns.on("PLAYER_EQUIPMENT_CHANGED", function(_, slot)
		slot = ns.clean(slot)
		if slot == nil or slot == 16 or slot == 17 then RE:Refresh() end
	end)
	ns.listen("BARS_LAYOUT", function()
		ns.afterCombat("reminder-layout", function()
			ns.placeFrame(bar, ns.char.bars.reminders)
			RE:ApplySpells()
		end)
	end)
	C_Timer.NewTicker(1, function()
		local ok, err = pcall(RE.Check, RE)
		if not ok then ns.report(err) end
	end)
end

function RE:Refresh() self:ApplySpells(); self:Check() end
