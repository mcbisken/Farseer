-- BiS-data för shaman i WoW: Forever (genererad från research 2026-11-23, se källor i meta.sources).
-- Format per rad: slot, name, id, source, where, chance, verified, url, alt = { ... }
local _, ns = ...

-- Shaman BiS research for World of Warcraft: Forever (client 1.60.1), checked 2026-11-23.
-- Only pre-raid lists exist: no Forever site has published a Phase 1 raid list yet (raids open 2026-12-09).
-- Item IDs come from wowhead.com/forever link URLs on the cited guide, or were checked by opening
-- wowhead.com/forever/item=<id> and matching the name. Drop chances: no Forever guide lists them and
-- wowhead pages do not show them to the fetcher, so chance = nil unless a guide stated one.

local CC_ELE  = "https://conquestcapped.com/guides/wow-forever/wow-forever-elemental-shaman-bis/"
local CC_ENH  = "https://conquestcapped.com/guides/wow-forever/wow-forever-enhancement-shaman-bis/"
local WT_ELE  = "https://wowtbc.gg/warcraftforever/bis-list/elemental-shaman/"
local WT_ENH  = "https://wowtbc.gg/warcraftforever/bis-list/enhancement-shaman/"
local WT_RES  = "https://wowtbc.gg/warcraftforever/bis-list/restoration-shaman/"
local TS_RES  = "https://timesaver.gg/tools/wow-forever/leveling-gear/shaman/restoration"

local T05 = "Tier 0.5 'The Five Thunders' questline (turn in to Deliana, Ironforge / Mokvar, Orgrimmar; pick the spec version)"

ns.BIS = {
  meta = {
    checked = "2026-11-23",
    notes = "Pre-raid only. No Forever source has published a Phase 1 (Onyxia/Hyjal/Barrow Deeps) list; conquestcapped says a raid section comes once loot is known. "
      .. "Elemental and Enhancement use conquestcapped's 'Pre-Raid BiS' tab (updated 22 and 21 Nov 2026), with the first alternative from its options tables or 'realistic' tab. "
      .. "Restoration uses timesaver.gg's level-60 row (data checked 13 Nov 2026) as primary and wowtbc.gg's 'Realistic' pre-raid list as the alternative. "
      .. "Forever changes: the Five Thunders T0.5 set has three versions, one per spec, with new IDs 2270xx. Many new items have IDs 25xxxx-28xxxx: new Leatherworking and Blacksmithing recipes, "
      .. "Pix Xizzix (STV) items bought with Tarnished Undermine Real, and new dungeons (Blackmaw Hold, The Drowned City, The Shaper's Terrace). "
      .. "Hit caps per conquestcapped: casters need 17% spell hit against raid bosses (Tidal Focus 5/5 gives 5%); Enhancement needs 8% melee hit. "
      .. "Totems (relic slot) exist. Dual wield is not covered by any source; Enhancement BiS is a two-hander. "
      .. "Quest-to-slot mapping for the T0.5 pieces is from wowtbc.gg (Horde quest names). Drop chances are not published.",
    sources = { CC_ELE, CC_ENH, WT_ELE, WT_ENH, WT_RES, TS_RES, "https://www.wowhead.com/forever/" },
  },
  specs = {
    -------------------------------------------------------------------------
    elemental = {
      prebis = {
        { slot = "HEAD", name = "Coif of The Five Thunders", id = 227002, source = "quest", where = T05 .. " - Saving the Best for Last", chance = nil,
          alt = { name = "Spellweaver's Turban", id = 22267, source = "dungeon", where = "Upper Blackrock Spire - General Drakkisath" }, verified = true, url = CC_ELE },
        { slot = "NECK", name = "Nacreous Shell Necklace", id = 22403, source = "dungeon", where = "Stratholme - Cannon Master Willey", chance = nil,
          alt = { name = "Orb of the Darkmoon", id = 19426, source = "vendor", where = "Darkmoon Faire" }, verified = true, url = CC_ELE },
        { slot = "SHOULDER", name = "Pauldrons of The Five Thunders", id = 227003, source = "quest", where = T05 .. " - Anthion's Parting Words", chance = nil,
          alt = { name = "Burial Shawl", id = 18681, source = "dungeon", where = "Scholomance - Lord Alexei Barov (rare from other Scholomance bosses)" }, verified = true, url = CC_ELE },
        { slot = "BACK", name = "Arcanoweave Cloak", id = 272411, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - 75 Tarnished Undermine Real", chance = nil,
          alt = { name = "Amplifying Cloak", id = 18350, source = "dungeon", where = "Dire Maul - Magister Kalendris" }, verified = true, url = CC_ELE },
        { slot = "CHEST", name = "Vest of The Five Thunders", id = 227004, source = "quest", where = T05 .. " - Saving the Best for Last", chance = nil,
          alt = { name = "Robes of Dark Summons", id = 280057, source = "dungeon", where = "Blackmaw Hold - Impaan the Imprisoner" }, verified = true, url = CC_ELE },
        { slot = "WRIST", name = "Bindings of The Five Thunders", id = 227001, source = "quest", where = T05 .. " - An Earnest Proposition", chance = nil,
          alt = { name = "Dryad's Wrist Bindings", id = 19595, source = "reputation", where = "Warsong Gulch - Warsong Outriders / Silverwing Sentinels, Exalted" }, verified = true, url = CC_ELE },
        { slot = "HANDS", name = "Gauntlets of The Five Thunders", id = 227006, source = "quest", where = T05 .. " - Just Compensation", chance = nil,
          alt = { name = "Storm Gauntlets", id = 12632, source = "crafted", where = "Leatherworking (BoE)" }, verified = true, url = CC_ELE },
        { slot = "WAIST", name = "Belt of the Archmage", id = 18405, source = "crafted", where = "Tailoring (pattern source in Forever unconfirmed by guide)", chance = nil,
          alt = { name = "Cord of The Five Thunders", id = 227008, source = "quest", where = T05 .. " - Just Compensation (conquestcapped 'realistic' pick)" }, verified = true, url = CC_ELE },
        { slot = "LEGS", name = "Ironfeather Leggings", id = 252486, source = "crafted", where = "Leatherworking (300)", chance = nil,
          alt = { name = "Kilt of The Five Thunders", id = 227005, source = "quest", where = T05 .. " - Anthion's Parting Words" }, verified = true, url = CC_ELE },
        { slot = "FEET", name = "Slippers of The Five Thunders", id = 227007, source = "quest", where = T05 .. " - Anthion's Parting Words", chance = nil,
          alt = { name = "Waterspout Boots", id = 18322, source = "dungeon", where = "Dire Maul - Hydrospawn" }, verified = true, url = CC_ELE },
        { slot = "FINGER1", name = "Channeler's Ring", id = 272406, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - buy Blessed Band of Light (272407) for 75 Tarnished Undermine Real, then exchange it", chance = nil,
          alt = { name = "Warden's Signet of Brilliance", id = 275982, source = "reputation", where = "The Watchers - Exalted" }, verified = true, url = CC_ELE },
        { slot = "FINGER2", name = "Rune Band of Wizardry", id = 22339, source = "dungeon", where = "Upper Blackrock Spire - Lord Valthalak (summoned)", chance = nil,
          alt = { name = "Maiden's Circle", id = 13001, source = "world drop", where = "World drop (BoE, Auction House)" }, verified = true, url = CC_ELE },
        { slot = "TRINKET1", name = "Eye of the Beast", id = 13968, source = "quest", where = "Quest 'For The Horde!' (4974) or 'General Drakkisath's Demise' (5102) - Upper Blackrock Spire", chance = nil,
          alt = { name = "Weakness Analyzer", id = 272438, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - 125 Tarnished Undermine Real" }, verified = true, url = CC_ELE },
        { slot = "TRINKET2", name = "Royal Seal of Eldre'Thalas", id = 18471, source = "quest", where = "Quest 'Frost Shock and You' (7505) - Dire Maul", chance = nil,
          alt = { name = "Smolderweb's Eye", id = 13213, source = "dungeon", where = "Lower Blackrock Spire - Mother Smolderweb" }, verified = true, url = CC_ELE },
        { slot = "MAINHAND", name = "Witchblade", id = 13964, source = "dungeon", where = "Scholomance - Darkmaster Gandling", chance = nil,
          alt = { name = "Mindfang", id = 20214, source = "reputation", where = "Arathi Basin - The Defilers / The League of Arathor, Exalted (Sageclaw 20070 is the other AB option)" }, verified = true, url = CC_ELE },
        { slot = "OFFHAND", name = "Draconian Aegis of the Legion", id = 22336, source = "dungeon", where = "Upper Blackrock Spire - Lord Valthalak (summoned)", chance = nil,
          alt = { name = "Tome of the Lost", id = 22253, source = "dungeon", where = "Upper Blackrock Spire - General Drakkisath" }, verified = true, url = CC_ELE },
        { slot = "RELIC", name = "Burning Totem", id = 272433, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - 50 Tarnished Undermine Real (extends Flame Shock by 3 s)", chance = nil,
          alt = { name = "Totem of the Storm", id = 23199, source = "world drop", where = "World drop (BoE, Auction House); +33 Lightning Bolt/Chain Lightning damage. Not the same item as Pix Xizzix's Totem of the Storm 272432" }, verified = true, url = CC_ELE },
      },
      -- phase1: omitted, no published list.
    },
    -------------------------------------------------------------------------
    enhancement = {
      prebis = {
        { slot = "HEAD", name = "Black Dragonscale Helm", id = 252605, source = "crafted", where = "Leatherworking", chance = nil,
          alt = { name = "Skyfury Helm", id = 20134, source = "quest", where = "Quest 'The Darkreaver Menace' - Scholomance" }, verified = true, url = CC_ENH },
        { slot = "NECK", name = "Mark of Fordring", id = 15411, source = "quest", where = "Quest 'In Dreams' - Western Plaguelands", chance = nil,
          alt = { name = "Beads of Ogre Might", id = 22150, source = "quest", where = "Quest 'Falrin's Vendetta' - Dire Maul" }, verified = true, url = CC_ENH },
        { slot = "SHOULDER", name = "Darkspear Epaulets", id = 272106, source = "reputation", where = "Darkspear Raiders - Exalted (vendor Creeg Bothunk), Horde", chance = nil,
          alt = { name = "Theramore Epaulets", id = 271956, source = "reputation", where = "Theramore Expeditionary Force - Exalted (Alliance version)" }, verified = true, url = CC_ENH },
        { slot = "BACK", name = "Howler's Furs", id = 272414, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - 75 Tarnished Undermine Real (1% hit)", chance = nil,
          alt = { name = "Arcanoweave Cloak", id = 272411, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - 75 Tarnished Undermine Real" }, verified = true, url = CC_ENH },
        { slot = "CHEST", name = "Timbermaw Tunic", id = 252484, source = "crafted", where = "Leatherworking", chance = nil,
          alt = { name = "Dawn Armor", id = 252483, source = "crafted", where = "Leatherworking" }, verified = true, url = CC_ENH },
        { slot = "WRIST", name = "Tranquil Wristguards", id = 279256, source = "crafted", where = "Leatherworking (guide notes Windtalker's Wristguards 19582, WSG Exalted, are slightly better)", chance = nil,
          alt = { name = "Slashclaw Bracers", id = 13211, source = "dungeon", where = "Lower Blackrock Spire" }, verified = true, url = CC_ENH },
        { slot = "HANDS", name = "Bloodmail Gauntlets", id = 14615, source = "dungeon", where = "Scholomance", chance = nil,
          alt = { name = "Fists of The Five Thunders", id = 227022, source = "quest", where = T05 .. " - Just Compensation" }, verified = true, url = CC_ENH },
        { slot = "WAIST", name = "Girdle of The Five Thunders", id = 227018, source = "quest", where = T05 .. " - Just Compensation (1% hit)", chance = nil,
          alt = { name = "Might of the Timbermaw", id = 19044, source = "crafted", where = "Leatherworking" }, verified = true, url = CC_ENH },
        { slot = "LEGS", name = "Outrider's Chain Leggings", id = 22673, source = "reputation", where = "Warsong Gulch - Warsong Outriders, Exalted (Horde) (1% hit)", chance = nil,
          alt = { name = "Sentinel's Chain Leggings", id = 22748, source = "reputation", where = "Warsong Gulch - Silverwing Sentinels, Exalted (Alliance version)" }, verified = true, url = CC_ENH },
        { slot = "FEET", name = "Bloodmail Boots", id = 14616, source = "dungeon", where = "Scholomance - six bosses (wowtbc lists it as a Scholomance trash drop)", chance = "<=3% per boss (per conquestcapped)",
          alt = { name = "Windreaver Greaves", id = 13967, source = "dungeon", where = "Scholomance" }, verified = true, url = CC_ENH },
        { slot = "FINGER1", name = "Don Julio's Band", id = 19325, source = "reputation", where = "Alterac Valley - Frostwolf Clan / Stormpike Guard, Exalted (1% hit)", chance = nil,
          alt = { name = "Blackstone Ring", id = 17713, source = "dungeon", where = "Maraudon (conquestcapped 'realistic' pick)" }, verified = true, url = CC_ENH },
        { slot = "FINGER2", name = "Warden's Signet of Ferocity", id = 275981, source = "reputation", where = "The Watchers - Exalted (1% hit)", chance = nil,
          alt = { name = "Ring of Demonic Guile", id = 18314, source = "dungeon", where = "Dire Maul (conquestcapped 'realistic' pick)" }, verified = true, url = CC_ENH },
        { slot = "TRINKET1", name = "Behemoth Bones", id = 280065, source = "dungeon", where = "Blackmaw Hold - Blackmaw Behemoth", chance = nil,
          alt = { name = "Hand of Justice", id = 11815, source = "dungeon", where = "Blackrock Depths - Emperor Dagran Thaurissan" }, verified = true, url = CC_ENH },
        { slot = "TRINKET2", name = "Counterattack Lodestone", id = 18537, source = "dungeon", where = "Dire Maul North - Mizzle the Crafty (tribute chest)", chance = nil,
          alt = { name = "Blackhand's Breadth", id = 13965, source = "quest", where = "Quest 'For The Horde!' or 'General Drakkisath's Demise' - Upper Blackrock Spire" }, verified = true, url = CC_ENH },
        { slot = "MAINHAND", name = "Forest Defender's Axe", id = 279260, source = "crafted", where = "Blacksmithing (two-hand)", chance = nil,
          alt = { name = "The Unstoppable Force", id = 19323, source = "reputation", where = "Alterac Valley - Exalted (two-hand)" }, verified = true, url = CC_ENH },
        { slot = "OFFHAND", name = nil, id = nil, source = nil, where = "Not used: BiS weapon is a two-hander. No source covers dual wield", chance = nil,
          alt = nil, verified = false, url = CC_ENH },
        { slot = "RELIC", name = "Totem of Rage", id = 22395, source = "dungeon", where = "Blackrock Depths - Magmus", chance = nil,
          alt = { name = "Totem of the Storm", id = 272432, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - 50 Tarnished Undermine Real (lets Lightning Bolt trigger Maelstrom Weapon)" }, verified = true, url = CC_ENH },
      },
      -- phase1: omitted, no published list.
    },
    -------------------------------------------------------------------------
    restoration = {
      prebis = {
        { slot = "HEAD", name = "Living Crown", id = 252561, source = "crafted", where = "Leatherworking", chance = nil,
          alt = nil, verified = true, url = TS_RES },  -- wowtbc also picks Living Crown
        { slot = "NECK", name = "Animated Chain Necklace", id = 18723, source = "dungeon", where = "Stratholme - Ramstein the Gorger", chance = nil,
          alt = { name = "Tooth of Gnarr", id = 13141, source = "dungeon", where = "Upper Blackrock Spire - General Drakkisath" }, verified = true, url = TS_RES },
        { slot = "SHOULDER", name = "Spiritcaller Epaulets", id = 273938, source = "crafted", where = "Leatherworking", chance = nil,
          alt = { name = "Mantle of The Five Thunders", id = 227011, source = "quest", where = T05 .. " - Anthion's Parting Words" }, verified = true, url = TS_RES },
        { slot = "BACK", name = "Hide of the Wild", id = 18510, source = "crafted", where = "Leatherworking", chance = nil,
          alt = nil, verified = true, url = TS_RES },  -- wowtbc also picks Hide of the Wild
        { slot = "CHEST", name = "Vest of Elements", id = 16666, source = "dungeon", where = "Upper Blackrock Spire - General Drakkisath", chance = nil,
          alt = { name = "Tunic of The Five Thunders", id = 227016, source = "quest", where = T05 .. " - Saving the Best for Last" }, verified = true, url = TS_RES },
        { slot = "WRIST", name = "Loomguard Armbraces", id = 13969, source = "dungeon", where = "Scholomance - Kirtonos the Herald", chance = nil,
          alt = { name = "Bracers of The Five Thunders", id = 227009, source = "quest", where = T05 .. " - An Earnest Proposition" }, verified = true, url = TS_RES },
        { slot = "HANDS", name = "Spiritcaller Gauntlets", id = 273937, source = "crafted", where = "Leatherworking", chance = nil,
          alt = { name = "Grasp of The Five Thunders", id = 227014, source = "quest", where = T05 .. " - Just Compensation" }, verified = true, url = TS_RES },
        { slot = "WAIST", name = "Eyestalk Cord", id = 18391, source = "dungeon", where = "Dire Maul - Immol'thar", chance = nil,
          alt = { name = "Sash of The Five Thunders", id = 227010, source = "quest", where = T05 .. " - Just Compensation" }, verified = true, url = TS_RES },
        { slot = "LEGS", name = "Spiritcaller Pants", id = 273936, source = "crafted", where = "Leatherworking", chance = nil,
          alt = { name = "Padre's Trousers", id = 18386, source = "dungeon", where = "Dire Maul West - Illyanna Ravenoak" }, verified = true, url = TS_RES },
        { slot = "FEET", name = "Spiritcaller Greaves", id = 273939, source = "crafted", where = "Leatherworking", chance = nil,
          alt = { name = "Greaves of The Five Thunders", id = 227015, source = "quest", where = T05 .. " - Anthion's Parting Words" }, verified = true, url = TS_RES },
        { slot = "FINGER1", name = "The Postmaster's Seal", id = 13392, source = "dungeon", where = "Stratholme - Postmaster Malown", chance = nil,
          alt = { name = "Band of Mending", id = 22334, source = "dungeon", where = "Stratholme - Grand Crusader Dathrohan" }, verified = true, url = TS_RES },
        { slot = "FINGER2", name = "Fordring's Seal", id = 16058, source = "quest", where = "Quest 'In Dreams' - Western Plaguelands", chance = nil,
          alt = nil, verified = true, url = TS_RES },  -- wowtbc also picks Fordring's Seal
        { slot = "TRINKET1", name = "Heart of the Primeval", id = 274615, source = "dungeon", where = "The Drowned City - Primeval Elemental", chance = nil,
          alt = { name = "Serenity Field", id = nil, source = "vendor", where = "Pix Xizzix (Stranglethorn Vale) - Tarnished Undermine Real (wowtbc shows '125 TUR'); new in Forever, ID not found" }, verified = true, url = TS_RES },
        { slot = "TRINKET2", name = "Second Wind", id = 11819, source = "dungeon", where = "Blackrock Depths - Golem Lord Argelmach", chance = nil,
          alt = { name = "Royal Seal of Eldre'Thalas", id = 18471, source = "quest", where = "Quest 'Frost Shock and You' (7505) - Dire Maul" }, verified = true, url = TS_RES },
        { slot = "MAINHAND", name = "Hammer of Revitalization", id = 22315, source = "dungeon", where = "Dire Maul - Isalien (summoned)", chance = nil,
          alt = { name = "Gift of the Elven Magi", id = 13360, source = "dungeon", where = "Stratholme - Balnazzar" }, verified = true, url = TS_RES },
        { slot = "OFFHAND", name = "Evergreen Shield", id = 279262, source = "crafted", where = "Blacksmithing", chance = nil,
          alt = { name = "Penelope's Rose", id = 15805, source = "quest", where = "Quest 'Kirtonos the Herald' - Scholomance" }, verified = true, url = TS_RES },
        { slot = "RELIC", name = "Totem of Sustaining", id = 23200, source = "dungeon", where = "Scholomance - trash drop (timesaver: 'no clear upgrade' for this slot)", chance = nil,
          alt = nil, verified = true, url = WT_RES },
      },
      -- phase1: omitted, no published list.
    },
  },
}
