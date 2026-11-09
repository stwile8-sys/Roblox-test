--!nonstrict
-- Мир глазами игрока: переводы подсказок «E», какие подсказки видны для текущей работы,
-- таблички участков, указатель цели (работа и туториал).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local L = require(Shared.Lang.L)
local JobsCfg = require(Shared.Config.Jobs)
local Map = require(Shared.Config.Map)
local Store = require(script.Parent.Store)

local player = Players.LocalPlayer
local M = {}

local PROMPT_TAGS = {
	"UiPrompt",
	"JobFenceGap",
	"JobPlant",
}

local prompts: { [ProximityPrompt]: string } = {}

local function jobState(): (string, number, boolean, { [number]: boolean })
	local id = player:GetAttribute("Job")
	local progress = player:GetAttribute("JobProgress")
	local carry = player:GetAttribute("JobCarry")
	local doneStr = player:GetAttribute("JobDone")
	local done = {}
	if type(doneStr) == "string" then
		for n in string.gmatch(doneStr, "%d+") do
			done[tonumber(n) :: number] = true
		end
	end
	return if type(id) == "string" then id else "", if type(progress) == "number" then progress else 0, carry == true, done
end

local function promptVisible(prompt: ProximityPrompt, tag: string): boolean
	if tag == "UiPrompt" then
		return true
	end
	local id, _, carry, done = jobState()
	local job = JobsCfg.byId[id]
	if not job then
		return false
	end
	local _ = carry
	if job.kind == "prompts" then
		local n = prompt:GetAttribute("N")
		return tag == job.target and type(n) == "number" and not done[n]
	end
	return false
end

local function refreshPrompt(prompt: ProximityPrompt, tag: string)
	local key = prompt:GetAttribute("Key")
	if type(key) == "string" then
		prompt.ActionText = L.t(key)
	end
	local id = jobState()
	prompt.ObjectText = if tag ~= "UiPrompt" and id ~= "" then L.t("job." .. id) else ""
	prompt.Enabled = promptVisible(prompt, tag)
end

local function refreshAllPrompts()
	for prompt, tag in prompts do
		if prompt.Parent then
			refreshPrompt(prompt, tag)
		else
			prompts[prompt] = nil
		end
	end
end

-- Таблички участков -------------------------------------------------------

local function refreshSign(model: Instance)
	local sign = model:FindFirstChild("Sign")
	local gui = sign and sign:FindFirstChild("SignGui")
	local text = gui and gui:FindFirstChild("Text", true)
	if not text or not text:IsA("TextLabel") then
		return
	end
	local index = model:GetAttribute("Index")
	local biome = model:GetAttribute("Biome")
	local ownerName = model:GetAttribute("OwnerName")
	if type(ownerName) == "string" and ownerName ~= "" then
		text.Text = "🏠 " .. ownerName
	else
		text.Text = L.t("plots.name", { n = index }) .. " · " .. L.t("biome." .. tostring(biome)) .. "\n" .. L.t("plots.for_sale", { price = Map.PLOT_PRICE })
	end
end

local function watchPlots()
	local world = workspace:WaitForChild("World", 30)
	local plots = world and world:WaitForChild("Plots", 30)
	if not plots then
		return
	end
	local function hook(model: Instance)
		if not model:IsA("Model") then
			return
		end
		refreshSign(model)
		model:GetAttributeChangedSignal("OwnerName"):Connect(function()
			refreshSign(model)
		end)
		local sign = model:WaitForChild("Sign", 10)
		if sign then
			refreshSign(model)
		end
	end
	for _, m in plots:GetChildren() do
		task.spawn(hook, m)
	end
	plots.ChildAdded:Connect(hook)
	L.onChange(function()
		for _, m in plots:GetChildren() do
			refreshSign(m)
		end
	end)
end

-- Указатель цели ----------------------------------------------------------

local beacon: Part
local beam: Beam
local rootAttachment: Attachment? = nil

local function firstTagged(tag: string, filter: ((Instance) -> boolean)?): BasePart?
	local best: BasePart? = nil
	local bestDist = math.huge
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, inst in CollectionService:GetTagged(tag) do
		local part: Instance? = if inst:IsA("ProximityPrompt") then inst.Parent else inst
		if part and part:IsA("BasePart") and (not filter or filter(inst)) then
			local d = if hrp then (part.Position - hrp.Position).Magnitude else 0
			if d < bestDist then
				best, bestDist = part, d
			end
		end
	end
	return best
end

local myVehicle: () -> Model?

local function target(): Vector3?
	local s = Store.state
	local id, progress, carry, done = jobState()
	local job = JobsCfg.byId[id]
	if job then
		-- служебная машина брошена — ведём к ней
		if job.vehicle then
			local mine = myVehicle()
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local seatPart = hum and hum.SeatPart
			if mine and mine.PrimaryPart and not (seatPart and seatPart:IsDescendantOf(mine)) then
				return mine.PrimaryPart.Position
			end
		end
		if job.kind == "haul" then
			local p = firstTagged(if carry then job.drop :: string else job.pickup :: string)
			return p and p.Position
		elseif job.kind == "prompts" then
			local p = firstTagged(job.target :: string, function(inst)
				local n = inst:GetAttribute("N")
				return type(n) == "number" and not done[n]
			end)
			return p and p.Position
		else
			local p = firstTagged(job.target :: string, function(inst)
				return inst:GetAttribute("N") == progress + 1
			end)
			if p then
				return p.Position
			end
			-- точка ещё не подгрузилась (далеко): берём известные координаты рынков (+40 к югу)
			if id == "parcel" then
				if progress + 1 == 2 then
					return Map.tileCenter(4, 0) + Vector3.new(0, 0, 40)
				elseif progress + 1 == 3 then
					return Map.tileCenter(0, 0) + Vector3.new(0, 0, 40)
				end
			end
			return nil
		end
	end
	if not s then
		return nil
	end
	local step = s.tutorial or 6
	if step == 1 or step == 3 then
		local p = firstTagged("TutorialBoard")
		return p and p.Position
	elseif step == 4 then
		local p = firstTagged("TutorialOffice")
		return p and p.Position
	elseif step == 5 and s.plot then
		local ei, ej = Map.entrance(s.plot)
		local x, z = Map.cellXZ(s.plot, ei, ej)
		return Vector3.new(x, Map.BASE, z)
	end
	return nil
end

-- Своя машина (служебная или тележка) в мире
myVehicle = function(): Model?
	local folder = workspace:FindFirstChild("Vehicles")
	if not folder then
		return nil
	end
	for _, car in folder:GetChildren() do
		if car:IsA("Model") and car:GetAttribute("Owner") == player.UserId and car.Name ~= "cart_" .. player.UserId then
			return car
		end
	end
	return nil
end

-- Подсказка «Сесть за руль» видна только хозяину машины
local function watchVehicles()
	local folder = workspace:WaitForChild("Vehicles", 60)
	if not folder then
		return
	end
	local function hook(inst: Instance)
		if inst:IsA("ProximityPrompt") and inst.Name == "DrivePrompt" then
			local car = inst:FindFirstAncestorOfClass("Model")
			inst.ActionText = L.t("act.drive")
			inst.Enabled = car ~= nil and car:GetAttribute("Owner") == player.UserId
		end
	end
	for _, d in folder:GetDescendants() do
		hook(d)
	end
	folder.DescendantAdded:Connect(hook)
end

-- Дальность прорисовки: дальние участки (дома и украшения) скрываются у этого игрока
local drawDistance = 2000
local hiddenPlots: { [Instance]: boolean } = {}
local function setHidden(model: Instance, hidden: boolean)
	if (hiddenPlots[model] == true) == hidden then
		return
	end
	hiddenPlots[model] = hidden
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end

function M.setDrawDistance(d: number)
	drawDistance = d
end

local function updateDrawDistance()
	local world = workspace:FindFirstChild("World")
	local plots = world and world:FindFirstChild("Plots")
	if not plots then
		return
	end
	local cam = workspace.CurrentCamera.CFrame.Position
	for _, model in plots:GetChildren() do
		local index = model:GetAttribute("Index")
		if type(index) == "number" and Map.plots[index] then
			local p = Map.plots[index]
			local c = Map.tileCenter(p.c, p.r)
			local dx = math.max(0, math.abs(cam.X - c.X) - Map.PLOT / 2)
			local dz = math.max(0, math.abs(cam.Z - c.Z) - Map.PLOT / 2)
			setHidden(model, math.sqrt(dx * dx + dz * dz) > drawDistance)
		end
	end
end

local function makeBeacon()
	beacon = Instance.new("Part")
	beacon.Name = "GoalBeacon"
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CanQuery = false
	beacon.CanTouch = false
	beacon.Transparency = 1
	beacon.Size = Vector3.new(1, 1, 1)
	local a1 = Instance.new("Attachment")
	a1.Parent = beacon
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(60, 60)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.AlwaysOnTop = true
	gui.Parent = beacon
	local arrow = Instance.new("TextLabel")
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Text = "⬇"
	arrow.TextScaled = true
	arrow.TextColor3 = Color3.fromRGB(255, 200, 70)
	arrow.TextStrokeTransparency = 0.3
	arrow.Parent = gui
	beam = Instance.new("Beam")
	beam.Attachment1 = a1
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 200, 70))
	beam.Transparency = NumberSequence.new(0.35, 0.8)
	beam.Width0 = 0.6
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 1
	beam.Parent = beacon
	beacon.Parent = workspace
end

local function onCharacter(ch: Model)
	local hrp = ch:WaitForChild("HumanoidRootPart", 10)
	if hrp then
		local a = Instance.new("Attachment")
		a.Name = "GoalFrom"
		a.Position = Vector3.new(0, -2, 0)
		a.Parent = hrp
		rootAttachment = a
		beam.Attachment0 = a
	end
end

function M.start()
	for _, tag in PROMPT_TAGS do
		local function hook(inst: Instance)
			if inst:IsA("ProximityPrompt") then
				prompts[inst] = tag
				refreshPrompt(inst, tag)
			end
		end
		for _, inst in CollectionService:GetTagged(tag) do
			hook(inst)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(hook)
	end
	for _, attr in { "Job", "JobProgress", "JobCarry", "JobDone" } do
		player:GetAttributeChangedSignal(attr):Connect(refreshAllPrompts)
	end
	L.onChange(refreshAllPrompts)
	task.spawn(watchPlots)
	task.spawn(watchVehicles)
	task.spawn(function()
		while true do
			task.wait(1.5)
			updateDrawDistance()
		end
	end)

	makeBeacon()
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.2 then
			return
		end
		acc = 0
		local pos = target()
		local show = pos ~= nil and rootAttachment ~= nil
		beam.Enabled = show
		local gui = beacon:FindFirstChildOfClass("BillboardGui")
		if gui then
			gui.Enabled = show
		end
		if pos then
			beacon.Position = pos + Vector3.new(0, 1, 0)
		end
	end)
end

function M.hideGuide(hidden: boolean)
	beacon.Parent = if hidden then nil else workspace
end

return M
