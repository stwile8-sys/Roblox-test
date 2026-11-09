--!nonstrict
-- Прогрессия: ребёрс, ежедневные квесты, серия входов, достижения, Титан-ранг, сезонный пропуск, VIP-бонус.

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)

local Game = Ctx.Game
local Defs = Ctx.Defs
local api = Ctx.api

local M: any = {}

local function today(): number
	return math.floor(os.time() / 86400)
end

-- ── Титан-ранг (сбрасывается каждый сезон) ──────────────────
function M.titan(S: any, delta: number)
	local d = S.data
	local season = Game.seasonNumber(os.time())
	if d.titanSeason ~= season then
		d.titanSeason = season
		d.titan = 0
	end
	d.titan = math.max(0, d.titan + delta)
	Ctx.mark(S, "titan")
end

-- ── Достижения ──────────────────────────────────────────────
local function statValue(S: any, stat: string): number
	local d = S.data
	if stat == "rebirths" then
		return d.rebirths
	elseif stat == "collection" then
		local n = 0
		for id in d.coll do
			local def = Defs.BY_ID[id]
			if def and not def.seasonal then
				n += 1
			end
		end
		return n
	elseif stat == "wall" then
		return d.wall
	elseif stat == "clan" then
		return if d.clan ~= "" then 1 else 0
	end
	return d.stats[stat] or 0
end

function M.checkAch(S: any)
	local d = S.data
	for _, a in Game.ACHIEVEMENTS do
		if not d.ach[a.id] and statValue(S, a.stat) >= a.goal then
			d.ach[a.id] = true
			api.addShards(S, a.shards)
			Ctx.mark(S, "ach")
			Ctx.popup(S, "achievement", { id = a.id, shards = a.shards })
			Ctx.fx("levelup", Ctx.root(S) and Ctx.root(S).Position, nil)
		end
	end
end

-- ── Квесты ──────────────────────────────────────────────────
local function rollQuests(S: any)
	local d = S.data
	local day = today()
	if d.quests.day == day then
		return
	end
	local rng = Random.new(day * 7919 + S.player.UserId % 100000)
	local pool = table.clone(Game.QUESTS)
	local list = {}
	for _ = 1, Game.DAILY_QUESTS do
		local q = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, { id = q.id, p = 0, claimed = false })
	end
	d.quests = { day = day, list = list }
	Ctx.mark(S, "quests")
end

local function questCfg(id: string): any
	for _, q in Game.QUESTS do
		if q.id == id then
			return q
		end
	end
	return nil
end

function M.quest(S: any, id: string, n: number)
	if S.isBot then
		return
	end
	rollQuests(S)
	for _, q in S.data.quests.list do
		if q.id == id and not q.claimed then
			local cfg = questCfg(id)
			if cfg and q.p < cfg.goal then
				q.p = math.min(cfg.goal, q.p + n)
				Ctx.mark(S, "quests")
				if q.p >= cfg.goal then
					Ctx.notify(S, "msg.questDone", nil, "gold")
				end
			end
		end
	end
end

Ctx.actions.questClaim = function(S, args)
	rollQuests(S)
	if not Ctx.isInt(args.i, 1, #S.data.quests.list) then
		return false, "msg.bad"
	end
	local q = S.data.quests.list[args.i]
	local cfg = questCfg(q.id)
	if q.claimed or not cfg or q.p < cfg.goal then
		return false, "msg.notYet"
	end
	q.claimed = true
	local r = Game.QUEST_REWARD
	api.addShards(S, r.shards)
	api.addTokens(S, r.tokens)
	local cash = math.floor(math.max(100, api.income(S) * r.incomeSeconds))
	api.addCash(S, cash, "quest")
	M.passXp(S, Game.XP.quest)
	Ctx.mark(S, "quests")
	return true, "msg.claimed", { cash = cash, shards = r.shards, tokens = r.tokens }
end

-- ── Серия входов ────────────────────────────────────────────
function M.checkStreak(S: any)
	local d = S.data
	local day = today()
	if d.streak.last == day then
		return
	end
	if d.streak.last == day - 1 then
		d.streak.count = d.streak.count % 7 + 1
	else
		d.streak.count = 1 -- пропуск сбрасывает серию
	end
	d.streak.last = day
	d.streak.claimed = false
	Ctx.mark(S, "streak")
	Ctx.popup(S, "daily", { day = d.streak.count })
end

Ctx.actions.streakClaim = function(S)
	local d = S.data
	if d.streak.claimed or d.streak.last ~= today() then
		return false, "msg.notYet"
	end
	local r = Game.STREAK[d.streak.count]
	if r.art and not api.hasRoom(S) then
		return false, "msg.noRoom"
	end
	d.streak.claimed = true
	if r.cashSec then
		api.addCash(S, math.floor(math.max(200, api.income(S) * r.cashSec)), "streak")
	end
	if r.tokens then
		api.addTokens(S, r.tokens)
	end
	if r.shards then
		api.addShards(S, r.shards)
	end
	if r.art then
		api.give(S, r.art, 1)
	end
	Ctx.mark(S, "streak")
	return true, "msg.claimed"
end

-- ── VIP: ежедневные осколки ─────────────────────────────────
function M.checkVip(S: any)
	if S.passes.VIP and S.data.vipDay ~= today() then
		S.data.vipDay = today()
		api.addShards(S, 5)
		Ctx.notify(S, "msg.vipDaily", nil, "gold")
	end
end

-- ── Сезонный пропуск ────────────────────────────────────────
function M.checkPass(S: any)
	local p = S.data.pass
	local season = Game.seasonNumber(os.time())
	if p.season ~= season then
		S.data.pass = { season = season, xp = 0, prem = false, cf = {}, cp = {} }
		Ctx.mark(S, "pass")
	end
end

function M.passXp(S: any, n: number)
	if S.isBot then
		return
	end
	M.checkPass(S)
	local p = S.data.pass
	local before = math.floor(p.xp / Game.PASS_XP)
	p.xp = math.min(p.xp + n, Game.PASS_LEVELS * Game.PASS_XP)
	local after = math.floor(p.xp / Game.PASS_XP)
	Ctx.mark(S, "pass")
	if after > before then
		Ctx.notify(S, "msg.passLevel", { lvl = after }, "gold")
	end
end

local function grantReward(S: any, r: any): boolean
	if r.art then
		if not api.hasRoom(S) then
			return false
		end
		local id
		if r.art == "seasonal" then
			id = "s" .. Game.seasonTheme(os.time())
		else
			id = api.randomOf(r.art)
		end
		api.give(S, id, 1)
	end
	if r.shards then
		api.addShards(S, r.shards)
	end
	if r.tokens then
		api.addTokens(S, r.tokens)
	end
	if r.cashSec then
		api.addCash(S, math.floor(math.max(300, api.income(S) * r.cashSec)), "pass")
	end
	if r.skin then
		S.data.skins[r.skin] = true
		Ctx.mark(S, "skins")
	end
	return true
end

Ctx.actions.passClaim = function(S, args)
	M.checkPass(S)
	local p = S.data.pass
	if not Ctx.isInt(args.level, 1, Game.PASS_LEVELS) then
		return false, "msg.bad"
	end
	if math.floor(p.xp / Game.PASS_XP) < args.level then
		return false, "msg.notYet"
	end
	local key = tostring(args.level)
	local premium = args.premium == true
	if premium and not p.prem then
		return false, "msg.needPass"
	end
	local claimed = if premium then p.cp else p.cf
	if claimed[key] then
		return false, "msg.notYet"
	end
	if not grantReward(S, Game.passReward(args.level, premium)) then
		return false, "msg.noRoom"
	end
	claimed[key] = true
	Ctx.mark(S, "pass")
	return true, "msg.claimed"
end

-- ── Ребёрс ──────────────────────────────────────────────────
local function rarityAtLeast(id: string, rarity: string): boolean
	local d = Defs.BY_ID[id]
	if not d or d.rarity == "chrono" then
		return false
	end
	return Defs.RARITY[d.rarity].index >= Defs.RARITY[rarity].index
end

function M.canRebirth(S: any): (boolean, string?)
	local d = S.data
	if d.rebirths >= Game.REBIRTH_MAX then
		return false, "msg.maxRebirth"
	end
	local req = Game.rebirthReq(d.rebirths + 1)
	if d.cash < req.cash then
		return false, "msg.noCash"
	end
	-- считаем по пьедесталам: каждый артефакт закрывает одно требование (от высокого к низкому)
	local pool = {}
	for k, a in d.slots do
		if not (S.B and S.B.transit[tonumber(k)]) then
			table.insert(pool, a.id)
		end
	end
	local needs = table.clone(req.need)
	table.sort(needs, function(a, b)
		return Defs.RARITY[a.rarity].index > Defs.RARITY[b.rarity].index
	end)
	for _, need in needs do
		local left = need.count
		for i = #pool, 1, -1 do
			if left <= 0 then
				break
			end
			if rarityAtLeast(pool[i], need.rarity) then
				table.remove(pool, i)
				left -= 1
			end
		end
		if left > 0 then
			return false, "msg.needArts"
		end
	end
	return true, nil
end

Ctx.actions.rebirth = function(S)
	if S.carry then
		return false, "msg.busy"
	end
	local ok, why = M.canRebirth(S)
	if not ok then
		return false, why
	end
	local d = S.data
	-- анимация вознесения у артефактов
	if S.B then
		for _, anchor in S.B.arts do
			Bases.playAnim(anchor, "rebirth")
		end
	end
	d.cash = 0
	d.pending = 0
	-- сбрасываем артефакты на базе; Chrono-аномалии остаются (их нельзя требовать и они дают перки)
	local keep = {}
	for k, a in d.slots do
		local def = Defs.BY_ID[a.id]
		if def and def.rarity == "chrono" then
			keep[k] = a
		end
	end
	d.slots = keep
	d.rebirths += 1
	Ctx.mark(S, "cash", "pending", "slots", "income", "rebirths", "lock")
	task.delay(1.2, function()
		if S.B then
			Bases.renderArts(S.B)
		end
	end)
	if api.passXp then
		M.passXp(S, 50)
	end
	Ctx.fx("rebirth", Ctx.root(S) and Ctx.root(S).Position, { n = d.rebirths })
	if api.setPose then
		api.setPose(S, "rebirth", 2.5)
	end
	M.checkAch(S)
	Ctx.track(S, "rebirth_completed", d.rebirths)
	if api.updateBoards then
		api.updateBoards(S)
	end
	return true, "msg.rebirthed", { n = d.rebirths }
end

-- ── Вход игрока ─────────────────────────────────────────────
function M.onJoin(S: any)
	rollQuests(S)
	M.checkPass(S)
	M.titan(S, 0)
	M.checkStreak(S)
	M.checkVip(S)
	M.checkAch(S)
end

api.titan = M.titan
api.checkAch = M.checkAch
api.quest = M.quest
api.passXp = M.passXp
api.canRebirth = M.canRebirth
api.checkPass = M.checkPass
api.checkVip = M.checkVip

return M
