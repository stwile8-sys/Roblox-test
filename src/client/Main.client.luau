--!nonstrict
-- «Frontier Empires», клиент. На «входе» показываем подключение к миру,
-- в мире — загрузку, затем основной интерфейс.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local LocalizationService = game:GetService("LocalizationService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared:WaitForChild("Lang"):WaitForChild("L"))
local Kit = require(script.Parent:WaitForChild("UI"):WaitForChild("Kit"))

local player = Players.LocalPlayer

-- язык по умолчанию — язык Roblox у игрока
do
	local ok, locale = pcall(function()
		return LocalizationService.RobloxLocaleId
	end)
	L.set(L.fromLocale(if ok and type(locale) == "string" then locale else player.LocaleId))
end

-- режим сервера
local mode = ReplicatedStorage:GetAttribute("ServerMode")
local waited = 0
while mode == nil and waited < 30 do
	task.wait(0.2)
	waited += 0.2
	mode = ReplicatedStorage:GetAttribute("ServerMode")
end

local function fullscreen(name: string): (ScreenGui, TextLabel, TextLabel)
	local gui = Kit.screen(name, 50)
	gui.IgnoreGuiInset = true
	local bg = Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(20, 26, 34), Parent = gui })
	Kit.new("UIGradient", {
		Color = ColorSequence.new(Color3.fromRGB(40, 70, 60), Color3.fromRGB(20, 26, 40)),
		Rotation = 90,
		Parent = bg,
	})
	local title = Kit.label({
		Text = "FRONTIER EMPIRES",
		Font = Kit.BOLD,
		TextSize = 38,
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.4),
		Size = UDim2.new(0, 600, 0, 50),
		TextColor3 = Kit.C.accent,
		Parent = bg,
	})
	local status = Kit.label({
		TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.new(0, 500, 0, 30),
		TextColor3 = Kit.C.dim,
		TextSize = 18,
		Parent = bg,
	})
	return gui, title, status
end

if mode == "router" then
	local gui, _, status = fullscreen("Connect")
	local retry = Kit.button(L.t("route.retry"), "main", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.new(0, 200, 0, 46),
		Visible = false,
		Parent = gui,
	}, function()
		pcall(function()
			TeleportService:Teleport(game.PlaceId)
		end)
	end)
	local function update()
		local st = player:GetAttribute("RouteStatus")
		status.Text = L.t("route." .. tostring(st or "search"))
		retry.Visible = st == "error"
	end
	player:GetAttributeChangedSignal("RouteStatus"):Connect(update)
	update()
	return
end

-- Мир -------------------------------------------------------------------

local loadingGui, _, loadingStatus = fullscreen("Loading")
loadingStatus.Text = L.t("load.world")

local Store = require(script.Parent:WaitForChild("Store"))
local Net = require(Shared:WaitForChild("Net"))
local Graphics = require(script.Parent:WaitForChild("Graphics"))
local Hud = require(script.Parent.UI:WaitForChild("Hud"))
local Windows = require(script.Parent.UI:WaitForChild("Windows"))
local Build = require(script.Parent.UI:WaitForChild("Build"))
local WorldView = require(script.Parent:WaitForChild("WorldView"))
local Driving = require(script.Parent:WaitForChild("Driving"))
local Map = require(Shared:WaitForChild("Config"):WaitForChild("Map"))

while ReplicatedStorage:GetAttribute("WorldReady") ~= true do
	local p = ReplicatedStorage:GetAttribute("WorldProgress")
	if type(p) == "number" then
		loadingStatus.Text = L.t("load.world") .. "  " .. math.floor(p * 100) .. "%"
	end
	task.wait(0.25)
end
loadingStatus.Text = L.t("load.profile")

Hud.start()
local function toast(text: string, kind: string?)
	Hud.toast(text, kind)
end
local function setGraphics(m: string)
	Graphics.apply(m)
end
local function setDraw(d: number)
	WorldView.setDrawDistance(d)
	Graphics.setDraw(d)
end
Windows.start(Hud.gui(), toast, setGraphics, setDraw)
Build.start(toast, function()
	Hud.hideFor(false)
	WorldView.hideGuide(false)
end)
WorldView.start()
Graphics.apply("auto")
setDraw(Graphics.defaultDraw())
Driving.start(function(on)
	Hud.setDriving(on)
	if on then
		Windows.closeAll()
	end
end, toast)

Net.event("Notify").OnClientEvent:Connect(function(key: string, args: { [string]: any }, kind: string)
	local a = table.clone(args or {})
	if type(a.item) == "string" then
		a.item = L.t("item." .. a.item)
	end
	toast(L.t(key, a), kind)
end)

Hud.onButton("build", function()
	if Driving.active() then
		toast(L.t("drive.exit_first"), "error")
		return
	end
	Windows.closeAll()
	Hud.hideFor(true)
	WorldView.hideGuide(true)
	Build.enter()
end)
Hud.onButton("storage", function()
	Windows.open("storage")
end)
Hud.onButton("market", function()
	Windows.open("market")
end)
Hud.onButton("plots", function()
	Windows.open("plots")
end)
Hud.onButton("settings", function()
	Windows.open("settings")
end)

local function atOwnPlot(): boolean
	local s = Store.state
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	if not s or not s.plot or not hrp or not hrp:IsA("BasePart") then
		return false
	end
	return Map.plotAt(hrp.Position) == s.plot
end

Hud.onButton("travel", function()
	local ok, msg = Store.act(if atOwnPlot() then "goHub" else "goPlot")
	if not ok and type(msg) == "string" then
		toast(L.t(msg), "error")
	end
end)
task.spawn(function()
	while true do
		task.wait(1)
		Hud.setTravelIcon(atOwnPlot())
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local ui = prompt:GetAttribute("Ui")
	if type(ui) == "string" then
		Windows.open(ui)
	end
end)

-- настройки игрока из сохранения (один раз)
local prefsApplied = false
Store.on(function(s)
	if prefsApplied or not s.prefs then
		return
	end
	prefsApplied = true
	if L.isLang(s.prefs.lang) then
		L.set(s.prefs.lang)
	end
	Graphics.apply(s.prefs.gfx or "auto")
	local d = tonumber(s.prefs.draw)
	if d then
		setDraw(d)
	end
end)

-- рукопожатие: сервер готов отдать профиль и сводку
task.spawn(function()
	while true do
		local ok, summary = Store.act("hello")
		if ok then
			loadingGui:Destroy()
			if type(summary) == "table" then
				Hud.showSummary(summary)
			end
			break
		end
		task.wait(1)
	end
end)
