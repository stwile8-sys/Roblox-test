--!nonstrict
-- Клиент Chrono Heist Tycoon: запуск интерфейса, существ, эффектов; подсказки взаимодействия,
-- кнопка «Действие» (замок / взлом / удар), горячие клавиши ПК (E — украсть, F — замок, Q — сканер, V — действие),
-- атмосфера своей/чужой базы, музыка по зонам, вращение/парение декора.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local player = Players.LocalPlayer
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Game = require(Shared.Config.Game)
local Palette = require(Shared.Config.Palette)
local L = require(Shared.Lang.L)

-- язык: по настройкам Roblox, базовый — русский
pcall(function()
	L.set(L.fromLocale(game:GetService("LocalizationService").RobloxLocaleId))
end)

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Windows = require(script.Parent.UI.Windows)
local Animate = require(script.Parent.Art.Animate)

Animate.start()
Kit.onClick = function()
	Fx.sfx("click", nil, 0.4)
end

Hud.onScan = Windows.scan
Hud.onShop = function()
	Windows.shop()
end
Hud.onMenu = Windows.menu
Hud.onRebirth = Windows.rebirth

local function myBase(): Model?
	local i = State.s.base
	local bases = workspace:FindFirstChild("Bases")
	return i and bases and bases:FindFirstChild("Base" .. i)
end

local function root(): BasePart?
	local c = player.Character
	local r = c and c:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

-- точка внутри базы (правило из ARCH.md)
local function inside(base: Model, pos: Vector3): boolean
	local floor = base:FindFirstChild("Floor")
	if not floor then
		return false
	end
	local cf = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
	local l = cf:PointToObjectSpace(pos)
	return math.abs(l.X) < 58 and math.abs(l.Z) < 58 and l.Y > -5 and l.Y < 45
end

local function baseAt(pos: Vector3): Model?
	local bases = workspace:FindFirstChild("Bases")
	if not bases then
		return nil
	end
	for _, b in bases:GetChildren() do
		if b:IsA("Model") and inside(b, pos) then
			return b
		end
	end
	return nil
end

-- ── Подсказки ProximityPrompt: показываем только нужные ─────
local function promptAllowed(prompt: ProximityPrompt): boolean
	local role = prompt:GetAttribute("Role")
	local anchor = prompt.Parent
	if not anchor then
		return false
	end
	local owner = anchor:GetAttribute("Owner")
	local mine = owner == player.UserId
	if role == "buy" or role == "manage" then
		return mine
	elseif role == "steal" then
		if anchor:GetAttribute("Kind") == "den" then
			return true
		end
		if mine then
			return false
		end
		local b = anchor:GetAttribute("Base")
		local base = b and workspace.Bases:FindFirstChild("Base" .. b)
		return base ~= nil and base:GetAttribute("Breached") == true
	end
	return true
end

local function refreshPrompt(prompt: ProximityPrompt)
	prompt.Enabled = promptAllowed(prompt)
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.UIOffset = Vector2.new(0, 0)
end

ProximityPromptService.PromptShown:Connect(function(prompt)
	refreshPrompt(prompt)
end)
task.spawn(function()
	while true do
		task.wait(0.5)
		for _, a in CollectionService:GetTagged("Art") do
			for _, p in a:GetChildren() do
				if p:IsA("ProximityPrompt") then
					local allowed = promptAllowed(p)
					if p.Enabled ~= allowed then
						p.Enabled = allowed
					end
				end
			end
		end
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local role = prompt:GetAttribute("Role")
	if role == "manage" then
		local slot = prompt.Parent:GetAttribute("Slot")
		if slot then
			Windows.pedestal(slot)
		end
	elseif role == "bench" then
		Windows.bench()
	end
end)

-- локальная подсказка у своего верстака
local benchPrompt: ProximityPrompt? = nil
State.on("base", function()
	task.wait(0.5)
	local b = myBase()
	local bench = b and b:FindFirstChild("Bench")
	local part = bench and bench:FindFirstChild("Prompt")
	if part then
		if benchPrompt then
			benchPrompt:Destroy()
		end
		local p = Instance.new("ProximityPrompt")
		p:SetAttribute("Role", "bench")
		p.ActionText = "Верстак"
		p.ObjectText = "Стены · Ловушки · Инструмент"
		p.HoldDuration = 0
		p.MaxActivationDistance = 12
		p.RequiresLineOfSight = false
		p.KeyboardKeyCode = Enum.KeyCode.E
		p.Parent = part
		benchPrompt = p
	end
end)

-- ── Кнопка «Действие» ───────────────────────────────────────
local SEG_RANGE = Game.HACK_RANGE - 1

local function nearestEnemySegment(pos: Vector3): (number?, string?)
	local bases = workspace:FindFirstChild("Bases")
	if not bases then
		return nil, nil
	end
	local best, bestBase, bd = nil, nil, SEG_RANGE
	for _, b in bases:GetChildren() do
		local idx = b:GetAttribute("Index")
		if idx and idx ~= State.s.base and b:GetAttribute("Kind") ~= "empty" then
			local walls = b:FindFirstChild("Walls")
			if walls then
				for _, seg in walls:GetChildren() do
					if seg:IsA("BasePart") and not seg:GetAttribute("Broken") then
						local l = seg.CFrame:PointToObjectSpace(pos)
						local h = seg.Size / 2
						local c = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
						local d = (l - c).Magnitude
						if d < bd then
							best, bestBase, bd = seg.Name, idx, d
						end
					end
				end
			end
		end
	end
	return bestBase, best
end

local function nearestCharacter(pos: Vector3): number?
	local best, bd = nil, Game.BAT_RANGE
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			local r = p.Character:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude < bd then
				best, bd = p.UserId, (r.Position - pos).Magnitude
			end
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in bots:GetChildren() do
			local r = b:FindFirstChild("HumanoidRootPart")
			if r and (r.Position - pos).Magnitude < bd then
				best, bd = b:GetAttribute("BotId"), (r.Position - pos).Magnitude
			end
		end
	end
	return best
end

local action = { kind = "lock", base = nil, seg = nil, target = nil }

local function computeAction()
	local r = root()
	if not r then
		return
	end
	local pos = r.Position
	local cd = 0
	if State.s.carry then
		action.kind = "none"
	else
		local target = nearestCharacter(pos)
		local bIdx, seg = nearestEnemySegment(pos)
		local cageHp = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Season") and workspace.Map.Season:GetAttribute("CageHP") or 0
		if cageHp > 0 and (pos - Vector3.new(0, 95, 0)).Magnitude < 13 then
			action.kind = "cage"
		elseif bIdx then
			action.kind, action.base, action.seg = "hack", bIdx, seg
		elseif target then
			action.kind, action.target = "bat", target
		else
			action.kind = "lock"
			local lock = State.s.lock
			if lock then
				local now = workspace:GetServerTimeNow()
				if lock.untilT > now then
					cd = lock.untilT - now
				elseif lock.cdUntil > now then
					cd = lock.cdUntil - now
				end
			end
		end
	end
	local tcd = State.s.toolCd or 0
	if action.kind == "hack" and tcd > 0 then
		cd = tcd
	end
	Hud.setAction(action.kind, cd)
end

local lastHack = 0
local function doAction()
	computeAction()
	if action.kind == "hack" then
		if os.clock() - lastHack >= Game.HACK_INTERVAL then
			lastHack = os.clock()
			State.send("hack", { base = action.base, seg = action.seg })
		end
	elseif action.kind == "cage" then
		if os.clock() - lastHack >= Game.HACK_INTERVAL then
			lastHack = os.clock()
			State.send("hackCage")
		end
	elseif action.kind == "bat" then
		State.send("bat", { target = action.target })
	elseif action.kind == "lock" then
		State.act("lock")
	end
end
Hud.onAction = doAction

-- удержание кнопки — взлом повторяется сам
local holding = false
Hud.onActionHold = function(on)
	holding = on
end
task.spawn(function()
	while true do
		task.wait(Game.HACK_INTERVAL)
		if holding and (action.kind == "hack" or action.kind == "cage") then
			doAction()
		end
	end
end)
task.spawn(function()
	while true do
		task.wait(0.2)
		pcall(computeAction)
	end
end)

-- горячие клавиши ПК
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.F then
		State.act("lock")
	elseif k == Enum.KeyCode.Q then
		Windows.scan()
	elseif k == Enum.KeyCode.V then
		holding = true
		doAction()
	elseif k == Enum.KeyCode.Escape then
		Kit.close()
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.V then
		holding = false
	end
end)

-- ── Атмосфера, музыка, декор ────────────────────────────────
local cc = Instance.new("ColorCorrectionEffect")
cc.Name = "MoodCC"
cc.Parent = Lighting
local mood = ""
local function setMood(m: string)
	if m == mood then
		return
	end
	mood = m
	local goal = if m == "mine" then { TintColor = Color3.fromRGB(255, 240, 220), Saturation = 0.1, Brightness = 0.02 } elseif m == "enemy" then { TintColor = Color3.fromRGB(215, 225, 255), Saturation = -0.05, Brightness = -0.02 } else { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0 }
	TweenService:Create(cc, TweenInfo.new(1.2), goal):Play()
end

local function lamps()
	local my = myBase()
	for _, lamp in CollectionService:GetTagged("BaseLamp") do
		if lamp:IsA("BasePart") then
			local isMine = my ~= nil and lamp:IsDescendantOf(my)
			lamp.Color = if isMine then Palette.orange else Palette.chrono
			local light = lamp:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = if isMine then Palette.orange else Palette.thief
			end
		end
	end
end
State.on("base", function()
	task.wait(1)
	lamps()
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		local r = root()
		if r then
			local pos = r.Position
			local b = baseAt(pos)
			local my = myBase()
			if pos.Y > 70 then
				setMood("")
				Fx.music("season")
			elseif b and b == my then
				setMood("mine")
				Fx.music("base")
			elseif b or State.s.carry or State.s.raid then
				setMood("enemy")
				Fx.music("raid")
			else
				setMood("")
				Fx.music("lobby")
			end
		end
	end
end)

-- вращение, парение, пульс декора (тег Spin / Float / Pulse)
local spinBase: { [BasePart]: CFrame } = {}
local floatBase: { [BasePart]: CFrame } = {}
local pulseBase: { [BasePart]: number } = {}
RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for _, p in CollectionService:GetTagged("Spin") do
		if p:IsA("BasePart") then
			local b = spinBase[p]
			if not b then
				b = p.CFrame
				spinBase[p] = b
			end
			local center = p:GetAttribute("Center") or b.Position
			local ang = math.rad((p:GetAttribute("Speed") or 20) * t)
			p.CFrame = CFrame.new(center) * CFrame.Angles(0, ang, 0) * CFrame.new(center):Inverse() * b
		end
	end
	for _, p in CollectionService:GetTagged("Float") do
		if p:IsA("BasePart") then
			local b = floatBase[p]
			if not b then
				b = p.CFrame
				floatBase[p] = b
			end
			local ph = (b.Position.X + b.Position.Z) * 0.1
			p.CFrame = b * CFrame.new(0, math.sin(t * 1.2 + ph) * 0.8, 0) * CFrame.Angles(0, t * 0.3 + ph, 0)
		end
	end
	for _, p in CollectionService:GetTagged("Pulse") do
		if p:IsA("BasePart") then
			local b = pulseBase[p]
			if not b then
				b = p.Transparency
				pulseBase[p] = b
			end
			p.Transparency = math.clamp(b + (math.sin(t * 3 + p.Position.X) + 1) * 0.15, 0, 1)
		end
	end
end)

print("[Chrono Heist] клиент готов")
