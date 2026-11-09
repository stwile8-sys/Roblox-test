--!strict
-- Единственный владелец сохранений игроков.
-- Ключ: store "profiles", key "User_<id>" (по ТЗ: profiles/User_{Id}). Roblox хранит версии ключа 30 дней.
-- Блокировка сессии: в записи {data, lock = {job, t}}. Чужая свежая блокировка не даёт загрузиться
-- второй раз — нет дюпа при входе с двух устройств. Автосохранение раз в 60 сек через UpdateAsync.
-- Кэш активных сессий — MemoryStore (быстрый ответ «игрок сейчас в игре?» для офлайн-баз).
-- Офлайн-кража — атомарный UpdateAsync чужой записи: только если владелец не в игре.

local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Game = require(game.ReplicatedStorage.Shared.Config.Game)

local STORE_NAME = if RunService:IsStudio() then "profiles_studio" else "profiles"
local LOCK_STALE = 300
local AUTOSAVE = 60
local LOAD_TRIES = 6
local SESSION_TTL = 200

export type Art = { id: string, lvl: number }
export type Trap = { k: string, l: number, b: number? } -- b = секунд стройки осталось
export type Data = {
	v: number,
	cash: number,
	shards: number,
	tokens: number,
	energy: number,
	energyT: number,
	rebirths: number,
	slots: { [string]: Art },
	inv: { Art },
	pending: number,
	wall: number,
	wallBuild: { to: number, left: number }?,
	traps: { [string]: Trap },
	trapSkin: string,
	tool: number,
	coll: { [string]: boolean },
	skins: { [string]: boolean },
	skin: string,
	stats: { [string]: number },
	titan: number,
	titanSeason: number,
	quests: { day: number, list: { { id: string, p: number, claimed: boolean } } },
	streak: { last: number, count: number },
	ach: { [string]: boolean },
	pass: { season: number, xp: number, prem: boolean, cf: { [string]: boolean }, cp: { [string]: boolean } },
	clan: string,
	once: { [string]: boolean },
	boostUntil: number,
	ftue: number,
	inbox: { { by: string, id: string, t: number } },
	offLost: number,
	lastOnline: number,
	firstJoin: number,
	vipDay: number,
	ac: { shadowUntil: number, shadows: number },
	receipts: { string },
	notifyDay: number,
	lang: string,
}

local M = {}

local store: DataStore? = nil
local recent: OrderedDataStore? = nil
local sessions: MemoryStoreHashMap? = nil
pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
	recent = DataStoreService:GetOrderedDataStore(STORE_NAME .. "_recent")
end)
pcall(function()
	sessions = MemoryStoreService:GetHashMap("sessions")
end)
if not store then
	warn("[Profiles] DataStore недоступен")
end

local profiles: { [Player]: Data } = {}
local lockLost: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}

function M.defaults(): Data
	local now = os.time()
	return {
		v = 1,
		cash = 0,
		shards = 0,
		tokens = 0,
		energy = Game.ENERGY_MAX,
		energyT = now,
		rebirths = 0,
		slots = {},
		inv = {},
		pending = 0,
		wall = 1,
		wallBuild = nil,
		traps = {},
		trapSkin = "",
		tool = 1,
		coll = {},
		skins = { default = true },
		skin = "default",
		stats = {},
		titan = 0,
		titanSeason = 0,
		quests = { day = 0, list = {} },
		streak = { last = 0, count = 0 },
		ach = {},
		pass = { season = 0, xp = 0, prem = false, cf = {}, cp = {} },
		clan = "",
		once = {},
		boostUntil = 0,
		ftue = 0,
		inbox = {},
		offLost = 0,
		lastOnline = now,
		firstJoin = now,
		vipDay = 0,
		ac = { shadowUntil = 0, shadows = 0 },
		receipts = {},
		notifyDay = 0,
		lang = "",
	}
end

local function num(v: any, default: number): number
	if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		return default
	end
	return v
end

local function validArt(a: any): Art?
	if type(a) == "table" and type(a.id) == "string" and #a.id < 40 then
		return { id = a.id, lvl = math.clamp(math.floor(num(a.lvl, 1)), 1, Game.ART_MAX_LVL) }
	end
	return nil
end

-- Подставить недостающие поля и отбросить мусор неверных типов
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
	for _, k in { "cash", "shards", "tokens", "energy", "pending" } do
		(d :: any)[k] = math.max(0, num((d :: any)[k], 0))
	end
	local slots = {}
	for k, a in d.slots do
		local ok = validArt(a)
		if ok and tonumber(k) then
			slots[tostring(tonumber(k))] = ok
		end
	end
	d.slots = slots
	local inv = {}
	for _, a in d.inv do
		local ok = validArt(a)
		if ok and #inv < Game.INVENTORY_MAX + 10 then
			table.insert(inv, ok)
		end
	end
	d.inv = inv
	if type(raw.wallBuild) == "table" and type(raw.wallBuild.to) == "number" then
		d.wallBuild = { to = raw.wallBuild.to, left = num(raw.wallBuild.left, 0) }
	end
	d.wall = math.clamp(math.floor(num(d.wall, 1)), 1, #Game.WALLS)
	d.tool = math.clamp(math.floor(num(d.tool, 1)), 1, #Game.TOOLS)
	d.rebirths = math.clamp(math.floor(num(d.rebirths, 0)), 0, Game.REBIRTH_MAX)
	return d
end

local function key(userId: number): string
	return "User_" .. userId
end

local function setSession(userId: number, value: string?)
	local s = sessions
	if not s then
		return
	end
	task.spawn(function()
		pcall(function()
			if value then
				s:SetAsync(tostring(userId), value, SESSION_TTL)
			else
				s:RemoveAsync(tostring(userId))
			end
		end)
	end)
end

-- Игрок сейчас в игре на каком-то сервере? (MemoryStore; при ошибке — считаем, что да: безопаснее)
function M.isOnline(userId: number): boolean
	local s = sessions
	if not s then
		return true
	end
	local ok, v = pcall(function()
		return s:GetAsync(tostring(userId))
	end)
	if not ok then
		return true
	end
	return v ~= nil
end

-- Прочитать чужое сохранение без блокировки (для показа офлайн-базы)
function M.peek(userId: number): (Data?, boolean)
	local s = store
	if not s then
		return nil, false
	end
	local opts = Instance.new("DataStoreGetOptions")
	opts.UseCache = false
	local ok, raw = pcall(function()
		return s:GetAsync(key(userId), opts)
	end)
	if ok and type(raw) == "table" then
		local lock = raw.lock
		local locked = type(lock) == "table" and type(lock.t) == "number" and os.time() - lock.t < LOCK_STALE
		return M.reconcile(raw.data), locked
	end
	return nil, false
end

-- Недавно игравшие (кандидаты для офлайн-баз): {userId, lastOnline}
function M.recentPlayers(limit: number): { { id: number, t: number } }
	local r = recent
	local out = {}
	if not r then
		return out
	end
	pcall(function()
		local pages = r:GetSortedAsync(false, math.clamp(limit, 1, 100))
		for _, entry in pages:GetCurrentPage() do
			local id = tonumber(entry.key)
			if id then
				table.insert(out, { id = id, t = entry.value })
			end
		end
	end)
	return out
end

-- Загрузка с блокировкой. Возвращает данные или nil + причина
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
			setSession(player.UserId, jobId)
			if player.Parent ~= Players then
				M.release(player)
				return nil, "left"
			end
			return result, nil
		end
		if not ok then
			warn("[Profiles] загрузка, попытка", attempt, err)
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
		warn("[Profiles] блокировку перехватил другой сервер:", player.UserId)
		return false
	end
	if not ok then
		warn("[Profiles] сохранение не удалось:", player.UserId, err)
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
	if ok then
		setSession(player.UserId, game.JobId)
	end
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
	setSession(player.UserId, nil)
	local r = recent
	if r then
		local id = player.UserId
		task.spawn(function()
			pcall(function()
				r:SetAsync(tostring(id), os.time())
			end)
		end)
	end
end

function M.forget(player: Player)
	profiles[player] = nil
	lockLost[player] = nil
	saving[player] = nil
end

function M.startAutosave()
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE)
			for player in profiles do
				if player.Parent == Players then
					task.spawn(M.save, player)
				end
			end
		end
	end)
end

function M.releaseAll()
	local pending = 0
	for player in profiles do
		pending += 1
		task.spawn(function()
			M.release(player)
			pending -= 1
		end)
	end
	local started = os.clock()
	while pending > 0 and os.clock() - started < 25 do
		task.wait(0.2)
	end
end

-- ── Офлайн-кража ──────────────────────────────────────────────
-- Атомарно забрать артефакт из слота офлайн-игрока. Отказ, если владелец в игре (свежая блокировка),
-- артефакта уже нет (украли на другом сервере) или достигнут лимит краж за отлучку.
function M.takeFromOffline(victimId: number, slot: number, artId: string, thiefName: string): (Art?, string?)
	local s0 = store
	if not s0 then
		return nil, "store"
	end
	local s = s0 :: DataStore
	local reason: string? = nil
	local taken: Art? = nil
	local ok, err = pcall(function()
		s:UpdateAsync(key(victimId), function(old: any)
			reason = nil
			taken = nil
			if type(old) ~= "table" or type(old.data) ~= "table" then
				reason = "gone"
				return nil
			end
			local lock = old.lock
			if type(lock) == "table" and type(lock.t) == "number" and os.time() - lock.t < LOCK_STALE then
				reason = "online"
				return nil
			end
			local d = M.reconcile(old.data)
			local a = d.slots[tostring(slot)]
			if not a or a.id ~= artId then
				reason = "gone"
				return nil
			end
			if d.offLost >= Game.OFFLINE_STEAL_LIMIT then
				reason = "limit"
				return nil
			end
			d.slots[tostring(slot)] = nil
			d.offLost += 1
			table.insert(d.inbox, { by = string.sub(thiefName, 1, 40), id = artId, t = os.time() })
			while #d.inbox > 20 do
				table.remove(d.inbox, 1)
			end
			taken = a
			old.data = d
			return old, { victimId }
		end)
	end)
	if not ok then
		warn("[Profiles] офлайн-кража:", err)
		return nil, "error"
	end
	return taken, reason
end

-- Журнал краж (для разборов): отдельный store, ключ на событие
local logStore: DataStore? = nil
pcall(function()
	logStore = DataStoreService:GetDataStore(STORE_NAME .. "_thefts")
end)
function M.logTheft(entry: { [string]: any })
	local ls = logStore
	if not ls then
		return
	end
	task.spawn(function()
		pcall(function()
			ls:SetAsync(string.format("t_%d_%d", os.time(), math.random(1, 1e9)), entry)
		end)
	end)
end

return M
