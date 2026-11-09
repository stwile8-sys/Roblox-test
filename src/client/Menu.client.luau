-- Главное меню с пролётами камеры, настройки времени суток, телескоп и подписи мест.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local playerGui = player:WaitForChild("PlayerGui")

local state = "menu" -- menu | transition | play | telescope
local ready = ReplicatedStorage:GetAttribute("WorldReady") == true

-- ── управление персонажем ────────────────────────────────────

local controls = nil
task.spawn(function()
	local ok, module = pcall(function()
		return require(player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
	end)
	if ok and module then
		controls = module:GetControls()
		if state ~= "play" then
			controls:Disable()
		end
	end
end)

local function setControls(enabled: boolean)
	if controls then
		if enabled then
			controls:Enable()
		else
			controls:Disable()
		end
	end
end

-- ── помощники интерфейса ─────────────────────────────────────

local function new(className: string, props: { [string]: any }, children: { Instance }?): any
	local inst = Instance.new(className)
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
	inst.Parent = props.Parent
	return inst
end

local function corner(r: number)
	return new("UICorner", { CornerRadius = UDim.new(0, r) })
end

local function stroke(color: Color3, transparency: number, thickness: number?)
	return new("UIStroke", {
		Color = color,
		Transparency = transparency,
		Thickness = thickness or 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

local function tween(inst: Instance, time: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local t = TweenService:Create(inst, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
	t:Play()
	return t
end

local WHITE = Color3.new(1, 1, 1)
local WARM = Color3.fromRGB(255, 200, 140)
local DARK = Color3.fromRGB(18, 18, 22)

-- ── затемнение для переходов ─────────────────────────────────

local fadeGui = new("ScreenGui", { Name = "Fade", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 100, Parent = playerGui })
local fadeFrame = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0, Parent = fadeGui })

local function fade(to: number, time: number)
	local t = tween(fadeFrame, time, { BackgroundTransparency = 1 - to }, Enum.EasingStyle.Sine)
	t.Completed:Wait()
end

-- ── меню ─────────────────────────────────────────────────────

local menuGui = new("ScreenGui", { Name = "Menu", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 10, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Parent = playerGui })

new("Frame", {
	Size = UDim2.fromScale(0.7, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	Parent = menuGui,
}, {
	new("UIGradient", {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(0.55, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}),
})
new("Frame", {
	Size = UDim2.fromScale(1, 0.25),
	Position = UDim2.fromScale(0, 0.75),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BorderSizePixel = 0,
	Parent = menuGui,
}, {
	new("UIGradient", {
		Rotation = 90,
		Transparency = NumberSequence.new(1, 0.5),
	}),
})

local scale = new("UIScale", {})
local column = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 56, 0.5, 0),
	Size = UDim2.fromOffset(440, 470),
	BackgroundTransparency = 1,
	Parent = menuGui,
}, {
	scale,
	new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
})

new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Text = "Л О Б Б И",
	TextColor3 = WARM,
	Font = Enum.Font.BuilderSansBold,
	TextSize = 18,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = column,
})
new("TextLabel", {
	LayoutOrder = 2,
	Size = UDim2.new(1, 0, 0, 78),
	BackgroundTransparency = 1,
	Text = "ВЕРШИНА",
	TextColor3 = WHITE,
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 80,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = column,
}, {
	new("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(WHITE, Color3.fromRGB(255, 206, 150)),
	}),
})
new("TextLabel", {
	LayoutOrder = 3,
	Size = UDim2.new(1, 0, 0, 26),
	BackgroundTransparency = 1,
	Text = "Горы, лес и закат — всё построено кодом",
	TextColor3 = Color3.fromRGB(215, 210, 205),
	Font = Enum.Font.BuilderSans,
	TextSize = 21,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = column,
})
new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), BackgroundTransparency = 1, Parent = column })

local function makeButton(order: number, text: string, primary: boolean)
	local press = new("UIScale", {})
	local label = new("TextLabel", {
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromOffset(22, 0),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = primary and DARK or WHITE,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local button = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.fromOffset(320, 60),
		BackgroundColor3 = primary and WHITE or DARK,
		BackgroundTransparency = primary and 0 or 0.35,
		AutoButtonColor = false,
		Text = "",
		Parent = column,
	}, {
		corner(14),
		stroke(WHITE, primary and 1 or 0.75),
		press,
		label,
	})
	button.MouseButton1Down:Connect(function()
		tween(press, 0.08, { Scale = 0.95 })
	end)
	button.MouseButton1Up:Connect(function()
		tween(press, 0.15, { Scale = 1 }, Enum.EasingStyle.Back)
	end)
	button.MouseLeave:Connect(function()
		tween(press, 0.15, { Scale = 1 })
	end)
	button.MouseEnter:Connect(function()
		if not primary then
			tween(button, 0.15, { BackgroundTransparency = 0.15 })
		end
	end)
	button.MouseLeave:Connect(function()
		if not primary then
			tween(button, 0.15, { BackgroundTransparency = 0.35 })
		end
	end)
	return button, label
end

local playButton, playLabel = makeButton(5, "▶  ИГРАТЬ", true)
local settingsButton = makeButton(6, "НАСТРОЙКИ", false)
local aboutButton = makeButton(7, "ОБ ИГРЕ", false)

local loadingFrame = new("Frame", { LayoutOrder = 8, Size = UDim2.fromOffset(320, 44), BackgroundTransparency = 1, Parent = column })
local loadingLabel = new("TextLabel", {
	Size = UDim2.new(1, 0, 0, 22),
	BackgroundTransparency = 1,
	Text = "Строим горы… 0%",
	TextColor3 = Color3.fromRGB(220, 215, 210),
	Font = Enum.Font.BuilderSansMedium,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Left,
	Parent = loadingFrame,
})
local barBack = new("Frame", {
	Position = UDim2.fromOffset(0, 28),
	Size = UDim2.new(1, 0, 0, 6),
	BackgroundColor3 = WHITE,
	BackgroundTransparency = 0.8,
	Parent = loadingFrame,
}, { corner(3) })
local barFill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = WARM, Parent = barBack }, { corner(3) })

-- ── панели ───────────────────────────────────────────────────

local function panel(title: string, height: number)
	local panelScale = new("UIScale", {})
	local frame = new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -48, 0.5, 0),
		Size = UDim2.fromOffset(420, height),
		BackgroundColor3 = DARK,
		BackgroundTransparency = 0.15,
		Visible = false,
		Parent = menuGui,
	}, {
		corner(18),
		stroke(WHITE, 0.8),
		panelScale,
		new("UIPadding", {
			PaddingLeft = UDim.new(0, 24),
			PaddingRight = UDim.new(0, 24),
			PaddingTop = UDim.new(0, 20),
			PaddingBottom = UDim.new(0, 20),
		}),
		new("UIListLayout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	new("TextLabel", {
		LayoutOrder = 0,
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		Text = title,
		TextColor3 = WHITE,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 30,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	return frame, panelScale
end

local function caption(parent: Instance, order: number, text: string)
	new("TextLabel", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Text = text,
		TextColor3 = Color3.fromRGB(190, 185, 180),
		Font = Enum.Font.BuilderSansBold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = parent,
	})
end

local function segmented(parent: Instance, order: number, options: { string }, onPick: (string) -> ())
	local row = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, 0, 0, 44), BackgroundTransparency = 1, Parent = parent }, {
		new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }),
	})
	local buttons = {}
	local function highlight(name: string)
		for n, b in buttons do
			local on = n == name
			tween(b, 0.15, { BackgroundTransparency = on and 0 or 0.85 })
			b.TextColor3 = on and DARK or WHITE
		end
	end
	local width = 1 / #options
	for _, name in options do
		local b = new("TextButton", {
			Size = UDim2.new(width, -8 + 8 / #options, 1, 0),
			BackgroundColor3 = WHITE,
			BackgroundTransparency = 0.85,
			AutoButtonColor = false,
			Text = name,
			TextColor3 = WHITE,
			Font = Enum.Font.BuilderSansBold,
			TextSize = 18,
			Parent = row,
		}, { corner(10) })
		buttons[name] = b
		b.Activated:Connect(function()
			highlight(name)
			onPick(name)
		end)
	end
	return highlight
end

local settingsPanel, settingsScale = panel("Настройки", 330)
local aboutPanel, aboutScale = panel("Об игре", 300)

local function closeButton(parent: Instance, order: number, onClick: () -> ())
	local b = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 48),
		BackgroundColor3 = WHITE,
		AutoButtonColor = false,
		Text = "Готово",
		TextColor3 = DARK,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 21,
		Parent = parent,
	}, { corner(12) })
	b.Activated:Connect(onClick)
end

new("TextLabel", {
	LayoutOrder = 1,
	Size = UDim2.new(1, 0, 0, 150),
	BackgroundTransparency = 1,
	Text = "Демонстрационное лобби. Горы, озеро, лес, домик, костёр и телескоп — всё создаётся кодом при запуске сервера.\n\nСделано с телефона вместе с Claude.",
	TextColor3 = Color3.fromRGB(225, 220, 215),
	Font = Enum.Font.BuilderSans,
	TextSize = 19,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = aboutPanel,
})

-- ── время суток ──────────────────────────────────────────────

local PRESETS = {
	["Утро"] = {
		ClockTime = 7.1,
		Brightness = 2.2,
		OutdoorAmbient = Color3.fromRGB(132, 128, 142),
		ExposureCompensation = 0.15,
		atmosphere = { Density = 0.4, Offset = 0.1, Color = Color3.fromRGB(232, 204, 214), Decay = Color3.fromRGB(150, 140, 172), Glare = 0.3, Haze = 2.6 },
		color = { TintColor = Color3.fromRGB(250, 240, 246), Saturation = 0.05 },
		flies = 0,
	},
	["День"] = {
		ClockTime = 13,
		Brightness = 3,
		OutdoorAmbient = Color3.fromRGB(140, 140, 150),
		ExposureCompensation = 0,
		atmosphere = { Density = 0.26, Offset = 0.15, Color = Color3.fromRGB(205, 218, 235), Decay = Color3.fromRGB(100, 120, 150), Glare = 0, Haze = 1 },
		color = { TintColor = Color3.fromRGB(255, 255, 255), Saturation = 0.12 },
		flies = 0,
	},
	["Закат"] = {
		ClockTime = 17.4,
		Brightness = 2.6,
		OutdoorAmbient = Color3.fromRGB(128, 118, 128),
		ExposureCompensation = 0.1,
		atmosphere = { Density = 0.3, Offset = 0.2, Color = Color3.fromRGB(255, 212, 172), Decay = Color3.fromRGB(122, 108, 140), Glare = 0.55, Haze = 1.6 },
		color = { TintColor = Color3.fromRGB(255, 244, 232), Saturation = 0.14 },
		flies = 0,
	},
	["Ночь"] = {
		ClockTime = 22.5,
		Brightness = 1.2,
		OutdoorAmbient = Color3.fromRGB(70, 80, 115),
		ExposureCompensation = 0.4,
		atmosphere = { Density = 0.32, Offset = 0.05, Color = Color3.fromRGB(60, 72, 110), Decay = Color3.fromRGB(30, 36, 60), Glare = 0, Haze = 1.2 },
		color = { TintColor = Color3.fromRGB(215, 225, 255), Saturation = 0 },
		flies = 18,
	},
}

local function applyPreset(name: string)
	local p = PRESETS[name]
	if not p then
		return
	end
	tween(Lighting, 2.5, {
		ClockTime = p.ClockTime,
		Brightness = p.Brightness,
		OutdoorAmbient = p.OutdoorAmbient,
		ExposureCompensation = p.ExposureCompensation,
	}, Enum.EasingStyle.Sine)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere")
	if atm then
		tween(atm, 2.5, p.atmosphere, Enum.EasingStyle.Sine)
	end
	local cc = Lighting:FindFirstChild("ColorCorrection")
	if cc then
		tween(cc, 2.5, p.color, Enum.EasingStyle.Sine)
	end
	for _, emitter in CollectionService:GetTagged("Fireflies") do
		emitter.Rate = p.flies
	end
end

caption(settingsPanel, 1, "ВРЕМЯ СУТОК")
local highlightTime = segmented(settingsPanel, 2, { "Утро", "День", "Закат", "Ночь" }, applyPreset)
highlightTime("Закат")
caption(settingsPanel, 3, "ЭФФЕКТЫ (СВЕЧЕНИЕ, ЛУЧИ)")
local highlightFx = segmented(settingsPanel, 4, { "Вкл", "Выкл" }, function(choice)
	local on = choice == "Вкл"
	for _, name in { "Bloom", "SunRays" } do
		local e = Lighting:FindFirstChild(name)
		if e then
			(e :: any).Enabled = on
		end
	end
end)
highlightFx("Вкл")
new("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 6), BackgroundTransparency = 1, Parent = settingsPanel })

local function showPanel(p: Frame?)
	for _, other in { settingsPanel, aboutPanel } do
		if other ~= p then
			other.Visible = false
		end
	end
	if p then
		p.Visible = true
		p.Position = UDim2.new(1, 0, 0.5, 0)
		tween(p, 0.3, { Position = UDim2.new(1, -48, 0.5, 0) }, Enum.EasingStyle.Quint)
	end
end
closeButton(settingsPanel, 9, function()
	showPanel(nil)
end)
closeButton(aboutPanel, 9, function()
	showPanel(nil)
end)
settingsButton.Activated:Connect(function()
	if settingsPanel.Visible then
		showPanel(nil)
	else
		showPanel(settingsPanel)
	end
end)
aboutButton.Activated:Connect(function()
	if aboutPanel.Visible then
		showPanel(nil)
	else
		showPanel(aboutPanel)
	end
end)

-- ── экран игры (HUD) ─────────────────────────────────────────

local hudGui = new("ScreenGui", { Name = "Hud", ResetOnSpawn = false, DisplayOrder = 5, Enabled = false, Parent = playerGui })
local hudScale = new("UIScale", {})
local menuButton = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 10),
	Size = UDim2.fromOffset(52, 52),
	BackgroundColor3 = DARK,
	BackgroundTransparency = 0.35,
	AutoButtonColor = false,
	Text = "☰",
	TextColor3 = WHITE,
	Font = Enum.Font.BuilderSansBold,
	TextSize = 28,
	Parent = hudGui,
}, { corner(14), stroke(WHITE, 0.8), hudScale })

local zoneTitle = new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 70),
	Size = UDim2.fromOffset(600, 50),
	BackgroundTransparency = 1,
	Text = "",
	TextColor3 = WHITE,
	TextTransparency = 1,
	TextStrokeTransparency = 1,
	TextStrokeColor3 = Color3.new(0, 0, 0),
	Font = Enum.Font.BuilderSansExtraBold,
	TextSize = 40,
	Parent = hudGui,
})

-- телескоп
local teleGui = new("ScreenGui", { Name = "Telescope", IgnoreGuiInset = true, ResetOnSpawn = false, DisplayOrder = 20, Enabled = false, Parent = playerGui })
new("Frame", { Size = UDim2.fromScale(1, 0.12), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = teleGui })
new("Frame", { Size = UDim2.fromScale(1, 0.12), Position = UDim2.fromScale(0, 0.88), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Parent = teleGui })
new("TextLabel", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0.02, 0),
	Size = UDim2.new(1, 0, 0.08, 0),
	BackgroundTransparency = 1,
	Text = "Водите пальцем, чтобы осмотреться",
	TextColor3 = Color3.fromRGB(220, 215, 210),
	Font = Enum.Font.BuilderSansMedium,
	TextScaled = true,
	Parent = teleGui,
}, { new("UITextSizeConstraint", { MaxTextSize = 20 }) })
local teleBar = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.fromOffset(330, 52),
	BackgroundTransparency = 1,
	Parent = teleGui,
}, { new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center }) })
local function teleButton(text: string, width: number)
	return new("TextButton", {
		Size = UDim2.fromOffset(width, 52),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 0.1,
		AutoButtonColor = true,
		Text = text,
		TextColor3 = DARK,
		Font = Enum.Font.BuilderSansExtraBold,
		TextSize = 24,
		Parent = teleBar,
	}, { corner(12) })
end
local zoomOut = teleButton("−", 60)
local zoomIn = teleButton("+", 60)
local teleExit = teleButton("Выйти", 180)

-- масштаб интерфейса под экран
local function rescale()
	local h = camera.ViewportSize.Y
	local s = math.clamp(h / 720, 0.5, 1.2)
	scale.Scale = s
	settingsScale.Scale = s
	aboutScale.Scale = s
	hudScale.Scale = math.clamp(h / 600, 0.75, 1.2)
	column.Position = UDim2.new(0, math.floor(56 * s), 0.5, 0)
end
camera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
rescale()

-- ── загрузка мира ────────────────────────────────────────────

local function updateLoading()
	local p = ReplicatedStorage:GetAttribute("WorldProgress") or 0
	ready = ReplicatedStorage:GetAttribute("WorldReady") == true
	barFill.Size = UDim2.fromScale(p, 1)
	loadingLabel.Text = string.format("Строим горы и лес… %d%%", math.floor(p * 100))
	if ready then
		loadingFrame.Visible = false
		playLabel.Text = "▶  ИГРАТЬ"
		playButton.BackgroundTransparency = 0
	else
		playLabel.Text = "ЗАГРУЗКА…"
		playButton.BackgroundTransparency = 0.4
	end
end
ReplicatedStorage:GetAttributeChangedSignal("WorldProgress"):Connect(updateLoading)
ReplicatedStorage:GetAttributeChangedSignal("WorldReady"):Connect(updateLoading)
updateLoading()

-- ── пролёты камеры в меню ────────────────────────────────────

local shots = nil
local function buildShots(L: CFrame)
	local function w(x: number, y: number, z: number): Vector3
		return (L * CFrame.new(x, y, z)).Position
	end
	shots = {
		{ eye0 = w(40, 34, -160), eye1 = w(-40, 42, -150), at0 = w(0, 10, 0), at1 = w(0, 14, 0) },
		{ eye0 = w(-6, 8, -50), eye1 = w(6, 8, -52), at0 = w(-130, -70, -420), at1 = w(130, -70, -420) },
		{ eye0 = w(-34, 7, 8), eye1 = w(-30, 5, 2), at0 = w(-20, 2, -4), at1 = w(-20, 2.5, -4) },
		{ eye0 = w(-260, 150, 140), eye1 = w(-190, 140, 230), at0 = w(0, 0, -20), at1 = w(0, 0, 20) },
		{ eye0 = w(26, 6, -6), eye1 = w(12, 9, -14), at0 = w(0, 7, 30), at1 = w(0, 9, 30) },
	}
end
task.spawn(function()
	while not ReplicatedStorage:GetAttribute("LobbyCF") do
		ReplicatedStorage:GetAttributeChangedSignal("LobbyCF"):Wait()
	end
	buildShots(ReplicatedStorage:GetAttribute("LobbyCF"))
end)

local SHOT_TIME = 9
local shotIndex, shotStart = 1, os.clock()
local switching = false

local function ease(t: number): number
	return 0.5 - math.cos(math.clamp(t, 0, 1) * math.pi) / 2
end

RunService:BindToRenderStep("MenuCamera", Enum.RenderPriority.Camera.Value + 1, function()
	if state ~= "menu" or not shots then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 60
	local shot = shots[shotIndex]
	local t = (os.clock() - shotStart) / SHOT_TIME
	local e = ease(t)
	camera.CFrame = CFrame.lookAt(shot.eye0:Lerp(shot.eye1, e), shot.at0:Lerp(shot.at1, e))
	if t > 0.93 and not switching then
		switching = true
		task.spawn(function()
			fade(1, 0.6)
			shotIndex = shotIndex % #shots + 1
			shotStart = os.clock()
			switching = false
			if state == "menu" then
				fade(0, 0.8)
			end
		end)
	end
end)

-- ── переходы ─────────────────────────────────────────────────

local function startPlay()
	if state ~= "menu" or not ready then
		return
	end
	state = "transition"
	fade(1, 0.5)
	showPanel(nil)
	menuGui.Enabled = false
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = 70
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	setControls(true)
	hudGui.Enabled = true
	state = "play"
	fade(0, 0.7)
end

local function openMenu()
	if state ~= "play" then
		return
	end
	state = "transition"
	fade(1, 0.4)
	setControls(false)
	hudGui.Enabled = false
	menuGui.Enabled = true
	shotStart = os.clock()
	state = "menu"
	fade(0, 0.7)
end

playButton.Activated:Connect(function()
	task.spawn(startPlay)
end)
menuButton.Activated:Connect(function()
	task.spawn(openMenu)
end)

-- ── телескоп ─────────────────────────────────────────────────

local eyeCF = CFrame.new()
local yaw, pitch, fov = 0, 0, 30
local activePrompt: ProximityPrompt? = nil
local dragging = false

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name ~= "TelescopePrompt" or state ~= "play" then
		return
	end
	local tube = prompt.Parent
	local cf = tube and tube:GetAttribute("EyeCFrame")
	if typeof(cf) ~= "CFrame" then
		return
	end
	state = "transition"
	activePrompt = prompt
	prompt.Enabled = false
	setControls(false)
	fade(1, 0.35)
	eyeCF, yaw, pitch, fov = cf, 0, 0, 30
	hudGui.Enabled = false
	teleGui.Enabled = true
	camera.CameraType = Enum.CameraType.Scriptable
	state = "telescope"
	fade(0, 0.5)
end)

local function exitTelescope()
	if state ~= "telescope" then
		return
	end
	state = "transition"
	fade(1, 0.35)
	teleGui.Enabled = false
	camera.FieldOfView = 70
	camera.CameraType = Enum.CameraType.Custom
	if activePrompt then
		activePrompt.Enabled = true
	end
	setControls(true)
	hudGui.Enabled = true
	state = "play"
	fade(0, 0.5)
end
teleExit.Activated:Connect(function()
	task.spawn(exitTelescope)
end)
zoomIn.Activated:Connect(function()
	fov = math.max(8, fov - 6)
end)
zoomOut.Activated:Connect(function()
	fov = math.min(45, fov + 6)
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if state ~= "telescope" then
		return
	end
	local isTouch = input.UserInputType == Enum.UserInputType.Touch
	local isMouse = input.UserInputType == Enum.UserInputType.MouseMovement and dragging
	if isTouch or isMouse then
		local k = 0.004 * fov / 30
		yaw = math.clamp(yaw - input.Delta.X * k, -1.2, 1.2)
		pitch = math.clamp(pitch - input.Delta.Y * k, -0.6, 0.35)
	end
end)

RunService:BindToRenderStep("TelescopeCamera", Enum.RenderPriority.Camera.Value + 2, function()
	if state ~= "telescope" then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView += (fov - camera.FieldOfView) * 0.2
	camera.CFrame = eyeCF * CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end)

-- ── подписи мест ─────────────────────────────────────────────

local currentZone: string? = nil
local zoneToken = 0
local function showZone(name: string)
	zoneToken += 1
	local token = zoneToken
	zoneTitle.Text = name
	tween(zoneTitle, 0.6, { TextTransparency = 0, TextStrokeTransparency = 0.6 })
	task.delay(3, function()
		if token == zoneToken then
			tween(zoneTitle, 1, { TextTransparency = 1, TextStrokeTransparency = 1 })
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(0.3)
		if state == "play" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root then
				local found = nil
				for _, zone in CollectionService:GetTagged("Zone") do
					if zone:IsA("Model") then
						local r = zone:GetAttribute("ZoneRadius") or 10
						if (zone:GetPivot().Position - root.Position).Magnitude < r then
							found = zone:GetAttribute("ZoneName")
							break
						end
					end
				end
				if found ~= currentZone then
					currentZone = found
					if found then
						showZone(found)
					end
				end
			end
		end
	end
end)

-- после возрождения камера снова следит за персонажем
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid")
	if state == "play" then
		camera.CameraSubject = humanoid
	end
end)

-- первое появление меню
task.delay(0.5, function()
	fade(0, 1.2)
end)
