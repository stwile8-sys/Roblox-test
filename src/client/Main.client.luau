--!nonstrict
-- Интерфейс и связка с сервером. Телефон горизонтально — основной экран; ПК тоже работает.
-- Главный жест — кнопка LAUNCH справа внизу под большим пальцем. Остальное тихое.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local MarketplaceService = game:GetService("MarketplaceService")
local SoundService = game:GetService("SoundService")
local SocialService = game:GetService("SocialService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Assets = require(ReplicatedStorage.Shared.Assets)
local Fmt = require(ReplicatedStorage.Shared.Fmt)
local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Ui)
local Flight = require(script.Parent.Flight)

local player = Players.LocalPlayer
local C = Ui.C
local new = Ui.new

local act = Net.fn("Act")

local S: any = {
	power = 0,
	gain = 0,
	coins = 0,
	best = 0,
	runBest = 0,
	rebirths = 0,
	upg = { power = 0, coin = 0, bounce = 0 },
	boostLeft = 0,
	passes = {},
	gifts = {},
	session = 0,
	dailyReady = false,
	streak = 0,
	friends = 0,
	auto = false,
	ftue = 0,
	coinMult = 1,
	bounces = 0,
	launches = 0,
	flying = false,
	trails = { basic = true },
	trail = "basic",
	todayBest = 0,
	mod = { zone = 2, kind = "coins" },
	raceIn = 0,
	raceJoined = false,
}
local stateAt = os.clock()
local loaded = false

-- ===== корневой GUI =====

local gui = new("ScreenGui", {
	Name = "Hud",
	ResetOnSpawn = false,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = player:WaitForChild("PlayerGui"),
})
-- корневая рамка в «дизайн-пикселях»: UIScale растягивает и её размер, поэтому делим его на масштаб,
-- чтобы после масштабирования она ровно совпадала с экраном
local root = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = gui })
local scale = new("UIScale", { Parent = root })
local function rescale()
	local v = workspace.CurrentCamera.ViewportSize
	local k = math.clamp(math.min(v.X / 900, v.Y / 430), 0.62, 1.5)
	scale.Scale = k
	root.Size = UDim2.fromScale(1 / k, 1 / k)
end
rescale()
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)

local toastHolder

local function toast(text: string, kind: string?)
	if not toastHolder or text == "" then
		return
	end
	local col = if kind == "good" then C.good elseif kind == "big" then C.accent elseif kind == "bad" then Color3.fromRGB(230, 80, 80) else C.ink
	local f = new("Frame", {
		BackgroundColor3 = col,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 0, 38),
		Parent = toastHolder,
	}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(2.5, C.white), new("UIPadding", { PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18) }) })
	Ui.label(f, text, 20, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0) })
	Ui.pop(f, 0.7)
	task.delay(2.6, function()
		f:Destroy()
	end)
end

local function call(action: string, arg: any?): boolean
	local ok, res, msg = pcall(act.InvokeServer, act, action, arg)
	if not ok then
		return false
	end
	if msg then
		toast(msg, if res then "good" else "bad")
	end
	return res == true
end

local function power(): number
	return S.power + S.gain * math.min(os.clock() - stateAt, 1.5)
end

-- ===== верх: сила =====

local top = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.new(0, 360, 0, 100),
	BackgroundTransparency = 1,
	Parent = root,
})
local powerLbl = Ui.label(top, "⚡ 0", 46, { Size = UDim2.new(1, 0, 0, 52) })
Ui.textStroke(3).Parent = powerLbl
local gainLbl = Ui.label(top, "+1 power / sec", 20, { Position = UDim2.new(0, 0, 0, 50), TextColor3 = C.power })
Ui.textStroke(2).Parent = gainLbl
local extraLbl = Ui.label(top, "", 17, { Position = UDim2.new(0, 0, 0, 74), TextColor3 = C.gold })
Ui.textStroke(2).Parent = extraLbl

-- всплывающие «+N»
local function plusPopup(n: number)
	local l = Ui.label(top, "+" .. Fmt.num(n), 22, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5 + (math.random() - 0.5) * 0.5, 0, 0, 30),
		Size = UDim2.new(0, 120, 0, 26),
		TextColor3 = C.power,
		ZIndex = 2,
	})
	Ui.textStroke(2).Parent = l
	Ui.tween(l, 0.9, { Position = l.Position - UDim2.new(0, 0, 0, 40), TextTransparency = 1 })
	local st = l:FindFirstChildOfClass("UIStroke")
	if st then
		Ui.tween(st, 0.9, { Transparency = 1 })
	end
	task.delay(1, function()
		l:Destroy()
	end)
end

toastHolder = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104),
	Size = UDim2.new(0, 500, 0, 130),
	BackgroundTransparency = 1,
	Parent = root,
}, { new("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }) })

-- ===== слева сверху: монеты и рекорд =====

local coinPill = new("Frame", {
	Position = UDim2.new(0, 12, 0, 10),
	Size = UDim2.new(0, 170, 0, 42),
	BackgroundColor3 = C.panel,
	Parent = root,
}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(3) })
local coinLbl = Ui.label(coinPill, "🪙 0", 24, { Size = UDim2.fromScale(1, 1), TextColor3 = C.ink })
local bestLbl = Ui.label(root, "🏁 Best 0m", 18, { Position = UDim2.new(0, 14, 0, 56), Size = UDim2.new(0, 220, 0, 22), TextXAlignment = Enum.TextXAlignment.Left })
Ui.textStroke(2).Parent = bestLbl
local modLbl = Ui.label(root, "", 16, { Position = UDim2.new(0, 14, 0, 78), Size = UDim2.new(0, 300, 0, 20), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.gold })
Ui.textStroke(2).Parent = modLbl

-- ===== слева: меню =====

local menu = new("Frame", {
	AnchorPoint = Vector2.new(0, 0.5),
	Position = UDim2.new(0, 12, 0.55, 0),
	Size = UDim2.new(0, 76, 0, 330),
	BackgroundTransparency = 1,
	Parent = root,
}, { new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Center }) })

local windows: { [string]: Frame } = {}
local openWindow: (string) -> ()

local function menuButton(order: number, icon: string, text: string, onClick: () -> ()): (TextButton, TextLabel)
	local b = Ui.button(menu, {
		Size = UDim2.new(0, 72, 0, 58),
		BackgroundColor3 = C.panel,
		Text = "",
		LayoutOrder = order,
	}, onClick)
	Ui.label(b, icon, 26, { Position = UDim2.new(0, 0, 0, 3), Size = UDim2.new(1, 0, 0, 30) })
	Ui.label(b, text, 14, { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 18), TextColor3 = C.ink })
	local badge = Ui.label(b, "", 14, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 8, 0, -8),
		Size = UDim2.new(0, 0, 0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = C.accent,
		BackgroundTransparency = 0,
		Visible = false,
		ZIndex = 3,
	})
	Ui.corner(UDim.new(1, 0)).Parent = badge
	new("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7), Parent = badge })
	return b, badge
end

local upgBtn, upgBadge = menuButton(1, "⬆️", "Upgrade", function()
	openWindow("upgrades")
end)
local giftBtn, giftBadge = menuButton(2, "🎁", "Gifts", function()
	openWindow("gifts")
end)
local rebBtn, rebBadge = menuButton(3, "🔁", "Rebirth", function()
	openWindow("rebirth")
end)
local _shopBtn = menuButton(4, "🛒", "Shop", function()
	openWindow("shop")
end)
local _trailBtn = menuButton(5, "🌈", "Trails", function()
	openWindow("trails")
end)

-- ===== LAUNCH =====

local launchBtn: TextButton
local raceCard: Frame
launchBtn = Ui.button(root, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -28, 1, -24),
	Size = UDim2.new(0, 156, 0, 156),
	BackgroundColor3 = C.accent,
	Text = "",
}, function()
	if Flight.active or S.flying then
		return
	end
	if S.raceJoined and raceCard.Visible then
		toast("Wait for the race start! 🏁")
		return
	end
	if S.ftue < 1 then
		S.ftue = 1
		task.spawn(call, "ftue", 1)
	end
	task.spawn(call, "launch")
end)
;(launchBtn:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)
;(launchBtn:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 5
Ui.label(launchBtn, "🚀", 44, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 50) })
local launchTxt = Ui.label(launchBtn, "LAUNCH", 32, { Position = UDim2.new(0, 0, 0, 78), Size = UDim2.new(1, 0, 0, 36) })
Ui.textStroke(3).Parent = launchTxt
local launchSub = Ui.label(launchBtn, "", 16, { Position = UDim2.new(0, 0, 0, 112), Size = UDim2.new(1, 0, 0, 20) })
Ui.textStroke(2).Parent = launchSub

local launchScale = launchBtn:FindFirstChildOfClass("UIScale")

local autoBtn = Ui.button(root, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -196, 1, -28),
	Size = UDim2.new(0, 120, 0, 44),
	BackgroundColor3 = C.panel,
	TextColor3 = C.ink,
	TextSize = 18,
	Text = "AUTO 🔒",
}, function()
	if S.passes.AutoLaunch then
		task.spawn(call, "auto", not S.auto)
		S.auto = not S.auto
	else
		local id = Assets.passes.AutoLaunch
		if id > 0 then
			MarketplaceService:PromptGamePassPurchase(player, id)
		else
			toast("Auto Launch is coming soon!")
		end
	end
end)
;(autoBtn:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)

local nearest: Player? = nil
local tandemBtn = Ui.button(root, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -196, 1, -82),
	Size = UDim2.new(0, 120, 0, 44),
	BackgroundColor3 = Color3.fromRGB(120, 200, 255),
	TextSize = 18,
	Text = "🤝 TANDEM",
	Visible = false,
}, function()
	local target = nearest
	if target then
		call("tandemAsk", target.UserId)
	end
end)
;(tandemBtn:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)

local inviteBtn = Ui.button(root, {
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -28, 1, -192),
	Size = UDim2.new(0, 156, 0, 44),
	BackgroundColor3 = C.panel,
	TextColor3 = C.ink,
	TextSize = 18,
	Text = "👥 Invite: 2x",
}, function()
	task.spawn(call, "invite")
	pcall(function()
		local opts = Instance.new("ExperienceInviteOptions")
		opts.PromptMessage = "Invite a friend: you both get 2x Power!"
		SocialService:PromptGameInvite(player, opts)
	end)
end)
;(inviteBtn:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)

-- приглашение в тандем
local askCard = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -24),
	Size = UDim2.new(0, 380, 0, 70),
	BackgroundColor3 = C.panel,
	Visible = false,
	ZIndex = 8,
	Parent = root,
}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(3) })
local askLbl = Ui.label(askCard, "", 19, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -150, 1, 0), TextColor3 = C.ink, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 9 })
local askFrom = 0
local askToken = 0
local askBtn = Ui.button(askCard, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -10, 0.5, 0),
	Size = UDim2.new(0, 120, 0, 50),
	BackgroundColor3 = C.good,
	Text = "FLY! 🤝",
	TextSize = 20,
	ZIndex = 9,
}, function()
	askCard.Visible = false
	call("tandemAccept", askFrom)
end)
local _ = askBtn

-- гонка
raceCard = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 108),
	Size = UDim2.new(0, 360, 0, 64),
	BackgroundColor3 = C.ink,
	Visible = false,
	ZIndex = 8,
	Parent = root,
}, { Ui.corner(UDim.new(0, 18)), Ui.stroke(3, C.gold) })
local raceLbl = Ui.label(raceCard, "", 20, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(1, -150, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 9 })
local raceEnd = 0
local raceBtn = Ui.button(raceCard, {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -8, 0.5, 0),
	Size = UDim2.new(0, 120, 0, 48),
	BackgroundColor3 = C.good,
	Text = "JOIN 🏁",
	TextSize = 20,
	ZIndex = 9,
}, function()
	if call("race") then
		S.raceJoined = true
	end
end)

-- подсказки обучения
local hint = Ui.label(root, "", 24, {
	AnchorPoint = Vector2.new(1, 0.5),
	Size = UDim2.new(0, 260, 0, 30),
	TextXAlignment = Enum.TextXAlignment.Right,
	TextColor3 = C.gold,
	Visible = false,
	ZIndex = 5,
})
Ui.textStroke(3).Parent = hint
local hintBase = UDim2.new()
task.spawn(function()
	local t = 0
	while true do
		t += 0.05
		if hint.Visible then
			hint.Position = hintBase + UDim2.new(0, math.sin(t * 6) * 8, 0, 0)
		end
		task.wait(0.03)
	end
end)

-- ===== полёт: верхний счётчик и итог =====

local flyBox = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 4),
	Size = UDim2.new(0, 420, 0, 110),
	BackgroundTransparency = 1,
	Visible = false,
	Parent = root,
})
local distLbl = Ui.label(flyBox, "0m", 56, { Size = UDim2.new(1, 0, 0, 60) })
Ui.textStroke(3.5).Parent = distLbl
local zoneLbl = Ui.label(flyBox, "", 20, { Position = UDim2.new(0, 0, 0, 58) })
Ui.textStroke(2).Parent = zoneLbl
local ringLbl = Ui.label(flyBox, "", 20, { Position = UDim2.new(0, 0, 0, 82), TextColor3 = C.gold })
Ui.textStroke(2).Parent = ringLbl

local steerHint = Ui.label(root, "◀  steer to catch golden rings  ▶", 22, {
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -30),
	Size = UDim2.new(0, 500, 0, 28),
	Visible = false,
})
Ui.textStroke(2.5).Parent = steerHint

local banner = Ui.label(root, "", 40, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.42, 0),
	Size = UDim2.new(0, 700, 0, 46),
	Visible = false,
	ZIndex = 4,
})
Ui.textStroke(3.5).Parent = banner
local bannerSub = Ui.label(banner, "", 22, { Position = UDim2.new(0, 0, 1, 2), Size = UDim2.new(1, 0, 0, 26), TextColor3 = C.gold })
Ui.textStroke(2.5).Parent = bannerSub
local bannerToken = 0
local function showBanner(text: string, sub: string, hold: number?)
	bannerToken += 1
	local my = bannerToken
	banner.Text = text
	bannerSub.Text = sub
	banner.Visible = true
	Ui.pop(banner, 0.4)
	task.delay(hold or 2, function()
		if bannerToken == my then
			banner.Visible = false
		end
	end)
end

local resultCard = new("Frame", {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0.5, 0),
	Size = UDim2.new(0, 320, 0, 170),
	BackgroundColor3 = C.panel,
	Visible = false,
	ZIndex = 6,
	Parent = root,
}, { Ui.corner(UDim.new(0, 22)), Ui.stroke(4) })
local resBest = Ui.label(resultCard, "NEW BEST!", 18, {
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(0, 140, 0, 30),
	BackgroundColor3 = C.gold,
	BackgroundTransparency = 0,
	TextColor3 = C.ink,
	ZIndex = 7,
})
Ui.corner(UDim.new(1, 0)).Parent = resBest
Ui.stroke(3).Parent = resBest
local resDist = Ui.label(resultCard, "0m", 50, { Position = UDim2.new(0, 0, 0, 22), Size = UDim2.new(1, 0, 0, 56), TextColor3 = C.ink, ZIndex = 7 })
local resCoins = Ui.label(resultCard, "+0 🪙", 30, { Position = UDim2.new(0, 0, 0, 82), Size = UDim2.new(1, 0, 0, 36), TextColor3 = Color3.fromRGB(214, 150, 0), ZIndex = 7 })
local resNote = Ui.label(resultCard, "", 17, { Position = UDim2.new(0, 0, 0, 124), Size = UDim2.new(1, 0, 0, 34), TextColor3 = C.muted, TextWrapped = true, ZIndex = 7 })

-- ===== окна =====

local dim = new("TextButton", {
	Text = "",
	AutoButtonColor = false,
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.5,
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	ZIndex = 10,
	Parent = root,
})

local function window(name: string, title: string): (Frame, ScrollingFrame)
	local w = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 540, 0, 360),
		BackgroundColor3 = C.panel,
		Visible = false,
		ZIndex = 11,
		Parent = root,
	}, { Ui.corner(UDim.new(0, 22)), Ui.stroke(4) })
	Ui.label(w, title, 30, { Position = UDim2.new(0, 22, 0, 12), Size = UDim2.new(1, -90, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.ink, ZIndex = 12 })
	local close = Ui.button(w, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 10),
		Size = UDim2.new(0, 44, 0, 44),
		BackgroundColor3 = Color3.fromRGB(240, 90, 90),
		Text = "✕",
		TextSize = 24,
		ZIndex = 12,
	}, function()
		openWindow("")
	end)
	;(close:FindFirstChildOfClass("UICorner") :: UICorner).CornerRadius = UDim.new(1, 0)
	local list = new("ScrollingFrame", {
		Position = UDim2.new(0, 14, 0, 60),
		Size = UDim2.new(1, -28, 1, -74),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.muted,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 12,
		Parent = w,
	}, {
		new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder }),
		new("UIPadding", { PaddingRight = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8), PaddingLeft = UDim.new(0, 4) }),
	})
	windows[name] = w
	return w, list
end

local current = ""
local refreshers: { [string]: () -> () } = {}
openWindow = function(name: string)
	for n, w in windows do
		w.Visible = n == name
	end
	current = name
	dim.Visible = name ~= ""
	local w = windows[name]
	if w then
		Ui.pop(w, 0.85)
		local r = refreshers[name]
		if r then
			r()
		end
	end
end
dim.Activated:Connect(function()
	openWindow("")
end)

local function row(list: Instance, order: number, h: number?): Frame
	return new("Frame", {
		Size = UDim2.new(1, 0, 0, h or 76),
		BackgroundColor3 = C.white,
		LayoutOrder = order,
		ZIndex = 12,
		Parent = list,
	}, { Ui.corner(), Ui.stroke(2.5) })
end

local function rowText(r: Frame, title: string, sub: string): (TextLabel, TextLabel)
	local a = Ui.label(r, title, 22, { Position = UDim2.new(0, 14, 0, 8), Size = UDim2.new(1, -170, 0, 28), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.ink, ZIndex = 13 })
	local b = Ui.label(r, sub, 16, { Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -170, 0, 30), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.muted, TextWrapped = true, ZIndex = 13 })
	return a, b
end

local function rowButton(r: Frame, text: string, onClick: () -> ()): TextButton
	return Ui.button(r, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0, 140, 0, 50),
		BackgroundColor3 = C.good,
		Text = text,
		TextSize = 20,
		ZIndex = 13,
	}, onClick)
end

-- Улучшения
do
	local _, list = window("upgrades", "Upgrades")
	local items = {}
	for i, u in Config.UPGRADES do
		local r = row(list, i)
		local title, sub = rowText(r, u.name, u.desc)
		local btn = rowButton(r, "", function()
			if call("upgrade", u.id) then
				Ui.sfx("upgrade", 0.7)
			end
		end)
		items[u.id] = { title = title, sub = sub, btn = btn, u = u }
	end
	refreshers.upgrades = function()
		for id, it in items do
			local lvl = S.upg[id] or 0
			it.title.Text = string.format("%s  ·  Lv %d", it.u.name, lvl)
			if lvl >= it.u.max then
				it.btn.Text = "MAX"
				it.btn.BackgroundColor3 = C.off
			else
				local cost = Config.upgradeCost(it.u, lvl)
				it.btn.Text = "🪙 " .. Fmt.num(cost)
				it.btn.BackgroundColor3 = if S.coins >= cost then C.good else C.off
			end
		end
	end
end

-- Перерождение
do
	local _, list = window("rebirth", "Rebirth")
	local r = row(list, 1, 120)
	local title, sub = rowText(r, "", "")
	sub.Size = UDim2.new(1, -170, 0, 70)
	local btn = rowButton(r, "REBIRTH", function()
		if call("rebirth") then
			Ui.sfx("rebirth", 0.8)
			openWindow("")
			showBanner("REBIRTH #" .. S.rebirths + 1 .. "!", "Power grows faster forever", 2.5)
		end
	end)
	btn.BackgroundColor3 = C.rebirth
	local r2 = row(list, 2, 70)
	rowText(r2, "Resets", "Power, coins, Power Gain and Coin Magnet. Bounces and your best distance stay.")
	refreshers.rebirth = function()
		local need = Config.rebirthZone(S.rebirths)
		local zone = Config.ZONES[need]
		local ready = Config.zoneAt(S.runBest) >= need
		title.Text = string.format("Rebirths: %d", S.rebirths)
		sub.Text = string.format(
			"Reward: +%d%% power gain and +%d%% coins forever.\nNeed: reach %s (%s). Now: %s",
			math.floor(Config.REBIRTH_POWER * 100),
			math.floor(Config.REBIRTH_COINS * 100),
			zone.name,
			Fmt.dist(zone.from),
			Fmt.dist(S.runBest)
		)
		btn.BackgroundColor3 = if ready then C.rebirth else C.off
	end
end

-- Подарки, ежедневка, коды
local giftItems = {}
do
	local _, list = window("gifts", "Gifts")
	local dr = row(list, 0, 76)
	local dTitle, dSub = rowText(dr, "Daily reward", "")
	local dBtn = rowButton(dr, "CLAIM", function()
		if call("daily") then
			Ui.sfx("buy", 0.7)
		end
	end)
	local grid = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		ZIndex = 12,
		Parent = list,
	}, { new("UIGridLayout", { CellSize = UDim2.new(0, 152, 0, 92), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local icons = { power = "⚡", coins = "🪙", boost = "⏱️" }
	for i, g in Config.GIFTS do
		local cell = Ui.button(grid, {
			BackgroundColor3 = C.white,
			Text = "",
			LayoutOrder = i,
			ZIndex = 13,
		}, function()
			if call("gift", i) then
				Ui.sfx("buy", 0.7)
			end
		end)
		;(cell:FindFirstChildOfClass("UIStroke") :: UIStroke).Thickness = 2.5
		Ui.label(cell, icons[g.kind] or "🎁", 30, { Position = UDim2.new(0, 0, 0, 6), Size = UDim2.new(1, 0, 0, 34), ZIndex = 14 })
		local what = if g.kind == "boost" then "2x " .. g.amount .. " min" elseif g.kind == "power" then "Power" else "Coins"
		Ui.label(cell, what, 16, { Position = UDim2.new(0, 0, 0, 40), Size = UDim2.new(1, 0, 0, 20), TextColor3 = C.ink, ZIndex = 14 })
		local timer = Ui.label(cell, "", 17, { Position = UDim2.new(0, 0, 0, 62), Size = UDim2.new(1, 0, 0, 22), TextColor3 = C.muted, ZIndex = 14 })
		giftItems[i] = { cell = cell, timer = timer, g = g }
	end
	local cr = row(list, 2, 76)
	Ui.label(cr, "Code", 22, { Position = UDim2.new(0, 14, 0, 0), Size = UDim2.new(0, 70, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, TextColor3 = C.ink, ZIndex = 13 })
	local box = new("TextBox", {
		Position = UDim2.new(0, 84, 0.5, -24),
		Size = UDim2.new(1, -250, 0, 48),
		BackgroundColor3 = C.panel2,
		Font = Ui.FONT,
		TextSize = 22,
		TextColor3 = C.ink,
		PlaceholderText = "LAUNCH",
		PlaceholderColor3 = C.muted,
		Text = "",
		ClearTextOnFocus = false,
		ZIndex = 13,
		Parent = cr,
	}, { Ui.corner(), Ui.stroke(2) })
	rowButton(cr, "REDEEM", function()
		if call("code", box.Text) then
			Ui.sfx("buy", 0.7)
			box.Text = ""
		end
	end)
	refreshers.gifts = function()
		dTitle.Text = "Daily reward  ·  streak " .. S.streak
		dSub.Text = if S.dailyReady then "Ready! Come back every day for bigger rewards." else "Claimed today. Come back tomorrow!"
		dBtn.BackgroundColor3 = if S.dailyReady then C.good else C.off
		dBtn.Text = if S.dailyReady then "CLAIM" else "✓"
	end
end

-- Магазин
do
	local _, list = window("shop", "Shop")
	local any = false
	local passRows = {}
	for i, p in Config.PASSES do
		local id = Assets.passes[p.id]
		if id and id > 0 then
			any = true
			local r = row(list, i)
			rowText(r, p.name, p.desc)
			local btn = rowButton(r, "R$ " .. p.price, function()
				if not S.passes[p.id] then
					MarketplaceService:PromptGamePassPurchase(player, id)
				end
			end)
			passRows[p.id] = btn
		end
	end
	for i, p in Config.PRODUCTS do
		local id = Assets.products[p.id]
		if id and id > 0 then
			any = true
			local r = row(list, 100 + i)
			rowText(r, p.name, p.desc)
			rowButton(r, "R$ " .. p.price, function()
				MarketplaceService:PromptProductPurchase(player, id)
			end)
		end
	end
	if not any then
		local r = row(list, 1, 90)
		rowText(r, "Shop opens soon!", "New items are on the way.")
	end
	refreshers.shop = function()
		for pid, btn in passRows do
			if S.passes[pid] then
				btn.Text = "OWNED ✓"
				btn.BackgroundColor3 = C.off
			end
		end
	end
end

-- Следы полёта
do
	local _, list = window("trails", "Trails")
	local grid = new("Frame", {
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ZIndex = 12,
		Parent = list,
	}, { new("UIGridLayout", { CellSize = UDim2.new(0, 152, 0, 104), CellPadding = UDim2.new(0, 10, 0, 10), SortOrder = Enum.SortOrder.LayoutOrder }) })
	local cells = {}
	for i, t in Config.TRAILS do
		local cell = Ui.button(grid, { BackgroundColor3 = C.white, Text = "", LayoutOrder = i, ZIndex = 13 }, function()
			if S.trails[t.id] then
				call("trail", t.id)
				S.trail = t.id
			else
				toast(t.how)
			end
		end)
		local sw = new("Frame", {
			Position = UDim2.new(0.5, -50, 0, 10),
			Size = UDim2.new(0, 100, 0, 22),
			BackgroundColor3 = Color3.new(1, 1, 1),
			ZIndex = 14,
			Parent = cell,
		}, { Ui.corner(UDim.new(1, 0)), Ui.stroke(2), new("UIGradient", { Color = ColorSequence.new(t.a, t.b) }) })
		local _ = sw
		Ui.label(cell, t.name, 17, { Position = UDim2.new(0, 0, 0, 38), Size = UDim2.new(1, 0, 0, 22), TextColor3 = C.ink, ZIndex = 14 })
		local state = Ui.label(cell, "", 14, { Position = UDim2.new(0, 6, 0, 62), Size = UDim2.new(1, -12, 0, 36), TextColor3 = C.muted, TextWrapped = true, ZIndex = 14 })
		cells[t.id] = { cell = cell, state = state, t = t }
	end
	refreshers.trails = function()
		for id, c in cells do
			if S.trail == id then
				c.state.Text = "✓ equipped"
				c.state.TextColor3 = C.good
				c.cell.BackgroundColor3 = Color3.fromRGB(230, 255, 236)
			elseif S.trails[id] then
				c.state.Text = "Tap to equip"
				c.state.TextColor3 = C.ink
				c.cell.BackgroundColor3 = C.white
			else
				c.state.Text = "🔒 " .. c.t.how
				c.state.TextColor3 = C.muted
				c.cell.BackgroundColor3 = C.panel2
			end
		end
	end
end

-- ===== обновление HUD =====

local function nextGift(): (number?, number)
	for i, g in Config.GIFTS do
		if not table.find(S.gifts, i) then
			return i, g.min * 60 - (S.session + (os.clock() - stateAt))
		end
	end
	return nil, 0
end

local function cheapestUpgrade(): number
	local m = math.huge
	for _, u in Config.UPGRADES do
		local lvl = S.upg[u.id] or 0
		if lvl < u.max then
			m = math.min(m, Config.upgradeCost(u, lvl))
		end
	end
	return m
end

local function refreshHud()
	local flying = Flight.active or S.flying
	top.Visible = not flying
	flyBox.Visible = flying
	launchBtn.Visible = not flying
	autoBtn.Visible = not flying
	menu.Visible = not flying
	inviteBtn.Visible = not flying
	-- ближайший игрок для тандема
	nearest = nil
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and not flying then
		local bestD = Config.TANDEM_RANGE
		for _, o in Players:GetPlayers() do
			local r = o ~= player and o.Character and o.Character:FindFirstChild("HumanoidRootPart")
			if r and r:IsA("BasePart") then
				local dd = (r.Position - (myRoot :: BasePart).Position).Magnitude
				if dd < bestD then
					bestD = dd
					nearest = o
				end
			end
		end
	end
	tandemBtn.Visible = nearest ~= nil
	local mz = Config.ZONES[S.mod.zone]
	modLbl.Text = if mz then (if S.mod.kind == "coins" then "🌟 Today: x2 coins in " else "🌟 Today: double rings in ") .. mz.name else ""
	if raceCard.Visible and raceEnd > 0 then
		local left = math.max(0, raceEnd - os.clock())
		raceLbl.Text = if S.raceJoined then string.format("🏁 You're in! Race in %ds", math.ceil(left)) else string.format("🏁 RACE in %ds — most rings wins!", math.ceil(left))
		raceBtn.Visible = not S.raceJoined
	end
	powerLbl.Text = "⚡ " .. Fmt.num(power())
	gainLbl.Text = "+" .. Fmt.num(S.gain) .. " power / sec"
	local extras = {}
	if S.raceIn > 0 then
		local left = S.raceIn - (os.clock() - stateAt)
		if left > 0 and left < 120 then
			table.insert(extras, "🏁 race " .. Fmt.time(left))
		end
	end
	if S.boostLeft > 0 then
		table.insert(extras, "2x ⏱ " .. Fmt.time(S.boostLeft - (os.clock() - stateAt)))
	end
	if S.friends > 0 then
		table.insert(extras, "👥 +" .. math.floor(S.friends * Config.FRIEND_BOOST * 100) .. "%")
	end
	extraLbl.Text = table.concat(extras, "   ")
	coinLbl.Text = "🪙 " .. Fmt.num(S.coins)
	bestLbl.Text = "🏁 Best " .. Fmt.dist(S.best)
	launchSub.Text = "≈ " .. Fmt.dist(Config.firstArc(power()))
	-- кнопка авто
	if S.passes.AutoLaunch then
		autoBtn.Text = if S.auto then "AUTO: ON" else "AUTO: OFF"
		autoBtn.BackgroundColor3 = if S.auto then C.good else C.panel
		autoBtn.TextColor3 = if S.auto then C.white else C.ink
	end
	-- значки
	local cheap = cheapestUpgrade()
	upgBadge.Visible = S.coins >= cheap
	upgBadge.Text = "!"
	local gi, left = nextGift()
	local readyCount = 0
	for i, g in Config.GIFTS do
		if not table.find(S.gifts, i) and g.min * 60 <= S.session + (os.clock() - stateAt) then
			readyCount += 1
		end
	end
	if S.dailyReady then
		readyCount += 1
	end
	giftBadge.Visible = readyCount > 0 or gi ~= nil
	giftBadge.Text = if readyCount > 0 then tostring(readyCount) elseif gi then Fmt.time(left) else ""
	giftBadge.BackgroundColor3 = if readyCount > 0 then C.accent else C.ink
	rebBadge.Visible = Config.zoneAt(S.runBest) >= Config.rebirthZone(S.rebirths)
	rebBadge.Text = "!"
	-- окно подарков: таймеры
	if current == "gifts" then
		for i, it in giftItems do
			local claimed = table.find(S.gifts, i) ~= nil
			local wait = it.g.min * 60 - (S.session + (os.clock() - stateAt))
			if claimed then
				it.timer.Text = "✓ claimed"
				it.cell.BackgroundColor3 = C.panel2
			elseif wait <= 0 then
				it.timer.Text = "CLAIM!"
				it.timer.TextColor3 = C.good
				it.cell.BackgroundColor3 = Color3.fromRGB(230, 255, 236)
			else
				it.timer.Text = Fmt.time(wait)
				it.timer.TextColor3 = C.muted
				it.cell.BackgroundColor3 = C.white
			end
		end
	end
	local r = refreshers[current]
	if r and current ~= "gifts" then
		r()
	elseif current == "gifts" then
		refreshers.gifts()
	end
	-- обучение
	if not flying and loaded then
		if S.ftue < 1 and S.launches == 0 then
			hint.Visible = true
			hint.Text = "TAP TO LAUNCH! 👉"
			hint.AnchorPoint = Vector2.new(1, 0.5)
			hint.TextXAlignment = Enum.TextXAlignment.Right
			hintBase = UDim2.new(1, -196, 1, -100)
		elseif S.ftue < 2 and S.coins >= cheap then
			hint.Visible = true
			hint.Text = "👈 UPGRADE!"
			hint.AnchorPoint = Vector2.new(0, 0.5)
			hint.TextXAlignment = Enum.TextXAlignment.Left
			local p = upgBtn.AbsolutePosition
			local s = upgBtn.AbsoluteSize
			local k = scale.Scale
			hintBase = UDim2.new(0, (p.X + s.X) / k + 14, 0, (p.Y + s.Y / 2) / k)
		else
			hint.Visible = false
		end
	else
		hint.Visible = false
	end
	if flying then
		distLbl.Text = Fmt.dist(Flight.dist)
		local zi = Config.zoneAt(Flight.dist)
		local z = Config.ZONES[zi]
		zoneLbl.Text = string.format("%s  ·  x%s coins", z.name, tostring(z.mult))
		ringLbl.Text = if Flight.rings > 0 then string.format("+%d%% 🪙  (%d rings)", math.floor(Flight.rings * Config.RING_BONUS * 100), Flight.rings) else ""
	end
end

local lastPowerInt = 0
RunService.RenderStepped:Connect(function()
	refreshHud()
end)

-- ===== события сервера =====

Net.event("State").OnClientEvent:Connect(function(st)
	local before = S.power
	for k, v in st do
		S[k] = v
	end
	stateAt = os.clock()
	if loaded and st.power > before and not Flight.active then
		local add = st.power - before
		if add > 0 and add < st.gain * 3 + 1 then
			plusPopup(add)
		end
	end
	if not loaded then
		loaded = true
		-- самый первый вход: летим сами через 2 секунды, без единого нажатия
		if S.launches == 0 then
			task.spawn(function()
				task.wait(2)
				for _ = 1, 8 do
					if S.launches > 0 or Flight.active or S.flying then
						break
					end
					if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
						call("launch")
					end
					task.wait(1.5)
				end
			end)
		end
		if S.dailyReady then
			task.delay(2, function()
				if S.dailyReady and S.launches > 0 then
					openWindow("gifts")
				end
			end)
		end
	end
	lastPowerInt = math.floor(S.power)
end)

Net.event("Ask").OnClientEvent:Connect(function(from: Player)
	if not from or Flight.active then
		return
	end
	askFrom = from.UserId
	askLbl.Text = from.DisplayName .. " wants to fly together! x" .. Config.TANDEM_MULT .. " distance"
	askCard.Visible = true
	Ui.pop(askCard, 0.7)
	Ui.sfx("pop", 0.7)
	askToken += 1
	local my = askToken
	task.delay(Config.TANDEM_ASK_TTL, function()
		if askToken == my then
			askCard.Visible = false
		end
	end)
end)

Net.event("Race").OnClientEvent:Connect(function(kind, arg)
	if kind == "open" then
		raceEnd = os.clock() + (tonumber(arg) or 20)
		S.raceJoined = false
		raceCard.Visible = true
		Ui.pop(raceCard, 0.7)
		Ui.sfx("zone", 0.6)
	elseif kind == "go" or kind == "none" then
		raceCard.Visible = false
		S.raceJoined = false
	elseif kind == "result" and type(arg) == "table" then
		if #arg.winners > 0 then
			showBanner("🏆 " .. table.concat(arg.winners, ", ") .. " WON!", arg.rings .. " rings · next race in 10 min", 3)
		else
			showBanner("RACE OVER", "Nobody caught a ring!", 2)
		end
	end
end)

Net.event("Notify").OnClientEvent:Connect(function(text, kind)
	toast(text, kind)
	if kind == "big" then
		Ui.sfx("pop", 0.8)
	end
end)

local flights = 0
Net.event("Launch").OnClientEvent:Connect(function(p)
	openWindow("")
	resultCard.Visible = false
	flights += 1
	steerHint.Visible = S.launches < 3
	task.delay(3, function()
		steerHint.Visible = false
	end)
	Flight.start(p)
end)

Flight.onZone = function(z: number)
	local zone = Config.ZONES[z]
	if Config.zoneAt(S.runBest) < z then
		showBanner("NEW ZONE: " .. string.upper(zone.name), "x" .. zone.mult .. " coins here!", 2.2)
		Ui.sfx("zone", 0.8)
	else
		showBanner(string.upper(zone.name), "x" .. zone.mult .. " coins", 1.4)
	end
end

Flight.onRing = function(n: number)
	local l = Ui.label(root, "+10% 🪙", 28, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.55, 0),
		Size = UDim2.new(0, 200, 0, 32),
		TextColor3 = C.gold,
	})
	Ui.textStroke(3).Parent = l
	Ui.tween(l, 0.7, { Position = UDim2.new(0.5, 0, 0.45, 0), TextTransparency = 1 })
	task.delay(0.8, function()
		l:Destroy()
	end)
end

Net.event("Result").OnClientEvent:Connect(function(r)
	resDist.Text = Fmt.dist(r.dist)
	resCoins.Text = "+" .. Fmt.num(r.coins) .. " 🪙"
	resBest.Visible = r.best
	local notes = {}
	if r.rings > 0 then
		table.insert(notes, r.rings .. " rings: +" .. math.floor(r.rings * Config.RING_BONUS * 100) .. "%")
	end
	if r.newZone then
		table.insert(notes, "Unlocked " .. Config.ZONES[r.newZone].name .. "!")
	end
	if r.todayBest then
		table.insert(notes, "Best today!")
	end
	if r.race then
		table.insert(notes, "Race: " .. r.rings .. " rings")
	end
	if #notes == 0 then
		table.insert(notes, "Power grows +" .. Fmt.num(S.gain) .. " every second")
	end
	resNote.Text = table.concat(notes, "  ·  ")
	resultCard.Visible = true
	Ui.pop(resultCard, 0.5)
	Ui.sfx("coin", 0.9)
	if r.best then
		Ui.sfx("zone", 0.6, 1.2)
	end
	task.delay(2.4, function()
		resultCard.Visible = false
	end)
end)

-- взрыв пушки у всех
Net.event("Fx").OnClientEvent:Connect(function(kind, lane, who)
	if kind == "boom" then
		local world = workspace:FindFirstChild("World")
		local plaza = world and world:FindFirstChild("Plaza")
		local cannon = plaza and plaza:FindFirstChild("Cannon" .. tostring(lane))
		local mouth = cannon and cannon:FindFirstChild("Mouth")
		local att = mouth and mouth:FindFirstChild("Muzzle")
		local blast = att and att:FindFirstChild("Blast")
		if blast and blast:IsA("ParticleEmitter") then
			blast:Emit(30)
		end
		if who ~= player and mouth then
			local s = Instance.new("Sound")
			s.SoundId = "rbxassetid://" .. Assets.sfx.boom
			s.Volume = 0.5
			s.RollOffMaxDistance = 200
			s.Parent = mouth
			s:Play()
			game:GetService("Debris"):AddItem(s, 3)
		end
	elseif kind == "rebirth" and who and who ~= player then
		toast(who.DisplayName .. " just rebirthed! 🔁")
	end
end)

-- ===== персонаж и авто-запуск =====

local function onCharacter(char: Model)
	Flight.stop()
	task.delay(1.4, function()
		if player.Character ~= char or Flight.active then
			return
		end
		if S.passes.AutoLaunch and S.auto and S.launches > 0 then
			call("launch")
		end
	end)
end
player.CharacterAdded:Connect(onCharacter)

-- ПК: пробел/Enter тоже запускает, когда открытых окон нет
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.F then
		if current == "" and not Flight.active and not S.flying then
			task.spawn(call, "launch")
		end
	end
end)

-- музыка
task.spawn(function()
	local id = Assets.music.main
	if id and id > 0 then
		local m = Instance.new("Sound")
		m.SoundId = "rbxassetid://" .. id
		m.Looped = true
		m.Volume = 0.25
		m.Parent = SoundService
		m:Play()
	end
end)

-- лёгкое «дыхание» кнопки запуска
task.spawn(function()
	local up = true
	while true do
		if launchScale and launchBtn.Visible then
			Ui.tween(launchScale, 0.7, { Scale = if up then 1.05 else 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			up = not up
		end
		task.wait(0.7)
	end
end)
