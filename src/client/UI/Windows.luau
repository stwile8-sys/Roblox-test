--!nonstrict
-- Экраны ТЗ 6.3: Сканер, Магазин (5 вкладок), Коллекция+хранилище, Лидерборды, Квесты+серия, Трейд,
-- Кланы, Верстак (стены/ловушки/инструмент), Пьедестал, Ребёрс, Меню, Тест-панель владельца.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local L = require(Shared.Lang.L)
local Defs = require(Shared.Art.Defs)
local Game = require(Shared.Config.Game)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local Hud = require(script.Parent.Hud)
local State = require(script.Parent.Parent.State)

local M: any = {}
local C = Kit.C
local root = Hud.root
local player = Players.LocalPlayer

local RCOL = {}
for r, info in Defs.RARITY do
	RCOL[r] = info.color
end
-- на светлом фоне светлые цвета редкостей плохо читаются — темнее для текста
RCOL.common = Color3.fromHex("#6F7F99")
RCOL.legendary = Color3.fromHex("#E08A00")
RCOL.chrono = Color3.fromHex("#0FA3C4")



local function scrollBody(body: Frame): ScrollingFrame
	Kit.clear(body)
	return Kit.scroll({ ZIndex = 22, Parent = body }, { Kit.list(nil, 8, Enum.HorizontalAlignment.Left), Kit.pad(2) })
end

-- ярлык-«пилюля»
local function chip(parent: Instance, text: string, bg: Color3, fg: Color3?, props: { [string]: any }?): TextLabel
	local base = { Text = text, Font = Kit.BLACK, TextSize = 13, TextColor3 = fg or C.white, BackgroundColor3 = bg, BackgroundTransparency = 0, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), TextWrapped = false, ZIndex = 24, Parent = parent }
	local pp: any = props or {}
	for k, v in pp do
		base[k] = v
	end
	local l = Kit.label(base)
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = l })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9), Parent = l })
	return l
end

-- заголовок раздела внутри окна
local function section(parent: Instance, text: string, sub: string?, order: number)
	local f = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, if sub then 44 else 28), LayoutOrder = order, ZIndex = 22, Parent = parent })
	Kit.label({ Text = text, Font = Kit.BLACK, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24), ZIndex = 22, Parent = f })
	if sub then
		Kit.label({ Text = sub, TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18), ZIndex = 22, Parent = f })
	end
end

-- строка-карточка: цветная плитка с иконкой слева, заголовок и подпись, кнопка справа
type RowOpts = { icon: string, color: Color3, title: string, sub: string?, subColor: Color3?, btn: string?, kind: string?, onClick: (() -> ())?, h: number?, btnW: number?, dim: boolean? }
local function row(parent: Instance, order: number, o: RowOpts): Frame
	local h = o.h or 74
	local c = Kit.frame({ Size = UDim2.new(1, -6, 0, h), BackgroundColor3 = C.panel, LayoutOrder = order, ZIndex = 22, Parent = parent }, { Kit.corner(18) })
	local tile = Kit.frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(h - 20, h - 20), BackgroundColor3 = o.color, ZIndex = 23, Parent = c }, { Kit.corner(14), Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }) })
	Kit.label({ Text = o.icon, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = 24, Parent = tile })
	local right = if o.btn then (o.btnW or 140) + 20 else 14
	Kit.label({ Text = o.title, Font = Kit.BLACK, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Position = UDim2.new(0, h, 0, if o.sub then h / 2 - 22 else 0), Size = UDim2.new(1, -h - right, 0, if o.sub then 22 else h), ZIndex = 23, Parent = c })
	if o.sub then
		Kit.label({ Text = o.sub, TextSize = 14, TextColor3 = o.subColor or C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.new(0, h, 0, h / 2 + 1), Size = UDim2.new(1, -h - right, 0, h / 2 - 6), ZIndex = 23, Parent = c })
	end
	if o.btn then
		Kit.button(o.btn, o.kind or "buy", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(o.btnW or 140, 46), TextSize = 16, ZIndex = 23, Parent = c }, function()
			if o.onClick then
				o.onClick()
			end
		end)
	end
	if o.dim then
		c.BackgroundTransparency = 0.4
	end
	return c
end

-- плитка существа: цвет редкости, уровень, отметка выбора
local function artTile(parent: Instance, it: any, size: number, order: number, selected: boolean?, badge: string?, silhouette: boolean?): TextButton
	local d = Defs.BY_ID[it.id]
	local rc = d and Defs.RARITY[d.rarity].color or C.grey
	local b = Kit.new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = if silhouette then C.soft else rc, BackgroundTransparency = if selected then 0.55 elseif silhouette then 0.3 else 0.82, Size = UDim2.fromOffset(size, size), LayoutOrder = order, ZIndex = 23, Parent = parent }, { Kit.corner(14), Kit.new("UIStroke", { Color = if selected then Color3.fromHex("#FFB020") else rc, Thickness = if selected then 3 else 1.5, Transparency = if selected then 0 elseif silhouette then 0.8 else 0.4 }) })
	Kit.creature(it.id, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 2), ZIndex = 24, Parent = b }, silhouette)
	if it.lvl then
		local lv = Kit.label({ Text = "ур." .. it.lvl, Font = Kit.BLACK, TextSize = 11, TextColor3 = C.white, BackgroundColor3 = Color3.fromHex("#231A3B"), BackgroundTransparency = 0.35, AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, -4), Size = UDim2.fromOffset(0, 16), TextWrapped = false, ZIndex = 25, Parent = b })
		Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = lv })
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 5), PaddingRight = UDim.new(0, 5), Parent = lv })
	end
	if selected then
		local ck = Kit.label({ Text = "✓", Font = Kit.BLACK, TextSize = 14, TextColor3 = C.white, BackgroundColor3 = Color3.fromHex("#FFB020"), BackgroundTransparency = 0, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(20, 20), ZIndex = 25, Parent = b })
		Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = ck })
	elseif badge then
		Kit.label({ Text = badge, TextSize = 14, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 3), Size = UDim2.fromOffset(18, 18), ZIndex = 25, Parent = b })
	end
	return b
end

local function tileGrid(parent: Instance, cell: number, order: number): Frame
	local g = Kit.frame({ BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -6, 0, 0), LayoutOrder = order, ZIndex = 22, Parent = parent })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(cell, cell), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
	return g
end

-- ── Сканер ──────────────────────────────────────────────────
local scanWin, scanBody = Kit.window(root, "📡 Сканер", 0.7, Color3.fromHex("#7B5CFF"))
local DEF_NAME = { "Низкий", "Средний", "Высокий" }
local DEF_COL = { C.ok, C.gold, C.alarm }

function M.scan()
	local ok, list = State.act("scan")
	if not ok or type(list) ~= "table" then
		return
	end
	local s = scrollBody(scanBody)
	section(s, "Куда идём на дело?", "−1 ⚡ уже списана. Чем выше защита, тем дороже добыча", 0)
	for i, b in list do
		local col = DEF_COL[b.defense]
		local icon = if b.kind == "offline" then "💤" elseif b.kind == "bot" then "🤖" else "🏠"
		local c = row(s, i, {
			icon = icon,
			color = col,
			title = (b.name ~= "" and b.name or "База " .. b.index),
			sub = "💰 лут ≈ " .. L.money(b.loot),
			subColor = C.gold,
			btn = "Вторгнуться",
			kind = if b.defense == 3 then "danger" else "thief",
			btnW = 150,
			h = 84,
			onClick = function()
				if State.act("invade", { index = b.index }) then
					Kit.close(scanWin)
				end
			end,
		})
		-- ярлыки защиты справа от названия
		local tags = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 84, 1, -28), Size = UDim2.new(1, -260, 0, 22), ZIndex = 23, Parent = c }, { Kit.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Left) })
		chip(tags, "🛡️ " .. DEF_NAME[b.defense], col)
		chip(tags, "🧱 ур." .. b.wall, C.soft, C.text)
		if b.shield then
			chip(tags, "🔒 замок", C.grey)
		end
		if b.kind == "offline" then
			chip(tags, "не в игре", C.soft, C.dim)
		end
	end
	Kit.open(scanWin)
end

-- ── Магазин ─────────────────────────────────────────────────
-- Каждая покупка открывает карточку-разъяснение: что именно даёт, навсегда или разово, цена.
local shopWin, shopBody = Kit.window(root, "Магазин", 0.86, Color3.fromHex("#FF7A45"))
local shopTab = "passes"

local INFO: { [string]: { icon: string, tag: string, color: string, lines: { string }, note: string? } } = {
	VIP = { icon = "👑", tag = "Навсегда", color = "#FFB020", lines = { "+10% к доходу, пока ты не в игре", "+5 💎 осколков каждый день", "Золотой ник над головой" } },
	AutoCollect = { icon = "🤖", tag = "Навсегда", color = "#2EB8F0", lines = { "Деньги с плиты сами падают на счёт каждые 5 с", "Работает, даже когда ты в рейде", "Больше не нужно бегать к плите" } },
	ScannerPlus = { icon = "📡", tag = "Навсегда", color = "#7B5CFF", lines = { "Сканер показывает 5 баз вместо 3", "Хозяин не увидит твоё имя, когда ты крадёшь" } },
	SecondFloor = { icon = "🏰", tag = "Навсегда", color = "#C9853B", lines = { "Второй этаж на твоей базе с лестницей", "+10 пьедесталов — больше существ и дохода" } },
	Starter = { icon = "🎁", tag = "Один раз", color = "#FF7A45", lines = { "500 💰 сразу", "Редкое существо «Жук-хранитель»", "Скин хроно-следа «Старт»" }, note = "Можно купить только один раз" },
	Energy5 = { icon = "⚡", tag = "Разово", color = "#FFB020", lines = { "+5 ⚡ энергии сразу", "1 ⚡ = одно вторжение на чужую базу" }, note = "Энергия и так восстанавливается: 1 ⚡ за 5 минут" },
	BoostX2 = { icon = "💰", tag = "15 минут", color = "#22B455", lines = { "Весь доход ×2 на 15 минут", "Купишь ещё — время продлится" } },
	Titan = { icon = "🕳️", tag = "Один раз", color = "#1A1230", lines = { "Все твои мины станут «Чёрными дырами»", "Скин хроно-следа «Титан»" }, note = "Только внешний вид — силу не даёт" },
	Shards100 = { icon = "💎", tag = "Разово", color = "#2EB8F0", lines = { "+100 💎 хроно-осколков", "Осколки тратятся на скины хроно-следа" } },
	Shards550 = { icon = "💎", tag = "Выгодно", color = "#2EB8F0", lines = { "+550 💎 хроно-осколков", "На 10% выгоднее маленького набора" } },
	Shards1500 = { icon = "💎", tag = "Лучшая цена", color = "#2EB8F0", lines = { "+1500 💎 хроно-осколков", "Самый выгодный набор" } },
	SeasonPass = { icon = "⭐", tag = "Этот сезон", color = "#7B5CFF", lines = { "+20% к доходу до конца сезона", "Открывает ⭐ награды на всех 20 уровнях пропуска", "Сезонный скин сразу, Сезонный Титан — на 20 уровне" }, note = "Награды забираешь по мере прокачки уровня" },
}

local function priceOf(key: string): number
	local p = Game.PASSES[key] or Game.PRODUCTS[key]
	return p and p.price or 0
end

local function nameOf(key: string): string
	local p = Game.PASSES[key] or Game.PRODUCTS[key]
	return p and L.name(p.name) or key
end

-- лист покупки поверх всего интерфейса
local sheetBg = Kit.new("TextButton", { Name = "SheetBg", Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromHex("#140E26"), BackgroundTransparency = 0.45, Size = UDim2.new(1, 400, 1, 400), Position = UDim2.fromOffset(-200, -200), ZIndex = 40, Visible = false, Parent = root })
local sheet = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(440, 330), BackgroundColor3 = C.bg, ZIndex = 41, Visible = false, Parent = root }, { Kit.corner(24) })
sheetBg.Activated:Connect(function()
	sheet.Visible = false
	sheetBg.Visible = false
end)

function M.explain(key: string)
	local info = INFO[key]
	if not info then
		return
	end
	Kit.clear(sheet)
	sheet.Size = UDim2.fromOffset(440, 330)
	local owned = (Game.PASSES[key] and (State.s.passes or {})[key]) or (Game.PRODUCTS[key] and Game.PRODUCTS[key].once and (State.s.once or {})[key])
	local col = Color3.fromHex(info.color)
	-- слева крупная иконка на цветной плашке, справа текст
	local tile = Kit.frame({ Position = UDim2.fromOffset(20, 20), Size = UDim2.fromOffset(120, 120), BackgroundColor3 = col, ZIndex = 42, Parent = sheet }, { Kit.corner(28), Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) }) })
	Kit.label({ Text = info.icon, TextScaled = true, Size = UDim2.fromScale(0.62, 0.62), Position = UDim2.fromScale(0.19, 0.19), ZIndex = 43, Parent = tile })
	local pill = Kit.label({ Text = info.tag, Font = Kit.BLACK, TextSize = 14, TextColor3 = col, BackgroundTransparency = 0.85, BackgroundColor3 = col, AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(160, 22), Size = UDim2.fromOffset(0, 26), ZIndex = 42, Parent = sheet }, nil)
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), Parent = pill })
	if key == "Titan" then
		pill.TextColor3 = C.text
	end
	Kit.label({ Text = nameOf(key), Font = Kit.BLACK, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(160, 52), Size = UDim2.new(1, -180, 0, 36), ZIndex = 42, Parent = sheet })
	local list = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(160, 94), Size = UDim2.new(1, -180, 0, 140), ZIndex = 42, Parent = sheet }, { Kit.list(nil, 6, Enum.HorizontalAlignment.Left) })
	for i, line in info.lines do
		Kit.label({ Text = "✓  " .. line, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = i, ZIndex = 42, Parent = list })
	end
	if info.note then
		Kit.label({ Text = info.note, TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(20, 236), Size = UDim2.new(1, -40, 0, 20), ZIndex = 42, Parent = sheet })
	end
	local close = function()
		sheet.Visible = false
		sheetBg.Visible = false
	end
	Kit.button("Не сейчас", "cancel", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 20, 1, -18), Size = UDim2.fromOffset(150, 54), ZIndex = 42, Parent = sheet }, close)
	Kit.button(if owned then "Уже есть ✓" else "Купить  R$ " .. priceOf(key), if owned then "cancel" else "buy", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -20, 1, -18), Size = UDim2.fromOffset(230, 54), TextSize = 22, ZIndex = 42, Parent = sheet }, function()
		if not owned then
			State.act("buy", { key = key, test = State.s.tester == true and M.testBuy == true })
		end
		close()
	end)
	sheetBg.Visible = true
	sheet.Visible = true
	Kit.pop(sheet, 0.9)
end

-- карточка товара в сетке: иконка, название, коротко, цена; тап — разъяснение
local function productCard(parent: Instance, order: number, key: string, owned: boolean)
	local info = INFO[key]
	local col = Color3.fromHex(info.color)
	local c = Kit.new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.panel, LayoutOrder = order, ZIndex = 22, Parent = parent }, { Kit.corner(18) })
	local tile = Kit.frame({ Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 74), BackgroundColor3 = col, ZIndex = 23, Parent = c }, { Kit.corner(14), Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)) }) })
	Kit.label({ Text = info.icon, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(50, 50), ZIndex = 24, Parent = tile })
	local tag = Kit.label({ Text = info.tag, Font = Kit.BLACK, TextSize = 12, TextColor3 = C.white, BackgroundColor3 = Color3.fromHex("#140E26"), BackgroundTransparency = 0.55, AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(0, 20), ZIndex = 25, Parent = tile })
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = tag })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = tag })
	Kit.label({ Text = nameOf(key), Font = Kit.BLACK, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 90), Size = UDim2.new(1, -24, 0, 20), ZIndex = 23, Parent = c })
	Kit.label({ Text = info.lines[1], TextSize = 13, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(12, 111), Size = UDim2.new(1, -24, 0, 32), ZIndex = 23, Parent = c })
	local price = Kit.label({ Text = if owned then "Есть ✓" else "R$ " .. priceOf(key), Font = Kit.BLACK, TextSize = 16, TextColor3 = if owned then C.dim else C.white, BackgroundColor3 = if owned then C.soft else Color3.fromHex("#34C759"), AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 10, 1, -10), Size = UDim2.new(1, -20, 0, 32), ZIndex = 23, Parent = c })
	Kit.new("UICorner", { CornerRadius = UDim.new(0, 10), Parent = price })
	c.Activated:Connect(function()
		Kit.click(c)
		M.explain(key)
	end)
	return c
end

local function grid(parent: Instance, order: number): Frame
	local g = Kit.frame({ BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -6, 0, 0), LayoutOrder = order, ZIndex = 22, Parent = parent })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 196), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
	return g
end


local SHOP_TABS = { { "passes", "Навсегда" }, { "boost", "Бусты" }, { "cosmetic", "Стиль" }, { "shards", "Осколки" }, { "season", "Пропуск" } }

function M.shop(tab: string?)
	shopTab = tab or shopTab
	if shopTab == "season" then
		M.pass()
		return
	end
	Kit.clear(shopBody)
	-- вкладки-«пилюли»: активная залита
	local tabs = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), ZIndex = 22, Parent = shopBody }, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left) })
	for i, t in SHOP_TABS do
		local active = t[1] == shopTab
		local b = Kit.new("TextButton", { Text = t[2], Font = Kit.BLACK, TextSize = 16, TextColor3 = if active then C.white else C.dim, BackgroundColor3 = if active then Color3.fromHex("#FF7A45") else C.panel, AutoButtonColor = true, Size = UDim2.fromOffset(98, 40), LayoutOrder = i, ZIndex = 22, Parent = tabs }, { Kit.corner(20) })
		b.Activated:Connect(function()
			Kit.click(b)
			M.shop(t[1])
		end)
	end
	local holder = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 1, -52), ZIndex = 22, Parent = shopBody })
	local s = Kit.scroll({ ZIndex = 22, Parent = holder }, { Kit.list(nil, 10, Enum.HorizontalAlignment.Left), Kit.pad(2) })
	local passes = State.s.passes or {}
	local once = State.s.once or {}
	if shopTab == "passes" then
		section(s, "Покупаются один раз и остаются навсегда", "Нажми на карточку — расскажем, что она даёт", 0)
		local g = grid(s, 1)
		for i, key in { "VIP", "AutoCollect", "ScannerPlus", "SecondFloor" } do
			productCard(g, i, key, passes[key] == true)
		end
	elseif shopTab == "boost" then
		section(s, "Ускорители", "Действуют сразу после покупки", 0)
		local g = grid(s, 1)
		productCard(g, 1, "Starter", once.Starter == true)
		productCard(g, 2, "BoostX2", false)
		productCard(g, 3, "Energy5", false)
	elseif shopTab == "cosmetic" then
		section(s, "Скины хроно-следа", "Покупаются за 💎 осколки, силу не дают", 0)
		local skins = State.s.skins or {}
		local g = Kit.frame({ BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, -6, 0, 0), LayoutOrder = 1, ZIndex = 22, Parent = s })
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(160, 150), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, Parent = g })
		for i, sk in Game.SKINS do
			if sk.shards >= 0 or skins[sk.id] then
				local owned = skins[sk.id]
				local equipped = State.s.skin == sk.id
				local c = Kit.frame({ BackgroundColor3 = C.panel, LayoutOrder = i, ZIndex = 22, Parent = g }, { Kit.corner(18) })
				if equipped then
					Kit.new("UIStroke", { Color = sk.color, Thickness = 3, Parent = c })
				end
				-- образец следа: три шарика по убыванию
				for k = 1, 3 do
					Kit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, (k - 2) * 30, 0, 38), Size = UDim2.fromOffset(34 - k * 6, 34 - k * 6), BackgroundColor3 = sk.color, BackgroundTransparency = (k - 1) * 0.25, ZIndex = 23, Parent = c }, { Kit.corner(20) })
				end
				Kit.label({ Text = L.name(sk.name), Font = Kit.BLACK, TextSize = 16, Position = UDim2.fromOffset(8, 66), Size = UDim2.new(1, -16, 0, 22), ZIndex = 23, Parent = c })
				Kit.button(if equipped then "Надет" elseif owned then "Надеть" else "💎 " .. sk.shards, if equipped then "cancel" elseif owned then "chrono" else "buy", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, -20, 0, 40), TextSize = 17, ZIndex = 23, Parent = c }, function()
					if equipped then
						return
					end
					State.act(if owned then "skinEquip" else "skinBuy", { id = sk.id })
					task.wait(0.3)
					M.shop()
				end)
			end
		end
		section(s, "Наборы", nil, 2)
		local g2 = grid(s, 3)
		productCard(g2, 1, "Titan", once.Titan == true)
	elseif shopTab == "shards" then
		section(s, "Хроно-осколки 💎", "Валюта для скинов хроно-следа", 0)
		local g = grid(s, 1)
		productCard(g, 1, "Shards100", false)
		productCard(g, 2, "Shards550", false)
		productCard(g, 3, "Shards1500", false)
	end
	Kit.open(shopWin)
end

-- после покупки (в т.ч. тестовой) перерисовать открытый магазин и пропуск
for _, key in { "once", "passes", "skins" } do
	State.on(key, function()
		if shopWin.Visible then
			M.shop()
		end
	end)
end

-- ── Сезонный пропуск ────────────────────────────────────────
-- Шапка: сезон, дни до конца, уровень и полоса опыта, откуда брать опыт.
-- Ниже — горизонтальная дорожка 20 уровней: сверху бесплатные награды, снизу ⭐ премиум.
local passWin, passBody = Kit.window(root, "Хроно-пропуск", 0.9, Color3.fromHex("#7B5CFF"))

local function reward(r: any): (string, string)
	if r.art == "seasonal" then
		return "🏆", "Сезонный Титан"
	elseif r.art then
		local info = Defs.RARITY[r.art]
		return "🥚", (info and L.name(info.name) or "") .. " существо"
	elseif r.shards then
		return "💎", tostring(r.shards)
	elseif r.tokens then
		return "🔨", "×" .. r.tokens
	elseif r.skin then
		return "✨", "Скин сезона"
	end
	return "💰", "5 мин дохода"
end

function M.pass()
	Kit.clear(passBody)
	local p = State.s.pass or { xp = 0, prem = false, cf = {}, cp = {} }
	local theme = workspace:GetAttribute("Season") or 1
	local sCfg = Game.SEASONS[theme] or Game.SEASONS[1]
	local ends = workspace:GetAttribute("SeasonEnds") or os.time()
	local lvl = math.floor(p.xp / Game.PASS_XP)
	local into = p.xp % Game.PASS_XP
	if lvl >= Game.PASS_LEVELS then
		into = Game.PASS_XP
	end
	-- шапка: значок уровня + полоса опыта
	local badge = Kit.frame({ Size = UDim2.fromOffset(64, 64), BackgroundColor3 = sCfg.color, ZIndex = 22, Parent = passBody }, { Kit.corner(32), Kit.new("UIStroke", { Color = C.white, Thickness = 3 }) })
	Kit.label({ Text = tostring(lvl), Font = Kit.BLACK, TextSize = 30, TextColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = badge }).TextStrokeTransparency = 0.6
	Kit.label({ Text = L.name(sCfg.name) .. " · ещё " .. math.max(0, math.ceil((ends - os.time()) / 86400)) .. " дн.", Font = Kit.BLACK, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(76, 2), Size = UDim2.new(1, -330, 0, 24), ZIndex = 22, Parent = passBody })
	local bar = Kit.frame({ Position = UDim2.fromOffset(76, 32), Size = UDim2.new(1, -330, 0, 14), BackgroundColor3 = C.soft, ZIndex = 22, Parent = passBody }, { Kit.corner(7) })
	Kit.frame({ Size = UDim2.fromScale(math.clamp(into / Game.PASS_XP, 0.02, 1), 1), BackgroundColor3 = sCfg.color, ZIndex = 23, Parent = bar }, { Kit.corner(7) })
	Kit.label({ Text = if lvl >= Game.PASS_LEVELS then "Максимальный уровень!" else into .. " / " .. Game.PASS_XP .. " опыта до уровня " .. (lvl + 1), TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(76, 48), Size = UDim2.new(1, -330, 0, 18), ZIndex = 22, Parent = passBody })
	-- откуда опыт
	local chips = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(244, 66), ZIndex = 22, Parent = passBody })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(118, 30), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = chips })
	for i, t in { { "🦝 Кража", Game.XP.steal }, { "📜 Квест", Game.XP.quest }, { "🛡️ Защита", Game.XP.defend }, { "🛒 Покупка", Game.XP.buy } } do
		local chip = Kit.label({ Text = t[1] .. "  +" .. t[2], TextSize = 14, BackgroundColor3 = C.panel, BackgroundTransparency = 0, LayoutOrder = i, ZIndex = 23, Parent = chips })
		Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = chip })
	end
	-- подписи рядов
	local TRACK_Y, ROW_H = 80, 92
	local labels = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, TRACK_Y), Size = UDim2.fromOffset(70, ROW_H * 2 + 30), ZIndex = 22, Parent = passBody })
	Kit.label({ Text = "Бесплатно", Font = Kit.BLACK, TextSize = 14, TextColor3 = C.dim, Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = 22, Parent = labels })
	Kit.label({ Text = "⭐\nПремиум", Font = Kit.BLACK, TextSize = 14, TextColor3 = Color3.fromHex("#D98A00"), Position = UDim2.fromOffset(0, ROW_H + 30), Size = UDim2.new(1, 0, 0, ROW_H), ZIndex = 22, Parent = labels })
	local track = Kit.scroll({ Position = UDim2.fromOffset(74, TRACK_Y), Size = UDim2.new(1, -74, 0, ROW_H * 2 + 40), ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 4, ZIndex = 22, Parent = passBody })
	local COL_W = 96
	-- линия прогресса между рядами
	local lineY = ROW_H + 15
	Kit.frame({ Position = UDim2.fromOffset(0, lineY - 3), Size = UDim2.fromOffset(COL_W * Game.PASS_LEVELS, 6), BackgroundColor3 = C.soft, ZIndex = 22, Parent = track }, { Kit.corner(3) })
	Kit.frame({ Position = UDim2.fromOffset(0, lineY - 3), Size = UDim2.fromOffset(COL_W * math.clamp(lvl - 0.5, 0, Game.PASS_LEVELS), 6), BackgroundColor3 = sCfg.color, ZIndex = 22, Parent = track }, { Kit.corner(3) })
	for level = 1, Game.PASS_LEVELS do
		local x = (level - 1) * COL_W
		local reached = level <= lvl
		local node = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x + COL_W / 2, lineY), Size = UDim2.fromOffset(28, 28), BackgroundColor3 = if reached then sCfg.color else C.bg, ZIndex = 23, Parent = track }, { Kit.corner(14), Kit.new("UIStroke", { Color = if reached then C.white else C.soft, Thickness = 2 }) })
		Kit.label({ Text = tostring(level), Font = Kit.BLACK, TextSize = 13, TextColor3 = if reached then C.white else C.dim, Size = UDim2.fromScale(1, 1), ZIndex = 24, Parent = node })
		for row, premium in { false, true } do
			local key = tostring(level)
			local claimed = if premium then p.cp[key] else p.cf[key]
			local locked = premium and not p.prem
			local can = reached and not claimed and not locked
			local icon, text = reward(Game.passReward(level, premium))
			local big = premium and (level % 5 == 0 or level == 1)
			local bg = if can then Color3.fromHex("#FFF3CC") elseif big then Color3.fromHex("#F3EDFF") else C.panel
			local t = Kit.new("TextButton", { Text = "", AutoButtonColor = can, BackgroundColor3 = bg, Position = UDim2.fromOffset(x + 6, if row == 1 then 0 else ROW_H + 30), Size = UDim2.fromOffset(COL_W - 12, ROW_H), ZIndex = 23, Parent = track }, { Kit.corner(16) })
			if can then
				Kit.new("UIStroke", { Color = Color3.fromHex("#FFB020"), Thickness = 3, Parent = t })
				Kit.pulse(t, true)
			elseif big then
				Kit.new("UIStroke", { Color = Color3.fromHex("#7B5CFF"), Thickness = 2, Transparency = 0.4, Parent = t })
			end
			Kit.label({ Text = icon, TextScaled = true, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(38, 38), ZIndex = 24, Parent = t })
			Kit.label({ Text = if can then "Забрать!" elseif claimed then "Получено" else text, Font = Kit.BLACK, TextSize = 12, TextColor3 = if can then Color3.fromHex("#B36B00") elseif claimed then C.ok else C.text, Position = UDim2.new(0, 4, 1, -36), Size = UDim2.new(1, -8, 0, 30), ZIndex = 24, Parent = t })
			if claimed or locked or not reached then
				-- приглушить недоступное
				Kit.frame({ Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.bg, BackgroundTransparency = if claimed then 0.45 else 0.35, ZIndex = 25, Parent = t }, { Kit.corner(16) })
				if locked then
					Kit.label({ Text = "🔒", TextSize = 18, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(22, 22), ZIndex = 26, Parent = t })
				elseif claimed then
					Kit.label({ Text = "✓", Font = Kit.BLACK, TextSize = 20, TextColor3 = C.ok, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -6, 0, 2), Size = UDim2.fromOffset(22, 22), ZIndex = 26, Parent = t })
				end
			end
			t.Activated:Connect(function()
				if can then
					Kit.click(t)
					if State.act("passClaim", { level = level, premium = premium }) then
						M.pass()
					end
				elseif locked then
					M.explain("SeasonPass")
				end
			end)
		end
	end
	-- прокрутить к текущему уровню
	track.CanvasPosition = Vector2.new(math.max(0, (lvl - 2) * COL_W), 0)
	if not p.prem then
		Kit.button("⭐ Открыть премиум — R$ " .. priceOf("SeasonPass"), "gold", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2), Size = UDim2.fromOffset(330, 50), TextSize = 19, ZIndex = 22, Parent = passBody }, function()
			M.explain("SeasonPass")
		end)
	else
		Kit.label({ Text = "⭐ Премиум открыт: +20% к доходу до конца сезона", Font = Kit.BLACK, TextSize = 16, TextColor3 = Color3.fromHex("#B36B00"), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.new(1, 0, 0, 24), ZIndex = 22, Parent = passBody })
	end
	Kit.open(passWin)
end
M.passBody = function(_s: Instance)
	M.pass()
end
State.on("pass", function()
	if passWin.Visible then
		M.pass()
	end
end)

-- ── Коллекция + хранилище ───────────────────────────────────
local collWin, collBody = Kit.window(root, "📖 Коллекция", 0.88, Color3.fromHex("#2EB8F0"))
function M.collection()
	local s = scrollBody(collBody)
	local coll = State.s.coll or {}
	local inv = State.s.inv or {}
	local n = 0
	for _, d in Defs.LIST do
		if coll[d.id] then
			n += 1
		end
	end
	-- общий прогресс
	local head = Kit.frame({ Size = UDim2.new(1, -6, 0, 54), BackgroundColor3 = C.panel, LayoutOrder = 0, ZIndex = 22, Parent = s }, { Kit.corner(16) })
	Kit.label({ Text = "Собрано " .. n .. " / " .. #Defs.LIST, Font = Kit.BLACK, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 0, 22), ZIndex = 23, Parent = head })
	local bar = Kit.frame({ Position = UDim2.fromOffset(14, 32), Size = UDim2.new(1, -28, 0, 10), BackgroundColor3 = C.soft, ZIndex = 23, Parent = head }, { Kit.corner(5) })
	Kit.frame({ Size = UDim2.fromScale(math.max(0.02, n / #Defs.LIST), 1), BackgroundColor3 = Color3.fromHex("#2EB8F0"), ZIndex = 24, Parent = bar }, { Kit.corner(5) })
	if #inv > 0 then
		section(s, "📦 Хранилище (" .. #inv .. "/" .. Game.INVENTORY_MAX .. ")", "Нажми на существо — поставить на пьедестал или сдать в осколки", 1)
		local g = tileGrid(s, 84, 2)
		for i, a in inv do
			local d = Defs.BY_ID[a.id]
			local t = artTile(g, a, 84, i)
			t.Activated:Connect(function()
				Hud.popup({ title = d and L.name(d.name) or "?", color = Color3.fromHex("#2EB8F0"), art = a.id, text = "Доход: " .. L.money((d and d.income or 0) * (1 + Game.ART_LVL_BONUS * (a.lvl - 1))) .. "/с", buttons = {
					{ "Поставить", "buy", function()
						State.act("invPlace", { i = i })
						M.collection()
					end },
					{ "В осколки", "danger", function()
						State.act("invSell", { i = i })
						M.collection()
					end },
				} })
			end)
		end
	end
	local order = 10
	for _, r in Defs.RARITIES do
		local list = {}
		local got = 0
		for _, d in Defs.LIST do
			if d.rarity == r then
				table.insert(list, d)
				if coll[d.id] then
					got += 1
				end
			end
		end
		order += 1
		local hdr = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 28), LayoutOrder = order, ZIndex = 22, Parent = s })
		chip(hdr, L.name(Defs.RARITY[r].name), Defs.RARITY[r].color, nil, { TextSize = 15, Size = UDim2.fromOffset(0, 26) })
		Kit.label({ Text = got .. " / " .. #list, TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Right, Size = UDim2.new(1, 0, 1, 0), ZIndex = 22, Parent = hdr })
		order += 1
		local g = tileGrid(s, 84, order)
		for i, d in list do
			local t = artTile(g, { id = d.id }, 84, i, false, nil, not coll[d.id])
			t.AutoButtonColor = false
			Kit.label({ Text = if coll[d.id] then L.name(d.name) else "???", Font = Kit.BLACK, TextSize = 11, TextColor3 = if coll[d.id] then C.text else C.dim, AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 2, 1, -2), Size = UDim2.new(1, -4, 0, 14), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, ZIndex = 26, Parent = t })
		end
	end
	Kit.open(collWin)
end

-- ── Лидерборды ──────────────────────────────────────────────
local boardWin, boardBody = Kit.window(root, "🏆 Лидерборды", 0.85, Color3.fromHex("#F29A00"))
function M.boards()
	local _, b = State.act("boards")
	b = b or State.boards
	local s = scrollBody(boardBody)
	local mine = Kit.frame({ Size = UDim2.new(1, -6, 0, 48), BackgroundColor3 = Color3.fromHex("#FFF6D6"), LayoutOrder = 0, ZIndex = 22, Parent = s }, { Kit.corner(16) })
	Kit.label({ Text = "Твой Титан-ранг: " .. tostring(State.s.titan or 0), Font = Kit.BLACK, TextSize = 18, TextColor3 = Color3.fromHex("#B36B00"), Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = mine })
	local MEDAL = { "🥇", "🥈", "🥉" }
	for i, sec in { { "titan", "⚔️ Титан-ранг (сезон)" }, { "collection", "📖 Коллекция" }, { "clans", "🛡️ Кланы" } } do
		section(s, sec[2], nil, i * 20)
		local rows = b[sec[1]] or {}
		if #rows == 0 then
			Kit.label({ Text = "Пока пусто — стань первым!", TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, -6, 0, 22), LayoutOrder = i * 20 + 1, ZIndex = 22, Parent = s })
		end
		for j, r in rows do
			local v = if sec[1] == "collection" then math.floor(r.value / 100) .. "/40" else tostring(r.value)
			local line = Kit.frame({ Size = UDim2.new(1, -6, 0, 38), BackgroundColor3 = if j <= 3 then Color3.fromHex("#FFF6D6") else C.panel, LayoutOrder = i * 20 + j, ZIndex = 22, Parent = s }, { Kit.corner(12) })
			Kit.label({ Text = MEDAL[j] or tostring(j), Font = Kit.BLACK, TextSize = if j <= 3 then 20 else 15, TextColor3 = C.dim, Size = UDim2.fromOffset(44, 38), ZIndex = 23, Parent = line })
			Kit.label({ Text = r.name, Font = Kit.BLACK, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -150, 1, 0), ZIndex = 23, Parent = line })
			Kit.label({ Text = v, Font = Kit.BLACK, TextSize = 16, TextColor3 = Color3.fromHex("#B36B00"), TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.new(1, -110, 0, 0), Size = UDim2.fromOffset(98, 38), ZIndex = 23, Parent = line })
		end
	end
	Kit.open(boardWin)
end

-- ── Квесты и серия ──────────────────────────────────────────
local questWin, questBody = Kit.window(root, "📜 Ежедневные квесты", 0.85, Color3.fromHex("#22B455"))
function M.quests()
	local s = scrollBody(questBody)
	local q = State.s.quests or { list = {} }
	-- серия входов: 7 кружков
	local st = State.s.streak or { count = 0 }
	local sc = Kit.frame({ Size = UDim2.new(1, -6, 0, 86), BackgroundColor3 = Color3.fromHex("#FFF1E6"), LayoutOrder = 0, ZIndex = 22, Parent = s }, { Kit.corner(18) })
	Kit.label({ Text = "🔥 Серия входов: " .. st.count .. " из 7", Font = Kit.BLACK, TextSize = 17, TextColor3 = Color3.fromHex("#C25A00"), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -200, 0, 22), ZIndex = 23, Parent = sc })
	local days = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -200, 0, 40), ZIndex = 23, Parent = sc }, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left) })
	for d = 1, 7 do
		local on = d <= st.count
		local dot = Kit.frame({ Size = UDim2.fromOffset(36, 36), BackgroundColor3 = if on then Color3.fromHex("#FF7A45") else C.white, LayoutOrder = d, ZIndex = 24, Parent = days }, { Kit.corner(18), Kit.new("UIStroke", { Color = Color3.fromHex("#FF7A45"), Thickness = 2, Transparency = if on then 0 else 0.5 }) })
		Kit.label({ Text = if d == 7 then "🎁" else tostring(d), Font = Kit.BLACK, TextSize = 14, TextColor3 = if on then C.white else C.dim, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = dot })
	end
	Kit.button(if st.claimed == false then "Забрать награду дня" else "Завтра — ещё награда", if st.claimed == false then "gold" else "cancel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(176, 50), TextSize = 15, ZIndex = 23, Parent = sc }, function()
		if st.claimed == false then
			State.act("streakClaim")
			task.wait(0.3)
			M.quests()
		end
	end)
	section(s, "Задания на сегодня", "За каждое: 💎 " .. Game.QUEST_REWARD.shards .. " и 🔨 " .. Game.QUEST_REWARD.tokens .. ", плюс опыт пропуска", 1)
	for i, item in q.list do
		local cfg
		for _, c in Game.QUESTS do
			if c.id == item.id then
				cfg = c
			end
		end
		if cfg then
			local done = item.p >= cfg.goal
			local c = row(s, 10 + i, {
				icon = if item.claimed then "✅" elseif done then "🎁" else "📜",
				color = if item.claimed then C.grey elseif done then Color3.fromHex("#FFB020") else Color3.fromHex("#22B455"),
				title = L.name(cfg.name),
				sub = math.min(item.p, cfg.goal) .. " / " .. cfg.goal,
				btn = if item.claimed then "Готово" elseif done then "Забрать" else "В процессе",
				kind = if done and not item.claimed then "gold" else "cancel",
				btnW = 130,
				dim = item.claimed,
				onClick = function()
					if done and not item.claimed and State.act("questClaim", { i = i }) then
						task.wait(0.3)
						M.quests()
					end
				end,
			})
			-- полоса прогресса под подписью
			local pb = Kit.frame({ Position = UDim2.new(0, 74, 1, -16), Size = UDim2.new(1, -234, 0, 6), BackgroundColor3 = C.soft, ZIndex = 23, Parent = c }, { Kit.corner(3) })
			Kit.frame({ Size = UDim2.fromScale(math.clamp(item.p / cfg.goal, 0.03, 1), 1), BackgroundColor3 = if done then Color3.fromHex("#FFB020") else Color3.fromHex("#22B455"), ZIndex = 24, Parent = pb }, { Kit.corner(3) })
		end
	end
	Kit.open(questWin)
end

-- ── Верстак ─────────────────────────────────────────────────
local benchWin, benchBody = Kit.window(root, "🔨 Верстак", 0.88, Color3.fromHex("#C9853B"))
local TRAP_ICON = { mine = "💣", slow = "🌀", decoy = "🎭" }
local TRAP_COL = { mine = Color3.fromHex("#FF4D6D"), slow = Color3.fromHex("#7B5CFF"), decoy = Color3.fromHex("#FFB020") }
function M.bench()
	local s = scrollBody(benchBody)
	local w = State.s.wall or { lvl = 1 }
	local tok = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 26), LayoutOrder = 0, ZIndex = 22, Parent = s })
	chip(tok, "🔨 Жетоны стройки: " .. (State.s.tokens or 0), Color3.fromHex("#C9853B"), nil, { TextSize = 14, Size = UDim2.fromOffset(0, 26) })
	section(s, "Защита базы", nil, 1)
	local cur = Game.WALLS[w.lvl]
	local nxt = Game.WALLS[w.lvl + 1]
	local refresh = function()
		task.wait(0.3)
		M.bench()
	end
	if w.build then
		row(s, 2, { icon = "🧱", color = Color3.fromHex("#C9853B"), title = "Стены: " .. L.name(cur.name) .. " · " .. cur.hp .. " HP", sub = "Строится: " .. L.duration(math.max(0, w.build.left)), subColor = C.gold, btn = "🔨 " .. math.max(1, math.ceil(w.build.left / 60)) .. " — сразу", kind = "chrono", btnW = 160, onClick = function()
			State.act("finishBuild", { what = "wall" })
			refresh()
		end })
	elseif nxt then
		row(s, 2, { icon = "🧱", color = Color3.fromHex("#C9853B"), title = "Стены: " .. L.name(cur.name) .. " · " .. cur.hp .. " HP", sub = "Дальше: " .. L.name(nxt.name) .. ", " .. nxt.hp .. " HP, стройка " .. L.duration(nxt.build), btn = L.money(nxt.cost), btnW = 140, onClick = function()
			State.act("wallUpgrade")
			refresh()
		end })
	else
		row(s, 2, { icon = "🧱", color = Color3.fromHex("#C9853B"), title = "Стены: " .. L.name(cur.name) .. " · " .. cur.hp .. " HP", sub = "Максимальный уровень!", subColor = C.ok })
	end
	local tool = State.s.tool or 1
	local nt = Game.TOOLS[tool + 1]
	row(s, 3, { icon = "⛏️", color = Color3.fromHex("#7B5CFF"), title = L.name(Game.TOOLS[tool].name) .. " · урон " .. Game.TOOLS[tool].dmg, sub = if nt then "Дальше: " .. L.name(nt.name) .. ", урон " .. nt.dmg .. " — быстрее ломаешь стены" else "Лучший инструмент!", subColor = if nt then nil else C.ok, btn = if nt then L.money(nt.cost) else nil, onClick = function()
		State.act("toolBuy", { tier = tool + 1 })
		refresh()
	end })
	section(s, "Ловушки", "8 мест по периметру базы. Срабатывают на воров", 4)
	local traps = (State.s.traps or { list = {} }).list
	for slot = 1, Game.TRAP_SLOTS do
		local t = traps[tostring(slot)]
		if t then
			local cfg = Game.TRAPS[t.k]
			local sub = "Уровень " .. t.l .. " из " .. #cfg.cost .. (if t.b then " · строится " .. L.duration(math.max(0, t.b)) else "")
			if t.b then
				row(s, 10 + slot, { icon = TRAP_ICON[t.k], color = TRAP_COL[t.k], title = slot .. ". " .. L.name(cfg.name), sub = sub, btn = "🔨 " .. math.max(1, math.ceil(t.b / 60)) .. " — сразу", kind = "chrono", btnW = 150, h = 66, onClick = function()
					State.act("finishBuild", { slot = slot })
					refresh()
				end })
			elseif t.l < #cfg.cost then
				row(s, 10 + slot, { icon = TRAP_ICON[t.k], color = TRAP_COL[t.k], title = slot .. ". " .. L.name(cfg.name), sub = sub, btn = "↑ " .. L.money(cfg.cost[t.l + 1]), btnW = 140, h = 66, onClick = function()
					State.act("trapUpgrade", { slot = slot })
					refresh()
				end })
			else
				row(s, 10 + slot, { icon = TRAP_ICON[t.k], color = TRAP_COL[t.k], title = slot .. ". " .. L.name(cfg.name), sub = "Максимальный уровень!", subColor = C.ok, h = 66 })
			end
		else
			-- пустое место: три варианта ловушки
			local c = Kit.frame({ Size = UDim2.new(1, -6, 0, 66), BackgroundColor3 = C.panel, LayoutOrder = 10 + slot, ZIndex = 22, Parent = s }, { Kit.corner(18) })
			Kit.label({ Text = slot .. ".", Font = Kit.BLACK, TextSize = 17, TextColor3 = C.dim, Size = UDim2.fromOffset(40, 66), ZIndex = 23, Parent = c })
			local opts = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(40, 10), Size = UDim2.new(1, -50, 0, 46), ZIndex = 23, Parent = c }, { Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left) })
			for i, kind in Game.TRAP_KINDS do
				local cfg = Game.TRAPS[kind]
				local b = Kit.button(TRAP_ICON[kind] .. " " .. L.name(cfg.name) .. " · " .. L.short(cfg.cost[1]), "plain", { Size = UDim2.fromOffset(148, 46), TextSize = 13, LayoutOrder = i, ZIndex = 24, Parent = opts }, function()
					State.act("trapPlace", { slot = slot, kind = kind })
					refresh()
				end)
				b.TextWrapped = true
			end
		end
	end
	Kit.open(benchWin)
end

-- ── Пьедестал ───────────────────────────────────────────────
function M.pedestal(slot: number)
	local slots = (State.s.slots or { list = {} }).list
	local a = slots[tostring(slot)]
	if not a then
		return
	end
	local d = Defs.BY_ID[a.id]
	if not d then
		return
	end
	local rinfo = Defs.RARITY[d.rarity]
	local rc = rinfo.color
	local inc = d.income * (1 + Game.ART_LVL_BONUS * (a.lvl - 1))
	local nextInc = d.income * (1 + Game.ART_LVL_BONUS * a.lvl)
	local cost = math.floor(d.income * (Game.PRICE_MULT[d.rarity] or 20) * Game.ART_UPGRADE_MULT * a.lvl)
	local shards = (Game.SHARDS_FOR[d.rarity] or 1) * a.lvl
	local perk = d.perk and Defs.PERKS[d.perk]
	local maxed = a.lvl >= Game.ART_MAX_LVL

	Kit.clear(sheet)
	sheet.Size = UDim2.fromOffset(520, 320)
	local close = function()
		sheet.Visible = false
		sheetBg.Visible = false
		sheet.Size = UDim2.fromOffset(440, 330)
	end
	-- слева: существо на плашке цвета редкости
	local tile = Kit.frame({ Position = UDim2.fromOffset(18, 18), Size = UDim2.fromOffset(180, 200), BackgroundColor3 = rc, BackgroundTransparency = 0.78, ZIndex = 42, Parent = sheet }, { Kit.corner(22), Kit.new("UIStroke", { Color = rc, Thickness = 2, Transparency = 0.3 }) })
	Kit.creature(a.id, { Size = UDim2.new(1, -10, 1, -40), Position = UDim2.fromOffset(5, 6), ZIndex = 43, Parent = tile })
	-- уровень: 5 точек
	local dots = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -10), Size = UDim2.fromOffset(120, 14), ZIndex = 43, Parent = tile }, { Kit.list(Enum.FillDirection.Horizontal, 6) })
	for i = 1, Game.ART_MAX_LVL do
		Kit.frame({ Size = UDim2.fromOffset(14, 14), BackgroundColor3 = if i <= a.lvl then rc else C.white, BackgroundTransparency = if i <= a.lvl then 0 else 0.3, LayoutOrder = i, ZIndex = 44, Parent = dots }, { Kit.corner(7) })
	end
	-- справа: редкость, имя, доход, перк
	local pill = Kit.label({ Text = L.name(rinfo.name), Font = Kit.BLACK, TextSize = 14, TextColor3 = C.white, BackgroundColor3 = rc, BackgroundTransparency = 0, AutomaticSize = Enum.AutomaticSize.X, Position = UDim2.fromOffset(216, 20), Size = UDim2.fromOffset(0, 24), ZIndex = 42, Parent = sheet })
	pill.TextStrokeTransparency = 0.6
	Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = pill })
	Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10), Parent = pill })
	Kit.label({ Text = L.name(d.name), Font = Kit.BLACK, TextSize = 28, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextScaled = false, Position = UDim2.fromOffset(216, 48), Size = UDim2.new(1, -234, 0, 34), ZIndex = 42, Parent = sheet })
	Kit.label({ Text = "Уровень " .. a.lvl .. " из " .. Game.ART_MAX_LVL, TextSize = 15, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(216, 82), Size = UDim2.new(1, -234, 0, 18), ZIndex = 42, Parent = sheet })
	local incBox = Kit.frame({ Position = UDim2.fromOffset(216, 108), Size = UDim2.new(1, -234, 0, 44), BackgroundColor3 = Color3.fromHex("#FFF6D6"), ZIndex = 42, Parent = sheet }, { Kit.corner(12) })
	Kit.label({ Text = "💰 " .. L.money(inc) .. "/с", Font = Kit.BLACK, TextSize = 22, TextColor3 = Color3.fromHex("#B36B00"), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ZIndex = 43, Parent = incBox })
	if not maxed then
		Kit.label({ Text = "→ " .. L.money(nextInc) .. "/с", TextSize = 15, TextColor3 = C.ok, TextXAlignment = Enum.TextXAlignment.Right, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 1, 0), ZIndex = 43, Parent = incBox })
	end
	if perk then
		local pb = Kit.frame({ Position = UDim2.fromOffset(216, 160), Size = UDim2.new(1, -234, 0, 58), BackgroundColor3 = C.panel, ZIndex = 42, Parent = sheet }, { Kit.corner(12) })
		Kit.label({ Text = "✨ " .. L.name(perk), Font = Kit.BLACK, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 18), ZIndex = 43, Parent = pb })
		Kit.label({ Text = L.name(perk.desc), TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 30), ZIndex = 43, Parent = pb })
	end
	-- кнопки: главная — улучшить; второстепенные — в хранилище и продать
	local row = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -16), Size = UDim2.new(1, -36, 0, 56), ZIndex = 42, Parent = sheet }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
	Kit.button(if maxed then "Макс. уровень" else "Улучшить · " .. L.money(cost), if maxed then "cancel" else "buy", { Size = UDim2.fromOffset(220, 56), TextSize = 19, LayoutOrder = 1, ZIndex = 43, Parent = row }, function()
		if not maxed and State.act("artUpgrade", { slot = slot }) then
			task.wait(0.25)
			M.pedestal(slot)
		end
	end)
	Kit.button("📦 В хранилище", "plain", { Size = UDim2.fromOffset(122, 56), TextSize = 15, LayoutOrder = 2, ZIndex = 43, Parent = row }, function()
		State.act("artToInv", { slot = slot })
		close()
	end)
	local armed = false
	local sell
	sell = Kit.button("Продать +" .. shards .. " 💎", "plain", { Size = UDim2.fromOffset(122, 56), TextSize = 15, TextColor3 = C.alarm, LayoutOrder = 3, ZIndex = 43, Parent = row }, function()
		-- продажа необратима: первое нажатие спрашивает подтверждение
		if not armed then
			armed = true
			sell.Text = "Точно? Тапни ещё"
			sell.BackgroundColor3 = Color3.fromHex("#FF4D6D")
			sell.TextColor3 = C.white
			task.delay(3, function()
				if armed and sell.Parent then
					armed = false
					sell.Text = "Продать +" .. shards .. " 💎"
					sell.BackgroundColor3 = Kit.KIND.plain[1]
					sell.TextColor3 = C.alarm
				end
			end)
			return
		end
		State.act("artSell", { slot = slot })
		close()
	end)
	local x = Kit.new("TextButton", { Text = "X", Font = Kit.BLACK, TextSize = 18, TextColor3 = C.dim, BackgroundColor3 = C.panel, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -12, 0, 12), Size = UDim2.fromOffset(38, 38), ZIndex = 44, Parent = sheet }, { Kit.corner(19) })
	x.Activated:Connect(close)
	sheetBg.Visible = true
	sheet.Visible = true
	Kit.pop(sheet, 0.9)
end

-- ── Ребёрс ──────────────────────────────────────────────────
local rebWin, rebBody = Kit.window(root, "🌀 Ребёрс", 0.86, Color3.fromHex("#2EB8F0"))
function M.rebirth()
	local s = scrollBody(rebBody)
	local r = State.s.rebirths
	if not r or not r.req then
		section(s, "Все " .. Game.REBIRTH_MAX .. " ребёрсов пройдены! 👑", "Ты прошёл всё — легенда хроно-острова", 0)
		Kit.open(rebWin)
		return
	end
	-- что получишь и что сбросится
	local top = Kit.frame({ Size = UDim2.new(1, -6, 0, 96), BackgroundColor3 = Color3.fromHex("#E3F6FD"), LayoutOrder = 0, ZIndex = 22, Parent = s }, { Kit.corner(18) })
	Kit.label({ Text = "Ребёрс " .. (r.n + 1) .. " из " .. Game.REBIRTH_MAX, Font = Kit.BLACK, TextSize = 22, TextColor3 = Color3.fromHex("#0F7FA8"), TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 8), Size = UDim2.new(1, -32, 0, 28), ZIndex = 23, Parent = top })
	Kit.label({ Text = "✓ Навсегда: доход ×" .. (r.n + 2) .. ", замок +10 сек", Font = Kit.BLACK, TextSize = 15, TextColor3 = C.ok, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 40), Size = UDim2.new(1, -32, 0, 20), ZIndex = 23, Parent = top })
	Kit.label({ Text = "↺ Сбросится: деньги и существа на базе (хроно-аномалии останутся)", TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(16, 64), Size = UDim2.new(1, -32, 0, 20), ZIndex = 23, Parent = top })
	section(s, "Что нужно", nil, 1)
	local cash = State.s.cash or 0
	local okCash = cash >= r.req.cash
	row(s, 2, { icon = if okCash then "✅" else "💰", color = if okCash then C.ok else Color3.fromHex("#FFB020"), title = L.money(r.req.cash), sub = if okCash then "Хватает" else "Ещё " .. L.money(r.req.cash - cash), subColor = if okCash then C.ok else C.dim, h = 62 })
	for i, need in r.req.need do
		local info = Defs.RARITY[need.rarity]
		row(s, 2 + i, { icon = "🥚", color = info.color, title = need.count .. " × " .. L.name(info.name) .. " или выше", sub = "Должны стоять на пьедесталах", h = 62 })
	end
	Kit.button(if r.can then "🌀 Вознестись" else "Пока не хватает", if r.can then "chrono" else "cancel", { Size = UDim2.new(1, -6, 0, 56), TextSize = 20, LayoutOrder = 20, ZIndex = 23, Parent = s }, function()
		if r.can and State.act("rebirth") then
			Kit.close(rebWin)
		end
	end)
	Kit.open(rebWin)
end

-- ── Трейд ───────────────────────────────────────────────────
local tradeWin, tradeBody = Kit.window(root, "🤝 Обмен", 0.9, Color3.fromHex("#FF7A45"))
local tradeView = nil
local myGive: { number } = {}

local function artIncome(it: any): number
	local d = Defs.BY_ID[it.id]
	if not d then
		return 0
	end
	return d.income * (1 + Game.ART_LVL_BONUS * ((it.lvl or 1) - 1))
end

local function drawTrade()
	local v = tradeView
	if not v then
		Kit.close(tradeWin)
		return
	end
	Kit.clear(tradeBody)
	-- ── верх: две стороны обмена ──
	local giveInc, getInc = 0, 0
	for _, it in v.mine do
		giveInc += artIncome(it)
	end
	for _, it in v.theirs do
		getInc += artIncome(it)
	end
	local function side(x: number, title: string, items: { any }, ready: boolean, total: number, mine: boolean)
		local p = Kit.frame({ Position = UDim2.new(x, if x == 0 then 0 else 6, 0, 0), Size = UDim2.new(0.5, -6, 0, 128), BackgroundColor3 = if ready then Color3.fromHex("#E7F8EC") else C.panel, ZIndex = 22, Parent = tradeBody }, { Kit.corner(18) })
		if ready then
			Kit.new("UIStroke", { Color = C.ok, Thickness = 2, Parent = p })
		end
		Kit.label({ Text = title, Font = Kit.BLACK, TextSize = 15, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -104, 0, 22), ZIndex = 23, Parent = p })
		local st = Kit.label({ Text = if ready then "✓ Готов" else "Выбирает…", Font = Kit.BLACK, TextSize = 11, TextColor3 = if ready then C.white else C.dim, BackgroundColor3 = if ready then C.ok else C.soft, BackgroundTransparency = 0, AutomaticSize = Enum.AutomaticSize.X, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.fromOffset(0, 18), ZIndex = 23, Parent = p })
		Kit.new("UICorner", { CornerRadius = UDim.new(1, 0), Parent = st })
		Kit.new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8), Parent = st })
		local grid = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 32), Size = UDim2.new(1, -16, 0, 56), ZIndex = 22, Parent = p }, { Kit.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center) })
		for i = 1, Game.TRADE_MAX_ITEMS do
			local it = items[i]
			if it then
				local t = artTile(grid, it, 52, i)
				if mine then
					t.Activated:Connect(function()
						local idx = table.find(myGive, it.i)
						if idx then
							table.remove(myGive, idx)
							State.act("tradeSet", { give = myGive })
						end
					end)
				end
			else
				local e = Kit.frame({ Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.bg, LayoutOrder = i, ZIndex = 23, Parent = grid }, { Kit.corner(14), Kit.new("UIStroke", { Color = C.soft, Thickness = 2 }) })
				Kit.label({ Text = "+", Font = Kit.BLACK, TextSize = 22, TextColor3 = C.soft, Size = UDim2.fromScale(1, 1), ZIndex = 24, Parent = e })
			end
		end
		Kit.label({ Text = "Доход: " .. L.money(total) .. "/с", TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.new(0, 10, 1, -28), Size = UDim2.new(1, -24, 0, 20), ZIndex = 23, Parent = p })
	end
	side(0, "Ты отдаёшь", v.mine, v.myReady == true, giveInc, true)
	side(0.5, v.name .. " отдаёт", v.theirs, v.theirReady == true, getInc, false)
	-- стрелка обмена между сторонами
	local sw = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.fromOffset(34, 34), BackgroundColor3 = Color3.fromHex("#FF7A45"), ZIndex = 24, Parent = tradeBody }, { Kit.corner(18), Kit.new("UIStroke", { Color = C.white, Thickness = 3 }) })
	Kit.label({ Text = "⇄", Font = Kit.BLACK, TextSize = 20, TextColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 25, Parent = sw })
	-- ── честность сделки по доходу ──
	local verdict, vcol
	if giveInc == 0 and getInc == 0 then
		verdict, vcol = "Добавь существ в обмен", C.dim
	elseif getInc >= giveInc * 1.15 then
		verdict, vcol = "👍 Выгодно тебе: +" .. L.money(getInc - giveInc) .. "/с", C.ok
	elseif giveInc >= getInc * 1.15 then
		verdict, vcol = "⚠️ Ты теряешь " .. L.money(giveInc - getInc) .. "/с дохода", C.alarm
	else
		verdict, vcol = "⚖️ Честный обмен", Color3.fromHex("#D98A00")
	end
	Kit.label({ Text = verdict, Font = Kit.BLACK, TextSize = 15, TextColor3 = vcol, Position = UDim2.fromOffset(0, 132), Size = UDim2.new(1, 0, 0, 20), ZIndex = 22, Parent = tradeBody })
	-- ── твои существа: хранилище + пьедесталы, горизонтальная лента ──
	Kit.label({ Text = "Твои существа — нажми, чтобы добавить (до " .. Game.TRADE_MAX_ITEMS .. ")", TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(2, 154), Size = UDim2.new(1, 0, 0, 18), ZIndex = 22, Parent = tradeBody })
	local strip = Kit.scroll({ Position = UDim2.fromOffset(0, 174), Size = UDim2.new(1, 0, 1, -230), ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 4, ZIndex = 22, Parent = tradeBody }, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left) })
	local inv = State.s.inv or {}
	local n = 0
	for i, a in inv do
		n += 1
		local sel = table.find(myGive, i) ~= nil
		local t = artTile(strip, a, 60, n, sel)
		t.Activated:Connect(function()
			local idx = table.find(myGive, i)
			if idx then
				table.remove(myGive, idx)
			elseif #myGive < Game.TRADE_MAX_ITEMS then
				table.insert(myGive, i)
			else
				Hud.toast("Максимум " .. Game.TRADE_MAX_ITEMS .. " существа в обмене", "bad")
				return
			end
			State.act("tradeSet", { give = myGive })
		end)
	end
	local slots = (State.s.slots or { list = {} }).list
	local keys = {}
	for k in slots do
		table.insert(keys, k)
	end
	table.sort(keys, function(x, y)
		return (tonumber(x) or 0) < (tonumber(y) or 0)
	end)
	for _, k in keys do
		n += 1
		local a = slots[k]
		local t = artTile(strip, a, 60, n, false, "🏛️")
		t.Activated:Connect(function()
			if #myGive >= Game.TRADE_MAX_ITEMS then
				Hud.toast("Максимум " .. Game.TRADE_MAX_ITEMS .. " существа в обмене", "bad")
				return
			end
			-- с пьедестала: сначала в хранилище, затем в обмен
			if State.act("artToInv", { slot = tonumber(k) }) then
				task.wait(0.35)
				table.insert(myGive, #(State.s.inv or {}))
				State.act("tradeSet", { give = myGive })
			end
		end)
	end
	if n == 0 then
		Kit.label({ Text = "Пока нечего предложить — купи существо на конвейере", TextSize = 15, TextColor3 = C.dim, Size = UDim2.fromOffset(400, 68), ZIndex = 23, Parent = strip })
	end
	-- ── кнопки ──
	local btns = Kit.frame({ BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 0, 0, 48), ZIndex = 22, Parent = tradeBody }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
	Kit.button("Отмена", "cancel", { Size = UDim2.fromOffset(140, 46), LayoutOrder = 1, ZIndex = 23, Parent = btns }, function()
		State.act("tradeCancel")
	end)
	Kit.button(if v.myReady then "Ждём " .. v.name .. "…" else "✓ Готов к обмену", if v.myReady then "cancel" else "buy", { Size = UDim2.fromOffset(240, 46), LayoutOrder = 2, ZIndex = 23, Parent = btns }, function()
		if not v.myReady then
			State.act("tradeReady")
		end
	end)
	Kit.open(tradeWin)
end

-- закрыли окно обмена крестиком или тапом по фону — отменяем обмен и на сервере
tradeWin:GetPropertyChangedSignal("Visible"):Connect(function()
	if not tradeWin.Visible and tradeView then
		tradeView = nil
		myGive = {}
		State.act("tradeCancel")
	end
end)

Net.event("Trade").OnClientEvent:Connect(function(view, reason)
	if not tradeView and view then
		myGive = {}
	end
	tradeView = view
	if not view then
		myGive = {}
		Kit.close(tradeWin)
		if reason == "done" then
			Hud.toast(L.t("msg.tradeDone"), "good")
		elseif reason == "declined" or reason == "failed" then
			Hud.toast(L.t("msg.tradeFailed"), "bad")
		end
		return
	end
	drawTrade()
end)

-- выбрать ближайшего игрока/бота для обмена
function M.tradeNearest()
	local char = player.Character
	local my = char and char:FindFirstChild("HumanoidRootPart")
	if not my then
		return
	end
	local best, bd = nil, 30
	for _, p in Players:GetPlayers() do
		local r = p ~= player and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if r and (r.Position - my.Position).Magnitude < bd then
			best, bd = p.UserId, (r.Position - my.Position).Magnitude
		end
	end
	local bots = workspace:FindFirstChild("Bots")
	if bots and not best then
		for _, b in bots:GetChildren() do
			local r = b:FindFirstChild("HumanoidRootPart")
			if r and b.Name:find("Торговец") and (r.Position - my.Position).Magnitude < bd then
				best = -1
			end
		end
	end
	if not best then
		Hud.toast("Подойди к игроку (ближе 30 стад)", "bad")
		return
	end
	if best == -1 then
		-- id бота-торговца ищем на сервере по ближайшему; сервер сам проверит расстояние
		for _, b in bots:GetChildren() do
			if b.Name:find("Торговец") then
				best = b:GetAttribute("BotId")
			end
		end
	end
	State.act("tradeRequest", { target = best })
end

-- ── Кланы ───────────────────────────────────────────────────
local clanWin, clanBody = Kit.window(root, "🛡️ Клан", 0.8, Color3.fromHex("#7B5CFF"))
local function inputBox(parent: Instance, ph: string, order: number): TextBox
	local f = Kit.frame({ Size = UDim2.new(1, -6, 0, 50), BackgroundColor3 = C.panel, LayoutOrder = order, ZIndex = 22, Parent = parent }, { Kit.corner(14), Kit.new("UIStroke", { Color = C.soft, Thickness = 2 }) })
	return Kit.new("TextBox", { PlaceholderText = ph, PlaceholderColor3 = C.grey, Text = "", Font = Kit.FONT, TextSize = 19, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Left, BackgroundTransparency = 1, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), ZIndex = 23, ClearTextOnFocus = false, Parent = f })
end
function M.clan()
	local s = scrollBody(clanBody)
	local c = State.s.clan
	if c then
		local head = Kit.frame({ Size = UDim2.new(1, -6, 0, 92), BackgroundColor3 = Color3.fromHex("#EFEAFF"), LayoutOrder = 0, ZIndex = 22, Parent = s }, { Kit.corner(18) })
		local badge = Kit.frame({ AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, 0), Size = UDim2.fromOffset(68, 68), BackgroundColor3 = Color3.fromHex("#7B5CFF"), ZIndex = 23, Parent = head }, { Kit.corner(18) })
		Kit.label({ Text = c.tag, Font = Kit.BLACK, TextSize = 20, TextColor3 = C.white, Size = UDim2.fromScale(1, 1), ZIndex = 24, Parent = badge })
		Kit.label({ Text = c.name or "", Font = Kit.BLACK, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(94, 16), Size = UDim2.new(1, -110, 0, 28), ZIndex = 23, Parent = head })
		local tags = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(94, 50), Size = UDim2.new(1, -110, 0, 24), ZIndex = 23, Parent = head }, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left) })
		chip(tags, "👥 " .. (c.count or 1) .. "/" .. Game.CLAN_MAX, Color3.fromHex("#7B5CFF"))
		chip(tags, "⭐ Очки: " .. (c.points or 0), Color3.fromHex("#FFB020"), Color3.fromHex("#3A2600"))
		section(s, "Бонусы клана", nil, 1)
		row(s, 2, { icon = "⚔️", color = Color3.fromHex("#FF4D6D"), title = "Клановый рейд", sub = "2+ соклановца на одной базе: взлом +30%, награда +20%", h = 66 })
		row(s, 3, { icon = "💬", color = Color3.fromHex("#2EB8F0"), title = "Чат клана", sub = "Отдельная вкладка в обычном чате Roblox", h = 66 })
		Kit.button("Покинуть клан", "plain", { Size = UDim2.new(1, -6, 0, 50), TextColor3 = C.alarm, LayoutOrder = 10, ZIndex = 23, Parent = s }, function()
			State.act("clanLeave")
			task.wait(0.4)
			M.clan()
		end)
	else
		section(s, "Играй вместе с друзьями", "Вступи по тегу или создай свой клан за " .. L.money(Game.CLAN_COST), 0)
		row(s, 1, { icon = "⚔️", color = Color3.fromHex("#FF4D6D"), title = "Клановый рейд: взлом +30%, награда +20%", sub = "Когда 2+ соклановца грабят одну базу", h = 62 })
		local tagBox = inputBox(s, "ТЕГ (2–5 букв)", 2)
		local nameBox = inputBox(s, "Название (для создания)", 3)
		local btns = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 54), LayoutOrder = 4, ZIndex = 22, Parent = s }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
		Kit.button("Вступить", "chrono", { Size = UDim2.fromOffset(180, 52), ZIndex = 23, Parent = btns }, function()
			State.act("clanJoin", { tag = tagBox.Text })
			task.wait(0.4)
			M.clan()
		end)
		Kit.button("Создать · " .. L.money(Game.CLAN_COST), "buy", { Size = UDim2.fromOffset(220, 52), ZIndex = 23, Parent = btns }, function()
			State.act("clanCreate", { tag = tagBox.Text, name = nameBox.Text })
			task.wait(0.4)
			M.clan()
		end)
	end
	Kit.open(clanWin)
end

-- ── Тест-панель владельца ───────────────────────────────────
local testWin, testBody = Kit.window(root, "🧪 Тест (видишь только ты)", 0.75, Color3.fromHex("#6E6688"))
M.testBuy = false
function M.test()
	local s = scrollBody(testBody)
	local function b(text: string, kind: string, fn: () -> ())
		Kit.button(text, kind, { Size = UDim2.new(1, -20, 0, 54), ZIndex = 23, Parent = s }, fn)
	end
	b("🤖 Бот-рейдер на мою базу", "danger", function()
		State.act("testRaid")
	end)
	b("🏚️ Обновить базу-бота (с охранником)", "thief", function()
		State.act("testBotBase")
	end)
	b("🤝 Обмен с ботом-торговцем (подойди к нему в хабе)", "chrono", function()
		Kit.close(testWin)
		M.tradeNearest()
	end)
	b("💰 +1M Cash, +10 жетонов, +10 энергии", "gold", function()
		State.act("testCash")
	end)
	for _, r in Defs.RARITIES do
		b("➕ Артефакт: " .. L.name(Defs.RARITY[r].name), "plain", function()
			State.act("testArt", { rarity = r })
		end)
	end
	b("🎓 Пройти обучение заново", "plain", function()
		Kit.close(testWin)
		State.act("testFtue")
	end)
	b((if M.testBuy then "✅" else "⬜") .. " Тестовые покупки без Robux", "plain", function()
		M.testBuy = not M.testBuy
		M.test()
	end)
	Kit.open(testWin)
end

-- ── Меню ────────────────────────────────────────────────────
local menuWin, menuBody = Kit.window(root, "Меню", 0.72, Color3.fromHex("#231A3B"))
function M.menu()
	Kit.clear(menuBody)
	local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = menuBody })
	Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(124, 112), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = g })
	local items = {
		{ "📖", "Коллекция", "#2EB8F0", M.collection },
		{ "📜", "Квесты", "#22B455", M.quests },
		{ "⭐", "Пропуск", "#7B5CFF", M.pass },
		{ "🏆", "Рейтинг", "#F29A00", M.boards },
		{ "🛡️", "Клан", "#7B5CFF", M.clan },
		{ "🤝", "Обмен", "#FF7A45", M.tradeNearest },
	}
	if State.s.tester then
		table.insert(items, { "🧪", "Тест", "#6E6688", M.test })
	end
	for i, it in items do
		local col = Color3.fromHex(it[3])
		local b = Kit.new("TextButton", { Text = "", AutoButtonColor = true, BackgroundColor3 = C.panel, LayoutOrder = i, ZIndex = 22, Parent = g }, { Kit.corner(20) })
		local tile = Kit.frame({ AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.fromOffset(58, 58), BackgroundColor3 = col, ZIndex = 23, Parent = b }, { Kit.corner(18), Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)) }) })
		Kit.label({ Text = it[1], TextScaled = true, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62), ZIndex = 24, Parent = tile })
		Kit.label({ Text = it[2], Font = Kit.BLACK, TextSize = 16, Position = UDim2.new(0, 0, 1, -34), Size = UDim2.new(1, 0, 0, 24), ZIndex = 23, Parent = b })
		b.Activated:Connect(function()
			Kit.click(b)
			Kit.close(menuWin)
			it[4]()
		end)
	end
	Kit.open(menuWin)
end

-- хранилище поменялось — перерисовать открытый обмен
State.on("inv", function()
	if tradeView then
		drawTrade()
	end
end)

return M
