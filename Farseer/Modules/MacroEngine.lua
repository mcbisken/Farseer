-- Bygger makron från mallar och skapar/uppdaterar dem i spelet (bara utanför strid).

local _, ns = ...
local ME = ns.module("MacroEngine")

ME.MAX_BODY = 255
ME.MAX_NAME = 16
ME.ICON = 134400 -- frågetecknet: med #showtooltip visar makrot spellens ikon

local byId = {}
function ME:OnLoad()
	for _, t in ipairs(ns.MACRO_TEMPLATES) do byId[t.id] = t end
end
function ME:Template(id) return byId[id] end

---------------------------------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------------------------------
local function condList(list)
	-- { "@mouseover,harm,nodead", "" } -> "[@mouseover,harm,nodead][] "
	if not list or #list == 0 then return "" end
	local out = {}
	for _, c in ipairs(list) do table.insert(out, "[" .. c .. "]") end
	return table.concat(out) .. " "
end

local function withMod(mod, target)
	-- en klausul med modifier och mål -> "[mod:shift,@player]" (flera mål = flera hakparenteser)
	local targets
	if type(target) == "table" then targets = target
	elseif type(target) == "string" and target ~= "" then targets = { target }
	else targets = { "" } end
	local out = {}
	for _, c in ipairs(targets) do
		local parts = {}
		if mod then table.insert(parts, "mod:" .. mod) end
		if c ~= "" then table.insert(parts, c) end
		table.insert(out, "[" .. table.concat(parts, ",") .. "]")
	end
	local s = table.concat(out)
	if s == "[]" then return "" end
	return s
end

-- ctx.all = true: låtsas kunna allt (förhandsvisning / skapa innan man lärt sig spellsen)
function ME:Context(all)
	local o = ns.db.macros
	local rem = ns.char and ns.char.reminders or {}
	local ctx = { opt = { preferWaterShield = rem.preferWaterShield } }
	local function known(spell)
		if all then return true end
		return ns.Spellbook:Knows(spell)
	end
	ctx.known = known
	function ctx.pick(...)
		for i = 1, select("#", ...) do
			local s = select(i, ...)
			if known(s) then return s end
		end
		return (select(1, ...))
	end
	ctx.harmTargets = o.mouseover and { "@mouseover,harm,nodead", "" } or nil
	ctx.focusTargets = (o.focus or o.mouseover) and {} or nil
	if ctx.focusTargets then
		if o.focus then table.insert(ctx.focusTargets, "@focus,harm,nodead") end
		if o.mouseover then table.insert(ctx.focusTargets, "@mouseover,harm,nodead") end
		table.insert(ctx.focusTargets, "")
	end
	local help = {}
	if o.mouseover then table.insert(help, "@mouseover,help,nodead") end
	table.insert(help, "help,nodead")
	if o.selfcast then table.insert(help, "@player") end
	ctx.helpTargets = help
	ctx.harm = condList(ctx.harmTargets)
	ctx.fharm = condList(ctx.focusTargets)
	ctx.help = condList(help)
	ctx.kick = o.downrankKick and ("Earth Shock(" .. ME:RankText("Earth Shock", 1) .. ")") or "Earth Shock"
	-- Downranking: "Healing Wave(Rank 4)" med klientens egen rank-text och ranken från Healing-fliken
	function ctx.rank(spell)
		return spell .. "(" .. ME:RankText(spell, ME:DownRank(spell)) .. ")"
	end
	ctx.racial = ""
	for _, r in ipairs(ns.RACIAL_OFFENSIVE) do
		if not all and ns.Spellbook:Knows(r) then ctx.racial = "/cast " .. r .. "\n" break end
	end
	-- modcast: entries = { {mod, spell, mål}, ... }; okända spells hoppas över
	function ctx.modcast(entries, defaultTarget)
		local clauses, fallback = {}, nil
		for _, e in ipairs(entries) do
			local mod, spell, target = e[1], e[2], e[3] or defaultTarget
			if spell and known(spell) then
				if mod then
					table.insert(clauses, withMod(mod, target) .. " " .. spell)
				else
					local c = withMod(nil, target)
					fallback = (c ~= "" and (c .. " ") or "") .. spell
				end
			end
		end
		if fallback then table.insert(clauses, fallback) end
		if #clauses == 0 then return "" end
		return "/cast " .. table.concat(clauses, "; ")
	end
	return ctx
end

---------------------------------------------------------------------------------------------------
-- Ranker (downranking)
---------------------------------------------------------------------------------------------------
-- Vald rank för en spell i downrank-makrona
function ME:DownRank(spell)
	local r = ns.db.macros.ranks and ns.db.macros.ranks[spell]
	return r or (ns.DOWNRANK_DEFAULT and ns.DOWNRANK_DEFAULT[spell]) or 1
end

function ME:SetDownRank(spell, rank)
	ns.db.macros.ranks = ns.db.macros.ranks or {}
	ns.db.macros.ranks[spell] = rank
end

-- Rankerna från trainertabellen: { { rank, level, id, mana } }, lägst först
function ME:Ranks(spell)
	local out = {}
	for _, r in ipairs((ns.Spellbook.RankRows and ns.Spellbook.RankRows()[spell]) or {}) do
		local mana
		if r.id and C_Spell and C_Spell.GetSpellPowerCost then
			local costs = ns.get(C_Spell.GetSpellPowerCost, r.id)
			local first = type(costs) == "table" and costs[1]
			mana = ns.field(first, "cost")
		end
		table.insert(out, { rank = r.rank, level = r.level, id = r.id, mana = mana })
	end
	table.sort(out, function(a, b) return a.rank < b.rank end)
	return out
end

-- Klientens text för ranken ("Rank 4", "Rang 4" ...), annars engelska
function ME:RankText(spell, rank)
	for _, r in ipairs(self:Ranks(spell)) do
		if r.rank == rank and r.id then
			local sub = C_Spell and ns.get(C_Spell.GetSpellSubtext, r.id)
			if type(sub) == "string" and sub:find(tostring(rank), 1, true) then return sub end
		end
	end
	return "Rank " .. tostring(rank)
end

local function substitute(body, ctx)
	return (body:gsub("{(%w+)}", function(tok)
		local v = ctx[tok]
		if type(v) == "string" then return v end
		return "{" .. tok .. "}"
	end))
end

-- Spellnamn som makrot castar (för att visa vad som saknas)
function ME:SpellsIn(body)
	local out, seen = {}, {}
	for line in (body .. "\n"):gmatch("([^\n]*)\n") do
		local cmd, rest = line:match("^%s*/(%a+)%s+(.*)$")
		if cmd == "cast" or cmd == "castsequence" then
			for clause in (rest .. ";"):gmatch("([^;]*);") do
				clause = clause:gsub("%b[]", ""):gsub("reset=%S+", "")
				for spell in (clause .. ","):gmatch("([^,]*),") do
					spell = ns.trim(spell):gsub("^!", ""):gsub("%b()$", "")
					spell = ns.trim(spell)
					if spell ~= "" and not seen[spell] then
						seen[spell] = true
						table.insert(out, spell)
					end
				end
			end
		end
	end
	return out
end

-- Renderar en mall. Returnerar body, saknade spells (lista)
function ME:Render(t)
	local function build(all)
		local ctx = self:Context(all)
		local body
		if t.build then
			local ok, res = pcall(t.build, ctx)
			body = ok and res or ("-- template error: " .. tostring(res))
		else
			body = substitute(t.body or "", ctx)
		end
		return body
	end
	local body = build(false)
	-- Kan du inget av det makrot castar: bygg med allt, så makrot fungerar när du lär dig dem
	local spells = self:SpellsIn(body)
	if #spells == 0 and (t.build or body:find("/cast")) then
		body = build(true)
		spells = self:SpellsIn(body)
	end
	local missing = {}
	for _, s in ipairs(spells) do
		if not ns.Spellbook:Knows(s) then table.insert(missing, s) end
	end
	-- Klientens spellnamn (icke-engelsk klient)
	return ns.localizeText(body), missing
end

---------------------------------------------------------------------------------------------------
-- Skapa / uppdatera i spelet
---------------------------------------------------------------------------------------------------
local function limits()
	local acc = _G.MAX_ACCOUNT_MACROS or 120
	-- Konstanterna finns bara när Blizzards makrofönster har laddats; nya klienter har 120 + 30
	local char = _G.MAX_CHARACTER_MACROS or 30
	return acc, char
end

function ME:Exists(name)
	local idx = ns.get(GetMacroIndexByName, name)
	return idx and idx > 0 and idx or nil
end

-- Skapar eller uppdaterar makrot. Returnerar true, "skapad"/"uppdaterad" eller false, felmeddelande
function ME:Save(name, body, perChar)
	if InCombatLockdown() then return false, "can't change macros in combat" end
	name = ns.trim(name)
	if name == "" then return false, "the macro has no name" end
	if #name > self.MAX_NAME then return false, "the name is longer than " .. self.MAX_NAME .. " characters" end
	if #body > self.MAX_BODY then return false, string.format("the macro is %d characters (max %d)", #body, self.MAX_BODY) end
	local idx = self:Exists(name)
	if idx then
		local ok, err = pcall(EditMacro, idx, name, self.ICON, body)
		if not ok then return false, tostring(err) end
		return true, "updated"
	end
	local numAcc, numChar = GetNumMacros()
	local maxAcc, maxChar = limits()
	if perChar and numChar >= maxChar then
		return false, "character macros are full (" .. maxChar .. ")"
	elseif not perChar and numAcc >= maxAcc then
		return false, "account macros are full (" .. maxAcc .. ")"
	end
	local ok, res = pcall(CreateMacro, name, self.ICON, body, perChar and true or nil)
	if not ok then return false, tostring(res) end
	if not res or res == 0 then return false, "the client didn't create the macro" end
	return true, "created"
end

function ME:CreateFromTemplate(id, quiet)
	local t = byId[id]
	if not t then return false, "unknown template " .. tostring(id) end
	local body = self:Render(t)
	local ok, msg = self:Save(t.name, body, ns.db.macros.perCharacter)
	if ok and not ns.db.macros.perCharacter then self:ClaimAccountMacros() end
	if not quiet then
		if ok then ns.print("macro |cffffd100%s|r %s.", t.name, msg)
		else ns.print("|cffff4040%s|r: %s", t.name, msg) end
	end
	return ok, msg
end

function ME:CreateCategory(cat)
	local made, failed = 0, 0
	for _, t in ipairs(ns.MACRO_TEMPLATES) do
		if t.cat == cat and not t.experimental then
			if self:CreateFromTemplate(t.id, true) then made = made + 1 else failed = failed + 1 end
		end
	end
	ns.print("%s: %d macros created/updated%s.", cat, made, failed > 0 and (", " .. failed .. " failed") or "")
	ns.fire("MACROS_CHANGED")
end

-- Kontomakron delas av alla karaktärer: de uppdateras automatiskt bara för den karaktär som senast
-- skapade/uppdaterade dem för hand, så att en annan shaman (annan level/ras) inte skriver över dem.
local function me()
	local n, r = ns.get(UnitName, "player"), ns.get(GetRealmName)
	return tostring(n or "?") .. "-" .. tostring(r or "?")
end
function ME:ClaimAccountMacros() ns.db.macros.owner = me() end
function ME:OwnsAccountMacros()
	local o = ns.db.macros.owner
	if o == nil then self:ClaimAccountMacros() return true end
	return o == me()
end

-- Uppdatera alla Farseer-makron som redan finns (t.ex. efter level-up eller ändrade inställningar).
-- auto = true: automatisk uppdatering (hoppar över andras kontomakron)
function ME:RefreshExisting(auto)
	if InCombatLockdown() then return 0 end
	if not auto then self:ClaimAccountMacros() end
	local owns = self:OwnsAccountMacros()
	local maxAcc = limits()
	local n = 0
	for _, t in ipairs(ns.MACRO_TEMPLATES) do
		local idx = self:Exists(t.name)
		if idx and (owns or idx > maxAcc) then
			local body = self:Render(t)
			local cur = ns.get(GetMacroBody, t.name)
			if type(cur) ~= "string" or ns.trim(cur) ~= ns.trim(body) then
				if self:Save(t.name, body) then n = n + 1 end
			end
		end
	end
	return n
end

-- Lägger makrot på muspekaren så att man kan släppa det på en actionbar
function ME:Pickup(name)
	if InCombatLockdown() then return false end
	if not self:Exists(name) then return false end
	pcall(PickupMacro, name)
	return true
end

function ME:Delete(name)
	if InCombatLockdown() then return false end
	local idx = self:Exists(name)
	if not idx then return false end
	return pcall(DeleteMacro, idx)
end

function ME:OnShamanLogin()
	-- Nya spells (level-up/talanger) -> uppdatera befintliga Farseer-makron efter en stund
	local pending = false
	ns.listen("SPELLS_CHANGED", function()
		if pending then return end
		pending = true
		C_Timer.After(2, function()
			pending = false
			ns.afterCombat("macro-refresh", function()
				local n = ME:RefreshExisting(true)
				if n > 0 then ns.print("%d macros updated after new spells.", n) end
			end)
		end)
	end)
end
