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
	if ns.Reminders.ImbueSpell and ns.Reminders:ImbueSpell() then
		local has, left = ns.Reminders:Imbue()
		local okI = has
		if has and left and left < 10 * 60 then okI = false end
		add(okI, "Weapon imbue" .. (left and has and string.format(" (%d min left)", math.floor(left / 60)) or ""),
			"At least 10 minutes left.")
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
