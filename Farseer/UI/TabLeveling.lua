-- Utveckling: vad som väntar hos trainern, hit-cap, reagens och checklistan före raid/dungeon.

local _, ns = ...
local UI = ns.UI

local widgets = {}
local function track(w) table.insert(widgets, w); return w end
local trainerText, hitText, reagentText, checkText, trainerContent

local function build(p)
	local LV = ns.Leveling
	local c = ns.char.leveling

	-- Vänster: trainern
	local h = UI.Header(p, "Trainern")
	h:SetPoint("TOPLEFT", 4, -4)
	local sf
	sf, trainerContent = UI.Scroll(p, 410, UI.HEIGHT - 40)
	sf:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -8)
	trainerText = UI.Label(trainerContent, "", "GameFontHighlight")
	trainerText:SetPoint("TOPLEFT", 0, 0)
	trainerText:SetWidth(390)
	trainerText:SetJustifyV("TOP")

	-- Höger
	local x = 450
	local hh = UI.Header(p, "Hit")
	hh:SetPoint("TOPLEFT", p, "TOPLEFT", x, -4)
	hitText = UI.Label(p, "", "GameFontHighlight")
	hitText:SetPoint("TOPLEFT", hh, "BOTTOMLEFT", 0, -6)
	hitText:SetWidth(400)
	local s1 = track(UI.Stepper(p, "Spell hit-cap (%)", 1, 20, 1, function() return c.hitSpell end, function(v) c.hitSpell = v end))
	s1:SetPoint("TOPLEFT", hitText, "BOTTOMLEFT", 0, -6)
	local s2 = track(UI.Stepper(p, "Melee hit-cap (%)", 1, 20, 1, function() return c.hitMelee end, function(v) c.hitMelee = v end))
	s2:SetPoint("TOPLEFT", s1, "BOTTOMLEFT", 0, -2)

	local rh = UI.Header(p, "Reagens")
	rh:SetPoint("TOPLEFT", s2, "BOTTOMLEFT", 0, -14)
	reagentText = UI.Label(p, "", "GameFontHighlight")
	reagentText:SetPoint("TOPLEFT", rh, "BOTTOMLEFT", 0, -6)
	reagentText:SetWidth(400)

	local ch = UI.Header(p, "Checklista före raid")
	ch:SetPoint("TOPLEFT", reagentText, "BOTTOMLEFT", 0, -14)
	local show = UI.Button(p, "Visa checklistan", 150, 24, function() LV:ShowChecklist() end,
		"Sköld, imbue, mat, flaska, Ankh, hållbarhet, Call-set, hit-cap och trainern. Även /farseer check.")
	show:SetPoint("TOPLEFT", ch, "BOTTOMLEFT", 0, -6)
	local opts = {
		{ "Visa vid ready check", "readyCheck" },
		{ "Visa när jag går in i en raid", "checklist" },
		{ "Skriv nya trainer-ranker i chatten", "announce" },
		{ "Varna när reagens tar slut", "reagents" },
	}
	local last = show
	for i, o in ipairs(opts) do
		local cb = track(UI.Check(p, o[1], function() return c[o[2]] end, function(v) c[o[2]] = v end))
		cb:SetPoint("TOPLEFT", last, "BOTTOMLEFT", i == 1 and -2 or 0, i == 1 and -6 or 2)
		last = cb
	end
	checkText = UI.Label(p, "", "GameFontHighlightSmall")
	checkText:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 4, -6)
	checkText:SetWidth(400)
end

local function refresh()
	local LV, SB = ns.Leveling, ns.Spellbook
	for _, w in ipairs(widgets) do if w.Refresh then w:Refresh() end end
	local level = ns.get(UnitLevel, "player") or 1
	local lines = {}
	local missing = SB:TrainerMissing(level)
	if #missing == 0 then
		table.insert(lines, "|cff40ff40Du har allt trainern kan lära dig på level " .. level .. ".|r")
	else
		table.insert(lines, "|cffffd100Väntar hos trainern nu:|r")
		for _, r in ipairs(missing) do
			local tag = r.source == "tome" and " |cffaaaaaa(tome)|r" or (r.source == "quest" and " |cffaaaaaa(quest)|r" or "")
			table.insert(lines, string.format("  %s  rank %d  |cffaaaaaa(level %d)|r%s", r.spell, r.rank, r.level, tag))
		end
	end
	local up = SB:TrainerUpcoming(level, math.min(60, level + 6))
	local levels = {}
	for l in pairs(up) do table.insert(levels, l) end
	table.sort(levels)
	if #levels > 0 then
		table.insert(lines, " ")
		table.insert(lines, "|cffffd100Kommande levels:|r")
		for _, l in ipairs(levels) do
			local names = {}
			for _, r in ipairs(up[l]) do table.insert(names, r.spell .. " " .. r.rank) end
			table.insert(lines, string.format("  |cff40c0ff%d|r: %s", l, table.concat(names, ", ")))
		end
	end
	table.insert(lines, " ")
	table.insert(lines, "|cffaaaaaaKällor: wclbox, method.gg, conquestcapped (kontrollerade " .. (ns.TRAINER and ns.TRAINER.checked or "?") .. ").|r")
	trainerText:SetText(table.concat(lines, "\n"))
	-- Rader som bryts blir högre än 14 px: använd textens verkliga höjd
	local th = trainerText.GetStringHeight and trainerText:GetStringHeight()
	trainerContent:SetHeight(math.max(#lines * 14, tonumber(th) or 0) + 20)

	-- Hit
	local sh, mh = LV:Hit()
	local cs, cm = LV:HitCaps()
	local function line(label, v, cap, active)
		if not v then return label .. ": |cff999999kan inte läsas|r" end
		local col = v >= cap and "|cff40ff40" or "|cffff8040"
		return string.format("%s%s: %s%.1f %%|r av %d %%", active and "> " or "", label, col, v, cap)
	end
	local kind = LV:HitKind()
	hitText:SetText(line("Spell hit", sh, cs, kind == "spell") .. "\n" .. line("Melee hit", mh, cm, kind == "melee")
		.. "\n|cffaaaaaaSpec väljs på BiS-fliken. Resto behöver ingen hit.|r")

	-- Reagens
	if LV:ReagentFree() then
		reagentText:SetText("|cff40ff40Reagent Economy: dina spells behöver inga reagens.|r")
	else
		local out = {}
		for _, r in ipairs(LV:Reagents()) do
			local col = r.low and "|cffff6060" or "|cff40ff40"
			table.insert(out, string.format("%s: %s%s|r  |cffaaaaaa(%s)|r", r.def.name, col, tostring(r.count or "?"), r.def.spell))
		end
		reagentText:SetText(#out > 0 and table.concat(out, "\n") or "|cffaaaaaaInga spells som kräver reagens än.|r")
	end
	-- Checklistans status (kort)
	local list = LV:Checklist()
	local bad = 0
	for _, it in ipairs(list) do if it.ok == false then bad = bad + 1 end end
	checkText:SetText(bad == 0 and "|cff40ff40Allt klart just nu.|r" or ("|cffff8040" .. bad .. " saker saknas just nu.|r"))
end

UI.AddTab("leveling", "Utveckling", build, refresh)
