-- Vilka spells spelaren kan, och vilket element varje totem tillhör (läst ur klienten).

local _, ns = ...
local SB = ns.module("Spellbook")

local known = {}       -- namn -> högsta spellID
local totemSlot = {}   -- totemnamn -> slot (1-4), från GetMultiCastTotemSpells
local totemID = {}     -- totemnamn -> högsta rankens ID (för SetMultiCastSpell)
local scanned = false

---------------------------------------------------------------------------------------------------
-- Språk: Farseer använder engelska namn internt. Klientens namn slås upp via spell-ID, så att makron,
-- knappar och keybinds fungerar även på t.ex. en tysk eller fransk klient.
---------------------------------------------------------------------------------------------------
local toLocal, toCanon = {}, {}
local function seedIDs(name)
	local ids = ns.SPELL_IDS[name]
	if ids and ids[1] then return ids end
end

function SB:BuildLocale()
	wipe(toLocal)
	wipe(toCanon)
	local names = {}
	for name, ids in pairs(ns.SPELL_IDS) do names[name] = ids[1] end
	for _, r in ipairs(ns.TRAINER and ns.TRAINER.ranks or {}) do
		if r.id and not names[r.spell] then names[r.spell] = r.id end
	end
	for name, id in pairs(names) do
		local loc = C_Spell and ns.get(C_Spell.GetSpellName, id)
		if type(loc) == "string" and loc ~= "" then
			if loc ~= name then toLocal[name] = loc end
			toCanon[loc] = name
		end
	end
end

-- Engelskt namn -> klientens namn (samma på engelsk klient)
function ns.L(name)
	if type(name) ~= "string" then return name end
	return toLocal[name] or name
end
-- Klientens namn -> engelskt namn
function ns.canon(name)
	if type(name) ~= "string" then return name end
	return toCanon[name] or name
end
function ns.localized() return next(toLocal) ~= nil end

-- Byter engelska spellnamn i en makrotext mot klientens (bara hela namn, längsta först)
function ns.localizeText(text)
	if type(text) ~= "string" or not next(toLocal) then return text end
	local list = {}
	for en, loc in pairs(toLocal) do table.insert(list, { en, loc }) end
	table.sort(list, function(a, b) return #a[1] > #b[1] end)
	local marks = {}
	for i, pair in ipairs(list) do
		local pat = "%f[%w]" .. pair[1]:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1") .. "%f[^%w]"
		text = text:gsub(pat, function()
			marks[i] = pair[2]
			return "\001" .. i .. "\002"
		end)
	end
	return (text:gsub("\001(%d+)\002", function(i) return marks[tonumber(i)] end))
end

local function rankOf(id)
	local sub = C_Spell and ns.get(C_Spell.GetSpellSubtext, id)
	local n = type(sub) == "string" and tonumber(sub:match("(%d+)")) or 0
	return n
end

local function strictKnown(id)
	if not id then return false end
	if C_SpellBook and C_SpellBook.IsSpellKnown then
		if ns.get(C_SpellBook.IsSpellKnown, id) == true then return true end
	end
	if IsSpellKnown and ns.get(IsSpellKnown, id) == true then return true end
	return false
end

function SB:Scan()
	self:BuildLocale()
	wipe(known)
	wipe(totemSlot)
	wipe(totemID)
	if C_SpellBook and C_SpellBook.GetNumSpellBookSkillLines then
		local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
		local future = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.FutureSpell
		local lines = ns.get(C_SpellBook.GetNumSpellBookSkillLines) or 0
		for line = 1, lines do
			local info = ns.get(C_SpellBook.GetSpellBookSkillLineInfo, line)
			local off = ns.field(info, "itemIndexOffset")
			local num = ns.field(info, "numSpellBookItems")
			if off and num then
				for i = off + 1, off + num do
					local item = ns.get(C_SpellBook.GetSpellBookItemInfo, i, bank)
					local name, id = ns.canon(ns.field(item, "name")), ns.field(item, "spellID")
					local itemType = ns.field(item, "itemType")
					local isFuture = future ~= nil and itemType == future
					if name and id and not isFuture then
						local cur = known[name]
						if not cur or rankOf(id) >= rankOf(cur) then known[name] = id end
					end
				end
			end
		end
	end
	-- Totems per element, med högsta rank
	if GetMultiCastTotemSpells then
		for slot = 1, 4 do
			local ok, ids = pcall(function() return { GetMultiCastTotemSpells(slot) } end)
			if ok then
				for _, id in ipairs(ids) do
					if type(id) == "number" and not ns.isSecret(id) then
						local name = ns.canon(ns.get(C_Spell.GetSpellName, id))
						if name then
							totemSlot[name] = slot
							local cur = totemID[name]
							if not cur or rankOf(id) >= rankOf(cur) then totemID[name] = id end
							known[name] = known[name] or id
						end
					end
				end
			end
		end
	end
	scanned = true
	ns.fire("SPELLS_CHANGED")
end

-- Kan spelaren spellen? (namn, engelska klienten)
function SB:Knows(name)
	if not name or name == "" then return false end
	if known[name] then return true end
	-- Talanger och spells som inte syns i spellboken: fråga klienten
	local info = C_Spell and ns.get(C_Spell.GetSpellInfo, ns.L(name))
	local id = ns.field(info, "spellID")
	if id and strictKnown(id) then
		known[name] = id
		return true
	end
	for _, seed in ipairs(ns.SPELL_IDS[name] or {}) do
		if strictKnown(seed) then
			known[name] = seed
			return true
		end
	end
	return false
end

-- Högsta rank du kan enligt trainertabellen (0 = ingen, -1 = okänd rank, nil = inte i tabellen)
local rankRows
local function rows()
	if rankRows then return rankRows end
	rankRows = {}
	for _, r in ipairs(ns.TRAINER and ns.TRAINER.ranks or {}) do
		rankRows[r.spell] = rankRows[r.spell] or {}
		table.insert(rankRows[r.spell], r)
	end
	return rankRows
end
SB.RankRows = rows

function SB:KnownRank(name)
	local list = rows()[name]
	if not list then return nil end
	local best = 0
	for _, r in ipairs(list) do
		if r.id and r.rank > best and strictKnown(r.id) then best = r.rank end
	end
	if best == 0 and self:Knows(name) then
		-- Inget rank-ID matchade (klienten har andra ID:n): rangen ur spellbokens text, annars okänd
		local n = rankOf(known[name])
		best = n > 0 and n or -1
	end
	return best
end

-- Ranker/spells hos trainern som du har level för men inte kan: { spell, rank, level, source, id }
function SB:TrainerMissing(level)
	level = level or ns.get(UnitLevel, "player") or 1
	local out = {}
	for spell, list in pairs(rows()) do
		local have = self:KnownRank(spell)
		if have and have >= 0 then
			local best
			for _, r in ipairs(list) do
				if r.level <= level and r.rank > have and not (r.talentUpgrade and have == 0) then
					if not best or r.rank > best.rank then best = r end
				end
			end
			if best then table.insert(out, best) end
		end
	end
	table.sort(out, function(a, b) if a.level ~= b.level then return a.level < b.level end return a.spell < b.spell end)
	return out
end

-- Det som blir tillgängligt på kommande levels: { [level] = { rader } }
function SB:TrainerUpcoming(fromLevel, toLevel)
	local out = {}
	for _, r in ipairs(ns.TRAINER and ns.TRAINER.ranks or {}) do
		if r.level > fromLevel and r.level <= toLevel and not r.talentUpgrade then
			out[r.level] = out[r.level] or {}
			table.insert(out[r.level], r)
		end
	end
	return out
end

-- Sätter en cooldown-ram efter spellens cooldown. Vanliga tal när de går att läsa (GCD:n hoppas över),
-- annars spelets duration-objekt, som fungerar även när värdena är secret.
function ns.setSpellCooldown(cd, spell)
	if not cd then return end
	local id = SB:ID(spell) or (seedIDs(spell) or {})[1]
	if not id then pcall(cd.Clear, cd) return end
	if C_Spell and C_Spell.GetSpellCooldown then
		local ok, info = pcall(C_Spell.GetSpellCooldown, id)
		if ok and type(info) == "table" and not ns.isSecret(info) then
			local gcd = ns.field(info, "isOnGCD")
			local start, dur = ns.field(info, "startTime"), ns.field(info, "duration")
			if gcd == true or (dur and dur <= 1.5) then pcall(cd.Clear, cd) return end
			if start and dur then
				if dur > 0 then pcall(cd.SetCooldown, cd, start, dur) else pcall(cd.Clear, cd) end
				return
			end
		end
	end
	if C_Spell and C_Spell.GetSpellCooldownDuration and cd.SetCooldownFromDurationObject then
		-- true = utan global cooldown (annars sveper varje cast alla ikoner; ShamanForever 0.6.1/0.13.0)
		local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id, true)
		if ok and d then pcall(cd.SetCooldownFromDurationObject, cd, d, true) end
	end
end

function SB:ID(name)
	if self:Knows(name) then return known[name] end
end

function SB:Scanned() return scanned end

-- Totemets element ("EARTH"...), från klienten om möjligt
function SB:TotemElement(name)
	local slot = totemSlot[name]
	if slot then return ns.SLOT_ELEMENT[slot] end
	local t = ns.TOTEMS[name]
	return t and t.el or nil
end

function SB:IsTotem(name)
	return name ~= nil and (totemSlot[name] ~= nil or ns.TOTEMS[name] ~= nil)
end

function SB:TotemSpellID(name) return totemID[name] end

-- Alla kända totems för ett element, sorterade på namn
function SB:KnownTotems(el)
	local out = {}
	for name in pairs(ns.TOTEMS) do
		if self:TotemElement(name) == el and self:Knows(name) then table.insert(out, name) end
	end
	for name, slot in pairs(totemSlot) do
		if ns.SLOT_ELEMENT[slot] == el and not ns.TOTEMS[name] then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

-- Alla totems för ett element (även okända), för redigering innan man lärt sig dem
function SB:AllTotems(el)
	local seen, out = {}, {}
	for name in pairs(ns.TOTEMS) do
		if self:TotemElement(name) == el then seen[name] = true; table.insert(out, name) end
	end
	for name, slot in pairs(totemSlot) do
		if ns.SLOT_ELEMENT[slot] == el and not seen[name] then table.insert(out, name) end
	end
	table.sort(out)
	return out
end

-- Högsta kända Call-spell (1-3), eller 0
function SB:CallCount()
	local n = 0
	for i, name in ipairs(ns.CALLS) do
		if self:Knows(name) then n = i end
	end
	return n
end

local pending = false
local function scanSoon()
	if pending then return end
	pending = true
	C_Timer.After(0.5, function()
		pending = false
		SB:Scan()
	end)
end

function SB:OnLogin()
	self:Scan()
	ns.on("SPELLS_CHANGED", scanSoon)
	ns.on("PLAYER_LEVEL_UP", scanSoon)
	ns.on("PLAYER_TALENT_UPDATE", scanSoon)
	ns.on("TRAIT_CONFIG_UPDATED", scanSoon)
end
