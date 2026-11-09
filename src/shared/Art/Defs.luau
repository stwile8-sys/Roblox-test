--!strict
-- Определения артефактов-существ: 40 основных (10/10/8/6/6) + 6 сезонных скинов «Титана Вечности».
-- shape — семейство силуэта для Build, остальные параметры (cols, eyes, horns…) делают каждое существо уникальным.

local M = {}

M.RARITIES = { "common", "rare", "epic", "legendary", "chrono" }

M.RARITY = {
	common = { index = 1, size = 1, weight = 60, color = Color3.fromHex("#B8C4D6"), name = { ru = "Обычный", en = "Common" } },
	rare = { index = 2, size = 2, weight = 25, color = Color3.fromHex("#4FA8FF"), name = { ru = "Редкий", en = "Rare" } },
	epic = { index = 3, size = 3, weight = 10, color = Color3.fromHex("#B45CFF"), name = { ru = "Эпический", en = "Epic" } },
	legendary = { index = 4, size = 5, weight = 4, color = Color3.fromHex("#FFB347"), name = { ru = "Легендарный", en = "Legendary" } },
	chrono = { index = 5, size = 4, weight = 1, color = Color3.fromHex("#00E5FF"), name = { ru = "Хроно", en = "Chrono" } },
} :: { [string]: { index: number, size: number, weight: number, color: Color3, name: { [string]: string } } }

M.PERKS = {
	silent = { ru = "Тихий взлом", en = "Silent hack", desc = { ru = "Шум взлома не будит владельца", en = "Hacking doesn't alert the owner" } },
	step = { ru = "Хроно-шаг", en = "Chrono step", desc = { ru = "Иммунитет к замедлению", en = "Immune to slowdowns" } },
	steel = { ru = "Стальная воля", en = "Steel will", desc = { ru = "Стены +20% прочности", en = "Walls +20% HP" } },
	double = { ru = "Двойник", en = "Double", desc = { ru = "20% шанс унести добычу при провале", en = "20% chance to keep loot when caught" } },
	echo = { ru = "Эхо", en = "Echo", desc = { ru = "+15% дохода базы", en = "+15% base income" } },
	shield = { ru = "Хроно-щит", en = "Chrono shield", desc = { ru = "Замок дольше на 10 сек", en = "Lock lasts 10s longer" } },
} :: { [string]: any }

export type Def = {
	id: string,
	name: { [string]: string },
	rarity: string,
	income: number,
	color: Color3,
	glow: Color3,
	shape: string,
	emotion: string,
	perk: string?,
	seasonal: boolean?,
	season: number?,
	p: { [string]: any }, -- параметры силуэта
}

local function c(h: string): Color3
	return Color3.fromHex(h)
end

local function def(id, ru, en, rarity, income, col, glow, shape, emotion, p, perk): Def
	return {
		id = id,
		name = { ru = ru, en = en },
		rarity = rarity,
		income = income,
		color = c(col),
		glow = c(glow),
		shape = shape,
		emotion = emotion,
		perk = perk,
		p = p or {},
	}
end

-- shape: drop | stone | feather | gem | mush | blob | bug | fox | owl | bat | golem | snail
--        dragon | hourglass | knight | serpent | titan | eater | colossus | rift | paradox | zero
M.LIST = {
	-- COMMON «Крошки»: маленькие капли-кристаллы, пастель
	def("c_drop", "Капля Времени", "Time Drop", "common", 1, "#9FE8FF", "#00E5FF", "drop", "smile", { stretch = 1.25 }),
	def("c_moss", "Мшистый Камень", "Mossy Pebble", "common", 2, "#A7D7A0", "#7CFF9E", "stone", "sleepy", { moss = true }),
	def("c_feather", "Пёрышко Часов", "Clock Feather", "common", 2, "#FFE3A8", "#FFE066", "feather", "smile", {}),
	def("c_tick", "Тик-Так", "Tick-Tock", "common", 3, "#FFC2D9", "#FF8FC4", "gem", "surprise", { facets = 6 }),
	def("c_bubble", "Пузырик", "Bubblet", "common", 1, "#C9D6FF", "#8FB4FF", "blob", "smile", { bubbles = 2 }),
	def("c_shroom", "Грибочек-Минутка", "Minute Shroom", "common", 3, "#FFB6A3", "#FF8A65", "mush", "sly", {}),
	def("c_spark", "Искорка", "Sparky", "common", 4, "#FFF3A1", "#FFE066", "gem", "angry", { facets = 4, spikes = true }),
	def("c_pebble", "Песчинка", "Sandgrain", "common", 2, "#E8D3A8", "#FFD08A", "stone", "smile", {}),
	def("c_jelly", "Желейка", "Jelly", "common", 4, "#D9B8FF", "#B47CFF", "blob", "surprise", { tall = true }),
	def("c_snail", "Улитка-Секунда", "Second Snail", "common", 5, "#BFF0D9", "#5FFFC8", "snail", "sleepy", {}),

	-- RARE «Хранители»: полусущества с глазами и лапками на пьедестале
	def("r_beetle", "Хроно-Жук", "Chrono Beetle", "rare", 8, "#2EC4B6", "#00E5FF", "bug", "smile", { horn = true }),
	def("r_fox", "Кристальный Лис", "Crystal Fox", "rare", 14, "#FF9F5A", "#FFE066", "fox", "sly", { tails = 2 }),
	def("r_whisper", "Шептун", "Whisperer", "rare", 10, "#8E7CC3", "#C3A6FF", "owl", "surprise", { ears = true }),
	def("r_bat", "Летучая Полночь", "Midnight Bat", "rare", 12, "#3D3B6E", "#7B2FF7", "bat", "angry", {}),
	def("r_golem", "Каменный Малыш", "Pebble Golem", "rare", 9, "#B9A27E", "#FFB347", "golem", "smile", { small = true }),
	def("r_owl", "Совушка-Будильник", "Alarm Owl", "rare", 16, "#E6C27A", "#FFE066", "owl", "sleepy", { bell = true }),
	def("r_frog", "Квакстрелка", "Clockfrog", "rare", 7, "#7ED957", "#39FF14", "blob", "smile", { frog = true }),
	def("r_mole", "Крот-Копатель", "Digger Mole", "rare", 11, "#8D6E63", "#FFB347", "golem", "sly", { claws = true }),
	def("r_moth", "Лунный Мотылёк", "Moon Moth", "rare", 18, "#E1E8FF", "#9BE7FF", "bat", "smile", { moth = true }),
	def("r_crab", "Шестерёнчатый Краб", "Gear Crab", "rare", 20, "#FF6B6B", "#FF2E63", "bug", "angry", { crab = true }),

	-- EPIC «Стражи»: крупные, бронированные, парящие фрагменты, кольца
	def("e_dragon", "Механический Дракончик", "Clockwork Dragonling", "epic", 40, "#4ECDC4", "#00E5FF", "dragon", "angry", { wings = true }),
	def("e_hourglass", "Хранитель Песочных Часов", "Hourglass Keeper", "epic", 35, "#F4D35E", "#FFE066", "hourglass", "sleepy", {}),
	def("e_knight", "Латный Страж", "Armor Warden", "epic", 28, "#7F8C9D", "#9BE7FF", "knight", "angry", {}),
	def("e_serpent", "Змей Циферблата", "Dial Serpent", "epic", 50, "#2ECC71", "#39FF14", "serpent", "sly", {}),
	def("e_turtle", "Черепаха-Бастион", "Bastion Turtle", "epic", 22, "#5D8A66", "#7CFF9E", "golem", "sleepy", { shell = true }),
	def("e_phoenix", "Феникс Рассвета", "Dawn Phoenix", "epic", 60, "#FF7A1A", "#FFB347", "dragon", "smile", { phoenix = true }),
	def("e_lynx", "Призрачная Рысь", "Phantom Lynx", "epic", 45, "#B39DDB", "#C3A6FF", "fox", "angry", { big = true, tails = 1 }),
	def("e_golem", "Шестерёночный Голем", "Cog Golem", "epic", 32, "#A0522D", "#FFB347", "golem", "surprise", { cogs = true }),

	-- LEGENDARY «Титаны»: гигантские силуэты, много глаз, столб света
	def("l_titan", "Титан Вечности", "Titan of Eternity", "legendary", 150, "#3A6EA5", "#00E5FF", "titan", "angry", {}),
	def("l_eater", "Пожиратель Секунд", "Second Eater", "legendary", 200, "#6A1B9A", "#B47CFF", "eater", "sly", {}),
	def("l_colossus", "Колосс Полудня", "Noon Colossus", "legendary", 120, "#E0A100", "#FFE066", "colossus", "smile", {}),
	def("l_kraken", "Кракен Безвременья", "Timeless Kraken", "legendary", 170, "#00897B", "#5FFFC8", "eater", "surprise", { tentacles = true }),
	def("l_owlking", "Совиный Король", "Owl King", "legendary", 90, "#8D6E63", "#FFB347", "titan", "sleepy", { owl = true }),
	def("l_whale", "Небесный Кит", "Sky Whale", "legendary", 60, "#5C9EFF", "#9BE7FF", "colossus", "smile", { whale = true }),

	-- CHRONO «Хроно-Аномалии»: глитч, мерцание, эхо-двойники, перки
	def("x_rift", "Разлом Времени", "Time Rift", "chrono", 400, "#00E5FF", "#00E5FF", "rift", "angry", {}, "steel"),
	def("x_paradox", "Двойник Парадокса", "Paradox Twin", "chrono", 350, "#FF2E63", "#7B2FF7", "paradox", "sly", {}, "double"),
	def("x_zero", "Ноль", "Zero", "chrono", 500, "#FFFFFF", "#00E5FF", "zero", "surprise", {}, "silent"),
	def("x_echo", "Эхо Будущего", "Future Echo", "chrono", 300, "#39FF14", "#00E5FF", "rift", "smile", { ring = true }, "echo"),
	def("x_loop", "Петля", "The Loop", "chrono", 250, "#FFB347", "#FF2E63", "zero", "sleepy", { loop = true }, "step"),
	def("x_aegis", "Хроно-Эгида", "Chrono Aegis", "chrono", 200, "#7B2FF7", "#00E5FF", "paradox", "angry", { shield = true }, "shield"),
} :: { Def }

-- сезонные скины «Титана Вечности»
local SEASON_SKINS = {
	{ "Тыквенный Титан", "Pumpkin Titan", "#FF7A1A", "#FFB347", "pumpkin" },
	{ "Ледяной Титан", "Frost Titan", "#BFEFFF", "#9BE7FF", "ice" },
	{ "Песчаный Титан", "Sand Titan", "#E8C77A", "#FFE066", "sand" },
	{ "Цветущий Титан", "Blossom Titan", "#FFB3D9", "#FF8FC4", "sakura" },
	{ "Звёздный Титан", "Star Titan", "#3B2E7E", "#8C7BFF", "space" },
	{ "Коралловый Титан", "Coral Titan", "#2ED3C6", "#5FFFC8", "coral" },
}

M.SEASONAL = {} :: { Def }
for i, s in SEASON_SKINS do
	local d = def("s" .. i, s[1], s[2], "legendary", 150, s[3], s[4], "titan", "smile", { theme = s[5] })
	d.seasonal = true
	d.season = i
	table.insert(M.SEASONAL, d)
end

M.BY_ID = {} :: { [string]: Def }
for _, d in M.LIST do
	M.BY_ID[d.id] = d
end
for _, d in M.SEASONAL do
	M.BY_ID[d.id] = d
end

return M
