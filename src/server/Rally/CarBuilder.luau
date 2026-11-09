-- Постройка раллийной машины из деталей.
-- Корень — невидимый корпус Body с массой; всё остальное без массы.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CarConfig = require(ReplicatedStorage:WaitForChild("Rally"):WaitForChild("CarConfig"))

local CarBuilder = {}

local M = Enum.Material
local BLACK = Color3.fromRGB(22, 22, 24)
local GLASS = Color3.fromRGB(30, 40, 52)

local function weld(body: BasePart, part: BasePart)
	local wc = Instance.new("WeldConstraint")
	wc.Part0 = body
	wc.Part1 = part
	wc.Parent = part
end

-- деталь кузова: локальная поза относительно Body
local function piece(car: Model, body: BasePart, className: string, size: Vector3, local_: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?)
	local p = Instance.new(className) :: BasePart
	if props and props.Shape then
		(p :: any).Shape = props.Shape
	end
	p.Size = size
	p.CFrame = body.CFrame * local_
	p.Color = color
	p.Material = material or M.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Massless = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	if props then
		for key, v in props do
			if key ~= "Shape" then
				(p :: any)[key] = v
			end
		end
	end
	p.Parent = car
	weld(body, p)
	return p
end

local function numberDecal(part: BasePart, face: Enum.NormalId, number: number)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local circle = Instance.new("Frame")
	circle.AnchorPoint = Vector2.new(0.5, 0.5)
	circle.Position = UDim2.fromScale(0.5, 0.5)
	circle.Size = UDim2.fromScale(0.8, 0.8)
	circle.SizeConstraint = Enum.SizeConstraint.RelativeYY
	circle.BackgroundColor3 = Color3.new(1, 1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = circle
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = tostring(number)
	t.TextScaled = true
	t.Font = Enum.Font.BuilderSansExtraBold
	t.TextColor3 = BLACK
	t.Parent = circle
	circle.Parent = gui
	gui.Parent = part
end

function CarBuilder.build(typeName: string, cf: CFrame, parent: Instance): Model
	local cfg = CarConfig.TYPES[typeName]
	local car = Instance.new("Model")
	car.Name = cfg.name
	car:SetAttribute("CarType", typeName)

	-- корпус (столкновения и масса)
	local body = Instance.new("Part")
	body.Name = "Body"
	body.Size = Vector3.new(6, 2, 12)
	body.CFrame = cf
	body.Transparency = 1
	body.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0.3, 0.2, 1, 1)
	body.TopSurface = Enum.SurfaceType.Smooth
	body.BottomSurface = Enum.SurfaceType.Smooth
	body.Anchored = true
	body.Parent = car
	car.PrimaryPart = body

	local ballast = Instance.new("Part")
	ballast.Name = "Ballast"
	ballast.Size = Vector3.new(4, 0.5, 8)
	ballast.CFrame = cf * CFrame.new(0, -0.75, 0)
	ballast.Transparency = 1
	ballast.CanCollide = false
	ballast.CanQuery = false
	ballast.CanTouch = false
	ballast.CustomPhysicalProperties = PhysicalProperties.new(3, 0.3, 0.2)
	ballast.Parent = car
	weld(body, ballast)

	local paint, accent = cfg.paint, cfg.accent

	-- нижняя часть кузова
	local shell = piece(car, body, "Part", Vector3.new(6.4, 1.7, 12.4), CFrame.new(0, 0.1, 0), paint, M.SmoothPlastic, { Reflectance = 0.06 })
	-- капот (скат вперёд) и багажник
	piece(car, body, "WedgePart", Vector3.new(6.4, 0.7, 3.4), CFrame.new(0, 1.3, -4.5), paint, M.SmoothPlastic, { Reflectance = 0.06 })
	piece(car, body, "Part", Vector3.new(6.4, 0.7, 1.4), CFrame.new(0, 1.3, -2.1), paint, M.SmoothPlastic, { Reflectance = 0.06 })
	piece(car, body, "Part", Vector3.new(6.4, 0.6, 2.6), CFrame.new(0, 1.25, 4.9), paint, M.SmoothPlastic, { Reflectance = 0.06 })
	-- кабина
	piece(car, body, "Part", Vector3.new(5.7, 1.9, 4.4), CFrame.new(0, 2.6, 1.3), paint, M.SmoothPlastic, { Reflectance = 0.06 })
	piece(car, body, "Part", Vector3.new(5.9, 0.25, 4.6), CFrame.new(0, 3.62, 1.3), paint, M.SmoothPlastic, { Reflectance = 0.06 })
	piece(car, body, "WedgePart", Vector3.new(5.7, 1.9, 2.2), CFrame.new(0, 2.6, -2), GLASS, M.Glass, { Transparency = 0.25 })
	piece(car, body, "WedgePart", Vector3.new(5.7, 1.9, 1.4), CFrame.new(0, 2.6, 4.2) * CFrame.Angles(0, math.pi, 0), GLASS, M.Glass, { Transparency = 0.25 })
	for _, sx in { -1, 1 } do
		piece(car, body, "Part", Vector3.new(0.12, 1.3, 3.6), CFrame.new(sx * 2.88, 2.7, 1.3), GLASS, M.Glass, { Transparency = 0.25 })
	end

	-- раскраска: полосы и номер
	piece(car, body, "Part", Vector3.new(1.4, 0.05, 12.5), CFrame.new(-0.9, 0.97, 0), accent, M.SmoothPlastic)
	piece(car, body, "Part", Vector3.new(1.4, 0.05, 4.7), CFrame.new(-0.9, 3.76, 1.3), accent, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		piece(car, body, "Part", Vector3.new(0.06, 0.45, 12.45), CFrame.new(sx * 3.21, -0.25, 0), accent, M.SmoothPlastic)
		local door = piece(car, body, "Part", Vector3.new(0.06, 1.4, 2.4), CFrame.new(sx * 3.22, 0.35, 0.3), paint, M.SmoothPlastic)
		numberDecal(door, sx > 0 and Enum.NormalId.Right or Enum.NormalId.Left, cfg.number)
	end
	local roof = piece(car, body, "Part", Vector3.new(2.4, 0.06, 2.4), CFrame.new(1.3, 3.78, 1.3), paint, M.SmoothPlastic)
	numberDecal(roof, Enum.NormalId.Top, cfg.number)

	-- бамперы, пороги, брызговики
	piece(car, body, "Part", Vector3.new(6.7, 0.9, 0.7), CFrame.new(0, -0.45, -6.3), BLACK, M.SmoothPlastic)
	piece(car, body, "Part", Vector3.new(6.7, 0.9, 0.7), CFrame.new(0, -0.45, 6.3), BLACK, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		for _, z in { -2.3, 5.6 } do
			piece(car, body, "Part", Vector3.new(1.2, 1.2, 0.08), CFrame.new(sx * 2.8, -0.7, z), BLACK, M.SmoothPlastic)
		end
	end
	-- антикрыло
	for _, sx in { -1, 1 } do
		piece(car, body, "Part", Vector3.new(0.25, 0.8, 0.5), CFrame.new(sx * 2.2, 1.95, 5.6), BLACK, M.SmoothPlastic)
	end
	piece(car, body, "Part", Vector3.new(6.2, 0.18, 1.3), CFrame.new(0, 2.38, 5.75) * CFrame.Angles(math.rad(-8), 0, 0), accent, M.SmoothPlastic)

	-- фары, люстра, стопы
	local white = Color3.fromRGB(255, 250, 235)
	for _, sx in { -1, 1 } do
		piece(car, body, "Part", Vector3.new(1.3, 0.5, 0.15), CFrame.new(sx * 2.3, 0.65, -6.22), white, M.Neon)
		piece(car, body, "Part", Vector3.new(1.2, 0.4, 0.15), CFrame.new(sx * 2.3, 0.65, 6.22), Color3.fromRGB(220, 20, 20), M.Neon)
		piece(car, body, "Part", Vector3.new(0.6, 0.6, 0.15), CFrame.new(sx * 1.5, -0.45, -6.7), Color3.fromRGB(255, 214, 90), M.Neon, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 0.6, 0.6), CFrame = body.CFrame * CFrame.new(sx * 1.5, -0.45, -6.7) * CFrame.Angles(0, math.pi / 2, 0) })
	end
	piece(car, body, "Part", Vector3.new(4.4, 0.5, 0.4), CFrame.new(0, 3.95, -0.7), BLACK, M.SmoothPlastic)
	for i = 0, 3 do
		local x = -1.65 + i * 1.1
		piece(car, body, "Part", Vector3.new(0.12, 0.42, 0.42), CFrame.new(x, 3.95, -0.92) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(255, 226, 140), M.Neon, { Shape = Enum.PartType.Cylinder })
	end
	local beam = Instance.new("SpotLight")
	beam.Face = Enum.NormalId.Front
	beam.Range = 60
	beam.Angle = 55
	beam.Brightness = 2.5
	beam.Color = Color3.fromRGB(255, 244, 220)
	beam.Parent = shell

	-- выхлоп
	piece(car, body, "Part", Vector3.new(0.9, 0.45, 0.45), CFrame.new(2, -0.75, 6.6) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(150, 150, 155), M.Metal, { Shape = Enum.PartType.Cylinder })

	-- колёса: невидимая ось на Weld (C0 меняет клиент для анимации)
	local wheels = Instance.new("Folder")
	wheels.Name = "Wheels"
	wheels.Parent = car
	local rest = CarConfig.S_MAX - CarConfig.REST_COMPRESSION
	for _, name in CarConfig.WHEEL_ORDER do
		local mount = CarConfig.WHEELS[name]
		local offset = CFrame.new(mount - Vector3.new(0, rest, 0))
		local pivot = Instance.new("Part")
		pivot.Name = name
		pivot.Size = Vector3.new(0.2, 0.2, 0.2)
		pivot.Transparency = 1
		pivot.CanCollide = false
		pivot.CanQuery = false
		pivot.CanTouch = false
		pivot.Massless = true
		pivot.CFrame = body.CFrame * offset
		pivot.Parent = wheels
		local joint = Instance.new("Weld")
		joint.Name = "Joint"
		joint.Part0 = body
		joint.Part1 = pivot
		joint.C0 = offset
		joint.Parent = pivot

		local sx = mount.X > 0 and 1 or -1
		local function wheelPart(size: Vector3, local_: CFrame, color: Color3, material: Enum.Material)
			local p = Instance.new("Part")
			p.Shape = Enum.PartType.Cylinder
			p.Size = size
			p.CFrame = pivot.CFrame * local_
			p.Color = color
			p.Material = material
			p.Massless = true
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Parent = wheels
			local wc = Instance.new("WeldConstraint")
			wc.Part0 = pivot
			wc.Part1 = p
			wc.Parent = p
		end
		local d = CarConfig.WHEEL_RADIUS * 2
		wheelPart(Vector3.new(1.15, d, d), CFrame.new(), BLACK, M.Fabric)
		wheelPart(Vector3.new(1.2, d * 0.62, d * 0.62), CFrame.new(), Color3.fromRGB(210, 210, 214), M.Metal)
		wheelPart(Vector3.new(1.25, d * 0.22, d * 0.22), CFrame.new(sx * 0.01, 0, 0), accent, M.Metal)
	end

	-- место водителя
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = Vector3.new(2, 0.4, 2)
	seat.CFrame = body.CFrame * CFrame.new(-1.3, 0.25, 1.6)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanTouch = false -- садимся только через подсказку (проверка на сервере)
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.HeadsUpDisplay = false
	seat.Parent = car
	weld(body, seat)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DrivePrompt"
	prompt.ActionText = "Сесть за руль"
	prompt.ObjectText = cfg.name .. " · " .. cfg.drive
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = shell

	CollectionService:AddTag(car, "RallyCar")
	car.Parent = parent
	return car
end

return CarBuilder
