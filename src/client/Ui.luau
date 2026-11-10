--!nonstrict
-- Мини-кит интерфейса: токены, панели, кнопки, тексты, анимации нажатия.

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Assets = require(ReplicatedStorage.Shared.Assets)

local M = {}

M.FONT = Enum.Font.FredokaOne
M.C = {
	ink = Color3.fromRGB(43, 35, 80), -- обводка и основной текст
	panel = Color3.fromRGB(255, 249, 240),
	panel2 = Color3.fromRGB(244, 236, 226),
	muted = Color3.fromRGB(110, 102, 140),
	accent = Color3.fromRGB(255, 107, 61), -- только LAUNCH
	gold = Color3.fromRGB(255, 201, 60),
	good = Color3.fromRGB(60, 196, 106),
	off = Color3.fromRGB(190, 184, 200),
	white = Color3.fromRGB(255, 255, 255),
	power = Color3.fromRGB(120, 220, 255),
	rebirth = Color3.fromRGB(176, 120, 255),
}
M.RADIUS = UDim.new(0, 14)

function M.new(class: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(class)
	for k, v in props do
		if k ~= "Parent" then
			(inst :: any)[k] = v
		end
	end
	if children then
		for _, c in children do
			c.Parent = inst
		end
	end
	if props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

function M.corner(r: UDim?): UICorner
	return M.new("UICorner", { CornerRadius = r or M.RADIUS })
end

function M.stroke(th: number?, color: Color3?): UIStroke
	return M.new("UIStroke", { Thickness = th or 3, Color = color or M.C.ink, ApplyStrokeMode = Enum.ApplyStrokeMode.Border })
end

function M.textStroke(th: number?): UIStroke
	return M.new("UIStroke", { Thickness = th or 2.5, Color = M.C.ink })
end

function M.label(parent: Instance, text: string, size: number, props: { [string]: any }?): TextLabel
	local t = M.new("TextLabel", {
		BackgroundTransparency = 1,
		Font = M.FONT,
		Text = text,
		TextSize = size,
		TextColor3 = M.C.white,
		Size = UDim2.new(1, 0, 0, size + 6),
		Parent = parent,
	})
	if props then
		for k, v in props do
			(t :: any)[k] = v
		end
	end
	return t
end

-- Кнопка с откликом нажатия
function M.button(parent: Instance, props: { [string]: any }, onClick: () -> ()): TextButton
	local b = M.new("TextButton", {
		AutoButtonColor = false,
		Font = M.FONT,
		TextColor3 = M.C.white,
		TextSize = 22,
		BackgroundColor3 = M.C.white,
		Parent = parent,
	}, { M.corner(), M.stroke(3) })
	for k, v in props do
		(b :: any)[k] = v
	end
	local scale = M.new("UIScale", { Parent = b })
	local function to(s: number, t: number)
		TweenService:Create(scale, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = s }):Play()
	end
	b.MouseButton1Down:Connect(function()
		to(0.92, 0.08)
	end)
	b.MouseButton1Up:Connect(function()
		to(1, 0.15)
	end)
	b.MouseLeave:Connect(function()
		to(1, 0.15)
	end)
	b.Activated:Connect(function()
		M.sfx("click", 0.5)
		onClick()
	end)
	return b
end

function M.pop(gui: GuiObject, from: number?)
	local s = gui:FindFirstChildOfClass("UIScale") or M.new("UIScale", { Parent = gui })
	s.Scale = from or 0.6
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

function M.tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play()
	return tw
end

local soundCache: { [string]: Sound } = {}
function M.sfx(name: string, volume: number?, pitch: number?)
	local id = Assets.sfx[name]
	if not id or id == 0 then
		return
	end
	local s = soundCache[name]
	if not s then
		s = Instance.new("Sound")
		s.SoundId = "rbxassetid://" .. id
		s.Parent = SoundService
		soundCache[name] = s
	end
	s.Volume = volume or 0.6
	s.PlaybackSpeed = pitch or 1
	SoundService:PlayLocalSound(s)
end

return M
