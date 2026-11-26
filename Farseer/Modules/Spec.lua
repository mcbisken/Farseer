-- Spec: specen läses av från talangpoängen per träd (Elemental/Enhancement/Restoration), och annars från
-- talanger som bara en spec har (Stormstrike ...).
-- Forever (1.60.1) har ingen GetTalentTabInfo (bara med CVar loadDeprecationFallbacks). Blizzards egen
-- talangruta (Blizzard_PlayerSpells/Camelot) läser poängen så här: aktiv config -> trädet -> grupperna
-- (ett per träd) -> C_Traits.GetGroupCurrencyInfo(...).currencyInfos[1].spent. Samma ordning här, sedan
-- C_SpecializationInfo.GetSpecializationInfo (pointsSpent) och sist GetTalentTabInfo.
-- När specen byts (utanför strid) byter Farseer BiS-spec och laddar profilen du kopplat till den.

local _, ns = ...
local SP = ns.module("Spec")

local function cfg() return ns.char.spec end

-- Trädets plats (1 ele, 2 enh, 3 resto) från namnet, annars från ordningen
local function treeIndex(name, order)
	if type(name) == "string" then
		local l = name:lower()
		if l:find("elemental", 1, true) then return 1 end
		if l:find("enhancement", 1, true) then return 2 end
		if l:find("restoration", 1, true) then return 3 end
	end
	return order
end

-- 1. Talangträdet (C_Traits), som Forevers egen talangruta
local function traitPoints()
	if not (C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_Traits and C_Traits.GetConfigInfo
		and C_Traits.GetGroupDisplayInfoByTreeID and C_Traits.GetGroupCurrencyInfo) then return nil end
	local configID = ns.get(C_ClassTalents.GetActiveConfigID)
	if type(configID) ~= "number" then return nil end
	local info = ns.get(C_Traits.GetConfigInfo, configID)
	local treeID = type(info) == "table" and type(info.treeIDs) == "table" and info.treeIDs[1]
	if type(treeID) ~= "number" then return nil end
	local displays = ns.get(C_Traits.GetGroupDisplayInfoByTreeID, treeID)
	if type(displays) ~= "table" or #displays == 0 then return nil end
	local list, ids = {}, {}
	for _, di in ipairs(displays) do
		if type(di) == "table" and type(di.groupID) == "number" then table.insert(list, di) end
	end
	table.sort(list, function(a, b) return (tonumber(a.orderIndex) or 0) < (tonumber(b.orderIndex) or 0) end)
	for i, di in ipairs(list) do ids[i] = di.groupID end
	local groups = ns.get(C_Traits.GetGroupCurrencyInfo, configID, ids)
	if type(groups) ~= "table" then return nil end
	local spent = {}
	for _, g in ipairs(groups) do
		local c = type(g) == "table" and type(g.currencyInfos) == "table" and g.currencyInfos[1]
		if type(c) == "table" and type(c.spent) == "number" then spent[g.traitNodeGroupID] = c.spent end
	end
	local pts, any = { 0, 0, 0 }, false
	for order, di in ipairs(list) do
		local idx = treeIndex(di.displayName, order)
		if idx and idx <= 3 and spent[di.groupID] then pts[idx] = spent[di.groupID]; any = true end
	end
	return any and pts or nil
end

-- 2. Specialiseringarna (pointsSpent är 7:e värdet)
local function specInfoPoints()
	local f = C_SpecializationInfo and C_SpecializationInfo.GetSpecializationInfo
	if not f then return nil end
	local pts, any = { 0, 0, 0 }, false
	for i = 1, 3 do
		local ok, _, name, _, _, _, _, spent = ns.getAll(f, i)
		local idx = ok and treeIndex(name, i)
		if idx and idx <= 3 and type(spent) == "number" then pts[idx] = spent; any = true end
	end
	return any and pts or nil
end

-- Poäng per talangflik { ele, enh, resto }, eller nil om det inte går att läsa
function SP:TalentPoints()
	local ok, pts = pcall(traitPoints)
	if ok and pts then return pts end
	ok, pts = pcall(specInfoPoints)
	if ok and pts and (pts[1] > 0 or pts[2] > 0 or pts[3] > 0) then return pts end
	if not GetTalentTabInfo then return pts end
	local pts, any = {}, false
	for i = 1, 3 do
		local ok, a, _, c, _, e = ns.getAll(GetTalentTabInfo, i)
		local n
		if ok then
			if type(a) == "string" then n = c        -- vanilla: namn, ikon, poäng, fil
			elseif type(a) == "number" then n = e    -- senare klienter: id, namn, beskrivning, ikon, poäng
			end
		end
		if type(n) == "number" then any = true else n = 0 end
		pts[i] = n
	end
	return any and pts or nil
end

-- Returnerar spec ("elemental" ...), hur den avgjordes
function SP:Detect()
	local pts = self:TalentPoints()
	if pts then
		local best, idx, tie = 0, nil, false
		for i, n in ipairs(pts) do
			if n > best then best, idx, tie = n, i, false elseif n == best and n > 0 then tie = true end
		end
		if idx and not tie then
			return ns.SPEC_TABS[idx], string.format("talent points %d/%d/%d", pts[1], pts[2], pts[3])
		end
	end
	for _, sig in ipairs(ns.SPEC_SIGNATURE) do
		if ns.Spellbook:Knows(sig[2]) then return sig[1], "talent " .. sig[2] end
	end
	return nil, "no talents chosen"
end

function SP:Current() return cfg().last end

-- Osatta talangpoäng (0 om det inte går att läsa)
local function unspent()
	-- Forever: C_ClassTalents.HasUnspentTalentPoints() -> har, klasspoäng, specpoäng
	if C_ClassTalents and C_ClassTalents.HasUnspentTalentPoints then
		local ok, has, a, b = ns.getAll(C_ClassTalents.HasUnspentTalentPoints)
		if ok and (type(a) == "number" or type(b) == "number") then
			return (type(a) == "number" and a or 0) + (type(b) == "number" and b or 0)
		end
		if ok and has == false then return 0 end
	end
	local f = rawget(_G, "GetUnspentTalentPoints")
	local v = f and ns.get(f)
	if type(v) ~= "number" and rawget(_G, "UnitCharacterPoints") then v = ns.get(UnitCharacterPoints, "player") end
	return type(v) == "number" and v or 0
end
SP.Unspent = unspent

function SP:Unspent() return unspent() end

function SP:Check(quiet)
	local c = cfg()
	if not c.auto then return end
	if InCombatLockdown() then
		ns.afterCombat("spec-check", function() SP:Check(quiet) end)
		return
	end
	local spec, how = self:Detect()
	if not spec or spec == c.last then return end
	-- Mitt i en omspec (poäng kvar att sätta): byt inte profil på ett halvfärdigt träd
	if c.last ~= nil and unspent() > 1 then return end
	local first = c.last == nil
	c.last = spec
	local did = {}
	if c.setBis and ns.char.bisSpec ~= spec then
		ns.char.bisSpec = spec
		table.insert(did, "BiS list shows " .. ns.SPEC_NAME[spec])
	end
	local profile = not first and c.profiles[spec]
	if profile and profile ~= "" then
		if ns.db.profiles[profile] then
			local ok, err = ns.Profiles:Load(profile, { charOnly = true })
			table.insert(did, ok and ("profile \"" .. profile .. "\" loaded") or ("profile could not be loaded: " .. tostring(err)))
		else
			table.insert(did, "profile \"" .. profile .. "\" no longer exists")
		end
	end
	ns.fire("SPEC_CHANGED", spec, first)
	if not quiet or not first then
		ns.print("spec: %s (%s)%s", ns.SPEC_NAME[spec], how, #did > 0 and (" — " .. table.concat(did, ", ")) or "")
	end
end

local pending = false
local function checkSoon()
	if pending then return end
	pending = true
	C_Timer.After(1, function()
		pending = false
		SP:Check()
	end)
end

function SP:OnShamanLogin()
	for _, e in ipairs({ "PLAYER_TALENT_UPDATE", "CHARACTER_POINTS_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "TRAIT_CONFIG_UPDATED" }) do
		ns.on(e, checkSoon)
	end
	ns.listen("SPELLS_CHANGED", checkSoon)
	C_Timer.After(2, function() SP:Check(true) end)
end
