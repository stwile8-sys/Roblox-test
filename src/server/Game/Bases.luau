--!nonstrict
-- Базы: 8 участков, кто владеет (онлайн-игрок / офлайн-база / бот / пусто), стены и их HP,
-- замок (щит), артефакты на пьедесталах (якоря), ловушки (визуал), маяк, второй этаж.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ctx = require(script.Parent.Ctx)
local BaseBuilder = require(script.Parent.Parent.World.BaseBuilder)
local Palette = require(ReplicatedStorage.Shared.Config.Palette)

local Game = Ctx.Game
local Defs = Ctx.Defs

local M: any = {}

local artsFolder = Instance.new("Folder")
artsFolder.Name = "Arts"
artsFolder.Parent = workspace

local SEG_NAMES = { "F1", "F2", "F3", "R1", "R2", "R3", "B1", "B2", "B3", "L1", "L2", "L3" }

-- ── Якоря артефактов ────────────────────────────────────────
function M.makeAnchor(id: string, cf: CFrame, attrs: { [string]: any }): BasePart
	local d = Defs.BY_ID[id]
	local size = if d then Defs.RARITY[d.rarity].size else 2
	local p = Instance.new("Part")
	p.Name = "Art_" .. id
	p.Size = Vector3.new(size, size, size)
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Transparency = 1
	p.CastShadow = false
	p:SetAttribute("Id", id)
	for k, v in attrs do
		p:SetAttribute(k, v)
	end
	CollectionService:AddTag(p, "Art")
	p.Parent = artsFolder
	return p
end

function M.playAnim(anchor: BasePart?, anim: string)
	if anchor and anchor.Parent then
		anchor:SetAttribute("Anim", anim)
		anchor:SetAttribute("AnimT", os.clock())
	end
end

-- ── Геометрия ───────────────────────────────────────────────
function M.toLocal(B: any, pos: Vector3): Vector3
	return B.cf:PointToObjectSpace(pos)
end

function M.inside(B: any, pos: Vector3, margin: number?): boolean
	local l = B.cf:PointToObjectSpace(pos)
	local m = 58 + (margin or 0)
	return math.abs(l.X) < m and math.abs(l.Z) < m and l.Y > -5 and l.Y < 45
end

function M.baseAt(pos: Vector3): any
	for _, B in Ctx.bases do
		if M.inside(B, pos) then
			return B
		end
	end
	return nil
end

-- точка перед воротами снаружи (для «Вторгнуться» и выброса)
function M.frontPoint(B: any): CFrame
	return B.cf * CFrame.new(0, 3, -72) * CFrame.Angles(0, math.pi, 0)
end

function M.spawnPoint(B: any): CFrame
	return B.cf * CFrame.new(0, 3, -40) * CFrame.Angles(0, math.pi, 0)
end

-- ── Стены ───────────────────────────────────────────────────
function M.wallMax(B: any): number
	local lvl = if B.data then B.data.wall else 1
	local hp = Game.WALLS[lvl].hp
	if B.perks and B.perks.steel then
		hp = math.floor(hp * (1 + Game.STEEL_BONUS))
	end
	return hp
end

function M.applyWalls(B: any)
	local lvl = if B.data then B.data.wall else 1
	pcall(BaseBuilder.setWallLevel, B.model, lvl)
	local max = M.wallMax(B)
	for _, seg in B.segs do
		seg.max = max
		seg.hp = max
		seg.broken = false
		seg.part:SetAttribute("HP", max)
		seg.part:SetAttribute("MaxHP", max)
		pcall(BaseBuilder.setSegmentBroken, seg.part, false)
		pcall(BaseBuilder.setSegmentDamage, seg.part, 0)
	end
	M.updateBreach(B)
end

function M.updateBreach(B: any)
	local any = false
	for _, seg in B.segs do
		if seg.broken then
			any = true
			break
		end
	end
	B.breached = any
	B.model:SetAttribute("Breached", any)
end

function M.shielded(B: any): boolean
	return B.shieldUntil > Ctx.now()
end

-- урон сегменту; возвращает true, если сегмент сломан этим ударом
function M.damage(B: any, seg: any, dmg: number): boolean
	if seg.broken or M.shielded(B) then
		return false
	end
	seg.hp = math.max(0, seg.hp - dmg)
	seg.lastHit = os.clock()
	seg.part:SetAttribute("HP", math.floor(seg.hp))
	pcall(BaseBuilder.setSegmentDamage, seg.part, 1 - seg.hp / seg.max)
	if seg.hp <= 0 then
		seg.broken = true
		seg.brokenAt = os.clock()
		pcall(BaseBuilder.setSegmentBroken, seg.part, true)
		M.updateBreach(B)
		return true
	end
	return false
end

function M.repairAll(B: any)
	for _, seg in B.segs do
		if seg.broken or seg.hp < seg.max then
			seg.broken = false
			seg.hp = seg.max
			seg.part:SetAttribute("HP", seg.max)
			pcall(BaseBuilder.setSegmentBroken, seg.part, false)
			pcall(BaseBuilder.setSegmentDamage, seg.part, 0)
		end
	end
	M.updateBreach(B)
end

-- восстановление стен (вызывается раз в секунду)
local function regen(B: any)
	local now = os.clock()
	local changed = false
	for _, seg in B.segs do
		if seg.broken then
			if now - seg.brokenAt >= Game.WALL_REBUILD then
				seg.broken = false
				seg.hp = seg.max
				seg.part:SetAttribute("HP", seg.max)
				pcall(BaseBuilder.setSegmentBroken, seg.part, false)
				pcall(BaseBuilder.setSegmentDamage, seg.part, 0)
				changed = true
			end
		elseif seg.hp < seg.max and now - seg.lastHit >= Game.WALL_REGEN_DELAY then
			seg.hp = math.min(seg.max, seg.hp + seg.max * Game.WALL_REGEN_RATE)
			seg.part:SetAttribute("HP", math.floor(seg.hp))
			pcall(BaseBuilder.setSegmentDamage, seg.part, 1 - seg.hp / seg.max)
		end
	end
	if changed then
		M.updateBreach(B)
	end
end

-- ── Замок ───────────────────────────────────────────────────
function M.lockSeconds(B: any): number
	local reb = if B.data then B.data.rebirths else 0
	local t = Game.LOCK_BASE + Game.LOCK_PER_REBIRTH * reb
	if B.perks and B.perks.shield then
		t += Game.LOCK_SHIELD_PERK
	end
	return t
end

function M.setShield(B: any, seconds: number)
	B.shieldUntil = Ctx.now() + seconds
	B.model:SetAttribute("ShieldUntil", B.shieldUntil)
	M.repairAll(B)
	pcall(BaseBuilder.setShield, B.model, true)
	-- выбросить чужих из базы
	for _, S in Ctx.sessions do
		local r = Ctx.root(S)
		if r and S.base ~= B.index and M.inside(B, r.Position, 2) then
			S.serverMoved = true
			r.CFrame = M.frontPoint(B)
		end
	end
	if B.S then
		Ctx.mark(B.S, "lock")
	end
end

-- ── Перки Chrono владельца ──────────────────────────────────
function M.perksOf(data: any): { [string]: boolean }
	local out = {}
	if not data then
		return out
	end
	for _, a in data.slots do
		local d = Defs.BY_ID[a.id]
		if d and d.perk then
			out[d.perk] = true
		end
	end
	return out
end

function M.refreshPerks(B: any)
	local before = B.perks and B.perks.steel
	B.perks = M.perksOf(B.data)
	if (B.perks.steel or false) ~= (before or false) then
		local max = M.wallMax(B)
		for _, seg in B.segs do
			local frac = seg.hp / math.max(1, seg.max)
			seg.max = max
			seg.hp = if seg.broken then 0 else max * frac
			seg.part:SetAttribute("MaxHP", max)
		end
	end
end

-- ── Артефакты на пьедесталах ────────────────────────────────
function M.pedestalTop(B: any, slot: number): CFrame?
	local ped = B.model.Pedestals:FindFirstChild("P" .. slot)
	if not ped then
		ped = B.model:FindFirstChild("Floor2") and B.model.Floor2:FindFirstChild("P" .. slot, true)
	end
	local top = ped and ped:FindFirstChild("Top")
	if top and top:IsA("BasePart") then
		return top.CFrame * CFrame.new(0, top.Size.Y / 2, 0)
	end
	return nil
end

function M.slotCount(B: any): number
	return if B.floor2 then Game.PEDESTALS + Game.PEDESTALS_FLOOR2 else Game.PEDESTALS
end

-- синхронизировать якоря с data.slots
function M.renderArts(B: any)
	local data = B.data
	local want = {}
	if data then
		for k, a in data.slots do
			local slot = tonumber(k)
			if slot and slot <= M.slotCount(B) and not B.transit[slot] then
				want[slot] = a
			end
		end
	end
	for slot, anchor in B.arts do
		local a = want[slot]
		if not a or anchor:GetAttribute("Id") ~= a.id then
			anchor:Destroy()
			B.arts[slot] = nil
		elseif anchor:GetAttribute("Lvl") ~= a.lvl then
			anchor:SetAttribute("Lvl", a.lvl)
		end
	end
	for slot, a in want do
		if not B.arts[slot] then
			local top = M.pedestalTop(B, slot)
			if top then
				local d = Defs.BY_ID[a.id]
				local size = if d then Defs.RARITY[d.rarity].size else 2
				local anchor = M.makeAnchor(a.id, top * CFrame.new(0, size / 2 + 0.3, 0), {
					Kind = "pedestal",
					Lvl = a.lvl,
					Owner = B.ownerId,
					Base = B.index,
					Slot = slot,
				})
				B.arts[slot] = anchor
				if M.onAnchor then
					M.onAnchor(B, slot, anchor)
				end
			end
		end
	end
	M.refreshPerks(B)
	M.updateBeacon(B)
end

function M.clearArts(B: any)
	for slot, anchor in B.arts do
		anchor:Destroy()
		B.arts[slot] = nil
	end
end

-- ── Ловушки (визуал) ────────────────────────────────────────
function M.renderTraps(B: any)
	local data = B.data
	for slot = 1, Game.TRAP_SLOTS do
		local t = data and data.traps[tostring(slot)]
		local kind = if t and not t.b then t.k else nil
		local skin = if kind == "mine" and data and data.trapSkin == "blackhole" then "blackhole" else nil
		pcall(BaseBuilder.setTrap, B.model, slot, kind, skin)
		if M.onTrap then
			M.onTrap(B, slot, kind, t)
		end
	end
	M.updateBeacon(B)
end

-- ── Маяк ────────────────────────────────────────────────────
function M.defenseLevel(B: any): number
	local data = B.data
	if not data then
		return 1
	end
	local traps = 0
	for _, t in data.traps do
		if not t.b then
			traps += t.l
		end
	end
	local score = data.wall * 2 + traps
	if score >= 14 then
		return 3
	elseif score >= 6 then
		return 2
	end
	return 1
end

function M.updateBeacon(B: any)
	local lvl = M.defenseLevel(B)
	local colors = { Palette.success, Palette.gold, Palette.alarm }
	local names = { "low", "mid", "high" }
	B.model:SetAttribute("Defense", lvl)
	B.model:SetAttribute("DefenseKey", names[lvl])
	local name = if B.kind == "empty" then "" else (B.ownerName or "")
	pcall(BaseBuilder.setBeacon, B.model, name, names[lvl], colors[lvl])
end

-- оценка лута (для сканера)
function M.lootValue(B: any): number
	local total = 0
	if B.data then
		for _, a in B.data.slots do
			total += Ctx.price(a.id, a.lvl)
		end
	end
	return total
end

-- ── Владение ────────────────────────────────────────────────
local function setOwner(B: any, kind: string, ownerId: number, ownerName: string, data: any, S: any)
	B.kind = kind
	B.ownerId = ownerId
	B.ownerName = ownerName
	B.data = data
	B.S = S
	B.offlineTaken = 0
	B.shieldUntil = 0
	B.model:SetAttribute("Owner", ownerId)
	B.model:SetAttribute("OwnerName", ownerName)
	B.model:SetAttribute("Kind", kind)
	B.model:SetAttribute("ShieldUntil", 0)
	pcall(BaseBuilder.setShield, B.model, false)
	pcall(BaseBuilder.setOwnerStyle, B.model, kind)
	table.clear(B.transit)
	B.floor2 = S ~= nil and S.passes and S.passes.SecondFloor or (data and data.floor2view) or false
	pcall(BaseBuilder.setSecondFloor, B.model, B.floor2)
	M.clearArts(B)
	M.applyWalls(B)
	M.renderArts(B)
	M.renderTraps(B)
	if M.onOwnerChanged then
		M.onOwnerChanged(B)
	end
end

function M.setEmpty(B: any)
	setOwner(B, "empty", 0, "", nil, nil)
end

function M.setOnline(B: any, S: any)
	setOwner(B, "online", S.player.UserId, S.player.DisplayName, S.data, S)
	S.base = B.index
	S.B = B
	local spawn = B.model:FindFirstChild("Spawn")
	if spawn and spawn:IsA("SpawnLocation") then
		S.player.RespawnLocation = spawn
	end
end

function M.setOffline(B: any, userId: number, name: string, data: any)
	setOwner(B, "offline", userId, name, data, nil)
end

function M.setBot(B: any, name: string, data: any)
	setOwner(B, "bot", -B.index, name, data, nil)
end

-- найти базу для входящего игрока: пустая → офлайн → бот
function M.findFree(): any
	for _, kind in { "empty", "offline", "bot" } do
		for i = 1, Game.PLOTS do
			local B = Ctx.bases[i]
			if B.kind == kind and not B.reserved then
				return B
			end
		end
	end
	return nil
end

function M.setSecondFloor(B: any, on: boolean)
	B.floor2 = on
	pcall(BaseBuilder.setSecondFloor, B.model, on)
	M.renderArts(B)
end

-- ── Старт ───────────────────────────────────────────────────
function M.init()
	local folder = workspace:FindFirstChild("Bases")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Bases"
		folder.Parent = workspace
	end
	for i = 1, Game.PLOTS do
		local model = BaseBuilder.build(i)
		local B = {
			index = i,
			model = model,
			cf = model:GetPivot(),
			kind = "empty",
			ownerId = 0,
			ownerName = "",
			data = nil,
			S = nil,
			segs = {},
			arts = {},
			transit = {}, -- слот → вор, который несёт этот артефакт
			belt = {},
			traps = {},
			hackers = {},
			shieldUntil = 0,
			breached = false,
			perks = {},
			floor2 = false,
		}
		local floor = model:FindFirstChild("Floor")
		if floor and floor:IsA("BasePart") then
			B.cf = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
		end
		for _, name in SEG_NAMES do
			local part = model.Walls:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				table.insert(B.segs, { name = name, part = part, hp = 400, max = 400, lastHit = 0, brokenAt = 0, broken = false })
			end
		end
		Ctx.bases[i] = B
		M.setEmpty(B)
	end
	task.spawn(function()
		while true do
			task.wait(1)
			for _, B in Ctx.bases do
				regen(B)
				if B.shieldUntil > 0 and B.shieldUntil <= Ctx.now() then
					B.shieldUntil = 0
					pcall(BaseBuilder.setShield, B.model, false)
					if B.S then
						Ctx.mark(B.S, "lock")
					end
				end
			end
		end
	end)
end

return M
