--!nonstrict
-- Набор интерфейса: палитра ТЗ, крупные кнопки (≥ 80 px на телефоне), окна, карточки, иконки-эмодзи.
-- Макет рассчитан на портрет ~400×800 «логических» пикселей и масштабируется UIScale.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Palette = require(ReplicatedStorage:WaitForChild("Shared").Config.Palette)

local M = {}

M.C = {
	bg = Color3.fromHex("#1A1A2E"),
	panel = Color3.fromHex("#25254A"),
	panel2 = Color3.fromHex("#33336A"),
	line = Color3.fromHex("#4B4B8A"),
	text = Color3.fromHex("#FFFFFF"),
	dim = Color3.fromHex("#B8B8D8"),
	gold = Palette.gold,
	orange = Palette.orange,
	chrono = Palette.chrono,
	thief = Palette.thief,
	alarm = Palette.alarm,
	ok = Palette.success,
	grey = Color3.fromHex("#6C6C88"),
}

M.FONT = Enum.Font.GothamBold
M.BLACK = Enum.Font.GothamBlack

function M.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	if props then
		for k, v in props do
			if k ~= "Parent" then
				(inst :: any)[k] = v
			end
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function M.corner(r: number?): UICorner
	return M.new("UICorner", { CornerRadius = UDim.new(0, r or 14) })
end

function M.stroke(color: Color3?, t: number?): UIStroke
	return M.new("UIStroke", { Color = color or M.C.line, Thickness = t or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function M.pad(p: number): UIPadding
	local u = UDim.new(0, p)
	return M.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function M.list(dir: Enum.FillDirection?, gap: number?, halign: Enum.HorizontalAlignment?): UIListLayout
	return M.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = halign or Enum.HorizontalAlignment.Center,
	})
end

function M.grid(cell: Vector2, gap: number?): UIGridLayout
	return M.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(gap or 8, gap or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
	})
end

function M.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = M.FONT,
		TextColor3 = M.C.text,
		TextSize = 20,
		TextWrapped = true,
		AutoLocalize = false,
		Size = UDim2.new(1, 0, 0, 26),
	}
	for k, v in props do
		base[k] = v
	end
	return M.new("TextLabel", base)
end

local KIND = {
	buy = { Palette.success, Color3.fromHex("#0B2A06") },
	gold = { Palette.gold, Color3.fromHex("#3A2A00") },
	chrono = { Palette.chrono, Color3.fromHex("#00303A") },
	danger = { Palette.alarm, Color3.new(1, 1, 1) },
	cancel = { Color3.fromHex("#5A5A78"), Color3.new(1, 1, 1) },
	plain = { Color3.fromHex("#33336A"), Color3.new(1, 1, 1) },
	thief = { Palette.thief, Color3.new(1, 1, 1) },
}

function M.button(text: string, kind: string?, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local k = KIND[kind or "plain"] or KIND.plain
	local base = {
		Text = text,
		BackgroundColor3 = k[1],
		TextColor3 = k[2],
		Font = M.BLACK,
		TextSize = 20,
		AutoButtonColor = true,
		AutoLocalize = false,
		TextWrapped = true,
		Size = UDim2.new(0, 140, 0, 52),
	}
	if props then
		for key, v in props do
			base[key] = v
		end
	end
	local b = M.new("TextButton", base, { M.corner(14) })
	if onClick then
		b.Activated:Connect(function()
			M.click(b)
			onClick()
		end)
	end
	return b
end

-- круглая кнопка-иконка (HUD)
function M.iconButton(icon: string, color: Color3, size: number, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local base = {
		Text = icon,
		BackgroundColor3 = color,
		TextColor3 = Color3.new(1, 1, 1),
		Font = M.BLACK,
		TextScaled = true,
		AutoButtonColor = true,
		AutoLocalize = false,
		Size = UDim2.fromOffset(size, size),
	}
	if props then
		for key, v in props do
			base[key] = v
		end
	end
	local b = M.new("TextButton", base, { M.corner(size), M.stroke(Color3.new(1, 1, 1), 3), M.new("UIPadding", {
		PaddingTop = UDim.new(0.18, 0),
		PaddingBottom = UDim.new(0.18, 0),
		PaddingLeft = UDim.new(0.18, 0),
		PaddingRight = UDim.new(0.18, 0),
	}) })
	if onClick then
		b.Activated:Connect(function()
			M.click(b)
			onClick()
		end)
	end
	return b
end

function M.frame(props: { [string]: any }, children: { Instance }?): Frame
	local base = { BackgroundColor3 = M.C.panel, BorderSizePixel = 0 }
	for k, v in props do
		base[k] = v
	end
	return M.new("Frame", base, children)
end

function M.scroll(props: { [string]: any }, children: { Instance }?): ScrollingFrame
	local base = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = M.C.line,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}
	for k, v in props do
		base[k] = v
	end
	return M.new("ScrollingFrame", base, children)
end

-- Корневой ScreenGui. Масштаб: макет 400 px по ширине в портрете
M.scales = {}
function M.screen(name: string, order: number?): (ScreenGui, Frame)
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = M.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 0,
		AutoLocalize = false,
		Parent = pg,
	})
	-- корень с логическим размером, растянутый на экран через UIScale
	local root = M.frame({ Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
	local scale = M.new("UIScale", { Parent = root })
	local function fit()
		local cam = workspace.CurrentCamera
		local v = if cam then cam.ViewportSize else Vector2.new(400, 800)
		local s = math.clamp(math.min(v.X / 400, v.Y / 720), 0.6, 2)
		scale.Scale = s
		root.Size = UDim2.fromOffset(v.X / s, v.Y / s)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return gui, root
end

-- Окно на весь экран снизу (удобно для большого пальца). Возвращает (окно, тело, заголовок)
M.openWindow = nil :: Frame?
function M.window(parent: Instance, titleText: string, heightScale: number?): (Frame, Frame, TextLabel)
	local win = M.frame({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -6),
		Size = UDim2.new(1, -12, heightScale or 0.78, 0),
		BackgroundColor3 = M.C.bg,
		Visible = false,
		ZIndex = 20,
		Parent = parent,
	}, { M.corner(22), M.stroke(M.C.chrono, 2) })
	local title = M.label({ Text = titleText, Font = M.BLACK, TextSize = 26, Position = UDim2.fromOffset(16, 12), Size = UDim2.new(1, -100, 0, 34), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 21, Parent = win })
	M.button("✕", "cancel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(56, 56), TextSize = 26, ZIndex = 21, Parent = win }, function()
		M.close(win)
	end)
	local body = M.frame({ Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 72), Size = UDim2.new(1, -20, 1, -82), ZIndex = 21, Parent = win })
	return win, body, title
end

function M.open(win: Frame)
	if M.openWindow and M.openWindow ~= win then
		M.openWindow.Visible = false
	end
	M.openWindow = win
	win.Visible = true
	local s = win:FindFirstChildOfClass("UIScale") or M.new("UIScale", { Parent = win })
	s.Scale = 0.92
	TweenService:Create(s, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function M.close(win: Frame?)
	local w = win or M.openWindow
	if w then
		w.Visible = false
	end
	if M.openWindow == w then
		M.openWindow = nil
	end
end

function M.pop(obj: GuiObject, from: number?)
	local s = obj:FindFirstChildOfClass("UIScale") or M.new("UIScale", { Parent = obj })
	s.Scale = from or 0.8
	TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function M.pulse(obj: GuiObject, on: boolean)
	local s = obj:FindFirstChild("PulseScale") or M.new("UIScale", { Name = "PulseScale", Parent = obj })
	local tw = obj:GetAttribute("Pulsing")
	if on and not tw then
		obj:SetAttribute("Pulsing", true)
		local t = TweenService:Create(s, TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
		t:Play()
		obj:SetAttribute("PulseId", tostring(t))
		M[obj] = t
	elseif not on and tw then
		obj:SetAttribute("Pulsing", nil)
		local t = M[obj]
		if t then
			t:Cancel()
			M[obj] = nil
		end
		s.Scale = 1
	end
end

M.onClick = nil :: (() -> ())?
function M.click(obj: GuiObject)
	if M.onClick then
		M.onClick()
	end
	local s = obj:FindFirstChild("ClickScale") or M.new("UIScale", { Name = "ClickScale", Parent = obj })
	s.Scale = 0.9
	TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function M.clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") and not c:IsA("UIStroke") then
			c:Destroy()
		end
	end
end

-- превью существа в ViewportFrame
function M.creature(id: string, props: { [string]: any }, silhouette: boolean?): ViewportFrame
	local Build = require(ReplicatedStorage.Shared.Art.Build)
	local vp = M.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Ambient = Color3.fromRGB(200, 200, 220),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	})
	for k, v in props do
		if k ~= "Parent" then
			(vp :: any)[k] = v
		end
	end
	local model = Build.model(id, 1, true)
	local size = Build.size(id)
	if silhouette then
		for _, p in model:GetDescendants() do
			if p:IsA("BasePart") then
				p.Color = Color3.fromRGB(20, 20, 35)
				p.Material = Enum.Material.SmoothPlastic
			end
		end
	end
	model.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 40
	cam.CFrame = CFrame.lookAt(Vector3.new(size * 0.9, size * 0.5, -size * 2.1), Vector3.new(0, 0, 0))
	cam.Parent = vp
	vp.CurrentCamera = cam
	vp.Parent = props.Parent
	return vp
end

return M
