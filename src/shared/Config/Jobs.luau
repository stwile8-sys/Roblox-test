--!strict
-- NPC-работы в хабе (ТЗ 3.1.1). Где груз надо возить — работодатель выдаёт служебный транспорт:
-- погрузчик для ящиков, фургон для посылок. После работы он исчезает.
--   haul    — на транспорте: заехать в зону погрузки, затем в зону разгрузки (count раз)
--   route   — пройти/проехать точки по порядку
--   prompts — пешком: нажать на все объекты (E)

export type Job = {
	id: string,
	pay: number,
	time: number, -- примерное время для игрока, секунд (показывается на доске)
	minTime: number, -- быстрее этого физически не успеть — значит, читы
	kind: string,
	count: number,
	vehicle: string?, -- служебный транспорт
	spawn: string?, -- тег точки, где появляется транспорт
	pickup: string?, -- тег зоны погрузки
	drop: string?, -- тег зоны разгрузки
	target: string?, -- тег точек (prompts / route)
	order: number,
}

local Jobs: { [string]: Job } = {
	cart = { id = "cart", pay = 20, time = 30, minTime = 3, kind = "haul", count = 1, vehicle = "forklift", spawn = "SpawnYard", pickup = "ZoneCratePile", drop = "ZoneCart", order = 1 },
	sweep = { id = "sweep", pay = 30, time = 60, minTime = 6, kind = "route", count = 8, target = "JobSweepPoint", order = 2 },
	truck = { id = "truck", pay = 40, time = 60, minTime = 8, kind = "haul", count = 5, vehicle = "forklift", spawn = "SpawnYard", pickup = "ZoneTruck", drop = "ZoneWarehouse", order = 3 },
	fence = { id = "fence", pay = 70, time = 120, minTime = 11, kind = "prompts", count = 5, target = "JobFenceGap", order = 4 },
	harvest = { id = "harvest", pay = 80, time = 120, minTime = 10, kind = "prompts", count = 10, target = "JobPlant", order = 5 },
	parcel = { id = "parcel", pay = 100, time = 180, minTime = 45, kind = "route", count = 3, vehicle = "van", spawn = "SpawnPost", target = "JobParcelPoint", order = 6 },
	ship = { id = "ship", pay = 120, time = 180, minTime = 18, kind = "haul", count = 10, vehicle = "forklift", spawn = "SpawnPort", pickup = "ZoneShip", drop = "ZoneDockStore", order = 7 },
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
M.ROUTE_RADIUS = 12 -- пешком
M.VEHICLE_RADIUS = 20 -- на транспорте
M.ZONE_RADIUS = 14 -- зона погрузки/разгрузки
M.ZONE_MAX_SPEED = 8 -- остановиться (почти) для погрузки
M.ZONE_DWELL = 0.6
return M
