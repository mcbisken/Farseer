-- Totemrådgivaren: läser situationen och varnar om vilket totem som behövs.
-- Regler (var och en kan stängas av):
--   fear      du är fearad/charmad/sövd (C_LossOfControl)            -> Tremor Totem
--   fearMobs  target/nameplate är en mob som fearar/charmar/söver och är i strid med dig -> Tremor Totem
--   pvpClass  fientlig spelare: klassen styr kontratotemet            -> Grounding/Tremor/Poison...
--   dispel    gift/sjukdom på dig eller gruppen (när auror går att läsa) -> Cleansing-totems
--   boss      boss/zon med eld-/frost-/naturskada                     -> resist-totems (ruta bara i strid)
--   noTotems  i strid en stund utan ett enda totem                    -> påminnelse (inte solo med soloQuiet)
--   groupComp gruppens sammansättning (PvE, utanför strid)            -> grön markerad situation
-- Totems som redan är ute, eller vars buff du redan har från någon annan, ger ingen varning.
-- Allt som kan vara secret läses skyddat.

local _, ns = ...
local AD = ns.module("Advisor")

local plates = {}
local fearNames, bossRules, dispelMobs = {}, {}, {}
local locHold = 0
local combatStart
local dispelCache = { poison = 0, disease = 0, who = nil, dirty = true }
local lastTop

function AD:RebuildLists()
	wipe(fearNames)
	local removed = ns.db.fearMobsRemoved or {}
	for _, n in ipairs(ns.FEAR_MOBS) do
		if not removed[n:lower()] then fearNames[n:lower()] = n end
	end
	for k, v in pairs(ns.db.fearMobs) do fearNames[k] = v end
	wipe(bossRules)
	for _, r in ipairs(ns.BOSS_RULES) do bossRules[r[1]:lower()] = { totem = r[2], reason = r[3] } end
	for k, v in pairs(ns.db.bossRules) do bossRules[k] = { totem = v.totem, reason = v.name .. ": custom rule" } end
	wipe(dispelMobs)
	for name, list in pairs(ns.DISPEL_MOBS or {}) do dispelMobs[name:lower()] = list end
end

function AD:FearList()
	local out = {}
	for k, v in pairs(fearNames) do table.insert(out, { key = k, name = v, own = ns.db.fearMobs[k] ~= nil }) end
	table.sort(out, function(a, b) return a.key < b.key end)
	return out
end

function AD:AddFearMob(name)
	name = ns.trim(name)
	if name == "" then return end
	local k = name:lower()
	ns.db.fearMobsRemoved[k] = nil
	local seeded = false
	for _, n in ipairs(ns.FEAR_MOBS) do if n:lower() == k then seeded = true end end
	if not seeded then ns.db.fearMobs[k] = name end
	self:RebuildLists()
end

function AD:RemoveFearMob(key)
	ns.db.fearMobs[key] = nil
	for _, n in ipairs(ns.FEAR_MOBS) do if n:lower() == key then ns.db.fearMobsRemoved[key] = true end end
	self:RebuildLists()
end

function AD:AddBossRule(name, totem)
	name = ns.trim(name)
	if name == "" or not totem then return end
	ns.db.bossRules[name:lower()] = { name = name, totem = totem }
	self:RebuildLists()
end
function AD:RemoveBossRule(key)
	ns.db.bossRules[key] = nil
	self:RebuildLists()
end

---------------------------------------------------------------------------------------------------
-- Läsning
---------------------------------------------------------------------------------------------------
local function unitInfo(unit)
	if ns.get(UnitExists, unit) ~= true then return nil end
	if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret
		and ns.get(C_Secrets.ShouldUnitIdentityBeSecret, unit) == true then
		return nil
	end
	local info = {
		hostile = ns.get(UnitCanAttack, "player", unit) == true,
		dead = ns.get(UnitIsDeadOrGhost, unit) == true,
		player = ns.get(UnitIsPlayer, unit) == true,
		name = ns.get(UnitName, unit),
	}
	local _, _, class = ns.getAll(UnitClass, unit)
	info.class = class
	return info
end

-- En fiende i närheten räknas bara om du har den som target/focus eller om den har dig som target.
-- Okänt (secret) räknas som nej, så att spelare som bara står i närheten inte ger varningar.
function AD:Engaged(unit)
	if unit == "target" or unit == "focus" then return true end
	if ns.get(UnitIsUnit, unit, "target") == true or ns.get(UnitIsUnit, unit, "focus") == true then return true end
	return ns.get(UnitIsUnit, unit .. "target", "player") == true
end

-- Är en mob (fear-mob) faktiskt i strid med dig? I strid (UnitAffectingCombat) eller har dig som target.
-- Att bara ha den som target/focus räcker inte (du planerar en pull), och en nameplate i närheten
-- räcker inte heller. Secret/okänt = nej.
function AD:EngagedMob(unit)
	if ns.get(UnitAffectingCombat, unit) == true then return true end
	return ns.get(UnitIsUnit, unit .. "target", "player") == true
end

-- Är du i strid? (InCombatLockdown eller UnitAffectingCombat; secret = nej)
local function playerInCombat()
	return InCombatLockdown() and true or ns.get(UnitAffectingCombat, "player") == true
end

local function lossOfControl()
	local C = C_LossOfControl
	if not C then return false end
	local n = ns.get(C.GetActiveLossOfControlDataCount)
	if type(n) ~= "number" then return false end
	for i = 1, n do
		local d = ns.get(C.GetActiveLossOfControlData, i)
		local t = ns.field(d, "locType")
		if t and ns.TREMOR_LOC_TYPES[t] then return true, ns.field(d, "displayText") end
	end
	return false
end

local function scanDispels()
	dispelCache.dirty = false
	dispelCache.poison, dispelCache.disease, dispelCache.who = 0, 0, nil
	if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return end
	-- I strid kan auror vara secret: läsningen kastar då och ns.get ger nil, så loopen bryts
	-- (bästa möjliga: auror som spelet låter oss läsa räknas ändå).
	local units = { "player" }
	for i = 1, 4 do table.insert(units, "party" .. i) end
	for _, unit in ipairs(units) do
		if ns.get(UnitExists, unit) == true then
			for i = 1, 40 do
				local a = ns.get(C_UnitAuras.GetAuraDataByIndex, unit, i, "HARMFUL")
				if not a then break end
				local dn = ns.field(a, "dispelName")
				if dn == "Poison" then
					dispelCache.poison = dispelCache.poison + 1
					dispelCache.who = dispelCache.who or ns.get(UnitName, unit)
				elseif dn == "Disease" then
					dispelCache.disease = dispelCache.disease + 1
					dispelCache.who = dispelCache.who or ns.get(UnitName, unit)
				end
			end
		end
	end
end

local function groupComposition()
	local melee, caster, total = 0, 0, 0
	local raid = ns.get(IsInRaid) == true
	local n = ns.get(GetNumGroupMembers) or 0
	if n == 0 then return nil end
	for i = 1, n do
		local unit = raid and ("raid" .. i) or (i == n and "player" or ("party" .. i))
		local _, _, class = ns.getAll(UnitClass, unit)
		if class then
			total = total + 1
			if ns.MELEE_CLASSES[class] then melee = melee + 1 end
			if ns.CASTER_CLASSES[class] then caster = caster + 1 end
		end
	end
	return melee, caster, total
end

---------------------------------------------------------------------------------------------------
-- Utvärdering
---------------------------------------------------------------------------------------------------
function AD:Evaluate()
	local cfg = ns.char.advisor
	if not cfg.enabled or not ns.isShaman then
		ns.Bars:Highlight({})
		ns.Alert:Hide()
		return {}
	end
	local recs = {}
	-- kind: "critical" (varningsrutan med prio critical), "quiet" (bara glöd, ingen ruta utanför strid), nil = advice
	local function add(totem, prio, reason, extra, kind)
		if not totem or not ns.Spellbook:Knows(totem) then return end
		if ns.Totems:Active(totem) then return end
		-- Buffen finns redan på dig från någon annan (t.ex. en annan shamans Fire Resistance i Molten Core)
		if ns.Totems:BuffState(totem) == true then return end
		local r = recs[totem]
		if not r or prio > r.prio then
			recs[totem] = { totem = totem, prio = prio, reason = reason, extra = extra, kind = kind }
		end
	end

	local now = GetTime()
	local cantAct = ns.get(UnitIsDeadOrGhost, "player") == true or ns.get(UnitOnTaxi, "player") == true
	-- Zon-/bossregler (resist) visas som ruta bara i strid; utanför strid är de bara glöd
	local resistKind = not playerInCombat() and "quiet" or nil

	-- 1. Fear/charm/sleep på dig
	if cfg.fear then
		local feared, text = lossOfControl()
		if feared then locHold = now + 6 end
		if feared or now < locHold then
			add("Tremor Totem", 100, feared and ("You are " .. (text and text:lower() or "feared") .. "!") or "You were just feared",
				nil, "critical")
		end
	end

	-- 2. Target och nameplates
	local units = { "target", "focus" }
	for unit in pairs(plates) do table.insert(units, unit) end
	for _, unit in ipairs(units) do
		local u = unitInfo(unit)
		if u and u.hostile and not u.dead then
			local bonus = unit == "target" and 10 or 0
			local lname = u.name and u.name:lower()
			if not u.player and lname then
				-- Bara en fear-mob som är i strid med dig (inte varje nameplate i närheten)
				if cfg.fearMobs and fearNames[lname] and AD:EngagedMob(unit) then
					local what = ns.FEAR_INFO and ns.FEAR_INFO[fearNames[lname]]
					add("Tremor Totem", 70 + bonus, fearNames[lname] .. (what and (": " .. what) or " can fear/charm/sleep"))
				end
				if cfg.dispel and dispelMobs[lname] then
					for _, d in ipairs(dispelMobs[lname]) do add(d[1], 40 + bonus, d[2]) end
				end
				if cfg.boss and bossRules[lname] then
					add(bossRules[lname].totem, 50 + bonus, bossRules[lname].reason, nil, resistKind)
				end
			elseif u.player and u.class and cfg.pvpClass and (cfg.pvpNearby or AD:Engaged(unit)) then
				for _, rule in ipairs(ns.PVP_CLASS_RULES[u.class] or {}) do
					add(rule[1], rule[2] - 10 + bonus, rule[3])
				end
			end
		end
	end

	-- 3. Zon
	if cfg.boss then
		local zone = ns.get(GetInstanceInfo)
		local z = zone and ns.ZONE_RULES[zone]
		if z then add(z[1], 35, z[2], nil, resistKind) end
	end

	-- 4. Gift/sjukdom
	if cfg.dispel then
		if dispelCache.dirty then scanDispels() end
		if dispelCache.poison > 0 then
			add("Poison Cleansing Totem", 45 + math.min(dispelCache.poison, 5) * 3,
				string.format("Poison on %s%s", dispelCache.who or "the group",
					dispelCache.poison > 1 and (" (+" .. (dispelCache.poison - 1) .. ")") or ""))
		end
		if dispelCache.disease > 0 then
			add("Disease Cleansing Totem", 45 + math.min(dispelCache.disease, 5) * 3,
				string.format("Disease on %s%s", dispelCache.who or "the group",
					dispelCache.disease > 1 and (" (+" .. (dispelCache.disease - 1) .. ")") or ""))
		end
	end

	-- Markera knappar (alla förslag glöder; "quiet" ger ingen varningsruta)
	local want = {}
	local top
	for totem, r in pairs(recs) do
		want[totem] = r.reason
		if r.kind ~= "quiet" and (not top or r.prio > top.prio) then top = r end
	end
	ns.Bars:Highlight(want)

	-- 5. Inga totems i strid (solo utanför instanser: tyst om soloQuiet)
	local noTotems
	local soloQuiet = cfg.soloQuiet and not ns.Alert:InGroupOrInstance()
	if cfg.noTotems and not soloQuiet and combatStart and now - combatStart > 8 and ns.Totems:Count() == 0 then
		local rec = ns.Bars:LoadedIndex() or 1
		noTotems = ns.Bars:Situation(rec)
	end

	-- Visa varning
	if cantAct then
		ns.Alert:Hide()
	elseif top then
		local el = ns.Spellbook:TotemElement(top.totem)
		local c = el and ns.ELEMENT_COLOR[el]
		local _, sit = ns.Bars:SituationFor(top.totem)
		local text = top.reason .. (sit and ("  ·  button: " .. sit.name) or "")
		ns.Alert:Show(top.totem, top.totem, top.totem:upper() .. "!", text, c, nil, top.kind == "critical" and "critical" or "advice")
		if lastTop ~= top.totem then ns.fire("ADVICE", top) end
	elseif noTotems then
		ns.Alert:Show("nototems", noTotems.totems and noTotems.totems[1], "DROP TOTEMS!",
			"No totems down — right-click \"" .. noTotems.name .. "\" for the full set.", { 0.4, 0.8, 1 })
	else
		ns.Alert:Hide()
	end
	lastTop = top and top.totem

	-- 6. Gruppsammansättning (grön markering, bara PvE och utanför strid)
	if cfg.groupComp and not InCombatLockdown() then
		local idx, why
		if ns.Bars:Mode() == "PVE" then
			local melee, caster, total = groupComposition()
			if total and total > 1 then
				if melee >= caster and melee > 0 then
					idx = ns.Bars:FindByName("Melee")
					why = melee .. " melee in the group"
				elseif caster > 0 then
					idx = ns.Bars:FindByName("Caster")
					why = caster .. " casters in the group"
				end
			end
		end
		ns.Bars:Recommend(idx, why)
	end
	return recs
end

---------------------------------------------------------------------------------------------------
function AD:OnShamanLogin()
	self:RebuildLists()
	ns.on("NAME_PLATE_UNIT_ADDED", function(_, unit)
		if type(unit) == "string" and not ns.isSecret(unit) then plates[unit] = true end
	end)
	ns.on("NAME_PLATE_UNIT_REMOVED", function(_, unit)
		if type(unit) == "string" and not ns.isSecret(unit) then plates[unit] = nil end
	end)
	ns.on("UNIT_AURA", function(_, unit)
		if ns.isSecret(unit) or type(unit) ~= "string" then return end
		if unit == "player" or unit:find("^party") then
			dispelCache.dirty = true
		end
	end)
	ns.on("GROUP_ROSTER_UPDATE", function() dispelCache.dirty = true end)
	ns.listen("COMBAT_START", function() combatStart = GetTime() end)
	ns.listen("COMBAT_END", function()
		combatStart = nil
		dispelCache.dirty = true
	end)
	ns.every(0.4, "advisor", function() AD:Evaluate() end)
end
