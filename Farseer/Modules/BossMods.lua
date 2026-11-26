-- DBM/BigWigs: lyser upp Tremor/Cleansing strax innan en boss fearar eller förgiftar, och påminner om
-- totems/imbue/sköld när en pull-timer startar. Båda addonen kan laddas efter Farseer, så kopplingen
-- görs vid PLAYER_LOGIN och vid deras ADDON_LOADED. Allt deras anrop går genom pcall.

local _, ns = ...
local BM = ns.module("BossMods")

-- Nyckelord (hela ord, små bokstäver) i barens text eller spellnamn -> kontratotem. Flera ord ("mind
-- control") matchas som en fras. Hela ord: "chains" träffar Chains of Kel'Thuzad men inte Chain Lightning.
BM.COUNTERS = {
	{ totem = "Tremor Totem", label = "TREMOR", color = { 1, 0.6, 0.1 },
		-- Tremor tar bort fear, charm och sleep, inte horror (Death Coil): därför inga "horror"/"death coil"
		words = { "fear", "roar", "scream", "psychic scream", "terrify", "terrifying", "howl", "panic",
			"intimidating", "charm", "dominate", "mind control", "shadow command", "chains", "insanity",
			"seduce", "seduction", "sleep" } },
	{ totem = "Poison Cleansing Totem", label = "POISON CLEANSING", color = { 0.3, 0.9, 0.3 },
		words = { "poison", "venom", "sting" } },
	{ totem = "Disease Cleansing Totem", label = "DISEASE CLEANSING", color = { 0.75, 0.6, 0.3 },
		words = { "disease", "plague", "blight" } },
}

-- Spell-ID (Classic) -> totem. Matchas före texten. Bara ID:n vi är säkra på; osäkra är kommenterade.
BM.SPELLS = {
	[19408] = "Tremor Totem",   -- Magmadar: Panic
	[20604] = "Tremor Totem",   -- Lucifron: Dominate Mind
	[18431] = "Tremor Totem",   -- Onyxia: Bellowing Roar
	[22686] = "Tremor Totem",   -- Nefarian: Bellowing Roar
	[22667] = "Tremor Totem",   -- Lord Victor Nefarius: Shadow Command (mind control)
	[28410] = "Tremor Totem",   -- Kel'Thuzad: Chains of Kel'Thuzad (charm)
	[24327] = "Tremor Totem",   -- Hakkar: Cause Insanity (charm)
	-- Princess Huhuran: Wyvern Sting är ett gift som söver. Osäkert vilket totem som hjälper bäst (Poison
	-- Cleansing tar bort giftet men det smäller när det försvinner); samma som "sting"-ordet tills vidare.
	[26180] = "Poison Cleansing Totem",
}

local bars = {}          -- [bar-id] = { token, totem, delay, ends } (schemalagd varning)
local meta = {}          -- [bar-id] = { rule, label, paused, remaining } (matchad bar tills den stoppas)
local token = 0
local hooked = { dbm = false, bw = false }
local lastPull = -100
local PULL_GAP = 3       -- DBM och BigWigs samtidigt = samma pull
local owner = {}         -- BigWigs vill ha en ägare för RegisterMessage

local function cfg() return ns.char and ns.char.procs end

local function inCombat()
	return InCombatLockdown() and true or ns.get(UnitAffectingCombat, "player") == true
end

---------------------------------------------------------------------------------------------------
-- Matchning
---------------------------------------------------------------------------------------------------
-- Färgkoder (|cAARRGGBB ... |r) och texturer (|T...|t) bort, små bokstäver
local function normalize(s)
	s = s:gsub("|T.-|t", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	return (s:lower())
end
BM.normalize = normalize

-- Hela ord: %f[%a]ord%f[%A]
local patterns = {}
local function pattern(w)
	local p = patterns[w]
	if not p then
		p = "%f[%a]" .. w:gsub("%p", "%%%0") .. "%f[%A]"
		patterns[w] = p
	end
	return p
end

-- Kontraregeln för en text (eller nil)
function BM:Match(...)
	for i = 1, select("#", ...) do
		local s = ns.clean((select(i, ...)))
		if type(s) == "string" and s ~= "" then
			s = normalize(s)
			for _, rule in ipairs(self.COUNTERS) do
				for _, w in ipairs(rule.words) do
					if s:find(pattern(w)) then return rule end
				end
			end
		end
	end
	return nil
end

-- Kontraregeln för ett spell-ID (eller nil)
function BM:MatchSpell(id)
	id = ns.clean(id)
	local totem = type(id) == "number" and self.SPELLS[id]
	if not totem then return nil end
	for _, rule in ipairs(self.COUNTERS) do
		if rule.totem == totem then return rule end
	end
	return nil
end

-- DBM:s timertyper: bara kommande casts (cd/next/cast och deras count/source/special/np-varianter).
-- "target", "active", "fades" (något som pågår), "ai", "stage", "break" m.fl. ignoreras. nil = okänd typ.
local UPCOMING = { cd = true, next = true, cast = true }
local SUFFIXES = { "count", "source", "special", "np" }
function BM.Upcoming(timerType)
	local t = ns.clean(timerType)
	if type(t) ~= "string" then return true end
	t = t:lower()
	if UPCOMING[t] then return true end
	for _, suf in ipairs(SUFFIXES) do
		if #t > #suf and t:sub(-#suf) == suf then return UPCOMING[t:sub(1, -#suf - 1)] == true end
	end
	return false
end

local function spellName(id)
	id = ns.clean(id)
	if type(id) ~= "number" or not (C_Spell and C_Spell.GetSpellName) then return nil end
	return ns.get(C_Spell.GetSpellName, id)
end

---------------------------------------------------------------------------------------------------
-- Barer
---------------------------------------------------------------------------------------------------
-- Schemalägg varningen `bossLead` sekunder innan baren (som har `seconds` kvar) tar slut
function BM:Schedule(id, seconds)
	local m = meta[id]
	if not m then return end
	local c = cfg()
	token = token + 1
	local tok = token
	local lead = tonumber(c and c.bossLead) or 4
	local delay = math.max(0, seconds - lead)
	bars[id] = { token = tok, totem = m.rule.totem, delay = delay, ends = GetTime() + seconds }
	C_Timer.After(delay, function()
		local b = bars[id]
		if not b or b.token ~= tok then return end   -- baren stoppades, pausades eller startades om
		bars[id] = nil
		if not inCombat() then return end            -- wipe/kill: inga gamla varningar
		BM:Fire(m.rule, m.label, math.min(lead, seconds))
	end)
end

-- En bar startade
function BM:StartBar(id, text, seconds, spellID)
	id, text, seconds = ns.clean(id), ns.clean(text), ns.clean(seconds)
	if id == nil then return end
	bars[id], meta[id] = nil, nil   -- omstart: den gamla schemaläggningen gäller inte längre
	local c = cfg()
	if not (c and c.bossmods) or type(seconds) ~= "number" then return end
	local rule = self:MatchSpell(spellID) or self:Match(text, spellName(spellID))
	if not rule or not ns.Spellbook:Knows(rule.totem) then return end
	meta[id] = { rule = rule, label = type(text) == "string" and text or rule.totem }
	self:Schedule(id, seconds)
end

function BM:Fire(rule, text, left)
	local c = cfg()
	if not (c and c.bossmods) or not ns.Spellbook:Knows(rule.totem) then return end
	if ns.Totems and ns.Totems.Active and ns.Totems:Active(rule.totem) then return end   -- redan nere
	ns.Alert:Flash("boss-" .. rule.totem, rule.totem, string.format("%s IN %ds", rule.label, math.floor(left + 0.5)),
		tostring(text) .. " — drop " .. rule.totem .. ".", rule.color, 3, "critical")
end

function BM:StopBar(id)
	id = ns.clean(id)
	if id ~= nil then bars[id], meta[id] = nil, nil end
end

-- Pausad bar (DBM_TimerPause): ingen varning, men kom ihåg tiden kvar till resume
function BM:PauseBar(id)
	id = ns.clean(id)
	local m = id ~= nil and meta[id]
	if not m then return end
	local b = bars[id]
	m.paused = true
	m.remaining = b and math.max(0, b.ends - GetTime()) or nil
	bars[id] = nil
end

function BM:ResumeBar(id)
	id = ns.clean(id)
	local m = id ~= nil and meta[id]
	if not (m and m.paused) then return end
	m.paused = false
	local r = m.remaining
	m.remaining = nil
	if type(r) == "number" and r > 0 then self:Schedule(id, r) end
end

-- Ny tid på en bar (DBM_TimerUpdate): kvar = total - förfluten
function BM:UpdateBar(id, elapsed, total)
	id, elapsed, total = ns.clean(id), ns.clean(elapsed), ns.clean(total)
	local m = id ~= nil and meta[id]
	if not m or type(elapsed) ~= "number" or type(total) ~= "number" then return end
	local left = total - elapsed
	if m.paused then m.remaining = left return end
	if left <= 0 then bars[id] = nil return end
	self:Schedule(id, left)
end

-- Alla barer vars id börjar med prefix (BigWigs_StopBars: alla barer för en modul)
function BM:StopPrefix(prefix)
	for id in pairs(meta) do
		if type(id) == "string" and id:sub(1, #prefix) == prefix then meta[id] = nil end
	end
	for id in pairs(bars) do
		if type(id) == "string" and id:sub(1, #prefix) == prefix then bars[id] = nil end
	end
end

-- Wipe/kill (ENCOUNTER_END, ur strid): alla väntande varningar bort
function BM:ClearAll()
	wipe(bars)
	wipe(meta)
end

function BM:Pending(id) return bars[id] end

---------------------------------------------------------------------------------------------------
-- Pull: vad saknas?
---------------------------------------------------------------------------------------------------
-- Lista med det som saknas: { { spell, text } }. Okänt (secret) räknas inte som saknat.
function BM:Missing()
	local out = {}
	local RE, rc = ns.Reminders, ns.char.reminders or {}
	local shield = RE and RE.ShieldSpell and RE:ShieldSpell()
	if shield and rc.shield ~= false and RE:ShieldUp() == false then
		table.insert(out, { spell = shield, text = "no shield" })
	end
	local imbue = RE and RE.ImbueSpell and RE:ImbueSpell()
	if imbue and rc.imbue ~= false and RE:Imbue() == false then
		table.insert(out, { spell = imbue, text = "no weapon imbue" })
	end
	-- Off-hand: bara med ett vapen i off-hand (true; nil = okänt) och en imbue som säkert saknas (false)
	local off = RE and RE.OffhandSpell and RE:OffhandSpell()
	if off and rc.offhand ~= false and RE.OffhandWeapon and RE:OffhandWeapon() == true
		and RE.OffhandImbue and RE:OffhandImbue() == false then
		table.insert(out, { spell = off, text = "no off-hand imbue" })
	end
	if ns.Totems and ns.Totems.Count and ns.Totems:Count() == 0 then
		table.insert(out, { spell = "Call of the Elements", text = "no totems" })
	end
	return out
end

function BM:Pull(seconds)
	local c = cfg()
	if not (c and c.pullCheck) then return end
	local now = GetTime()
	if now - lastPull < PULL_GAP then return end   -- en varning per pull
	lastPull = now
	local missing = self:Missing()
	if #missing == 0 then return end
	local parts = {}
	for _, m in ipairs(missing) do table.insert(parts, m.text) end
	seconds = ns.clean(seconds)
	local title = type(seconds) == "number" and string.format("PULL IN %ds", math.floor(seconds + 0.5)) or "PULL TIMER"
	local spell = missing[1].spell
	if spell == "Call of the Elements" and not ns.Spellbook:Knows(spell) then spell = "Stoneskin Totem" end
	ns.Alert:Flash("pull", spell, title, "Missing: " .. table.concat(parts, ", ") .. ".", { 1, 0.82, 0 }, 4, "advice")
end

---------------------------------------------------------------------------------------------------
-- Kopplingen
---------------------------------------------------------------------------------------------------
local function guard(fn)
	return function(...)
		local ok, err = pcall(fn, ...)
		if not ok then ns.report(err) end
	end
end

local function isPull(id, msg, timerType)
	if ns.clean(timerType) == "pull" or ns.clean(id) == "pull" then return true end
	msg = ns.clean(msg)
	-- DBM:s pull-bar heter "Pull in" (börjar med Pull; "Magnetic Pull" är en bossförmåga)
	return type(msg) == "string" and msg:lower():find("^pull") ~= nil
end

local function dbmID(id)
	id = ns.clean(id)
	if id == nil then return nil end
	return "dbm:" .. tostring(id)
end

-- DBM-callbacks (egen tabell så testerna kan anropa dem direkt). Pause/Resume/Update finns inte i alla
-- DBM-versioner: då kommer de helt enkelt aldrig.
BM.DBM_HANDLERS = {
	DBM_TimerStart = function(_, id, msg, timer, _, timerType, spellId)
		if isPull(id, msg, timerType) then BM:Pull(timer) return end
		if not BM.Upcoming(timerType) then return end
		BM:StartBar(dbmID(id), msg, timer, spellId)
	end,
	DBM_TimerStop = function(_, id) BM:StopBar(dbmID(id)) end,
	DBM_TimerPause = function(_, id) BM:PauseBar(dbmID(id)) end,
	DBM_TimerResume = function(_, id) BM:ResumeBar(dbmID(id)) end,
	DBM_TimerUpdate = function(_, id, elapsed, total) BM:UpdateBar(dbmID(id), elapsed, total) end,
}
local DBM_ORDER = { "DBM_TimerStart", "DBM_TimerStop", "DBM_TimerPause", "DBM_TimerResume", "DBM_TimerUpdate" }

function BM:HookDBM()
	if hooked.dbm then return true end
	local D = rawget(_G, "DBM")
	if type(D) ~= "table" or type(D.RegisterCallback) ~= "function" then return false end
	local ok = {}
	for _, ev in ipairs(DBM_ORDER) do
		ok[ev] = pcall(D.RegisterCallback, D, ev, guard(BM.DBM_HANDLERS[ev]))
	end
	hooked.dbm = ok.DBM_TimerStart or ok.DBM_TimerStop
	return hooked.dbm
end

function BM:HookBigWigs()
	if hooked.bw then return true end
	local L = rawget(_G, "BigWigsLoader")
	if type(L) ~= "table" or type(L.RegisterMessage) ~= "function" then return false end
	local function barID(module, text) return "bw:" .. tostring(module) .. ":" .. tostring(ns.clean(text)) end
	local ok1 = pcall(L.RegisterMessage, owner, "BigWigs_StartBar", guard(function(_, module, key, text, time)
		BM:StartBar(barID(module, text), text, time, key)
	end))
	local ok2 = pcall(L.RegisterMessage, owner, "BigWigs_StopBar", guard(function(_, module, text)
		BM:StopBar(barID(module, text))
	end))
	pcall(L.RegisterMessage, owner, "BigWigs_StopBars", guard(function(_, module)
		BM:StopPrefix("bw:" .. tostring(module) .. ":")
	end))
	pcall(L.RegisterMessage, owner, "BigWigs_StartPull", guard(function(_, _, seconds)
		BM:Pull(seconds)
	end))
	hooked.bw = ok1 or ok2
	return hooked.bw
end

function BM:Hooked() return hooked.dbm, hooked.bw end

function BM:TryHook()
	if not ns.isShaman then return end
	self:HookDBM()
	self:HookBigWigs()
end

local ADDONS = { ["DBM-Core"] = true, ["BigWigs"] = true, ["BigWigs_Core"] = true, ["BigWigs_Plugins"] = true }
ns.on("ADDON_LOADED", function(_, name)
	if ADDONS[ns.clean(name)] then BM:TryHook() end
end)

-- Wipe/kill: DBM stoppar oftast sina timers (DBM_TimerStop) och BigWigs skickar BigWigs_StopBars, men
-- för säkerhets skull rensas allt vid ENCOUNTER_END och när du lämnar strid, och den schemalagda
-- varningen visas bara i strid.
-- Under en encounter rensas inget när du lämnar strid: död + Reincarnation/soulstone ska inte tappa
-- väntande varningar (de visas ändå bara i strid)
local encounter = false
function BM:InEncounter() return encounter end
function BM:OnShamanLogin()
	self:TryHook()
	ns.on("ENCOUNTER_START", function() encounter = true end)
	ns.on("ENCOUNTER_END", function() encounter = false; BM:ClearAll() end)
	ns.on("PLAYER_REGEN_ENABLED", function() if not encounter then BM:ClearAll() end end)
	ns.on("PLAYER_ENTERING_WORLD", function() encounter = false end)
end
