--!nonstrict
-- Режим стройки как в Cities: Skylines: вид сверху на свой участок,
-- дороги (линия «Г»), зоны и снос (прямоугольник), особые здания (призрак + подтверждение).
-- Управление: палец / мышь / геймпад. Два пальца — сдвиг и масштаб.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local Shared = game.ReplicatedStorage.Shared
local L = require(Shared.Lang.L)
local Map = require(Shared.Config.Map)
local CityCfg = require(Shared.Config.City)
local Biomes = require(Shared.Config.Biomes)
local Rules = require(Shared.CityRules)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Parent.Store)

local C = Kit.C
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local M = {}

local active = false
local plot: number? = nil
local tool = "pan"
local focus = Vector3.zero
local dist = 150
local PITCH = math.rad(58)

local gui: ScreenGui
local toolButtons: { [string]: TextButton } = {}
local statsLabel: TextLabel
local bars: { [string]: Frame } = {}
local costLabel: TextLabel
local confirmRow: Frame
local picker: Frame
local crosshair: TextLabel
local overlay: Folder
local preview: Folder
local toast: (string, string?) -> ()
local onExit: () -> () = function() end

local lastGrid = ""
local dragStart: number? = nil -- ключ клетки
local dragCur: number? = nil
local pendingSpecial: number? = nil
local usingGamepad = false

local ZONE_COLOR = { R = C.R, C = C.C, I = C.I }

-- Камера ------------------------------------------------------------------

local function clampFocus()
	if not plot then
		return
	end
	local o = Map.plotOrigin(plot)
	focus = Vector3.new(
		math.clamp(focus.X, o.X - 20, o.X + Map.PLOT + 20),
		Map.GROUND_Y,
		math.clamp(focus.Z, o.Z - 20, o.Z + Map.PLOT + 20)
	)
	dist = math.clamp(dist, 50, 260)
end

local function updateCamera()
	clampFocus()
	local offset = Vector3.new(0, math.sin(PITCH) * dist, math.cos(PITCH) * dist)
	camera.CFrame = CFrame.lookAt(focus + offset, focus)
end

local function panScreen(delta: Vector2)
	-- смещение пальца в пикселях → смещение по земле
	local k = dist / camera.ViewportSize.Y * 1.6
	focus -= Vector3.new(delta.X * k, 0, delta.Y * k / math.sin(PITCH))
end

-- Клетки ------------------------------------------------------------------

local function cellAt(screen: Vector2): number?
	if not plot then
		return nil
	end
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	if math.abs(ray.Direction.Y) < 1e-4 then
		return nil
	end
	local t = (Map.GROUND_Y - ray.Origin.Y) / ray.Direction.Y
	if t < 0 then
		return nil
	end
	local pos = ray.Origin + ray.Direction * t
	local i, j = Map.worldToCell(plot, pos)
	if not i or not j then
		return nil
	end
	return Map.key(i, j)
end

local function lineCells(a: number, b: number): { number }
	local ai, aj = Map.unkey(a)
	local bi, bj = Map.unkey(b)
	local out = {}
	local horizontalFirst = math.abs(bi - ai) >= math.abs(bj - aj)
	local function push(i: number, j: number)
		table.insert(out, Map.key(i, j))
	end
	if horizontalFirst then
		local step = if bi >= ai then 1 else -1
		for i = ai, bi, step do
			push(i, aj)
		end
		local stepJ = if bj >= aj then 1 else -1
		for j = aj + stepJ, bj, stepJ do
			if j ~= aj then
				push(bi, j)
			end
		end
	else
		local stepJ = if bj >= aj then 1 else -1
		for j = aj, bj, stepJ do
			push(ai, j)
		end
		local step = if bi >= ai then 1 else -1
		for i = ai + step, bi, step do
			if i ~= ai then
				push(i, bj)
			end
		end
	end
	return out
end

local function rectCells(a: number, b: number): { number }
	local ai, aj = Map.unkey(a)
	local bi, bj = Map.unkey(b)
	local out = {}
	for i = math.min(ai, bi), math.max(ai, bi) do
		for j = math.min(aj, bj), math.max(aj, bj) do
			table.insert(out, Map.key(i, j))
		end
	end
	return out
end

local function cityData(): Rules.CityData?
	local s = Store.state
	return if s and s.city then s.city :: any else nil
end

-- Отрисовка ---------------------------------------------------------------

local function tile(parent: Instance, k: number, color: Color3, transparency: number, h: number?): Part
	local i, j = Map.unkey(k)
	local center = Map.cellCenter(plot :: number, i, j)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.Size = Vector3.new(Map.CELL - 0.6, 0.12, Map.CELL - 0.6)
	p.CFrame = CFrame.new(center + Vector3.new(0, h or 0.3, 0))
	p.Color = color
	p.Transparency = transparency
	p.Parent = parent
	return p
end

local function drawOverlay(force: boolean?)
	local city = cityData()
	if not city or not plot then
		return
	end
	if not force and city.grid == lastGrid then
		return
	end
	lastGrid = city.grid
	overlay:ClearAllChildren()
	local grid = Rules.toArray(city.grid)
	for k, ch in grid do
		local col = ZONE_COLOR[ch]
		if col then
			tile(overlay, k, col, 0.55, 0.25)
		end
	end
	-- границы участка
	local o = Map.plotOrigin(plot)
	for side = 0, 3 do
		local center = o + Vector3.new(Map.PLOT / 2, Map.GROUND_Y + 0.4, Map.PLOT / 2)
		local cf = CFrame.new(center) * CFrame.Angles(0, side * math.pi / 2, 0) * CFrame.new(0, 0, Map.PLOT / 2)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Size = Vector3.new(Map.PLOT, 0.3, 0.6)
		p.CFrame = cf
		p.Color = C.accent
		p.Material = Enum.Material.Neon
		p.Parent = overlay
	end
end

local function drawPreview()
	preview:ClearAllChildren()
	costLabel.Text = ""
	local city = cityData()
	if not city or not plot then
		return
	end
	local grid = Rules.toArray(city.grid)
	local occ = Rules.occupancy(city)
	if string.sub(tool, 1, 8) == "special:" then
		local id = string.sub(tool, 9)
		local anchorKey = pendingSpecial or dragCur
		if not anchorKey then
			return
		end
		local def = CityCfg.SPECIAL[id]
		local i, j = Map.unkey(anchorKey)
		local ok = Rules.canPlaceSpecial(grid, occ, Rules.allRoads(grid), id, i, j)
		for di = 0, def.w - 1 do
			for dj = 0, def.h - 1 do
				if Map.inside(i + di, j + dj) then
					tile(preview, Map.key(i + di, j + dj), if ok then C.good else C.bad, 0.35, 0.5)
				end
			end
		end
		return
	end
	if not dragStart or not dragCur then
		return
	end
	local cells = if tool == "road" then lineCells(dragStart, dragCur) else rectCells(dragStart, dragCur)
	local near = Rules.distance(Rules.allRoads(grid), CityCfg.ZONE_REACH)
	local valid = 0
	for _, k in cells do
		local ok
		if tool == "road" then
			ok = Rules.canRoad(grid, occ, k)
		elseif tool == "bulldoze" then
			ok = grid[k] ~= "." or occ[k] ~= nil
		else
			ok = grid[k] ~= tool and Rules.canZone(grid, occ, near, k)
		end
		if ok then
			valid += 1
		end
		local color = if tool == "bulldoze" then C.bad elseif ok then (ZONE_COLOR[tool] or C.good) else Color3.fromRGB(120, 40, 40)
		tile(preview, k, color, if ok then 0.25 else 0.6, 0.5)
	end
	local unit = if tool == "road" then CityCfg.ROAD_COST elseif tool == "bulldoze" then 0 else CityCfg.ZONE_COST[tool] or 0
	if unit > 0 then
		costLabel.Text = L.t("build.cost", { n = valid, money = valid * unit })
	else
		costLabel.Text = L.t("build.cells", { n = valid })
	end
end

local function drawStats()
	local city = cityData()
	if not city then
		return
	end
	local st = (city :: any).stats
	if not st then
		return
	end
	statsLabel.Text = L.t("build.stats", {
		pop = st.pop,
		cap = st.capacity,
		jobs = st.jobsC + st.jobsI,
		work = math.floor((st.employment or 0) * 100),
		income = math.floor((st.income or 0) - (st.costs or 0)),
	}) .. (if st.food then "" else "\n" .. L.t("build.no_food"))
	for z, bar in bars do
		local v = st.demand[z] or 0
		bar.Size = UDim2.new(1, 0, math.max(0, v), 0)
	end
end

-- Действия ----------------------------------------------------------------

local function send(action: string, ...: any)
	task.spawn(function(...)
		local ok, msg = Store.act(action, ...)
		if not ok and type(msg) == "string" then
			toast(L.t(msg), "error")
		end
	end, ...)
end

local function commitDrag()
	if not dragStart or not dragCur then
		return
	end
	if tool == "road" then
		local cells = lineCells(dragStart, dragCur)
		while #cells > 0 do
			local chunk = {}
			for _ = 1, math.min(80, #cells) do
				table.insert(chunk, table.remove(cells, 1))
			end
			send("road", chunk)
		end
	elseif tool == "bulldoze" then
		send("bulldoze", rectCells(dragStart, dragCur))
	elseif tool == "R" or tool == "C" or tool == "I" then
		send("zone", tool, rectCells(dragStart, dragCur))
	end
	dragStart, dragCur = nil, nil
	drawPreview()
end

local function setTool(name: string)
	tool = name
	dragStart, dragCur, pendingSpecial = nil, nil, nil
	for id, b in toolButtons do
		b.BackgroundColor3 = if id == name or (id == "special" and string.sub(name, 1, 8) == "special:") then C.accent else C.panel2
		b.TextColor3 = if b.BackgroundColor3 == C.accent then Color3.fromRGB(35, 30, 20) else C.text
	end
	picker.Visible = false
	confirmRow.Visible = false
	drawPreview()
end

local function beginAt(screen: Vector2)
	local k = cellAt(screen)
	if not k then
		return
	end
	if string.sub(tool, 1, 8) == "special:" then
		local def = CityCfg.SPECIAL[string.sub(tool, 9)]
		local i, j = Map.unkey(k)
		i = math.clamp(i - def.w // 2, 0, Map.CELLS - def.w)
		j = math.clamp(j - def.h // 2, 0, Map.CELLS - def.h)
		pendingSpecial = Map.key(i, j)
		confirmRow.Visible = true
		drawPreview()
		return
	end
	dragStart, dragCur = k, k
	drawPreview()
end

local function moveTo(screen: Vector2)
	if not dragStart then
		return
	end
	local k = cellAt(screen)
	if k and k ~= dragCur then
		dragCur = k
		drawPreview()
	end
end

-- Ввод --------------------------------------------------------------------

local touches: { [InputObject]: Vector2 } = {}
local pinchDist: number? = nil
local pinchMid: Vector2? = nil
local mouseDown = false
local rightDown = false
local lastMouse = Vector2.zero

local function touchCount(): number
	local n = 0
	for _ in touches do
		n += 1
	end
	return n
end

local function twoTouches(): (Vector2, Vector2)
	local a, b
	for _, p in touches do
		if not a then
			a = p
		elseif not b then
			b = p
		end
	end
	return a :: Vector2, b :: Vector2
end

local function onTouchStart(input: InputObject, processed: boolean)
	if not active or processed then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	touches[input] = pos
	if touchCount() == 2 then
		dragStart, dragCur = nil, nil
		drawPreview()
		local a, b = twoTouches()
		pinchDist = (a - b).Magnitude
		pinchMid = (a + b) / 2
	elseif touchCount() == 1 and tool ~= "pan" then
		beginAt(pos)
	end
end

local function onTouchMove(input: InputObject)
	if not active or not touches[input] then
		return
	end
	local pos = Vector2.new(input.Position.X, input.Position.Y)
	local prev = touches[input]
	touches[input] = pos
	local n = touchCount()
	if n >= 2 then
		local a, b = twoTouches()
		local d = (a - b).Magnitude
		local mid = (a + b) / 2
		if pinchDist and pinchDist > 0 then
			dist *= pinchDist / math.max(1, d)
		end
		if pinchMid then
			panScreen(mid - pinchMid)
		end
		pinchDist, pinchMid = d, mid
	elseif n == 1 then
		if tool == "pan" then
			panScreen(pos - prev)
		else
			moveTo(pos)
		end
	end
end

local function onTouchEnd(input: InputObject)
	if not touches[input] then
		return
	end
	touches[input] = nil
	if touchCount() < 2 then
		pinchDist, pinchMid = nil, nil
	end
	if touchCount() == 0 and dragStart then
		commitDrag()
	end
end

local function confirmSpecial()
	if pendingSpecial and string.sub(tool, 1, 8) == "special:" then
		send("special", string.sub(tool, 9), pendingSpecial)
	end
	setTool("pan")
end

-- Интерфейс ---------------------------------------------------------------

local TOOLS = {
	{ id = "pan", icon = "✋", key = "tool.pan" },
	{ id = "road", icon = "🛣️", key = "tool.road" },
	{ id = "R", icon = "🏠", key = "tool.R" },
	{ id = "C", icon = "🏪", key = "tool.C" },
	{ id = "I", icon = "🏭", key = "tool.I" },
	{ id = "special", icon = "⭐", key = "tool.special" },
	{ id = "bulldoze", icon = "🧨", key = "tool.bulldoze" },
	{ id = "exit", icon = "✔️", key = "tool.exit" },
}

local function fillPicker()
	Kit.clear(picker)
	local s = Store.state or {}
	local city = cityData()
	if not plot or not city then
		return
	end
	local res = Map.plotResources(plot, Biomes.byId)
	local counts: { [string]: number } = {}
	for _, sp in city.special do
		counts[sp[1]] = (counts[sp[1]] or 0) + 1
	end
	for n, id in CityCfg.SPECIAL_ORDER do
		local def = CityCfg.SPECIAL[id]
		local cost = CityCfg.specialCost(id, counts[id] or 0)
		local can = res[def.needs] == true
		local text = L.t("special." .. id) .. "\n" .. (if can then L.money(cost) .. " · " .. L.t("special.out", { item = L.t("item." .. def.output) }) else L.t("build.no_resource"))
		local b = Kit.button(text, if can then "plain" else "plain", {
			Size = UDim2.new(1, 0, 0, 52),
			TextSize = 13,
			LayoutOrder = n,
			TextColor3 = if can then C.text else C.dim,
			Parent = picker,
		}, function()
			if not can then
				toast(L.t("build.no_resource"), "error")
				return
			end
			if (s.money or 0) < cost then
				toast(L.t("err.money"), "error")
			end
			setTool("special:" .. id)
			toast(L.t("build.tap_place"), "info")
		end)
		b.TextYAlignment = Enum.TextYAlignment.Center
	end
end

local function buildGui()
	gui = Kit.screen("Build", 2)
	gui.Enabled = false

	-- панель статистики и спроса
	local info = Kit.frame({
		Position = UDim2.new(0, 10, 0, 8),
		Size = UDim2.new(0, 250, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Kit.corner(10), Kit.pad(10) })
	local barBox = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(0, 66, 0, 60), Parent = info })
	for n, z in { "R", "C", "I" } do
		local holder = Kit.frame({ BackgroundColor3 = C.panel2, Position = UDim2.new(0, (n - 1) * 22, 0, 0), Size = UDim2.new(0, 16, 0, 44), Parent = barBox }, { Kit.corner(4) })
		bars[z] = Kit.frame({ BackgroundColor3 = ZONE_COLOR[z], AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 0), Parent = holder }, { Kit.corner(4) })
		Kit.label({ Text = z, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, (n - 1) * 22, 0, 46), Size = UDim2.new(0, 16, 0, 14), Parent = barBox })
	end
	statsLabel = Kit.label({ Position = UDim2.new(0, 76, 0, 0), Size = UDim2.new(1, -76, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextSize = 13, Parent = info })

	-- инструменты внизу
	local bar = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(0, 0, 0, 62),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.1,
		Parent = gui,
	}, { Kit.corner(12), Kit.pad(5) })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 5), SortOrder = Enum.SortOrder.LayoutOrder, Parent = bar })
	for n, t in TOOLS do
		local b = Kit.button(t.icon, "plain", { Size = UDim2.new(0, 58, 1, 0), TextSize = 22, LayoutOrder = n, Parent = bar })
		b.TextYAlignment = Enum.TextYAlignment.Top
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 4), Parent = b })
		local cap = Kit.label({ Text = L.t(t.key), TextSize = 10, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.new(0, 0, 1, -16), Size = UDim2.new(1, 0, 0, 12), TextColor3 = C.dim, Parent = b })
		L.onChange(function()
			cap.Text = L.t(t.key)
		end)
		b.Activated:Connect(function()
			if t.id == "exit" then
				M.exit()
			elseif t.id == "special" then
				fillPicker()
				picker.Visible = not picker.Visible
			else
				setTool(t.id)
			end
		end)
		if t.id ~= "exit" then
			toolButtons[t.id] = b
		end
	end

	picker = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 80, 1, -80),
		Size = UDim2.new(0, 220, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		Visible = false,
		Parent = gui,
	}, { Kit.corner(10), Kit.pad(6), Kit.list(nil, 6) })

	costLabel = Kit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -78),
		Size = UDim2.new(0, 300, 0, 22),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.3,
		Font = Kit.BOLD,
		Parent = gui,
	})

	confirmRow = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -104),
		Size = UDim2.new(0, 260, 0, 44),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = confirmRow })
	Kit.button("✔ " .. L.t("build.place"), "ok", { Size = UDim2.new(0, 120, 1, 0), Parent = confirmRow }, confirmSpecial)
	Kit.button("✕", "bad", { Size = UDim2.new(0, 60, 1, 0), Parent = confirmRow }, function()
		setTool("pan")
	end)

	crosshair = Kit.label({
		Text = "+",
		TextSize = 34,
		Font = Kit.BOLD,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 40, 0, 40),
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = gui,
	})
end

-- В режиме стройки персонаж стоит, экранный джойстик скрыт
local saved: { [string]: any } = {}
local function freeze(on: boolean)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if on then
		saved.touch = GuiService.TouchControlsEnabled
		GuiService.TouchControlsEnabled = false
		if hum then
			saved.speed = hum.WalkSpeed
			saved.jump = hum.JumpHeight
			hum.WalkSpeed = 0
			hum.JumpHeight = 0
		end
	else
		GuiService.TouchControlsEnabled = if saved.touch == nil then true else saved.touch
		if hum then
			hum.WalkSpeed = saved.speed or 16
			hum.JumpHeight = saved.jump or 7.2
		end
	end
end

function M.enter()
	local s = Store.state
	if not s or not s.plot or not s.city then
		return
	end
	plot = s.plot
	active = true
	local p = Map.plots[s.plot]
	focus = Map.tileCenter(p.c, p.r)
	dist = 170
	camera.CameraType = Enum.CameraType.Scriptable
	freeze(true)
	gui.Enabled = true
	lastGrid = ""
	drawOverlay(true)
	drawStats()
	setTool("pan")
	if (s.tutorial or 6) == 5 then
		fillPicker()
		picker.Visible = true
	end
end

function M.exit()
	if not active then
		return
	end
	active = false
	gui.Enabled = false
	overlay:ClearAllChildren()
	preview:ClearAllChildren()
	touches = {}
	camera.CameraType = Enum.CameraType.Custom
	freeze(false)
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	onExit()
end

function M.isActive(): boolean
	return active
end

function M.start(toastFn: (string, string?) -> (), exitFn: () -> ())
	toast = toastFn
	onExit = exitFn
	overlay = Instance.new("Folder")
	overlay.Name = "BuildOverlay"
	overlay.Parent = workspace
	preview = Instance.new("Folder")
	preview.Name = "BuildPreview"
	preview.Parent = workspace
	buildGui()

	UserInputService.TouchStarted:Connect(onTouchStart)
	UserInputService.TouchMoved:Connect(function(input)
		onTouchMove(input)
	end)
	UserInputService.TouchEnded:Connect(function(input)
		onTouchEnd(input)
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.Gamepad1 then
			usingGamepad = true
			crosshair.Visible = true
		elseif input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Keyboard then
			usingGamepad = false
			crosshair.Visible = false
		end
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = true
			lastMouse = Vector2.new(input.Position.X, input.Position.Y)
			if tool ~= "pan" then
				beginAt(lastMouse)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightDown = true
			lastMouse = Vector2.new(input.Position.X, input.Position.Y)
		elseif input.KeyCode == Enum.KeyCode.ButtonA then
			local center = camera.ViewportSize / 2
			if string.sub(tool, 1, 8) == "special:" and pendingSpecial then
				confirmSpecial()
			elseif tool ~= "pan" then
				beginAt(center)
			end
		elseif input.KeyCode == Enum.KeyCode.ButtonB then
			if tool ~= "pan" then
				setTool("pan")
			else
				M.exit()
			end
		elseif input.KeyCode == Enum.KeyCode.Return and pendingSpecial then
			confirmSpecial()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			local pos = Vector2.new(input.Position.X, input.Position.Y)
			if rightDown or (mouseDown and tool == "pan") then
				panScreen(pos - lastMouse)
			elseif mouseDown then
				moveTo(pos)
			elseif string.sub(tool, 1, 8) == "special:" and not pendingSpecial then
				local k = cellAt(pos)
				if k ~= dragCur then
					dragCur = k
					drawPreview()
				end
			end
			lastMouse = pos
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			dist *= if input.Position.Z > 0 then 0.88 else 1.14
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if not active then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			mouseDown = false
			if dragStart then
				commitDrag()
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
			rightDown = false
		elseif input.KeyCode == Enum.KeyCode.ButtonA and dragStart then
			commitDrag()
		end
	end)

	RunService.RenderStepped:Connect(function(dt)
		if not active then
			return
		end
		-- клавиатура и геймпад: сдвиг и масштаб
		local move = Vector3.zero
		if UserInputService:GetFocusedTextBox() == nil then
			if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
				move += Vector3.new(0, 0, -1)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
				move += Vector3.new(0, 0, 1)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.A) or UserInputService:IsKeyDown(Enum.KeyCode.Left) then
				move += Vector3.new(-1, 0, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.D) or UserInputService:IsKeyDown(Enum.KeyCode.Right) then
				move += Vector3.new(1, 0, 0)
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.Q) then
				dist *= 1 + dt
			end
			if UserInputService:IsKeyDown(Enum.KeyCode.E) then
				dist *= 1 - dt
			end
		end
		local pads = if UserInputService:GetGamepadConnected(Enum.UserInputType.Gamepad1)
			then UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)
			else {}
		for _, state in pads do
			if state.KeyCode == Enum.KeyCode.Thumbstick1 and state.Position.Magnitude > 0.15 then
				move += Vector3.new(state.Position.X, 0, -state.Position.Y)
			elseif state.KeyCode == Enum.KeyCode.Thumbstick2 and math.abs(state.Position.Y) > 0.15 then
				dist *= 1 - state.Position.Y * dt
			end
		end
		if move.Magnitude > 0 then
			focus += move * dist * 0.9 * dt
		end
		updateCamera()
		-- геймпад: клетка под прицелом
		if usingGamepad then
			local center = camera.ViewportSize / 2
			if dragStart then
				moveTo(center)
			elseif string.sub(tool, 1, 8) == "special:" and not pendingSpecial then
				local k = cellAt(center)
				if k ~= dragCur then
					dragCur = k
					drawPreview()
				end
			end
		end
	end)

	Store.on(function()
		if active then
			local s = Store.state
			if not s or not s.city then
				M.exit()
				return
			end
			drawOverlay()
			drawStats()
			if picker.Visible then
				fillPicker()
			end
		end
	end)
	L.onChange(function()
		if active then
			drawStats()
		end
	end)
end

return M
