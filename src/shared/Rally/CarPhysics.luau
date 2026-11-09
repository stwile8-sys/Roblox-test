-- Физика машины: подвеска на лучах и модель шин.
-- Запускается там, где у машины владелец физики: у водителя на клиенте
-- или на сервере, пока машина пустая.

local CarConfig = require(script.Parent.CarConfig)

local CarPhysics = {}

local R = CarConfig.WHEEL_RADIUS
local S_MIN, S_MAX = CarConfig.S_MIN, CarConfig.S_MAX

export type Input = {
	throttle: number, -- 0..1
	brake: number, -- 0..1 (на месте — задний ход)
	steer: number, -- −1..1, плюс — вправо
	handbrake: boolean,
}

export type WheelState = {
	grounded: boolean,
	length: number, -- текущая длина подвески
	spin: number, -- угол вращения (рад)
	slip: number, -- 0..1+, для эффектов
	material: Enum.Material?,
	contact: Vector3?,
}

export type State = {
	steer: number,
	wheels: { [string]: WheelState },
	params: RaycastParams,
	speed: number,
	grounded: number,
	paramsAge: number,
}

function CarPhysics.newState(car: Model): State
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { car }
	params.IgnoreWater = true
	local wheels = {}
	for _, name in CarConfig.WHEEL_ORDER do
		wheels[name] = { grounded = false, length = S_MAX, spin = 0, slip = 0, material = nil, contact = nil }
	end
	return { steer = 0, wheels = wheels, params = params, speed = 0, grounded = 0, paramsAge = 0 }
end

local function refreshFilter(car: Model, state: State)
	local list: { Instance } = { car }
	for _, other in game:GetService("Players"):GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	state.params.FilterDescendantsInstances = list
end

local function sign(x: number): number
	return x > 0 and 1 or (x < 0 and -1 or 0)
end

function CarPhysics.step(car: Model, input: Input, dt: number, state: State)
	local body = car.PrimaryPart
	if not body or body.Anchored or dt <= 0 then
		return
	end
	local cfg = CarConfig.TYPES[car:GetAttribute("CarType") or "Buran"] or CarConfig.TYPES.Buran

	state.paramsAge -= dt
	if state.paramsAge <= 0 then
		state.paramsAge = 1
		refreshFilter(car, state)
	end

	local mass = body.AssemblyMass
	local quarter = mass / 4
	local g = workspace.Gravity
	local k = quarter * g / CarConfig.REST_COMPRESSION
	local c = 2 * math.sqrt(k * quarter) * 0.55

	local cf = body.CFrame
	local up, fwd = cf.UpVector, cf.LookVector
	local vel = body.AssemblyLinearVelocity
	local speed = vel.Magnitude
	local speedFwd = vel:Dot(fwd)
	state.speed = speedFwd

	-- руль: меньше угол на скорости, плавная перекладка
	local maxSteer = math.rad(cfg.maxSteer) * (1 - 0.62 * math.clamp(speed / 130, 0, 1))
	local target = math.clamp(input.steer, -1, 1) * maxSteer
	local rate = 2.6 * dt
	state.steer += math.clamp(target - state.steer, -rate, rate)

	-- газ, тормоз, задний ход
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
	elseif drive < 0 and absV < 32 then
		engine = drive * cfg.accel * mass
	end

	local grounded = 0
	local steerRot = CFrame.fromAxisAngle(up, -state.steer)
	for _, name in CarConfig.WHEEL_ORDER do
		local w = state.wheels[name]
		local isFront = name == "FL" or name == "FR"
		local mount = cf:PointToWorldSpace(CarConfig.WHEELS[name])
		local result = workspace:Raycast(mount, -up * (S_MAX + R), state.params)
		if not result then
			w.grounded = false
			w.length = S_MAX
			w.slip = 0
			w.contact = nil
			w.spin += speedFwd / R * dt
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
		local wf = isFront and steerRot:VectorToWorldSpace(fwd) or fwd
		wf = wf - n * wf:Dot(n)
		if wf.Magnitude < 1e-3 then
			wf = fwd
		end
		wf = wf.Unit
		local wr = wf:Cross(n).Unit

		local vLong = pv:Dot(wf)
		local vLat = pv:Dot(wr)
		local surface = CarConfig.SURFACE[result.Material] or CarConfig.DEFAULT_SURFACE
		local maxF = cfg.grip * surface * springF

		-- продольная сила
		local share = isFront and cfg.frontShare or (1 - cfg.frontShare)
		local fx = engine * share / 2
		local stopLong = math.abs(vLong) * quarter / dt
		if brake > 0 then
			fx -= sign(vLong) * math.min(brake * cfg.brake * quarter, stopLong)
		end
		local hand = input.handbrake and not isFront
		if hand then
			fx = -sign(vLong) * math.min(maxF * 0.9, stopLong)
		end
		fx -= vLong * 0.15 * quarter -- сопротивление качению

		-- боковая сила (упрощённая формула Пацейки)
		local slipAngle = math.atan2(vLat, math.max(math.abs(vLong), 5))
		local curve = math.sin(1.35 * math.atan(9 * slipAngle))
		local fy = -maxF * (hand and 0.42 or 1) * curve
		local stopLat = math.abs(vLat) * quarter / dt
		fy = math.clamp(fy, -stopLat, stopLat)

		-- круг трения: тяга «съедает» боковое сцепление
		local total = math.sqrt(fx * fx + fy * fy)
		local excess = 0
		if total > maxF and total > 0 then
			excess = (total - maxF) / math.max(maxF, 1)
			local scale = maxF * 0.92 / total
			fx *= scale
			fy *= scale
		end

		body:ApplyImpulseAtPosition((up * springF + wf * fx + wr * fy) * dt, center)

		w.grounded = true
		w.length = length
		w.material = result.Material
		w.contact = result.Position
		w.slip = math.clamp(math.abs(slipAngle) * 2.5 + excess * 1.5 + (hand and absV > 5 and 0.6 or 0), 0, 2)
		local spinSpeed = vLong / R
		if excess > 0 and share > 0 and drive ~= 0 then
			spinSpeed += sign(drive) * excess * 25
		end
		if hand and absV > 1 then
			spinSpeed = 0
		end
		w.spin += spinSpeed * dt
	end
	state.grounded = grounded

	-- аэродинамика
	local dragK = cfg.power / (cfg.topSpeed ^ 3)
	body:ApplyImpulse((-vel * speed * dragK - up * speed * speed * 0.0018) * mass * dt)

	-- в полёте: мягко выравниваем машину и гасим вращение
	local angVel = body.AssemblyAngularVelocity
	if grounded == 0 then
		local axis = up:Cross(Vector3.yAxis)
		local torque = (axis * 5 - angVel * 1.2) * mass * 14
		body:ApplyAngularImpulse(torque * dt)
	elseif grounded <= 2 then
		local axis = up:Cross(Vector3.yAxis)
		body:ApplyAngularImpulse(axis * mass * 30 * dt)
	end
end

-- Поза колеса для отрисовки (локально относительно кузова).
function CarPhysics.wheelOffset(name: string, length: number, steer: number, spin: number): CFrame
	local isFront = name == "FL" or name == "FR"
	local mount = CarConfig.WHEELS[name]
	return CFrame.new(mount - Vector3.new(0, length, 0)) * CFrame.Angles(0, isFront and -steer or 0, 0) * CFrame.Angles(-spin, 0, 0)
end

return CarPhysics
