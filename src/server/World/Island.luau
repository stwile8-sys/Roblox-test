--!nonstrict
-- Остров Хроно: хаб (лобби) с кристаллом, подиумами, лидербордами, алтарём ребёрса, статуями;
-- мосты к 8 базам и кольцо между ними; сезонный остров над хабом; освещение и пост-обработка.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local M = {}

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

local function bridge(parent: Instance, a: Vector3, b: Vector3, width: number)
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
	end
end

-- ── Пещера удачи ────────────────────────────────────────────
-- Холм в центре хаба: ступени-кольца, 4 пандуса, тёмный вход на вершине (CaveTrigger над ним).
-- Подземная комната под островом: CaveRoom/CaveSpawn, светящиеся кристаллы, поток воздуха.
local CAVE_TOP = 8
function M.buildCave(hub: Instance)
	local cave = Instance.new("Folder")
	cave.Name = "Cave"
	cave.Parent = hub
	local cols = { "#CDB8F5", "#BBA3EE", "#A98FE6" }
	for i, r in { 18, 14, 10 } do
		solid(cave, {
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(CAVE_TOP * i / 3, r * 2, r * 2),
			CFrame = CFrame.new(0, CAVE_TOP * i / 6, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Color = Color3.fromHex(cols[i]),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	-- пандусы на вершину
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local w = Instance.new("WedgePart")
		w.Anchored = true
		w.Size = Vector3.new(6, CAVE_TOP, 14)
		w.CFrame = CFrame.new(math.cos(a) * 21, CAVE_TOP / 2, math.sin(a) * 21) * CFrame.Angles(0, -a - math.pi / 2, 0)
		w.Color = Color3.fromHex("#FFF4DE")
		w.Material = Enum.Material.SmoothPlastic
		w.TopSurface = Enum.SurfaceType.Smooth
		w.Parent = cave
	end
	-- вход: тёмный колодец с обводкой и мерцающими искрами
	mk(cave, { Name = "Mouth", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 9, 9), CFrame = CFrame.new(0, CAVE_TOP + 0.15, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#14102A"), Material = Enum.Material.SmoothPlastic })
	mk(cave, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 10.6, 10.6), CFrame = CFrame.new(0, CAVE_TOP + 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
	for k = 1, 8 do
		local a = k / 8 * math.pi * 2
		local c = mk(cave, { Size = Vector3.new(1.4, 3, 1.4), CFrame = CFrame.new(math.cos(a) * 6.6, CAVE_TOP + 1.4, math.sin(a) * 6.6) * CFrame.Angles(0.25, a, 0.25), Color = if k % 2 == 0 then Palette.chrono else Color3.fromHex("#C9B3FF"), Material = Enum.Material.Neon })
		CollectionService:AddTag(c, "Pulse")
	end
	local glow = Instance.new("ParticleEmitter")
	glow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	glow.Color = ColorSequence.new(Palette.chrono)
	glow.LightEmission = 1
	glow.Rate = 10
	glow.Lifetime = NumberRange.new(1, 2)
	glow.Speed = NumberRange.new(4, 8)
	glow.EmissionDirection = Enum.NormalId.Top
	glow.Size = NumberSequence.new(0.6, 0)
	local holder = mk(cave, { Name = "Sparks", Size = Vector3.new(6, 0.2, 6), CFrame = CFrame.new(0, CAVE_TOP + 0.4, 0), Transparency = 1 })
	glow.Parent = holder
	local trig = mk(cave, { Name = "CaveTrigger", Size = Vector3.new(7, 3, 7), CFrame = CFrame.new(0, CAVE_TOP + 1.8, 0), Transparency = 1 })
	trig.CanTouch = true
	-- подземная комната
	local room = Instance.new("Folder")
	room.Name = "CaveRoom"
	room.Parent = hub
	local rc = Vector3.new(0, -110, 0)
	solid(room, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 40, 40), CFrame = CFrame.new(rc) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#3A2F6B"), Material = Enum.Material.SmoothPlastic })
	for k = 1, 16 do
		local a = k / 16 * math.pi * 2
		solid(room, { Size = Vector3.new(8.5, 30, 2), CFrame = CFrame.new(rc + Vector3.new(math.cos(a) * 19, 15, math.sin(a) * 19)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = Color3.fromHex("#4B3F8F"), Material = Enum.Material.SmoothPlastic })
	end
	solid(room, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 40, 40), CFrame = CFrame.new(rc + Vector3.new(0, 31, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local c = mk(room, { Size = Vector3.new(2, 5 + (k % 3) * 2, 2), CFrame = CFrame.new(rc + Vector3.new(math.cos(a) * 16, 3, math.sin(a) * 16)) * CFrame.Angles(0.3, a, 0.2), Color = if k % 2 == 0 then Palette.chrono else Color3.fromHex("#FF9FD2"), Material = Enum.Material.Neon })
		CollectionService:AddTag(c, "Pulse")
	end
	local spot = mk(room, { Name = "CaveSpawn", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(rc + Vector3.new(0, 1.5, 0)), Color = Palette.chrono, Material = Enum.Material.Neon, Transparency = 0.3 })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromHex("#C9B3FF")
	light.Range = 40
	light.Brightness = 3
	light.Parent = spot
	-- поток воздуха (включает сервер на время выброса)
	local wind = Instance.new("ParticleEmitter")
	wind.Name = "Wind"
	wind.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	wind.Color = ColorSequence.new(Color3.new(1, 1, 1))
	wind.Rate = 0
	wind.Lifetime = NumberRange.new(0.8, 1.2)
	wind.Speed = NumberRange.new(40, 60)
	wind.EmissionDirection = Enum.NormalId.Top
	wind.SpreadAngle = Vector2.new(10, 10)
	wind.Size = NumberSequence.new(1.2, 0)
	wind.Parent = spot
	local wind2 = wind:Clone()
	wind2.Parent = holder
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

	-- кристалл в центре
	M.buildCave(hub)
	local crystal = Instance.new("Model")
	crystal.Name = "Crystal"
	crystal.Parent = hub
	local ccf = CFrame.new(0, 26, 0)
	for i = 1, 4 do
		local p = mk(crystal, { Size = Vector3.new(5, 14, 5), CFrame = ccf * CFrame.Angles(0, i * math.pi / 4, 0), Color = Palette.chrono, Material = Enum.Material.Glass, Transparency = 0.15 })
		CollectionService:AddTag(p, "Spin")
		p:SetAttribute("Speed", 25)
		p:SetAttribute("Center", ccf.Position)
	end
	local core = mk(crystal, { Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = ccf, Color = Color3.fromHex("#E0FBFF"), Material = Enum.Material.Neon })
	CollectionService:AddTag(core, "Pulse")
	local cl = Instance.new("PointLight")
	cl.Color = Palette.chrono
	cl.Range = 45
	cl.Brightness = 2.5
	cl.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Palette.chrono)
	sparks.LightEmission = 1
	sparks.Rate = 12
	sparks.Lifetime = NumberRange.new(3, 5)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new(0.6, 0)
	sparks.Parent = core
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local f = mk(crystal, { Size = Vector3.new(1.5, 3.5, 1.5), CFrame = CFrame.new(math.cos(a) * 11, 27 + math.sin(a * 2) * 2, math.sin(a) * 11) * CFrame.Angles(0.3, a, 0.3), Color = Palette.chrono, Material = Enum.Material.Neon })
		CollectionService:AddTag(f, "Float")
	end

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
	solid(season, { Size = Vector3.new(10, 2, 10), CFrame = CFrame.new(0, 91, 0), Color = Palette.gold, Material = Enum.Material.SmoothPlastic })
	mk(season, { Name = "Vault", Size = Vector3.new(4, 0.4, 4), CFrame = CFrame.new(0, 92.2, 0), Color = Palette.chrono, Material = Enum.Material.Neon })
	local cage = Instance.new("Model")
	cage.Name = "Cage"
	cage:SetAttribute("MaxHP", 3000)
	cage.Parent = season
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		solid(cage, { Name = "Bar" .. i, Size = Vector3.new(4.2, 12, 1), CFrame = CFrame.new(math.cos(a) * 5, 96, math.sin(a) * 5) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = Palette.thief, Material = Enum.Material.ForceField })
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
	for n = 1, 10 do
		local a = n / 10 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(22, 38)
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
