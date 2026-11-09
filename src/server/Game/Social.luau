--!nonstrict
-- Социальное: кланы (DataStore, фильтр названия, чат клана через TextChatService), лидерборды
-- (Титан-ранг за сезон, Коллекция, Кланы) на стене хаба и в окне, безопасный трейд артефактами.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Ctx = require(script.Parent.Ctx)
local Net = require(ReplicatedStorage.Shared.Net)

local Game = Ctx.Game
local Defs = Ctx.Defs
local api = Ctx.api

local M: any = {}

local PREFIX = if RunService:IsStudio() then "studio_" else ""
local clanStore: DataStore? = nil
local boards: { [string]: OrderedDataStore } = {}
pcall(function()
	clanStore = DataStoreService:GetDataStore(PREFIX .. "clans")
end)

local function boardStore(name: string): OrderedDataStore?
	if boards[name] then
		return boards[name]
	end
	local ok, s = pcall(function()
		return DataStoreService:GetOrderedDataStore(PREFIX .. name)
	end)
	if ok then
		boards[name] = s
		return s
	end
	return nil
end

local function titanBoard(): string
	return "board_titan_s" .. Game.seasonNumber(os.time())
end

-- ── Кланы ───────────────────────────────────────────────────
local clans: { [string]: any } = {} -- кэш: тег → {name, tag, owner, members = {userId...}, points}

local function loadClan(tag: string): any
	if clans[tag] then
		return clans[tag]
	end
	local s = clanStore
	if not s then
		return nil
	end
	local ok, data = pcall(function()
		return s:GetAsync("clan_" .. tag)
	end)
	if ok and type(data) == "table" then
		clans[tag] = data
		return data
	end
	return nil
end

local function updateClan(tag: string, fn: (any) -> any): any
	local s = clanStore
	if not s then
		return nil
	end
	local result = nil
	local ok, err = pcall(function()
		s:UpdateAsync("clan_" .. tag, function(old)
			local new = fn(old)
			result = new
			return new
		end)
	end)
	if not ok then
		warn("[Clan]", err)
		return nil
	end
	if result then
		clans[tag] = result
	end
	return result
end

local function filtered(text: string, userId: number): string?
	local ok, res = pcall(function()
		local f = TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)
		return f:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or type(res) ~= "string" or string.find(res, "#") then
		return nil
	end
	return res
end

local channels: { [string]: TextChannel } = {}
local function clanChannel(tag: string): TextChannel?
	if channels[tag] then
		return channels[tag]
	end
	local folder = TextChatService:FindFirstChild("ClanChannels")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ClanChannels"
		folder.Parent = TextChatService
	end
	local ch = Instance.new("TextChannel")
	ch.Name = "Clan_" .. tag
	ch.Parent = folder
	channels[tag] = ch
	return ch
end

local function joinChannel(S: any)
	local tag = S.data.clan
	if tag == "" or not S.player then
		return
	end
	local ch = clanChannel(tag)
	if ch then
		pcall(function()
			ch:AddUserAsync(S.player.UserId)
		end)
	end
	S.player:SetAttribute("Clan", tag)
end

local function leaveChannel(S: any, tag: string)
	local ch = channels[tag]
	if ch then
		local src = ch:FindFirstChild(S.player.Name)
		if src then
			src:Destroy()
		end
	end
	S.player:SetAttribute("Clan", "")
end

Ctx.views.clan = function(S)
	local tag = S.data.clan
	if tag == "" then
		return nil
	end
	local c = loadClan(tag)
	if not c then
		return { tag = tag }
	end
	return { tag = c.tag, name = c.name, owner = c.owner, count = #c.members, points = c.points or 0 }
end

Ctx.actions.clanCreate = function(S, args)
	if S.data.clan ~= "" then
		return false, "msg.inClan"
	end
	if not Ctx.isStr(args.name, 24) or not Ctx.isStr(args.tag, 5) then
		return false, "msg.bad"
	end
	local tag = string.upper(args.tag)
	if not string.match(tag, "^[A-Z0-9]+$") or #tag < 2 then
		return false, "msg.badTag"
	end
	if #args.name < 3 then
		return false, "msg.badName"
	end
	local name = filtered(args.name, S.player.UserId)
	if not name then
		return false, "msg.badName"
	end
	if S.data.cash < Game.CLAN_COST then
		return false, "msg.noCash"
	end
	local taken = false
	local created = updateClan(tag, function(old)
		if old then
			taken = true
			return nil
		end
		return { tag = tag, name = name, owner = S.player.UserId, members = { S.player.UserId }, points = 0 }
	end)
	if taken then
		return false, "msg.tagTaken"
	end
	if not created then
		return false, "msg.tryLater"
	end
	api.spend(S, Game.CLAN_COST)
	S.data.clan = tag
	S.data.stats.clan = 1
	joinChannel(S)
	Ctx.mark(S, "clan")
	api.checkAch(S)
	return true, "msg.clanCreated"
end

Ctx.actions.clanJoin = function(S, args)
	if S.data.clan ~= "" then
		return false, "msg.inClan"
	end
	if not Ctx.isStr(args.tag, 5) then
		return false, "msg.bad"
	end
	local tag = string.upper(args.tag)
	local full = false
	local c = updateClan(tag, function(old)
		if not old then
			return nil
		end
		if #old.members >= Game.CLAN_MAX then
			full = true
			return nil
		end
		if not table.find(old.members, S.player.UserId) then
			table.insert(old.members, S.player.UserId)
		end
		return old
	end)
	if full then
		return false, "msg.clanFull"
	end
	if not c then
		return false, "msg.noClan"
	end
	S.data.clan = tag
	S.data.stats.clan = 1
	joinChannel(S)
	Ctx.mark(S, "clan")
	api.checkAch(S)
	return true, "msg.clanJoined"
end

Ctx.actions.clanLeave = function(S)
	local tag = S.data.clan
	if tag == "" then
		return false, "msg.bad"
	end
	updateClan(tag, function(old)
		if not old then
			return nil
		end
		local i = table.find(old.members, S.player.UserId)
		if i then
			table.remove(old.members, i)
		end
		if old.owner == S.player.UserId then
			old.owner = old.members[1] or 0
		end
		return old
	end)
	leaveChannel(S, tag)
	S.data.clan = ""
	Ctx.mark(S, "clan")
	return true, nil
end

function M.clanPoints(S: any, n: number)
	local tag = S.data.clan
	if tag == "" then
		return
	end
	S.clanPending = (S.clanPending or 0) + n
end

-- ── Лидерборды ──────────────────────────────────────────────
local cache = { titan = {}, collection = {}, clans = {} }

local function collCount(d: any): number
	local n = 0
	for id in d.coll do
		local def = Defs.BY_ID[id]
		if def and not def.seasonal then
			n += 1
		end
	end
	return n
end

function M.pushScores(S: any)
	if S.isBot or not S.player then
		return
	end
	local uid = tostring(S.player.UserId)
	local d = S.data
	local t = boardStore(titanBoard())
	local c = boardStore("board_collection")
	pcall(function()
		if t then
			t:SetAsync(uid, math.floor(d.titan))
		end
		if c then
			c:SetAsync(uid, collCount(d) * 100 + math.min(99, d.rebirths))
		end
	end)
	local pending = S.clanPending or 0
	if pending > 0 and d.clan ~= "" then
		S.clanPending = 0
		local cl = updateClan(d.clan, function(old)
			if not old then
				return nil
			end
			old.points = (old.points or 0) + pending
			return old
		end)
		local cb = boardStore("board_clans")
		if cl and cb then
			pcall(function()
				cb:SetAsync(d.clan, cl.points)
			end)
		end
	end
end

local names: { [number]: string } = {}
local function nameOf(id: number): string
	if names[id] then
		return names[id]
	end
	local ok, n = pcall(function()
		return Players:GetNameFromUserIdAsync(id)
	end)
	names[id] = if ok then n else tostring(id)
	return names[id]
end

local function fetch(storeName: string, isClan: boolean): { { name: string, value: number } }
	local s = boardStore(storeName)
	local out = {}
	if not s then
		return out
	end
	pcall(function()
		local page = s:GetSortedAsync(false, 10):GetCurrentPage()
		for _, e in page do
			local name
			if isClan then
				local c = loadClan(e.key)
				name = if c then ("[" .. c.tag .. "] " .. c.name) else e.key
			else
				name = nameOf(tonumber(e.key) or 0)
			end
			table.insert(out, { name = name, value = e.value })
		end
	end)
	return out
end

local function drawBoard(part: Instance?, rows: { any }, fmt: (number) -> string)
	local gui = part and part:FindFirstChild("Gui")
	local list = gui and gui:FindFirstChild("List")
	if not list then
		return
	end
	for _, ch in list:GetChildren() do
		if ch:IsA("TextLabel") then
			ch:Destroy()
		end
	end
	for i, r in rows do
		local t = Instance.new("TextLabel")
		t.BackgroundTransparency = if i == 1 then 0.6 else 1
		t.BackgroundColor3 = Color3.fromHex("#FFE066")
		t.Size = UDim2.new(1, 0, 0.095, 0)
		t.Font = Enum.Font.GothamBold
		t.TextScaled = true
		t.TextXAlignment = Enum.TextXAlignment.Left
		t.TextColor3 = if i == 1 then Color3.fromHex("#FFE066") else Color3.new(1, 1, 1)
		t.Text = string.format("%s%d. %s — %s", if i == 1 then "👑 " else "", i, r.name, fmt(r.value))
		t.LayoutOrder = i
		t.Parent = list
	end
end

local boardEv = Net.event("Board")

local function refreshBoards()
	cache.titan = fetch(titanBoard(), false)
	cache.collection = fetch("board_collection", false)
	cache.clans = fetch("board_clans", true)
	local hub = workspace.Map.Hub
	drawBoard(hub:FindFirstChild("Board_Titan"), cache.titan, tostring)
	drawBoard(hub:FindFirstChild("Board_Collection"), cache.collection, function(v)
		return tostring(math.floor(v / 100)) .. "/40"
	end)
	drawBoard(hub:FindFirstChild("Board_Clans"), cache.clans, tostring)
	boardEv:FireAllClients(cache)
	-- топ-1 Титана — золотой ореол над головой
	local top = cache.titan[1]
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Crown", top ~= nil and p.Name == top.name)
	end
end

Ctx.actions.boards = function(S)
	return true, nil, cache
end

-- ── Трейд ───────────────────────────────────────────────────
-- состояние: S.trade = {with = S2, give = {индексы inv}, ready = bool, t = время последнего изменения}
local tradeEv = Net.event("Trade")

local function tradeView(S: any): any
	local T = S.trade
	if not T then
		return nil
	end
	local O = T.with
	local function items(X: any)
		local out = {}
		for _, i in X.trade.give do
			local a = X.data.inv[i]
			if a then
				table.insert(out, { id = a.id, lvl = a.lvl, i = i })
			end
		end
		return out
	end
	return {
		name = Ctx.displayName(O),
		mine = items(S),
		theirs = items(O),
		myReady = T.ready,
		theirReady = O.trade.ready,
		lockUntil = math.max(T.t, O.trade.t) + Game.TRADE_CONFIRM_DELAY,
	}
end

local function tradeSend(S: any)
	if S.player and not S.isBot then
		tradeEv:FireClient(S.player, tradeView(S))
	end
end

local function tradeClose(S: any, reason: string?)
	local T = S.trade
	if not T then
		return
	end
	local O = T.with
	S.trade = nil
	if O and O.trade and O.trade.with == S then
		O.trade = nil
		if O.player and not O.isBot then
			tradeEv:FireClient(O.player, nil, reason)
		end
	end
	if S.player and not S.isBot then
		tradeEv:FireClient(S.player, nil, reason)
	end
end
M.tradeClose = tradeClose

local function findActor(uid: number): any
	for _, S in api.actors() do
		if Ctx.uid(S) == uid then
			return S
		end
	end
	return nil
end

Ctx.actions.tradeRequest = function(S, args)
	if not Ctx.isNum(args.target) or S.trade then
		return false, "msg.bad"
	end
	local O = findActor(args.target)
	if not O or O == S or O.trade then
		return false, "msg.tradeBusy"
	end
	local r1, r2 = Ctx.root(S), Ctx.root(O)
	if not r1 or not r2 or (r1.Position - r2.Position).Magnitude > 30 then
		return false, "msg.tooFar"
	end
	if O.isBot then
		S.trade = { with = O, give = {}, ready = false, t = os.clock() }
		O.trade = { with = S, give = {}, ready = false, t = os.clock() }
		if O.onTradeOpen then
			O.onTradeOpen(S)
		end
		tradeSend(S)
		return true, nil
	end
	O.tradeInvite = { from = S, t = os.clock() }
	Ctx.popup(O, "tradeInvite", { from = S.player.DisplayName, id = S.player.UserId })
	return true, "msg.tradeSent"
end

Ctx.actions.tradeAccept = function(S, args)
	local inv = S.tradeInvite
	if not inv or os.clock() - inv.t > 30 or S.trade then
		return false, "msg.bad"
	end
	local O = inv.from
	S.tradeInvite = nil
	if not O or O.trade or not Ctx.session(O.player) then
		return false, "msg.tradeBusy"
	end
	S.trade = { with = O, give = {}, ready = false, t = os.clock() }
	O.trade = { with = S, give = {}, ready = false, t = os.clock() }
	tradeSend(S)
	tradeSend(O)
	return true, nil
end

function M.tradeSet(S: any, give: { number })
	local T = S.trade
	if not T then
		return false
	end
	local clean = {}
	local seen = {}
	for _, i in give do
		if Ctx.isInt(i, 1, #S.data.inv) and not seen[i] and #clean < Game.TRADE_MAX_ITEMS then
			seen[i] = true
			table.insert(clean, i)
		end
	end
	T.give = clean
	T.ready = false
	T.t = os.clock()
	local O = T.with
	O.trade.ready = false
	tradeSend(S)
	tradeSend(O)
	if O.isBot and O.onTradeChange then
		O.onTradeChange(S)
	end
	return true
end

Ctx.actions.tradeSet = function(S, args)
	if type(args.give) ~= "table" then
		return false, "msg.bad"
	end
	return M.tradeSet(S, args.give), nil
end

local function execute(A: any, B: any): boolean
	-- атомарно в памяти сервера: проверяем, что предметы на месте и есть место, потом меняем
	local function pick(X: any)
		local out = {}
		for _, i in X.trade.give do
			local a = X.data.inv[i]
			if not a then
				return nil
			end
			table.insert(out, a)
		end
		return out
	end
	local ga, gb = pick(A), pick(B)
	if not ga or not gb then
		return false
	end
	local function roomOk(X: any, takeN: number, getN: number)
		if X.isBot then
			return true
		end
		return #X.data.inv - takeN + getN <= Game.INVENTORY_MAX
	end
	if not roomOk(A, #ga, #gb) or not roomOk(B, #gb, #ga) then
		return false
	end
	local function remove(X: any)
		local idx = table.clone(X.trade.give)
		table.sort(idx, function(a, b)
			return a > b
		end)
		for _, i in idx do
			table.remove(X.data.inv, i)
		end
	end
	remove(A)
	remove(B)
	for _, a in gb do
		table.insert(A.data.inv, a)
		if not A.isBot then
			A.data.coll[a.id] = true
		end
	end
	for _, a in ga do
		table.insert(B.data.inv, a)
		if not B.isBot then
			B.data.coll[a.id] = true
		end
	end
	for _, X in { A, B } do
		if not X.isBot then
			X.data.stats.trades = (X.data.stats.trades or 0) + 1
			Ctx.mark(X, "inv", "coll", "stats")
			api.checkAch(X)
			if api.saveSoon then
				api.saveSoon(X)
			end
		end
	end
	return true
end

function M.tradeReady(S: any)
	local T = S.trade
	if not T then
		return false, "msg.bad"
	end
	local O = T.with
	if os.clock() < math.max(T.t, O.trade.t) + Game.TRADE_CONFIRM_DELAY then
		return false, "msg.tradeWait"
	end
	T.ready = true
	if O.trade.ready then
		local ok = execute(S, O)
		tradeClose(S, if ok then "done" else "failed")
		return ok, if ok then "msg.tradeDone" else "msg.tradeFailed"
	end
	tradeSend(S)
	tradeSend(O)
	return true, nil
end

Ctx.actions.tradeReady = function(S)
	return M.tradeReady(S)
end

Ctx.actions.tradeCancel = function(S)
	tradeClose(S, "cancel")
	return true, nil
end

function M.onLeave(S: any)
	tradeClose(S, "left")
	M.pushScores(S)
end

function M.onJoin(S: any)
	if S.data.clan ~= "" then
		local c = loadClan(S.data.clan)
		if c and table.find(c.members, S.player.UserId) then
			joinChannel(S)
		else
			S.data.clan = ""
		end
	end
	if #cache.titan > 0 then
		boardEv:FireClient(S.player, cache)
	end
end

function M.init()
	task.spawn(function()
		task.wait(5)
		while true do
			for _, S in Ctx.sessions do
				if S.ready then
					M.pushScores(S)
					task.wait(0.5)
				end
			end
			pcall(refreshBoards)
			task.wait(90)
		end
	end)
end

api.clanPoints = M.clanPoints
api.tradeSet = M.tradeSet
api.tradeReady = M.tradeReady
api.tradeClose = tradeClose
api.updateBoards = M.pushScores

return M
