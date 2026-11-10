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

local function txt(parent: Instance, text: string, size: number?, color: Color3?, h: number?, order: number?): TextLabel
	return Kit.label({ Text = text, TextSize = size or 20, TextColor3 = color or C.text, Size = UDim2.new(1, 0, 0, h or 28), LayoutOrder = order or 0, ZIndex = 22, Parent = parent })
end

local function card(parent: Instance, h: number, order: number?, color: Color3?): Frame
	local f = Kit.frame({ Size = UDim2.new(1, -6, 0, h), BackgroundColor3 = C.panel, LayoutOrder = order or 0, ZIndex = 22, Parent = parent }, { Kit.corner(18) })
	if color then
		Kit.new("UIStroke", { Color = color, Thickness = 2, Transparency = 0.35, Parent = f })
	end
	return f
end

local function scrollBody(body: Frame): ScrollingFrame
	Kit.clear(body)
	return Kit.scroll({ ZIndex = 22, Parent = body }, { Kit.list(nil, 8), Kit.pad(4) })
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
	txt(s, "Выбери базу для рейда (−1 ⚡ уже списана)", 18, C.dim, 26, 0)
	for i, b in list do
		local c = card(s, 130, i, DEF_COL[b.defense])
		Kit.label({ Text = (if b.kind == "offline" then "💤 " elseif b.kind == "bot" then "🤖 " else "🟢 ") .. (b.name ~= "" and b.name or "База " .. b.index), Font = Kit.BLACK, TextSize = 22, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 28), ZIndex = 23, Parent = c })
		Kit.label({ Text = "🛡️ " .. DEF_NAME[b.defense] .. "   🧱 ур." .. b.wall .. (if b.shield then "   🔒" else ""), TextSize = 19, TextColor3 = DEF_COL[b.defense], TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 40), Size = UDim2.new(1, -28, 0, 24), ZIndex = 23, Parent = c })
		Kit.label({ Text = "💰 лут ≈ " .. L.money(b.loot), TextSize = 19, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 66), Size = UDim2.new(1, -28, 0, 24), ZIndex = 23, Parent = c })
		Kit.button("Вторгнуться", if b.defense == 3 then "danger" else "thief", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(170, 50), ZIndex = 23, Parent = c }, function()
			if State.act("invade", { index = b.index }) then
				Kit.close(scanWin)
			end
		end)
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

local function section(parent: Instance, text: string, sub: string?, order: number)
	local f = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, if sub then 44 else 28), LayoutOrder = order, ZIndex = 22, Parent = parent })
	Kit.label({ Text = text, Font = Kit.BLACK, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Size = UDim2.new(1, 0, 0, 24), ZIndex = 22, Parent = f })
	if sub then
		Kit.label({ Text = sub, TextSize = 14, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 18), ZIndex = 22, Parent = f })
	end
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
local collWin, collBody = Kit.window(root, "📖 Коллекция", 0.85, Color3.fromHex("#2EB8F0"))
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
	txt(s, "Собрано " .. n .. " / " .. #Defs.LIST, 22, C.gold, 30, 0)
	if #inv > 0 then
		txt(s, "📦 Хранилище (" .. #inv .. "/" .. Game.INVENTORY_MAX .. ") — нажми, чтобы поставить на пьедестал", 16, C.dim, 40, 1)
		local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.ceil(#inv / 4) * 108), LayoutOrder = 2, ZIndex = 22, Parent = s }, { Kit.grid(Vector2.new(84, 100), 6) })
		for i, a in inv do
			local d = Defs.BY_ID[a.id]
			local b = Kit.new("TextButton", { Text = "", BackgroundColor3 = C.panel, LayoutOrder = i, ZIndex = 22, Parent = g }, { Kit.corner(12), Kit.stroke(d and RCOL[d.rarity] or C.soft, 3) })
			Kit.creature(a.id, { Size = UDim2.new(1, 0, 1, -22), ZIndex = 23, Parent = b })
			Kit.label({ Text = "ур." .. a.lvl, TextSize = 14, Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 20), ZIndex = 23, Parent = b })
			b.Activated:Connect(function()
				Hud.popup({ title = d and L.name(d.name) or "?", color = C.panel2, art = a.id, text = "Доход: " .. L.money((d and d.income or 0) * (1 + 0.25 * (a.lvl - 1))) .. "/с", buttons = {
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
		order += 1
		txt(s, L.name(Defs.RARITY[r].name), 22, RCOL[r], 30, order)
		local list = {}
		for _, d in Defs.LIST do
			if d.rarity == r then
				table.insert(list, d)
			end
		end
		order += 1
		local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.ceil(#list / 4) * 118), LayoutOrder = order, ZIndex = 22, Parent = s }, { Kit.grid(Vector2.new(84, 110), 6) })
		for i, d in list do
			local got = coll[d.id] == true
			local f = Kit.frame({ BackgroundColor3 = C.panel, LayoutOrder = i, ZIndex = 22, Parent = g }, { Kit.corner(12), Kit.stroke(if got then RCOL[r] else C.soft, 3) })
			Kit.creature(d.id, { Size = UDim2.new(1, 0, 1, -30), ZIndex = 23, Parent = f }, not got)
			Kit.label({ Text = if got then L.name(d.name) else "?", TextSize = 13, Position = UDim2.new(0, 2, 1, -30), Size = UDim2.new(1, -4, 0, 28), ZIndex = 23, Parent = f })
		end
	end
	Kit.open(collWin)
end

-- ── Лидерборды ──────────────────────────────────────────────
local boardWin, boardBody = Kit.window(root, "🏆 Лидерборды", 0.8, Color3.fromHex("#F29A00"))
function M.boards()
	local _, b = State.act("boards")
	b = b or State.boards
	local s = scrollBody(boardBody)
	for i, sec in { { "titan", "⚔️ Титан-ранг (сезон)" }, { "collection", "📖 Коллекция" }, { "clans", "🛡️ Кланы" } } do
		txt(s, sec[2], 22, C.gold, 30, i * 20)
		for j, row in b[sec[1]] or {} do
			local v = if sec[1] == "collection" then math.floor(row.value / 100) .. "/40" else tostring(row.value)
			txt(s, (if j == 1 then "👑 " else j .. ". ") .. row.name .. " — " .. v, 19, if j == 1 then C.gold else C.text, 26, i * 20 + j)
		end
	end
	txt(s, "Твой Титан-ранг: " .. tostring(State.s.titan or 0), 20, C.chrono, 30, 100)
	Kit.open(boardWin)
end

-- ── Квесты и серия ──────────────────────────────────────────
local questWin, questBody = Kit.window(root, "📜 Ежедневные квесты", 0.7, Color3.fromHex("#22B455"))
function M.quests()
	local s = scrollBody(questBody)
	local q = State.s.quests or { list = {} }
	for i, item in q.list do
		local cfg
		for _, c in Game.QUESTS do
			if c.id == item.id then
				cfg = c
			end
		end
		if cfg then
			local done = item.p >= cfg.goal
			local c = card(s, 84, i, if item.claimed then C.grey elseif done then C.gold else C.line)
			Kit.label({ Text = L.name(cfg.name), Font = Kit.BLACK, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -170, 0, 30), ZIndex = 23, Parent = c })
			Kit.label({ Text = item.p .. " / " .. cfg.goal .. "   🎁 💎" .. Game.QUEST_REWARD.shards .. " 🔨" .. Game.QUEST_REWARD.tokens, TextSize = 17, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(14, 42), Size = UDim2.new(1, -170, 0, 26), ZIndex = 23, Parent = c })
			Kit.button(if item.claimed then "✓" elseif done then "Забрать" else "…", if done and not item.claimed then "gold" else "cancel", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 52), ZIndex = 23, Parent = c }, function()
				if done and not item.claimed and State.act("questClaim", { i = i }) then
					task.wait(0.3)
					M.quests()
				end
			end)
		end
	end
	local st = State.s.streak or { count = 0 }
	txt(s, "🔥 Серия входов: " .. st.count .. " / 7 (7-й день — редкий артефакт)", 18, C.orange, 30, 20)
	if st.claimed == false then
		Kit.button("Забрать награду дня", "gold", { Size = UDim2.new(1, -20, 0, 54), LayoutOrder = 21, ZIndex = 23, Parent = s }, function()
			State.act("streakClaim")
			task.wait(0.3)
			M.quests()
		end)
	end
	Kit.open(questWin)
end

-- ── Верстак ─────────────────────────────────────────────────
local benchWin, benchBody = Kit.window(root, "🔨 Верстак", 0.8, Color3.fromHex("#C9853B"))
local TRAP_ICON = { mine = "💣", slow = "🌀", decoy = "🎭" }
function M.bench()
	local s = scrollBody(benchBody)
	local w = State.s.wall or { lvl = 1 }
	txt(s, "🔨 Жетоны стройки: " .. (State.s.tokens or 0), 18, C.dim, 26, 0)
	-- стены
	local c = card(s, 110, 1, C.orange)
	local cur = Game.WALLS[w.lvl]
	Kit.label({ Text = "🧱 Стены: " .. L.name(cur.name) .. " (ур." .. w.lvl .. ", " .. cur.hp .. " HP)", Font = Kit.BLACK, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), ZIndex = 23, Parent = c })
	local nxt = Game.WALLS[w.lvl + 1]
	if w.build then
		Kit.label({ Text = "Строится: " .. L.duration(math.max(0, w.build.left)), TextSize = 18, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -200, 0, 26), ZIndex = 23, Parent = c })
		Kit.button("🔨 " .. math.max(1, math.ceil(w.build.left / 60)) .. " — сразу", "chrono", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(170, 52), ZIndex = 23, Parent = c }, function()
			State.act("finishBuild", { what = "wall" })
			task.wait(0.3)
			M.bench()
		end)
	elseif nxt then
		Kit.label({ Text = "→ " .. L.name(nxt.name) .. ", " .. nxt.hp .. " HP, " .. L.duration(nxt.build), TextSize = 17, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -200, 0, 26), ZIndex = 23, Parent = c })
		Kit.button(L.money(nxt.cost), "buy", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(150, 52), ZIndex = 23, Parent = c }, function()
			State.act("wallUpgrade")
			task.wait(0.3)
			M.bench()
		end)
	end
	-- инструмент
	local tool = State.s.tool or 1
	local t2 = card(s, 90, 2, C.thief)
	Kit.label({ Text = "⛏️ " .. L.name(Game.TOOLS[tool].name) .. " (урон " .. Game.TOOLS[tool].dmg .. ")", Font = Kit.BLACK, TextSize = 19, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 30), ZIndex = 23, Parent = t2 })
	local nt = Game.TOOLS[tool + 1]
	if nt then
		Kit.label({ Text = "→ " .. L.name(nt.name) .. " (урон " .. nt.dmg .. ")", TextSize = 17, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(1, -180, 0, 26), ZIndex = 23, Parent = t2 })
		Kit.button(L.money(nt.cost), "buy", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -10, 1, -10), Size = UDim2.fromOffset(150, 50), ZIndex = 23, Parent = t2 }, function()
			State.act("toolBuy", { tier = tool + 1 })
			task.wait(0.3)
			M.bench()
		end)
	end
	-- ловушки
	txt(s, "Ловушки (8 слотов по периметру)", 20, C.gold, 30, 3)
	local traps = (State.s.traps or { list = {} }).list
	for slot = 1, Game.TRAP_SLOTS do
		local t = traps[tostring(slot)]
		local tc = card(s, 76, 10 + slot)
		if t then
			local cfg = Game.TRAPS[t.k]
			Kit.label({ Text = TRAP_ICON[t.k] .. " " .. slot .. ". " .. L.name(cfg.name) .. " ур." .. t.l .. (if t.b then " ⏳" .. L.duration(math.max(0, t.b)) else ""), TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -180, 1, 0), ZIndex = 23, Parent = tc })
			if t.b then
				Kit.button("🔨 " .. math.max(1, math.ceil(t.b / 60)), "chrono", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(110, 50), ZIndex = 23, Parent = tc }, function()
					State.act("finishBuild", { slot = slot })
					task.wait(0.3)
					M.bench()
				end)
			elseif t.l < #cfg.cost then
				Kit.button("↑ " .. L.money(cfg.cost[t.l + 1]), "buy", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(150, 50), ZIndex = 23, Parent = tc }, function()
					State.act("trapUpgrade", { slot = slot })
					task.wait(0.3)
					M.bench()
				end)
			end
		else
			Kit.label({ Text = slot .. ".", TextSize = 18, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(12, 0), Size = UDim2.fromOffset(30, 76), ZIndex = 23, Parent = tc })
			for i, kind in Game.TRAP_KINDS do
				local cfg = Game.TRAPS[kind]
				Kit.button(TRAP_ICON[kind] .. " " .. L.short(cfg.cost[1]), "plain", { Position = UDim2.new(0, 40 + (i - 1) * 104, 0, 12), Size = UDim2.fromOffset(100, 52), TextSize = 17, ZIndex = 23, Parent = tc }, function()
					State.act("trapPlace", { slot = slot, kind = kind })
					task.wait(0.3)
					M.bench()
				end)
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
	local inc = d.income * (1 + Game.ART_LVL_BONUS * (a.lvl - 1))
	local cost = math.floor(d.income * (Game.PRICE_MULT[d.rarity] or 20) * Game.ART_UPGRADE_MULT * a.lvl)
	local perk = d.perk and Defs.PERKS[d.perk]
	Hud.popup({
		title = L.name(d.name),
		color = C.panel2,
		art = a.id,
		text = L.name(Defs.RARITY[d.rarity].name) .. " · ур." .. a.lvl .. "\n" .. L.money(inc) .. "/с" .. (if perk then "\n✨ " .. L.name(perk) .. ": " .. L.name(perk.desc) else ""),
		buttons = {
			{ if a.lvl < Game.ART_MAX_LVL then "↑ " .. L.money(cost) else "Макс.", "buy", function()
				if a.lvl < Game.ART_MAX_LVL then
					State.act("artUpgrade", { slot = slot })
				end
			end },
			{ "📦", "plain", function()
				State.act("artToInv", { slot = slot })
			end },
			{ "💎", "danger", function()
				State.act("artSell", { slot = slot })
			end },
		},
	})
end

-- ── Ребёрс ──────────────────────────────────────────────────
local rebWin, rebBody = Kit.window(root, "🌀 Ребёрс", 0.6, Color3.fromHex("#2EB8F0"))
function M.rebirth()
	local s = scrollBody(rebBody)
	local r = State.s.rebirths
	if not r or not r.req then
		txt(s, "Все 18 ребёрсов пройдены! 👑", 22, C.gold, 40, 0)
		Kit.open(rebWin)
		return
	end
	txt(s, "Ребёрс " .. (r.n + 1) .. " / " .. Game.REBIRTH_MAX, 24, C.chrono, 32, 0)
	txt(s, "Навсегда: доход ×" .. (r.n + 2) .. ", замок +10 сек", 19, C.ok, 28, 1)
	txt(s, "Сбросится: деньги и артефакты на базе (хроно-аномалии останутся)", 17, C.dim, 44, 2)
	txt(s, "Нужно:", 20, C.gold, 28, 3)
	local cash = State.s.cash or 0
	txt(s, (if cash >= r.req.cash then "✅ " else "❌ ") .. L.money(r.req.cash), 20, C.text, 28, 4)
	for i, need in r.req.need do
		txt(s, "• " .. need.count .. " × " .. L.name(Defs.RARITY[need.rarity].name) .. " или выше на пьедесталах", 18, RCOL[need.rarity], 28, 4 + i)
	end
	Kit.button("Вознестись", if r.can then "chrono" else "cancel", { Size = UDim2.new(1, -20, 0, 60), LayoutOrder = 20, ZIndex = 23, Parent = s }, function()
		if r.can and State.act("rebirth") then
			Kit.close(rebWin)
		end
	end)
	Kit.open(rebWin)
end

-- ── Трейд ───────────────────────────────────────────────────
local tradeWin, tradeBody = Kit.window(root, "🤝 Обмен", 0.85, Color3.fromHex("#FF7A45"))
local tradeView = nil
local myGive: { number } = {}

local function drawTrade()
	local v = tradeView
	if not v then
		Kit.close(tradeWin)
		return
	end
	local s = scrollBody(tradeBody)
	txt(s, "С: " .. v.name, 20, C.chrono, 28, 0)
	local function row(title: string, items: { any }, order: number)
		txt(s, title, 18, C.dim, 24, order)
		local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 96), LayoutOrder = order + 1, ZIndex = 22, Parent = s }, { Kit.grid(Vector2.new(80, 90), 6) })
		for _, it in items do
			local f = Kit.frame({ BackgroundColor3 = C.panel, ZIndex = 22, Parent = g }, { Kit.corner(12) })
			Kit.creature(it.id, { Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = f })
		end
	end
	row("Ты отдаёшь" .. (if v.myReady then " ✅" else ""), v.mine, 1)
	row(v.name .. " отдаёт" .. (if v.theirReady then " ✅" else ""), v.theirs, 3)
	txt(s, "Хранилище — нажми, чтобы добавить или убрать (до " .. Game.TRADE_MAX_ITEMS .. ")", 16, C.dim, 40, 5)
	local inv = State.s.inv or {}
	local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.max(1, math.ceil(#inv / 4)) * 96), LayoutOrder = 6, ZIndex = 22, Parent = s }, { Kit.grid(Vector2.new(80, 90), 6) })
	for i, a in inv do
		local sel = table.find(myGive, i) ~= nil
		local b = Kit.new("TextButton", { Text = "", BackgroundColor3 = if sel then C.gold else C.panel, ZIndex = 22, Parent = g }, { Kit.corner(12) })
		Kit.creature(a.id, { Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = b })
		b.Activated:Connect(function()
			local idx = table.find(myGive, i)
			if idx then
				table.remove(myGive, idx)
			elseif #myGive < Game.TRADE_MAX_ITEMS then
				table.insert(myGive, i)
			end
			State.act("tradeSet", { give = myGive })
		end)
	end
	local slots = (State.s.slots or { list = {} }).list
	local keys = {}
	for k in slots do
		table.insert(keys, k)
	end
	if #keys > 0 then
		txt(s, "На пьедесталах — нажми, чтобы добавить в обмен", 16, C.dim, 26, 8)
		local g2 = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, math.ceil(#keys / 5) * 96), LayoutOrder = 9, ZIndex = 22, Parent = s }, { Kit.grid(Vector2.new(80, 90), 6) })
		for _, k in keys do
			local a = slots[k]
			local b = Kit.new("TextButton", { Text = "", BackgroundColor3 = C.panel, ZIndex = 22, Parent = g2 }, { Kit.corner(12), Kit.stroke(C.soft, 3) })
			Kit.creature(a.id, { Size = UDim2.fromScale(1, 1), ZIndex = 23, Parent = b })
			b.Activated:Connect(function()
				-- перенос в хранилище, затем выбрать его в обмен
				if State.act("artToInv", { slot = tonumber(k) }) then
					task.wait(0.35)
					local inv = State.s.inv or {}
					if #myGive < Game.TRADE_MAX_ITEMS then
						table.insert(myGive, #inv)
					end
					State.act("tradeSet", { give = myGive })
				end
			end)
		end
	end
	local btns = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 10, ZIndex = 22, Parent = s }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
	Kit.button("Подтвердить", "buy", { Size = UDim2.fromOffset(170, 56), ZIndex = 23, Parent = btns }, function()
		State.act("tradeReady")
	end)
	Kit.button("Отмена", "cancel", { Size = UDim2.fromOffset(140, 56), ZIndex = 23, Parent = btns }, function()
		State.act("tradeCancel")
	end)
	Kit.open(tradeWin)
end

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
local clanWin, clanBody = Kit.window(root, "🛡️ Клан", 0.7, Color3.fromHex("#7B5CFF"))
function M.clan()
	local s = scrollBody(clanBody)
	local c = State.s.clan
	if c then
		txt(s, "[" .. c.tag .. "] " .. (c.name or ""), 26, C.gold, 34, 0)
		txt(s, "Участников: " .. (c.count or 1) .. "/" .. Game.CLAN_MAX .. "   Очки: " .. (c.points or 0), 19, C.dim, 28, 1)
		txt(s, "Клановый рейд: 2+ соклановца на одной базе — взлом +30%, награда +20%", 17, C.ok, 44, 2)
		txt(s, "Чат клана — вкладка в обычном чате Roblox", 16, C.dim, 26, 3)
		Kit.button("Покинуть клан", "danger", { Size = UDim2.new(1, -20, 0, 54), LayoutOrder = 10, ZIndex = 23, Parent = s }, function()
			State.act("clanLeave")
			task.wait(0.4)
			M.clan()
		end)
	else
		txt(s, "Вступи по тегу или создай свой (" .. L.money(Game.CLAN_COST) .. ")", 19, C.dim, 30, 0)
		local tagBox = Kit.new("TextBox", { PlaceholderText = "ТЕГ (2–5 букв)", Text = "", Font = Kit.FONT, TextSize = 22, TextColor3 = C.text, BackgroundColor3 = C.panel, Size = UDim2.new(1, -20, 0, 54), LayoutOrder = 1, ZIndex = 23, ClearTextOnFocus = false, Parent = s }, { Kit.corner(12) })
		local nameBox = Kit.new("TextBox", { PlaceholderText = "Название (для создания)", Text = "", Font = Kit.FONT, TextSize = 22, TextColor3 = C.text, BackgroundColor3 = C.panel, Size = UDim2.new(1, -20, 0, 54), LayoutOrder = 2, ZIndex = 23, ClearTextOnFocus = false, Parent = s }, { Kit.corner(12) })
		local btns = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 60), LayoutOrder = 3, ZIndex = 22, Parent = s }, { Kit.list(Enum.FillDirection.Horizontal, 10) })
		Kit.button("Вступить", "chrono", { Size = UDim2.fromOffset(160, 56), ZIndex = 23, Parent = btns }, function()
			State.act("clanJoin", { tag = tagBox.Text })
			task.wait(0.4)
			M.clan()
		end)
		Kit.button("Создать", "buy", { Size = UDim2.fromOffset(160, 56), ZIndex = 23, Parent = btns }, function()
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
local menuWin, menuBody = Kit.window(root, "Меню", 0.6, Color3.fromHex("#231A3B"))
function M.menu()
	Kit.clear(menuBody)
	local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 22, Parent = menuBody }, { Kit.grid(Vector2.new(112, 112), 10) })
	local items = {
		{ "📖", "Коллекция", M.collection },
		{ "🏆", "Рейтинг", M.boards },
		{ "📜", "Квесты", M.quests },
		{ "🛡️", "Клан", M.clan },
		{ "🤝", "Обмен", M.tradeNearest },
		{ "🌀", "Пропуск", function()
			M.shop("season")
		end },
	}
	if State.s.tester then
		table.insert(items, { "🧪", "Тест", M.test })
	end
	for _, it in items do
		local b = Kit.new("TextButton", { Text = "", BackgroundColor3 = C.panel, ZIndex = 22, Parent = g }, { Kit.corner(18), Kit.stroke(C.line, 3) })
		Kit.label({ Text = it[1], TextScaled = true, Position = UDim2.fromOffset(28, 10), Size = UDim2.fromOffset(56, 56), ZIndex = 23, Parent = b })
		Kit.label({ Text = it[2], TextSize = 18, Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, 0, 0, 30), ZIndex = 23, Parent = b })
		b.Activated:Connect(function()
			Kit.click(b)
			Kit.close(menuWin)
			it[3]()
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
