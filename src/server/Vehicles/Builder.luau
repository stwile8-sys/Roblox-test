--!strict
-- Постройка транспорта из деталей. Корень — невидимый корпус Body с массой; детали без массы.

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Vehicles.Config)

local M = {}

local MAT = Enum.Material
local BLACK = Color3.fromRGB(25, 25, 28)
local GLASS = Color3.fromRGB(40, 55, 70)

local function weld(body: BasePart, part: BasePart)
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = body
	wc.Part1 = part
	wc.Parent = part
end

local function piece(car: Model, body: BasePart, class: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, cylinder: boolean?): BasePart
	local p = Instance.new(class) :: BasePart
	if cylinder and p:IsA("Part") then
		p.Shape = Enum.PartType.Cylinder
	end
	p.Size = size
	p.CFrame = body.CFrame * offset
	p.Color = color
	p.Material = material or MAT.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = car
	weld(body, p)
	return p
end

local function wheel(car: Model, body: BasePart, t: Config.VehicleType, name: string, rim: Color3)
	local mount = t.wheels[name]
	local offset = CFrame.new(mount - Vector3.new(0, t.sMax - t.rest, 0))
	local d = t.radius * 2
	piece(car, body, "Part", Vector3.new(0.9, d, d), offset, BLACK, MAT.Fabric, true)
	piece(car, body, "Part", Vector3.new(0.95, d * 0.55, d * 0.55), offset, rim, MAT.Metal, true)
end

local function build(t: Config.VehicleType, cf: CFrame, parent: Instance, color: Color3): (Model, BasePart)
	local car = Instance.new("Model")
	car.Name = t.id
	car:SetAttribute("VehicleType", t.id)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = t.body
	body.CFrame = cf
	body.Transparency = 1
	body.CustomPhysicalProperties = PhysicalProperties.new(0.6, 0.3, 0.2, 1, 1)
	body.Anchored = true
	body.Parent = car
	car.PrimaryPart = body
	local ballast = Instance.new("Part")
	ballast.Name = "Ballast"
	ballast.Size = Vector3.new(t.body.X * 0.6, 0.5, t.body.Z * 0.6)
	ballast.CFrame = cf * CFrame.new(0, -t.body.Y / 2 + 0.25, 0)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CanTouch = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0.2)
	ballast.Parent = car
	weld(body, ballast)
	local _ = color
	return car, body
end

local function seat(car: Model, body: BasePart, offset: CFrame)
	local s = Instance.new("VehicleSeat")
	s.Name = "DriverSeat"
	s.Size = Vector3.new(2, 0.4, 2)
	s.CFrame = body.CFrame * offset
	s.Transparency = 1
	s.CanCollide = false
	s.CanTouch = false -- садимся только через подсказку (проверка на сервере)
	s.Massless = true
	s.MaxSpeed = 0
	s.Torque = 0
	s.HeadsUpDisplay = false
	s.Parent = car
	weld(body, s)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "act.drive"
	prompt:SetAttribute("Key", "act.drive")
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.AutoLocalize = false
	prompt.Parent = body
end

function M.van(cf: CFrame, parent: Instance): Model
	local t = Config.TYPES.van
	local car, body = build(t, cf, parent, Color3.new())
	local paint = Color3.fromRGB(240, 240, 235)
	local accent = Color3.fromRGB(230, 120, 40)
	piece(car, body, "Part", Vector3.new(6.4, 1.6, 13), CFrame.new(0, 0, 0), paint)
	-- кабина
	piece(car, body, "Part", Vector3.new(6.2, 3, 3.6), CFrame.new(0, 2.3, -3.9), paint)
	piece(car, body, "WedgePart", Vector3.new(6.2, 2.2, 1.6), CFrame.new(0, 2.7, -6.4), GLASS, MAT.Glass).Transparency = 0.3
	-- фургон
	local box = piece(car, body, "Part", Vector3.new(6.4, 4.6, 8.4), CFrame.new(0, 3.1, 2.2), Color3.fromRGB(250, 250, 248))
	piece(car, body, "Part", Vector3.new(6.5, 0.7, 8.5), CFrame.new(0, 2, 2.2), accent)
	local logo = Instance.new("SurfaceGui")
	logo.Face = Enum.NormalId.Left
	logo.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	logo.PixelsPerStud = 30
	local t1 = Instance.new("TextLabel")
	t1.Size = UDim2.fromScale(1, 1)
	t1.BackgroundTransparency = 1
	t1.Text = "📦"
	t1.TextScaled = true
	t1.Parent = logo
	logo.Parent = box
	local logo2 = logo:Clone()
	logo2.Face = Enum.NormalId.Right
	logo2.Parent = box
	-- фары
	for _, sx in { -1, 1 } do
		piece(car, body, "Part", Vector3.new(1.2, 0.5, 0.2), CFrame.new(sx * 2.4, 0.4, -6.55), Color3.fromRGB(255, 250, 230), MAT.Neon)
		piece(car, body, "Part", Vector3.new(1, 0.5, 0.2), CFrame.new(sx * 2.5, 0.4, 6.55), Color3.fromRGB(220, 30, 30), MAT.Neon)
	end
	for _, name in Config.WHEEL_ORDER do
		wheel(car, body, t, name, Color3.fromRGB(190, 190, 195))
	end
	seat(car, body, CFrame.new(-1.4, 1.2, -3.8))
	car.Parent = parent
	return car
end

function M.forklift(cf: CFrame, parent: Instance): Model
	local t = Config.TYPES.forklift
	local car, body = build(t, cf, parent, Color3.new())
	local yellow = Color3.fromRGB(245, 190, 30)
	piece(car, body, "Part", Vector3.new(4.4, 1.6, 7), CFrame.new(0, 0, 0), yellow)
	piece(car, body, "Part", Vector3.new(4.2, 1.6, 2.2), CFrame.new(0, 1.4, 2.4), Color3.fromRGB(60, 60, 65)) -- противовес
	-- кабина-каркас
	for _, sx in { -1.9, 1.9 } do
		for _, z in { -1.2, 1.8 } do
			piece(car, body, "Part", Vector3.new(0.25, 4.2, 0.25), CFrame.new(sx, 2.9, z), BLACK)
		end
	end
	piece(car, body, "Part", Vector3.new(4.3, 0.25, 3.4), CFrame.new(0, 5, 0.3), BLACK)
	-- мачта и вилы
	for _, sx in { -1.2, 1.2 } do
		piece(car, body, "Part", Vector3.new(0.35, 6, 0.35), CFrame.new(sx, 2.4, -3.7), Color3.fromRGB(70, 70, 75), MAT.Metal)
		piece(car, body, "Part", Vector3.new(0.4, 0.2, 3), CFrame.new(sx * 0.8, -0.2, -5.2), Color3.fromRGB(90, 90, 95), MAT.Metal)
	end
	piece(car, body, "Part", Vector3.new(3, 1.6, 0.25), CFrame.new(0, 0.6, -3.85), Color3.fromRGB(70, 70, 75), MAT.Metal)
	for _, name in Config.WHEEL_ORDER do
		wheel(car, body, t, name, yellow)
	end
	seat(car, body, CFrame.new(0, 1.1, 0.4))
	car.Parent = parent
	return car
end

function M.cart(cf: CFrame, parent: Instance): Model
	local t = Config.TYPES.cart
	local car, body = build(t, cf, parent, Color3.new())
	local wood = Color3.fromRGB(150, 110, 70)
	piece(car, body, "Part", Vector3.new(3.6, 0.5, 5), CFrame.new(0, 0, 0), wood, MAT.WoodPlanks)
	for _, sx in { -1.7, 1.7 } do
		piece(car, body, "Part", Vector3.new(0.25, 1, 5), CFrame.new(sx, 0.7, 0), wood)
	end
	piece(car, body, "Part", Vector3.new(3.6, 1, 0.25), CFrame.new(0, 0.7, 2.4), wood)
	piece(car, body, "Part", Vector3.new(3.6, 1, 0.25), CFrame.new(0, 0.7, -2.4), wood)
	piece(car, body, "Part", Vector3.new(0.25, 0.25, 2), CFrame.new(-1, 1, 3.4), Color3.fromRGB(110, 80, 50))
	piece(car, body, "Part", Vector3.new(0.25, 0.25, 2), CFrame.new(1, 1, 3.4), Color3.fromRGB(110, 80, 50))
	for _, name in Config.WHEEL_ORDER do
		wheel(car, body, t, name, wood)
	end
	seat(car, body, CFrame.new(0, 0.6, 3.6))
	car.Parent = parent
	return car
end

return M
