-- Varningsrutan ("TREMOR TOTEM!") och en enkel pulserande glöd som kan sättas på vilken knapp som helst.

local _, ns = ...
local AL = ns.module("Alert")

---------------------------------------------------------------------------------------------------
-- Glöd (vanliga texturer: får visas/döljas även i strid på säkra knappar)
---------------------------------------------------------------------------------------------------
function ns.addGlow(button, r, g, b)
	local glow = button:CreateTexture(nil, "OVERLAY")
	glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	glow:SetBlendMode("ADD")
	glow:SetVertexColor(r or 1, g or 0.85, b or 0.2, 1)
	-- Storleken följer knappen (knappar får ofta sin storlek först senare, eller byter storlek i inställningarna)
	local function fit(w)
		w = tonumber(w) or 0
		glow:SetSize(w * 1.85, w * 1.85)
	end
	fit(button:GetWidth())
	if button.HookScript then button:HookScript("OnSizeChanged", function(_, w) fit(w) end) end
	glow:SetPoint("CENTER")
	glow:Hide()
	local ag = glow:CreateAnimationGroup()
	ag:SetLooping("BOUNCE")
	local a = ag:CreateAnimation("Alpha")
	a:SetFromAlpha(1)
	a:SetToAlpha(0.25)
	a:SetDuration(0.45)
	glow.anim = ag
	function glow:On()
		if not self:IsShown() then self:Show() end
		if not self.anim:IsPlaying() then self.anim:Play() end
	end
	function glow:Off()
		if self:IsShown() then self.anim:Stop(); self:Hide() end
	end
	return glow
end

---------------------------------------------------------------------------------------------------
-- Varningsrutan
---------------------------------------------------------------------------------------------------
local frame
local current
local currentPrio = 0
local lastSound = {}
local lastSpeak = {}   -- uppläsning: samma varning högst var SOUND_GAP:e sekund (två som byter av varandra köas annars)
local SOUND_GAP = 8

-- Prioritet: en varning ersätter bara en som är lika viktig eller mindre viktig.
--   info     = upplysning (totem dog/gick ut/utom räckhåll, purge, pull-check)
--   advice   = rådgivarens totemförslag, låg mana
--   critical = det som måste göras nu (fear på dig, bossens fear om några sekunder, kick i PvP, andning)
AL.PRIO = { info = 1, advice = 2, critical = 3 }
local function prioOf(p)
	if type(p) == "number" then return p end
	return AL.PRIO[p or ""] or nil
end

-- Var varningar visas: "always", "group" (grupp eller instans), "instance" (bara instanser/BG) eller "off"
function AL:InGroupOrInstance()
	local inst = ns.get(IsInInstance)
	if inst == true then return true end
	local n = ns.get(GetNumGroupMembers) or 0
	return type(n) == "number" and n > 0
end
function AL:Allowed()
	local mode = ns.db.alert.mode or "always"
	if mode == "off" then return false end
	if mode == "instance" then return ns.get(IsInInstance) == true end
	if mode == "group" then return self:InGroupOrInstance() end
	return true
end

function AL:Build()
	local cfg = ns.db.alert
	frame = CreateFrame("Frame", "FarseerAlert", UIParent)
	frame:SetSize(360, 64)
	ns.placeFrame(frame, cfg)
	frame:SetFrameStrata("HIGH")
	local T = ns.Theme
	-- Bricka bakom texten (tonar ut åt höger) och en färgad kant
	frame.plate = frame:CreateTexture(nil, "BACKGROUND")
	frame.plate:SetPoint("TOPLEFT", -6, 6)
	frame.plate:SetPoint("BOTTOMRIGHT", 40, -6)
	frame.plate:SetColorTexture(1, 1, 1, 1)
	if not T.Gradient(frame.plate, "HORIZONTAL", { 0.02, 0.025, 0.04, 0.85 }, { 0.02, 0.025, 0.04, 0 }) then
		frame.plate:SetColorTexture(0.02, 0.025, 0.04, 0.6)
	end
	frame.stripe = frame:CreateTexture(nil, "BORDER")
	frame.stripe:SetPoint("TOPLEFT", frame.plate, "TOPLEFT", 0, 0)
	frame.stripe:SetPoint("BOTTOMLEFT", frame.plate, "BOTTOMLEFT", 0, 0)
	frame.stripe:SetWidth(3)
	frame.stripe:SetColorTexture(1, 0.82, 0, 1)
	frame.iconFrame = CreateFrame("Frame", nil, frame)
	frame.iconFrame:SetSize(52, 52)
	frame.iconFrame:SetPoint("LEFT", 6, 0)
	frame.icon = frame.iconFrame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetPoint("TOPLEFT", 1, -1)
	frame.icon:SetPoint("BOTTOMRIGHT", -1, 1)
	T.Border(frame.iconFrame, { 0, 0, 0, 1 }, "OVERLAY", 0)
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.ring = frame:CreateTexture(nil, "OVERLAY")
	frame.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	frame.ring:SetBlendMode("ADD")
	frame.ring:SetSize(96, 96)
	frame.ring:SetPoint("CENTER", frame.icon, "CENTER")
	frame.title = frame:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontAlert"))
	frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
	frame.title:SetJustifyH("LEFT")
	frame.text = frame:CreateFontString(nil, "OVERLAY", T.Font("FarseerFontAlertText"))
	frame.text:SetPoint("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -4)
	frame.text:SetJustifyH("LEFT")
	frame.text:SetWidth(290)
	local ok, ag = pcall(function()
		local g = frame:CreateAnimationGroup()
		local s1 = g:CreateAnimation("Scale")
		s1:SetScale(1.12, 1.12)
		s1:SetDuration(0.12)
		s1:SetOrder(1)
		local s2 = g:CreateAnimation("Scale")
		s2:SetScale(1 / 1.12, 1 / 1.12)
		s2:SetDuration(0.18)
		s2:SetOrder(2)
		return g
	end)
	frame.pop = ok and ag or { Play = function() end }
	ns.makeMovable(frame, cfg, "Farseer: warnings")
	frame:Hide()
end

-- Kortvarig varning (t.ex. "totemet dog") som bara en viktigare varning skriver över under `seconds` sekunder
local flashUntil = 0
local flashToken = 0
local function flashing() return GetTime() < flashUntil end

-- key: regelns id, så samma varning inte poppar/låter om och om igen. prio: se AL.PRIO (standard advice).
-- Returnerar true om varningen visades.
-- Läs upp med spelets text-till-tal (som TotemWatch). speak: off / critical / advice
function AL:Speak(text)
	if type(text) ~= "string" or text == "" then return false end
	text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
	if TextToSpeech_Speak then
		local voice = TextToSpeech_GetSelectedVoice and Enum and Enum.TtsVoiceType
			and select(2, pcall(TextToSpeech_GetSelectedVoice, Enum.TtsVoiceType.Standard)) or nil
		if pcall(TextToSpeech_Speak, text, voice) then return true end
	end
	local V = C_VoiceChat
	if V and V.SpeakText and V.GetTtsVoices then
		local ok, voices = pcall(V.GetTtsVoices)
		local id = ok and type(voices) == "table" and voices[1] and voices[1].voiceID or 0
		-- Nyare klienter: (röst, text, hastighet, volym). Äldre: (röst, text, destination, hastighet, volym).
		local newer = not (Enum and Enum.VoiceTtsDestination)
		if newer then
			if pcall(V.SpeakText, id, text, 0, 100) then return true end
		else
			if pcall(V.SpeakText, id, text, Enum.VoiceTtsDestination.LocalPlayback or 1, 0, 100) then return true end
		end
	end
	return false
end

function AL:SpeakFor(prio)
	local mode = ns.db.alert.speak or "off"
	if mode == "critical" then return prio >= AL.PRIO.critical end
	if mode == "advice" then return prio >= AL.PRIO.advice end
	return false
end

function AL:Show(key, spell, title, text, color, force, prio)
	if not frame then return false end
	if not self:Allowed() then return false end
	prio = prioOf(prio) or AL.PRIO.advice
	-- En pågående flash ersätts bara av något viktigare (rådgivarens förslag trycker inte undan en lika viktig flash)
	if flashing() and not force and prio <= currentPrio then return false end
	-- En flash (force) tränger inte undan en kritisk varning som visas nu (t.ex. "TREMOR!" när du är fearad)
	if force and current and current ~= key and currentPrio >= AL.PRIO.critical and prio < currentPrio then
		return false
	end
	-- Rådgivaren tog över från en flash: flashen är slut (annars blockeras Hide/Show tills dess tid gått)
	if not force then flashUntil = 0 end
	local fresh = current ~= key
	current = key
	currentPrio = prio
	frame.icon:SetTexture(ns.spellIcon(spell))
	local c = color or { 1, 0.82, 0 }
	frame.title:SetText(title or "")
	frame.title:SetTextColor(c[1], c[2], c[3])
	frame.ring:SetVertexColor(c[1], c[2], c[3])
	if frame.stripe then frame.stripe:SetColorTexture(c[1], c[2], c[3], 1) end
	frame.text:SetText(text or "")
	-- "Visa förklaring" gäller rådgivarens text; en flash är meningslös utan sin text (t.ex. pull-checkens lista)
	frame.text:SetShown(force or ns.char.advisor.showText)
	frame:Show()
	if fresh then
		frame.pop:Play()
		local now = GetTime()
		local quiet = ns.db.alert.quietInfo ~= false and prio <= AL.PRIO.info
		if ns.char.advisor.sound and not quiet and (not lastSound[key] or now - lastSound[key] > SOUND_GAP) then
			lastSound[key] = now
			local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959
			pcall(PlaySound, kit, "Master")
		end
		if self:SpeakFor(prio) and (not lastSpeak[key] or now - lastSpeak[key] > SOUND_GAP) then
			lastSpeak[key] = now
			self:Speak(title)
		end
	end
	return true
end

-- prio: standard info. Returnerar true om den visades (en viktigare varning kan vara uppe).
function AL:Flash(key, spell, title, text, color, seconds, prio)
	prio = prioOf(prio) or AL.PRIO.info
	if flashing() and prio < currentPrio then return false end
	local wasUntil = flashUntil
	flashUntil = 0
	if not self:Show(key, spell, title, text, color, true, prio) then
		flashUntil = wasUntil
		return false
	end
	flashUntil = GetTime() + (seconds or 3)
	flashToken = flashToken + 1
	local token = flashToken
	-- Token: en ny flash (även med samma key) får hela sin tid, den gamla timern döljer den inte
	C_Timer.After(seconds or 3, function()
		if token == flashToken and current == key then
			flashUntil = 0
			AL:Hide()
		end
	end)
	return true
end

function AL:Hide(force)
	if flashing() and not force then return end
	current = nil
	currentPrio = 0
	if frame and ns.char.locked then frame:Hide() end
end

function AL:Current() return current end

function AL:Test()
	flashUntil = 0
	current, currentPrio = nil, 0
	self:Flash("test", "Tremor Totem", "TREMOR TOTEM!", "Test: this is what a warning looks like. Drag it while the addon is unlocked.",
		{ 1, 0.6, 0.1 }, 4)
end

function AL:OnShamanLogin()
	self:Build()
	ns.listen("BARS_LAYOUT", function() ns.placeFrame(frame, ns.db.alert) end)
	ns.listen("LOCK_CHANGED", function(locked)
		if not locked then
			frame:Show()
			if not current then
				frame.icon:SetTexture(ns.spellIcon("Tremor Totem"))
				frame.title:SetText("Warnings")
				frame.text:SetText("Drag to move")
			end
		elseif not current then
			frame:Hide()
		end
	end)
end
