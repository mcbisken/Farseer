-- Larm: procs (Maelstrom, Windfury, sköld), låg mana, purge, fiendens casts, DR, Blizzards förslag och
-- totemräckvidd.

local _, ns = ...
local UI = ns.UI

local widgets = {}
local function track(w) table.insert(widgets, w); return w end
local function changed() ns.fire("PROCS_CHANGED") end

-- En kolumn: rader läggs under varandra (y räknas uppifrån), checkboxar, stegare, rubriker och text
local function column(p, x, header, rows)
	local h = UI.Header(p, header)
	h:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	local y = -28
	for _, r in ipairs(rows) do
		local w
		if r.stepper then
			w = track(UI.Stepper(p, r[1], r.min, r.max, r.step, r[2], r[3], r.fmt))
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x + 28, y)
			y = y - 26
		elseif r.label then
			w = UI.Label(p, r[1], "GameFontHighlightSmall")
			w:SetWidth(400)
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x + 4, y - 2)
			y = y - 46
		elseif r.header then
			w = UI.Label(p, r[1], "GameFontNormal")
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x, y - 8)
			y = y - 26
		else
			w = track(UI.Check(p, r[1], r[2], r[3], r[4]))
			w:SetPoint("TOPLEFT", p, "TOPLEFT", x, y)
			y = y - 24
		end
	end
end

local function build(p)
	local c = ns.char.procs
	local bar = ns.char.bars.procs
	local ta = ns.char.totemAlerts
	column(p, 4, "Procs och larm", {
		{ "Visa procs-rutan", function() return bar.show end, function(v) bar.show = v; changed() end,
			"Rutan ovanför HUD:en. Flytta den genom att låsa upp (minimap-ikonen, högerklick)." },
		{ "Maelstrom Weapon-stackar", function() return c.maelstrom end, function(v) c.maelstrom = v; changed() end,
			"Ikon med antal stackar. Lyser vid 5. Visas bara om du har talangen." },
		{ "Ljud vid 5 stackar", function() return c.maelstromSound end, function(v) c.maelstromSound = v end,
			"Bara när antalet går att läsa (spelet kan dölja det i strid; då lyser ikonen ändå)." },
		{ "Windfury-proc (\"WINDFURY!\")", function() return c.windfury end, function(v) c.windfury = v end,
			"Visas när Windfury Weapon eller Windfury Totem slår. Läses från spelets cooldown-händelse." },
		{ "Ljud vid Windfury", function() return c.windfurySound end, function(v) c.windfurySound = v end },
		{ "Laddningar på skölden", function() return c.shield end, function(v) c.shield = v; changed() end,
			"Lightning/Water Shield: siffran visas på sköldikonen och på påminnelseknappen." },
		{ "Laddningar kvar för varning", stepper = true, min = 1, max = 2, step = 1,
			function() return c.shieldLow or 1 end, function(v) c.shieldLow = v end },
		{ "Låg mana: förslag", function() return c.mana end, function(v) c.mana = v end,
			"I strid: varning med förslag i ordningen Mana Tide Totem, Water Shield, Mana Spring Totem." },
		{ "Gräns (% mana)", stepper = true, min = 5, max = 60, step = 5,
			function() return c.manaPct or 25 end, function(v) c.manaPct = v end },
		{ "Purge: target har magiska buffar", function() return c.purge end, function(v) c.purge = v; changed() end,
			"Ikon med buffen som Purge tar bort. Fungerar när spelet visar fiendens buffar (oftast utanför strid)." },
		{ "...varna i PvP-läge", function() return c.purgeAlertPvp end, function(v) c.purgeAlertPvp = v end },
		{ "Fiendens casts (castbar + \"Earth Shock!\")", function() return c.enemyCasts end, function(v) c.enemyCasts = v end,
			"Target och focus. Namnet och tiden visas när spelet ger dem; annars bara att fienden castar." },
		{ "...stor KICK-varning i PvP-läge", function() return c.enemyCastAlertPvp end, function(v) c.enemyCastAlertPvp = v end },
		{ "Diminishing returns på target", function() return c.dr end, function(v) c.dr = v end,
			"50 % / 25 % / immun per CC-kategori, från spelets DR-händelse (om klienten skickar den)." },
		{ "Blizzards förslag på nästa spell", function() return c.assisted end, function(v) c.assisted = v; changed() end,
			"Assisted Combat: visas bara om Forever-klienten har funktionen." },
		{ "Ikonstorlek", stepper = true, min = 20, max = 64, step = 2,
			function() return bar.size or 36 end, function(v) bar.size = v; changed() end },
	})
	column(p, 470, "Totemräckvidd", {
		{ "Markera totems som inte når dig", function() return ta.range end, function(v) ta.range = v end,
			"Buff-totems (Strength of Earth, Mana Spring, Grace of Air ...): röd ruta och UTOM på totembaren när buffen "
				.. "inte finns på dig. Bara när spelet visar dina buffar (oftast utanför strid)." },
		{ "...och varna en gång per totem", function() return ta.rangeAlert end, function(v) ta.rangeAlert = v end },
		{ "Totemic Call-knapp på totembaren", function() return ta.callButton end,
			function(v) ta.callButton = v; ns.Totems:ApplyCallButton() end,
			"Klick: Totemic Call (flyttar dina totems till dig). Högerklick: Totemic Recall. Lyser när något är utom räckhåll." },
		{ "Så funkar det", header = true },
		{ "Ett totem markeras först när dess buff setts på dig en gång, så ett okänt buff-ID i Forever ger inga "
			.. "falsklarm. Windfury Totem och Flametongue Totem ger vapenförtrollningar och kan inte kollas.", label = true },
	})
end

local function refresh(p)
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
end

UI.AddTab("alerts", "Larm", build, refresh)
