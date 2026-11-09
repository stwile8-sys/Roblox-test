--!strict
-- ID звуков, музыки и товаров. Заполняется автоматически пайплайном assets (ветка assets → Open Cloud).
-- 0 = ещё не загружено/не создано: код это переживает (звук не играет, товар скрыт).
return {
	sfx = {
		coin = 0, hack = 0, wallBreak = 0, steal = 0, caught = 0, escape = 0, upgrade = 0, rebirth = 0,
		trap = 0, alarm = 0, buy = 0, click = 0, pop = 0, whoosh = 0,
		voiceCommon = 0, voiceRare = 0, voiceEpic = 0, voiceLegendary = 0, voiceChrono = 0,
	} :: { [string]: number },
	music = {
		lobby = 1843529601,
		base = 117013055420452,
		raid = 9045389581,
		season = 131361167613190,
	} :: { [string]: number },
	passes = {
		VIP = 0, AutoCollect = 0, ScannerPlus = 0, SecondFloor = 0,
	} :: { [string]: number },
	products = {
		Starter = 0, Titan = 0, Shards100 = 0, Shards550 = 0, Shards1500 = 0, Energy5 = 0, BoostX2 = 0, SeasonPass = 0,
	} :: { [string]: number },
}
