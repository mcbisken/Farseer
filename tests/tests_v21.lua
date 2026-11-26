-- v2.2: fixar från genomgången av hela addonet

local ns = FARSEER_NS
local test, check = TEST, CHECK

test("v21: Water Shield visas som Water Shield (eget aura-ID per sköld)", function()
	local PC = ns.Procs
	local old = MOCK.auras.player
	MOCK.auras.player = { { name = "Water Shield", spellId = 408510, auraInstanceID = 77, applications = 3 } }
	MOCK.learn("Lightning Shield")
	MOCK.learn("Water Shield")
	ns.Spellbook:Scan()
	PC:ResetShieldBox()
	local s1, n1 = PC:Shield()
	local s2 = PC:Shield()
	local s3 = PC:Shield()
	check(s1 == "Water Shield" and n1 == 3, "första läsningen: " .. tostring(s1) .. " " .. tostring(n1))
	check(s2 == "Water Shield" and s3 == "Water Shield", "följande läsningar också: " .. tostring(s2) .. ", " .. tostring(s3))
	MOCK.auras.player = old
	PC:ResetShieldBox()
	MOCK.unlearn("Water Shield")
	MOCK.unlearn("Lightning Shield")
	ns.Spellbook:Scan()
	MOCK.runTimers()
end)

test("v21: cooldown som inte går att läsa: egen klocka", function()
	local PC = ns.Procs
	local orig = C_Spell.GetSpellCooldown
	C_Spell.GetSpellCooldown = function() return SECRET end
	local t0 = MOCK.time
	PC:OnPlayerCast(MOCK.known["Mana Tide Totem"])
	check(PC:Ready("Mana Tide Totem") == false, "Mana Tide nyss castad: inte redo")
	MOCK.time = t0 + 301
	check(PC:Ready("Mana Tide Totem") == true, "5 min senare: redo")
	MOCK.time = t0
	ns.HUD:OnReadyCast("Frost Shock")
	check(PC:Ready("Earth Shock") == false, "shock-cooldown via HUD:ens klocka")
	MOCK.time = t0 + 7
	check(PC:Ready("Earth Shock") == true, "efter 6 s: redo")
	MOCK.time = t0
	C_Spell.GetSpellCooldown = orig
end)

test("v21: info-flash flimrar inte över rådgivarens förslag", function()
	local AL = ns.Alert
	ns.db.alert.mode = "always"
	AL:Hide(true)
	check(AL:Show("adv", "Tremor Totem", "TREMOR", "x", nil, nil, "advice"), "förslaget visas")
	check(AL:Flash("inf", "Searing Totem", "TOTEM DIED", "y", nil, 3, "info"), "flashen visas")
	check(AL:Show("adv", "Tremor Totem", "TREMOR", "x", nil, nil, "advice") == false, "förslaget väntar tills flashen är klar")
	check(AL:Current() == "inf", "flashen står kvar")
	MOCK.runTimers()
	check(AL:Show("adv", "Tremor Totem", "TREMOR", "x", nil, nil, "advice"), "sedan tillbaka")
	check(AL:Show("crit", "Tremor Totem", "FEAR", "z", nil, nil, "critical"), "kritiskt går alltid före")
	AL:Hide(true)
end)

test("v21: totem med oläsbart namn räknas inte som borta", function()
	local TO = ns.Totems
	local slot = ns.SLOT.FIRE
	MOCK.totems[slot] = { name = "Searing Totem", start = MOCK.time, dur = 55 }
	check(TO:ReadSlot(slot) and TO:SlotTotem(slot) == "Searing Totem", "läst")
	local orig = GetTotemInfo
	rawset(_G, "GetTotemInfo", function() return true, SECRET, SECRET, SECRET, 1000 end)
	check(TO:ReadSlot(slot) == false, "namnet secret: läsningen räknas inte")
	check(TO:SlotTotem(slot) == "Searing Totem", "totemet finns kvar i spårningen")
	rawset(_G, "GetTotemInfo", orig)
	MOCK.totems[slot] = nil
	TO:ReadSlot(slot)
	check(TO:SlotTotem(slot) == nil, "tom slot: borta")
end)

test("v21: ett nytt totem i slotten är ingen död", function()
	local TO = ns.Totems
	local slot = ns.SLOT.AIR
	ns.char.totemAlerts.death = true
	local prev = { name = "Windfury Totem", start = MOCK.time - 10, dur = 120 }
	MOCK.totems[slot] = { name = "Grace of Air Totem", start = MOCK.time, dur = 120 }
	ns.Alert:Hide(true)
	TO:CheckDeath(slot, prev)
	check(ns.Alert:Current() ~= "died-Windfury Totem", "ersatt, inte dödat")
	check(TO:SlotTotem(slot) == "Grace of Air Totem", "det nya totemet spåras")
	MOCK.totems[slot] = nil
	TO:ReadSlot(slot)
end)

test("v21: dolda situationsknappar avväpnas", function()
	local BA = ns.Bars
	local list = BA:List(BA:Mode())
	local n = #list
	check(n >= 2, "minst två situationer")
	local s = list[n]
	s.hidden = true
	BA:ApplySituations()
	local b = _G["FarseerSit" .. n]
	check(b:GetAttribute("type") == nil and b:GetAttribute("*type2") == nil and b:GetAttribute("*macrotext2") == nil,
		"inga attribut kvar på den dolda knappen")
	s.hidden = nil
	BA:ApplySituations()
	check(b:GetAttribute("type") == "macro", "tillbaka när den visas")
end)

test("v21: profiler", function()
	local PR = ns.Profiles
	local rez = ns.char.bars.rez
	local snap = PR:Snapshot()
	snap.char.bars.rez = nil   -- som en profil sparad före v1.8
	ns.db.custom = ns.db.custom or {}
	local before = #ns.db.custom
	local ok = PR:Apply(snap)
	check(ok, "laddad")
	check(ns.char.bars.rez == rez, "samma bar-tabell (ramen tappar inte sina inställningar)")
	check(type(rez.point) == "string", "fylld från standardvärdena")
	-- Spec-byte: kontots listor rörs inte
	ns.db.profiles["v21test"] = PR:Snapshot()
	table.insert(ns.db.custom, { name = "FS v21", body = "/say x" })
	check(PR:Load("v21test", { charOnly = true }), "laddad vid spec-byte")
	check(#ns.db.custom == before + 1, "makrot som lades till efteråt finns kvar")
	PR:Load("v21test")
	check(#ns.db.custom == before, "manuell laddning tar profilens lista")
	ns.db.profiles["v21test"] = nil
	ns.char.profile = nil
end)

test("v21: keybinds", function()
	local KM, BE = ns.KeyMode, ns.BindingEngine
	check(KM.MouseFor(_G.FarseerTotemFIRE) == "RightButton", "totemknapp: högerklick (förstör totemet)")
	check(KM.MouseFor(_G.FarseerTotemicCall) == "LeftButton", "Totemic Call: vänsterklick")
	check(KM.MouseFor(_G.FarseerSit1) == "LeftButton", "situation: vänsterklick")
	MOCK.combat = false
	check(KM:Bind(_G.FarseerTotemFIRE, "F10"), "binder")
	check(MOCK.bindings["F10"] == "CLICK FarseerTotemFIRE:RightButton", "på högerklicket")
	MOCK.bindings["F11"] = "CLICK FarseerSit2:RightButton"
	KM:Clear(_G.FarseerSit2)
	check((MOCK.bindings["F11"] or "") == "", "Delete tar bort högerklicksbindningen också")
	-- Restore behåller det som inte gick att återställa
	BE:Restore()
	ns.char.bindBackup["F12"] = "ACTIONBUTTON12"
	local orig = SetBinding
	rawset(_G, "SetBinding", function(key, action) if key == "F12" then return false end return orig(key, action) end)
	local _, errors = BE:Restore()
	check(#errors == 1 and ns.char.bindBackup["F12"] == "ACTIONBUTTON12", "misslyckad tangent ligger kvar i backupen")
	rawset(_G, "SetBinding", orig)
	BE:Restore()
	check(next(ns.char.bindBackup) == nil, "andra försöket: tomt")
end)

test("v21: raidplan räknar inte jägare som melee", function()
	local plan = ns.RaidTotems:Plan({
		{ name = "Sham", group = 1, class = "SHAMAN", me = true },
		{ name = "H1", group = 1, class = "HUNTER" }, { name = "H2", group = 1, class = "HUNTER" },
		{ name = "M1", group = 1, class = "MAGE" },
	})
	check(plan[1] and plan[1].kind == "caster", "jägargrupp får caster-setet: " .. tostring(plan[1] and plan[1].kind))
end)

test("v21: Escape på en meny stänger inte fönstret", function()
	ns.Options:Open("settings")
	rawset(_G, "UISpecialFrames", UISpecialFrames or {})
	local function has(name)
		for _, n in ipairs(UISpecialFrames) do if n == name then return true end end
		return false
	end
	local hadMain = has("FarseerOptions")
	local anchor = CreateFrame("Button", nil, UIParent)
	ns.UI.Menu(anchor, { { text = "a", value = 1 } }, function() end)
	local menu = _G.FarseerMenu
	if menu and menu.__scripts and menu.__scripts.OnShow then menu.__scripts.OnShow(menu) end
	check(not has("FarseerOptions") or not hadMain, "huvudfönstret ur listan medan menyn är öppen")
	ns.UI.HideMenu()
	if menu and menu.__scripts and menu.__scripts.OnHide then menu.__scripts.OnHide(menu) end
	check(has("FarseerOptions") == hadMain, "tillbaka när menyn stängs")
	ns.Options:Hide()
end)
