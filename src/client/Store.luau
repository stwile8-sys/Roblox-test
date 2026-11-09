--!nonstrict
-- Последнее состояние игрока с сервера + вызов действий. Интерфейс подписывается на изменения.

local Shared = game.ReplicatedStorage.Shared
local Net = require(Shared.Net)

local M = {}

M.state = nil :: { [string]: any }?
local listeners: { (s: { [string]: any }) -> () } = {}
local act = Net.fn("Act")

function M.on(fn: (s: { [string]: any }) -> ())
	table.insert(listeners, fn)
	if M.state then
		task.spawn(fn, M.state)
	end
end

Net.event("State").OnClientEvent:Connect(function(s)
	M.state = s
	for _, fn in listeners do
		task.spawn(fn, s)
	end
end)

-- Вызвать действие на сервере. Возвращает (ok, ключ сообщения или данные)
function M.act(action: string, ...: any): (boolean, any)
	local ok, a, b = pcall(act.InvokeServer, act, action, ...)
	if not ok then
		return false, "err.net"
	end
	return a == true, b
end

return M
