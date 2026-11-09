--!strict
-- Личное состояние игрока в мире: деньги, склад, отправка состояния клиенту, уведомления.
-- Все изменения денег и предметов идут только через этот модуль.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game.ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Items = require(Shared.Config.Items)
local CityCfg = require(Shared.Config.City)
local Profiles = require(script.Parent.Data.Profiles)

local M = {}

local stateEvent = Net.event("State")
local notifyEvent = Net.event("Notify")

local dirty: { [Player]: boolean } = {}
local ready: { [Player]: boolean } = {}
-- дополнительные части состояния, которые добавляют другие модули (работа, город…)
local extras: { (Player, { [string]: any }) -> () } = {}

function M.data(player: Player): Profiles.Data?
	if not ready[player] then
		return nil
	end
	return Profiles.get(player)
end

function M.setReady(player: Player, value: boolean)
	ready[player] = if value then true else nil :: any
	if value then
		dirty[player] = true
	end
end

function M.isReady(player: Player): boolean
	return ready[player] == true
end

function M.addExtra(fn: (Player, { [string]: any }) -> ())
	table.insert(extras, fn)
end

function M.markDirty(player: Player)
	dirty[player] = true
end

function M.notify(player: Player, key: string, args: { [string]: any }?, kind: string?)
	notifyEvent:FireClient(player, key, args or {}, kind or "info")
end

-- Деньги -----------------------------------------------------------------

function M.money(player: Player): number
	local d = M.data(player)
	return if d then d.money else 0
end

function M.addMoney(player: Player, amount: number)
	local d = M.data(player)
	if not d or amount ~= amount then
		return
	end
	d.money = math.max(0, d.money + amount)
	dirty[player] = true
end

function M.spend(player: Player, amount: number): boolean
	local d = M.data(player)
	if not d or amount ~= amount or amount < 0 then
		return false
	end
	if d.money + 1e-6 < amount then
		return false
	end
	d.money = math.max(0, d.money - amount)
	dirty[player] = true
	return true
end

-- Склад -------------------------------------------------------------------

function M.count(player: Player, item: string): number
	local d = M.data(player)
	return if d then d.items[item] or 0 else 0
end

-- Добавить на склад (с учётом вместимости). Возвращает сколько реально поместилось.
function M.addItem(d: Profiles.Data, item: string, amount: number): number
	if amount <= 0 or not Items.isItem(item) then
		return 0
	end
	local have = d.items[item] or 0
	local fit = math.max(0, math.min(amount, CityCfg.STORAGE - have))
	d.items[item] = have + fit
	return fit
end

function M.removeItem(d: Profiles.Data, item: string, amount: number): boolean
	local have = d.items[item] or 0
	if amount <= 0 or have < amount then
		return false
	end
	local left = have - amount
	d.items[item] = if left > 0 then left else nil :: any
	return true
end

-- Отправка состояния ------------------------------------------------------

local function snapshot(player: Player): { [string]: any }?
	local d = Profiles.get(player)
	if not d then
		return nil
	end
	local s: { [string]: any } = {
		money = math.floor(d.money),
		items = d.items,
		storage = CityCfg.STORAGE,
		plot = d.plot,
		tutorial = d.tutorial,
		badges = d.badges,
		incoming = d.incoming,
		vehicles = d.vehicles,
		prefs = d.prefs,
	}
	for _, fn in extras do
		fn(player, s)
	end
	return s
end

function M.start()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.25 then
			return
		end
		acc = 0
		for player in dirty do
			dirty[player] = nil
			if ready[player] and player.Parent == Players then
				local s = snapshot(player)
				if s then
					stateEvent:FireClient(player, s)
				end
			end
		end
	end)
end

function M.forget(player: Player)
	dirty[player] = nil
	ready[player] = nil
end

return M
