--!strict
-- Карта мира в лоу-поли: земля, вода (Terrain), общие дороги, горы, лес, плитки участков.

local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local Biomes = require(Shared.Config.Biomes)
local B = require(script.Parent.Builders)

local M = {}

local GRASS = Color3.fromRGB(110, 165, 85)
local SAND = Color3.fromRGB(225, 205, 150)
local ASPHALT = Color3.fromRGB(70, 72, 78)
local LINE = Color3.fromRGB(230, 225, 200)

local function landRect(parent: Instance, x0: number, x1: number, z0: number, z1: number, color: Color3)
	B.part(parent, Vector3.new(x1 - x0, 6, z1 - z0), CFrame.new((x0 + x1) / 2, -3, (z0 + z1) / 2), color, Enum.Material.SmoothPlastic)
end

local function water(x0: number, x1: number, z0: number, z1: number, depth: number)
	local t = workspace.Terrain
	local size = Vector3.new(x1 - x0, depth, z1 - z0)
	local center = Vector3.new((x0 + x1) / 2, -0.8 - depth / 2, (z0 + z1) / 2)
	t:FillBlock(CFrame.new(center - Vector3.new(0, depth / 2 + 3, 0)), Vector3.new(size.X, 6, size.Z), Enum.Material.Sand)
	t:FillBlock(CFrame.new(center), size, Enum.Material.Water)
end

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
	atmo.Density = 0.28
	atmo.Offset = 0.2
	atmo.Color = Color3.fromRGB(200, 215, 235)
	atmo.Decay = Color3.fromRGB(120, 140, 170)
	atmo.Glare = 0.2
	atmo.Haze = 1
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
end

-- Украшения свободного участка по биому (убираются при покупке)
local function decorate(folder: Instance, index: number, rng: Random)
	local p = Map.plots[index]
	local o = Map.plotOrigin(index)
	local function spot(margin: number): Vector3
		return o + Vector3.new(rng:NextNumber(margin, Map.PLOT - margin), Map.GROUND_Y, rng:NextNumber(margin, Map.PLOT - margin))
	end
	local biome = p.biome
	if biome == "forest" then
		for _ = 1, 22 do
			if rng:NextNumber() < 0.6 then
				B.pine(folder, spot(8), rng:NextNumber(0.9, 1.4), rng)
			else
				B.leafy(folder, spot(8), rng:NextNumber(0.9, 1.3), rng)
			end
		end
	elseif biome == "field" or biome == "meadow" then
		local rows = if biome == "field" then 8 else 4
		for n = 1, rows do
			local z = 20 + n * (120 / rows)
			B.part(folder, Vector3.new(110, 1.2, 4), CFrame.new(o + Vector3.new(80, Map.GROUND_Y + 0.6, z)), Color3.fromRGB(225, 195, 85))
		end
		for _ = 1, (if biome == "meadow" then 6 else 2) do
			B.leafy(folder, spot(10), rng:NextNumber(1, 1.4), rng)
		end
		if biome == "meadow" then
			for _ = 1, 30 do
				local c = ({ Color3.fromRGB(240, 90, 90), Color3.fromRGB(250, 220, 90), Color3.fromRGB(230, 230, 250) })[rng:NextInteger(1, 3)]
				B.part(folder, Vector3.new(0.8, 0.8, 0.8), CFrame.new(spot(4) + Vector3.new(0, 0.4, 0)), c)
			end
		end
	elseif biome == "desert" then
		for _ = 1, 5 do
			B.ridge(folder, spot(20) - Vector3.new(0, 0.5, 0), rng:NextNumber(20, 40), rng:NextNumber(10, 18), rng:NextNumber(3, 6), SAND:Lerp(Color3.new(0.9, 0.7, 0.4), 0.2), rng:NextNumber() * 3)
		end
		for _ = 1, 10 do
			B.rock(folder, spot(6), rng:NextNumber(2, 6), rng, Color3.fromRGB(180, 140, 100))
		end
	elseif biome == "mountains" then
		for _ = 1, 3 do
			B.ridge(folder, spot(30), rng:NextNumber(30, 50), rng:NextNumber(20, 30), rng:NextNumber(10, 18), Color3.fromRGB(130, 130, 125), rng:NextNumber() * 3, Enum.Material.Slate)
		end
		for _ = 1, 12 do
			B.rock(folder, spot(6), rng:NextNumber(2, 7), rng)
		end
	elseif biome == "swamp" then
		for _ = 1, 6 do
			local c = spot(15)
			B.part(folder, Vector3.new(rng:NextNumber(12, 24), 0.3, rng:NextNumber(10, 20)), CFrame.new(c + Vector3.new(0, 0.1, 0)), Color3.fromRGB(70, 90, 70), Enum.Material.Glass).Transparency = 0.2
		end
		for _ = 1, 10 do
			B.pine(folder, spot(8), rng:NextNumber(0.7, 1), rng, Color3.fromRGB(75, 95, 60))
		end
	else -- river, lake, coast
		for _ = 1, 8 do
			B.leafy(folder, spot(10), rng:NextNumber(0.9, 1.2), rng)
		end
		for _ = 1, 20 do
			local c = spot(4)
			B.part(folder, Vector3.new(0.4, rng:NextNumber(2, 4), 0.4), CFrame.new(c + Vector3.new(0, 1.5, 0)), Color3.fromRGB(120, 150, 70))
		end
	end
end

M.decorate = decorate

function M.build(rng: Random): Folder
	sky()
	local world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	local land = Instance.new("Folder")
	land.Name = "Land"
	land.Parent = world

	-- суша вокруг реки (запад), озера (восток) и моря (юг)
	landRect(land, -1100, -565, -1100, 540, GRASS)
	landRect(land, -515, 540, -1100, 540, GRASS)
	landRect(land, 540, 1100, -1100, -140, GRASS)
	landRect(land, 760, 1100, -140, 540, GRASS)
	landRect(land, 540, 760, 340, 540, GRASS)
	landRect(land, -1100, 1100, 540, 600, SAND) -- пляж

	water(-565, -515, -1100, 600, 10) -- река
	water(540, 760, -140, 340, 12) -- озеро
	water(-1300, 1300, 600, 1500, 20) -- море

	-- общие дороги между плитками
	local roads = Instance.new("Folder")
	roads.Name = "Roads"
	roads.Parent = world
	for k = 0, 5 do
		local x = -500 + 200 * k
		B.part(roads, Vector3.new(40, 1, 1040), CFrame.new(x, Map.ROAD_Y - 0.5, 0), ASPHALT, Enum.Material.Asphalt)
		B.part(roads, Vector3.new(1040, 1, 40), CFrame.new(0, Map.ROAD_Y - 0.49, x), ASPHALT, Enum.Material.Asphalt)
		B.part(roads, Vector3.new(0.6, 0.1, 1040), CFrame.new(x, Map.ROAD_Y + 0.02, 0), LINE)
		B.part(roads, Vector3.new(1040, 0.1, 0.6), CFrame.new(0, Map.ROAD_Y + 0.03, x), LINE)
	end

	-- горы на севере
	local mountains = Instance.new("Folder")
	mountains.Name = "Mountains"
	mountains.Parent = world
	for n = 0, 16 do
		local x = -1050 + n * 135 + rng:NextNumber(-30, 30)
		local z = -760 - rng:NextNumber(0, 220)
		local h = rng:NextNumber(110, 230)
		local w = rng:NextNumber(220, 320)
		local yaw = rng:NextNumber(-0.5, 0.5)
		B.ridge(mountains, Vector3.new(x, 0, z), w, h * 1.6, h, Color3.fromRGB(120, 122, 118), yaw, Enum.Material.Slate)
		-- снежная шапка
		B.ridge(mountains, Vector3.new(x, h * 0.72, z), w * 0.28, h * 0.45, h * 0.28, Color3.fromRGB(245, 248, 255), yaw, Enum.Material.Snow)
	end

	-- лес по краям карты
	local forest = Instance.new("Folder")
	forest.Name = "Forest"
	forest.Parent = world
	CollectionService:AddTag(forest, "Decor")
	local function tree(x: number, z: number)
		if rng:NextNumber() < 0.65 then
			B.pine(forest, Vector3.new(x, 0, z), rng:NextNumber(1.2, 2), rng)
		else
			B.leafy(forest, Vector3.new(x, 0, z), rng:NextNumber(1.2, 1.8), rng)
		end
	end
	for _ = 1, 90 do
		tree(rng:NextNumber(-1050, -600), rng:NextNumber(-700, 500))
	end
	for _ = 1, 50 do
		tree(rng:NextNumber(-500, 500), rng:NextNumber(-700, -540))
	end
	for _ = 1, 50 do
		tree(rng:NextNumber(780, 1050), rng:NextNumber(-700, 500))
	end

	-- плитки участков
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
		local ground = B.part(model, Vector3.new(Map.PLOT, 1, Map.PLOT), CFrame.new(center + Vector3.new(0, Map.GROUND_Y - 0.5, 0)), Biomes.byId[p.biome].ground)
		ground.Name = "Ground"
		model.PrimaryPart = ground
		-- бордюр
		for side = 0, 3 do
			local cf = CFrame.new(center) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, Map.GROUND_Y + 0.15, Map.PLOT / 2 - 0.4)
			B.part(model, Vector3.new(Map.PLOT, 0.5, 0.8), cf, Color3.fromRGB(190, 185, 170))
		end
		local decor = Instance.new("Folder")
		decor.Name = "Decor"
		decor.Parent = model
		decorate(decor, p.index, rng)
		local city = Instance.new("Folder")
		city.Name = "City"
		city.Parent = model
		-- табличка
		local signPost = B.part(model, Vector3.new(1, 6, 1), CFrame.new(center + Vector3.new(0, 3, 0)), Color3.fromRGB(120, 90, 60))
		signPost.Name = "Sign"
		signPost.Transparency = 1
		signPost.CanCollide = false
		local gui = B.label(signPost, "", 10, nil, 400)
		gui.Name = "SignGui"
		gui.Size = UDim2.fromOffset(300, 60)
	end

	return world
end

return M
