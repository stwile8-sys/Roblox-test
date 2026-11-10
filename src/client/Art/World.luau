--!nonstrict
-- Оживление 3D-моделей мира на клиенте (тег WAnim, атрибут WAnim = вид анимации; ставит сервер в Dress).
-- portal — свечение портала крутится по кругу; lid — крышка сундука «дышит» и иногда подпрыгивает;
-- crystal/float — парят и медленно вращаются; sway — деревья и кусты качаются на ветру;
-- glow — светящиеся детали мягко пульсируют; spin — воронка ловушки крутится;
-- button — кнопка замка проседает при нажатии; cage — клетка вздрагивает от ударов.
-- Только CFrame/прозрачность, один проход за кадр, дальние модели не трогаем.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local M = {}

local RANGE = 170
local GLOW_RANGE = 120

type Entry = {
	model: Model,
	kind: string,
	parts: { BasePart },
	base: { CFrame },
	glow: { BasePart },
	glowT0: { number },
	glowIdx: { number },
	pivot: CFrame,
	center: Vector3,
	ph: number,
	pressAt: number?,
	shakeAt: number?,
	button: BasePart?,
	buttonBase: CFrame?,
}

local entries: { [Model]: Entry } = {}

local function isGlow(p: BasePart): boolean
	return p:GetAttribute("Glow") == true or string.sub(p.Name, 1, 5) == "Glow_"
end

local function add(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local kind = model:GetAttribute("WAnim")
	if type(kind) ~= "string" then
		return
	end
	local e: Entry = {
		model = model,
		kind = kind,
		parts = {},
		base = {},
		glow = {},
		glowT0 = {},
		glowIdx = {},
		pivot = model:GetPivot(),
		center = model:GetBoundingBox().Position,
		ph = math.random() * 6.28,
	}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(e.parts, p)
			table.insert(e.base, p.CFrame)
			if isGlow(p) then
				table.insert(e.glow, p)
				table.insert(e.glowT0, p.Transparency)
				table.insert(e.glowIdx, #e.parts)
			end
			if p.Name == "Button" then
				e.button = p
				e.buttonBase = p.CFrame
			end
		end
	end
	if kind == "button" then
		model:GetAttributeChangedSignal("PressedAt"):Connect(function()
			e.pressAt = os.clock()
		end)
	end
	entries[model] = e
end

local function remove(model: Instance)
	entries[model :: Model] = nil
end

-- клетка вздрагивает, когда её прочность падает
local function hookCage()
	local map = workspace:WaitForChild("Map", 60)
	local season = map and map:WaitForChild("Season", 60)
	if not season then
		return
	end
	local last = season:GetAttribute("CageHP") or 0
	season:GetAttributeChangedSignal("CageHP"):Connect(function()
		local hp = season:GetAttribute("CageHP") or 0
		if hp < last then
			for _, e in entries do
				if e.kind == "cage" then
					e.shakeAt = os.clock()
				end
			end
		end
		last = hp
	end)
end

local parts: { BasePart } = {}
local cfs: { CFrame } = {}

local function step()
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	local cp = cam.CFrame.Position
	local t = os.clock()
	table.clear(parts)
	table.clear(cfs)
	for model, e in entries do
		if not model.Parent then
			entries[model] = nil
			continue
		end
		local dist = (e.center - cp).Magnitude
		if dist > RANGE then
			continue
		end
		local k = e.kind
		if k == "portal" then
			-- свечение крутится вокруг оси «вперёд» портала через его центр
			local axis = e.pivot.LookVector
			local rot = CFrame.new(e.center) * CFrame.fromAxisAngle(axis, t * 1.4 + e.ph) * CFrame.new(-e.center)
			for i, idx in e.glowIdx do
				local _ = i
				table.insert(parts, e.parts[idx])
				table.insert(cfs, rot * e.base[idx])
			end
		elseif k == "spin" then
			local c = e.pivot.Position
			local rot = CFrame.new(c) * CFrame.Angles(0, t * 2.2, 0) * CFrame.new(-c)
			for _, idx in e.glowIdx do
				table.insert(parts, e.parts[idx])
				table.insert(cfs, rot * e.base[idx])
			end
		elseif k == "lid" then
			local hinge = e.model:GetAttribute("Hinge")
			if typeof(hinge) == "CFrame" then
				-- лёгкое «дыхание» + раз в 7 с крышка подпрыгивает
				local cyc = (t + e.ph) % 7
				local pop = if cyc < 0.5 then math.sin(cyc / 0.5 * math.pi) * 0.22 else 0
				local a = 0.06 + math.sin(t * 1.3) * 0.04 + pop
				local rot = hinge * CFrame.Angles(a, 0, 0) * hinge:Inverse()
				for i, p in e.parts do
					table.insert(parts, p)
					table.insert(cfs, rot * e.base[i])
				end
			end
		elseif k == "crystal" or k == "float" then
			local amp = if k == "float" then 1.1 else 0.5
			local c = e.pivot.Position
			local m = CFrame.new(0, math.sin(t * 1.1 + e.ph) * amp, 0) * CFrame.new(c) * CFrame.Angles(0, t * 0.4 + e.ph, 0) * CFrame.new(-c)
			for i, p in e.parts do
				table.insert(parts, p)
				table.insert(cfs, m * e.base[i])
			end
		elseif k == "sway" then
			local c = e.pivot.Position
			local m = CFrame.new(c) * CFrame.Angles(math.sin(t * 0.9 + e.ph) * 0.03, 0, math.cos(t * 0.75 + e.ph) * 0.025) * CFrame.new(-c)
			for i, p in e.parts do
				table.insert(parts, p)
				table.insert(cfs, m * e.base[i])
			end
		elseif k == "button" and e.button and e.buttonBase then
			local dt = if e.pressAt then t - e.pressAt else 99
			local down = if dt < 0.12 then dt / 0.12 elseif dt < 0.5 then 1 - (dt - 0.12) / 0.38 else 0
			if dt < 0.6 then
				table.insert(parts, e.button)
				table.insert(cfs, e.buttonBase * CFrame.new(0, -0.45 * down, 0))
			end
		elseif k == "cage" and e.shakeAt then
			local dt = t - e.shakeAt
			if dt < 0.3 then
				local off = Vector3.new(math.sin(dt * 90) * 0.18 * (1 - dt / 0.3), 0, math.cos(dt * 80) * 0.12 * (1 - dt / 0.3))
				for i, p in e.parts do
					table.insert(parts, p)
					table.insert(cfs, e.base[i] + off)
				end
			elseif dt < 0.4 then
				for i, p in e.parts do
					table.insert(parts, p)
					table.insert(cfs, e.base[i])
				end
			end
		end
		-- мягкий пульс свечения (у всех, кроме ловушек — их прозрачностью управляет сервер)
		if dist < GLOW_RANGE and k ~= "spin" and #e.glow > 0 then
			local pulse = (math.sin(t * 2.4 + e.ph) + 1) * 0.5
			for i, g in e.glow do
				g.Transparency = math.clamp(e.glowT0[i] + pulse * 0.25, 0, 0.95)
			end
		end
	end
	if #parts > 0 then
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	end
end

function M.start()
	for _, m in CollectionService:GetTagged("WAnim") do
		add(m)
	end
	CollectionService:GetInstanceAddedSignal("WAnim"):Connect(function(m)
		-- подождать, пока доедут все детали и сервер закончит подгонку позиции
		task.delay(1.5, add, m)
	end)
	CollectionService:GetInstanceRemovedSignal("WAnim"):Connect(remove)
	task.spawn(hookCage)
	RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[World]", err)
		end
	end)
end

return M
