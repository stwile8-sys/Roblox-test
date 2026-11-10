--!nonstrict
-- Точка входа сервера Chrono Heist Tycoon: мир, системы, вход/выход игроков, состояние для клиента, сеть.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Game = require(Shared.Config.Game)
local Defs = require(Shared.Art.Defs)

local Island = require(script.Parent.World.Island)
local Profiles = require(script.Parent.Data.Profiles)
local G = script.Parent.Game
local Ctx = require(G.Ctx)
local Bases = require(G.Bases)
local Economy = require(G.Economy)
local Raid = require(G.Raid)
local Progress = require(G.Progress)
local Shop = require(G.Shop)
local Social = require(G.Social)
local Seasons = require(G.Seasons)
local Anticheat = require(G.Anticheat)
local Analytics = require(G.Analytics)
local Bots = require(G.Bots)
local Tutorial = require(G.Tutorial)
local OfflineBases = require(G.OfflineBases)

local _ = Analytics
local api = Ctx.api

ReplicatedStorage:SetAttribute("Ready", false)

-- ── Мир и системы ───────────────────────────────────────────
local okWorld, errWorld = pcall(Island.build)
if not okWorld then
	warn("[Main] остров:", errWorld)
end
Bases.init()
-- 3D-модели: переодеть мир, когда загрузятся (ловушки перерисовать моделями)
local Dress = require(script.Parent.World.Dress)
Dress.onReady = function()
	for _, B in Ctx.bases do
		Bases.renderTraps(B)
	end
end
Dress.start()
Economy.init()
Raid.init()
Seasons.init()
Anticheat.init()
Bots.init()
Social.init()
OfflineBases.init()
Profiles.startAutosave()

-- ── Виды состояния для клиента ──────────────────────────────
local V = Ctx.views
V.cash = function(S)
	return S.data.cash
end
V.shards = function(S)
	return S.data.shards
end
V.tokens = function(S)
	return S.data.tokens
end
V.energy = function(S)
	return { n = S.data.energy, t = S.data.energyT, max = Game.ENERGY_MAX }
end
V.pending = function(S)
	return math.floor(S.data.pending)
end
V.income = function(S)
	return { now = api.income(S), mult = api.mult(S) }
end
V.slots = function(S)
	local out = {}
	for k, a in S.data.slots do
		out[k] = { id = a.id, lvl = a.lvl, away = S.B and S.B.transit[tonumber(k)] ~= nil }
	end
	return { list = out, count = if S.B then Bases.slotCount(S.B) else Game.PEDESTALS }
end
V.inv = function(S)
	return S.data.inv
end
V.wall = function(S)
	return { lvl = S.data.wall, build = S.data.wallBuild }
end
V.traps = function(S)
	return { list = S.data.traps, skin = S.data.trapSkin }
end
V.tool = function(S)
	return S.data.tool
end
V.toolCd = function(S)
	return math.max(0, (S.toolCdUntil or 0) - os.clock())
end
V.coll = function(S)
	return S.data.coll
end
V.skins = function(S)
	return S.data.skins
end
V.skin = function(S)
	return S.data.skin
end
V.stats = function(S)
	return S.data.stats
end
V.titan = function(S)
	return S.data.titan
end
V.quests = function(S)
	return S.data.quests
end
V.streak = function(S)
	return S.data.streak
end
V.ach = function(S)
	return S.data.ach
end
V.pass = function(S)
	return S.data.pass
end
V.once = function(S)
	return S.data.once
end
V.boost = function(S)
	return S.data.boostUntil
end
V.rebirths = function(S)
	local n = S.data.rebirths
	local can, why = api.canRebirth(S)
	return { n = n, req = if n < Game.REBIRTH_MAX then Game.rebirthReq(n + 1) else nil, can = can, why = why }
end
V.lock = function(S)
	local B = S.B
	return {
		untilT = B and B.shieldUntil or 0,
		cdUntil = S.lockCdUntil or 0,
		secs = B and Bases.lockSeconds(B) or Game.LOCK_BASE,
	}
end
V.raid = function(S)
	return S.raid and { base = S.raid.base } or nil
end
V.carry = function(S)
	return S.carry and { id = S.carry.id, t0 = S.carry.t0 } or nil
end
V.passes = function(S)
	return S.passes
end
V.base = function(S)
	return S.base
end
V.ftue = function(S)
	return S.data.ftue
end
V.tester = function(S)
	return Shop.isOwnerTester(S.player)
end

-- быстрый пересчёт стоимости ребёрса при изменении денег — раз в 2 сек
task.spawn(function()
	while true do
		task.wait(2)
		for _, S in Ctx.sessions do
			if S.ready then
				Ctx.mark(S, "rebirths")
			end
		end
	end
end)

-- ── Сеть ────────────────────────────────────────────────────
local act = Net.fn("Act")
act.OnServerInvoke = function(player, name, args)
	local S = Ctx.session(player)
	if not S or not S.ready then
		return false, "msg.loading"
	end
	if type(name) ~= "string" or #name > 32 then
		return false, "msg.bad"
	end
	if not Ctx.rate(S, "act", 12) then
		return false, "msg.slow"
	end
	local fn = Ctx.actions[name]
	if not fn then
		return false, "msg.bad"
	end
	if type(args) ~= "table" then
		args = {}
	end
	local ok, a, b, c = pcall(fn, S, args)
	if not ok then
		warn("[Act]", name, a)
		return false, "msg.error"
	end
	return a, b, c
end

Net.event("Do").OnServerEvent:Connect(function(player, name, args)
	local S = Ctx.session(player)
	if not S or not S.ready or type(name) ~= "string" then
		return
	end
	if not Ctx.rate(S, "do", 20) then
		return
	end
	local fn = Ctx.doActions[name]
	if fn then
		local ok, err = pcall(fn, S, args)
		if not ok then
			warn("[Do]", name, err)
		end
	end
end)

-- ── Вход ────────────────────────────────────────────────────
local function offlineIncome(S: any)
	local d = S.data
	local away = math.clamp(os.time() - d.lastOnline, 0, Game.OFFLINE_MAX_H * 3600)
	if away < 60 then
		return
	end
	local rate = Game.OFFLINE_RATE * (if S.passes.VIP then 1 + Game.VIP_OFFLINE_BONUS else 1)
	local base = api.baseIncome(d, Game.PEDESTALS + (if S.passes.SecondFloor then Game.PEDESTALS_FLOOR2 else 0), nil)
	local earned = math.floor(base * (1 + d.rebirths) * rate * away)
	local robbed = d.inbox
	d.inbox = {}
	d.offLost = 0
	if earned > 0 then
		d.pending += earned
	end
	if earned > 0 or #robbed > 0 then
		Ctx.popup(S, "offline", { cash = earned, seconds = away, robbed = robbed })
		Ctx.track(S, "offline_collect", earned)
	end
end

local function placeCharacter(S: any, char: Model)
	local B = S.B
	if not B then
		return
	end
	Bots.setCharGroup(char, B.index)
	char.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = "Own_" .. B.index
		end
	end)
	local hum = char:WaitForChild("Humanoid", 10)
	if hum and hum:IsA("Humanoid") then
		hum.WalkSpeed = S.baseSpeed
		hum.Died:Connect(function()
			if S.carry then
				api.failCarry(S, "fell", nil)
			end
		end)
	end
	task.defer(function()
		local r = char:WaitForChild("HumanoidRootPart", 10)
		if r and r:IsA("BasePart") and S.B then
			S.serverMoved = true
			r.CFrame = Bases.spawnPoint(S.B)
		end
	end)
	char:SetAttribute("Pose", "")
	task.defer(function()
		api.giveBat(S)
	end)
end

local function onJoin(player: Player)
	local data, why = Profiles.load(player)
	if not data then
		if why ~= "left" then
			player:Kick(if why == "locked" then "Ваш прогресс открыт на другом сервере. Зайдите через минуту." else "Сохранения Roblox недоступны, попробуйте позже.")
		end
		return
	end
	local S = {
		player = player,
		data = data,
		ready = false,
		dirty = {},
		rates = {},
		passes = {} :: { [string]: boolean },
		baseSpeed = Game.TEST_TOOLS and 16 or 16,
	}
	Ctx.sessions[player] = S
	Anticheat.onLoad(S)
	Shop.loadPasses(S)
	-- своя офлайн-база на этом сервере? Иначе — свободная
	local B
	for _, b in Ctx.bases do
		if b.ownerId == player.UserId then
			B = b
		end
	end
	B = B or Bases.findFree()
	if not B then
		player:Kick("Сервер заполнен")
		Profiles.release(player)
		Profiles.forget(player)
		Ctx.sessions[player] = nil
		return
	end
	if B.kind == "offline" or B.kind == "bot" then
		Raid.onOwnerLeaving(B)
	end
	Bases.setOnline(B, S)
	if S.passes.SecondFloor then
		Bases.setSecondFloor(B, true)
	end
	offlineIncome(S)
	Shop.applySkin(S)
	Progress.onJoin(S)
	Social.onJoin(S)
	S.ready = true
	Ctx.markAll(S)
	Ctx.flush(S)
	player.CharacterAdded:Connect(function(char)
		placeCharacter(S, char)
	end)
	if player.Character then
		placeCharacter(S, player.Character)
	end
	if data.ftue == 0 then
		task.delay(2, function()
			if S.ready and player.Parent then
				Tutorial.start(S)
			end
		end)
	end
end

local function onLeave(player: Player)
	local S = Ctx.sessions[player]
	if not S then
		return
	end
	S.ready = false
	if S.carry then
		api.failCarry(S, "timeout", nil)
	end
	Tutorial.onLeave(S)
	Social.onLeave(S)
	local B = S.B
	if B then
		Raid.onOwnerLeaving(B)
		Economy.clearBelt(B)
		Bases.setEmpty(B)
	end
	Profiles.release(player)
	Profiles.forget(player)
	Ctx.sessions[player] = nil
end

-- сохранить вскоре после важного события (трейд)
function api.saveSoon(S: any)
	if S.player then
		task.spawn(Profiles.save, S.player)
	end
end

Players.PlayerAdded:Connect(function(p)
	local ok, err = pcall(onJoin, p)
	if not ok then
		warn("[Main] вход:", err)
	end
end)
Players.PlayerRemoving:Connect(onLeave)
for _, p in Players:GetPlayers() do
	task.spawn(onJoin, p)
end

game:BindToClose(function()
	for _, S in Ctx.sessions do
		S.ready = false
		if S.carry then
			pcall(api.failCarry, S, "timeout", nil)
		end
	end
	Profiles.releaseAll()
end)

-- упавших в пустоту возвращаем домой
task.spawn(function()
	while true do
		task.wait(1)
		for _, S in Ctx.sessions do
			local r = Ctx.root(S)
			if S.ready and r and r.Position.Y < -60 and S.B and not S.inCave then
				if S.carry then
					api.failCarry(S, "fell", nil)
				end
				S.serverMoved = true
				r.AssemblyLinearVelocity = Vector3.zero
				r.CFrame = Bases.spawnPoint(S.B)
			end
		end
	end
end)

local _defs = Defs
ReplicatedStorage:SetAttribute("Ready", true)
print("[Chrono Heist] сервер готов")
