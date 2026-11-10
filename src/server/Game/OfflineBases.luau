--!nonstrict
-- Офлайн-базы: свободные участки сервера занимают базы недавно игравших, которые сейчас не в игре.
-- Их можно ограбить: кража атомарно списывается из сохранения владельца (Profiles.takeFromOffline),
-- если он в этот момент не зашёл в игру. Не больше Game.OFFLINE_STEAL_LIMIT артефактов за отлучку.

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)
local Profiles = require(script.Parent.Parent.Data.Profiles)

local Game = Ctx.Game
local api = Ctx.api

local M: any = {}

local tried: { [number]: number } = {}

local function onServer(userId: number): boolean
	if Players:GetPlayerByUserId(userId) then
		return true
	end
	for _, B in Ctx.bases do
		if B.ownerId == userId then
			return true
		end
	end
	return false
end

local function hasLoot(d: any): boolean
	return next(d.slots) ~= nil and d.offLost < Game.OFFLINE_STEAL_LIMIT
end

function M.fill()
	-- места: пустые острова и острова ботов-соседей (но не меньше 4 ботов, чтобы сервер был живым)
	local empty, fillers = {}, {}
	for _, B in Ctx.bases do
		if not B.reserved then
			if B.kind == "empty" then
				table.insert(empty, B)
			elseif B.kind == "bot" and B.filler then
				table.insert(fillers, B)
			end
		end
	end
	for i = 5, #fillers do
		table.insert(empty, fillers[i])
	end
	if #empty == 0 then
		return
	end
	local list = Profiles.recentPlayers(40)
	for _, entry in list do
		if #empty == 0 then
			break
		end
		local id = entry.id
		if not onServer(id) and os.clock() - (tried[id] or -1e9) > 600 then
			tried[id] = os.clock()
			if not Profiles.isOnline(id) then
				local data, locked = Profiles.peek(id)
				if data and not locked and hasLoot(data) then
					local ok, name = pcall(function()
						return Players:GetNameFromUserIdAsync(id)
					end)
					local B = table.remove(empty, 1)
					if B and (B.kind == "empty" or (B.kind == "bot" and B.filler)) then
						if B.kind == "bot" then
							api.onOwnerLeaving(B)
						end
						Bases.setOffline(B, id, if ok then name else "?", data)
					end
				end
			end
		end
	end
end

-- после успешной офлайн-кражи: если лимит исчерпан, база уходит с сервера
function M.onTaken(B: any)
	B.offlineTaken = (B.offlineTaken or 0) + 1
	if B.data then
		B.data.offLost = (B.data.offLost or 0) + 1
		if B.data.offLost >= Game.OFFLINE_STEAL_LIMIT then
			task.delay(5, function()
				if B.kind == "offline" then
					api.onOwnerLeaving(B)
					Bases.setEmpty(B)
				end
			end)
		end
	end
end

-- раз в минуту: убрать офлайн-базы, чьи владельцы зашли куда-то в игру, и заполнить пустые
function M.init()
	local Raid = require(script.Parent.Raid)
	Raid.onOfflineTaken = M.onTaken
	task.spawn(function()
		task.wait(20)
		while true do
			for _, B in Ctx.bases do
				if B.kind == "offline" and Profiles.isOnline(B.ownerId) then
					api.onOwnerLeaving(B)
					Bases.setEmpty(B)
				end
			end
			pcall(M.fill)
			task.wait(60)
		end
	end)
end

return M
