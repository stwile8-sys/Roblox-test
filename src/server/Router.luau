--!strict
-- Обычный (публичный) сервер — это только «вход»: он находит мир игрока и переносит его туда.
-- Карту здесь не строим, клиент показывает экран подключения.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Worlds = require(script.Parent.Data.Worlds)

local M = {}

local function route(player: Player)
	player:SetAttribute("RouteStatus", "search")
	local world = Worlds.assign(player.UserId)
	if player.Parent ~= Players then
		return
	end
	if not world then
		player:SetAttribute("RouteStatus", "error")
		return
	end
	player:SetAttribute("RouteStatus", "teleport")
	if not Worlds.teleport(player, world) then
		player:SetAttribute("RouteStatus", "error")
	end
end

function M.start()
	ReplicatedStorage:SetAttribute("ServerMode", "router")
	Players.CharacterAutoLoads = false
	Players.PlayerAdded:Connect(function(player)
		route(player)
	end)
	for _, p in Players:GetPlayers() do
		task.spawn(route, p)
	end
end

-- Отправить игрока в его мир из любого сервера (используется миром для «чужих» игроков)
M.route = route
return M
