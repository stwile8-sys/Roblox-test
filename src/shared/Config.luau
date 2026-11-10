--!strict
-- Весь баланс игры в одном месте. Сервер и клиент читают одни и те же числа.

local M = {}

-- Карта: игроки летят вдоль +Z. Стартовая площадка у Z=0, конец мира — MAP_END.
M.MAP_END = 30000
M.MAP_HALF_WIDTH = 300 -- поле от -300 до +300 по X
M.LANES = 8 -- пушек на площадке
M.LANE_GAP = 26
M.MUZZLE_Y = 34 -- высота вылета из пушки
M.LAUNCH_ANGLE = 38 -- градусов над горизонтом

-- Дальность первой дуги (без отскоков) от силы: D = K * sqrt(power)
M.DIST_K = 120
M.DIST_MIN = 60

-- Гравитация в полёте: чем дальше летим, тем «тяжелее», чтобы полёт не длился вечность
function M.flightGravity(d: number): number
	return math.clamp(45 + d / 400, 45, 120)
end

function M.firstArc(power: number): number
	return math.clamp(M.DIST_K * math.sqrt(math.max(power, 0)), M.DIST_MIN, M.MAP_END)
end

-- Отскок: доля горизонтальной скорости и вертикальной, которая остаётся после удара о землю
M.BOUNCE_KEEP_H = 0.7
M.BOUNCE_KEEP_V = 0.5

-- Кольца в полёте: каждое +10% монет за этот полёт
M.RING_BONUS = 0.1
M.RING_EVERY = 1.4 -- секунд между кольцами
M.RING_RADIUS = 13

export type Zone = {
	name: string,
	from: number,
	mult: number,
	ground: Color3,
	ground2: Color3,
	sky: Color3,
	theme: string,
}

M.ZONES = {
	{ name = "Grassy Meadow", from = 0, mult = 1, ground = Color3.fromRGB(108, 196, 92), ground2 = Color3.fromRGB(94, 178, 80), sky = Color3.fromRGB(150, 210, 255), theme = "meadow" },
	{ name = "Sunny Beach", from = 800, mult = 1.5, ground = Color3.fromRGB(246, 222, 150), ground2 = Color3.fromRGB(236, 208, 132), sky = Color3.fromRGB(140, 220, 255), theme = "beach" },
	{ name = "Dusty Desert", from = 2000, mult = 2.2, ground = Color3.fromRGB(232, 182, 104), ground2 = Color3.fromRGB(220, 166, 90), sky = Color3.fromRGB(255, 220, 170), theme = "desert" },
	{ name = "Red Canyon", from = 3800, mult = 3, ground = Color3.fromRGB(206, 112, 78), ground2 = Color3.fromRGB(188, 98, 68), sky = Color3.fromRGB(255, 196, 160), theme = "canyon" },
	{ name = "Frosty Peaks", from = 6000, mult = 4, ground = Color3.fromRGB(236, 246, 255), ground2 = Color3.fromRGB(214, 232, 250), sky = Color3.fromRGB(196, 228, 255), theme = "snow" },
	{ name = "Candy Land", from = 9000, mult = 5.5, ground = Color3.fromRGB(255, 176, 214), ground2 = Color3.fromRGB(250, 156, 200), sky = Color3.fromRGB(255, 214, 240), theme = "candy" },
	{ name = "Mushroom Forest", from = 13000, mult = 7.5, ground = Color3.fromRGB(150, 116, 210), ground2 = Color3.fromRGB(134, 100, 196), sky = Color3.fromRGB(210, 190, 255), theme = "mushroom" },
	{ name = "Lava Lands", from = 17500, mult = 10, ground = Color3.fromRGB(70, 60, 66), ground2 = Color3.fromRGB(56, 48, 54), sky = Color3.fromRGB(255, 160, 120), theme = "lava" },
	{ name = "Crystal Caves", from = 23000, mult = 14, ground = Color3.fromRGB(90, 200, 220), ground2 = Color3.fromRGB(74, 182, 204), sky = Color3.fromRGB(180, 240, 255), theme = "crystal" },
	{ name = "Sky Kingdom", from = 28000, mult = 20, ground = Color3.fromRGB(255, 236, 160), ground2 = Color3.fromRGB(250, 224, 130), sky = Color3.fromRGB(255, 246, 210), theme = "sky" },
} :: { Zone }

function M.zoneAt(d: number): number
	local z = 1
	for i, zone in M.ZONES do
		if d >= zone.from then
			z = i
		end
	end
	return z
end

-- Апгрейды за монеты. cost(level) = base * growth^level
export type Upgrade = { id: string, name: string, desc: string, base: number, growth: number, max: number }
M.UPGRADES = {
	{ id = "power", name = "Power Gain", desc = "+1 power every second", base = 30, growth = 1.32, max = 1000 },
	{ id = "coin", name = "Coin Magnet", desc = "+15% coins per launch", base = 60, growth = 1.42, max = 1000 },
	{ id = "bounce", name = "Bouncy Butt", desc = "+1 bounce on landing", base = 400, growth = 3.2, max = 6 },
} :: { Upgrade }

function M.upgradeCost(u: Upgrade, level: number): number
	return math.floor(u.base * u.growth ^ level)
end

-- Перерождение: сбрасывает силу, монеты и апгрейды силы/монет. Даёт постоянный множитель.
M.REBIRTH_POWER = 0.5 -- +50% к приросту силы за каждое
M.REBIRTH_COINS = 0.25 -- +25% монет за каждое
function M.rebirthZone(rebirths: number): number
	return math.min(4 + rebirths, #M.ZONES)
end

-- Монеты за полёт: дальность / 5 * множитель зоны приземления
M.COINS_PER_STUD = 0.2

M.FRIEND_BOOST = 0.1 -- +10% силы за каждого друга на сервере
M.FRIEND_MAX = 5

-- Подарки за время в игре (минуты этой сессии)
export type Reward = { kind: string, amount: number }
M.GIFTS = {
	{ min = 1, kind = "power", amount = 60 },
	{ min = 3, kind = "coins", amount = 3 },
	{ min = 6, kind = "boost", amount = 5 },
	{ min = 10, kind = "power", amount = 180 },
	{ min = 15, kind = "coins", amount = 8 },
	{ min = 20, kind = "boost", amount = 10 },
	{ min = 30, kind = "power", amount = 600 },
	{ min = 45, kind = "coins", amount = 20 },
	{ min = 60, kind = "boost", amount = 30 },
}
-- power: секунд текущего прироста; coins: запусков на лучшую дальность; boost: минут x2 силы

-- Ежедневная награда, день серии 1..7 (дальше по кругу седьмой)
M.DAILY = {
	{ kind = "power", amount = 120 },
	{ kind = "coins", amount = 5 },
	{ kind = "boost", amount = 10 },
	{ kind = "power", amount = 300 },
	{ kind = "coins", amount = 12 },
	{ kind = "boost", amount = 20 },
	{ kind = "power", amount = 900 },
}

-- Коды (для роликов в ТикТоке). Ключ — в верхнем регистре.
M.CODES = {
	LAUNCH = { kind = "power", amount = 120 },
	RAGDOLL = { kind = "coins", amount = 5 },
	FLY = { kind = "boost", amount = 15 },
	FRIENDS = { kind = "power", amount = 300 },
} :: { [string]: Reward }

-- Геймпассы и товары. ID подставляются из Assets.luau (заполняет конвейер Open Cloud).
M.PASSES = {
	{ id = "VIP", name = "VIP", price = 149, desc = "+25% power and coins, +1 bounce, gold VIP tag" },
	{ id = "Power2x", name = "2x Power", price = 199, desc = "Double power gain forever" },
	{ id = "Coins2x", name = "2x Coins", price = 149, desc = "Double coins from every launch forever" },
	{ id = "AutoLaunch", name = "Auto Launch", price = 99, desc = "Relaunch automatically after landing" },
}

M.PRODUCTS = {
	{ id = "PowerS", name = "Power Pack", price = 25, desc = "+10 minutes of power", kind = "power", amount = 600 },
	{ id = "PowerM", name = "Big Power Pack", price = 79, desc = "+45 minutes of power", kind = "power", amount = 2700 },
	{ id = "PowerL", name = "Huge Power Pack", price = 199, desc = "+3 hours of power", kind = "power", amount = 10800 },
	{ id = "Boost15", name = "2x Power (15 min)", price = 49, desc = "Double power gain for 15 minutes", kind = "boost", amount = 15 },
	{ id = "Coins", name = "Coin Bag", price = 49, desc = "Coins for 15 launches at your best distance", kind = "coins", amount = 15 },
	{ id = "LaunchAll", name = "Launch Everyone!", price = 25, desc = "Blast every player in the server into the sky", kind = "launchAll", amount = 0 },
}

M.VIP_MULT = 1.25

-- ===== с друзьями =====

M.TANDEM_MULT = 1.5 -- тандем: дальность сильнейшего из двоих x1.5
M.TANDEM_RANGE = 22 -- как близко должен стоять второй игрок
M.TANDEM_ASK_TTL = 12 -- секунд на ответ
M.INVITE_BOOST = 10 -- минут x2 силы обоим, когда друг пришёл по приглашению
M.INVITE_REWARDS_PER_DAY = 5

-- ===== гонка на сервере =====

M.RACE_EVERY = 600 -- секунд между гонками
M.RACE_WARN = 20 -- за сколько секунд объявлять
M.RACE_DIST = 2600 -- у всех одинаковая дальность: побеждают кольца, а не сила
M.RACE_RING_EVERY = 0.9

-- ===== модификатор дня =====

export type Modifier = { zone: number, kind: string }
M.MOD_KINDS = { "coins", "rings" } -- x2 монет в зоне / кольца дают вдвое больше

function M.modifier(day: number): Modifier
	local zone = 2 + (day * 7) % (#M.ZONES - 1)
	local kind = M.MOD_KINDS[(day % #M.MOD_KINDS) + 1]
	return { zone = zone, kind = kind }
end

-- ===== следы полёта =====

export type TrailDef = { id: string, name: string, how: string, a: Color3, b: Color3 }
M.TRAILS = {
	{ id = "basic", name = "Sunset", how = "Starter trail", a = Color3.fromRGB(255, 120, 90), b = Color3.fromRGB(120, 220, 255) },
} :: { TrailDef }
for i, z in M.ZONES do
	if i > 1 then
		table.insert(M.TRAILS, { id = "zone" .. i, name = z.name, how = "Land in " .. z.name, a = z.ground, b = z.sky })
	end
end
table.insert(M.TRAILS, { id = "rings5", name = "Golden", how = "Catch 5 rings in one flight", a = Color3.fromRGB(255, 214, 70), b = Color3.fromRGB(255, 160, 40) })
table.insert(M.TRAILS, { id = "rings12", name = "Sunbeam", how = "Catch 12 rings in one flight", a = Color3.fromRGB(255, 255, 200), b = Color3.fromRGB(255, 200, 60) })
table.insert(M.TRAILS, { id = "race", name = "Champion", how = "Win a server race", a = Color3.fromRGB(255, 80, 120), b = Color3.fromRGB(255, 214, 70) })
table.insert(M.TRAILS, { id = "tandem", name = "Buddies", how = "Fly in a tandem", a = Color3.fromRGB(120, 255, 170), b = Color3.fromRGB(120, 180, 255) })
table.insert(M.TRAILS, { id = "rebirth1", name = "Reborn", how = "Rebirth once", a = Color3.fromRGB(176, 120, 255), b = Color3.fromRGB(255, 255, 255) })
table.insert(M.TRAILS, { id = "rebirth5", name = "Cosmic", how = "Rebirth 5 times", a = Color3.fromRGB(60, 40, 140), b = Color3.fromRGB(255, 120, 230) })
table.insert(M.TRAILS, { id = "vip", name = "Royal", how = "VIP pass", a = Color3.fromRGB(255, 214, 70), b = Color3.fromRGB(176, 120, 255) })

return M
