--!nonstrict
-- Геймпассы и товары за Robux. Покупка товара засчитывается только после успешного сохранения,
-- id чека запоминается — повторная выдача невозможна.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Assets = require(ReplicatedStorage.Shared.Assets)
local Data = require(script.Parent.Data)
local Game = require(script.Parent.Game)

local M = {}

local productById: { [number]: any } = {}
for _, p in Config.PRODUCTS do
	local id = Assets.products[p.id]
	if id and id > 0 then
		productById[id] = p
	end
end

local passByAsset: { [number]: string } = {}
for key, id in Assets.passes do
	if id > 0 then
		passByAsset[id] = key
	end
end

function M.loadPasses(player: Player): { [string]: boolean }
	local out = {}
	for key, id in Assets.passes do
		if id > 0 then
			local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, id)
			if ok and owns then
				out[key] = true
			end
		end
	end
	return out
end

local function processReceipt(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local d = player and Data.get(player)
	if not player or not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local rid = tostring(info.PurchaseId)
	if table.find(d.receipts, rid) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local p = productById[info.ProductId]
	if not p then
		warn("[Shop] неизвестный товар", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local text
	if p.kind == "launchAll" then
		text = "Launching everyone!"
	else
		text = Game.grant(player, p.kind, p.amount)
	end
	table.insert(d.receipts, rid)
	while #d.receipts > 60 do
		table.remove(d.receipts, 1)
	end
	if not Data.saveNow(player) then
		-- награда уже выдана и чек записан в память: Roblox повторит позже, повтор увидит чек
		-- и просто подтвердит, а автосохранение донесёт данные
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if p.kind == "launchAll" then
		Game.launchAll(player)
	end
	Game.notify(player, "Thanks! " .. text, "good")
	Game.push(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function M.start()
	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, bought)
		if not bought then
			return
		end
		local key = passByAsset[passId]
		local s = Game.sessions[player]
		if key and s then
			s.passes[key] = true
			Game.notify(player, "Unlocked " .. key .. "! 🎉", "good")
			if key == "VIP" and player.Character then
				local hum = player.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.DisplayName = "👑 " .. player.DisplayName
				end
			end
			Game.push(player)
		end
	end)
end

return M
