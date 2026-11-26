-- Totemfördelning mellan shamans i gruppen/raiden. Addons får inte skicka egna meddelanden i
-- instanser, så Farseer räknar ut ett förslag som du kopierar eller skickar i chatten med ett klick.
-- Varje shaman får ett set efter sin grupps sammansättning (Mana Spring, Healing Stream, Stoneskin m.fl.
-- når bara den egna gruppen; se Data/Situations.lua för vilka som når hela raiden i Forever).

local _, ns = ...
local RT = ns.module("RaidTotems")

-- Set per grupptyp: första shamanen i gruppen får [1], nästa [2] osv. Ordning: jord, eld, vatten, luft.
-- Flametongue finns inte med: den krockar med Windfury (Data/Situations.lua).
RT.SETS = {
	melee = {
		{ "Strength of Earth Totem", "Searing Totem", "Mana Spring Totem", "Windfury Totem" },
		{ "Stoneskin Totem", "Searing Totem", "Healing Stream Totem", "Grace of Air Totem" },
		{ "Tremor Totem", "Frost Resistance Totem", "Poison Cleansing Totem", "Nature Resistance Totem" },
	},
	caster = {
		{ "Stoneskin Totem", "Searing Totem", "Mana Spring Totem", "Windwall Totem" },
		{ "Tremor Totem", "Frost Resistance Totem", "Healing Stream Totem", "Nature Resistance Totem" },
		{ "Strength of Earth Totem", "Searing Totem", "Poison Cleansing Totem", "Grace of Air Totem" },
	},
}

-- I Forever når de här hela raiden: en räcker, nästa shaman tar ett grupptotem av samma element i stället
RT.RAID_WIDE = { ["Windfury Totem"] = true, ["Flametongue Totem"] = true, ["Strength of Earth Totem"] = true,
	["Grace of Air Totem"] = true, ["Frost Resistance Totem"] = true, ["Fire Resistance Totem"] = true,
	["Nature Resistance Totem"] = true }
-- Ersättare per element (index = plats i setet), i den ordning de väljs
RT.FALLBACK = {
	{ "Stoneskin Totem", "Tremor Totem", "Strength of Earth Totem" },
	{ "Searing Totem", "Frost Resistance Totem", "Magma Totem" },
	{ "Mana Spring Totem", "Healing Stream Totem", "Poison Cleansing Totem", "Fire Resistance Totem" },
	{ "Grace of Air Totem", "Windwall Totem", "Grounding Totem", "Nature Resistance Totem", "Windfury Totem" },
}

local function dedupe(set, used)
	local out = {}
	for i, t in ipairs(set) do
		if RT.RAID_WIDE[t] and used[t] then
			t = nil
			for _, alt in ipairs(RT.FALLBACK[i] or {}) do
				if not (RT.RAID_WIDE[alt] and used[alt]) then t = alt break end
			end
			t = t or set[i]
		end
		if RT.RAID_WIDE[t] then used[t] = true end
		out[i] = t
	end
	return out
end

local function short(t) return (t:gsub(" Totem$", "")) end

-- Alla i gruppen: { name, group, class, me }
function RT:Roster()
	local out = {}
	local me = ns.get(UnitName, "player")
	local n = ns.get(GetNumGroupMembers) or 0
	if ns.get(IsInRaid) == true and GetRaidRosterInfo then
		for i = 1, n do
			local ok, name, _, sub, _, _, class = ns.getAll(GetRaidRosterInfo, i)
			if ok and name then
				table.insert(out, { name = name, group = sub or 1, class = class, me = name == me })
			end
		end
	else
		local units = { "player" }
		for i = 1, math.max(0, n - 1) do table.insert(units, "party" .. i) end
		for _, u in ipairs(units) do
			local name = ns.get(UnitName, u)
			local _, _, class = ns.getAll(UnitClass, u)
			if name then table.insert(out, { name = name, group = 1, class = class, me = u == "player" }) end
		end
	end
	return out
end

-- Förslaget: { { group, kind, shaman, me, totems = {...} } }, sorterat på grupp
function RT:Plan(roster)
	roster = roster or self:Roster()
	local groups = {}
	for _, p in ipairs(roster) do
		local g = groups[p.group] or { melee = 0, caster = 0, shamans = {} }
		groups[p.group] = g
		if p.class == "SHAMAN" then table.insert(g.shamans, p) end
		-- Jägare räknas inte som melee: Windfury gör inget för distansvapen (samma som situationen "Caster")
		if ns.MELEE_CLASSES[p.class] then g.melee = g.melee + 1 end
		if ns.CASTER_CLASSES[p.class] then g.caster = g.caster + 1 end
	end
	local plan = {}
	-- Melee-grupper väljer först (Windfury och Strength of Earth gör mest där), sedan i gruppordning
	local order = {}
	for gi, g in pairs(groups) do
		g.kind = g.melee >= g.caster and "melee" or "caster"
		table.insert(order, gi)
	end
	table.sort(order, function(a, b)
		local ka, kb = groups[a].kind, groups[b].kind
		if ka ~= kb then return ka == "melee" end
		return a < b
	end)
	local used = {}
	for _, gi in ipairs(order) do
		local g = groups[gi]
		local kind = g.kind
		table.sort(g.shamans, function(a, b) return a.name < b.name end)
		for i, s in ipairs(g.shamans) do
			local sets = self.SETS[kind]
			table.insert(plan, { group = gi, kind = kind, shaman = s.name, me = s.me,
				totems = dedupe(sets[(i - 1) % #sets + 1], used), melee = g.melee, caster = g.caster })
		end
	end
	table.sort(plan, function(a, b)
		if a.group ~= b.group then return a.group < b.group end
		return a.shaman < b.shaman
	end)
	return plan
end

function RT:Lines(plan)
	plan = plan or self:Plan()
	local lines = {}
	for _, p in ipairs(plan) do
		local names = {}
		for _, t in ipairs(p.totems) do table.insert(names, short(t)) end
		table.insert(lines, string.format("Group %d (%s) - %s: %s", p.group, p.kind == "melee" and "melee" or "casters",
			p.shaman, table.concat(names, ", ")))
	end
	return lines
end

function RT:Mine(plan)
	for _, p in ipairs(plan or self:Plan()) do
		if p.me then return p end
	end
end

-- Skriver ditt set till Call-spellen (utanför strid)
function RT:LoadMine()
	local mine = self:Mine()
	if not mine then return false, "you're not in the plan" end
	if InCombatLockdown() then return false, "not in combat" end
	if not ns.Bars:WriteCall(mine.totems) then return false, "couldn't write the Call set (no Call spell, or blocked)" end
	return true
end

-- Skickar förslaget i raid-/gruppchatten (ett klick = du skickar, inte addonet i bakgrunden)
function RT:Send()
	local lines = self:Lines()
	if #lines == 0 then return false, "no shamans in the group" end
	local n = ns.get(GetNumGroupMembers) or 0
	local channel = ns.get(IsInRaid) == true and "RAID" or (n > 0 and "PARTY" or nil)
	if not channel then
		for _, l in ipairs(lines) do ns.print(l) end
		return true, "not in a group: shown only to you"
	end
	for _, l in ipairs(lines) do
		-- Den globala SendChatMessage är på väg bort i nya klienter
		local send = (C_ChatInfo and C_ChatInfo.SendChatMessage) or SendChatMessage
		if not send then return false, "the client has no chat API — copy the text instead" end
		local ok, err = pcall(send, "Totems: " .. l, channel)
		if not ok then return false, "chat was blocked (" .. tostring(err) .. ") — copy the text instead" end
	end
	return true
end
