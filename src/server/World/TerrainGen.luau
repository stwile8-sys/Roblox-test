--!strict
-- Генерация ландшафта по Relief.height: куски 64×64 записываются через WriteVoxels.
-- Сначала ближние к хабу куски (игроков пускаем, как только готов центр), дальние — в фоне.
-- Открытое море дальше от берега — одной заливкой FillBlock (дёшево).
-- Генерация уступает кадр, когда кусок работы занял больше ~25 мс.

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local Relief = require(Shared.Relief)

local M = {}

local RES = 4
local CHUNK = 16 -- колонок в куске по стороне (64 шпильки)
local SEA_Z = 3400 -- дальше этого — открытое море одной заливкой
local AIR = Enum.Material.Air
local WATER_MAT = Enum.Material.Water

local function chunk(terrain: Terrain, x0: number, z0: number)
	local n = CHUNK
	-- высоты с рамкой в 1 колонку (для крутизны)
	local hs = table.create(n + 2)
	local lo, hi = math.huge, -math.huge
	for ix = 0, n + 1 do
		local col = table.create(n + 2)
		local x = x0 + (ix - 1) * RES + RES / 2
		for iz = 0, n + 1 do
			local h = Relief.height(x, z0 + (iz - 1) * RES + RES / 2)
			col[iz + 1] = h
			if ix >= 1 and ix <= n and iz >= 1 and iz <= n then
				if h > hi then
					hi = h
				end
			end
			if h < lo then
				lo = h
			end
		end
		hs[ix + 1] = col
	end
	local y0 = math.floor((lo - 10) / RES) * RES
	local y1 = math.ceil((math.max(hi, Map.WATER) + 6) / RES) * RES
	local ny = (y1 - y0) // RES
	local mats = table.create(n)
	local occ = table.create(n)
	for ix = 1, n do
		local mx = table.create(ny)
		local ox = table.create(ny)
		for iy = 1, ny do
			mx[iy] = table.create(n, AIR)
			ox[iy] = table.create(n, 0)
		end
		mats[ix] = mx
		occ[ix] = ox
		local col, left, right = hs[ix + 1], hs[ix], hs[ix + 2]
		local x = x0 + (ix - 1) * RES + RES / 2
		for iz = 1, n do
			local h = col[iz + 1]
			local slope = math.max(
				math.abs(h - left[iz + 1]),
				math.abs(h - right[iz + 1]),
				math.abs(h - col[iz]),
				math.abs(h - col[iz + 2])
			) / RES
			local z = z0 + (iz - 1) * RES + RES / 2
			local mat = Relief.material(x, z, h, slope)
			-- заполняем только «корку» у поверхности: глубже снаружи не видно
			local bottom = math.min(h, left[iz + 1], right[iz + 1], col[iz], col[iz + 2]) - 8
			local top = math.max(h, Map.WATER) + RES
			local iyFrom = math.max(1, math.floor((bottom - y0) / RES) + 1)
			local iyTo = math.min(ny, math.ceil((top - y0) / RES) + 1)
			for iy = iyFrom, iyTo do
				local vy = y0 + (iy - 1) * RES
				local solid = math.clamp((h - vy) / RES, 0, 1)
				if solid >= 0.5 or (solid > 0 and vy >= Map.WATER) then
					mx[iy][iz] = mat
					ox[iy][iz] = solid
				elseif vy < Map.WATER then
					mx[iy][iz] = WATER_MAT
					ox[iy][iz] = math.clamp((Map.WATER - vy) / RES, 0, 1)
				end
			end
		end
	end
	local region = Region3.new(Vector3.new(x0, y0, z0), Vector3.new(x0 + n * RES, y1, z0 + n * RES))
	terrain:WriteVoxels(region, RES, mats, occ)
end

-- Список кусков, ближние к центру первыми
local function chunkList(): { { number } }
	local W = Map.WORLD
	local span = CHUNK * RES
	local list = {}
	local zEnd = W.z0 + math.ceil((SEA_Z - W.z0) / span) * span
	local x = W.x0
	while x < W.x1 do
		local z = W.z0
		while z < zEnd do
			local cx, cz = x + span / 2, z + span / 2
			table.insert(list, { x, z, cx * cx + cz * cz })
			z += span
		end
		x += span
	end
	table.sort(list, function(a, b)
		return a[3] < b[3]
	end)
	return list
end

local function sea(zStart: number)
	local W = Map.WORLD
	local terrain = workspace.Terrain
	local width = W.x1 - W.x0
	local depth = W.z1 - zStart
	local midX, midZ = (W.x0 + W.x1) / 2, (zStart + W.z1) / 2
	terrain:FillBlock(CFrame.new(midX, -30, midZ), Vector3.new(width, 8, depth), Enum.Material.Sand)
	local waterH = Map.WATER + 26
	terrain:FillBlock(CFrame.new(midX, Map.WATER - waterH / 2, midZ), Vector3.new(width, waterH, depth), WATER_MAT)
end

-- Сгенерировать ландшафт. coreRadius — после кусков в этом радиусе вызывается onCore
-- (можно пускать игроков); остальное догенерируется, затем onDone.
function M.generate(progress: (number) -> (), coreRadius: number, onCore: () -> (), onDone: () -> ())
	local terrain = workspace.Terrain
	terrain:Clear()
	local list = chunkList()
	local total = #list
	local coreCount = 0
	for _, c in list do
		if c[3] <= coreRadius * coreRadius then
			coreCount += 1
		end
	end
	local budget = os.clock()
	local coreFired = false
	for n, c in list do
		local ok, err = pcall(function()
			chunk(terrain, c[1], c[2])
		end)
		if not ok then
			warn("Ландшафт: ошибка куска", c[1], c[2], err)
		end
		if not coreFired and n >= coreCount then
			coreFired = true
			onCore()
		end
		if os.clock() - budget > 0.025 then
			progress(math.min(1, n / math.max(coreCount, 1)))
			task.wait()
			budget = os.clock()
		end
	end
	local W = Map.WORLD
	local span = CHUNK * RES
	sea(W.z0 + math.ceil((SEA_Z - W.z0) / span) * span)
	if not coreFired then
		onCore()
	end
	print("Ландшафт готов, кусков:", total)
	onDone()
end

-- Выровнять прямоугольник земли под постройку (верх земли на высоте level)
function M.flatten(center: Vector3, sizeX: number, sizeZ: number, level: number)
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(center.X, level - 6, center.Z), Vector3.new(sizeX, 12, sizeZ), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(center.X, level + 30, center.Z), Vector3.new(sizeX, 60, sizeZ), AIR)
end

return M
