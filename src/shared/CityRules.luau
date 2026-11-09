--!strict
-- Чистые правила застройки (без Roblox-объектов): общие для сервера (решает) и клиента
-- (подсвечивает, что можно построить). Сетка — массив из 400 символов:
--   "." пусто · "#" дорога · "R" жилая · "C" торговая · "I" промышленная зона

local Map = require(script.Parent.Config.Map)
local CityCfg = require(script.Parent.Config.City)

local N = Map.CELLS
local M = {}

export type CityData = {
	grid: string,
	grown: { { any } },
	special: { { any } },
	spent: number,
}

function M.toArray(s: string): { string }
	local t = table.create(N * N, ".")
	for k = 1, math.min(#s, N * N) do
		t[k] = string.sub(s, k, k)
	end
	return t
end

function M.toString(t: { string }): string
	return table.concat(t)
end

local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
M.DIRS = DIRS

-- Клетки, занятые домами и особыми зданиями: ключ → "G<номер>" / "S<номер>"
function M.occupancy(city: CityData): { [number]: string }
	local occ = {}
	for n, g in city.grown do
		local key, size = g[1], g[3]
		local i, j = Map.unkey(key)
		for di = 0, size - 1 do
			for dj = 0, size - 1 do
				occ[Map.key(i + di, j + dj)] = "G" .. n
			end
		end
	end
	for n, s in city.special do
		local def = CityCfg.SPECIAL[s[1]]
		if def then
			local i, j = Map.unkey(s[2])
			for di = 0, def.w - 1 do
				for dj = 0, def.h - 1 do
					if Map.inside(i + di, j + dj) then
						occ[Map.key(i + di, j + dj)] = "S" .. n
					end
				end
			end
		end
	end
	return occ
end

-- Дороги, связанные с краем участка (вокруг каждого участка проходит общая дорога)
function M.connected(grid: { string }): { [number]: boolean }
	local seen: { [number]: boolean } = {}
	local queue: { number } = {}
	for i = 0, N - 1 do
		for _, j in { 0, N - 1 } do
			for _, pair in { { i, j }, { j, i } } do
				local k = Map.key(pair[1], pair[2])
				if grid[k] == "#" and not seen[k] then
					seen[k] = true
					table.insert(queue, k)
				end
			end
		end
	end
	local head = 1
	while head <= #queue do
		local k = queue[head]
		head += 1
		local i, j = Map.unkey(k)
		for _, d in DIRS do
			local ni, nj = i + d[1], j + d[2]
			if Map.inside(ni, nj) then
				local nk = Map.key(ni, nj)
				if grid[nk] == "#" and not seen[nk] then
					seen[nk] = true
					table.insert(queue, nk)
				end
			end
		end
	end
	return seen
end

-- Расстояние (шагами по клеткам) до ближайшей дороги из набора sources, не дальше limit
function M.distance(sources: { [number]: boolean }, limit: number): { [number]: number }
	local dist: { [number]: number } = {}
	local queue: { number } = {}
	for k in sources do
		dist[k] = 0
		table.insert(queue, k)
	end
	local head = 1
	while head <= #queue do
		local k = queue[head]
		head += 1
		local dk = dist[k]
		if dk < limit then
			local i, j = Map.unkey(k)
			for _, d in DIRS do
				local ni, nj = i + d[1], j + d[2]
				if Map.inside(ni, nj) then
					local nk = Map.key(ni, nj)
					if dist[nk] == nil then
						dist[nk] = dk + 1
						table.insert(queue, nk)
					end
				end
			end
		end
	end
	return dist
end

function M.allRoads(grid: { string }): { [number]: boolean }
	local set = {}
	for k, c in grid do
		if c == "#" then
			set[k] = true
		end
	end
	return set
end

-- Касается ли прямоугольник дороги из набора roads (по стороне)
function M.touchesRoad(roads: { [number]: boolean }, i: number, j: number, w: number, h: number): boolean
	for di = -1, w do
		for dj = -1, h do
			local edge = (di == -1 or di == w) ~= (dj == -1 or dj == h)
			if edge and Map.inside(i + di, j + dj) and roads[Map.key(i + di, j + dj)] then
				return true
			end
		end
	end
	return false
end

-- Поворот здания «лицом» к ближайшей дороге (в радианах вокруг Y; 0 — лицом к −Z)
function M.facing(roads: { [number]: boolean }, i: number, j: number, w: number, h: number): number
	local best, bestYaw = -1, 0
	local sides = {
		{ yaw = 0, cells = function(n: number) return i + n, j - 1 end, len = w }, -- север (−Z)
		{ yaw = math.pi, cells = function(n: number) return i + n, j + h end, len = w }, -- юг
		{ yaw = math.pi / 2, cells = function(n: number) return i - 1, j + n end, len = h }, -- запад (−X)
		{ yaw = -math.pi / 2, cells = function(n: number) return i + w, j + n end, len = h }, -- восток
	}
	for _, s in sides do
		local count = 0
		for n = 0, s.len - 1 do
			local ci, cj = s.cells(n)
			if Map.inside(ci, cj) and roads[Map.key(ci, cj)] then
				count += 1
			end
		end
		if count > best then
			best, bestYaw = count, s.yaw
		end
	end
	return bestYaw
end

-- Можно ли поставить особое здание с левым верхним углом (i, j)
function M.canPlaceSpecial(grid: { string }, occ: { [number]: string }, roads: { [number]: boolean }, id: string, i: number, j: number): (boolean, string?)
	local def = CityCfg.SPECIAL[id]
	if not def then
		return false, "err.bad"
	end
	for di = 0, def.w - 1 do
		for dj = 0, def.h - 1 do
			local ci, cj = i + di, j + dj
			if not Map.inside(ci, cj) then
				return false, "build.out"
			end
			local k = Map.key(ci, cj)
			if grid[k] == "#" or occ[k] then
				return false, "build.occupied"
			end
		end
	end
	if not M.touchesRoad(roads, i, j, def.w, def.h) then
		return false, "build.need_road"
	end
	return true, nil
end

-- Можно ли размечать зону в клетке
function M.canZone(grid: { string }, occ: { [number]: string }, nearRoad: { [number]: number }, k: number): boolean
	local c = grid[k]
	if c == "#" or occ[k] then
		return false
	end
	local d = nearRoad[k]
	return d ~= nil and d <= CityCfg.ZONE_REACH
end

function M.canRoad(grid: { string }, occ: { [number]: string }, k: number): boolean
	return grid[k] ~= "#" and occ[k] == nil
end

return M
