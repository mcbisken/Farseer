-- DBM/BigWigs: lyser upp Tremor/Cleansing strax innan en boss fearar eller förgiftar, och påminner om
-- totems/imbue/sköld när en pull-timer startar. Båda addonen kan laddas efter Farseer, så kopplingen
-- görs vid PLAYER_LOGIN och vid deras ADDON_LOADED. Allt deras anrop går genom pcall.

local _, ns = ...
local BM = ns.module("BossMods")

-- Nyckelord i barens text eller spellnamn -> kontratotem (små bokstäver, enkel textsökning)
BM.COUNTERS = {
	{ totem = "Tremor Totem", label = "TREMOR", color = { 1, 0.6, 0.1 },
		words = { "fear", "roar", "scream", "terrify", "horror", "howl", "charm", "mind control", "seduc", "sleep" } },
	{ totem = "Poison Cleansing Totem", label = "POISON CLEANSING", color = { 0.3, 0.9, 0.3 },
		words = { "poison", "venom", "sting" } },
	{ totem = "Disease Cleansing Totem", label = "DISEASE CLEANSING", color = { 0.75, 0.6, 0.3 },
		words = { "disease", "plague", "blight" } },
}

local bars = {}          -- [bar-id] = { token, totem }
local token = 0
local hooked = { dbm = false, bw = false }
local lastPull = -100
local PULL_GAP = 3       -- DBM och BigWigs samtidigt = samma pull
local owner = {}         -- BigWigs vill ha en ägare för RegisterMessage

local function cfg() return ns.char and ns.char.procs end

-- Kontraregeln för en text (eller nil)
function BM:Match(...)
	for i = 1, select("#", ...) do
		local s = ns.clean((select(i, ...)))
		if type(s) == "string" and s ~= "" then
			s = s:lower()
			for _, rule in ipairs(self.COUNTERS) do
				for _, w in ipairs(rule.words) do
					if s:find(w, 1, true) then return rule end
				end
			end
		end
	end
	return nil
end

local function spellName(id)
	id = ns.clean(id)
	if type(id) ~= "number" or not (C_Spell and C_Spell.GetSpellName) then return nil end
	return ns.get(C_Spell.GetSpellName, id)
end

---------------------------------------------------------------------------------------------------
-- Barer
---------------------------------------------------------------------------------------------------
-- En bar startade: schemalägg varningen `bossLead` sekunder innan den tar slut
function BM:StartBar(id, text, seconds, spellID)
	id, text, seconds = ns.clean(id), ns.clean(text), ns.clean(seconds)
	if id == nil then return end
	bars[id] = nil   -- omstart: den gamla schemaläggningen gäller inte längre
	local c = cfg()
	if not (c and c.bossmods) or type(seconds) ~= "number" then return end
	local rule = self:Match(text, spellName(spellID))
	if not rule or not ns.Spellbook:Knows(rule.totem) then return end
	token = token + 1
	local tok = token
	local lead = tonumber(c.bossLead) or 4
	local delay = math.max(0, seconds - lead)
	bars[id] = { token = tok, totem = rule.totem, delay = delay }
	local label = type(text) == "string" and text or rule.totem
	C_Timer.After(delay, function()
		local b = bars[id]
		if not b or b.token ~= tok then return end   -- baren stoppades eller startades om
		bars[id] = nil
		BM:Fire(rule, label, math.min(lead, seconds))
	end)
end

function BM:Fire(rule, text, left)
	local c = cfg()
	if not (c and c.bossmods) or not ns.Spellbook:Knows(rule.totem) then return end
	ns.Alert:Flash("boss-" .. rule.totem, rule.totem, string.format("%s IN %ds", rule.label, math.floor(left + 0.5)),
		tostring(text) .. " — drop " .. rule.totem .. ".", rule.color, 3)
end

function BM:StopBar(id)
	id = ns.clean(id)
	if id ~= nil then bars[id] = nil end
end

-- Alla barer vars id börjar med prefix (BigWigs_StopBars: alla barer för en modul)
function BM:StopPrefix(prefix)
	for id in pairs(bars) do
		if type(id) == "string" and id:sub(1, #prefix) == prefix then bars[id] = nil end
	end
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
	ns.Alert:Flash("pull", spell, title, "Missing: " .. table.concat(parts, ", ") .. ".", { 1, 0.82, 0 }, 4)
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

function BM:HookDBM()
	if hooked.dbm then return true end
	local D = rawget(_G, "DBM")
	if type(D) ~= "table" or type(D.RegisterCallback) ~= "function" then return false end
	local ok1 = pcall(D.RegisterCallback, D, "DBM_TimerStart", guard(function(_, id, msg, timer, _, timerType, spellId)
		if isPull(id, msg, timerType) then BM:Pull(timer) return end
		BM:StartBar("dbm:" .. tostring(id), msg, timer, spellId)
	end))
	local ok2 = pcall(D.RegisterCallback, D, "DBM_TimerStop", guard(function(_, id)
		BM:StopBar("dbm:" .. tostring(id))
	end))
	hooked.dbm = ok1 or ok2
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

-- Wipe/kill: DBM stoppar sina timers (DBM_TimerStop) och BigWigs skickar BigWigs_StopBars, så gamla
-- varningar avbryts den vägen.
function BM:OnShamanLogin()
	self:TryHook()
end
