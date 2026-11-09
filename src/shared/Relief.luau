--!strict
-- Рельеф мира: высота земли в любой точке. Детерминированная функция (одинакова на сервере
-- и клиенте), по ней сервер строит Terrain, а стройка узнаёт высоту и крутизну клетки.
-- Края участков, коридоры с дорогами, хаб и рынки — ровные (уровень BASE).

local Map = require(script.Parent.Config.Map)

local BASE, WATER = Map.BASE, Map.WATER
local HALF = Map.PLOT / 2
local GRID = Map.GRID_HALF

local M = {}

-- биом плитки по номеру (без строк — быстрее при генерации)
local TILE_BIOME: { [number]: string } = {}
for _, p in Map.plots do
	TILE_BIOME[p.c * 8 + p.r] = p.biome
end
local function tileBiome(c: number, r: number): string?
	if c < 0 or c > 4 or r < 0 or r > 4 then
		return nil
	end
	return TILE_BIOME[c * 8 + r]
end
M.tileBiome = tileBiome

local function smooth(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

local function fbm(x: number, z: number, scale: number, seed: number): number
	local v, amp, f = 0, 1, 1 / scale
	for _ = 1, 3 do
		v += math.noise(x * f, z * f, seed) * amp
		amp *= 0.5
		f *= 2.03
	end
	return v -- примерно −1..1
end

local function ridged(x: number, z: number, scale: number, seed: number): number
	local v, amp, f = 0, 0.6, 1 / scale
	for _ = 1, 3 do
		local n = 1 - math.abs(math.noise(x * f, z * f, seed))
		v += n * n * amp
		amp *= 0.5
		f *= 2.1
	end
	return v -- 0..~1
end

-- Русло реки: ломаная от западных холмов через речные участки к морю
local RIVER: { Vector2 } = {
	Vector2.new(-3800, -150),
	Vector2.new(-2700, -60),
	Vector2.new(-2330, 120),
	Vector2.new(-2180, 560),
	Vector2.new(-2290, 1050),
	Vector2.new(-2520, 1460),
	Vector2.new(-2900, 1720),
	Vector2.new(-3300, 2400),
	Vector2.new(-3320, 4600),
}

-- отрезки русла заранее в числах (функция вызывается миллионы раз при генерации)
local SEG: { { number } } = {}
for n = 1, #RIVER - 1 do
	local a, b = RIVER[n], RIVER[n + 1]
	local abx, abz = b.X - a.X, b.Y - a.Y
	table.insert(SEG, { a.X, a.Y, abx, abz, abx * abx + abz * abz })
end
local RIVER_MAX_X = -2050

local function riverDistance(x: number, z: number): number
	if x > RIVER_MAX_X then
		return math.huge
	end
	local best = math.huge
	for _, s in SEG do
		local px, pz = x - s[1], z - s[2]
		local t = math.clamp((px * s[3] + pz * s[4]) / s[5], 0, 1)
		local dx, dz = px - s[3] * t, pz - s[4] * t
		local d = dx * dx + dz * dz
		if d < best then
			best = d
		end
	end
	best = math.sqrt(best)
	if best > 120 then
		return best
	end
	-- лёгкое извилистое колебание ширины
	return best + math.noise(x / 90, z / 90, 7.7) * 6
end

-- Чаши озёр (центр, радиусы)
local LAKES = {
	{ x = 2240 + 90, z = -40, rx = 280, rz = 220 },
	{ x = 2240 - 60, z = 1120 + 60, rx = 240, rz = 300 },
	{ x = -320, z = 330, rx = 120, rz = 95 }, -- гавань хаба
}

local function lakeDepth(x: number, z: number): number?
	for _, l in LAKES do
		if math.abs(x - l.x) > l.rx * 1.3 or math.abs(z - l.z) > l.rz * 1.3 then
			continue
		end
		local dx, dz = (x - l.x) / l.rx, (z - l.z) / l.rz
		local d = math.sqrt(dx * dx + dz * dz)
		if d < 1.25 then
			return d
		end
	end
	return nil
end

-- Высота рельефа внутри участка (до маски краёв), по биому
local function biomeRelief(biome: string, x: number, z: number): number
	if biome == "forest" then
		return math.max(-3, (fbm(x, z, 260, 1.1) + 0.25) * 32)
	elseif biome == "meadow" then
		return math.max(-2, (fbm(x, z, 320, 2.2) + 0.2) * 16)
	elseif biome == "field" then
		return fbm(x, z, 420, 3.3) * 4
	elseif biome == "desert" then
		local n = 1 - math.abs(math.noise(x / 190, z / 85, 4.4))
		return n * n * 16 + fbm(x, z, 500, 4.5) * 6
	elseif biome == "mountains" then
		local r = ridged(x, z, 380, 5.5)
		return r ^ 1.6 * 190 + fbm(x, z, 200, 5.6) * 10
	elseif biome == "swamp" then
		local puddle = math.noise(x / 70, z / 70, 6.6)
		local h = fbm(x, z, 160, 6.7) * 3
		if puddle > 0.25 then
			h -= (puddle - 0.25) * 30
		end
		return math.max(h, -8)
	elseif biome == "coast" then
		return math.max(-2, fbm(x, z, 300, 8.8) * 7)
	end
	-- река и озеро: пологие холмы
	return math.max(-2, fbm(x, z, 300, 9.9) * 10)
end

-- Высота за пределами сетки плиток: горы на севере, холмы по бокам, пляж и море на юге
local function outside(x: number, z: number): number
	local dx = math.max(0, math.abs(x) - GRID - 40)
	local dzN = math.max(0, -z - GRID - 40)
	local dzS = math.max(0, z - GRID - 40)
	if dzS > 0 then
		-- пляж и спуск в море
		local beach = BASE - dzS * 0.06
		return math.max(beach, -26) + fbm(x, z, 150, 10.1) * 2
	end
	local h = BASE
	if dzN > 0 then
		local ramp = smooth(0, 700, dzN)
		h += ramp * (ridged(x, z, 420, 11.1) ^ 1.4 * 420 + 30) + smooth(0, 120, dzN) * 10
	end
	if dx > 0 then
		h += smooth(0, 400, dx) * (fbm(x, z, 300, 12.2) + 0.6) * 40
	end
	return h
end

local function raw(x: number, z: number): number
	local h: number
	if math.abs(x) > GRID + 40 or math.abs(z) > GRID + 40 then
		h = outside(x, z)
	else
		local c, r, dx, dz = Map.tileAt(x, z)
		local biome = tileBiome(c, r)
		h = BASE
		if biome then
			local edge = HALF - math.max(math.abs(dx), math.abs(dz))
			if edge > 0 then
				local width = if biome == "mountains" then 220 else 150
				h = BASE + biomeRelief(biome, x, z) * smooth(0, width, edge)
			end
		end
	end
	-- река
	local rd = riverDistance(x, z)
	if rd < 60 then
		local bed = WATER - 7
		h = math.min(h, bed + (h - bed) * smooth(16, 52, rd))
	end
	-- озёра
	local ld = lakeDepth(x, z)
	if ld then
		local bed = WATER - 9
		h = math.min(h, bed + (h - bed) * smooth(0.55, 1.2, ld))
	end
	return h
end

M.height = raw

function M.isRiver(x: number, z: number): boolean
	return riverDistance(x, z) < 26
end

-- Материал Terrain по высоте, крутизне и месту
function M.material(x: number, z: number, h: number, slope: number): Enum.Material
	if h < WATER + 1.2 then
		local c, r = Map.tileAt(x, z)
		if tileBiome(c, r) == "swamp" then
			return Enum.Material.Mud
		end
		return Enum.Material.Sand
	end
	if slope > 1.1 then
		return Enum.Material.Rock
	end
	if math.abs(x) > GRID + 40 or math.abs(z) > GRID + 40 then
		if z > GRID + 40 then
			return Enum.Material.Sand
		end
		if h > BASE + 260 then
			return Enum.Material.Snow
		elseif h > BASE + 90 or slope > 0.7 then
			return Enum.Material.Rock
		end
		return if math.noise(x / 200, z / 200, 3) > 0 then Enum.Material.LeafyGrass else Enum.Material.Grass
	end
	local c, r, dx, dz = Map.tileAt(x, z)
	local found = tileBiome(c, r)
	if not found or math.abs(dx) >= HALF or math.abs(dz) >= HALF then
		return Enum.Material.Ground
	end
	local biome = found :: string
	if slope > 0.75 then
		return Enum.Material.Slate
	end
	if biome == "mountains" then
		if h > BASE + 150 then
			return Enum.Material.Snow
		elseif h > BASE + 55 then
			return Enum.Material.Rock
		end
		return Enum.Material.Ground
	elseif biome == "desert" then
		return Enum.Material.Sand
	elseif biome == "forest" then
		return Enum.Material.LeafyGrass
	elseif biome == "swamp" then
		return if math.noise(x / 40, z / 40, 1) > 0.2 then Enum.Material.Mud else Enum.Material.Grass
	elseif biome == "coast" then
		return if math.noise(x / 120, z / 120, 2) > 0.3 then Enum.Material.Sand else Enum.Material.Grass
	elseif biome == "field" then
		return Enum.Material.Grass
	end
	return Enum.Material.Grass
end

-- Стройка ---------------------------------------------------------------

-- Уровень, на который выравнивается клетка под дорогу или дом
function M.cellLevel(index: number, i: number, j: number): number
	local x, z = Map.cellXZ(index, i, j)
	return math.floor(raw(x, z) * 2 + 0.5) / 2
end

-- Можно ли строить в клетке: не под водой и не слишком круто
function M.buildable(index: number, i: number, j: number): boolean
	local x, z = Map.cellXZ(index, i, j)
	local h = raw(x, z)
	if h < WATER + 1 then
		return false
	end
	local q = Map.CELL / 2
	for _, d in { { -q, -q }, { q, -q }, { -q, q }, { q, q } } do
		local hc = raw(x + d[1], z + d[2])
		if math.abs(hc - h) > 2.6 or hc < WATER + 0.5 then
			return false
		end
	end
	return true
end

return M
