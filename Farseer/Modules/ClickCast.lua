-- Click-cast: skriver mallar (Data/ClickCast.lua) till Blizzards inbyggda Click Casting, som gäller på
-- raid- och gruppramarna. Spelets profil sparas först så att den kan återställas.
-- Osäkert i Forever: om addons får skriva till C_ClickBindings. Allt sker i pcall och resultatet läses
-- tillbaka, så Farseer säger ifrån i stället för att låtsas att det gick.

local _, ns = ...
local CC = ns.module("ClickCast")

local TYPE_SPELL = Enum and Enum.ClickBindingType and Enum.ClickBindingType.Spell or 1
local TYPE_INTERACTION = Enum and Enum.ClickBindingType and Enum.ClickBindingType.Interaction or 3
local INTERACTION = {
	target = Enum and Enum.ClickBindingInteraction and Enum.ClickBindingInteraction.Target or 1,
	menu = Enum and Enum.ClickBindingInteraction and Enum.ClickBindingInteraction.OpenContextMenu or 2,
}

function CC:Available()
	local B = C_ClickBindings
	return B ~= nil and B.GetProfileInfo ~= nil and B.SetProfileByInfo ~= nil
end

function CC:Template(id)
	for _, t in ipairs(ns.CLICKCAST) do if t.id == id then return t end end
end

-- Modifierarnas bitar läses ur klienten: GetStringFromModifiers(bit) -> "SHIFT" ...
local modBits
function CC:ModBits()
	if modBits and next(modBits) then return modBits end
	modBits = {}
	local f = C_ClickBindings and C_ClickBindings.GetStringFromModifiers
	if not f then return modBits end
	local loose = {}
	for b = 0, 15 do
		local m = 2 ^ b
		local s = ns.get(f, m)
		if type(s) == "string" then
			local u = s:upper():gsub("[%-%s]", "")
			for _, k in ipairs({ "SHIFT", "CTRL", "ALT" }) do
				if u == k then modBits[k] = modBits[k] or m
				elseif u:find(k, 1, true) and not loose[k] then loose[k] = m end
			end
		end
	end
	for k, m in pairs(loose) do modBits[k] = modBits[k] or m end
	return modBits
end

-- "shift-ctrl" -> bitmask, eller nil om någon modifierare inte gick att hitta
function CC:Mask(mods)
	local mask = 0
	if not mods or mods == "" then return 0 end
	local bits = self:ModBits()
	for m in mods:gmatch("[^%-]+") do
		local b = bits[m:upper()]
		if not b then return nil end
		mask = mask + b
	end
	return mask
end

local function plainList(list)
	local out = {}
	if type(list) ~= "table" or ns.isSecret(list) then return out end
	for _, b in ipairs(list) do
		table.insert(out, { type = ns.field(b, "type"), actionID = ns.field(b, "actionID"),
			button = ns.field(b, "button"), modifiers = ns.field(b, "modifiers") or 0 })
	end
	return out
end

function CC:Current()
	if not self:Available() then return {} end
	return plainList(ns.get(C_ClickBindings.GetProfileInfo))
end

-- Vad mallen blir: lista ClickBindingInfo, saknade spells, modifierare som inte gick att översätta
function CC:Build(t)
	local out, missing, badMods = {}, {}, {}
	for _, b in ipairs(t.binds) do
		local mask = self:Mask(b[2])
		if not mask then
			table.insert(badMods, b[2])
		elseif b.interaction then
			table.insert(out, { type = TYPE_INTERACTION, actionID = INTERACTION[b.interaction], button = b[1], modifiers = mask })
		else
			local id = ns.Spellbook:ID(b[3])
			if id then
				table.insert(out, { type = TYPE_SPELL, actionID = id, button = b[1], modifiers = mask, spell = b[3] })
			else
				table.insert(missing, b[3])
			end
		end
	end
	return out, missing, badMods
end

-- Lägger mallen ovanpå spelets nuvarande click-cast (samma knapp + modifierare ersätts)
-- Returnerar ok, antal, saknade, fel
function CC:Apply(id)
	if InCombatLockdown() then return false, 0, {}, "can't be changed in combat" end
	if not self:Available() then return false, 0, {}, "the client doesn't have Click Casting (C_ClickBindings)" end
	local t = self:Template(id)
	if not t then return false, 0, {}, "unknown template" end
	local add, missing, badMods = self:Build(t)
	if #add == 0 then return false, 0, missing, "nothing to add (no known spells)" end
	local current = self:Current()
	if not ns.char.clickBackup then ns.char.clickBackup = ns.copy(current) end
	local taken = {}
	for _, b in ipairs(add) do taken[b.button .. ":" .. b.modifiers] = true end
	local new = {}
	for _, b in ipairs(current) do
		if not taken[tostring(b.button) .. ":" .. tostring(b.modifiers)] then table.insert(new, b) end
	end
	for _, b in ipairs(add) do
		table.insert(new, { type = b.type, actionID = b.actionID, button = b.button, modifiers = b.modifiers })
	end
	local ok, err = pcall(C_ClickBindings.SetProfileByInfo, new)
	if not ok then return false, 0, missing, "the client refused: " .. tostring(err) end
	-- Läs tillbaka: syns våra bindningar?
	local after, found = self:Current(), 0
	for _, b in ipairs(add) do
		for _, a in ipairs(after) do
			if a.button == b.button and a.modifiers == b.modifiers and a.actionID == b.actionID then found = found + 1 break end
		end
	end
	if found == 0 then return false, 0, missing, "the client didn't save the change" end
	local note = #badMods > 0 and ("modifiers not found: " .. table.concat(badMods, ", ")) or nil
	return true, found, missing, note
end

function CC:Restore()
	if InCombatLockdown() then return false, "can't be changed in combat" end
	local backup = ns.char.clickBackup
	if not backup then return false, "nothing to restore" end
	if not self:Available() then return false, "the client doesn't have Click Casting" end
	local ok, err = pcall(C_ClickBindings.SetProfileByInfo, backup)
	if not ok then return false, tostring(err) end
	ns.char.clickBackup = nil
	return true
end

-- Läsbar text för en bindning
local BUTTON = { LeftButton = "Left", RightButton = "Right", MiddleButton = "Middle", Button4 = "Button 4", Button5 = "Button 5" }
function CC:Describe(b)
	local mods = b[2] ~= "" and (b[2]:gsub("shift", "Shift"):gsub("ctrl", "Ctrl"):gsub("alt", "Alt"):gsub("%-", "+") .. " + ") or ""
	local what = b.interaction == "target" and "target" or b.interaction == "menu" and "menu" or b[3]
	return mods .. (BUTTON[b[1]] or b[1]) .. ": " .. what
end
