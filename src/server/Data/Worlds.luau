--!strict
-- Миры. Мир — постоянный приватный (reserved) сервер на 20 участков.
-- Записи в DataStore:
--   index            {nextId, open = {[id] = членов}}  — миры, где есть свободные участки
--   w_<id>           {id, code, ps, members = {[userId] = true}}
--   ps_<privateId>   id мира по PrivateServerId
--   m_<userId>       id мира игрока
--   market_<id>      заявки рынка мира
-- Отдельное хранилище выплат продавцам, которые были оффлайн: u_<userId> = сумма.

local DataStoreService = game:GetService("DataStoreService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")

local MAX_MEMBERS = 20

local M = {}

local store: DataStore? = nil
local payouts: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("FE_Worlds_v2")
	payouts = DataStoreService:GetDataStore("FE_Payouts_v2")
end)

export type World = {
	id: string,
	code: string?,
	ps: string?,
	members: { [string]: boolean },
}

local function retry<T>(fn: () -> T, tries: number?): (boolean, T | string)
	local last: any = nil
	for attempt = 1, tries or 3 do
		local ok, res = pcall(fn)
		if ok then
			return true, res
		end
		last = res
		task.wait(attempt)
	end
	warn("Миры: ошибка хранилища", last)
	return false, tostring(last)
end

function M.available(): boolean
	return store ~= nil
end

function M.getWorld(id: string): World?
	if not store then
		return nil
	end
	local s = store :: DataStore
	local ok, w = retry(function()
		return s:GetAsync("w_" .. id)
	end)
	if ok and type(w) == "table" then
		return w :: any
	end
	return nil
end

function M.worldOfPrivateServer(ps: string): string?
	if not store then
		return nil
	end
	local s = store :: DataStore
	local ok, id = retry(function()
		return s:GetAsync("ps_" .. ps)
	end)
	if ok and type(id) == "string" then
		return id
	end
	return nil
end

function M.memberWorld(userId: number): string?
	if not store then
		return nil
	end
	local s = store :: DataStore
	local ok, id = retry(function()
		return s:GetAsync("m_" .. userId)
	end)
	if ok and type(id) == "string" then
		return id
	end
	return nil
end

-- Добавить игрока в мир, если там есть место. true — если он теперь член мира.
function M.addMember(id: string, userId: number): boolean
	if not store then
		return false
	end
	local s = store :: DataStore
	-- игрок уже числится в другом мире — не переписываем
	local okM, prev = retry(function()
		return s:GetAsync("m_" .. userId)
	end)
	if not okM or (type(prev) == "string" and prev ~= id) then
		return false
	end
	local added = false
	local ok = retry(function()
		s:UpdateAsync("w_" .. id, function(w: any)
			if type(w) ~= "table" then
				return nil
			end
			w.members = w.members or {}
			local count = 0
			for _ in w.members do
				count += 1
			end
			if w.members[tostring(userId)] then
				added = true
				return nil
			end
			if count >= MAX_MEMBERS then
				return nil
			end
			w.members[tostring(userId)] = true
			added = true
			return w
		end)
		return true
	end)
	if not ok or not added then
		return false
	end
	retry(function()
		s:SetAsync("m_" .. userId, id)
		return true
	end)
	-- обновить счётчик в индексе
	retry(function()
		s:UpdateAsync("index", function(idx: any)
			if type(idx) ~= "table" or type(idx.open) ~= "table" then
				return nil
			end
			local n = idx.open[id]
			if n == nil then
				return nil
			end
			n += 1
			idx.open[id] = if n >= MAX_MEMBERS then nil else n
			return idx
		end)
		return true
	end)
	return true
end

local function createWorld(): World?
	if not store then
		return nil
	end
	local s = store :: DataStore
	local okR, code, ps = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	if not okR or type(code) ~= "string" then
		warn("Не удалось создать сервер мира:", code)
		return nil
	end
	local newId: string? = nil
	retry(function()
		s:UpdateAsync("index", function(idx: any)
			idx = if type(idx) == "table" then idx else { nextId = 1, open = {} }
			idx.open = idx.open or {}
			newId = tostring(idx.nextId or 1)
			idx.nextId = (idx.nextId or 1) + 1
			idx.open[newId :: string] = 0
			return idx
		end)
		return true
	end)
	if not newId then
		return nil
	end
	local world: World = { id = newId :: string, code = code, ps = ps, members = {} }
	retry(function()
		s:SetAsync("w_" .. world.id, world)
		return true
	end)
	if type(ps) == "string" then
		retry(function()
			s:SetAsync("ps_" .. ps, world.id)
			return true
		end)
	end
	return world
end

-- Найти мир игрока или подобрать новый (со свободным местом, иначе создать)
function M.assign(userId: number, excluded: string?): World?
	local current = M.memberWorld(userId)
	if current then
		local w = M.getWorld(current)
		if w then
			return w
		end
	end
	if not store then
		return nil
	end
	local s = store :: DataStore
	-- миры со свободными местами: самые заполненные первыми, чтобы мир скорее ожил
	local ok, idx = retry(function()
		return s:GetAsync("index")
	end)
	if ok and type(idx) == "table" and type(idx.open) == "table" then
		local candidates = {}
		for id, n in idx.open do
			if id ~= excluded and type(n) == "number" and n < MAX_MEMBERS then
				table.insert(candidates, { id = id, n = n })
			end
		end
		table.sort(candidates, function(a, b)
			return a.n > b.n
		end)
		for _, c in candidates do
			local w = M.getWorld(c.id)
			if w and w.code and M.addMember(c.id, userId) then
				return w
			end
		end
	end
	local w = createWorld()
	if w and M.addMember(w.id, userId) then
		return w
	end
	return nil
end

function M.teleport(player: Player, world: World): boolean
	if not world.code then
		return false
	end
	local options = Instance.new("TeleportOptions")
	local opts: any = options
	opts.ReservedServerAccessCode = world.code
	options:SetTeleportData({ world = world.id })
	for attempt = 1, 3 do
		local ok, err = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, { player }, options)
		end)
		if ok then
			return true
		end
		warn("Телепорт в мир не удался:", err)
		task.wait(attempt * 2)
	end
	return false
end

-- Рынок мира
function M.loadMarket(id: string): { any }
	if not store then
		return {}
	end
	local s = store :: DataStore
	local ok, data = retry(function()
		return s:GetAsync("market_" .. id)
	end)
	if ok and type(data) == "table" then
		return data
	end
	return {}
end

function M.saveMarket(id: string, orders: { any })
	if not store then
		return
	end
	local s = store :: DataStore
	retry(function()
		s:SetAsync("market_" .. id, orders)
		return true
	end)
end

-- Деньги продавцу, который сейчас не на сервере
function M.addPayout(userId: number, amount: number)
	if not payouts or amount <= 0 then
		return
	end
	local p = payouts :: DataStore
	retry(function()
		p:UpdateAsync("u_" .. userId, function(old: any)
			return (if type(old) == "number" then old else 0) + amount
		end)
		return true
	end)
end

-- Забрать накопленные выплаты (атомарно обнуляет)
function M.takePayout(userId: number): number
	if not payouts then
		return 0
	end
	local p = payouts :: DataStore
	local taken = 0
	retry(function()
		p:UpdateAsync("u_" .. userId, function(old: any)
			if type(old) ~= "number" or old <= 0 then
				taken = 0
				return nil
			end
			taken = old
			return 0
		end)
		return true
	end)
	return taken
end

function M.isStudio(): boolean
	return RunService:IsStudio()
end

M.MAX_MEMBERS = MAX_MEMBERS
return M
