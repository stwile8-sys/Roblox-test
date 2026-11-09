--!nonstrict
-- Античит: серверная проверка движения (скорость, телепорт), спам запросов, «роботизированные» интервалы.
-- Подозрение копится → тихий бан на 24 ч (игрок не знает: не может красть и ломать, доход ×0.5) →
-- после нескольких тихих банов — Players:BanAsync. Один странный пакет никогда не наказывается.

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)

local Game = Ctx.Game
local api = Ctx.api

local M: any = {}

local DECAY = 0.5 -- очков подозрения в секунду уходит само

function M.suspect(S: any, reason: string, pts: number)
	if not S or S.isBot or not S.data then
		return
	end
	if api.isOwnerTester and api.isOwnerTester(S.player) then
		return
	end
	S.ac = S.ac or { score = 0, t = os.clock(), events = {} }
	local now = os.clock()
	S.ac.score = math.max(0, S.ac.score - (now - S.ac.t) * DECAY) + pts
	S.ac.t = now
	if S.ac.score >= Game.AC_SHADOW_SCORE and not S.shadow then
		local ac = S.data.ac
		ac.shadows += 1
		ac.shadowUntil = os.time() + Game.AC_SHADOW_HOURS * 3600
		S.shadow = true
		warn("[AC] тихий бан", S.player.UserId, reason, ac.shadows)
		if ac.shadows >= Game.AC_BAN_AFTER then
			task.spawn(function()
				pcall(function()
					Players:BanAsync({
						UserIds = { S.player.UserId },
						Duration = Game.AC_BAN_DAYS * 86400,
						DisplayReason = "Нечестная игра (читы)",
						PrivateReason = "suspicion: " .. reason,
						ApplyToUniverse = true,
					})
				end)
			end)
		end
	end
end

-- «роботизированные» интервалы: последние 10 одинаковых действий с почти одинаковым шагом
function M.event(S: any, kind: string)
	if not S or S.isBot then
		return
	end
	S.ac = S.ac or { score = 0, t = os.clock(), events = {} }
	local list = S.ac.events[kind]
	if not list then
		list = {}
		S.ac.events[kind] = list
	end
	table.insert(list, os.clock())
	if #list > 11 then
		table.remove(list, 1)
	end
	if #list == 11 then
		local gaps = {}
		local sum = 0
		for i = 2, #list do
			local g = list[i] - list[i - 1]
			table.insert(gaps, g)
			sum += g
		end
		local mean = sum / #gaps
		local var = 0
		for _, g in gaps do
			var += (g - mean) ^ 2
		end
		if math.sqrt(var / #gaps) < 0.012 and kind ~= "hack" then
			M.suspect(S, "robot:" .. kind, 6)
		end
	end
end

-- проверка движения 4 раза в секунду
local function moveCheck()
	for _, S in Ctx.sessions do
		if S.ready then
			local r = Ctx.root(S)
			local hum = Ctx.humanoid(S)
			if r and hum and hum.Health > 0 then
				local now = os.clock()
				local pos = r.Position
				local last = S.acPos
				if last and not S.serverMoved and (S.acGrace or 0) < now then
					local dt = now - S.acT
					local flat = ((pos - last) * Vector3.new(1, 0, 1)).Magnitude
					local allowed = (S.expectedSpeed or 16) * dt * 1.6 + 6
					local falling = r.AssemblyLinearVelocity.Y < -30
					if flat > 80 then
						M.suspect(S, "teleport", 8)
						S.serverMoved = true
					elseif flat > allowed and not falling then
						M.suspect(S, "speed", 1.5)
					end
				end
				S.acPos = pos
				S.acT = now
				S.serverMoved = false
			end
		end
	end
end

-- телепорты, которые делает сервер, не считаются читом
function M.serverTeleport(S: any, cf: CFrame)
	local r = Ctx.root(S)
	if r then
		S.serverMoved = true
		r.CFrame = cf
	end
end

function M.onLoad(S: any)
	if S.data.ac.shadowUntil > os.time() then
		S.shadow = true
	end
end

function M.init()
	task.spawn(function()
		while true do
			task.wait(0.25)
			pcall(moveCheck)
		end
	end)
end

api.suspect = M.suspect
api.acEvent = M.event
api.teleport = M.serverTeleport

return M
