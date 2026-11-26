-- Utveckling och förberedelse: nya ranker hos trainern, reagens, hit-cap och checklista före raid/dungeon.

local _, ns = ...
local LV = ns.module("Leveling")

local function cfg() return ns.char.leveling end

---------------------------------------------------------------------------------------------------
-- Trainern
---------------------------------------------------------------------------------------------------
function LV:TrainerText(list)
	local parts = {}
	for _, r in ipairs(list) do
		local extra = r.source == "tome" and " (tome)" or (r.source == "quest" and " (quest)" or "")
		table.insert(parts, string.format("%s %d%s", r.spell, r.rank, extra))
	end
	return table.concat(parts, ", ")
end

function LV:AnnounceTrainer(level)
	if not cfg().announce then return end
	local list = ns.Spellbook:TrainerMissing(level)
	if #list == 0 then return end
	ns.print("|cffffd100%d|r new ranks/spells waiting at the trainer: %s", #list, self:TrainerText(list))
end

---------------------------------------------------------------------------------------------------
-- Reagens
---------------------------------------------------------------------------------------------------
function LV:ReagentFree()
	return ns.get(C_SpellBook and C_SpellBook.IsSpellKnown, ns.REAGENT_PERK) == true
end

-- { { def, count, low } } för spells du kan
function LV:Reagents()
	local out = {}
	if self:ReagentFree() then return out end
	for _, r in ipairs(ns.REAGENTS) do
		if ns.Spellbook:Knows(r.spell) then
			local n = ns.get(C_Item and C_Item.GetItemCount, r.item)
			if type(n) ~= "number" then n = ns.get(GetItemCount, r.item) end
			table.insert(out, { def = r, count = n, low = type(n) == "number" and n < r.low })
		end
	end
	return out
end

local warned = {}
function LV:WarnReagents()
	if not cfg().reagents then return end
	for _, r in ipairs(self:Reagents()) do
		if r.low and not warned[r.def.item] then
			warned[r.def.item] = true
			ns.print("|cffff8040low on %s|r (%d) — needed for %s.", r.def.name, r.count or 0, r.def.spell)
		elseif not r.low and type(r.count) == "number" then
			warned[r.def.item] = nil   -- fyllt på: varna igen nästa gång det tar slut
		end
	end
end

---------------------------------------------------------------------------------------------------
-- Hit
---------------------------------------------------------------------------------------------------
-- Returnerar spell hit %, melee hit % (nil om de inte går att läsa)
function LV:Hit()
	local function cr(idx)
		local v = ns.get(GetCombatRatingBonus, idx)
		return type(v) == "number" and v or 0
	end
	local sm = ns.get(GetSpellHitModifier)
	local mm = ns.get(GetHitModifier)
	local spell = (type(sm) == "number" or GetCombatRatingBonus) and (cr(_G.CR_HIT_SPELL or 8) + (tonumber(sm) or 0)) or nil
	local melee = (type(mm) == "number" or GetCombatRatingBonus) and (cr(_G.CR_HIT_MELEE or 6) + (tonumber(mm) or 0)) or nil
	return spell, melee
end

function LV:HitCaps()
	local c = cfg()
	return c.hitSpell or ns.HIT_CAP.spell, c.hitMelee or ns.HIT_CAP.melee
end

-- Vilket hit som gäller för specen ("spell"/"melee"/nil för resto)
function LV:HitKind()
	local spec = ns.char.bisSpec
	if spec == "enhancement" then return "melee" end
	if spec == "elemental" then return "spell" end
	return nil
end

---------------------------------------------------------------------------------------------------
-- Checklista
---------------------------------------------------------------------------------------------------
local function playerBuffs()
	local names = {}
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
	for i = 1, 40 do
		local a = ns.get(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
		if not a then break end
		local n = ns.field(a, "name")
		if n then table.insert(names, n) end
	end
	return names
end

local function anyMatch(list, patterns)
	for _, n in ipairs(list) do
		for _, p in ipairs(patterns) do
			if n:find(p) then return n end
		end
	end
end

ns.CHECK_FOOD = { "Well Fed" }
ns.CHECK_FLASK = { "^Flask of", "Elixir", "Spirit of Zanza", "Mageblood", "Supreme Power" }

-- Vapenolja/slipsten (stackar med imbues i Forever): { mönster (gemener, vanlig text), typ }.
-- "caster" = olja för Elemental/Resto, "melee" = sten för Enhancement. Matchar både tooltipraden på
-- vapnet ("Brilliant Wizard Oil (30 min)", "Sharpened (+8 Damage)") och föremålen i väskorna.
ns.CHECK_OIL = {
	{ "wizard oil", "caster" },
	{ "mana oil", "caster" },
	{ "sharpening stone", "melee" },
	{ "weightstone", "melee" },
	{ "sharpened (", "melee" },
	{ "weighted (", "melee" },
}

local function oilKind(text)
	local low = text:lower()
	for _, p in ipairs(ns.CHECK_OIL) do
		if low:find(p[1], 1, true) then return p[2] end
	end
end

-- Shamanens imbues som de står på vapnets tooltip ("Flametongue 3 (5 min)"): namnet först, sedan en tid
ns.CHECK_IMBUE = { "rockbiter", "flametongue", "frostbrand", "windfury" }

local function imbueLine(low)
	if not low:find("%(%d+%s*%a*%)") then return false end
	for _, p in ipairs(ns.CHECK_IMBUE) do
		if low:sub(1, #p) == p then return true end
	end
	return false
end

-- Temporära förtrollningar ur vapnets tooltip (slot 16 = main hand, 17 = off-hand):
-- oljans/stenens namn (false = ingen, nil = går inte att läsa), dess typ, och om en imbue-rad finns
-- (true/false, nil = går inte att läsa). Delas med Reminders (det gamla imbue-API:t ser inte skillnad).
function LV:WeaponTemp(slot)
	local fn = C_TooltipInfo and C_TooltipInfo.GetInventoryItem
	if not fn then return nil end
	local data = ns.get(fn, "player", slot or 16)
	local lines = ns.field(data, "lines")
	if type(lines) ~= "table" then return nil end
	local unreadable, oil, kind, imbue = false, nil, nil, false
	for i = 1, #lines do
		local line = lines[i]
		local ok, text = pcall(function() return line.leftText end)
		if not ok or ns.isSecret(line) or ns.isSecret(text) then
			unreadable = true
		elseif type(text) == "string" then
			if not oil then
				local k = oilKind(text)
				if k then
					-- "Brilliant Wizard Oil (30 min)" -> "Brilliant Wizard Oil"
					oil, kind = ns.trim((text:gsub("%s*%(%d+%s*%a*%)%s*$", ""))), k
				end
			end
			-- rad 1 är föremålets namn
			if i > 1 and imbueLine(text:lower()) then imbue = true end
		end
	end
	-- oläsbara rader: det som inte hittades är okänt, inte "saknas"
	if unreadable then return oil, kind, imbue or nil end
	return oil or false, kind, imbue
end

-- Namn på oljan/stenen på vapnet (standard main hand) + typ, false = ingen, nil = går inte att läsa
function LV:WeaponOil(slot)
	local oil, kind = self:WeaponTemp(slot)
	return oil, kind
end

local function bagItemName(info)
	local link = ns.field(info, "hyperlink")
	if type(link) == "string" then
		local n = link:match("%[(.-)%]")
		if n then return n end
	end
	local id = ns.field(info, "itemID")
	if not id then return nil end
	local n = C_Item and (ns.get(C_Item.GetItemNameByID, id) or ns.get(C_Item.GetItemInfo, id))
	if type(n) == "string" then return n end
	return nil
end

-- Recept/ritningar på oljor ("Formula: Brilliant Wizard Oil") är inga oljor
local RECIPE_PREFIX = { "formula:", "recipe:", "plans:", "pattern:", "schematic:" }
local CONSUMABLE = Enum and Enum.ItemClass and Enum.ItemClass.Consumable or 0

local function bagOilKind(name, id)
	local low = name:lower()
	for _, p in ipairs(RECIPE_PREFIX) do
		if low:sub(1, #p) == p then return nil end
	end
	-- Föremålsklassen om den går att läsa: bara förbrukningsvaror (olja/sten) räknas
	local info = (C_Item and C_Item.GetItemInfoInstant) or GetItemInfoInstant
	if info and id ~= nil then
		-- itemID, itemType, itemSubType, itemEquipLoc, icon, classID, subClassID
		local ok, _, _, _, _, _, classID = ns.getAll(info, id)
		if ok and type(classID) == "number" and classID ~= CONSUMABLE then return nil end
	end
	return oilKind(name)
end

-- Antal oljor/stenar i väskorna (kind = "caster"/"melee"/nil = alla) + namnet på den första; nil = okänt
function LV:OilsInBags(kind)
	local C = C_Container
	if not (C and C.GetContainerNumSlots and C.GetContainerItemInfo) then return nil end
	local total, first = 0, nil
	for bag = 0, (tonumber(NUM_BAG_SLOTS) or 4) do
		local slots = ns.get(C.GetContainerNumSlots, bag)
		for slot = 1, (type(slots) == "number" and slots or 0) do
			local info = ns.get(C.GetContainerItemInfo, bag, slot)
			local name = info and bagItemName(info)
			local k = name and bagOilKind(name, ns.field(info, "itemID"))
			if k and (not kind or k == kind) then
				local n = ns.field(info, "stackCount")
				total = total + (type(n) == "number" and n or 1)
				first = first or name
			end
		end
	end
	return total, first
end

-- Tips för oljeraden: vad specen vill ha + vad som finns i väskorna
function LV:OilTip(foundKind)
	local spec = ns.char.bisSpec or (ns.Spec and ns.Spec.Detect and ns.Spec:Detect())
	local want = spec == "enhancement" and "melee" or "caster"
	local parts = {}
	if spec == "enhancement" then
		table.insert(parts, "Enhancement: use a sharpening stone or weightstone.")
	elseif spec == "restoration" then
		table.insert(parts, "Restoration: use Mana Oil (or Wizard Oil).")
	else
		table.insert(parts, "Elemental: use Wizard Oil (or Mana Oil).")
	end
	if foundKind and foundKind ~= want then
		table.insert(parts, want == "melee" and "Oil is meant for casters." or "Stones only add melee damage.")
	end
	local n, first = self:OilsInBags(want)
	if n == 0 then
		table.insert(parts, "None in bags.")
	elseif n then
		table.insert(parts, string.format("In bags: %d (%s).", n, first or "?"))
	end
	return table.concat(parts, " ")
end

local function lowestDurability()
	local low
	for slot = 1, 18 do
		local ok, cur, max = ns.getAll(GetInventoryItemDurability, slot)
		if ok and cur and max and max > 0 then
			local p = cur / max * 100
			if not low or p < low then low = p end
		end
	end
	return low
end

-- Lista med { ok = true/false/nil (okänt), text, tip }
function LV:Checklist()
	local out = {}
	local function add(ok, text, tip) table.insert(out, { ok = ok, text = text, tip = tip }) end
	local readable = not InCombatLockdown()
	-- Sköld och imbue
	if ns.Reminders.ShieldSpell and ns.Reminders:ShieldSpell() then
		add(ns.Reminders:ShieldUp(), "Shield up (" .. ns.Reminders:ShieldSpell() .. ")")
	end
	local RE = ns.Reminders
	-- Gräns: 10 min, men högst 30 % av den längsta imbue-tiden som setts (Classic-imbues varar 5 min)
	local function imbueLimit(hand)
		local base = 10 * 60
		local lim = RE.ImbueThreshold and RE:ImbueThreshold(hand, base) or base
		local tip = lim >= 120 and string.format("At least %d minutes left.", math.floor(lim / 60))
			or string.format("At least %d seconds left.", math.floor(lim))
		return lim, tip
	end
	local mainHas
	if RE.ImbueSpell and RE:ImbueSpell() then
		local has, left = RE:Imbue()
		mainHas = has
		local lim, tip = imbueLimit("main")
		local okI = has
		if has and left and left < lim then okI = false end
		add(okI, "Weapon imbue" .. (left and has and string.format(" (%d min left)", math.floor(left / 60)) or ""), tip)
	end
	local rem = ns.char.reminders or {}
	if rem.offhand ~= false and RE.OffhandSpell and RE:OffhandSpell() and RE:OffhandWeapon() == true then
		local has, left = RE:OffhandImbue()
		local lim, tip = imbueLimit("off")
		local okO = has
		if has and left and left < lim then okO = false end
		tip = tip .. " The off-hand reminder button applies " .. RE:OffhandSpell() .. "."
		if mainHas == nil then mainHas = RE:Imbue() end
		if okO == false and mainHas ~= true then tip = tip .. " Imbue the main hand first." end
		add(okO, "Off-hand imbue" .. (left and has and string.format(" (%d min left)", math.floor(left / 60)) or ""), tip)
	end
	-- Vapenolja/slipsten på main hand
	if rem.oil ~= false and ns.get(GetInventoryItemID, "player", 16) ~= nil then
		local name, kind = self:WeaponOil()
		local text = "Weapon oil/stone"
		if name then text = text .. " (" .. name .. ")"
		elseif name == nil then text = text .. " (can't read)"
		else
			-- Saknas: visa direkt om det finns något i väskorna (tipset säger vilken sort)
			local n = self:OilsInBags()
			if n == 0 then text = text .. " (none in bags)"
			elseif n then text = text .. string.format(" (%d in bags)", n) end
		end
		local okOil
		if name ~= nil then okOil = name and true or false end
		add(okOil, text, self:OilTip(kind))
	end
	-- Mat och flaska/elixir
	local buffs = readable and playerBuffs()
	if buffs then
		local food = anyMatch(buffs, ns.CHECK_FOOD)
		add(food ~= nil, "Food buff" .. (food and (" (" .. food .. ")") or ""))
		local flask = anyMatch(buffs, ns.CHECK_FLASK)
		add(flask ~= nil, "Flask/elixir" .. (flask and (" (" .. flask .. ")") or ""))
	else
		add(nil, "Food buff (can't read in combat)")
		add(nil, "Flask/elixir (can't read in combat)")
	end
	-- Reagens
	for _, r in ipairs(self:Reagents()) do
		if r.def.spell == "Reincarnation" then
			add(r.count ~= nil and not r.low, string.format("%s: %s", r.def.name, r.count or "?"), "For " .. r.def.spell)
		end
	end
	-- Hållbarhet
	local d = lowestDurability()
	if d then add(d >= 30, string.format("Durability (lowest %d %%)", math.floor(d)), "Repair below 30 %.") end
	-- Call of the Elements
	local call, set
	if ns.Bars.CallSpell then call, set = ns.Bars:CallSpell() end
	if call then
		local n = 0
		for _ in pairs(ns.Totems:CallSetContents(set)) do n = n + 1 end
		add(n > 0, string.format("%s loaded (%d totems)", call, n), "Right-click a situation button to load the set.")
	end
	-- Hit-cap
	local kind = self:HitKind()
	if kind then
		local sh, mh = self:Hit()
		local cs, cm = self:HitCaps()
		local v, capv = (kind == "spell" and sh or mh), (kind == "spell" and cs or cm)
		if v then
			add(v >= capv, string.format("%s hit %.1f %% / %d %%", kind == "spell" and "Spell" or "Melee", v, capv),
				"Hit cap vs raid bosses. Talents are included if the client reports them.")
		end
	end
	-- Trainern
	local missing = ns.Spellbook:TrainerMissing()
	add(#missing == 0, #missing == 0 and "All ranks from the trainer" or (#missing .. " ranks waiting at the trainer"),
		#missing > 0 and self:TrainerText(missing) or nil)
	return out
end

---------------------------------------------------------------------------------------------------
-- The Five Thunders (T0.5): status per steg ur questloggen
---------------------------------------------------------------------------------------------------
-- "done" / "active" / "todo" / nil (okänt quest-ID)
function LV:QuestState(id)
	if not id or not C_QuestLog then return nil end
	if ns.get(C_QuestLog.IsQuestFlaggedCompleted, id) == true then return "done" end
	local idx = ns.get(C_QuestLog.GetLogIndexForQuestID, id)
	if type(idx) == "number" and idx > 0 then return "active" end
	return "todo"
end

-- Returnerar lista { step, state }, antal klara, index för nästa steg
function LV:T05Progress()
	local out, done, nextIdx = {}, 0, nil
	for i, st in ipairs(ns.T05 and ns.T05.steps or {}) do
		local state = self:QuestState(st.id)
		if state == "done" then done = done + 1 end
		if not nextIdx and state ~= "done" then nextIdx = i end
		table.insert(out, { step = st, state = state })
	end
	-- Klara senare steg betyder att tidigare (med andra ID-varianter) också är klara
	local lastDone = 0
	for i, r in ipairs(out) do if r.state == "done" then lastDone = i end end
	for i = 1, lastDone do
		if out[i].state ~= "done" then out[i].state = "done"; done = done + 1 end
	end
	nextIdx = nil
	for i, r in ipairs(out) do if r.state ~= "done" then nextIdx = i break end end
	return out, done, nextIdx
end

---------------------------------------------------------------------------------------------------
-- Checklistefönster
---------------------------------------------------------------------------------------------------
local win
local function buildWindow()
	local UI = ns.UI
	win = CreateFrame("Frame", "FarseerChecklist", UIParent, "BackdropTemplate")
	win:SetSize(320, 60)
	win:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	win:SetFrameStrata("DIALOG")
	win:SetMovable(true)
	win:EnableMouse(true)
	win:RegisterForDrag("LeftButton")
	win:SetScript("OnDragStart", win.StartMoving)
	win:SetScript("OnDragStop", win.StopMovingOrSizing)
	win:SetClampedToScreen(true)
	UI.Backdrop(win, 0.94, { 0.25, 0.4, 0.65 })
	local t = UI.Label(win, "Farseer: ready?", "GameFontNormalLarge", UI.GOLD)
	t:SetPoint("TOPLEFT", 10, -8)
	local close = UI.Button(win, "X", 22, 20, function() win:Hide() end)
	close:SetPoint("TOPRIGHT", -6, -6)
	win.rows = {}
	table.insert(UISpecialFrames, "FarseerChecklist")
	win:Hide()
end

function LV:ShowChecklist()
	if not win then buildWindow() end
	local list = self:Checklist()
	for i, item in ipairs(list) do
		local r = win.rows[i]
		if not r then
			r = win:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			r:SetPoint("TOPLEFT", win, "TOPLEFT", 12, -34 - (i - 1) * 16)
			r:SetJustifyH("LEFT")
			r:SetWidth(296)
			win.rows[i] = r
		end
		local mark = item.ok == true and "|cff40ff40OK|r" or (item.ok == false and "|cffff4040MISSING|r" or "|cff999999?|r")
		r:SetText(mark .. "  " .. item.text)
		r:Show()
	end
	for i = #list + 1, #win.rows do win.rows[i]:Hide() end
	win:SetHeight(44 + #list * 16)
	win:Show()
	return list
end

function LV:HideChecklist() if win then win:Hide() end end

---------------------------------------------------------------------------------------------------
function LV:OnShamanLogin()
	C_Timer.After(5, function()
		LV:AnnounceTrainer()
		LV:WarnReagents()
	end)
	ns.on("PLAYER_LEVEL_UP", function(_, level)
		level = ns.clean(level)
		C_Timer.After(2, function() LV:AnnounceTrainer(type(level) == "number" and level or nil) end)
	end)
	ns.on("BAG_UPDATE_DELAYED", function() LV:WarnReagents() end)
	ns.on("READY_CHECK", function()
		if cfg().readyCheck then LV:ShowChecklist() end
	end)
	ns.on("PLAYER_ENTERING_WORLD", function()
		local _, _, kind = ns.getAll(IsInInstance)
		if cfg().checklist and kind == "raid" then C_Timer.After(3, function() LV:ShowChecklist() end) end
	end)
end
