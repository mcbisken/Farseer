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
			function b:SetApplicationBar(bar, o2) table.insert(calls.bars, o2) end
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
	check(calls.count ~= nil, "spelet skriver talet")
	check(calls.cd ~= nil, "tid kvar som svep")
	local full, stack
	for _, o in ipairs(calls.bars or {}) do
		if o.minApplications == 5 and o.maxApplications == 5 then full = true end
		if o.minApplications == 0 and o.maxApplications == 5 then stack = true end
	end
	check(full, "markering som bara fylls vid 5")
	check(stack, "stackbar 0-5")
	check(PC:MaelstromBox() ~= nil, "aktiv")
	check(PC:MaelstromBoxState() == "active", "debug: active")
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
