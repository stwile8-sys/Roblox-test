--!nonstrict
-- Клиент Chrono Heist Tycoon: запуск интерфейса, существ, эффектов; подсказки взаимодействия,
-- кнопка «Действие» (взлом стены / клетки), дубинка — предмет в рюкзаке, замок — кнопка на базе,
-- горячие клавиши ПК (E — украсть, Q — сканер, V — взлом),
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
-- все русские тексты интерфейса — на язык игрока (если он не русский)
require(script.Parent.Translate).start()

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false) -- своя кнопка дубинки (Hud)
end)

local State = require(script.Parent.State)
local Fx = require(script.Parent.Fx)
local Kit = require(script.Parent.UI.Kit)
local Hud = require(script.Parent.UI.Hud)
local Windows = require(script.Parent.UI.Windows)
local Animate = require(script.Parent.Art.Animate)

Animate.start()
require(script.Parent.Art.World).start()
Kit.onClick = function()
	Fx.sfx("click", nil, 0.4)
end

-- ── Звуки событий на стороне игрока ─────────────────────────
-- взял существо на руки / донёс
local carrying = false
State.on("carry", function(v)
	local now = v ~= nil and v ~= false
	if now and not carrying then
		Fx.sfx("pop", nil, 0.9)
		task.delay(0.08, function()
			Fx.sfx("steal", nil, 0.45)
		end)
	end
	carrying = now
end)
-- дубинка: достал — щелчок, замах — свист
local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("SfxHooked") then
		return
	end
	tool:SetAttribute("SfxHooked", true)
	tool.Equipped:Connect(function()
		Fx.sfx("click", nil, 0.6)
	end)
	tool.Activated:Connect(function()
		Fx.sfx("whoosh", nil, 0.75)
	end)
end
local function hookChar(char: Model)
	for _, c in char:GetChildren() do
		hookTool(c)
	end
	char.ChildAdded:Connect(hookTool)
end
if player.Character then
	hookChar(player.Character)
end
player.CharacterAdded:Connect(hookChar)
task.spawn(function()
	local bp = player:WaitForChild("Backpack", 30)
	if bp then
		for _, c in bp:GetChildren() do
			hookTool(c)
		end
		bp.ChildAdded:Connect(hookTool)
	end
	player.CharacterAdded:Connect(function()
		local nb = player:WaitForChild("Backpack", 30)
		if nb then
			nb.ChildAdded:Connect(hookTool)
		end
	end)
end)
-- открыл окно — мягкий «поп»
Kit.onOpen = function()
	Fx.sfx("pop", nil, 0.35)
end
-- деньги/осколки прилетели (сбор, награда) — монетка
Hud.onGain = function()
	Fx.sfx("coin", nil, 0.35)
end

Hud.onScan = Windows.scan
Hud.onShop = function()
	Windows.shop()
end
Hud.onMenu = Windows.menu
Hud.onPass = Windows.pass
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
	if role == "buy" then
		return true
	elseif role == "manage" then
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
		else
			action.kind = "none"
		end
		local _ = target
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
	if k == Enum.KeyCode.Q then
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

-- ── Сезонный остров: табличка над алтарём ───────────────────
task.spawn(function()
	local map = workspace:WaitForChild("Map", 30)
	local season = map and map:WaitForChild("Season", 30)
	local frame = season and season:WaitForChild("CageFrame", 30)
	local top = frame and frame:WaitForChild("Top", 30)
	if not top then
		return
	end
	local bb = Instance.new("BillboardGui")
	-- маленькая и только вблизи: с базы и хаба её не видно
	bb.Size = UDim2.fromOffset(210, 78)
	bb.StudsOffset = Vector3.new(0, 5, 0)
	bb.MaxDistance = 60
	bb.Parent = top
	local box = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.C.bg, Parent = bb }, { Kit.corner(14), Kit.stroke(Kit.C.line, 3) })
	local title = Kit.label({ Text = "", Font = Kit.BLACK, TextSize = 18, Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 24), Parent = box })
	local sub = Kit.label({ Text = "", TextSize = 15, TextColor3 = Kit.C.dim, Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 20), Parent = box })
	local barBg = Kit.frame({ Position = UDim2.new(0, 12, 1, -20), Size = UDim2.new(1, -24, 0, 10), BackgroundColor3 = Kit.C.soft, Parent = box }, { Kit.corner(8) })
	local bar = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Kit.C.thief, Parent = barBg }, { Kit.corner(8) })
	while true do
		local theme = workspace:GetAttribute("Season") or 1
		local names = { "Тыквенный", "Ледяной", "Песчаный", "Цветущий", "Звёздный", "Коралловый" }
		title.Text = "✨ " .. (names[theme] or "") .. " Титан"
		local st = workspace:GetAttribute("SeasonState") or "waiting"
		local hp = season:GetAttribute("CageHP") or 0
		barBg.Visible = st == "caged"
		if st == "waiting" then
			local left = math.max(0, (workspace:GetAttribute("SeasonNext") or 0) - workspace:GetServerTimeNow())
			sub.Text = "Появится через " .. L.duration(left)
		elseif st == "caged" then
			sub.Text = "Ломай клетку! ⛏️"
			bar.Size = UDim2.fromScale(math.clamp(hp / 3000, 0, 1), 1)
		elseif st == "open" then
			sub.Text = "Клетка сломана — хватай!"
		else
			sub.Text = "Его несут! Догони и ударь 🏏"
		end
		task.wait(0.5)
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
