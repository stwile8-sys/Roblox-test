--!strict
-- Геометрия карты. Сетка 5×5 плиток: в центре хаб, по углам рынки, остальные 20 — участки.
-- Север — это −Z. Горы на севере, река на западе, озеро на востоке, море на юге.

local M = {}

M.TILE = 200 -- шаг плиток (участок + дорога вокруг)
M.CELL = 8 -- клетка застройки
M.CELLS = 20 -- клеток на сторону участка
M.PLOT = M.CELL * M.CELLS -- 160
M.GROUND_Y = 0.2 -- верх земли участков
M.ROAD_Y = 0.3 -- верх общих дорог
M.EDGE = 500 -- край сетки плиток

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
for i, d in defs do
	M.plots[i] = { index = i, c = d[1], r = d[2], biome = d[3], extra = d[4] }
end

M.hub = { c = 2, r = 2 }
M.markets = { { c = 0, r = 0 }, { c = 4, r = 0 }, { c = 0, r = 4 }, { c = 4, r = 4 } }

function M.tileCenter(c: number, r: number): Vector3
	return Vector3.new((c - 2) * M.TILE, 0, (r - 2) * M.TILE)
end

-- Угол участка с минимальными X и Z
function M.plotOrigin(index: number): Vector3
	local p = M.plots[index]
	return M.tileCenter(p.c, p.r) - Vector3.new(M.PLOT / 2, 0, M.PLOT / 2)
end

function M.key(i: number, j: number): number
	return i + j * M.CELLS + 1 -- 1..400
end

function M.unkey(k: number): (number, number)
	local z = k - 1
	return z % M.CELLS, z // M.CELLS
end

function M.inside(i: number, j: number): boolean
	return i >= 0 and j >= 0 and i < M.CELLS and j < M.CELLS
end

-- Центр клетки в мире (на уровне земли)
function M.cellCenter(index: number, i: number, j: number): Vector3
	return M.plotOrigin(index) + Vector3.new((i + 0.5) * M.CELL, M.GROUND_Y, (j + 0.5) * M.CELL)
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
	for _, p in M.plots do
		local o = M.plotOrigin(p.index)
		if pos.X >= o.X and pos.X < o.X + M.PLOT and pos.Z >= o.Z and pos.Z < o.Z + M.PLOT then
			return p.index
		end
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

-- Готовая стартовая дорога: от края, обращённого к хабу, до середины участка
function M.starterRoad(index: number): { number }
	local side = M.hubSide(index)
	local cells = {}
	local mid = M.CELLS // 2
	for n = 0, mid do
		local i, j
		if side == "W" then
			i, j = n, mid
		elseif side == "E" then
			i, j = M.CELLS - 1 - n, mid
		elseif side == "N" then
			i, j = mid, n
		else
			i, j = mid, M.CELLS - 1 - n
		end
		table.insert(cells, M.key(i, j))
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
