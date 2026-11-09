-- Простые «кирпичики» для построек из деталей.

local CollectionService = game:GetService("CollectionService")

local B = {}

local function finish(p: BasePart, parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?)
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for k, v in props do
			(p :: any)[k] = v
		end
	end
	p.Parent = parent
	return p
end

function B.part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	return finish(Instance.new("Part"), parent, size, cf, color, material, props) :: Part
end

-- Клин: вертикальная грань сзади (+Z), скат смотрит вперёд (−Z).
function B.wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): WedgePart
	return finish(Instance.new("WedgePart"), parent, size, cf, color, material, props) :: WedgePart
end

-- Цилиндр, ось вдоль X у cf.
function B.cylinder(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	return finish(p, parent, Vector3.new(length, diameter, diameter), cf, color, material, props) :: Part
end

-- Вертикальный цилиндр, стоящий основанием на точке base.
function B.post(parent: Instance, base: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local cf = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return B.cylinder(parent, height, diameter, cf, color, material, props)
end

-- Цилиндр между двумя точками (не строго вертикальный).
function B.between(parent: Instance, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b) * CFrame.Angles(0, math.pi / 2, 0)
	return B.cylinder(parent, (b - a).Magnitude, diameter, cf, color, material, props)
end

function B.ball(parent: Instance, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, props: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	return finish(p, parent, Vector3.new(diameter, diameter, diameter), cf, color, material, props) :: Part
end

function B.light(parent: Instance, color: Color3, range: number, brightness: number, flicker: number?, shadows: boolean?): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows or false
	l:SetAttribute("BaseBrightness", brightness)
	if flicker then
		l:SetAttribute("Flicker", flicker)
		CollectionService:AddTag(l, "Flicker")
	end
	l.Parent = parent
	return l
end

function B.surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3, font: Enum.Font?)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 1
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextScaled = true
	t.Font = font or Enum.Font.BuilderSansBold
	t.TextColor3 = color
	t.Parent = gui
	gui.Parent = part
end

-- Камень из нескольких повёрнутых блоков.
function B.rock(parent: Instance, base: Vector3, scale: number, rng: Random)
	local grays = {
		Color3.fromRGB(110, 108, 104),
		Color3.fromRGB(94, 92, 90),
		Color3.fromRGB(124, 118, 110),
	}
	for i = 1, 3 do
		local s = scale * rng:NextNumber(0.6, 1)
		local size = Vector3.new(s * rng:NextNumber(1, 1.6), s * rng:NextNumber(0.6, 1.1), s * rng:NextNumber(1, 1.5))
		local offset = Vector3.new(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.5, 0.5)) * scale
		local cf = CFrame.new(base + offset + Vector3.new(0, size.Y * 0.25, 0))
			* CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.5, 0.5))
		B.part(parent, size, cf, grays[i], i == 2 and Enum.Material.Slate or Enum.Material.Rock)
	end
end

-- Ель: ствол и ярусы из пар скрещённых «палаток».
function B.pine(parent: Instance, base: Vector3, height: number, rng: Random, props: { [string]: any }?)
	local m = Instance.new("Model")
	m.Name = "Ель"
	local trunkColor = Color3.fromRGB(92, 62, 40)
	B.post(m, base - Vector3.new(0, 1, 0), height * 0.4, height * 0.07, trunkColor, Enum.Material.Wood, props)
	local tiers = height > 26 and 3 or 2
	local g = rng:NextNumber(0.85, 1.1)
	local green = Color3.fromRGB(46 * g, 82 * g, 46 * g)
	local width = height * 0.5
	local yaw = rng:NextNumber(0, math.pi)
	for i = 1, tiers do
		local w = width * (1 - (i - 1) * 0.28)
		local th = height * (tiers == 3 and 0.4 or 0.5)
		local y = height * 0.16 + (i - 1) * height * (tiers == 3 and 0.24 or 0.3)
		local shade = Color3.new(green.R * (1 + i * 0.06), green.G * (1 + i * 0.06), green.B * (1 + i * 0.05))
		local center = CFrame.new(base + Vector3.new(0, y + th / 2, 0)) * CFrame.Angles(0, yaw + i * 0.7, 0)
		for a = 0, 1 do
			local rot = center * CFrame.Angles(0, a * math.pi / 2, 0)
			local size = Vector3.new(w * 0.42, th, w / 2)
			B.wedge(m, size, rot * CFrame.new(0, 0, -w / 4), shade, Enum.Material.LeafyGrass, props)
			B.wedge(m, size, rot * CFrame.new(0, 0, w / 4) * CFrame.Angles(0, math.pi, 0), shade, Enum.Material.LeafyGrass, props)
		end
	end
	m.Parent = parent
	return m
end

local AUTUMN = {
	Color3.fromRGB(214, 122, 46),
	Color3.fromRGB(228, 178, 62),
	Color3.fromRGB(176, 64, 42),
	Color3.fromRGB(116, 142, 60),
	Color3.fromRGB(196, 150, 56),
}

-- Лиственное дерево (берёза или клён) с осенней кроной.
function B.leafy(parent: Instance, base: Vector3, height: number, rng: Random, props: { [string]: any }?)
	local m = Instance.new("Model")
	m.Name = "Дерево"
	local birch = rng:NextNumber() < 0.5
	local trunkColor = birch and Color3.fromRGB(226, 222, 212) or Color3.fromRGB(96, 70, 50)
	B.post(m, base - Vector3.new(0, 1, 0), height * 0.62, height * 0.06, trunkColor, Enum.Material.Wood, props)
	local color = AUTUMN[rng:NextInteger(1, #AUTUMN)]
	local crown = height * 0.42
	local top = base + Vector3.new(0, height * 0.66, 0)
	local count = rng:NextInteger(2, 3)
	for i = 1, count do
		local d = crown * rng:NextNumber(0.7, 1)
		local off = Vector3.new(rng:NextNumber(-0.25, 0.25) * crown, (i - 1) * crown * 0.28, rng:NextNumber(-0.25, 0.25) * crown)
		local c = color:Lerp(Color3.new(1, 0.9, 0.6), rng:NextNumber(0, 0.15))
		B.ball(m, d, CFrame.new(top + off), c, Enum.Material.LeafyGrass, props)
	end
	m.Parent = parent
	return m
end

function B.lantern(parent: Instance, base: Vector3)
	local m = Instance.new("Model")
	m.Name = "Фонарь"
	local metal = Color3.fromRGB(36, 34, 32)
	B.part(m, Vector3.new(1.2, 0.5, 1.2), CFrame.new(base + Vector3.new(0, 0.25, 0)), metal, Enum.Material.Metal)
	B.post(m, base, 7, 0.32, metal, Enum.Material.Metal)
	B.part(m, Vector3.new(1.3, 0.25, 1.3), CFrame.new(base + Vector3.new(0, 7.1, 0)), metal, Enum.Material.Metal)
	B.part(m, Vector3.new(1.1, 1.3, 1.1), CFrame.new(base + Vector3.new(0, 7.9, 0)), Color3.fromRGB(255, 236, 200), Enum.Material.Glass, { Transparency = 0.5 })
	local glow = B.ball(m, 0.7, CFrame.new(base + Vector3.new(0, 7.9, 0)), Color3.fromRGB(255, 196, 120), Enum.Material.Neon)
	B.wedge(m, Vector3.new(1.5, 0.6, 0.75), CFrame.new(base + Vector3.new(0, 8.85, -0.375)), metal, Enum.Material.Metal)
	B.wedge(m, Vector3.new(1.5, 0.6, 0.75), CFrame.new(base + Vector3.new(0, 8.85, 0.375)) * CFrame.Angles(0, math.pi, 0), metal, Enum.Material.Metal)
	B.light(glow, Color3.fromRGB(255, 190, 120), 18, 1.3, 0.08)
	m.Parent = parent
	return m
end

return B
