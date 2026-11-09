--!strict
-- Единственный владелец сохранений игроков.
-- Блокировка сессии: в записи хранится {job, t}. Чужая свежая блокировка (моложе LOCK_STALE)
-- не даёт загрузиться второй раз — так исключается дюп при входе с двух устройств.
-- Автосохранение обновляет время блокировки; при выходе блокировка снимается.

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Map = require(game.ReplicatedStorage.Shared.Config.Map)

local STORE_NAME = "FE_Profiles_v1"
local LOCK_STALE = 300
local AUTOSAVE = 60
local LOAD_TRIES = 6

export type City = {
	grid: string, -- 400 символов: "." пусто, "#" дорога, "R" "C" "I" зоны
	grown: { { any } }, -- {ключ клетки, зона, размер, жители/занятость}
	special: { { any } }, -- {id, ключ клетки}
	spent: number, -- потрачено на особые здания (для налога на землю)
}

export type Data = {
	v: number,
	money: number,
	tutorial: number, -- 1..5 шаг, 6 — пройден
	badges: { [string]: boolean },
	items: { [string]: number },
	vehicles: { [string]: number },
	plot: number?, -- номер участка в мире
	world: string?,
	city: City?,
	rates: { [string]: number }, -- скорость дохода/производства в час на момент сохранения
	lastOnline: number,
	incoming: { { any } }, -- доставки с рынка {предмет, кол-во, время прибытия}
	frac: { [string]: number }, -- дробные остатки производства
	jobsDone: number,
	firstJoin: number,
	prefs: { [string]: string }, -- язык, графика
}

local M = {}

local store: DataStore? = nil
local storeOk, storeErr = pcall(function()
	store = DataStoreService:GetDataStore(STORE_NAME)
end)
if not storeOk then
	warn("Сохранения недоступны:", storeErr)
end

local profiles: { [Player]: Data } = {}
local lockLost: { [Player]: boolean } = {}
local saving: { [Player]: boolean } = {}

function M.newCity(index: number): City
	local cells = table.create(Map.CELLS * Map.CELLS, ".")
	for _, k in Map.starterRoad(index) do
		cells[k] = "#"
	end
	return { grid = table.concat(cells), grown = {}, special = {}, spent = 0 }
end

local function defaults(): Data
	return {
		v = 1,
		money = 500,
		tutorial = 1,
		badges = {},
		items = {},
		vehicles = {},
		plot = nil,
		world = nil,
		city = nil,
		rates = {},
		lastOnline = os.time(),
		incoming = {},
		frac = {},
		jobsDone = 0,
		firstJoin = os.time(),
		prefs = {},
	}
end

-- Подставить недостающие поля и отбросить мусор неверных типов
local function reconcile(raw: any): Data
	local d = defaults()
	if type(raw) ~= "table" then
		return d
	end
	for k, v in d :: any do
		local got = raw[k]
		if got ~= nil and type(got) == type(v) then
			(d :: any)[k] = got
		end
	end
	if type(raw.plot) == "number" then
		d.plot = raw.plot
	end
	if type(raw.world) == "string" then
		d.world = raw.world
	end
	if type(raw.city) == "table" and type(raw.city.grid) == "string" and #raw.city.grid == Map.CELLS * Map.CELLS then
		d.city = {
			grid = raw.city.grid,
			grown = if type(raw.city.grown) == "table" then raw.city.grown else {},
			special = if type(raw.city.special) == "table" then raw.city.special else {},
			spent = if type(raw.city.spent) == "number" then raw.city.spent else 0,
		}
	end
	if d.money ~= d.money or d.money == math.huge then
		d.money = 0
	end
	return d
end

local function key(userId: number): string
	return "p_" .. userId
end

-- Прочитать сохранение без блокировки (для показа чужих городов)
function M.peek(userId: number): Data?
	if not store then
		return nil
	end
	local s = store :: DataStore
	local ok, raw = pcall(function()
		return s:GetAsync(key(userId))
	end)
	if ok and type(raw) == "table" then
		return reconcile(raw.data)
	end
	return nil
end

-- Загрузка с блокировкой. Возвращает данные или nil + причина
function M.load(player: Player): (Data?, string?)
	if not store then
		if RunService:IsStudio() then
			local d = defaults()
			profiles[player] = d
			return d, nil
		end
		return nil, "store"
	end
	local s = store :: DataStore
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
					return nil -- не трогаем запись
				end
				result = reconcile(old.data)
				old.data = result
				old.lock = { job = jobId, t = os.time() }
				return old
			end)
		end)
		if ok and result and not locked then
			if player.Parent ~= Players then
				-- игрок ушёл, пока грузились: сразу отпускаем блокировку
				profiles[player] = result
				M.release(player)
				return nil, "left"
			end
			profiles[player] = result
			return result, nil
		end
		if not ok then
			warn("Загрузка профиля, попытка", attempt, err)
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
	if not data or not store or lockLost[player] then
		return false
	end
	local s = store :: DataStore
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
			return old
		end)
	end)
	if stolen then
		lockLost[player] = true
		warn("Блокировка профиля перехвачена другим сервером:", player.UserId)
		return false
	end
	if not ok then
		warn("Сохранение не удалось:", player.UserId, err)
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

-- Сохранить и снять блокировку; данные остаются доступны через M.get до forget
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

-- Сохранить всех при остановке сервера (вызывается из BindToClose)
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

function M.newId(): string
	return HttpService:GenerateGUID(false)
end

return M
