--!strict
-- Сетевые каналы. Сервер создаёт их при запуске, клиент ждёт.
--   Act    RemoteFunction  клиент → сервер: действие с ответом (ok, ключ сообщения, данные)
--   Do     RemoteEvent     клиент → сервер: частые действия (взлом, удар)
--   State  RemoteEvent     сервер → клиент: частичный снимок личного состояния
--   Notify RemoteEvent     сервер → клиент: тост (ключ перевода, аргументы, вид)
--   Popup  RemoteEvent     сервер → клиент: большое окно (тип, данные)
--   Fx     RemoteEvent     сервер → клиенты: эффект/звук (тип, позиция, данные)
--   Board  RemoteEvent     сервер → клиент: лидерборды
--   Trade  RemoteEvent     сервер → клиент: окно обмена

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES: { [string]: string } = {
	Act = "RemoteFunction",
	Do = "RemoteEvent",
	State = "RemoteEvent",
	Notify = "RemoteEvent",
	Popup = "RemoteEvent",
	Fx = "RemoteEvent",
	Board = "RemoteEvent",
	Trade = "RemoteEvent",
}

local M = {}

local folder: Folder

if RunService:IsServer() then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for name, class in NAMES do
		local r = Instance.new(class)
		r.Name = name
		r.Parent = folder
	end
	folder.Parent = ReplicatedStorage
else
	local f = ReplicatedStorage:WaitForChild("Remotes", 60)
	assert(f, "Remotes не пришли с сервера")
	folder = f :: Folder
end

function M.fn(name: string): RemoteFunction
	local r = folder:WaitForChild(name, 30)
	assert(r and r:IsA("RemoteFunction"), name)
	return r
end

function M.event(name: string): RemoteEvent
	local r = folder:WaitForChild(name, 30)
	assert(r and r:IsA("RemoteEvent"), name)
	return r
end

return M
