--!nonstrict
-- HUD по ТЗ 6.2 (портрет, кнопки ≥ 80 px, важное внизу), тосты, попапы 6.4, обучение без текста.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared.Lang.L)
local Defs = require(Shared.Art.Defs)
local Game = require(Shared.Config.Game)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local State = require(script.Parent.Parent.State)
local Fx = require(script.Parent.Parent.Fx)

local M: any = {}
local C = Kit.C
local player = Players.LocalPlayer

local gui, root = Kit.screen("HUD", 5)
M.gui = gui
M.root = root

-- виньетка погони
local vignette = Kit.new("ImageLabel", {
	Image = "rbxasset://textures/ui/TopBar/TopBarRoundedFrameGradient.png",
	BackgroundTransparency = 1,
	ImageTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ScaleType = Enum.ScaleType.Stretch,
	Visible = false,
	ZIndex = 0,
	Parent = root,
})
Kit.new("UIStroke", { Thickness = 22, Color = C.alarm, Transparency = 0.4, Parent = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = vignette }) })
Fx.vignette = vignette

-- ── Верх: валюты ────────────────────────────────────────────
-- подпись поверх 3D-мира: белая с тёмным контуром
local function cap(l: TextLabel): TextLabel
	l.TextColor3 = C.white
	l.TextStrokeColor3 = C.line
	l.TextStrokeTransparency = 0
	return l
end

local function pill(icon: string, color: Color3, pos: UDim2, anchor: Vector2?): TextLabel
	local f = Kit.frame({ Position = pos, AnchorPoint = anchor or Vector2.zero, Size = UDim2.fromOffset(140, 40), BackgroundColor3 = C.bg, Parent = root }, { Kit.corner(20), Kit.stroke(C.line, 3) })
	Kit.frame({ Size = UDim2.fromOffset(40, 40), BackgroundColor3 = color, Parent = f }, { Kit.corner(20), Kit.stroke(C.line, 3) })
	Kit.label({ Text = icon, TextScaled = true, Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(6, 6), ZIndex = 2, Parent = f })
	return Kit.label({ Text = "0", Font = Kit.BLACK, TextSize = 21, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -52, 1, 0), Parent = f })
end

local cashL = pill("💰", Color3.fromHex("#FFC93C"), UDim2.fromOffset(12, 56))
local shardL = pill("💎", Color3.fromHex("#8FF0FF"), UDim2.fromOffset(160, 56))
local energyL = pill("⚡", Color3.fromHex("#FFE066"), UDim2.new(1, -12, 0, 10), Vector2.new(1, 0))
local incomeL = cap(Kit.label({ Text = "", TextSize = 18, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 100), Size = UDim2.fromOffset(240, 20), Parent = root }))

State.on("cash", function(v)
	cashL.Text = L.money(v)
end)
State.on("shards", function(v)
	shardL.Text = L.short(v)
end)
State.on("income", function(v)
	incomeL.Text = "+" .. L.money(v.now) .. "/с" .. (if v.mult > 1 then "  ×" .. string.format("%.1f", v.mult) else "")
end)
local energyNext = cap(Kit.label({ Text = "", TextSize = 16, TextColor3 = C.dim, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -170, 0, 20), Size = UDim2.fromOffset(150, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = root }))
task.spawn(function()
	while true do
		local e = State.s.energy
		if e then
			energyL.Text = if e.n > e.max then tostring(e.n) else e.n .. "/" .. e.max
			if e.n < e.max then
				local left = Game.ENERGY_REGEN - (os.time() - e.t) % Game.ENERGY_REGEN
				energyNext.Text = "+1 через " .. L.duration(left)
			else
				energyNext.Text = ""
			end
		end
		task.wait(1)
	end
end)

M.onShop = nil :: (() -> ())?
M.onMenu = nil :: (() -> ())?
M.onScan = nil :: (() -> ())?
M.onRebirth = nil :: (() -> ())?
M.onAction = nil :: (() -> ())?
M.onActionHold = nil :: ((boolean) -> ())?

local shopB = Kit.iconButton("🛍️", C.ok, 54, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -74, 0, 58), Parent = root }, function()
	if M.onShop then
		M.onShop()
	end
end)
local menuB = Kit.iconButton("📋", C.panel2, 54, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 58), Parent = root }, function()
	if M.onMenu then
		M.onMenu()
	end
end)
local _ = shopB
local _m = menuB

-- ── Низ: Сканер / Ребёрс / Действие ─────────────────────────
-- подняты над стиком и прыжком Roblox
local BOTTOM = -150
local scanB = Kit.iconButton("📡", Color3.fromHex("#8B5CF6"), 66, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, -10), Parent = root }, function()
	if M.onScan then
		M.onScan()
	end
end)
cap(Kit.label({ Text = "Сканер", TextSize = 15, Position = UDim2.new(0, -20, 0, 70), Size = UDim2.new(1, 40, 0, 20), Parent = scanB }))

local rebirthB = Kit.iconButton("🌀", Color3.fromHex("#3EC9F5"), 60, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 17, 0.5, 92), Parent = root }, function()
	if M.onRebirth then
		M.onRebirth()
	end
end)
cap(Kit.label({ Text = "Ребёрс", TextSize = 15, Position = UDim2.new(0, -24, 0, 64), Size = UDim2.new(1, 48, 0, 18), Parent = rebirthB }))
State.on("rebirths", function(v)
	rebirthB.Visible = v.req ~= nil
	Kit.pulse(rebirthB, v.can == true)
end)

local actionB = Kit.iconButton("🔒", Color3.fromHex("#FFC93C"), 78, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -22, 1, BOTTOM), Parent = root })
local actionL = cap(Kit.label({ Text = "Замок", TextSize = 15, Position = UDim2.new(0, -20, 0, 82), Size = UDim2.new(1, 40, 0, 18), Parent = actionB }))
local actionCd = Kit.label({ Text = "", Font = Kit.BLACK, TextSize = 28, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = actionB })
actionB.Activated:Connect(function()
	Kit.click(actionB)
	if M.onAction then
		M.onAction()
	end
end)
actionB.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
		if M.onActionHold then
			M.onActionHold(true)
		end
	end
end)
actionB.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.Touch or i.UserInputType == Enum.UserInputType.MouseButton1 then
		if M.onActionHold then
			M.onActionHold(false)
		end
	end
end)
M.actionB = actionB

local ACTION = {
	lock = { "🔒", Color3.fromHex("#FFC93C"), "Замок" },
	hack = { "⛏️", Color3.fromHex("#FF5C7A"), "Взлом" },
	bat = { "🏏", Color3.fromHex("#FF9F43"), "Удар" },
	cage = { "⛏️", Color3.fromHex("#8B5CF6"), "Клетка" },
	none = { "🏃", C.grey, "" },
}
function M.setAction(kind: string, cd: number?)
	local a = ACTION[kind] or ACTION.none
	actionB.Text = if cd and cd > 0 then "" else a[1]
	actionB.BackgroundColor3 = a[2]
	actionL.Text = a[3]
	actionCd.Text = if cd and cd > 0 then tostring(math.ceil(cd)) else ""
end

-- таймер рейда (несёшь добычу)
local raidBar = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(280, 46), BackgroundColor3 = Color3.fromHex("#8B5CF6"), Visible = false, Parent = root }, { Kit.corner(16), Kit.stroke(C.line, 3) })
local raidL = Kit.label({ Text = "", Font = Kit.BLACK, TextSize = 22, Size = UDim2.fromScale(1, 1), Parent = raidBar })
task.spawn(function()
	while true do
		local c = State.s.carry
		raidBar.Visible = c ~= nil
		if c then
			local left = math.max(0, Game.CARRY_TIMEOUT - (os.clock() - (M.carryStart or os.clock())))
			raidL.Text = "🏃 Беги домой! " .. L.duration(left)
		end
		task.wait(0.25)
	end
end)
State.on("carry", function(c)
	M.carryStart = if c then os.clock() else nil
end)

-- плита сбора: сколько накопилось
local pendingL = cap(Kit.label({ Text = "", TextSize = 18, TextColor3 = C.gold, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(360, 22), Parent = root }))
State.on("pending", function(v)
	pendingL.Text = if v > 0 then "На плите: " .. L.money(v) .. " — встань на неё" else ""
end)

-- ── Тосты ───────────────────────────────────────────────────
local toastHolder = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(380, 160), Parent = root }, { Kit.list(nil, 6) })
local TOAST = { good = C.ok, bad = C.alarm, gold = C.gold, info = C.text }
function M.toast(text: string, kind: string?)
	local col = TOAST[kind or "info"] or C.chrono
	local f = Kit.frame({ Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.bg, Parent = toastHolder }, { Kit.corner(14), Kit.stroke(C.line, 3) })
	Kit.label({ Text = text, TextSize = 18, TextColor3 = col, Size = UDim2.fromScale(1, 1), Parent = f })
	Kit.pop(f)
	task.delay(2.6, function()
		f:Destroy()
	end)
	if kind == "bad" then
		Fx.sfx("click", nil, 0.3)
	end
end
State.toast = M.toast
Net.event("Notify").OnClientEvent:Connect(function(key, args, kind)
	M.toast(L.t(key, args), kind)
end)

-- ── Попапы ──────────────────────────────────────────────────
local popupWin = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(400, 340), Visible = false, ZIndex = 40, Parent = root }, { Kit.corner(24), Kit.stroke(C.line, 4) })
local popTitle = cap(Kit.label({ Text = "", Font = Kit.BLACK, TextSize = 30, Position = UDim2.fromOffset(10, 12), Size = UDim2.new(1, -20, 0, 40), ZIndex = 41, Parent = popupWin }))
local popArt = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.new(0.5, -60, 0, 54), Size = UDim2.fromOffset(120, 110), ZIndex = 41, Parent = popupWin })
local popText = cap(Kit.label({ Text = "", TextSize = 22, Position = UDim2.fromOffset(16, 166), Size = UDim2.new(1, -32, 0, 86), ZIndex = 41, Parent = popupWin }))
local popButtons = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.new(1, -24, 0, 60), ZIndex = 41, Parent = popupWin }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
local queue = {}
local showing = false

local function showNext()
	if showing or #queue == 0 then
		return
	end
	showing = true
	local p = table.remove(queue, 1)
	popupWin.BackgroundColor3 = p.color
	popTitle.Text = p.title
	popText.Text = p.text or ""
	Kit.clear(popArt)
	if p.art and Defs.BY_ID[p.art] then
		Kit.creature(p.art, { Size = UDim2.fromScale(1, 1), ZIndex = 42, Parent = popArt })
	elseif p.icon then
		Kit.label({ Text = p.icon, TextScaled = true, Size = UDim2.fromScale(1, 1), ZIndex = 42, Parent = popArt })
	end
	Kit.clear(popButtons)
	for _, b in p.buttons or { { "Ок", "plain" } } do
		Kit.button(b[1], b[2], { Size = UDim2.fromOffset(150, 56), ZIndex = 42, Parent = popButtons }, function()
			popupWin.Visible = false
			showing = false
			if b[3] then
				b[3]()
			end
			task.delay(0.15, showNext)
		end)
	end
	popupWin.Visible = true
	Kit.pop(popupWin, 0.6)
	Fx.sfx("pop")
end

function M.popup(p: any)
	table.insert(queue, p)
	showNext()
end

local function artName(id: string?): string
	local d = id and Defs.BY_ID[id]
	return if d then L.name(d.name) else ""
end

M.onRevenge = nil :: ((number) -> ())?
M.onTutorial = nil :: ((any) -> ())?
M.onTradeInvite = nil :: ((any) -> ())?

local POP: { [string]: (any) -> () } = {
	robbed = function(d)
		M.popup({ title = "Вас обокрали!", color = Color3.fromHex("#FF5C7A"), art = d.id, text = artName(d.id) .. (if d.thief ~= "" then "\nВор: " .. d.thief else ""), buttons = {
			{ "Отомстить", "gold", function()
				State.act("revenge", { thiefId = d.thiefId })
			end },
			{ "Ок", "cancel" },
		} })
	end,
	stealOk = function(d)
		M.popup({ title = "Успешная кража!", color = Color3.fromHex("#FFB400"), art = d.id, text = artName(d.id) .. (if d.bonus and d.bonus > 0 then "\nКлановый бонус +" .. L.money(d.bonus) else ""), buttons = { { "Забрать", "buy" } } })
	end,
	achievement = function(d)
		local name = d.id
		for _, a in Game.ACHIEVEMENTS do
			if a.id == d.id then
				name = L.name(a.name)
			end
		end
		M.popup({ title = "Достижение!", color = Color3.fromHex("#FFB400"), icon = "🏆", text = name .. "\n+" .. d.shards .. " 💎" })
	end,
	daily = function(d)
		local r = Game.STREAK[d.day] or {}
		local what = if r.art then "Редкий артефакт!" elseif r.shards then "+" .. r.shards .. " 💎" elseif r.tokens then "+" .. r.tokens .. " 🔨" else "Мешок денег 💰"
		M.popup({ title = "День " .. d.day .. " из 7", color = Color3.fromHex("#3EC9F5"), icon = "🎁", text = what, buttons = { { "Открыть", "gold", function()
			State.act("streakClaim")
		end } } })
	end,
	offline = function(d)
		local text = "Пока тебя не было: +" .. L.money(d.cash) .. "\nДеньги на плите сбора"
		if d.robbed and #d.robbed > 0 then
			text ..= "\nУкрадено: " .. #d.robbed .. " 😡"
		end
		M.popup({ title = if d.robbed and #d.robbed > 0 then "Вас обокрали!" else "С возвращением!", color = if d.robbed and #d.robbed > 0 then C.alarm else Color3.fromHex("#C9A227"), art = d.robbed and d.robbed[1] and d.robbed[1].id, icon = "💰", text = text })
	end,
	defended = function(d)
		M.popup({ title = "Защита!", color = Color3.fromHex("#3EC9F5"), icon = "🛡️", text = (if d.decoy then "Вор попался на приманку!" else "Вор пойман!") .. (if d.thief and d.thief ~= "" then "\n" .. d.thief else "") })
	end,
	raidFail = function(d)
		local why = ({ caught = "Тебя поймали!", trap = "Ловушка!", decoy = "Это была приманка!", timeout = "Время вышло", fell = "Ты упал" })[d.reason] or "Провал"
		M.popup({ title = why, color = Color3.fromHex("#FF5C7A"), icon = "💫", text = "−1 ⚡, инструменты на 60 сек" })
	end,
	stealCancelled = function(d)
		M.popup({ title = "Кража отменена", color = Color3.fromHex("#9A93AD"), icon = "↩️", text = "Хозяин вернулся.\nКомпенсация: " .. L.money(d.cash or 0) })
	end,
	purchased = function(d)
		M.popup({ title = "Спасибо!", color = Color3.fromHex("#4CD964"), icon = "🎉", text = (if d.test then "[тест] " else "") .. "Покупка получена" })
	end,
	alarm = function(d)
		M.toast(if d.thief ~= "" then L.t(d.key) .. " (" .. d.thief .. ")" else L.t(d.key), "bad")
	end,
	tradeInvite = function(d)
		M.popup({ title = "Обмен", color = Color3.fromHex("#8B5CF6"), icon = "🤝", text = d.from .. " хочет обменяться", buttons = {
			{ "Да", "buy", function()
				State.act("tradeAccept")
			end },
			{ "Нет", "cancel" },
		} })
	end,
	tutorial = function(d)
		if M.onTutorial then
			M.onTutorial(d)
		end
	end,
}

Net.event("Popup").OnClientEvent:Connect(function(kind, data)
	local h = POP[kind]
	if h then
		pcall(h, data or {})
	end
end)

-- ── Обучение: стрелка к цели и пульс кнопок ─────────────────
local arrow = Instance.new("Beam")
local tutTarget: Vector3? = nil
local a1 = Instance.new("Attachment")
a1.Parent = workspace.Terrain
arrow.Attachment1 = a1
arrow.Width0 = 1.5
arrow.Width1 = 1.5
arrow.Color = ColorSequence.new(C.gold)
arrow.LightEmission = 1
arrow.FaceCamera = true
arrow.TextureSpeed = 2
arrow.Texture = "rbxasset://textures/ui/ArrowRightThin.png"
arrow.Enabled = false
arrow.Parent = workspace.Terrain
local hint = cap(Kit.label({ Text = "", Font = Kit.BLACK, TextSize = 34, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 62), Size = UDim2.fromOffset(300, 44), Visible = false, Parent = root }))

M.onTutorial = function(d)
	local step = d.step
	arrow.Enabled = false
	hint.Visible = false
	Kit.pulse(actionB, false)
	if step == 2 or step == 3 then
		tutTarget = d.target
		arrow.Enabled = tutTarget ~= nil
		hint.Text = if step == 2 then "Догони вора!" else "Неси домой!"
		hint.Visible = true
	elseif step == 4 then
		hint.Text = "Жми «Замок»!"
		hint.Visible = true
		Kit.pulse(actionB, true)
	end
end
task.spawn(function()
	while true do
		task.wait(0.1)
		if arrow.Enabled and tutTarget then
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp then
				local att = hrp:FindFirstChild("TutA0") or Kit.new("Attachment", { Name = "TutA0", Parent = hrp })
				arrow.Attachment0 = att
				a1.WorldPosition = tutTarget
			end
		end
	end
end)

return M
