-- Flikarna "Procs" (procs-rutan och cooldown-timers) och "Alerts" (larm i strid, bossmods, andning och totems).

local _, ns = ...
local UI = ns.UI

local function changed() ns.fire("PROCS_CHANGED") end
local function totemsChanged()
	ns.fire("PROCS_CHANGED")
	ns.fire("TOTEMS_CHANGED")
end

-- En kolumn: rader läggs under varandra (y räknas uppifrån), checkboxar, stegare, rubriker och text
local function column(p, x, header, rows, track)
	local h = UI.Header(p, header)
	h:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local y = -28
	for _, r in ipairs(rows) do
		local w
		if r.dropdown then
			local l = UI.Label(p, r[1], "GameFontNormalSmall")
			l:SetPoint("TOPLEFT", p, "TOPLEFT", x + 4, y - 4)
			local items = r.items
			w = track(UI.Dropdown(p, r.width or 190, function()
				local v = r[2]()
				for _, it in ipairs(items) do if it.value == v then return it.text end end
				return items[1].text
			end, function() return items end, function(v) r[3](v) end))
			w:SetPoint("LEFT", l, "RIGHT", 6, 0)
			if r[4] then
				w:HookScript("OnEnter", function(self)
					GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
					GameTooltip:AddLine(r[1])
					GameTooltip:AddLine(r[4], 1, 1, 1, true)
					GameTooltip:Show()
				end)
				w:HookScript("OnLeave", function() GameTooltip:Hide() end)
			end
			y = y - 30
		elseif r.stepper then
			w = track(UI.Stepper(p, r[1], r.min, r.max, r.step, r[2], r[3], r.fmt))
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x + 28, y)
			y = y - 26
		elseif r.label then
			w = UI.Label(p, r[1], "GameFontHighlightSmall")
			w:SetWidth(400)
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x + 4, y - 2)
			y = y - (r.height or 46)
		elseif r.header then
			w = UI.Label(p, r[1], "GameFontNormal")
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x, y - 8)
			y = y - 28
		else
			w = track(UI.Check(p, r[1], r[2], r[3], r[4]))
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
			y = y - 24
		end
	end
end

-- Varje flik har sin egen lista med widgets som uppdateras när fliken visas
local function tab(id, title, build)
	local widgets = {}
	local function track(w) table.insert(widgets, w); return w end
	UI.AddTab(id, title, function(p) build(p, track) end, function()
		for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
	end)
end

---------------------------------------------------------------------------------------------------
-- Procs
---------------------------------------------------------------------------------------------------
tab("procs", "Procs", function(p, track)
	local c = ns.char.procs
	local bar = ns.char.bars.procs
	column(p, 4, "Procs box", {
		{ "Show procs box", function() return bar.show end, function(v) bar.show = v; changed() end,
			"The box above the HUD. Move it by unlocking (minimap icon, right-click)." },
		{ "Maelstrom Weapon stacks", function() return c.maelstrom end, function(v) c.maelstrom = v; changed() end,
			"Icon with stack count. Lights up at 5. Only shown if you have the talent/rune." },
		{ "Sound at 5 stacks", function() return c.maelstromSound end, function(v) c.maelstromSound = v end,
			"Only when the count can be read (the game may hide it in combat; the icon still lights up)." },
		{ "Elemental Focus (Clearcasting)", function() return c.clearcast end, function(v) c.clearcast = v; changed() end,
			"Icon while Clearcasting is up: your next spells cost less — always spend it." },
		{ "Stormstrike buff", function() return c.stormstrike end, function(v) c.stormstrike = v; changed() end,
			"Icon while Stormstrike's buff is up: the next Lightning Bolt, Chain Lightning or Earth Shock hits harder." },
		{ "Flurry", function() return c.flurry end, function(v) c.flurry = v; changed() end,
			"Icon with charges while Flurry (attack speed after a crit) is up." },
		{ "Windfury proc (\"WINDFURY!\")", function() return c.windfury end, function(v) c.windfury = v end,
			"Shown when Windfury Weapon or Windfury Totem procs. Read from the game's cooldown event." },
		{ "Sound on Windfury", function() return c.windfurySound end, function(v) c.windfurySound = v end },
		{ "Shield charges", function() return c.shield end, function(v) c.shield = v; changed() end,
			"Lightning/Water Shield: the number is shown on the shield icon and the reminder button." },
		{ "Charges left to warn", stepper = true, min = 1, max = 2, step = 1,
			function() return c.shieldLow or 1 end, function(v) c.shieldLow = v end },
		{ "Blizzard's next spell suggestion", function() return c.assisted end, function(v) c.assisted = v; changed() end,
			"Assisted Combat: only shown if the Forever client has the feature." },
		{ "Icon size", stepper = true, min = 20, max = 64, step = 2,
			function() return bar.size or 36 end, function(v) bar.size = v; changed() end },
	}, track)
	column(p, 470, "Cooldowns", {
		{ "Mana Tide / Rage of the Farseer timer", function() return c.cdTimers end, function(v) c.cdTimers = v; changed() end,
			"Countdown in the procs box while Mana Tide Totem or Rage of the Farseer is running." },
		{ "...announce in party/raid chat", function() return c.announce end, function(v) c.announce = v end,
			"Sends one line (\"Mana Tide Totem up (12 s)\") when you use them. Chat may be blocked in some instances." },
	}, track)
end)

---------------------------------------------------------------------------------------------------
-- Alerts
---------------------------------------------------------------------------------------------------
tab("alerts", "Alerts", function(p, track)
	local c = ns.char.procs
	local ta = ns.char.totemAlerts
	local al = ns.db.alert
	local adv = ns.char.advisor
	column(p, 4, "Combat alerts", {
		{ "Show alerts:", dropdown = true, width = 200, items = {
			{ text = "Everywhere", value = "always" },
			{ text = "In groups and instances", value = "group" },
			{ text = "Only in instances", value = "instance" },
			{ text = "Off (glows only)", value = "off" },
		}, function() return al.mode or "always" end, function(v) al.mode = v; if v == "off" then ns.Alert:Hide(true) end end,
			"Where the big warning box may appear. Button glows and bar marks still work when it's off. Account-wide." },
		{ "No sound for info alerts", function() return al.quietInfo ~= false end, function(v) al.quietInfo = v end,
			"Totem died/expiring/out of range, purge and pull reminders show silently. Important warnings (fear, boss "
				.. "fear, kick, low mana) still play the sound." },
		{ "Quiet when solo", function() return adv.soloQuiet end, function(v) adv.soloQuiet = v end,
			"Solo outside instances: no \"DROP TOTEMS!\", no out-of-range or expiry warnings (nice while leveling)." },
		{ "Low mana: suggestion", function() return c.mana end, function(v) c.mana = v end,
			"In combat: warning with suggestions in the order Mana Tide Totem, Water Shield, Mana Spring Totem." },
		{ "Threshold (% mana)", stepper = true, min = 5, max = 60, step = 5,
			function() return c.manaPct or 25 end, function(v) c.manaPct = v end },
		{ "Purge: target has magic buffs", function() return c.purge end, function(v) c.purge = v; changed() end,
			"Icon of the buff Purge removes. Works when the game shows enemy buffs (usually out of combat)." },
		{ "...warn in PvP mode", function() return c.purgeAlertPvp end, function(v) c.purgeAlertPvp = v end },
		{ "Enemy casts (castbar + \"Earth Shock!\")", function() return c.enemyCasts end, function(v) c.enemyCasts = v end,
			"Target and focus. Name and time are shown when the game provides them; otherwise just that the enemy is casting." },
		{ "...big KICK warning in PvP mode", function() return c.enemyCastAlertPvp end, function(v) c.enemyCastAlertPvp = v end },
		{ "Diminishing returns on target", function() return c.dr end, function(v) c.dr = v end,
			"50 % / 25 % / immune per CC category, from the game's DR event (if the client sends it)." },
		{ "Boss mods (DBM / BigWigs)", header = true },
		{ "Counter totem before boss fear/poison", function() return c.bossmods end, function(v) c.bossmods = v end,
			"When DBM or BigWigs shows a timer for a fear, charm, poison or disease ability, Farseer warns a few seconds "
				.. "before it with the right totem (Tremor, Poison/Disease Cleansing)." },
		{ "Seconds before", stepper = true, min = 1, max = 10, step = 1,
			function() return c.bossLead or 4 end, function(v) c.bossLead = v end },
		{ "Pull timer: check shield, imbue, totems", function() return c.pullCheck end, function(v) c.pullCheck = v end,
			"When a pull timer starts: one reminder listing what's missing." },
		{ "Breath running out (Water Breathing)", function() return c.breath end, function(v) c.breath = v end,
			"Under water: warns when your breath starts running out, or Water Breathing has less than a minute left." },
	}, track)
	column(p, 470, "Totems", {
		{ "Warn before totems expire", function() return ta.expire end, function(v) ta.expire = v; totemsChanged() end,
			"One warning per totem a few seconds before it runs out (buff totems last 5 minutes in Forever)." },
		{ "Seconds before", stepper = true, min = 5, max = 60, step = 5,
			function() return ta.expireSec or 20 end, function(v) ta.expireSec = v end },
		{ "...only totems that last a minute or more", function() return ta.expireLongOnly end,
			function(v) ta.expireLongOnly = v end, "Skips short totems like Searing, Magma and Earthbind." },
		{ "Party members missing your totem buffs", function() return ta.party end, function(v) ta.party = v; totemsChanged() end,
			"Out of combat: a line under the totem bar (\"2 missing buffs\", hover for names). Totemic Call lights up "
				.. "when someone in range is missing a buff. The game's range check is ~40 yd, totems reach 20-30 yd." },
		{ "Dim totem buttons you can't afford", function() return ta.manaDim end, function(v) ta.manaDim = v; totemsChanged() end,
			"Situation and counter-totem buttons turn blue when you don't have the mana for the totem." },
		{ "Mark totems that don't reach you", function() return ta.range end, function(v) ta.range = v end,
			"Buff totems (Strength of Earth, Mana Spring, Grace of Air ...): red box and OOR on the totem bar when the buff "
				.. "isn't on you. Only when the game shows your buffs (usually out of combat)." },
		{ "...and warn once per totem", function() return ta.rangeAlert end, function(v) ta.rangeAlert = v end },
		{ "Totemic Call button on totem bar", function() return ta.callButton end,
			function(v) ta.callButton = v; ns.Totems:ApplyCallButton() end,
			"Click: Totemic Call (moves your totems to you). Right-click: Totemic Recall. Lights up when something is "
				.. "out of range or a party member is missing a buff." },
		{ "A totem is only marked once its buff has been seen on you, so an unknown buff ID in Forever gives no "
			.. "false alarms.", label = true, height = 34 },
	}, track)
end)
