--!strict
-- «Frontier Empires». Точка входа сервера.
-- Публичный сервер — «вход»: переносит игрока в его мир. Приватный (reserved) сервер — мир:
-- строит карту, грузит города всех членов мира и принимает игроков.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Map = require(Shared.Config.Map)
local L = require(Shared.Lang.L)
local Worlds = require(script.Parent.Data.Worlds)
local Router = require(script.Parent.Router)

local isWorld = game.PrivateServerId ~= "" or RunService:IsStudio()

if not isWorld then
	Router.start()
	return
end

local Profiles = require(script.Parent.Data.Profiles)
local PlayerState = require(script.Parent.PlayerState)
local Tutorial = require(script.Parent.Tutorial)
local MapBuilder = require(script.Parent.World.MapBuilder)
local HubBuilder = require(script.Parent.World.HubBuilder)
local Jobs = require(script.Parent.Hub.Jobs)
local City = require(script.Parent.City.City)
local Market = require(script.Parent.Economy.Market)
local Offline = require(script.Parent.Economy.Offline)

ReplicatedStorage:SetAttribute("ServerMode", "world")
ReplicatedStorage:SetAttribute("WorldReady", false)

-- 1. Какой это мир
local worldId: string
local members: { [string]: boolean } = {}
if RunService:IsStudio() and game.PrivateServerId == "" then
	worldId = "studio"
elseif game.PrivateServerOwnerId ~= 0 then
	worldId = "vip_" .. game.PrivateServerId -- купленный приватный сервер — свой мир
else
	worldId = Worlds.worldOfPrivateServer(game.PrivateServerId) or ("ps_" .. game.PrivateServerId)
end
local isRealWorld = string.sub(worldId, 1, 3) ~= "ps_" and worldId ~= "studio" and string.sub(worldId, 1, 4) ~= "vip_"
if isRealWorld then
	local w = Worlds.getWorld(worldId)
	if w and type(w.members) == "table" then
		members = w.members
	end
end
ReplicatedStorage:SetAttribute("WorldId", worldId)
print("Мир", worldId)

-- 2. Карта и хаб
local rng = Random.new(20261109)
local world = MapBuilder.build(rng)
HubBuilder.build(world)

-- 3. Системы
PlayerState.start()
Jobs.start()
City.start()
Market.start(worldId)
City.loadMembers(members)
Profiles.startAutosave()

ReplicatedStorage:SetAttribute("WorldReady", true)

-- 4. Игроки
local summaries: { [Player]: { [string]: any } } = {}

local function join(player: Player)
	if isRealWorld then
		local mine = Worlds.memberWorld(player.UserId)
		if mine ~= worldId then
			if mine ~= nil or not Worlds.addMember(worldId, player.UserId) then
				-- игрок из другого мира или мир полон — отправляем по адресу
				player:SetAttribute("RouteStatus", "search")
				Router.route(player)
				return
			end
			members[tostring(player.UserId)] = true
		end
	end
	local d, why = Profiles.load(player)
	if not d then
		if why ~= "left" then
			player:Kick(if why == "locked" then "Ваши данные ещё открыты на другом сервере. Перезайдите через минуту." else "Сохранения сейчас недоступны. Попробуйте позже.")
		end
		return
	end
	d.world = worldId
	local summary = Offline.apply(player, d)
	if summary then
		summaries[player] = summary
	end
	City.onJoin(player, d)
	PlayerState.setReady(player, true)
	Tutorial.check(player)
	Market.deliver(player)
	player.CharacterAdded:Connect(function()
		Jobs.onCharacter(player)
	end)
end

local function leave(player: Player)
	summaries[player] = nil
	City.onLeave(player)
	Jobs.cancel(player)
	if Profiles.get(player) then
		Profiles.release(player)
	end
	PlayerState.forget(player)
	Profiles.forget(player)
end

Players.PlayerAdded:Connect(join)
Players.PlayerRemoving:Connect(leave)
for _, p in Players:GetPlayers() do
	task.spawn(join, p)
end

game:BindToClose(function()
	Market.save()
	Profiles.releaseAll()
end)

-- 5. Действия игроков: единая точка входа с ограничением частоты
local BUCKET_MAX = 20
local BUCKET_RATE = 8 -- действий в секунду в среднем
local buckets: { [Player]: { n: number, t: number } } = {}

local function allow(player: Player): boolean
	local now = os.clock()
	local b = buckets[player]
	if not b then
		b = { n = BUCKET_MAX, t = now }
		buckets[player] = b
	end
	b.n = math.min(BUCKET_MAX, b.n + (now - b.t) * BUCKET_RATE)
	b.t = now
	if b.n < 1 then
		return false
	end
	b.n -= 1
	return true
end

Players.PlayerRemoving:Connect(function(p)
	buckets[p] = nil
end)

local function plotSpawn(player: Player): (boolean, string?)
	local d = PlayerState.data(player)
	local ch = player.Character
	if not d or not d.plot or not ch then
		return false, "err.bad"
	end
	local p = Map.plots[d.plot]
	local center = Map.tileCenter(p.c, p.r)
	ch:PivotTo(CFrame.new(center + Vector3.new(0, 5, 0)))
	return true, nil
end

local function hubSpawn(player: Player): (boolean, string?)
	local ch = player.Character
	if not ch then
		return false, "err.bad"
	end
	ch:PivotTo(CFrame.new(0, 5, 30))
	return true, nil
end

local handlers: { [string]: (Player, ...any) -> (boolean, any) } = {
	hello = function(player)
		if not PlayerState.isReady(player) then
			return false, "err.loading"
		end
		PlayerState.markDirty(player)
		local s = summaries[player]
		summaries[player] = nil
		return true, s
	end,
	takeJob = Jobs.take,
	cancelJob = Jobs.cancel,
	buyPlot = City.buyPlot,
	road = City.road,
	zone = City.zone,
	bulldoze = City.bulldoze,
	special = City.special,
	marketBook = function(player)
		return true, Market.book(player)
	end,
	buy = Market.buy,
	sellNpc = Market.sellNpc,
	order = Market.order,
	cancelOrder = Market.cancel,
	setPref = function(player, key, value)
		local d = PlayerState.data(player)
		if not d or type(key) ~= "string" or type(value) ~= "string" then
			return false, "err.bad"
		end
		local okValue = (key == "lang" and L.isLang(value)) or (key == "gfx" and (value == "auto" or value == "low" or value == "high"))
		if not okValue then
			return false, "err.bad"
		end
		d.prefs[key] = value
		return true, nil
	end,
	goPlot = plotSpawn,
	goHub = hubSpawn,
}

Net.fn("Act").OnServerInvoke = function(player: Player, action: any, ...: any)
	if type(action) ~= "string" then
		return false, "err.bad"
	end
	local h = handlers[action]
	if not h then
		return false, "err.bad"
	end
	if action ~= "hello" and not PlayerState.isReady(player) then
		return false, "err.loading"
	end
	if not allow(player) then
		return false, "err.slow"
	end
	local ok, a, b = pcall(h, player, ...)
	if not ok then
		warn("Ошибка действия", action, a)
		return false, "err.bad"
	end
	return a, b
end
