--!nonstrict
-- Полёт на клиенте: тряпичная кукла летит по дуге, игрок рулит влево-вправо, ловит кольца,
-- отскакивает от земли. Приземление ловим лучом заранее (на больших скоростях физика проваливается).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Ui)

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local M = {}
M.active = false
M.onZone = nil :: ((number) -> ())?
M.onRing = nil :: ((number) -> ())?
M.onBounce = nil :: (() -> ())?
M.onLand = nil :: ((number) -> ())?
M.dist = 0
M.speed = 0
M.rings = 0

local landEv = Net.event("Land")

local controls: any = nil
task.spawn(function()
	local ok, pm = pcall(function()
		return (require :: any)(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and pm then
		controls = pm:GetControls()
	end
end)

local function moveX(): number
	if not controls then
		return 0
	end
	local ok, mv = pcall(function()
		return controls:GetMoveVector()
	end)
	if not ok or not mv then
		return 0
	end
	return mv.X
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

local function groundParts(): { Instance }
	local list = {}
	local world = workspace:FindFirstChild("World")
	if world then
		local field = world:FindFirstChild("Field")
		local plaza = world:FindFirstChild("Plaza")
		if field then
			for _, p in field:GetChildren() do
				if p:IsA("BasePart") and p.Name == "Ground" then
					table.insert(list, p)
				end
			end
		end
		if plaza then
			local base = plaza:FindFirstChild("Plaza")
			if base then
				table.insert(list, base)
			end
		end
	end
	return list
end

-- ===== кольца =====

type Ring = { model: Model, center: Vector3, t: number, id: number? }
local rings: { Ring } = {}

local function makeRing(center: Vector3, dir: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "Ring"
	local r = Config.RING_RADIUS
	local look = CFrame.lookAt(center, center + dir)
	for i = 0, 13 do
		local a = i / 14 * math.pi * 2
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Material = Enum.Material.Neon
		p.Color = Color3.fromRGB(255, 214, 70)
		p.Size = Vector3.new(1.6, 6.2, 1.6)
		p.CFrame = look * CFrame.new(math.cos(a) * r, math.sin(a) * r, 0) * CFrame.Angles(0, 0, a)
		p.Parent = m
	end
	m.Parent = workspace
	return m
end

local function clearRings()
	for _, r in rings do
		r.model:Destroy()
	end
	table.clear(rings)
end

-- ===== эффекты =====

local function zoneSky(z: number)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atm then
		return
	end
	local zone = Config.ZONES[Config.zoneAt(z)]
	atm.Color = atm.Color:Lerp(zone.sky, 0.03)
end

-- ===== сам полёт =====

local conn: RBXScriptConnection? = nil

function M.start(p: { id: number, origin: Vector3, vel: Vector3, g: number, bounces: number, d: number, rings: { Vector3 }?, race: boolean? })
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hrp or not hum then
		landEv:FireServer(p.id, 0, 0)
		return
	end
	M.active = true
	M.rings = 0
	M.dist = 0
	clearRings()
	rayParams.FilterDescendantsInstances = groundParts()

	hum:ChangeState(Enum.HumanoidStateType.Physics)
	hum.PlatformStand = true
	local origin = p.origin
	local pos = origin
	local vel = p.vel
	local g = p.g
	local bounces = p.bounces
	local spin = Vector3.new(math.random(-8, 8), math.random(-3, 3), math.random(-8, 8))
	char:PivotTo(CFrame.lookAt(pos, pos + vel))
	for _, part in char:GetDescendants() do
		if part:IsA("BasePart") then
			part.AssemblyLinearVelocity = vel
		end
	end
	Ui.sfx("boom", 0.8)
	Ui.sfx("whoosh", 0.7)

	camera.CameraType = Enum.CameraType.Scriptable
	local camPos = camera.CFrame.Position
	local nextRing = 0.8
	local t = 0
	local zone = Config.zoneAt(0)
	local landed = false
	local landT = 0
	local reported = false
	local lateral = 0
	local shake = 0
	local raceRings = p.rings
	local caught: { number } = {}
	if raceRings then
		-- гонка: все кольца известны заранее и одинаковы для всех
		for i, c in raceRings do
			table.insert(rings, { model = makeRing(c, p.vel.Unit), center = c, t = 0, id = i })
		end
	end

	local function report(z: number)
		if reported then
			return
		end
		reported = true
		landEv:FireServer(p.id, z, if raceRings then caught else M.rings)
		if M.onLand then
			M.onLand(math.max(0, z - origin.Z))
		end
	end

	if conn then
		conn:Disconnect()
	end
	conn = RunService.PreSimulation:Connect(function(dt)
		if not hrp.Parent then
			if conn then
				conn:Disconnect()
				conn = nil
			end
			M.active = false
			report(pos.Z)
			return
		end
		t += dt
		if not landed then
			-- руление
			local mx = moveX()
			-- камера смотрит вдоль +Z, поэтому «вправо» на экране — это -X в мире
			lateral = math.clamp(lateral - mx * 90 * dt, -55, 55)
			lateral *= (1 - math.min(dt * 1.5, 1))
			vel = Vector3.new(lateral, vel.Y - g * dt, vel.Z)
			local nextPos = pos + vel * dt
			if math.abs(nextPos.X) > Config.MAP_HALF_WIDTH - 8 then
				nextPos = Vector3.new(math.clamp(nextPos.X, -Config.MAP_HALF_WIDTH + 8, Config.MAP_HALF_WIDTH - 8), nextPos.Y, nextPos.Z)
				lateral = 0
			end
			if nextPos.Z > Config.MAP_END + 60 then
				nextPos = Vector3.new(nextPos.X, nextPos.Y, Config.MAP_END + 60)
				vel = Vector3.new(vel.X, math.min(vel.Y, 0), 0)
			end
			-- земля впереди?
			local step = nextPos - pos
			local look = step.Magnitude + 4
			local hit = workspace:Raycast(pos, if step.Magnitude > 0.01 then step.Unit * look else Vector3.new(0, -look, 0), rayParams)
			if hit and vel.Y < 0 then
				nextPos = hit.Position + Vector3.new(0, 3, 0)
				if bounces > 0 and math.abs(vel.Y) > 25 then
					bounces -= 1
					vel = Vector3.new(vel.X, -vel.Y * Config.BOUNCE_KEEP_V, vel.Z * Config.BOUNCE_KEEP_H)
					shake = 0.6
					Ui.sfx("pop", 0.8, 0.8 + math.random() * 0.3)
					if M.onBounce then
						M.onBounce()
					end
				else
					landed = true
					landT = t
					shake = 1
					Ui.sfx("land", 0.8)
					report(nextPos.Z)
					for _, part in char:GetDescendants() do
						if part:IsA("BasePart") then
							part.AssemblyLinearVelocity = Vector3.new(vel.X * 0.1, 10, math.min(vel.Z * 0.08, 60))
						end
					end
				end
			end
			if t > 75 then
				landed = true
				landT = t
				report(nextPos.Z)
			end
			pos = nextPos
			if not landed then
				-- корень куклы тянем к расчётной точке, конечности болтаются сами
				local err = pos - hrp.Position
				hrp.AssemblyLinearVelocity = vel + err * 12
				hrp.AssemblyAngularVelocity = spin
			end
			M.dist = math.max(0, pos.Z - origin.Z)
			M.speed = vel.Magnitude
			-- зоны
			local z = Config.zoneAt(M.dist)
			if z ~= zone then
				zone = z
				if M.onZone then
					M.onZone(z)
				end
			end
			zoneSky(M.dist)
			-- кольца
			nextRing -= dt
			if nextRing <= 0 and not landed and not raceRings then
				nextRing = Config.RING_EVERY
				local ahead = 1.1
				local pred = pos + vel * ahead + Vector3.new(0, -0.5 * g * ahead * ahead, 0)
				if pred.Y > 25 then
					local off = (math.random() * 2 - 1) * 26
					local x = math.clamp(pred.X + off, -Config.MAP_HALF_WIDTH + 20, Config.MAP_HALF_WIDTH - 20)
					local c = Vector3.new(x, pred.Y, pred.Z)
					local fwd = vel + Vector3.new(0, -g * ahead, 0)
					table.insert(rings, { model = makeRing(c, fwd.Unit), center = c, t = t })
				end
			end
			for i = #rings, 1, -1 do
				local r = rings[i]
				if (r.center - hrp.Position).Magnitude < Config.RING_RADIUS + 4 then
					M.rings += 1
					if r.id then
						table.insert(caught, r.id)
					end
					r.model:Destroy()
					table.remove(rings, i)
					Ui.sfx("coin", 0.8, 1 + M.rings * 0.05)
					if M.onRing then
						M.onRing(M.rings)
					end
				elseif not raceRings and t - r.t > 3.5 then
					r.model:Destroy()
					table.remove(rings, i)
				end
			end
		elseif t - landT > 3 then
			if conn then
				conn:Disconnect()
				conn = nil
			end
		end
		-- камера
		local target = hrp.Position
		local flat = Vector3.new(vel.X * 0.3, 0, math.max(vel.Z, 1))
		flat = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
		local back = math.clamp(28 + M.speed * 0.025, 28, 70)
		local want = target - flat * back + Vector3.new(0, 10 + back * 0.25, 0)
		camPos = camPos:Lerp(want, math.min(dt * (if landed then 3 else 9), 1))
		shake = math.max(0, shake - dt * 2)
		local jitter = if shake > 0 then Vector3.new(math.random() - 0.5, math.random() - 0.5, 0) * shake * 2 else Vector3.zero
		camera.CFrame = CFrame.lookAt(camPos + jitter, target + flat * 12)
		camera.FieldOfView = camera.FieldOfView + ((70 + math.min(M.speed / 30, 25)) - camera.FieldOfView) * math.min(dt * 3, 1)
	end)
end

function M.stop()
	if conn then
		conn:Disconnect()
		conn = nil
	end
	clearRings()
	M.active = false
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		atm.Color = Config.ZONES[1].sky:Lerp(Color3.fromRGB(190, 225, 255), 0.6)
	end
end

return M
