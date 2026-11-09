--!nonstrict
-- Экономика: доход, сбор, конвейер, покупка артефактов, апгрейды, слив в осколки,
-- энергия, стройка стен и ловушек (таймер ≤ 3 мин, ускорение — только Build Tokens).

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)

local Game = Ctx.Game
local Defs = Ctx.Defs

local M: any = {}
local api = Ctx.api

-- ── Деньги ──────────────────────────────────────────────────
function M.mult(S: any): number
	local d = S.data
	local m = 1 + d.rebirths
	if d.pass.prem and d.pass.season == Game.seasonNumber(os.time()) then
		m *= 1 + Game.SEASON_PASS_BONUS
	end
	if d.boostUntil > os.time() then
		m *= Game.BOOST_MULT
	end
	if S.B and S.B.perks and S.B.perks.echo then
		m *= 1 + Game.ECHO_BONUS
	end
	return m
end

-- базовый доход/сек без множителей (слоты «в пути» у вора не приносят дохода)
function M.baseIncome(data: any, slotCount: number, transit: { [number]: any }?): number
	local total = 0
	for k, a in data.slots do
		local slot = tonumber(k)
		if slot and slot <= slotCount and not (transit and transit[slot]) then
			total += Ctx.artIncome(a.id, a.lvl)
		end
	end
	return total
end

function M.income(S: any): number
	local count = if S.B then Bases.slotCount(S.B) else Game.PEDESTALS
	return M.baseIncome(S.data, count, S.B and S.B.transit) * M.mult(S)
end

function M.addCash(S: any, n: number, src: string?)
	if n <= 0 or n ~= n then
		return
	end
	S.data.cash += n
	S.data.stats.earned = (S.data.stats.earned or 0) + n
	Ctx.mark(S, "cash", "stats")
	if api.checkAch then
		api.checkAch(S)
	end
end

function M.spend(S: any, n: number): boolean
	if n < 0 or n ~= n or S.data.cash < n then
		return false
	end
	S.data.cash -= n
	Ctx.mark(S, "cash")
	return true
end

function M.addShards(S: any, n: number)
	S.data.shards += math.max(0, math.floor(n))
	Ctx.mark(S, "shards")
end

function M.addTokens(S: any, n: number)
	S.data.tokens += math.max(0, math.floor(n))
	Ctx.mark(S, "tokens")
end

function M.addEnergy(S: any, n: number)
	S.data.energy = math.min(Game.ENERGY_HARD_MAX, S.data.energy + n)
	Ctx.mark(S, "energy")
end

-- ── Артефакты игрока ────────────────────────────────────────
function M.freeSlot(S: any): number?
	local count = if S.B then Bases.slotCount(S.B) else Game.PEDESTALS
	for i = 1, count do
		if not S.data.slots[tostring(i)] and not (S.B and S.B.transit[i]) then
			return i
		end
	end
	return nil
end

function M.markCollected(S: any, id: string)
	local d = Defs.BY_ID[id]
	if not d then
		return
	end
	if not S.data.coll[id] then
		S.data.coll[id] = true
		Ctx.mark(S, "coll")
	end
	if d.rarity == "chrono" then
		S.data.stats.chronos = (S.data.stats.chronos or 0) + 1
	end
	if api.checkAch then
		api.checkAch(S)
	end
end

-- выдать артефакт: в свободный слот, иначе в хранилище. false — некуда
function M.give(S: any, id: string, lvl: number?, preferInv: boolean?): (boolean, string?)
	if not Defs.BY_ID[id] then
		return false, nil
	end
	local art = { id = id, lvl = lvl or 1 }
	local slot = if preferInv then nil else M.freeSlot(S)
	if slot then
		S.data.slots[tostring(slot)] = art
		M.markCollected(S, id)
		Ctx.mark(S, "slots", "income")
		if S.B then
			Bases.renderArts(S.B)
		end
		return true, "slot"
	end
	if #S.data.inv < Game.INVENTORY_MAX then
		table.insert(S.data.inv, art)
		M.markCollected(S, id)
		Ctx.mark(S, "inv")
		return true, "inv"
	end
	return false, nil
end

function M.hasRoom(S: any): boolean
	return M.freeSlot(S) ~= nil or #S.data.inv < Game.INVENTORY_MAX
end

-- ── Сбор дохода ─────────────────────────────────────────────
function M.collect(S: any, auto: boolean?)
	local n = math.floor(S.data.pending)
	if n <= 0 then
		return
	end
	S.data.pending -= n
	M.addCash(S, n, "income")
	Ctx.mark(S, "pending")
	if not auto then
		if api.quest then
			api.quest(S, "collect", 1)
		end
		local B = S.B
		if B then
			local plate = B.model:FindFirstChild("Collect")
			Ctx.fx("collect", plate and plate.Position, { n = n }, S.player)
			for _, anchor in B.arts do
				Bases.playAnim(anchor, "collect")
			end
		end
	end
end

-- ── Конвейер ────────────────────────────────────────────────
local function rollRarity(): string
	local total = 0
	for _, r in Defs.RARITIES do
		total += Defs.RARITY[r].weight
	end
	local x = math.random() * total
	for _, r in Defs.RARITIES do
		x -= Defs.RARITY[r].weight
		if x <= 0 then
			return r
		end
	end
	return "common"
end

local byRarity: { [string]: { string } } = {}
for _, d in Defs.LIST do
	byRarity[d.rarity] = byRarity[d.rarity] or {}
	table.insert(byRarity[d.rarity], d.id)
end

function M.randomOf(rarity: string): string
	local list = byRarity[rarity] or byRarity.common
	return list[math.random(1, #list)]
end

-- общий конвейер на хабе (как отдельная «база» без владельца)
local HUB = { index = 0, ownerId = 0, belt = {}, model = nil :: any }
M.HUB = HUB

local function beltEnds(B: any, which: string): (Vector3?, Vector3?)
	local belt = B.model and B.model:FindFirstChild(which)
	if not belt then
		return nil, nil
	end
	local s = belt:FindFirstChild("Start")
	local e = belt:FindFirstChild("End")
	if not (s and e) then
		return nil, nil
	end
	return s.Position, e.Position
end

local function spawnBelt(B: any, which: string)
	local from, to = beltEnds(B, which)
	if not from then
		return
	end
	local count = 0
	for _, item in B.belt do
		if item.which == which then
			count += 1
		end
	end
	if count >= Game.BELT_MAX then
		return
	end
	local id = M.randomOf(rollRarity())
	local d = Defs.BY_ID[id]
	local size = Defs.RARITY[d.rarity].size
	local up = Vector3.new(0, size / 2 + 0.2, 0)
	local price = Ctx.price(id, 1)
	local anchor = Bases.makeAnchor(id, CFrame.lookAt(from + up, to + up), {
		Kind = "belt",
		Owner = B.ownerId,
		Base = B.index,
		Price = price,
		From = from + up,
		To = to + up,
		T0 = Ctx.now(),
		Dur = Game.BELT_DUR,
	})
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Buy"
	prompt:SetAttribute("Role", "buy")
	prompt.ActionText = "$" .. tostring(price)
	prompt.ObjectText = d.name.ru
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	local item = { anchor = anchor, id = id, price = price, t0 = Ctx.now(), from = from + up, to = to + up, which = which }
	table.insert(B.belt, item)
	prompt.Triggered:Connect(function(player)
		local S = Ctx.session(player)
		if not S or not S.ready then
			return
		end
		M.buyFromBelt(S, B, item)
	end)
end

function M.clearBelt(B: any)
	for _, item in B.belt do
		if item.anchor then
			item.anchor:Destroy()
		end
	end
	table.clear(B.belt)
end

function M.buyFromBelt(S: any, B: any, item: any)
	if B ~= HUB and S.B ~= B then
		Ctx.notify(S, "msg.notYourBelt", nil, "bad")
		return
	end
	if not table.find(B.belt, item) or not item.anchor.Parent then
		return
	end
	if not M.hasRoom(S) then
		Ctx.notify(S, "msg.noRoom", nil, "bad")
		return
	end
	if not M.spend(S, item.price) then
		Ctx.notify(S, "msg.noCash", nil, "bad")
		return
	end
	table.remove(B.belt, table.find(B.belt, item))
	local pos = item.anchor.Position
	item.anchor:Destroy()
	M.give(S, item.id, 1)
	Ctx.fx("buy", pos, { id = item.id }, nil)
	if api.quest then
		api.quest(S, "buy", 1)
	end
	if api.passXp then
		api.passXp(S, Game.XP.buy)
	end
	Ctx.track(S, "artifact_bought", item.price, { id = item.id })
end

local function moveBelt(B: any)
	local now = Ctx.now()
	for i = #B.belt, 1, -1 do
		local item = B.belt[i]
		local t = (now - item.t0) / Game.BELT_DUR
		if t >= 1 or not item.anchor.Parent then
			if item.anchor then
				item.anchor:Destroy()
			end
			table.remove(B.belt, i)
		else
			local p = item.from:Lerp(item.to, t)
			item.anchor.CFrame = CFrame.lookAt(p, item.to)
		end
	end
end

-- ── Апгрейды на пьедестале ──────────────────────────────────
local function slotArt(S: any, slot: any): any
	if not Ctx.isInt(slot, 1, 20) then
		return nil
	end
	if S.B and S.B.transit[slot] then
		return nil -- артефакт сейчас несёт вор
	end
	return S.data.slots[tostring(slot)]
end

Ctx.actions.artUpgrade = function(S, args)
	local a = slotArt(S, args.slot)
	if not a then
		return false, "msg.noArt"
	end
	if a.lvl >= Game.ART_MAX_LVL then
		return false, "msg.maxLevel"
	end
	local cost = math.floor(Ctx.price(a.id, 1) * Game.ART_UPGRADE_MULT * a.lvl)
	if not M.spend(S, cost) then
		return false, "msg.noCash"
	end
	a.lvl += 1
	Ctx.mark(S, "slots", "income")
	if S.B then
		Bases.renderArts(S.B)
		Bases.playAnim(S.B.arts[args.slot], "collect")
	end
	Ctx.fx("upgrade", S.B and S.B.arts[args.slot] and S.B.arts[args.slot].Position, nil, nil)
	return true, "msg.upgraded"
end

Ctx.actions.artSell = function(S, args)
	local a = slotArt(S, args.slot)
	if not a then
		return false, "msg.noArt"
	end
	local d = Defs.BY_ID[a.id]
	local shards = (Game.SHARDS_FOR[d.rarity] or 1) * a.lvl
	S.data.slots[tostring(args.slot)] = nil
	M.addShards(S, shards)
	Ctx.mark(S, "slots", "income")
	if S.B then
		Bases.renderArts(S.B)
	end
	return true, "msg.merged", { shards = shards }
end

Ctx.actions.artToInv = function(S, args)
	local a = slotArt(S, args.slot)
	if not a then
		return false, "msg.noArt"
	end
	if #S.data.inv >= Game.INVENTORY_MAX then
		return false, "msg.invFull"
	end
	S.data.slots[tostring(args.slot)] = nil
	table.insert(S.data.inv, a)
	Ctx.mark(S, "slots", "inv", "income")
	if S.B then
		Bases.renderArts(S.B)
	end
	return true, nil
end

Ctx.actions.invPlace = function(S, args)
	if not Ctx.isInt(args.i, 1, #S.data.inv) then
		return false, "msg.noArt"
	end
	local slot = args.slot
	if slot == nil then
		slot = M.freeSlot(S)
	end
	local count = if S.B then Bases.slotCount(S.B) else Game.PEDESTALS
	if not Ctx.isInt(slot, 1, count) then
		return false, "msg.noRoom"
	end
	if S.B and S.B.transit[slot] then
		return false, "msg.inTransit"
	end
	local a = table.remove(S.data.inv, args.i)
	local prev = S.data.slots[tostring(slot)]
	S.data.slots[tostring(slot)] = a
	if prev then
		table.insert(S.data.inv, prev)
	end
	Ctx.mark(S, "slots", "inv", "income")
	if S.B then
		Bases.renderArts(S.B)
	end
	return true, nil
end

Ctx.actions.invSell = function(S, args)
	if not Ctx.isInt(args.i, 1, #S.data.inv) then
		return false, "msg.noArt"
	end
	local a = table.remove(S.data.inv, args.i)
	local d = Defs.BY_ID[a.id]
	local shards = (d and Game.SHARDS_FOR[d.rarity] or 1) * a.lvl
	M.addShards(S, shards)
	Ctx.mark(S, "inv")
	return true, "msg.merged", { shards = shards }
end

Ctx.actions.collect = function(S)
	M.collect(S, false)
	return true, nil
end

-- ── Стройка: стены, ловушки, инструмент ─────────────────────
local function wallsTouched(S: any)
	S.data.stats.wall = S.data.wall
	if api.checkAch then
		api.checkAch(S)
	end
	if api.quest then
		api.quest(S, "upgrade", 1)
	end
end

Ctx.actions.wallUpgrade = function(S)
	local d = S.data
	if d.wallBuild then
		return false, "msg.building"
	end
	local nextLvl = d.wall + 1
	local cfg = Game.WALLS[nextLvl]
	if not cfg then
		return false, "msg.maxLevel"
	end
	if not M.spend(S, cfg.cost) then
		return false, "msg.noCash"
	end
	d.wallBuild = { to = nextLvl, left = cfg.build }
	Ctx.mark(S, "wall")
	return true, "msg.buildStarted"
end

local function finishWall(S: any)
	local d = S.data
	if not d.wallBuild then
		return
	end
	d.wall = d.wallBuild.to
	d.wallBuild = nil
	Ctx.mark(S, "wall")
	if S.B then
		Bases.applyWalls(S.B)
		Bases.updateBeacon(S.B)
		local bench = S.B.model:FindFirstChild("Bench")
		Ctx.fx("upgrade", bench and bench:GetPivot().Position, nil, nil)
	end
	Ctx.notify(S, "msg.wallDone", { lvl = d.wall }, "good")
	wallsTouched(S)
end

local function trapCount(S: any): number
	local n = 0
	for _ in S.data.traps do
		n += 1
	end
	return n
end

Ctx.actions.trapPlace = function(S, args)
	if not Ctx.isInt(args.slot, 1, Game.TRAP_SLOTS) or type(args.kind) ~= "string" then
		return false, "msg.bad"
	end
	local cfg = Game.TRAPS[args.kind]
	if not cfg then
		return false, "msg.bad"
	end
	local key = tostring(args.slot)
	if S.data.traps[key] then
		return false, "msg.slotBusy"
	end
	if not M.spend(S, cfg.cost[1]) then
		return false, "msg.noCash"
	end
	S.data.traps[key] = { k = args.kind, l = 1, b = cfg.build[1] }
	S.data.stats.traps = trapCount(S)
	Ctx.mark(S, "traps")
	if S.B then
		Bases.renderTraps(S.B)
	end
	wallsTouched(S)
	return true, "msg.buildStarted"
end

Ctx.actions.trapUpgrade = function(S, args)
	if not Ctx.isInt(args.slot, 1, Game.TRAP_SLOTS) then
		return false, "msg.bad"
	end
	local t = S.data.traps[tostring(args.slot)]
	if not t then
		return false, "msg.noTrap"
	end
	if t.b then
		return false, "msg.building"
	end
	local cfg = Game.TRAPS[t.k]
	if t.l >= #cfg.cost then
		return false, "msg.maxLevel"
	end
	if not M.spend(S, cfg.cost[t.l + 1]) then
		return false, "msg.noCash"
	end
	t.l += 1
	t.b = cfg.build[t.l]
	Ctx.mark(S, "traps")
	if S.B then
		Bases.renderTraps(S.B)
	end
	wallsTouched(S)
	return true, "msg.buildStarted"
end

Ctx.actions.trapRemove = function(S, args)
	if not Ctx.isInt(args.slot, 1, Game.TRAP_SLOTS) then
		return false, "msg.bad"
	end
	S.data.traps[tostring(args.slot)] = nil
	S.data.stats.traps = trapCount(S)
	Ctx.mark(S, "traps")
	if S.B then
		Bases.renderTraps(S.B)
	end
	return true, nil
end

Ctx.actions.toolBuy = function(S, args)
	if not Ctx.isInt(args.tier, 2, #Game.TOOLS) then
		return false, "msg.bad"
	end
	if args.tier ~= S.data.tool + 1 then
		return false, "msg.bad"
	end
	if not M.spend(S, Game.TOOLS[args.tier].cost) then
		return false, "msg.noCash"
	end
	S.data.tool = args.tier
	Ctx.mark(S, "tool")
	Ctx.fx("upgrade", Ctx.root(S) and Ctx.root(S).Position, nil, nil)
	return true, "msg.toolBought"
end

-- ускорить стройку за Build Tokens: 1 жетон за каждые начатые 60 сек
function M.tokenCost(seconds: number): number
	return math.max(1, math.ceil(seconds / 60))
end

Ctx.actions.finishBuild = function(S, args)
	local d = S.data
	if args.what == "wall" then
		if not d.wallBuild then
			return false, "msg.bad"
		end
		local cost = M.tokenCost(d.wallBuild.left)
		if d.tokens < cost then
			return false, "msg.noTokens"
		end
		d.tokens -= cost
		Ctx.mark(S, "tokens")
		finishWall(S)
		return true, nil
	elseif Ctx.isInt(args.slot, 1, Game.TRAP_SLOTS) then
		local t = d.traps[tostring(args.slot)]
		if not t or not t.b then
			return false, "msg.bad"
		end
		local cost = M.tokenCost(t.b)
		if d.tokens < cost then
			return false, "msg.noTokens"
		end
		d.tokens -= cost
		t.b = nil
		Ctx.mark(S, "tokens", "traps")
		if S.B then
			Bases.renderTraps(S.B)
		end
		return true, nil
	end
	return false, "msg.bad"
end

-- ── Тик раз в секунду ───────────────────────────────────────
local function tickSession(S: any, dt: number)
	local d = S.data
	-- доход копится на плите сбора
	local inc = M.income(S)
	if S.shadow then
		inc *= 0.5
	end
	d.pending += inc * dt
	S.incomeNow = inc
	Ctx.mark(S, "pending")
	if S.passes.AutoCollect then
		S.autoT = (S.autoT or 0) + dt
		if S.autoT >= Game.AUTOCOLLECT_EVERY then
			S.autoT = 0
			M.collect(S, true)
		end
	end
	-- энергия
	local now = os.time()
	if d.energy >= Game.ENERGY_MAX then
		d.energyT = now
	elseif now - d.energyT >= Game.ENERGY_REGEN then
		local n = math.floor((now - d.energyT) / Game.ENERGY_REGEN)
		d.energy = math.min(Game.ENERGY_MAX, d.energy + n)
		d.energyT += n * Game.ENERGY_REGEN
		Ctx.mark(S, "energy")
	end
	-- стройка (идёт только пока игрок в игре)
	if d.wallBuild then
		d.wallBuild.left -= dt
		if d.wallBuild.left <= 0 then
			finishWall(S)
		end
	end
	local trapsChanged = false
	for _, t in d.traps do
		if t.b then
			t.b -= dt
			if t.b <= 0 then
				t.b = nil
				trapsChanged = true
			end
		end
	end
	if trapsChanged then
		Ctx.mark(S, "traps")
		if S.B then
			Bases.renderTraps(S.B)
		end
		Ctx.notify(S, "msg.trapDone", nil, "good")
	end
	if d.boostUntil > 0 and d.boostUntil <= now then
		d.boostUntil = 0
		Ctx.mark(S, "boost", "income")
	end
end

function M.init()
	-- плита сбора: касание владельцем
	for _, B in Ctx.bases do
		local plate = B.model:FindFirstChild("Collect")
		if plate and plate:IsA("BasePart") then
			plate.CanTouch = true
			local debounce = {}
			plate.Touched:Connect(function(hit)
				local char = hit.Parent
				local player = char and game.Players:GetPlayerFromCharacter(char)
				if not player then
					return
				end
				local S = Ctx.session(player)
				if not S or not S.ready or S.B ~= B then
					return
				end
				if debounce[player] and os.clock() - debounce[player] < 1 then
					return
				end
				debounce[player] = os.clock()
				M.collect(S, false)
			end)
		end
	end
	-- доход и таймеры
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local dt = math.min(5, now - last)
			last = now
			for _, S in Ctx.sessions do
				if S.ready then
					local ok, err = pcall(tickSession, S, dt)
					if not ok then
						warn("[Economy] тик:", err)
					end
				end
			end
		end
	end)
	-- общий конвейер на хабе
	HUB.model = workspace:FindFirstChild("Map") and workspace.Map:FindFirstChild("Hub")
	task.spawn(function()
		local acc = 0
		while true do
			task.wait(0.25)
			acc += 0.25
			moveBelt(HUB)
			if acc >= Game.BELT_EVERY then
				acc = 0
				if next(Ctx.sessions) then
					spawnBelt(HUB, "Belt")
				end
			end
		end
	end)
end

api.addCash = M.addCash
api.spend = M.spend
api.addShards = M.addShards
api.addTokens = M.addTokens
api.addEnergy = M.addEnergy
api.give = M.give
api.hasRoom = M.hasRoom
api.income = M.income
api.baseIncome = M.baseIncome
api.mult = M.mult
api.collect = M.collect
api.randomOf = M.randomOf
api.clearBelt = M.clearBelt

return M
