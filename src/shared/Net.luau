--!strict
-- Имена сетевых каналов. Сервер создаёт их при запуске, клиент ждёт с ограничением по времени.
--   Act      (RemoteFunction) клиент → сервер: действие игрока, ответ (ok, ключ сообщения)
--   State    (RemoteEvent)    сервер → клиент: личное состояние игрока (деньги, склад, город…)
--   Notify   (RemoteEvent)    сервер → клиент: всплывающее сообщение (ключ перевода + аргументы)
--   Summary  (RemoteEvent)    сервер → клиент: сводка «пока вас не было»
--   Market   (RemoteEvent)    сервер → клиент: книга заявок рынка

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES: { [string]: string } = {
	Act = "RemoteFunction",
	State = "RemoteEvent",
	Notify = "RemoteEvent",
	Summary = "RemoteEvent",
	Market = "RemoteEvent",
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
