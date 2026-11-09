--!strict
-- Баланс и правила игры. Все цены, таймеры и награды — только здесь.
-- Сервер берёт значения отсюда; клиент — только для показа (клиенту не верим).

local M = {}

-- Тестовые инструменты (боты, панель владельца). На релизе выключить: false.
M.TEST_TOOLS = true

M.MAX_PLAYERS = 8
M.PLOTS = 8

-- ── Артефакты ─────────────────────────────────────────────────
-- цена покупки с конвейера = доход/сек × множитель редкости
M.PRICE_MULT = { common = 20, rare = 30, epic = 45, legendary = 60, chrono = 90 } :: { [string]: number }
-- слив дубликата в осколки
M.SHARDS_FOR = { common = 1, rare = 3, epic = 8, legendary = 20, chrono = 50 } :: { [string]: number }
M.ART_MAX_LVL = 5
M.ART_LVL_BONUS = 0.25 -- +25% дохода за уровень
M.ART_UPGRADE_MULT = 0.6 -- цена апгрейда = цена × 0.6 × текущий уровень
M.PEDESTALS = 10
M.PEDESTALS_FLOOR2 = 10
M.INVENTORY_MAX = 30

-- пещера удачи: цена одного прыжка × (1 + ребёрсы)
M.CAVE_COST = 250

-- конвейер (отключён, заменён пещерой)
M.BELT_EVERY = 2.5 -- новый артефакт каждые N сек
M.BELT_DUR = 30 -- сек на проезд ленты
M.BELT_MAX = 14 -- одновременно на ленте

-- ── Доход ─────────────────────────────────────────────────────
M.OFFLINE_RATE = 0.5 -- офлайн-доход = 50% от онлайна
M.OFFLINE_MAX_H = 12
M.VIP_OFFLINE_BONUS = 0.10
M.SEASON_PASS_BONUS = 0.20
M.ECHO_BONUS = 0.15
M.BOOST_MULT = 2
M.BOOST_SECONDS = 15 * 60
M.AUTOCOLLECT_EVERY = 5

-- ── Энергия ───────────────────────────────────────────────────
M.ENERGY_MAX = 10
M.ENERGY_REGEN = 5 * 60 -- 1 ед. за 5 минут
M.ENERGY_HARD_MAX = 30 -- с энергетиками можно выше обычного максимума
M.SCAN_COST = 1
M.SCAN_COUNT = 3
M.SCAN_COUNT_PLUS = 5

-- ── Стены ─────────────────────────────────────────────────────
M.WALLS = {
	{ name = { ru = "Дерево", en = "Wood" }, hp = 400, cost = 0, build = 0 },
	{ name = { ru = "Камень", en = "Stone" }, hp = 900, cost = 2000, build = 30 },
	{ name = { ru = "Металл", en = "Metal" }, hp = 1800, cost = 25000, build = 60 },
	{ name = { ru = "Укреплённая сталь", en = "Reinforced steel" }, hp = 3500, cost = 300000, build = 120 },
	{ name = { ru = "Хроно-барьер", en = "Chrono barrier" }, hp = 6000, cost = 3000000, build = 180 },
}
M.WALL_REGEN_DELAY = 15 -- сек без ударов до начала восстановления
M.WALL_REGEN_RATE = 0.08 -- доля HP в секунду
M.WALL_REBUILD = 40 -- сломанный сегмент сам восстанавливается через N сек
M.STEEL_BONUS = 0.20

-- ── Инструменты взлома ───────────────────────────────────────
M.TOOLS = {
	{ id = "crowbar", name = { ru = "Ломик", en = "Crowbar" }, dmg = 20, cost = 0 },
	{ id = "drill", name = { ru = "Дрель", en = "Drill" }, dmg = 45, cost = 5000 },
	{ id = "plasma", name = { ru = "Плазморез", en = "Plasma cutter" }, dmg = 100, cost = 80000 },
	{ id = "chrono", name = { ru = "Хроно-резак", en = "Chrono cutter" }, dmg = 220, cost = 1500000 },
}
M.HACK_INTERVAL = 0.5 -- сек между ударами
M.HACK_RANGE = 10
M.CLAN_HACK_BONUS = 0.30
M.CLAN_REWARD_BONUS = 0.20
M.CLAN_MAX_ON_BASE = 3

-- ── Кража ─────────────────────────────────────────────────────
M.STEAL_RANGE = 10
M.STEAL_HOLD = 1.0 -- удержание кнопки
M.CARRY_SPEED = 0.6 -- -40% скорости
M.CARRY_NO_ATTACK = 5
M.CARRY_TIMEOUT = 120 -- не донёс за N сек — артефакт возвращается
M.FAIL_TOOL_COOLDOWN = 60 -- провал: инструменты конфискованы на N сек
M.FAIL_ENERGY = 1
M.OFFLINE_STEAL_LIMIT = 3 -- у офлайн-игрока за одну отлучку можно украсть максимум N артефактов
M.OFFLINE_CANCEL_COMP = 0.25 -- компенсация вору при отмене (доля цены)
M.RAID_TIMEOUT = 180

-- ── Дубинка ──────────────────────────────────────────────────
M.BAT_COOLDOWN = 1.5
M.BAT_RANGE = 9
M.CAUGHT_STUN = 0.8
M.PUSH_STUN = 0.5

-- ── Замок ────────────────────────────────────────────────────
M.LOCK_BASE = 30
M.LOCK_PER_REBIRTH = 10
M.LOCK_SHIELD_PERK = 10
M.LOCK_COOLDOWN = 90

-- ── Ловушки ──────────────────────────────────────────────────
M.TRAP_SLOTS = 8
M.TRAPS = {
	mine = {
		name = { ru = "Мина", en = "Mine" },
		cost = { 1500, 12000, 90000 },
		build = { 20, 60, 150 },
		stun = { 1.5, 2.0, 2.5 },
		radius = { 4, 5, 6 },
		rearm = 25,
	},
	slow = {
		name = { ru = "Замедляющее поле", en = "Slow field" },
		cost = { 1000, 8000, 60000 },
		build = { 20, 60, 150 },
		radius = { 7, 9, 11 },
		slow = 0.4, -- скорость 40%
		rearm = 0,
	},
	decoy = {
		name = { ru = "Ложный артефакт", en = "Decoy" },
		cost = { 3000, 20000, 140000 },
		build = { 30, 90, 180 },
		stun = { 2.5, 3.0, 3.5 },
		rearm = 40,
	},
} :: { [string]: any }
M.TRAP_KINDS = { "mine", "slow", "decoy" }

-- ── Ребёрс ───────────────────────────────────────────────────
M.REBIRTH_MAX = 18
-- требование: Cash + N артефактов не ниже редкости (Chrono не требуется никогда)
function M.rebirthReq(n: number): { cash: number, need: { { rarity: string, count: number } } }
	local cash = math.floor(10000 * 2.4 ^ (n - 1) / 100) * 100
	local need = {}
	if n <= 3 then
		table.insert(need, { rarity = "common", count = n + 2 })
	elseif n <= 6 then
		table.insert(need, { rarity = "common", count = 5 })
		table.insert(need, { rarity = "rare", count = n - 2 })
	elseif n <= 10 then
		table.insert(need, { rarity = "rare", count = 4 })
		table.insert(need, { rarity = "epic", count = n - 6 })
	else
		table.insert(need, { rarity = "epic", count = 4 })
		table.insert(need, { rarity = "legendary", count = math.ceil((n - 10) / 2) })
	end
	return { cash = cash, need = need }
end

-- ── Титан-ранг (очки рейтинга) ───────────────────────────────
M.TITAN_STEAL = { common = 10, rare = 20, epic = 40, legendary = 80, chrono = 160 } :: { [string]: number }
M.TITAN_DEFEND = 15
M.TITAN_CAUGHT = -5

-- ── Ежедневные квесты ────────────────────────────────────────
M.QUESTS = {
	{ id = "steal", goal = 2, name = { ru = "Укради 2 артефакта", en = "Steal 2 artifacts" } },
	{ id = "upgrade", goal = 1, name = { ru = "Улучши стену или ловушку", en = "Upgrade a wall or trap" } },
	{ id = "defend", goal = 1, name = { ru = "Победи в защите", en = "Win a defense" } },
	{ id = "buy", goal = 3, name = { ru = "Купи 3 артефакта", en = "Buy 3 artifacts" } },
	{ id = "scan", goal = 3, name = { ru = "Просканируй 3 раза", en = "Scan 3 times" } },
	{ id = "hack", goal = 5, name = { ru = "Сломай 5 стен", en = "Break 5 walls" } },
	{ id = "collect", goal = 20, name = { ru = "Собери доход 20 раз", en = "Collect income 20 times" } },
}
M.QUEST_REWARD = { shards = 15, tokens = 1, incomeSeconds = 120 }
M.DAILY_QUESTS = 3

-- ── Серия входов (7 дней) ────────────────────────────────────
M.STREAK = {
	{ cashSec = 300 },
	{ tokens = 2 },
	{ shards = 20 },
	{ cashSec = 900 },
	{ tokens = 4 },
	{ shards = 50 },
	{ art = "r_fox" }, -- 7 день — редкий артефакт
} :: { { [string]: any } }

-- ── Достижения ───────────────────────────────────────────────
M.ACHIEVEMENTS = {
	{ id = "first_steal", stat = "steals", goal = 1, shards = 10, name = { ru = "Первая кража", en = "First heist" } },
	{ id = "steals_10", stat = "steals", goal = 10, shards = 25, name = { ru = "Вор-ученик", en = "Apprentice thief" } },
	{ id = "steals_100", stat = "steals", goal = 100, shards = 100, name = { ru = "Мастер кражи", en = "Master thief" } },
	{ id = "defend_1", stat = "defends", goal = 1, shards = 10, name = { ru = "Первая защита", en = "First defense" } },
	{ id = "defend_25", stat = "defends", goal = 25, shards = 60, name = { ru = "Страж базы", en = "Base guardian" } },
	{ id = "rebirth_1", stat = "rebirths", goal = 1, shards = 30, name = { ru = "Вознесение", en = "Ascension" } },
	{ id = "rebirth_5", stat = "rebirths", goal = 5, shards = 80, name = { ru = "Хроно-путник", en = "Chrono traveler" } },
	{ id = "rebirth_18", stat = "rebirths", goal = 18, shards = 500, name = { ru = "Титан времени", en = "Titan of time" } },
	{ id = "collect_10", stat = "collection", goal = 10, shards = 20, name = { ru = "Коллекционер", en = "Collector" } },
	{ id = "collect_25", stat = "collection", goal = 25, shards = 60, name = { ru = "Хранитель коллекции", en = "Curator" } },
	{ id = "collect_40", stat = "collection", goal = 40, shards = 300, name = { ru = "Все артефакты!", en = "Gotta steal 'em all" } },
	{ id = "chrono_1", stat = "chronos", goal = 1, shards = 50, name = { ru = "Аномалия", en = "Anomaly" } },
	{ id = "wall_5", stat = "wall", goal = 5, shards = 80, name = { ru = "Хроно-крепость", en = "Chrono fortress" } },
	{ id = "traps_8", stat = "traps", goal = 8, shards = 40, name = { ru = "Мастер ловушек", en = "Trap master" } },
	{ id = "cash_1m", stat = "earned", goal = 1e6, shards = 30, name = { ru = "Миллионер", en = "Millionaire" } },
	{ id = "cash_1b", stat = "earned", goal = 1e9, shards = 150, name = { ru = "Миллиардер", en = "Billionaire" } },
	{ id = "clan", stat = "clan", goal = 1, shards = 15, name = { ru = "Свои люди", en = "Squad up" } },
	{ id = "trade", stat = "trades", goal = 1, shards = 15, name = { ru = "Честный обмен", en = "Fair trade" } },
}

-- ── Скины (косметика) ────────────────────────────────────────
-- trail — цвет хроно-следа и ауры персонажа
M.SKINS = {
	{ id = "default", name = { ru = "Хроно", en = "Chrono" }, color = Color3.fromHex("#00E5FF"), shards = 0 },
	{ id = "flame", name = { ru = "Пламя", en = "Flame" }, color = Color3.fromHex("#FF7A1A"), shards = 150 },
	{ id = "neon", name = { ru = "Неон", en = "Neon" }, color = Color3.fromHex("#7B2FF7"), shards = 200 },
	{ id = "toxic", name = { ru = "Кислота", en = "Toxic" }, color = Color3.fromHex("#39FF14"), shards = 250 },
	{ id = "gold", name = { ru = "Золото", en = "Gold" }, color = Color3.fromHex("#FFE066"), shards = 400 },
	{ id = "ruby", name = { ru = "Рубин", en = "Ruby" }, color = Color3.fromHex("#FF2E63"), shards = 300 },
	{ id = "starter", name = { ru = "Новичок-вор", en = "Rookie" }, color = Color3.fromHex("#5BC0FF"), shards = -1 },
	{ id = "titan", name = { ru = "Титан", en = "Titan" }, color = Color3.fromHex("#FFFFFF"), shards = -1 },
	{ id = "season", name = { ru = "Сезонный", en = "Seasonal" }, color = Color3.fromHex("#FFB347"), shards = -1 },
}

-- ── Сезоны (смена каждые 2 недели по серверному времени) ─────
M.SEASON_EPOCH = 1767571200 -- 2026-01-05 00:00 UTC (понедельник)
M.SEASON_LEN = 14 * 86400
M.SEASONS = {
	{ id = 1, name = { ru = "Хэллоуин", en = "Halloween" }, color = Color3.fromHex("#FF7A1A") },
	{ id = 2, name = { ru = "Новый год", en = "New Year" }, color = Color3.fromHex("#9BE7FF") },
	{ id = 3, name = { ru = "Лето", en = "Summer" }, color = Color3.fromHex("#FFD36B") },
	{ id = 4, name = { ru = "Весна", en = "Spring" }, color = Color3.fromHex("#FF9FD2") },
	{ id = 5, name = { ru = "Космос", en = "Space" }, color = Color3.fromHex("#8C7BFF") },
	{ id = 6, name = { ru = "Глубина", en = "Deep sea" }, color = Color3.fromHex("#2ED3C6") },
}
M.SEASON_ART_EVERY = 8 * 60 -- сезонный артефакт появляется на алтаре раз в N сек
M.SEASON_CAGE_HP = 3000
M.PASS_LEVELS = 20
M.PASS_XP = 100
M.XP = { steal = 25, defend = 15, quest = 40, buy = 3 }

function M.seasonNumber(t: number): number
	return math.floor((t - M.SEASON_EPOCH) / M.SEASON_LEN)
end

function M.seasonTheme(t: number): number
	return M.seasonNumber(t) % #M.SEASONS + 1
end

function M.seasonEnds(t: number): number
	return M.SEASON_EPOCH + (M.seasonNumber(t) + 1) * M.SEASON_LEN
end

-- награды пропуска: free и premium на уровнях 1..20
function M.passReward(level: number, premium: boolean): { [string]: any }
	if premium then
		if level == 1 then
			return { skin = "season" }
		elseif level == 5 then
			return { art = "rare" }
		elseif level == 10 then
			return { art = "epic" }
		elseif level == 15 then
			return { art = "legendary" }
		elseif level == 20 then
			return { art = "seasonal" }
		elseif level % 2 == 0 then
			return { shards = 40 }
		end
		return { tokens = 3 }
	end
	if level % 5 == 0 then
		return { shards = 25 }
	elseif level % 2 == 0 then
		return { tokens = 1 }
	end
	return { cashSec = 300 }
end

-- ── Кланы ────────────────────────────────────────────────────
M.CLAN_COST = 25000
M.CLAN_MAX = 20

-- ── Трейд ────────────────────────────────────────────────────
M.TRADE_MAX_ITEMS = 4
M.TRADE_CONFIRM_DELAY = 3

-- ── Товары за Robux (ключи совпадают с Config.Assets) ────────
M.PASSES = {
	VIP = { price = 99, name = { ru = "VIP навсегда", en = "VIP forever" }, desc = { ru = "+10% офлайн-дохода, золотой ник, +5 осколков в день", en = "+10% offline income, golden name, +5 shards daily" } },
	AutoCollect = { price = 199, name = { ru = "Авто-сборщик", en = "Auto-collector" }, desc = { ru = "Доход собирается сам", en = "Income collects itself" } },
	ScannerPlus = { price = 299, name = { ru = "Сканер+", en = "Scanner+" }, desc = { ru = "5 баз вместо 3 и скрытая личность вора", en = "5 bases instead of 3, hidden thief identity" } },
	SecondFloor = { price = 499, name = { ru = "Второй этаж", en = "Second floor" }, desc = { ru = "+10 пьедесталов и второй конвейер", en = "+10 pedestals and a second belt" } },
} :: { [string]: any }
M.PRODUCTS = {
	Starter = { price = 49, once = true, name = { ru = "Стартовый набор", en = "Starter pack" }, desc = { ru = "500 Cash + редкий артефакт + скин", en = "500 Cash + rare artifact + skin" } },
	Titan = { price = 1999, once = true, name = { ru = "Титан-набор", en = "Titan pack" }, desc = { ru = "Скин ловушки «Чёрная дыра» + скин «Титан»", en = "Black hole trap skin + Titan skin" } },
	Shards100 = { price = 49, shards = 100, name = { ru = "100 осколков", en = "100 shards" } },
	Shards550 = { price = 199, shards = 550, name = { ru = "550 осколков", en = "550 shards" } },
	Shards1500 = { price = 449, shards = 1500, name = { ru = "1500 осколков", en = "1500 shards" } },
	Energy5 = { price = 25, name = { ru = "Энергетик", en = "Energy drink" }, desc = { ru = "+5 энергии", en = "+5 energy" } },
	BoostX2 = { price = 59, name = { ru = "x2 доход", en = "x2 income" }, desc = { ru = "Двойной доход 15 минут", en = "Double income for 15 minutes" } },
	SeasonPass = { price = 999, name = { ru = "Хроно-пропуск", en = "Chrono pass" }, desc = { ru = "+20% дохода в сезоне, сезонный скин и артефакты", en = "+20% income this season, seasonal skin and artifacts" } },
} :: { [string]: any }

-- ── Античит ──────────────────────────────────────────────────
M.AC_SHADOW_SCORE = 40
M.AC_SHADOW_HOURS = 24
M.AC_BAN_AFTER = 3 -- после N теневых банов — BanAsync
M.AC_BAN_DAYS = 3

return M
