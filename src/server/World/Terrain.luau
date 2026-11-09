-- Генерация ландшафта: гора с плато в центре, лесная долина, озеро с рекой
-- и кольцо снежных гор по краю карты.

local Terrain = {}

Terrain.H0 = 180 -- высота плато (кратна 4, чтобы поверхность была ровной)
Terrain.WATER = 28 -- уровень воды (кратен 4)
Terrain.PLATEAU_R = 62
Terrain.MOUNTAIN_R = 300
Terrain.HALF = 768 -- полуразмер карты (кратен 64)

local H0, WATER = Terrain.H0, Terrain.WATER
local PLATEAU_R, MOUNTAIN_R = Terrain.PLATEAU_R, Terrain.MOUNTAIN_R

local SEED = 7.31
local noise = math.noise

local viewDir = Vector3.new(0, 0, -1)
local sideDir = Vector3.new(1, 0, 0)
local lakeCenter = Vector3.zero
local lakeAngle = 0

function Terrain.setup(dir: Vector3)
	viewDir = dir
	sideDir = Vector3.new(-dir.Z, 0, dir.X)
	lakeCenter = dir * 345
	lakeAngle = math.atan2(dir.Z, dir.X)
end

local function smoothstep(a: number, b: number, x: number): number
	local t = math.clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end
Terrain.smoothstep = smoothstep

local function fbm(x: number, z: number, scale: number, octaves: number, seed: number): number
	local sum, amp, freq, norm = 0, 1, 1 / scale, 0
	for i = 1, octaves do
		sum += amp * noise(x * freq + seed + i * 17.13, z * freq - seed + i * 3.71)
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end
Terrain.fbm = fbm

local function ridged(x: number, z: number, scale: number, octaves: number, seed: number): number
	local sum, amp, freq, norm = 0, 1, 1 / scale, 0
	for i = 1, octaves do
		local n = math.clamp(1 - math.abs(noise(x * freq + seed + i * 11.7, z * freq + seed * 2 - i * 5.3)) * 1.8, 0, 1)
		sum += amp * n * n
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Terrain.naturalHeightAt(x: number, z: number): number
	local r = math.sqrt(x * x + z * z)

	-- холмистая долина
	local valley = 48 + fbm(x, z, 300, 4, SEED) * 56 + fbm(x, z, 70, 3, SEED + 5) * 8
	valley = math.max(valley, WATER + 4)
	local h = valley

	-- центральная гора: ровное плато, крутой обрыв со стороны вида
	if r < MOUNTAIN_R then
		local t = math.max(0, (r - PLATEAU_R) / (MOUNTAIN_R - PLATEAU_R))
		local facing = 0
		if r > 1 then
			facing = math.max(0, (x * viewDir.X + z * viewDir.Z) / r)
		end
		local p = (1 - t) ^ (2.2 + 2.3 * facing * facing)
		local rough = fbm(x, z, 45, 4, SEED + 9) * 34 * p * (1 - p) * 4
		h = valley + (H0 - valley) * p + rough
	end

	-- кольцо снежных гор
	local ring = smoothstep(400, 720, r)
	if ring > 0 then
		h += ring * (90 + ridged(x, z, 240, 5, SEED + 3) * 340)
	end

	-- озеро перед смотровой
	local rx, rz = x - lakeCenter.X, z - lakeCenter.Z
	local along = rx * viewDir.X + rz * viewDir.Z
	local side = rx * sideDir.X + rz * sideDir.Z
	local d = math.sqrt((along / 72) ^ 2 + (side / 125) ^ 2) + fbm(x, z, 60, 2, SEED + 13) * 0.25
	if d < 1.3 then
		local bed = WATER - 8 - math.max(0, 1 - d) * 7
		local f = smoothstep(1.3, 0.85, d)
		if bed < h then
			h = lerp(h, bed, f)
		end
	end

	-- река, огибающая гору от озера
	local theta = math.atan2(z, x)
	local dTheta = (theta - lakeAngle + math.pi) % (2 * math.pi) - math.pi
	if dTheta > 0.1 and dTheta < 2.7 then
		local rr = 348 + 30 * math.sin(dTheta * 3.1)
		local dist = math.abs(r - rr)
		local half = 6 + dTheta * 1.5
		local f = smoothstep(half + 18, half, dist) * smoothstep(2.7, 2.3, dTheta)
		local bed = WATER - 5
		if f > 0 and bed < h then
			h = lerp(h, bed, f)
		end
	end

	return h
end

-- ── дорога и стартовая площадка ──────────────────────────────

local road = nil
local ROAD_HALF, SHOULDER = 9, 22

function Terrain.setRoad(track)
	road = track
	ROAD_HALF, SHOULDER = track.HALF_W, track.SHOULDER
end

local function padDistance(x: number, z: number): number?
	if not road then
		return nil
	end
	local pad = road.pad
	local lp = pad.cf:PointToObjectSpace(Vector3.new(x, pad.y, z))
	local ex = math.max(math.abs(lp.X) - pad.halfAcross, 0)
	local ez = math.max(math.abs(lp.Z) - pad.halfAlong, 0)
	return math.sqrt(ex * ex + ez * ez)
end

-- расстояние до дороги или площадки (для леса), math.huge если далеко
function Terrain.clearance(x: number, z: number): number
	local best = math.huge
	if road then
		local d = road:query(x, z)
		if d then
			best = d - ROAD_HALF
		end
		local pd = padDistance(x, z)
		if pd and pd < best then
			best = pd
		end
	end
	return best
end

function Terrain.heightAt(x: number, z: number): number
	local h = Terrain.naturalHeightAt(x, z)
	if not road then
		return h
	end
	local d, elev = road:query(x, z)
	if d then
		if d < ROAD_HALF then
			h = elev
		elseif d < ROAD_HALF + SHOULDER then
			h = lerp(h, elev, smoothstep(ROAD_HALF + SHOULDER, ROAD_HALF, d))
		end
	end
	local pd = padDistance(x, z)
	if pd and pd < 14 then
		h = lerp(h, road.pad.y, smoothstep(14, 0, pd))
	end
	return h
end

local M = Enum.Material

function Terrain.surfaceMaterial(x: number, z: number, h: number, slope: number): Enum.Material
	if road then
		local pd = padDistance(x, z)
		if pd and pd < 1 then
			return M.Concrete
		end
		local d = road:query(x, z)
		if d and d < ROAD_HALF + 2 then
			if h < WATER + 0.5 then
				return M.Mud
			end
			return d < ROAD_HALF - 1.5 and M.Ground or M.Mud
		end
	end
	local snowLine = 285 + fbm(x, z, 120, 2, SEED + 21) * 50
	if h > snowLine and slope < 1.4 then
		return M.Snow
	end
	if slope > 1.1 then
		return fbm(x, z, 40, 2, SEED + 30) > 0.08 and M.Slate or M.Rock
	end
	if h < WATER + 1 then
		return M.Mud
	end
	if h < WATER + 3.5 then
		return M.Sand
	end
	if slope > 0.65 then
		return fbm(x, z, 25, 2, SEED + 33) > 0 and M.Ground or M.Rock
	end
	if h > snowLine - 45 then
		return M.Rock
	end
	if fbm(x, z, 60, 2, SEED + 40) > 0.1 then
		return M.LeafyGrass
	end
	return M.Grass
end

function Terrain.slopeAt(x: number, z: number): number
	local hx = Terrain.heightAt(x + 3, z) - Terrain.heightAt(x - 3, z)
	local hz = Terrain.heightAt(x, z + 3) - Terrain.heightAt(x, z - 3)
	return math.sqrt(hx * hx + hz * hz) / 6
end

function Terrain.applyLook()
	local t = workspace.Terrain
	t.WaterColor = Color3.fromRGB(38, 92, 104)
	t.WaterTransparency = 0.75
	t.WaterReflectance = 0.65
	t.WaterWaveSize = 0.12
	t.WaterWaveSpeed = 7
	t:SetMaterialColor(M.Grass, Color3.fromRGB(98, 122, 58))
	t:SetMaterialColor(M.LeafyGrass, Color3.fromRGB(82, 108, 50))
	t:SetMaterialColor(M.Rock, Color3.fromRGB(104, 100, 94))
	t:SetMaterialColor(M.Slate, Color3.fromRGB(88, 86, 84))
	t:SetMaterialColor(M.Snow, Color3.fromRGB(238, 244, 255))
	t:SetMaterialColor(M.Ground, Color3.fromRGB(112, 92, 70))
	t:SetMaterialColor(M.Sand, Color3.fromRGB(196, 178, 138))
	t:SetMaterialColor(M.Mud, Color3.fromRGB(78, 66, 52))
	t:SetMaterialColor(M.Concrete, Color3.fromRGB(150, 146, 140))
	pcall(function()
		t.Decoration = true -- колышущаяся трава
	end)
	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.52
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 242, 228)
	clouds.Parent = t
end

function Terrain.generate(onProgress: (number) -> ())
	local terrain = workspace.Terrain
	terrain:Clear()

	local HALF = Terrain.HALF
	local N = HALF * 2 / 4 -- колонок по стороне
	local heightAt = Terrain.heightAt
	local surfaceMaterial = Terrain.surfaceMaterial

	-- карта высот (с запасом в одну колонку для расчёта уклона)
	local heights = {}
	for ix = 0, N + 1 do
		local col = {}
		local x = -HALF + (ix - 0.5) * 4
		for iz = 0, N + 1 do
			col[iz] = heightAt(x, -HALF + (iz - 0.5) * 4)
		end
		heights[ix] = col
		if ix % 16 == 0 then
			onProgress(0.15 * ix / (N + 1))
			task.wait()
		end
	end

	-- чанки 16×16 колонок, от центра к краям
	local CH = 16
	local chunks = {}
	for cx = 0, N / CH - 1 do
		for cz = 0, N / CH - 1 do
			table.insert(chunks, { cx, cz })
		end
	end
	local mid = N / CH / 2 - 0.5
	table.sort(chunks, function(a, b)
		return (a[1] - mid) ^ 2 + (a[2] - mid) ^ 2 < (b[1] - mid) ^ 2 + (b[2] - mid) ^ 2
	end)

	local AIR, WATERM = M.Air, M.Water
	for index, chunk in chunks do
		local ix0, iz0 = chunk[1] * CH, chunk[2] * CH
		local minH, maxH = math.huge, -math.huge
		for i = 1, CH do
			local col = heights[ix0 + i]
			for k = 1, CH do
				local h = col[iz0 + k]
				if h < minH then
					minH = h
				end
				if h > maxH then
					maxH = h
				end
			end
		end
		local yMin = math.floor((minH - 12) / 4) * 4
		local yMax = math.ceil((math.max(maxH, WATER) + 4) / 4) * 4
		local ny = (yMax - yMin) / 4

		local mats, occs = table.create(CH), table.create(CH)
		for i = 1, CH do
			local gx = ix0 + i
			local x = -HALF + (gx - 0.5) * 4
			local mi, oi = table.create(ny), table.create(ny)
			for j = 1, ny do
				mi[j] = table.create(CH)
				oi[j] = table.create(CH)
			end
			for k = 1, CH do
				local gz = iz0 + k
				local z = -HALF + (gz - 0.5) * 4
				local h = heights[gx][gz]
				local sx = (heights[gx + 1][gz] - heights[gx - 1][gz]) / 8
				local sz = (heights[gx][gz + 1] - heights[gx][gz - 1]) / 8
				local slope = math.sqrt(sx * sx + sz * sz)
				local surf = surfaceMaterial(x, z, h, slope)
				local under = (slope > 1.1 or h > 240) and M.Rock or M.Ground
				for j = 1, ny do
					local yb = yMin + (j - 1) * 4
					local occ = math.clamp((h - yb) / 4, 0, 1)
					local mat
					if occ > 0 then
						mat = (h - yb <= 8) and surf or under
					elseif yb < WATER then
						mat = WATERM
						occ = 1
					else
						mat = AIR
					end
					mi[j][k] = mat
					oi[j][k] = occ
				end
			end
			mats[i] = mi
			occs[i] = oi
		end

		local region = Region3.new(
			Vector3.new(-HALF + ix0 * 4, yMin, -HALF + iz0 * 4),
			Vector3.new(-HALF + (ix0 + CH) * 4, yMax, -HALF + (iz0 + CH) * 4)
		)
		terrain:WriteVoxels(region, 4, mats, occs)

		if index % 3 == 0 then
			onProgress(0.15 + 0.7 * index / #chunks)
			task.wait()
		end
	end
end

return Terrain
