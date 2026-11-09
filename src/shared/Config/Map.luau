--!strict
-- Геометрия мира. Сетка 5×5 плиток по 1120: в центре хаб, по углам рынки, остальные 20 — участки
-- по 1000×1000 (125×125 клеток по 8). Между плитками — общие дороги на ровной земле.
-- Север — это −Z. Горы на севере, река течёт через западные участки, на юге море.

local M = {}

M.CELL = 8 -- клетка застройки
M.CELLS = 125 -- клеток на сторону участка
M.PLOT = M.CELL * M.CELLS -- 1000
M.TILE = 1120 -- шаг плиток (участок + коридор с дорогой)
M.ROAD_W = 48 -- ширина общей дороги
M.BASE = 20 -- уровень ровной земли (коридоры, хаб, края участков)
M.WATER = 14 -- уровень воды (река, озёра, море)
M.GRID_HALF = M.TILE * 2.5 -- 2800: край сетки плиток
M.WORLD = { x0 = -3800, x1 = 3800, z0 = -4400, z1 = 4600 } -- границы ландшафта

M.PLOT_PRICE = 800

export type PlotDef = {
	index: number,
	c: number,
	r: number,
	biome: string,
	extra: { string }, -- 1–2 ресурса второстепенного биома
}

local defs: { { any } } = {
	-- c, r, биом, второстепенные ресурсы
	{ 1, 0, "mountains", { "wood" } },
	{ 2, 0, "mountains", { "water", "clay" } },
	{ 3, 0, "desert", { "coal" } },
	{ 0, 1, "forest", { "grain" } },
	{ 1, 1, "forest", { "stone", "clay" } },
	{ 2, 1, "meadow", { "wood" } },
	{ 3, 1, "desert", { "wood", "water" } },
	{ 4, 1, "swamp", { "wood", "fish" } },
	{ 0, 2, "river", { "wood", "grain" } },
	{ 1, 2, "field", { "wood" } },
	{ 3, 2, "field", { "stone" } },
	{ 4, 2, "lake", { "grain", "wood" } },
	{ 0, 3, "river", { "grain", "stone" } },
	{ 1, 3, "meadow", { "stone", "wood" } },
	{ 2, 3, "field", { "fish" } },
	{ 3, 3, "forest", { "grain" } },
	{ 4, 3, "lake", { "wood" } },
	{ 1, 4, "coast", { "grain", "wood" } },
	{ 2, 4, "coast", { "stone" } },
	{ 3, 4, "swamp", { "grain" } },
}

M.plots = {} :: { PlotDef }
M.byTile = {} :: { [string]: PlotDef }
for i, d in defs do
	local p = { index = i, c = d[1], r = d[2], biome = d[3], extra = d[4] }
	M.plots[i] = p
	M.byTile[d[1] .. "," .. d[2]] = p
end

M.hub = { c = 2, r = 2 }
M.markets = { { c = 0, r = 0 }, { c = 4, r = 0 }, { c = 0, r = 4 }, { c = 4, r = 4 } }

function M.tileCenter(c: number, r: number): Vector3
	return Vector3.new((c - 2) * M.TILE, M.BASE, (r - 2) * M.TILE)
end

-- Угол участка с минимальными X и Z (на уровне BASE)
function M.plotOrigin(index: number): Vector3
	local p = M.plots[index]
	return M.tileCenter(p.c, p.r) - Vector3.new(M.PLOT / 2, 0, M.PLOT / 2)
end

-- Плитка под точкой (c, r) и смещение от её центра
function M.tileAt(x: number, z: number): (number, number, number, number)
	local c = math.floor(x / M.TILE + 2.5)
	local r = math.floor(z / M.TILE + 2.5)
	local cx, cz = (c - 2) * M.TILE, (r - 2) * M.TILE
	return c, r, x - cx, z - cz
end

function M.key(i: number, j: number): number
	return i + j * M.CELLS + 1
end

function M.unkey(k: number): (number, number)
	local z = k - 1
	return z % M.CELLS, z // M.CELLS
end

function M.inside(i: number, j: number): boolean
	return i >= 0 and j >= 0 and i < M.CELLS and j < M.CELLS
end

-- Центр клетки в мире (X, Z; высоту даёт модуль Relief)
function M.cellXZ(index: number, i: number, j: number): (number, number)
	local o = M.plotOrigin(index)
	return o.X + (i + 0.5) * M.CELL, o.Z + (j + 0.5) * M.CELL
end

-- Мировая точка → клетка участка (или nil)
function M.worldToCell(index: number, pos: Vector3): (number?, number?)
	local o = M.plotOrigin(index)
	local i = math.floor((pos.X - o.X) / M.CELL)
	local j = math.floor((pos.Z - o.Z) / M.CELL)
	if M.inside(i, j) then
		return i, j
	end
	return nil, nil
end

-- Какой участок под точкой
function M.plotAt(pos: Vector3): number?
	local c, r, dx, dz = M.tileAt(pos.X, pos.Z)
	local p = M.byTile[c .. "," .. r]
	if p and math.abs(dx) < M.PLOT / 2 and math.abs(dz) < M.PLOT / 2 then
		return p.index
	end
	return nil
end

-- Сторона участка, обращённая к хабу: "W", "E", "N", "S"
function M.hubSide(index: number): string
	local p = M.plots[index]
	local dx, dz = p.c - 2, p.r - 2
	if math.abs(dx) >= math.abs(dz) then
		return if dx > 0 then "W" else "E"
	end
	return if dz > 0 then "N" else "S"
end

-- Клетка въезда (на краю, обращённом к хабу, по середине стороны)
function M.entrance(index: number): (number, number)
	local side = M.hubSide(index)
	local mid = M.CELLS // 2
	if side == "W" then
		return 0, mid
	elseif side == "E" then
		return M.CELLS - 1, mid
	elseif side == "N" then
		return mid, 0
	end
	return mid, M.CELLS - 1
end

-- Готовая стартовая дорога: от въезда на 16 клеток внутрь участка
M.STARTER_LEN = 16
function M.starterRoad(index: number): { number }
	local side = M.hubSide(index)
	local ei, ej = M.entrance(index)
	local di, dj = 0, 0
	if side == "W" then
		di = 1
	elseif side == "E" then
		di = -1
	elseif side == "N" then
		dj = 1
	else
		dj = -1
	end
	local cells = {}
	for n = 0, M.STARTER_LEN - 1 do
		table.insert(cells, M.key(ei + di * n, ej + dj * n))
	end
	return cells
end

-- Все ресурсы участка: основной биом + второстепенные
function M.plotResources(index: number, biomes: { [string]: any }): { [string]: boolean }
	local p = M.plots[index]
	local set = {}
	for _, r in biomes[p.biome].resources do
		set[r] = true
	end
	for _, r in p.extra do
		set[r] = true
	end
	return set
end

return M
