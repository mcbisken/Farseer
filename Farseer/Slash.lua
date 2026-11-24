-- /farseer och /fsr

local _, ns = ...

local HELP = {
	"|cffffd100/farseer|r — öppna inställningarna",
	"|cffffd100/farseer lock|r / |cffffd100unlock|r — lås eller lås upp bars för att flytta dem",
	"|cffffd100/farseer pve|r / |cffffd100pvp|r — byt situationsläge",
	"|cffffd100/farseer test|r — testa en varning",
	"|cffffd100/farseer macros <kategori>|r — skapa alla makron i en kategori (Elemental, Enhancement, Restoration, Totems, PvP, Verktyg)",
	"|cffffd100/farseer bind <mall>|r — applicera keybind-mall (elemental, enhancement, restoration, pvp, situations, mouse)",
	"|cffffd100/farseer restore|r — återställ tangenter som Farseer har ändrat",
	"|cffffd100/farseer bis|r — öppna BiS-listan",
	"|cffffd100/farseer check|r — checklista före raid (sköld, imbue, mat, flaska, Ankh ...)",
	"|cffffd100/farseer trainer|r — vad som väntar hos trainern",
	"|cffffd100/farseer gear <set>|r — byt utrustningsset",
	"|cffffd100/farseer profile save|load <namn>|r — spara eller ladda en profil",
	"|cffffd100/farseer t05|r — Five Thunders-kedjan",
	"|cffffd100/farseer spec|r — visa avkänd spec (och byt profil om specen ändrats)",
	"|cffffd100/farseer click <mall>|r / |cffffd100click restore|r — click-cast-mall (heal_mods, heal_direct, offheal)",
	"|cffffd100/farseer raid|r / |cffffd100raid send|r — totemfördelning mellan shamans",
	"|cffffd100/farseer debug|r — visa fel och totemslottar",
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
		ns.print("kategorier: %s", table.concat(ns.MACRO_CATEGORIES, ", "))
	elseif cmd == "bind" then
		local p = ns.BindingEngine:Preset(rest:lower())
		if not p then
			local ids = {}
			for _, x in ipairs(ns.BINDING_PRESETS) do table.insert(ids, x.id) end
			ns.print("mallar: %s", table.concat(ids, ", "))
			return
		end
		local n, errors = ns.BindingEngine:Apply(p.id)
		ns.print("%s: %d keybinds satta.%s", p.name, n, #errors > 0 and (" Fel: " .. table.concat(errors, "; ")) or "")
	elseif cmd == "restore" then
		local n = ns.BindingEngine:Restore()
		ns.print("%d tangenter återställda.", n)
	elseif cmd == "bis" then
		ns.Options:Open("bis")
	elseif cmd == "check" then
		ns.Leveling:ShowChecklist()
	elseif cmd == "trainer" then
		local list = ns.Spellbook:TrainerMissing()
		if #list == 0 then ns.print("inget nytt hos trainern.") else
			ns.print("hos trainern: %s", ns.Leveling:TrainerText(list))
		end
	elseif cmd == "gear" then
		if rest == "" then
			local names = {}
			for _, s in ipairs(ns.Gear:Sets()) do table.insert(names, s.name) end
			ns.print("dina set: %s", #names > 0 and table.concat(names, ", ") or "(inga)")
		else
			ns.Gear:Equip(rest)
		end
	elseif cmd == "profile" then
		local sub, name = rest:match("^(%S+)%s*(.-)$")
		sub = (sub or ""):lower()
		if sub == "save" and name ~= "" then
			local ok, err = ns.Profiles:Save(name)
			ns.print(ok and ("profil sparad: " .. name) or err)
		elseif sub == "load" and name ~= "" then
			local ok, err = ns.Profiles:Load(name)
			ns.print(ok and ("profil laddad: " .. name) or err)
		else
			ns.Options:Open("profiles")
		end
	elseif cmd == "t05" then
		ns.Options:Open("t05")
	elseif cmd == "spec" then
		local spec, how = ns.Spec:Detect()
		ns.print("spec: %s (%s)", spec and ns.SPEC_NAME[spec] or "okänd", tostring(how))
		ns.Spec:Check()
	elseif cmd == "click" then
		local want = rest:lower()
		if want == "restore" then
			local ok, err = ns.ClickCast:Restore()
			ns.print(ok and "click-cast återställd." or ("click-cast: " .. tostring(err)))
		elseif ns.ClickCast:Template(want) then
			local ok, n, missing, note = ns.ClickCast:Apply(want)
			ns.print("click-cast %s: %s%s%s", want, ok and (n .. " bindningar satta") or "gick inte",
				#missing > 0 and (", saknas: " .. table.concat(missing, ", ")) or "", note and (" (" .. note .. ")") or "")
		else
			ns.Options:Open("healing")
		end
	elseif cmd == "raid" then
		if rest:lower() == "send" then
			local ok, err = ns.RaidTotems:Send()
			if not ok or err then ns.print("totems: %s", tostring(err or "skickat")) end
		else
			local lines = ns.RaidTotems:Lines()
			if #lines == 0 then ns.print("inga shamans i gruppen.") end
			for _, l in ipairs(lines) do ns.print(l) end
		end
	elseif cmd == "debug" then
		ns.print("version %s, shaman: %s, läge: %s", ns.VERSION, tostring(ns.isShaman), ns.Bars:Mode())
		for slot = 1, 4 do
			local ok, have, name, start, dur = ns.getAll(GetTotemInfo, slot)
			ns.print("totemslot %d (%s): läst=%s have=%s namn=%s dur=%s | spårat: %s", slot, ns.SLOT_ELEMENT[slot],
				tostring(ok), tostring(have), tostring(name), tostring(dur), tostring(ns.Totems:SlotTotem(slot)))
		end
		local secret = C_Secrets and C_Secrets.ShouldAurasBeSecret and ns.get(C_Secrets.ShouldAurasBeSecret)
		ns.print("auror secret nu: %s, i strid: %s", tostring(secret), tostring(InCombatLockdown()))
		local call, set = ns.Bars:CallSpell()
		if call then
			local c = ns.Totems:CallSetContents(set)
			ns.print("%s innehåller: %s, %s, %s, %s", call, tostring(c[2]), tostring(c[1]), tostring(c[3]), tostring(c[4]))
		end
		if #ns.errors == 0 then ns.print("inga fel denna session.") end
		for i, e in ipairs(ns.errors) do ns.print("fel %d: %s", i, e) end
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
