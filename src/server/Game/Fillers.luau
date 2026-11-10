--!nonstrict
-- Боты-соседи: каждый свободный остров занимает бот с аватаром настоящего игрока, чтобы новый
-- сервер не был пустым. У бота своя база с существами (её можно ограбить), он гуляет по базе
-- и гоняется с дубинкой за ворами. Когда заходит живой игрок и ему достаётся остров бота —
-- бот исчезает (Bases.findFree отдаёт базы ботов в последнюю очередь, Main освобождает остров).

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)
local Bots = require(script.Parent.Bots)
local Profiles = require(script.Parent.Parent.Data.Profiles)
local BaseBuilder = require(script.Parent.Parent.World.BaseBuilder)

local Game = Ctx.Game
local api = Ctx.api

local M: any = {}

local npcOf: { [any]: any } = {} -- база → бот

-- ники в духе обычных игроков Roblox
local NAMES = {
	"PixelFox_77", "NoobMaster2013", "CoolKid_Lev", "xX_Shadow_Xx", "MaksimPro", "Kira_Cat",
	"TurboBanana", "SashaGamer", "Diman4ik", "LunaStar_09", "BloxyDanya", "Nikitos_2012",
	"FrostWolf", "MegaBuilder", "Vika_Sweet", "Artyom_YT", "ChronoKing", "SkyRunner_5",
	"Polina_Love", "DragonSlayer99", "Egorka_Plays", "MiniMila", "Rocket_Boy", "SonyaCandy",
	"BestThief_RU", "Lexa_Ninja", "HappyPanda", "GoldDigger_X", "Timurka", "StarDust_Liza",
}
-- запасные аватары, если на сервере ещё нет данных о недавних игроках (официальные аккаунты Roblox)
local FALLBACK_IDS = { 156, 261, 1, 16, 15, 18, 19, 26, 37, 87 }

local usedNames: { [string]: boolean } = {}
local function pickName(): string
	for _ = 1, 30 do
		local n = NAMES[math.random(1, #NAMES)]
		if not usedNames[n] then
			usedNames[n] = true
			return n
		end
	end
	return "Player" .. math.random(1000, 9999)
end

-- аватар: недавние игроки этой игры, которых сейчас нет на сервере, иначе — запасной список
local function pickAvatarId(): number
	local pool = {}
	for _, e in Profiles.recentPlayers(60) do
		if not Players:GetPlayerByUserId(e.id) then
			table.insert(pool, e.id)
		end
	end
	if #pool < 3 then
		for _, id in FALLBACK_IDS do
			table.insert(pool, id)
		end
	end
	return pool[math.random(1, #pool)]
end

-- база бота: от новичка до крепкого середняка
local function baseData(): any
	local tier = math.random(1, 3)
	local d = { slots = {}, inv = {}, wall = tier, traps = {}, rebirths = tier - 1, trapSkin = "", clan = "" }
	local pools = {
		{ "common", "common", "common", "common", "rare", "rare" },
		{ "common", "common", "rare", "rare", "rare", "epic", "epic" },
		{ "common", "rare", "rare", "epic", "epic", "epic", "legendary", "rare" },
	}
	for i, r in pools[tier] do
		d.slots[tostring(i)] = { id = api.randomOf(r), lvl = math.random(1, tier) }
	end
	if tier >= 2 then
		d.traps[tostring(math.random(1, 8))] = { k = if math.random() < 0.5 then "slow" else "mine", l = 1 }
	end
	return d
end

local function inBase(B: any, pos: Vector3, margin: number): boolean
	return Bases.inside(B, pos, margin)
end

-- поведение: гуляет по своей базе, гонится за вором своей базы
local function brain(S: any, B: any)
	task.spawn(function()
		local nextWalk = 0
		while not S.dead do
			task.wait(0.35)
			if npcOf[B] ~= S then
				break
			end
			local hum = Ctx.humanoid(S)
			local r = Ctx.root(S)
			if not hum or not r then
				continue
			end
			local thief
			for _, o in Ctx.sessions do
				if o.carry and o.carry.from == B then
					thief = o
				end
			end
			if thief then
				local tr = Ctx.root(thief)
				if tr and inBase(B, tr.Position, 40) then
					hum:MoveTo(tr.Position)
					if (tr.Position - r.Position).Magnitude < Game.BAT_RANGE - 1 and api.bat then
						api.bat(S, Ctx.uid(thief))
					end
					continue
				end
			end
			if os.clock() > nextWalk then
				nextWalk = os.clock() + math.random(4, 10)
				local roll = math.random()
				local target
				if roll < 0.45 then
					-- подойти к случайному пьедесталу
					local slot = math.random(1, Bases.slotCount(B))
					local top = Bases.pedestalTop(B, slot)
					if top then
						target = (top * CFrame.new(0, 0, -4)).Position
					end
				elseif roll < 0.6 then
					local collect = B.model:FindFirstChild("Collect")
					if collect then
						target = collect.Position
					end
				end
				target = target or (B.cf * CFrame.new(math.random(-40, 40), 3, math.random(-40, 40))).Position
				hum:MoveTo(target)
			end
		end
	end)
end

local function spawnFor(B: any)
	local name = pickName()
	Bases.setBot(B, name, baseData())
	B.filler = true
	-- снаружи база выглядит как база обычного игрока
	B.model:SetAttribute("Kind", "online")
	pcall(BaseBuilder.setOwnerStyle, B.model, "online")
	local S = Bots.spawnNpc(name, Color3.fromHex("#7B5CFF"), Bases.spawnPoint(B) * CFrame.new(0, 3, 0), { B = B, base = B.index, group = "Own_" .. B.index, baseSpeed = 18, filler = true })
	npcOf[B] = S
	-- настоящий аватар
	local avatarId = pickAvatarId()
	task.spawn(function()
		local ok, desc = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(avatarId)
		end)
		local hum = Ctx.humanoid(S)
		if ok and desc and hum and not S.dead then
			pcall(function()
				hum:ApplyDescription(desc)
			end)
			if S.char then
				for _, p in S.char:GetDescendants() do
					if p:IsA("BasePart") then
						p.CollisionGroup = "Own_" .. B.index
					end
				end
			end
		end
		if hum then
			hum.WalkSpeed = 14
			hum.DisplayName = name
		end
	end)
	brain(S, B)
end

local function removeFor(B: any)
	local S = npcOf[B]
	if S then
		npcOf[B] = nil
		if S.botName then
			usedNames[S.botName] = nil
		end
		Bots.despawn(S)
	end
	B.filler = nil
end

-- заполнить все свободные острова ботами
function M.fill()
	for _, B in Ctx.bases do
		if B.kind == "empty" and not B.reserved then
			pcall(spawnFor, B)
		end
	end
end

-- ограбленному боту со временем «докупаются» существа
local function restock()
	for B, S in npcOf do
		if B.kind == "bot" and B.data and not S.dead then
			local n = 0
			for _ in B.data.slots do
				n += 1
			end
			if n < 4 then
				for i = 1, Bases.slotCount(B) do
					if not B.data.slots[tostring(i)] then
						B.data.slots[tostring(i)] = { id = api.randomOf(if math.random() < 0.7 then "common" else "rare"), lvl = 1 }
						break
					end
				end
				pcall(Bases.renderArts, B)
			end
		end
	end
end

function M.init()
	-- база перестала быть базой бота (зашёл игрок, офлайн-база) — бот уходит
	local prev = Bases.onOwnerChanged
	Bases.onOwnerChanged = function(B)
		if prev then
			prev(B)
		end
		if npcOf[B] and not (B.kind == "bot" and B.filler) then
			removeFor(B)
		end
	end
	task.spawn(function()
		task.wait(8)
		while true do
			pcall(M.fill)
			pcall(restock)
			task.wait(25)
		end
	end)
end

function M.isFiller(B: any): boolean
	return npcOf[B] ~= nil
end

return M
