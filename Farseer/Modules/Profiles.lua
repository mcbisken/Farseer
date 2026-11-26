-- Profiler: spara/ladda hela Farseer-setupen (situationer, bars, varningar, HUD, makroinställningar, egna makron)
-- under ett namn, och exportera/importera den som text att dela med andra.
-- Exportformat: "FS1:" + base64 av en egen, enkel serialisering (bara tabeller, strängar, tal, true/false),
-- eller "FS2:" när klienten kan komprimera (C_EncodingUtil). Importen kör aldrig kod.

local _, ns = ...
local PR = ns.module("Profiles")

-- Det i karaktärsinställningarna som hör till en profil (inte t.ex. keybind-backup eller inlärda tider)
PR.CHAR_KEYS = { "mode", "autoMode", "situations", "callSet", "seqReset", "bars", "counterTotems", "advisor",
	"reminders", "hud", "totemAlerts", "gear", "leveling", "procs" }

---------------------------------------------------------------------------------------------------
-- Serialisering
---------------------------------------------------------------------------------------------------
local function ser(v, out, depth)
	local t = type(v)
	if depth > 20 then error("nested too deeply") end
	if t == "string" then
		table.insert(out, "s" .. #v .. ":" .. v)
	elseif t == "number" then
		table.insert(out, "n" .. string.format("%.17g", v) .. ";")
	elseif t == "boolean" then
		table.insert(out, v and "T" or "F")
	elseif t == "table" then
		table.insert(out, "{")
		local keys = {}
		for k in pairs(v) do
			if type(k) == "string" or type(k) == "number" then table.insert(keys, k) end
		end
		table.sort(keys, function(a, b)
			if type(a) == type(b) then return a < b end
			return type(a) == "number"
		end)
		for _, k in ipairs(keys) do
			local x = v[k]
			local tx = type(x)
			if tx == "string" or tx == "number" or tx == "boolean" or tx == "table" then
				ser(k, out, depth + 1)
				ser(x, out, depth + 1)
			end
		end
		table.insert(out, "}")
	end
end

function PR.Serialize(v)
	local out = {}
	ser(v, out, 0)
	return table.concat(out)
end

function PR.Deserialize(s)
	local pos = 1
	local function read(depth)
		if depth > 20 then error("nested too deeply") end
		local c = s:sub(pos, pos)
		if c == "s" then
			local colon = s:find(":", pos, true)
			local len = colon and tonumber(s:sub(pos + 1, colon - 1))
			if not len then error("broken string at " .. pos) end
			local v = s:sub(colon + 1, colon + len)
			if #v ~= len then error("string too short at " .. pos) end
			pos = colon + len + 1
			return v
		elseif c == "n" then
			local semi = s:find(";", pos, true)
			local v = semi and tonumber(s:sub(pos + 1, semi - 1))
			if not v then error("broken number at " .. pos) end
			pos = semi + 1
			return v
		elseif c == "T" then pos = pos + 1 return true
		elseif c == "F" then pos = pos + 1 return false
		elseif c == "{" then
			pos = pos + 1
			local t = {}
			while s:sub(pos, pos) ~= "}" do
				if pos > #s then error("table never ends") end
				local k = read(depth + 1)
				if type(k) ~= "string" and type(k) ~= "number" then error("invalid key") end
				t[k] = read(depth + 1)
			end
			pos = pos + 1
			return t
		end
		error("unknown character '" .. c .. "' at " .. pos)
	end
	local ok, v = pcall(read, 0)
	if not ok then return nil, v end
	if pos <= #s then return nil, "junk after data" end
	return v
end

---------------------------------------------------------------------------------------------------
-- Base64 (egen, så att exporten fungerar även utan C_EncodingUtil)
---------------------------------------------------------------------------------------------------
local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local DEC = {}
for i = 1, 64 do DEC[B64:byte(i)] = i - 1 end

function PR.ToBase64(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2 = math.floor(n / 262144) % 64, math.floor(n / 4096) % 64
		local c3, c4 = math.floor(n / 64) % 64, n % 64
		table.insert(out, B64:sub(c1 + 1, c1 + 1) .. B64:sub(c2 + 1, c2 + 1)
			.. (b and B64:sub(c3 + 1, c3 + 1) or "=") .. (c and B64:sub(c4 + 1, c4 + 1) or "="))
	end
	return table.concat(out)
end

function PR.FromBase64(s)
	s = s:gsub("[^%w%+/=]", "")
	if #s % 4 ~= 0 then return nil end
	local out = {}
	for i = 1, #s, 4 do
		local q = { s:byte(i, i + 3) }
		local v = {}
		for j = 1, 4 do
			if q[j] == 61 then v[j] = nil
			else
				v[j] = DEC[q[j]]
				if not v[j] then return nil end
			end
		end
		if not (v[1] and v[2]) then return nil end
		local n = v[1] * 262144 + v[2] * 4096 + (v[3] or 0) * 64 + (v[4] or 0)
		table.insert(out, string.char(math.floor(n / 65536) % 256))
		if v[3] then table.insert(out, string.char(math.floor(n / 256) % 256)) end
		if v[4] then table.insert(out, string.char(n % 256)) end
	end
	return table.concat(out)
end

local E = C_EncodingUtil
local function compress(raw)
	if not (E and E.CompressString and E.EncodeBase64) then return nil end
	local ok, z = pcall(E.CompressString, raw)
	if not ok or type(z) ~= "string" then return nil end
	local ok2, b = pcall(E.EncodeBase64, z)
	if ok2 and type(b) == "string" then return b end
end
local function decompress(b)
	if not (E and E.DecodeBase64 and E.DecompressString) then return nil, "the client can't decompress FS2 text" end
	local ok, z = pcall(E.DecodeBase64, b)
	if not ok or type(z) ~= "string" then return nil, "broken base64" end
	local ok2, raw = pcall(E.DecompressString, z)
	if not ok2 or type(raw) ~= "string" then return nil, "could not decompress" end
	return raw
end

---------------------------------------------------------------------------------------------------
-- Profiler
---------------------------------------------------------------------------------------------------
function PR:Snapshot()
	local char = {}
	for _, k in ipairs(self.CHAR_KEYS) do char[k] = ns.copy(ns.char[k]) end
	return {
		v = 1,
		addon = ns.VERSION,
		char = char,
		macros = ns.copy(ns.db.macros),
		custom = ns.copy(ns.db.custom),
		fearMobs = ns.copy(ns.db.fearMobs),
		bossRules = ns.copy(ns.db.bossRules),
	}
end

-- Tar bara kända nycklar med rätt typ (en importerad profil får inte förstöra sparad data)
local function applyInto(dst, src, defaults)
	if type(src) ~= "table" then return end
	for k, d in pairs(defaults) do
		local v = src[k]
		if v ~= nil and (type(v) == type(d) or d == nil) then
			if type(v) == "table" and type(dst[k]) == "table" then ns.assign(dst[k], v) else dst[k] = ns.copy(v) end
		end
	end
end

-- opts.charOnly: bara karaktärens inställningar (automatiskt vid spec-byte). Kontots listor (egna makron,
-- fear-mobs, bossregler) byts då inte ut, så det man lagt till efter att profilen sparades finns kvar.
function PR:Apply(p, opts)
	if type(p) ~= "table" or type(p.char) ~= "table" then return false, "not a Farseer profile" end
	if InCombatLockdown() then return false, "can't switch profiles in combat" end
	for _, k in ipairs(self.CHAR_KEYS) do
		local v, d = p.char[k], ns.DEFAULTS.char[k]
		if v ~= nil and (d == nil or type(v) == type(d)) then
			-- In i befintliga tabeller: flikar och ramar har referenser till dem. Det profilen saknar (t.ex. en
			-- bar som kom i en senare version) fylls i från standardvärdena först, så att assign inte tar bort
			-- tabeller som ramarna håller referenser till.
			if type(v) == "table" and type(ns.char[k]) == "table" then
				local incoming = ns.copy(v)
				if type(d) == "table" then ns.merge(incoming, d) end
				ns.assign(ns.char[k], incoming)
			else
				ns.char[k] = ns.copy(v)
			end
		end
	end
	ns.merge(ns.char, ns.DEFAULTS.char)
	applyInto(ns.db.macros, p.macros, ns.DEFAULTS.account.macros)
	if not (opts and opts.charOnly) then
		for _, k in ipairs({ "custom", "fearMobs", "bossRules" }) do
			if type(p[k]) == "table" then
				if type(ns.db[k]) == "table" then ns.assign(ns.db[k], p[k]) else ns.db[k] = ns.copy(p[k]) end
			end
		end
	end
	ns.Bars:OnLoad()
	if ns.Advisor.RebuildLists then ns.Advisor:RebuildLists() end
	ns.fire("BARS_LAYOUT")
	ns.fire("PROFILE_LOADED")
	if ns.Bars.Refresh and ns.isShaman then ns.Bars:Refresh() end
	if ns.Reminders.Refresh and ns.isShaman then ns.Reminders:Refresh() end
	-- Makroinställningarna (mouseover, focus, rangs) till de makron som redan finns
	if ns.MacroEngine.RefreshExisting then pcall(ns.MacroEngine.RefreshExisting, ns.MacroEngine, true) end
	return true
end

function PR:List()
	local out = {}
	for name, p in pairs(ns.db.profiles) do table.insert(out, { name = name, saved = p.saved }) end
	table.sort(out, function(a, b) return a.name:lower() < b.name:lower() end)
	return out
end

function PR:Save(name)
	name = ns.trim(name)
	if name == "" then return false, "the profile has no name" end
	local p = self:Snapshot()
	p.saved = date and date("%Y-%m-%d %H:%M") or ""
	ns.db.profiles[name] = p
	ns.char.profile = name
	return true
end

function PR:Load(name, opts)
	local p = ns.db.profiles[name]
	if not p then return false, "no profile named " .. tostring(name) end
	local ok, err = self:Apply(p, opts)
	if ok then ns.char.profile = name end
	return ok, err
end

function PR:Delete(name)
	ns.db.profiles[name] = nil
	if ns.char.profile == name then ns.char.profile = nil end
end

function PR:Export(name)
	local p = name and ns.db.profiles[name] or self:Snapshot()
	if not p then return nil end
	local raw = PR.Serialize(p)
	local z = compress(raw)
	if z and #z < #raw then return "FS2:" .. z end
	return "FS1:" .. PR.ToBase64(raw)
end

-- Text -> profiltabell (sparas inte). Returnerar p eller nil, fel
function PR:Decode(text)
	text = ns.trim(text)
	local kind, body = text:match("^(FS%d):(.+)$")
	if not kind then return nil, "the text doesn't start with FS1: or FS2:" end
	local raw, err
	if kind == "FS1" then
		raw = PR.FromBase64(body)
		if not raw then return nil, "broken text (base64)" end
	elseif kind == "FS2" then
		raw, err = decompress(body)
		if not raw then return nil, err end
	else
		return nil, "unknown version " .. kind
	end
	local p, perr = PR.Deserialize(raw)
	if not p then return nil, perr end
	if type(p) ~= "table" or type(p.char) ~= "table" then return nil, "not a Farseer profile" end
	return p
end

function PR:Import(text, name)
	local p, err = self:Decode(text)
	if not p then return false, err end
	name = ns.trim(name or "")
	if name == "" then name = "Import" end
	p.saved = date and date("%Y-%m-%d %H:%M") or ""
	ns.db.profiles[name] = p
	return true, name
end
