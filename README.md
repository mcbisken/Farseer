# Farseer — shaman-addon för WoW: Forever

Allt-i-ett-addon för shaman i **World of Warcraft: Forever** (klient 1.60.1, `## Interface: 16001`).
Öppnas med `/farseer` (eller `/fsr`) eller via minimap-ikonen.

## Installation
```
powershell -ExecutionPolicy Bypass -File tools\install.ps1
```
Kopierar `Farseer\` till `C:\SPEL\World of Warcraft\_forever_\Interface\AddOns\Farseer`. Skriv `/reload` i spelet.

## Funktioner
| Del | Vad den gör |
|---|---|
| **Makron** | ~45 mallar i 6 kategorier (Elemental, Enhancement, Restoration, Totems, PvP, Verktyg). Byggs efter dina spells och inställningar: mouseover, focus, självheal, rank 1 Earth Shock. Skapa/uppdatera i spelet, plocka upp till actionbar, redigera, spara egna. Uppdateras automatiskt när du lär dig nya spells. |
| **Keybinds** | 6 färdiga layouter (Elemental, Enhancement, Resto mouseover, PvP, bara situationsknappar, musknappar). Skapar makron som behövs. Det som låg på tangenterna sparas och kan återställas (`/farseer restore`). |
| **Situationsknappar** | PvE-set (Melee, Caster, Tank, AoE, Fear, Gift, Sjukdom, Eld/Frost/Natur-resist) och PvP-set (vs Melee, Rogue, Mage, Fear, Hunter, Flagga, Burst, Healer). **Vänsterklick** = nästa totem i ordningen, **högerklick** = hela setet med Call of the Elements. Auto-byte PvE/PvP efter zon. Redigerbara. |
| **Totemvarningar** | Stor varning + ljud + glödande knapp: fear/charm på dig → Tremor; fear-mobs (Magmadar, Onyxia…) → Tremor; fiendens klass i PvP → Grounding/Tremor/Poison Cleansing/Earthbind; gift/sjukdom i gruppen → Cleansing; boss/zon → resist-totem; inga totems i strid. Gruppens sammansättning ger grön markerad situation. Egna fear-mobs och bossregler. |
| **Kontratotems** | Egen bar med Tremor, Grounding, Poison/Disease Cleansing, Earthbind, resist-totems… (väljbara). |
| **Totem-timers** | En knapp per element med tid kvar; högerklick tar bort totemet. |
| **Påminnelser** | Sköld (Lightning/Water) och vapen-imbue saknas/går ut — klicka för att casta. |
| **BiS** | Pre-raid BiS för Elemental, Enhancement och Restoration (17 slots var) med källa (dungeon/boss, quest, crafting, rykte, Pix Xizzix), alternativ, tooltips, shift-klick-länk och bock för items du redan har. |
| **Strids-HUD** (v1.1) | Cooldowns för shocks, Stormstrike, Chain Lightning, Riptide, Fire Nova, Nature's Swiftness, Lightning Mastery, Rage of the Farseer, Mana Tide, Reincarnation, rasförmågor och trinkets med use-effekt. Räckvidd mot target (Shock/Bolt/Melee, röda ikoner utom räckhåll). Flame Shock-timer på ditt target, Riptide per mål med "Chain Heal +25 %"-tips, swing timer (Forevers `PLAYER_SWING`). |
| **Totems, nästa nivå** (v1.1) | Varning när ett totem dör i förtid ("GROUNDING ÅT EN SPELL!") — inte när det går ut, byts, recallas eller tas bort av dig. Nedräkning till Tremor Totems nästa puls (var 4:e s). Cooldown-svep på kontratotem-baren. 20 nya fear-mobs, 17 resist-bossar och 12 gift/sjukdoms-mobs från Forevers nya dungeons (Blackmaw Hold, Shaper's Terrace, Drowned City, Alcaz Island …) och klassiska 55–60. |
| **Utrustningsset** (v1.1) | Knappar för spelets Equipment Manager-set, automatiskt byte vid PvE/PvP-byte, `/farseer gear <set>`. |
| **Utveckling** (v1.1) | Vad som väntar hos trainern (173 ranker, level 1–60) och vad som kommer de närmaste levels; meddelande vid level up. Hit mot cap (17 % spell / 8 % melee). Reagens (Ankh, Fish Oil, Shiny Fish Scale; Reagent Economy-perken räknas). |
| **Checklista** (v1.1) | Före raid: sköld, imbue, mat, flaska/elixir, Ankh, hållbarhet, Call-set, hit-cap, trainer. Visas vid ready check, när du går in i en raid och med `/farseer check`. |
| **T0.5** (v1.1) | The Five Thunders-kedjan, 29 steg med quest-ID, NPC, uppgift och belöning; status (klar/pågår/kvar) från questloggen. |
| **BiS-jämförelse** (v1.1) | Per slot: "BiS på" / "Alt på" / "Uppgradera", och en lista med nästa uppgraderingar. |
| **Profiler** (v1.1) | Spara/ladda hela setupen under ett namn, exportera/importera som text (`FS1:`/`FS2:`) för att dela. |
| **Språk** (v1.1) | Spellnamn slås upp via spell-ID: makron, knappar och keybinds fungerar även på icke-engelska klienter (mob-namnen i varningarna är fortfarande engelska). |
| **Procs och larm** (v1.2) | Egen ruta (Larm-fliken): Maelstrom Weapon-stackar som lyser vid 5, laddningar på Lightning/Water Shield (även på påminnelseknappen), "WINDFURY!" vid proc (spelets cooldown-händelse), låg mana med förslag (Mana Tide → Water Shield → Mana Spring), purge-ikon när target har magiska buffar, castbar för target/focus med "Earth Shock!" (stor KICK-varning i PvP), diminishing returns på target, Blizzards Assisted Combat-förslag om klienten har det. |
| **Totemräckvidd** (v1.2) | Buff-totems som inte når dig får röd ruta och UTOM på totembaren, plus en varning. Ny Totemic Call-knapp på totembaren (högerklick Totemic Recall) som lyser när något är utom räckhåll. |
| **Spec** (v1.2) | Specen läses från talangpoängen (eller Stormstrike/Mana Tide/Lightning Mastery). Vid byte: BiS-listan byter spec och profilen du kopplat till specen laddas (Profiler-fliken). |
| **Healing** (v1.2) | Click-cast-mallar till Blizzards Click Casting (raidramar) med backup och återställning. Downranking: välj rank för Healing Wave, Lesser Healing Wave och Chain Heal, se mana per rank, makrona FS HW/LHW/CH Low. |
| **Raid** (v1.2) | Totemfördelning mellan shamans efter varje grupps sammansättning; skicka i chatten, kopiera, eller lägg ditt set i Call. |
| **Vapen** (v1.6) | Påminnelse + knapp för off-hand-imbue (dual wield; Flametongue Weapon som standard, `/cast` + `/use 17`). Checklistan visar off-hand-imbue och vapenolja/slipsten (rätt sort för din spec, antal i väskorna). |
| **Totems** (v1.6) | Varning innan totems går ut (standard 20 s, bara totems ≥ 1 min). Vilka i gruppen saknar dina totembuffar (utanför strid, rad under totembaren, Totemic Call lyser). Situations- och kontratotemknappar blir blå när du inte har mana. Orange ram för Windfury + Flametongue i samma set. |
| **Procs** (v1.6) | Egen flik. Ikoner för Clearcasting (Elemental Focus), Stormstrike (buff på dig eller din debuff på target) och Flurry. Nedräkning för Mana Tide Totem och Rage of the Farseer, valfritt meddelande i gruppen. Lava Burst på HUD:en. |
| **Bossmods** (v1.6) | DBM/BigWigs: "TREMOR IN 4s" innan bossens fear/charm, Poison/Disease Cleansing innan gift/sjukdom. Pull-timer: lista över det som saknas (sköld, imbue, totems). |
| **Under vatten** (v1.6) | Varning när luften tar slut (förslag: Water Breathing och antal Shiny Fish Scale) och när Water Breathing har under en minut kvar. |
| **Inställningar** | Visa/dölj, skala och storlek för alla bars, lås upp/flytta, minimap-ikon, påminnelser, återställ. |

Minimap-ikon: vänsterklick = inställningar, högerklick = lås upp/lås bars, mittenklick = PvE/PvP, dra = flytta ikonen.

## WoW: Forever-begränsningar som addonet tar hänsyn till
Forever kör retail-klienten med Midnights addon-regler:
- I strid kan värden vara **secret**: all läsning går via `ns.get`/`ns.getAll`/`ns.field` som ger `nil` i stället för att krascha.
- Totems spåras från dina egna casts (alltid läsbara), inte bara från totemslottarna.
- Säkra knappar, makron och keybinds ändras bara utanför strid (köas till striden är slut).
- Combat-loggen är stängd för addons, så inget i Farseer använder den.

## Tester
```
pip install lupa
python tests/run_tests.py
```
Laddar addonet i riktig Lua 5.1 mot en mock av WoW-API:t (`tests/wowmock.lua`) och kör scenarion: alla makromallar ≤ 255 tecken
med alla inställningskombinationer, keybind-mallar + återställning, Call of the Elements-slottar, strid/köande, varningsregler,
secret values, påminnelser, alla UI-flikar, slashkommandon och kontroll av oavsiktliga globaler.
`tests/tests_v11.lua` täcker v1.1 (tysk klient, HUD, totemdöd, profiler, utrustning, trainer, checklista, T0.5, BiS-jämförelse).
`tests/tests_v12.lua` täcker v1.2 (procs, mana, purge, casts, DR, totemräckvidd, spec, click-cast, raid-totems, downranking).
2589 kontroller, 0 fel (2026-11-24). Addonet visar all text på engelska (kommentarer i koden är på svenska).

## Inte verifierat i riktiga klienten än
Testerna kör mot en mock, inte mot spelet. Saker att kolla första gången i spelet:
1. Att ett klick på en situationsknapp bara lägger **ett** totem (knapparna registrerar både ned- och upptryck, som ShamanForever gör).
2. Att högerklick skriver in setet i Call of the Elements (`SetMultiCastSpell`). Om klienten blockerar det säger Farseer till i chatten. Kontrollera också att varje totem hamnar i rätt element: Farseer utgår från att Call-baren har ordningen Earth, Fire, Water, Air (som i Wrath), eller klientens `TOTEM_PRIORITIES` om den finns. Hamnar de fel, kör `/dump GetActionInfo(133)` till `(136)` och säg till.
3. Rank-syntax (`Earth Shock(Rank 1)`) i de makron som är märkta experimentella.
4. `/farseer debug` visar totemslottar, secret-läge och fel.
5. v1.1: att HUD-cooldowns syns i strid (duration-objekt), att `PLAYER_SWING` och `UNIT_SPELLCAST_SENT` levererar
   (swing timer och Riptide-mål), att "totemet dog"-varningen inte ger falsklarm i strid, och att hit-procenten stämmer
   med karaktärsfönstret (`GetSpellHitModifier` + `GetCombatRatingBonus`).
6. v1.2, mest osäkert först:
   - Click-cast: om addons får skriva till `C_ClickBindings` (Farseer läser tillbaka och säger till om det inte gick).
   - Windfury-proc: att `SPELL_UPDATE_COOLDOWN` skickar proc-spellens ID i Forever (ShamanForever bygger på det).
   - Maelstrom-buffens ID 408505 och om stackarna går att läsa i strid (annars ritas siffran av spelet utan ljud).
   - DR (`UNIT_SPELL_DIMINISH_CATEGORY_STATE_UPDATED`) och Assisted Combat finns kanske inte i Forever — då syns inget.
   - Fiendens casts: namnet är troligen secret i strid; då visas bara att target castar.
   - Totemräckvidd och purge fungerar bara när spelet visar buffar (oftast utanför strid). Buff-ID:n är Classics.
   - Spec: formatet på `GetTalentTabInfo` i Forever.
   - Chattmeddelanden från knappen Skicka i chatten kan vara blockerade i instanser.
7. v1.6:
   - Off-hand-imbue: att `/cast Flametongue Weapon` följt av `/use 17` lägger imbuen på off-hand, och att
     `C_PaperDollInfo.OffhandHasWeapon` finns.
   - Vapenolja: att tooltipraderna (`C_TooltipInfo`) visar "Brilliant Wizard Oil (30 min)" / "Sharpened (+8 Damage)".
   - Gruppens totembuffar: `UnitInRange` är ~40 m, totems når 20–30 m, så någon på 30–40 m kan visas som "saknar".
   - Manaknappar: `C_Spell.IsSpellUsable` (annars manakostnad mot `UnitPower`). Nästa totem i `/castsequence`
     spåras av Farseer själv.
   - Stormstrike: om det är en buff på dig eller en debuff på target i Forever (båda kollas).
   - DBM/BigWigs: att callbackarna har samma argument som i retail.
   - Andning: att `MIRROR_TIMER_START` ger luften i millisekunder.

Data för v1.1: trainer-ranker från wowforever.wclbox.com, method.gg och conquestcapped; T0.5 från conquestcapped och
wowhead.com/forever (bara 7 av 29 quest-ID:n bekräftade för Forever, resten är Classic-ID:n); bossmekanik från
Warcraft Tavern och method.gg (Hyjal och Barrow Deeps saknar publicerad förmågedata).

BiS-källor: conquestcapped.com, wowtbc.gg, timesaver.gg, wowhead.com/forever (kontrollerade 2026-11-23). Fas 1-raidlistor saknas tills raiderna öppnar 9 december.
