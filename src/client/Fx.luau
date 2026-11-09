--!nonstrict
-- Эффекты и звук: VFX по событиям сервера (пул частиц, без создания мусора), SFX, музыка по зонам,
-- позы персонажей кодом (Motor6D.Transform поверх стандартных анимаций), хроно-след, ореол топ-1.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Assets = require(Shared.Config.Assets)
local Palette = require(Shared.Config.Palette)
local Net = require(Shared.Net)

local M: any = {}
local player = Players.LocalPlayer

-- ── Звук ────────────────────────────────────────────────────
local sounds: { [string]: Sound } = {}
local function sfxSound(key: string): Sound?
	local id = Assets.sfx[key]
	if not id or id == 0 then
		return nil
	end
	local s = sounds[key]
	if not s then
		s = Instance.new("Sound")
		s.Name = key
		s.SoundId = "rbxassetid://" .. id
		s.Volume = 0.6
		s.Parent = SoundService
		sounds[key] = s
	end
	return s
end

function M.sfx(key: string, pos: Vector3?, volume: number?)
	local s = sfxSound(key)
	if not s then
		return
	end
	if pos then
		local holder = Instance.new("Attachment")
		holder.WorldPosition = pos
		holder.Parent = workspace.Terrain
		local c = s:Clone()
		c.Volume = volume or 0.8
		c.RollOffMaxDistance = 120
		c.Parent = holder
		c:Play()
		task.delay(3, function()
			holder:Destroy()
		end)
	else
		s.Volume = volume or 0.6
		s:Play()
	end
end

-- музыка: лобби / своя база / рейд / сезон, плавная смена
local music: { [string]: Sound } = {}
local currentMusic = ""
for key, id in Assets.music do
	local s = Instance.new("Sound")
	s.Name = "Music_" .. key
	s.SoundId = "rbxassetid://" .. id
	s.Looped = true
	s.Volume = 0
	s.Parent = SoundService
	music[key] = s
end

function M.music(key: string)
	if key == currentMusic then
		return
	end
	currentMusic = key
	for k, s in music do
		if k == key then
			if not s.IsPlaying then
				s:Play()
			end
			TweenService:Create(s, TweenInfo.new(1.5), { Volume = 0.35 }):Play()
		else
			TweenService:Create(s, TweenInfo.new(1.5), { Volume = 0 }):Play()
		end
	end
end

-- ── Пул частиц ──────────────────────────────────────────────
local pool: { BasePart } = {}
local fxFolder = Instance.new("Folder")
fxFolder.Name = "Fx"
fxFolder.Parent = workspace

local function holder(): any
	local p = table.remove(pool)
	if not p then
		p = Instance.new("Part")
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.Transparency = 1
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		local e = Instance.new("ParticleEmitter")
		e.Name = "E"
		e.Enabled = false
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.LightEmission = 1
		e.Parent = p
		local l = Instance.new("PointLight")
		l.Name = "L"
		l.Enabled = false
		l.Parent = p
		p.Parent = fxFolder
	end
	return p
end

local function release(p: any)
	p.L.Enabled = false
	table.insert(pool, p)
end

-- вспышка частиц: цвет, количество, скорость, размер, свет
function M.burst(pos: Vector3, color: Color3, count: number, speed: number?, size: number?, light: boolean?, up: boolean?)
	local p = holder()
	p.CFrame = CFrame.new(pos)
	local e: ParticleEmitter = p.E
	e.Color = ColorSequence.new(color)
	e.Speed = NumberRange.new((speed or 12) * 0.5, speed or 12)
	e.SpreadAngle = if up then Vector2.new(25, 25) else Vector2.new(180, 180)
	e.EmissionDirection = Enum.NormalId.Top
	e.Lifetime = NumberRange.new(0.5, 1.1)
	e.Size = NumberSequence.new(size or 0.6, 0)
	e.Acceleration = if up then Vector3.zero else Vector3.new(0, -20, 0)
	e:Emit(count)
	if light then
		p.L.Color = color
		p.L.Range = 18
		p.L.Brightness = 3
		p.L.Enabled = true
		task.delay(0.25, function()
			p.L.Enabled = false
		end)
	end
	task.delay(1.5, function()
		release(p)
	end)
end

-- всплывающий текст в мире (+$)
function M.floatText(pos: Vector3, text: string, color: Color3)
	local p = holder()
	p.CFrame = CFrame.new(pos)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 50)
	gui.AlwaysOnTop = true
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Text = text
	t.Parent = gui
	TweenService:Create(gui, TweenInfo.new(1.2), { StudsOffset = Vector3.new(0, 5, 0) }):Play()
	TweenService:Create(t, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.3, function()
		gui:Destroy()
		release(p)
	end)
end

-- тряска камеры
local shake = 0
function M.shake(amount: number)
	shake = math.max(shake, amount)
end
RunService:BindToRenderStep("ChronoShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if shake > 0.01 then
		local cam = workspace.CurrentCamera
		cam.CFrame = cam.CFrame * CFrame.Angles((math.random() - 0.5) * shake * 0.05, (math.random() - 0.5) * shake * 0.05, 0)
		shake = math.max(0, shake - dt * 3)
	end
end)

-- виньетка погони (красная у вора, бирюзовая у владельца)
M.vignette = nil :: ImageLabel?
function M.chase(role: string, seconds: number)
	local v = M.vignette
	if not v then
		return
	end
	v.ImageColor3 = if role == "thief" then Palette.alarm else Palette.chrono
	v.ImageTransparency = 0.2
	v.Visible = true
	local stamp = os.clock()
	v:SetAttribute("Stamp", stamp)
	task.delay(seconds, function()
		if v:GetAttribute("Stamp") == stamp then
			v.Visible = false
		end
	end)
end

-- вспышка/затемнение экрана
M.flashFrame = nil :: Frame?
function M.flash(color: Color3, seconds: number)
	local f = M.flashFrame
	if not f then
		return
	end
	f.BackgroundColor3 = color
	f.BackgroundTransparency = 0
	f.Visible = true
	TweenService:Create(f, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { BackgroundTransparency = 1 }):Play()
	task.delay(seconds, function()
		f.Visible = false
	end)
end

-- ── События сервера ─────────────────────────────────────────
local handlers: { [string]: (Vector3?, any) -> () } = {
	collect = function(pos, d)
		if pos then
			M.burst(pos + Vector3.new(0, 1, 0), Palette.gold, 30, 14, 0.7, true, true)
			M.floatText(pos + Vector3.new(0, 3, 0), "+$" .. tostring(d.n or ""), Palette.gold)
		end
		M.sfx("coin")
	end,
	buy = function(pos)
		if pos then
			M.burst(pos, Palette.success, 25, 10, 0.5, true)
		end
		M.sfx("buy", pos)
	end,
	upgrade = function(pos)
		if pos then
			M.burst(pos, Palette.success, 35, 12, 0.6, true, true)
		end
		M.sfx("upgrade", pos)
	end,
	hack = function(pos)
		if pos then
			M.burst(pos, Color3.fromHex("#FFF3A1"), 10, 18, 0.3)
		end
		M.sfx("hack", pos, 0.7)
	end,
	wallBreak = function(pos)
		if pos then
			M.burst(pos, Palette.stone, 45, 25, 1.2, false)
		end
		M.sfx("wallBreak", pos, 1)
		M.shake(0.6)
	end,
	steal = function(pos)
		if pos then
			M.burst(pos, Palette.thief, 40, 10, 0.8, true)
		end
		M.sfx("steal", pos)
	end,
	caught = function(pos)
		if pos then
			M.burst(pos + Vector3.new(0, 2, 0), Palette.alarm, 40, 20, 0.9, true)
			M.burst(pos + Vector3.new(0, 4, 0), Palette.gold, 8, 4, 0.8, false, true)
		end
		M.sfx("caught", pos, 1)
	end,
	escape = function(pos)
		if pos then
			M.burst(pos, Palette.gold, 60, 22, 0.9, true, true)
		end
		M.sfx("escape", pos, 1)
	end,
	trap = function(pos, d)
		if pos then
			local col = if d.skin == "blackhole" then Palette.thief else Palette.orange
			M.burst(pos + Vector3.new(0, 1, 0), col, 50, 28, 1.1, true)
		end
		M.sfx("trap", pos, 1)
		M.shake(0.8)
	end,
	bat = function(pos)
		M.sfx("whoosh", pos, 0.6)
	end,
	hit = function(pos)
		if pos then
			M.burst(pos, Color3.new(1, 1, 1), 15, 15, 0.5)
		end
		M.sfx("caught", pos, 0.5)
	end,
	alarm = function()
		M.sfx("alarm", nil, 0.9)
	end,
	rebirth = function(pos)
		if pos then
			M.burst(pos, Palette.chrono, 100, 30, 1.2, true, true)
		end
		M.sfx("rebirth", nil, 1)
		M.shake(0.4)
	end,
	lock = function(pos)
		M.sfx("upgrade", pos, 0.8)
	end,
	levelup = function(pos)
		if pos then
			M.burst(pos + Vector3.new(0, 4, 0), Palette.gold, 60, 18, 0.8, true, true)
		end
		M.sfx("escape", nil, 0.7)
	end,
	whoosh = function(pos)
		M.sfx("whoosh", pos)
	end,
	double = function(pos)
		if pos then
			M.burst(pos, Palette.chrono, 30, 10, 0.8, true)
		end
	end,
	seasonSpawn = function(pos)
		if pos then
			M.burst(pos, Palette.gold, 80, 25, 1, true, true)
		end
		M.sfx("pop")
	end,
	caveFall = function()
		M.sfx("whoosh", nil, 1)
		M.flash(Color3.fromHex("#14102A"), 0.6)
	end,
	caveWind = function(pos)
		M.sfx("whoosh", pos, 1)
		M.shake(0.5)
	end,
	caveLaunch = function(pos)
		if pos then
			M.burst(pos, Palette.chrono, 60, 30, 1, true, true)
			M.burst(pos, Color3.new(1, 1, 1), 40, 40, 0.8, false, true)
		end
		M.sfx("rebirth", pos, 1)
	end,
	chase = function(_, d)
		M.chase(d.role or "owner", 6)
	end,
}

Net.event("Fx").OnClientEvent:Connect(function(kind, pos, data)
	local h = handlers[kind]
	if h then
		pcall(h, pos, data or {})
	end
end)

-- ── Позы персонажей (для всех игроков и ботов, по атрибуту Pose) ──
-- Добавляем поворот к Motor6D.Transform после стандартной анимации (Stepped).
local POSES: { [string]: (number) -> { [string]: CFrame } } = {
	hack = function(t)
		local swing = math.sin(math.min(1, t / 0.5) * math.pi)
		return {
			RightShoulder = CFrame.Angles(math.rad(-150 + swing * 120), 0, 0),
			LeftShoulder = CFrame.Angles(math.rad(-60 + swing * 40), 0, 0),
			Waist = CFrame.Angles(math.rad(-10 - swing * 15), 0, 0),
		}
	end,
	bat = function(t)
		local e = math.min(1, t / 0.4)
		return {
			RightShoulder = CFrame.Angles(math.rad(-120 + e * 150), math.rad(-40 + e * 80), 0),
			Waist = CFrame.Angles(0, math.rad(40 - e * 80), 0),
		}
	end,
	steal = function(t)
		local e = math.min(1, t / 0.5)
		return {
			Waist = CFrame.Angles(math.rad(-35 * math.sin(e * math.pi)), 0, 0),
			RightShoulder = CFrame.Angles(math.rad(-80), 0, 0),
			LeftShoulder = CFrame.Angles(math.rad(-80), 0, 0),
		}
	end,
	carry = function(t)
		return {
			RightShoulder = CFrame.Angles(math.rad(-170), 0, math.rad(-10)),
			LeftShoulder = CFrame.Angles(math.rad(-170), 0, math.rad(10)),
			Waist = CFrame.Angles(math.rad(-12 + math.sin(t * 8) * 3), 0, 0),
		}
	end,
	caught = function(t)
		local e = math.min(1, t / 0.3)
		return {
			Root = CFrame.Angles(math.rad(-75 * e), 0, 0) * CFrame.new(0, -1.5 * e, 0),
			RightShoulder = CFrame.Angles(0, 0, math.rad(60)),
			LeftShoulder = CFrame.Angles(0, 0, math.rad(-60)),
		}
	end,
	stun = function(t)
		return { Neck = CFrame.Angles(0, math.sin(t * 10) * 0.4, 0) }
	end,
	hit = function(t)
		return { Waist = CFrame.Angles(math.rad(25 * math.max(0, 1 - t * 2)), 0, 0) }
	end,
	trap = function(t)
		local e = math.max(0, 1 - t)
		return {
			Waist = CFrame.Angles(math.rad(30 * e), 0, 0),
			RightShoulder = CFrame.Angles(0, 0, math.rad(90 * e)),
			LeftShoulder = CFrame.Angles(0, 0, math.rad(-90 * e)),
		}
	end,
	rebirth = function(t)
		local e = math.min(1, t / 1.5)
		return {
			Root = CFrame.new(0, 2 * math.sin(e * math.pi / 2), 0),
			RightShoulder = CFrame.Angles(math.rad(-160), 0, 0),
			LeftShoulder = CFrame.Angles(math.rad(-160), 0, 0),
		}
	end,
	escape = function(t)
		return {
			RightShoulder = CFrame.Angles(math.rad(-170), 0, 0),
			LeftShoulder = CFrame.Angles(math.rad(-170), 0, 0),
		}
	end,
}

local motorsCache: { [Model]: { [string]: Motor6D } } = {}
local function motors(char: Model): { [string]: Motor6D }
	local m = motorsCache[char]
	if m then
		return m
	end
	m = {}
	for _, d in char:GetDescendants() do
		if d:IsA("Motor6D") then
			m[d.Name] = d
		end
	end
	motorsCache[char] = m
	char.Destroying:Connect(function()
		motorsCache[char] = nil
	end)
	return m
end

local function characters(): { Model }
	local out = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(out, p.Character)
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots then
		for _, b in bots:GetChildren() do
			if b:IsA("Model") then
				table.insert(out, b)
			end
		end
	end
	return out
end

local poseStart: { [Model]: { name: string, t: number } } = {}
RunService.Stepped:Connect(function()
	local now = os.clock()
	for _, char in characters() do
		local pose = char:GetAttribute("Pose")
		if pose and pose ~= "" and POSES[pose] then
			local ps = poseStart[char]
			local stamp = char:GetAttribute("PoseT")
			if not ps or ps.name ~= pose or ps.stamp ~= stamp then
				ps = { name = pose, t = now, stamp = stamp }
				poseStart[char] = ps
			end
			local ok, offsets = pcall(POSES[pose], now - ps.t)
			if ok then
				local m = motors(char)
				for name, cf in offsets do
					local motor = m[name]
					if motor then
						motor.Transform = motor.Transform * cf
					end
				end
			end
		elseif poseStart[char] then
			poseStart[char] = nil
		end
	end
end)

-- ── Хроно-след и корона ─────────────────────────────────────
local function decorate(p: Player, char: Model)
	local root = char:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0.5)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.5, 0.5)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.Transparency = NumberSequence.new(0.3, 1)
	trail.Parent = root
	local function color()
		local c = (p:GetAttribute("SkinColor") or Palette.chrono) :: Color3
		trail.Color = ColorSequence.new(c)
	end
	color()
	p:GetAttributeChangedSignal("SkinColor"):Connect(color)
	-- след ярче при беге с добычей
	char:GetAttributeChangedSignal("Carry"):Connect(function()
		trail.Lifetime = if char:GetAttribute("Carry") then 0.8 else 0.35
		trail.Color = if char:GetAttribute("Carry") then ColorSequence.new(Palette.thief) else ColorSequence.new((p:GetAttribute("SkinColor") or Palette.chrono) :: Color3)
	end)
	-- золотой ореол топ-1 Титан-ранга
	local head = char:WaitForChild("Head", 10)
	if head then
		local crown = Instance.new("BillboardGui")
		crown.Size = UDim2.fromOffset(34, 34)
		crown.StudsOffset = Vector3.new(0, 2.6, 0)
		crown.AlwaysOnTop = true
		crown.Enabled = p:GetAttribute("Crown") == true
		crown.Parent = head
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.fromScale(1, 1)
		t.TextScaled = true
		t.Text = "👑"
		t.Parent = crown
		p:GetAttributeChangedSignal("Crown"):Connect(function()
			crown.Enabled = p:GetAttribute("Crown") == true
		end)
	end
end

local function hookPlayer(p: Player)
	if p.Character then
		task.spawn(decorate, p, p.Character)
	end
	p.CharacterAdded:Connect(function(c)
		decorate(p, c)
	end)
end
for _, p in Players:GetPlayers() do
	hookPlayer(p)
end
Players.PlayerAdded:Connect(hookPlayer)

local _l = Lighting
local _pl = player
return M
