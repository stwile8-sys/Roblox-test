--!nonstrict
-- Остров Хроно: хаб (лобби) с кристаллом, подиумами, лидербордами, алтарём ребёрса, статуями;
-- мосты к 8 базам и кольцо между ними; сезонный остров над хабом; освещение и пост-обработка.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local M: any = {}

local STATUES = { "l_titan", "l_eater", "e_dragon", "x_rift" }
local R = 230

local function mk(parent: Instance, props: { [string]: any }): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = parent
	return p
end

local function solid(parent: Instance, props: { [string]: any }): BasePart
	local p = mk(parent, props)
	p.CanCollide = true
	p.CanQuery = true
	return p
end


-- Милый парящий остров: травяной диск сверху и сужающийся вниз земляной конус из цилиндров
local function floatingIsland(parent: Instance, center: Vector3, radius: number, seed: number)
	if parent:IsA("Instance") then
		parent:SetAttribute("IslandCenter", center)
		parent:SetAttribute("IslandRadius", radius)
	end
	local rng = Random.new(seed)
	local grass = Instance.new("Part")
	grass.Anchored = true
	grass.CanCollide = false
	grass.CanQuery = false
	grass.CanTouch = false
	grass.CastShadow = false
	grass.Shape = Enum.PartType.Cylinder
	grass.Size = Vector3.new(3, radius * 2, radius * 2)
	grass.CFrame = CFrame.new(center + Vector3.new(0, -1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	grass.Color = Color3.fromHex("#7DD87A")
	grass.Material = Enum.Material.SmoothPlastic
	grass:SetAttribute("IslandVis", true)
	grass.Parent = parent
	local layers = { { "#E2B98A", 0.92, 6 }, { "#D4A574", 0.74, 8 }, { "#C29166", 0.52, 9 }, { "#AE7F5A", 0.3, 10 } }
	local y = -3
	for _, l in layers do
		local h = l[3]
		local p = grass:Clone()
		p.Size = Vector3.new(h, radius * 2 * l[2], radius * 2 * l[2])
		p.CFrame = CFrame.new(center + Vector3.new(0, y - h / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
		p.Color = Color3.fromHex(l[1])
		p.Parent = parent
		y -= h
	end
	-- пастельные кристаллы снизу
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2 + rng:NextNumber(0, 1)
		local r = radius * rng:NextNumber(0.2, 0.5)
		local c = grass:Clone()
		c.Shape = Enum.PartType.Block
		c.Size = Vector3.new(3, rng:NextNumber(6, 12), 3)
		c.CFrame = CFrame.new(center + Vector3.new(math.cos(a) * r, y + 4, math.sin(a) * r)) * CFrame.Angles(math.pi + rng:NextNumber(-0.3, 0.3), a, rng:NextNumber(-0.3, 0.3))
		c.Color = if i % 2 == 0 then Color3.fromHex("#8FF0FF") else Color3.fromHex("#C9B3FF")
		c.Material = Enum.Material.Neon
		c.Parent = parent
	end
end

local function dir(deg: number): Vector3
	local a = math.rad(deg)
	return Vector3.new(math.sin(a), 0, math.cos(a))
end

local function board(parent: Instance, name: string, title: string, deg: number)
	local d = dir(deg)
	local pos = d * 58 + Vector3.new(0, 9, 0)
	local p = solid(parent, { Name = name, Size = Vector3.new(16, 14, 1), CFrame = CFrame.lookAt(pos, Vector3.new(0, 9, 0)), Color = Color3.fromHex("#FFF8EC"), Material = Enum.Material.SmoothPlastic })
	mk(parent, { Size = Vector3.new(17.4, 15.4, 0.6), CFrame = p.CFrame * CFrame.new(0, 0, 0.6), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Gui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	gui.Parent = p
	local t = Instance.new("TextLabel")
	t.Name = "Title"
	t.BackgroundTransparency = 1
	t.Size = UDim2.new(1, 0, 0.13, 0)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = Color3.fromHex("#2A2140")
	t.Text = title
	t.Parent = gui
	local list = Instance.new("Frame")
	list.Name = "List"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.15)
	list.Size = UDim2.fromScale(0.92, 0.83)
	list.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list
	-- стойки
	for s = -1, 1, 2 do
		solid(parent, { Size = Vector3.new(1, 9, 1), CFrame = p.CFrame * CFrame.new(s * 7, -11, 0), Color = Palette.steel, Material = Enum.Material.Metal })
	end
end

M.bridges = {} :: { { a: Vector3, b: Vector3, w: number, parts: { BasePart } } }
local function bridge(parent: Instance, a: Vector3, b: Vector3, width: number)
	local rec = { a = a, b = b, w = width, parts = {} }
	table.insert(M.bridges, rec)
	local before = {}
	for _, k in parent:GetChildren() do
		before[k] = true
	end
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b)
	solid(parent, { Size = Vector3.new(width, 1.6, len), CFrame = cf * CFrame.new(0, -0.8, 0), Color = Color3.fromHex("#6B5440"), Material = Enum.Material.WoodPlanks })
	for s = -1, 1, 2 do
		solid(parent, { Size = Vector3.new(0.6, 2.4, len), CFrame = cf * CFrame.new(s * width / 2, 1.2, 0), Color = Palette.wood, Material = Enum.Material.Wood })
		mk(parent, { Size = Vector3.new(0.7, 0.3, len), CFrame = cf * CFrame.new(s * width / 2, 2.55, 0), Color = Color3.fromHex("#FFE3B0"), Material = Enum.Material.SmoothPlastic })
	end
	-- опоры-кристаллы снизу
	local n = math.floor(len / 30)
	for i = 1, n do
		local c = mk(parent, { Size = Vector3.new(2, 8, 2), CFrame = cf * CFrame.new(0, -6, -len / 2 + i * len / (n + 1)) * CFrame.Angles(math.pi, 0, 0.3), Color = Palette.chrono, Material = Enum.Material.Neon, Transparency = 0.2 })
		CollectionService:AddTag(c, "Float")
		c:SetAttribute("Keep", true)
	end
	for _, k in parent:GetChildren() do
		if not before[k] and k:IsA("BasePart") and not k:GetAttribute("Keep") then
			table.insert(rec.parts, k)
		end
	end
end

-- ── Золотой сундук в центре хаба ─────────────────────────────
local INK = Color3.fromHex("#2A2140")
local GOLD = Color3.fromHex("#FFC93C")
local GOLD_D = Color3.fromHex("#E09A00")

function M.buildChest(hub: Instance)
	local f = Instance.new("Model")
	f.Name = "Chest"
	f.Parent = hub
	-- пьедестал: три яруса с тёмными ободками
	local y = 0
	for i, t in { { 20, 1.6, "#FFF4DE" }, { 16, 1.6, "#F6D7A7" }, { 13, 1.4, "#FFE9A8" } } do
		local d, h = t[1], t[2]
		solid(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, d, d), CFrame = CFrame.new(0, y + h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex(t[3]), Material = Enum.Material.SmoothPlastic })
		mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, d + 0.5, d + 0.5), CFrame = CFrame.new(0, y + h - 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = INK, Material = Enum.Material.SmoothPlastic })
		y += h
		local _ = i
	end
	-- корпус сундука
	local base = CFrame.new(0, y, 0)
	local W, H, D = 10, 5.5, 7
	solid(f, { Name = "Body", Size = Vector3.new(W, H, D), CFrame = base * CFrame.new(0, H / 2, 0), Color = GOLD, Material = Enum.Material.SmoothPlastic })
	-- тёмные рёбра по углам и полосы
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			mk(f, { Size = Vector3.new(0.7, H + 0.2, 0.7), CFrame = base * CFrame.new(sx * W / 2, H / 2, sz * D / 2), Color = INK, Material = Enum.Material.SmoothPlastic })
		end
	end
	for _, sx in { -0.28, 0.28 } do
		mk(f, { Size = Vector3.new(1.1, H + 0.1, D + 0.15), CFrame = base * CFrame.new(sx * W, H / 2, 0), Color = GOLD_D, Material = Enum.Material.SmoothPlastic })
	end
	mk(f, { Size = Vector3.new(W + 0.3, 0.6, D + 0.3), CFrame = base * CFrame.new(0, 0.3, 0), Color = INK, Material = Enum.Material.SmoothPlastic })
	-- замок спереди (−Z смотрит на мост к базе 5)
	mk(f, { Size = Vector3.new(2.2, 2.6, 0.5), CFrame = base * CFrame.new(0, H - 1.3, -D / 2 - 0.2), Color = INK, Material = Enum.Material.SmoothPlastic })
	local gem = mk(f, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = base * CFrame.new(0, H - 1.3, -D / 2 - 0.45), Color = Palette.chrono, Material = Enum.Material.Neon })
	CollectionService:AddTag(gem, "Pulse")
	-- крышка приоткрыта: полуцилиндр, повернутый на заднем шарнире
	local hinge = base * CFrame.new(0, H, D / 2) * CFrame.Angles(math.rad(-28), 0, 0)
	local lidCF = hinge * CFrame.new(0, 0, -D / 2)
	local lid = mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(W, D, D), CFrame = lidCF * CFrame.Angles(0, 0, 0), Color = GOLD, Material = Enum.Material.SmoothPlastic })
	lid.Size = Vector3.new(W, D, D)
	-- нижнюю половину крышки прячет «срез» — тёмная пластина
	mk(f, { Size = Vector3.new(W + 0.2, 0.4, D + 0.2), CFrame = lidCF * CFrame.new(0, -0.1, 0), Color = INK, Material = Enum.Material.SmoothPlastic })
	for _, sx in { -0.28, 0.28 } do
		mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.1, D + 0.15, D + 0.15), CFrame = lidCF * CFrame.new(sx * W, 0, 0), Color = GOLD_D, Material = Enum.Material.SmoothPlastic })
	end
	-- сокровища внутри: монеты и свечение
	local glow = mk(f, { Size = Vector3.new(W - 1, 0.3, D - 1), CFrame = base * CFrame.new(0, H + 0.1, 0), Color = Color3.fromHex("#FFF1A8"), Material = Enum.Material.Neon })
	CollectionService:AddTag(glow, "Pulse")
	local rng = Random.new(42)
	for _ = 1, 14 do
		mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.4, 1.4), CFrame = base * CFrame.new(rng:NextNumber(-3.8, 3.8), H + rng:NextNumber(0.2, 1.4), rng:NextNumber(-2.4, 2.4)) * CFrame.Angles(rng:NextNumber(-0.8, 0.8), rng:NextNumber(0, 3), math.pi / 2 + rng:NextNumber(-0.6, 0.6)), Color = GOLD, Material = Enum.Material.Metal })
	end
	for _, info in { { -2.5, Color3.fromHex("#FF5C7A") }, { 1.2, Palette.chrono }, { 3, Color3.fromHex("#B47CFF") } } do
		local g = mk(f, { Size = Vector3.new(1, 1.4, 1), CFrame = base * CFrame.new(info[1], H + 1.2, 0.8) * CFrame.Angles(0.4, info[1], 0.3), Color = info[2], Material = Enum.Material.Neon })
		CollectionService:AddTag(g, "Pulse")
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#FFD36B")
	light.Range = 30
	light.Brightness = 2.5
	light.Parent = glow
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sp.Color = ColorSequence.new(GOLD)
	sp.LightEmission = 1
	sp.Rate = 10
	sp.Lifetime = NumberRange.new(1.5, 2.5)
	sp.Speed = NumberRange.new(3, 6)
	sp.EmissionDirection = Enum.NormalId.Top
	sp.SpreadAngle = Vector2.new(30, 30)
	sp.Size = NumberSequence.new(0.6, 0)
	sp.Parent = glow
	-- монеты, парящие вокруг сундука
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		local c = mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.2, 2.2), CFrame = CFrame.new(math.cos(a) * 9, y + 9 + (i % 2) * 1.5, math.sin(a) * 9) * CFrame.Angles(0, a, 0), Color = GOLD, Material = Enum.Material.Metal })
		CollectionService:AddTag(c, "Float")
	end
end

-- ── Кольцевой конвейер вокруг сундука ───────────────────────
-- Едет по дуге от портала-начала до портала-конца; между порталами небольшой зазор.
local RING_R = 27
local RING_W = 7
local RING_A0 = math.rad(-70)
local RING_GAP = math.rad(26)

function M.buildRing(hub: Instance)
	local f = Instance.new("Model")
	f.Name = "Ring"
	f.Parent = hub
	local span = math.pi * 2 - RING_GAP
	local N = 44
	local d = span / N
	for i = 0, N - 1 do
		local a = RING_A0 + d * (i + 0.5)
		local cf = CFrame.new(math.cos(a) * RING_R, 0, math.sin(a) * RING_R) * CFrame.Angles(0, -a, 0)
		local seg = RING_R * d * 1.08
		solid(f, { Size = Vector3.new(RING_W, 1.2, seg), CFrame = cf * CFrame.new(0, 0.6, 0), Color = if i % 2 == 0 then Color3.fromHex("#EFE4FF") else Color3.fromHex("#E4D6FB"), Material = Enum.Material.SmoothPlastic })
		for _, side in { -1, 1 } do
			local r2 = RING_R + side * (RING_W / 2 + 0.4)
			local cf2 = CFrame.new(math.cos(a) * r2, 0, math.sin(a) * r2) * CFrame.Angles(0, -a, 0)
			solid(f, { Size = Vector3.new(0.8, 2, r2 * d * 1.1), CFrame = cf2 * CFrame.new(0, 1, 0), Color = Color3.fromHex("#FFE3B0"), Material = Enum.Material.SmoothPlastic })
			mk(f, { Size = Vector3.new(0.9, 0.25, r2 * d * 1.1), CFrame = cf2 * CFrame.new(0, 2.05, 0), Color = INK, Material = Enum.Material.SmoothPlastic })
		end
	end
	-- порталы начала и конца, развёрнуты поперёк ленты
	local function portal(a: number, color: Color3, name: string)
		local p = CFrame.new(math.cos(a) * RING_R, 0, math.sin(a) * RING_R) * CFrame.Angles(0, -a, 0)
		local holder = mk(f, { Name = name, Size = Vector3.new(1, 1, 1), CFrame = p * CFrame.new(0, 4, 0), Transparency = 1 })
		for k = 1, 12 do
			local t = k / 12 * math.pi * 2
			mk(f, { Size = Vector3.new(1.4, 1.4, 1.1), CFrame = p * CFrame.new(math.cos(t) * 4.6, 4.6 + math.sin(t) * 4.6, 0) * CFrame.Angles(0, 0, t), Color = INK, Material = Enum.Material.SmoothPlastic })
			mk(f, { Size = Vector3.new(1, 1, 1.3), CFrame = p * CFrame.new(math.cos(t) * 4.6, 4.6 + math.sin(t) * 4.6, 0) * CFrame.Angles(0, 0, t), Color = color, Material = Enum.Material.Neon })
		end
		local disc = mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 8.4, 8.4), CFrame = p * CFrame.new(0, 4.6, 0) * CFrame.Angles(0, math.pi / 2, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.45 })
		CollectionService:AddTag(disc, "Pulse")
		return holder
	end
	portal(RING_A0, Palette.chrono, "PortalIn")
	portal(RING_A0 + span, Palette.thief, "PortalOut")
	hub:SetAttribute("RingR", RING_R)
	hub:SetAttribute("RingA0", RING_A0)
	hub:SetAttribute("RingSpan", span)
	hub:SetAttribute("RingY", 1.2)
end

function M.build()
	local map = Instance.new("Folder")
	map.Name = "Map"
	map.Parent = workspace
	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = map

	-- диск хаба
	solid(hub, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 140, 140), CFrame = CFrame.new(0, -2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#D6CCF2"), Material = Enum.Material.SmoothPlastic })
	mk(hub, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 60, 60), CFrame = CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#C3B4EC"), Material = Enum.Material.SmoothPlastic })
	mk(hub, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 62, 62), CFrame = CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#9FE7F5"), Material = Enum.Material.SmoothPlastic })
	floatingIsland(hub, Vector3.new(0, -4, 0), 74, 3)

	-- общий конвейер артефактов на центральном острове

	-- в центре: пьедестал с золотым сундуком, вокруг него кольцевой конвейер с монстрами
	M.buildChest(hub)
	M.buildRing(hub)

	-- всё, что стоит между мостами (мосты на углах 0,45,…): подиумы, доски, алтарь, портал, статуи
	for i = 1, 4 do
		local deg = 22.5 + (i - 1) * 90 -- 22.5, 112.5, 202.5, 292.5
		local pm = Instance.new("Model")
		pm.Name = "Podium" .. i
		pm.Parent = hub
		local pos = dir(deg) * 40
		local stand = solid(pm, { Name = "Stand", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 8, 8), CFrame = CFrame.new(pos + Vector3.new(0, 1.5, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Palette.dark, Material = Enum.Material.Metal })
		stand.Name = "Stand"
		mk(pm, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 8.4, 8.4), CFrame = CFrame.new(pos + Vector3.new(0, 3.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = ({ Palette.chrono, Palette.thief, Palette.gold, Palette.alarm })[i], Material = Enum.Material.Neon })
		local pc = ({ Palette.chrono, Palette.thief, Palette.gold, Palette.alarm })[i]
		local desc = Instance.new("HumanoidDescription")
		desc.HeadColor = Color3.fromHex("#FFE0BD")
		desc.TorsoColor = pc
		desc.LeftArmColor = pc
		desc.RightArmColor = pc
		desc.LeftLegColor = Color3.fromHex("#2A2140")
		desc.RightLegColor = Color3.fromHex("#2A2140")
		local ok, rig = pcall(function()
			return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		end)
		if ok and rig then
			rig.Name = "Mannequin"
			local hrp = rig:FindFirstChild("HumanoidRootPart")
			if hrp then
				hrp.Anchored = true
			end
			local hum = rig:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
			rig:PivotTo(CFrame.lookAt(pos + Vector3.new(0, 6.3, 0), Vector3.new(0, 6.3, 0)))
			rig.Parent = pm
		end
	end
	board(hub, "Board_Titan", "ТИТАН-РАНГ", 67.5 - 10)
	board(hub, "Board_Collection", "КОЛЛЕКЦИЯ", 67.5 + 10)
	board(hub, "Board_Clans", "КЛАНЫ", 157.5)

	-- алтарь ребёрса (5 ступеней)
	local altar = Instance.new("Model")
	altar.Name = "Altar"
	altar.Parent = hub
	local apos = dir(247.5) * 44
	for s = 1, 5 do
		local w = 18 - s * 3
		local p = solid(altar, { Size = Vector3.new(w, 1.2, w), CFrame = CFrame.new(apos + Vector3.new(0, (s - 0.5) * 1.2, 0)), Color = if s == 5 then Palette.chrono else Palette.stone, Material = if s == 5 then Enum.Material.Neon else Enum.Material.SmoothPlastic })
		if s == 5 then
			p.Name = "Top"
		end
	end
	-- сезонный портал
	local portal = mk(hub, { Name = "SeasonPortal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 12, 12), CFrame = CFrame.lookAt(dir(337.5) * 50 + Vector3.new(0, 6.5, 0), Vector3.new(0, 6.5, 0)) * CFrame.Angles(0, math.pi / 2, 0), Color = Palette.thief, Material = Enum.Material.Neon, Transparency = 0.3 })
	portal.CanTouch = true
	CollectionService:AddTag(portal, "Pulse")
	-- статуи-маскоты (клиент рисует существ на якорях)
	local statues = Instance.new("Folder")
	statues.Name = "Statues"
	statues.Parent = hub
	for i, id in STATUES do
		local deg = 22.5 + (i - 1) * 90 + 45 * 0 + 12
		local pos = dir(deg + 22) * 64
		solid(statues, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 8, 8), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#FFF4DE"), Material = Enum.Material.SmoothPlastic })
		local a = mk(statues, { Name = "Statue" .. i, Size = Vector3.new(5, 5, 5), CFrame = CFrame.lookAt(pos + Vector3.new(0, 4 + 6.5, 0), Vector3.new(0, 10.5, 0)), Transparency = 1 })
		a:SetAttribute("Kind", "statue")
		a:SetAttribute("Id", id)
		a:SetAttribute("Scale", 1.4)
		CollectionService:AddTag(a, "Art")
	end

	-- мосты к базам и кольцо
	local bridges = Instance.new("Folder")
	bridges.Name = "Bridges"
	bridges.Parent = map
	for i = 1, 8 do
		local d = dir((i - 1) * 45)
		bridge(bridges, d * 69, d * (R - 60), 14)
		-- боковое кольцо: от правого края базы i к левому краю базы i+1
		local pa = d * R
		local pb = dir(i * 45) * R
		local u = (pb - pa).Unit
		bridge(bridges, pa + u * 62, pb - u * 62, 12)
	end

	-- сезонный остров
	local season = Instance.new("Folder")
	season.Name = "Season"
	season.Parent = map
	solid(season, { Name = "Ground", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 90, 90), CFrame = CFrame.new(0, 88, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#E9E1FF"), Material = Enum.Material.SmoothPlastic })
	floatingIsland(season, Vector3.new(0, 86, 0), 48, 9)
	-- алтарь: три круглых яруса
	for k, t in { { 14, "#FFF4DE" }, { 11, "#F6D7A7" }, { 8, "#FFE9A8" } } do
		solid(season, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, t[1], t[1]), CFrame = CFrame.new(0, 90 + k - 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex(t[2]), Material = Enum.Material.SmoothPlastic })
		mk(season, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, t[1] + 0.4, t[1] + 0.4), CFrame = CFrame.new(0, 90 + k - 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
	end
	mk(season, { Name = "Vault", Size = Vector3.new(4, 0.4, 4), CFrame = CFrame.new(0, 93.2, 0), Color = Palette.chrono, Material = Enum.Material.Neon })
	-- клетка: прутья ломаются (Cage), каркас остаётся (CageFrame)
	local cage = Instance.new("Model")
	cage.Name = "Cage"
	cage:SetAttribute("MaxHP", 3000)
	cage.Parent = season
	local frame = Instance.new("Folder")
	frame.Name = "CageFrame"
	frame.Parent = season
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 4.6, 99, math.sin(a) * 4.6)
		solid(cage, { Name = "Bar" .. i, Shape = Enum.PartType.Cylinder, Size = Vector3.new(11, 0.9, 0.9), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#4B3F8F"), Material = Enum.Material.SmoothPlastic })
	end
	for _, y in { 93.6, 104.6 } do
		for i = 1, 20 do
			local a = i / 20 * math.pi * 2
			mk(frame, { Size = Vector3.new(1.6, 1, 1.8), CFrame = CFrame.new(math.cos(a) * 4.6, y, math.sin(a) * 4.6) * CFrame.Angles(0, -a, 0), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
		end
	end
	-- купол-крыша с камнем
	mk(frame, { Shape = Enum.PartType.Ball, Size = Vector3.new(10, 4, 10), CFrame = CFrame.new(0, 105.6, 0), Color = Color3.fromHex("#FFC93C"), Material = Enum.Material.SmoothPlastic })
	local top = mk(frame, { Name = "Top", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(0, 108, 0), Color = Palette.chrono, Material = Enum.Material.Neon })
	CollectionService:AddTag(top, "Pulse")
	-- дорожка от портала к алтарю
	for k = 1, 5 do
		mk(season, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 4, 4), CFrame = CFrame.new(0, 90.1, 9 + k * 4.6) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#FFF4DE"), Material = Enum.Material.SmoothPlastic })
	end
	local ret = mk(season, { Name = "ReturnPortal", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 10, 10), CFrame = CFrame.new(0, 95, 36) * CFrame.Angles(0, math.pi / 2, 0), Color = Palette.chrono, Material = Enum.Material.Neon, Transparency = 0.3 })
	ret.CanTouch = true
	CollectionService:AddTag(ret, "Pulse")
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = season

	-- атмосфера: свечение, лёгкий туман, цвет
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Threshold = 1.3
	bloom.Size = 28
	bloom.Parent = Lighting
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.3
	atm.Offset = 0.05
	atm.Color = Color3.fromHex("#C7D6FF")
	atm.Decay = Color3.fromHex("#8FA8E0")
	atm.Glare = 0
	atm.Haze = 0
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.12
	cc.Contrast = 0.12
	cc.Parent = Lighting
	local sky = Instance.new("Sky")
	sky.StarCount = 3000
	sky.CelestialBodiesShown = true
	sky.Parent = Lighting
end

-- ── Сезонный декор ──────────────────────────────────────────
local THEMES = {
	{ ground = "#8A6A4A", main = "#FF7A1A", acc = "#7B2FF7", kind = "pumpkin" },
	{ ground = "#DDEFFF", main = "#BFEFFF", acc = "#FF2E63", kind = "snow" },
	{ ground = "#E8D3A0", main = "#4CAF50", acc = "#FFE066", kind = "palm" },
	{ ground = "#5E8C4A", main = "#FFB3D9", acc = "#FFFFFF", kind = "sakura" },
	{ ground = "#6A5FB8", main = "#8C7BFF", acc = "#FFB347", kind = "planet" },
	{ ground = "#4F9BD1", main = "#FF6F91", acc = "#5FFFC8", kind = "coral" },
}

function M.setSeason(i: number)
	local season = workspace.Map:FindFirstChild("Season")
	if not season then
		return
	end
	local t = THEMES[i] or THEMES[1]
	season.Ground.Color = Color3.fromHex(t.ground)
	local decor = season.Decor
	decor:ClearAllChildren()
	local main, acc = Color3.fromHex(t.main), Color3.fromHex(t.acc)
	local rng = Random.new(i * 77)
	for n = 1, 18 do
		local a = n / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		-- не ставить на дорожку к порталу
		if math.abs(math.sin(a) - 1) < 0.12 then
			continue
		end
		local r = if n % 2 == 0 then rng:NextNumber(30, 40) else rng:NextNumber(17, 25)
		local pos = Vector3.new(math.cos(a) * r, 90, math.sin(a) * r)
		if t.kind == "pumpkin" then
			mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3.2, 4), CFrame = CFrame.new(pos + Vector3.new(0, 1.6, 0)), Color = main, Material = Enum.Material.SmoothPlastic })
			local f = mk(decor, { Size = Vector3.new(0.6, 1, 0.6), CFrame = CFrame.new(pos + Vector3.new(0, 3.6, 0)), Color = acc, Material = Enum.Material.Neon })
			CollectionService:AddTag(f, "Pulse")
		elseif t.kind == "snow" then
			mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(4, 4, 4), CFrame = CFrame.new(pos + Vector3.new(0, 2, 0)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Snow })
			mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)), Color = Color3.new(1, 1, 1), Material = Enum.Material.Snow })
			mk(decor, { Size = Vector3.new(0.4, 0.4, 1.2), CFrame = CFrame.new(pos + Vector3.new(0, 5, -1.3)), Color = Color3.fromHex("#FF7A1A"), Material = Enum.Material.SmoothPlastic })
		elseif t.kind == "palm" then
			mk(decor, { Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(pos + Vector3.new(0, 4.5, 0)) * CFrame.Angles(0, 0, 0.15), Color = Color3.fromHex("#8B5A2B"), Material = Enum.Material.Wood })
			for k = 1, 4 do
				mk(decor, { Size = Vector3.new(0.3, 0.6, 5), CFrame = CFrame.new(pos + Vector3.new(0.7, 9, 0)) * CFrame.Angles(-0.4, k * math.pi / 2, 0) * CFrame.new(0, 0, -2.4), Color = main, Material = Enum.Material.Grass })
			end
		elseif t.kind == "sakura" then
			mk(decor, { Size = Vector3.new(1, 7, 1), CFrame = CFrame.new(pos + Vector3.new(0, 3.5, 0)), Color = Color3.fromHex("#6D4C41"), Material = Enum.Material.Wood })
			mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(7, 5, 7), CFrame = CFrame.new(pos + Vector3.new(0, 8, 0)), Color = main, Material = Enum.Material.SmoothPlastic })
		elseif t.kind == "planet" then
			local p = mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, rng:NextNumber(6, 14), 0)), Color = if n % 2 == 0 then main else acc, Material = Enum.Material.Neon })
			CollectionService:AddTag(p, "Float")
		else
			for k = -1, 1 do
				mk(decor, { Size = Vector3.new(0.6, 4, 0.6), CFrame = CFrame.new(pos + Vector3.new(k * 0.8, 2, 0)) * CFrame.Angles(0, 0, k * 0.4), Color = if k == 0 then acc else main, Material = Enum.Material.SmoothPlastic })
			end
			local b = mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(pos + Vector3.new(0, 6, 0)), Color = Color3.fromHex("#BFEFFF"), Material = Enum.Material.Glass, Transparency = 0.4 })
			CollectionService:AddTag(b, "Float")
		end
	end
	if M.dress then
		pcall(M.dress.seasonDecor, i)
	end
	-- тематичный акцент на хабе: кольцо цвета сезона
	local hub = workspace.Map.Hub
	local old = hub:FindFirstChild("SeasonRing")
	if old then
		old:Destroy()
	end
	local ring = Instance.new("Folder")
	ring.Name = "SeasonRing"
	ring.Parent = hub
	for n = 1, 16 do
		local a = (n + 0.5) / 16 * math.pi * 2
		mk(ring, { Size = Vector3.new(1.2, 3, 1.2), CFrame = CFrame.new(math.sin(a) * 68, 1.5, math.cos(a) * 68), Color = if n % 2 == 0 then main else acc, Material = Enum.Material.Neon })
	end
end

return M
