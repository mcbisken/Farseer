-- Tester för v1.7: imbue på main hand först, dynamisk varningsgräns, olja döljer inte saknad imbue,
-- recept räknas inte som oljor och vapenbyte nollställer off-hand-läget.

local ns = FARSEER_NS
local test, check = TEST, CHECK
local RE, LV = ns.Reminders, ns.Leveling

-- Extra globala mockar: rawset förbi läckkontrollen, och allt återställs efteråt
local function setGlobal(name, value) rawset(_G, name, value) end

local origWEI = GetWeaponEnchantInfo
local origTooltip, origContainer = rawget(_G, "C_TooltipInfo"), rawget(_G, "C_Container")
local origSeen = ns.char.reminders.imbueMaxSeen and ns.copy(ns.char.reminders.imbueMaxSeen) or nil

-- hasMH, expMH(ms), chargesMH, idMH, hasOH, expOH(ms), chargesOH, idOH; SECRET går att skicka per hand
local function enchants(mh, mhExp, oh, ohExp)
	setGlobal("GetWeaponEnchantInfo", function()
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

local function offhandItem(id)
	MOCK.inventory[17] = id or 777
	C_Item.GetItemInfoInstant = function(i)
		return i, "Weapon", "Sword", "INVTYPE_WEAPON", 135000, 2, 7
	end
end
local function clearOffhand()
	MOCK.inventory[17] = nil
	C_Item.GetItemInfoInstant = nil
	setGlobal("C_PaperDollInfo", nil)
end

-- Tooltip per utrustningsplats: { [16] = { rader }, [17] = { rader } }
local function tooltips(bySlot)
	setGlobal("C_TooltipInfo", { GetInventoryItem = function(unit, slot)
		local lines = unit == "player" and bySlot[slot]
		if not lines then return nil end
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

local function find(list, prefix)
	for _, it in ipairs(list) do
		if it.text:sub(1, #prefix) == prefix then return it end
	end
end

local addedFT, addedWF
local function setup()
	addedFT = learnTemp("Flametongue Weapon")
	addedWF = learnTemp("Windfury Weapon")
	offhandItem(777)
	enchants(true, 3600000, true, 3600000)
	RE:Refresh()
end
local function teardown()
	clearOffhand()
	setGlobal("GetWeaponEnchantInfo", origWEI)
	setGlobal("C_TooltipInfo", origTooltip)
	setGlobal("C_Container", origContainer)
	if addedFT then unlearn("Flametongue Weapon") end
	if addedWF then unlearn("Windfury Weapon") end
	addedFT, addedWF = nil, nil
	RE:Refresh()
end

---------------------------------------------------------------------------------------------------
test("v1.7 imbue: main hand först, sedan off-hand", function()
	setup()
	local main, off = _G.FarseerImbueButton, _G.FarseerImbueOffButton
	check(off:IsShown(), "off-hand-knappen visas")
	check(off:GetAttribute("macrotext") == "/cast Flametongue Weapon\n/use 17", "makrot behåller /use 17")
	-- ingen imbue alls: bara main hand lyser
	enchants(false, 0, false, 0)
	RE:Check()
	check(main.glow:IsShown(), "main hand utan imbue -> glöd")
	check(not off.glow:IsShown(), "off-hand dim så länge main hand saknar imbue")
	check(off.why == "Imbue the main hand first.", "tooltip: " .. tostring(off.why))
	-- main hand klar: nu är off-hand nästa
	enchants(true, 300000, false, 0)
	RE:Check()
	check(not main.glow:IsShown(), "main hand klar -> ingen glöd")
	check(off.glow:IsShown(), "off-hand lyser när main hand har imbue")
	check(off.why and off.why:find("off%-hand weapon"), "varför: " .. tostring(off.why))
	-- main hand okänd efter vapenbyte (secret): off-hand föreslås inte
	enchants(SECRET, SECRET, false, 0)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	check(not off.glow:IsShown(), "main hand okänd -> off-hand dim")
	check(off.why == "Imbue the main hand first.", "okänd main hand: " .. tostring(off.why))
	-- main hand-påminnelsen avstängd: main hand läses ändå för off-hand-regeln
	ns.char.reminders.imbue = false
	enchants(false, 0, false, 0)
	RE:Check()
	check(not off.glow:IsShown(), "avstängd main hand-påminnelse: regeln gäller ändå")
	enchants(true, 300000, false, 0)
	RE:Check()
	check(off.glow:IsShown(), "avstängd main hand-påminnelse: off-hand lyser")
	ns.char.reminders.imbue = true
	-- checklistan säger samma sak
	enchants(false, 0, false, 0)
	local it = find(LV:Checklist(), "Off-hand imbue")
	check(it and it.ok == false and it.tip:find("Imbue the main hand first"), "checklista: " .. tostring(it and it.tip))
	enchants(true, 300000, false, 0)
	it = find(LV:Checklist(), "Off-hand imbue")
	check(it and not it.tip:find("main hand first"), "checklista med main hand klar: " .. tostring(it and it.tip))
	teardown()
end)

test("v1.7 imbue: gränsen följer längsta sedda tiden", function()
	setup()
	local main, off = _G.FarseerImbueButton, _G.FarseerImbueOffButton
	local rem = ns.char.reminders
	-- nygjord 5-minutersimbue på båda händerna (nytt vapen = ny maxtid)
	enchants(true, 299000, true, 299000)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 17)
	check(RE:ImbueMaxSeen("main") == 299 and RE:ImbueMaxSeen("off") == 299,
		"maxtid: " .. tostring(RE:ImbueMaxSeen("main")) .. "/" .. tostring(RE:ImbueMaxSeen("off")))
	check(math.abs(RE:ImbueThreshold("main", 300) - 89.7) < 0.01, "gräns = 30 %: " .. tostring(RE:ImbueThreshold("main", 300)))
	check(not main.glow:IsShown(), "direkt efter casten -> ingen glöd (main)")
	check(not off.glow:IsShown(), "direkt efter casten -> ingen glöd (off-hand)")
	enchants(true, 120000, true, 120000)
	RE:Check()
	check(not main.glow:IsShown() and not off.glow:IsShown(), "2 min kvar av 5 -> ingen glöd")
	check(RE:ImbueMaxSeen("main") == 299, "maxtiden sjunker inte")
	enchants(true, 80000, true, 80000)
	RE:Check()
	check(main.glow:IsShown(), "under 30 % -> glöd (main)")
	check(main.why and main.why:find("2 min"), "main: " .. tostring(main.why))
	check(off.glow:IsShown(), "under 30 % -> glöd (off-hand)")
	check(off.why and off.why:find("2 min"), "off-hand: " .. tostring(off.why))
	-- lägre inställning vinner
	rem.imbueMinutes = 1
	RE:Check()
	check(not main.glow:IsShown() and not off.glow:IsShown(), "imbueMinutes 1 -> 60 s gräns")
	rem.imbueMinutes = 5
	-- okänd maxtid: inställningen gäller som förut
	enchants(true, 120000, true, 120000)
	local seen = rem.imbueMaxSeen
	rem.imbueMaxSeen = nil
	check(RE:ImbueThreshold("main", 300) == 300, "okänd maxtid -> inställningen")
	rem.imbueMaxSeen = seen
	-- lång imbue (60 min) ger den vanliga 5-minutersgränsen
	enchants(true, 3600000, true, 3600000)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	enchants(true, 120000, true, 120000)
	RE:Check()
	check(main.glow:IsShown(), "60 min-imbue: < 5 min -> glöd")
	-- checklistan: samma gräns (10 min, högst 30 %)
	enchants(true, 299000, true, 299000)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 17)
	local list = LV:Checklist()
	local itM, itO = find(list, "Weapon imbue"), find(list, "Off-hand imbue")
	check(itM and itM.ok == true, "checklista: nygjord 5-min-imbue OK (" .. tostring(itM and itM.ok) .. ")")
	check(itO and itO.ok == true, "checklista: off-hand OK")
	check(itM and itM.tip == "At least 89 seconds left.", "tips: " .. tostring(itM and itM.tip))
	enchants(true, 60000, true, 60000)
	list = LV:Checklist()
	itM, itO = find(list, "Weapon imbue"), find(list, "Off-hand imbue")
	check(itM and itM.ok == false and itO and itO.ok == false, "checklista: 1 min kvar -> MISSING")
	enchants(true, 3600000, true, 3600000)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	itM = find(LV:Checklist(), "Weapon imbue")
	check(itM and itM.tip == "At least 10 minutes left.", "lång imbue: 10 min: " .. tostring(itM and itM.tip))
	teardown()
end)

test("v1.7 imbue: olja + gamla API:t -> okänt", function()
	setup()
	-- bara olja på main hand: temporär förtrollning är oljan, inte en imbue
	enchants(true, 1800000, true, 1800000)
	tooltips({ [16] = { "Some Mace", "Brilliant Wizard Oil (30 min)" } })
	local has, left = RE:Imbue()
	check(has == nil and left == nil, "olja utan imbue-rad -> nil: " .. tostring(has))
	-- olja + imbue-rad: imbuen finns, tiden är kanske oljans
	tooltips({ [16] = { "Some Mace", "Brilliant Wizard Oil (30 min)", "Flametongue 3 (5 min)" } })
	has, left = RE:Imbue()
	check(has == true and left == nil, "olja + Flametongue-rad -> true utan tid: " .. tostring(has) .. "/" .. tostring(left))
	for _, name in ipairs({ "Rockbiter 7 (5 min)", "Frostbrand 4 (5 min)", "Windfury 3 (5 min)" }) do
		tooltips({ [16] = { "Some Mace", "Dense Sharpening Stone", "Sharpened (+8 Damage) (30 min)", name } })
		check(RE:Imbue() == true, "imbue-rad känns igen: " .. name)
	end
	-- imbue-namnet i föremålets namn (rad 1) räknas inte
	tooltips({ [16] = { "Windfury Mace (5 min)", "Brilliant Wizard Oil (30 min)" } })
	check(RE:Imbue() == nil, "rad 1 är föremålet")
	-- ingen olja: som förut
	tooltips({ [16] = { "Some Mace" } })
	has, left = RE:Imbue()
	check(has == true and left == 1800, "utan olja -> true med tid: " .. tostring(left))
	-- tooltip går inte att läsa: som förut
	tooltips({ [16] = { "Some Mace", SECRET } })
	check(RE:Imbue() == true, "oläsbar tooltip -> som förut")
	local oil, kind, imb = LV:WeaponTemp(16)
	check(oil == nil and imb == nil, "WeaponTemp oläsbar -> nil/nil")
	-- off-hand: slipsten på slot 17
	tooltips({ [17] = { "Some Sword", "Weighted (+8 Damage) (30 min)" } })
	check(RE:OffhandImbue() == nil, "off-hand: sten utan imbue-rad -> nil")
	check(RE:Imbue() == true, "main hand opåverkad av off-handens tooltip")
	oil, kind, imb = LV:WeaponTemp(17)
	check(oil == "Weighted (+8 Damage)" and kind == "melee" and imb == false, "WeaponTemp 17: " .. tostring(oil))
	-- nya API:t med imbue-typ påverkas inte av oljan
	tooltips({ [16] = { "Some Mace", "Brilliant Wizard Oil (30 min)" } })
	C_Item.GetWeaponEnchantInfo = function()
		return { { hasEnchant = true, enchantType = 3, timeLeft = 200000 } }
	end
	has, left = RE:Imbue()
	check(has == true and left == 200, "C_Item-API: imbue-typen avgör")
	C_Item.GetWeaponEnchantInfo = nil
	-- WeaponOil fungerar som förut (main hand som standard)
	tooltips({ [16] = { "Some Mace", "Brilliant Wizard Oil (30 min)", "Windfury 3 (25 min)" } })
	check(LV:WeaponOil() == "Brilliant Wizard Oil", "WeaponOil standard = main hand")
	teardown()
end)

test("v1.7 olja: recept i väskorna räknas inte", function()
	bags({
		{ "Formula: Brilliant Wizard Oil", 1 },
		{ "Recipe: Brilliant Mana Oil", 1 },
		{ "Plans: Dense Sharpening Stone", 1 },
		{ "Pattern: Something Wizard Oil", 1 },
		{ "Schematic: Weightstone Press", 1 },
		{ "Brilliant Wizard Oil", 2 },
	})
	local n, first = LV:OilsInBags()
	check(n == 2 and first == "Brilliant Wizard Oil", "bara oljan: " .. tostring(n) .. " " .. tostring(first))
	check(LV:OilsInBags("melee") == 0, "inga stenar (bara ritningen)")
	-- föremålsklassen avgör när den går att läsa (0 = förbrukningsvara, 9 = recept)
	bags({ { "Brilliant Mana Oil", 1, 50 }, { "Dense Weightstone", 3, 51 }, { "Lesser Wizard Oil", 4, 52 } })
	C_Item.GetItemInfoInstant = function(id)
		if id == 50 then return id, "Recipe", "Tailoring", "", 1, 9, 2 end
		if id == 51 then return id, "Consumable", "Other", "", 1, 0, 8 end
		return id, nil, nil, nil, nil, nil, nil   -- okänd klass: namnet avgör
	end
	n = LV:OilsInBags()
	check(n == 7, "klass 9 hoppas över, klass 0 och okänd räknas: " .. tostring(n))
	C_Item.GetItemInfoInstant = nil
	n = LV:OilsInBags()
	check(n == 8, "utan item-API: namnet avgör: " .. tostring(n))
	setGlobal("C_Container", origContainer)
end)

test("v1.7 off-hand: vapenbyte nollställer läget", function()
	setup()
	local off = _G.FarseerImbueOffButton
	RE:Check()
	check(RE:ImbueMaxSeen("off") == 3600, "maxtid off-hand: " .. tostring(RE:ImbueMaxSeen("off")))
	-- PLAYER_EQUIPMENT_CHANGED 17 (samma item-ID): maxtiden lärs om från det nya vapnet
	enchants(true, 3600000, true, 299000)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 17)
	check(RE:ImbueMaxSeen("off") == 299, "slot 17 -> ny maxtid: " .. tostring(RE:ImbueMaxSeen("off")))
	check(RE:ImbueMaxSeen("main") == 3600, "main hand orörd")
	-- slot 16 nollställer main hand
	enchants(true, 299000, true, 299000)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 16)
	check(RE:ImbueMaxSeen("main") == 299, "slot 16 -> ny maxtid: " .. tostring(RE:ImbueMaxSeen("main")))
	-- gammalt "saknas" ligger inte kvar efter bytet när den nya off-handen inte går att läsa
	enchants(true, 3600000, false, 0)
	RE:Check()
	check(off.glow:IsShown(), "off-hand saknar imbue -> glöd")
	enchants(true, 3600000, SECRET, SECRET)
	MOCK.inventory[17] = 778
	RE:ApplySpells()
	RE:Check()
	check(not off.glow:IsShown(), "nytt off-hand-vapen (ApplySpells): gammalt läge borta")
	check(RE:ImbueMaxSeen("off") == nil, "nytt vapen -> ingen maxtid")
	-- samma i strid: bytet nollställer direkt fast knapparna väntar
	enchants(true, 3600000, false, 0)
	RE:Check()
	check(off.glow:IsShown(), "glöd igen")
	MOCK.combat = true
	enchants(true, 3600000, SECRET, SECRET)
	MOCK.fire("PLAYER_EQUIPMENT_CHANGED", 17)
	check(not off.glow:IsShown(), "byte i strid -> gammalt läge borta")
	MOCK.combat = false
	MOCK.fire("PLAYER_REGEN_ENABLED")
	-- item-ID skyddar maxtiden även utan händelse
	enchants(true, 3600000, true, 3600000)
	RE:Check()
	check(RE:ImbueMaxSeen("off") == 3600, "maxtid för 778")
	MOCK.inventory[17] = 779
	check(RE:ImbueMaxSeen("off") == nil, "annat item-ID -> maxtiden gäller inte")
	MOCK.inventory[17] = 778
	-- knappen av/på nollställer
	ns.char.reminders.offhand = false
	RE:Refresh()
	check(RE:ImbueMaxSeen("off") == nil, "offhand av -> nollställd")
	ns.char.reminders.offhand = true
	RE:Refresh()
	check(off:IsShown() and RE:ImbueMaxSeen("off") == 3600, "på igen -> läses om")
	teardown()
	ns.char.reminders.imbueMaxSeen = origSeen
end)
