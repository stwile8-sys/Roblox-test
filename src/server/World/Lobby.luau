-- Постройки на вершине: домик, костёр, смотровая площадка с телескопом,
-- портал, указатель, фонари, камни, цветы.

local CollectionService = game:GetService("CollectionService")

local B = require(script.Parent.Builders)
local T = require(script.Parent.Terrain)

local Lobby = {}

local M = Enum.Material
local LOG_A = Color3.fromRGB(122, 84, 54)
local LOG_B = Color3.fromRGB(108, 74, 47)
local DARK_WOOD = Color3.fromRGB(70, 46, 30)
local PLANK = Color3.fromRGB(150, 108, 70)
local STONE = Color3.fromRGB(120, 116, 110)
local WARM = Color3.fromRGB(255, 186, 110)

local function zone(model: Instance, name: string, radius: number)
	model:SetAttribute("ZoneName", name)
	model:SetAttribute("ZoneRadius", radius)
	CollectionService:AddTag(model, "Zone")
end

local function model(parent: Instance, name: string, pivot: CFrame): Model
	local m = Instance.new("Model")
	m.Name = name
	m.WorldPivot = pivot
	m.Parent = parent
	return m
end

-- ── домик ────────────────────────────────────────────────────

local function window(m: Model, cf: CFrame)
	B.part(m, Vector3.new(4.8, 4.2, 0.5), cf, DARK_WOOD, M.Wood)
	local glow = B.part(m, Vector3.new(4, 3.4, 0.3), cf * CFrame.new(0, 0, -0.2), WARM, M.Neon)
	B.part(m, Vector3.new(0.25, 3.4, 0.4), cf * CFrame.new(0, 0, -0.3), DARK_WOOD, M.Wood)
	B.part(m, Vector3.new(4, 0.25, 0.4), cf * CFrame.new(0, 0, -0.3), DARK_WOOD, M.Wood)
	B.part(m, Vector3.new(5.4, 0.4, 1), cf * CFrame.new(0, -2.2, -0.4), DARK_WOOD, M.Wood)
	B.light(glow, WARM, 12, 0.9)
end

function Lobby.cabin(parent: Instance, o: CFrame)
	local m = model(parent, "Домик", o)
	local W, D, logD, rows = 26, 18, 1.6, 8
	local step = logD * 0.92
	local base = 1.5

	B.part(m, Vector3.new(W + 3, 2.5, D + 3), o * CFrame.new(0, 0.25, 0), STONE, M.Cobblestone)
	B.part(m, Vector3.new(W - 1, rows * step, D - 1), o * CFrame.new(0, base + rows * step / 2, 0), DARK_WOOD, M.Wood)

	for i = 0, rows - 1 do
		local y = base + logD / 2 + i * step
		local c = i % 2 == 0 and LOG_A or LOG_B
		for _, s in { -1, 1 } do
			B.cylinder(m, W + 2.6, logD, o * CFrame.new(0, y, s * D / 2), c, M.Wood)
			B.cylinder(m, D + 2.6, logD, o * CFrame.new(s * W / 2, y, 0) * CFrame.Angles(0, math.pi / 2, 0), c, M.Wood)
		end
	end
	local top = base + rows * step + 0.3

	-- крыша
	local roofH, rw, rd = 7.5, W + 5, D / 2 + 3
	local roofColor = Color3.fromRGB(84, 58, 44)
	B.wedge(m, Vector3.new(rw, roofH, rd), o * CFrame.new(0, top + roofH / 2, -rd / 2), roofColor, M.WoodPlanks)
	B.wedge(m, Vector3.new(rw, roofH, rd), o * CFrame.new(0, top + roofH / 2, rd / 2) * CFrame.Angles(0, math.pi, 0), roofColor, M.WoodPlanks)
	B.cylinder(m, rw + 0.6, 1.1, o * CFrame.new(0, top + roofH, 0), DARK_WOOD, M.Wood)
	-- торцевые доски по скатам
	local slopeLen = math.sqrt(roofH ^ 2 + rd ^ 2)
	local ang = math.atan2(roofH, rd)
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local cf = o * CFrame.new(sx * (rw / 2 + 0.15), top + roofH / 2, sz * rd / 2) * CFrame.Angles(sz * ang, 0, 0)
			B.part(m, Vector3.new(0.4, 0.8, slopeLen + 0.4), cf, DARK_WOOD, M.Wood)
		end
	end

	-- труба с дымом
	local chimney = B.part(m, Vector3.new(3.6, roofH + 9, 3.6), o * CFrame.new(W / 2 - 5, top + (roofH + 9) / 2 - 1.5, 3.5), STONE, M.Cobblestone)
	B.part(m, Vector3.new(4.4, 0.8, 4.4), chimney.CFrame * CFrame.new(0, chimney.Size.Y / 2, 0), Color3.fromRGB(90, 88, 84), M.Slate)
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(200, 196, 190)
	smoke.Opacity = 0.12
	smoke.RiseVelocity = 5
	smoke.Size = 4
	smoke.Parent = chimney

	-- фасад: окна и дверь
	local front = -(D / 2 + logD / 2 + 0.2)
	window(m, o * CFrame.new(-7.5, base + 6, front))
	window(m, o * CFrame.new(7.5, base + 6, front))
	window(m, o * CFrame.new(W / 2 + logD / 2 + 0.2, base + 6, 0) * CFrame.Angles(0, -math.pi / 2, 0))
	window(m, o * CFrame.new(-(W / 2 + logD / 2 + 0.2), base + 6, 0) * CFrame.Angles(0, math.pi / 2, 0))
	B.part(m, Vector3.new(5, 8.6, 0.5), o * CFrame.new(0, base + 4.3, front), DARK_WOOD, M.Wood)
	B.part(m, Vector3.new(4, 7.8, 0.4), o * CFrame.new(0, base + 3.9, front - 0.2), Color3.fromRGB(96, 62, 38), M.WoodPlanks)
	B.ball(m, 0.45, o * CFrame.new(1.4, base + 3.8, front - 0.5), Color3.fromRGB(212, 170, 80), M.Metal)
	local lamp = B.ball(m, 0.8, o * CFrame.new(3.6, base + 7.4, front - 0.6), WARM, M.Neon)
	B.light(lamp, WARM, 16, 1.2, 0.1)

	-- веранда
	local porchZ = -(D / 2 + 3.8)
	B.part(m, Vector3.new(W + 2, 0.6, 6.4), o * CFrame.new(0, base - 0.3, porchZ), PLANK, M.WoodPlanks)
	B.part(m, Vector3.new(8, 0.75, 1.6), o * CFrame.new(0, 0.75, porchZ - 3.9), PLANK, M.WoodPlanks)
	B.part(m, Vector3.new(8, 0.75, 1.6), o * CFrame.new(0, 0.05, porchZ - 5.3), PLANK, M.WoodPlanks)
	for _, x in { -(W / 2), -4.5, 4.5, W / 2 } do
		B.post(m, (o * CFrame.new(x, base, porchZ - 2.8)).Position, 7.4, 0.8, LOG_A, M.Wood)
	end
	B.part(m, Vector3.new(W + 3, 0.5, 7.6), o * CFrame.new(0, base + 8.3, porchZ + 0.3) * CFrame.Angles(math.rad(-12), 0, 0), roofColor, M.WoodPlanks)

	-- скамейка на веранде
	local seat = Instance.new("Seat")
	B.part(m, Vector3.new(5, 0.4, 1.6), o * CFrame.new(-8, base + 1.6, porchZ + 1.6), PLANK, M.Wood)
	for _, lx in { -10, -6 } do
		B.part(m, Vector3.new(0.4, 1.4, 1.4), o * CFrame.new(lx, base + 0.7, porchZ + 1.6), DARK_WOOD, M.Wood)
	end
	seat.Anchored = true
	seat.Size = Vector3.new(4, 0.3, 1.4)
	seat.CFrame = o * CFrame.new(-8, base + 1.85, porchZ + 1.6)
	seat.Transparency = 1
	seat.Parent = m
	B.part(m, Vector3.new(5, 1.6, 0.3), o * CFrame.new(-8, base + 2.6, porchZ + 2.5), PLANK, M.Wood)

	-- поленница и пень с топором
	for row = 0, 2 do
		for i = 0, 3 - row do
			local x = W / 2 + 4.2
			local z = -2 + i * 1.05 + row * 0.52
			B.cylinder(m, 4, 1, o * CFrame.new(x, 0.5 + row * 0.88, z), i % 2 == 0 and LOG_A or LOG_B, M.Wood)
		end
	end
	local stump = (o * CFrame.new(W / 2 + 4, 0, -12)).Position
	B.post(m, stump, 1.6, 2.4, LOG_B, M.Wood)
	local axe = CFrame.new(stump + Vector3.new(0, 2.6, 0)) * CFrame.Angles(0, 0.6, math.rad(20))
	B.part(m, Vector3.new(0.3, 2.8, 0.3), axe, Color3.fromRGB(140, 100, 60), M.Wood)
	B.part(m, Vector3.new(0.25, 0.8, 1.2), axe * CFrame.new(0, -1.1, 0.5), Color3.fromRGB(150, 150, 155), M.Metal)

	zone(m, "Охотничий домик", 22)
	return m
end

-- ── костёр ───────────────────────────────────────────────────

function Lobby.campfire(parent: Instance, o: CFrame, rng: Random)
	local m = model(parent, "Костёр", o)
	local center = o.Position

	for i = 1, 11 do
		local a = i / 11 * math.pi * 2
		local cf = o * CFrame.new(math.cos(a) * 3, 0.35, math.sin(a) * 3) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, rng:NextNumber(-0.3, 0.3))
		B.part(m, Vector3.new(rng:NextNumber(1.2, 1.7), rng:NextNumber(0.8, 1.1), rng:NextNumber(1, 1.4)), cf, Color3.fromRGB(96, 94, 92), M.Slate)
	end
	B.part(m, Vector3.new(4.4, 0.2, 4.4), o * CFrame.new(0, 0.1, 0), Color3.fromRGB(40, 32, 28), M.Ground)
	for i = 1, 5 do
		local a = i / 5 * math.pi * 2
		local foot = center + Vector3.new(math.cos(a) * 1.5, 0.2, math.sin(a) * 1.5)
		B.between(m, foot, center + Vector3.new(0, 2.6, 0), 0.6, Color3.fromRGB(70, 48, 32), M.Wood)
	end
	local embers = B.part(m, Vector3.new(0.5, 2.6, 2.6), CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 110, 30), M.Neon, { Shape = Enum.PartType.Cylinder })
	embers.Size = Vector3.new(0.5, 2.6, 2.6)

	local core = B.part(m, Vector3.new(1, 1, 1), CFrame.new(center + Vector3.new(0, 1.2, 0)), Color3.new(1, 1, 1), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
	})
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 10
	fire.Color = Color3.fromRGB(255, 140, 40)
	fire.SecondaryColor = Color3.fromRGB(255, 60, 20)
	fire.Parent = core
	B.light(core, Color3.fromRGB(255, 150, 70), 28, 2.6, 0.35, true)

	local sparks = Instance.new("ParticleEmitter")
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 90, 30))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.18, 0)
	sparks.Lifetime = NumberRange.new(1, 2.2)
	sparks.Speed = NumberRange.new(3, 7)
	sparks.SpreadAngle = Vector2.new(25, 25)
	sparks.Acceleration = Vector3.new(0, 2, 0)
	sparks.Drag = 1
	sparks.Rate = 14
	sparks.Parent = core

	-- брёвна-скамейки
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2 + 0.4
		local pos = center + Vector3.new(math.cos(a) * 7, 0.8, math.sin(a) * 7)
		local look = CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
		B.cylinder(m, 6.5, 1.6, look, LOG_A, M.Wood)
		for _, off in { -1.5, 1.5 } do
			local seat = Instance.new("Seat")
			seat.Anchored = true
			seat.Size = Vector3.new(2, 0.3, 1.4)
			seat.CFrame = look * CFrame.new(off, 0.85, 0)
			seat.Transparency = 1
			seat.Parent = m
		end
	end

	zone(m, "Костёр", 12)
	return m
end

-- ── смотровая площадка ───────────────────────────────────────

function Lobby.deck(parent: Instance, o: CFrame)
	local m = model(parent, "Смотровая", o)
	local W, L, y = 18, 16, 0.6
	local z0, z1 = 2, -(L - 2) -- от края плато наружу

	for i = 0, W - 1 do
		local c = PLANK:Lerp(DARK_WOOD, (i % 3) * 0.12)
		B.part(m, Vector3.new(0.94, 0.5, L), o * CFrame.new(-W / 2 + 0.5 + i, y, (z0 + z1) / 2), c, M.WoodPlanks)
	end
	for _, z in { z0 - 0.5, (z0 + z1) / 2, z1 + 0.5 } do
		B.part(m, Vector3.new(W + 0.6, 0.9, 0.9), o * CFrame.new(0, y - 0.7, z), DARK_WOOD, M.Wood)
	end

	-- опоры до склона
	for _, x in { -W / 2 + 0.6, 0, W / 2 - 0.6 } do
		for _, z in { (z0 + z1) / 2, z1 + 0.5 } do
			local top = (o * CFrame.new(x, y - 1, z)).Position
			local ground = T.heightAt(top.X, top.Z)
			local h = top.Y - ground + 3
			if h > 1 then
				B.post(m, Vector3.new(top.X, ground - 3, top.Z), h, 0.9, DARK_WOOD, M.Wood)
			end
		end
	end
	for _, x in { -W / 2 + 0.6, W / 2 - 0.6 } do
		local a = (o * CFrame.new(x, y - 1, 0)).Position
		local b = (o * CFrame.new(x, y - 9, z1 + 0.5)).Position
		B.between(m, a, b, 0.6, DARK_WOOD, M.Wood)
	end

	-- перила
	local rail = Color3.fromRGB(96, 66, 42)
	local function railLine(p0: Vector3, p1: Vector3)
		local len = (p1 - p0).Magnitude
		local n = math.max(1, math.floor(len / 3))
		for i = 0, n do
			local p = p0:Lerp(p1, i / n)
			B.part(m, Vector3.new(0.45, 3.4, 0.45), o * CFrame.new(p + Vector3.new(0, y + 1.9, 0)), rail, M.Wood)
		end
		local mid = (p0 + p1) / 2
		local dir = (p1 - p0).Unit
		local rot = CFrame.lookAt(Vector3.zero, dir)
		B.part(m, Vector3.new(0.6, 0.35, len + 0.4), o * CFrame.new(mid + Vector3.new(0, y + 3.6, 0)) * rot, rail, M.Wood)
		B.part(m, Vector3.new(0.25, 0.25, len), o * CFrame.new(mid + Vector3.new(0, y + 2, 0)) * rot, rail, M.Wood)
	end
	railLine(Vector3.new(-W / 2 + 0.3, 0, z0 - 1), Vector3.new(-W / 2 + 0.3, 0, z1 + 0.3))
	railLine(Vector3.new(W / 2 - 0.3, 0, z0 - 1), Vector3.new(W / 2 - 0.3, 0, z1 + 0.3))
	railLine(Vector3.new(-W / 2 + 0.3, 0, z1 + 0.3), Vector3.new(W / 2 - 0.3, 0, z1 + 0.3))

	-- скамейки, смотрят на вид
	for _, x in { -5, 5 } do
		local cf = o * CFrame.new(x, y, -3)
		B.part(m, Vector3.new(5, 0.4, 1.6), cf * CFrame.new(0, 1.6, 0), PLANK, M.Wood)
		B.part(m, Vector3.new(5, 1.6, 0.3), cf * CFrame.new(0, 2.6, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), PLANK, M.Wood)
		for _, lx in { -2, 2 } do
			B.part(m, Vector3.new(0.4, 1.4, 1.4), cf * CFrame.new(lx, 0.8, 0), DARK_WOOD, M.Wood)
		end
		local seat = Instance.new("Seat")
		seat.Anchored = true
		seat.Size = Vector3.new(4, 0.3, 1.4)
		seat.CFrame = cf * CFrame.new(0, 1.85, 0)
		seat.Transparency = 1
		seat.Parent = m
	end

	-- телескоп
	local tpos = o * CFrame.new(0, y, z1 + 3.5)
	local head = (tpos * CFrame.new(0, 3.6, 0)).Position
	for i = 0, 2 do
		local a = i / 3 * math.pi * 2
		local foot = (tpos * CFrame.new(math.cos(a) * 1.2, 0.2, math.sin(a) * 1.2)).Position
		B.between(m, foot, head, 0.18, Color3.fromRGB(40, 38, 36), M.Metal)
	end
	local tubeCF = CFrame.lookAt(head + Vector3.new(0, 0.3, 0), head + Vector3.new(0, 0.3, 0) + (o.LookVector + Vector3.new(0, -0.1, 0)).Unit)
	local brass = Color3.fromRGB(196, 150, 72)
	local tube = B.cylinder(m, 3.6, 0.65, tubeCF * CFrame.Angles(0, math.pi / 2, 0), brass, M.Metal)
	tube.Name = "Telescope"
	B.cylinder(m, 0.5, 0.9, tubeCF * CFrame.new(0, 0, -1.8) * CFrame.Angles(0, math.pi / 2, 0), brass, M.Metal)
	B.cylinder(m, 0.6, 0.35, tubeCF * CFrame.new(0, 0, 2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(30, 30, 30), M.Metal)
	tube:SetAttribute("EyeCFrame", tubeCF * CFrame.new(0, 0, 2.6))
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TelescopePrompt"
	prompt.ActionText = "Смотреть"
	prompt.ObjectText = "Телескоп"
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = tube

	B.lantern(m, (o * CFrame.new(-W / 2 + 0.3, y, z0 - 1)).Position + Vector3.new(0, 0.3, 0))
	B.lantern(m, (o * CFrame.new(W / 2 - 0.3, y, z0 - 1)).Position + Vector3.new(0, 0.3, 0))

	zone(m, "Смотровая площадка", 15)
	return m
end

-- ── портал «Скоро» ───────────────────────────────────────────

function Lobby.portal(parent: Instance, o: CFrame)
	local m = model(parent, "Портал", o)
	local stone = Color3.fromRGB(132, 128, 120)
	local R, pillarH = 6, 9
	B.part(m, Vector3.new(17, 1, 5), o * CFrame.new(0, 0.3, 0), Color3.fromRGB(100, 98, 94), M.Slate)
	for _, x in { -R, R } do
		B.part(m, Vector3.new(2.2, pillarH, 2.4), o * CFrame.new(x, pillarH / 2 + 0.5, 0), stone, M.Cobblestone)
	end
	for i = 0, 8 do
		local a = math.pi * i / 8
		local cf = o * CFrame.new(math.cos(a) * R, pillarH + 0.5 + math.sin(a) * R, 0) * CFrame.Angles(0, 0, a)
		B.part(m, Vector3.new(2, 2.6, 2.4), cf, stone, M.Cobblestone)
	end
	local purple = Color3.fromRGB(150, 96, 255)
	local plane = B.part(m, Vector3.new(R * 2 - 2, pillarH, 0.2), o * CFrame.new(0, pillarH / 2 + 0.5, 0), purple, M.Neon, { Transparency = 0.35, CanCollide = false })
	B.cylinder(m, 0.2, R * 2 - 2, o * CFrame.new(0, pillarH + 0.5, 0) * CFrame.Angles(0, math.pi / 2, 0), purple, M.Neon, { Transparency = 0.35, CanCollide = false })
	B.light(plane, purple, 18, 1.6, 0.15)
	local swirl = Instance.new("ParticleEmitter")
	swirl.Color = ColorSequence.new(Color3.fromRGB(210, 170, 255), Color3.fromRGB(120, 80, 255))
	swirl.LightEmission = 1
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.35), NumberSequenceKeypoint.new(1, 0) })
	swirl.Lifetime = NumberRange.new(1.5, 3)
	swirl.Speed = NumberRange.new(0.5, 1.5)
	swirl.RotSpeed = NumberRange.new(-90, 90)
	swirl.SpreadAngle = Vector2.new(180, 180)
	swirl.Rate = 25
	swirl.Parent = plane
	local tablet = B.part(m, Vector3.new(8, 2, 0.6), o * CFrame.new(0, pillarH + R + 2.3, 0), Color3.fromRGB(70, 66, 62), M.Slate)
	B.surfaceText(tablet, Enum.NormalId.Front, "СКОРО", Color3.fromRGB(230, 210, 255))
	B.surfaceText(tablet, Enum.NormalId.Back, "СКОРО", Color3.fromRGB(230, 210, 255))
	zone(m, "Портал · скоро откроется", 12)
	return m
end

-- ── указатель ────────────────────────────────────────────────

function Lobby.signpost(parent: Instance, base: Vector3, targets: { { name: string, pos: Vector3 } })
	local m = model(parent, "Указатель", CFrame.new(base))
	B.post(m, base, 7.5, 0.6, DARK_WOOD, M.Wood)
	for i, t in targets do
		local flat = Vector3.new(t.pos.X, 0, t.pos.Z) - Vector3.new(base.X, 0, base.Z)
		local dir = flat.Unit
		local center = base + Vector3.new(0, 7.3 - i * 1.3, 0) + dir * 2
		local cf = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.pi / 2, 0)
		local board = B.part(m, Vector3.new(4.2, 1, 0.25), cf, PLANK, M.WoodPlanks)
		-- со стороны Front ось +X уходит влево
		B.surfaceText(board, Enum.NormalId.Front, "‹ " .. t.name, Color3.fromRGB(56, 34, 18))
		B.surfaceText(board, Enum.NormalId.Back, t.name .. " ›", Color3.fromRGB(56, 34, 18))
	end
end

-- ── сборка всего лобби ───────────────────────────────────────

function Lobby.build(parent: Instance, L: CFrame, rng: Random): CFrame
	local folder = Instance.new("Folder")
	folder.Name = "Лобби"
	folder.Parent = parent

	local function at(x: number, z: number, yaw: number?): CFrame
		return L * CFrame.new(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	end

	-- точка появления: каменный круг
	local spawnCF = at(16, 4)
	B.cylinder(folder, 0.5, 11, spawnCF * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 146, 138), M.Slate)
	B.cylinder(folder, 0.55, 7, spawnCF * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 116, 108), M.Cobblestone)
	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Size = Vector3.new(6, 0.4, 6)
	spawn.CFrame = spawnCF * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, math.pi, 0)
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Parent = folder

	Lobby.cabin(folder, at(0, 30))
	local fireCF = at(-20, -4)
	Lobby.campfire(folder, fireCF, rng)
	local deckCF = at(0, -57)
	Lobby.deck(folder, deckCF)
	local portalCF = CFrame.lookAt(at(44, -20).Position, L.Position)
	Lobby.portal(folder, portalCF)

	Lobby.signpost(folder, at(9, -6).Position, {
		{ name = "Смотровая", pos = deckCF.Position },
		{ name = "Домик", pos = at(0, 20).Position },
		{ name = "Портал", pos = portalCF.Position },
	})

	-- тропинки из плоских камней
	local function path(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local n = math.floor(len / 3.2)
		for i = 1, n - 1 do
			local p = a:Lerp(b, i / n) + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
			local d = rng:NextNumber(2.2, 3)
			B.cylinder(folder, 0.3, d, CFrame.new(p + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.pi / 2), Color3.fromRGB(140, 136, 128):Lerp(Color3.fromRGB(110, 106, 100), rng:NextNumber()), M.Slate)
		end
	end
	path(spawnCF.Position, at(0, -52).Position)
	path(spawnCF.Position, at(0, 12).Position)
	path(spawnCF.Position, fireCF.Position + L.RightVector * 8)
	path(at(0, -20).Position, portalCF.Position - portalCF.LookVector * -3)

	for _, p in { { 8, -24 }, { -6, -40 }, { 24, 16 }, { -10, 10 }, { 30, -14 } } do
		B.lantern(folder, at(p[1], p[2]).Position)
	end

	for _, p in { { 48, 10 }, { 36, 44 }, { -50, 10 }, { -40, 40 }, { -14, 52 }, { 20, 52 }, { -52, -14 } } do
		B.pine(folder, at(p[1], p[2]).Position, rng:NextNumber(26, 34), rng)
	end
	for _, p in { { 50, -30 }, { -30, -50 }, { 28, -48 }, { -56, -4 }, { 54, 24 }, { -24, 54 } } do
		B.rock(folder, at(p[1], p[2]).Position, rng:NextNumber(3, 6), rng)
	end

	-- цветы
	local petals = { Color3.fromRGB(250, 250, 245), Color3.fromRGB(250, 214, 80), Color3.fromRGB(190, 120, 230), Color3.fromRGB(240, 120, 140) }
	for _, c in { { -16, 18 }, { 18, 18 }, { 26, 0 }, { -30, -16 } } do
		for _ = 1, 10 do
			local p = at(c[1] + rng:NextNumber(-4, 4), c[2] + rng:NextNumber(-3, 3)).Position
			B.ball(folder, rng:NextNumber(0.4, 0.7), CFrame.new(p + Vector3.new(0, 0.35, 0)), petals[rng:NextInteger(1, #petals)], M.SmoothPlastic, { CanCollide = false })
		end
	end

	-- светлячки над плато (видны ночью)
	local fliesPart = B.part(folder, Vector3.new(110, 6, 110), L * CFrame.new(0, 4, 0), Color3.new(1, 1, 1), M.SmoothPlastic, {
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		CanTouch = false,
	})
	local flies = Instance.new("ParticleEmitter")
	flies.Name = "Fireflies"
	flies.Color = ColorSequence.new(Color3.fromRGB(220, 255, 140))
	flies.LightEmission = 1
	flies.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.22), NumberSequenceKeypoint.new(1, 0) })
	flies.Lifetime = NumberRange.new(4, 7)
	flies.Speed = NumberRange.new(0.3, 1)
	flies.SpreadAngle = Vector2.new(180, 180)
	flies.Rate = 0
	flies.Parent = fliesPart
	CollectionService:AddTag(flies, "Fireflies")

	return deckCF
end

return Lobby
