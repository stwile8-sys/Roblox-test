--!strict
-- ID звуков, музыки и товаров. Заполняется автоматически пайплайном assets (ветка assets → Open Cloud).
-- 0 = ещё не загружено/не создано: код это переживает (звук не играет, товар скрыт).
return {
	sfx = {
		coin = 79090775493928, hack = 75237901831863, wallBreak = 83325341073722, steal = 92048137987336, caught = 135151797424512, escape = 75651272851801, upgrade = 130912696991028, rebirth = 94953124258497,
		trap = 112376491675221, alarm = 128118964741972, buy = 103970609646472, click = 128531387672967, pop = 87199843858262, whoosh = 102305966404460,
		voiceCommon = 77601670657067, voiceRare = 118569478934289, voiceEpic = 111522940584088, voiceLegendary = 72374710193133, voiceChrono = 125076578837982,
	} :: { [string]: number },
	music = {
		lobby = 1843529601,
		base = 117013055420452,
		raid = 9045389581,
		season = 131361167613190,
	} :: { [string]: number },
	passes = {
		VIP = 2074222785, AutoCollect = 2076196659, ScannerPlus = 2074936843, SecondFloor = 2075392790,
	} :: { [string]: number },
	products = {
		Starter = 3730050843, Titan = 3730050845, Shards100 = 3730050852, Shards550 = 3730050860, Shards1500 = 3730050864, Energy5 = 3730050869, BoostX2 = 3730050880, SeasonPass = 3730050885,
	} :: { [string]: number },
}
