--!nonstrict
-- Строитель баз (8 участков вокруг хаба). Имена и раскладка — по docs/ARCH.md, их использует логика.
-- Локальная −Z базы смотрит на хаб (там ворота). Пол 120×120, верх пола на локальном y = 0.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local M = {}

local R = 230

local function mk(parent: Instance, props: { [string]: any }, class: string?): BasePart
	local p = Instance.new(class or "Part")
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
	p.CastShadow = true
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

function M.baseCFrame(index: number): CFrame
	local a = math.rad((index - 1) * 45)
	local pos = Vector3.new(math.sin(a) * R, 0, math.cos(a) * R)
	return CFrame.lookAt(pos, Vector3.new(0, 0, 0))
end

-- ── Стены: геометрия сегментов ──────────────────────────────
-- имя → (центр по x, z; длина; поворот: true = вдоль Z)
local SEG_LEN = 116 / 3
local SEGS = {}
for i = 1, 3 do
	local off = -58 + SEG_LEN * (i - 0.5)
	SEGS["F" .. i] = { x = off, z = -58, alongZ = false }
	SEGS["B" .. i] = { x = -off, z = 58, alongZ = false }
	SEGS["R" .. i] = { x = 58, z = off, alongZ = true }
	SEGS["L" .. i] = { x = -58, z = -off, alongZ = true }
end

local WALL_STYLE = {
	{ color = Color3.fromHex("#E0A96D"), mat = Enum.Material.WoodPlanks, trim = Color3.fromHex("#B5764A"), trimMat = Enum.Material.Wood },
	{ color = Color3.fromHex("#D9D2C5"), mat = Enum.Material.SmoothPlastic, trim = Color3.fromHex("#B8AE9C"), trimMat = Enum.Material.SmoothPlastic },
	{ color = Color3.fromHex("#B9C6D6"), mat = Enum.Material.SmoothPlastic, trim = Color3.fromHex("#8FA0B5"), trimMat = Enum.Material.Metal },
	{ color = Palette.steel, mat = Enum.Material.Metal, trim = Palette.gold, trimMat = Enum.Material.Metal },
	{ color = Palette.chrono, mat = Enum.Material.ForceField, trim = Color3.fromHex("#E0FBFF"), trimMat = Enum.Material.Neon },
}

local function segDecor(seg: BasePart, level: number)
	local old = seg:FindFirstChild("Decor")
	if old then
		old:Destroy()
	end
	local style = WALL_STYLE[level] or WALL_STYLE[1]
	local f = Instance.new("Folder")
	f.Name = "Decor"
	f.Parent = seg
	local len = seg.Size.X
	-- верхний кант и столбы по краям
	mk(f, { Size = Vector3.new(len, 1, 2.6), CFrame = seg.CFrame * CFrame.new(0, 7.3, 0), Color = style.trim, Material = style.trimMat })
	for s = -1, 1, 2 do
		mk(f, { Size = Vector3.new(2.8, 16, 2.8), CFrame = seg.CFrame * CFrame.new(s * len / 2, 1, 0), Color = style.trim, Material = style.trimMat })
	end
	if level == 1 then
		for i = 1, 3 do
			mk(f, { Size = Vector3.new(len, 0.5, 2.2), CFrame = seg.CFrame * CFrame.new(0, -6 + i * 3.5, 0), Color = style.trim, Material = Enum.Material.Wood })
		end
	elseif level == 4 then
		for i = 1, 5 do
			mk(f, { Size = Vector3.new(0.8, 2, 0.8), CFrame = seg.CFrame * CFrame.new(-len / 2 + i * len / 6, 8.5, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = Palette.gold, Material = Enum.Material.Metal })
		end
	elseif level == 5 then
		mk(f, { Size = Vector3.new(len, 0.4, 2.4), CFrame = seg.CFrame * CFrame.new(0, -4, 0), Color = Palette.chrono, Material = Enum.Material.Neon })
		mk(f, { Size = Vector3.new(len, 0.4, 2.4), CFrame = seg.CFrame * CFrame.new(0, 3, 0), Color = Palette.chrono, Material = Enum.Material.Neon })
	end
	-- трещины (показываются при повреждении)
	local cracks = Instance.new("Folder")
	cracks.Name = "Cracks"
	cracks.Parent = f
	for i = 1, 4 do
		local c = mk(cracks, {
			Size = Vector3.new(0.3, 3 + i, 2.3),
			CFrame = seg.CFrame * CFrame.new(-len / 3 + i * len / 6, (i % 2) * 2 - 1, 0) * CFrame.Angles(0, 0, (i % 2 == 0) and 0.5 or -0.4),
			Color = Color3.fromHex("#1A1A2E"),
			Material = Enum.Material.SmoothPlastic,
			Transparency = 1,
		})
		c:SetAttribute("CrackAt", 0.25 * i)
	end
end

function M.setWallLevel(base: any, level: number)
	local style = WALL_STYLE[level] or WALL_STYLE[1]
	for _, seg in base.Walls:GetChildren() do
		if seg:IsA("BasePart") then
			seg.Color = style.color
			seg.Material = style.mat
			seg.Transparency = if level == 5 then 0.15 else 0
			seg:SetAttribute("Level", level)
			if seg:GetAttribute("Gate") then
				seg.Color = if level == 5 then Palette.chrono else style.trim
			end
			segDecor(seg, level)
			if seg:GetAttribute("Broken") then
				M.setSegmentBroken(seg, true)
			end
		end
	end
end

function M.setSegmentDamage(seg: BasePart, frac: number)
	local decor = seg:FindFirstChild("Decor")
	local cracks = decor and decor:FindFirstChild("Cracks")
	if not cracks then
		return
	end
	for _, c in cracks:GetChildren() do
		if c:IsA("BasePart") then
			c.Transparency = if frac >= ((c:GetAttribute("CrackAt") or 1) :: number) then 0.1 else 1
		end
	end
end

function M.setSegmentBroken(seg: BasePart, broken: boolean)
	seg:SetAttribute("Broken", broken)
	local level = (seg:GetAttribute("Level") or 1) :: number
	seg.Transparency = if broken then 1 else (if level == 5 then 0.15 else 0)
	seg.CanCollide = not broken
	local decor = seg:FindFirstChild("Decor")
	if decor then
		for _, p in decor:GetDescendants() do
			if p:IsA("BasePart") and p.Parent == decor then
				p.Transparency = if broken then 1 else 0
			end
		end
	end
	local rubble = seg:FindFirstChild("Rubble")
	if broken and not rubble then
		local f = Instance.new("Folder")
		f.Name = "Rubble"
		f.Parent = seg
		local rng = Random.new(#seg.Name * 13)
		for i = 1, 6 do
			mk(f, {
				Size = Vector3.new(rng:NextNumber(1.5, 3.5), rng:NextNumber(1, 2.5), rng:NextNumber(1.5, 3)),
				CFrame = seg.CFrame * CFrame.new(rng:NextNumber(-seg.Size.X / 2.5, seg.Size.X / 2.5), -6, rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), rng:NextNumber(0, 1)),
				Color = seg.Color,
				Material = seg.Material,
			})
		end
	elseif not broken and rubble then
		rubble:Destroy()
	end
end

-- ── Пьедестал ───────────────────────────────────────────────
local function pedestal(parent: Instance, name: string, cf: CFrame, rich: boolean)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	solid(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 7.5, 7.5), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#FFF4DE"), Material = Enum.Material.SmoothPlastic })
	local col = solid(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 5, 5), CFrame = cf * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = if rich then Color3.fromHex("#FFE9A8") else Color3.fromHex("#F4C27A"), Material = Enum.Material.SmoothPlastic })
	col.Name = "Column"
	local top = solid(m, { Name = "Top", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 5.6, 5.6), CFrame = cf * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Palette.gold, Material = Enum.Material.Metal })
	top.Name = "Top"
	-- Top должен быть «ровным»: CFrame без поворота, чтобы логика ставила артефакт вверх
	top.Shape = Enum.PartType.Block
	top.Size = Vector3.new(5.4, 0.6, 5.4)
	top.CFrame = cf * CFrame.new(0, 3.3, 0)
	top.Transparency = 1
	mk(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 6, 6), CFrame = cf * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = if rich then Palette.gold else Color3.fromHex("#FFD36B"), Material = Enum.Material.SmoothPlastic })
	mk(m, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 6.6, 6.6), CFrame = cf * CFrame.new(0, 2.85, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
	return m
end

-- ── Конвейер ────────────────────────────────────────────────
function M.belt(parent: Instance, name: string, cf: CFrame, z: number, y: number)
	local b = solid(parent, {
		Name = name,
		Size = Vector3.new(92, 1.2, 6),
		CFrame = cf * CFrame.new(0, y + 0.6, z),
		Color = Color3.fromHex("#F1E6FF"),
		Material = Enum.Material.SmoothPlastic,
	})
	for s = -1, 1, 2 do
		mk(b, { Size = Vector3.new(92, 1.6, 0.6), CFrame = cf * CFrame.new(0, y + 0.8, z + s * 3.2), Color = Palette.orange, Material = Enum.Material.Metal })
		mk(b, { Size = Vector3.new(92, 0.3, 0.9), CFrame = cf * CFrame.new(0, y + 1.7, z + s * 3.2), Color = Color3.fromHex("#FFE3B0"), Material = Enum.Material.SmoothPlastic })
	end
	for _, info in { { "Start", -46 }, { "End", 46 } } do
		mk(b, { Name = info[1], Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(info[2], y + 1.2, z), Transparency = 1 })
	end
	-- портал, из которого выходят артефакты
	for i = 1, 10 do
		local a = i / 10 * math.pi * 2
		mk(b, {
			Size = Vector3.new(1.2, 2.4, 1.2),
			CFrame = cf * CFrame.new(-47, y + 4.5 + math.sin(a) * 4, z + math.cos(a) * 4) * CFrame.Angles(a, 0, 0),
			Color = Palette.chrono,
			Material = Enum.Material.Neon,
		})
	end
	local glow = mk(b, { Size = Vector3.new(0.4, 7, 7), CFrame = cf * CFrame.new(-47, y + 4.5, z), Color = Palette.chrono, Material = Enum.Material.Neon, Transparency = 0.6, Shape = Enum.PartType.Cylinder })
	glow.CFrame = cf * CFrame.new(-47, y + 4.5, z)
	CollectionService:AddTag(glow, "Pulse")
	-- золотые частицы дохода
	local pe = Instance.new("ParticleEmitter")
	pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	pe.Color = ColorSequence.new(Palette.gold)
	pe.LightEmission = 1
	pe.Rate = 4
	pe.Lifetime = NumberRange.new(2, 3)
	pe.Speed = NumberRange.new(2, 4)
	pe.EmissionDirection = Enum.NormalId.Top
	pe.Size = NumberSequence.new(0.4, 0)
	pe.Parent = b
	return b
end
local belt = M.belt
local _belt = belt

-- ── Сборка базы ─────────────────────────────────────────────
function M.build(index: number): Model
	local cf = M.baseCFrame(index)
	local rng = Random.new(index * 101)
	local base = Instance.new("Model")
	base.Name = "Base" .. index
	base:SetAttribute("Index", index)
	local folder = workspace:FindFirstChild("Bases")
	base.Parent = folder

	local floor = solid(base, { Name = "Floor", Size = Vector3.new(120, 4, 120), CFrame = cf * CFrame.new(0, -2, 0), Color = Color3.fromHex("#8EDB7E"), Material = Enum.Material.SmoothPlastic })
	base.PrimaryPart = floor
	-- узор на полу и дорожка к воротам
	mk(base, { Size = Vector3.new(14, 0.1, 30), CFrame = cf * CFrame.new(0, 0.05, -44), Color = Color3.fromHex("#F3E2C4"), Material = Enum.Material.SmoothPlastic })
	mk(base, { Size = Vector3.new(100, 0.1, 40), CFrame = cf * CFrame.new(0, 0.05, 33), Color = Color3.fromHex("#F6D7A7"), Material = Enum.Material.WoodPlanks })
	floatingIsland(base, cf.Position + Vector3.new(0, -0.4, 0), 88, index * 7)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "Spawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = cf * CFrame.new(0, 0.5, -42)
	spawn.Anchored = true
	spawn.Neutral = false
	spawn.Enabled = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = base

	-- стены
	local walls = Instance.new("Folder")
	walls.Name = "Walls"
	walls.Parent = base
	for name, s in SEGS do
		local seg = solid(walls, {
			Name = name,
			Size = Vector3.new(SEG_LEN, 14, 2),
			CFrame = cf * CFrame.new(s.x, 7, s.z) * (if s.alongZ then CFrame.Angles(0, math.pi / 2, 0) else CFrame.new()),
			Color = Palette.wood,
			Material = Enum.Material.WoodPlanks,
		})
		if name == "F2" then
			seg:SetAttribute("Gate", true)
		end
	end
	M.setWallLevel(base, 1)

	-- пьедесталы
	local peds = Instance.new("Folder")
	peds.Name = "Pedestals"
	peds.Parent = base
	local xs = { -36, -18, 0, 18, 36 }
	for i = 1, 10 do
		local x = xs[(i - 1) % 5 + 1]
		local z = if i <= 5 then 25 else 42
		pedestal(peds, "P" .. i, cf * CFrame.new(x, 0, z), false)
	end


	local collect = mk(base, { Name = "Collect", Size = Vector3.new(10, 0.4, 10), CFrame = cf * CFrame.new(0, 0.2, -22), Color = Palette.gold, Material = Enum.Material.Neon, Transparency = 0.2 })
	collect.CanTouch = true
	CollectionService:AddTag(collect, "Pulse")
	mk(base, { Size = Vector3.new(12, 0.3, 12), CFrame = cf * CFrame.new(0, 0.1, -22), Color = Palette.orange, Material = Enum.Material.Metal })

	-- верстак
	local bench = Instance.new("Model")
	bench.Name = "Bench"
	bench.Parent = base
	local bcf = cf * CFrame.new(-38, 0, -26)
	solid(bench, { Size = Vector3.new(10, 1, 5), CFrame = bcf * CFrame.new(0, 3.5, 0), Color = Palette.wood, Material = Enum.Material.Wood })
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do
			mk(bench, { Size = Vector3.new(0.8, 3, 0.8), CFrame = bcf * CFrame.new(sx * 4.3, 1.5, sz * 1.9), Color = Color3.fromHex("#5C3A1E"), Material = Enum.Material.Wood })
		end
	end
	mk(bench, { Size = Vector3.new(1.5, 1.5, 1.5), CFrame = bcf * CFrame.new(-2.5, 4.75, 0), Color = Color3.fromHex("#9AA4B0"), Material = Enum.Material.Metal })
	mk(bench, { Size = Vector3.new(0.4, 0.4, 3), CFrame = bcf * CFrame.new(2, 4.2, 0) * CFrame.Angles(0, 0.4, 0), Color = Palette.orange, Material = Enum.Material.Metal })
	local bp = mk(bench, { Name = "Prompt", Size = Vector3.new(2, 2, 2), CFrame = bcf * CFrame.new(0, 5, 0), Transparency = 1 })
	bench.PrimaryPart = bp
	local light = Instance.new("PointLight")
	light.Color = Palette.orange
	light.Range = 14
	light.Brightness = 1.2
	light.Parent = bp

	-- слоты ловушек
	local traps = Instance.new("Folder")
	traps.Name = "Traps"
	traps.Parent = base
	local tpos = { { -25, -48 }, { 25, -48 }, { -50, -20 }, { 50, -20 }, { -50, 20 }, { 50, 20 }, { -25, 50 }, { 25, 50 } }
	for i, p in tpos do
		mk(traps, { Name = "T" .. i, Size = Vector3.new(6, 0.3, 6), CFrame = cf * CFrame.new(p[1], 0.15, p[2]), Color = Color3.fromHex("#3A3550"), Material = Enum.Material.Metal, Transparency = 0.3 })
	end

	-- маяк
	local beacon = Instance.new("Model")
	beacon.Name = "Beacon"
	beacon.Parent = base
	local bc = cf * CFrame.new(52, 0, -52)
	solid(beacon, { Size = Vector3.new(4, 2, 4), CFrame = bc * CFrame.new(0, 1, 0), Color = Palette.steel, Material = Enum.Material.Metal })
	local pole = mk(beacon, { Name = "Light", Size = Vector3.new(1.4, 26, 1.4), CFrame = bc * CFrame.new(0, 15, 0), Color = Palette.success, Material = Enum.Material.Neon })
	local bl = Instance.new("PointLight")
	bl.Name = "Glow"
	bl.Range = 18
	bl.Brightness = 1.5
	bl.Color = Palette.success
	bl.Parent = pole
	local gui = Instance.new("BillboardGui")
	gui.Name = "Tag"
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffset = Vector3.new(0, 16, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 400
	gui.LightInfluence = 0
	gui.Parent = pole
	for i, n in { "Name", "Level" } do
		local t = Instance.new("TextLabel")
		t.Name = n
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0.5, 0)
		t.Position = UDim2.fromScale(0, (i - 1) * 0.5)
		t.Font = Enum.Font.GothamBlack
		t.TextScaled = true
		t.TextColor3 = Color3.new(1, 1, 1)
		t.TextStrokeTransparency = 0.3
		t.Text = ""
		t.Parent = gui
	end

	local f2 = Instance.new("Folder")
	f2.Name = "Floor2"
	f2.Parent = base

	-- декор: тёплые фонари, растения, ящики
	local decor = Instance.new("Folder")
	decor.Name = "Decor"
	decor.Parent = base
	local lampPos = { { -52, -40 }, { -52, 40 }, { 52, 40 }, { -14, -54 }, { 14, -54 } }
	for i, p in lampPos do
		local lcf = cf * CFrame.new(p[1], 0, p[2])
		mk(decor, { Size = Vector3.new(0.8, 9, 0.8), CFrame = lcf * CFrame.new(0, 4.5, 0), Color = Palette.steel, Material = Enum.Material.Metal })
		local bulb = mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = lcf * CFrame.new(0, 9.5, 0), Color = Palette.orange, Material = Enum.Material.Neon })
		CollectionService:AddTag(bulb, "BaseLamp")
		if i <= 3 then
			local pl = Instance.new("PointLight")
			pl.Color = Palette.orange
			pl.Range = 22
			pl.Brightness = 1.3
			pl.Parent = bulb
		end
	end
	for _ = 1, 6 do
		local x, z = rng:NextNumber(-50, 50), rng:NextNumber(48, 54)
		mk(decor, { Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(x, 1.5, z), Color = Color3.fromHex("#4CAF50"), Material = Enum.Material.Grass })
	end
	for i = 1, 4 do
		solid(decor, { Size = Vector3.new(3, 3, 3), CFrame = cf * CFrame.new(-52 + (i % 2) * 3.2, 1.5 + math.floor((i - 1) / 2) * 3, -8) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), Color = Palette.wood, Material = Enum.Material.WoodPlanks })
	end

	return base
end

-- ── Второй этаж ─────────────────────────────────────────────
function M.setSecondFloor(base: any, on: boolean)
	local f2 = base:FindFirstChild("Floor2")
	if not f2 then
		return
	end
	f2:ClearAllChildren()
	if not on then
		return
	end
	local cf = base:GetAttribute("Index") and M.baseCFrame(base:GetAttribute("Index") :: number) or base:GetPivot()
	local y = 22
	solid(f2, { Size = Vector3.new(112, 2, 50), CFrame = cf * CFrame.new(0, y - 1, 33), Color = Color3.fromHex("#7A5C3E"), Material = Enum.Material.WoodPlanks })
	mk(f2, { Size = Vector3.new(112, 0.4, 1), CFrame = cf * CFrame.new(0, y + 0.2, 8.4), Color = Color3.fromHex("#2A2140"), Material = Enum.Material.SmoothPlastic })
	-- перила
	solid(f2, { Size = Vector3.new(112, 3, 0.6), CFrame = cf * CFrame.new(0, y + 1.5, 8.3), Color = Color3.fromHex("#FFE3B0"), Material = Enum.Material.SmoothPlastic })
	-- колонны
	for _, x in { -54, -18, 18, 54 } do
		solid(f2, { Size = Vector3.new(2, y, 2), CFrame = cf * CFrame.new(x, y / 2, 9), Color = Palette.gold, Material = Enum.Material.Metal })
	end
	-- лестница вдоль правой стены (+X), ступени от z=-30 до z=8
	for i = 0, 21 do
		solid(f2, { Size = Vector3.new(8, 1, 2), CFrame = cf * CFrame.new(51, i * 1 + 0.5, -34 + i * 2), Color = Palette.wood, Material = Enum.Material.Wood })
	end
	local xs = { -36, -18, 0, 18, 36 }
	for i = 11, 20 do
		local x = xs[(i - 11) % 5 + 1]
		local z = if i <= 15 then 30 else 46
		pedestal(f2, "P" .. i, cf * CFrame.new(x, y, z), true)
	end
end

-- ── Ловушки ─────────────────────────────────────────────────
function M.setTrap(base: any, slot: number, kind: string?, skin: string?)
	local pad = base.Traps:FindFirstChild("T" .. slot)
	if not pad then
		return
	end
	local old = pad:FindFirstChild("Vis")
	if old then
		old:Destroy()
	end
	pad.Transparency = if kind then 0.6 else 0.3
	if not kind then
		return
	end
	local f = Instance.new("Folder")
	f.Name = "Vis"
	f.Parent = pad
	local cf = pad.CFrame
	if kind == "mine" then
		if skin == "blackhole" then
			mk(f, { Shape = Enum.PartType.Ball, Size = Vector3.new(2.6, 2.6, 2.6), CFrame = cf * CFrame.new(0, 1.6, 0), Color = Color3.new(0, 0, 0), Material = Enum.Material.SmoothPlastic })
			for i = 1, 10 do
				local a = i / 10 * math.pi * 2
				local p = mk(f, { Size = Vector3.new(1.4, 0.15, 0.3), CFrame = cf * CFrame.new(math.cos(a) * 2.2, 1.6, math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0), Color = Palette.thief, Material = Enum.Material.Neon })
				CollectionService:AddTag(p, "Pulse")
			end
		else
			mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 3.4, 3.4), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Palette.steel, Material = Enum.Material.Metal })
			local l = mk(f, { Name = "Blink", Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), CFrame = cf * CFrame.new(0, 1.1, 0), Color = Palette.alarm, Material = Enum.Material.Neon })
			CollectionService:AddTag(l, "Pulse")
		end
	elseif kind == "slow" then
		mk(f, { Shape = Enum.PartType.Ball, Size = Vector3.new(14, 8, 14), CFrame = cf * CFrame.new(0, 0, 0), Color = Palette.thief, Material = Enum.Material.ForceField, Transparency = 0.2 })
		local pe = Instance.new("ParticleEmitter")
		pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		pe.Color = ColorSequence.new(Palette.thief)
		pe.Rate = 6
		pe.Lifetime = NumberRange.new(1.5)
		pe.Speed = NumberRange.new(1, 2)
		pe.Size = NumberSequence.new(0.5, 0)
		local holder = mk(f, { Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 1, 0), Transparency = 1 })
		pe.Parent = holder
	elseif kind == "decoy" then
		mk(f, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1, 4.6, 4.6), CFrame = cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), Color = Color3.fromHex("#FFF4DE"), Material = Enum.Material.SmoothPlastic })
	end
end

function M.setTrapArmed(base: any, slot: number, armed: boolean)
	local pad = base.Traps:FindFirstChild("T" .. slot)
	local vis = pad and pad:FindFirstChild("Vis")
	if not vis then
		return
	end
	for _, p in vis:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("BaseT", p:GetAttribute("BaseT") or p.Transparency)
			p.Transparency = if armed then (p:GetAttribute("BaseT") :: number) else math.min(1, ((p:GetAttribute("BaseT") or 0) :: number) + 0.6)
		end
	end
end

-- ── Маяк, щит, логово, стиль ────────────────────────────────
function M.setBeacon(base: any, ownerName: string, levelText: string, color: Color3)
	local beacon = base:FindFirstChild("Beacon")
	local pole = beacon and beacon:FindFirstChild("Light")
	if not pole then
		return
	end
	pole.Color = color
	local glow = pole:FindFirstChild("Glow")
	if glow then
		glow.Color = color
	end
	local tag = pole:FindFirstChild("Tag")
	if tag then
		local names = { low = "Защита: Низкая", mid = "Защита: Средняя", high = "Защита: Высокая" }
		tag.Name.Text = if ownerName == "" then "СВОБОДНО" else ownerName
		tag.Level.Text = if ownerName == "" then "" else (names[levelText] or levelText)
		tag.Level.TextColor3 = color
	end
end

function M.setShield(base: any, on: boolean)
	local old = base:FindFirstChild("Shield")
	if old then
		old:Destroy()
	end
	if not on then
		return
	end
	local cf = M.baseCFrame(base:GetAttribute("Index") :: number)
	mk(base, {
		Name = "Shield",
		Size = Vector3.new(124, 30, 124),
		CFrame = cf * CFrame.new(0, 15, 0),
		Color = Palette.chrono,
		Material = Enum.Material.ForceField,
		Transparency = 0.7,
	})
end

function M.makeDen(base: any): Model
	local cf = M.baseCFrame(base:GetAttribute("Index") :: number)
	local den = Instance.new("Model")
	den.Name = "Den"
	den.Parent = base
	local dcf = cf * CFrame.new(0, 0, -86)
	solid(den, { Size = Vector3.new(16, 1, 12), CFrame = dcf * CFrame.new(0, -0.5, 0), Color = Color3.fromHex("#3A2F4F"), Material = Enum.Material.Wood })
	mk(den, { Size = Vector3.new(10, 6, 0.5), CFrame = dcf * CFrame.new(0, 3, 4) * CFrame.Angles(-0.4, 0, 0), Color = Palette.thief, Material = Enum.Material.Fabric })
	for s = -1, 1, 2 do
		solid(den, { Size = Vector3.new(2.5, 2.5, 2.5), CFrame = dcf * CFrame.new(s * 5, 1.25, 1), Color = Palette.wood, Material = Enum.Material.WoodPlanks })
	end
	local spot = mk(den, { Name = "Spot", Size = Vector3.new(1, 1, 1), CFrame = dcf * CFrame.new(0, 1.5, 0), Transparency = 1 })
	local pl = Instance.new("PointLight")
	pl.Color = Palette.thief
	pl.Range = 16
	pl.Parent = spot
	den.PrimaryPart = spot
	return den
end

function M.setOwnerStyle(base: any, style: string)
	base:SetAttribute("Style", style)
	local beacon = base:FindFirstChild("Beacon")
	local pole = beacon and beacon:FindFirstChild("Light")
	if pole then
		pole.Transparency = if style == "empty" then 0.8 else 0
	end
end

return M
