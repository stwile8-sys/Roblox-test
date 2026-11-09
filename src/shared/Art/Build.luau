--!strict
-- Сборка существ-артефактов из простых деталей (без мешей). Работает на сервере, клиенте и в ViewportFrame.
-- Всё строится в «единичном» пространстве (рост ≈ 1) и масштабируется на размер редкости × scale.
-- Роли деталей (атрибут Role) нужны анимации: body, head, eye, lid, mouth, ring, shard, glow, limb, prop, pillar.

local Defs = require(script.Parent.Defs)

local M = {}

type Ctx = { model: Model, root: BasePart, k: number, def: Defs.Def, cf: CFrame }

local BALL = Enum.PartType.Ball
local BLOCK = Enum.PartType.Block
local CYL = Enum.PartType.Cylinder
local WEDGE = Enum.PartType.Wedge

local function part(c: Ctx, shape: Enum.PartType, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material?, role: string?, transp: number?): BasePart
	local p = Instance.new("Part")
	p.Shape = shape
	p.Size = size * c.k
	p.CFrame = c.cf * CFrame.new(offset.Position * c.k) * offset.Rotation
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transp or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p:SetAttribute("Role", role or "body")
	p.Parent = c.model
	return p
end

local function ball(c: Ctx, d: number, pos: Vector3, color: Color3, mat: Enum.Material?, role: string?, sx: number?, sy: number?, sz: number?): BasePart
	return part(c, BALL, Vector3.new(d * (sx or 1), d * (sy or 1), d * (sz or 1)), CFrame.new(pos), color, mat, role)
end

local function block(c: Ctx, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, role: string?): BasePart
	return part(c, BLOCK, size, cf, color, mat, role)
end

local function wedge(c: Ctx, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, role: string?): BasePart
	return part(c, WEDGE, size, cf, color, mat, role)
end

local function cyl(c: Ctx, len: number, d: number, cf: CFrame, color: Color3, mat: Enum.Material?, role: string?): BasePart
	return part(c, CYL, Vector3.new(len, d, d), cf, color, mat, role)
end

local function darker(col: Color3, f: number): Color3
	return Color3.new(col.R * f, col.G * f, col.B * f)
end

local WHITE = Color3.new(1, 1, 1)
local INK = Color3.fromRGB(25, 22, 40)

-- Лицо: глаза (с веками для моргания) и рот по эмоции. center — центр лица, w — ширина лица, n — число глаз
local function face(c: Ctx, center: Vector3, w: number, emotion: string, n: number?, eyeColor: Color3?)
	local count = n or 2
	local eyeD = w * (if count > 2 then 0.22 else 0.3)
	for i = 1, count do
		local t = if count == 1 then 0 else (i - 1) / (count - 1) - 0.5
		local x = t * w * (if count > 2 then 0.9 else 0.7)
		local y = if count > 2 then math.abs(t) * -0.1 * w + w * 0.12 else w * 0.12
		local ep = center + Vector3.new(x, y, 0)
		ball(c, eyeD, ep, WHITE, Enum.Material.SmoothPlastic, "eye")
		ball(c, eyeD * 0.55, ep + Vector3.new(0, 0, -eyeD * 0.35), eyeColor or INK, Enum.Material.Neon, "eye")
		-- веко: прячется внутри глаза, анимация опускает его при моргании
		local lid = block(c, Vector3.new(eyeD * 1.1, eyeD * 0.5, eyeD * 0.3), CFrame.new(ep + Vector3.new(0, eyeD * 0.55, -eyeD * 0.3)), c.def.color, nil, "lid")
		lid:SetAttribute("EyeY", ep.Y)
		if emotion == "sleepy" then
			lid.CFrame = lid.CFrame * CFrame.new(0, -eyeD * 0.3 * c.k, 0)
		end
		if emotion == "angry" or (emotion == "sly" and i == 1) then
			local tilt = if x < 0 then -0.45 else 0.45
			if emotion == "sly" then
				tilt = -0.3
			end
			block(c, Vector3.new(eyeD * 1.1, eyeD * 0.18, eyeD * 0.2), CFrame.new(ep + Vector3.new(0, eyeD * 0.75, -eyeD * 0.35)) * CFrame.Angles(0, 0, tilt), INK, nil, "lid")
		end
	end
	local m = center + Vector3.new(0, -w * 0.22, -w * 0.02)
	if emotion == "surprise" then
		ball(c, w * 0.16, m, INK, nil, "mouth")
	elseif emotion == "smile" or emotion == "sleepy" then
		block(c, Vector3.new(w * 0.16, w * 0.05, w * 0.05), CFrame.new(m + Vector3.new(-w * 0.08, w * 0.02, 0)) * CFrame.Angles(0, 0, -0.5), INK, nil, "mouth")
		block(c, Vector3.new(w * 0.16, w * 0.05, w * 0.05), CFrame.new(m + Vector3.new(w * 0.08, w * 0.02, 0)) * CFrame.Angles(0, 0, 0.5), INK, nil, "mouth")
	elseif emotion == "angry" then
		block(c, Vector3.new(w * 0.3, w * 0.06, w * 0.05), CFrame.new(m), INK, nil, "mouth")
		wedge(c, Vector3.new(w * 0.05, w * 0.08, w * 0.06), CFrame.new(m + Vector3.new(-w * 0.1, w * 0.06, -w * 0.01)) * CFrame.Angles(math.pi, 0, 0), WHITE, nil, "mouth")
		wedge(c, Vector3.new(w * 0.05, w * 0.08, w * 0.06), CFrame.new(m + Vector3.new(w * 0.1, w * 0.06, -w * 0.01)) * CFrame.Angles(math.pi, 0, 0), WHITE, nil, "mouth")
	else -- sly
		block(c, Vector3.new(w * 0.26, w * 0.05, w * 0.05), CFrame.new(m + Vector3.new(w * 0.03, 0, 0)) * CFrame.Angles(0, 0, 0.25), INK, nil, "mouth")
	end
end

local function legs(c: Ctx, n: number, radius: number, y: number, len: number, col: Color3)
	for i = 1, n do
		local a = (i - 0.5) / n * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
		block(c, Vector3.new(0.08, len, 0.08), CFrame.new(pos) * CFrame.Angles(math.sin(a) * 0.4, 0, -math.cos(a) * 0.4), col, nil, "limb")
	end
end

local function ring(c: Ctx, radius: number, y: number, col: Color3, tilt: number?, segments: number?)
	local n = segments or 12
	for i = 1, n do
		local a = i / n * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
		local p = block(c, Vector3.new(radius * 0.55, 0.05, 0.08), CFrame.Angles(tilt or 0, 0, 0) * CFrame.new(pos) * CFrame.Angles(0, -a + math.pi / 2, 0), col, Enum.Material.Neon, "ring")
		p:SetAttribute("Ring", radius)
	end
end

local function shards(c: Ctx, n: number, radius: number, y: number, col: Color3)
	for i = 1, n do
		local a = i / n * math.pi * 2
		local p = part(c, BLOCK, Vector3.new(0.12, 0.28, 0.12), CFrame.new(math.cos(a) * radius, y + math.sin(a * 2) * 0.1, math.sin(a) * radius) * CFrame.Angles(0.6, a, 0.6), col, Enum.Material.Neon, "shard")
		p:SetAttribute("Phase", a)
	end
end

local function gemBody(c: Ctx, h: number, w: number, y: number, col: Color3, facets: number, role: string?)
	-- кристалл: призма из повернутых блоков + клинья сверху и снизу
	for i = 1, facets do
		local a = i / facets * math.pi
		block(c, Vector3.new(w, h * 0.5, w * 0.35), CFrame.new(0, y, 0) * CFrame.Angles(0, a, 0), col, Enum.Material.Glass, role or "body")
	end
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2
		wedge(c, Vector3.new(w * 0.7, h * 0.28, w * 0.35), CFrame.new(0, y + h * 0.39, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -w * 0.17), col, Enum.Material.Glass, role or "body")
		wedge(c, Vector3.new(w * 0.7, h * 0.28, w * 0.35), CFrame.new(0, y - h * 0.39, 0) * CFrame.Angles(math.pi, a, 0) * CFrame.new(0, 0, -w * 0.17), darker(col, 0.85), Enum.Material.Glass, role or "body")
	end
end

-- ── Семейства силуэтов ──────────────────────────────────────
local SHAPES: { [string]: (Ctx) -> () } = {}

SHAPES.drop = function(c)
	local d = c.def
	local s = d.p.stretch or 1.2
	ball(c, 0.75, Vector3.new(0, -0.1, 0), d.color, Enum.Material.Glass, "body", 1, 1, 1)
	part(c, WEDGE, Vector3.new(0.32, 0.45 * s, 0.32), CFrame.new(0, 0.38, 0), d.color, Enum.Material.Glass, "body")
	ball(c, 0.25, Vector3.new(0.15, 0.08, -0.28), WHITE, Enum.Material.Neon, "glow", 0.6, 1, 0.3)
	face(c, Vector3.new(0, -0.1, -0.36), 0.55, d.emotion)
end

SHAPES.stone = function(c)
	local d = c.def
	ball(c, 0.85, Vector3.new(0, -0.1, 0), d.color, Enum.Material.Slate, "body", 1.1, 0.8, 1)
	ball(c, 0.4, Vector3.new(0.25, 0.2, 0.1), darker(d.color, 0.9), Enum.Material.Slate, "body")
	if d.p.moss then
		ball(c, 0.5, Vector3.new(-0.1, 0.25, 0.05), Color3.fromHex("#6BBF59"), Enum.Material.Grass, "prop", 1.2, 0.35, 1)
		ball(c, 0.12, Vector3.new(-0.15, 0.38, -0.05), Color3.fromHex("#FF8FC4"), Enum.Material.Neon, "glow")
	end
	face(c, Vector3.new(0, -0.08, -0.4), 0.55, d.emotion)
end

SHAPES.feather = function(c)
	local d = c.def
	ball(c, 0.55, Vector3.new(0, -0.2, 0), d.color, Enum.Material.SmoothPlastic, "body")
	for i = -1, 1 do
		block(c, Vector3.new(0.14, 0.7, 0.04), CFrame.new(i * 0.14, 0.25, 0.1) * CFrame.Angles(0, 0, -i * 0.35), if i == 0 then d.glow else d.color, if i == 0 then Enum.Material.Neon else nil, "limb")
	end
	cyl(c, 0.05, 0.3, CFrame.new(0, -0.2, -0.27) * CFrame.Angles(0, math.pi / 2, 0), WHITE, nil, "prop")
	face(c, Vector3.new(0, -0.17, -0.3), 0.42, d.emotion)
end

SHAPES.gem = function(c)
	local d = c.def
	gemBody(c, 0.9, 0.55, 0, d.color, d.p.facets or 6)
	if d.p.spikes then
		for i = 1, 4 do
			local a = i / 4 * math.pi * 2
			wedge(c, Vector3.new(0.12, 0.25, 0.12), CFrame.new(math.cos(a) * 0.32, 0.1, math.sin(a) * 0.32) * CFrame.Angles(0, -a, -math.pi / 2), d.glow, Enum.Material.Neon, "shard")
		end
	end
	face(c, Vector3.new(0, 0, -0.3), 0.45, d.emotion)
end

SHAPES.blob = function(c)
	local d = c.def
	local tall = if d.p.tall then 1.3 else 1
	ball(c, 0.85, Vector3.new(0, -0.12, 0), d.color, Enum.Material.Glass, "body", 1.1, 0.85 * tall, 1)
	if d.p.bubbles then
		for i = 1, d.p.bubbles do
			ball(c, 0.15, Vector3.new(0.35 * (if i == 1 then 1 else -1), 0.35, 0), d.glow, Enum.Material.Neon, "shard"):SetAttribute("Phase", i)
		end
	end
	if d.p.frog then
		-- лягушка: глаза-шишки сверху, лапки, часы на животе
		ball(c, 0.3, Vector3.new(-0.22, 0.38, -0.05), d.color, nil, "head")
		ball(c, 0.3, Vector3.new(0.22, 0.38, -0.05), d.color, nil, "head")
		cyl(c, 0.04, 0.35, CFrame.new(0, -0.2, -0.45) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromHex("#FFE066"), Enum.Material.Neon, "glow")
		ball(c, 0.25, Vector3.new(-0.42, -0.45, -0.15), darker(d.color, 0.8), nil, "limb", 1.4, 0.5, 1)
		ball(c, 0.25, Vector3.new(0.42, -0.45, -0.15), darker(d.color, 0.8), nil, "limb", 1.4, 0.5, 1)
		face(c, Vector3.new(0, 0.05, -0.42), 0.7, d.emotion)
		return
	end
	face(c, Vector3.new(0, -0.05 * tall, -0.42), 0.6, d.emotion)
end

SHAPES.mush = function(c)
	local d = c.def
	cyl(c, 0.5, 0.42, CFrame.new(0, -0.22, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("#FFF2DE"), nil, "body")
	ball(c, 0.9, Vector3.new(0, 0.15, 0), d.color, nil, "head", 1, 0.55, 1)
	for i = 1, 4 do
		local a = i / 4 * math.pi * 2 + 0.4
		ball(c, 0.13, Vector3.new(math.cos(a) * 0.28, 0.32, math.sin(a) * 0.28), WHITE, Enum.Material.Neon, "glow")
	end
	face(c, Vector3.new(0, -0.22, -0.22), 0.36, d.emotion)
end

SHAPES.snail = function(c)
	local d = c.def
	ball(c, 0.4, Vector3.new(0, -0.35, -0.1), d.color, nil, "body", 2.2, 0.6, 1)
	cyl(c, 0.32, 0.7, CFrame.new(0.05, 0, 0.12), Color3.fromHex("#FFE066"), Enum.Material.SmoothPlastic, "prop")
	cyl(c, 0.34, 0.4, CFrame.new(0.05, 0, 0.12), d.glow, Enum.Material.Neon, "glow")
	block(c, Vector3.new(0.04, 0.25, 0.04), CFrame.new(-0.42, -0.1, -0.15) * CFrame.Angles(0, 0, 0.3), d.color, nil, "limb")
	ball(c, 0.08, Vector3.new(-0.46, 0.04, -0.15), d.glow, Enum.Material.Neon, "eye")
	face(c, Vector3.new(-0.38, -0.3, -0.22), 0.28, d.emotion)
end

SHAPES.bug = function(c)
	local d = c.def
	ball(c, 1.0, Vector3.new(0, -0.15, 0.15), d.color, Enum.Material.SmoothPlastic, "body", 1, 0.7, 1.2)
	block(c, Vector3.new(0.03, 0.55, 1.1), CFrame.new(0, -0.02, 0.15), darker(d.color, 0.6), nil, "body")
	ball(c, 0.55, Vector3.new(0, -0.05, -0.45), darker(d.color, 0.75), nil, "head")
	if d.p.horn then
		wedge(c, Vector3.new(0.1, 0.4, 0.2), CFrame.new(0, 0.3, -0.55) * CFrame.Angles(-0.4, 0, 0), d.glow, Enum.Material.Neon, "head")
	end
	if d.p.crab then
		for s = -1, 1, 2 do
			ball(c, 0.3, Vector3.new(s * 0.6, 0, -0.45), d.color, nil, "limb", 1, 0.8, 1.3)
			wedge(c, Vector3.new(0.1, 0.2, 0.25), CFrame.new(s * 0.62, 0.15, -0.6), WHITE, nil, "limb")
		end
		cyl(c, 0.06, 0.45, CFrame.new(0, 0.2, 0.25) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("#FFE066"), Enum.Material.Neon, "ring")
	end
	legs(c, 6, 0.48, -0.45, 0.35, darker(d.color, 0.5))
	face(c, Vector3.new(0, -0.02, -0.71), 0.48, d.emotion)
end

SHAPES.fox = function(c)
	local d = c.def
	local big = if d.p.big then 1.15 else 1
	ball(c, 0.8 * big, Vector3.new(0, -0.3, 0.12), d.color, nil, "body", 0.9, 0.8, 1.2)
	ball(c, 0.62 * big, Vector3.new(0, 0.18, -0.2), d.color, nil, "head")
	wedge(c, Vector3.new(0.22, 0.3, 0.24), CFrame.new(0, 0.05, -0.55), WHITE, nil, "head")
	for s = -1, 1, 2 do
		wedge(c, Vector3.new(0.18, 0.32, 0.1), CFrame.new(s * 0.2, 0.55, -0.2) * CFrame.Angles(0, 0, s * -0.2), d.color, nil, "head")
		wedge(c, Vector3.new(0.1, 0.2, 0.05), CFrame.new(s * 0.2, 0.52, -0.25) * CFrame.Angles(0, 0, s * -0.2), d.glow, Enum.Material.Neon, "head")
	end
	for i = 1, d.p.tails or 1 do
		local a = (i - (d.p.tails or 1) / 2 - 0.5) * 0.5
		local p = block(c, Vector3.new(0.22, 0.22, 0.7), CFrame.new(math.sin(a) * 0.3, -0.05, 0.65) * CFrame.Angles(0.7, a, 0), d.glow, Enum.Material.Neon, "limb")
		p:SetAttribute("Phase", i)
	end
	block(c, Vector3.new(0.12, 0.3, 0.12), CFrame.new(-0.2, -0.62, -0.1), darker(d.color, 0.7), nil, "limb")
	block(c, Vector3.new(0.12, 0.3, 0.12), CFrame.new(0.2, -0.62, -0.1), darker(d.color, 0.7), nil, "limb")
	face(c, Vector3.new(0, 0.2, -0.49), 0.5, d.emotion, 2, d.glow)
end

SHAPES.owl = function(c)
	local d = c.def
	ball(c, 0.95, Vector3.new(0, -0.15, 0), d.color, nil, "body", 1, 1.15, 0.9)
	ball(c, 0.6, Vector3.new(0, -0.25, -0.2), Color3.fromHex("#FFF2DE"), nil, "body", 1, 1, 0.6)
	block(c, Vector3.new(0.35, 0.6, 0.1), CFrame.new(-0.5, -0.15, 0.05) * CFrame.Angles(0, 0, -0.2), darker(d.color, 0.8), nil, "limb")
	block(c, Vector3.new(0.35, 0.6, 0.1), CFrame.new(0.5, -0.15, 0.05) * CFrame.Angles(0, 0, 0.2), darker(d.color, 0.8), nil, "limb")
	if d.p.ears then
		wedge(c, Vector3.new(0.15, 0.3, 0.1), CFrame.new(-0.25, 0.45, 0), d.glow, Enum.Material.Neon, "head")
		wedge(c, Vector3.new(0.15, 0.3, 0.1), CFrame.new(0.25, 0.45, 0), d.glow, Enum.Material.Neon, "head")
	end
	if d.p.bell then
		ball(c, 0.25, Vector3.new(-0.28, 0.48, 0), Color3.fromHex("#FFE066"), Enum.Material.Metal, "head")
		ball(c, 0.25, Vector3.new(0.28, 0.48, 0), Color3.fromHex("#FFE066"), Enum.Material.Metal, "head")
	end
	wedge(c, Vector3.new(0.1, 0.12, 0.1), CFrame.new(0, 0.02, -0.48) * CFrame.Angles(math.pi, 0, 0), Color3.fromHex("#FFB347"), nil, "head")
	face(c, Vector3.new(0, 0.12, -0.42), 0.62, d.emotion, 2, d.glow)
end

SHAPES.bat = function(c)
	local d = c.def
	ball(c, 0.65, Vector3.new(0, 0, 0), d.color, nil, "body", 1, 1.1, 0.9)
	for s = -1, 1, 2 do
		local w = block(c, Vector3.new(0.65, if d.p.moth then 0.6 else 0.4, 0.04), CFrame.new(s * 0.55, 0.08, 0.05) * CFrame.Angles(0, 0, s * -0.3), if d.p.moth then d.glow else darker(d.color, 0.8), if d.p.moth then Enum.Material.Neon else nil, "limb")
		w:SetAttribute("Wing", s)
		wedge(c, Vector3.new(0.1, 0.22, 0.08), CFrame.new(s * 0.18, 0.4, 0), d.color, nil, "head")
	end
	face(c, Vector3.new(0, 0.05, -0.3), 0.48, d.emotion, 2, d.glow)
end

SHAPES.golem = function(c)
	local d = c.def
	local mat = Enum.Material.Slate
	if d.p.shell then
		ball(c, 1.0, Vector3.new(0, -0.1, 0.1), d.color, mat, "body", 1.2, 0.7, 1.2)
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			cyl(c, 0.06, 0.3, CFrame.new(math.cos(a) * 0.35, 0.2, math.sin(a) * 0.35 + 0.1) * CFrame.Angles(0, 0, math.pi / 2), d.glow, Enum.Material.Neon, "glow")
		end
		ball(c, 0.42, Vector3.new(0, -0.15, -0.6), Color3.fromHex("#8BC34A"), nil, "head")
		face(c, Vector3.new(0, -0.12, -0.78), 0.35, d.emotion)
		legs(c, 4, 0.5, -0.5, 0.3, darker(d.color, 0.6))
		return
	end
	local k = if d.p.small then 0.85 else 1
	block(c, Vector3.new(0.75, 0.6, 0.55) * k, CFrame.new(0, -0.15, 0), d.color, mat, "body")
	block(c, Vector3.new(0.5, 0.42, 0.45) * k, CFrame.new(0, 0.35 * k, -0.05), darker(d.color, 0.9), mat, "head")
	for s = -1, 1, 2 do
		block(c, Vector3.new(0.22, 0.55, 0.22) * k, CFrame.new(s * 0.5 * k, -0.15, 0) * CFrame.Angles(0, 0, s * 0.15), darker(d.color, 0.8), mat, "limb")
		block(c, Vector3.new(0.22, 0.3, 0.25) * k, CFrame.new(s * 0.2, -0.6, 0), darker(d.color, 0.7), mat, "limb")
		if d.p.claws then
			wedge(c, Vector3.new(0.18, 0.15, 0.12), CFrame.new(s * 0.5, -0.47, -0.12), WHITE, nil, "limb")
		end
	end
	cyl(c, 0.05, 0.25, CFrame.new(0, -0.1, -0.29) * CFrame.Angles(0, math.pi / 2, 0), d.glow, Enum.Material.Neon, "glow")
	if d.p.cogs then
		ring(c, 0.55, 0.05, d.glow, 0.3, 10)
		cyl(c, 0.08, 0.35, CFrame.new(0.42, 0.45, 0) * CFrame.Angles(0, 0, 0), Color3.fromHex("#C9A227"), Enum.Material.Metal, "ring")
	end
	face(c, Vector3.new(0, 0.37 * k, -0.29), 0.42, d.emotion, 2, d.glow)
end

SHAPES.dragon = function(c)
	local d = c.def
	ball(c, 0.75, Vector3.new(0, -0.2, 0.1), d.color, Enum.Material.Metal, "body", 1, 0.9, 1.25)
	block(c, Vector3.new(0.3, 0.3, 0.35), CFrame.new(0, 0.1, -0.3) * CFrame.Angles(-0.5, 0, 0), d.color, Enum.Material.Metal, "body")
	ball(c, 0.5, Vector3.new(0, 0.35, -0.45), d.color, Enum.Material.Metal, "head", 1, 0.9, 1.2)
	block(c, Vector3.new(0.3, 0.2, 0.25), CFrame.new(0, 0.28, -0.7), darker(d.color, 0.85), Enum.Material.Metal, "head")
	for s = -1, 1, 2 do
		wedge(c, Vector3.new(0.08, 0.28, 0.12), CFrame.new(s * 0.15, 0.62, -0.38) * CFrame.Angles(0.5, 0, 0), d.glow, Enum.Material.Neon, "head")
		local w = wedge(c, Vector3.new(0.05, 0.55, 0.7), CFrame.new(s * 0.45, 0.15, 0.15) * CFrame.Angles(0, 0, s * -0.9), if d.p.phoenix then d.glow else darker(d.color, 0.7), if d.p.phoenix then Enum.Material.Neon else Enum.Material.Metal, "limb")
		w:SetAttribute("Wing", s)
	end
	for i = 1, 3 do
		block(c, Vector3.new(0.18 - i * 0.04, 0.18 - i * 0.04, 0.3), CFrame.new(0, -0.3 + i * 0.03, 0.45 + i * 0.25) * CFrame.Angles(0.2 * i, 0, 0), d.color, Enum.Material.Metal, "limb"):SetAttribute("Phase", i)
	end
	ring(c, 0.75, -0.15, d.glow, 0, 10)
	shards(c, 3, 0.85, 0.3, d.glow)
	face(c, Vector3.new(0, 0.38, -0.66), 0.42, d.emotion, 2, d.glow)
end

SHAPES.hourglass = function(c)
	local d = c.def
	local gold = Color3.fromHex("#C9A227")
	cyl(c, 0.08, 0.9, CFrame.new(0, -0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Metal, "body")
	cyl(c, 0.08, 0.9, CFrame.new(0, 0.55, 0) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Metal, "body")
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		cyl(c, 1.05, 0.07, CFrame.new(math.cos(a) * 0.38, 0, math.sin(a) * 0.38) * CFrame.Angles(0, 0, math.pi / 2), gold, Enum.Material.Metal, "body")
	end
	ball(c, 0.6, Vector3.new(0, 0.22, 0), d.color, Enum.Material.Glass, "body", 1, 0.8, 1)
	ball(c, 0.6, Vector3.new(0, -0.22, 0), d.color, Enum.Material.Glass, "body", 1, 0.8, 1)
	ball(c, 0.35, Vector3.new(0, -0.3, 0), d.glow, Enum.Material.Neon, "glow", 1, 0.6, 1)
	ring(c, 0.7, 0, d.glow, 0.5, 10)
	shards(c, 4, 0.8, 0.2, d.glow)
	face(c, Vector3.new(0, 0.2, -0.3), 0.42, d.emotion)
end

SHAPES.knight = function(c)
	local d = c.def
	block(c, Vector3.new(0.65, 0.65, 0.45), CFrame.new(0, -0.15, 0), d.color, Enum.Material.Metal, "body")
	ball(c, 0.5, Vector3.new(0, 0.4, 0), d.color, Enum.Material.Metal, "head", 1, 1.1, 1)
	block(c, Vector3.new(0.5, 0.1, 0.08), CFrame.new(0, 0.42, -0.25), INK, nil, "head")
	wedge(c, Vector3.new(0.06, 0.3, 0.35), CFrame.new(0, 0.75, 0.05), Color3.fromHex("#FF2E63"), nil, "head")
	for s = -1, 1, 2 do
		ball(c, 0.32, Vector3.new(s * 0.42, 0.12, 0), darker(d.color, 0.8), Enum.Material.Metal, "limb")
		block(c, Vector3.new(0.18, 0.3, 0.2), CFrame.new(s * 0.18, -0.62, 0), darker(d.color, 0.7), Enum.Material.Metal, "limb")
	end
	block(c, Vector3.new(0.45, 0.6, 0.06), CFrame.new(-0.55, -0.1, -0.15) * CFrame.Angles(0, 0.3, 0), d.glow, Enum.Material.Neon, "prop")
	shards(c, 4, 0.75, 0.2, d.glow)
	ring(c, 0.7, -0.4, d.glow, 0, 10)
	-- глаза — светящиеся точки в прорези шлема
	ball(c, 0.09, Vector3.new(-0.1, 0.42, -0.27), d.glow, Enum.Material.Neon, "eye")
	ball(c, 0.09, Vector3.new(0.1, 0.42, -0.27), d.glow, Enum.Material.Neon, "eye")
end

SHAPES.serpent = function(c)
	local d = c.def
	for i = 1, 6 do
		local a = i / 6 * math.pi * 1.6
		local p = ball(c, 0.4 - i * 0.03, Vector3.new(math.cos(a) * 0.4, -0.45 + i * 0.08, math.sin(a) * 0.4), if i % 2 == 0 then d.color else darker(d.color, 0.8), nil, "limb")
		p:SetAttribute("Phase", i)
	end
	ball(c, 0.5, Vector3.new(0.1, 0.35, -0.15), d.color, nil, "head", 1, 0.85, 1.2)
	cyl(c, 0.05, 0.6, CFrame.new(0, -0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromHex("#FFE066"), Enum.Material.Neon, "ring")
	ring(c, 0.65, -0.1, d.glow, 0.2, 12)
	shards(c, 3, 0.8, 0.35, d.glow)
	face(c, Vector3.new(0.1, 0.38, -0.38), 0.4, d.emotion, 2, d.glow)
end

SHAPES.titan = function(c)
	local d = c.def
	local mat = Enum.Material.Slate
	block(c, Vector3.new(0.7, 0.6, 0.45), CFrame.new(0, -0.05, 0), d.color, mat, "body")
	block(c, Vector3.new(0.5, 0.3, 0.38), CFrame.new(0, -0.45, 0), darker(d.color, 0.85), mat, "body")
	block(c, Vector3.new(0.48, 0.38, 0.4), CFrame.new(0, 0.42, -0.02), darker(d.color, 0.9), mat, "head")
	for s = -1, 1, 2 do
		ball(c, 0.3, Vector3.new(s * 0.45, 0.2, 0), darker(d.color, 0.75), mat, "limb")
		block(c, Vector3.new(0.18, 0.5, 0.18), CFrame.new(s * 0.48, -0.15, 0), d.color, mat, "limb")
		block(c, Vector3.new(0.2, 0.35, 0.22), CFrame.new(s * 0.17, -0.72, 0), darker(d.color, 0.7), mat, "limb")
		wedge(c, Vector3.new(0.08, 0.3, 0.15), CFrame.new(s * 0.2, 0.72, 0) * CFrame.Angles(0, 0, s * -0.3), d.glow, Enum.Material.Neon, "head")
	end
	cyl(c, 0.05, 0.3, CFrame.new(0, 0, -0.24) * CFrame.Angles(0, math.pi / 2, 0), d.glow, Enum.Material.Neon, "glow")
	ring(c, 0.75, 0.05, d.glow, 0.15, 14)
	shards(c, 5, 0.9, 0.4, d.glow)
	-- сезонные украшения
	local theme = d.p.theme
	if theme == "pumpkin" then
		ball(c, 0.5, Vector3.new(0, 0.45, 0), Color3.fromHex("#FF7A1A"), nil, "head", 1.2, 0.9, 1.1)
		block(c, Vector3.new(0.06, 0.15, 0.06), CFrame.new(0, 0.72, 0), Color3.fromHex("#4CAF50"), nil, "head")
	elseif theme == "ice" then
		for i = 1, 5 do
			wedge(c, Vector3.new(0.08, 0.3, 0.08), CFrame.new(-0.24 + i * 0.08, 0.72, 0), Color3.fromHex("#E0FBFF"), Enum.Material.Ice, "head")
		end
	elseif theme == "sand" then
		ball(c, 0.25, Vector3.new(0.45, 0.4, 0), Color3.fromHex("#FFF2DE"), nil, "prop", 1, 0.6, 1)
	elseif theme == "sakura" then
		for i = 1, 5 do
			local a = i / 5 * math.pi * 2
			ball(c, 0.12, Vector3.new(math.cos(a) * 0.18, 0.66, math.sin(a) * 0.18), Color3.fromHex("#FFC1E3"), Enum.Material.Neon, "prop")
		end
	elseif theme == "space" then
		ball(c, 0.25, Vector3.new(0.55, 0.65, 0), Color3.fromHex("#FFB347"), Enum.Material.Neon, "shard")
		ring(c, 0.22, 0.65, Color3.fromHex("#8C7BFF"), 0.6, 8)
	elseif theme == "coral" then
		for i = -1, 1 do
			block(c, Vector3.new(0.06, 0.32, 0.06), CFrame.new(i * 0.15, 0.72, 0) * CFrame.Angles(0, 0, i * 0.4), Color3.fromHex("#FF6F91"), nil, "head")
		end
	end
	face(c, Vector3.new(0, 0.43, -0.23), 0.46, d.emotion, if d.p.owl or theme then 2 else 3, d.glow)
end

SHAPES.eater = function(c)
	local d = c.def
	ball(c, 1.05, Vector3.new(0, 0, 0), d.color, nil, "body", 1, 0.95, 1)
	-- пасть
	ball(c, 0.62, Vector3.new(0, -0.15, -0.3), INK, nil, "mouth", 1, 0.55, 0.6)
	for i = -2, 2 do
		wedge(c, Vector3.new(0.08, 0.14, 0.06), CFrame.new(i * 0.1, 0.0, -0.55) * CFrame.Angles(math.pi, 0, 0), WHITE, nil, "mouth")
	end
	if d.p.tentacles then
		for i = 1, 6 do
			local a = i / 6 * math.pi * 2
			local p = block(c, Vector3.new(0.12, 0.6, 0.12), CFrame.new(math.cos(a) * 0.38, -0.6, math.sin(a) * 0.38) * CFrame.Angles(math.sin(a) * 0.5, 0, -math.cos(a) * 0.5), darker(d.color, 0.8), nil, "limb")
			p:SetAttribute("Phase", i)
		end
	else
		for s = -1, 1, 2 do
			wedge(c, Vector3.new(0.12, 0.4, 0.2), CFrame.new(s * 0.35, 0.5, 0) * CFrame.Angles(0, 0, s * -0.4), d.glow, Enum.Material.Neon, "head")
		end
	end
	ring(c, 0.8, 0, d.glow, 0.4, 14)
	shards(c, 5, 0.95, 0.2, d.glow)
	-- много глаз
	for i = 1, 5 do
		local a = (i - 3) * 0.32
		local ep = Vector3.new(math.sin(a) * 0.45, 0.25 + math.abs(i - 3) * -0.04, -math.cos(a) * 0.45)
		ball(c, 0.16, ep, WHITE, nil, "eye")
		ball(c, 0.09, ep * 1.08, d.glow, Enum.Material.Neon, "eye")
	end
end

SHAPES.colossus = function(c)
	local d = c.def
	if d.p.whale then
		ball(c, 1.0, Vector3.new(0, 0, 0.1), d.color, nil, "body", 0.9, 0.7, 1.4)
		ball(c, 0.7, Vector3.new(0, -0.12, 0.1), Color3.fromHex("#E8F4FF"), nil, "body", 0.9, 0.5, 1.3)
		for s = -1, 1, 2 do
			local w = block(c, Vector3.new(0.5, 0.06, 0.25), CFrame.new(s * 0.5, -0.1, -0.05) * CFrame.Angles(0, 0, s * 0.4), darker(d.color, 0.8), nil, "limb")
			w:SetAttribute("Wing", s)
		end
		wedge(c, Vector3.new(0.6, 0.08, 0.3), CFrame.new(0, 0.05, 0.85), darker(d.color, 0.8), nil, "limb"):SetAttribute("Phase", 1)
		ring(c, 0.8, 0.0, d.glow, 0.1, 14)
		face(c, Vector3.new(0, 0.05, -0.55), 0.55, d.emotion, 2, d.glow)
		return
	end
	ball(c, 0.9, Vector3.new(0, 0, 0), d.color, Enum.Material.Neon, "glow", 1, 1, 1)
	for i = 1, 8 do
		local a = i / 8 * math.pi * 2
		wedge(c, Vector3.new(0.14, 0.38, 0.14), CFrame.new(math.cos(a) * 0.55, math.sin(a) * 0.55, 0) * CFrame.Angles(0, 0, a - math.pi / 2), Color3.fromHex("#FFB347"), Enum.Material.Neon, "shard"):SetAttribute("Phase", a)
	end
	ring(c, 0.85, 0, Color3.fromHex("#FFFFFF"), 0.3, 14)
	ring(c, 0.95, 0, d.glow, -0.5, 14)
	face(c, Vector3.new(0, 0.02, -0.44), 0.55, d.emotion, 2, Color3.fromHex("#8B5A2B"))
end

-- Хроно-аномалии: части помечены Glitch=true — анимация смещает их и мерцает
local function glitchy(p: BasePart)
	p:SetAttribute("Glitch", true)
end

SHAPES.rift = function(c)
	local d = c.def
	for i = 1, 5 do
		local p = block(c, Vector3.new(0.18, 0.95 - math.abs(i - 3) * 0.18, 0.12), CFrame.new((i - 3) * 0.17, 0, 0) * CFrame.Angles(0, 0, (i - 3) * 0.12), if i == 3 then WHITE else d.color, Enum.Material.Neon, "body")
		glitchy(p)
	end
	for i = 1, 6 do
		local p = block(c, Vector3.new(0.14, 0.14, 0.14), CFrame.new(math.cos(i) * 0.55, math.sin(i * 1.7) * 0.4, math.sin(i) * 0.35) * CFrame.Angles(i, i, i), d.glow, Enum.Material.Neon, "shard")
		p:SetAttribute("Phase", i)
		glitchy(p)
	end
	if d.p.ring then
		ring(c, 0.7, 0, Color3.fromHex("#39FF14"), 0.6, 12)
	end
	ring(c, 0.75, 0, d.glow, -0.3, 12)
	face(c, Vector3.new(0, 0.12, -0.12), 0.45, d.emotion, 3, INK)
end

SHAPES.paradox = function(c)
	local d = c.def
	-- два полу-существа, сросшихся спинами, разных цветов
	local a = ball(c, 0.6, Vector3.new(-0.22, 0, 0), d.color, Enum.Material.Neon, "body", 1, 1.2, 1)
	local b = ball(c, 0.6, Vector3.new(0.22, 0, 0), d.glow, Enum.Material.Neon, "body", 1, 1.2, 1)
	glitchy(a)
	glitchy(b)
	if d.p.shield then
		part(c, CYL, Vector3.new(0.08, 1.1, 1.1), CFrame.new(0, 0, -0.45) * CFrame.Angles(0, math.pi / 2, 0), d.glow, Enum.Material.ForceField, "ring")
	end
	for s = -1, 1, 2 do
		local h = wedge(c, Vector3.new(0.1, 0.35, 0.15), CFrame.new(s * 0.3, 0.6, 0) * CFrame.Angles(0, 0, s * -0.3), WHITE, Enum.Material.Neon, "head")
		glitchy(h)
	end
	ring(c, 0.8, 0, WHITE, 0.4, 12)
	shards(c, 5, 0.9, 0, d.glow)
	face(c, Vector3.new(-0.22, 0.1, -0.3), 0.4, d.emotion, 1, INK)
	face(c, Vector3.new(0.22, 0.1, -0.3), 0.4, if d.emotion == "sly" then "angry" else "sly", 1, INK)
end

SHAPES.zero = function(c)
	local d = c.def
	-- кольцо-ноль из сегментов с пустотой внутри
	for i = 1, 14 do
		local a = i / 14 * math.pi * 2
		local p = block(c, Vector3.new(0.2, 0.2, 0.22), CFrame.new(math.cos(a) * 0.42, math.sin(a) * 0.5, 0) * CFrame.Angles(0, 0, a), if i % 2 == 0 then d.color else d.glow, Enum.Material.Neon, "body")
		glitchy(p)
	end
	ball(c, 0.45, Vector3.new(0, 0, 0), INK, nil, "body", 1, 1.2, 0.3)
	if d.p.loop then
		ring(c, 0.75, 0, Color3.fromHex("#FF2E63"), math.pi / 2, 12)
	end
	ring(c, 0.85, 0, d.glow, 0.5, 14)
	shards(c, 4, 0.95, 0, d.glow)
	face(c, Vector3.new(0, 0.02, -0.12), 0.35, d.emotion, 2, d.glow)
end

-- ── Публичное API ───────────────────────────────────────────
function M.size(id: string): number
	local d = Defs.BY_ID[id]
	return if d then Defs.RARITY[d.rarity].size else 2
end

-- Модель существа. noFx — без света и частиц (для интерфейса)
function M.model(id: string, scale: number?, noFx: boolean?): Model
	local d = Defs.BY_ID[id] or Defs.LIST[1]
	local k = Defs.RARITY[d.rarity].size * (scale or 1)
	local model = Instance.new("Model")
	model.Name = d.id
	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(0.2, 0.2, 0.2)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanQuery = false
	root.CanTouch = false
	root.CastShadow = false
	root.Parent = model
	model.PrimaryPart = root
	local c: Ctx = { model = model, root = root, k = k, def = d, cf = CFrame.new() }
	local builder = SHAPES[d.shape] or SHAPES.blob
	builder(c)
	model:SetAttribute("Rarity", d.rarity)
	model:SetAttribute("K", k)
	if not noFx then
		local r = Defs.RARITY[d.rarity].index
		local light = Instance.new("PointLight")
		light.Name = "Glow"
		light.Color = d.glow
		light.Range = 4 + r * 3 * (scale or 1)
		light.Brightness = 0.6 + r * 0.35
		light.Shadows = false
		light.Parent = root
		if r >= 3 then
			local pe = Instance.new("ParticleEmitter")
			pe.Name = "Sparkles"
			pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			pe.Color = ColorSequence.new(d.glow)
			pe.LightEmission = 1
			pe.Rate = if r == 3 then 5 else 9
			pe.Lifetime = NumberRange.new(0.8, 1.6)
			pe.Speed = NumberRange.new(0.5, 1.5)
			pe.SpreadAngle = Vector2.new(180, 180)
			pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25 * k / 3), NumberSequenceKeypoint.new(1, 0) })
			pe.Transparency = NumberSequence.new(0.2, 1)
			pe.Parent = root
		end
		if d.rarity == "legendary" then
			local pillar = Instance.new("Part")
			pillar.Shape = CYL
			pillar.Size = Vector3.new(30, k * 0.35, k * 0.35)
			pillar.CFrame = CFrame.new(0, 15 + k * 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2)
			pillar.Material = Enum.Material.Neon
			pillar.Color = d.glow
			pillar.Transparency = 0.75
			pillar.Anchored = true
			pillar.CanCollide = false
			pillar.CanQuery = false
			pillar.CanTouch = false
			pillar.CastShadow = false
			pillar:SetAttribute("Role", "pillar")
			pillar.Parent = model
		end
	end
	return model
end

return M
