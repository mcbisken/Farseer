-- Tester för v1.6: off-hand-imbue (knapp, makro, checklista) och vapenolja/slipsten i checklistan.

local ns = FARSEER_NS
local test, check = TEST, CHECK
local RE, LV = ns.Reminders, ns.Leveling

-- Extra globala mockar: rawset förbi läckkontrollen, och allt återställs efteråt
local function setGlobal(name, value) rawset(_G, name, value) end

local origWEI = GetWeaponEnchantInfo
-- hasMH, expMH(ms), chargesMH, idMH, hasOH, expOH(ms), chargesOH, idOH
local function enchants(mh, mhExp, oh, ohExp)
	setGlobal("GetWeaponEnchantInfo", function()
		if MOCK.secretMode then return SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET, SECRET end
		return mh, mhExp, 0, mh and 1 or nil, oh, ohExp, 0, oh and 2 or nil
	end)
end

local function learnTemp(name)
	if ns.Spellbook:Knows(name) then return false end
	MOCK.learn(name)
	ns.Spellbook:Scan()
	MOCK.runTimers()
	return true
end
local function unlearn(name)
	MOCK.unlearn(name)
	ns.Spellbook:Scan()
	MOCK.runTimers()
end

-- Off-hand-vapen via C_Item.GetItemInfoInstant (classID 2 = vapen, 4 = rustning/sköld)
local function offhandItem(classID, equipLoc)
	MOCK.inventory[17] = 777
	C_Item.GetItemInfoInstant = function(id)
		return id, "Weapon", "Sword", equipLoc or "INVTYPE_WEAPON", 135000, classID, 7
	end
end
local function clearOffhand()
	MOCK.inventory[17] = nil
	C_Item.GetItemInfoInstant = nil
	setGlobal("C_PaperDollInfo", nil)
end

---------------------------------------------------------------------------------------------------
test("off-hand: vapen i off-hand känns av", function()
	clearOffhand()
	check(RE:OffhandWeapon() == false, "tom off-hand -> false")
	offhandItem(2)
	check(RE:OffhandWeapon() == true, "vapen (classID 2) -> true")
	offhandItem(4, "INVTYPE_SHIELD")
	check(RE:OffhandWeapon() == false, "sköld (classID 4) -> false")
	offhandItem(nil, "INVTYPE_WEAPONOFFHAND")
	check(RE:OffhandWeapon() == true, "utan classID: equipLoc avgör")
	offhandItem(nil, "")
	check(RE:OffhandWeapon() == nil, "inget går att läsa -> nil")
	C_Item.GetItemInfoInstant = nil
	check(RE:OffhandWeapon() == nil, "inget item-API -> nil")
	-- C_PaperDollInfo går före
	setGlobal("C_PaperDollInfo", { OffhandHasWeapon = function() return true end })
	check(RE:OffhandWeapon() == true, "OffhandHasWeapon true")
	setGlobal("C_PaperDollInfo", { OffhandHasWeapon = function() return false end })
	offhandItem(2)
	check(RE:OffhandWeapon() == false, "OffhandHasWeapon false vinner över item-klassen")
	setGlobal("C_PaperDollInfo", { OffhandHasWeapon = function() return SECRET end })
	check(RE:OffhandWeapon() == true, "secret -> reserv via item-klassen")
	clearOffhand()
end)

test("off-hand: automatiskt spellval och makrotext", function()
	local rem = ns.char.reminders
	local addedFT = learnTemp("Flametongue Weapon")
	local addedWF = learnTemp("Windfury Weapon")
	local addedRB = learnTemp("Rockbiter Weapon")
	rem.offhandSpell = "auto"
	check(RE:OffhandSpell() == "Flametongue Weapon", "auto = Flametongue: " .. tostring(RE:OffhandSpell()))
	check(RE:OffhandMacro() == "/cast Flametongue Weapon\n/use 17", "makro: " .. tostring(RE:OffhandMacro()))
	rem.offhandSpell = "Rockbiter Weapon"
	check(RE:OffhandSpell() == "Rockbiter Weapon", "eget val")
	rem.offhandSpell = "Unknown Weapon"
	check(RE:OffhandSpell() == "Flametongue Weapon", "okänt val -> auto")
	rem.offhandSpell = "auto"
	unlearn("Flametongue Weapon")
	check(RE:OffhandSpell() == RE:ImbueSpell() and RE:OffhandSpell() == "Windfury Weapon",
		"utan Flametongue: samma som main hand (" .. tostring(RE:OffhandSpell()) .. ")")
	if not addedFT then MOCK.learn("Flametongue Weapon", MOCK.spellIDs["Flametongue Weapon"]); ns.Spellbook:Scan(); MOCK.runTimers() end
	if addedWF then unlearn("Windfury Weapon") end
	if addedRB then unlearn("Rockbiter Weapon") end
end)

test("off-hand: knappen visas och lyser", function()
	local rem = ns.char.reminders
	local addedFT = learnTemp("Flametongue Weapon")
	local addedWF = learnTemp("Windfury Weapon")
	local b = _G.FarseerImbueOffButton
	check(b ~= nil, "knappen finns")
	check(_G["BINDING_NAME_CLICK FarseerImbueOffButton:LeftButton"] == "Off-hand imbue", "keybind-namn")
	-- ingen off-hand
	clearOffhand()
	enchants(true, 3600000, false, 0)
	RE:Refresh()
	check(not b:IsShown(), "inget off-hand-vapen -> dold")
	check(b:GetAttribute("type") == nil, "ingen typ utan vapen")
	-- vapen utan imbue
	offhandItem(2)
	RE:Refresh()
	check(b:IsShown(), "vapen i off-hand -> visas")
	check(b:GetAttribute("type") == "macro", "typ macro")
	check(b:GetAttribute("macrotext") == "/cast Flametongue Weapon\n/use 17", "makrotext: " .. tostring(b:GetAttribute("macrotext")))
	check(b.glow:IsShown(), "ingen imbue -> glöd")
	check(b.why and b.why:find("off%-hand"), "varför: " .. tostring(b.why))
	-- main hand påverkas inte
	check(not _G.FarseerImbueButton.glow:IsShown(), "main hand har imbue -> ingen glöd där")
	-- snart slut / gott om tid
	enchants(true, 3600000, true, 120000)
	RE:Check()
	check(b.glow:IsShown(), "off-hand < 5 min -> glöd")
	check(b.why and b.why:find("2 min"), "minuter kvar: " .. tostring(b.why))
	enchants(true, 3600000, true, 3600000)
	RE:Check()
	check(not b.glow:IsShown(), "off-hand 60 min -> ingen glöd")
	-- secret: senaste kända läget behålls, inga fel
	MOCK.secretMode = true
	RE:Check()
	MOCK.secretMode = false
	check(not b.glow:IsShown(), "secret: behåller läget")
	-- död: ingen glöd
	enchants(true, 3600000, false, 0)
	local origDead = UnitIsDeadOrGhost
	setGlobal("UnitIsDeadOrGhost", function() return true end)
	RE:Check()
	check(not b.glow:IsShown(), "död -> ingen glöd")
	setGlobal("UnitIsDeadOrGhost", origDead)
	RE:Check()
	check(b.glow:IsShown(), "levande igen -> glöd")
	-- avstängd
	rem.offhand = false
	RE:Refresh()
	check(not b:IsShown(), "offhand = false -> dold")
	rem.offhand = true
	-- vapenbyte i strid: knappen kan inte döljas, men lyser inte
	RE:Refresh()
	check(b:IsShown(), "på igen")
	MOCK.combat = true
	clearOffhand()
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 17)
	check(not b.glow:IsShown(), "inget vapen i strid -> ingen glöd")
	offhandItem(2)
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	check(b:IsShown(), "efter strid: visas igen")
	-- städa
	clearOffhand()
	setGlobal("GetWeaponEnchantInfo", origWEI)
	RE:Refresh()
	check(not b:IsShown(), "dold efter städning")
	if addedFT then unlearn("Flametongue Weapon") end
	if addedWF then unlearn("Windfury Weapon") end
	RE:Refresh()
end)

---------------------------------------------------------------------------------------------------
local function find(list, prefix)
	for _, it in ipairs(list) do
		if it.text:sub(1, #prefix) == prefix then return it end
	end
end

local function tooltip(lines)
	setGlobal("C_TooltipInfo", { GetInventoryItem = function(unit, slot)
		if unit ~= "player" or slot ~= 16 then return nil end
		local out = {}
		for i, t in ipairs(lines) do out[i] = { leftText = t } end
		return { lines = out }
	end })
end

local function bags(items)
	setGlobal("C_Container", {
		GetContainerNumSlots = function(bag) return bag == 0 and #items or 0 end,
		GetContainerItemInfo = function(bag, slot)
			local it = bag == 0 and items[slot]
			if not it then return nil end
			return { itemID = it[3] or 1, stackCount = it[2], hyperlink = "|cffffffff|Hitem:1|h[" .. it[1] .. "]|h|r" }
		end,
	})
end

test("checklista: off-hand-imbue", function()
	local addedFT = learnTemp("Flametongue Weapon")
	clearOffhand()
	enchants(true, 3600000, false, 0)
	check(find(LV:Checklist(), "Off-hand imbue") == nil, "ingen off-hand -> ingen rad")
	offhandItem(2)
	local it = find(LV:Checklist(), "Off-hand imbue")
	check(it and it.ok == false, "off-hand utan imbue -> MISSING")
	enchants(true, 3600000, true, 30 * 60000)
	it = find(LV:Checklist(), "Off-hand imbue")
	check(it and it.ok == true and it.text:find("30 min"), "30 min kvar: " .. tostring(it and it.text))
	enchants(true, 3600000, true, 5 * 60000)
	it = find(LV:Checklist(), "Off-hand imbue")
	check(it and it.ok == false, "under 10 min -> MISSING")
	ns.char.reminders.offhand = false
	check(find(LV:Checklist(), "Off-hand imbue") == nil, "avstängd -> ingen rad")
	ns.char.reminders.offhand = true
	clearOffhand()
	setGlobal("GetWeaponEnchantInfo", origWEI)
	if addedFT then unlearn("Flametongue Weapon") end
end)

test("checklista: vapenolja/slipsten", function()
	local spec = ns.char.bisSpec
	-- ingen tooltip-API -> okänt
	setGlobal("C_TooltipInfo", nil)
	setGlobal("C_Container", nil)
	local it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == nil and it.text:find("can't read"), "inget API -> can't read: " .. tostring(it and it.text))
	-- olja på vapnet
	ns.char.bisSpec = "elemental"
	tooltip({ "Some Mace", "Binds when equipped", "Brilliant Wizard Oil (30 min)", "Windfury 3 (25 min)" })
	bags({})
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == true, "olja hittad -> OK")
	check(it and it.text == "Weapon oil/stone (Brilliant Wizard Oil)", "namnet utan tid: " .. tostring(it and it.text))
	check(it and it.tip:find("Wizard Oil") and it.tip:find("None in bags"), "tips: " .. tostring(it and it.tip))
	check(LV:WeaponOil() == "Brilliant Wizard Oil", "WeaponOil")
	-- slipsten (gemener/versaler spelar ingen roll)
	tooltip({ "Some Sword", "SHARPENED (+8 Damage) (30 min)" })
	local name, kind = LV:WeaponOil()
	check(name == "SHARPENED (+8 Damage)" and kind == "melee", "sharpened: " .. tostring(name) .. "/" .. tostring(kind))
	ns.char.bisSpec = "enhancement"
	tooltip({ "Some Sword", "Weighted (+8 Damage) (30 min)" })
	bags({ { "Dense Sharpening Stone", 3 }, { "Brilliant Wizard Oil", 1 }, { "Heavy Linen Bandage", 10 } })
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == true, "weightstone OK")
	check(it and it.tip:find("Enhancement") and it.tip:find("In bags: 3"), "enhancement-tips räknar stenar: " .. tostring(it and it.tip))
	-- fel sort för specen
	tooltip({ "Some Sword", "Brilliant Mana Oil (30 min)" })
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == true and it.tip:find("casters"), "olja på enhancement nämns: " .. tostring(it and it.tip))
	-- ingen olja
	tooltip({ "Some Sword", "Windfury 3 (25 min)" })
	bags({})
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == false, "ingen olja -> MISSING")
	check(it and it.text:find("none in bags"), "text: " .. tostring(it and it.text))
	check(it and it.tip:find("None in bags"), "tips: " .. tostring(it and it.tip))
	bags({ { "Dense Weightstone", 2 } })
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == false and it.text:find("2 in bags"), "i väskan: " .. tostring(it and it.text))
	-- resto
	ns.char.bisSpec = "restoration"
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.tip:find("Mana Oil") and it.tip:find("None in bags"), "resto-tips: " .. tostring(it and it.tip))
	-- secret rad -> okänt
	tooltip({ "Some Sword", SECRET })
	it = find(LV:Checklist(), "Weapon oil/stone")
	check(it and it.ok == nil and it.text:find("can't read"), "secret -> can't read")
	-- secret-rad men olja på en läsbar rad -> hittad ändå
	tooltip({ SECRET, "Lesser Wizard Oil (30 min)" })
	check(LV:WeaponOil() == "Lesser Wizard Oil", "läsbar rad räcker")
	-- hela tooltipen secret
	setGlobal("C_TooltipInfo", { GetInventoryItem = function() return SECRET end })
	check(LV:WeaponOil() == nil, "secret tooltip -> nil")
	-- avstängd
	ns.char.reminders.oil = false
	check(find(LV:Checklist(), "Weapon oil/stone") == nil, "oil = false -> ingen rad")
	ns.char.reminders.oil = true
	-- inget vapen
	MOCK.inventory[16] = false
	check(find(LV:Checklist(), "Weapon oil/stone") == nil, "inget vapen -> ingen rad")
	MOCK.inventory[16] = nil
	-- checklistefönstret ritar raderna utan fel
	tooltip({ "Some Sword" })
	local list = LV:ShowChecklist()
	check(find(list, "Weapon oil/stone") ~= nil, "fönstret")
	LV:HideChecklist()
	setGlobal("C_TooltipInfo", nil)
	setGlobal("C_Container", nil)
	ns.char.bisSpec = spec
end)

test("inställningar: off-hand och olja", function()
	ns.Options:Open()
	ns.UI.SelectTab("settings")
	check(ns.char.reminders.offhand == true and ns.char.reminders.oil == true, "standard på")
	check(ns.char.reminders.offhandSpell == "auto", "standard auto")
end)
