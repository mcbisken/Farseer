-- Applicerar keybind-mallar och sparar det som låg på tangenterna innan, så att det kan återställas.

local _, ns = ...
local BE = ns.module("BindingEngine")

local byId = {}
function BE:OnLoad()
	for _, p in ipairs(ns.BINDING_PRESETS) do byId[p.id] = p end
	ns.char.bindBackup = ns.char.bindBackup or {}
end
function BE:Preset(id) return byId[id] end

local function bindingSet()
	local set = ns.get(GetCurrentBindingSet)
	if set ~= 1 and set ~= 2 then set = 2 end
	return set
end

-- Beskrivning av vad en rad gör
function BE:Describe(b)
	if b.macro then
		local t = ns.MacroEngine:Template(b.macro)
		return "Macro: " .. (t and t.name or b.macro)
	elseif b.spell then
		return "Spell: " .. b.spell
	elseif b.click then
		local n = tonumber(b.click:match("FarseerSit(%d+)"))
		if n then
			local s = ns.Bars and ns.Bars:Situation(n)
			local label = s and s.name or ("situation " .. n)
			return (b.button == "RightButton" and "Full set: " or "Next totem: ") .. label
		end
		return "Click: " .. b.click
	elseif b.command then
		return "Command: " .. b.command
	end
	return "?"
end

-- Vad tangenten gör nu
function BE:Current(key)
	local a = ns.get(GetBindingAction, key)
	if not a or a == "" then return nil end
	return a
end

---------------------------------------------------------------------------------------------------
-- Lager och "behåll mina": mallen kan läggas på Shift/Ctrl/Alt (1 -> SHIFT-1) och bara binda tangenter
-- som är lediga, så att spelarens egna bindningar ligger kvar.
---------------------------------------------------------------------------------------------------
BE.LAYERS = { "", "SHIFT", "CTRL", "ALT" }
local MOD_ORDER = { "ALT", "CTRL", "SHIFT" }   -- WoW skriver modifierare i den här ordningen
local NEXT_MOD = { SHIFT = "CTRL", CTRL = "ALT", ALT = "SHIFT" }

local function splitKey(key)
	local mods, rest = {}, key
	while true do
		local m, r = rest:match("^(%u+)%-(.+)$")
		if m and (m == "ALT" or m == "CTRL" or m == "SHIFT") then mods[m] = true; rest = r else break end
	end
	return mods, rest
end

-- "1" + SHIFT -> "SHIFT-1". Har tangenten redan modifieraren tas nästa (SHIFT-T + SHIFT -> CTRL-SHIFT-T).
-- nil om alla tre redan används.
function BE:AddMod(key, mod)
	if not mod or mod == "" then return key end
	local mods, base = splitKey(key)
	local m, tries = mod, 0
	while mods[m] and tries < 3 do m = NEXT_MOD[m]; tries = tries + 1 end
	if mods[m] then return nil end
	mods[m] = true
	local out = ""
	for _, k in ipairs(MOD_ORDER) do if mods[k] then out = out .. k .. "-" end end
	return out .. base
end

function BE:Options()
	local o = ns.char.bindLayer
	if type(o) ~= "table" then o = { mod = "", keep = false }; ns.char.bindLayer = o end
	return o
end

-- Är det Farseer som har bundit tangenten? (sådant får skrivas över även i "behåll mina")
local function ours(action)
	return action:find("^CLICK Farseer") ~= nil or action:find("^MACRO FS ") ~= nil
end

-- Vad mallen gör med valda inställningar: { key, b, cur, skip = orsak|nil, modWarn = bool }
function BE:Plan(id, opts)
	local p = byId[id]
	if not p then return {} end
	opts = opts or self:Options()
	local out, used = {}, {}
	for _, b in ipairs(p.binds) do
		-- Krockar två rader på samma tangent (CTRL-F1 + Shift = CTRL-SHIFT-F1 = SHIFT-F1 + Shift) prövas nästa modifierare
		local key = self:AddMod(b[1], opts.mod)
		if key and used[key] and opts.mod ~= "" then
			local m = NEXT_MOD[opts.mod]
			for _ = 1, 2 do
				local k = self:AddMod(b[1], m)
				if k and not used[k] then key = k break end
				m = NEXT_MOD[m]
			end
		end
		local e = { key = key or b[1], b = b }
		if not key then
			e.skip = "no free modifier"
		else
			e.cur = self:Current(key)
			if used[key] then
				e.skip = "key used twice"
			elseif opts.keep and e.cur and not ours(e.cur) then
				e.skip = "kept"
			end
			used[key] = true
		end
		-- Makron med [mod:shift] gör alltid Shift-delen när de ligger på en Shift-tangent
		if b.macro and key and key:find("SHIFT%-") then
			local t = ns.MacroEngine:Template(b.macro)
			local body = t and (t.body or "") or ""
			if t and t.build then
				local ok, res = pcall(ns.MacroEngine.Render, ns.MacroEngine, t)
				if ok and type(res) == "string" then body = res end
			end
			e.modWarn = body:find("%[mod:shift%]") ~= nil
		end
		table.insert(out, e)
	end
	return out
end

-- Binder en rad. Returnerar true eller false + fel
local function bindOne(key, b, errors)
	local ok, res
	if b.macro then
		local t = ns.MacroEngine:Template(b.macro)
		local made, msg = true, nil
		if t and not ns.MacroEngine:Exists(t.name) then
			made, msg = ns.MacroEngine:CreateFromTemplate(b.macro, true)
			if not made then table.insert(errors, t.name .. ": " .. tostring(msg)) end
		end
		-- Ingen bindning till ett makro som inte finns (tangenten skulle bli död)
		if t and made then ok, res = pcall(SetBindingMacro, key, t.name) end
	elseif b.spell then
		ok, res = pcall(SetBindingSpell, key, ns.L(b.spell))
	elseif b.click then
		ok, res = pcall(SetBindingClick, key, b.click, b.button or "LeftButton")
	elseif b.command then
		ok, res = pcall(SetBinding, key, b.command)
	end
	if ok and res ~= false then return true end
	table.insert(errors, key .. ": " .. tostring(res))
	return false
end

-- Applicerar mallen. Returnerar antal bindningar, lista med fel, antal tangenter som lämnades orörda
function BE:Apply(id, opts)
	local p = byId[id]
	if not p then return 0, { "unknown template" }, 0 end
	if InCombatLockdown() then return 0, { "can't change keybinds in combat" }, 0 end
	local backup = ns.char.bindBackup
	local count, errors, kept = 0, {}, 0
	for _, e in ipairs(self:Plan(id, opts)) do
		if e.skip then
			kept = kept + 1
		else
			if backup[e.key] == nil then backup[e.key] = self:Current(e.key) or "" end
			if bindOne(e.key, e.b, errors) then count = count + 1 end
		end
	end
	pcall(SaveBindings, bindingSet())
	ns.char.lastPreset = id
	ns.fire("BINDINGS_CHANGED")
	return count, errors, kept
end

-- Återställer alla tangenter som Farseer har ändrat
function BE:Restore()
	if InCombatLockdown() then return 0, { "can't change keybinds in combat" } end
	local n = 0
	for key, old in pairs(ns.char.bindBackup) do
		if old == "" then pcall(SetBinding, key) else pcall(SetBinding, key, old) end
		n = n + 1
	end
	wipe(ns.char.bindBackup)
	ns.char.lastPreset = nil
	pcall(SaveBindings, bindingSet())
	ns.fire("BINDINGS_CHANGED")
	return n, {}
end

function BE:HasBackup() return next(ns.char.bindBackup) ~= nil end

-- Tangent som en kommando-sträng är bunden till ("CLICK FarseerSit1:LeftButton")
function BE:KeyFor(command)
	local key = ns.get(GetBindingKey, command)
	if type(key) ~= "string" then return nil end
	return key
end

-- Kort tangenttext för knappar: "SHIFT-T" -> "sT"
function BE:ShortKey(key)
	if not key then return "" end
	key = key:gsub("SHIFT%-", "s"):gsub("CTRL%-", "c"):gsub("ALT%-", "a")
	key = key:gsub("BUTTON", "M"):gsub("MOUSEWHEELUP", "MwU"):gsub("MOUSEWHEELDOWN", "MwD")
	key = key:gsub("NUMPAD", "N")
	return key
end
