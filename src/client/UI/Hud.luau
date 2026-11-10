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
Fx.flashFrame = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 60, Parent = gui })

-- ── Верх: валюты ────────────────────────────────────────────
-- подпись поверх 3D-мира: белая с тёмным контуром
local function cap(l: TextLabel): TextLabel
	l.TextColor3 = C.white
	l.TextStrokeColor3 = C.line
	l.TextStrokeTransparency = 0
	return l
end

local function pill(icon: string, color: Color3, pos: UDim2, anchor: Vector2?): TextLabel
	-- белая «таблетка» с цветным кружком-иконкой и мягкой тенью
	local f = Kit.frame({ Position = pos, AnchorPoint = anchor or Vector2.zero, Size = UDim2.fromOffset(150, 42), BackgroundColor3 = C.bg, ZIndex = 2, Parent = root }, { Kit.corner(21) })
	Kit.shadow(f, 21, 0.82)
	Kit.frame({ Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(36, 36), BackgroundColor3 = color, ZIndex = 2, Parent = f }, { Kit.corner(18), Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }) })
	Kit.label({ Text = icon, TextScaled = true, Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(9, 9), ZIndex = 3, Parent = f })
	return Kit.label({ Text = "0", Font = Kit.BLACK, TextSize = 22, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(48, 0), Size = UDim2.new(1, -54, 1, 0), ZIndex = 3, Parent = f })
end

-- деньги и алмазы по центру сверху: слева угол занят кнопкой меню Roblox, её скрыть нельзя
local cashL = pill("💰", Color3.fromHex("#FFC93C"), UDim2.new(0.5, -6, 0, 10), Vector2.new(1, 0))
local shardL = pill("💎", Color3.fromHex("#8FF0FF"), UDim2.new(0.5, 6, 0, 10))
local energyL = pill("⚡", Color3.fromHex("#FFE066"), UDim2.new(1, -12, 0, 10), Vector2.new(1, 0))
local incomeL = cap(Kit.label({ Text = "", TextSize = 18, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 54), Size = UDim2.fromOffset(240, 20), Parent = root }))

-- деньги «докручиваются» до нового значения, прибыль всплывает под таблеткой
local shownCash, cashTarget, cashRolling = 0, 0, false
local function rollCash()
	if cashRolling then
		return
	end
	cashRolling = true
	task.spawn(function()
		while math.abs(cashTarget - shownCash) >= 1 do
			shownCash += (cashTarget - shownCash) * 0.25
			if math.abs(cashTarget - shownCash) < 1 then
				shownCash = cashTarget
			end
			cashL.Text = L.money(math.floor(shownCash))
			task.wait(1 / 30)
		end
		cashL.Text = L.money(cashTarget)
		cashRolling = false
	end)
end
local function gainText(pill: GuiObject, text: string, color: Color3)
	local g = Kit.label({ Text = text, Font = Kit.BLACK, TextSize = 20, TextColor3 = color, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(160, 24), ZIndex = 4, Parent = pill })
	g.TextStrokeColor3 = Color3.fromHex("#231A3B")
	g.TextStrokeTransparency = 0.3
	local TweenService = game:GetService("TweenService")
	TweenService:Create(g, TweenInfo.new(1.1, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Position = UDim2.new(0.5, 0, 1, 34), TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.2, function()
		g:Destroy()
	end)
	Kit.pop(pill, 1.12)
	if M.onGain then
		pcall(M.onGain)
	end
end
State.on("cash", function(v)
	local first = cashTarget == 0 and shownCash == 0
	local diff = v - cashTarget
	cashTarget = v
	if first then
		shownCash = v
		cashL.Text = L.money(v)
		return
	end
	-- заметная прибыль (сбор, продажа, награда) — всплывающая цифра
	if diff >= math.max(10, (State.s.income and State.s.income.now or 0) * 2.5) then
		gainText(cashL.Parent, "+" .. L.money(diff), Color3.fromHex("#5BE37D"))
	end
	rollCash()
end)
local lastShards = nil
State.on("shards", function(v)
	if lastShards and v > lastShards then
		gainText(shardL.Parent, "+" .. L.short(v - lastShards) .. " 💎", Color3.fromHex("#8FF0FF"))
	end
	lastShards = v
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
M.onPass = nil :: (() -> ())?
local passB = Kit.iconButton("⭐", Color3.fromHex("#7B5CFF"), 54, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -136, 0, 58), Parent = root }, function()
	if M.onPass then
		M.onPass()
	end
end)
-- точка «есть что забрать» на кнопке пропуска
local passDot = Kit.frame({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 2, 0, -2), Size = UDim2.fromOffset(18, 18), BackgroundColor3 = C.alarm, Visible = false, ZIndex = 5, Parent = passB }, { Kit.corner(9), Kit.new("UIStroke", { Color = C.white, Thickness = 2 }) })
State.on("pass", function(p)
	if type(p) ~= "table" then
		return
	end
	local lvl = math.floor((p.xp or 0) / Game.PASS_XP)
	local any = false
	for l = 1, math.min(lvl, Game.PASS_LEVELS) do
		if not (p.cf or {})[tostring(l)] or (p.prem and not (p.cp or {})[tostring(l)]) then
			any = true
			break
		end
	end
	passDot.Visible = any
	Kit.pulse(passB, any)
end)
for _, b in { shopB, menuB, passB } do
	local cap2 = Kit.label({ Text = ({ [shopB] = "Магазин", [menuB] = "Меню", [passB] = "Пропуск" })[b], Font = Kit.BLACK, TextSize = 13, TextColor3 = C.white, Position = UDim2.new(0, -12, 1, 2), Size = UDim2.new(1, 24, 0, 16), ZIndex = 3, Parent = b })
	cap2.TextStrokeColor3 = C.line
	cap2.TextStrokeTransparency = 0.2
end

-- ── Своя кнопка дубинки вместо рюкзака Roblox ───────────────
local Players = game:GetService("Players")
local batB = Kit.iconButton("🏏", Color3.fromHex("#FF9F43"), 62, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Visible = false, Parent = root })
local batL = Kit.label({ Text = "Дубинка", Font = Kit.BLACK, TextSize = 13, TextColor3 = C.white, Position = UDim2.new(0, -14, 0, -18), Size = UDim2.new(1, 28, 0, 16), ZIndex = 3, Parent = batB })
batL.TextStrokeColor3 = C.line
batL.TextStrokeTransparency = 0.2
local function batTool(): (Tool?, boolean)
	local pl = Players.LocalPlayer
	local ch = pl.Character
	local t = ch and ch:FindFirstChildOfClass("Tool")
	if t then
		return t, true
	end
	local bp = pl:FindFirstChildOfClass("Backpack")
	return bp and bp:FindFirstChildOfClass("Tool"), false
end
batB.Activated:Connect(function()
	Kit.click(batB)
	local t, equipped = batTool()
	local hum = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not t or not hum then
		return
	end
	if equipped then
		hum:UnequipTools()
	else
		hum:EquipTool(t)
	end
end)
task.spawn(function()
	while true do
		local t, equipped = batTool()
		batB.Visible = t ~= nil
		local stroke = batB:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = if equipped then Color3.fromHex("#FFE066") else C.white
			stroke.Thickness = if equipped then 5 else 3
		end
		batL.Text = if equipped then "Убрать" else "Дубинка"
		task.wait(0.25)
	end
end)

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
	actionB.Visible = kind ~= "none"
	local a = ACTION[kind] or ACTION.none
	actionB.Text = if cd and cd > 0 then "" else a[1]
	actionB.BackgroundColor3 = a[2]
	actionL.Text = a[3]
	actionCd.Text = if cd and cd > 0 then tostring(math.ceil(cd)) else ""
end

-- таймер рейда (несёшь добычу)
local raidBar = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 80), Size = UDim2.fromOffset(280, 46), BackgroundColor3 = Color3.fromHex("#8B5CF6"), Visible = false, Parent = root }, { Kit.corner(16), Kit.stroke(C.line, 3) })
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
local pendingL = cap(Kit.label({ Text = "", TextSize = 18, TextColor3 = C.gold, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -96), Size = UDim2.fromOffset(360, 22), Parent = root }))
State.on("pending", function(v)
	-- с «Авто-сборщиком» деньги сами уходят на счёт каждые 5 с — подсказка про плиту не нужна
	local auto = (State.s.passes or {}).AutoCollect == true
	pendingL.Text = if v > 0 and not auto then "На плите: " .. L.money(v) .. " — встань на неё" else ""
end)

-- ── Тосты ───────────────────────────────────────────────────
local toastHolder = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 82), Size = UDim2.fromOffset(380, 160), Parent = root }, { Kit.list(nil, 6) })
local TOAST = { good = C.ok, bad = C.alarm, gold = C.gold, info = C.text }
function M.toast(text: string, kind: string?)
	local col = TOAST[kind or "info"] or C.chrono
	-- тёмный тост с цветной точкой-статусом
	local f = Kit.frame({ Size = UDim2.new(1, 0, 0, 40), BackgroundColor3 = Color3.fromHex("#231A3B"), BackgroundTransparency = 0.08, Parent = toastHolder }, { Kit.corner(20) })
	Kit.frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = if kind == "info" or kind == nil then Color3.fromHex("#2EB8F0") else col, Parent = f }, { Kit.corner(5) })
	Kit.label({ Text = text, TextSize = 17, TextColor3 = C.white, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -46, 1, 0), Parent = f })
	Kit.pop(f)
	task.delay(2.6, function()
		f:Destroy()
	end)
	if kind == "bad" then
		Fx.sfx("click", nil, 0.3)
	elseif kind == "good" or kind == "gold" then
		Fx.sfx("pop", nil, 0.3)
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
	caveReveal = function(d)
		local def = Defs.BY_ID[d.id]
		if not def then
			return
		end
		local r = Defs.RARITY[def.rarity]
		local stars = string.rep("⭐", r.index)
		M.popup({
			title = "🎉 " .. string.upper(L.name(r.name)) .. "! 🎉",
			color = r.color,
			art = d.id,
			text = L.name(def.name) .. "\n" .. stars .. "\n+" .. L.money(def.income) .. "/с — уже на твоей базе!",
			buttons = { { "Ура!", "gold", function()
				State.act("caveDone")
			end } },
		})
		Fx.sfx("escape", nil, 1)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		if hrp then
			Fx.burst(hrp.Position + Vector3.new(0, 3, 0), r.color, 80, 25, 1, true, true)
		end
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
local hint = cap(Kit.label({ Text = "", Font = Kit.BLACK, TextSize = 34, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 132), Size = UDim2.fromOffset(300, 44), Visible = false, Parent = root }))

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
		hint.Text = "Беги к кнопке замка!"
		hint.Visible = true
		tutTarget = d.target
		arrow.Enabled = tutTarget ~= nil
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
