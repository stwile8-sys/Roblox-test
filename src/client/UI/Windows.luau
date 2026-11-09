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
	return Kit.frame({ Size = UDim2.new(1, -6, 0, h), BackgroundColor3 = C.panel, LayoutOrder = order or 0, ZIndex = 22, Parent = parent }, { Kit.corner(16), Kit.stroke(color or C.soft, 3) })
end

local function scrollBody(body: Frame): ScrollingFrame
	Kit.clear(body)
	return Kit.scroll({ ZIndex = 22, Parent = body }, { Kit.list(nil, 8), Kit.pad(4) })
end

-- ── Сканер ──────────────────────────────────────────────────
local scanWin, scanBody = Kit.window(root, "📡 Сканер", 0.7)
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
local shopWin, shopBody = Kit.window(root, "🛍️ Магазин", 0.82)
local shopTab = "passes"

local function buyButton(parent: Instance, price: number, key: string, owned: boolean)
	Kit.button(if owned then "Есть ✓" else "R$ " .. price, if owned then "cancel" else "buy", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 52), ZIndex = 23, Parent = parent }, function()
		if not owned then
			State.act("buy", { key = key, test = State.s.tester == true and M.testBuy == true })
		end
	end)
end

local function productCard(s: Instance, i: number, icon: string, name: string, desc: string?, price: number, key: string, owned: boolean)
	local c = card(s, 92, i)
	Kit.label({ Text = icon, TextScaled = true, Position = UDim2.fromOffset(10, 14), Size = UDim2.fromOffset(64, 64), ZIndex = 23, Parent = c })
	Kit.label({ Text = name, Font = Kit.BLACK, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -220, 0, 26), ZIndex = 23, Parent = c })
	Kit.label({ Text = desc or "", TextSize = 16, TextColor3 = C.dim, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(84, 38), Size = UDim2.new(1, -220, 0, 46), ZIndex = 23, Parent = c })
	buyButton(c, price, key, owned)
end

function M.shop(tab: string?)
	shopTab = tab or shopTab
	Kit.clear(shopBody)
	local tabs = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 52), ZIndex = 22, Parent = shopBody }, { Kit.list(Enum.FillDirection.Horizontal, 4) })
	for _, t in { { "passes", "🎫" }, { "boost", "⚡" }, { "cosmetic", "✨" }, { "shards", "💎" }, { "season", "🌀" } } do
		Kit.button(t[2], if t[1] == shopTab then "gold" else "plain", { Size = UDim2.fromOffset(68, 50), TextSize = 26, ZIndex = 22, Parent = tabs }, function()
			M.shop(t[1])
		end)
	end
	local holder = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 58), Size = UDim2.new(1, 0, 1, -58), ZIndex = 22, Parent = shopBody })
	local s = Kit.scroll({ ZIndex = 22, Parent = holder }, { Kit.list(nil, 8), Kit.pad(4) })
	local passes = State.s.passes or {}
	local once = State.s.once or {}
	if shopTab == "passes" then
		txt(s, "Пропуска — навсегда", 20, C.gold, 28, 0)
		local icons = { VIP = "👑", AutoCollect = "🤖", ScannerPlus = "📡", SecondFloor = "🏰" }
		local i = 1
		for _, key in { "VIP", "AutoCollect", "ScannerPlus", "SecondFloor" } do
			local p = Game.PASSES[key]
			productCard(s, i, icons[key], L.name(p.name), L.name(p.desc), p.price, key, passes[key] == true)
			i += 1
		end
	elseif shopTab == "boost" then
		txt(s, "Бустеры", 20, C.gold, 28, 0)
		productCard(s, 1, "🎁", L.name(Game.PRODUCTS.Starter.name), L.name(Game.PRODUCTS.Starter.desc), 49, "Starter", once.Starter == true)
		productCard(s, 2, "⚡", L.name(Game.PRODUCTS.Energy5.name), L.name(Game.PRODUCTS.Energy5.desc), 25, "Energy5", false)
		productCard(s, 3, "✖️2", L.name(Game.PRODUCTS.BoostX2.name), L.name(Game.PRODUCTS.BoostX2.desc), 59, "BoostX2", false)
	elseif shopTab == "cosmetic" then
		txt(s, "Скины хроно-следа (за 💎)", 20, C.gold, 28, 0)
		local skins = State.s.skins or {}
		for i, sk in Game.SKINS do
			if sk.shards >= 0 or skins[sk.id] then
				local c = card(s, 80, i, sk.color)
				Kit.frame({ Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(52, 52), BackgroundColor3 = sk.color, ZIndex = 23, Parent = c }, { Kit.corner(26) })
				Kit.label({ Text = L.name(sk.name), Font = Kit.BLACK, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(76, 0), Size = UDim2.new(1, -210, 1, 0), ZIndex = 23, Parent = c })
				local owned = skins[sk.id]
				local equipped = State.s.skin == sk.id
				Kit.button(if equipped then "Надет" elseif owned then "Надеть" else "💎 " .. sk.shards, if equipped then "cancel" elseif owned then "chrono" else "buy", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(120, 52), ZIndex = 23, Parent = c }, function()
					if equipped then
						return
					end
					State.act(if owned then "skinEquip" else "skinBuy", { id = sk.id })
					task.wait(0.3)
					M.shop()
				end)
			end
		end
		productCard(s, 50, "🕳️", L.name(Game.PRODUCTS.Titan.name), L.name(Game.PRODUCTS.Titan.desc), 1999, "Titan", once.Titan == true)
	elseif shopTab == "shards" then
		txt(s, "Хроно-осколки 💎", 20, C.gold, 28, 0)
		productCard(s, 1, "💎", L.name(Game.PRODUCTS.Shards100.name), nil, 49, "Shards100", false)
		productCard(s, 2, "💎💎", L.name(Game.PRODUCTS.Shards550.name), nil, 199, "Shards550", false)
		productCard(s, 3, "💎💎💎", L.name(Game.PRODUCTS.Shards1500.name), nil, 449, "Shards1500", false)
	else
		M.passBody(s)
	end
	Kit.open(shopWin)
end

-- сезонный пропуск: уровни, награды free/premium
function M.passBody(s: Instance)
	local p = State.s.pass or { xp = 0, prem = false, cf = {}, cp = {} }
	local theme = workspace:GetAttribute("Season") or 1
	local ends = workspace:GetAttribute("SeasonEnds") or os.time()
	local lvl = math.floor(p.xp / Game.PASS_XP)
	txt(s, "🌀 " .. L.name(Game.SEASONS[theme].name) .. " — осталось " .. math.max(0, math.floor((ends - os.time()) / 86400)) .. " дн.", 20, Game.SEASONS[theme].color, 28, 0)
	txt(s, "Уровень " .. lvl .. "/" .. Game.PASS_LEVELS .. "  (" .. p.xp % Game.PASS_XP .. "/" .. Game.PASS_XP .. " XP)", 18, C.dim, 24, 1)
	if not p.prem then
		productCard(s, 2, "🌀", L.name(Game.PRODUCTS.SeasonPass.name), L.name(Game.PRODUCTS.SeasonPass.desc), 999, "SeasonPass", false)
	end
	local function rewardText(r: any): string
		if r.art then
			return if r.art == "seasonal" then "Сезонный Титан" else (L.name(Defs.RARITY[r.art] and Defs.RARITY[r.art].name) .. " арт.")
		elseif r.shards then
			return "💎" .. r.shards
		elseif r.tokens then
			return "🔨" .. r.tokens
		elseif r.skin then
			return "Скин"
		end
		return "💰"
	end
	for level = 1, Game.PASS_LEVELS do
		local c = card(s, 64, 10 + level, if level <= lvl then C.gold else C.line)
		Kit.label({ Text = tostring(level), Font = Kit.BLACK, TextSize = 24, Size = UDim2.fromOffset(44, 64), ZIndex = 23, Parent = c })
		for col, premium in { false, true } do
			local key = tostring(level)
			local claimed = if premium then p.cp[key] else p.cf[key]
			local can = level <= lvl and not claimed and (not premium or p.prem)
			Kit.button((if premium then "⭐ " else "") .. rewardText(Game.passReward(level, premium)), if claimed then "cancel" elseif can then "gold" else "plain", {
				Position = UDim2.new(0, 48 + (col - 1) * 150, 0, 8),
				Size = UDim2.fromOffset(144, 48),
				TextSize = 16,
				ZIndex = 23,
				Parent = c,
			}, function()
				if can and State.act("passClaim", { level = level, premium = premium }) then
					M.shop("season")
				end
			end)
		end
	end
end

-- ── Коллекция + хранилище ───────────────────────────────────
local collWin, collBody = Kit.window(root, "📖 Коллекция", 0.85)
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
local boardWin, boardBody = Kit.window(root, "🏆 Лидерборды", 0.8)
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
local questWin, questBody = Kit.window(root, "📜 Ежедневные квесты", 0.7)
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
local benchWin, benchBody = Kit.window(root, "🔨 Верстак", 0.8)
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
local rebWin, rebBody = Kit.window(root, "🌀 Ребёрс", 0.6)
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
local tradeWin, tradeBody = Kit.window(root, "🤝 Обмен", 0.85)
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
local clanWin, clanBody = Kit.window(root, "🛡️ Клан", 0.7)
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
local testWin, testBody = Kit.window(root, "🧪 Тест (видишь только ты)", 0.75)
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
local menuWin, menuBody = Kit.window(root, "Меню", 0.6)
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
