--!nonstrict
-- Клиентская копия личного состояния (только для показа; всё решает сервер) и вызовы действий.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage:WaitForChild("Shared").Net)
local L = require(ReplicatedStorage.Shared.Lang.L)

local M = {}

M.s = {} :: { [string]: any }
M.boards = { titan = {}, collection = {}, clans = {} }
local listeners: { [string]: { (any) -> () } } = {}

function M.on(key: string, fn: (any) -> ())
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
	if M.s[key] ~= nil then
		task.spawn(fn, M.s[key])
	end
end

local function emit(key: string, v: any)
	for _, fn in listeners[key] or {} do
		task.spawn(fn, v)
	end
end

Net.event("State").OnClientEvent:Connect(function(patch)
	if type(patch) ~= "table" then
		return
	end
	for k, v in patch do
		if v == false then
			v = nil
		end
		M.s[k] = v
		emit(k, v)
	end
	emit("*", patch)
end)

Net.event("Board").OnClientEvent:Connect(function(b)
	if type(b) == "table" then
		M.boards = b
		emit("boards", b)
	end
end)

local act = Net.fn("Act")
local doEv = Net.event("Do")
M.toast = nil :: ((string, string?) -> ())?

-- действие с ответом; ошибки/сообщения показываем тостом
function M.act(name: string, args: { [string]: any }?): (boolean, any)
	local ok, a, b, c = pcall(function()
		return act:InvokeServer(name, args or {})
	end)
	if not ok then
		return false, nil
	end
	if b and M.toast then
		M.toast(L.t(b, c), if a then "good" else "bad")
	end
	return a, c
end

function M.send(name: string, args: any?)
	doEv:FireServer(name, args)
end

return M
