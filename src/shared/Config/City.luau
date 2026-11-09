--!strict
-- Правила города: стоимость застройки, особые здания, параметры зон и экономики жителей.

local M = {}

M.ROAD_COST = 10 -- за клетку
M.ROAD_REFUND = 0.5
M.ZONE_COST = { R = 4, C = 6, I = 6 } -- разметка за клетку
M.ZONE_REACH = 3 -- дом растёт, если до подключённой дороги не дальше 3 клеток

-- Дома, которые вырастают в зонах сами
-- size: 1 — дом 1×1, 2 — квартал 2×2
M.GROWN = {
	R = { [1] = { residents = 4 }, [2] = { residents = 14 } },
	C = { [1] = { jobs = 3 }, [2] = { jobs = 10 } },
	I = { [1] = { jobs = 4 }, [2] = { jobs = 14 } },
}

export type Special = {
	id: string,
	w: number,
	h: number,
	cost: number, -- первая постройка; каждая следующая такая же дороже
	costGrowth: number,
	needs: string, -- нужный ресурс участка
	output: string,
	period: number, -- секунд на 1 единицу продукции (в онлайне)
	color: Color3,
	order: number,
}

M.SPECIAL = {
	farm = {
		id = "farm",
		w = 3,
		h = 3,
		cost = 100,
		costGrowth = 2,
		needs = "grain",
		output = "grain",
		period = 6,
		color = Color3.fromRGB(220, 190, 80),
		order = 1,
	},
	lumber = {
		id = "lumber",
		w = 3,
		h = 3,
		cost = 100,
		costGrowth = 2,
		needs = "wood",
		output = "wood",
		period = 6,
		color = Color3.fromRGB(120, 85, 50),
		order = 2,
	},
	quarry = {
		id = "quarry",
		w = 3,
		h = 3,
		cost = 100,
		costGrowth = 2,
		needs = "stone",
		output = "stone",
		period = 8,
		color = Color3.fromRGB(150, 150, 150),
		order = 3,
	},
} :: { [string]: Special }

M.SPECIAL_ORDER = { "farm", "lumber", "quarry" }
M.MAX_SPECIAL = 6 -- на уровне «Деревня»

M.STORAGE = 500 -- вместимость склада на каждый предмет

-- Жители и экономика (за секунду, в онлайне)
M.TICK = 5
M.WORKER_SHARE = 0.6 -- доля жителей, которые работают
M.FOOD_PER_RESIDENT = 1 / 600 -- 1 единица сытости в 10 минут
M.TAX_PER_RESIDENT = 0.006 -- монет в секунду
M.IND_GOODS_PER_JOB = 0.01 -- товаров в секунду на рабочее место
M.IND_RAW_PER_GOODS = 0.5
M.COM_SALES_PER_JOB = 0.008 -- продаж товаров в секунду на рабочее место
M.COM_MARGIN = 1.0 -- выручка магазина = цена товара × коэффициент
M.ROAD_UPKEEP = 1 / 3600 -- монет в секунду за клетку дороги
M.LAND_TAX_WEEK = 0.02 -- налог на землю: 2% стоимости в неделю
M.OFFLINE_RATE = 0.2
M.OFFLINE_CAP = 24 * 3600

-- Стоимость участка для налога на землю
function M.cityValue(roads: number, specialSpent: number): number
	return 800 + roads * M.ROAD_COST + specialSpent
end

function M.specialCost(id: string, alreadyBuilt: number): number
	local s = M.SPECIAL[id]
	return math.floor(s.cost * s.costGrowth ^ alreadyBuilt)
end

return M
