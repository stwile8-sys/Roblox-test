--!strict
-- Стартовый хаб в центре карты и 4 рынка по углам. Здесь же — реквизит NPC-работ:
-- доска заданий, склад с грузовиком, телега, NPC-ферма, забор, причал с кораблём.

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
local Y = Map.GROUND_Y

local function at(x: number, z: number, y: number?): Vector3
	return Vector3.new(x, Y + (y or 0), z)
end

local function marker(parent: Instance, tag: string, pos: Vector3, n: number?): Part
	local p = B.part(parent, Vector3.new(2, 1, 2), CFrame.new(pos), Color3.new(1, 1, 1))
	p.Transparency = 1
	p.CanCollide = false
	p.CanQuery = false
	p.Name = tag
	if n then
		p:SetAttribute("N", n)
	end
	CollectionService:AddTag(p, tag)
	return p
end

-- Домик: стены + двускатная крыша. cf — центр основания, «перед» смотрит в −Z
local function house(parent: Instance, cf: CFrame, w: number, d: number, h: number, wall: Color3, roof: Color3)
	B.part(parent, Vector3.new(w, h, d), cf * CFrame.new(0, h / 2, 0), wall)
	local roofH = math.min(w, d) * 0.35
	local _, yaw = cf:ToEulerAnglesYXZ()
	B.ridge(parent, (cf * CFrame.new(0, h, 0)).Position, w + 1.5, d + 1.5, roofH, roof, yaw)
	B.part(parent, Vector3.new(3, 5, 0.4), cf * CFrame.new(0, 2.5, -d / 2 - 0.1), DARKWOOD)
end

local function crate(parent: Instance, pos: Vector3, size: number?): Part
	local s = size or 2.5
	local c = B.part(parent, Vector3.new(s, s, s), CFrame.new(pos + Vector3.new(0, s / 2, 0)), Color3.fromRGB(190, 145, 85), Enum.Material.WoodPlanks)
	return c
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

function M.build(world: Instance)
	local hub = Instance.new("Model")
	hub.Name = "Hub"
	hub.Parent = world

	-- площадь
	-- площадь из 4 кусков: на юго-западе оставлен вырез под пруд x[-74,-30] z[32,72]
	local function plaza(x0: number, x1: number, z0: number, z1: number)
		B.part(hub, Vector3.new(x1 - x0, 1, z1 - z0), CFrame.new((x0 + x1) / 2, Y - 0.5, (z0 + z1) / 2), STONE, Enum.Material.Cobblestone)
	end
	plaza(-80, 80, -80, 32)
	plaza(-30, 80, 32, 80)
	plaza(-80, -74, 32, 80)
	plaza(-74, -30, 72, 80)
	B.part(hub, Vector3.new(60, 0.2, 60), CFrame.new(0, Y + 0.05, 0), Color3.fromRGB(210, 200, 185), Enum.Material.Pavement)

	-- точка появления
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 0.4, 10)
	spawn.CFrame = CFrame.new(at(0, 30, 0.2))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = hub

	-- фонтан в центре
	B.cylinder(hub, 1.6, 22, CFrame.new(at(0, 0, 0.8)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(170, 165, 155), Enum.Material.Concrete)
	local w = B.cylinder(hub, 0.4, 19, CFrame.new(at(0, 0, 1.5)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(90, 170, 220), Enum.Material.Glass)
	w.Transparency = 0.25
	B.post(hub, at(0, 0, 1), 7, 2.2, Color3.fromRGB(180, 175, 165), Enum.Material.Concrete)
	B.ball(hub, 3, CFrame.new(at(0, 0, 8.6)), Color3.fromRGB(230, 200, 90), Enum.Material.Metal)

	-- доска заданий (север)
	local board = B.part(hub, Vector3.new(14, 8, 0.8), CFrame.new(at(0, -45, 6)), Color3.fromRGB(120, 85, 55), Enum.Material.WoodPlanks)
	board.Name = "JobBoard"
	B.part(hub, Vector3.new(12.5, 6.5, 0.2), CFrame.new(at(0, -44.5, 6.2)), Color3.fromRGB(225, 210, 170))
	B.post(hub, at(-6.5, -45, 0), 10, 0.8, DARKWOOD)
	B.post(hub, at(6.5, -45, 0), 10, 0.8, DARKWOOD)
	B.label(board, "📋", 6, nil, 120)
	uiPrompt(board, "jobs", "act.jobs")
	marker(hub, "TutorialBoard", at(0, -42, 0))

	-- рынок (восток)
	local market = Instance.new("Model")
	market.Name = "HubMarket"
	market.Parent = hub
	stall(market, CFrame.new(at(50, 0, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(70, 140, 200))
	local terminal = B.part(market, Vector3.new(2, 4, 2), CFrame.new(at(44, 0, 2)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
	B.label(terminal, "💰", 6, nil, 120)
	uiPrompt(terminal, "market", "act.market")

	-- земельная контора (запад) — покупка участков и почта
	local office = Instance.new("Model")
	office.Name = "LandOffice"
	office.Parent = hub
	house(office, CFrame.new(at(-55, 0)) * CFrame.Angles(0, -math.pi / 2, 0), 16, 14, 9, WALL, Color3.fromRGB(70, 110, 160))
	local desk = B.part(office, Vector3.new(2, 4, 4), CFrame.new(at(-44, 0, 2)), WOOD)
	B.label(desk, "🗺️", 6, nil, 120)
	uiPrompt(desk, "plots", "act.plots")
	marker(hub, "TutorialOffice", at(-42, 0))
	-- почтовый ящик: начало доставки посылок
	local post = B.part(office, Vector3.new(2.5, 4, 2.5), CFrame.new(at(-44, 14, 2)), Color3.fromRGB(60, 90, 170))
	post.Name = "PostBox"
	marker(hub, "JobParcelPoint", at(-44, 14), 1)

	-- северо-восток: склад и грузовик + куча ящиков и телега
	local yard = Instance.new("Model")
	yard.Name = "Warehouse"
	yard.Parent = hub
	house(yard, CFrame.new(at(55, -60)) * CFrame.Angles(0, math.pi / 2, 0), 22, 18, 11, Color3.fromRGB(200, 170, 140), ROOF)
	local door = B.part(yard, Vector3.new(1, 7, 6), CFrame.new(at(44.5, -60, 3.5)), DARKWOOD)
	door.Transparency = 0.5
	B.prompt(door, "JobWarehouse", "act.drop", 0.5, 9)
	-- грузовик
	local truck = Instance.new("Model")
	truck.Name = "Truck"
	truck.Parent = yard
	local tcf = CFrame.new(at(28, -62)) * CFrame.Angles(0, math.pi / 2, 0)
	B.part(truck, Vector3.new(7, 6, 12), tcf * CFrame.new(0, 4.5, 2), Color3.fromRGB(150, 150, 160), Enum.Material.Metal)
	B.part(truck, Vector3.new(7, 5, 5), tcf * CFrame.new(0, 4, -7), Color3.fromRGB(210, 70, 60))
	B.part(truck, Vector3.new(6.6, 2, 0.3), tcf * CFrame.new(0, 5, -9.6), Color3.fromRGB(150, 200, 230), Enum.Material.Glass)
	for _, x in { -3.4, 3.4 } do
		for _, z in { -6.5, 5.5 } do
			B.cylinder(truck, 1.2, 3, tcf * CFrame.new(x, 1.5, z), Color3.fromRGB(30, 30, 30))
		end
	end
	local tail = B.part(truck, Vector3.new(6, 1, 1), tcf * CFrame.new(0, 2, 8.5), Color3.fromRGB(90, 90, 95))
	B.prompt(tail, "JobTruck", "act.pickup", 1, 9)
	-- куча ящиков и телега
	for n = 0, 5 do
		crate(yard, at(20 + (n % 3) * 2.6, -35 + (n // 3) * 2.6, (n // 3) * 0))
	end
	local pile = B.part(yard, Vector3.new(8, 3, 6), CFrame.new(at(22.6, -33.7, 1.5)), Color3.new(1, 1, 1))
	pile.Transparency = 1
	B.prompt(pile, "JobCratePile", "act.pickup", 1, 9)
	local cart = Instance.new("Model")
	cart.Name = "Cart"
	cart.Parent = yard
	local ccf = CFrame.new(at(50, -25))
	B.part(cart, Vector3.new(6, 1, 4), ccf * CFrame.new(0, 2.2, 0), WOOD, Enum.Material.WoodPlanks)
	B.part(cart, Vector3.new(6, 1.5, 0.4), ccf * CFrame.new(0, 3.2, 1.8), WOOD)
	B.part(cart, Vector3.new(6, 1.5, 0.4), ccf * CFrame.new(0, 3.2, -1.8), WOOD)
	for _, x in { -2, 2 } do
		B.cylinder(cart, 0.5, 3.4, ccf * CFrame.new(x, 1.7, 2.3) * CFrame.Angles(0, math.pi / 2, 0), DARKWOOD)
		B.cylinder(cart, 0.5, 3.4, ccf * CFrame.new(x, 1.7, -2.3) * CFrame.Angles(0, math.pi / 2, 0), DARKWOOD)
	end
	local cartBed = B.part(cart, Vector3.new(6, 2, 4), ccf * CFrame.new(0, 3.5, 0), Color3.new(1, 1, 1))
	cartBed.Transparency = 1
	cartBed.CanCollide = false
	B.prompt(cartBed, "JobCart", "act.load", 0.5, 9)

	-- северо-запад: NPC-ферма, 10 растений
	local farm = Instance.new("Model")
	farm.Name = "NpcFarm"
	farm.Parent = hub
	B.part(farm, Vector3.new(44, 0.4, 30), CFrame.new(at(-50, -55, 0.1)), Color3.fromRGB(120, 85, 55), Enum.Material.Ground)
	for n = 1, 10 do
		local x = -66 + ((n - 1) % 5) * 8
		local z = -63 + ((n - 1) // 5) * 14
		local stem = B.part(farm, Vector3.new(1.2, 3, 1.2), CFrame.new(at(x, z, 1.8)), Color3.fromRGB(90, 160, 60))
		B.part(farm, Vector3.new(2.4, 1.6, 2.4), CFrame.new(at(x, z, 3.8)) * CFrame.Angles(0, 0.7, 0), Color3.fromRGB(235, 200, 80))
		stem.Name = "Plant" .. n
		local pr = B.prompt(stem, "JobPlant", "act.harvest", 1.5, 7)
		pr:SetAttribute("N", n)
	end

	-- юго-восток: забор с 5 дырами
	local fence = Instance.new("Model")
	fence.Name = "Fence"
	fence.Parent = hub
	local fx0, fz = 25, 62
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

	-- юго-запад: пруд-гавань с кораблём и складом
	local dock = Instance.new("Model")
	dock.Name = "Dock"
	dock.Parent = hub
	-- вода чуть ниже площади, но выше общей земли (у неё верх на 0)
	local pond = B.part(dock, Vector3.new(44, 0.2, 40), CFrame.new(-52, 0.02, 52), Color3.fromRGB(70, 140, 190), Enum.Material.Glass)
	pond.Transparency = 0.1
	B.part(dock, Vector3.new(8, 1, 26), CFrame.new(at(-34, 52, 0.1)), WOOD, Enum.Material.WoodPlanks) -- причал
	local ship = Instance.new("Model")
	ship.Name = "Ship"
	ship.Parent = dock
	local scf = CFrame.new(at(-45, 52, -1.2))
	B.part(ship, Vector3.new(10, 3, 26), scf * CFrame.new(0, 1.5, 0), Color3.fromRGB(120, 70, 45), Enum.Material.WoodPlanks)
	B.wedge(ship, Vector3.new(10, 3, 6), scf * CFrame.new(0, 1.5, -16) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(120, 70, 45))
	B.part(ship, Vector3.new(0.8, 16, 0.8), scf * CFrame.new(0, 10, 0), DARKWOOD)
	B.part(ship, Vector3.new(0.2, 9, 8), scf * CFrame.new(0, 11, 1), Color3.fromRGB(240, 235, 220))
	for n = 0, 5 do
		crate(ship, (scf * CFrame.new(-2.5 + (n % 2) * 5, 3, -6 + (n // 2) * 4)).Position, 2)
	end
	local gang = B.part(ship, Vector3.new(6, 2, 8), scf * CFrame.new(5, 3.5, 0), Color3.new(1, 1, 1))
	gang.Transparency = 1
	gang.CanCollide = false
	B.prompt(gang, "JobShip", "act.pickup", 1, 10)
	local store = Instance.new("Model")
	store.Name = "DockStore"
	store.Parent = dock
	house(store, CFrame.new(at(-15, 72)) * CFrame.Angles(0, math.pi, 0), 12, 10, 8, Color3.fromRGB(190, 200, 210), Color3.fromRGB(80, 100, 120))
	local sdoor = B.part(store, Vector3.new(4, 6, 1), CFrame.new(at(-15, 66.5, 3)), DARKWOOD)
	sdoor.Transparency = 0.5
	B.prompt(sdoor, "JobDockStore", "act.drop", 0.5, 9)

	-- точки уборки площади
	for n = 1, 8 do
		local a = (n - 1) / 8 * math.pi * 2
		marker(hub, "JobSweepPoint", at(math.cos(a) * 24, math.sin(a) * 24), n)
	end

	-- фонари и деревья для уюта
	for n = 0, 7 do
		local a = n / 8 * math.pi * 2 + 0.39
		local pos = at(math.cos(a) * 34, math.sin(a) * 34)
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
		B.part(model, Vector3.new(160, 1, 160), CFrame.new(center + Vector3.new(0, Y - 0.5, 0)), Color3.fromRGB(205, 185, 150), Enum.Material.Sand)
		for k = 0, 3 do
			local cf = CFrame.new(center) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, Y, -22)
			stall(model, cf, ({ Color3.fromRGB(200, 70, 60), Color3.fromRGB(70, 150, 90), Color3.fromRGB(230, 170, 60), Color3.fromRGB(80, 120, 200) })[k + 1])
		end
		local t = B.part(model, Vector3.new(2, 4, 2), CFrame.new(center + Vector3.new(0, Y + 2, 0)), Color3.fromRGB(60, 60, 70), Enum.Material.Metal)
		B.label(t, "💰", 6, nil, 300)
		uiPrompt(t, "market", "act.market")
	end
	-- конечные точки доставки посылок: два угловых рынка на севере
	marker(world, "JobParcelPoint", Map.tileCenter(4, 0) + Vector3.new(0, Y, 6), 2)
	marker(world, "JobParcelPoint", Map.tileCenter(0, 0) + Vector3.new(0, Y, 6), 3)

	return hub
end

return M
