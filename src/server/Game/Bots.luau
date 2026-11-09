--!nonstrict
-- Тестовые боты (только при Config.Game.TEST_TOOLS и только когда на сервере владелец плейса):
--   • рейдер — сканирует, идёт к твоей базе, ломает стену, крадёт артефакт и убегает к себе;
--   • база-бот с охранником — можно украсть у него, охранник догоняет и бьёт дубинкой;
--   • торговец в хабе — принимает обмен, отказывает, если ты отдаёшь легендарку/хроно.
-- Также NPC для обучения (вор и рейдер) создаются отсюда — они видны только в обучении.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)

local Game = Ctx.Game
local Defs = Ctx.Defs
local api = Ctx.api

local M: any = {}

local botFolder = Instance.new("Folder")
botFolder.Name = "Bots"
botFolder.Parent = workspace

local nextId = 0

-- ── NPC ─────────────────────────────────────────────────────
local function makeRig(name: string, color: Color3): Model
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(255, 220, 180)
	desc.TorsoColor = color
	desc.LeftArmColor = color
	desc.RightArmColor = color
	desc.LeftLegColor = Color3.fromRGB(40, 40, 60)
	desc.RightLegColor = Color3.fromRGB(40, 40, 60)
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then
		rig = Instance.new("Model")
		local hrp = Instance.new("Part")
		hrp.Name = "HumanoidRootPart"
		hrp.Size = Vector3.new(2, 2, 1)
		hrp.Parent = rig
		local head = Instance.new("Part")
		head.Name = "Head"
		head.Size = Vector3.new(2, 1, 1)
		head.Color = color
		head.Parent = rig
		local w = Instance.new("WeldConstraint")
		w.Part0 = hrp
		w.Part1 = head
		w.Parent = hrp
		head.CFrame = hrp.CFrame * CFrame.new(0, 1.5, 0)
		Instance.new("Humanoid").Parent = rig
		rig.PrimaryPart = hrp
	end
	rig.Name = name
	local hum = rig:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayName = name
		hum.NameDisplayDistance = 80
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	rig:SetAttribute("Bot", true)
	return rig
end

function M.spawnNpc(name: string, color: Color3, cf: CFrame, opts: any?): any
	nextId += 1
	local rig = makeRig(name, color)
	rig:PivotTo(cf)
	rig.Parent = botFolder
	local hrp = rig:FindFirstChild("HumanoidRootPart")
	if hrp and hrp:IsA("BasePart") then
		pcall(function()
			hrp:SetNetworkOwner(nil)
		end)
	end
	local S = {
		isBot = true,
		botId = -1000 - nextId,
		botName = name,
		char = rig,
		data = { tool = 2, clan = "", inv = {}, energy = 10, stats = {} },
		passes = {},
		rates = {},
		baseSpeed = 16,
		dirty = {},
	}
	if opts then
		for k, v in opts do
			S[k] = v
		end
	end
	Ctx.bots[S.botId] = S
	if S.group then
		for _, p in rig:GetDescendants() do
			if p:IsA("BasePart") then
				p.CollisionGroup = S.group
			end
		end
	end
	return S
end

function M.despawn(S: any)
	if not S then
		return
	end
	if S.carry then
		if S.carry.from and api.failCarry then
			api.failCarry(S, "timeout", nil)
		else
			if S.carry.anchor then
				S.carry.anchor:Destroy()
			end
			S.carry = nil
		end
	end
	if api.tradeClose then
		api.tradeClose(S, "left")
	end
	Ctx.bots[S.botId] = nil
	S.dead = true
	if S.char then
		S.char:Destroy()
	end
end

-- пройти по точкам; false — если прервали или застряли
function M.walk(S: any, points: { Vector3 }, timeout: number?): boolean
	local hum = Ctx.humanoid(S)
	if not hum then
		return false
	end
	for _, p in points do
		if S.dead then
			return false
		end
		local reached = false
		local conn = hum.MoveToFinished:Connect(function(r)
			reached = r
		end)
		local t0 = os.clock()
		hum:MoveTo(p)
		while not reached and os.clock() - t0 < (timeout or 12) do
			task.wait(0.2)
			if S.dead then
				conn:Disconnect()
				return false
			end
			local r = Ctx.root(S)
			if r and ((r.Position - p) * Vector3.new(1, 0, 1)).Magnitude < 3 then
				reached = true
			elseif os.clock() - t0 > 7.5 and math.floor((os.clock() - t0) * 5) % 20 == 0 then
				hum:MoveTo(p)
				hum.Jump = true
			end
		end
		conn:Disconnect()
		if not reached then
			-- застрял — подтолкнуть телепортом (только боты, в тесте)
			local r = Ctx.root(S)
			if r then
				r.CFrame = CFrame.new(p + Vector3.new(0, 3, 0))
			end
		end
	end
	return true
end

-- маршрут между базами по мостам: от передней кромки базы a через хаб к базе b
function M.route(fromB: any?, toB: any): { Vector3 }
	local pts = {}
	if fromB then
		table.insert(pts, (fromB.cf * CFrame.new(0, 3, -50)).Position)
		table.insert(pts, (fromB.cf * CFrame.new(0, 3, -75)).Position)
		table.insert(pts, (fromB.cf.Position * Vector3.new(1, 0, 1)).Unit * 72 + Vector3.new(0, 3, 0))
	end
	table.insert(pts, (toB.cf.Position * Vector3.new(1, 0, 1)).Unit * 72 + Vector3.new(0, 3, 0))
	table.insert(pts, (toB.cf * CFrame.new(0, 3, -75)).Position)
	return pts
end

-- ── Данные базы-бота ────────────────────────────────────────
local function botBaseData(): any
	local d = { slots = {}, inv = {}, wall = 1, traps = {}, rebirths = 0, trapSkin = "", clan = "" }
	local pool = { "common", "common", "common", "rare", "rare", "epic" }
	for i = 1, 6 do
		d.slots[tostring(i)] = { id = api.randomOf(pool[i]), lvl = 1 }
	end
	d.traps["1"] = { k = "slow", l = 1 }
	return d
end

-- ── Рейдер ──────────────────────────────────────────────────
local function nearestSlot(B: any, from: Vector3): (number?, BasePart?)
	local best, bestA, bd = nil, nil, math.huge
	for slot, anchor in B.arts do
		local d = (anchor.Position - from).Magnitude
		if d < bd and not B.transit[slot] then
			best, bestA, bd = slot, anchor, d
		end
	end
	return best, bestA
end

function M.raid(raider: any, home: any?, target: any, opts: any?)
	opts = opts or {}
	task.spawn(function()
		local seg
		for _, s in target.segs do
			if s.name == "F1" then
				seg = s
			end
		end
		if not seg then
			return
		end
		-- дойти до стены снаружи
		local pts = M.route(home, target)
		local outside = (target.cf * CFrame.new(seg.part.CFrame:PointToObjectSpace(target.cf.Position).X * 0 - 19, 3, -63)).Position
		table.insert(pts, outside)
		if not M.walk(raider, pts) then
			return
		end
		-- взлом
		local t0 = os.clock()
		while not seg.broken and os.clock() - t0 < 60 and not raider.dead do
			if Bases.shielded(target) then
				Ctx.fx("hit", Ctx.root(raider) and Ctx.root(raider).Position, nil)
				if opts.onShield then
					opts.onShield()
				end
				task.wait(1.5)
				M.despawn(raider)
				return
			end
			api.hack(raider, target.index, seg.name)
			task.wait(Game.HACK_INTERVAL)
		end
		if opts.noSteal or raider.dead then
			task.wait(2)
			M.despawn(raider)
			return
		end
		-- внутрь и к артефакту
		local inside = (target.cf * CFrame.new(-19, 3, -48)).Position
		M.walk(raider, { inside })
		local r = Ctx.root(raider)
		local _slot, anchor = nearestSlot(target, r and r.Position or inside)
		if not anchor then
			M.despawn(raider)
			return
		end
		M.walk(raider, { anchor.Position - Vector3.new(0, anchor.Size.Y / 2, 0) + (target.cf.LookVector * 3) })
		raider.stealT = 0
		api.trySteal(raider, anchor)
		task.wait(1)
		if not raider.carry then
			task.wait(2)
			M.despawn(raider)
			return
		end
		-- побег к себе
		local back = { inside, (target.cf * CFrame.new(-19, 3, -70)).Position }
		for _, p in M.route(target, home or target) do
			table.insert(back, p)
		end
		if home then
			table.insert(back, (home.cf * CFrame.new(0, 3, -30)).Position)
		end
		M.walk(raider, back, 15)
		task.wait(3)
		M.despawn(raider)
	end)
end

-- ── Охранник базы-бота ──────────────────────────────────────
local function guardLoop(guard: any, B: any)
	task.spawn(function()
		while not guard.dead do
			task.wait(0.3)
			local thief
			for _, S in Ctx.sessions do
				if S.carry and S.carry.from == B then
					thief = S
				end
			end
			local hum = Ctx.humanoid(guard)
			local r = Ctx.root(guard)
			if thief and hum and r then
				local tr = Ctx.root(thief)
				if tr then
					hum:MoveTo(tr.Position)
					if (tr.Position - r.Position).Magnitude < Game.BAT_RANGE - 1 then
						api.bat(guard, Ctx.uid(thief))
					end
				end
			elseif hum and r then
				local home = (B.cf * CFrame.new(0, 3, 15)).Position
				if (r.Position - home).Magnitude > 6 then
					hum:MoveTo(home)
				end
			end
		end
	end)
end

-- ── Торговец ────────────────────────────────────────────────
local function makeTrader(): any
	local cf = CFrame.lookAt(Vector3.new(30, 3, -30), Vector3.new(0, 3, 0))
	local T = M.spawnNpc("Торговец (бот)", Color3.fromHex("#FFB347"), cf)
	T.data.inv = { { id = api.randomOf("rare"), lvl = 1 }, { id = api.randomOf("epic"), lvl = 1 } }
	local hrp = Ctx.root(T)
	if hrp then
		hrp.Anchored = true
	end
	T.onTradeOpen = function(S)
		T.trade.give = { 1 }
		T.trade.t = os.clock()
	end
	T.onTradeChange = function(S)
		local tooRare = false
		for _, i in S.trade.give do
			local a = S.data.inv[i]
			local d = a and Defs.BY_ID[a.id]
			if d and (d.rarity == "legendary" or d.rarity == "chrono") then
				tooRare = true
			end
		end
		local stamp = S.trade.t
		task.delay(Game.TRADE_CONFIRM_DELAY + 0.3, function()
			if not T.trade or T.trade.with ~= S or S.trade == nil or S.trade.t ~= stamp then
				return
			end
			if tooRare then
				Ctx.notify(S, "msg.botDeclines", nil, "bad")
				api.tradeClose(T, "declined")
				return
			end
			if #S.trade.give > 0 then
				api.tradeReady(T)
			end
		end)
	end
	return T
end

-- ── Тестовый режим ──────────────────────────────────────────
local test = { on = false, raider = nil, guard = nil, trader = nil, base = nil }

local function ownerSession(): any
	for _, S in Ctx.sessions do
		if S.ready and api.isOwnerTester and api.isOwnerTester(S.player) then
			return S
		end
	end
	return nil
end

local function ensureBotBase(): any
	if test.base and test.base.kind == "bot" then
		return test.base
	end
	for i = Game.PLOTS, 1, -1 do
		local B = Ctx.bases[i]
		if B.kind == "empty" then
			Bases.setBot(B, "Бот-база", botBaseData())
			test.base = B
			return B
		end
	end
	return nil
end

function M.startTest()
	if test.on then
		return
	end
	test.on = true
	local B = ensureBotBase()
	if B then
		test.guard = M.spawnNpc("Охранник (бот)", Color3.fromHex("#2C3E50"), B.cf * CFrame.new(0, 3, 15), { B = B, base = B.index, group = "Own_" .. B.index })
		guardLoop(test.guard, B)
	end
	test.trader = makeTrader()
end

function M.stopTest()
	test.on = false
	for _, k in { "raider", "guard", "trader" } do
		if test[k] then
			M.despawn(test[k])
			test[k] = nil
		end
	end
	if test.base and test.base.kind == "bot" then
		Bases.setEmpty(test.base)
	end
	test.base = nil
end

function M.sendRaider(target: any)
	if test.raider and not test.raider.dead then
		return false
	end
	local home = ensureBotBase()
	local cf = if home then home.cf * CFrame.new(0, 3, -30) else CFrame.new(0, 3, 0)
	local raider = M.spawnNpc("Рейдер (бот)", Color3.fromHex("#7B2FF7"), cf, {
		B = home,
		base = home and home.index,
		group = if home then "Own_" .. home.index else nil,
		onDeliver = function(c)
			-- украденное у тебя попадает на базу-бота: можно отомстить и вернуть
			if home and home.data then
				for i = 1, 10 do
					if not home.data.slots[tostring(i)] then
						home.data.slots[tostring(i)] = { id = c.id, lvl = c.lvl }
						break
					end
				end
				Bases.renderArts(home)
			end
		end,
	})
	raider.data.tool = 3
	test.raider = raider
	M.raid(raider, home, target)
	return true
end

-- ── Действия панели владельца ───────────────────────────────
local function ownerOnly(S: any): boolean
	return api.isOwnerTester ~= nil and api.isOwnerTester(S.player)
end

Ctx.actions.testRaid = function(S)
	if not ownerOnly(S) or not S.B then
		return false, "msg.bad"
	end
	M.startTest()
	return M.sendRaider(S.B), "msg.testRaid"
end

Ctx.actions.testCash = function(S)
	if not ownerOnly(S) then
		return false, "msg.bad"
	end
	api.addCash(S, 1000000, "test")
	api.addTokens(S, 10)
	api.addEnergy(S, 10)
	return true, nil
end

Ctx.actions.testArt = function(S, args)
	if not ownerOnly(S) or not Ctx.isStr(args.rarity, 10) or not Defs.RARITY[args.rarity] then
		return false, "msg.bad"
	end
	api.give(S, api.randomOf(args.rarity), 1)
	return true, nil
end

Ctx.actions.testFtue = function(S)
	if not ownerOnly(S) then
		return false, "msg.bad"
	end
	S.data.ftue = 0
	if api.startTutorial then
		api.startTutorial(S)
	end
	return true, nil
end

Ctx.actions.testBotBase = function(S)
	if not ownerOnly(S) then
		return false, "msg.bad"
	end
	M.startTest()
	local B = test.base
	if B and B.data then
		B.data = botBaseData()
		Bases.applyWalls(B)
		Bases.renderArts(B)
		Bases.renderTraps(B)
	end
	return true, nil
end

-- ── Группы столкновений: ворота своей базы проходимы для хозяина ──
function M.setupGroups()
	for i = 1, Game.PLOTS do
		pcall(function()
			PhysicsService:RegisterCollisionGroup("Gate_" .. i)
			PhysicsService:RegisterCollisionGroup("Own_" .. i)
		end)
	end
	for i = 1, Game.PLOTS do
		pcall(function()
			PhysicsService:CollisionGroupSetCollidable("Gate_" .. i, "Own_" .. i, false)
		end)
	end
	for _, B in Ctx.bases do
		for _, seg in B.segs do
			if seg.part:GetAttribute("Gate") then
				seg.part.CollisionGroup = "Gate_" .. B.index
			end
		end
	end
end

function M.setCharGroup(char: Model, baseIndex: number?)
	local group = if baseIndex then "Own_" .. baseIndex else "Default"
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = group
		end
	end
	char:SetAttribute("Group", group)
end

function M.init()
	M.setupGroups()
	task.spawn(function()
		while true do
			task.wait(3)
			if Game.TEST_TOOLS then
				local owner = ownerSession()
				if owner and not test.on then
					M.startTest()
				elseif not owner and test.on then
					M.stopTest()
				end
			end
		end
	end)
end

api.spawnNpc = M.spawnNpc
api.despawnNpc = M.despawn
api.walk = M.walk
api.botRaid = M.raid
api.setCharGroup = M.setCharGroup

return M
