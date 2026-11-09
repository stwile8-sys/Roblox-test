--!strict
-- Мир: свет, ландшафт (TerrainGen), общие дороги с мостами, участки (бордюры, табличка у въезда,
-- украшения по биому, пока участок свободен), лес по краям карты.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local Relief = require(Shared.Relief)
local B = require(script.Parent.Builders)

local M = {}

local ASPHALT = Color3.fromRGB(70, 72, 78)
local LINE = Color3.fromRGB(230, 225, 200)
local BASE = Map.BASE

local function sky()
	Lighting.ClockTime = 14.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(95, 100, 110)
	Lighting.OutdoorAmbient = Color3.fromRGB(135, 140, 150)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.GeographicLatitude = 35

	local atmo = Instance.new("Atmosphere")
	atmo.Density = 0.3
	atmo.Offset = 0.15
	atmo.Color = Color3.fromRGB(200, 215, 235)
	atmo.Decay = Color3.fromRGB(120, 140, 170)
	atmo.Glare = 0.2
	atmo.Haze = 1.2
	atmo.Parent = Lighting

	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "Grade"
	cc.Contrast = 0.08
	cc.Saturation = 0.12
	cc.TintColor = Color3.fromRGB(255, 250, 240)
	cc.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Name = "Bloom"
	bloom.Intensity = 0.25
	bloom.Size = 20
	bloom.Threshold = 0.9
	bloom.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Name = "Rays"
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.45
	clouds.Density = 0.6
	clouds.Parent = workspace.Terrain

	workspace.Terrain.WaterColor = Color3.fromRGB(40, 110, 150)
	workspace.Terrain.WaterTransparency = 0.6
end

local function ground(x: number, z: number): Vector3
	return Vector3.new(x, Relief.height(x, z), z)
end

-- Украшения свободного участка (убираются при покупке)
local function decorate(folder: Instance, index: number, rng: Random)
	local p = Map.plots[index]
	local o = Map.plotOrigin(index)
	local function spot(margin: number): Vector3?
		for _ = 1, 4 do
			local x = o.X + rng:NextNumber(margin, Map.PLOT - margin)
			local z = o.Z + rng:NextNumber(margin, Map.PLOT - margin)
			local h = Relief.height(x, z)
			if h > Map.WATER + 1.5 then
				return Vector3.new(x, h - 0.3, z)
			end
		end
		return nil
	end
	local biome = p.biome
	local function trees(n: number, pineShare: number, scale: number, tint: Color3?)
		for _ = 1, n do
			local s = spot(20)
			if s then
				if rng:NextNumber() < pineShare then
					B.pine(folder, s, rng:NextNumber(1.1, 1.8) * scale, rng, tint)
				else
					B.leafy(folder, s, rng:NextNumber(1, 1.6) * scale, rng, tint)
				end
			end
		end
	end
	if biome == "forest" then
		trees(170, 0.6, 1)
	elseif biome == "field" then
		for n = 0, 9 do
			local z = o.Z + 150 + n * 70
			for k = 0, 2 do
				local x = o.X + 180 + k * 240
				B.part(folder, Vector3.new(200, 1.4, 22), CFrame.new(ground(x, z) + Vector3.new(0, 0.5, 0)), Color3.fromRGB(225, 195, 85))
			end
		end
		trees(14, 0.1, 1)
	elseif biome == "meadow" then
		trees(40, 0.2, 1)
		for _ = 1, 120 do
			local s = spot(10)
			if s then
				local c = ({ Color3.fromRGB(240, 90, 90), Color3.fromRGB(250, 220, 90), Color3.fromRGB(230, 230, 250) })[rng:NextInteger(1, 3)]
				B.part(folder, Vector3.new(1, 1, 1), CFrame.new(s + Vector3.new(0, 0.6, 0)), c)
			end
		end
	elseif biome == "desert" then
		for _ = 1, 50 do
			local s = spot(10)
			if s then
				B.rock(folder, s, rng:NextNumber(2, 8), rng, Color3.fromRGB(180, 140, 100))
			end
		end
		for _ = 1, 25 do
			local s = spot(10)
			if s then
				B.part(folder, Vector3.new(1.4, rng:NextNumber(5, 9), 1.4), CFrame.new(s + Vector3.new(0, 3, 0)), Color3.fromRGB(90, 140, 70))
			end
		end
	elseif biome == "mountains" then
		trees(40, 1, 1)
		for _ = 1, 60 do
			local s = spot(10)
			if s then
				B.rock(folder, s, rng:NextNumber(3, 10), rng)
			end
		end
	elseif biome == "swamp" then
		trees(60, 0.8, 0.8, Color3.fromRGB(75, 95, 60))
		for _ = 1, 80 do
			local s = spot(5)
			if s then
				B.part(folder, Vector3.new(0.4, rng:NextNumber(2, 4), 0.4), CFrame.new(s + Vector3.new(0, 1.5, 0)), Color3.fromRGB(110, 130, 70))
			end
		end
	else -- река, озеро, побережье
		trees(50, 0.3, 1)
		for _ = 1, 60 do
			local s = spot(5)
			if s then
				B.part(folder, Vector3.new(0.4, rng:NextNumber(2, 4), 0.4), CFrame.new(s + Vector3.new(0, 1.5, 0)), Color3.fromRGB(120, 150, 70))
			end
		end
	end
end

M.decorate = decorate

-- Дорога по прямой (по оси X или Z), разбитая на куски не длиннее 1100; мосты над рекой
local function roadLine(parent: Instance, alongX: boolean, offset: number, from: number, to: number)
	local len = to - from
	local pieces = math.ceil(len / 1100)
	local step = len / pieces
	for n = 0, pieces - 1 do
		local a = from + n * step
		local mid = a + step / 2
		local cf = if alongX then CFrame.new(mid, BASE - 0.2, offset) else CFrame.new(offset, BASE - 0.2, mid)
		local size = if alongX then Vector3.new(step, 1, Map.ROAD_W) else Vector3.new(Map.ROAD_W, 1, step)
		B.part(parent, size, cf, ASPHALT, Enum.Material.Asphalt).CastShadow = false
		local lineSize = if alongX then Vector3.new(step, 0.1, 0.8) else Vector3.new(0.8, 0.1, step)
		B.part(parent, lineSize, cf + Vector3.new(0, 0.55, 0), LINE).CastShadow = false
	end
	-- мост: где под дорогой русло реки — перила и опоры
	local inBridge, startT = false, 0
	local t = from
	while t <= to + 8 do
		local x = if alongX then t else offset
		local z = if alongX then offset else t
		local river = t <= to and Relief.height(x, z) < BASE - 2
		if river and not inBridge then
			inBridge, startT = true, t
		elseif not river and inBridge then
			inBridge = false
			local mid = (startT + t) / 2
			local length = t - startT + 8
			for _, side in { -1, 1 } do
				local sx = side * (Map.ROAD_W / 2 + 0.5)
				local cf = if alongX then CFrame.new(mid, BASE + 1.6, offset + sx) else CFrame.new(offset + sx, BASE + 1.6, mid)
				local size = if alongX then Vector3.new(length, 0.6, 0.6) else Vector3.new(0.6, 0.6, length)
				B.part(parent, size, cf, Color3.fromRGB(200, 195, 185), Enum.Material.Concrete)
			end
			local pcf = if alongX then CFrame.new(mid, BASE - 8, offset) else CFrame.new(offset, BASE - 8, mid)
			B.part(parent, Vector3.new(6, 15, 6), pcf, Color3.fromRGB(170, 165, 155), Enum.Material.Concrete)
		end
		t += 8
	end
end

-- Постройки мира (ландшафт генерирует TerrainGen отдельно)
function M.build(rng: Random): Folder
	sky()

	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace

	-- общие дороги по коридорам между плитками
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = world
	local edge = Map.GRID_HALF + Map.ROAD_W / 2
	for k = 0, 5 do
		local line = -Map.GRID_HALF + Map.TILE * k
		roadLine(roads, true, line, -edge, edge)
		roadLine(roads, false, line, -edge, edge)
	end

	-- лес по краям карты
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = world
	CollectionService:AddTag(forest, "Decor")
	local function tree(x: number, z: number)
		local h = Relief.height(x, z)
		if h < Map.WATER + 2 or h > BASE + 120 then
			return
		end
		if rng:NextNumber() < 0.65 then
			B.pine(forest, Vector3.new(x, h - 0.3, z), rng:NextNumber(1.4, 2.2), rng)
		else
			B.leafy(forest, Vector3.new(x, h - 0.3, z), rng:NextNumber(1.3, 2), rng)
		end
	end
	for _ = 1, 260 do
		tree(rng:NextNumber(-3700, -2900), rng:NextNumber(-3000, 2600))
	end
	for _ = 1, 260 do
		tree(rng:NextNumber(2900, 3700), rng:NextNumber(-3000, 2600))
	end
	for _ = 1, 200 do
		tree(rng:NextNumber(-2800, 2800), rng:NextNumber(-3300, -2900))
	end

	-- участки
	local plots = Instance.new("Folder")
	plots.Name = "Plots"
	plots.Parent = world
	for _, p in Map.plots do
		local model = Instance.new("Model")
		model.Name = "Plot_" .. p.index
		model:SetAttribute("Index", p.index)
		model:SetAttribute("Biome", p.biome)
		model:SetAttribute("Owner", 0)
		model:SetAttribute("OwnerName", "")
		model.Parent = plots
		local center = Map.tileCenter(p.c, p.r)
		-- бордюр по краю участка
		for side = 0, 3 do
			local cf = CFrame.new(center) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0.25, Map.PLOT / 2 + 0.5)
			B.part(model, Vector3.new(Map.PLOT + 2, 0.5, 1), cf, Color3.fromRGB(190, 185, 170), Enum.Material.Concrete).CastShadow = false
		end
		-- табличка у въезда
		local ei, ej = Map.entrance(p.index)
		local x, z = Map.cellXZ(p.index, ei, ej)
		local side = Map.hubSide(p.index)
		local dx = if side == "W" then -14 elseif side == "E" then 14 else 14
		local dz = if side == "N" then -14 elseif side == "S" then 14 else 14
		local post = B.part(model, Vector3.new(0.8, 7, 0.8), CFrame.new(x + dx, BASE + 3.5, z + dz), Color3.fromRGB(110, 80, 55))
		post.Name = "Sign"
		local board = B.part(model, Vector3.new(6, 3, 0.4), CFrame.new(x + dx, BASE + 7, z + dz), Color3.fromRGB(150, 110, 70), Enum.Material.WoodPlanks)
		board.Name = "SignBoard"
		local gui = B.label(post, "", 7, nil, 70)
		gui.Name = "SignGui"
		gui.Size = UDim2.fromOffset(190, 46)
		local decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = model
		decorate(decor, p.index, rng)
		local city = Instance.new("Folder")
		city.Name = "City"
		city.Parent = model
	end

	return world
end

return M
