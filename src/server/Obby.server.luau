-- Тестовое обби: вся трасса строится кодом при запуске сервера.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local STAGES = 12
local BASE_Y = 10

ReplicatedStorage:SetAttribute("TotalStages", STAGES)

local finishEvent = Instance.new("RemoteEvent")
finishEvent.Name = "ObbyFinish"
finishEvent.Parent = ReplicatedStorage

local restartEvent = Instance.new("RemoteEvent")
restartEvent.Name = "ObbyRestart"
restartEvent.Parent = ReplicatedStorage

local course = Instance.new("Folder")
course.Name = "Obby"
course.Parent = workspace

local COLORS = {
	Color3.fromRGB(85, 170, 255),
	Color3.fromRGB(120, 220, 120),
	Color3.fromRGB(255, 200, 80),
	Color3.fromRGB(200, 120, 255),
}

-- ── помощники ────────────────────────────────────────────────

local function makePart(size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = course
	return p
end

local function killHumanoidOf(hit: BasePart)
	local model = hit.Parent
	local hum = model and model:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		hum.Health = 0
	end
end

local function makeLava(size: Vector3, cframe: CFrame): Part
	local p = makePart(size, cframe, Color3.fromRGB(255, 85, 0), Enum.Material.Neon)
	p.Touched:Connect(killHumanoidOf)
	return p
end

local function addLabel(p: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = Enum.Font.BuilderSansBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.5
	t.Parent = gui
	gui.Parent = p
end

-- ── игроки и этапы ───────────────────────────────────────────

local checkpoints: { [number]: BasePart } = {}

local function getStage(player: Player): IntValue?
	local ls = player:FindFirstChild("leaderstats")
	return ls and ls:FindFirstChild("Этап") :: IntValue?
end

local function onCheckpointTouched(stageNumber: number, hit: BasePart)
	local player = Players:GetPlayerFromCharacter(hit.Parent)
	if not player then
		return
	end
	local stage = getStage(player)
	if stage and stageNumber > stage.Value then
		stage.Value = stageNumber
	end
end

-- ── постройка трассы ─────────────────────────────────────────

local z = 0
local blinkers = {}
local spinners = {}

-- старт
local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = CFrame.new(0, BASE_Y, z + 6)
spawn.Color = Color3.fromRGB(240, 240, 240)
spawn.Material = Enum.Material.SmoothPlastic
spawn.TopSurface = Enum.SurfaceType.Smooth
spawn.Neutral = true
spawn.Duration = 0
spawn.Parent = course
addLabel(spawn, "СТАРТ")
checkpoints[0] = spawn
z += 12

local function addCheckpoint(stageNumber: number, isFinish: boolean)
	local size = isFinish and 16 or 12
	local color = isFinish and Color3.fromRGB(255, 215, 0) or Color3.fromRGB(60, 200, 90)
	local cp = makePart(Vector3.new(size, 1, size), CFrame.new(0, BASE_Y, z + size / 2), color, Enum.Material.Neon)
	addLabel(cp, isFinish and "ФИНИШ" or tostring(stageNumber))
	checkpoints[stageNumber] = cp
	cp.Touched:Connect(function(hit)
		onCheckpointTouched(stageNumber, hit)
		if not isFinish then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if player and not player:GetAttribute("Finished") then
			player:SetAttribute("Finished", true)
			local seconds = os.clock() - (player:GetAttribute("StartTime") or os.clock())
			finishEvent:FireClient(player, seconds)
			local root = hit.Parent:FindFirstChild("HumanoidRootPart")
			if root then
				Instance.new("Sparkles").Parent = root
			end
		end
	end)
	z += size
end

local function buildJumps(d: number, color: Color3)
	local gap = 4 + d * 3 -- 4..7 шпилек
	local w = 6 - d * 2 -- 6..4
	for i = 1, 5 do
		z += gap
		local h = BASE_Y + (i % 2 == 0 and 1.5 or 0)
		makePart(Vector3.new(w, 1, w), CFrame.new((i % 3 - 1) * 2, h, z + w / 2), color)
		z += w
	end
	z += gap
end

local function buildBeams(d: number, color: Color3)
	local segment = 10
	local count = 3
	local width = 3 - d * 1.5 -- 3..1.5
	local length = segment * count
	makeLava(Vector3.new(24, 1, length + 4), CFrame.new(0, BASE_Y - 1.5, z + length / 2))
	for i = 1, count do
		local x = (i % 2 == 0) and 2.5 or -2.5
		makePart(Vector3.new(width, 1, segment), CFrame.new(x, BASE_Y, z + (i - 0.5) * segment), color)
	end
	z += length
end

local function buildBlinkers(d: number, color: Color3)
	local gap = 3 + d * 2
	for i = 1, 5 do
		z += gap
		local p = makePart(Vector3.new(6, 1, 6), CFrame.new(0, BASE_Y, z + 3), color, Enum.Material.Glass)
		table.insert(blinkers, { part = p, phase = i * 0.6 })
		z += 6
	end
	z += gap
end

local function buildSpinner(d: number, color: Color3)
	local length = 34
	makePart(Vector3.new(14, 1, length), CFrame.new(0, BASE_Y, z + length / 2), color)
	local center = Vector3.new(0, BASE_Y + 1.5, z + length / 2)
	local bar = makePart(Vector3.new(1, 1, 13), CFrame.new(center), Color3.fromRGB(230, 40, 40), Enum.Material.Neon)
	bar.CanCollide = false
	table.insert(spinners, { part = bar, center = center, speed = 1.5 + d * 2 })
	z += length
end

local builders = { buildJumps, buildBeams, buildBlinkers, buildSpinner }

for s = 1, STAGES do
	local d = (s - 1) / (STAGES - 1)
	local kind = (s - 1) % #builders + 1
	builders[kind](d, COLORS[kind])
	addCheckpoint(s, s == STAGES)
end

-- пропасть под трассой
local void = makePart(Vector3.new(300, 2, z + 80), CFrame.new(0, BASE_Y - 25, z / 2), Color3.fromRGB(40, 20, 60), Enum.Material.Slate)
void.Touched:Connect(killHumanoidOf)

-- ── анимация ловушек ─────────────────────────────────────────

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.FilterDescendantsInstances = { course }

RunService.Heartbeat:Connect(function()
	local now = os.clock()

	-- исчезающие платформы: 2 с есть, 1 с нет; мигают перед исчезновением
	for _, b in blinkers do
		local t = (now + b.phase) % 3
		if t < 2 then
			b.part.CanCollide = true
			b.part.Transparency = (t > 1.4) and 0.6 or 0
		else
			b.part.CanCollide = false
			b.part.Transparency = 0.9
		end
	end

	-- вращающиеся балки
	for _, sp in spinners do
		sp.part.CFrame = CFrame.new(sp.center) * CFrame.Angles(0, now * sp.speed, 0)
		for _, hit in workspace:GetPartsInPart(sp.part, overlap) do
			killHumanoidOf(hit)
		end
	end
end)

-- ── подключение игроков ──────────────────────────────────────

local function teleportToCheckpoint(player: Player, character: Model)
	local stage = getStage(player)
	local cp = stage and checkpoints[stage.Value]
	if cp and stage.Value > 0 then
		character:PivotTo(cp.CFrame + Vector3.new(0, 4, 0))
	end
end

Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local stage = Instance.new("IntValue")
	stage.Name = "Этап"
	stage.Parent = ls
	ls.Parent = player

	player:SetAttribute("StartTime", os.clock())

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart")
		task.wait() -- даём стандартному спавну отработать
		teleportToCheckpoint(player, character)
	end)
end)

restartEvent.OnServerEvent:Connect(function(player)
	local stage = getStage(player)
	if stage then
		stage.Value = 0
	end
	player:SetAttribute("Finished", nil)
	player:SetAttribute("StartTime", os.clock())
	player:LoadCharacter()
end)
