-- /farseer och /fsr

local _, ns = ...

local HELP = {
	"|cffffd100/farseer|r — open settings",
	"|cffffd100/farseer lock|r / |cffffd100unlock|r — lock or unlock bars to move them",
	"|cffffd100/farseer pve|r / |cffffd100pvp|r — switch situation mode",
	"|cffffd100/farseer test|r — test a warning",
	"|cffffd100/farseer macros <category>|r — create all macros in a category (" .. table.concat(ns.MACRO_CATEGORIES or {}, ", ") .. ")",
	"|cffffd100/farseer bind <template> [shift|ctrl|alt] [keep]|r — apply a keybind template (elemental, enhancement, restoration, pvp, totems, healmouse, situations, mouse). shift = put it on Shift+key, keep = only use free keys",
	"|cffffd100/farseer restore|r — restore keys Farseer has changed",
	"|cffffd100/farseer bis|r — open the BiS list",
	"|cffffd100/farseer check|r — pre-raid checklist (shield, imbue, food, flask, Ankh ...)",
	"|cffffd100/farseer trainer|r — what's waiting at the trainer",
	"|cffffd100/farseer gear <set>|r — switch equipment set",
	"|cffffd100/farseer profile save|load <name>|r — save or load a profile",
	"|cffffd100/farseer t05|r — the Five Thunders chain",
	"|cffffd100/farseer spec|r — show detected spec (and switch profile if the spec changed)",
	"|cffffd100/farseer click <template>|r / |cffffd100click restore|r — click-cast template (heal_mods, heal_direct, offheal)",
	"|cffffd100/farseer raid|r / |cffffd100raid send|r — totem assignments between shamans",
	"|cffffd100/farseer debug|r — show errors and totem slots",
}

function ns.Slash(msg)
	msg = ns.trim(msg)
	local cmd, rest = msg:match("^(%S+)%s*(.-)$")
	cmd = (cmd or ""):lower()
	if cmd == "" then
		ns.Options:Toggle()
	elseif cmd == "help" or cmd == "?" then
		for _, l in ipairs(HELP) do ns.print(l) end
	elseif cmd == "lock" then
		ns.setLocked(true)
	elseif cmd == "unlock" then
		ns.setLocked(false)
	elseif cmd == "pve" or cmd == "pvp" then
		ns.Bars:SetMode(cmd:upper())
	elseif cmd == "test" then
		ns.Alert:Test()
	elseif cmd == "macros" then
		local want = rest:lower()
		for _, c in ipairs(ns.MACRO_CATEGORIES) do
			if c:lower() == want then ns.MacroEngine:CreateCategory(c) return end
		end
		ns.print("categories: %s", table.concat(ns.MACRO_CATEGORIES, ", "))
	elseif cmd == "bind" then
		-- /farseer bind <mall> [shift|ctrl|alt] [keep]
		local words = {}
		for w in rest:lower():gmatch("%S+") do table.insert(words, w) end
		local p = ns.BindingEngine:Preset(words[1] or "")
		local opts
		if #words > 1 then
			opts = { mod = "", keep = false }
			for i = 2, #words do
				local w = words[i]
				if w == "shift" or w == "ctrl" or w == "alt" then opts.mod = w:upper()
				elseif w == "keep" then opts.keep = true end
			end
		end
		if not p then
			local ids = {}
			for _, x in ipairs(ns.BINDING_PRESETS) do table.insert(ids, x.id) end
			ns.print("templates: %s", table.concat(ids, ", "))
			return
		end
		local n, errors, kept = ns.BindingEngine:Apply(p.id, opts)
		ns.print("%s: %d keybinds set%s.%s", p.name, n, (kept or 0) > 0 and (", " .. kept .. " kept") or "",
			#errors > 0 and (" Errors: " .. table.concat(errors, "; ")) or "")
	elseif cmd == "restore" then
		local n = ns.BindingEngine:Restore()
		ns.print("%d keys restored.", n)
	elseif cmd == "bis" then
		ns.Options:Open("bis")
	elseif cmd == "check" then
		ns.Leveling:ShowChecklist()
	elseif cmd == "trainer" then
		local list = ns.Spellbook:TrainerMissing()
		if #list == 0 then ns.print("nothing new at the trainer.") else
			ns.print("at the trainer: %s", ns.Leveling:TrainerText(list))
		end
	elseif cmd == "gear" then
		if rest == "" then
			local names = {}
			for _, s in ipairs(ns.Gear:Sets()) do table.insert(names, s.name) end
			ns.print("your sets: %s", #names > 0 and table.concat(names, ", ") or "(none)")
		else
			ns.Gear:Equip(rest)
		end
	elseif cmd == "profile" then
		local sub, name = rest:match("^(%S+)%s*(.-)$")
		sub = (sub or ""):lower()
		if sub == "save" and name ~= "" then
			local ok, err = ns.Profiles:Save(name)
			ns.print(ok and ("profile saved: " .. name) or err)
		elseif sub == "load" and name ~= "" then
			local ok, err = ns.Profiles:Load(name)
			ns.print(ok and ("profile loaded: " .. name) or err)
		else
			ns.Options:Open("profiles")
		end
	elseif cmd == "t05" then
		ns.Options:Open("t05")
	elseif cmd == "spec" then
		local spec, how = ns.Spec:Detect()
		ns.print("spec: %s (%s)", spec and ns.SPEC_NAME[spec] or "unknown", tostring(how))
		ns.Spec:Check()
	elseif cmd == "click" then
		local want = rest:lower()
		if want == "restore" then
			local ok, err = ns.ClickCast:Restore()
			ns.print(ok and "click-cast restored." or ("click-cast: " .. tostring(err)))
		elseif ns.ClickCast:Template(want) then
			local ok, n, missing, note = ns.ClickCast:Apply(want)
			ns.print("click-cast %s: %s%s%s", want, ok and (n .. " bindings set") or "failed",
				#missing > 0 and (", missing: " .. table.concat(missing, ", ")) or "", note and (" (" .. note .. ")") or "")
		else
			ns.Options:Open("healing")
		end
	elseif cmd == "raid" then
		if rest:lower() == "send" then
			local ok, err = ns.RaidTotems:Send()
			if not ok or err then ns.print("totems: %s", tostring(err or "sent")) end
		else
			local lines = ns.RaidTotems:Lines()
			if #lines == 0 then ns.print("no shamans in the group.") end
			for _, l in ipairs(lines) do ns.print(l) end
		end
	elseif cmd == "debug" then
		ns.print("version %s, shaman: %s, mode: %s", ns.VERSION, tostring(ns.isShaman), ns.Bars:Mode())
		for slot = 1, 4 do
			local ok, have, name, start, dur = ns.getAll(GetTotemInfo, slot)
			ns.print("totem slot %d (%s): read=%s have=%s name=%s dur=%s | tracked: %s", slot, ns.SLOT_ELEMENT[slot],
				tostring(ok), tostring(have), tostring(name), tostring(dur), tostring(ns.Totems:SlotTotem(slot)))
		end
		local secret = C_Secrets and C_Secrets.ShouldAurasBeSecret and ns.get(C_Secrets.ShouldAurasBeSecret)
		ns.print("auras secret now: %s, in combat: %s", tostring(secret), tostring(InCombatLockdown()))
		ns.print("maelstrom display: %s", ns.Procs:MaelstromBoxState())
		ns.print("shield display: %s", ns.Procs:ShieldBoxState())
		ns.print("Call with any set in combat: %s", ns.Bars.combatCallState or "?")
		local call, set = ns.Bars:CallSpell()
		if call then
			local c = ns.Totems:CallSetContents(set)
			ns.print("%s contains: %s, %s, %s, %s", call, tostring(c[2]), tostring(c[1]), tostring(c[3]), tostring(c[4]))
		end
		if #ns.errors == 0 then ns.print("no errors this session.") end
		for i, e in ipairs(ns.errors) do ns.print("error %d: %s", i, e) end
	else
		for _, l in ipairs(HELP) do ns.print(l) end
	end
end

SLASH_FARSEER1 = "/farseer"
SLASH_FARSEER2 = "/fsr"
SlashCmdList.FARSEER = function(msg)
	local ok, err = pcall(ns.Slash, msg or "")
	if not ok then ns.report(err) end
end
