-- Интерфейс: номер этапа сверху и окно победы.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local finishEvent = ReplicatedStorage:WaitForChild("ObbyFinish") :: RemoteEvent
local restartEvent = ReplicatedStorage:WaitForChild("ObbyRestart") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "ObbyHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

-- плашка этапа
local stageLabel = Instance.new("TextLabel")
stageLabel.AnchorPoint = Vector2.new(0.5, 0)
stageLabel.Position = UDim2.new(0.5, 0, 0, 10)
stageLabel.Size = UDim2.fromOffset(220, 44)
stageLabel.BackgroundColor3 = Color3.new(0, 0, 0)
stageLabel.BackgroundTransparency = 0.4
stageLabel.TextColor3 = Color3.new(1, 1, 1)
stageLabel.Font = Enum.Font.BuilderSansBold
stageLabel.TextSize = 24
stageLabel.Parent = gui
corner(stageLabel, 12)

-- окно победы
local win = Instance.new("Frame")
win.AnchorPoint = Vector2.new(0.5, 0.5)
win.Position = UDim2.fromScale(0.5, 0.5)
win.Size = UDim2.fromOffset(300, 180)
win.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
win.Visible = false
win.Parent = gui
corner(win, 16)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 60)
title.BackgroundTransparency = 1
title.Text = "Победа!"
title.TextColor3 = Color3.fromRGB(255, 215, 0)
title.Font = Enum.Font.BuilderSansBold
title.TextSize = 36
title.Parent = win

local timeLabel = Instance.new("TextLabel")
timeLabel.Position = UDim2.fromOffset(0, 60)
timeLabel.Size = UDim2.new(1, 0, 0, 40)
timeLabel.BackgroundTransparency = 1
timeLabel.TextColor3 = Color3.new(1, 1, 1)
timeLabel.Font = Enum.Font.BuilderSans
timeLabel.TextSize = 22
timeLabel.Parent = win

local again = Instance.new("TextButton")
again.AnchorPoint = Vector2.new(0.5, 1)
again.Position = UDim2.new(0.5, 0, 1, -14)
again.Size = UDim2.fromOffset(220, 48)
again.BackgroundColor3 = Color3.fromRGB(60, 200, 90)
again.Text = "Пройти заново"
again.TextColor3 = Color3.new(1, 1, 1)
again.Font = Enum.Font.BuilderSansBold
again.TextSize = 22
again.Parent = win
corner(again, 12)

-- логика
local total = ReplicatedStorage:GetAttribute("TotalStages") or 0
local stage = player:WaitForChild("leaderstats"):WaitForChild("Этап") :: IntValue

local function refresh()
	if stage.Value >= total and total > 0 then
		stageLabel.Text = "Финиш!"
	else
		stageLabel.Text = string.format("Этап %d / %d", stage.Value, total)
	end
end
stage.Changed:Connect(refresh)
refresh()

finishEvent.OnClientEvent:Connect(function(seconds: number)
	local m = math.floor(seconds / 60)
	local s = math.floor(seconds % 60)
	timeLabel.Text = string.format("Время: %d:%02d", m, s)
	win.Visible = true
end)

again.Activated:Connect(function()
	win.Visible = false
	restartEvent:FireServer()
end)
