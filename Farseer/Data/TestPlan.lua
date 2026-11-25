-- Första testpasset: det mest osäkra först (sådant bara den riktiga klienten kan visa).
-- Resultatet sparas i ns.db.testlist[id] = "ok" / "bad" och följer med i /farseer report.

local _, ns = ...

ns.TEST_PLAN = {
	{ id = "look", title = "Settings window looks right",
		how = "Open /farseer. Click through every tab: nothing cut off or overlapping, all sidebar icons show." },
	{ id = "skins", title = "Buttons on screen look clean",
		how = "Situation, totem, reminder and procs buttons have thin black borders, no old Blizzard frame behind." },
	{ id = "maelstrom", title = "Maelstrom stacks and flash",
		how = "Get Maelstrom once out of combat. In combat the number counts up and the icon flashes gold at 5." },
	{ id = "shield", title = "Shield charges flash red",
		how = "Cast your shield, let it get hit down to 1 charge (also in combat): the icon flashes red." },
	{ id = "combatcall", title = "Call of the Elements with any set in combat",
		how = "In combat, right-click a situation set: Call drops THAT set. After combat the report says \"works\"." },
	{ id = "procflash", title = "Stormstrike, Clearcasting and Flurry flash",
		how = "Each proc icon flashes while it is up and stops when it fades." },
	{ id = "swing", title = "Swing timer, off-hand bar and Flurry",
		how = "The swing bar follows your swings; dual wield shows a second thin bar; \"Flurry 3\" appears on crits." },
	{ id = "ready", title = "Ready glow on the HUD",
		how = "In combat with a target in range, Earth Shock and Stormstrike glow when they are off cooldown." },
	{ id = "offhand", title = "Off-hand imbue button",
		how = "Dual wield, main hand imbued: the third reminder button puts the imbue on the off-hand." },
	{ id = "keymode", title = "Key binding mode",
		how = "/farseer kb, hover a Farseer button, press a key: it binds. Delete clears, Escape exits." },
	{ id = "rez", title = "Resurrect button",
		how = "With a dead party member and you out of combat, the button appears with their name and resurrects them." },
	{ id = "tts", title = "Read alerts aloud",
		how = "Alerts tab: pick \"Critical only\" in Read alerts aloud. You should hear \"Farseer\"." },
	{ id = "timers", title = "Totem timer colors",
		how = "Drop a totem: the time turns yellow at 30 s, red at 10 s and blinks the last 5 s." },
	{ id = "fade", title = "Fade bars out of combat",
		how = "Settings: tick Fade totem bars. Bars go see-through out of combat, full on mouseover and in combat." },
	{ id = "alertbox", title = "Alert box",
		how = "/farseer test shows the alert with its colored edge and dark plate." },
	{ id = "setup", title = "First-time setup",
		how = "/farseer setup opens the setup window; its choices are applied when you press Finish." },
}
