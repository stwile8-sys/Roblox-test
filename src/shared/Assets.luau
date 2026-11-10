--!strict
-- ID звуков и товаров. Товары заполняет конвейер tools/assets (Open Cloud).
-- 0 = ещё не создано: код это переживает (товар скрыт, звук молчит).
return {
	sfx = {
		coin = 79090775493928,
		click = 128531387672967,
		buy = 103970609646472,
		pop = 87199843858262,
		whoosh = 102305966404460,
		boom = 83325341073722,
		upgrade = 130912696991028,
		rebirth = 94953124258497,
		zone = 75651272851801,
		land = 75237901831863,
	} :: { [string]: number },
	music = {
		main = 1843529601,
	} :: { [string]: number },
	passes = {
		VIP = 0,
		Power2x = 0,
		Coins2x = 0,
		AutoLaunch = 0,
	} :: { [string]: number },
	products = {
		PowerS = 0,
		PowerM = 0,
		PowerL = 0,
		Boost15 = 0,
		Coins = 0,
		LaunchAll = 0,
	} :: { [string]: number },
}
