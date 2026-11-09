--!strict
-- «Кирпичики» лоу-поли построек: блоки, клинья, пирамиды, деревья, камни, надписи.

local CollectionService = game:GetService("CollectionService")

local B = {}

local function finish<T>(p: T & BasePart, parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): T
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = size.Magnitude > 6
	p.Parent = parent
	return p
end

function B.part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): Part
	return finish(Instance.new("Part"), parent, size, cf, color, material)
end

-- Клин: вертикальная грань сзади (+Z), скат смотрит вперёд (−Z)
function B.wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?): WedgePart
	return finish(Instance.new("WedgePart"), parent, size, cf, color, material)
end

function B.cylinder(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder
	return finish(p, parent, Vector3.new(length, diameter, diameter), cf, color, material)
end

-- Вертикальный столб, стоящий основанием на точке
function B.post(parent: Instance, base: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material?): Part
	local cf = CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	return B.cylinder(parent, height, diameter, cf, color, material)
end

function B.ball(parent: Instance, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball
	return finish(p, parent, Vector3.new(diameter, diameter, diameter), cf, color, material)
end

-- Хребет-«палатка» из двух клиньев спина к спине. base — центр основания.
-- width — длина хребта (по X), depth — ширина основания (по Z).
function B.ridge(parent: Instance, base: Vector3, width: number, depth: number, height: number, color: Color3, yaw: number?, material: Enum.Material?)
	local rot = CFrame.new(base) * CFrame.Angles(0, yaw or 0, 0)
	local size = Vector3.new(width, height, depth / 2)
	-- скат клина смотрит в −Z, вертикальная грань в +Z: ставим вертикальными гранями друг к другу
	B.wedge(parent, size, rot * CFrame.new(0, height / 2, -depth / 4), color, material)
	B.wedge(parent, size, rot * CFrame.Angles(0, math.pi, 0) * CFrame.new(0, height / 2, -depth / 4), color:Lerp(Color3.new(0, 0, 0), 0.12), material)
end

-- Ель: ствол + ярусы повёрнутых блоков, сужающихся кверху
function B.pine(parent: Instance, base: Vector3, scale: number, rng: Random, tint: Color3?)
	local trunk = Color3.fromRGB(105, 75, 50)
	B.part(parent, Vector3.new(1.2, 4, 1.2) * scale, CFrame.new(base + Vector3.new(0, 2 * scale, 0)), trunk)
	local green = tint or Color3.fromRGB(55 + rng:NextInteger(-8, 8), 120 + rng:NextInteger(-12, 12), 70)
	local yaw = rng:NextNumber() * math.pi
	local y = 3 * scale
	for n = 0, 2 do
		local w = (7 - n * 2) * scale
		local h = 3.2 * scale
		local cf = CFrame.new(base + Vector3.new(0, y + h / 2, 0)) * CFrame.Angles(0, yaw + n * 0.785, 0)
		B.part(parent, Vector3.new(w, h, w), cf, green:Lerp(Color3.new(1, 1, 1), n * 0.05))
		y += h * 0.85
	end
end

-- Лиственное дерево: ствол + наклонённые кубы кроны
function B.leafy(parent: Instance, base: Vector3, scale: number, rng: Random, tint: Color3?)
	local h = 7 * scale
	B.part(parent, Vector3.new(1.2 * scale, h, 1.2 * scale), CFrame.new(base + Vector3.new(0, h / 2, 0)), Color3.fromRGB(110, 80, 55))
	local leaf = tint or Color3.fromRGB(80 + rng:NextInteger(-10, 10), 150 + rng:NextInteger(-15, 15), 70)
	local top = base + Vector3.new(0, h + 1.5 * scale, 0)
	local cf = CFrame.new(top) * CFrame.Angles(rng:NextNumber() * 0.6, rng:NextNumber() * 6, rng:NextNumber() * 0.6)
	B.part(parent, Vector3.new(6, 5, 6) * scale, cf, leaf)
	B.part(parent, Vector3.new(4, 4, 4) * scale, cf * CFrame.new(2 * scale, 1.5 * scale, -1 * scale) * CFrame.Angles(0.5, 0.3, 0.2), leaf:Lerp(Color3.new(1, 1, 0.6), 0.1))
end

function B.rock(parent: Instance, base: Vector3, size: number, rng: Random, color: Color3?)
	local c = color or Color3.fromRGB(125, 125, 120)
	local cf = CFrame.new(base + Vector3.new(0, size * 0.25, 0))
		* CFrame.Angles(rng:NextNumber() * 0.8, rng:NextNumber() * 6, rng:NextNumber() * 0.8)
	B.part(parent, Vector3.new(size, size * 0.7, size * 0.9), cf, c:Lerp(Color3.new(0, 0, 0), rng:NextNumber() * 0.15), Enum.Material.Slate)
end

-- Небольшая табличка над объектом: тёмная плашка, видна только вблизи и не сквозь стены
function B.label(adornee: BasePart, text: string, offset: number, color: Color3?, maxDistance: number?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 34)
	gui.StudsOffsetWorldSpace = Vector3.new(0, offset, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = maxDistance or 60
	gui.LightInfluence = 0
	gui.AutoLocalize = false
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = Color3.fromRGB(28, 32, 40)
	plate.BackgroundTransparency = 0.2
	plate.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = plate
	local t = Instance.new("TextLabel")
	t.Name = "Text"
	t.BackgroundTransparency = 1
	t.Position = UDim2.fromOffset(6, 3)
	t.Size = UDim2.new(1, -12, 1, -6)
	t.Font = Enum.Font.GothamBold
	t.TextScaled = true
	t.Text = text
	t.TextColor3 = color or Color3.fromRGB(255, 205, 90)
	t.Parent = plate
	gui.Parent = adornee
	return gui
end

-- Подсказка «нажми E». Действие и видимость определяются тегами и атрибутами.
function B.prompt(parent: Instance, tag: string, actionKey: string, hold: number?, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = actionKey -- клиент переводит по ключу
	p.ObjectText = ""
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = distance or 10
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Style = Enum.ProximityPromptStyle.Default
	p.AutoLocalize = false
	p:SetAttribute("Key", actionKey)
	p.Parent = parent
	CollectionService:AddTag(p, tag)
	return p
end

function B.model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

return B
