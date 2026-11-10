--!nonstrict
-- Рейды: сканер, вторжение, взлом стен, кража, перенос добычи, погоня, дубинка, ловушки, замок.
-- Всё проверяется на сервере: расстояние, кулдауны, наличие инструмента, пролом в стене, щит.

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)
local Profiles = require(script.Parent.Parent.Data.Profiles)
local BaseBuilder = require(script.Parent.Parent.World.BaseBuilder)
local ModelLib = require(script.Parent.Parent.World.ModelLib)

local Game = Ctx.Game
local Defs = Ctx.Defs
local api = Ctx.api

local M: any = {}

function M.setArmed(B: any, slot: number, armed: boolean)
	pcall(BaseBuilder.setTrapArmed, B.model, slot, armed)
end

Ctx.bots = Ctx.bots or {} -- псевдо-сессии NPC (боты, вор из обучения)

local function actors(): { any }
	local out = {}
	for _, S in Ctx.sessions do
		if S.ready then
			table.insert(out, S)
		end
	end
	for _, S in Ctx.bots do
		table.insert(out, S)
	end
	return out
end
M.actors = actors

local function perks(S: any): { [string]: boolean }
	return if S.B and S.B.perks then S.B.perks else {}
end

local function sameClan(a: any, b: any): boolean
	local ca = a.data and a.data.clan or ""
	local cb = b.data and b.data.clan or ""
	return ca ~= "" and ca == cb
end

-- расстояние от точки до ближайшей точки детали
local function distToPart(part: BasePart, pos: Vector3): number
	local l = part.CFrame:PointToObjectSpace(pos)
	local h = part.Size / 2
	local c = Vector3.new(math.clamp(l.X, -h.X, h.X), math.clamp(l.Y, -h.Y, h.Y), math.clamp(l.Z, -h.Z, h.Z))
	return (l - c).Magnitude
end

local function setPose(S: any, pose: string, seconds: number?)
	local char = Ctx.char(S)
	if char then
		char:SetAttribute("Pose", pose)
		char:SetAttribute("PoseT", os.clock())
		if seconds then
			local t = os.clock()
			task.delay(seconds, function()
				if char.Parent and char:GetAttribute("PoseT") == t then
					char:SetAttribute("Pose", if S.carry then "carry" else "")
				end
			end)
		end
	end
end
M.setPose = setPose

-- ── Скорость персонажа ──────────────────────────────────────
local function updateSpeed(S: any)
	local hum = Ctx.humanoid(S)
	if not hum then
		return
	end
	local now = os.clock()
	local speed = S.baseSpeed or 16
	local step = perks(S).step
	if S.stunUntil and S.stunUntil > now then
		speed = 0
	else
		if S.carry and not step then
			speed *= Game.CARRY_SPEED
		end
		if S.slowUntil and S.slowUntil > now and not step then
			speed *= Game.TRAPS.slow.slow
		end
	end
	if math.abs(hum.WalkSpeed - speed) > 0.05 then
		hum.WalkSpeed = speed
	end
	S.expectedSpeed = math.max(speed, S.baseSpeed or 16)
end

function M.stun(S: any, seconds: number, pose: string?)
	S.acGrace = os.clock() + seconds + 1.5 -- отброс не считается читом
	S.stunUntil = math.max(S.stunUntil or 0, os.clock() + seconds)
	setPose(S, pose or "stun", seconds)
	updateSpeed(S)
end

-- ── Сканер ──────────────────────────────────────────────────
Ctx.actions.scan = function(S)
	local d = S.data
	if d.energy < Game.SCAN_COST then
		return false, "msg.noEnergy"
	end
	local pool = {}
	for _, B in Ctx.bases do
		if B.kind ~= "empty" and B.index ~= S.base and B.data then
			table.insert(pool, B)
		end
	end
	if #pool == 0 then
		return false, "msg.noTargets"
	end
	d.energy -= Game.SCAN_COST
	if d.energy < Game.ENERGY_MAX and d.energyT > os.time() then
		d.energyT = os.time()
	end
	Ctx.mark(S, "energy")
	local n = if S.passes.ScannerPlus then Game.SCAN_COUNT_PLUS else Game.SCAN_COUNT
	local out = {}
	S.scanned = {}
	while #pool > 0 and #out < n do
		local B = table.remove(pool, math.random(1, #pool))
		S.scanned[B.index] = os.clock()
		table.insert(out, {
			index = B.index,
			name = B.ownerName,
			kind = B.kind,
			defense = Bases.defenseLevel(B),
			loot = Bases.lootValue(B),
			wall = B.data.wall,
			shield = Bases.shielded(B),
		})
	end
	d.stats.scans = (d.stats.scans or 0) + 1
	if api.quest then
		api.quest(S, "scan", 1)
	end
	Ctx.track(S, "scan", #out)
	return true, nil, out
end

Ctx.actions.invade = function(S, args)
	if not Ctx.isInt(args.index, 1, Game.PLOTS) then
		return false, "msg.bad"
	end
	local t = S.scanned and S.scanned[args.index]
	if not t or os.clock() - t > 180 then
		return false, "msg.scanFirst"
	end
	if S.carry then
		return false, "msg.busy"
	end
	local B = Ctx.bases[args.index]
	local r = Ctx.root(S)
	if not r or B.kind == "empty" then
		return false, "msg.bad"
	end
	S.raid = { base = B.index, t0 = os.clock() }
	S.serverMoved = true
		r.CFrame = Bases.frontPoint(B)
	Ctx.mark(S, "raid")
	Ctx.track(S, "raid_start", B.index)
	return true, nil
end

-- ── Тревога владельцу ───────────────────────────────────────
local function alarmOwner(B: any, thief: any, key: string)
	local owner = B.S
	if not owner then
		return
	end
	if perks(thief).silent then
		return
	end
	local now = os.clock()
	B.alarmT = B.alarmT or 0
	if now - B.alarmT < 15 then
		return
	end
	B.alarmT = now
	local anon = thief.passes and thief.passes.ScannerPlus
	Ctx.popup(owner, "alarm", { key = key, thief = if anon then "" else Ctx.displayName(thief), base = B.index })
	Ctx.fx("alarm", nil, { base = B.index }, owner.player)
end

-- сколько соклановцев вора уже на этой базе (включая его)
local function clanOnBase(S: any, B: any): number
	if not S.data or S.data.clan == "" then
		return 1
	end
	local n = 0
	for _, o in actors() do
		if o.data and o.data.clan == S.data.clan then
			local r = Ctx.root(o)
			if r and Bases.inside(B, r.Position, 6) then
				n += 1
			end
		end
	end
	return math.max(1, n)
end

-- ── Взлом ───────────────────────────────────────────────────
local function canAct(S: any): boolean
	local now = os.clock()
	if S.stunUntil and S.stunUntil > now then
		return false
	end
	return true
end

-- платим энергию за начало рейда на базу (если не было скана/вторжения)
local function ensureRaid(S: any, B: any): boolean
	if S.raid and S.raid.base == B.index and os.clock() - S.raid.t0 < Game.RAID_TIMEOUT then
		return true
	end
	if S.isBot then
		S.raid = { base = B.index, t0 = os.clock() }
		return true
	end
	if S.revengeBase == B.index then
		S.revengeBase = nil
		S.raid = { base = B.index, t0 = os.clock() }
		Ctx.mark(S, "raid")
		return true
	end
	if S.data.energy < Game.SCAN_COST then
		Ctx.notify(S, "msg.noEnergyRaid", nil, "bad")
		return false
	end
	S.data.energy -= Game.SCAN_COST
	Ctx.mark(S, "energy")
	S.raid = { base = B.index, t0 = os.clock() }
	Ctx.mark(S, "raid")
	Ctx.track(S, "raid_start", B.index)
	return true
end

function M.hack(S: any, baseIndex: any, segName: any)
	if not Ctx.isInt(baseIndex, 1, Game.PLOTS) or not Ctx.isStr(segName, 4) then
		return
	end
	if not canAct(S) or S.carry then
		return
	end
	local now = os.clock()
	if S.toolCdUntil and S.toolCdUntil > now then
		Ctx.notify(S, "msg.toolCd", { s = math.ceil(S.toolCdUntil - now) }, "bad")
		return
	end
	if now - (S.hackT or 0) < Game.HACK_INTERVAL * 0.9 then
		return
	end
	local B = Ctx.bases[baseIndex]
	if not B or B.kind == "empty" or B.index == S.base then
		return
	end
	if B.kind == "online" and B.S and sameClan(S, B.S) then
		return
	end
	if Bases.shielded(B) then
		Ctx.notify(S, "msg.shielded", nil, "bad")
		return
	end
	local seg
	for _, s in B.segs do
		if s.name == segName then
			seg = s
			break
		end
	end
	if not seg or seg.broken then
		return
	end
	local r = Ctx.root(S)
	if not r or distToPart(seg.part, r.Position) > Game.HACK_RANGE then
		return
	end
	local mates = clanOnBase(S, B)
	if mates > Game.CLAN_MAX_ON_BASE then
		Ctx.notify(S, "msg.clanCap", nil, "bad")
		return
	end
	if not ensureRaid(S, B) then
		return
	end
	S.hackT = now
	local tool = Game.TOOLS[S.data and S.data.tool or 1]
	local dmg = tool.dmg
	if mates >= 2 then
		dmg *= 1 + Game.CLAN_HACK_BONUS
	end
	if S.shadow then
		dmg = 0
	end
	setPose(S, "hack", 0.6)
	if api.acEvent then
		api.acEvent(S, "hack")
	end
	local broke = Bases.damage(B, seg, dmg)
	Ctx.fx("hack", seg.part.Position, { tool = tool.id })
	alarmOwner(B, S, "alarm.hack")
	if broke then
		Ctx.fx("wallBreak", seg.part.Position, nil)
		if not S.isBot then
			S.data.stats.hacks = (S.data.stats.hacks or 0) + 1
			if api.quest then
				api.quest(S, "hack", 1)
			end
		end
	end
end

-- ── Перенос добычи ──────────────────────────────────────────
local function attachCarry(S: any, id: string, lvl: number): BasePart?
	local char = Ctx.char(S)
	local root = Ctx.root(S)
	if not char or not root then
		return nil
	end
	local d = Defs.BY_ID[id]
	local size = Defs.RARITY[d.rarity].size
	local scale = math.min(1, 2.2 / size)
	local anchor = Bases.makeAnchor(id, root.CFrame * CFrame.new(0, 3 + size * scale / 2, 0), {
		Kind = "carry",
		Lvl = lvl,
		Scale = scale,
	})
	anchor.Anchored = false
	anchor.Massless = true
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = anchor
	weld.Parent = anchor
	return anchor
end

-- opts: { id, lvl, from = B?, slot?, kind = "pedestal"|"season"|"den", victimS?, victimId?, offline?, bot?,
--         onFail = fn(), onDeliver = fn() -> (ok, reason) }
function M.startCarry(S: any, opts: any): boolean
	local anchor = attachCarry(S, opts.id, opts.lvl or 1)
	if not anchor then
		return false
	end
	opts.anchor = anchor
	opts.t0 = os.clock()
	S.carry = opts
	S.noAttackUntil = os.clock() + Game.CARRY_NO_ATTACK
	local char = Ctx.char(S)
	if char then
		char:SetAttribute("Carry", true)
		char:SetAttribute("CarryFrom", opts.victimId or 0)
	end
	setPose(S, "steal", 0.5)
	task.delay(0.5, function()
		if S.carry == opts then
			setPose(S, "carry")
		end
	end)
	updateSpeed(S)
	if not S.isBot then
		Ctx.mark(S, "carry")
	end
	return true
end

local function endCarry(S: any)
	local c = S.carry
	if not c then
		return
	end
	S.carry = nil
	if c.anchor then
		c.anchor:Destroy()
	end
	local char = Ctx.char(S)
	if char then
		char:SetAttribute("Carry", false)
		char:SetAttribute("CarryFrom", 0)
		char:SetAttribute("Pose", "")
	end
	updateSpeed(S)
	if not S.isBot then
		Ctx.mark(S, "carry", "raid")
	end
end

-- вернуть артефакт хозяину (кража не удалась)
local function restore(c: any)
	if c.from and c.slot then
		c.from.transit[c.slot] = nil
		if c.from.data == c.data then
			Bases.renderArts(c.from)
			Bases.playAnim(c.from.arts[c.slot], "return")
		end
		if c.from.S then
			Ctx.mark(c.from.S, "slots", "income")
		end
	end
	if c.onFail then
		c.onFail()
	end
end

-- провал кражи: поймали дубинкой, ловушка, таймаут, смерть
function M.failCarry(S: any, reason: string, catcher: any?)
	local c = S.carry
	if not c then
		return
	end
	-- купленное не теряется: упал/время вышло — существо всё равно попадает на базу
	if c.kind == "bought" then
		endCarry(S)
		local where
		if api.give then
			_, where = api.give(S, c.id, 1)
		end
		local d = Defs.BY_ID[c.id]
		Ctx.notify(S, if where == "inv" then "msg.boughtInv" else "msg.bought", { name = d and d.name.ru or "" }, "good")
		return
	end
	-- перк «Двойник»: 20% шанс всё равно унести добычу
	if reason == "caught" and perks(S).double and math.random() < 0.2 then
		Ctx.notify(S, "msg.doubleSaved", nil, "gold")
		Ctx.fx("double", Ctx.root(S) and Ctx.root(S).Position, nil)
		return
	end
	endCarry(S)
	restore(c)
	local pos = Ctx.root(S) and Ctx.root(S).Position
	if not S.isBot then
		S.data.energy = math.max(0, S.data.energy - Game.FAIL_ENERGY)
		S.toolCdUntil = os.clock() + Game.FAIL_TOOL_COOLDOWN
		S.data.stats.caught = (S.data.stats.caught or 0) + 1
		if api.titan then
			api.titan(S, Game.TITAN_CAUGHT)
		end
		Ctx.mark(S, "energy", "toolCd")
		Ctx.popup(S, "raidFail", { reason = reason, id = c.id })
		Ctx.track(S, "raid_fail", 0, { reason = reason })
	end
	M.stun(S, Game.CAUGHT_STUN, "caught")
	Ctx.fx("caught", pos, { reason = reason })
	S.raid = nil
	-- награда защитнику
	local defender = catcher or (c.from and c.from.S)
	if defender and not defender.isBot and (catcher or reason == "trap") and c.kind == "pedestal" then
		defender.data.stats.defends = (defender.data.stats.defends or 0) + 1
		if api.titan then
			api.titan(defender, Game.TITAN_DEFEND)
		end
		if api.quest then
			api.quest(defender, "defend", 1)
		end
		if api.passXp then
			api.passXp(defender, Game.XP.defend)
		end
		if api.checkAch then
			api.checkAch(defender)
		end
		Ctx.mark(defender, "stats")
		Ctx.popup(defender, "defended", { id = c.id, thief = Ctx.displayName(S) })
	end
end

-- добыча донесена до своей базы
local function deliver(S: any)
	local c = S.carry
	if not c then
		return
	end
	if c.kind == "bought" then
		endCarry(S)
		local where
		if api.give then
			_, where = api.give(S, c.id, 1)
		end
		local d = Defs.BY_ID[c.id]
		Ctx.fx("escape", Ctx.root(S) and Ctx.root(S).Position, { id = c.id })
		Ctx.notify(S, if where == "inv" then "msg.boughtInv" else "msg.bought", { name = d and d.name.ru or "" }, "good")
		return
	end
	local ok, why = true, nil
	if c.onDeliver then
		ok, why = c.onDeliver()
	end
	endCarry(S)
	local pos = Ctx.root(S) and Ctx.root(S).Position
	if not ok then
		restore(c)
		local comp = math.floor(Ctx.price(c.id, c.lvl) * Game.OFFLINE_CANCEL_COMP)
		if not S.isBot and comp > 0 and api.addCash then
			api.addCash(S, comp, "comp")
		end
		Ctx.popup(S, "stealCancelled", { reason = why or "gone", cash = comp })
		return
	end
	-- снять с базы жертвы окончательно
	if c.from and c.slot then
		c.from.transit[c.slot] = nil
		if c.data and c.data.slots[tostring(c.slot)] and c.data.slots[tostring(c.slot)].id == c.id then
			c.data.slots[tostring(c.slot)] = nil
		end
		if c.from.data == c.data then
			Bases.renderArts(c.from)
		end
		if c.from.S then
			Ctx.mark(c.from.S, "slots", "income")
			if api.titan then
				api.titan(c.from.S, 0)
			end
		end
	end
	Ctx.fx("escape", pos, { id = c.id })
	if S.isBot then
		if S.onDeliver then
			S.onDeliver(c)
		end
		return
	end
	if api.give then
		api.give(S, c.id, c.lvl)
	end
	local d = Defs.BY_ID[c.id]
	local rarity = d and d.rarity or "common"
	local reward = 0
	if c.clanRaid then
		reward = math.floor(Ctx.price(c.id, c.lvl) * Game.CLAN_REWARD_BONUS)
		if api.addCash then
			api.addCash(S, reward, "clanRaid")
		end
	end
	S.data.stats.steals = (S.data.stats.steals or 0) + 1
	if api.titan then
		local pts = Game.TITAN_STEAL[rarity] or 10
		api.titan(S, if c.clanRaid then math.floor(pts * (1 + Game.CLAN_REWARD_BONUS)) else pts)
	end
	if api.clanPoints then
		api.clanPoints(S, Game.TITAN_STEAL[rarity] or 10)
	end
	if api.quest then
		api.quest(S, "steal", 1)
	end
	if api.passXp then
		api.passXp(S, Game.XP.steal)
	end
	if api.checkAch then
		api.checkAch(S)
	end
	Ctx.mark(S, "stats")
	S.raid = nil
	Ctx.popup(S, "stealOk", { id = c.id, lvl = c.lvl, bonus = reward })
	Ctx.track(S, "raid_success", Ctx.rarityIndex(c.id), { id = c.id })
	if c.kind == "pedestal" and c.victimS and not c.victimS.isBot then
		Ctx.popup(c.victimS, "robbed", { id = c.id, thief = if S.passes.ScannerPlus then "" else S.player.DisplayName, thiefId = S.player.UserId })
	end
	if api.afterSteal then
		api.afterSteal(S, c)
	end
end

-- ── Кража с пьедестала ──────────────────────────────────────
function M.trySteal(S: any, anchor: BasePart)
	if not S or not anchor.Parent then
		return
	end
	local B = Ctx.bases[anchor:GetAttribute("Base")]
	local slot = anchor:GetAttribute("Slot")
	local kind = anchor:GetAttribute("Kind")
	if not B or B.index == S.base then
		return
	end
	if S.carry or not canAct(S) then
		return
	end
	local now = os.clock()
	if now - (S.stealT or 0) < 1.5 then
		return
	end
	S.stealT = now
	if S.toolCdUntil and S.toolCdUntil > now then
		Ctx.notify(S, "msg.toolCd", { s = math.ceil(S.toolCdUntil - now) }, "bad")
		return
	end
	if B.kind == "online" and B.S and sameClan(S, B.S) then
		return
	end
	local r = Ctx.root(S)
	if not r or (r.Position - anchor.Position).Magnitude > Game.STEAL_RANGE + 2 then
		return
	end
	if Bases.shielded(B) then
		Ctx.notify(S, "msg.shielded", nil, "bad")
		return
	end
	if not B.breached or not Bases.inside(B, r.Position) then
		Ctx.notify(S, "msg.needBreach", nil, "bad")
		return
	end
	if clanOnBase(S, B) > Game.CLAN_MAX_ON_BASE then
		Ctx.notify(S, "msg.clanCap", nil, "bad")
		return
	end
	if not S.isBot and api.hasRoom and not api.hasRoom(S) then
		Ctx.notify(S, "msg.noRoomSteal", nil, "bad")
		return
	end
	if S.shadow then
		return -- теневой бан: молча ничего не происходит
	end
	if api.acEvent then
		api.acEvent(S, "steal")
	end
	-- ложный артефакт
	if kind == "decoy" then
		if M.onDecoy then
			M.onDecoy(S, B, anchor)
		end
		return
	end
	if kind ~= "pedestal" or not slot or B.transit[slot] then
		return
	end
	local art = B.data and B.data.slots[tostring(slot)]
	if not art or art.id ~= anchor:GetAttribute("Id") then
		return
	end
	if not ensureRaid(S, B) then
		return
	end
	Bases.playAnim(anchor, "stolen")
	B.transit[slot] = S
	local victimS = B.S
	local opts = {
		id = art.id,
		lvl = art.lvl,
		from = B,
		slot = slot,
		data = B.data,
		kind = "pedestal",
		victimS = victimS,
		victimId = B.ownerId,
		clanRaid = clanOnBase(S, B) >= 2,
	}
	if B.kind == "offline" then
		local victimId = B.ownerId
		opts.onDeliver = function()
			if S.isBot then
				return false, "bot"
			end
			local taken, why = Profiles.takeFromOffline(victimId, slot, art.id, S.player.DisplayName)
			Profiles.logTheft({ thief = S.player.UserId, victim = victimId, id = art.id, slot = slot, ok = taken ~= nil, why = why, offline = true })
			if not taken then
				return false, why
			end
			if why == nil and M.onOfflineTaken then
				M.onOfflineTaken(B)
			end
			return true, nil
		end
	elseif B.kind == "online" and victimS then
		opts.onDeliver = function()
			if victimS.player and victimS.player.Parent == Players and victimS.B == B then
				Profiles.logTheft({ thief = Ctx.uid(S), victim = B.ownerId, id = art.id, slot = slot, ok = true })
				return true, nil
			end
			return false, "left"
		end
	end
	task.delay(0.35, function()
		if B.transit[slot] ~= S then
			return
		end
		Bases.renderArts(B)
		if victimS then
			Ctx.mark(victimS, "slots", "income")
		end
		if not M.startCarry(S, opts) then
			B.transit[slot] = nil
			Bases.renderArts(B)
			return
		end
		Ctx.fx("steal", anchor.Position, { id = art.id })
		alarmOwner(B, S, "alarm.steal")
		if victimS and not victimS.isBot then
			Ctx.fx("chase", nil, { thief = Ctx.uid(S), role = "owner" }, victimS.player)
		end
		if S.player then
			Ctx.fx("chase", nil, { thief = Ctx.uid(S), role = "thief" }, S.player)
		end
	end)
end

-- хозяин уходит из игры: все переносы его артефактов отменяются (его сохранение не тронуто)
function M.onOwnerLeaving(B: any)
	for _, S in actors() do
		local c = S.carry
		if c and c.from == B then
			c.onFail = nil
			endCarry(S)
			c.from.transit[c.slot] = nil
			local comp = math.floor(Ctx.price(c.id, c.lvl) * Game.OFFLINE_CANCEL_COMP)
			if not S.isBot and comp > 0 and api.addCash then
				api.addCash(S, comp, "comp")
			end
			Ctx.popup(S, "stealCancelled", { reason = "left", cash = comp })
		end
	end
	table.clear(B.transit)
end

-- ── Дубинка ─────────────────────────────────────────────────
function M.bat(S: any, targetId: any)
	if not canAct(S) then
		return
	end
	local now = os.clock()
	if now - (S.batT or 0) < Game.BAT_COOLDOWN then
		return
	end
	if S.carry and now < (S.noAttackUntil or 0) then
		return
	end
	local r = Ctx.root(S)
	if not r then
		return
	end
	S.batT = now
	setPose(S, "bat", 0.45)
	Ctx.fx("bat", r.Position, { by = Ctx.uid(S) })
	-- цель: указанная клиентом (проверяем) или ближайшая
	local best, bestD = nil, Game.BAT_RANGE
	for _, T in actors() do
		if T ~= S then
			local tr = Ctx.root(T)
			if tr then
				local dist = (tr.Position - r.Position).Magnitude
				local wanted = targetId == nil or Ctx.uid(T) == targetId
				if dist <= bestD and wanted then
					best, bestD = T, dist
				end
			end
		end
	end
	if not best then
		return
	end
	local T = best
	local c = T.carry
	if c then
		local isOwner = c.victimId == Ctx.uid(S)
		local ownerMate = c.victimS and sameClan(S, c.victimS)
		local botGuard = S.isBot and S.B and c.from == S.B
		if c.kind == "season" or isOwner or ownerMate or botGuard then
			M.failCarry(T, "caught", S)
			if api.acEvent then
				api.acEvent(S, "bat")
			end
			return
		end
	end
	-- чужой на моей базе — выталкиваем
	local myB = S.B
	local tr = Ctx.root(T)
	if myB and tr and Bases.inside(myB, tr.Position, 2) and T.base ~= myB.index then
		local away = (tr.Position - myB.cf.Position) * Vector3.new(1, 0, 1)
		if away.Magnitude < 1 then
			away = Vector3.new(0, 0, 1)
		end
		tr.AssemblyLinearVelocity = away.Unit * 70 + Vector3.new(0, 35, 0)
		M.stun(T, Game.PUSH_STUN, "hit")
		Ctx.fx("hit", tr.Position, nil)
	end
end

-- ── Замок ───────────────────────────────────────────────────
-- замок включается только кнопкой на своей базе (касание ногой)
function M.lock(S: any): (boolean, string?)
	local B = S.B
	if not B then
		return false, "msg.bad"
	end
	if (S.lockCdUntil or 0) > Ctx.now() then
		return false, "msg.lockCd"
	end
	local secs = Bases.lockSeconds(B)
	Bases.setShield(B, secs)
	S.lockCdUntil = Ctx.now() + secs + Game.LOCK_COOLDOWN
	-- кнопка серая, пока замок на перезарядке
	local lb = B.model:FindFirstChild("LockButton")
	local btn = lb and lb:FindFirstChild("Button")
	local function paint(c: Color3)
		if btn then
			btn.Color = c
		end
		local skin = lb and lb:FindFirstChild("Skin")
		local mb = skin and skin:FindFirstChild("Button", true)
		if mb and mb:IsA("BasePart") then
			mb.Color = c
		end
	end
	local skinM = lb and lb:FindFirstChild("Skin")
	if skinM then
		skinM:SetAttribute("PressedAt", workspace:GetServerTimeNow())
	end
	if btn then
		paint(Color3.fromHex("#9A93AD"))
		local stamp = S.lockCdUntil
		task.spawn(function()
			local label = btn:FindFirstChild("Tag") and btn.Tag:FindFirstChild("Text")
			while S.lockCdUntil == stamp and Ctx.now() < stamp and btn.Parent do
				if label then
					local left = math.ceil(stamp - Ctx.now())
					label.Text = if B.shieldUntil > Ctx.now() then "🛡️ " .. math.ceil(B.shieldUntil - Ctx.now()) else "⏳ " .. left
				end
				task.wait(1)
			end
			paint(Color3.fromHex("#FFC93C"))
			if label then
				label.Text = "🔒 ЗАМОК"
			end
		end)
	end
	Ctx.mark(S, "lock")
	Ctx.fx("lock", B.cf.Position, { base = B.index })
	if api.tutorialEvent then
		api.tutorialEvent(S, "lock")
	end
	return true, nil
end

local function hookLockButtons()
	for _, B in Ctx.bases do
		local lb = B.model:FindFirstChild("LockButton")
		local btn = lb and lb:FindFirstChild("Button")
		if btn then
			local last = {}
			btn.Touched:Connect(function(hit)
				local player = Players:GetPlayerFromCharacter(hit.Parent)
				local S = player and Ctx.session(player)
				if not S or not S.ready or S.B ~= B then
					return
				end
				if last[player] and os.clock() - last[player] < 2 then
					return
				end
				last[player] = os.clock()
				local ok, msg = M.lock(S)
				if not ok and msg == "msg.lockCd" then
					local left = math.ceil((S.lockCdUntil or 0) - Ctx.now())
					Ctx.notify(S, "msg.lockCdS", { s = left }, "bad")
				end
			end)
		end
	end
end

-- месть: бесплатный рейд на базу обидчика, если он на этом сервере
Ctx.actions.revenge = function(S, args)
	if not Ctx.isNum(args.thiefId) then
		return false, "msg.bad"
	end
	for _, B in Ctx.bases do
		if B.ownerId == args.thiefId and B.kind ~= "empty" then
			local r = Ctx.root(S)
			if r and not S.carry then
				S.revengeBase = B.index
				S.scanned = S.scanned or {}
				S.scanned[B.index] = os.clock()
				S.serverMoved = true
		r.CFrame = Bases.frontPoint(B)
				return true, "msg.revengeGo"
			end
		end
	end
	return false, "msg.thiefGone"
end

-- ── Ловушки ─────────────────────────────────────────────────
local function trapPos(B: any, slot: number): Vector3?
	local pad = B.model.Traps:FindFirstChild("T" .. slot)
	return pad and pad.Position
end

local function trapHit(S: any, B: any, slot: number, t: any)
	local cfg = Game.TRAPS[t.k]
	local pos = trapPos(B, slot)
	B.traps[slot] = { armedAt = os.clock() + cfg.rearm }
	if M.setArmed then
		M.setArmed(B, slot, false)
		task.delay(cfg.rearm, function()
			M.setArmed(B, slot, true)
		end)
	end
	Ctx.fx("trap", pos, { kind = t.k, skin = B.data and B.data.trapSkin or "" })
	local tr = Ctx.root(S)
	if tr and pos then
		local away = (tr.Position - pos) * Vector3.new(1, 0, 1)
		if away.Magnitude < 0.5 then
			away = Vector3.new(1, 0, 0)
		end
		tr.AssemblyLinearVelocity = away.Unit * 45 + Vector3.new(0, 45, 0)
	end
	M.stun(S, cfg.stun[t.l] or 1.5, "trap")
	if S.carry and S.carry.from == B then
		M.failCarry(S, "trap", nil)
	end
end

function M.onDecoy(S: any, B: any, anchor: BasePart)
	local slot = anchor:GetAttribute("TrapSlot")
	local t = B.data and slot and B.data.traps[tostring(slot)]
	Bases.playAnim(anchor, "stolen")
	Ctx.fx("trap", anchor.Position, { kind = "decoy" })
	local cfg = Game.TRAPS.decoy
	M.stun(S, cfg.stun[t and t.l or 1] or 2.5, "caught")
	if not S.isBot then
		S.data.energy = math.max(0, S.data.energy - Game.FAIL_ENERGY)
		Ctx.mark(S, "energy")
		Ctx.popup(S, "raidFail", { reason = "decoy" })
		Ctx.track(S, "raid_fail", 0, { reason = "decoy" })
	end
	S.raid = nil
	if B.S then
		Ctx.popup(B.S, "defended", { id = "", thief = Ctx.displayName(S), decoy = true })
		if api.quest then
			api.quest(B.S, "defend", 1)
		end
	end
	if anchor.Parent then
		anchor.Parent = nil
		task.delay(cfg.rearm, function()
			if B.data and slot and B.data.traps[tostring(slot)] then
				anchor.Parent = workspace:FindFirstChild("Arts")
			else
				anchor:Destroy()
			end
		end)
	end
end

-- визуал/логика ловушки при перерисовке базы
function Bases.onTrap(B: any, slot: number, kind: string?, t: any)
	B.decoys = B.decoys or {}
	local old = B.decoys[slot]
	if kind ~= "decoy" and old then
		old:Destroy()
		B.decoys[slot] = nil
	end
	-- высота подставки: 3D-модель ложного пьедестала или старый цилиндр
	local function decoyLift(size: number): Vector3
		local pad = B.model.Traps:FindFirstChild("T" .. slot)
		local h = 1
		local vis = pad and pad:FindFirstChild("Vis")
		local m = vis and vis:FindFirstChildWhichIsA("Model")
		if m then
			h = pad.Size.Y / 2 + m:GetExtentsSize().Y
		end
		return Vector3.new(0, h + size / 2 + 0.1, 0)
	end
	if kind == "decoy" and old then
		local pos = trapPos(B, slot)
		local size = old.Size.Y
		if pos then
			old.CFrame = CFrame.new(pos + decoyLift(size))
		end
	end
	if kind == "decoy" and not old then
		local pos = trapPos(B, slot)
		if pos then
			local id = api.randomOf and api.randomOf(if math.random() < 0.5 then "rare" else "epic") or "c_drop"
			local d = Defs.BY_ID[id]
			local size = d and Defs.RARITY[d.rarity].size or 2
			local anchor = Bases.makeAnchor(id, CFrame.new(pos + decoyLift(size)), {
				Kind = "decoy",
				Owner = B.ownerId,
				Base = B.index,
				TrapSlot = slot,
			})
			M.addStealPrompt(anchor)
			B.decoys[slot] = anchor
		end
	end
	if not kind then
		B.traps[slot] = nil
	end
end

-- проверка ловушек и замедляющих полей (10 раз в секунду)
local function trapLoop()
	local now = os.clock()
	for _, B in Ctx.bases do
		local data = B.data
		if data and B.kind ~= "empty" and next(data.traps) then
			for _, S in actors() do
				if S.base ~= B.index and not (B.S and sameClan(S, B.S)) then
					local r = Ctx.root(S)
					if r and Bases.inside(B, r.Position) then
						for key, t in data.traps do
							local slot = tonumber(key)
							if slot and not t.b and t.k ~= "decoy" then
								local pos = trapPos(B, slot)
								if pos then
									local cfg = Game.TRAPS[t.k]
									local flat = (r.Position - pos) * Vector3.new(1, 0, 1)
									local radius = cfg.radius[t.l] or 5
									if flat.Magnitude <= radius and math.abs(r.Position.Y - pos.Y) < 8 then
										if t.k == "slow" then
											S.slowUntil = now + 0.4
										elseif t.k == "mine" then
											local st = B.traps[slot]
											if not st or st.armedAt <= now then
												trapHit(S, B, slot, t)
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

-- ── Подсказки на якорях ─────────────────────────────────────
function M.addStealPrompt(anchor: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Steal"
	prompt:SetAttribute("Role", "steal")
	prompt.ActionText = "Украсть"
	prompt.HoldDuration = Game.STEAL_HOLD
	prompt.MaxActivationDistance = Game.STEAL_RANGE
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		local S = Ctx.session(player)
		if S and S.ready then
			M.trySteal(S, anchor)
		end
	end)
end

function Bases.onAnchor(B: any, slot: number, anchor: BasePart)
	M.addStealPrompt(anchor)
	local manage = Instance.new("ProximityPrompt")
	manage.Name = "Manage"
	manage:SetAttribute("Role", "manage")
	manage.ActionText = "Управлять"
	manage.HoldDuration = 0
	manage.MaxActivationDistance = 10
	manage.RequiresLineOfSight = false
	manage.KeyboardKeyCode = Enum.KeyCode.R
	manage.Parent = anchor
	-- открытие окна — на клиенте (сервер проверяет каждое действие отдельно)
end

-- ── Дубинка-предмет ─────────────────────────────────────────
function M.makeBat(): Tool
	local tool = Instance.new("Tool")
	tool.Name = "Дубинка"
	tool.ToolTip = "Ударь вора — артефакт вернётся"
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, -1.2, 0)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = Enum.PartType.Cylinder
	handle.Size = Vector3.new(4, 0.6, 0.6)
	handle.Color = Color3.fromHex("#C98B4F")
	handle.Material = Enum.Material.Wood
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	-- цилиндр лежит по оси X: поворачиваем рукоять вдоль руки
	tool.GripForward = Vector3.new(0, 0, -1)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(1, 0, 0)
	tool.GripPos = Vector3.new(-1.2, 0, 0)
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1.3, 1.3, 1.3)
	head.Color = Color3.fromHex("#FFC93C")
	head.Material = Enum.Material.SmoothPlastic
	head.CanCollide = false
	head.Massless = true
	head.CFrame = handle.CFrame * CFrame.new(2, 0, 0)
	head.Parent = tool
	local band = head:Clone()
	band.Name = "Band"
	band.Shape = Enum.PartType.Cylinder
	band.Size = Vector3.new(0.35, 0.8, 0.8)
	band.Color = Color3.fromHex("#2A2140")
	band.CFrame = handle.CFrame * CFrame.new(-1.6, 0, 0)
	band.Parent = tool
	for _, p in { head, band } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = handle
		w.Part1 = p
		w.Parent = p
	end
	-- 3D-модель дубинки (если загружена): рукоять невидима, детали модели приварены к ней
	local club = ModelLib.get("club")
	if club then
		handle.Transparency = 1
		head:Destroy()
		band:Destroy()
		-- низ модели у конца рукояти, ось Y модели — вдоль оси X рукояти
		club:PivotTo(handle.CFrame * CFrame.new(-2, 0, 0) * CFrame.Angles(0, 0, -math.pi / 2))
		for _, p in club:GetDescendants() do
			if p:IsA("BasePart") then
				p.Anchored = false
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
				p.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = p
				w.Parent = p
			end
		end
		club.Parent = tool
	end
	return tool
end

function M.giveBat(S: any)
	local player = S.player
	if not player then
		return
	end
	local bp = player:FindFirstChildOfClass("Backpack")
	if not bp or bp:FindFirstChild("Дубинка") then
		return
	end
	local char = player.Character
	if char and char:FindFirstChild("Дубинка") then
		return
	end
	local tool = M.makeBat()
	-- замах: дубинка наклоняется из «вверх» вперёд перед собой и возвращается (Grip реплицируется всем)
	local baseGrip = tool.Grip
	local swinging = false
	local function swing()
		if swinging then
			return
		end
		swinging = true
		local fwd = baseGrip * CFrame.Angles(math.rad(95), 0, 0)
		for i = 1, 4 do
			tool.Grip = baseGrip:Lerp(fwd, i / 4)
			task.wait(0.03)
		end
		task.wait(0.12)
		for i = 1, 6 do
			tool.Grip = fwd:Lerp(baseGrip, i / 6)
			task.wait(0.03)
		end
		tool.Grip = baseGrip
		swinging = false
	end
	tool.Activated:Connect(function()
		task.spawn(swing)
		local s = Ctx.session(player)
		if s and s.ready then
			M.bat(s, nil)
		end
	end)
	tool.Parent = bp
	-- модель дубинки ещё грузится: когда загрузится — заменить дубинку на 3D-версию
	if not ModelLib.has("club") then
		task.spawn(function()
			ModelLib.wait(180)
			if not ModelLib.has("club") or not tool.Parent then
				return
			end
			local equipped = tool.Parent == player.Character
			tool:Destroy()
			M.giveBat(S)
			if equipped then
				local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local nt = bp:FindFirstChild("Дубинка")
				if hum and nt then
					hum:EquipTool(nt)
				end
			end
		end)
	end
end

-- купленное с конвейера: нести домой (кражей не считается, отнять нельзя)
api.carryBought = function(S: any, id: string): boolean
	if S.carry or S.isBot then
		return false
	end
	return M.startCarry(S, { id = id, lvl = 1, kind = "bought" })
end

-- ── Главный цикл рейдов ─────────────────────────────────────
local function carryLoop()
	local now = os.clock()
	for _, S in actors() do
		local c = S.carry
		if c then
			local r = Ctx.root(S)
			local hum = Ctx.humanoid(S)
			if not r or not hum or hum.Health <= 0 or r.Position.Y < -50 then
				M.failCarry(S, "fell", nil)
			elseif now - c.t0 > Game.CARRY_TIMEOUT then
				M.failCarry(S, "timeout", nil)
			elseif S.B and Bases.inside(S.B, r.Position) then
				deliver(S)
			end
		end
		if S.raid and now - S.raid.t0 > Game.RAID_TIMEOUT and not S.carry then
			S.raid = nil
			if not S.isBot then
				Ctx.mark(S, "raid")
			end
		end
		updateSpeed(S)
	end
end

function M.init()
	hookLockButtons()
	Ctx.doActions.hack = function(S, args)
		if type(args) == "table" then
			M.hack(S, args.base, args.seg)
		end
	end
	Ctx.doActions.bat = function(S, args)
		M.bat(S, type(args) == "table" and args.target or nil)
	end
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(carryLoop)
			if not ok then
				warn("[Raid] перенос:", err)
			end
			ok, err = pcall(trapLoop)
			if not ok then
				warn("[Raid] ловушки:", err)
			end
		end
	end)
end

api.startCarry = M.startCarry
api.failCarry = M.failCarry
api.stun = M.stun
api.setPose = setPose
api.onOwnerLeaving = M.onOwnerLeaving
api.addStealPrompt = M.addStealPrompt
api.trySteal = M.trySteal
api.hack = M.hack
api.bat = M.bat
api.giveBat = M.giveBat
api.actors = actors

return M
