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
		return "Makro: " .. (t and t.name or b.macro)
	elseif b.spell then
		return "Spell: " .. b.spell
	elseif b.click then
		local n = tonumber(b.click:match("FarseerSit(%d+)"))
		if n then
			local s = ns.Bars and ns.Bars:Situation(n)
			local label = s and s.name or ("situation " .. n)
			return (b.button == "RightButton" and "Hela setet: " or "Nästa totem: ") .. label
		end
		return "Klick: " .. b.click
	elseif b.command then
		return "Kommando: " .. b.command
	end
	return "?"
end

-- Vad tangenten gör nu
function BE:Current(key)
	local a = ns.get(GetBindingAction, key)
	if not a or a == "" then return nil end
	return a
end

-- Applicerar mallen. Returnerar antal bindningar, lista med fel
function BE:Apply(id)
	local p = byId[id]
	if not p then return 0, { "okänd mall" } end
	if InCombatLockdown() then return 0, { "kan inte ändra keybinds i strid" } end
	local backup = ns.char.bindBackup
	local count, errors = 0, {}
	for _, b in ipairs(p.binds) do
		local key = b[1]
		if backup[key] == nil then backup[key] = self:Current(key) or "" end
		local ok, res
		if b.macro then
			local t = ns.MacroEngine:Template(b.macro)
			if t and not ns.MacroEngine:Exists(t.name) then
				local made, msg = ns.MacroEngine:CreateFromTemplate(b.macro, true)
				if not made then table.insert(errors, t.name .. ": " .. tostring(msg)) end
			end
			if t then ok, res = pcall(SetBindingMacro, key, t.name) end
		elseif b.spell then
			ok, res = pcall(SetBindingSpell, key, ns.L(b.spell))
		elseif b.click then
			ok, res = pcall(SetBindingClick, key, b.click, b.button or "LeftButton")
		elseif b.command then
			ok, res = pcall(SetBinding, key, b.command)
		end
		if ok and res ~= false then
			count = count + 1
		else
			table.insert(errors, key .. ": " .. tostring(res))
		end
	end
	pcall(SaveBindings, bindingSet())
	ns.char.lastPreset = id
	ns.fire("BINDINGS_CHANGED")
	return count, errors
end

-- Återställer alla tangenter som Farseer har ändrat
function BE:Restore()
	if InCombatLockdown() then return 0, { "kan inte ändra keybinds i strid" } end
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
