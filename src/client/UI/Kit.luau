--!nonstrict
-- Набор интерфейса: палитра ТЗ, крупные кнопки (≥ 80 px на телефоне), окна, карточки, иконки-эмодзи.
-- Макет рассчитан на портрет ~400×800 «логических» пикселей и масштабируется UIScale.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local _Palette = require(ReplicatedStorage:WaitForChild("Shared").Config.Palette)

local M: any = {}

-- Тема v2 «Chrono Candy»: белые панели без жёстких контуров, мягкие тени, сочные объёмные кнопки,
-- шрифт Builder Sans (современный шрифт Roblox). Один фирменный цвет — фиолетовый хроно (#7B5CFF).
M.C = {
	bg = Color3.fromHex("#FFFFFF"),
	panel = Color3.fromHex("#F6F3FF"), -- карточки внутри окон (surface-2)
	panel2 = Color3.fromHex("#EEE8FF"),
	line = Color3.fromHex("#231A3B"),
	soft = Color3.fromHex("#E6E0F5"),
	text = Color3.fromHex("#231A3B"),
	dim = Color3.fromHex("#6E6688"),
	white = Color3.new(1, 1, 1),
	gold = Color3.fromHex("#D98A00"),
	orange = Color3.fromHex("#F08A24"),
	chrono = Color3.fromHex("#0FA3C4"),
	thief = Color3.fromHex("#7B5CFF"),
	brand = Color3.fromHex("#7B5CFF"),
	alarm = Color3.fromHex("#F0436A"),
	ok = Color3.fromHex("#22B455"),
	grey = Color3.fromHex("#9A93AD"),
}

M.FONT = Enum.Font.GothamBold
M.BLACK = Enum.Font.GothamBlack
-- все Gotham-шрифты интерфейса подменяются на Builder Sans нужной жирности
local BUILDER = "rbxasset://fonts/families/BuilderSans.json"
M.FACE = {
	[Enum.Font.GothamBlack] = Font.new(BUILDER, Enum.FontWeight.ExtraBold),
	[Enum.Font.GothamBold] = Font.new(BUILDER, Enum.FontWeight.Bold),
	[Enum.Font.Gotham] = Font.new(BUILDER, Enum.FontWeight.Medium),
	[Enum.Font.GothamMedium] = Font.new(BUILDER, Enum.FontWeight.SemiBold),
}

function M.new(class: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(class)
	if props then
		for k, v in props do
			if k == "Font" and M.FACE[v] then
				(inst :: any).FontFace = M.FACE[v]
			elseif k ~= "Parent" then
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
	-- v2: вместо толстых чёрных контуров — тонкая полупрозрачная обводка
	local c = color or M.C.line
	local dark = c == M.C.line
	return M.new("UIStroke", {
		Color = c,
		Thickness = if dark then 1.5 else 2,
		Transparency = if dark then 0.86 else 0.25,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

-- мягкая тень под элементом (ставится сзади соседом)
function M.shadow(target: GuiObject, radius: number?, alpha: number?): Frame
	local sh = M.new("Frame", {
		Name = target.Name .. "_Shadow",
		AnchorPoint = target.AnchorPoint,
		Position = target.Position + UDim2.fromOffset(0, 4),
		Size = target.Size,
		BackgroundColor3 = Color3.fromHex("#1A1230"),
		BackgroundTransparency = alpha or 0.8,
		BorderSizePixel = 0,
		ZIndex = math.max(0, target.ZIndex - 1),
		Visible = target.Visible,
		Parent = target.Parent,
	}, { M.corner(radius or 14) })
	target:GetPropertyChangedSignal("Visible"):Connect(function()
		sh.Visible = target.Visible
	end)
	target:GetPropertyChangedSignal("Position"):Connect(function()
		sh.Position = target.Position + UDim2.fromOffset(0, 4)
	end)
	return sh
end

local function darken(c: Color3, k: number): Color3
	local h, s, v = c:ToHSV()
	return Color3.fromHSV(h, math.min(1, s * 1.05), v * k)
end
M.darken = darken

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
	buy = { Color3.fromHex("#34C759"), Color3.new(1, 1, 1) },
	gold = { Color3.fromHex("#FFC233"), Color3.fromHex("#3A2600") },
	chrono = { Color3.fromHex("#2EB8F0"), Color3.new(1, 1, 1) },
	danger = { Color3.fromHex("#FF4D6D"), Color3.new(1, 1, 1) },
	cancel = { Color3.fromHex("#ECE8F5"), Color3.fromHex("#6E6688") },
	plain = { Color3.fromHex("#F1ECFF"), Color3.fromHex("#231A3B") },
	thief = { Color3.fromHex("#7B5CFF"), Color3.new(1, 1, 1) },
}
M.KIND = KIND

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
	-- объёмная «конфетная» кнопка: светлый верх, тёмный низ, обводка того же оттенка
	local flat = kind == "cancel" or kind == "plain" or kind == nil
	local b = M.new("TextButton", base, {
		M.corner(14),
		M.new("UIStroke", { Color = darken(k[1], if flat then 0.88 else 0.72), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }),
		M.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215)),
		}),
	})
	if k[2] == Color3.new(1, 1, 1) then
		b.TextStrokeColor3 = darken(k[1], 0.5)
		b.TextStrokeTransparency = 0.55
	end
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
	local b = M.new("TextButton", base, { M.corner(size), M.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }), M.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) }), M.new("UIPadding", {
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
		ScrollBarImageColor3 = M.C.grey,
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

-- Корневой ScreenGui. Масштаб: макет 860×420 логических px (горизонтальный экран)
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
		local s = math.clamp(math.min(v.X / 860, v.Y / 420), 0.55, 2)
		scale.Scale = s
		root.Size = UDim2.fromOffset(v.X / s, v.Y / s)
	end
	fit()
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	return gui, root
end

-- Окно на весь экран снизу (удобно для большого пальца). Возвращает (окно, тело, заголовок)
M.openWindow = nil :: Frame?
-- Окно: белая карточка с цветной шапкой (иконка + заголовок), затемнение фона, крестик в шапке.
local ACCENT = M.C.brand
function M.window(parent: Instance, titleText: string, heightScale: number?, accent: Color3?): (Frame, Frame, TextLabel)
	local win = M.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0, 560, 0.88, 0),
		BackgroundColor3 = M.C.bg,
		Visible = false,
		ZIndex = 20,
		ClipsDescendants = false,
		Parent = parent,
	}, { M.corner(24) })
	win:SetAttribute("Window", true)
	local head = M.frame({ Name = "Head", Size = UDim2.new(1, 0, 0, 60), BackgroundColor3 = accent or ACCENT, ZIndex = 21, Parent = win }, {
		M.corner(24),
		M.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }),
	})
	-- нижние углы шапки прямые
	M.frame({ Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -24), BackgroundColor3 = accent or ACCENT, ZIndex = 21, Parent = head }, {
		M.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(222, 222, 222), Color3.fromRGB(205, 205, 205)) }),
	})
	local title = M.label({ Text = titleText, Font = M.BLACK, TextSize = 26, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(20, 0), Size = UDim2.new(1, -90, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 22, Parent = head })
	title.TextStrokeTransparency = 0.7
	local x = M.new("TextButton", {
		Text = "X",
		Font = M.BLACK,
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.78,
		AutoButtonColor = true,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(44, 44),
		ZIndex = 22,
		Parent = head,
	}, { M.corner(22) })
	x.Activated:Connect(function()
		M.click(x)
		M.close(win)
	end)
	local body = M.frame({ Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 70), Size = UDim2.new(1, -28, 1, -80), ZIndex = 21, Parent = win })
	return win, body, title
end

-- затемнение под открытым окном (одно на ScreenGui)
local function backdrop(win: Frame): Frame?
	local parent = win.Parent
	if not parent then
		return nil
	end
	local bd = parent:FindFirstChild("Backdrop")
	if not bd then
		bd = M.new("TextButton", {
			Name = "Backdrop",
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = Color3.fromHex("#140E26"),
			BackgroundTransparency = 0.5,
			Size = UDim2.new(1, 400, 1, 400),
			Position = UDim2.fromOffset(-200, -200),
			ZIndex = 19,
			Visible = false,
			Parent = parent,
		})
		bd.Activated:Connect(function()
			M.close()
		end)
	end
	return bd
end

function M.open(win: Frame)
	if M.openWindow and M.openWindow ~= win then
		M.openWindow.Visible = false
	end
	if not win.Visible and M.onOpen then
		pcall(M.onOpen)
	end
	M.openWindow = win
	win.Visible = true
	local bd = backdrop(win)
	if bd then
		bd.Visible = true
	end
	local s = win:FindFirstChildOfClass("UIScale") or M.new("UIScale", { Parent = win })
	s.Scale = 0.94
	TweenService:Create(s, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function M.close(win: Frame?)
	local w = win or M.openWindow
	if w then
		w.Visible = false
		local bd = w.Parent and w.Parent:FindFirstChild("Backdrop")
		if bd and (M.openWindow == w or M.openWindow == nil) then
			bd.Visible = false
		end
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
		Ambient = Color3.fromRGB(230, 225, 240),
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
