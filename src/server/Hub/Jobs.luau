--!strict
-- NPC-работы в хабе. Сервер — единственный, кто решает, выполнен ли шаг и сколько платить.
-- Проверки: шаг соответствует текущей работе, игрок рядом с объектом, работа не выполнена
-- быстрее разумного, между работами перерыв.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local JobsCfg = require(Shared.Config.Jobs)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Tutorial = require(script.Parent.Parent.Tutorial)

type Active = {
	id: string,
	progress: number,
	carry: boolean,
	done: { [number]: boolean },
	started: number,
	prop: BasePart?,
}

local M = {}

local active: { [Player]: Active } = {}
local cooldown: { [Player]: number } = {}

local PROMPT_TAGS = {
	"JobCratePile",
	"JobCart",
	"JobTruck",
	"JobWarehouse",
	"JobShip",
	"JobDockStore",
	"JobFenceGap",
	"JobPlant",
}

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

-- Предмет в руках: ящик, посылка или метла
local function giveProp(player: Player, a: Active, kind: string)
	clearProp(a)
	local hrp = root(player)
	if not hrp then
		return
	end
	local p = Instance.new("Part")
	p.Name = "JobProp"
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Anchored = false
	local offset: CFrame
	if kind == "broom" then
		p.Size = Vector3.new(0.3, 5, 0.3)
		p.Color = Color3.fromRGB(150, 110, 60)
		offset = CFrame.new(1.4, -0.6, -1.2) * CFrame.Angles(0.5, 0, 0)
	elseif kind == "parcel" then
		p.Size = Vector3.new(1.6, 1.2, 1.2)
		p.Color = Color3.fromRGB(200, 170, 120)
		offset = CFrame.new(0, 0, -1.4)
	else
		p.Size = Vector3.new(2, 2, 2)
		p.Color = Color3.fromRGB(190, 145, 85)
		p.Material = Enum.Material.WoodPlanks
		offset = CFrame.new(0, 0.4, -1.6)
	end
	p.CFrame = hrp.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = p
	weld.Parent = p
	p.Parent = player.Character
	a.prop = p
end

local function finish(player: Player, a: Active)
	local job = JobsCfg.byId[a.id]
	clearProp(a)
	active[player] = nil
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

local function near(player: Player, part: BasePart, radius: number): boolean
	local hrp = root(player)
	if not hrp then
		return false
	end
	local d = hrp.Position - part.Position
	return Vector3.new(d.X, 0, d.Z).Magnitude <= radius
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
	if job.kind == "carry" then
		if tag == job.pickup and not a.carry then
			a.carry = true
			giveProp(player, a, "crate")
			syncAttributes(player)
		elseif tag == job.drop and a.carry then
			a.carry = false
			clearProp(a)
			advance(player, a)
		end
	elseif job.kind == "prompts" and tag == job.target then
		local n = prompt:GetAttribute("N")
		if type(n) == "number" and not a.done[n] then
			a.done[n] = true
			advance(player, a)
		end
	end
end

-- Точки маршрута по тегу, упорядоченные по атрибуту N
local function routePoints(tag: string): { [number]: BasePart }
	local pts = {}
	for _, inst in CollectionService:GetTagged(tag) do
		local n = inst:GetAttribute("N")
		if inst:IsA("BasePart") and type(n) == "number" then
			pts[n] = inst
		end
	end
	return pts
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
	local a: Active = { id = id, progress = 0, carry = false, done = {}, started = os.clock() }
	active[player] = a
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
	clearProp(a)
	active[player] = nil
	syncAttributes(player)
	return true, nil
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

	-- маршруты: проверяем, дошёл ли игрок до следующей точки
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		for player, a in active do
			local job = JobsCfg.byId[a.id]
			if job.kind == "route" and job.target then
				local pts = routePoints(job.target)
				local nextPoint = pts[a.progress + 1]
				if nextPoint and near(player, nextPoint, JobsCfg.ROUTE_RADIUS) then
					if a.id == "parcel" and a.progress == 0 then
						giveProp(player, a, "parcel")
					end
					advance(player, a)
				end
			end
		end
	end)

	PlayerState.addExtra(function(player, s)
		local cd = cooldown[player]
		s.jobCooldown = if cd then math.max(0, cd - os.clock()) else 0
	end)

	Players.PlayerRemoving:Connect(function(player)
		local a = active[player]
		if a then
			clearProp(a)
		end
		active[player] = nil
		cooldown[player] = nil
	end)
end

-- После смерти персонажа предмет пропадает — сбрасываем груз
function M.onCharacter(player: Player)
	local a = active[player]
	if not a then
		return
	end
	a.prop = nil
	if a.carry then
		a.carry = false
	end
	if a.id == "sweep" then
		giveProp(player, a, "broom")
	elseif a.id == "parcel" and a.progress > 0 then
		giveProp(player, a, "parcel")
	end
	syncAttributes(player)
end

return M
