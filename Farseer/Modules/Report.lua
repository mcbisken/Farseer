-- Testrapport (/farseer report): kollar de delar av klienten som Farseer bygger på, visar testlistans
-- resultat, vad som kostar mest tid och de senaste felen — i en ruta att kopiera och klistra in.

local _, ns = ...
local RP = ns.module("Report")

local win

local function yn(v) return v and "yes" or "no" end

local function addonLoaded(name)
	local f = (C_AddOns and C_AddOns.IsAddOnLoaded) or rawget(_G, "IsAddOnLoaded")
	return f and ns.get(f, name) == true
end

local function memoryKB()
	pcall(rawget(_G, "UpdateAddOnMemoryUsage") or function() end)
	local f = (C_AddOns and C_AddOns.GetAddOnMemoryUsage) or rawget(_G, "GetAddOnMemoryUsage")
	local v = f and ns.get(f, ns.ADDON or "Farseer")
	return type(v) == "number" and v or nil
end

-- Raderna i rapporten
function RP:Lines()
	local L = {}
	local function add(fmt, ...) table.insert(L, select("#", ...) > 0 and string.format(fmt, ...) or fmt) end
	local ok, ver, build, _, iface = ns.getAll(GetBuildInfo)
	add("Farseer %s report  (client %s build %s, interface %s, %s)", tostring(ns.VERSION), tostring(ok and ver),
		tostring(ok and build), tostring(ok and iface), tostring(ns.get(GetLocale)))
	add("Character: level %s, spec %s, mode %s, in group %s, in instance %s", tostring(ns.get(UnitLevel, "player")),
		tostring(ns.Spec and ns.Spec:Current() or "?"), ns.Bars and ns.Bars:Mode() or "?",
		yn(ns.get(IsInGroup) == true), yn(ns.get(IsInInstance) == true))
	add("Look: %s", ns.Theme and ns.Theme.Classic() and "classic" or "modern")
	add("")
	add("== Client features ==")
	local PC = ns.Procs
	add("Aura container (Maelstrom): %s", PC and PC:MaelstromBoxState() or "?")
	add("Aura container (shield): %s", PC and PC.ShieldBoxState and PC:ShieldBoxState() or "?")
	add("Call with any set in combat: %s", ns.Bars and ns.Bars.combatCallState or "?")
	add("SetMultiCastSpell: %s", yn(rawget(_G, "SetMultiCastSpell") ~= nil))
	local getBool = (C_CVar and C_CVar.GetCVarBool) or rawget(_G, "GetCVarBool")
	add("ActionButtonUseKeyDown: %s", tostring(ns.get(getBool, "ActionButtonUseKeyDown")))
	add("Number formatter (C_StringUtil): %s", yn(C_StringUtil and C_StringUtil.CreateNumericRuleFormatter))
	local voices = C_VoiceChat and C_VoiceChat.GetTtsVoices and ns.get(C_VoiceChat.GetTtsVoices)
	add("Text to speech: TextToSpeech_Speak %s, C_VoiceChat.SpeakText %s, voices %s",
		yn(rawget(_G, "TextToSpeech_Speak")), yn(C_VoiceChat and C_VoiceChat.SpeakText),
		type(voices) == "table" and tostring(#voices) or "?")
	local seen = ns.HUD and ns.HUD.swingSeen or {}
	add("PLAYER_SWING events: main hand %d, off-hand %d", seen.main or 0, seen.off or 0)
	local secret = C_Secrets and C_Secrets.ShouldAurasBeSecret and ns.get(C_Secrets.ShouldAurasBeSecret)
	add("Auras secret now: %s, in combat: %s", tostring(secret), yn(InCombatLockdown()))
	add("UnitInRange(party1): %s", tostring(ns.get(UnitInRange, "party1")))
	add("Boss mods: DBM %s, BigWigs %s", yn(addonLoaded("DBM-Core")), yn(addonLoaded("BigWigs") or addonLoaded("BigWigs_Core")))
	add("Fishing pole check (C_Item.GetItemInfoInstant): %s", yn(C_Item and C_Item.GetItemInfoInstant))
	for slot = 1, 4 do
		local rok, have, name, _, dur = ns.getAll(GetTotemInfo, slot)
		add("Totem slot %d (%s): readable %s, have %s, %s %s s | tracked %s", slot, tostring(ns.SLOT_ELEMENT[slot]),
			yn(rok and have ~= nil), tostring(have), tostring(name), tostring(dur), tostring(ns.Totems:SlotTotem(slot)))
	end
	local call, set
	if ns.Bars then call, set = ns.Bars:CallSpell() end
	if call and set then
		local c = ns.Totems:CallSetContents(set)
		add("%s contains: %s, %s, %s, %s", call, tostring(c[2]), tostring(c[1]), tostring(c[3]), tostring(c[4]))
	end
	add("")
	add("== Test checklist ==")
	local okN, badN, total = 0, 0, 0
	for _, it in ipairs(ns.TEST_PLAN or {}) do
		total = total + 1
		local st = ns.db.testlist and ns.db.testlist[it.id]
		if st == "ok" then okN = okN + 1 elseif st == "bad" then badN = badN + 1 end
		add("[%s] %s%s", st == "ok" and "OK" or st == "bad" and "BROKEN" or " - ", it.title,
			(ns.db.testnotes and ns.db.testnotes[it.id] and ns.db.testnotes[it.id] ~= "") and ("  — " .. ns.db.testnotes[it.id]) or "")
	end
	add("%d of %d tested, %d broken", okN + badN, total, badN)
	add("")
	add("== Load ==")
	local list = {}
	for _, t in ipairs(ns.tasks or {}) do table.insert(list, t) end
	table.sort(list, function(a, b) return a.ms > b.ms end)
	local totalMs = 0
	for _, t in ipairs(list) do totalMs = totalMs + t.ms end
	local mem = memoryKB()
	add("Memory: %s KB, CPU in timers this session: %.0f ms", mem and string.format("%.0f", mem) or "?", totalMs)
	for i = 1, math.min(6, #list) do
		local t = list[i]
		add("  %s (every %s): %.1f ms over %d runs (%.3f ms each)", t.name, tostring(t.interval), t.ms, t.runs,
			t.runs > 0 and t.ms / t.runs or 0)
	end
	add("")
	add("== Errors (%d) ==", #ns.errors)
	for i = math.max(1, #ns.errors - 19), #ns.errors do
		local e = tostring(ns.errors[i]):gsub("\n", " | ")
		if #e > 400 then e = e:sub(1, 400) .. " ..." end
		add("%d: %s", i, e)
	end
	if #ns.errors == 0 then add("none") end
	return L
end

function RP:Text() return table.concat(self:Lines(), "\n") end

-- Fönstret med texten markerad (Ctrl+C kopierar)
function RP:Show()
	local UI, T = ns.UI, ns.Theme
	if not win then
		win = CreateFrame("Frame", "FarseerReport", UIParent, "BackdropTemplate")
		win:SetSize(620, 460)
		win:SetPoint("CENTER")
		win:SetFrameStrata("FULLSCREEN_DIALOG")
		win:SetMovable(true)
		win:EnableMouse(true)
		win:RegisterForDrag("LeftButton")
		win:SetScript("OnDragStart", win.StartMoving)
		win:SetScript("OnDragStop", win.StopMovingOrSizing)
		T.Skin(win, T.C.bg, T.C.border, 0.98)
		T.Shadow(win, 6)
		table.insert(UISpecialFrames, "FarseerReport")
		local title = UI.Header(win, "Farseer test report")
		title:SetPoint("TOPLEFT", 16, -14)
		local hint = UI.Label(win, "Ctrl+A selects everything, Ctrl+C copies. Paste it to whoever is fixing Farseer.", "GameFontDisableSmall")
		hint:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
		local box, edit = UI.MultiLine(win, 588, 360)
		box:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -8)
		win.edit = edit
		local close = UI.Button(win, "Close", 90, 24, function() win:Hide() end)
		close:SetPoint("BOTTOMRIGHT", -14, 10)
		local again = UI.Button(win, "Refresh", 90, 24, function() RP:Show() end)
		again:SetPoint("RIGHT", close, "LEFT", -6, 0)
	end
	win:Show()
	win.edit:SetText(self:Text())
	win.edit:HighlightText()
	win.edit:SetFocus()
end
