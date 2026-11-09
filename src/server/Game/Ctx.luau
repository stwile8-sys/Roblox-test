--!nonstrict
-- Общий контекст сервера: сессии игроков, базы, отправка состояния, тосты, эффекты.
-- Системы (Bases, Economy, Raid, …) кладут сюда свои функции, чтобы не было циклических require.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Game = require(ReplicatedStorage.Shared.Config.Game)
local Defs = require(ReplicatedStorage.Shared.Art.Defs)

local M: any = {}

M.Game = Game
M.Defs = Defs

M.sessions = {} :: { [Player]: any } -- игрок → сессия
M.bases = {} :: { [number]: any } -- индекс → база
M.actions = {} :: { [string]: (any, any) -> (boolean, string?, any) }
M.doActions = {} :: { [string]: (any, any) -> () }
M.views = {} :: { [string]: (any) -> any } -- ключ состояния → функция вида
M.api = {} -- функции систем: M.api.addCash(S, n, src) и т.д.

local stateEv = Net.event("State")
local notifyEv = Net.event("Notify")
local popupEv = Net.event("Popup")
local fxEv = Net.event("Fx")

-- ── Сессии ──────────────────────────────────────────────────
function M.session(p: Player): any
	return M.sessions[p]
end

function M.each(fn: (any) -> ())
	for _, S in M.sessions do
		if S.ready then
			fn(S)
		end
	end
end

-- ── Состояние для клиента ───────────────────────────────────
function M.mark(S: any, ...: string)
	if not S then
		return
	end
	for _, k in { ... } do
		S.dirty[k] = true
	end
end

function M.markAll(S: any)
	for k in M.views do
		S.dirty[k] = true
	end
end

function M.flush(S: any)
	if not S.ready or next(S.dirty) == nil then
		return
	end
	local out = {}
	for k in S.dirty do
		local view = M.views[k]
		if view then
			local ok, v = pcall(view, S)
			if ok then
				out[k] = if v == nil then false else v
			else
				warn("[State] вид", k, v)
			end
		end
	end
	table.clear(S.dirty)
	stateEv:FireClient(S.player, out)
end

task.spawn(function()
	while true do
		task.wait(0.2)
		for _, S in M.sessions do
			M.flush(S)
		end
	end
end)

-- ── Сообщения ───────────────────────────────────────────────
-- kind: "info" | "good" | "bad" | "gold"
function M.notify(target: any, key: string, args: { [string]: any }?, kind: string?)
	local p = if typeof(target) == "Instance" then target else target and target.player
	if p and p.Parent == Players and not p:GetAttribute("Bot") then
		notifyEv:FireClient(p, key, args or {}, kind or "info")
	end
end

function M.popup(target: any, kind: string, data: { [string]: any }?)
	local p = if typeof(target) == "Instance" then target else target and target.player
	if p and p.Parent == Players and not p:GetAttribute("Bot") then
		popupEv:FireClient(p, kind, data or {})
	end
end

-- эффект всем (или одному игроку, если указан)
function M.fx(kind: string, pos: Vector3?, data: { [string]: any }?, only: Player?)
	if only then
		if only.Parent == Players then
			fxEv:FireClient(only, kind, pos, data or {})
		end
	else
		fxEv:FireAllClients(kind, pos, data or {})
	end
end

-- ── Ограничение частоты ─────────────────────────────────────
-- true, если действие разрешено (не чаще perSec в секунду, с небольшим запасом)
function M.rate(S: any, name: string, perSec: number): boolean
	local now = os.clock()
	local r = S.rates[name]
	if not r then
		r = { t = now, n = 0 }
		S.rates[name] = r
	end
	if now - r.t >= 1 then
		r.t = now
		r.n = 0
	end
	r.n += 1
	if r.n > perSec then
		if M.api.suspect then
			M.api.suspect(S, "spam:" .. name, 1)
		end
		return false
	end
	return true
end

-- ── Проверка аргументов ─────────────────────────────────────
function M.isNum(v: any, lo: number?, hi: number?): boolean
	if type(v) ~= "number" or v ~= v or math.abs(v) == math.huge then
		return false
	end
	if lo and v < lo then
		return false
	end
	if hi and v > hi then
		return false
	end
	return true
end

function M.isInt(v: any, lo: number, hi: number): boolean
	return M.isNum(v, lo, hi) and math.floor(v) == v
end

function M.isStr(v: any, maxLen: number): boolean
	return type(v) == "string" and #v <= maxLen and utf8.len(v) ~= nil
end

-- ── Персонаж ────────────────────────────────────────────────
-- персонаж игрока или бота (у бота S.char — модель NPC)
function M.char(p: any): any
	if type(p) == "table" and p.char then
		return p.char
	end
	local plr = if typeof(p) == "Instance" then p else p and p.player
	return plr and plr.Character
end

function M.root(p: any): any
	local char = M.char(p)
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return if r and r:IsA("BasePart") then r else nil
end

function M.humanoid(p: any): Humanoid?
	local char = M.char(p)
	return char and char:FindFirstChildOfClass("Humanoid")
end

function M.uid(S: any): number
	return if S.player then S.player.UserId else (S.botId or 0)
end

function M.displayName(S: any): string
	return if S.player then S.player.DisplayName else (S.botName or "Bot")
end

function M.now(): number
	return workspace:GetServerTimeNow()
end

-- ── Артефакты ───────────────────────────────────────────────
function M.def(id: string): any
	return Defs.BY_ID[id]
end

function M.price(id: string, lvl: number?): number
	local d = Defs.BY_ID[id]
	if not d then
		return 0
	end
	local base = d.income * (Game.PRICE_MULT[d.rarity] or 20)
	return math.floor(base * (1 + 0.5 * ((lvl or 1) - 1)))
end

function M.artIncome(id: string, lvl: number): number
	local d = Defs.BY_ID[id]
	if not d then
		return 0
	end
	return d.income * (1 + Game.ART_LVL_BONUS * (lvl - 1))
end

function M.rarityIndex(id: string): number
	local d = Defs.BY_ID[id]
	return if d then Defs.RARITY[d.rarity].index else 0
end

-- аналитика (заглушка до подключения Analytics)
function M.track(S: any, event: string, value: number?, extra: { [string]: any }?)
	if M.api.track then
		M.api.track(S, event, value, extra)
	end
end

return M
