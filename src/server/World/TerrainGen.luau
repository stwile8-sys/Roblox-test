--!strict
-- Генерация ландшафта по Relief.height: куски 128×128 записываются через WriteVoxels.
-- Открытое море дальше от берега — одной заливкой FillBlock (дёшево).
-- Генерация уступает кадр, когда кусок работы занял больше ~30 мс.

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local Relief = require(Shared.Relief)

local M = {}

local RES = 4
local CHUNK = 32 -- колонок в куске по стороне (128 шпилек)
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
			local bottom = math.min(h, left[iz + 1], right[iz + 1], col[iz], col[iz + 2]) - 8
			for iy = 1, ny do
				local vy = y0 + (iy - 1) * RES
				if vy + RES < bottom then
					-- глубоко под землёй — пусто (снаружи не видно), экономим воксели
					continue
				end
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

function M.generate(progress: (number) -> ())
	local terrain = workspace.Terrain
	terrain:Clear()
	local W = Map.WORLD
	local span = CHUNK * RES
	local xs = math.ceil((W.x1 - W.x0) / span)
	local zs = math.ceil((SEA_Z - W.z0) / span)
	local total = xs * zs
	local done = 0
	local budget = os.clock()
	for cz = 0, zs - 1 do
		for cx = 0, xs - 1 do
			chunk(terrain, W.x0 + cx * span, W.z0 + cz * span)
			done += 1
			if os.clock() - budget > 0.03 then
				progress(done / total)
				task.wait()
				budget = os.clock()
			end
		end
	end
	-- открытое море: песчаное дно и вода
	local zEnd = W.z1
	local zStart = W.z0 + zs * span
	local width = W.x1 - W.x0
	local mid = Vector3.new((W.x0 + W.x1) / 2, 0, (zStart + zEnd) / 2)
	local depth = zEnd - zStart
	terrain:FillBlock(CFrame.new(mid.X, -30, mid.Z), Vector3.new(width, 8, depth), Enum.Material.Sand)
	local waterH = Map.WATER + 26
	terrain:FillBlock(CFrame.new(mid.X, Map.WATER - waterH / 2, mid.Z), Vector3.new(width, waterH, depth), WATER_MAT)
	progress(1)
end

-- Выровнять прямоугольник земли под постройку (верх земли на высоте level)
function M.flatten(center: Vector3, sizeX: number, sizeZ: number, level: number)
	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(center.X, level - 6, center.Z), Vector3.new(sizeX, 12, sizeZ), Enum.Material.Ground)
	terrain:FillBlock(CFrame.new(center.X, level + 30, center.Z), Vector3.new(sizeX, 60, sizeZ), AIR)
end

return M
