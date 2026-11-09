--!strict
-- Стартовый хаб в центре карты (плитка 1000×1000) и 4 рынка по углам.
-- Пешие работы — у площади: доска, NPC-ферма, забор, уборка. Транспортные — дальше:
-- двор склада (погрузчик), гавань с кораблём (погрузчик), почта (фургон до угловых рынков).

local CollectionService = game:GetService("CollectionService")

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local B = require(script.Parent.Builders)

local M = {}

local STONE = Color3.fromRGB(196, 190, 178)
local WOOD = Color3.fromRGB(150, 110, 70)
local DARKWOOD = Color3.fromRGB(105, 75, 50)
local ROOF = Color3.fromRGB(175, 80, 65)
local WALL = Color3.fromRGB(235, 225, 205)
local Y = Map.BASE

local function at(x: number, z: number, y: number?): Vector3
	return Vector3.new(x, Y + (y or 0), z)
end

local function marker(parent: Instance, tag: string, pos: Vector3, n: number?, yaw: number?): Part
	local p = B.part(parent, Vector3.new(2, 1, 2), CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Name = tag
	if n then
		p:SetAttribute("N", n)
	end
	CollectionService:AddTag(p, tag)
	return p
end

-- Зона погрузки/разгрузки: видимое пятно на земле
local function zone(parent: Instance, tag: string, pos: Vector3, color: Color3)
	local p = B.part(parent, Vector3.new(24, 0.2, 24), CFrame.new(pos + Vector3.new(0, 0.32, 0)), color, Enum.Material.SmoothPlastic)
	p.Transparency = 0.55
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Name = tag
	CollectionService:AddTag(p, tag)
end

local function house(parent: Instance, cf: CFrame, w: number, d: number, h: number, wall: Color3, roof: Color3)
	B.part(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), wall)
	local roofH = math.min(w, d) * 0.35
	local _, yaw = cf:ToEulerAnglesYXZ()
	B.ridge(parent, (cf * CFrame.new(0, h, 0)).Position, w + 1.5, d + 1.5, roofH, roof, yaw)
	B.part(parent, Vector3.new(4, 6, 0.4), cf * CFrame.new(0, 3, -d / 2 - 0.1), DARKWOOD)
end

local function crate(parent: Instance, pos: Vector3, size: number?)
	local s = size or 2.5
	B.part(parent, Vector3.new(s, s, s), CFrame.new(pos + Vector3.new(0, s / 2, 0)), Color3.fromRGB(190, 145, 85), Enum.Material.WoodPlanks)
end

local function uiPrompt(parent: Instance, ui: string, key: string)
	local pr = B.prompt(parent, "UiPrompt", key, 0, 12)
	pr:SetAttribute("Ui", ui)
end

local function stall(parent: Instance, cf: CFrame, color: Color3)
	B.part(parent, Vector3.new(12, 3.5, 4), cf * CFrame.new(0, 1.75, 0), WOOD)
	for _, x in { -5.5, 5.5 } do
		B.part(parent, Vector3.new(0.6, 8, 0.6), cf * CFrame.new(x, 4, 1.6), DARKWOOD)
		B.part(parent, Vector3.new(0.6, 8, 0.6), cf * CFrame.new(x, 4, -1.6), DARKWOOD)
	end
	B.wedge(parent, Vector3.new(13, 1.5, 5), cf * CFrame.new(0, 8.5, 0), color)
	for n = -2, 2 do
		crate(parent, (cf * CFrame.new(n * 2.2, 3.5, 0)).Position, 1.5)
	end
end

local function pad(parent: Instance, center: Vector3, sx: number, sz: number, color: Color3, material: Enum.Material)
	local p = B.part(parent, Vector3.new(sx, 1, sz), CFrame.new(center - Vector3.new(0, 0.3, 0)), color, material)
	p.CastShadow = false
end

-- Подъездная дорога внутри хаба (полоса асфальта)
local function lane(parent: Instance, a: Vector3, b: Vector3)
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local p = B.part(parent, Vector3.new(16, 1, len + 16), CFrame.lookAt(mid, b) - Vector3.new(0, 0.4, 0), Color3.fromRGB(75, 77, 83), Enum.Material.Asphalt)
	p.CastShadow = false
end

function M.build(world: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = world

	-- площадь
	pad(hub, at(0, 0), 200, 200, STONE, Enum.Material.Cobblestone)
	pad(hub, at(0, 0, 0.05), 70, 70, Color3.fromRGB(210, 200, 185), Enum.Material.Pavement)

	-- подъездные дороги от площади к работам и к общим дорогам
	lane(hub, at(100, 0), at(560, 0))
	lane(hub, at(-100, 0), at(-560, 0))
	lane(hub, at(0, -100), at(0, -560))
	lane(hub, at(0, 100), at(0, 560))
	lane(hub, at(60, -100), at(240, -260))
	lane(hub, at(-100, 60), at(-200, 300))

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(at(0, 40, 0.3))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	-- фонтан
	B.cylinder(hub, 1.6, 24, CFrame.new(at(0, 0, 0.8)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(170, 165, 155), Enum.Material.Concrete)
	local w = B.cylinder(hub, 0.4, 21, CFrame.new(at(0, 0, 1.5)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 170, 220), Enum.Material.Glass)
	w.Transparency = 0.25
	B.post(hub, at(0, 0, 1), 7, 2.2, Color3.fromRGB(180, 175, 165), Enum.Material.Concrete)
	B.ball(hub, 3, CFrame.new(at(0, 0, 8.6)), Color3.fromRGB(230, 200, 90), Enum.Material.Metal)

	-- доска заданий (север площади)
	local board = B.part(hub, Vector3.new(14, 8, 0.8), CFrame.new(at(0, -50, 6)), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
	board.Name = "JobBoard"
	B.part(hub, Vector3.new(12.5, 6.5, 0.2), CFrame.new(at(0, -49.5, 6.2)), Color3.fromRGB(225, 210, 170))
	B.post(hub, at(-6.5, -50), 10, 0.8, DARKWOOD)
	B.post(hub, at(6.5, -50), 10, 0.8, DARKWOOD)
	B.label(board, "📋", 6, nil, 80)
	uiPrompt(board, "jobs", "act.jobs")
	marker(hub, "TutorialBoard", at(0, -46))

	-- рынок (восток площади)
	stall(hub, CFrame.new(at(60, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(70, 140, 200))
	local terminal = B.part(hub, Vector3.new(2, 4, 2), CFrame.new(at(54, 2, 2)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	B.label(terminal, "💰", 5, nil, 80)
	uiPrompt(terminal, "market", "act.market")

	-- земельная контора и почта (запад площади)
	house(hub, CFrame.new(at(-65, 0)) * CFrame.Angles(0, -math.pi / 2, 0), 16, 14, 9, WALL, Color3.fromRGB(70, 110, 160))
	local desk = B.part(hub, Vector3.new(2, 4, 4), CFrame.new(at(-54, 0, 2)), WOOD)
	B.label(desk, "🗺️", 5, nil, 80)
	uiPrompt(desk, "plots", "act.plots")
	marker(hub, "TutorialOffice", at(-52, 0))
	-- почта: фургоны и первая точка доставки
	house(hub, CFrame.new(at(-70, -75)) * CFrame.Angles(0, -math.pi / 2, 0), 14, 12, 8, Color3.fromRGB(230, 230, 240), Color3.fromRGB(60, 90, 170))
	B.part(hub, Vector3.new(2.5, 4, 2.5), CFrame.new(at(-58, -64, 2)), Color3.fromRGB(60, 90, 170))
	marker(hub, "SpawnPost", at(-40, -90), nil, math.pi / 2)
	marker(hub, "JobParcelPoint", at(-58, -64), 1)

	-- NPC-ферма (пешком, северо-запад площади)
	local farm = Instance.new("Model")
	farm.Name = "NpcFarm"
	farm.Parent = hub
	pad(farm, at(-150, -40, 0.1), 50, 34, Color3.fromRGB(120, 85, 55), Enum.Material.Ground)
	for n = 1, 10 do
		local x = -166 + ((n - 1) % 5) * 8
		local z = -50 + ((n - 1) // 5) * 16
		local stem = B.part(farm, Vector3.new(1.2, 3, 1.2), CFrame.new(at(x, z, 1.8)), Color3.fromRGB(90, 160, 60))
		B.part(farm, Vector3.new(2.4, 1.6, 2.4), CFrame.new(at(x, z, 3.8)) * CFrame.Angles(0, 0.7, 0), Color3.fromRGB(235, 200, 80))
		stem.Name = "Plant" .. n
		local pr = B.prompt(stem, "JobPlant", "act.harvest", 1.5, 7)
		pr:SetAttribute("N", n)
	end

	-- забор с 5 дырами (пешком, юго-восток площади)
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = hub
	local fx0, fz = 110, 70
	for n = 0, 10 do
		local x = fx0 + n * 5
		B.post(fence, at(x, fz), 4, 0.7, DARKWOOD)
		local gapIndex = if n % 2 == 1 then (n + 1) // 2 else nil
		if gapIndex and gapIndex <= 5 then
			local gap = B.part(fence, Vector3.new(4.4, 3, 0.4), CFrame.new(at(x - 2.5, fz, 2)), Color3.new(1, 1, 1))
			gap.Transparency = 1
			gap.CanCollide = false
			gap.Name = "Gap" .. gapIndex
			gap:SetAttribute("N", gapIndex)
			CollectionService:AddTag(gap, "FenceGap")
			local pr = B.prompt(gap, "JobFenceGap", "act.repair", 2.5, 8)
			pr:SetAttribute("N", gapIndex)
		elseif n < 10 then
			B.part(fence, Vector3.new(5, 0.5, 0.3), CFrame.new(at(x + 2.5, fz, 1.2)), WOOD)
			B.part(fence, Vector3.new(5, 0.5, 0.3), CFrame.new(at(x + 2.5, fz, 2.8)), WOOD)
		end
	end

	-- точки уборки площади
	for n = 1, 8 do
		local a = (n - 1) / 8 * math.pi * 2
		marker(hub, "JobSweepPoint", at(math.cos(a) * 28, math.sin(a) * 28), n)
	end

	-- двор склада (погрузчик): склад, грузовик, куча ящиков, телега
	local yard = Instance.new("Model")
	yard.Name = "Warehouse"
	yard.Parent = hub
	pad(yard, at(300, -300, 0.05), 220, 200, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	house(yard, CFrame.new(at(360, -360)) * CFrame.Angles(0, math.pi / 4, 0), 40, 30, 16, Color3.fromRGB(200, 170, 140), ROOF)
	zone(yard, "ZoneWarehouse", at(330, -320), Color3.fromRGB(90, 200, 120))
	-- грузовик
	local tcf = CFrame.new(at(250, -380)) * CFrame.Angles(0, math.pi / 2, 0)
	B.part(yard, Vector3.new(7, 6, 14), tcf * CFrame.new(0, 4.5, 2), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
	B.part(yard, Vector3.new(7, 5, 5), tcf * CFrame.new(0, 4, -7.5), Color3.fromRGB(210, 70, 60))
	for _, x in { -3.4, 3.4 } do
		for _, z in { -7, 6 } do
			B.cylinder(yard, 1.2, 3, tcf * CFrame.new(x, 1.5, z), Color3.fromRGB(30, 30, 30))
		end
	end
	zone(yard, "ZoneTruck", (tcf * CFrame.new(0, 0, 18)).Position - Vector3.new(0, 0, 0), Color3.fromRGB(240, 190, 60))
	-- куча ящиков и телега (работа «погрузить ящик на телегу»)
	for n = 0, 8 do
		crate(yard, at(220 + (n % 3) * 2.6, -220 + (n // 3) * 2.6))
	end
	zone(yard, "ZoneCratePile", at(224, -205), Color3.fromRGB(240, 190, 60))
	local ccf = CFrame.new(at(380, -230))
	B.part(yard, Vector3.new(6, 1, 4), ccf * CFrame.new(0, 2.2, 0), WOOD, Enum.Material.WoodPlanks)
	for _, x in { -2, 2 } do
		B.cylinder(yard, 0.5, 3.4, ccf * CFrame.new(x, 1.7, 2.3) * CFrame.Angles(0, math.pi / 2, 0), DARKWOOD)
		B.cylinder(yard, 0.5, 3.4, ccf * CFrame.new(x, 1.7, -2.3) * CFrame.Angles(0, math.pi / 2, 0), DARKWOOD)
	end
	zone(yard, "ZoneCart", at(380, -215), Color3.fromRGB(90, 200, 120))
	marker(yard, "SpawnYard", at(260, -250), nil, math.pi * 0.75)

	-- гавань (погрузчик): корабль у причала, портовый склад
	local port = Instance.new("Model")
	port.Name = "Port"
	port.Parent = hub
	-- причал над водой (вода гавани — в ландшафте, центр (-320, 330))
	B.part(port, Vector3.new(60, 1, 18), CFrame.new(at(-230, 330, -0.2)), WOOD, Enum.Material.WoodPlanks)
	for k = 0, 5 do
		B.part(port, Vector3.new(1.2, 12, 1.2), CFrame.new(at(-255 + k * 10, 322, -6)), DARKWOOD)
		B.part(port, Vector3.new(1.2, 12, 1.2), CFrame.new(at(-255 + k * 10, 338, -6)), DARKWOOD)
	end
	local scf = CFrame.new(at(-300, 330, -4)) * CFrame.Angles(0, math.pi / 2, 0)
	B.part(port, Vector3.new(14, 5, 40), scf * CFrame.new(0, 2.5, 0), Color3.fromRGB(120, 70, 45), Enum.Material.WoodPlanks)
	B.wedge(port, Vector3.new(14, 5, 9), scf * CFrame.new(0, 2.5, -24.5) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(120, 70, 45))
	B.part(port, Vector3.new(1, 22, 1), scf * CFrame.new(0, 15, 0), DARKWOOD)
	B.part(port, Vector3.new(0.3, 13, 12), scf * CFrame.new(0, 16, 1), Color3.fromRGB(240, 235, 220))
	for n = 0, 7 do
		crate(port, (scf * CFrame.new(-3.5 + (n % 2) * 7, 5, -12 + (n // 2) * 6)).Position, 2.5)
	end
	zone(port, "ZoneShip", at(-215, 330), Color3.fromRGB(240, 190, 60))
	house(port, CFrame.new(at(-110, 420)) * CFrame.Angles(0, math.pi, 0), 24, 18, 11, Color3.fromRGB(190, 200, 210), Color3.fromRGB(80, 100, 120))
	zone(port, "ZoneDockStore", at(-110, 400), Color3.fromRGB(90, 200, 120))
	pad(port, at(-150, 380, 0.05), 140, 120, Color3.fromRGB(150, 150, 150), Enum.Material.Concrete)
	marker(port, "SpawnPort", at(-150, 360), nil, -math.pi / 2)

	-- фонари вокруг площади
	for n = 0, 7 do
		local a = n / 8 * math.pi * 2 + 0.39
		local pos = at(math.cos(a) * 42, math.sin(a) * 42)
		B.post(hub, pos, 9, 0.5, Color3.fromRGB(50, 50, 55), Enum.Material.Metal)
		local lamp = B.part(hub, Vector3.new(1.4, 1.4, 1.4), CFrame.new(pos + Vector3.new(0, 9.5, 0)), Color3.fromRGB(255, 225, 160), Enum.Material.Neon)
		local l = Instance.new("PointLight")
		l.Range = 18
		l.Brightness = 1
		l.Color = Color3.fromRGB(255, 210, 150)
		l.Parent = lamp
	end

	-- рынки по углам карты
	local markets = Instance.new("Folder")
	markets.Name = "Markets"
	markets.Parent = world
	for n, m in Map.markets do
		local center = Map.tileCenter(m.c, m.r)
		local model = Instance.new("Model")
		model.Name = "Market" .. n
		model.Parent = markets
		pad(model, center, 160, 160, Color3.fromRGB(205, 185, 150), Enum.Material.Sand)
		for k = 0, 3 do
			local cf = CFrame.new(center) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -26)
			stall(model, cf, ({ Color3.fromRGB(200, 70, 60), Color3.fromRGB(70, 150, 90), Color3.fromRGB(230, 170, 60), Color3.fromRGB(80, 120, 200) })[k + 1])
		end
		local t = B.part(model, Vector3.new(2, 4, 2), CFrame.new(center + Vector3.new(0, 2, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		B.label(t, "💰", 5, nil, 80)
		uiPrompt(t, "market", "act.market")
		-- дороги от рынка к коридорам
		lane(model, center + Vector3.new(80, 0, 0), center + Vector3.new(560, 0, 0))
		lane(model, center - Vector3.new(80, 0, 0), center - Vector3.new(560, 0, 0))
		lane(model, center + Vector3.new(0, 0, 80), center + Vector3.new(0, 0, 560))
		lane(model, center - Vector3.new(0, 0, 80), center - Vector3.new(0, 0, 560))
	end
	-- точки доставки посылок: северо-восточный и северо-западный рынки
	marker(world, "JobParcelPoint", Map.tileCenter(4, 0) + Vector3.new(0, 0, 40), 2)
	marker(world, "JobParcelPoint", Map.tileCenter(0, 0) + Vector3.new(0, 0, 40), 3)

	return hub
end

return M
