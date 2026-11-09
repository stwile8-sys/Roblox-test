--!strict
-- Физика транспорта: подвеска на лучах и модель шин (основа — физика машин из ралли).
-- Считается у того, кто владеет физикой машины: у водителя на клиенте.

local Config = require(script.Parent.Config)

local M = {}

export type Input = {
	throttle: number, -- 0..1
	brake: number, -- 0..1 (на месте — задний ход)
	steer: number, -- −1..1, плюс — вправо
	handbrake: boolean,
}

export type State = {
	steer: number,
	params: RaycastParams,
	speed: number,
	grounded: number,
	paramsAge: number,
}

function M.newState(car: Model): State
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car }
	params.IgnoreWater = true
	return { steer = 0, params = params, speed = 0, grounded = 0, paramsAge = 0 }
end

local function refreshFilter(car: Model, state: State)
	local list: { Instance } = { car }
	for _, other in game:GetService("Players"):GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	local preview = workspace:FindFirstChild("BuildOverlay")
	if preview then
		table.insert(list, preview)
	end
	state.params.FilterDescendantsInstances = list
end

local function sign(x: number): number
	return if x > 0 then 1 elseif x < 0 then -1 else 0
end

function M.step(car: Model, input: Input, dt: number, state: State)
	local body = car.PrimaryPart
	if not body or body.Anchored or dt <= 0 then
		return
	end
	local vt = car:GetAttribute("VehicleType")
	local cfg = (if type(vt) == "string" then Config.TYPES[vt] else nil) or Config.TYPES.van
	local R, S_MIN, S_MAX = cfg.radius, cfg.sMin, cfg.sMax

	state.paramsAge -= dt
	if state.paramsAge <= 0 then
		state.paramsAge = 1
		refreshFilter(car, state)
	end

	local mass = body.AssemblyMass
	local quarter = mass / 4
	local g = workspace.Gravity
	local k = quarter * g / cfg.rest
	local c = 2 * math.sqrt(k * quarter) * 0.6

	local cf = body.CFrame
	local up, fwd = cf.UpVector, cf.LookVector
	local vel = body.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local speedFwd = vel:Dot(fwd)
	state.speed = speedFwd

	local maxSteer = math.rad(cfg.maxSteer) * (1 - 0.55 * math.clamp(speed / cfg.topSpeed, 0, 1))
	local target = math.clamp(input.steer, -1, 1) * maxSteer
	local rate = 2.8 * dt
	state.steer += math.clamp(target - state.steer, -rate, rate)

	local drive, brake = input.throttle, input.brake
	if speedFwd < -1.5 and input.throttle > 0 then
		brake, drive = input.throttle, 0
	elseif speedFwd < 2 and input.brake > 0 and input.throttle == 0 then
		drive, brake = -input.brake * 0.6, 0
	end
	local absV = math.abs(speedFwd)
	local engine = 0
	if drive > 0 then
		engine = drive * math.min(cfg.accel, cfg.power / math.max(absV, 1)) * mass
	elseif drive < 0 and absV < cfg.topSpeed * 0.3 then
		engine = drive * cfg.accel * mass
	end

	local grounded = 0
	local steerRot = CFrame.fromAxisAngle(up, -state.steer)
	for _, name in Config.WHEEL_ORDER do
		local isFront = name == "FL" or name == "FR"
		local mount = cf:PointToWorldSpace(cfg.wheels[name])
		local result = workspace:Raycast(mount, -up * (S_MAX + R), state.params)
		if not result then
			continue
		end
		grounded += 1
		local s = result.Distance - R
		local length = math.max(s, S_MIN)
		local compression = S_MAX - length
		local center = mount - up * length
		local pv = body:GetVelocityAtPosition(center)

		local springF = k * compression - c * pv:Dot(up)
		if s < S_MIN then
			springF += k * 8 * (S_MIN - s)
		end
		springF = math.max(springF, 0)

		local n = result.Normal
		local wf = if isFront then steerRot:VectorToWorldSpace(fwd) else fwd
		wf = wf - n * wf:Dot(n)
		if wf.Magnitude < 1e-3 then
			wf = fwd
		end
		wf = wf.Unit
		local wr = wf:Cross(n).Unit

		local vLong = pv:Dot(wf)
		local vLat = pv:Dot(wr)
		local surface = Config.SURFACE[result.Material] or Config.DEFAULT_SURFACE
		local maxF = cfg.grip * surface * springF

		local share = if isFront then cfg.frontShare else (1 - cfg.frontShare)
		local fx = engine * share / 2
		local stopLong = math.abs(vLong) * quarter / dt
		if brake > 0 then
			fx -= sign(vLong) * math.min(brake * cfg.brake * quarter, stopLong)
		end
		local hand = input.handbrake and not isFront
		if hand then
			fx = -sign(vLong) * math.min(maxF * 0.9, stopLong)
		end
		fx -= vLong * 0.2 * quarter -- сопротивление качению

		local slipAngle = math.atan2(vLat, math.max(math.abs(vLong), 5))
		local curve = math.sin(1.35 * math.atan(9 * slipAngle))
		local fy = -maxF * (if hand then 0.42 else 1) * curve
		local stopLat = math.abs(vLat) * quarter / dt
		fy = math.clamp(fy, -stopLat, stopLat)

		local total = math.sqrt(fx * fx + fy * fy)
		if total > maxF and total > 0 then
			local scale = maxF * 0.92 / total
			fx *= scale
			fy *= scale
		end

		body:ApplyImpulseAtPosition((up * springF + wf * fx + wr * fy) * dt, center)
	end
	state.grounded = grounded

	-- сопротивление воздуха и прижим
	local dragK = cfg.power / (cfg.topSpeed ^ 3)
	body:ApplyImpulse((-vel * speed * dragK - up * speed * speed * 0.002) * mass * dt)

	-- в полёте и на двух колёсах — мягко выравниваем
	local angVel = body.AssemblyAngularVelocity
	if grounded == 0 then
		local axis = up:Cross(Vector3.yAxis)
		body:ApplyAngularImpulse((axis * 5 - angVel * 1.2) * mass * 14 * dt)
	elseif grounded <= 2 then
		local axis = up:Cross(Vector3.yAxis)
		body:ApplyAngularImpulse(axis * mass * 30 * dt)
	end
end

return M
