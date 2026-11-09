--!strict
-- Города на участках: покупка участка, застройка (дороги, зоны, особые здания),
-- симуляция жителей и производства. Единственный владелец данных города —
-- этот модуль (данные лежат в профиле игрока, город оффлайн-игрока — копия только для показа).

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local Biomes = require(Shared.Config.Biomes)
local CityCfg = require(Shared.Config.City)
local Items = require(Shared.Config.Items)
local Rules = require(Shared.CityRules)
local Relief = require(Shared.Relief)
local Profiles = require(script.Parent.Parent.Data.Profiles)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Tutorial = require(script.Parent.Parent.Tutorial)
local Render = require(script.Parent.Render)

type Stats = {
	pop: number,
	capacity: number,
	jobsC: number,
	jobsI: number,
	workers: number,
	employment: number,
	demand: { R: number, C: number, I: number },
	food: boolean,
	income: number, -- монет в час
	costs: number,
	roads: number,
}

type CityState = {
	index: number,
	owner: number,
	ownerName: string,
	data: Profiles.City,
	player: Player?,
	stats: Stats,
	rates: { [string]: number },
	version: number,
}

local M = {}

local cities: { [number]: CityState } = {}
local byPlayer: { [Player]: CityState } = {}
local sentVersion: { [Player]: number } = {}

-- Где на участке строить нельзя (вода, круто) — считается один раз на участок
local buildableCache: { [number]: { [number]: boolean } } = {}
local function buildableOf(index: number): (number) -> boolean
	local cache = buildableCache[index]
	if not cache then
		local fresh: { [number]: boolean } = {}
		for j = 0, Map.CELLS - 1 do
			for i = 0, Map.CELLS - 1 do
				fresh[Map.key(i, j)] = Relief.buildable(index, i, j)
			end
		end
		buildableCache[index] = fresh
		cache = fresh
	end
	local c = cache :: { [number]: boolean }
	return function(k: number): boolean
		return c[k] == true
	end
end

local function emptyStats(): Stats
	return {
		pop = 0,
		capacity = 0,
		jobsC = 0,
		jobsI = 0,
		workers = 0,
		employment = 0,
		demand = { R = 0.5, C = 0, I = 0 },
		food = true,
		income = 0,
		costs = 0,
		roads = 0,
	}
end

local function plotModel(index: number): Model?
	local w = workspace:FindFirstChild("World")
	local plots = w and w:FindFirstChild("Plots")
	local m = plots and plots:FindFirstChild("Plot_" .. index)
	return if m and m:IsA("Model") then m else nil
end

local function setOwnerAttrs(index: number, owner: number, name: string)
	local m = plotModel(index)
	if m then
		m:SetAttribute("Owner", owner)
		m:SetAttribute("OwnerName", name)
	end
end

local function register(index: number, owner: number, name: string, data: Profiles.City, player: Player?): CityState
	local c: CityState = {
		index = index,
		owner = owner,
		ownerName = name,
		data = data,
		player = player,
		stats = emptyStats(),
		rates = {},
		version = 1,
	}
	cities[index] = c
	if player then
		byPlayer[player] = c
	end
	setOwnerAttrs(index, owner, name)
	Render.clearDecor(index)
	Render.sync(index, data)
	return c
end

function M.ownerOf(index: number): number?
	local c = cities[index]
	return if c then c.owner else nil
end

-- Загрузить города всех членов мира (оффлайн, только для показа)
function M.loadMembers(members: { [string]: boolean })
	for idStr in members do
		local userId = tonumber(idStr)
		if userId then
			local d = Profiles.peek(userId)
			if d and d.plot and d.city and not cities[d.plot] then
				local okName, name = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				register(d.plot, userId, if okName and type(name) == "string" then name else "?", d.city, nil)
			end
		end
	end
end

function M.onJoin(player: Player, d: Profiles.Data)
	if not d.plot then
		return
	end
	local existing = cities[d.plot]
	if existing and existing.owner ~= player.UserId then
		-- участок занят другим (не должно случаться): возвращаем деньги
		warn("Участок", d.plot, "уже занят, игрок", player.UserId)
		d.plot = nil
		d.city = nil
		d.money += Map.PLOT_PRICE
		return
	end
	if not d.city then
		d.city = Profiles.newCity(d.plot)
	end
	local c = register(d.plot, player.UserId, player.Name, d.city :: Profiles.City, player)
	c.rates = d.rates
end

function M.onLeave(player: Player)
	local c = byPlayer[player]
	if c then
		c.player = nil
		byPlayer[player] = nil
	end
	sentVersion[player] = nil
end

function M.cityOf(player: Player): CityState?
	return byPlayer[player]
end

-- Номер клетки от клиента: целое 1..N²
local function cellKey(k: any): number?
	if type(k) ~= "number" or k ~= k or k % 1 ~= 0 or k < 1 or k > Map.CELLS * Map.CELLS then
		return nil
	end
	return k
end

local function owned(player: Player): (CityState?, Profiles.Data?)
	local c = byPlayer[player]
	local d = PlayerState.data(player)
	if not c or not d or d.plot ~= c.index then
		return nil, nil
	end
	return c, d
end

local function commit(c: CityState, grid: { string })
	c.data.grid = Rules.toString(grid)
	c.version += 1
	Render.sync(c.index, c.data)
	if c.player then
		PlayerState.markDirty(c.player)
	end
end

-- Убрать дома, чьи клетки больше не в своей зоне
local function dropInvalidGrown(c: CityState, grid: { string })
	local keep = {}
	for _, g in c.data.grown do
		local i, j = Map.unkey(g[1])
		local ok = true
		for di = 0, g[3] - 1 do
			for dj = 0, g[3] - 1 do
				if not Map.inside(i + di, j + dj) or grid[Map.key(i + di, j + dj)] ~= g[2] then
					ok = false
				end
			end
		end
		if ok then
			table.insert(keep, g)
		end
	end
	c.data.grown = keep
end

-- Действия игрока ---------------------------------------------------------

function M.buyPlot(player: Player, index: any): (boolean, string?)
	local d = PlayerState.data(player)
	if not d then
		return false, "err.bad"
	end
	if type(index) ~= "number" or not Map.plots[index] then
		return false, "err.bad"
	end
	if d.plot then
		return false, "plot.have"
	end
	if cities[index] then
		return false, "plot.taken"
	end
	if not PlayerState.spend(player, Map.PLOT_PRICE) then
		return false, "err.money"
	end
	d.plot = index
	d.city = Profiles.newCity(index)
	PlayerState.addItem(d, "wood", 20)
	PlayerState.addItem(d, "bread", 10)
	d.vehicles.cart = (d.vehicles.cart or 0) + 1
	local c = register(index, player.UserId, player.Name, d.city :: Profiles.City, player)
	c.rates = d.rates
	PlayerState.markDirty(player)
	PlayerState.notify(player, "plot.bought", { n = index }, "success")
	Tutorial.check(player)
	task.spawn(Profiles.save, player)
	return true, nil
end

function M.road(player: Player, fromKey: any, toKey: any): (boolean, string?)
	local c, d = owned(player)
	local a, b = cellKey(fromKey), cellKey(toKey)
	if not c or not d or not a or not b then
		return false, "err.bad"
	end
	local cells = Rules.lineCells(a, b)
	if #cells > Rules.MAX_LINE then
		return false, "build.too_big"
	end
	local grid = Rules.toArray(c.data.grid)
	local occ = Rules.occupancy(c.data)
	local can = buildableOf(c.index)
	local placed = 0
	local blocked = false
	for _, k in cells do
		if Rules.canRoad(grid, occ, k, can) then
			if not PlayerState.spend(player, CityCfg.ROAD_COST) then
				blocked = true
				break
			end
			grid[k] = "#"
			placed += 1
		end
	end
	if placed == 0 then
		return false, if blocked then "err.money" else "build.cant"
	end
	dropInvalidGrown(c, grid)
	commit(c, grid)
	return true, nil
end

function M.zone(player: Player, zone: any, fromKey: any, toKey: any): (boolean, string?)
	local c, d = owned(player)
	local a, b = cellKey(fromKey), cellKey(toKey)
	if not c or not d or not a or not b or (zone ~= "R" and zone ~= "C" and zone ~= "I") then
		return false, "err.bad"
	end
	local w, h = Rules.rectSize(a, b)
	if w > Rules.MAX_RECT or h > Rules.MAX_RECT then
		return false, "build.too_big"
	end
	local grid = Rules.toArray(c.data.grid)
	local occ = Rules.occupancy(c.data)
	local near = Rules.distance(Rules.allRoads(grid), CityCfg.ZONE_REACH)
	local can = buildableOf(c.index)
	local cost = CityCfg.ZONE_COST[zone]
	local placed = 0
	local blocked = false
	for _, k in Rules.rectCells(a, b) do
		if grid[k] ~= zone and Rules.canZone(grid, occ, near, k, can) then
			if not PlayerState.spend(player, cost) then
				blocked = true
				break
			end
			grid[k] = zone
			placed += 1
		end
	end
	if placed == 0 then
		return false, if blocked then "err.money" else "build.zone_far"
	end
	dropInvalidGrown(c, grid)
	commit(c, grid)
	return true, nil
end

function M.bulldoze(player: Player, fromKey: any, toKey: any): (boolean, string?)
	local c, d = owned(player)
	local a, b = cellKey(fromKey), cellKey(toKey)
	if not c or not d or not a or not b then
		return false, "err.bad"
	end
	local w, h = Rules.rectSize(a, b)
	if w > Rules.MAX_RECT or h > Rules.MAX_RECT then
		return false, "build.too_big"
	end
	local grid = Rules.toArray(c.data.grid)
	local occ = Rules.occupancy(c.data)
	local removeG, removeS = {}, {}
	local refund = 0
	local starter = {}
	for _, k in Map.starterRoad(c.index) do
		starter[k] = true
	end
	for _, k in Rules.rectCells(a, b) do
		local o = occ[k]
		if o then
			local n = tonumber(string.sub(o, 2)) :: number
			if string.sub(o, 1, 1) == "G" then
				removeG[n] = true
			else
				removeS[n] = true
			end
		end
		if grid[k] == "#" then
			if not starter[k] then
				grid[k] = "."
				refund += CityCfg.ROAD_COST * CityCfg.ROAD_REFUND
			end
		elseif grid[k] ~= "." then
			grid[k] = "."
		end
	end
	local grown = {}
	for n, g in c.data.grown do
		if not removeG[n] then
			table.insert(grown, g)
		end
	end
	c.data.grown = grown
	local special = {}
	for n, sp in c.data.special do
		if not removeS[n] then
			table.insert(special, sp)
		end
	end
	c.data.special = special
	if refund > 0 then
		PlayerState.addMoney(player, refund)
	end
	dropInvalidGrown(c, grid)
	commit(c, grid)
	return true, nil
end

function M.special(player: Player, id: any, key: any): (boolean, string?)
	local c, d = owned(player)
	if not c or not d or type(id) ~= "string" or not CityCfg.SPECIAL[id] then
		return false, "err.bad"
	end
	if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > Map.CELLS * Map.CELLS then
		return false, "err.bad"
	end
	local def = CityCfg.SPECIAL[id]
	local res = Map.plotResources(c.index, Biomes.byId)
	if not res[def.needs] then
		return false, "build.no_resource"
	end
	if #c.data.special >= CityCfg.MAX_SPECIAL then
		return false, "build.limit"
	end
	local same = 0
	for _, s in c.data.special do
		if s[1] == id then
			same += 1
		end
	end
	local cost = CityCfg.specialCost(id, same)
	local grid = Rules.toArray(c.data.grid)
	local occ = Rules.occupancy(c.data)
	local i, j = Map.unkey(key)
	local ok, why = Rules.canPlaceSpecial(grid, occ, Rules.allRoads(grid), id, i, j, buildableOf(c.index))
	if not ok then
		return false, why
	end
	if not PlayerState.spend(player, cost) then
		return false, "err.money"
	end
	for di = 0, def.w - 1 do
		for dj = 0, def.h - 1 do
			grid[Map.key(i + di, j + dj)] = "."
		end
	end
	table.insert(c.data.special, { id, key } :: { any })
	c.data.spent += cost
	c.version += 1
	dropInvalidGrown(c, grid)
	commit(c, grid)
	Tutorial.check(player)
	return true, nil
end

-- Симуляция ---------------------------------------------------------------

local rng = Random.new()

local function frac(d: Profiles.Data, name: string, add: number): number
	-- накопить дробную часть и вернуть целое к выдаче
	local v = (d.frac[name] or 0) + add
	local whole = math.floor(v)
	d.frac[name] = v - whole
	return whole
end

local function ema(rates: { [string]: number }, key: string, value: number)
	local old = rates[key]
	rates[key] = if old == nil then value else old + (value - old) * 0.15
end

local function tick(c: CityState, d: Profiles.Data, dt: number)
	local data = c.data
	local grid = Rules.toArray(data.grid)
	local connected = Rules.connected(grid)
	local reach = Rules.distance(connected, CityCfg.ZONE_REACH)

	-- дома без доступа к дороге пустеют и сносятся
	local keep = {}
	for _, g in data.grown do
		local i, j = Map.unkey(g[1])
		local reached = false
		for di = 0, g[3] - 1 do
			for dj = 0, g[3] - 1 do
				local r = reach[Map.key(i + di, j + dj)]
				if r and r <= CityCfg.ZONE_REACH then
					reached = true
				end
			end
		end
		if reached then
			table.insert(keep, g)
		end
	end
	local changed = #keep ~= #data.grown
	data.grown = keep

	-- население и рабочие места
	local pop, capacity, jobsC, jobsI = 0, 0, 0, 0
	for _, g in data.grown do
		local def = CityCfg.GROWN[g[2]][g[3]]
		if g[2] == "R" then
			pop += g[4] or 0
			capacity += def.residents
		elseif g[2] == "C" then
			jobsC += def.jobs
		else
			jobsI += def.jobs
		end
	end
	local jobs = jobsC + jobsI
	local workers = math.floor(pop * CityCfg.WORKER_SHARE)
	local employment = if jobs > 0 then math.min(1, workers / jobs) else 0

	local income, costs = 0, 0
	local itemDelta: { [string]: number } = {}
	local function addDelta(item: string, n: number)
		itemDelta[item] = (itemDelta[item] or 0) + n
	end

	-- еда: сначала хлеб, потом зерно
	local need = frac(d, "food", pop * CityCfg.FOOD_PER_RESIDENT * dt)
	local fed = true
	if need > 0 then
		local left = need
		for _, item in { "bread", "grain" } do
			local value = Items.byId[item].food or 1
			local have = d.items[item] or 0
			local take = math.min(have, math.ceil(left / value))
			if take > 0 then
				PlayerState.removeItem(d, item, take)
				addDelta(item, -take)
				left -= take * value
			end
			if left <= 0 then
				break
			end
		end
		fed = left <= 0
	end

	-- налоги с жителей
	local tax = pop * CityCfg.TAX_PER_RESIDENT * dt * (if fed then 1 else 0.5)
	income += tax

	-- промзона: сырьё → товары
	local goodsWanted = jobsI * employment * CityCfg.IND_GOODS_PER_JOB * dt
	local goodsMade = frac(d, "goods", goodsWanted)
	if goodsMade > 0 then
		local rawNeed = math.ceil(goodsMade * CityCfg.IND_RAW_PER_GOODS)
		-- берём сырьё, которого больше всего
		local best, bestHave = nil, 0
		for _, item in Items.raw do
			local have = d.items[item] or 0
			if have > bestHave then
				best, bestHave = item, have
			end
		end
		if best and bestHave >= rawNeed then
			local fit = math.min(goodsMade, CityCfg.STORAGE - (d.items.goods or 0))
			if fit > 0 then
				PlayerState.removeItem(d, best, math.ceil(fit * CityCfg.IND_RAW_PER_GOODS))
				addDelta(best, -math.ceil(fit * CityCfg.IND_RAW_PER_GOODS))
				PlayerState.addItem(d, "goods", fit)
				addDelta("goods", fit)
			end
		end
	end

	-- магазины продают товары жителям
	local salesCap = math.min(jobsC * employment * CityCfg.COM_SALES_PER_JOB * dt, pop * CityCfg.FOOD_PER_RESIDENT * dt * 1.5)
	local sales = math.min(d.items.goods or 0, frac(d, "sales", salesCap))
	if sales > 0 then
		PlayerState.removeItem(d, "goods", sales)
		addDelta("goods", -sales)
		income += sales * Items.byId.goods.base * CityCfg.COM_MARGIN
	end

	-- особые здания (работают, если касаются подключённой дороги)
	for n, s in data.special do
		local def = CityCfg.SPECIAL[s[1]]
		if def then
			local i, j = Map.unkey(s[2])
			if Rules.touchesRoad(connected, i, j, def.w, def.h) then
				local made = frac(d, "s" .. n .. def.output, dt / def.period)
				if made > 0 then
					local fit = PlayerState.addItem(d, def.output, made)
					addDelta(def.output, fit)
				end
			end
		end
	end

	-- содержание дорог и налог на землю
	local roads = 0
	for _, ch in grid do
		if ch == "#" then
			roads += 1
		end
	end
	costs += roads * CityCfg.ROAD_UPKEEP * dt
	costs += CityCfg.cityValue(roads, data.spent) * CityCfg.LAND_TAX_WEEK / (7 * 86400) * dt

	d.money = math.max(0, d.money + income - costs)

	-- спрос (как в Cities: Skylines)
	local demandR = math.clamp(((jobs / CityCfg.WORKER_SHARE) - pop + 12) / math.max(20, pop), -1, 1)
	if not fed then
		demandR -= 0.6
	end
	local wantC = pop * 0.07
	local demandC = math.clamp((wantC - jobsC + 1) / math.max(4, wantC), -1, 1)
	local wantI = jobsC * 1.3 + 2
	local demandI = math.clamp((wantI - jobsI) / math.max(4, wantI), -1, 1)
	local demand = { R = demandR, C = demandC, I = demandI }

	-- рост домов в зонах
	local occ = Rules.occupancy(data)
	local free: { [string]: { number } } = { R = {}, C = {}, I = {} }
	for k, ch in grid do
		if (ch == "R" or ch == "C" or ch == "I") and not occ[k] then
			local r = reach[k]
			if r and r <= CityCfg.ZONE_REACH then
				table.insert(free[ch], k)
			end
		end
	end
	for _, z in { "R", "C", "I" } do
		local dz = demand[z]
		local list = free[z]
		if dz > 0.05 and #list > 0 then
			local tries = math.min(3, 1 + math.floor(dz * 2))
			for _ = 1, tries do
				if #list == 0 then
					break
				end
				local pick = table.remove(list, rng:NextInteger(1, #list)) :: number
				local i, j = Map.unkey(pick)
				local size = 1
				if pop > 30 and rng:NextNumber() < 0.35 and Map.inside(i + 1, j + 1) then
					local okBig = true
					for _, kk in { Map.key(i + 1, j), Map.key(i, j + 1), Map.key(i + 1, j + 1) } do
						if grid[kk] ~= z or occ[kk] then
							okBig = false
						end
					end
					if okBig then
						size = 2
					end
				end
				table.insert(data.grown, { pick, z, size, 0 } :: { any })
				for di = 0, size - 1 do
					for dj = 0, size - 1 do
						occ[Map.key(i + di, j + dj)] = "new"
					end
				end
				changed = true
			end
		elseif dz < -0.7 and rng:NextNumber() < 0.15 then
			-- сильный перекос — один дом этой зоны пустеет и сносится
			for n = #data.grown, 1, -1 do
				if data.grown[n][2] == z then
					table.remove(data.grown, n)
					changed = true
					break
				end
			end
		end
	end

	-- жители заселяются или уезжают
	for _, g in data.grown do
		if g[2] == "R" then
			local cap = CityCfg.GROWN.R[g[3]].residents
			local occN = g[4] or 0
			if fed and demandR > -0.3 and occN < cap then
				g[4] = math.min(cap, occN + g[3])
			elseif not fed and occN > 0 and rng:NextNumber() < 0.3 then
				g[4] = occN - 1
			end
		end
	end

	-- статистика и скорость в час (для оффлайна и интерфейса)
	local perHour = 3600 / dt
	ema(c.rates, "income", income * perHour)
	ema(c.rates, "costs", costs * perHour)
	for _, item in Items.list do
		ema(c.rates, "i_" .. item.id, (itemDelta[item.id] or 0) * perHour)
	end
	c.stats = {
		pop = pop,
		capacity = capacity,
		jobsC = jobsC,
		jobsI = jobsI,
		workers = workers,
		employment = employment,
		demand = demand,
		food = fed,
		income = c.rates.income or 0,
		costs = c.rates.costs or 0,
		roads = roads,
	}
	if changed then
		c.version += 1
		Render.sync(c.index, data)
	end
	PlayerState.markDirty(c.player :: Player)
end

-- Сетка для клиента: дома и особые здания отмечены, «нельзя строить» — "x"
function M.encode(c: CityState): string
	local grid = Rules.toArray(c.data.grid)
	local occ = Rules.occupancy(c.data)
	local can = buildableOf(c.index)
	for k, ch in grid do
		local o = occ[k]
		if o then
			if string.sub(o, 1, 1) == "S" then
				grid[k] = "S"
			else
				grid[k] = string.lower(ch)
			end
		elseif ch == "." and not can(k) then
			grid[k] = "x"
		end
	end
	return table.concat(grid)
end

-- После того как дальний ландшафт догенерировался — заново выровнять землю под городами
function M.reflattenAll()
	for index, c in cities do
		Render.resetFlat(index)
		Render.sync(index, c.data)
	end
end

function M.forgetPlayer(player: Player)
	sentVersion[player] = nil
end

function M.start()
	task.spawn(function()
		while true do
			task.wait(CityCfg.TICK)
			for player, c in byPlayer do
				local d = PlayerState.data(player)
				if d and d.city == c.data then
					local ok, err = pcall(function()
						tick(c, d, CityCfg.TICK)
					end)
					if not ok then
						warn("Ошибка симуляции города", c.index, err)
					end
				end
			end
		end
	end)

	PlayerState.addExtra(function(player, s)
		local c = byPlayer[player]
		if c then
			local city: { [string]: any } = {
				special = c.data.special,
				stats = c.stats,
				v = c.version,
			}
			if sentVersion[player] ~= c.version then
				sentVersion[player] = c.version
				city.grid = M.encode(c)
			end
			s.city = city
		end
		local owners = {}
		for index, other in cities do
			owners[tostring(index)] = other.ownerName
		end
		s.owners = owners
	end)
end

return M
