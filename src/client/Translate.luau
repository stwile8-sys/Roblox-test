--!nonstrict
-- Язык интерфейса = язык Roblox. Русский — базовый; для остальных языков все тексты интерфейса
-- (в PlayerGui и на табличках в мире) на лету переводятся на английский по словарю Lang/UiEn.
-- Перевод фрагментами: длинные фразы заменяются первыми, поэтому работают и строки, склеенные с числами.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local L = require(ReplicatedStorage.Shared.Lang.L)
local DICT = require(ReplicatedStorage.Shared.Lang.UiEn)

local M = {}

-- плюс имена из конфигов: существа, редкости, сезоны, скины, товары
local extra: { [string]: string } = {}
local function addName(t: any)
	if type(t) == "table" and type(t.ru) == "string" and type(t.en) == "string" and t.ru ~= "" then
		extra[t.ru] = t.en
	end
end
pcall(function()
	local Defs = require(ReplicatedStorage.Shared.Art.Defs)
	local Game = require(ReplicatedStorage.Shared.Config.Game)
	for _, d in Defs.LIST do
		addName(d.name)
		addName(d.desc)
	end
	for _, r in Defs.RARITY do
		addName(r.name)
	end
	for _, list in { Game.SEASONS or {}, Game.SKINS or {}, Game.QUESTS or {}, Game.ACHIEVEMENTS or {} } do
		for _, e in list do
			if type(e) == "table" then
				addName(e.name)
				addName(e.desc)
			end
		end
	end
	for _, tbl in { Game.PASSES, Game.PRODUCTS, Game.TOOLS or {}, Game.TRAPS or {} } do
		for _, e in tbl do
			if type(e) == "table" then
				addName(e.name)
				addName(e.desc)
			end
		end
	end
end)
for k, v in extra do
	if DICT[k] == nil then
		DICT[k] = v
	end
end

local keys: { string } = {}
for k in DICT do
	table.insert(keys, k)
end
table.sort(keys, function(a, b)
	return #a > #b
end)

local function hasCyrillic(s: string): boolean
	return string.find(s, "[\208\209]") ~= nil
end

local function replacePlain(s: string, from: string, to: string): string
	local out, i = {}, 1
	while true do
		local a, b = string.find(s, from, i, true)
		if not a then
			table.insert(out, string.sub(s, i))
			break
		end
		table.insert(out, string.sub(s, i, a - 1))
		table.insert(out, to)
		i = b + 1
	end
	return table.concat(out)
end

local cache: { [string]: string } = {}
function M.tr(s: string): string
	if s == "" or not hasCyrillic(s) then
		return s
	end
	local c = cache[s]
	if c then
		return c
	end
	local r = s
	for _, k in keys do
		if string.find(r, k, 1, true) then
			r = replacePlain(r, k, DICT[k])
			if not hasCyrillic(r) then
				break
			end
		end
	end
	cache[s] = r
	return r
end

local hooked = setmetatable({}, { __mode = "k" })
local function hook(obj: Instance)
	if hooked[obj] then
		return
	end
	if obj:IsA("Humanoid") then
		-- имена ботов над головой («Торговец (бот)»)
		hooked[obj] = true
		local function ah()
			local n = M.tr(obj.DisplayName)
			if n ~= obj.DisplayName then
				obj.DisplayName = n
			end
		end
		ah()
		obj:GetPropertyChangedSignal("DisplayName"):Connect(ah)
		return
	end
	if obj:IsA("ProximityPrompt") then
		hooked[obj] = true
		local function ap()
			local a, o = M.tr(obj.ActionText), M.tr(obj.ObjectText)
			if a ~= obj.ActionText then
				obj.ActionText = a
			end
			if o ~= obj.ObjectText then
				obj.ObjectText = o
			end
		end
		ap()
		obj.Changed:Connect(ap)
		return
	end
	if not (obj:IsA("TextLabel") or obj:IsA("TextButton") or obj:IsA("TextBox")) then
		return
	end
	hooked[obj] = true
	local busy = false
	local function apply()
		if busy then
			return
		end
		local o: any = obj
		local t = M.tr(o.Text)
		if t ~= o.Text then
			busy = true
			o.Text = t
			busy = false
		end
	end
	apply()
	obj:GetPropertyChangedSignal("Text"):Connect(apply)
	if obj:IsA("TextBox") then
		obj.PlaceholderText = M.tr(obj.PlaceholderText)
	end
end

local function watch(root: Instance)
	for _, d in root:GetDescendants() do
		hook(d)
	end
	root.DescendantAdded:Connect(hook)
end

function M.start()
	if L.lang() == "ru" then
		return
	end
	watch(Players.LocalPlayer:WaitForChild("PlayerGui"))
	watch(workspace)
end

return M
