--!strict
-- Сохранения игроков. Блокировка сессии в записи {data, lock = {job, t}}: вход с двух устройств
-- не даст дюпа. Автосохранение раз в 60 сек через UpdateAsync, сохранение при выходе и остановке.

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local STORE_NAME = if RunService:IsStudio() then "launch_studio" else "launch_v1"
local LOCK_STALE = 300
local LOAD_TRIES = 6

export type Data = {
	v: number,
	power: number,
	coins: number,
	best: number, -- лучшая дальность за всё время
	runBest: number, -- лучшая дальность с последнего перерождения
	rebirths: number,
	upg: { power: number, coin: number, bounce: number },
	launches: number,
	daily: { day: number, streak: number },
	codes: { [string]: boolean },
	boostUntil: number,
	playSec: number,
	firstJoin: number,
	lastOnline: number,
	receipts: { string },
	ftue: number,
	auto: boolean,
}

local M = {}

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not store then
	warn("[Data] DataStore недоступен")
end

local profiles: { [Player]: Data } = {}
local lockLost: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}

function M.defaults(): Data
	local now = os.time()
	return {
		v = 1,
		power = 0,
		coins = 0,
		best = 0,
		runBest = 0,
		rebirths = 0,
		upg = { power = 0, coin = 0, bounce = 0 },
		launches = 0,
		daily = { day = 0, streak = 0 },
		codes = {},
		boostUntil = 0,
		playSec = 0,
		firstJoin = now,
		lastOnline = now,
		receipts = {},
		ftue = 0,
		auto = true,
	}
end

local function num(v: any, default: number): number
	if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		return default
	end
	return v
end

function M.reconcile(raw: any): Data
	local d = M.defaults()
	if type(raw) ~= "table" then
		return d
	end
	for k, v in d :: any do
		local got = raw[k]
		if got ~= nil and type(got) == type(v) then
			(d :: any)[k] = got
		end
	end
	for _, k in { "power", "coins", "best", "runBest", "launches", "playSec" } do
		(d :: any)[k] = math.max(0, num((d :: any)[k], 0))
	end
	local u = M.defaults().upg
	if type(raw.upg) == "table" then
		for k in u :: any do
			(u :: any)[k] = math.max(0, math.floor(num(raw.upg[k], 0)))
		end
	end
	d.upg = u
	d.rebirths = math.max(0, math.floor(num(d.rebirths, 0)))
	if type(raw.daily) ~= "table" then
		d.daily = { day = 0, streak = 0 }
	else
		d.daily = { day = num(raw.daily.day, 0), streak = num(raw.daily.streak, 0) }
	end
	local rec = {}
	for _, r in d.receipts do
		if type(r) == "string" then
			table.insert(rec, r)
		end
	end
	while #rec > 60 do
		table.remove(rec, 1)
	end
	d.receipts = rec
	return d
end

local function key(userId: number): string
	return "User_" .. userId
end

function M.load(player: Player): (Data?, string?)
	local s0 = store
	if not s0 then
		if RunService:IsStudio() then
			local d = M.defaults()
			profiles[player] = d
			return d, nil
		end
		return nil, "store"
	end
	local s = s0 :: DataStore
	local jobId = game.JobId
	for attempt = 1, LOAD_TRIES do
		local locked = false
		local result: Data? = nil
		local ok, err = pcall(function()
			s:UpdateAsync(key(player.UserId), function(old: any)
				old = if type(old) == "table" then old else {}
				local lock = old.lock
				if
					type(lock) == "table"
					and lock.job ~= jobId
					and type(lock.t) == "number"
					and os.time() - lock.t < LOCK_STALE
				then
					locked = true
					return nil
				end
				result = M.reconcile(old.data)
				old.data = result
				old.lock = { job = jobId, t = os.time() }
				return old, { player.UserId }
			end)
		end)
		if ok and result and not locked then
			profiles[player] = result
			if player.Parent ~= Players then
				M.release(player)
				return nil, "left"
			end
			return result, nil
		end
		if not ok then
			warn("[Data] загрузка, попытка", attempt, err)
		end
		task.wait(if locked then 5 else 2)
	end
	return nil, "locked"
end

function M.get(player: Player): Data?
	return profiles[player]
end

local function write(player: Player, release: boolean): boolean
	local data = profiles[player]
	local s0 = store
	if not data or not s0 or lockLost[player] then
		return false
	end
	local s = s0 :: DataStore
	local jobId = game.JobId
	data.lastOnline = os.time()
	local stolen = false
	local ok, err = pcall(function()
		s:UpdateAsync(key(player.UserId), function(old: any)
			old = if type(old) == "table" then old else {}
			local lock = old.lock
			if type(lock) == "table" and lock.job ~= jobId then
				stolen = true
				return nil
			end
			old.data = data
			old.lock = if release then nil else { job = jobId, t = os.time() }
			return old, { player.UserId }
		end)
	end)
	if stolen then
		lockLost[player] = true
		warn("[Data] блокировку перехватил другой сервер:", player.UserId)
		return false
	end
	if not ok then
		warn("[Data] сохранение не удалось:", player.UserId, err)
	end
	return ok
end

function M.save(player: Player): boolean
	if saving[player] then
		return false
	end
	saving[player] = true
	local ok = write(player, false)
	saving[player] = nil
	return ok
end

-- Сохранить сейчас и дождаться (для покупок: сначала сохранить, потом подтвердить)
function M.saveNow(player: Player): boolean
	for _ = 1, 40 do
		if not saving[player] then
			break
		end
		task.wait(0.1)
	end
	return M.save(player)
end

function M.release(player: Player)
	for _ = 1, 20 do
		if not saving[player] then
			break
		end
		task.wait(0.25)
	end
	saving[player] = true
	for attempt = 1, 3 do
		if write(player, true) then
			break
		end
		if lockLost[player] then
			break
		end
		task.wait(attempt)
	end
	saving[player] = nil
end

function M.forget(player: Player)
	profiles[player] = nil
	lockLost[player] = nil
	saving[player] = nil
end

return M
