--!strict
-- Оффлайн-прогресс (ТЗ 2.5): производство и доходы — 20% от онлайна, максимум 24 часа;
-- содержание и налоги — полностью. Плюс выплаты с рынка, пока игрок отсутствовал.

local Shared = game.ReplicatedStorage.Shared
local Items = require(Shared.Config.Items)
local CityCfg = require(Shared.Config.City)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Worlds = require(script.Parent.Parent.Data.Worlds)
local Profiles = require(script.Parent.Parent.Data.Profiles)

local M = {}

-- Применить и вернуть сводку для клиента (или nil, если показывать нечего)
function M.apply(player: Player, d: Profiles.Data): { [string]: any }?
	local summary: { [string]: any } = { items = {} }
	local any = false

	local payout = Worlds.takePayout(player.UserId)
	if payout > 0 then
		d.money += payout
		summary.payout = math.floor(payout)
		any = true
	end

	local away = os.time() - d.lastOnline
	if d.plot and d.city and away >= 120 then
		local t = math.min(away, CityCfg.OFFLINE_CAP)
		local hours = t / 3600
		local income = math.max(0, d.rates.income or 0) * hours * CityCfg.OFFLINE_RATE
		local costs = math.max(0, d.rates.costs or 0) * hours
		d.money = math.max(0, d.money + income - costs)
		summary.income = math.floor(income)
		summary.costs = math.floor(costs)
		for _, item in Items.list do
			local rate = d.rates["i_" .. item.id] or 0
			local delta = rate * hours * CityCfg.OFFLINE_RATE
			local whole = if delta >= 0 then math.floor(delta) else -math.floor(-delta)
			if whole > 0 then
				local fit = PlayerState.addItem(d, item.id, whole)
				if fit > 0 then
					summary.items[item.id] = fit
				end
			elseif whole < 0 then
				local have = d.items[item.id] or 0
				local take = math.min(have, -whole)
				if take > 0 then
					PlayerState.removeItem(d, item.id, take)
					summary.items[item.id] = -take
				end
			end
		end
		summary.seconds = away
		any = true
	end
	return if any then summary else nil
end

return M
