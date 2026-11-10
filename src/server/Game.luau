--!nonstrict
-- Вся игровая логика сервера: прирост силы, запуск и полёт, награды, апгрейды, перерождение,
-- подарки, ежедневка, коды, друзья, лидерборд. Сервер — единственный источник правды:
-- клиент только сообщает, где приземлился, и это число обрезается расчётным максимумом.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Layout = require(ReplicatedStorage.Shared.Layout)
local Fmt = require(ReplicatedStorage.Shared.Fmt)
local Net = require(ReplicatedStorage.Shared.Net)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)

local M = {}

local stateEv = Net.event("State")
local launchEv = Net.event("Launch")
local resultEv = Net.event("Result")
local notifyEv = Net.event("Notify")
local fxEv = Net.event("Fx")

type Flight = {
	id: number,
	t0: number,
	lane: number,
	origin: Vector3,
	d: number, -- первая дуга
	maxD: number, -- с отскоками и допуском
	tFirst: number,
	tTotal: number,
	done: boolean,
}

type Session = {
	start: number,
	gifts: { [number]: boolean },
	flight: Flight?,
	lastLaunch: number,
	friends: number,
	passes: { [string]: boolean },
	lastCoins: number,
	nextId: number,
	stats: { power: StringValue, best: StringValue, rebirths: IntValue }?,
}

local sessions: { [Player]: Session } = {}
M.sessions = sessions

-- ===== расчёты =====

function M.hasPass(player: Player, id: string): boolean
	local s = sessions[player]
	return s ~= nil and s.passes[id] == true
end

function M.gain(player: Player): number
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s then
		return 0
	end
	local g = (1 + d.upg.power) * (1 + Config.REBIRTH_POWER * d.rebirths)
	if s.passes.Power2x then
		g *= 2
	end
	if s.passes.VIP then
		g *= Config.VIP_MULT
	end
	g *= 1 + Config.FRIEND_BOOST * math.min(s.friends, Config.FRIEND_MAX)
	if d.boostUntil > os.time() then
		g *= 2
	end
	return g
end

function M.coinMult(player: Player): number
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s then
		return 1
	end
	local m = (1 + 0.15 * d.upg.coin) * (1 + Config.REBIRTH_COINS * d.rebirths)
	if s.passes.Coins2x then
		m *= 2
	end
	if s.passes.VIP then
		m *= Config.VIP_MULT
	end
	return m
end

function M.bounces(player: Player): number
	local d = Data.get(player)
	if not d then
		return 0
	end
	return d.upg.bounce + (if M.hasPass(player, "VIP") then 1 else 0)
end

-- Сумма дуг: каждая следующая = предыдущая * keepH * keepV
local function totalFactor(bounces: number): number
	local k = Config.BOUNCE_KEEP_H * Config.BOUNCE_KEEP_V
	local sum, cur = 1, 1
	for _ = 1, bounces do
		cur *= k
		sum += cur
	end
	return sum
end

function M.coinsFor(player: Player, dist: number, rings: number): number
	local zone = Config.ZONES[Config.zoneAt(dist)]
	return math.floor(dist * Config.COINS_PER_STUD * zone.mult * M.coinMult(player) * (1 + Config.RING_BONUS * rings))
end

-- ===== состояние для клиента =====

local function today(): number
	return os.time() // 86400
end

function M.push(player: Player)
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s then
		return
	end
	local claimed = {}
	for i in s.gifts do
		table.insert(claimed, i)
	end
	stateEv:FireClient(player, {
		power = d.power,
		gain = M.gain(player),
		coins = d.coins,
		best = d.best,
		runBest = d.runBest,
		rebirths = d.rebirths,
		upg = d.upg,
		boostLeft = math.max(0, d.boostUntil - os.time()),
		passes = s.passes,
		gifts = claimed,
		session = os.clock() - s.start,
		dailyReady = d.daily.day ~= today(),
		streak = d.daily.streak,
		friends = math.min(s.friends, Config.FRIEND_MAX),
		auto = d.auto,
		ftue = d.ftue,
		coinMult = M.coinMult(player),
		bounces = M.bounces(player),
		launches = d.launches,
		flying = s.flight ~= nil,
	})
	local st = s.stats
	if st then
		st.power.Value = Fmt.num(d.power)
		st.best.Value = Fmt.dist(d.best)
		st.rebirths.Value = d.rebirths
	end
end

function M.notify(player: Player, text: string, kind: string?)
	notifyEv:FireClient(player, text, kind or "info")
end

local function funnel(player: Player, step: number, name: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

-- ===== награды =====

function M.grant(player: Player, kind: string, amount: number): string
	local d = Data.get(player)
	if not d then
		return ""
	end
	if kind == "power" then
		local add = M.gain(player) * amount
		d.power += add
		return "+" .. Fmt.num(add) .. " Power"
	elseif kind == "coins" then
		local per = M.coinsFor(player, math.max(d.runBest, d.best * 0.5, 250), 0)
		local add = per * amount
		d.coins += add
		return "+" .. Fmt.num(add) .. " Coins"
	elseif kind == "boost" then
		d.boostUntil = math.max(os.time(), d.boostUntil) + amount * 60
		return "2x Power for " .. amount .. " min"
	end
	return ""
end

-- ===== рэгдолл =====

local function ragdoll(char: Model)
	local hum = char:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.BreakJointsOnDeath = false
		hum.RequiresNeck = false
		hum.AutoRotate = false
	end
	for _, m in char:GetDescendants() do
		if m:IsA("Motor6D") and m.Name ~= "Root" and m.Part0 and m.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = "RagA0"
			a0.CFrame = m.C0
			a0.Parent = m.Part0
			local a1 = Instance.new("Attachment")
			a1.Name = "RagA1"
			a1.CFrame = m.C1
			a1.Parent = m.Part1
			local bs = Instance.new("BallSocketConstraint")
			bs.Name = "Rag"
			bs.Attachment0 = a0
			bs.Attachment1 = a1
			bs.LimitsEnabled = true
			bs.TwistLimitsEnabled = true
			bs.UpperAngle = 70
			bs.TwistLowerAngle = -45
			bs.TwistUpperAngle = 45
			bs.Parent = m.Part0
			m.Enabled = false
		end
	end
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			if p.Name == "HumanoidRootPart" then
				p.CanCollide = false
			elseif p.Parent == char then
				p.CanCollide = true
			end
		end
	end
end

-- ===== полёт =====

local laneBusy: { [number]: number } = {}

local function pickLane(): number
	local now = os.clock()
	local free = {}
	for lane = 1, Config.LANES do
		if (laneBusy[lane] or 0) < now - 1.5 then
			table.insert(free, lane)
		end
	end
	local lane = if #free > 0 then free[math.random(1, #free)] else math.random(1, Config.LANES)
	laneBusy[lane] = now
	return lane
end

local finish: (Player, number, number, string, number?) -> ()

function M.launch(player: Player, free: boolean?): (boolean, string?)
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s then
		return false, "Loading…"
	end
	if s.flight then
		return false, nil
	end
	if not free and os.clock() - s.lastLaunch < 1.2 then
		return false, nil
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or hum.Health <= 0 or not root then
		return false, nil
	end
	s.lastLaunch = os.clock()
	local lane = pickLane()
	local origin = Layout.muzzle(lane)
	local dist = Config.firstArc(d.power)
	local g = Config.flightGravity(dist)
	local theta = math.rad(Config.LAUNCH_ANGLE)
	local v = math.sqrt(dist * g / math.sin(2 * theta))
	local vel = Layout.DIR * v
	local bounces = M.bounces(player)
	local tFirst = 2 * v * math.sin(theta) / g
	local tTotal = tFirst * (1 + (if bounces > 0 then Config.BOUNCE_KEEP_V / (1 - Config.BOUNCE_KEEP_V) else 0)) + 1
	s.nextId += 1
	local f: Flight = {
		id = s.nextId,
		t0 = os.clock(),
		lane = lane,
		origin = origin,
		d = dist,
		maxD = dist * totalFactor(bounces) * 1.08 + 90,
		tFirst = tFirst,
		tTotal = tTotal,
		done = false,
	}
	s.flight = f
	ragdoll(char)
	launchEv:FireClient(player, {
		id = f.id,
		origin = origin,
		vel = vel,
		g = g,
		bounces = bounces,
		d = dist,
	})
	fxEv:FireAllClients("boom", lane, player)
	d.launches += 1
	if d.launches == 1 then
		funnel(player, 2, "First launch")
	end
	-- страховка: клиент не прислал приземление
	local myId = f.id
	task.delay(tTotal * 1.8 + 10, function()
		local cur = sessions[player]
		if cur and cur.flight and cur.flight.id == myId and not cur.flight.done then
			local r = char:FindFirstChild("HumanoidRootPart")
			local z = if r and r:IsA("BasePart") then r.Position.Z else origin.Z
			finish(player, myId, z, "timeout")
		end
	end)
	M.push(player)
	return true, nil
end

finish = function(player: Player, id: number, z: number, why: string, rings: number?)
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s then
		return
	end
	local f = s.flight
	if not f or f.id ~= id or f.done then
		return
	end
	f.done = true
	local elapsed = os.clock() - f.t0
	local raw = math.max(0, z - f.origin.Z)
	-- нельзя прилететь дальше расчёта и быстрее, чем летит снаряд
	local timeCap = f.maxD * math.clamp(elapsed / math.max(f.tFirst * 0.75, 0.3), 0, 1)
	local dist = math.min(raw, f.maxD, timeCap, Config.MAP_END + 100)
	local ringCount = math.clamp(math.floor(rings or 0), 0, math.floor(elapsed / (Config.RING_EVERY * 0.85)) + 1)
	local coins = M.coinsFor(player, dist, ringCount)
	local prevZone = Config.zoneAt(d.runBest)
	local wasBest = dist > d.best
	d.coins += coins
	s.lastCoins = coins
	if dist > d.runBest then
		d.runBest = dist
	end
	if wasBest then
		d.best = dist
	end
	local newZone = Config.zoneAt(d.runBest)
	if d.launches == 1 then
		funnel(player, 3, "First landing")
	end
	if newZone >= 2 and prevZone < 2 then
		funnel(player, 5, "Reached zone 2")
	end
	resultEv:FireClient(player, {
		dist = dist,
		coins = coins,
		rings = ringCount,
		best = wasBest,
		zone = Config.zoneAt(dist),
		newZone = if newZone > prevZone then newZone else nil,
		why = why,
	})
	task.delay(1.8, function()
		if sessions[player] and s.flight == f then
			s.flight = nil
			if player.Parent == Players then
				player:LoadCharacter()
			end
			M.push(player)
		end
	end)
	M.push(player)
end

function M.onLand(player: Player, id: any, z: any, rings: any)
	if type(id) ~= "number" or type(z) ~= "number" or z ~= z or math.abs(z) > 1e6 then
		return
	end
	if type(rings) ~= "number" or rings ~= rings then
		rings = 0
	end
	finish(player, id, z, "land", rings)
end

-- ===== действия =====

function M.upgrade(player: Player, id: any): (boolean, string?)
	local d = Data.get(player)
	if not d or type(id) ~= "string" then
		return false, nil
	end
	for _, u in Config.UPGRADES do
		if u.id == id then
			local lvl = (d.upg :: any)[id] or 0
			if lvl >= u.max then
				return false, "Max level!"
			end
			local cost = Config.upgradeCost(u, lvl)
			if d.coins < cost then
				return false, "Not enough coins"
			end
			d.coins -= cost;
			(d.upg :: any)[id] = lvl + 1
			if d.ftue < 2 then
				d.ftue = 2
				funnel(player, 4, "First upgrade")
			end
			M.push(player)
			return true, nil
		end
	end
	return false, nil
end

function M.rebirth(player: Player): (boolean, string?)
	local d = Data.get(player)
	if not d then
		return false, nil
	end
	local need = Config.rebirthZone(d.rebirths)
	if Config.zoneAt(d.runBest) < need then
		return false, "Reach " .. Config.ZONES[need].name .. " first!"
	end
	d.rebirths += 1
	d.power = 0
	d.coins = 0
	d.runBest = 0
	d.upg.power = 0
	d.upg.coin = 0
	if d.rebirths == 1 then
		funnel(player, 6, "First rebirth")
	end
	fxEv:FireAllClients("rebirth", 0, player)
	M.push(player)
	return true, nil
end

function M.claimGift(player: Player, index: any): (boolean, string?)
	local s = sessions[player]
	if not s or type(index) ~= "number" then
		return false, nil
	end
	local gift = Config.GIFTS[index]
	if not gift or s.gifts[index] then
		return false, nil
	end
	if os.clock() - s.start < gift.min * 60 - 2 then
		return false, "Not ready yet"
	end
	s.gifts[index] = true
	local text = M.grant(player, gift.kind, gift.amount)
	M.push(player)
	return true, text
end

function M.claimDaily(player: Player): (boolean, string?)
	local d = Data.get(player)
	if not d then
		return false, nil
	end
	local t = today()
	if d.daily.day == t then
		return false, "Come back tomorrow!"
	end
	d.daily.streak = if d.daily.day == t - 1 then d.daily.streak + 1 else 1
	d.daily.day = t
	local r = Config.DAILY[((d.daily.streak - 1) % #Config.DAILY) + 1]
	local text = M.grant(player, r.kind, r.amount)
	M.push(player)
	return true, text
end

function M.redeem(player: Player, code: any): (boolean, string?)
	local d = Data.get(player)
	if not d or type(code) ~= "string" or #code > 30 then
		return false, nil
	end
	local c = string.upper((code:gsub("%s", "")))
	local r = Config.CODES[c]
	if not r then
		return false, "Invalid code"
	end
	if d.codes[c] then
		return false, "Already used"
	end
	d.codes[c] = true
	local text = M.grant(player, r.kind, r.amount)
	M.push(player)
	return true, text
end

function M.setAuto(player: Player, on: any): (boolean, string?)
	local d = Data.get(player)
	if not d then
		return false, nil
	end
	d.auto = on == true
	M.push(player)
	return true, nil
end

function M.ftue(player: Player, step: any): (boolean, string?)
	local d = Data.get(player)
	if not d or type(step) ~= "number" then
		return false, nil
	end
	d.ftue = math.max(d.ftue, math.clamp(math.floor(step), 0, 10))
	return true, nil
end

function M.launchAll(by: Player)
	for _, p in Players:GetPlayers() do
		task.spawn(M.launch, p, true)
	end
	for _, p in Players:GetPlayers() do
		M.notify(p, by.DisplayName .. " launched EVERYONE! 🚀", "big")
	end
end

-- ===== друзья =====

local function recountFriends()
	local list = Players:GetPlayers()
	for _, p in list do
		local s = sessions[p]
		if s then
			local n = 0
			for _, o in list do
				if o ~= p then
					local ok, yes = pcall(p.IsFriendsWith, p, o.UserId)
					if ok and yes then
						n += 1
					end
				end
			end
			if n ~= s.friends then
				if n > s.friends then
					M.notify(p, "Friend boost! +" .. math.floor(Config.FRIEND_BOOST * 100 * math.min(n, Config.FRIEND_MAX)) .. "% power", "good")
				end
				s.friends = n
				M.push(p)
			end
		end
	end
end

-- ===== лидерборд =====

local bestStore: OrderedDataStore? = nil
pcall(function()
	bestStore = DataStoreService:GetOrderedDataStore("best_v1")
end)
local names: { [number]: string } = {}

local function submitBest(player: Player)
	local d = Data.get(player)
	local bs = bestStore
	if not d or not bs or d.best < 1 then
		return
	end
	local v = math.floor(d.best)
	pcall(function()
		bs:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) == "number" and old >= v then
				return nil
			end
			return v
		end)
	end)
end

local function refreshBoard()
	local bs = bestStore
	if not bs then
		return
	end
	local ok, pages = pcall(function()
		return bs:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return
	end
	local list = {}
	for _, e in pages:GetCurrentPage() do
		local id = tonumber(e.key)
		if id then
			local name = names[id]
			if not name then
				local ok2, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
				name = if ok2 and n then n else "Player"
				names[id] = name
			end
			table.insert(list, { name = name, value = e.value })
		end
	end
	World.setBoard(list)
end

-- ===== вход и выход =====

local function leaderstats(player: Player, s: Session)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local power = Instance.new("StringValue")
	power.Name = "Power"
	power.Parent = ls
	local best = Instance.new("StringValue")
	best.Name = "Best"
	best.Parent = ls
	local reb = Instance.new("IntValue")
	reb.Name = "Rebirths"
	reb.Parent = ls
	ls.Parent = player
	s.stats = { power = power, best = best, rebirths = reb }
end

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.BreakJointsOnDeath = false
		if M.hasPass(player, "VIP") then
			hum.DisplayName = "👑 " .. player.DisplayName
		end
		hum.Died:Connect(function()
			local s = sessions[player]
			if s and s.flight and not s.flight.done then
				local r = char:FindFirstChild("HumanoidRootPart")
				finish(player, s.flight.id, if r and r:IsA("BasePart") then r.Position.Z else 0, "died")
			end
		end)
	end
end

function M.join(player: Player, passes: { [string]: boolean })
	local s: Session = {
		start = os.clock(),
		gifts = {},
		flight = nil,
		lastLaunch = 0,
		friends = 0,
		passes = passes,
		lastCoins = 0,
		nextId = 0,
	}
	sessions[player] = s
	leaderstats(player, s)
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	funnel(player, 1, "Joined")
	task.spawn(recountFriends)
	M.push(player)
end

function M.leave(player: Player)
	submitBest(player)
	sessions[player] = nil
	task.spawn(recountFriends)
end

function M.start()
	-- прирост силы раз в секунду
	task.spawn(function()
		while true do
			task.wait(1)
			for player, s in sessions do
				local d = Data.get(player)
				if d then
					d.power += M.gain(player)
					d.playSec += 1
					if s then
						M.push(player)
					end
				end
			end
		end
	end)
	-- лидерборд
	task.spawn(function()
		task.wait(5)
		while true do
			for player in sessions do
				submitBest(player)
			end
			refreshBoard()
			task.wait(if RunService:IsStudio() then 30 else 120)
		end
	end)
end

return M
