--!nonstrict
-- Первая сессия (FTUE) без текста, ~90 сек до первой кражи:
--  1) бесплатная «Капля Времени» на пьедестале (доход $1/сек);
--  2) через 10 сек NPC-вор хватает её и убегает в логово перед базой — стрелка ведёт за ним;
--  3) в логове лежит артефакт лучше (Хроно-Жук): игрок забирает его одной кнопкой и несёт домой —
--     ПЕРВАЯ КРАЖА, а «Капля» возвращается на место;
--  4) через 30 сек NPC-рейдер ломится в ворота — пульсирует кнопка «Замок».

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)
local BaseBuilder = require(script.Parent.Parent.World.BaseBuilder)

local Palette = require(game.ReplicatedStorage.Shared.Config.Palette)

local api = Ctx.api

local M: any = {}

local function step(S: any, n: number, extra: { [string]: any }?)
	S.data.ftue = n
	local data = { step = n }
	if extra then
		for k, v in extra do
			data[k] = v
		end
	end
	Ctx.popup(S, "tutorial", data)
	Ctx.mark(S, "ftue")
end

local function finish(S: any)
	S.data.ftue = 99
	Ctx.popup(S, "tutorial", { step = 99 })
	Ctx.mark(S, "ftue")
	if S.tut then
		if S.tut.den then
			S.tut.den:Destroy()
		end
		if S.tut.raider then
			api.despawnNpc(S.tut.raider)
		end
		S.tut = nil
	end
end

function M.start(S: any)
	local B = S.B
	if not B then
		return
	end
	S.tut = { t0 = os.clock() }
	if not next(S.data.slots) then
		api.give(S, "c_drop", 1)
	end
	step(S, 1)
	task.spawn(function()
		task.wait(10)
		if not S.tut or S.player.Parent == nil then
			return
		end
		-- вор появляется у пьедестала с «Каплей»
		local slot, anchor
		for sl, a in B.arts do
			slot, anchor = sl, a
			break
		end
		if not anchor then
			finish(S)
			return
		end
		local thief = api.spawnNpc("Вор", Palette.thief, CFrame.new(anchor.Position + B.cf.LookVector * -4 + Vector3.new(0, 2, 0)), { group = "Own_" .. B.index })
		thief.baseSpeed = 11
		S.tut.thief = thief
		Bases.playAnim(anchor, "stolen")
		B.transit[slot] = thief
		task.wait(0.4)
		Bases.renderArts(B)
		local a = S.data.slots[tostring(slot)]
		api.startCarry(thief, { id = a.id, lvl = a.lvl, kind = "tutorial" })
		Ctx.fx("steal", anchor.Position, nil)
		Ctx.fx("chase", nil, { thief = thief.botId, role = "owner" }, S.player)
		-- логово перед базой
		local den = BaseBuilder.makeDen(B.model)
		S.tut.den = den
		local spot = den:FindFirstChild("Spot")
		step(S, 2, { target = spot and spot.Position })
		api.walk(thief, { (B.cf * CFrame.new(0, 3, -40)).Position, (B.cf * CFrame.new(0, 3, -70)).Position, (B.cf * CFrame.new(4, 3, -88)).Position })
		-- вор бросает добычу в логове и исчезает; «Капля» возвращается домой
		api.despawnNpc(thief)
		B.transit[slot] = nil
		Bases.renderArts(B)
		Bases.playAnim(B.arts[slot], "return")
		if not S.tut or not spot then
			return
		end
		local better = Bases.makeAnchor("r_beetle", spot.CFrame * CFrame.new(0, 1.5, 0), { Kind = "den" })
		S.tut.better = better
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Steal"
		prompt:SetAttribute("Role", "steal")
		prompt.ActionText = "Украсть"
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = better
		local done = false
		prompt.Triggered:Connect(function(player)
			if player ~= S.player or done or not S.tut then
				return
			end
			done = true
			better:Destroy()
			step(S, 3, { target = (B.cf * CFrame.new(0, 2, -30)).Position })
			api.startCarry(S, {
				id = "r_beetle",
				lvl = 1,
				kind = "den",
				onDeliver = function()
					Ctx.track(S, "ftue_first_steal", math.floor(os.clock() - (S.tut and S.tut.t0 or os.clock())))
					task.delay(30, function()
						if S.tut then
							M.raidStep(S)
						end
					end)
					return true, nil
				end,
				onFail = function()
					done = false
				end,
			})
		end)
	end)
end

function M.raidStep(S: any)
	local B = S.B
	if not B or not S.tut then
		return
	end
	local lb = B.model:FindFirstChild("LockButton")
	step(S, 4, { target = lb and lb:GetPivot().Position })
	local raider = api.spawnNpc("Рейдер", Palette.alarm, B.cf * CFrame.new(0, 3, -100))
	raider.data.tool = 1
	S.tut.raider = raider
	api.botRaid(raider, nil, B, {
		noSteal = true,
		onShield = function()
			Ctx.popup(S, "defended", { id = "", thief = "Рейдер" })
			if S.tut and S.data.ftue == 4 then
				M.buyStep(S)
			end
		end,
	})
	task.delay(40, function()
		if S.tut and S.data.ftue == 4 then
			M.buyStep(S)
		end
	end)
end

-- последний шаг: купить существо на кольцевом конвейере в центре и донести домой
function M.buyStep(S: any)
	if not S.tut then
		return
	end
	local hub = workspace.Map:FindFirstChild("Hub")
	local R, A0 = hub and hub:GetAttribute("RingR"), hub and hub:GetAttribute("RingA0")
	local target = if R and A0 then Vector3.new(math.cos(A0 + 0.6) * R, 2, math.sin(A0 + 0.6) * R) else Vector3.new(0, 2, 0)
	step(S, 5, { target = target })
	task.delay(150, function()
		if S.tut and (S.data.ftue == 5 or S.data.ftue == 6) then
			finish(S)
		end
	end)
end

-- события обучения: замок нажат, покупка с конвейера, покупка донесена
function M.event(S: any, name: string)
	if not S.tut then
		return
	end
	if name == "lock" and S.data.ftue == 4 then
		task.delay(3, function()
			if S.tut and S.data.ftue == 4 then
				M.buyStep(S)
			end
		end)
	elseif name == "bought" and S.data.ftue == 5 then
		local B = S.B
		step(S, 6, { target = B and (B.cf * CFrame.new(0, 2, -20)).Position })
	elseif name == "delivered" and S.data.ftue == 6 then
		finish(S)
	end
end

function M.onLeave(S: any)
	if S.tut then
		if S.tut.thief then
			api.despawnNpc(S.tut.thief)
		end
		if S.tut.better then
			S.tut.better:Destroy()
		end
		if S.tut.den then
			S.tut.den:Destroy()
		end
		if S.tut.raider then
			api.despawnNpc(S.tut.raider)
		end
		S.tut = nil
	end
	if S.data.ftue > 0 and S.data.ftue < 99 then
		S.data.ftue = 99 -- обучение не повторяем
	end
end

api.startTutorial = M.start
api.tutorialEvent = M.event

return M
