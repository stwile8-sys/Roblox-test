-- Вождение: ввод (кнопки на экране и клавиатура), физика своей машины,
-- камера погони и приборы. Владелец всего, что происходит за рулём.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Rally", 30)
if not Shared then
	warn("Rally: нет общих модулей")
	return
end
local CarConfig = require(Shared:WaitForChild("CarConfig", 10))
local CarPhysics = require(Shared:WaitForChild("CarPhysics", 10))

local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10))
	end)
	if ok and module then
		controls = module:GetControls()
	end
end)

-- ── интерфейс ────────────────────────────────────────────────

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	inst.Parent = props.Parent
	return inst
end
local function corner(r: number)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local WHITE = Color3.new(1, 1, 1)
local DARK = Color3.fromRGB(16, 16, 20)
local WARM = Color3.fromRGB(255, 200, 120)

local gui = new("ScreenGui", { Name = "Driving", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8, Enabled = false, Parent = playerGui })
local uiScale = new("UIScale", { Parent = gui })

-- спидометр
local speedBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -16),
	Size = UDim2.fromOffset(220, 110),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.35,
	Parent = gui,
}, { corner(20) })
local speedLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 64),
	Position = UDim2.fromOffset(0, 6),
	BackgroundTransparency = 1,
	Text = "0",
	TextColor3 = WHITE,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 62,
	Parent = speedBox,
})
local unitLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.fromOffset(0, 66),
	BackgroundTransparency = 1,
	Text = "км/ч · 1",
	TextColor3 = Color3.fromRGB(200, 196, 190),
	Font = Enum.Font.BuilderSansBold,
	TextSize = 18,
	Parent = speedBox,
})
local revBack = new("Frame", {
	Position = UDim2.new(0, 20, 1, -18),
	Size = UDim2.new(1, -40, 0, 6),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.8,
	Parent = speedBox,
}, { corner(3) })
local revFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WARM, Parent = revBack }, { corner(3) })

-- круг
local lapBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.fromOffset(340, 92),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.35,
	Parent = gui,
}, { corner(16) })
local lapLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 40),
	Position = UDim2.fromOffset(0, 6),
	BackgroundTransparency = 1,
	Text = "Пересеки старт",
	TextColor3 = WHITE,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 30,
	Parent = lapBox,
})
local bestLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 20),
	Position = UDim2.fromOffset(0, 46),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = Color3.fromRGB(210, 205, 200),
	Font = Enum.Font.BuilderSansBold,
	TextSize = 17,
	Parent = lapBox,
})
local dots = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(160, 12),
	BackgroundTransparency = 1,
	Parent = lapBox,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local dotFrames = {}
for i = 1, 5 do
	dotFrames[i] = new("Frame", { Size = UDim2.fromOffset(12, 12), BackgroundColor3 = WHITE, BackgroundTransparency = 0.7, Parent = dots }, { corner(6) })
end

local toast = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 112),
	Size = UDim2.fromOffset(500, 44),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = WARM,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 34,
	Parent = gui,
})

-- кнопки сверху справа
local topBar = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -12, 0, 12),
	Size = UDim2.fromOffset(420, 46),
	BackgroundTransparency = 1,
	Parent = gui,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Right }) })
local function topButton(text: string, width: number)
	return new("TextButton", {
		Size = UDim2.fromOffset(width, 46),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.3,
		Text = text,
		TextColor3 = WHITE,
		Font = Enum.Font.BuilderSansBold,
		TextSize = 18,
		AutoButtonColor = true,
		Parent = topBar,
	}, { corner(12) })
end
local flipButton = topButton("Перевернуть", 140)
local camButton = topButton("Камера", 110)
local exitButton = topButton("Выйти", 90)

-- сенсорные педали и руль
local pressed = { left = false, right = false, gas = false, brake = false, hand = false }
local inputOwner: { [InputObject]: string } = {}

local function pedal(name: string, text: string, size: Vector2, anchor: Vector2, pos: UDim2, color: Color3)
	local b = new("TextButton", {
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.45,
		Text = text,
		TextColor3 = WHITE,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 26,
		AutoButtonColor = false,
		Visible = UserInputService.TouchEnabled,
		Parent = gui,
	}, { corner(22), new("UIStroke", { Color = WHITE, Transparency = 0.7, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) })
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressed[name] = true
			inputOwner[input] = name
			b.BackgroundTransparency = 0.15
		end
	end)
	return b
end
local pedals = {
	left = pedal("left", "◀", Vector2.new(120, 120), Vector2.new(0, 1), UDim2.new(0, 24, 1, -24), DARK),
	right = pedal("right", "▶", Vector2.new(120, 120), Vector2.new(0, 1), UDim2.new(0, 156, 1, -24), DARK),
	gas = pedal("gas", "ГАЗ", Vector2.new(130, 170), Vector2.new(1, 1), UDim2.new(1, -24, 1, -24), Color3.fromRGB(40, 150, 70)),
	brake = pedal("brake", "ТОРМОЗ", Vector2.new(130, 110), Vector2.new(1, 1), UDim2.new(1, -166, 1, -24), Color3.fromRGB(170, 40, 40)),
	hand = pedal("hand", "РУЧНИК", Vector2.new(130, 70), Vector2.new(1, 1), UDim2.new(1, -166, 1, -146), Color3.fromRGB(60, 60, 70)),
}
UserInputService.InputEnded:Connect(function(input)
	local name = inputOwner[input]
	if name then
		inputOwner[input] = nil
		local still = false
		for _, other in inputOwner do
			if other == name then
				still = true
			end
		end
		pressed[name] = still
		if not still then
			pedals[name].BackgroundTransparency = 0.45
		end
	end
end)

local function rescale()
	uiScale.Scale = math.clamp(camera.ViewportSize.Y / 720, 0.55, 1.15)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- геймпад
local pad = { steer = 0, gas = 0, brake = 0 }
UserInputService.InputChanged:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.Thumbstick1 then
		pad.steer = math.abs(input.Position.X) > 0.15 and input.Position.X or 0
	elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
		pad.gas = input.Position.Z
	elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
		pad.brake = input.Position.Z
	end
end)

-- ── состояние вождения ───────────────────────────────────────

local car: Model? = nil
local seat: VehicleSeat? = nil
local state = nil
local camMode = 1 -- 1 погоня, 2 капот, 3 свободная
local camPos: Vector3? = nil
local camParams = RaycastParams.new()
camParams.FilterType = Enum.RaycastFilterType.Exclude
camParams.IgnoreWater = true

local function keyDown(...)
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function readInput()
	local K = Enum.KeyCode
	local steer = (pressed.right and 1 or 0) - (pressed.left and 1 or 0)
	if keyDown(K.D, K.Right) then
		steer += 1
	end
	if keyDown(K.A, K.Left) then
		steer -= 1
	end
	steer = math.clamp(steer + pad.steer, -1, 1)
	local throttle = (pressed.gas or keyDown(K.W, K.Up)) and 1 or pad.gas
	local brake = (pressed.brake or keyDown(K.S, K.Down)) and 1 or pad.brake
	local hand = pressed.hand or keyDown(K.Space, K.ButtonX)
	return { throttle = throttle, brake = brake, steer = steer, handbrake = hand }
end

local function fmt(t: number): string
	local m = math.floor(t / 60)
	return string.format("%d:%05.2f", m, t - m * 60)
end

local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	TweenService:Create(toast, TweenInfo.new(0.3), { TextTransparency = 0, TextStrokeTransparency = 0.5 }):Play()
	task.delay(2.5, function()
		if token == toastToken then
			TweenService:Create(toast, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

player:GetAttributeChangedSignal("LastLap"):Connect(function()
	local t = player:GetAttribute("LastLap")
	if typeof(t) == "number" and car then
		local best = player:GetAttribute("BestLap")
		if best == t then
			showToast("Новый рекорд! " .. fmt(t))
		else
			showToast("Круг: " .. fmt(t))
		end
	end
end)

local function startDriving(newCar: Model, newSeat: VehicleSeat)
	car, seat = newCar, newSeat
	state = CarPhysics.newState(newCar)
	camPos = nil
	camParams.FilterDescendantsInstances = { newCar, player.Character }
	if controls then
		controls:Disable()
	end
	local hud = playerGui:FindFirstChild("Hud")
	if hud then
		hud.Enabled = false
	end
	gui.Enabled = true
	local cfg = CarConfig.TYPES[newCar:GetAttribute("CarType")]
	if cfg then
		showToast(cfg.name .. " · " .. cfg.drive)
	end
end

local function stopDriving()
	if not car then
		return
	end
	car:SetAttribute("VisualSteer", nil)
	car:SetAttribute("VisualThrottle", nil)
	car, seat, state = nil, nil, nil
	for k in pressed do
		pressed[k] = false
	end
	table.clear(inputOwner)
	gui.Enabled = false
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	if controls then
		controls:Enable()
	end
	local hud = playerGui:FindFirstChild("Hud")
	if hud then
		hud.Enabled = true
	end
end

local function bindCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	humanoid.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") and seatPart.Name == "DriverSeat" then
			local model = seatPart.Parent
			if model and model:IsA("Model") and model:GetAttribute("CarType") then
				startDriving(model, seatPart)
				return
			end
		end
		stopDriving()
	end)
	humanoid.Died:Connect(stopDriving)
end
if player.Character then
	task.spawn(bindCharacter, player.Character)
end
player.CharacterAdded:Connect(bindCharacter)

flipButton.Activated:Connect(function()
	local remote = Shared:FindFirstChild("ResetCar")
	if remote and car then
		remote:FireServer()
	end
end)
camButton.Activated:Connect(function()
	camMode = camMode % 3 + 1
	camPos = nil
	showToast(({ "Камера: погоня", "Камера: капот", "Камера: свободная" })[camMode])
end)
exitButton.Activated:Connect(function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Sit = false
		humanoid.Jump = true
	end
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not car then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		local remote = Shared:FindFirstChild("ResetCar")
		if remote then
			remote:FireServer()
		end
	elseif input.KeyCode == Enum.KeyCode.C then
		camMode = camMode % 3 + 1
		camPos = nil
	end
end)

-- ── физика своей машины ──────────────────────────────────────

RunService.PreSimulation:Connect(function(dt)
	if not car or not state or not seat then
		return
	end
	local input = readInput()
	CarPhysics.step(car, input, dt, state)
	car:SetAttribute("VisualSteer", state.steer)
	car:SetAttribute("VisualThrottle", input.throttle)
	pcall(function()
		seat.ThrottleFloat = input.throttle - input.brake
		seat.SteerFloat = input.steer
	end)
end)

-- ── камера и приборы ─────────────────────────────────────────

RunService:BindToRenderStep("RallyCamera", Enum.RenderPriority.Camera.Value + 3, function(dt)
	if not car then
		return
	end
	local body = car.PrimaryPart
	if not body then
		return
	end
	local cf = body.CFrame
	local vel = body.AssemblyLinearVelocity
	local speed = vel.Magnitude

	if camMode == 3 then
		camera.CameraType = Enum.CameraType.Custom
		if seat then
			camera.CameraSubject = seat
		end
	else
		camera.CameraType = Enum.CameraType.Scriptable
		if camMode == 1 then
			local look = cf.LookVector
			if speed > 10 then
				look = look:Lerp(vel.Unit, 0.35)
			end
			local flat = Vector3.new(look.X, 0, look.Z)
			flat = flat.Magnitude > 0.1 and flat.Unit or Vector3.new(0, 0, -1)
			local desired = body.Position - flat * 17 + Vector3.new(0, 6.5, 0)
			camPos = camPos and camPos:Lerp(desired, 1 - math.exp(-dt * 6)) or desired
			local target = body.Position + flat * 6 + Vector3.new(0, 2, 0)
			local pos = camPos :: Vector3
			local hit = workspace:Raycast(target, pos - target, camParams)
			if hit then
				pos = hit.Position + hit.Normal * 0.6
			end
			local shake = 0
			if state and state.grounded > 0 then
				shake = math.clamp(speed / 160, 0, 1) * 0.06
			end
			local t = os.clock()
			camera.CFrame = CFrame.lookAt(pos, target) * CFrame.Angles(math.noise(t * 9) * shake, math.noise(t * 9, 5) * shake, 0)
		else
			camera.CFrame = cf * CFrame.new(0, 2.6, -1.5) * CFrame.Angles(math.rad(-4), 0, 0)
		end
		local fov = 70 + math.clamp(speed * 0.13, 0, 22)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 4)
	end

	-- приборы
	local kmh = math.floor(math.abs(vel:Dot(cf.LookVector)) + 0.5)
	speedLabel.Text = tostring(kmh)
	local bands = { 0, 32, 58, 84, 110, 136, 999 }
	local gear = 1
	for i = 1, 6 do
		if kmh >= bands[i] then
			gear = i
		end
	end
	local reverse = vel:Dot(cf.LookVector) < -2
	unitLabel.Text = "км/ч · " .. (reverse and "R" or tostring(gear))
	local lo, hi = bands[gear], math.min(bands[gear + 1], 170)
	revFill.Size = UDim2.fromScale(math.clamp((kmh - lo) / math.max(hi - lo, 1), 0.05, 1), 1)

	local lapStart = player:GetAttribute("LapStart")
	local lapCount = player:GetAttribute("LapCount") or 0
	if typeof(lapStart) == "number" and lapStart > 0 then
		lapLabel.Text = string.format("КРУГ %d · %s", lapCount + 1, fmt(workspace:GetServerTimeNow() - lapStart))
	else
		lapLabel.Text = "Пересеки старт"
	end
	local best, last = player:GetAttribute("BestLap"), player:GetAttribute("LastLap")
	local parts = {}
	if typeof(best) == "number" then
		table.insert(parts, "ЛУЧШИЙ " .. fmt(best))
	end
	if typeof(last) == "number" then
		table.insert(parts, "ПРОШЛЫЙ " .. fmt(last))
	end
	bestLabel.Text = table.concat(parts, "   ")
	local cp = player:GetAttribute("Checkpoint") or 0
	for i, d in dotFrames do
		d.BackgroundTransparency = i <= cp and 0 or 0.7
		d.BackgroundColor3 = i <= cp and WARM or WHITE
	end
end)
