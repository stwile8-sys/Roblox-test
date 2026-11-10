--!nonstrict
-- Вся игровая логика сервера: сила, полёт, награды, апгрейды, перерождение, подарки, ежедневка,
-- коды, друзья (приглашения и тандем), гонка на сервере, гонка дня, модификатор дня, следы, лидерборды.
-- Сервер — единственный источник правды: клиент только сообщает, где приземлился и какие кольца поймал,
-- и всё это обрезается расчётом (дальность) или проверяется по позициям, которые видел сервер (кольца гонки).

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
local askEv = Net.event("Ask")
local raceEv = Net.event("Race")

type Flight = {
	id: number,
	t0: number,
	origin: Vector3,
	d: number,
	maxD: number,
	tFirst: number,
	done: boolean,
	race: boolean,
	rings: { Vector3 }?, -- кольца гонки (общие для всех)
	ringT: { number }?,
	tandem: boolean,
}

type Session = {
	start: number,
	gifts: { [number]: boolean },
	flight: Flight?,
	lastLaunch: number,
	friends: number,
	passes: { [string]: boolean },
	nextId: number,
	ask: { from: Player, t: number }?,
	raceIn: boolean,
	samples: { { t: number, p: Vector3 } },
	invited: boolean,
	stats: { power: StringValue, best: StringValue, rebirths: IntValue }?,
}

local sessions: { [Player]: Session } = {}
M.sessions = sessions

local function today(): number
	return os.time() // 86400
end

-- ===== аналитика =====

local function funnel(player: Player, step: number, name: string)
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, step, name)
	end)
end

function M.event(player: Player, name: string, value: number?)
	pcall(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

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
	local zi = Config.zoneAt(dist)
	local zone = Config.ZONES[zi]
	local mod = Config.modifier(today())
	local zoneMult = zone.mult
	local ringBonus = Config.RING_BONUS
	if mod.zone == zi then
		if mod.kind == "coins" then
			zoneMult *= 2
		else
			ringBonus *= 2
		end
	end
	return math.floor(dist * Config.COINS_PER_STUD * zoneMult * M.coinMult(player) * (1 + ringBonus * rings))
end

-- ===== состояние для клиента =====

local raceAt = 0 -- os.clock() старта ближайшей гонки

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
	local t = today()
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
		dailyReady = d.daily.day ~= t,
		streak = d.daily.streak,
		friends = math.min(s.friends, Config.FRIEND_MAX),
		auto = d.auto,
		ftue = d.ftue,
		coinMult = M.coinMult(player),
		bounces = M.bounces(player),
		launches = d.launches,
		flying = s.flight ~= nil,
		trails = d.trails,
		trail = d.trail,
		todayBest = if d.today.day == t then d.today.v else 0,
		mod = Config.modifier(t),
		raceIn = math.max(0, raceAt - os.clock()),
		raceJoined = s.raceIn,
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

local function unlockTrail(player: Player, id: string)
	local d = Data.get(player)
	if not d or d.trails[id] then
		return
	end
	for _, t in Config.TRAILS do
		if t.id == id then
			d.trails[id] = true
			M.notify(player, "New trail: " .. t.name .. "! 🌈", "good")
			return
		end
	end
end

-- ===== рэгдолл и след =====

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

local function addTrail(player: Player, char: Model)
	local d = Data.get(player)
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if not d or not torso then
		return
	end
	local def = Config.TRAILS[1]
	for _, t in Config.TRAILS do
		if t.id == d.trail then
			def = t
		end
	end
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1, 0)
	a0.Parent = torso
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1, 0)
	a1.Parent = torso
	local tr = Instance.new("Trail")
	tr.Name = "FlightTrail"
	tr.Attachment0 = a0
	tr.Attachment1 = a1
	tr.Lifetime = 0.6
	tr.MinLength = 0.5
	tr.WidthScale = NumberSequence.new(1, 0)
	tr.LightEmission = 0.5
	tr.FaceCamera = true
	tr.Color = ColorSequence.new(def.a, def.b)
	tr.Transparency = NumberSequence.new(0.05, 1)
	tr.Parent = torso
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

local finish: (Player, number, number, string, any?) -> ()

type LaunchOpts = { dist: number?, lane: number?, offset: Vector3?, race: boolean?, rings: { Vector3 }?, ringT: { number }?, tandem: boolean?, free: boolean? }

-- Запустить одного игрока. opts.dist — принудительная дальность (гонка, тандем)
local function fire(player: Player, opts: LaunchOpts): boolean
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s or s.flight then
		return false
	end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not hum or hum.Health <= 0 or not root then
		return false
	end
	s.lastLaunch = os.clock()
	local lane = opts.lane or pickLane()
	local origin = (if opts.race then Layout.raceMuzzle() else Layout.muzzle(lane)) + (opts.offset or Vector3.zero)
	local dist = opts.dist or Config.firstArc(d.power)
	local g = Config.flightGravity(dist)
	local theta = math.rad(Config.LAUNCH_ANGLE)
	local v = math.sqrt(dist * g / math.sin(2 * theta))
	local vel = Layout.DIR * v
	local bounces = if opts.race then 0 else M.bounces(player)
	local tFirst = 2 * v * math.sin(theta) / g
	local tTotal = tFirst * (1 + (if bounces > 0 then Config.BOUNCE_KEEP_V / (1 - Config.BOUNCE_KEEP_V) else 0)) + 1
	s.nextId += 1
	local f: Flight = {
		id = s.nextId,
		t0 = os.clock(),
		origin = origin,
		d = dist,
		maxD = dist * totalFactor(bounces) * 1.08 + 90,
		tFirst = tFirst,
		done = false,
		race = opts.race == true,
		rings = opts.rings,
		ringT = opts.ringT,
		tandem = opts.tandem == true,
	}
	s.flight = f
	table.clear(s.samples)
	ragdoll(char)
	addTrail(player, char)
	launchEv:FireClient(player, {
		id = f.id,
		origin = origin,
		vel = vel,
		g = g,
		bounces = bounces,
		d = dist,
		rings = opts.rings,
		race = opts.race,
		tandem = opts.tandem,
	})
	fxEv:FireAllClients("boom", if opts.race then 0 else lane, player)
	d.launches += 1
	M.event(player, "launch")
	if d.launches == 1 then
		funnel(player, 2, "First launch")
	end
	local myId = f.id
	task.delay(tTotal * 1.8 + 10, function()
		local cur = sessions[player]
		if cur and cur.flight and cur.flight.id == myId and not cur.flight.done then
			local r = char:FindFirstChild("HumanoidRootPart")
			finish(player, myId, if r and r:IsA("BasePart") then r.Position.Z else origin.Z, "timeout")
		end
	end)
	M.push(player)
	return true
end

function M.launch(player: Player, free: boolean?): (boolean, string?)
	local d = Data.get(player)
	local s = sessions[player]
	if not d or not s then
		return false, "Loading…"
	end
	if not free and os.clock() - s.lastLaunch < 1.2 then
		return false, nil
	end
	return fire(player, {}), nil
end

-- Сколько колец гонки игрок действительно пролетел: по позициям, которые видел сервер
local function verifyRaceRings(s: Session, f: Flight, claimed: any): number
	if type(claimed) ~= "table" or not f.rings or not f.ringT then
		return 0
	end
	local got = 0
	local seen = {}
	for _, id in claimed do
		if type(id) == "number" and f.rings[id] and not seen[id] then
			seen[id] = true
			local c = f.rings[id]
			local tRing = f.ringT[id]
			for _, smp in s.samples do
				if math.abs(smp.t - tRing) < 0.9 and (smp.p - c).Magnitude < Config.RING_RADIUS + 18 then
					got += 1
					break
				end
			end
		end
	end
	return got
end

local raceResults: { [Player]: number } = {}

finish = function(player: Player, id: number, z: number, why: string, rings: any?)
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
	local timeCap = f.maxD * math.clamp(elapsed / math.max(f.tFirst * 0.75, 0.3), 0, 1)
	local dist = math.min(raw, f.maxD, timeCap, Config.MAP_END + 100)
	local ringCount
	if f.race then
		ringCount = verifyRaceRings(s, f, rings)
		raceResults[player] = ringCount
	else
		local n = if type(rings) == "number" and rings == rings then rings else 0
		ringCount = math.clamp(math.floor(n), 0, math.floor(elapsed / (Config.RING_EVERY * 0.85)) + 1)
	end
	local coins = M.coinsFor(player, dist, ringCount)
	local prevZone = Config.zoneAt(d.runBest)
	-- гонка идёт на одинаковой для всех дальности, поэтому в рекорды и прогресс зон её не пишем
	local wasBest = dist > d.best and not f.race
	d.coins += coins
	if dist > d.runBest and not f.race then
		d.runBest = dist
	end
	if wasBest then
		d.best = dist
	end
	-- гонка дня
	local t = today()
	if d.today.day ~= t then
		d.today = { day = t, v = 0 }
	end
	local todayBest = false
	if dist > d.today.v and not f.race then
		d.today.v = dist
		todayBest = true
	end
	-- следы за достижения
	local landZone = Config.zoneAt(dist)
	if landZone > 1 and not f.race then
		unlockTrail(player, "zone" .. landZone)
	end
	if ringCount >= 5 then
		unlockTrail(player, "rings5")
	end
	if ringCount >= 12 then
		unlockTrail(player, "rings12")
	end
	if f.tandem then
		unlockTrail(player, "tandem")
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
		todayBest = todayBest and not wasBest,
		zone = landZone,
		newZone = if newZone > prevZone then newZone else nil,
		race = f.race,
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
	finish(player, id, z, "land", rings)
end

-- ===== тандем =====

function M.tandemAsk(player: Player, targetId: any): (boolean, string?)
	local s = sessions[player]
	if not s or s.flight or type(targetId) ~= "number" then
		return false, nil
	end
	local target = Players:GetPlayerByUserId(targetId)
	local ts = target and sessions[target]
	if not target or target == player or not ts or ts.flight then
		return false, "They can't fly right now"
	end
	local a = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local b = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
	if not a or not b or (a.Position - b.Position).Magnitude > Config.TANDEM_RANGE + 6 then
		return false, "Stand closer!"
	end
	if ts.ask and ts.ask.from == player and os.clock() - ts.ask.t < Config.TANDEM_ASK_TTL then
		return false, "Already asked"
	end
	ts.ask = { from = player, t = os.clock() }
	askEv:FireClient(target, player)
	M.event(player, "tandem_asked")
	return true, "Asked " .. target.DisplayName .. " to fly together"
end

function M.tandemAccept(player: Player, fromId: any): (boolean, string?)
	local s = sessions[player]
	if not s or not s.ask or type(fromId) ~= "number" then
		return false, nil
	end
	local from = s.ask.from
	local fresh = os.clock() - s.ask.t < Config.TANDEM_ASK_TTL
	s.ask = nil
	if not fresh or from.UserId ~= fromId or from.Parent ~= Players then
		return false, "Too late!"
	end
	local fs = sessions[from]
	local da, db = Data.get(player), Data.get(from)
	if not fs or not da or not db or fs.flight or s.flight then
		return false, nil
	end
	local dist = math.min(math.max(Config.firstArc(da.power), Config.firstArc(db.power)) * Config.TANDEM_MULT, Config.MAP_END)
	local lane = pickLane()
	local okA = fire(from, { dist = dist, lane = lane, offset = Vector3.new(-2.5, 0, 0), tandem = true })
	local okB = fire(player, { dist = dist, lane = lane, offset = Vector3.new(2.5, 0, 0), tandem = true })
	if okA or okB then
		M.event(player, "tandem_flown")
		M.event(from, "tandem_flown")
		return true, nil
	end
	return false, nil
end

-- ===== гонка на сервере =====

local raceOpen = false

function M.raceJoin(player: Player): (boolean, string?)
	local s = sessions[player]
	if not s or not raceOpen then
		return false, nil
	end
	s.raceIn = true
	M.event(player, "race_joined")
	M.push(player)
	return true, "You're in the race! 🏁"
end

local function raceRings(): ({ Vector3 }, { number })
	local origin = Layout.raceMuzzle()
	local dist = Config.RACE_DIST
	local g = Config.flightGravity(dist)
	local theta = math.rad(Config.LAUNCH_ANGLE)
	local v = math.sqrt(dist * g / math.sin(2 * theta))
	local vel = Layout.DIR * v
	local tFirst = 2 * v * math.sin(theta) / g
	local rng = Random.new(math.floor(os.time()))
	local pos, times = {}, {}
	local t = 1.2
	while t < tFirst - 0.6 do
		local p = origin + vel * t + Vector3.new(rng:NextNumber(-32, 32), -0.5 * g * t * t, 0)
		if p.Y > 20 then
			table.insert(pos, p)
			table.insert(times, t)
		end
		t += Config.RACE_RING_EVERY
	end
	return pos, times
end

local function runRace()
	raceOpen = true
	raceEv:FireAllClients("open", Config.RACE_WARN)
	task.wait(Config.RACE_WARN)
	raceOpen = false
	local rings, times = raceRings()
	table.clear(raceResults)
	local racers = {}
	for p, s in sessions do
		if s.raceIn then
			s.raceIn = false
			if not s.flight then
				local spread = Vector3.new(math.random(-60, 60) / 10, 0, 0)
				if fire(p, { dist = Config.RACE_DIST, race = true, rings = rings, ringT = times, offset = spread }) then
					table.insert(racers, p)
					local d = Data.get(p)
					if d then
						d.races += 1
					end
				end
			end
		else
			M.event(p, "race_skipped")
		end
	end
	if #racers == 0 then
		raceEv:FireAllClients("none")
		return
	end
	raceEv:FireAllClients("go", #racers)
	-- ждём приземления всех (с запасом)
	local t0 = os.clock()
	while os.clock() - t0 < 30 do
		local waiting = false
		for _, p in racers do
			local s = sessions[p]
			if s and s.flight and s.flight.race and not s.flight.done then
				waiting = true
			end
		end
		if not waiting then
			break
		end
		task.wait(0.5)
	end
	local best = -1
	for _, p in racers do
		best = math.max(best, raceResults[p] or 0)
	end
	local winners = {}
	for _, p in racers do
		if (raceResults[p] or 0) == best and best > 0 then
			table.insert(winners, p)
		end
	end
	for _, p in racers do
		if p.Parent == Players then
			M.grant(p, "coins", 2)
		end
	end
	local names = {}
	for _, p in winners do
		if p.Parent == Players then
			table.insert(names, p.DisplayName)
			M.grant(p, "boost", 10)
			local d = Data.get(p)
			if d then
				d.raceWins += 1
			end
			unlockTrail(p, "race")
			M.event(p, "race_won", best)
		end
	end
	raceEv:FireAllClients("result", { winners = names, rings = best, count = #racers })
	for _, p in racers do
		M.push(p)
	end
end

-- ===== действия =====

function M.upgrade(player: Player, id: any): (boolean, string?)
	local d = Data.get(player)
	if not d or type(id) ~= "string" then
		return false, nil
	end
	for i, u in Config.UPGRADES do
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
			M.event(player, "upgrade_" .. id, lvl + 1)
			if d.ftue < 2 then
				d.ftue = 2
				funnel(player, 4, "First upgrade")
			end
			M.push(player)
			return true, nil
		end
		local _ = i
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
	M.event(player, "rebirth", d.rebirths)
	if d.rebirths == 1 then
		funnel(player, 6, "First rebirth")
		unlockTrail(player, "rebirth1")
	end
	if d.rebirths >= 5 then
		unlockTrail(player, "rebirth5")
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
	M.event(player, "daily_claimed", d.daily.streak)
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
	M.event(player, "code_" .. c)
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

function M.setTrail(player: Player, id: any): (boolean, string?)
	local d = Data.get(player)
	if not d or type(id) ~= "string" or not d.trails[id] then
		return false, nil
	end
	d.trail = id
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

function M.inviteClicked(player: Player): (boolean, string?)
	M.event(player, "invite_clicked")
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

-- Пришёл по приглашению: x2 силы ему и пригласившему, если тот здесь
local function checkInvite(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	local ok, jd = pcall(player.GetJoinData, player)
	local refId = ok and jd and jd.ReferredByPlayerId
	if type(refId) ~= "number" or refId <= 0 or refId == player.UserId then
		return
	end
	M.event(player, "friend_joined_via_invite")
	local t = today()
	if d.inviteDay ~= t then
		d.inviteDay = t
		M.grant(player, "boost", Config.INVITE_BOOST)
		M.notify(player, "Your friend invited you! 2x Power for " .. Config.INVITE_BOOST .. " min", "good")
	end
	local ref = Players:GetPlayerByUserId(refId)
	local rd = ref and Data.get(ref)
	if ref and rd then
		if rd.ref.day ~= t then
			rd.ref = { day = t, n = 0 }
		end
		if rd.ref.n < Config.INVITE_REWARDS_PER_DAY then
			rd.ref.n += 1
			M.grant(ref, "boost", Config.INVITE_BOOST)
			M.notify(ref, player.DisplayName .. " joined from your invite! 2x Power for " .. Config.INVITE_BOOST .. " min", "good")
			M.event(ref, "invite_reward")
			M.push(ref)
		end
	end
end

-- ===== лидерборды =====

local bestStore: OrderedDataStore? = nil
pcall(function()
	bestStore = DataStoreService:GetOrderedDataStore("best_v1")
end)
local names: { [number]: string } = {}

local function dayStore(): OrderedDataStore?
	local ok, st = pcall(DataStoreService.GetOrderedDataStore, DataStoreService, "today_" .. today())
	return if ok then st else nil
end

local function submit(store: OrderedDataStore?, player: Player, value: number)
	if not store or value < 1 then
		return
	end
	local v = math.floor(value)
	pcall(function()
		store:UpdateAsync(tostring(player.UserId), function(old)
			if type(old) == "number" and old >= v then
				return nil
			end
			return v
		end)
	end)
end

local function readBoard(store: OrderedDataStore?): { { name: string, value: number } }?
	if not store then
		return nil
	end
	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return nil
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
	return list
end

local function submitAll(player: Player)
	local d = Data.get(player)
	if not d then
		return
	end
	submit(bestStore, player, d.best)
	if d.today.day == today() then
		submit(dayStore(), player, d.today.v)
	end
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
		nextId = 0,
		ask = nil,
		raceIn = false,
		samples = {},
		invited = false,
	}
	sessions[player] = s
	leaderstats(player, s)
	if passes.VIP then
		unlockTrail(player, "vip")
	end
	player.CharacterAdded:Connect(function(c)
		onCharacter(player, c)
	end)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	funnel(player, 1, "Joined")
	M.event(player, "session_start")
	checkInvite(player)
	task.spawn(recountFriends)
	M.push(player)
end

function M.leave(player: Player)
	local s = sessions[player]
	if s then
		M.event(player, "session_end", math.floor(os.clock() - s.start))
	end
	submitAll(player)
	sessions[player] = nil
	task.spawn(recountFriends)
end

function M.start()
	-- прирост силы раз в секунду
	task.spawn(function()
		while true do
			task.wait(1)
			for player in sessions do
				local d = Data.get(player)
				if d then
					d.power += M.gain(player)
					d.playSec += 1
					M.push(player)
				end
			end
		end
	end)
	-- позиции участников гонки для проверки колец (10 раз в секунду)
	RunService.Heartbeat:Connect(function()
		for player, s in sessions do
			local f = s.flight
			if f and f.race and not f.done then
				local char = player.Character
				local r = char and char:FindFirstChild("HumanoidRootPart")
				if r and r:IsA("BasePart") then
					local t = os.clock() - f.t0
					local last = s.samples[#s.samples]
					if not last or t - last.t >= 0.1 then
						table.insert(s.samples, { t = t, p = r.Position })
					end
				end
			end
		end
	end)
	-- гонки
	task.spawn(function()
		while true do
			raceAt = os.clock() + Config.RACE_EVERY
			task.wait(Config.RACE_EVERY - Config.RACE_WARN)
			raceAt = os.clock() + Config.RACE_WARN
			local ok, err = pcall(runRace)
			if not ok then
				warn("[Race]", err)
				raceOpen = false
			end
		end
	end)
	-- лидерборды и табличка модификатора
	task.spawn(function()
		task.wait(5)
		local lastDay = -1
		while true do
			local t = today()
			if t ~= lastDay then
				lastDay = t
				World.setModifier(Config.modifier(t))
			end
			for player in sessions do
				submitAll(player)
			end
			local all = readBoard(bestStore)
			if all then
				World.setBoard(all, "all")
			end
			local day = readBoard(dayStore())
			if day then
				World.setBoard(day, "today")
			end
			task.wait(if RunService:IsStudio() then 30 else 120)
		end
	end)
end

return M
