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
	local w = button:GetWidth()
	glow:SetSize(w * 1.85, w * 1.85)
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
		if not self:IsShown() then self:Show(); self.anim:Play() end
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
local lastSound = {}
local SOUND_GAP = 8

function AL:Build()
	local cfg = ns.db.alert
	frame = CreateFrame("Frame", "FarseerAlert", UIParent)
	frame:SetSize(360, 64)
	ns.placeFrame(frame, cfg)
	frame:SetFrameStrata("HIGH")
	frame.icon = frame:CreateTexture(nil, "ARTWORK")
	frame.icon:SetSize(52, 52)
	frame.icon:SetPoint("LEFT", 4, 0)
	frame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	frame.ring = frame:CreateTexture(nil, "OVERLAY")
	frame.ring:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
	frame.ring:SetBlendMode("ADD")
	frame.ring:SetSize(96, 96)
	frame.ring:SetPoint("CENTER", frame.icon, "CENTER")
	frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
	frame.title:SetPoint("TOPLEFT", frame.icon, "TOPRIGHT", 10, -2)
	frame.title:SetJustifyH("LEFT")
	frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
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
	ns.makeMovable(frame, cfg, "Farseer: varningar")
	frame:Hide()
end

-- Kortvarig varning (t.ex. "totemet dog") som rådgivaren inte skriver över under `seconds` sekunder
local flashUntil = 0
local function flashing() return GetTime() < flashUntil end

-- key: regelns id, så samma varning inte poppar/låter om och om igen
function AL:Show(key, spell, title, text, color, force)
	if not frame then return end
	if flashing() and not force then return end
	local fresh = current ~= key
	current = key
	frame.icon:SetTexture(ns.spellIcon(spell))
	local c = color or { 1, 0.82, 0 }
	frame.title:SetText(title or "")
	frame.title:SetTextColor(c[1], c[2], c[3])
	frame.ring:SetVertexColor(c[1], c[2], c[3])
	frame.text:SetText(text or "")
	frame.text:SetShown(ns.char.advisor.showText)
	frame:Show()
	if fresh then
		frame.pop:Play()
		local now = GetTime()
		if ns.char.advisor.sound and (not lastSound[key] or now - lastSound[key] > SOUND_GAP) then
			lastSound[key] = now
			local kit = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959
			pcall(PlaySound, kit, "Master")
		end
	end
end

function AL:Flash(key, spell, title, text, color, seconds)
	flashUntil = 0
	self:Show(key, spell, title, text, color, true)
	flashUntil = GetTime() + (seconds or 3)
	C_Timer.After(seconds or 3, function()
		if current == key then
			flashUntil = 0
			AL:Hide()
		end
	end)
end

function AL:Hide(force)
	if flashing() and not force then return end
	current = nil
	if frame and ns.char.locked then frame:Hide() end
end

function AL:Current() return current end

function AL:Test()
	self:Flash("test", "Tremor Totem", "TREMOR TOTEM!", "Test: så här ser en varning ut. Dra i den när addonet är upplåst.",
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
				frame.title:SetText("Varningar")
				frame.text:SetText("Dra för att flytta")
			end
		elseif not current then
			frame:Hide()
		end
	end)
end
