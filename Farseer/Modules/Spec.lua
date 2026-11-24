-- Spec: Forever har ingen GetSpecialization, så specen läses av från talangpoängen (flikarna
-- Elemental/Enhancement/Restoration), och annars från talanger som bara en spec har (Stormstrike ...).
-- När specen byts (utanför strid) byter Farseer BiS-spec och laddar profilen du kopplat till den.

local _, ns = ...
local SP = ns.module("Spec")

local function cfg() return ns.char.spec end

-- Poäng per talangflik { ele, enh, resto }, eller nil om det inte går att läsa
function SP:TalentPoints()
	if not GetTalentTabInfo then return nil end
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
			return ns.SPEC_TABS[idx], string.format("talangpoäng %d/%d/%d", pts[1], pts[2], pts[3])
		end
	end
	for _, sig in ipairs(ns.SPEC_SIGNATURE) do
		if ns.Spellbook:Knows(sig[2]) then return sig[1], "talangen " .. sig[2] end
	end
	return nil, "inga talanger valda"
end

function SP:Current() return cfg().last end

function SP:Check(quiet)
	local c = cfg()
	if not c.auto then return end
	if InCombatLockdown() then
		ns.afterCombat("spec-check", function() SP:Check(quiet) end)
		return
	end
	local spec, how = self:Detect()
	if not spec or spec == c.last then return end
	local first = c.last == nil
	c.last = spec
	local did = {}
	if c.setBis and ns.char.bisSpec ~= spec then
		ns.char.bisSpec = spec
		table.insert(did, "BiS-listan visar " .. ns.SPEC_NAME[spec])
	end
	local profile = not first and c.profiles[spec]
	if profile and profile ~= "" then
		if ns.db.profiles[profile] then
			local ok, err = ns.Profiles:Load(profile)
			table.insert(did, ok and ("profilen \"" .. profile .. "\" laddad") or ("profilen kunde inte laddas: " .. tostring(err)))
		else
			table.insert(did, "profilen \"" .. profile .. "\" finns inte längre")
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
