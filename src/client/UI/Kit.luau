--!nonstrict
-- Набор для интерфейса: цвета, создание элементов, окна, кнопки. Один стиль на всю игру.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local M = {}

M.C = {
	bg = Color3.fromRGB(28, 32, 40),
	panel = Color3.fromRGB(38, 43, 54),
	panel2 = Color3.fromRGB(50, 56, 70),
	line = Color3.fromRGB(70, 78, 95),
	text = Color3.fromRGB(240, 242, 245),
	dim = Color3.fromRGB(165, 172, 185),
	accent = Color3.fromRGB(255, 190, 70),
	good = Color3.fromRGB(90, 200, 120),
	bad = Color3.fromRGB(235, 90, 80),
	blue = Color3.fromRGB(80, 150, 235),
	R = Color3.fromRGB(90, 200, 110),
	C = Color3.fromRGB(80, 150, 235),
	I = Color3.fromRGB(240, 190, 60),
}

M.FONT = Enum.Font.GothamMedium
M.BOLD = Enum.Font.GothamBold

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
	return M.new("UICorner", { CornerRadius = UDim.new(0, r or 10) })
end

function M.pad(p: number): UIPadding
	local u = UDim.new(0, p)
	return M.new("UIPadding", { PaddingLeft = u, PaddingRight = u, PaddingTop = u, PaddingBottom = u })
end

function M.list(dir: Enum.FillDirection?, gap: number?, align: Enum.HorizontalAlignment?): UIListLayout
	return M.new("UIListLayout", {
		FillDirection = dir or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = align or Enum.HorizontalAlignment.Left,
	})
end

function M.stroke(color: Color3?, t: number?): UIStroke
	return M.new("UIStroke", { Color = color or M.C.line, Thickness = t or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function M.label(props: { [string]: any }): TextLabel
	local base = {
		BackgroundTransparency = 1,
		Font = M.FONT,
		TextColor3 = M.C.text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		AutoLocalize = false,
		Size = UDim2.new(1, 0, 0, 20),
	}
	for k, v in props do
		base[k] = v
	end
	return M.new("TextLabel", base)
end

-- Кнопка. kind: "main" (акцент), "ok", "bad", "plain"
function M.button(text: string, kind: string?, props: { [string]: any }?, onClick: (() -> ())?): TextButton
	local color = M.C.panel2
	local tc = M.C.text
	if kind == "main" then
		color, tc = M.C.accent, Color3.fromRGB(35, 30, 20)
	elseif kind == "ok" then
		color = M.C.good
	elseif kind == "bad" then
		color = M.C.bad
	elseif kind == "blue" then
		color = M.C.blue
	end
	local base = {
		Text = text,
		BackgroundColor3 = color,
		TextColor3 = tc,
		Font = M.BOLD,
		TextSize = 16,
		AutoButtonColor = true,
		AutoLocalize = false,
		Size = UDim2.new(0, 120, 0, 40),
		TextWrapped = true,
	}
	if props then
		for k, v in props do
			base[k] = v
		end
	end
	local b = M.new("TextButton", base, { M.corner(10) })
	if onClick then
		b.Activated:Connect(onClick)
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

-- Корневой ScreenGui с масштабом под экран
function M.screen(name: string, order: number?): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = M.new("ScreenGui", {
		Name = name,
		ResetOnSpawn = false,
		IgnoreGuiInset = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		DisplayOrder = order or 0,
		AutoLocalize = false,
		Parent = pg,
	})
	local scale = M.new("UIScale", { Parent = gui })
	local function fit()
		local cam = workspace.CurrentCamera
		local v = if cam then cam.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(math.min(v.X / 1.6, v.Y) / 520, 0.7, 1.5)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	return gui
end

-- Модальное окно по центру с заголовком и крестиком. Возвращает (окно, тело, заголовок)
function M.window(parent: Instance, width: number, height: number): (Frame, Frame, TextLabel, TextButton)
	local win = M.frame({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, width, 0, height),
		BackgroundColor3 = M.C.bg,
		Visible = false,
		Parent = parent,
		ZIndex = 5,
	}, { M.corner(14), M.stroke(M.C.line, 1.5) })
	local title = M.label({
		Font = M.BOLD,
		TextSize = 20,
		Position = UDim2.new(0, 16, 0, 10),
		Size = UDim2.new(1, -70, 0, 28),
		Parent = win,
	})
	local close = M.button("✕", "plain", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 8),
		Size = UDim2.new(0, 38, 0, 34),
		Parent = win,
	})
	close.Activated:Connect(function()
		win.Visible = false
	end)
	local body = M.frame({
		BackgroundTransparency = 1,
		Position = UDim2.new(0, 14, 0, 50),
		Size = UDim2.new(1, -28, 1, -62),
		Parent = win,
	})
	return win, body, title, close
end

function M.pop(obj: GuiObject)
	local s = obj:FindFirstChildOfClass("UIScale") or M.new("UIScale", { Parent = obj })
	s.Scale = 0.9
	TweenService:Create(s, TweenInfo.new(0.15, Enum.EasingStyle.Back), { Scale = 1 }):Play()
end

function M.clear(frame: Instance)
	for _, c in frame:GetChildren() do
		if not c:IsA("UIListLayout") and not c:IsA("UIGridLayout") and not c:IsA("UIPadding") and not c:IsA("UICorner") then
			c:Destroy()
		end
	end
end

return M
