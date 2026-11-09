-- Ралли-трасса вокруг центральной горы: замкнутый сплайн, профиль высот,
-- брод через реку, трамплины и быстрый поиск ближайшего участка.

local Track = {}
Track.__index = Track

Track.HALF_W = 9 -- полуширина дороги
Track.SHOULDER = 22 -- зона плавного перехода к рельефу

-- контрольные точки: угол от направления вида (градусы, против часовой) и радиус
local CONTROL = {
	{ -60, 310 }, -- старт
	{ -45, 285 },
	{ -30, 252 },
	{ -15, 233 },
	{ 0, 228 }, -- берег озера под смотровой
	{ 15, 233 },
	{ 30, 248 },
	{ 44, 270 },
	{ 57, 252 },
	{ 70, 232 },
	{ 85, 252 },
	{ 100, 335 }, -- брод через реку
	{ 112, 410 },
	{ 126, 432 },
	{ 140, 445 },
	{ 154, 430 },
	{ 168, 362 },
	{ 182, 300 },
	{ 196, 240 },
	{ 207, 188 }, -- серпантин вверх по склону
	{ 216, 165 },
	{ 224, 186 },
	{ 233, 240 },
	{ 248, 300 },
	{ 262, 340 },
	{ 276, 305 },
	{ 290, 330 },
}

local CELL = 32

local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

local function smoothCircular(arr: { number }, radius: number): { number }
	local n = #arr
	local out = table.create(n)
	local sum = 0
	for k = -radius, radius do
		sum += arr[k % n + 1]
	end
	local w = radius * 2 + 1
	for i = 1, n do
		out[i] = sum / w
		sum += arr[(i + radius) % n + 1] - arr[(i - radius - 1) % n + 1]
	end
	return out
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Track.build(viewDir: Vector3, naturalHeightAt: (number, number) -> number, water: number)
	local self = setmetatable({}, Track)
	local baseAngle = math.atan2(viewDir.Z, viewDir.X)

	local pts = {}
	for _, c in CONTROL do
		local a = baseAngle + math.rad(c[1])
		table.insert(pts, Vector3.new(math.cos(a) * c[2], 0, math.sin(a) * c[2]))
	end

	-- равномерная выборка сплайна (~4 шпильки)
	local flat = {}
	local n = #pts
	for i = 1, n do
		local p0, p1, p2, p3 = pts[(i - 2) % n + 1], pts[i], pts[i % n + 1], pts[(i + 1) % n + 1]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 4))
		for s = 0, steps - 1 do
			table.insert(flat, catmull(p0, p1, p2, p3, s / steps))
		end
	end
	local m = #flat

	-- профиль: сглаженный рельеф + брод + трамплины
	local nat = table.create(m)
	for i, p in flat do
		nat[i] = naturalHeightAt(p.X, p.Z)
	end
	local elev = smoothCircular(smoothCircular(nat, 15), 15)

	local wet = table.create(m)
	for i = 1, m do
		local any = 0
		for k = -6, 6 do
			if nat[(i + k - 1) % m + 1] < water + 2 then
				any = 1
				break
			end
		end
		wet[i] = any
	end
	wet = smoothCircular(wet, 25)
	for i = 1, m do
		local f = math.clamp(wet[i] * 2, 0, 1)
		elev[i] = lerp(elev[i], water - 1, f)
	end

	-- направления и кривизна
	local dirs = table.create(m)
	for i = 1, m do
		local d = flat[i % m + 1] - flat[i]
		dirs[i] = d.Unit
	end
	local function curvature(i: number): number
		local a = dirs[(i - 7) % m + 1]
		local b = dirs[(i + 5) % m + 1]
		return math.acos(math.clamp(a:Dot(b), -1, 1))
	end

	-- трамплины на самых прямых участках
	self.jumps = {}
	for _, range in { { 0.2, 0.42 }, { 0.58, 0.8 } } do
		local best, bestC = nil, math.huge
		for i = math.floor(range[1] * m), math.floor(range[2] * m) do
			local c = curvature(i) + math.abs(elev[i % m + 1] - elev[(i - 2) % m + 1]) * 0.05
			if wet[i] < 0.01 and c < bestC then
				best, bestC = i, c
			end
		end
		if best then
			table.insert(self.jumps, best)
			for k = -8, 2 do
				local idx = (best + k - 1) % m + 1
				local bump = k <= 0 and 5 * (k + 8) / 8 or 5 * (1 - k / 3)
				elev[idx] += bump
			end
		end
	end

	local points = table.create(m)
	local cum = table.create(m + 1)
	cum[1] = 0
	for i = 1, m do
		points[i] = Vector3.new(flat[i].X, elev[i], flat[i].Z)
	end
	for i = 1, m do
		cum[i + 1] = cum[i] + (flat[i % m + 1] - flat[i]).Magnitude
	end

	self.points = points
	self.dirs = dirs
	self.cum = cum
	self.length = cum[m + 1]
	self.count = m
	self.wet = wet

	-- сетка для быстрых запросов
	local grid = {}
	local R = Track.HALF_W + Track.SHOULDER + 2
	for i = 1, m do
		local a, b = flat[i], flat[i % m + 1]
		local x0 = math.floor((math.min(a.X, b.X) - R) / CELL)
		local x1 = math.floor((math.max(a.X, b.X) + R) / CELL)
		local z0 = math.floor((math.min(a.Z, b.Z) - R) / CELL)
		local z1 = math.floor((math.max(a.Z, b.Z) + R) / CELL)
		for cx = x0, x1 do
			for cz = z0, z1 do
				local key = cx * 65536 + cz
				local list = grid[key]
				if not list then
					list = {}
					grid[key] = list
				end
				table.insert(list, i)
			end
		end
	end
	self.grid = grid
	self.flat = flat

	-- стартовая площадка: чуть до линии старта, с внешней стороны трассы
	local sp = m - 12
	local p = points[sp]
	local dir = dirs[sp]
	local right = dir:Cross(Vector3.yAxis)
	local outward = right:Dot(Vector3.new(p.X, 0, p.Z)) > 0 and right or -right
	local padCenter = Vector3.new(p.X, p.Y, p.Z) + outward * (Track.HALF_W + 24)
	self.pad = {
		cf = CFrame.lookAt(padCenter, padCenter + dir),
		halfAcross = 22,
		halfAlong = 30,
		outward = outward,
		dir = dir,
		y = p.Y,
	}
	return self
end

-- Ближайший участок дороги в пределах полосы влияния.
-- Возвращает расстояние, высоту дороги и индекс точки (или nil).
function Track:query(x: number, z: number): (number?, number?, number?)
	local list = self.grid[math.floor(x / CELL) * 65536 + math.floor(z / CELL)]
	if not list then
		return nil
	end
	local flat, points, m = self.flat, self.points, self.count
	local bestD, bestElev, bestI = math.huge, 0, 0
	for _, i in list do
		local a, b = flat[i], flat[i % m + 1]
		local abx, abz = b.X - a.X, b.Z - a.Z
		local len2 = abx * abx + abz * abz
		local t = len2 > 0 and math.clamp(((x - a.X) * abx + (z - a.Z) * abz) / len2, 0, 1) or 0
		local px, pz = a.X + abx * t - x, a.Z + abz * t - z
		local d = px * px + pz * pz
		if d < bestD then
			bestD = d
			bestElev = lerp(points[i].Y, points[i % m + 1].Y, t)
			bestI = i
		end
	end
	return math.sqrt(bestD), bestElev, bestI
end

-- Ближайшая точка трассы без ограничения расстояния (для сброса машины).
function Track:nearestAnywhere(pos: Vector3): number
	local bestI, bestD = 1, math.huge
	for i, p in self.points do
		local d = (Vector3.new(p.X, 0, p.Z) - Vector3.new(pos.X, 0, pos.Z)).Magnitude
		if d < bestD then
			bestI, bestD = i, d
		end
	end
	return bestI
end

function Track:frameAt(i: number): CFrame
	local p = self.points[i]
	return CFrame.lookAt(p, p + self.dirs[i])
end

return Track
