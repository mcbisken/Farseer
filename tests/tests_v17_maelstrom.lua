-- v1.7: Maelstrom via Blizzards aura-container (spelet ritar stackarna även när de är secret i strid)

local ns = FARSEER_NS
local test, check = TEST, CHECK
local PC = ns.Procs

-- Falsk container: sparar anropen och skapar knappen direkt (som spelet gör när buffen matchar)
local function fakeContainer(calls, opts)
	opts = opts or {}
	local realCreate = CreateFrame
	rawset(_G, "CreateFrame", function(kind, name, parent, template)
		if kind ~= "AuraContainer" then return realCreate(kind, name, parent, template) end
		if opts.fail then error("CreateFrame: unknown frame type 'AuraContainer'") end
		calls.template = template
		local c = realCreate("Frame", name, parent)
		function c:SetUnit(u) calls.unit = u end
		function c:AddAuraSlot(slot, filter, o)
			calls.slot, calls.filter, calls.opts = slot, filter, o
			if opts.noButton then return end
			local b = realCreate("Frame", nil, c)
			calls.bars = {}
			function b:SetIcon(t) calls.icon = t end
			function b:SetApplicationCount(fs, o2) calls.count = fs; calls.countOpts = o2 end
			function b:SetApplicationBar(bar, o2)
				if opts.noBars then error("bars") end
				table.insert(calls.bars, o2)
				calls.barFrames = calls.barFrames or {}
				table.insert(calls.barFrames, bar)
			end
			function b:SetDurationCooldown(cd) calls.cd = cd end
			o.initializeFrame(b)
		end
		return c
	end)
	return function() rawset(_G, "CreateFrame", realCreate) end
end

local function learnMW()
	MOCK.learn("Maelstrom Weapon")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	ns.char.procs.maelstrom = true
end

test("v17: Maelstrom-container byggs och spelet ritar stackarna", function()
	learnMW()
	MOCK.combat = false
	PC:ResetMaelstromBox()
	local calls = {}
	local restore = fakeContainer(calls)
	local box = PC:SetupMaelstromBox()
	restore()
	check(type(box) == "table", "containern byggd")
	check(calls.template == "CustomAuraContainerTemplate", "rätt template")
	check(calls.unit == "player", "följer spelaren")
	check(calls.filter == "HELPFUL", "buffar")
	check(calls.opts and calls.opts.candidateFilters.includeSpellIDs[408505], "filter på Maelstrom-buffen 408505")
	check(calls.icon ~= nil, "spelet sätter ikonen")
	check(calls.count == nil, "inget spelets tal när siffer-brickan finns")
	check(calls.cd ~= nil, "tid kvar som svep")
	local full, stack
	for _, o in ipairs(calls.bars or {}) do
		if o.minApplications == 5 and o.maxApplications == 5 then full = true end
		if o.minApplications == 0 and o.maxApplications == 5 then stack = true end
	end
	check(full, "markering som bara fylls vid 5")
	check(stack, "stackbar 0-5")
	check(PC:MaelstromBox() ~= nil, "aktiv")
	check(PC:MaelstromBoxState() == "active, number: digit badge", "debug: active (" .. PC:MaelstromBoxState() .. ")")
	-- Vår ikon blir en svag platshållare, inget eget tal ovanpå spelets
	local f = _G.FarseerProcmaelstrom
	MOCK.combat = true
	PC:UpdateMaelstrom()
	check(f:IsShown(), "syns i strid")
	check(f.count:GetText() == "", "inget eget tal")
	check(not f.sensor:IsShown(), "vår egen 5-markering är av")
	MOCK.combat = false
	-- Byggs bara en gång
	check(PC:SetupMaelstromBox() == box, "samma box nästa gång")
	PC:ResetMaelstromBox()
	MOCK.unlearn("Maelstrom Weapon")
end)

test("v17: Maelstrom-container väntar och faller tillbaka", function()
	learnMW()
	PC:ResetMaelstromBox()
	local calls = {}
	local restore = fakeContainer(calls)
	-- I strid: väntar
	MOCK.combat = true
	check(PC:SetupMaelstromBox() == nil, "i strid: byggs inte")
	MOCK.combat = false
	-- Auror secret: väntar
	local oldSecrets = rawget(_G, "C_Secrets")
	rawset(_G, "C_Secrets", { ShouldAurasBeSecret = function() return true end })
	check(PC:SetupMaelstromBox() == nil, "auror secret: byggs inte")
	rawset(_G, "C_Secrets", oldSecrets)
	restore()
	-- Klienten saknar containern: false, gamla vägen ritar talet
	PC:ResetMaelstromBox()
	restore = fakeContainer(calls, { fail = true })
	check(PC:SetupMaelstromBox() == false, "ingen container -> false")
	restore()
	check(PC:MaelstromBox() == nil, "inte aktiv")
	check(PC:MaelstromBoxState():find("unavailable"), "debug: unavailable")
	MOCK.auras.player = { { name = "Maelstrom Weapon", spellId = 408505, applications = 3, auraInstanceID = 91 } }
	PC:UpdateMaelstrom()
	local f = _G.FarseerProcmaelstrom
	check(f.count:GetText() == "3", "gamla vägen: talet 3 (" .. tostring(f.count:GetText()) .. ")")
	check(f.sensor:IsShown(), "egen 5-markering på")
	-- Container utan knapp än (buffen har inte matchat): gamla vägen ritar fortfarande
	PC:ResetMaelstromBox()
	restore = fakeContainer(calls, { noButton = true })
	check(type(PC:SetupMaelstromBox()) == "table", "container byggd")
	restore()
	check(PC:MaelstromBox() == nil, "inte aktiv förrän spelet gett en knapp")
	check(PC:MaelstromBoxState() == "waiting for the buff", "debug: waiting")
	PC:UpdateMaelstrom()
	check(f.count:GetText() == "3", "talet ritas av oss under tiden")
	MOCK.auras.player = {}
	PC:ResetMaelstromBox()
	MOCK.unlearn("Maelstrom Weapon")
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)

test("v17: Maelstrom blinkar vid 5 och Stormstrike blinkar", function()
	learnMW()
	MOCK.combat = false
	PC:ResetMaelstromBox()
	ns.char.procs.flash = true
	local calls = {}
	local restore = fakeContainer(calls)
	local box = PC:SetupMaelstromBox()
	restore()
	check(box and box.fullPulse and box.fullPulse.on == true, "5-markeringen blinkar")
	check(box.flashPulse and box.flashPulse.on == true, "blixten över ikonen blinkar")
	local fives = 0
	for _, o in ipairs(calls.bars or {}) do
		if o.minApplications == 5 and o.maxApplications == 5 then fives = fives + 1 end
	end
	check(fives == 2, "markering och blixt fylls bara vid 5 (" .. fives .. ")")
	-- Av: fast ram, ingen blixt
	ns.char.procs.flash = false
	PC:StyleMaelstromBox()
	check(box.fullPulse.on == false, "blinkning av")
	check(not box.flash:IsShown(), "blixten dold")
	ns.char.procs.flash = true
	PC:StyleMaelstromBox()
	check(box.fullPulse.on == true and box.flash:IsShown(), "på igen")
	-- Animationen startas om när ramen visas igen
	local played = 0
	box.fullPulse.Play = function() played = played + 1 end
	box.full.__scripts.OnShow()
	check(played == 1, "startas om vid OnShow")
	PC:ResetMaelstromBox()
	MOCK.unlearn("Maelstrom Weapon")

	-- Stormstrike: glöden går medan ikonen syns, av när den döljs
	MOCK.learn("Stormstrike")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	ns.char.procs.stormstrike = true
	PC:StormstrikeCast()
	local ss = _G.FarseerProcstormstrike
	check(ss:IsShown(), "Stormstrike syns efter casten")
	check(ss.glow:IsShown(), "Stormstrike blinkar")
	ns.char.procs.flash = false
	PC:UpdateProcs()
	check(not ss.glow:IsShown(), "flash av: ingen blinkning")
	ns.char.procs.flash = true
	PC:UpdateProcs()
	check(ss.glow:IsShown(), "flash på igen")
	-- Clearcasting blinkar också
	MOCK.auras.player = { { name = "Clearcasting", spellId = 16246, applications = 0, auraInstanceID = 77 } }
	ns.char.procs.clearcast = true
	PC:UpdateProcs()
	local cc = _G.FarseerProcclearcast
	check(cc:IsShown() and cc.glow:IsShown(), "Clearcasting blinkar")
	-- Flurry blinkar också
	MOCK.auras.player = { { name = "Flurry", spellId = 16257, applications = 3, auraInstanceID = 78 } }
	local oldFlurry = ns.char.procs.flurry
	ns.char.procs.flurry = true
	PC:UpdateProcs()
	local fl = _G.FarseerProcflurry
	check(fl:IsShown() and fl.glow:IsShown(), "Flurry blinkar")
	ns.char.procs.flurry = oldFlurry
	MOCK.auras.player = {}
	MOCK.unlearn("Stormstrike")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	PC:UpdateProcs()
	check(not ss:IsShown() and not ss.glow:IsShown(), "dold Stormstrike: glöden av")
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)

test("v17: sköldens laddningar via containern, rött vid få laddningar", function()
	MOCK.learn("Lightning Shield")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	MOCK.combat = false
	ns.char.procs.shield = true
	ns.char.procs.shieldLow = 1
	ns.char.procs.flash = true
	PC:ResetShieldBox()
	local calls = {}
	local restore = fakeContainer(calls)
	local box = PC:SetupShieldBox()
	restore()
	check(type(box) == "table", "containern byggd")
	check(calls.slot == "shield" and calls.filter == "HELPFUL", "sköldslot")
	check(calls.opts.candidateFilters.includeSpellIDs[10432], "Lightning Shield-ID i filtret")
	check(calls.opts.candidateFilters.includeSpellIDs[408510], "Water Shield-ID i filtret")
	check(calls.count ~= nil, "spelet skriver talet")
	local cover
	for _, o in ipairs(calls.bars or {}) do
		if o.minApplications == 1 and o.maxApplications == 2 then cover = true end
	end
	check(cover, "täckbilden full över 1 laddning")
	-- Klienten har inte visat något tal än: inget rött (annars blinkar det om laddningar inte räknas)
	check(not box.red:IsShown(), "inget rött innan laddningar setts")
	MOCK.auras.player = { { name = "Lightning Shield", spellId = 10432, applications = 3, auraInstanceID = 55 } }
	PC:UpdateShield()
	check(box.red:IsShown() and box.redPulse.on == true, "laddningar räknas: rött blinkar under täckbilden")
	local f = _G.FarseerProcshield
	check(f:IsShown() and f.count:GetText() == "", "vår ikon syns, spelet skriver talet")
	check(not f.glow:IsShown(), "3 laddningar: ingen ram")
	MOCK.auras.player = { { name = "Lightning Shield", spellId = 10432, applications = 1, auraInstanceID = 55 } }
	PC:UpdateShield()
	check(f.glow:IsShown(), "1 laddning (läsbart): ramen blinkar också")
	check(PC:ShieldBoxState() == "active", "debug: active (" .. PC:ShieldBoxState() .. ")")
	-- Flash av: fast rött
	ns.char.procs.flash = false
	PC:StyleShieldBox()
	PC:UpdateShield()
	check(box.red:IsShown() and box.redPulse.on == false, "flash av: fast rött")
	check(not f.glow:IsShown(), "flash av: ingen blinkande ram")
	ns.char.procs.flash = true
	-- Ny gräns: täckbilden får nya värden
	calls.bars = {}
	ns.char.procs.shieldLow = 2
	PC:StyleShieldBox()
	local two
	for _, o in ipairs(calls.bars) do
		if o.minApplications == 2 and o.maxApplications == 3 then two = true end
	end
	check(two, "gräns 2: täckbilden full över 2")
	ns.char.procs.shieldLow = 1
	MOCK.auras.player = {}
	PC:ResetShieldBox()
	MOCK.unlearn("Lightning Shield")
	ns.Spellbook:Scan()
	MOCK.runTimers()
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)

test("Maelstrom: siffer-brickan visar antalet, spelets tal som reserv", function()
	learnMW()
	MOCK.combat = false
	PC:ResetMaelstromBox()
	local calls = {}
	local restore = fakeContainer(calls)
	local box = PC:SetupMaelstromBox()
	restore()
	check(box.digits and #box.digits == 5, "en bar per siffra 1-5")
	for k = 1, 5 do
		local found
		for _, o in ipairs(calls.bars) do
			if o.minApplications == k - 1 and o.maxApplications == k and o.interpolation ~= nil then found = true end
		end
		check(found, "siffran " .. k .. " fylls vid >= " .. k)
	end
	check(box.badge:IsShown() and not box.fs:IsShown(), "brickan syns, spelets tal dolt")
	-- Spelet fyller brickan: den får vara kvar
	MOCK.auras.player = { { name = "Maelstrom Weapon", spellId = 408505, applications = 3, auraInstanceID = 92 } }
	box.digits[1].GetValue = function() return 1 end
	PC:UpdateMaelstrom(); PC:UpdateMaelstrom()
	check(box.digits ~= nil and box.countMode == "digit badge", "brickan kvar när spelet fyller den")
	-- Spelet fyller den inte (ettan tom fast vi har 3 stackar två gånger): spelets tal tar över
	box.digits[1].GetValue = function() return 0 end
	PC:UpdateMaelstrom()
	check(box.digits ~= nil, "en tom läsning räcker inte")
	PC:UpdateMaelstrom()
	check(box.digits == nil and box.fs:IsShown(), "spelets tal tar över")
	check(PC:MaelstromBoxState():find("badge stayed empty"), "debug säger varför: " .. PC:MaelstromBoxState())
	-- Klienten tar inte emot barer: spelets tal direkt
	PC:ResetMaelstromBox()
	calls = {}
	restore = fakeContainer(calls, { noBars = true })
	box = PC:SetupMaelstromBox()
	restore()
	check(box.digits == nil and calls.count ~= nil, "utan barer: spelets tal")
	check(PC:MaelstromBoxState() == "active, number: game text", PC:MaelstromBoxState())
	MOCK.auras.player = {}
	PC:ResetMaelstromBox()
	MOCK.unlearn("Maelstrom Weapon")
	check(#MOCK.errors == 0, "inga fel: " .. tostring(MOCK.errors[1]))
end)

test("formatter som ger tom text godtas inte", function()
	local function fm(fn) return { FormatNumber = function(_, n) return fn(n) end } end
	check(PC.formatterWorks(fm(function(n) return n == 0 and "" or tostring(n) end), 5), "riktig formatter")
	check(not PC.formatterWorks(fm(function() return "" end), 5), "tom text för allt")
	check(not PC.formatterWorks(fm(function(n) return n == 0 and "" or "%d" end), 5), "formatet tolkas inte")
	check(PC.formatterWorks(fm(function(n) return n == 0 and "" or ("|cffffd100" .. n .. "|r") end), 5), "färgkod runt talet")
end)
