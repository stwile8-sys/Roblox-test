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
		VIP = 2074222785,
		Power2x = 2074595016,
		Coins2x = 2075026887,
		AutoLaunch = 2075777008,
	} :: { [string]: number },
	products = {
		PowerS = 3730197053,
		PowerM = 3730197062,
		PowerL = 3730197070,
		Boost15 = 3730197078,
		Coins = 3730197084,
		LaunchAll = 3730197091,
	} :: { [string]: number },
}
