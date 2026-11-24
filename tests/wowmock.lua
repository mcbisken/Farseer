-- Minimal WoW-klient-mock för att köra Farseer i ren Lua 5.1 (lupa). Bara det addonet använder.
-- Inte en emulator: widgets sparar bara tillstånd, okända metoder är no-ops (Get* -> 0, Is* -> false).

MOCK = {
	time = 1000, combat = false, errors = {}, printed = {}, events = {}, timers = {}, tickers = {},
	macros = {}, bindings = {}, multicast = {}, totems = {}, units = {}, loc = {}, auras = {}, secretMode = false,
	known = {}, spellIDs = {}, spellNames = {}, saved = 0, played = 0, weaponEnchant = { true, 3600000 },
	cooldowns = {}, range = {}, inventory = {}, equipSets = {}, quests = {}, questLog = {}, guid = {}, level = 60,
	durability = {}, itemCounts = {},
}

SECRET = setmetatable({}, {
	__index = function() error("secret value indexed", 2) end,
	__concat = function() error("secret value concatenated", 2) end,
	__lt = function() error("secret value compared", 2) end,
	__le = function() error("secret value compared", 2) end,
	__tostring = function() return "<secret>" end,
})
function issecretvalue(v) return rawequal(v, SECRET) end
local function S(v) if MOCK.secretMode then return SECRET end return v end

---------------------------------------------------------------------------------------------------
-- Widgets
---------------------------------------------------------------------------------------------------
local Widget = {}
local function noop() end
local wmeta = {
	__index = function(t, k)
		local m = Widget[k]
		if m then return m end
		if type(k) == "string" then
			if k:match("^Get") then return function() return 0 end end
			if k:match("^Is") or k:match("^Has") then return function() return false end end
			-- Bara metodnamn (versal först) är no-ops; okända fält är nil som i spelet
			if k:match("^%u") then return noop end
		end
		return nil
	end,
}

local function newWidget(kind, name, parent)
	local w = setmetatable({ __kind = kind, __name = name, __parent = parent, __shown = true, __attrs = {},
		__scripts = {}, __events = {}, __w = 0, __h = 0, __text = "", __points = {}, __children = {} }, wmeta)
	if parent and type(parent) == "table" and parent.__children then table.insert(parent.__children, w) end
	return w
end
MOCK.newWidget = newWidget

function Widget:SetScript(k, fn) self.__scripts[k] = fn end
function Widget:GetScript(k) return self.__scripts[k] end
function Widget:HookScript(k, fn) self.__scripts[k] = fn end
function Widget:RegisterEvent(e)
	MOCK.events[e] = MOCK.events[e] or {}
	MOCK.events[e][self] = true
end
function Widget:RegisterUnitEvent(e) self:RegisterEvent(e) end
function Widget:UnregisterEvent(e) if MOCK.events[e] then MOCK.events[e][self] = nil end end
function Widget:SetAttribute(k, v)
	if MOCK.combat and rawget(self, "__protected") then error("ADDON_ACTION_BLOCKED: SetAttribute i strid på " .. tostring(self.__name)) end
	self.__attrs[k] = v
end
function Widget:GetAttribute(k) return self.__attrs[k] end
function Widget:Show()
	if MOCK.combat and rawget(self, "__protected") then error("ADDON_ACTION_BLOCKED: Show i strid på " .. tostring(self.__name)) end
	local was = self.__shown
	self.__shown = true
	if not was and self.__scripts.OnShow then self.__scripts.OnShow(self) end
end
function Widget:Hide()
	if MOCK.combat and rawget(self, "__protected") then error("ADDON_ACTION_BLOCKED: Hide i strid på " .. tostring(self.__name)) end
	local was = self.__shown
	self.__shown = false
	if was and self.__scripts.OnHide then self.__scripts.OnHide(self) end
end
function Widget:SetShown(v) if v then self:Show() else self:Hide() end end
function Widget:IsShown() return self.__shown end
function Widget:IsVisible()
	local f = self
	while f do
		if not f.__shown then return false end
		f = f.__parent
	end
	return true
end
function Widget:SetSize(w, h) self.__w, self.__h = w, h end
function Widget:SetWidth(w) self.__w = w end
function Widget:SetHeight(h) self.__h = h end
function Widget:GetWidth() return self.__w end
function Widget:GetHeight() return self.__h end
function Widget:SetPoint(...) table.insert(self.__points, { ... }) end
function Widget:ClearAllPoints() self.__points = {} end
function Widget:GetPoint() return "CENTER", UIParent, "CENTER", 0, 0 end
function Widget:SetText(t)
	-- Spelet ritar secret-värden i texter (vi kan inte läsa dem)
	if issecretvalue(t) then self.__text = "<secret>" return end
	if t ~= nil and type(t) ~= "string" and type(t) ~= "number" then error("SetText: fel typ " .. type(t), 2) end
	self.__text = t
	if rawget(self, "__fs") then self.__fs.__text = t end
end
function Widget:GetText() return self.__text end
function Widget:GetStringWidth() return #(tostring(self.__text or "")) * 6 end
function Widget:SetChecked(v) self.__checked = v end
function Widget:GetChecked() return self.__checked end
function Widget:GetFontString() return self.__fs end
function Widget:GetFrameLevel() return 1 end
function Widget:GetEffectiveScale() return 1 end
function Widget:GetCenter() return 500, 500 end
function Widget:GetName() return self.__name end
function Widget:GetParent() return self.__parent end
function Widget:SetParent(p) self.__parent = p end
function Widget:CreateTexture(name) return newWidget("Texture", name, self) end
function Widget:CreateFontString(name) return newWidget("FontString", name, self) end
function Widget:CreateAnimationGroup()
	local g = newWidget("AnimationGroup", nil, self)
	function g:CreateAnimation() return newWidget("Animation", nil, g) end
	return g
end
function Widget:SetEnabled(v) self.__enabled = v end
function Widget:Click(button, down)
	if self.__scripts.PreClick then self.__scripts.PreClick(self, button or "LeftButton", down) end
	if self.__scripts.OnClick then self.__scripts.OnClick(self, button or "LeftButton", down) end
end

function CreateFrame(kind, name, parent, template)
	local w = newWidget(kind, name, parent)
	if template and template:find("Secure") then w.__protected = true end
	if parent and parent.__protected == nil then end
	if kind == "Button" or kind == "CheckButton" then w.__fs = newWidget("FontString", nil, w) end
	if template and template:find("UICheckButtonTemplate") then w.Text = newWidget("FontString", nil, w) end
	if name then _G[name] = w end
	return w
end

UIParent = newWidget("Frame", "UIParent")
Minimap = newWidget("Frame", "Minimap")
Minimap.__w = 140
GameTooltip = newWidget("GameTooltip", "GameTooltip")
function GameTooltip:SetSpellByID() end
function GameTooltip:SetItemByID() end
function GameTooltip:SetTotem() end
ChatFontNormal, GameFontHighlightSmall = {}, {}
UISpecialFrames = {}
StaticPopupDialogs = {}
function StaticPopup_Show(which)
	MOCK.lastPopup = which
	local d = StaticPopupDialogs[which]
	if MOCK.autoAccept and d and d.OnAccept then d.OnAccept() end
end
SettingsPanel = newWidget("Frame", "SettingsPanel")
Settings = {
	RegisterCanvasLayoutCategory = function(panel, name) return { name = name } end,
	RegisterAddOnCategory = function() end,
}
BackdropTemplateMixin = {}
function Mixin(t, m) for k, v in pairs(m) do t[k] = v end return t end
SOUNDKIT = { RAID_WARNING = 8959, IG_MAINMENU_OPTION_CHECKBOX_ON = 856 }
function PlaySound() MOCK.played = MOCK.played + 1 end
ITEM_QUALITY_COLORS = { [4] = { r = 0.64, g = 0.21, b = 0.93 } }
YES, NO, CLOSE = "Yes", "No", "Close"

---------------------------------------------------------------------------------------------------
-- Lua-hjälpare som WoW har
---------------------------------------------------------------------------------------------------
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
function tContains(t, v) for _, x in ipairs(t) do if x == v then return true end end return false end
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do parts[i] = tostring(select(i, ...)) end
	table.insert(MOCK.printed, table.concat(parts, " "))
end
function geterrorhandler() return function(err) table.insert(MOCK.errors, tostring(err)) end end
function GetTime() return MOCK.time end
function InCombatLockdown() return MOCK.combat end
function IsShiftKeyDown() return false end
function GetCursorPosition() return 600, 600 end
function GetBindingText(k) return k end
function GetBindingName(k) return k end
SlashCmdList = {}
C_AddOns = { GetAddOnMetadata = function(_, k) if k == "Version" then return "test" end end }

C_Timer = {
	After = function(_, fn) table.insert(MOCK.timers, fn) end,
	NewTicker = function(_, fn) table.insert(MOCK.tickers, fn); return { Cancel = noop } end,
	NewTimer = function(_, fn) table.insert(MOCK.timers, fn); return { Cancel = noop } end,
}
function MOCK.runTimers()
	for _ = 1, 5 do
		local list = MOCK.timers
		MOCK.timers = {}
		for _, fn in ipairs(list) do fn() end
		if #MOCK.timers == 0 then break end
	end
end
function MOCK.tick(n)
	for _ = 1, n or 1 do
		MOCK.time = MOCK.time + 0.5
		for _, fn in ipairs(MOCK.tickers) do fn() end
	end
end
function MOCK.fire(event, ...)
	for f in pairs(MOCK.events[event] or {}) do
		local h = f.__scripts.OnEvent
		if h then h(f, event, ...) end
	end
end

Enum = {
	SpellBookSpellBank = { Player = 0 },
	SpellBookItemType = { None = 0, Spell = 1, FutureSpell = 2 },
	WeaponSlot = { MainHand = 0 },
	ItemEnchantType = { Imbue = 3 },
}

---------------------------------------------------------------------------------------------------
-- Spells
---------------------------------------------------------------------------------------------------
local nextID = 50000
function MOCK.learn(name, id)
	if not id then nextID = nextID + 1; id = nextID end
	MOCK.known[name] = id
	MOCK.spellIDs[name] = id
	MOCK.spellNames[id] = name
	return id
end
function MOCK.unlearn(name) MOCK.known[name] = nil end

C_Spell = {
	GetSpellInfo = function(name)
		local id = type(name) == "number" and name or MOCK.known[name]
		if not id then return nil end
		return { spellID = id, name = MOCK.spellNames[id], iconID = 1000 + id }
	end,
	GetSpellName = function(id) return MOCK.spellNames[id] end,
	GetSpellTexture = function(x)
		local id = type(x) == "number" and x or MOCK.spellIDs[x]
		return id and (1000 + id) or nil
	end,
	GetSpellSubtext = function() return "Rank 1" end,
	GetSpellCooldown = function(id)
		if MOCK.secretMode then return SECRET end
		local c = MOCK.cooldowns[id]
		if not c then return { startTime = 0, duration = 0, isEnabled = true, isOnGCD = false, isActive = false } end
		return { startTime = c[1], duration = c[2], isEnabled = true, isOnGCD = c[3] or false, isActive = true }
	end,
	GetSpellCooldownDuration = function(id) return { spell = id } end,
	IsSpellInRange = function(name)
		if MOCK.secretMode then return SECRET end
		local v = MOCK.range[name]
		if v == nil then return nil end
		return v
	end,
	DoesSpellExist = function() return true end,
}
C_SpellBook = {
	GetNumSpellBookSkillLines = function() return 1 end,
	GetSpellBookSkillLineInfo = function()
		local n = 0
		for _ in pairs(MOCK.known) do n = n + 1 end
		return { itemIndexOffset = 0, numSpellBookItems = n }
	end,
	GetSpellBookItemInfo = function(i)
		local list = {}
		for name, id in pairs(MOCK.known) do table.insert(list, { name = name, spellID = id, itemType = 1 }) end
		table.sort(list, function(a, b) return a.name < b.name end)
		return list[i]
	end,
	IsSpellKnown = function(id) return MOCK.spellNames[id] ~= nil and MOCK.known[MOCK.spellNames[id]] == id end,
	IsSpellInSpellBook = function(id) return MOCK.spellNames[id] ~= nil end,
}
-- Vanilla-elementen för totems (slot: 1 eld, 2 jord, 3 vatten, 4 luft)
MOCK.TOTEM_SLOT = {
	["Stoneskin Totem"] = 2, ["Earthbind Totem"] = 2, ["Stoneclaw Totem"] = 2, ["Strength of Earth Totem"] = 2, ["Tremor Totem"] = 2,
	["Searing Totem"] = 1, ["Magma Totem"] = 1, ["Flametongue Totem"] = 1, ["Frost Resistance Totem"] = 1,
	["Healing Stream Totem"] = 3, ["Mana Spring Totem"] = 3, ["Poison Cleansing Totem"] = 3, ["Disease Cleansing Totem"] = 3,
	["Fire Resistance Totem"] = 3, ["Mana Tide Totem"] = 3,
	["Grounding Totem"] = 4, ["Windfury Totem"] = 4, ["Grace of Air Totem"] = 4, ["Windwall Totem"] = 4,
	["Nature Resistance Totem"] = 4, ["Sentry Totem"] = 4,
}
function GetMultiCastTotemSpells(slot)
	local out = {}
	for name, s in pairs(MOCK.TOTEM_SLOT) do
		if s == slot and MOCK.known[name] then table.insert(out, MOCK.known[name]) end
	end
	return unpack(out)
end
function SetMultiCastSpell(action, id)
	if MOCK.combat then error("ADDON_ACTION_BLOCKED: SetMultiCastSpell") end
	MOCK.multicast[action] = id
end
function GetActionInfo(action)
	local id = MOCK.multicast[action]
	if id and id ~= 0 then return "spell", id end
end
C_ActionBar = { GetMultiCastBarIndex = function() return 12 end }
function IsSpellKnown(id) return C_SpellBook.IsSpellKnown(id) end

---------------------------------------------------------------------------------------------------
-- Totems
---------------------------------------------------------------------------------------------------
function GetTotemInfo(slot)
	local t = MOCK.totems[slot]
	if not t then return S(false), S(""), S(0), S(0), S(0) end
	return S(true), S(t.name), S(t.start), S(t.dur), S(1000)
end
function GetTotemDuration(slot) return { slot = slot } end
function DestroyTotem() end

---------------------------------------------------------------------------------------------------
-- Makron och bindningar
---------------------------------------------------------------------------------------------------
MAX_ACCOUNT_MACROS, MAX_CHARACTER_MACROS = 120, 18
local function macroIndex(name)
	for i, m in ipairs(MOCK.macros) do if m.name == name then return i end end
	return nil
end
function GetMacroIndexByName(name) return macroIndex(name) or 0 end
function GetNumMacros()
	local acc, char = 0, 0
	for _, m in ipairs(MOCK.macros) do if m.perChar then char = char + 1 else acc = acc + 1 end end
	return acc, char
end
function CreateMacro(name, icon, body, perChar)
	if MOCK.combat then error("CreateMacro i strid") end
	if #body > 255 then error("makro för långt") end
	table.insert(MOCK.macros, { name = name, icon = icon, body = body, perChar = perChar })
	return #MOCK.macros
end
function EditMacro(idx, name, icon, body)
	if MOCK.combat then error("EditMacro i strid") end
	local m = MOCK.macros[idx]
	m.name, m.icon, m.body = name, icon, body
	return idx
end
function GetMacroBody(name)
	local i = type(name) == "number" and name or macroIndex(name)
	return i and MOCK.macros[i] and (MOCK.macros[i].body .. "  ") or nil
end
function DeleteMacro(idx) table.remove(MOCK.macros, idx) end
function PickupMacro(name) MOCK.cursor = name end
function ShowMacroFrame() end

local function setBind(key, action)
	if MOCK.combat then error("SetBinding i strid") end
	MOCK.bindings[key] = action
	return true
end
function SetBinding(key, action) return setBind(key, action) end
function SetBindingMacro(key, name) return setBind(key, "MACRO " .. name) end
function SetBindingSpell(key, name) return setBind(key, "SPELL " .. name) end
function SetBindingClick(key, btn, mb) return setBind(key, "CLICK " .. btn .. ":" .. (mb or "LeftButton")) end
function GetBindingAction(key) return MOCK.bindings[key] or "" end
function GetBindingKey(command)
	local keys = {}
	for k, a in pairs(MOCK.bindings) do if a == command then table.insert(keys, k) end end
	table.sort(keys)
	return unpack(keys)
end
function SaveBindings() MOCK.saved = MOCK.saved + 1 end
function GetCurrentBindingSet() return 2 end

---------------------------------------------------------------------------------------------------
-- Enheter
---------------------------------------------------------------------------------------------------
-- MOCK.units[unit] = { name, class, hostile, player, dead }
MOCK.units.player = { name = "Thrall", class = "SHAMAN", player = true }
local function U(unit) return MOCK.units[unit] end
function UnitExists(unit) return S(U(unit) ~= nil) end
function UnitName(unit) local u = U(unit); return u and S(u.name) or nil end
function UnitClass(unit) local u = U(unit); if not u then return nil end return S(u.class), S(u.class), S(7) end
function UnitIsPlayer(unit) local u = U(unit); return S(u and u.player or false) end
function UnitCanAttack(_, unit) local u = U(unit); return S(u and u.hostile or false) end
function UnitIsDeadOrGhost(unit) local u = U(unit); return S(u and u.dead or false) end
function UnitOnTaxi() return false end
function UnitLevel() return MOCK.level end
function UnitGUID(unit) local u = MOCK.units[unit]; return u and S(u.guid or ("guid-" .. tostring(u.name))) or nil end
function UnitAttackSpeed() return S(2.6), S(0) end
function GetCombatRatingBonus(i) return S(MOCK.ratings and MOCK.ratings[i] or 0) end
function GetSpellHitModifier() return S(MOCK.spellHit or 0) end
function GetHitModifier() return S(MOCK.meleeHit or 0) end
function GetInventoryItemDurability(slot)
	local d = MOCK.durability[slot]
	if not d then return nil end
	return S(d[1]), S(d[2])
end
function GetInventoryItemTexture(_, slot) return MOCK.inventory[slot] and 3000 + slot or nil end
function GetInventoryItemCooldown(_, slot)
	local c = MOCK.itemCooldowns and MOCK.itemCooldowns[slot]
	if not c then return S(0), S(0), S(1) end
	return S(c[1]), S(c[2]), S(1)
end
C_EquipmentSet = {
	GetEquipmentSetIDs = function()
		local ids = {}
		for id in pairs(MOCK.equipSets) do table.insert(ids, id) end
		table.sort(ids)
		return ids
	end,
	GetEquipmentSetInfo = function(id)
		local s = MOCK.equipSets[id]
		if not s then return nil end
		return s.name, 4000 + id, id, s.equipped or false, 10, 10, 0, 0, 0
	end,
	UseEquipmentSet = function(id)
		if MOCK.combat then error("UseEquipmentSet i strid") end
		for k, s in pairs(MOCK.equipSets) do s.equipped = (k == id) end
		MOCK.usedSet = id
		return true
	end,
}
C_QuestLog = {
	IsQuestFlaggedCompleted = function(id) return MOCK.quests[id] == true end,
	GetLogIndexForQuestID = function(id) return MOCK.questLog[id] end,
}
function UnitInVehicle() return false end
function IsInRaid() return false end
function GetNumGroupMembers() return MOCK.group or 0 end
function IsInInstance() return MOCK.instanceType ~= "none", MOCK.instanceType or "none" end
function GetInstanceInfo() return MOCK.instanceName or "Azeroth", MOCK.instanceType or "none" end
function GetInventoryItemID(_, slot)
	if slot == nil then return nil end
	local v = MOCK.inventory[slot]
	if v == false then return nil end
	return S(v or (slot == 16 and 12345 or nil))
end
C_Secrets = {
	ShouldUnitIdentityBeSecret = function() return MOCK.identitySecret or false end,
	ShouldAurasBeSecret = function() return MOCK.combat end,
}
C_LossOfControl = {
	GetActiveLossOfControlDataCount = function() return S(#MOCK.loc) end,
	GetActiveLossOfControlData = function(i) return MOCK.secretMode and SECRET or MOCK.loc[i] end,
}
C_UnitAuras = {
	GetAuraDataByIndex = function(unit, i, filter)
		if MOCK.combat and MOCK.secretMode then error("secret aura") end
		local list = MOCK.auras[unit] or {}
		local a = list[i]
		if a and filter == "HARMFUL" and a.harmful then return a end
		if a and filter ~= "HARMFUL" then return a end
		return nil
	end,
	GetAuraDataBySpellName = function(unit, name)
		if MOCK.secretMode then error("secret aura") end
		for _, a in ipairs(MOCK.auras[unit] or {}) do if a.name == name then return a end end
		return nil
	end,
}
C_Item = {
	GetWeaponEnchantInfo = nil,
	GetItemIconByID = function(id) return 2000 + id end,
	GetItemQualityByID = function() return 4 end,
	RequestLoadItemDataByID = function() end,
	GetItemCount = function(id) return MOCK.itemCounts[id] or (MOCK.bag and MOCK.bag[id]) or 0 end,
	GetItemSpell = function(id) if MOCK.useItems and MOCK.useItems[id] then return "Use", 999 end return nil end,
	IsEquippedItem = function(id) return MOCK.equipped and MOCK.equipped[id] or false end,
	GetItemInfo = function(id) return "Item " .. id, "|Hitem:" .. id .. "|h[Item]|h" end,
}
function GetWeaponEnchantInfo()
	return S(MOCK.weaponEnchant[1]), S(MOCK.weaponEnchant[2])
end

---------------------------------------------------------------------------------------------------
-- v1.2: mana, casts, chatt, spelarens auror per ID, mana-kostnad
---------------------------------------------------------------------------------------------------
MOCK.mana = { 1000, 1000 }
MOCK.casting = {}
MOCK.chat = {}
function UnitPower() return S(MOCK.mana[1]) end
function UnitPowerMax() return S(MOCK.mana[2]) end
function UnitCastingInfo(unit)
	local c = MOCK.casting[unit]
	if not c or c.channel then return nil end
	return S(c.name), S(c.name), S(136000), S(c.start * 1000), S(c.ends * 1000), S(false), S(1), S(c.notInt or false), S(c.id or 1)
end
function UnitChannelInfo(unit)
	local c = MOCK.casting[unit]
	if not c or not c.channel then return nil end
	return S(c.name), S(c.name), S(136000), S(c.start * 1000), S(c.ends * 1000), S(false), S(c.notInt or false), S(c.id or 1)
end
function UnitCastingDuration() return { cast = true } end
function UnitChannelDuration() return { channel = true } end
function SendChatMessage(msg, channel)
	if MOCK.chatBlocked then error("chat blocked") end
	table.insert(MOCK.chat, { msg, channel })
end
function C_UnitAuras.GetPlayerAuraBySpellID(id)
	for _, a in ipairs(MOCK.auras.player or {}) do
		if a.spellId == id then
			if MOCK.secretMode then return { applications = SECRET, auraInstanceID = SECRET } end
			return a
		end
	end
	return nil
end
function C_UnitAuras.GetAuraDataByAuraInstanceID(unit, inst)
	for _, a in ipairs(MOCK.auras[unit] or {}) do
		if a.auraInstanceID == inst then
			if MOCK.secretMode then return { applications = SECRET } end
			return a
		end
	end
	return nil
end
C_Spell.GetSpellPowerCost = function(id)
	if MOCK.secretMode then return SECRET end
	return { { type = 0, cost = MOCK.manaCost and MOCK.manaCost[id] or 100 } }
end
