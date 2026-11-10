--!nonstrict
-- Магазин: геймпассы, товары разработчика (ProcessReceipt с защитой от повторной выдачи),
-- скины за осколки, тестовые покупки владельца плейса без списания Robux.
-- Правило ТЗ: никаких статов за Robux — только ускорение, комфорт и статус.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)
local Profiles = require(script.Parent.Parent.Data.Profiles)
local Assets = require(ReplicatedStorage.Shared.Config.Assets)

local Game = Ctx.Game
local api = Ctx.api

local M: any = {}

local function isOwnerTester(player: Player): boolean
	return Game.TEST_TOOLS and game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end
M.isOwnerTester = isOwnerTester

-- ── Геймпассы ───────────────────────────────────────────────
local function applyPass(S: any, key: string)
	if S.passes[key] then
		return
	end
	S.passes[key] = true
	Ctx.mark(S, "passes")
	if key == "SecondFloor" and S.B then
		Bases.setSecondFloor(S.B, true)
	elseif key == "VIP" then
		S.player:SetAttribute("VIP", true)
		if api.checkVip then
			api.checkVip(S)
		end
	end
end

function M.loadPasses(S: any)
	for key, id in Assets.passes do
		if id and id > 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(S.player.UserId, id)
			end)
			if ok and owns then
				applyPass(S, key)
			end
		end
	end
	-- тестовые пропуска действуют только в тестовом режиме; на релизе — стираются
	if S.data.testPasses then
		if Game.TEST_TOOLS then
			for key in S.data.testPasses do
				applyPass(S, key)
			end
		else
			S.data.testPasses = nil
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	if not purchased then
		return
	end
	local S = Ctx.session(player)
	if not S then
		return
	end
	for key, id in Assets.passes do
		if id == passId then
			applyPass(S, key)
			Ctx.popup(S, "purchased", { key = key })
			Ctx.track(S, "purchase_completed", Game.PASSES[key] and Game.PASSES[key].price or 0, { item = key })
		end
	end
end)

-- ── Выдача товаров ──────────────────────────────────────────
local function grantProduct(S: any, key: string): boolean
	local cfg = Game.PRODUCTS[key]
	if not cfg then
		return false
	end
	local d = S.data
	if key == "Starter" then
		if d.once.Starter then
			api.addCash(S, 500, "product")
			return true
		end
		d.once.Starter = true
		api.addCash(S, 500, "product")
		api.give(S, "r_beetle", 1, not api.hasRoom(S))
		d.skins.starter = true
		Ctx.mark(S, "once", "skins")
	elseif key == "Titan" then
		d.once.Titan = true
		d.skins.titan = true
		d.trapSkin = "blackhole"
		Ctx.mark(S, "once", "skins", "traps")
		if S.B then
			Bases.renderTraps(S.B)
		end
	elseif cfg.shards then
		api.addShards(S, cfg.shards)
	elseif key == "Energy5" then
		api.addEnergy(S, 5)
	elseif key == "BoostX2" then
		d.boostUntil = math.max(d.boostUntil, os.time()) + Game.BOOST_SECONDS
		Ctx.mark(S, "boost", "income")
	elseif key == "SeasonPass" then
		if api.checkPass then
			api.checkPass(S)
		end
		d.pass.prem = true
		Ctx.mark(S, "pass", "income")
	else
		return false
	end
	return true
end

local productKeyById = {}
for key, id in Assets.products do
	if id and id > 0 then
		productKeyById[id] = key
	end
end

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local S = player and Ctx.session(player)
	if not S or not S.ready then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local key = productKeyById[info.ProductId]
	if not key then
		warn("[Shop] неизвестный товар", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local rid = tostring(info.PurchaseId)
	if table.find(S.data.receipts, rid) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if not grantProduct(S, key) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	table.insert(S.data.receipts, rid)
	while #S.data.receipts > 50 do
		table.remove(S.data.receipts, 1)
	end
	-- сначала сохранить, потом подтвердить: иначе при падении сервера покупка потеряется
	if not Profiles.saveNow(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	Ctx.popup(S, "purchased", { key = key })
	Ctx.fx("buy", Ctx.root(S) and Ctx.root(S).Position, nil, player)
	Ctx.track(S, "purchase_completed", info.CurrencySpent, { item = key })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- клиент просит купить: сервер сам показывает окно Roblox
Ctx.actions.buy = function(S, args)
	if not Ctx.isStr(args.key, 20) then
		return false, "msg.bad"
	end
	local key = args.key
	local isPass = Game.PASSES[key] ~= nil
	local isProduct = Game.PRODUCTS[key] ~= nil
	if not isPass and not isProduct then
		return false, "msg.bad"
	end
	if isPass and S.passes[key] then
		return false, "msg.owned"
	end
	if isProduct and Game.PRODUCTS[key].once and S.data.once[key] then
		return false, "msg.owned"
	end
	Ctx.track(S, "purchase_initiated", 0, { item = key })
	-- тест владельца: выдаём без Robux
	if isOwnerTester(S.player) and args.test then
		if isPass then
			S.data.testPasses = S.data.testPasses or {}
			S.data.testPasses[key] = true
			applyPass(S, key)
		else
			grantProduct(S, key)
		end
		Ctx.popup(S, "purchased", { key = key, test = true })
		return true, nil
	end
	local id = if isPass then Assets.passes[key] else Assets.products[key]
	if not id or id <= 0 then
		return false, "msg.shopSoon"
	end
	if isPass then
		MarketplaceService:PromptGamePassPurchase(S.player, id)
	else
		MarketplaceService:PromptProductPurchase(S.player, id)
	end
	return true, nil
end

-- ── Скины ───────────────────────────────────────────────────
local function skinCfg(id: string): any
	for _, s in Game.SKINS do
		if s.id == id then
			return s
		end
	end
	return nil
end

Ctx.actions.skinBuy = function(S, args)
	local cfg = Ctx.isStr(args.id, 20) and skinCfg(args.id)
	if not cfg or cfg.shards < 0 then
		return false, "msg.bad"
	end
	if S.data.skins[cfg.id] then
		return false, "msg.owned"
	end
	if S.data.shards < cfg.shards then
		return false, "msg.noShards"
	end
	S.data.shards -= cfg.shards
	S.data.skins[cfg.id] = true
	S.data.skin = cfg.id
	Ctx.mark(S, "shards", "skins", "skin")
	M.applySkin(S)
	return true, "msg.skinBought"
end

Ctx.actions.skinEquip = function(S, args)
	if not Ctx.isStr(args.id, 20) or not S.data.skins[args.id] then
		return false, "msg.bad"
	end
	S.data.skin = args.id
	Ctx.mark(S, "skin")
	M.applySkin(S)
	return true, nil
end

-- цвет хроно-следа персонажа (клиенты рисуют след по атрибуту)
function M.applySkin(S: any)
	local cfg = skinCfg(S.data.skin) or Game.SKINS[1]
	local color = cfg.color
	if cfg.id == "season" then
		color = Game.SEASONS[Game.seasonTheme(os.time())].color
	end
	S.player:SetAttribute("Skin", cfg.id)
	S.player:SetAttribute("SkinColor", color)
end

api.loadPasses = M.loadPasses
api.applySkin = M.applySkin
api.isOwnerTester = isOwnerTester

return M
