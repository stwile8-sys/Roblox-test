-- Анимация колёс и эффекты для всех машин у каждого игрока:
-- подвеска, вращение, поворот, пыль, комья грязи, брызги и следы.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Rally", 30)
if not Shared then
	return
end
local CarConfig = require(Shared:WaitForChild("CarConfig", 10))
local CarPhysics = require(Shared:WaitForChild("CarPhysics", 10))

local R = CarConfig.WHEEL_RADIUS
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

type Wheel = {
	joint: Weld,
	fx: Attachment,
	trailA: Attachment,
	trailB: Attachment,
	trail: Trail,
	dust: ParticleEmitter,
	clods: ParticleEmitter,
	splash: ParticleEmitter,
	spin: number,
	length: number,
	dustAcc: number,
	clodAcc: number,
	splashAcc: number,
	material: Enum.Material?,
}

local cars: { [Model]: { wheels: { [string]: Wheel }, params: RaycastParams } } = {}

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Rate = 0
	e.LightInfluence = 1
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function setup(car: Instance)
	if not car:IsA("Model") or cars[car] then
		return
	end
	local body = car:WaitForChild("Body", 10) :: BasePart?
	local folder = car:WaitForChild("Wheels", 10)
	if not body or not folder then
		return
	end
	local wheels = {}
	for _, name in CarConfig.WHEEL_ORDER do
		local pivot = folder:WaitForChild(name, 10)
		local joint = pivot and pivot:WaitForChild("Joint", 10) :: Weld?
		if not joint then
			return
		end
		local fx = Instance.new("Attachment")
		fx.Name = "FX_" .. name
		fx.Parent = body
		local a = Instance.new("Attachment")
		a.Parent = body
		local b = Instance.new("Attachment")
		b.Parent = body
		local trail = Instance.new("Trail")
		trail.Attachment0 = a
		trail.Attachment1 = b
		trail.FaceCamera = false
		trail.Lifetime = 6
		trail.MinLength = 0.4
		trail.Color = ColorSequence.new(Color3.fromRGB(58, 46, 34))
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.LightInfluence = 1
		trail.Enabled = false
		trail.Parent = body
		wheels[name] = {
			joint = joint,
			fx = fx,
			trailA = a,
			trailB = b,
			trail = trail,
			dust = emitter(fx, {
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 7) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(1.4, 2.8),
				Speed = NumberRange.new(3, 8),
				SpreadAngle = Vector2.new(35, 35),
				Drag = 2.5,
				Acceleration = Vector3.new(0, 1.5, 0),
				Rotation = NumberRange.new(0, 360),
				RotSpeed = NumberRange.new(-40, 40),
				EmissionDirection = Enum.NormalId.Back,
			}),
			clods = emitter(fx, {
				Size = NumberSequence.new(0.35, 0.18),
				Transparency = NumberSequence.new(0, 0.2),
				Lifetime = NumberRange.new(0.6, 1.1),
				Speed = NumberRange.new(16, 30),
				SpreadAngle = Vector2.new(18, 35),
				Drag = 0.4,
				Acceleration = Vector3.new(0, -110, 0),
				EmissionDirection = Enum.NormalId.Back,
			}),
			splash = emitter(fx, {
				Color = ColorSequence.new(Color3.fromRGB(225, 238, 245)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
				Lifetime = NumberRange.new(0.6, 1),
				Speed = NumberRange.new(12, 24),
				SpreadAngle = Vector2.new(45, 45),
				Acceleration = Vector3.new(0, -80, 0),
				EmissionDirection = Enum.NormalId.Top,
			}),
			spin = 0,
			length = CarConfig.S_MAX - CarConfig.REST_COMPRESSION,
			dustAcc = 0,
			clodAcc = 0,
			splashAcc = 0,
			material = nil,
		}
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	params.FilterDescendantsInstances = { car }
	cars[car] = { wheels = wheels, params = params }
end

for _, car in CollectionService:GetTagged("RallyCar") do
	task.spawn(setup, car)
end
CollectionService:GetInstanceAddedSignal("RallyCar"):Connect(function(car)
	task.spawn(setup, car)
end)
CollectionService:GetInstanceRemovedSignal("RallyCar"):Connect(function(car)
	cars[car] = nil
end)

-- фильтр лучей: машина + персонажи, обновляем раз в секунду
local filterAge = 0

RunService.RenderStepped:Connect(function(dt)
	filterAge -= dt
	local refresh = filterAge <= 0
	if refresh then
		filterAge = 1
	end
	local water = ReplicatedStorage:GetAttribute("WaterLevel") or -1000
	local characters = {}
	if refresh then
		for _, p in Players:GetPlayers() do
			if p.Character then
				table.insert(characters, p.Character)
			end
		end
	end

	for car, data in cars do
		local body = car.PrimaryPart
		if not body or not car.Parent then
			continue
		end
		if refresh then
			local list: { Instance } = { car }
			for _, ch in characters do
				table.insert(list, ch)
			end
			data.params.FilterDescendantsInstances = list
		end
		local cfg = CarConfig.TYPES[car:GetAttribute("CarType") or "Buran"] or CarConfig.TYPES.Buran
		local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat?
		local steer = car:GetAttribute("VisualSteer")
		if typeof(steer) ~= "number" then
			steer = (seat and seat.SteerFloat or 0) * math.rad(cfg.maxSteer) * 0.7
		end
		local throttle = car:GetAttribute("VisualThrottle")
		if typeof(throttle) ~= "number" then
			throttle = seat and math.max(seat.ThrottleFloat, 0) or 0
		end

		local cf = body.CFrame
		local up, fwd, right = cf.UpVector, cf.LookVector, cf.RightVector
		local speed = body.AssemblyLinearVelocity.Magnitude
		local active = not body.Anchored

		for name, w in data.wheels do
			local isFront = name == "FL" or name == "FR"
			local mount = cf:PointToWorldSpace(CarConfig.WHEELS[name])
			local hit = active and workspace:Raycast(mount, -up * (CarConfig.S_MAX + R), data.params) or nil
			if not active then
				local result = workspace:Raycast(mount, -up * (CarConfig.S_MAX + R), data.params)
				if result then
					w.length = math.clamp(result.Distance - R, CarConfig.S_MIN, CarConfig.S_MAX)
				end
			end
			local target = hit and math.clamp(hit.Distance - R, CarConfig.S_MIN, CarConfig.S_MAX) or (active and CarConfig.S_MAX or w.length)
			w.length += (target - w.length) * math.min(1, dt * 25)

			local center = mount - up * w.length
			local pv = body:GetVelocityAtPosition(center)
			local vLong = pv:Dot(fwd)
			local vLat = pv:Dot(right)
			local driven = (isFront and cfg.frontShare > 0) or (not isFront and cfg.frontShare < 1)
			local burn = driven and throttle > 0.5 and math.clamp(1 - speed / 45, 0, 1) or 0
			w.spin += (vLong / R + burn * 30) * dt
			w.joint.C0 = CarPhysics.wheelOffset(name, w.length, steer, w.spin)

			-- эффекты
			if hit then
				local contact = hit.Position
				local lp = cf:PointToObjectSpace(contact)
				w.fx.CFrame = CFrame.new(lp + Vector3.new(0, 0.3, 0)) * CFrame.Angles(math.rad(-25), 0, 0)
				w.trailA.Position = lp + Vector3.new(-0.55, 0.06, 0)
				w.trailB.Position = lp + Vector3.new(0.55, 0.06, 0)

				local slip = math.clamp(math.abs(vLat) / 18, 0, 1.5) + burn
				local looseColor = CarConfig.LOOSE[hit.Material]
				if looseColor and hit.Material ~= w.material then
					w.material = hit.Material
					w.dust.Color = ColorSequence.new(looseColor:Lerp(Color3.new(1, 1, 1), 0.25))
					w.clods.Color = ColorSequence.new(looseColor:Lerp(Color3.new(0, 0, 0), 0.25), looseColor)
					w.trail.Color = ColorSequence.new(looseColor:Lerp(Color3.new(0, 0, 0), 0.45))
				end
				if looseColor then
					w.dustAcc += (speed * 0.12 + slip * 14) * dt
					w.clodAcc += ((speed > 20 and speed * 0.18 or 0) + slip * 30 + burn * 25) * dt
				end
				if contact.Y < water + 0.4 and speed > 4 then
					w.splashAcc += speed * 0.35 * dt
				end
				w.trail.Enabled = looseColor ~= nil and slip > 0.35
			else
				w.trail.Enabled = false
			end
			if w.dustAcc >= 1 then
				local n = math.floor(w.dustAcc)
				w.dustAcc -= n
				w.dust:Emit(math.min(n, 4))
			end
			if w.clodAcc >= 1 then
				local n = math.floor(w.clodAcc)
				w.clodAcc -= n
				w.clods:Emit(math.min(n, 6))
			end
			if w.splashAcc >= 1 then
				local n = math.floor(w.splashAcc)
				w.splashAcc -= n
				w.splash:Emit(math.min(n, 6))
			end
		end
	end
end)
