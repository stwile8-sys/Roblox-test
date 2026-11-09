-- Стартовая площадка, арка «Старт · Финиш», столбики вдоль трассы,
-- знаки трамплинов, табло и порталы лобби ↔ площадка.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local World = ServerScriptService:WaitForChild("Server"):WaitForChild("World")
local B = require(World:WaitForChild("Builders"))

local StartArea = {}

local M = Enum.Material
local BLACK = Color3.fromRGB(24, 24, 26)
local WHITE = Color3.fromRGB(240, 240, 236)
local RED = Color3.fromRGB(210, 34, 34)
local ORANGE = Color3.fromRGB(255, 120, 20)

local function banner(part: BasePart, text: string, color: Color3)
	B.surfaceText(part, Enum.NormalId.Front, text, color, Enum.Font.BuilderSansExtraBold)
	B.surfaceText(part, Enum.NormalId.Back, text, color, Enum.Font.BuilderSansExtraBold)
end

local function portalArch(parent: Instance, cf: CFrame, label: string): BasePart
	local stone = Color3.fromRGB(70, 70, 76)
	local R, h = 5, 8
	for _, x in { -R, R } do
		B.part(parent, Vector3.new(1.8, h, 2), cf * CFrame.new(x, h / 2, 0), stone, M.Metal)
	end
	for i = 0, 8 do
		local a = math.pi * i / 8
		B.part(parent, Vector3.new(1.6, 2.2, 2), cf * CFrame.new(math.cos(a) * R, h + math.sin(a) * R, 0) * CFrame.Angles(0, 0, a), stone, M.Metal)
	end
	local purple = Color3.fromRGB(150, 96, 255)
	local plane = B.part(parent, Vector3.new(R * 2 - 1.8, h, 0.3), cf * CFrame.new(0, h / 2, 0), purple, M.Neon, { Transparency = 0.35, CanCollide = false })
	B.cylinder(parent, 0.3, R * 2 - 1.8, cf * CFrame.new(0, h, 0) * CFrame.Angles(0, math.pi / 2, 0), purple, M.Neon, { Transparency = 0.35, CanCollide = false })
	B.light(plane, purple, 16, 1.4, 0.15)
	local tablet = B.part(parent, Vector3.new(9, 1.8, 0.5), cf * CFrame.new(0, h + R + 1.8, 0), BLACK, M.SmoothPlastic)
	banner(tablet, label, Color3.fromRGB(230, 210, 255))
	return plane
end

local function tireStack(parent: Instance, base: Vector3)
	for i = 0, 2 do
		B.cylinder(parent, 1, 2.6, CFrame.new(base + Vector3.new(0, 0.5 + i, 0)) * CFrame.Angles(0, 0, math.pi / 2), BLACK, M.Fabric)
	end
end

local function cone(parent: Instance, base: Vector3)
	B.cylinder(parent, 0.2, 1.4, CFrame.new(base + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), ORANGE, M.SmoothPlastic)
	B.cylinder(parent, 1.4, 0.8, CFrame.new(base + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, 0, math.pi / 2), ORANGE, M.SmoothPlastic)
	B.cylinder(parent, 0.3, 0.85, CFrame.new(base + Vector3.new(0, 1.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), WHITE, M.SmoothPlastic)
end

local function flag(parent: Instance, base: Vector3, color: Color3, facing: Vector3)
	B.post(parent, base, 9, 0.25, Color3.fromRGB(200, 200, 205), M.Metal)
	local cf = CFrame.lookAt(base + Vector3.new(0, 7.6, 0), base + Vector3.new(0, 7.6, 0) + facing) * CFrame.new(1.5, 0, 0)
	B.part(parent, Vector3.new(3, 2, 0.1), cf, color, M.Fabric)
end

function StartArea.build(parent: Instance, track)
	local folder = Instance.new("Folder")
	folder.Name = "Ралли"
	folder.Parent = parent

	local pad = track.pad
	local padCF = pad.cf
	local up = Vector3.yAxis

	-- арка старта над дорогой (первая точка трассы)
	local startCF = track:frameAt(1)
	local W = track.HALF_W + 2
	for _, sx in { -1, 1 } do
		local base = (startCF * CFrame.new(sx * W, 0, 0)).Position
		B.part(folder, Vector3.new(1.6, 14, 1.6), CFrame.new(base + Vector3.new(0, 6, 0)), BLACK, M.Metal)
	end
	local beamPart = B.part(folder, Vector3.new(W * 2 + 1.6, 3, 1), startCF * CFrame.new(0, 12.5, 0), BLACK, M.Metal)
	banner(beamPart, "СТАРТ · ФИНИШ", WHITE)
	for i = 0, 1 do
		for j = -4, 4 do
			local color = (i + j) % 2 == 0 and BLACK or WHITE
			B.part(folder, Vector3.new(2, 0.2, 2), startCF * CFrame.new(j * 2, 0.2, (i - 0.5) * 2), color, M.SmoothPlastic, { CanCollide = false })
		end
	end
	for _, sx in { -1, 1 } do
		local glow = B.part(folder, Vector3.new(0.6, 0.6, 0.6), startCF * CFrame.new(sx * (W - 1.5), 11, 0), Color3.fromRGB(255, 240, 210), M.Neon)
		B.light(glow, Color3.fromRGB(255, 240, 210), 26, 1.2)
	end

	-- столбики вдоль трассы со светоотражателями
	local step = 15 -- каждые ~60 шпилек
	for i = 1, track.count, step do
		if track.wet[i] < 0.2 then
			local f = track:frameAt(i)
			for _, sx in { -1, 1 } do
				local base = (f * CFrame.new(sx * (track.HALF_W + 1.8), 0, 0)).Position
				local ghost = { CanCollide = false, CanQuery = false, CanTouch = false }
				B.part(folder, Vector3.new(0.5, 3.2, 0.5), CFrame.new(base + Vector3.new(0, 1, 0)) * f.Rotation, WHITE, M.SmoothPlastic, ghost)
				B.part(folder, Vector3.new(0.52, 0.5, 0.52), CFrame.new(base + Vector3.new(0, 2.3, 0)) * f.Rotation, ORANGE, M.Neon, ghost)
			end
		end
	end

	-- знаки трамплинов: красно-белые щиты
	for _, j in track.jumps do
		local f = track:frameAt(math.max(1, j - 14))
		for _, sx in { -1, 1 } do
			local base = (f * CFrame.new(sx * (track.HALF_W + 3), 0, 0)).Position
			B.post(folder, base, 3.5, 0.3, WHITE, M.Metal)
			local sign = B.part(folder, Vector3.new(2.6, 2.6, 0.2), CFrame.new(base + Vector3.new(0, 4.6, 0)) * f.Rotation * CFrame.Angles(0, math.pi, math.rad(45)), RED, M.SmoothPlastic)
			B.surfaceText(sign, Enum.NormalId.Front, "!", WHITE, Enum.Font.BuilderSansExtraBold)
		end
	end

	-- площадка
	local function padAt(across: number, along: number): Vector3
		return (padCF * CFrame.new(0, 0, 0)).Position + pad.outward * across + pad.dir * along
	end
	local toRoad = -pad.outward

	-- три стояночных места: носом к дороге под углом
	local slots = {}
	local facing = (toRoad + pad.dir * 0.8).Unit
	for k = -1, 1 do
		local p = padAt(-6, k * 14) + up * (1.85 + 0.05)
		table.insert(slots, CFrame.lookAt(p, p + facing))
		-- разметка места
		for _, sx in { -1, 1 } do
			B.part(folder, Vector3.new(0.4, 0.1, 14), CFrame.lookAt(padAt(-6, k * 14) + up * 0.08, padAt(-6, k * 14) + up * 0.08 + facing) * CFrame.new(sx * 4.4, 0, 0), WHITE, M.SmoothPlastic, { CanCollide = false })
		end
	end

	for _, p in { { 18, 26 }, { 18, -26 }, { -20, 28 }, { -20, -28 } } do
		tireStack(folder, padAt(p[1], p[2]))
	end
	for _, along in { -30, -27, -24, 24, 27, 30 } do
		cone(folder, padAt(-19, along))
	end
	local flagColors = { RED, Color3.fromRGB(30, 80, 200), Color3.fromRGB(250, 200, 30), WHITE }
	for k = 0, 3 do
		flag(folder, padAt(20, -18 + k * 12), flagColors[k + 1], toRoad)
	end
	for _, along in { -24, 24 } do
		local base = padAt(10, along)
		B.post(folder, base, 14, 0.5, Color3.fromRGB(90, 90, 96), M.Metal)
		local lamp = B.part(folder, Vector3.new(2.4, 1, 1.2), CFrame.lookAt(base + up * 14, base + up * 10 + toRoad * 8), BLACK, M.Metal)
		local glow = B.part(folder, Vector3.new(2, 0.7, 0.2), lamp.CFrame * CFrame.new(0, 0, -0.6), Color3.fromRGB(255, 250, 230), M.Neon)
		local spot = Instance.new("SpotLight")
		spot.Face = Enum.NormalId.Front
		spot.Range = 50
		spot.Angle = 80
		spot.Brightness = 2
		spot.Parent = glow
	end

	-- табло лучших кругов
	local boardBase = padAt(19, 0)
	local boardCF = CFrame.lookAt(boardBase + up * 7, boardBase + up * 7 + toRoad)
	for _, sx in { -1, 1 } do
		B.post(folder, (boardCF * CFrame.new(sx * 6, -7, 0)).Position, 9, 0.5, BLACK, M.Metal)
	end
	local boardPart = B.part(folder, Vector3.new(14, 8, 0.6), boardCF * CFrame.new(0, 1, 0), Color3.fromRGB(16, 18, 24), M.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 0
	local board = Instance.new("TextLabel")
	board.Size = UDim2.fromScale(1, 1)
	board.BackgroundTransparency = 1
	board.TextColor3 = Color3.fromRGB(255, 220, 120)
	board.Font = Enum.Font.BuilderSansBold
	board.TextScaled = true
	board.TextXAlignment = Enum.TextXAlignment.Left
	board.Text = "ЛУЧШИЕ КРУГИ"
	local pad_ = Instance.new("UIPadding")
	pad_.PaddingLeft = UDim.new(0.05, 0)
	pad_.PaddingTop = UDim.new(0.06, 0)
	pad_.PaddingBottom = UDim.new(0.06, 0)
	pad_.Parent = board
	board.Parent = gui
	gui.Parent = boardPart

	-- портал обратно в лобби и точка прибытия
	local portalBase = padAt(14, -26)
	local portalCF = CFrame.lookAt(portalBase, portalBase + toRoad)
	local backPortal = portalArch(folder, portalCF, "В ЛОББИ")
	local arrival = CFrame.lookAt(padAt(6, -14) + up * 3, padAt(6, -14) + up * 3 + toRoad)

	return {
		slots = slots,
		arrival = arrival,
		backPortal = backPortal,
		board = board,
	}
end

-- телепорты между порталами (решает сервер, с задержкой на игрока)
function StartArea.linkPortals(a: BasePart, aDestination: CFrame, b: BasePart, bDestination: CFrame)
	local cooldown: { [Player]: number } = {}
	local function hook(part: BasePart, destination: CFrame)
		part.CanTouch = true
		part.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 or humanoid.SeatPart then
				return
			end
			local now = os.clock()
			if cooldown[player] and now - cooldown[player] < 2 then
				return
			end
			cooldown[player] = now
			character:PivotTo(destination)
		end)
	end
	hook(a, aDestination)
	hook(b, bDestination)
	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)
end

return StartArea
