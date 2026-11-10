--!nonstrict
-- Мир строится кодом при старте сервера: площадка с пушками, 10 зон до края мира, декор, облака.
-- Всё детерминировано (фиксированный seed), чтобы мир был одинаковым на всех серверах.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Fmt = require(ReplicatedStorage.Shared.Fmt)

local M = {}

local root: Folder
local rng = Random.new(20261110)

local SMOOTH = Enum.Material.SmoothPlastic
local FONT = Enum.Font.FredokaOne

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, shape: Enum.PartType?, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = SMOOTH
	w.Parent = parent
	return w
end

local function decor(parent: Instance, p: BasePart)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
end

local function shade(c: Color3, k: number): Color3
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function label(p: BasePart, face: Enum.NormalId, text: string, color: Color3, stroke: Color3?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 12
	g.LightInfluence = 0
	g.Parent = p
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Font = FONT
	t.Text = text
	t.TextScaled = true
	t.TextColor3 = color
	t.Parent = g
	local s = Instance.new("UIStroke")
	s.Thickness = 4
	s.Color = stroke or Color3.fromRGB(40, 30, 60)
	s.Parent = t
	return t
end

-- ===== декор по темам =====
-- Каждая функция ставит один объект с основанием в точке pos (y = 0) и возвращает самую высокую точку

local function tree(f: Instance, pos: Vector3, s: number, leaf: Color3)
	local h = 10 * s
	decor(f, part(f, Vector3.new(h, 2.2 * s, 2.2 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(140, 96, 64), Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.one * 11 * s, CFrame.new(pos + Vector3.new(0, h + 3 * s, 0)), leaf, Enum.PartType.Ball))
	decor(f, part(f, Vector3.one * 7 * s, CFrame.new(pos + Vector3.new(3 * s, h + 7 * s, 1 * s)), shade(leaf, 1.12), Enum.PartType.Ball))
end

local function bush(f: Instance, pos: Vector3, s: number, c: Color3)
	decor(f, part(f, Vector3.new(8, 5, 8) * s, CFrame.new(pos + Vector3.new(0, 1.5 * s, 0)), c, Enum.PartType.Ball))
end

local function flowers(f: Instance, pos: Vector3, s: number)
	local cols = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 140, 255) }
	for i = 1, 3 do
		local off = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)) * s
		decor(f, part(f, Vector3.one * 1.6 * s, CFrame.new(pos + off + Vector3.new(0, 0.8 * s, 0)), cols[rng:NextInteger(1, #cols)], Enum.PartType.Ball))
		if i > 2 then
			break
		end
	end
end

local function palm(f: Instance, pos: Vector3, s: number)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-12, 12)))
	local base = CFrame.new(pos) * lean
	decor(f, part(f, Vector3.new(16 * s, 1.8 * s, 1.8 * s), base * CFrame.new(0, 8 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(170, 120, 74), Enum.PartType.Cylinder))
	local top = base * CFrame.new(0, 16 * s, 0)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		decor(f, part(f, Vector3.new(10 * s, 0.8 * s, 3 * s), top * CFrame.Angles(0, a, 0) * CFrame.new(5 * s, -1 * s, 0) * CFrame.Angles(0, 0, math.rad(-20)), Color3.fromRGB(70, 180, 80)))
	end
end

local function umbrella(f: Instance, pos: Vector3, s: number)
	local cols = { Color3.fromRGB(255, 100, 100), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 200, 60) }
	decor(f, part(f, Vector3.new(9 * s, 0.6 * s, 0.6 * s), CFrame.new(pos + Vector3.new(0, 4.5 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(240, 240, 240), Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(1.2 * s, 10 * s, 10 * s), CFrame.new(pos + Vector3.new(0, 9 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), cols[rng:NextInteger(1, #cols)], Enum.PartType.Cylinder))
end

local function cactus(f: Instance, pos: Vector3, s: number)
	local g = Color3.fromRGB(86, 170, 90)
	decor(f, part(f, Vector3.new(14 * s, 3 * s, 3 * s), CFrame.new(pos + Vector3.new(0, 7 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), g, Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(5 * s, 2.2 * s, 2.2 * s), CFrame.new(pos + Vector3.new(2.6 * s, 7 * s, 0)) , g, Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(4 * s, 2.2 * s, 2.2 * s), CFrame.new(pos + Vector3.new(4.5 * s, 9 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), g, Enum.PartType.Cylinder))
end

local function rock(f: Instance, pos: Vector3, s: number, c: Color3)
	decor(f, part(f, Vector3.new(rng:NextNumber(5, 9), rng:NextNumber(3, 6), rng:NextNumber(5, 9)) * s, CFrame.new(pos + Vector3.new(0, 1 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), c, Enum.PartType.Ball))
end

local function mesa(f: Instance, pos: Vector3, s: number, c: Color3)
	local h = rng:NextNumber(20, 45) * s
	local w = rng:NextNumber(18, 30) * s
	decor(f, part(f, Vector3.new(w, h, w * 0.8), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), c))
	decor(f, part(f, Vector3.new(w * 1.08, 2 * s, w * 0.88), CFrame.new(pos + Vector3.new(0, h, 0)), shade(c, 1.15)))
end

local function pine(f: Instance, pos: Vector3, s: number, c: Color3)
	decor(f, part(f, Vector3.new(4 * s, 2 * s, 2 * s), CFrame.new(pos + Vector3.new(0, 2 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(130, 90, 60), Enum.PartType.Cylinder))
	for i = 0, 2 do
		local w = (10 - i * 3) * s
		local h = 7 * s
		local y = (4 + i * 4.5) * s + h / 2
		local cf = CFrame.new(pos + Vector3.new(0, y, 0))
		decor(f, wedge(f, Vector3.new(w, h, w / 2), cf * CFrame.new(0, 0, w / 4), c))
		decor(f, wedge(f, Vector3.new(w, h, w / 2), cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, w / 4), c))
	end
end

local function snowman(f: Instance, pos: Vector3, s: number)
	local w = Color3.fromRGB(250, 252, 255)
	decor(f, part(f, Vector3.one * 7 * s, CFrame.new(pos + Vector3.new(0, 3.2 * s, 0)), w, Enum.PartType.Ball))
	decor(f, part(f, Vector3.one * 5 * s, CFrame.new(pos + Vector3.new(0, 8 * s, 0)), w, Enum.PartType.Ball))
	decor(f, part(f, Vector3.one * 3.6 * s, CFrame.new(pos + Vector3.new(0, 11.6 * s, 0)), w, Enum.PartType.Ball))
	decor(f, part(f, Vector3.new(2, 0.6, 0.6) * s, CFrame.new(pos + Vector3.new(0, 11.6 * s, -2 * s)) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(255, 140, 40), Enum.PartType.Cylinder))
end

local function lollipop(f: Instance, pos: Vector3, s: number)
	local cols = { Color3.fromRGB(255, 90, 140), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 210, 80), Color3.fromRGB(150, 230, 120) }
	decor(f, part(f, Vector3.new(14 * s, 0.8 * s, 0.8 * s), CFrame.new(pos + Vector3.new(0, 7 * s, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 255, 255), Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(1.6 * s, 9 * s, 9 * s), CFrame.new(pos + Vector3.new(0, 16 * s, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), cols[rng:NextInteger(1, #cols)], Enum.PartType.Cylinder))
end

local function gumdrop(f: Instance, pos: Vector3, s: number)
	local cols = { Color3.fromRGB(255, 120, 120), Color3.fromRGB(140, 220, 140), Color3.fromRGB(255, 220, 100), Color3.fromRGB(190, 150, 255) }
	decor(f, part(f, Vector3.new(7, 6, 7) * s, CFrame.new(pos + Vector3.new(0, 2 * s, 0)), cols[rng:NextInteger(1, #cols)], Enum.PartType.Ball))
end

local function mushroom(f: Instance, pos: Vector3, s: number)
	local caps = { Color3.fromRGB(255, 90, 110), Color3.fromRGB(255, 160, 60), Color3.fromRGB(120, 210, 255) }
	local h = rng:NextNumber(8, 16) * s
	decor(f, part(f, Vector3.new(h, 3 * s, 3 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(250, 240, 220), Enum.PartType.Cylinder))
	local cap = caps[rng:NextInteger(1, #caps)]
	decor(f, part(f, Vector3.new(14, 7, 14) * s, CFrame.new(pos + Vector3.new(0, h + 1 * s, 0)), cap, Enum.PartType.Ball))
	decor(f, part(f, Vector3.one * 2.2 * s, CFrame.new(pos + Vector3.new(3 * s, h + 3.6 * s, 2 * s)), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball))
	decor(f, part(f, Vector3.one * 1.6 * s, CFrame.new(pos + Vector3.new(-3 * s, h + 3.8 * s, -1 * s)), Color3.fromRGB(255, 255, 255), Enum.PartType.Ball))
end

local function lavaPool(f: Instance, pos: Vector3, s: number)
	local r = rng:NextNumber(10, 22) * s
	local p = part(f, Vector3.new(0.4, r, r), CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(255, 120, 40), Enum.PartType.Cylinder, Enum.Material.Neon)
	decor(f, p)
end

local function spire(f: Instance, pos: Vector3, s: number, c: Color3)
	local h = rng:NextNumber(14, 30) * s
	local w = rng:NextNumber(4, 7) * s
	decor(f, part(f, Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(0, h / 2 - 1, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-10, 10))), c))
end

local function crystal(f: Instance, pos: Vector3, s: number)
	local cols = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(200, 150, 255), Color3.fromRGB(255, 150, 230) }
	local c = cols[rng:NextInteger(1, #cols)]
	for i = 1, 3 do
		local h = rng:NextNumber(8, 22) * s
		local w = rng:NextNumber(3, 5) * s
		local p = part(f, Vector3.new(w, h, w), CFrame.new(pos + Vector3.new(rng:NextNumber(-3, 3) * s, h / 2 - 1, rng:NextNumber(-3, 3) * s)) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-20, 20))), c, nil, Enum.Material.Glass)
		p.Transparency = 0.15
		decor(f, p)
		if i == 3 then
			break
		end
	end
end

local function cloudPuff(f: Instance, pos: Vector3, s: number)
	local w = Color3.fromRGB(255, 255, 255)
	decor(f, part(f, Vector3.new(14, 8, 10) * s, CFrame.new(pos), w, Enum.PartType.Ball))
	decor(f, part(f, Vector3.new(10, 7, 8) * s, CFrame.new(pos + Vector3.new(8 * s, -1 * s, 1 * s)), w, Enum.PartType.Ball))
	decor(f, part(f, Vector3.new(9, 6, 8) * s, CFrame.new(pos + Vector3.new(-7 * s, -1.5 * s, -1 * s)), w, Enum.PartType.Ball))
end

local function goldPillar(f: Instance, pos: Vector3, s: number)
	local g = Color3.fromRGB(255, 214, 90)
	local h = rng:NextNumber(14, 26) * s
	decor(f, part(f, Vector3.new(h, 4 * s, 4 * s), CFrame.new(pos + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), g, Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(6 * s, 1.5 * s, 6 * s), CFrame.new(pos + Vector3.new(0, h, 0)), shade(g, 1.1)))
end

local THEMES: { [string]: { (Instance, Vector3, number) -> () } } = {
	meadow = {
		function(f, p, s) tree(f, p, s, Color3.fromRGB(90, 190, 90)) end,
		function(f, p, s) tree(f, p, s, Color3.fromRGB(120, 210, 100)) end,
		function(f, p, s) bush(f, p, s, Color3.fromRGB(80, 170, 80)) end,
		flowers,
	},
	beach = {
		palm,
		palm,
		umbrella,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(200, 190, 170)) end,
	},
	desert = {
		cactus,
		cactus,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(210, 150, 90)) end,
		function(f, p, s) rock(f, p, s * 2.5, Color3.fromRGB(240, 196, 120)) end,
	},
	canyon = {
		function(f, p, s) mesa(f, p, s, Color3.fromRGB(196, 96, 66)) end,
		function(f, p, s) mesa(f, p, s, Color3.fromRGB(220, 130, 80)) end,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(170, 84, 60)) end,
		cactus,
	},
	snow = {
		function(f, p, s) pine(f, p, s, Color3.fromRGB(60, 140, 100)) end,
		function(f, p, s) pine(f, p, s, Color3.fromRGB(90, 160, 120)) end,
		snowman,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(190, 210, 230)) end,
	},
	candy = { lollipop, lollipop, gumdrop, gumdrop },
	mushroom = {
		mushroom,
		mushroom,
		function(f, p, s) bush(f, p, s, Color3.fromRGB(120, 90, 180)) end,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(110, 90, 150)) end,
	},
	lava = {
		lavaPool,
		function(f, p, s) spire(f, p, s, Color3.fromRGB(50, 40, 46)) end,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(80, 66, 70)) end,
		lavaPool,
	},
	crystal = {
		crystal,
		crystal,
		function(f, p, s) rock(f, p, s, Color3.fromRGB(70, 150, 170)) end,
		function(f, p, s) spire(f, p, s, Color3.fromRGB(60, 130, 160)) end,
	},
	sky = {
		cloudPuff,
		goldPillar,
		cloudPuff,
		function(f, p, s) bush(f, p, s, Color3.fromRGB(255, 250, 240)) end,
	},
}

-- ===== площадка =====

local function cannon(f: Instance, lane: number)
	local x = Layout.laneX(lane)
	local m = Instance.new("Model")
	m.Name = "Cannon" .. lane
	m.Parent = f
	local hue = (lane - 1) / Config.LANES
	local body = Color3.fromHSV(hue, 0.55, 0.95)
	local dark = Color3.fromRGB(70, 60, 90)
	-- лафет
	part(m, Vector3.new(14, 6, 18), CFrame.new(x, 3, -28), Color3.fromRGB(150, 104, 70))
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(2, 10, 10), CFrame.new(x + sx * 7.5, 5, -30) * CFrame.Angles(0, 0, 0), dark, Enum.PartType.Cylinder)
	end
	-- ствол: ось X цилиндра вдоль направления выстрела
	local pivot = Layout.pivot(lane)
	local d = Layout.DIR
	local up = Vector3.new(0, d.Z, -d.Y)
	local center = pivot + d * (Layout.BARREL_LEN / 2)
	local barrel = part(m, Vector3.new(Layout.BARREL_LEN, Layout.BARREL_R * 2, Layout.BARREL_R * 2), CFrame.fromMatrix(center, d, up), body, Enum.PartType.Cylinder)
	barrel.Name = "Barrel"
	local ringCf = CFrame.fromMatrix(pivot + d * Layout.BARREL_LEN, d, up)
	part(m, Vector3.new(2.5, Layout.BARREL_R * 2 + 1.6, Layout.BARREL_R * 2 + 1.6), ringCf, Color3.fromRGB(255, 220, 90), Enum.PartType.Cylinder)
	part(m, Vector3.new(2.5, Layout.BARREL_R * 2 + 1.2, Layout.BARREL_R * 2 + 1.2), CFrame.fromMatrix(pivot + d * 4, d, up), Color3.fromRGB(255, 220, 90), Enum.PartType.Cylinder)
	local mouth = part(m, Vector3.new(0.4, Layout.BARREL_R * 2 - 1, Layout.BARREL_R * 2 - 1), CFrame.fromMatrix(pivot + d * (Layout.BARREL_LEN + 1.3), d, up), Color3.fromRGB(30, 24, 40), Enum.PartType.Cylinder)
	mouth.Name = "Mouth"
	local att = Instance.new("Attachment")
	att.Name = "Muzzle"
	att.Parent = mouth
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Blast"
	fire.Enabled = false
	fire.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fire.Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.fromRGB(255, 140, 60))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(20, 40)
	fire.SpreadAngle = Vector2.new(25, 25)
	fire.EmissionDirection = Enum.NormalId.Right
	fire.LightEmission = 0.6
	fire.Parent = att
	-- номер пушки
	local tag = part(m, Vector3.new(8, 4, 0.5), CFrame.new(x, 4, -37.3), Color3.fromRGB(255, 255, 255))
	label(tag, Enum.NormalId.Back, tostring(lane), body)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
		end
	end
end

local function sign(f: Instance, size: Vector3, cf: CFrame, text: string, bg: Color3, fg: Color3)
	local p = part(f, size, cf, bg)
	label(p, Enum.NormalId.Back, text, fg)
	label(p, Enum.NormalId.Front, text, fg)
	return p
end

local boardLists: { [string]: Frame } = {}
local modLabel: TextLabel? = nil

local function makeBoard(f: Instance, cf: CFrame, title: string): Frame
	local board = part(f, Vector3.new(44, 52, 2), cf, Color3.fromRGB(60, 50, 90))
	board.Name = "Leaderboard"
	local g = Instance.new("SurfaceGui")
	g.Face = Enum.NormalId.Front
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 14
	g.LightInfluence = 0
	g.Parent = board
	local head = Instance.new("TextLabel")
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0.14, 0)
	head.Font = FONT
	head.TextScaled = true
	head.Text = title
	head.TextColor3 = Color3.fromRGB(255, 214, 90)
	head.Parent = g
	local list = Instance.new("Frame")
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromScale(0.04, 0.16)
	list.Size = UDim2.fromScale(0.92, 0.82)
	list.Parent = g
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0.01, 0)
	lay.Parent = list
	return list
end

local function plaza(f: Instance)
	local z0, z1 = Layout.PLAZA_Z0, Layout.PLAZA_Z1
	local base = part(f, Vector3.new(260, 4, z1 - z0), CFrame.new(0, -1.9, (z0 + z1) / 2), Color3.fromRGB(236, 230, 250))
	base.Name = "Plaza"
	-- плитка
	for i = -6, 6 do
		for j = 0, 5 do
			if (i + j) % 2 == 0 then
				decor(f, part(f, Vector3.new(20, 0.2, 20), CFrame.new(i * 20, 0.15, z0 + 10 + j * 20), Color3.fromRGB(220, 212, 246)))
			end
		end
	end
	for lane = 1, Config.LANES do
		cannon(f, lane)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(24, 1, 24)
	spawn.CFrame = CFrame.new(Layout.SPAWN - Vector3.new(0, 2.4, 0))
	spawn.Color = Color3.fromRGB(255, 214, 90)
	spawn.Material = SMOOTH
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 0
	spawn.Parent = f
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	-- название над пушками
	local title = sign(f, Vector3.new(120, 22, 2), CFrame.new(0, 62, -40), "+1 LAUNCH POWER", Color3.fromRGB(255, 120, 90), Color3.fromRGB(255, 255, 255))
	title.Name = "Title"
	for _, sx in { -1, 1 } do
		part(f, Vector3.new(4, 52, 4), CFrame.new(sx * 58, 26, -40), Color3.fromRGB(255, 214, 90))
	end
	-- лидерборды: за всё время и за сегодня
	boardLists.all = makeBoard(f, CFrame.new(-118, 26, -80) * CFrame.Angles(0, math.rad(-120), 0), "FARTHEST EVER")
	boardLists.today = makeBoard(f, CFrame.new(118, 26, -80) * CFrame.Angles(0, math.rad(120), 0), "TODAY'S RACE")
	-- модификатор дня
	local modSign = part(f, Vector3.new(70, 10, 1.5), CFrame.new(0, 80, -40), Color3.fromRGB(255, 214, 90))
	modLabel = label(modSign, Enum.NormalId.Back, "", Color3.fromRGB(255, 255, 255))
	label(modSign, Enum.NormalId.Front, "", Color3.fromRGB(255, 255, 255))
	-- подсказка про коды
	sign(f, Vector3.new(36, 7, 1.5), CFrame.new(0, 8, -112), "CODES IN 🎁 GIFTS", Color3.fromRGB(110, 200, 255), Color3.fromRGB(255, 255, 255))
	-- невидимые стенки по краям площадки сзади и с боков
	for _, w in {
		{ Vector3.new(270, 60, 2), Vector3.new(0, 30, z0 - 1) },
		{ Vector3.new(2, 60, z1 - z0), Vector3.new(-131, 30, (z0 + z1) / 2) },
		{ Vector3.new(2, 60, z1 - z0), Vector3.new(131, 30, (z0 + z1) / 2) },
	} do
		local wall = part(f, w[1], CFrame.new(w[2]), Color3.new(1, 1, 1))
		wall.Transparency = 1
	end
end

function M.setModifier(mod: { zone: number, kind: string })
	local zone = Config.ZONES[mod.zone]
	local text = if mod.kind == "coins" then "TODAY: x2 COINS IN " .. string.upper(zone.name) else "TODAY: DOUBLE RINGS IN " .. string.upper(zone.name)
	if modLabel then
		modLabel.Text = text
		local sg = modLabel.Parent and modLabel.Parent.Parent
		if sg then
			for _, g in sg:GetChildren() do
				local t = g:FindFirstChildOfClass("TextLabel")
				if g:IsA("SurfaceGui") and t then
					t.Text = text
				end
			end
		end
	end
end

function M.setBoard(entries: { { name: string, value: number } }, which: string)
	local list = boardLists[which]
	if not list then
		return
	end
	for _, c in list:GetChildren() do
		if c:IsA("TextLabel") then
			c:Destroy()
		end
	end
	for i, e in entries do
		if i > 10 then
			break
		end
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = 1
		t.Size = UDim2.new(1, 0, 0.09, 0)
		t.Font = FONT
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.LayoutOrder = i
		t.Text = string.format("%d. %s  —  %s", i, e.name, Fmt.dist(e.value))
		t.TextColor3 = if i == 1 then Color3.fromRGB(255, 214, 90) elseif i <= 3 then Color3.fromRGB(220, 230, 255) else Color3.fromRGB(255, 255, 255)
		t.Parent = list
	end
end

-- ===== поле =====

local function ground(f: Instance)
	local w = Config.MAP_HALF_WIDTH * 2 + 120
	for i, zone in Config.ZONES do
		local zFrom = if i == 1 then 0 else zone.from
		local nextZ = Config.ZONES[i + 1]
		local zTo = if nextZ then nextZ.from else Config.MAP_END + 600
		local z = zFrom
		local stripe = 0
		while z < zTo do
			local len = math.min(400, zTo - z)
			stripe += 1
			local col = if stripe % 2 == 0 then zone.ground else zone.ground2
			local p = part(f, Vector3.new(w, 20, len), CFrame.new(0, -10, z + len / 2), col)
			p.Name = "Ground"
			p.CastShadow = false
			z += len
		end
		-- холмы по краям
		local zf = Instance.new("Folder")
		zf.Name = zone.name
		zf.Parent = f
		local hz = zFrom
		while hz < zTo do
			for _, sx in { -1, 1 } do
				local r = rng:NextNumber(60, 110)
				decor(zf, part(zf, Vector3.new(r * 1.4, r, r * 1.4), CFrame.new(sx * (Config.MAP_HALF_WIDTH + 70 + rng:NextNumber(0, 40)), -r * 0.15, hz + rng:NextNumber(0, 80)), shade(zone.ground, 0.9), Enum.PartType.Ball))
			end
			hz += rng:NextNumber(110, 170)
		end
		-- декор
		local list = THEMES[zone.theme]
		local count = math.clamp(math.floor((zTo - zFrom) / 30), 24, 190)
		for _ = 1, count do
			local x = rng:NextNumber(-Config.MAP_HALF_WIDTH + 10, Config.MAP_HALF_WIDTH - 10)
			local zz = rng:NextNumber(zFrom + 20, zTo - 20)
			local s = rng:NextNumber(0.9, 1.8)
			list[rng:NextInteger(1, #list)](zf, Vector3.new(x, 0, zz), s)
		end
		-- ворота зоны
		if i > 1 then
			local gate = Instance.new("Model")
			gate.Name = "Gate" .. i
			gate.Parent = f
			local gc = Color3.fromHSV((i * 0.11) % 1, 0.6, 1)
			for _, sx in { -1, 1 } do
				decor(gate, part(gate, Vector3.new(14, 170, 14), CFrame.new(sx * (Config.MAP_HALF_WIDTH + 6), 85, zFrom), gc))
			end
			local beam = part(gate, Vector3.new(w, 30, 6), CFrame.new(0, 175, zFrom), gc)
			decor(gate, beam)
			local text = string.format("ZONE %d · %s · %s", i, string.upper(zone.name), Fmt.dist(zone.from))
			label(beam, Enum.NormalId.Front, text, Color3.fromRGB(255, 255, 255))
			label(beam, Enum.NormalId.Back, text, Color3.fromRGB(255, 255, 255))
			local line = part(gate, Vector3.new(w, 0.3, 6), CFrame.new(0, 0.2, zFrom), gc, nil, Enum.Material.Neon)
			decor(gate, line)
		end
	end
	-- отметки дистанции
	local marks = Instance.new("Folder")
	marks.Name = "Marks"
	marks.Parent = f
	local d = 250
	while d < Config.MAP_END do
		local big = d % 1000 == 0
		decor(marks, part(marks, Vector3.new(Config.MAP_HALF_WIDTH * 2, 0.3, if big then 4 else 2), CFrame.new(0, 0.18, d), Color3.fromRGB(255, 255, 255)))
		if big or d < 1000 then
			local plate = part(marks, Vector3.new(90, 0.4, 28), CFrame.new(0, 0.25, d + 18), Color3.fromRGB(255, 255, 255))
			plate.Transparency = 1
			decor(marks, plate)
			local t = label(plate, Enum.NormalId.Top, Fmt.dist(d), Color3.fromRGB(255, 255, 255))
			t.Rotation = 180
		end
		d += if d < 1000 then 250 else 500
	end
	-- край мира
	local edge = Instance.new("Model")
	edge.Name = "Edge"
	edge.Parent = f
	local e = Config.MAP_END
	for k = 0, 6 do
		local c = Color3.fromHSV(k / 7, 0.55, 1)
		local arc = part(edge, Vector3.new(w + 40, 26, 10), CFrame.new(0, 40 + k * 26, e + 120), c, nil, Enum.Material.Neon)
		decor(edge, arc)
	end
	local wall = part(edge, Vector3.new(w + 40, 30, 4), CFrame.new(0, 230, e + 116), Color3.fromRGB(255, 214, 90))
	decor(edge, wall)
	label(wall, Enum.NormalId.Front, "THE EDGE OF THE WORLD · REBIRTH TO GO AGAIN", Color3.fromRGB(255, 255, 255))
end

local function sky(f: Instance)
	local cf = Instance.new("Folder")
	cf.Name = "Clouds"
	cf.Parent = f
	local z = 300
	while z < Config.MAP_END do
		local h = rng:NextNumber(120, 260) + z * rng:NextNumber(0.02, 0.12)
		cloudPuff(cf, Vector3.new(rng:NextNumber(-500, 500), h, z), rng:NextNumber(2, 5))
		z += rng:NextNumber(140, 320)
	end
end

local function lighting()
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(110, 106, 130)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 148, 170)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.28
	atm.Offset = 0.15
	atm.Color = Color3.fromRGB(190, 225, 255)
	atm.Decay = Color3.fromRGB(150, 190, 240)
	atm.Glare = 0.2
	atm.Haze = 0.6
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.15
	cc.Contrast = 0.05
	cc.Brightness = 0.02
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.4
	bloom.Parent = Lighting
	local skyObj = Instance.new("Sky")
	skyObj.SunAngularSize = 14
	skyObj.Parent = Lighting
end

function M.build()
	root = Instance.new("Folder")
	root.Name = "World"
	root.Parent = workspace
	lighting()
	local pf = Instance.new("Folder")
	pf.Name = "Plaza"
	pf.Parent = root
	plaza(pf)
	local gf = Instance.new("Folder")
	gf.Name = "Field"
	gf.Parent = root
	ground(gf)
	sky(root)
end

function M.cannon(lane: number): Model?
	local pf = root and root:FindFirstChild("Plaza")
	local m = pf and pf:FindFirstChild("Cannon" .. lane)
	return if m and m:IsA("Model") then m else nil
end

return M
