--!strict
-- NPC-работы в хабе. Сервер — единственный, кто решает, выполнен ли шаг и сколько платить.
-- Транспортные работы: игрока сразу сажают в служебную машину; груз грузится, когда машина
-- стоит в зоне погрузки, и выгружается в зоне разгрузки. Пешие работы — подсказки «E».
-- Проверки: шаг соответствует работе, игрок/машина рядом, не быстрее физически возможного.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local JobsCfg = require(Shared.Config.Jobs)
local VConfig = require(Shared.Vehicles.Config)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Tutorial = require(script.Parent.Parent.Tutorial)
local Vehicles = require(script.Parent.Parent.Vehicles.Vehicles)

type Active = {
	id: string,
	progress: number,
	carry: boolean,
	done: { [number]: boolean },
	started: number,
	prop: BasePart?,
	vehicle: Model?,
	dwell: number,
}

local M = {}

local active: { [Player]: Active } = {}
local cooldown: { [Player]: number } = {}

local PROMPT_TAGS = { "JobFenceGap", "JobPlant" }

local function root(player: Player): BasePart?
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		return hrp
	end
	return nil
end

local function syncAttributes(player: Player)
	local a = active[player]
	player:SetAttribute("Job", if a then a.id else "")
	player:SetAttribute("JobProgress", if a then a.progress else 0)
	player:SetAttribute("JobCarry", if a then a.carry else false)
	local done = {}
	if a then
		for n in a.done do
			table.insert(done, tostring(n))
		end
	end
	player:SetAttribute("JobDone", table.concat(done, ","))
	PlayerState.markDirty(player)
end

local function clearProp(a: Active)
	if a.prop then
		a.prop:Destroy()
		a.prop = nil
	end
end

-- Груз на машине (ящик на вилах / в кузове) или метла в руках
local function giveProp(player: Player, a: Active, kind: string)
	clearProp(a)
	local anchor: BasePart? = nil
	local offset = CFrame.new()
	local p = Instance.new("Part")
	p.Name = "JobProp"
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	if kind == "broom" then
		anchor = root(player)
		p.Size = Vector3.new(0.3, 5, 0.3)
		p.Color = Color3.fromRGB(150, 110, 60)
		offset = CFrame.new(1.4, -0.6, -1.2) * CFrame.Angles(0.5, 0, 0)
	else
		local car = a.vehicle
		anchor = car and car.PrimaryPart
		local vt = car and car:GetAttribute("VehicleType")
		local t = if type(vt) == "string" then VConfig.TYPES[vt] else nil
		p.Size = if kind == "parcel" then Vector3.new(3, 2, 3) else Vector3.new(3, 3, 3)
		p.Color = if kind == "parcel" then Color3.fromRGB(200, 170, 120) else Color3.fromRGB(190, 145, 85)
		p.Material = Enum.Material.WoodPlanks
		offset = CFrame.new(if t then t.cargo else Vector3.zero) * CFrame.new(0, p.Size.Y / 2, 0)
	end
	if not anchor then
		p:Destroy()
		return
	end
	p.CFrame = anchor.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = p
	weld.Parent = p
	p.Parent = if kind == "broom" then player.Character else a.vehicle
	a.prop = p
end

local function endJob(player: Player, a: Active)
	clearProp(a)
	if a.vehicle then
		Vehicles.remove(a.vehicle)
		a.vehicle = nil
	end
	active[player] = nil
end

local function finish(player: Player, a: Active)
	local job = JobsCfg.byId[a.id]
	endJob(player, a)
	local elapsed = os.clock() - a.started
	cooldown[player] = os.clock() + JobsCfg.COOLDOWN
	if elapsed < job.minTime then
		warn(string.format("Работа %s выполнена подозрительно быстро: %s за %.1f c", job.id, player.Name, elapsed))
		PlayerState.notify(player, "job.too_fast", nil, "error")
		syncAttributes(player)
		return
	end
	local d = PlayerState.data(player)
	if d then
		d.jobsDone += 1
	end
	PlayerState.addMoney(player, job.pay)
	PlayerState.notify(player, "job.done", { pay = job.pay }, "money")
	syncAttributes(player)
	Tutorial.event(player, "jobDone")
end

local function advance(player: Player, a: Active)
	a.progress += 1
	local job = JobsCfg.byId[a.id]
	if a.progress >= job.count then
		finish(player, a)
	else
		syncAttributes(player)
	end
end

local function flatDist(a: Vector3, b: Vector3): number
	local d = a - b
	return Vector3.new(d.X, 0, d.Z).Magnitude
end

local function near(player: Player, part: BasePart, radius: number): boolean
	local hrp = root(player)
	return hrp ~= nil and flatDist(hrp.Position, part.Position) <= radius
end

local function onPrompt(prompt: ProximityPrompt, tag: string, player: Player)
	local a = active[player]
	if not a then
		return
	end
	local parent = prompt.Parent
	if not parent or not parent:IsA("BasePart") then
		return
	end
	if not near(player, parent, prompt.MaxActivationDistance + 6) then
		return
	end
	local job = JobsCfg.byId[a.id]
	if job.kind == "prompts" and tag == job.target then
		local n = prompt:GetAttribute("N")
		if type(n) == "number" and not a.done[n] then
			a.done[n] = true
			advance(player, a)
		end
	end
end

local function firstTagged(tag: string, filter: ((Instance) -> boolean)?): BasePart?
	for _, inst in CollectionService:GetTagged(tag) do
		if inst:IsA("BasePart") and (not filter or filter(inst)) then
			return inst
		end
	end
	return nil
end

function M.take(player: Player, id: any): (boolean, string?)
	if type(id) ~= "string" or not JobsCfg.byId[id] then
		return false, "err.bad"
	end
	if active[player] then
		return false, "job.busy"
	end
	local cd = cooldown[player]
	if cd and os.clock() < cd then
		return false, "job.cooldown"
	end
	if not root(player) then
		return false, "err.bad"
	end
	local job = JobsCfg.byId[id]
	local a: Active = { id = id, progress = 0, carry = false, done = {}, started = os.clock(), dwell = 0 }
	active[player] = a
	if job.vehicle and job.spawn then
		local spot = firstTagged(job.spawn)
		if spot then
			a.vehicle = Vehicles.spawn(player, job.vehicle, spot.CFrame, true)
		end
	end
	if id == "sweep" then
		giveProp(player, a, "broom")
	end
	syncAttributes(player)
	Tutorial.event(player, "jobTaken")
	return true, nil
end

function M.cancel(player: Player): (boolean, string?)
	local a = active[player]
	if not a then
		return false, nil
	end
	endJob(player, a)
	syncAttributes(player)
	return true, nil
end

-- Проверка зон и точек маршрута (раз в 0.2 с)
local function check(player: Player, a: Active, dt: number)
	local job = JobsCfg.byId[a.id]
	if job.kind == "haul" then
		local car = a.vehicle
		local body = car and car.PrimaryPart
		if not car or not body or Vehicles.driving(player) ~= car then
			a.dwell = 0
			return
		end
		local zoneTag = if a.carry then job.drop else job.pickup
		local zone = zoneTag and firstTagged(zoneTag)
		if not zone then
			return
		end
		local slow = body.AssemblyLinearVelocity.Magnitude < JobsCfg.ZONE_MAX_SPEED
		if slow and flatDist(body.Position, zone.Position) <= JobsCfg.ZONE_RADIUS then
			a.dwell += dt
			if a.dwell >= JobsCfg.ZONE_DWELL then
				a.dwell = 0
				if a.carry then
					a.carry = false
					clearProp(a)
					advance(player, a)
				else
					a.carry = true
					giveProp(player, a, "crate")
					syncAttributes(player)
				end
			end
		else
			a.dwell = 0
		end
	elseif job.kind == "route" and job.target then
		local nextN = a.progress + 1
		local point = firstTagged(job.target, function(inst)
			return inst:GetAttribute("N") == nextN
		end)
		if not point then
			return
		end
		local pos: Vector3?
		local radius = JobsCfg.ROUTE_RADIUS
		if a.vehicle then
			local body = a.vehicle.PrimaryPart
			pos = if body and Vehicles.driving(player) == a.vehicle then body.Position else nil
			radius = JobsCfg.VEHICLE_RADIUS
		else
			local hrp = root(player)
			pos = hrp and hrp.Position
		end
		if pos and flatDist(pos, point.Position) <= radius then
			if a.id == "parcel" and a.progress == 0 then
				giveProp(player, a, "parcel")
			end
			advance(player, a)
		end
	end
end

function M.start()
	for _, tag in PROMPT_TAGS do
		local function hook(inst: Instance)
			if inst:IsA("ProximityPrompt") then
				inst.Triggered:Connect(function(player)
					onPrompt(inst, tag, player)
				end)
			end
		end
		for _, inst in CollectionService:GetTagged(tag) do
			hook(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
	end

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		local step = acc
		acc = 0
		for player, a in active do
			check(player, a, step)
		end
	end)

	PlayerState.addExtra(function(player, s)
		local cd = cooldown[player]
		s.jobCooldown = if cd then math.max(0, cd - os.clock()) else 0
	end)

	Players.PlayerRemoving:Connect(function(player)
		local a = active[player]
		if a then
			endJob(player, a)
		end
		cooldown[player] = nil
	end)
end

-- После смерти персонажа: метла заново, служебная машина ждёт на месте
function M.onCharacter(player: Player)
	local a = active[player]
	if not a then
		return
	end
	if a.id == "sweep" then
		a.prop = nil
		giveProp(player, a, "broom")
	end
	syncAttributes(player)
end

return M
