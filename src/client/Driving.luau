--!nonstrict
-- Вождение: ввод (кнопки на экране, клавиатура, геймпад), физика своей машины, камера погони,
-- спидометр. Включается, когда персонаж садится за руль любой машины игры.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = game.ReplicatedStorage.Shared
local L = require(Shared.Lang.L)
local VConfig = require(Shared.Vehicles.Config)
local Physics = require(Shared.Vehicles.Physics)
local Kit = require(script.Parent.UI.Kit)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local C = Kit.C

local M = {}

local controls: any = nil
local gui: ScreenGui
local speedLabel: TextLabel
local pedals: { [string]: TextButton } = {}
local pressed = { left = false, right = false, gas = false, brake = false }
local inputOwner: { [InputObject]: string } = {}
local pad = { steer = 0, gas = 0, brake = 0 }
local onChange: (boolean) -> () = function() end
local toast: (string, string?) -> () = function() end

local car: Model? = nil
local seat: VehicleSeat? = nil
local state = nil
local camPos: Vector3? = nil
local camParams = RaycastParams.new()
camParams.FilterType = Enum.RaycastFilterType.Exclude
camParams.IgnoreWater = true
local touchWas = true

local function loadControls()
	task.spawn(function()
		local ok, mod = pcall(function()
			local ps = player:WaitForChild("PlayerScripts")
			local pm: any = ps:WaitForChild("PlayerModule", 10)
			return (require :: any)(pm)
		end)
		if ok and mod then
			controls = mod:GetControls()
		end
	end)
end

local function pedal(name: string, text: string, size: Vector2, anchor: Vector2, pos: UDim2, color: Color3): TextButton
	local b = Kit.button(text, "plain", {
		AnchorPoint = anchor,
		Position = pos,
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = color,
		BackgroundTransparency = 0.35,
		TextSize = 22,
		AutoButtonColor = false,
		Visible = UserInputService.TouchEnabled,
		Parent = gui,
	})
	Kit.stroke(Color3.new(1, 1, 1), 2).Parent = b
	b.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			pressed[name] = true
			inputOwner[input] = name
			b.BackgroundTransparency = 0.05
		end
	end)
	return b
end

local function buildGui()
	gui = Kit.screen("Driving", 3)
	gui.Enabled = false
	local box = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(0, 150, 0, 62),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.25,
		Parent = gui,
	}, { Kit.corner(14) })
	speedLabel = Kit.label({
		Text = "0",
		Font = Kit.BOLD,
		TextSize = 34,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.new(1, 0, 0, 40),
		Parent = box,
	})
	Kit.label({ Text = "km/h", TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 16), Parent = box })

	local top = Kit.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.new(0, 300, 0, 40),
		Parent = gui,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right, Parent = top })
	local flip = Kit.button(L.t("drive.flip"), "plain", { Size = UDim2.new(0, 120, 1, 0), TextSize = 14, Parent = top }, function()
		local ok, msg = Store.act("flip")
		if not ok and type(msg) == "string" then
			toast(L.t(msg), "error")
		end
	end)
	local exit = Kit.button(L.t("drive.exit"), "bad", { Size = UDim2.new(0, 100, 1, 0), TextSize = 14, Parent = top }, function()
		M.leave()
	end)
	L.onChange(function()
		flip.Text = L.t("drive.flip")
		exit.Text = L.t("drive.exit")
	end)

	pedals.left = pedal("left", "◀", Vector2.new(96, 96), Vector2.new(0, 1), UDim2.new(0, 16, 1, -16), C.bg)
	pedals.right = pedal("right", "▶", Vector2.new(96, 96), Vector2.new(0, 1), UDim2.new(0, 122, 1, -16), C.bg)
	pedals.gas = pedal("gas", "▲", Vector2.new(100, 130), Vector2.new(1, 1), UDim2.new(1, -16, 1, -16), Color3.fromRGB(40, 150, 70))
	pedals.brake = pedal("brake", "▼", Vector2.new(100, 96), Vector2.new(1, 1), UDim2.new(1, -126, 1, -16), Color3.fromRGB(170, 40, 40))
end

local function keyDown(...)
	for _, key in { ... } do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function readInput(): Physics.Input
	local K = Enum.KeyCode
	local steer = (if pressed.right then 1 else 0) - (if pressed.left then 1 else 0)
	if keyDown(K.D, K.Right) then
		steer += 1
	end
	if keyDown(K.A, K.Left) then
		steer -= 1
	end
	steer = math.clamp(steer + pad.steer, -1, 1)
	local throttle = if pressed.gas or keyDown(K.W, K.Up) then 1 else pad.gas
	local brake = if pressed.brake or keyDown(K.S, K.Down) then 1 else pad.brake
	local hand = keyDown(K.Space, K.ButtonX)
	return { throttle = throttle, brake = brake, steer = steer, handbrake = hand }
end

local function start(newCar: Model, newSeat: VehicleSeat)
	car, seat = newCar, newSeat
	state = Physics.newState(newCar)
	camPos = nil
	camParams.FilterDescendantsInstances = { newCar, player.Character }
	if controls then
		controls:Disable()
	end
	touchWas = GuiService.TouchControlsEnabled
	GuiService.TouchControlsEnabled = false
	gui.Enabled = true
	onChange(true)
end

local function stop()
	if not car then
		return
	end
	car, seat, state = nil, nil, nil
	for k in pressed do
		pressed[k] = false
	end
	table.clear(inputOwner)
	gui.Enabled = false
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	if controls then
		controls:Enable()
	end
	GuiService.TouchControlsEnabled = touchWas
	onChange(false)
end

function M.leave()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.Sit = false
		hum.Jump = true
	end
end

function M.active(): boolean
	return car ~= nil
end

local function bindCharacter(character: Model)
	local hum = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not hum then
		return
	end
	hum.Seated:Connect(function(active, seatPart)
		if active and seatPart and seatPart:IsA("VehicleSeat") and seatPart.Name == "DriverSeat" then
			local model = seatPart.Parent
			if model and model:IsA("Model") and model:GetAttribute("VehicleType") then
				start(model, seatPart)
				return
			end
		end
		stop()
	end)
	hum.Died:Connect(stop)
end

function M.start(changeFn: (boolean) -> (), toastFn: (string, string?) -> ())
	onChange = changeFn
	toast = toastFn
	loadControls()
	buildGui()

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
				pedals[name].BackgroundTransparency = 0.35
			end
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.Thumbstick1 then
			pad.steer = if math.abs(input.Position.X) > 0.15 then input.Position.X else 0
		elseif input.KeyCode == Enum.KeyCode.ButtonR2 then
			pad.gas = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			pad.brake = input.Position.Z
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not car then
			return
		end
		if input.KeyCode == Enum.KeyCode.R then
			Store.act("flip")
		elseif input.KeyCode == Enum.KeyCode.F or input.KeyCode == Enum.KeyCode.ButtonB then
			M.leave()
		end
	end)

	if player.Character then
		task.spawn(bindCharacter, player.Character)
	end
	player.CharacterAdded:Connect(bindCharacter)

	RunService.PreSimulation:Connect(function(dt)
		if not car or not state or not seat then
			return
		end
		local input = readInput()
		Physics.step(car, input, dt, state)
	end)

	RunService:BindToRenderStep("VehicleCamera", Enum.RenderPriority.Camera.Value + 3, function(dt)
		local c = car
		if not c then
			return
		end
		local body = c.PrimaryPart
		if not body then
			return
		end
		local t = VConfig.TYPES[c:GetAttribute("VehicleType") or "van"]
		local back = if t and t.id == "van" then 20 elseif t and t.id == "forklift" then 15 else 12
		local cf = body.CFrame
		local vel = body.AssemblyLinearVelocity
		local speed = vel.Magnitude
		camera.CameraType = Enum.CameraType.Scriptable
		local look = cf.LookVector
		if speed > 8 then
			look = look:Lerp(vel.Unit, 0.3)
		end
		local flat = Vector3.new(look.X, 0, look.Z)
		flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, -1)
		local desired = body.Position - flat * back + Vector3.new(0, back * 0.42, 0)
		camPos = if camPos then camPos:Lerp(desired, 1 - math.exp(-dt * 6)) else desired
		local target = body.Position + flat * 5 + Vector3.new(0, 2, 0)
		local pos = camPos :: Vector3
		local hit = workspace:Raycast(target, pos - target, camParams)
		if hit then
			pos = hit.Position + hit.Normal * 0.6
		end
		camera.CFrame = CFrame.lookAt(pos, target)
		local fov = 70 + math.clamp(speed * 0.12, 0, 15)
		camera.FieldOfView += (fov - camera.FieldOfView) * math.min(1, dt * 4)
		speedLabel.Text = tostring(math.floor(math.abs(vel:Dot(cf.LookVector)) + 0.5))
	end)
end

return M
