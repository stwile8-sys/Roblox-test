--!strict
-- Глобальный рынок мира (ТЗ 11.1): заявки игроков + NPC.
-- NPC продаёт втрое дороже базы, покупает за 30% базы. С продавца — комиссия 10% и налог 5%.
-- Доставка покупки — 5 минут или сразу за доплату 15%.
-- Товар продавца на время заявки лежит в заявке (снимается со склада).

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local CityCfg = require(Shared.Config.City)
local Net = require(Shared.Net)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Worlds = require(script.Parent.Parent.Data.Worlds)
local Profiles = require(script.Parent.Parent.Data.Profiles)

type Order = { id: string, s: number, n: string, i: string, q: number, p: number }

local MAX_ORDERS = 10
local MAX_QTY = 500

local M = {}

local worldId: string? = nil
local orders: { Order } = {}
local dirty = false
local marketEvent = Net.event("Market")

local function changed()
	dirty = true
	marketEvent:FireAllClients()
end

local function intQty(q: any): number?
	if type(q) ~= "number" or q ~= q or q % 1 ~= 0 or q < 1 or q > MAX_QTY then
		return nil
	end
	return q
end

local function pending(d: Profiles.Data, item: string): number
	local n = 0
	for _, e in d.incoming do
		if e[1] == item then
			n += e[2]
		end
	end
	return n
end

local function sorted(item: string): { Order }
	local list = {}
	for _, o in orders do
		if o.i == item then
			table.insert(list, o)
		end
	end
	table.sort(list, function(a, b)
		return a.p < b.p
	end)
	return list
end

local function paySeller(o: Order, amount: number)
	local net = amount * (1 - Items.MARKET_FEE - Items.SALE_TAX)
	local seller = Players:GetPlayerByUserId(o.s)
	if seller and PlayerState.isReady(seller) then
		PlayerState.addMoney(seller, net)
		PlayerState.notify(seller, "market.sold", { item = o.i, money = math.floor(net) }, "money")
	else
		task.spawn(Worlds.addPayout, o.s, net)
	end
end

function M.book(player: Player): { [string]: any }
	local items = {}
	for _, item in Items.list do
		local best, qty = nil, 0
		for _, o in orders do
			if o.i == item.id and o.s ~= player.UserId then
				qty += o.q
				if not best or o.p < best then
					best = o.p
				end
			end
		end
		items[item.id] = {
			best = best,
			qty = qty,
			npcSell = Items.npcSell(item.id),
			npcBuy = Items.npcBuy(item.id),
		}
	end
	local mine = {}
	for _, o in orders do
		if o.s == player.UserId then
			table.insert(mine, { id = o.id, i = o.i, q = o.q, p = o.p })
		end
	end
	return { items = items, mine = mine }
end

-- Сколько будет стоить покупка (сначала дешёвые заявки игроков, остаток — у NPC)
local function quote(player: Player, item: string, qty: number): (number, { { any } })
	local left = qty
	local total = 0
	local fills = {}
	local npc = Items.npcSell(item)
	for _, o in sorted(item) do
		if left <= 0 or o.p >= npc then
			break
		end
		if o.s ~= player.UserId then
			local take = math.min(left, o.q)
			total += take * o.p
			table.insert(fills, { o, take } :: { any })
			left -= take
		end
	end
	total += left * npc
	return math.ceil(total), fills
end

function M.buy(player: Player, item: any, qty: any, instant: any): (boolean, string?)
	local d = PlayerState.data(player)
	local q = intQty(qty)
	if not d or not Items.isItem(item) or not q or type(instant) ~= "boolean" then
		return false, "err.bad"
	end
	if not d.plot then
		return false, "market.need_plot"
	end
	local itemId = item :: string
	local space = CityCfg.STORAGE - (d.items[itemId] or 0) - pending(d, itemId)
	if q > space then
		return false, "market.no_space"
	end
	local total, fills = quote(player, itemId, q)
	if instant then
		total = math.ceil(total * (1 + Items.INSTANT_FEE))
	end
	if not PlayerState.spend(player, total) then
		return false, "err.money"
	end
	for _, f in fills do
		local o: Order, take: number = f[1] :: any, f[2] :: any
		o.q -= take
		paySeller(o, take * o.p)
	end
	for n = #orders, 1, -1 do
		if orders[n].q <= 0 then
			table.remove(orders, n)
		end
	end
	if instant then
		PlayerState.addItem(d, itemId, q)
	else
		table.insert(d.incoming, { itemId, q, os.time() + Items.DELIVERY_TIME } :: { any })
	end
	PlayerState.markDirty(player)
	if #fills > 0 then
		changed()
	end
	return true, if instant then "market.bought" else "market.on_way"
end

function M.sellNpc(player: Player, item: any, qty: any): (boolean, string?)
	local d = PlayerState.data(player)
	local q = intQty(qty)
	if not d or not Items.isItem(item) or not q then
		return false, "err.bad"
	end
	local itemId = item :: string
	if not PlayerState.removeItem(d, itemId, q) then
		return false, "market.not_enough"
	end
	PlayerState.addMoney(player, math.floor(q * Items.npcBuy(itemId)))
	return true, "market.sold_npc"
end

function M.order(player: Player, item: any, qty: any, price: any): (boolean, string?)
	local d = PlayerState.data(player)
	local q = intQty(qty)
	if not d or not Items.isItem(item) or not q or type(price) ~= "number" or price ~= price then
		return false, "err.bad"
	end
	local itemId = item :: string
	local p = math.floor(price * 10 + 0.5) / 10
	if p < Items.npcBuy(itemId) or p > Items.npcSell(itemId) then
		return false, "market.bad_price"
	end
	local mine = 0
	for _, o in orders do
		if o.s == player.UserId then
			mine += 1
		end
	end
	if mine >= MAX_ORDERS then
		return false, "market.too_many"
	end
	if not PlayerState.removeItem(d, itemId, q) then
		return false, "market.not_enough"
	end
	table.insert(orders, { id = Profiles.newId(), s = player.UserId, n = player.Name, i = itemId, q = q, p = p })
	PlayerState.markDirty(player)
	changed()
	return true, "market.placed"
end

function M.cancel(player: Player, id: any): (boolean, string?)
	local d = PlayerState.data(player)
	if not d or type(id) ~= "string" then
		return false, "err.bad"
	end
	for n, o in orders do
		if o.id == id and o.s == player.UserId then
			table.remove(orders, n)
			local fit = PlayerState.addItem(d, o.i, o.q)
			if fit < o.q then
				table.insert(d.incoming, { o.i, o.q - fit, os.time() } :: { any })
			end
			PlayerState.markDirty(player)
			changed()
			return true, nil
		end
	end
	return false, "err.bad"
end

-- Доставки, срок которых наступил, — на склад (если есть место)
function M.deliver(player: Player)
	local d = PlayerState.data(player)
	if not d or #d.incoming == 0 then
		return
	end
	local now = os.time()
	local left = {}
	local any = false
	for _, e in d.incoming do
		if e[3] <= now then
			local fit = PlayerState.addItem(d, e[1], e[2])
			if fit > 0 then
				any = true
			end
			if fit < e[2] then
				table.insert(left, { e[1], e[2] - fit, e[3] } :: { any })
			end
		else
			table.insert(left, e)
		end
	end
	d.incoming = left
	if any then
		PlayerState.notify(player, "market.delivered", nil, "success")
		PlayerState.markDirty(player)
	end
end

function M.start(id: string)
	worldId = id
	local raw = Worlds.loadMarket(id)
	for _, o in raw do
		if type(o) == "table" and Items.isItem(o.i) and type(o.q) == "number" and o.q > 0 and type(o.p) == "number" then
			table.insert(orders, o :: any)
		end
	end
	task.spawn(function()
		while true do
			task.wait(10)
			M.save()
			for _, p in Players:GetPlayers() do
				M.deliver(p)
			end
		end
	end)
end

function M.save()
	if dirty and worldId then
		dirty = false
		Worlds.saveMarket(worldId, orders)
	end
end

return M
