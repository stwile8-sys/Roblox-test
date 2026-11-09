--!strict
-- Отрисовка города на участке: дороги, выросшие дома, особые здания. Состояние в модели
-- сравнивается с данными города и меняется только то, что изменилось.

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local CityCfg = require(Shared.Config.City)
local Rules = require(Shared.CityRules)
local B = require(script.Parent.Parent.World.Builders)

local M = {}

local ROAD = Color3.fromRGB(78, 80, 86)
local Y = Map.GROUND_Y
local C = Map.CELL

type View = {
	folder: Folder,
	roads: { [number]: BasePart },
	grown: { [string]: Model },
	special: { [string]: Model },
}

local views: { [number]: View } = {}

local function plotFolder(index: number): Folder?
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	local model = plots and plots:FindFirstChild("Plot_" .. index)
	local f = model and model:FindFirstChild("City")
	return if f and f:IsA("Folder") then f else nil
end

local function view(index: number): View?
	local v = views[index]
	if v and v.folder.Parent then
		return v
	end
	local folder = plotFolder(index)
	if not folder then
		return nil
	end
	folder:ClearAllChildren()
	local nv: View = { folder = folder, roads = {}, grown = {}, special = {} }
	views[index] = nv
	return nv
end

-- Детерминированный «случай» по ключу клетки, чтобы дом не менял вид при перерисовке
local function hashRng(index: number, key: number): Random
	return Random.new(index * 1000 + key * 7919)
end

local PASTEL = {
	Color3.fromRGB(240, 228, 200),
	Color3.fromRGB(225, 205, 180),
	Color3.fromRGB(200, 220, 230),
	Color3.fromRGB(235, 210, 210),
	Color3.fromRGB(215, 230, 200),
}
local ROOFS = {
	Color3.fromRGB(180, 80, 65),
	Color3.fromRGB(90, 110, 150),
	Color3.fromRGB(120, 90, 70),
	Color3.fromRGB(80, 120, 90),
}

-- Центр прямоугольника клеток и поворот к дороге
local function anchor(index: number, i: number, j: number, w: number, h: number, yaw: number): CFrame
	local o = Map.plotOrigin(index)
	local center = o + Vector3.new((i + w / 2) * C, Y, (j + h / 2) * C)
	return CFrame.new(center) * CFrame.Angles(0, yaw, 0)
end

local function windows(parent: Instance, cf: CFrame, w: number, h: number, d: number, floors: number)
	local glass = Color3.fromRGB(150, 190, 220)
	for f = 0, floors - 1 do
		local y = 2.2 + f * 3.2
		if y + 1 < h then
			B.part(parent, Vector3.new(w * 0.75, 1.3, 0.2), cf * CFrame.new(0, y, -d / 2 - 0.05), glass, Enum.Material.Glass)
		end
	end
end

local function buildGrown(parent: Instance, index: number, key: number, zone: string, size: number, yaw: number): Model
	local m = Instance.new("Model")
	m.Name = zone .. size .. "_" .. key
	local i, j = Map.unkey(key)
	local rng = hashRng(index, key)
	local cf = anchor(index, i, j, size, size, yaw)
	local span = size * C - 1.6 -- отступ от соседей
	if zone == "R" then
		local wall = PASTEL[rng:NextInteger(1, #PASTEL)]
		local roof = ROOFS[rng:NextInteger(1, #ROOFS)]
		if size == 1 then
			local w, d, h = span * 0.8, span * 0.7, 4.2
			B.part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0.4), wall)
			B.ridge(m, (cf * CFrame.new(0, h, 0.4)).Position, w + 0.8, d + 0.8, 2.6, roof, yaw)
			B.part(m, Vector3.new(1.2, 2.4, 0.2), cf * CFrame.new(0, 1.2, 0.4 - d / 2 - 0.05), Color3.fromRGB(100, 70, 50))
			B.part(m, Vector3.new(1.2, 1.1, 0.2), cf * CFrame.new(w * 0.28, 2.4, 0.4 - d / 2 - 0.05), Color3.fromRGB(150, 190, 220), Enum.Material.Glass)
		else
			local floors = rng:NextInteger(3, 5)
			local h = floors * 3.2 + 1
			local w, d = span * 0.85, span * 0.75
			B.part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0.6), wall)
			B.part(m, Vector3.new(w + 0.6, 0.6, d + 0.6), cf * CFrame.new(0, h + 0.3, 0.6), roof)
			windows(m, cf * CFrame.new(0, 0, 0.6), w, h, d, floors)
		end
	elseif zone == "C" then
		local wall = Color3.fromRGB(235, 235, 240)
		local accent = ({ Color3.fromRGB(220, 80, 70), Color3.fromRGB(60, 140, 200), Color3.fromRGB(240, 170, 50), Color3.fromRGB(80, 170, 100) })[rng:NextInteger(1, 4)]
		local h = if size == 1 then 4.5 else 8
		local w, d = span * 0.85, span * 0.8
		B.part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0.5), wall)
		B.part(m, Vector3.new(w * 0.8, h * 0.45, 0.2), cf * CFrame.new(0, h * 0.3, 0.5 - d / 2 - 0.05), Color3.fromRGB(170, 210, 235), Enum.Material.Glass)
		B.wedge(m, Vector3.new(w, 0.8, 1.6), cf * CFrame.new(0, h * 0.62, 0.5 - d / 2 - 0.8) * CFrame.Angles(0, math.pi, 0), accent)
		B.part(m, Vector3.new(w * 0.6, 1.2, 0.3), cf * CFrame.new(0, h - 0.2, 0.5 - d / 2 - 0.2), accent, Enum.Material.Neon)
	else -- I
		local wall = Color3.fromRGB(175, 165, 150)
		local h = if size == 1 then 5 else 7
		local w, d = span * 0.9, span * 0.8
		B.part(m, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0.5), wall, Enum.Material.Concrete)
		if size == 2 then
			for n = -1, 1 do
				B.wedge(m, Vector3.new(w / 3, 2.4, d), cf * CFrame.new(n * w / 3, h + 1.2, 0.5), Color3.fromRGB(120, 120, 125))
			end
		else
			B.part(m, Vector3.new(w + 0.4, 0.5, d + 0.4), cf * CFrame.new(0, h + 0.25, 0.5), Color3.fromRGB(110, 110, 115))
		end
		B.post(m, (cf * CFrame.new(w * 0.3, h, 0.5 + d * 0.2)).Position, 4 + size * 2, 1.2, Color3.fromRGB(150, 70, 55), Enum.Material.Brick)
		B.part(m, Vector3.new(2.4, 3, 0.2), cf * CFrame.new(-w * 0.2, 1.5, 0.5 - d / 2 - 0.05), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	m.Parent = parent
	return m
end

local function buildSpecial(parent: Instance, index: number, id: string, key: number, yaw: number): Model
	local def = CityCfg.SPECIAL[id]
	local m = Instance.new("Model")
	m.Name = id .. "_" .. key
	local i, j = Map.unkey(key)
	local cf = anchor(index, i, j, def.w, def.h, yaw)
	local span = def.w * C - 1
	local rng = hashRng(index, key)
	if id == "farm" then
		B.part(m, Vector3.new(span, 0.3, span), cf * CFrame.new(0, 0.15, 0), Color3.fromRGB(120, 85, 55), Enum.Material.Ground)
		for n = 0, 5 do
			B.part(m, Vector3.new(span * 0.6, 1.4, 1.6), cf * CFrame.new(span * 0.15, 0.9, -span / 2 + 2.5 + n * 3.6), Color3.fromRGB(225, 195, 80))
		end
		-- амбар
		local bcf = cf * CFrame.new(-span * 0.32, 0, -span * 0.1)
		B.part(m, Vector3.new(6, 5, 8), bcf * CFrame.new(0, 2.5, 0), Color3.fromRGB(170, 60, 50))
		B.ridge(m, (bcf * CFrame.new(0, 5, 0)).Position, 8.6, 6.8, 3, Color3.fromRGB(90, 70, 60), yaw + math.pi / 2)
		B.part(m, Vector3.new(0.2, 3.4, 2.6), bcf * CFrame.new(3.05, 1.7, 0), Color3.fromRGB(240, 235, 220))
	elseif id == "lumber" then
		B.part(m, Vector3.new(span, 0.3, span), cf * CFrame.new(0, 0.15, 0), Color3.fromRGB(140, 115, 80), Enum.Material.Ground)
		local scf = cf * CFrame.new(-span * 0.2, 0, -span * 0.15)
		B.part(m, Vector3.new(10, 5, 7), scf * CFrame.new(0, 2.5, 0), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
		B.wedge(m, Vector3.new(11, 2, 8), scf * CFrame.new(0, 6, 0), Color3.fromRGB(100, 75, 55))
		for n = 0, 5 do
			local row = n // 3
			B.cylinder(m, 9, 1.6, cf * CFrame.new(span * 0.2, 0.8 + row * 1.5, span * 0.18 + (n % 3) * 1.7 - row * 0.85), Color3.fromRGB(130, 90, 55))
		end
		for _ = 1, 3 do
			B.pine(m, (cf * CFrame.new(rng:NextNumber(-span / 2 + 2, span / 2 - 2), 0, span * 0.38)).Position, 0.9, rng)
		end
	else -- quarry
		B.part(m, Vector3.new(span, 0.3, span), cf * CFrame.new(0, 0.15, 0), Color3.fromRGB(150, 145, 135), Enum.Material.Slate)
		B.part(m, Vector3.new(span * 0.55, 0.4, span * 0.55), cf * CFrame.new(span * 0.12, 0.2, span * 0.1), Color3.fromRGB(105, 100, 95), Enum.Material.Slate)
		for _ = 1, 6 do
			B.rock(m, (cf * CFrame.new(rng:NextNumber(-span / 2 + 2, span / 2 - 2), 0.3, rng:NextNumber(-span / 2 + 2, span / 2 - 2))).Position, rng:NextNumber(1.5, 3.5), rng)
		end
		-- кран
		local kcf = cf * CFrame.new(-span * 0.3, 0, -span * 0.3)
		B.part(m, Vector3.new(1.2, 12, 1.2), kcf * CFrame.new(0, 6, 0), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
		B.part(m, Vector3.new(1, 1, 12), kcf * CFrame.new(0, 12, 4), Color3.fromRGB(230, 180, 40), Enum.Material.Metal)
		B.part(m, Vector3.new(4, 3, 4), kcf * CFrame.new(span * 0.45, 1.5, 0), Color3.fromRGB(90, 90, 95), Enum.Material.Metal)
	end
	m.Parent = parent
	return m
end

function M.sync(index: number, city: Rules.CityData)
	local v = view(index)
	if not v then
		return
	end
	local grid = Rules.toArray(city.grid)
	local roads = Rules.allRoads(grid)
	-- дороги
	for k, part in v.roads do
		if not roads[k] then
			part:Destroy()
			v.roads[k] = nil
		end
	end
	local o = Map.plotOrigin(index)
	for k in roads do
		if not v.roads[k] then
			local i, j = Map.unkey(k)
			local p = B.part(v.folder, Vector3.new(C, 0.2, C), CFrame.new(o + Vector3.new((i + 0.5) * C, Y + 0.1, (j + 0.5) * C)), ROAD, Enum.Material.Asphalt)
			p.CastShadow = false
			p.Name = "Road"
			v.roads[k] = p
		end
	end
	-- дома
	local wanted: { [string]: { any } } = {}
	for _, g in city.grown do
		wanted[g[2] .. g[3] .. "_" .. g[1]] = g
	end
	for name, model in v.grown do
		if not wanted[name] then
			model:Destroy()
			v.grown[name] = nil
		end
	end
	for name, g in wanted do
		if not v.grown[name] then
			local i, j = Map.unkey(g[1])
			local yaw = Rules.facing(roads, i, j, g[3], g[3])
			v.grown[name] = buildGrown(v.folder, index, g[1], g[2], g[3], yaw)
		end
	end
	-- особые здания
	local wantedS: { [string]: { any } } = {}
	for _, s in city.special do
		wantedS[s[1] .. "_" .. s[2]] = s
	end
	for name, model in v.special do
		if not wantedS[name] then
			model:Destroy()
			v.special[name] = nil
		end
	end
	for name, s in wantedS do
		if not v.special[name] then
			local def = CityCfg.SPECIAL[s[1]]
			if def then
				local i, j = Map.unkey(s[2])
				local yaw = Rules.facing(roads, i, j, def.w, def.h)
				v.special[name] = buildSpecial(v.folder, index, s[1], s[2], yaw)
			end
		end
	end
end

function M.clear(index: number)
	local v = views[index]
	if v then
		v.folder:ClearAllChildren()
		views[index] = nil
	end
end

function M.clearDecor(index: number)
	local plots = workspace:FindFirstChild("World") and workspace.World:FindFirstChild("Plots")
	local model = plots and plots:FindFirstChild("Plot_" .. index)
	local decor = model and model:FindFirstChild("Decor")
	if decor then
		decor:ClearAllChildren()
	end
end

return M
