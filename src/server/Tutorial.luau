--!strict
-- Туториал из 5 шагов (ТЗ 3.1.2). Шаги двигаются только по событиям сервера.
--   1 взять задание · 2 выполнить его · 3 накопить на участок и первую постройку
--   4 купить участок · 5 поставить первое особое здание → бейдж «Основатель»

local Shared = game.ReplicatedStorage.Shared
local Map = require(Shared.Config.Map)
local PlayerState = require(script.Parent.PlayerState)

local GOAL = Map.PLOT_PRICE + 100

local M = {}
M.GOAL = GOAL
M.DONE = 6

local function set(player: Player, step: number)
	local d = PlayerState.data(player)
	if not d or d.tutorial >= step then
		return
	end
	d.tutorial = step
	PlayerState.markDirty(player)
	if step == M.DONE then
		d.badges.founder = true
		PlayerState.notify(player, "badge.founder", nil, "badge")
	end
end

-- Проверить шаги, которые зависят от состояния (деньги, участок)
function M.check(player: Player)
	local d = PlayerState.data(player)
	if not d then
		return
	end
	if d.tutorial == 3 and (d.money >= GOAL or d.plot ~= nil) then
		set(player, 4)
	end
	if d.tutorial == 4 and d.plot ~= nil then
		set(player, 5)
	end
	if d.tutorial == 5 and d.city and #d.city.special > 0 then
		set(player, M.DONE)
	end
end

function M.event(player: Player, name: string)
	local d = PlayerState.data(player)
	if not d then
		return
	end
	if name == "jobTaken" and d.tutorial == 1 then
		set(player, 2)
	elseif name == "jobDone" and d.tutorial <= 2 then
		set(player, 3)
	end
	M.check(player)
end

return M
