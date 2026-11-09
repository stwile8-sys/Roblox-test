--!nonstrict
-- Пещера удачи (вместо конвейера): игрок прыгает во вход на вершине холма в центре хаба →
-- падает в подземную комнату → СНАЧАЛА праздничная карточка с выпавшим существом →
-- ПОТОМ (закрыл карточку или прошло 6 с) поток воздуха выбрасывает наверх → существо уже на его базе.
-- Плата — только игровой Cash (не Robux), поэтому это не «платный рандом» по правилам Roblox.

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)

local Game = Ctx.Game
local Defs = Ctx.Defs
local api = Ctx.api

local M: any = {}

function M.cost(S: any): number
	return Game.CAVE_COST * (1 + S.data.rebirths)
end

local function roll(): string
	local total = 0
	for _, r in Defs.RARITIES do
		total += Defs.RARITY[r].weight
	end
	local x = math.random() * total
	local rarity = "common"
	for _, r in Defs.RARITIES do
		x -= Defs.RARITY[r].weight
		if x <= 0 then
			rarity = r
			break
		end
	end
	return api.randomOf(rarity)
end

local cave, room

-- выброс потоком воздуха из входа пещеры
local function launch(S: any)
	local st = S.cave
	if not st or st.launched then
		return
	end
	st.launched = true
	local r = Ctx.root(S)
	local spawn = room and room:FindFirstChild("CaveSpawn")
	local wind = spawn and spawn:FindFirstChild("Wind")
	if wind then
		wind:Emit(40)
	end
	Ctx.fx("caveWind", spawn and spawn.Position, nil, S.player)
	if api.setPose then
		api.setPose(S, "rebirth", 1.2)
	end
	task.wait(0.6)
	if r and r.Parent then
		local mouth = cave:FindFirstChild("Sparks")
		local top = if mouth then mouth.Position else Vector3.new(0, 9, 0)
		local w2 = mouth and mouth:FindFirstChild("Wind")
		if w2 then
			w2:Emit(40)
		end
		S.serverMoved = true
		S.acGrace = os.clock() + 4
		r.CFrame = CFrame.new(top + Vector3.new(0, 4, 0))
		local dir = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5)
		if dir.Magnitude < 0.1 then
			dir = Vector3.new(1, 0, 0)
		end
		r.AssemblyLinearVelocity = Vector3.new(0, 95, 0) + dir.Unit * 28
		Ctx.fx("caveLaunch", top, nil)
	end
	S.cave = nil
	S.inCave = false
end

local function enter(S: any)
	if S.cave or S.carry or S.inCave then
		return
	end
	local now = os.clock()
	if now - (S.caveT or 0) < 4 then
		return
	end
	S.caveT = now
	if not api.hasRoom(S) then
		Ctx.notify(S, "msg.noRoom", nil, "bad")
		return
	end
	local price = M.cost(S)
	if not api.spend(S, price) then
		Ctx.notify(S, "msg.caveNoCash", { cost = price }, "bad")
		return
	end
	local id = roll()
	local d = Defs.BY_ID[id]
	-- существо сразу на базу
	api.give(S, id, 1)
	if api.quest then
		api.quest(S, "buy", 1)
	end
	if api.passXp then
		api.passXp(S, Game.XP.buy)
	end
	Ctx.track(S, "cave_roll", Defs.RARITY[d.rarity].index, { id = id })
	S.cave = { id = id, t = now }
	S.inCave = true
	-- падение в комнату
	local r = Ctx.root(S)
	local spawn = room and room:FindFirstChild("CaveSpawn")
	if r and spawn then
		S.serverMoved = true
		S.acGrace = os.clock() + 8
		r.AssemblyLinearVelocity = Vector3.zero
		r.CFrame = CFrame.new(spawn.Position + Vector3.new(0, 4, 0))
	end
	Ctx.fx("caveFall", nil, nil, S.player)
	local st = S.cave
	task.delay(1.2, function()
		if S.cave == st then
			Ctx.popup(S, "caveReveal", { id = id, rarity = d.rarity })
		end
	end)
	task.delay(7.2, function()
		if S.cave == st then
			launch(S)
		end
	end)
end

-- игрок закрыл карточку
Ctx.actions.caveDone = function(S)
	if S.cave and os.clock() - S.cave.t > 1.3 then
		task.spawn(launch, S)
	end
	return true, nil
end

function M.init()
	local hub = workspace.Map.Hub
	cave = hub:FindFirstChild("Cave")
	room = hub:FindFirstChild("CaveRoom")
	local trig = cave and cave:FindFirstChild("CaveTrigger")
	if not trig then
		warn("[Cave] нет входа")
		return
	end
	trig.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		local S = player and Ctx.session(player)
		if S and S.ready then
			enter(S)
		end
	end)
	Ctx.views.caveCost = function(S)
		return M.cost(S)
	end
end

return M
