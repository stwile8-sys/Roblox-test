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

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local WHITE = rgb(255, 255, 255)
local GOLD = rgb(255, 214, 90)
local WOOD = rgb(150, 104, 70)
local NEON = Enum.Material.Neon
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Вертикальный цилиндр: d — диаметр, h — высота, pos — центр
local function cyl(f: Instance, d: number, h: number, pos: Vector3, color: Color3, material: Enum.Material?): Part
	return part(f, Vector3.new(h, d, d), CFrame.new(pos) * UPRIGHT, color, Enum.PartType.Cylinder, material)
end

-- Шар или эллипсоид. У Ball-части форма всегда сфера, поэтому сплюснутые формы делаем через SpecialMesh.
local function ball(f: Instance, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material?): Part
	if math.abs(size.X - size.Y) < 0.01 and math.abs(size.Y - size.Z) < 0.01 then
		return part(f, size, CFrame.new(pos), color, Enum.PartType.Ball, material)
	end
	local p = part(f, size, CFrame.new(pos), color, nil, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

local function up(pos: Vector3, y: number): Vector3
	return pos + Vector3.new(0, y, 0)
end

-- ===== декор по темам =====
-- Каждая функция ставит один объект с основанием в точке pos (y = 0)

local function tree(f: Instance, pos: Vector3, s: number, leaf: Color3)
	local h = rng:NextNumber(9, 13) * s
	decor(f, cyl(f, 2.4 * s, h, up(pos, h / 2), rgb(140, 96, 64)))
	decor(f, ball(f, Vector3.new(13, 10, 13) * s, up(pos, h + 2.5 * s), shade(leaf, 0.9)))
	decor(f, ball(f, Vector3.one * 9 * s, pos + Vector3.new(2.5 * s, h + 6.5 * s, 1 * s), leaf))
	decor(f, ball(f, Vector3.one * 6 * s, pos + Vector3.new(-3 * s, h + 5.5 * s, -2 * s), shade(leaf, 1.12)))
end

local function bush(f: Instance, pos: Vector3, s: number, c: Color3)
	decor(f, ball(f, Vector3.new(8, 5, 8) * s, up(pos, 1.6 * s), c))
	decor(f, ball(f, Vector3.new(5, 4, 5) * s, pos + Vector3.new(3.5 * s, 1.2 * s, 1.5 * s), shade(c, 1.12)))
end

local FLOWER_COLS = { rgb(255, 120, 160), rgb(255, 220, 90), WHITE, rgb(170, 140, 255), rgb(255, 150, 70) }

local function flowers(f: Instance, pos: Vector3, s: number)
	decor(f, ball(f, Vector3.new(9, 1.6, 9) * s, up(pos, 0.3 * s), rgb(84, 176, 84)))
	for _ = 1, 4 do
		local off = Vector3.new(rng:NextNumber(-3.5, 3.5), 0, rng:NextNumber(-3.5, 3.5)) * s
		decor(f, ball(f, Vector3.one * rng:NextNumber(1.4, 2.2) * s, pos + off + Vector3.new(0, 1.3 * s, 0), pick(FLOWER_COLS)))
	end
end

local function rock(f: Instance, pos: Vector3, s: number, c: Color3)
	local size = Vector3.new(rng:NextNumber(5, 9), rng:NextNumber(3, 6), rng:NextNumber(5, 9)) * s
	decor(f, ball(f, size, up(pos, size.Y * 0.25), c))
	decor(f, ball(f, size * 0.55, pos + Vector3.new(size.X * 0.4, size.Y * 0.12, size.Z * 0.2), shade(c, 0.9)))
end

local function palm(f: Instance, pos: Vector3, s: number)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-12, 12)))
	local base = CFrame.new(pos) * lean
	decor(f, part(f, Vector3.new(16 * s, 1.8 * s, 1.8 * s), base * CFrame.new(0, 8 * s, 0) * UPRIGHT, rgb(170, 120, 74), Enum.PartType.Cylinder))
	local top = base * CFrame.new(0, 16 * s, 0)
	for i = 0, 4 do
		local a = math.rad(i * 72)
		local col = if i % 2 == 0 then rgb(70, 180, 80) else rgb(96, 200, 90)
		decor(f, part(f, Vector3.new(10 * s, 0.8 * s, 3.2 * s), top * CFrame.Angles(0, a, 0) * CFrame.new(5 * s, -1 * s, 0) * CFrame.Angles(0, 0, math.rad(-22)), col))
	end
	decor(f, ball(f, Vector3.one * 1.8 * s, (top * CFrame.new(0.8 * s, -1 * s, 0.6 * s)).Position, rgb(120, 80, 50)))
end

local BRIGHT = { rgb(255, 100, 100), rgb(80, 170, 255), rgb(255, 200, 60), rgb(255, 130, 200), rgb(120, 220, 130) }

local function umbrella(f: Instance, pos: Vector3, s: number)
	local c = pick(BRIGHT)
	decor(f, cyl(f, 0.6 * s, 9 * s, up(pos, 4.5 * s), rgb(240, 240, 240)))
	decor(f, ball(f, Vector3.new(12, 4, 12) * s, up(pos, 8.6 * s), c))
	decor(f, ball(f, Vector3.one * 1.2 * s, up(pos, 10.8 * s), WHITE))
	-- полотенце рядом
	decor(f, part(f, Vector3.new(4, 0.3, 8) * s, CFrame.new(pos + Vector3.new(6 * s, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), pick(BRIGHT)))
end

local function beachBall(f: Instance, pos: Vector3, s: number)
	local d = 4.5 * s
	decor(f, ball(f, Vector3.one * d, up(pos, d / 2), pick(BRIGHT)))
	decor(f, part(f, Vector3.new(d * 0.28, d * 1.01, d * 1.01), CFrame.new(up(pos, d / 2)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.5), WHITE, Enum.PartType.Cylinder))
end

local function sandcastle(f: Instance, pos: Vector3, s: number)
	local c = rgb(232, 200, 126)
	decor(f, part(f, Vector3.new(10, 4, 10) * s, CFrame.new(up(pos, 2 * s)), c))
	for _, o in { Vector3.new(-5, 0, -5), Vector3.new(5, 0, -5), Vector3.new(-5, 0, 5), Vector3.new(5, 0, 5) } do
		decor(f, cyl(f, 3.4 * s, 7 * s, pos + o * s + Vector3.new(0, 3.5 * s, 0), shade(c, 1.06)))
	end
	decor(f, cyl(f, 5 * s, 9 * s, up(pos, 4.5 * s), shade(c, 0.95)))
	decor(f, ball(f, Vector3.one * 2 * s, up(pos, 10 * s), rgb(255, 100, 100)))
end

-- На воде: лодочка и надувной круг
local function boat(f: Instance, pos: Vector3, s: number)
	local cf = CFrame.new(up(pos, 0.4)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	decor(f, part(f, Vector3.new(6, 3, 14) * s, cf * CFrame.new(0, 1.2 * s, 0), pick(BRIGHT)))
	decor(f, part(f, Vector3.new(6.6, 0.8, 14.6) * s, cf * CFrame.new(0, 2.6 * s, 0), WHITE))
	decor(f, part(f, Vector3.new(12 * s, 0.7 * s, 0.7 * s), cf * CFrame.new(0, 8.5 * s, 0) * UPRIGHT, rgb(170, 120, 74), Enum.PartType.Cylinder))
	decor(f, wedge(f, Vector3.new(0.4, 9, 6) * s, cf * CFrame.new(0, 9 * s, 3.4 * s), WHITE))
end

local function swimRing(f: Instance, pos: Vector3, s: number)
	decor(f, cyl(f, 7 * s, 1.8 * s, up(pos, 1), pick(BRIGHT)))
	decor(f, cyl(f, 3.4 * s, 1.9 * s, up(pos, 1), rgb(64, 196, 232)))
end

local function cactus(f: Instance, pos: Vector3, s: number)
	local g = rgb(86, 178, 96)
	local turn = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	decor(f, cyl(f, 3 * s, 14 * s, up(pos, 7 * s), g))
	decor(f, ball(f, Vector3.one * 3 * s, up(pos, 14 * s), g))
	for _, sx in { -1, 1 } do
		local y = (if sx > 0 then 7 else 5) * s
		decor(f, part(f, Vector3.new(4 * s, 2.2 * s, 2.2 * s), turn * CFrame.new(sx * 3 * s, y, 0), g, Enum.PartType.Cylinder))
		decor(f, part(f, Vector3.new(5 * s, 2.2 * s, 2.2 * s), turn * CFrame.new(sx * 4.4 * s, y + 2 * s, 0) * UPRIGHT, g, Enum.PartType.Cylinder))
	end
	decor(f, ball(f, Vector3.one * 1.8 * s, up(pos, 15.6 * s), rgb(255, 120, 170)))
end

local function pyramid(f: Instance, pos: Vector3, s: number)
	local c = rgb(240, 200, 120)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0)
	for i = 0, 4 do
		local w = (44 - i * 9) * s
		decor(f, part(f, Vector3.new(w, 7 * s, w), cf * CFrame.new(0, (3.5 + i * 7) * s, 0), shade(c, 1 - i * 0.03), nil, Enum.Material.Sandstone))
	end
	decor(f, part(f, Vector3.new(5, 5, 5) * s, cf * CFrame.new(0, 36 * s, 0), GOLD))
end

local function mesa(f: Instance, pos: Vector3, s: number, c: Color3)
	local h = rng:NextNumber(20, 45) * s
	local w = rng:NextNumber(18, 30) * s
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	decor(f, part(f, Vector3.new(w * 1.25, h * 0.35, w * 1.05), cf * CFrame.new(0, h * 0.175, 0), shade(c, 0.88), nil, Enum.Material.Sandstone))
	decor(f, part(f, Vector3.new(w, h, w * 0.8), cf * CFrame.new(0, h / 2, 0), c, nil, Enum.Material.Sandstone))
	decor(f, part(f, Vector3.new(w * 1.08, 2.4 * s, w * 0.88), cf * CFrame.new(0, h, 0), shade(c, 1.2)))
end

local function arch(f: Instance, pos: Vector3, s: number, c: Color3)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local h = rng:NextNumber(18, 28) * s
	for _, sx in { -1, 1 } do
		decor(f, part(f, Vector3.new(7 * s, h, 8 * s), cf * CFrame.new(sx * 11 * s, h / 2, 0), c, nil, Enum.Material.Sandstone))
	end
	decor(f, part(f, Vector3.new(34 * s, 6 * s, 9 * s), cf * CFrame.new(0, h + 2 * s, 0), shade(c, 1.12), nil, Enum.Material.Sandstone))
end

local function pine(f: Instance, pos: Vector3, s: number, c: Color3)
	decor(f, cyl(f, 2 * s, 4 * s, up(pos, 2 * s), rgb(130, 90, 60)))
	for i = 0, 2 do
		local w = (11 - i * 3) * s
		local h = 7 * s
		local y = (4 + i * 4.5) * s + h / 2
		local cf = CFrame.new(up(pos, y))
		local col = shade(c, 1 + i * 0.08)
		decor(f, wedge(f, Vector3.new(w, h, w / 2), cf * CFrame.new(0, 0, w / 4), col))
		decor(f, wedge(f, Vector3.new(w, h, w / 2), cf * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, 0, w / 4), col))
	end
	decor(f, ball(f, Vector3.one * 2.4 * s, up(pos, 20.5 * s), WHITE))
end

local function snowman(f: Instance, pos: Vector3, s: number)
	local w = rgb(250, 252, 255)
	decor(f, ball(f, Vector3.one * 7 * s, up(pos, 3.2 * s), w))
	decor(f, ball(f, Vector3.one * 5 * s, up(pos, 8 * s), w))
	decor(f, ball(f, Vector3.one * 3.6 * s, up(pos, 11.6 * s), w))
	decor(f, part(f, Vector3.new(2, 0.6, 0.6) * s, CFrame.new(pos + Vector3.new(0, 11.6 * s, -2 * s)) * CFrame.Angles(0, math.rad(90), 0), rgb(255, 140, 40), Enum.PartType.Cylinder))
	decor(f, cyl(f, 4.4 * s, 0.4 * s, up(pos, 13.2 * s), rgb(60, 50, 80)))
	decor(f, cyl(f, 2.8 * s, 2.4 * s, up(pos, 14.4 * s), rgb(60, 50, 80)))
	decor(f, cyl(f, 3.9 * s, 1 * s, up(pos, 10 * s), pick(BRIGHT)))
end

local function igloo(f: Instance, pos: Vector3, s: number)
	local turn = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	decor(f, ball(f, Vector3.one * 18 * s, pos, rgb(240, 248, 255)))
	decor(f, part(f, Vector3.new(6, 6, 5) * s, turn * CFrame.new(0, 3 * s, -9 * s), rgb(220, 234, 250)))
	decor(f, part(f, Vector3.new(3.6, 4.4, 0.4) * s, turn * CFrame.new(0, 2.2 * s, -11.5 * s), rgb(70, 90, 130)))
end

local function icePond(f: Instance, pos: Vector3, s: number)
	local d = rng:NextNumber(18, 34) * s
	decor(f, cyl(f, d + 3, 0.3, up(pos, 0.1), WHITE))
	decor(f, cyl(f, d, 0.3, up(pos, 0.2), rgb(150, 215, 255), Enum.Material.Ice))
end

local CANDY = { rgb(255, 90, 140), rgb(120, 200, 255), rgb(255, 210, 80), rgb(150, 230, 120), rgb(190, 150, 255) }

local function lollipop(f: Instance, pos: Vector3, s: number)
	local c = pick(CANDY)
	local turn = CFrame.new(up(pos, 16 * s)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	decor(f, cyl(f, 0.9 * s, 14 * s, up(pos, 7 * s), WHITE))
	decor(f, part(f, Vector3.new(1.6 * s, 10 * s, 10 * s), turn, c, Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(1.9 * s, 6.4 * s, 6.4 * s), turn, WHITE, Enum.PartType.Cylinder))
	decor(f, part(f, Vector3.new(2.2 * s, 3 * s, 3 * s), turn, c, Enum.PartType.Cylinder))
end

local function gumdrop(f: Instance, pos: Vector3, s: number)
	local c = pick(CANDY)
	decor(f, ball(f, Vector3.new(7, 8, 7) * s, up(pos, 1 * s), c))
	decor(f, ball(f, Vector3.new(2, 1.2, 2) * s, pos + Vector3.new(1.2 * s, 4.4 * s, -1.2 * s), shade(c, 1.3)))
end

local function candyCane(f: Instance, pos: Vector3, s: number)
	local red = rgb(255, 80, 100)
	local turn = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	decor(f, cyl(f, 1.8 * s, 16 * s, up(pos, 8 * s), WHITE))
	for i = 0, 3 do
		decor(f, cyl(f, 1.95 * s, 1.8 * s, up(pos, (2.5 + i * 4) * s), red))
	end
	decor(f, part(f, Vector3.new(5 * s, 1.8 * s, 1.8 * s), turn * CFrame.new(2.2 * s, 16 * s, 0), red, Enum.PartType.Cylinder))
	decor(f, ball(f, Vector3.one * 1.8 * s, (turn * CFrame.new(-0.2 * s, 16 * s, 0)).Position, WHITE))
	decor(f, part(f, Vector3.new(3.5 * s, 1.8 * s, 1.8 * s), turn * CFrame.new(4.6 * s, 14.4 * s, 0) * UPRIGHT, WHITE, Enum.PartType.Cylinder))
end

local function cupcake(f: Instance, pos: Vector3, s: number)
	local c = pick(CANDY)
	decor(f, cyl(f, 7 * s, 5 * s, up(pos, 2.5 * s), rgb(236, 190, 130)))
	decor(f, ball(f, Vector3.new(9.5, 5.5, 9.5) * s, up(pos, 6 * s), c))
	decor(f, ball(f, Vector3.new(6.5, 4.5, 6.5) * s, up(pos, 8.6 * s), shade(c, 1.15)))
	decor(f, ball(f, Vector3.one * 2.2 * s, up(pos, 11.4 * s), rgb(255, 60, 90)))
end

local CAPS = { rgb(255, 90, 110), rgb(255, 160, 60), rgb(120, 210, 255), rgb(255, 130, 210) }

local function mushroom(f: Instance, pos: Vector3, s: number)
	local h = rng:NextNumber(8, 16) * s
	local cap = pick(CAPS)
	decor(f, cyl(f, 3.2 * s, h, up(pos, h / 2), rgb(250, 240, 220)))
	decor(f, ball(f, Vector3.new(15, 8, 15) * s, up(pos, h + 1 * s), cap))
	decor(f, cyl(f, 11 * s, 0.8 * s, up(pos, h - 0.2 * s), rgb(255, 236, 214)))
	for _, o in { Vector3.new(3.4, 3.6, 2.2), Vector3.new(-3.4, 3.7, -1.4), Vector3.new(0.4, 4.6, -3) } do
		decor(f, ball(f, Vector3.one * rng:NextNumber(1.6, 2.6) * s, pos + Vector3.new(o.X * s, h + o.Y * s, o.Z * s), WHITE))
	end
end

-- Кучка маленьких светящихся грибов
local function glowShrooms(f: Instance, pos: Vector3, s: number)
	local glow = pick({ rgb(120, 255, 230), rgb(255, 150, 240), rgb(190, 255, 120) })
	for _ = 1, 3 do
		local o = Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)) * s
		local h = rng:NextNumber(2.5, 5) * s
		decor(f, cyl(f, 0.9 * s, h, pos + o + Vector3.new(0, h / 2, 0), rgb(250, 240, 220)))
		decor(f, ball(f, Vector3.one * 3 * s, pos + o + Vector3.new(0, h + 0.6 * s, 0), glow, NEON))
	end
end

local function lavaPool(f: Instance, pos: Vector3, s: number)
	local r = rng:NextNumber(12, 24) * s
	decor(f, cyl(f, r + 4, 0.5, up(pos, 0.1), rgb(40, 32, 38)))
	decor(f, cyl(f, r, 0.5, up(pos, 0.2), rgb(255, 120, 40), NEON))
	decor(f, cyl(f, r * 0.5, 0.5, pos + Vector3.new(r * 0.1, 0.3, r * 0.08), rgb(255, 200, 70), NEON))
end

local function volcano(f: Instance, pos: Vector3, s: number)
	local c = rgb(92, 72, 78)
	for i = 0, 3 do
		decor(f, cyl(f, (34 - i * 7) * s, 7 * s, up(pos, (3.5 + i * 7) * s), shade(c, 1 - i * 0.06), Enum.Material.Basalt))
	end
	decor(f, cyl(f, 9 * s, 1 * s, up(pos, 28 * s), rgb(255, 130, 40), NEON))
	decor(f, part(f, Vector3.new(2.4 * s, 14 * s, 0.6 * s), CFrame.new(pos + Vector3.new(0, 20 * s, -8.6 * s)) * CFrame.Angles(math.rad(-27), 0, 0), rgb(255, 130, 40), nil, NEON))
end

local function spire(f: Instance, pos: Vector3, s: number, c: Color3)
	local h = rng:NextNumber(14, 30) * s
	local w = rng:NextNumber(4, 7) * s
	decor(f, part(f, Vector3.new(w, h, w), CFrame.new(up(pos, h / 2 - 1)) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-10, 10))), c))
	decor(f, part(f, Vector3.new(w * 0.6, h * 0.5, w * 0.6), CFrame.new(pos + Vector3.new(w * 0.9, h * 0.25 - 1, w * 0.3)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(-12)), shade(c, 1.2)))
end

local function emberRock(f: Instance, pos: Vector3, s: number)
	rock(f, pos, s * 1.4, rgb(96, 78, 84))
	decor(f, ball(f, Vector3.one * 2.6 * s, up(pos, 3.4 * s), rgb(255, 150, 50), NEON))
end

local CRYSTALS = { rgb(120, 230, 255), rgb(200, 150, 255), rgb(255, 150, 230), rgb(150, 255, 210) }

local function crystal(f: Instance, pos: Vector3, s: number)
	local c = pick(CRYSTALS)
	for i = 1, 4 do
		local h = rng:NextNumber(8, 22) * s
		local w = rng:NextNumber(3, 5) * s
		local cf = CFrame.new(pos + Vector3.new(rng:NextNumber(-3.5, 3.5) * s, h / 2 - 1, rng:NextNumber(-3.5, 3.5) * s)) * CFrame.Angles(math.rad(rng:NextNumber(-22, 22)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-22, 22)))
		-- один кристалл в друзе светится, остальные стеклянные
		local p = part(f, Vector3.new(w, h, w), cf, if i == 1 then shade(c, 1.1) else c, nil, if i == 1 then NEON else Enum.Material.Glass)
		p.Transparency = if i == 1 then 0 else 0.12
		decor(f, p)
	end
end

local function orb(f: Instance, pos: Vector3, s: number)
	local c = pick(CRYSTALS)
	decor(f, cyl(f, 7 * s, 2 * s, up(pos, 1 * s), rgb(60, 130, 160)))
	decor(f, cyl(f, 4 * s, 6 * s, up(pos, 5 * s), rgb(80, 160, 190)))
	decor(f, ball(f, Vector3.one * 6 * s, up(pos, 11 * s), c, NEON))
end

local function cloudPuff(f: Instance, pos: Vector3, s: number)
	decor(f, ball(f, Vector3.new(15, 8, 11) * s, pos, WHITE))
	decor(f, ball(f, Vector3.new(10, 7, 8) * s, pos + Vector3.new(8 * s, -1 * s, 1 * s), WHITE))
	decor(f, ball(f, Vector3.new(9, 6, 8) * s, pos + Vector3.new(-7 * s, -1.5 * s, -1 * s), WHITE))
	decor(f, ball(f, Vector3.new(8, 6, 7) * s, pos + Vector3.new(2 * s, 3 * s, -1 * s), rgb(246, 250, 255)))
end

local function groundCloud(f: Instance, pos: Vector3, s: number)
	cloudPuff(f, up(pos, 2.5 * s), s)
end

local function goldPillar(f: Instance, pos: Vector3, s: number)
	local h = rng:NextNumber(14, 26) * s
	decor(f, cyl(f, 6 * s, 1.6 * s, up(pos, 0.8 * s), GOLD))
	decor(f, cyl(f, 4 * s, h, up(pos, h / 2), rgb(255, 250, 240)))
	decor(f, cyl(f, 6 * s, 1.6 * s, up(pos, h), GOLD))
	decor(f, ball(f, Vector3.one * 3.4 * s, up(pos, h + 2.4 * s), rgb(255, 236, 140), NEON))
end

local function skyTower(f: Instance, pos: Vector3, s: number)
	local roof = pick({ rgb(120, 170, 255), rgb(255, 140, 190), rgb(170, 140, 255) })
	decor(f, cyl(f, 9 * s, 22 * s, up(pos, 11 * s), rgb(255, 250, 240)))
	decor(f, cyl(f, 11.5 * s, 1.6 * s, up(pos, 22 * s), GOLD))
	decor(f, ball(f, Vector3.new(10, 14, 10) * s, up(pos, 24 * s), roof))
	decor(f, ball(f, Vector3.one * 2 * s, up(pos, 31.6 * s), GOLD))
	decor(f, part(f, Vector3.new(2.4, 4, 0.4) * s, CFrame.new(pos + Vector3.new(0, 14 * s, -4.5 * s)), rgb(110, 150, 220)))
end

local THEMES: { [string]: { (Instance, Vector3, number) -> () } } = {
	meadow = {
		function(f, p, s) tree(f, p, s, rgb(90, 190, 90)) end,
		function(f, p, s) tree(f, p, s, rgb(124, 212, 100)) end,
		function(f, p, s) tree(f, p, s, rgb(255, 170, 205)) end,
		function(f, p, s) bush(f, p, s, rgb(80, 170, 80)) end,
		flowers,
		flowers,
		function(f, p, s) rock(f, p, s, rgb(170, 176, 190)) end,
	},
	beach = {
		palm,
		palm,
		palm,
		umbrella,
		umbrella,
		beachBall,
		sandcastle,
		function(f, p, s) rock(f, p, s, rgb(200, 190, 170)) end,
	},
	desert = {
		cactus,
		cactus,
		cactus,
		function(f, p, s) rock(f, p, s, rgb(210, 150, 90)) end,
		function(f, p, s) rock(f, p, s * 2.5, rgb(240, 196, 120)) end,
		function(f, p, s) bush(f, p, s * 0.7, rgb(190, 180, 96)) end,
		function(f, p, s) pyramid(f, p, s * 0.8) end,
	},
	canyon = {
		function(f, p, s) mesa(f, p, s, rgb(196, 96, 66)) end,
		function(f, p, s) mesa(f, p, s, rgb(220, 130, 80)) end,
		function(f, p, s) arch(f, p, s, rgb(210, 112, 72)) end,
		function(f, p, s) rock(f, p, s * 1.5, rgb(170, 84, 60)) end,
		function(f, p, s) rock(f, p, s, rgb(226, 150, 96)) end,
		cactus,
	},
	snow = {
		function(f, p, s) pine(f, p, s, rgb(60, 140, 100)) end,
		function(f, p, s) pine(f, p, s, rgb(90, 160, 120)) end,
		function(f, p, s) pine(f, p, s * 1.3, rgb(70, 150, 130)) end,
		snowman,
		igloo,
		icePond,
		function(f, p, s) rock(f, p, s, rgb(190, 210, 230)) end,
	},
	candy = { lollipop, lollipop, gumdrop, gumdrop, candyCane, cupcake, cupcake },
	mushroom = {
		mushroom,
		mushroom,
		function(f, p, s) mushroom(f, p, s * 1.8) end,
		glowShrooms,
		glowShrooms,
		function(f, p, s) bush(f, p, s, rgb(120, 90, 180)) end,
		function(f, p, s) rock(f, p, s, rgb(110, 90, 150)) end,
	},
	lava = {
		lavaPool,
		lavaPool,
		volcano,
		emberRock,
		function(f, p, s) spire(f, p, s, rgb(84, 68, 78)) end,
		function(f, p, s) rock(f, p, s, rgb(104, 84, 90)) end,
	},
	crystal = {
		crystal,
		crystal,
		crystal,
		orb,
		function(f, p, s) rock(f, p, s, rgb(70, 150, 170)) end,
		function(f, p, s) spire(f, p, s, rgb(60, 130, 160)) end,
	},
	sky = { groundCloud, groundCloud, goldPillar, goldPillar, skyTower },
}

local WATER_PROPS = { boat, swimRing, swimRing }

-- ===== площадка =====

local function cannon(f: Instance, lane: number)
	local x = Layout.laneX(lane)
	local m = Instance.new("Model")
	m.Name = "Cannon" .. lane
	m.Parent = f
	local hue = (lane - 1) / Config.LANES
	local body = Color3.fromHSV(hue, 0.68, 1)
	local bodyDark = Color3.fromHSV(hue, 0.72, 0.78)
	local dark = rgb(70, 60, 90)
	local woodDark = shade(WOOD, 0.8)
	-- цветной круг под пушкой
	cyl(m, 24, 0.3, Vector3.new(x, 0.2, -28), WHITE)
	cyl(m, 21, 0.3, Vector3.new(x, 0.3, -28), Color3.fromHSV(hue, 0.35, 1))
	-- лафет
	part(m, Vector3.new(13, 4.5, 18), CFrame.new(x, 2.75, -28), WOOD)
	part(m, Vector3.new(14, 1.2, 19), CFrame.new(x, 5.4, -28), woodDark)
	for _, sx in { -1, 1 } do
		part(m, Vector3.new(1.8, 6, 11), CFrame.new(x + sx * 6, 8, -27), woodDark)
		part(m, Vector3.new(2, 11, 11), CFrame.new(x + sx * 8, 5.5, -30), dark, Enum.PartType.Cylinder)
		part(m, Vector3.new(2.5, 8, 8), CFrame.new(x + sx * 8, 5.5, -30), rgb(110, 98, 136), Enum.PartType.Cylinder)
		part(m, Vector3.new(3, 3.4, 3.4), CFrame.new(x + sx * 8, 5.5, -30), GOLD, Enum.PartType.Cylinder)
	end
	-- ствол: ось X цилиндра вдоль направления выстрела
	local pivot = Layout.pivot(lane)
	local d = Layout.DIR
	local upv = Vector3.new(0, d.Z, -d.Y)
	local r2 = Layout.BARREL_R * 2
	local function along(dist: number): CFrame
		return CFrame.fromMatrix(pivot + d * dist, d, upv)
	end
	local barrel = part(m, Vector3.new(Layout.BARREL_LEN, r2, r2), along(Layout.BARREL_LEN / 2), body, Enum.PartType.Cylinder)
	barrel.Name = "Barrel"
	-- казённая часть: шар и «пуговка»
	part(m, Vector3.one * (r2 + 1.2), CFrame.new(pivot), bodyDark, Enum.PartType.Ball)
	part(m, Vector3.one * 3.4, CFrame.new(pivot - d * (Layout.BARREL_R + 1.6)), GOLD, Enum.PartType.Ball)
	-- кольца
	part(m, Vector3.new(2.8, r2 + 2.2, r2 + 2.2), along(Layout.BARREL_LEN), GOLD, Enum.PartType.Cylinder)
	part(m, Vector3.new(1.2, r2 + 3, r2 + 3), along(Layout.BARREL_LEN + 0.6), rgb(255, 240, 170), Enum.PartType.Cylinder)
	part(m, Vector3.new(2.5, r2 + 1.2, r2 + 1.2), along(5), GOLD, Enum.PartType.Cylinder)
	part(m, Vector3.new(3, r2 + 0.5, r2 + 0.5), along(15), WHITE, Enum.PartType.Cylinder)
	part(m, Vector3.new(1.4, r2 + 0.6, r2 + 0.6), along(22), bodyDark, Enum.PartType.Cylinder)
	local mouth = part(m, Vector3.new(0.4, r2 - 1, r2 - 1), along(Layout.BARREL_LEN + 1.3), rgb(30, 24, 40), Enum.PartType.Cylinder)
	mouth.Name = "Mouth"
	local att = Instance.new("Attachment")
	att.Name = "Muzzle"
	att.Parent = mouth
	local fire = Instance.new("ParticleEmitter")
	fire.Name = "Blast"
	fire.Enabled = false
	fire.Texture = "rbxasset://textures/particles/smoke_main.dds"
	fire.Color = ColorSequence.new(rgb(255, 230, 140), rgb(255, 140, 60))
	fire.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6), NumberSequenceKeypoint.new(1, 14) })
	fire.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	fire.Lifetime = NumberRange.new(0.5, 0.9)
	fire.Speed = NumberRange.new(20, 40)
	fire.SpreadAngle = Vector2.new(25, 25)
	fire.EmissionDirection = Enum.NormalId.Right
	fire.LightEmission = 0.6
	fire.Parent = att
	-- номер пушки
	local tagBack = part(m, Vector3.new(9.4, 5.4, 0.4), CFrame.new(x, 4, -37.9), body)
	tagBack.Name = "TagFrame"
	local tag = part(m, Vector3.new(8, 4, 0.5), CFrame.new(x, 4, -38), WHITE)
	label(tag, Enum.NormalId.Back, tostring(lane), bodyDark)
	label(tag, Enum.NormalId.Front, tostring(lane), bodyDark)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
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

local boardLists: { [string]: Frame } = {}
local modLabel: TextLabel? = nil

local function balloons(f: Instance, pos: Vector3)
	decor(f, cyl(f, 3, 1.2, up(pos, 0.6), GOLD))
	decor(f, cyl(f, 1.4, 26, up(pos, 13), WHITE))
	decor(f, ball(f, Vector3.one * 4, up(pos, 27), rgb(255, 236, 150), NEON))
	local cols = { rgb(255, 96, 120), rgb(90, 180, 255), rgb(255, 206, 70) }
	for i, o in { Vector3.new(-3.5, 33, 0), Vector3.new(3.5, 34.5, 1), Vector3.new(0, 38, -1) } do
		decor(f, ball(f, Vector3.new(6, 7.4, 6), pos + o, cols[i]))
	end
end

local function planter(f: Instance, pos: Vector3)
	decor(f, cyl(f, 8, 4, up(pos, 2), rgb(255, 150, 110)))
	decor(f, cyl(f, 9, 1, up(pos, 4.2), WHITE))
	decor(f, ball(f, Vector3.one * 9, up(pos, 7.5), rgb(96, 196, 96)))
	decor(f, ball(f, Vector3.one * 2, pos + Vector3.new(2.5, 10.6, -2), pick(FLOWER_COLS)))
	decor(f, ball(f, Vector3.one * 2, pos + Vector3.new(-2.8, 10, 1.5), pick(FLOWER_COLS)))
end

local function plaza(f: Instance)
	local z0, z1 = Layout.PLAZA_Z0, Layout.PLAZA_Z1
	local zc = (z0 + z1) / 2
	local base = part(f, Vector3.new(260, 4, z1 - z0), CFrame.new(0, -1.9, zc), rgb(246, 240, 252))
	base.Name = "Plaza"
	-- плитка
	for i = -6, 6 do
		for j = 0, 5 do
			if (i + j) % 2 == 0 then
				decor(f, part(f, Vector3.new(20, 0.2, 20), CFrame.new(i * 20, 0.15, z0 + 10 + j * 20), rgb(226, 214, 250)))
			end
		end
	end
	-- бортик по краям и полосатая стартовая линия спереди
	local rim = rgb(255, 255, 255)
	decor(f, part(f, Vector3.new(266, 2.4, 3), CFrame.new(0, 1.2, z0 - 1.5), rim))
	for _, sx in { -1, 1 } do
		decor(f, part(f, Vector3.new(3, 2.4, z1 - z0), CFrame.new(sx * 131.5, 1.2, zc), rim))
		decor(f, part(f, Vector3.new(3.4, 0.6, z1 - z0 + 0.4), CFrame.new(sx * 131.5, 2.7, zc), rgb(255, 130, 160)))
	end
	decor(f, part(f, Vector3.new(266.4, 0.6, 3.4), CFrame.new(0, 2.7, z0 - 1.5), rgb(255, 130, 160)))
	for i = -6, 6 do
		local c = if i % 2 == 0 then rgb(255, 96, 120) else WHITE
		decor(f, part(f, Vector3.new(20, 0.3, 4), CFrame.new(i * 20, 0.22, z1 - 2), c))
	end
	for lane = 1, Config.LANES do
		cannon(f, lane)
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(24, 1, 24)
	spawn.CFrame = CFrame.new(Layout.SPAWN - Vector3.new(0, 2.4, 0))
	spawn.Color = GOLD
	spawn.Material = SMOOTH
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Transparency = 0
	spawn.Parent = f
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end
	-- круги вокруг точки появления
	local sp = Vector3.new(Layout.SPAWN.X, 0, Layout.SPAWN.Z)
	decor(f, cyl(f, 46, 0.3, up(sp, 0.2), rgb(255, 130, 160)))
	decor(f, cyl(f, 41, 0.3, up(sp, 0.3), WHITE))
	-- название над пушками
	local titleCf = CFrame.new(0, 62, -40)
	local title = sign(f, Vector3.new(120, 22, 2), titleCf, "+1 LAUNCH POWER", rgb(255, 110, 90), WHITE)
	title.Name = "Title"
	part(f, Vector3.new(125, 27, 1.2), titleCf, GOLD)
	part(f, Vector3.new(128, 30, 0.6), titleCf, WHITE)
	for _, sx in { -1, 1 } do
		cyl(f, 5, 50, Vector3.new(sx * 58, 25, -40), WHITE)
		cyl(f, 5.6, 4, Vector3.new(sx * 58, 16, -40), rgb(255, 110, 90))
		cyl(f, 5.6, 4, Vector3.new(sx * 58, 34, -40), rgb(255, 110, 90))
		cyl(f, 9, 2, Vector3.new(sx * 58, 1, -40), GOLD)
		ball(f, Vector3.one * 8, Vector3.new(sx * 66, 77, -40), rgb(255, 236, 150), NEON)
	end
	-- лидерборды: за всё время и за сегодня
	local cfAll = CFrame.new(-118, 26, -80) * CFrame.Angles(0, math.rad(-120), 0)
	local cfToday = CFrame.new(118, 26, -80) * CFrame.Angles(0, math.rad(120), 0)
	boardLists.all = makeBoard(f, cfAll, "FARTHEST EVER")
	boardLists.today = makeBoard(f, cfToday, "TODAY'S RACE")
	for _, cf in { cfAll, cfToday } do
		part(f, Vector3.new(47, 55, 1.2), cf, GOLD)
		part(f, Vector3.new(49.5, 57.5, 0.6), cf, WHITE)
		ball(f, Vector3.one * 5, (cf * CFrame.new(0, 31, 0)).Position, rgb(255, 236, 150), NEON)
	end
	-- модификатор дня
	local modCf = CFrame.new(0, 80, -40)
	local modSign = part(f, Vector3.new(70, 10, 1.5), modCf, rgb(255, 170, 60))
	modLabel = label(modSign, Enum.NormalId.Back, "", WHITE)
	label(modSign, Enum.NormalId.Front, "", WHITE)
	part(f, Vector3.new(73, 13, 0.8), modCf, WHITE)
	-- подсказка про коды
	sign(f, Vector3.new(36, 7, 1.5), CFrame.new(0, 8, -112), "CODES IN 🎁 GIFTS", rgb(110, 200, 255), WHITE)
	part(f, Vector3.new(38, 9, 0.8), CFrame.new(0, 8, -112), WHITE)
	for _, sx in { -1, 1 } do
		cyl(f, 1.6, 6, Vector3.new(sx * 14, 3, -112), WHITE)
	end
	-- шарики и клумбы
	for _, sx in { -1, 1 } do
		balloons(f, Vector3.new(sx * 122, 0, z1 - 10))
		balloons(f, Vector3.new(sx * 122, 0, z0 + 8))
		planter(f, Vector3.new(sx * 122, 0, -36))
		planter(f, Vector3.new(sx * 60, 0, z0 + 8))
		planter(f, Vector3.new(sx * 30, 0, z0 + 8))
	end
	-- невидимые стенки по краям площадки сзади и с боков
	for _, w in {
		{ Vector3.new(270, 60, 2), Vector3.new(0, 30, z0 - 1) },
		{ Vector3.new(2, 60, z1 - z0), Vector3.new(-131, 30, zc) },
		{ Vector3.new(2, 60, z1 - z0), Vector3.new(131, 30, zc) },
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

local FIELD_W = Config.MAP_HALF_WIDTH * 2 + 120 -- ширина ворот, отметок и края мира
local GROUND_W = 2400 -- земля шире поля, чтобы за холмами не было пустоты
local SHORE_X = 150 -- на пляже правее этой линии — море

-- Материал земли и вид дальних гор для каждой темы
local SCENERY: { [string]: { mat: Enum.Material, far: Color3, cap: Color3?, glow: boolean?, mesa: boolean? } } = {
	meadow = { mat = Enum.Material.Grass, far = rgb(110, 196, 140) },
	beach = { mat = Enum.Material.Sand, far = rgb(120, 206, 130) },
	desert = { mat = Enum.Material.Sand, far = rgb(226, 160, 100) },
	canyon = { mat = Enum.Material.Sandstone, far = rgb(180, 90, 70), mesa = true },
	snow = { mat = Enum.Material.Snow, far = rgb(150, 176, 214), cap = WHITE },
	candy = { mat = SMOOTH, far = rgb(196, 160, 255), cap = rgb(255, 250, 252) },
	mushroom = { mat = Enum.Material.Grass, far = rgb(110, 90, 190), cap = rgb(255, 130, 190) },
	lava = { mat = Enum.Material.Basalt, far = rgb(96, 74, 84), cap = rgb(255, 120, 40), glow = true },
	crystal = { mat = Enum.Material.Glacier, far = rgb(90, 140, 214), cap = rgb(190, 244, 255) },
	sky = { mat = SMOOTH, far = WHITE },
}

-- Гора-эллипсоид с необязательной «шапкой» (снег, глазурь, лава)
local function mountain(f: Instance, x: number, z: number, w: number, h: number, color: Color3, cap: Color3?, glow: boolean?)
	local cy = -h * 0.12
	decor(f, ball(f, Vector3.new(w, h, w), Vector3.new(x, cy, z), color))
	if cap then
		if glow then
			decor(f, ball(f, Vector3.one * h * 0.16, Vector3.new(x, cy + h * 0.47, z), cap, NEON))
		else
			decor(f, ball(f, Vector3.new(w * 0.62, h * 0.5, w * 0.62), Vector3.new(x, cy + h * 0.3, z), cap))
		end
	end
end

-- Море справа от пляжа: плоская вода чуть выше песка, волнистый берег с пеной. Земля под водой остаётся на Y=0.
local function sea(f: Instance, zFrom: number, zTo: number)
	local water = rgb(64, 196, 232)
	local za, zb = zFrom + 90, zTo - 90
	decor(f, part(f, Vector3.new(GROUND_W / 2 - SHORE_X, 0.6, zb - za), CFrame.new((GROUND_W / 2 + SHORE_X) / 2, 0.1, (za + zb) / 2), water))
	local z = za
	while z <= zb do
		local d = rng:NextNumber(130, 190)
		local x = SHORE_X + rng:NextNumber(-8, 14)
		decor(f, cyl(f, d + 12, 0.5, Vector3.new(x, 0.02, z), WHITE))
		decor(f, cyl(f, d, 0.6, Vector3.new(x, 0.08, z), water))
		z += d * 0.55
	end
	-- светлые пятна-блики и пара островков
	for _ = 1, 10 do
		local d = rng:NextNumber(30, 70)
		decor(f, cyl(f, d, 0.3, Vector3.new(rng:NextNumber(SHORE_X + 80, 900), 0.3, rng:NextNumber(za + 40, zb - 40)), rgb(120, 222, 244)))
	end
	for _ = 1, 4 do
		local pos = Vector3.new(rng:NextNumber(420, 800), 0, rng:NextNumber(za + 80, zb - 80))
		decor(f, ball(f, Vector3.new(90, 16, 70), pos, rgb(246, 222, 150)))
		palm(f, up(pos, 7), 1.8)
		palm(f, pos + Vector3.new(14, 6, 8), 1.3)
	end
end

local function gate(f: Instance, i: number, zone: Config.Zone, z: number)
	local m = Instance.new("Model")
	m.Name = "Gate" .. i
	m.Parent = f
	local gc = Color3.fromHSV((i * 0.11) % 1, 0.6, 1)
	local px = Config.MAP_HALF_WIDTH + 8
	for _, sx in { -1, 1 } do
		decor(m, cyl(m, 16, 170, Vector3.new(sx * px, 85, z), gc))
		decor(m, cyl(m, 22, 6, Vector3.new(sx * px, 3, z), WHITE))
		for _, y in { 50, 100, 150 } do
			decor(m, cyl(m, 17.5, 7, Vector3.new(sx * px, y, z), WHITE))
		end
		decor(m, ball(m, Vector3.one * 26, Vector3.new(sx * (px + 8), 204, z), GOLD))
	end
	local beam = part(m, Vector3.new(FIELD_W, 30, 6), CFrame.new(0, 175, z), gc)
	decor(m, beam)
	decor(m, part(m, Vector3.new(FIELD_W + 6, 36, 3), CFrame.new(0, 175, z), WHITE))
	local text = string.format("ZONE %d · %s · %s", i, string.upper(zone.name), Fmt.dist(zone.from))
	label(beam, Enum.NormalId.Front, text, WHITE)
	label(beam, Enum.NormalId.Back, text, WHITE)
	decor(m, part(m, Vector3.new(FIELD_W, 0.3, 6), CFrame.new(0, 0.2, z), gc, nil, NEON))
end

local function ground(f: Instance)
	for i, zone in Config.ZONES do
		local zFrom = if i == 1 then 0 else zone.from
		local nextZ = Config.ZONES[i + 1]
		local zTo = if nextZ then nextZ.from else Config.MAP_END + 600
		local look = SCENERY[zone.theme] or SCENERY.meadow
		local isBeach = zone.theme == "beach"
		local z = zFrom
		local stripe = 0
		while z < zTo do
			local len = math.min(400, zTo - z)
			stripe += 1
			local col = if stripe % 2 == 0 then zone.ground else zone.ground2
			local p = part(f, Vector3.new(GROUND_W, 20, len), CFrame.new(0, -10, z + len / 2), col, nil, look.mat)
			p.Name = "Ground"
			p.CastShadow = false
			z += len
		end
		local zf = Instance.new("Folder")
		zf.Name = zone.name
		zf.Parent = f
		-- ближние холмы по краям: начинаются за полосой полёта (|X| > 300)
		local hz = zFrom
		while hz < zTo do
			for _, sx in { -1, 1 } do
				if not (isBeach and sx > 0) then
					local r = rng:NextNumber(60, 110)
					local x = sx * (Config.MAP_HALF_WIDTH + 95 + rng:NextNumber(0, 50))
					local c = shade(zone.ground, rng:NextNumber(0.84, 0.96))
					decor(zf, ball(zf, Vector3.new(r * 1.5, r * rng:NextNumber(0.7, 1.1), r * 1.5), Vector3.new(x, -r * 0.12, hz + rng:NextNumber(0, 80)), c))
				end
			end
			hz += rng:NextNumber(110, 170)
		end
		-- дальние горы: второй план, который читается с высоты
		local mz = zFrom + 100
		while mz < zTo do
			for _, sx in { -1, 1 } do
				if not (isBeach and sx > 0) then
					local x = sx * rng:NextNumber(620, 900)
					local zz = mz + rng:NextNumber(-60, 60)
					if look.mesa then
						mesa(zf, Vector3.new(x, 0, zz), rng:NextNumber(5, 8), look.far)
					else
						local w = rng:NextNumber(300, 460)
						mountain(zf, x, zz, w, w * rng:NextNumber(0.7, 1.15), shade(look.far, rng:NextNumber(0.92, 1.06)), look.cap, look.glow)
					end
				end
			end
			mz += rng:NextNumber(260, 380)
		end
		if isBeach then
			sea(zf, zFrom, zTo)
		elseif zone.theme == "lava" then
			-- светящиеся лавовые реки вдоль краёв поля
			for _, sx in { -1, 1 } do
				local x = sx * (Config.MAP_HALF_WIDTH + 34)
				decor(zf, part(zf, Vector3.new(40, 0.4, zTo - zFrom), CFrame.new(x, 0.05, (zFrom + zTo) / 2), rgb(46, 36, 42)))
				decor(zf, part(zf, Vector3.new(30, 0.4, zTo - zFrom), CFrame.new(x, 0.15, (zFrom + zTo) / 2), rgb(255, 120, 40), nil, NEON))
			end
		end
		-- декор
		local list = THEMES[zone.theme]
		local count = math.clamp(math.floor((zTo - zFrom) / 28), 30, 200)
		for _ = 1, count do
			local x = rng:NextNumber(-Config.MAP_HALF_WIDTH + 10, Config.MAP_HALF_WIDTH - 10)
			local zz = rng:NextNumber(zFrom + 20, zTo - 20)
			local s = rng:NextNumber(0.9, 1.8)
			local pos = Vector3.new(x, 0, zz)
			if isBeach and x > SHORE_X - 90 then
				-- у кромки пусто, дальше в воде — лодки и круги
				if x > SHORE_X + 100 and zz > zFrom + 140 and zz < zTo - 140 then
					pick(WATER_PROPS)(zf, pos, s)
				end
			else
				pick(list)(zf, pos, s)
			end
		end
		-- ворота зоны
		if i > 1 then
			gate(f, i, zone, zFrom)
		end
	end
	-- отметки дистанции
	local marks = Instance.new("Folder")
	marks.Name = "Marks"
	marks.Parent = f
	local d = 250
	while d < Config.MAP_END do
		local big = d % 1000 == 0
		decor(marks, part(marks, Vector3.new(Config.MAP_HALF_WIDTH * 2, 0.3, if big then 4 else 2), CFrame.new(0, 0.18, d), WHITE))
		if big or d < 1000 then
			local plate = part(marks, Vector3.new(90, 0.4, 28), CFrame.new(0, 0.25, d + 18), WHITE)
			plate.Transparency = 1
			decor(marks, plate)
			local t = label(plate, Enum.NormalId.Top, Fmt.dist(d), WHITE)
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
		local arc = part(edge, Vector3.new(FIELD_W + 40, 26, 10), CFrame.new(0, 40 + k * 26, e + 120), c, nil, NEON)
		decor(edge, arc)
	end
	local wall = part(edge, Vector3.new(FIELD_W + 40, 30, 4), CFrame.new(0, 230, e + 116), GOLD)
	decor(edge, wall)
	label(wall, Enum.NormalId.Front, "THE EDGE OF THE WORLD · REBIRTH TO GO AGAIN", WHITE)
	for _, sx in { -1, 1 } do
		decor(edge, cyl(edge, 40, 260, Vector3.new(sx * (FIELD_W / 2 + 30), 130, e + 120), WHITE))
		decor(edge, ball(edge, Vector3.one * 60, Vector3.new(sx * (FIELD_W / 2 + 30), 280, e + 120), GOLD))
	end
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
	-- объёмные облака движка: на слабых телефонах отключаются сами
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.5
		clouds.Density = 0.35
		clouds.Color = WHITE
		clouds.Parent = terrain
	end
end

local function lighting()
	Lighting.ClockTime = 14.3
	Lighting.GeographicLatitude = 32
	Lighting.Brightness = 2.7
	Lighting.Ambient = rgb(120, 114, 140)
	Lighting.OutdoorAmbient = rgb(168, 166, 190)
	Lighting.ColorShift_Top = rgb(255, 244, 220)
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.ExposureCompensation = 0.08
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.26
	atm.Offset = 0.2
	atm.Color = rgb(190, 225, 255)
	atm.Decay = rgb(150, 190, 240)
	atm.Glare = 0.15
	atm.Haze = 0.9
	atm.Parent = Lighting
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Saturation = 0.24
	cc.Contrast = 0.08
	cc.Brightness = 0.02
	cc.TintColor = rgb(255, 250, 244)
	cc.Parent = Lighting
	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.55
	bloom.Size = 26
	bloom.Threshold = 1.3
	bloom.Parent = Lighting
	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.7
	rays.Parent = Lighting
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
