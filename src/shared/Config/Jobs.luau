--!strict
-- NPC-работы в хабе (ТЗ 3.1.1). Шаги выполняются физически: подобрать ящик,
-- отнести, пройти точки маршрута. Сервер проверяет каждый шаг.

export type Job = {
	id: string,
	pay: number,
	time: number, -- примерное время для игрока, секунд (показывается на доске)
	minTime: number, -- быстрее этого физически не успеть — значит, читы
	kind: string, -- carry | route | prompts
	count: number, -- сколько раз повторить
	pickup: string?, -- тег места, где брать груз
	drop: string?, -- тег места, куда нести
	target: string?, -- тег точек (для prompts) или маршрута (route)
	order: number,
}

local Jobs: { [string]: Job } = {
	cart = { id = "cart", pay = 20, time = 30, minTime = 2, kind = "carry", count = 1, pickup = "JobCratePile", drop = "JobCart", order = 1 },
	sweep = { id = "sweep", pay = 30, time = 60, minTime = 6, kind = "route", count = 8, target = "JobSweepPoint", order = 2 },
	truck = { id = "truck", pay = 40, time = 60, minTime = 8, kind = "carry", count = 5, pickup = "JobTruck", drop = "JobWarehouse", order = 3 },
	fence = { id = "fence", pay = 70, time = 120, minTime = 11, kind = "prompts", count = 5, target = "JobFenceGap", order = 4 },
	harvest = { id = "harvest", pay = 80, time = 120, minTime = 10, kind = "prompts", count = 10, target = "JobPlant", order = 5 },
	parcel = { id = "parcel", pay = 100, time = 180, minTime = 40, kind = "route", count = 3, target = "JobParcelPoint", order = 6 },
	ship = { id = "ship", pay = 120, time = 180, minTime = 18, kind = "carry", count = 10, pickup = "JobShip", drop = "JobDockStore", order = 7 },
}

local list: { Job } = {}
for _, j in Jobs do
	table.insert(list, j)
end
table.sort(list, function(a, b)
	return a.order < b.order
end)

local M = {}
M.byId = Jobs
M.list = list
M.COOLDOWN = 30
M.ROUTE_RADIUS = 10
return M
