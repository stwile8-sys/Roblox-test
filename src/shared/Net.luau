--!strict
-- Сетевые каналы. Сервер создаёт их при запуске, клиент ждёт.
--   Act     RemoteFunction клиент → сервер: действие с ответом (ok, сообщение)
--   Land    RemoteEvent    клиент → сервер: приземлился (id полёта, z, колец)
--   State   RemoteEvent    сервер → клиент: снимок личного состояния
--   Launch  RemoteEvent    сервер → клиент: начать полёт (параметры)
--   Result  RemoteEvent    сервер → клиент: итог полёта
--   Notify  RemoteEvent    сервер → клиент: тост (текст, вид)
--   Fx      RemoteEvent    сервер → все: эффект (тип, позиция)
--   Ask     RemoteEvent    сервер → клиент: тебя зовут в тандем (игрок)
--   Race    RemoteEvent    сервер → все: гонка (open / go / none / result)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NAMES: { [string]: string } = {
	Act = "RemoteFunction",
	Land = "RemoteEvent",
	State = "RemoteEvent",
	Launch = "RemoteEvent",
	Result = "RemoteEvent",
	Notify = "RemoteEvent",
	Fx = "RemoteEvent",
	Ask = "RemoteEvent",
	Race = "RemoteEvent",
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
