--!nonstrict
-- Точка входа сервера.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)
local Game = require(script.Parent.Game)
local Shop = require(script.Parent.Shop)

World.build()
Game.start()
Shop.start()

-- Действия клиента с ответом и простым лимитом частоты
local lastAct: { [Player]: number } = {}
local ACTIONS: { [string]: (Player, any) -> (boolean, string?) } = {
	launch = function(p)
		return Game.launch(p)
	end,
	upgrade = Game.upgrade,
	rebirth = function(p)
		return Game.rebirth(p)
	end,
	gift = Game.claimGift,
	daily = function(p)
		return Game.claimDaily(p)
	end,
	code = Game.redeem,
	auto = Game.setAuto,
	ftue = Game.ftue,
}

Net.fn("Act").OnServerInvoke = function(player: Player, action: any, arg: any)
	if type(action) ~= "string" then
		return false
	end
	local now = os.clock()
	if now - (lastAct[player] or 0) < 0.08 then
		return false
	end
	lastAct[player] = now
	local fn = ACTIONS[action]
	if not fn then
		return false
	end
	local ok, res, msg = pcall(fn, player, arg)
	if not ok then
		warn("[Act]", action, res)
		return false
	end
	return res, msg
end

Net.event("Land").OnServerEvent:Connect(function(player, id, z, rings)
	Game.onLand(player, id, z, rings)
end)

local function onJoin(player: Player)
	local d, why = Data.load(player)
	if not d then
		if player.Parent == Players then
			player:Kick(if why == "locked" then "Your save is open on another server. Rejoin in a minute." else "Couldn't load your save. Please rejoin.")
		end
		return
	end
	local passes = Shop.loadPasses(player)
	if player.Parent ~= Players then
		return
	end
	Game.join(player, passes)
end

Players.PlayerAdded:Connect(onJoin)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

Players.PlayerRemoving:Connect(function(player)
	Game.leave(player)
	Data.release(player)
	Data.forget(player)
	lastAct[player] = nil
end)

-- автосохранение
task.spawn(function()
	while true do
		task.wait(60)
		for _, p in Players:GetPlayers() do
			task.spawn(Data.save, p)
		end
	end
end)

game:BindToClose(function()
	local list = Players:GetPlayers()
	local left = #list
	for _, p in list do
		task.spawn(function()
			Data.release(p)
			left -= 1
		end)
	end
	local t = os.clock()
	while left > 0 and os.clock() - t < 25 do
		task.wait(0.2)
	end
end)
