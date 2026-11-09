--!strict
-- Предметы, которые реально есть в игре (у каждого есть источник, применение и сток).
-- Цены — базовые, в монетах (c). Ориентир — реальное соотношение: еда и дерево дешёвые,
-- готовые товары дороже сырья, из которого сделаны.

export type Item = {
	id: string,
	base: number, -- базовая цена
	food: number?, -- сытость одной единицы для жителей (если это еда)
	color: Color3, -- цвет значка
	order: number,
}

local Items: { [string]: Item } = {
	wood = { id = "wood", base = 4, color = Color3.fromRGB(150, 105, 60), order = 1 },
	stone = { id = "stone", base = 5, color = Color3.fromRGB(150, 150, 155), order = 2 },
	grain = { id = "grain", base = 3, food = 1, color = Color3.fromRGB(230, 195, 90), order = 3 },
	bread = { id = "bread", base = 9, food = 3, color = Color3.fromRGB(200, 140, 70), order = 4 },
	goods = { id = "goods", base = 14, color = Color3.fromRGB(90, 140, 210), order = 5 },
}

local list: { Item } = {}
for _, item in Items do
	table.insert(list, item)
end
table.sort(list, function(a, b)
	return a.order < b.order
end)

local M = {}
M.byId = Items
M.list = list

-- Сырьё, из которого промзона делает товары
M.raw = { "wood", "stone", "grain" }

-- Рынок: NPC продаёт втрое дороже базы, покупает за 30% базы
M.NPC_SELL_MULT = 3
M.NPC_BUY_MULT = 0.3
M.MARKET_FEE = 0.10 -- комиссия рынка с продавца
M.SALE_TAX = 0.05 -- налог на продажу с продавца
M.INSTANT_FEE = 0.15 -- доплата за мгновенную доставку
M.DELIVERY_TIME = 300 -- обычная доставка, секунд

function M.isItem(id: any): boolean
	return type(id) == "string" and Items[id] ~= nil
end

function M.npcSell(id: string): number
	return math.ceil(Items[id].base * M.NPC_SELL_MULT)
end

function M.npcBuy(id: string): number
	return math.max(1, math.floor(Items[id].base * M.NPC_BUY_MULT * 10 + 0.5) / 10)
end

return M
