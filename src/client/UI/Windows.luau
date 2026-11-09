--!nonstrict
-- Окна: доска заданий, склад, рынок, участки, настройки.

local Shared = game.ReplicatedStorage.Shared
local L = require(Shared.Lang.L)
local Items = require(Shared.Config.Items)
local JobsCfg = require(Shared.Config.Jobs)
local Map = require(Shared.Config.Map)
local Biomes = require(Shared.Config.Biomes)
local Net = require(Shared.Net)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Parent.Store)

local C = Kit.C
local M = {}

local gui: ScreenGui
local toast: (string, string?) -> ()
local windows: { [string]: Frame } = {}
local refreshers: { [string]: () -> () } = {}
local onGraphics: (string) -> () = function() end

local function result(ok: boolean, msg: any)
	if type(msg) == "string" then
		toast(L.t(msg), if ok then "success" else "error")
	end
end

local function closeAll()
	for _, w in windows do
		w.Visible = false
	end
end

function M.open(name: string)
	local w = windows[name]
	if not w then
		return
	end
	local wasOpen = w.Visible
	closeAll()
	if wasOpen then
		return
	end
	w.Visible = true
	Kit.pop(w)
	local r = refreshers[name]
	if r then
		r()
	end
end

function M.isOpen(name: string): boolean
	local w = windows[name]
	return w ~= nil and w.Visible
end

local function itemIcon(parent: Instance, id: string, size: number): Frame
	local item = Items.byId[id]
	return Kit.frame({
		Size = UDim2.new(0, size, 0, size),
		BackgroundColor3 = if item then item.color else C.dim,
		Parent = parent,
	}, { Kit.corner(size // 3) })
end

-- Доска заданий -----------------------------------------------------------

local function currentJob(): string
	local v = game:GetService("Players").LocalPlayer:GetAttribute("Job")
	return if type(v) == "string" then v else ""
end

local function buildJobs()
	local win, body, title = Kit.window(gui, 480, 380)
	windows.jobs = win
	local scroll = Kit.scroll({ Parent = body }, { Kit.list(nil, 8) })
	refreshers.jobs = function()
		title.Text = L.t("jobs.title")
		Kit.clear(scroll)
		local s = Store.state or {}
		local busy = currentJob() ~= ""
		local cd = s.jobCooldown or 0
		for n, job in JobsCfg.list do
			local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 54), BackgroundColor3 = C.panel, LayoutOrder = n, Parent = scroll }, { Kit.corner(10) })
			Kit.label({ Text = L.t("job." .. job.id), Font = Kit.BOLD, Position = UDim2.new(0, 12, 0, 6), Size = UDim2.new(1, -150, 0, 22), Parent = row })
			Kit.label({
				Text = "≈ " .. L.duration(job.time) .. "  ·  +" .. L.money(job.pay),
				TextColor3 = C.dim,
				TextSize = 14,
				Position = UDim2.new(0, 12, 0, 28),
				Size = UDim2.new(1, -150, 0, 20),
				Parent = row,
			})
			local b = Kit.button(L.t("jobs.take"), "main", {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8, 0.5, 0),
				Size = UDim2.new(0, 120, 0, 38),
				Parent = row,
			}, function()
				local ok, msg = Store.act("takeJob", job.id)
				if ok then
					win.Visible = false
				else
					result(false, msg)
				end
			end)
			if busy or cd > 0 then
				b.AutoButtonColor = false
				b.BackgroundColor3 = C.panel2
				b.TextColor3 = C.dim
				b.Text = if busy then L.t("jobs.busy") else L.t("job.cooldown_left", { s = math.ceil(cd) })
			end
		end
	end
end

-- Склад -------------------------------------------------------------------

local function buildStorage()
	local win, body, title = Kit.window(gui, 420, 360)
	windows.storage = win
	local scroll = Kit.scroll({ Parent = body }, { Kit.list(nil, 6) })
	refreshers.storage = function()
		title.Text = L.t("storage.title")
		Kit.clear(scroll)
		local s = Store.state or {}
		local itemsHave = s.items or {}
		local cap = s.storage or 500
		if not s.plot then
			Kit.label({ Text = L.t("storage.no_plot"), TextColor3 = C.dim, AutomaticSize = Enum.AutomaticSize.Y, Parent = scroll })
		end
		for n, item in Items.list do
			local have = itemsHave[item.id] or 0
			local row = Kit.frame({ Size = UDim2.new(1, -8, 0, 40), BackgroundColor3 = C.panel, LayoutOrder = n, Parent = scroll }, { Kit.corner(8) })
			local icon = itemIcon(row, item.id, 22)
			icon.Position = UDim2.new(0, 10, 0.5, -11)
			Kit.label({ Text = L.t("item." .. item.id), Position = UDim2.new(0, 42, 0, 0), Size = UDim2.new(0.5, 0, 1, 0), Parent = row })
			Kit.label({
				Text = L.num(have) .. " / " .. L.num(cap),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = if have >= cap then C.bad else C.text,
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.new(0.5, -12, 1, 0),
				Parent = row,
			})
		end
		local order = 100
		for _, e in s.incoming or {} do
			order += 1
			local left = math.max(0, (e[3] or 0) - os.time())
			Kit.label({
				Text = "🚚 " .. L.t("item." .. tostring(e[1])) .. " × " .. L.num(e[2]) .. "  ·  " .. (if left > 0 then L.duration(left) else L.t("storage.arriving")),
				TextColor3 = C.dim,
				TextSize = 14,
				LayoutOrder = order,
				Parent = scroll,
			})
		end
		if s.vehicles and (s.vehicles.cart or 0) > 0 then
			Kit.label({ Text = "🛒 " .. L.t("vehicle.cart") .. " × " .. s.vehicles.cart, TextColor3 = C.dim, TextSize = 14, LayoutOrder = 200, Parent = scroll })
		end
	end
end

-- Рынок -------------------------------------------------------------------

local function buildMarket()
	local win, body, title = Kit.window(gui, 620, 400)
	windows.market = win
	local left = Kit.scroll({ Size = UDim2.new(0.42, -6, 1, 0), Parent = body }, { Kit.list(nil, 6) })
	local right = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.new(0.42, 6, 0, 0), Size = UDim2.new(0.58, -6, 1, 0), Parent = body })
	local selected = "wood"
	local qty = 10
	local price = 0
	local book: { [string]: any }? = nil

	local function loadBook()
		local ok, data = Store.act("marketBook")
		if ok and type(data) == "table" then
			book = data
		end
	end

	local draw: () -> ()

	local function act(name: string, ...: any)
		local ok, msg = Store.act(name, ...)
		result(ok, msg)
		loadBook()
		draw()
	end

	draw = function()
		title.Text = L.t("market.title")
		Kit.clear(left)
		Kit.clear(right)
		local s = Store.state or {}
		local have = s.items or {}
		local b = book
		if not b then
			Kit.label({ Text = "…", Parent = left })
			return
		end
		for n, item in Items.list do
			local info = b.items[item.id]
			local row = Kit.button("", "plain", {
				Size = UDim2.new(1, -8, 0, 46),
				BackgroundColor3 = if selected == item.id then C.panel2 else C.panel,
				LayoutOrder = n,
				Parent = left,
			}, function()
				selected = item.id
				price = 0
				draw()
			end)
			local icon = itemIcon(row, item.id, 20)
			icon.Position = UDim2.new(0, 8, 0.5, -10)
			Kit.label({ Text = L.t("item." .. item.id), Position = UDim2.new(0, 36, 0, 4), Size = UDim2.new(1, -40, 0, 20), TextSize = 15, Parent = row })
			local best = if info.best then math.min(info.best, info.npcSell) else info.npcSell
			Kit.label({
				Text = L.t("market.row", { have = have[item.id] or 0, price = best }),
				TextColor3 = C.dim,
				TextSize = 12,
				Position = UDim2.new(0, 36, 0, 24),
				Size = UDim2.new(1, -40, 0, 18),
				Parent = row,
			})
		end

		-- правая панель: выбранный товар
		local info = b.items[selected]
		if price <= 0 then
			price = math.floor(Items.byId[selected].base * 10 + 0.5) / 10
		end
		local col = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = right }, { Kit.list(nil, 6) })
		Kit.label({ Text = L.t("item." .. selected), Font = Kit.BOLD, TextSize = 18, LayoutOrder = 1, Parent = col })
		local bestPlayer = if info.best then L.t("market.best_player", { price = info.best, qty = info.qty }) else L.t("market.no_offers")
		Kit.label({ Text = bestPlayer, TextColor3 = C.dim, TextSize = 13, LayoutOrder = 2, Parent = col })
		Kit.label({ Text = L.t("market.npc", { sell = info.npcSell, buy = info.npcBuy }), TextColor3 = C.dim, TextSize = 13, LayoutOrder = 3, Parent = col })

		-- количество
		local qrow = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 4, Parent = col })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = qrow })
		Kit.label({ Text = L.t("market.qty"), Size = UDim2.new(0, 70, 1, 0), TextSize = 14, Parent = qrow })
		for _, step in { -10, -1 } do
			Kit.button(tostring(step), "plain", { Size = UDim2.new(0, 40, 1, 0), TextSize = 14, Parent = qrow }, function()
				qty = math.max(1, qty + step)
				draw()
			end)
		end
		Kit.label({ Text = tostring(qty), Font = Kit.BOLD, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 50, 1, 0), Parent = qrow })
		for _, step in { 1, 10, 100 } do
			Kit.button("+" .. step, "plain", { Size = UDim2.new(0, 44, 1, 0), TextSize = 14, Parent = qrow }, function()
				qty = math.min(500, qty + step)
				draw()
			end)
		end

		local brow = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 5, Parent = col })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = brow })
		Kit.button(L.t("market.buy"), "ok", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 14, Parent = brow }, function()
			act("buy", selected, qty, false)
		end)
		Kit.button(L.t("market.buy_now"), "blue", { Size = UDim2.new(0.5, -3, 1, 0), TextSize = 14, Parent = brow }, function()
			act("buy", selected, qty, true)
		end)
		Kit.button(L.t("market.sell_npc", { money = math.floor(qty * info.npcBuy) }), "plain", { Size = UDim2.new(1, 0, 0, 36), TextSize = 14, LayoutOrder = 6, Parent = col }, function()
			act("sellNpc", selected, qty)
		end)

		-- своя заявка
		local prow = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = 7, Parent = col })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Parent = prow })
		Kit.label({ Text = L.t("market.price"), Size = UDim2.new(0, 70, 1, 0), TextSize = 14, Parent = prow })
		for _, step in { -1, -0.1 } do
			Kit.button(tostring(step), "plain", { Size = UDim2.new(0, 40, 1, 0), TextSize = 13, Parent = prow }, function()
				price = math.max(info.npcBuy, math.floor((price + step) * 10 + 0.5) / 10)
				draw()
			end)
		end
		Kit.label({ Text = string.format("%.1f", price), Font = Kit.BOLD, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(0, 50, 1, 0), Parent = prow })
		for _, step in { 0.1, 1 } do
			Kit.button("+" .. step, "plain", { Size = UDim2.new(0, 44, 1, 0), TextSize = 13, Parent = prow }, function()
				price = math.min(info.npcSell, math.floor((price + step) * 10 + 0.5) / 10)
				draw()
			end)
		end
		Kit.button(L.t("market.place", { qty = qty, price = string.format("%.1f", price) }), "main", { Size = UDim2.new(1, 0, 0, 36), TextSize = 14, LayoutOrder = 8, Parent = col }, function()
			act("order", selected, qty, price)
		end)
		Kit.label({ Text = L.t("market.fees"), TextColor3 = C.dim, TextSize = 11, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 9, Parent = col })

		-- мои заявки
		for n, o in b.mine do
			local r = Kit.frame({ BackgroundColor3 = C.panel, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 10 + n, Parent = col }, { Kit.corner(6) })
			Kit.label({ Text = L.t("item." .. o.i) .. " × " .. o.q .. " @ " .. string.format("%.1f", o.p), TextSize = 13, Position = UDim2.new(0, 8, 0, 0), Size = UDim2.new(1, -90, 1, 0), Parent = r })
			Kit.button(L.t("market.cancel"), "bad", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -4, 0.5, 0), Size = UDim2.new(0, 80, 0, 24), TextSize = 12, Parent = r }, function()
				act("cancelOrder", o.id)
			end)
		end
	end

	refreshers.market = function()
		book = nil
		draw()
		task.spawn(function()
			loadBook()
			draw()
		end)
	end
	Net.event("Market").OnClientEvent:Connect(function()
		if win.Visible then
			task.spawn(function()
				loadBook()
				draw()
			end)
		end
	end)
	Store.on(function()
		if win.Visible and book then
			draw()
		end
	end)
end

-- Участки -----------------------------------------------------------------

local function buildPlots()
	local win, body, title = Kit.window(gui, 600, 400)
	windows.plots = win
	local grid = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(0, 330, 0, 330), Parent = body })
	local info = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 342, 0, 0), Size = UDim2.new(1, -342, 1, 0), Parent = body }, { Kit.list(nil, 6) })
	local selected: number? = nil

	local draw: () -> ()
	draw = function()
		title.Text = L.t("plots.title")
		Kit.clear(grid)
		Kit.clear(info)
		local s = Store.state or {}
		local owners = s.owners or {}
		local cell = 64
		local byPos = {}
		for _, p in Map.plots do
			byPos[p.c .. "," .. p.r] = p
		end
		for c = 0, 4 do
			for r = 0, 4 do
				local p = byPos[c .. "," .. r]
				local pos = UDim2.new(0, c * (cell + 2), 0, r * (cell + 2))
				if p then
					local owner = owners[tostring(p.index)]
					local mine = s.plot == p.index
					local b = Kit.button(if mine then "★" elseif owner then "👤" else tostring(p.index), "plain", {
						Position = pos,
						Size = UDim2.new(0, cell, 0, cell),
						BackgroundColor3 = Biomes.byId[p.biome].ground,
						TextColor3 = Color3.new(1, 1, 1),
						TextStrokeTransparency = 0.5,
						TextSize = 18,
						Parent = grid,
					}, function()
						selected = p.index
						draw()
					end)
					if selected == p.index then
						Kit.stroke(C.accent, 3).Parent = b
					end
				else
					local hub = c == 2 and r == 2
					Kit.label({
						Text = if hub then "🏛️" else "💰",
						TextXAlignment = Enum.TextXAlignment.Center,
						TextSize = 22,
						BackgroundTransparency = 0,
						BackgroundColor3 = C.panel2,
						Position = pos,
						Size = UDim2.new(0, cell, 0, cell),
						Parent = grid,
					})
				end
			end
		end
		if not selected then
			Kit.label({ Text = L.t("plots.pick"), TextColor3 = C.dim, AutomaticSize = Enum.AutomaticSize.Y, Parent = info })
			return
		end
		local p = Map.plots[selected]
		local biome = Biomes.byId[p.biome]
		Kit.label({ Text = L.t("plots.name", { n = p.index }) .. " · " .. L.t("biome." .. p.biome), Font = Kit.BOLD, TextSize = 18, LayoutOrder = 1, Parent = info })
		local names = {}
		for _, r in biome.resources do
			table.insert(names, L.t("res." .. r))
		end
		Kit.label({ Text = L.t("plots.resources") .. ": " .. table.concat(names, ", "), TextSize = 13, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = info })
		local extra = {}
		for _, r in p.extra do
			table.insert(extra, L.t("res." .. r))
		end
		Kit.label({ Text = L.t("plots.extra") .. ": " .. table.concat(extra, ", "), TextSize = 13, TextColor3 = C.dim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = info })
		if not biome.food then
			Kit.label({ Text = L.t("plots.hard"), TextSize = 13, TextColor3 = C.accent, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, Parent = info })
		end
		local owner = owners[tostring(p.index)]
		if s.plot == p.index then
			Kit.label({ Text = L.t("plots.yours"), TextColor3 = C.good, LayoutOrder = 5, Parent = info })
		elseif owner then
			Kit.label({ Text = L.t("plots.owner", { name = owner }), TextColor3 = C.dim, LayoutOrder = 5, Parent = info })
		elseif s.plot then
			Kit.label({ Text = L.t("plots.have_one"), TextColor3 = C.dim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = info })
		else
			local b = Kit.button(L.t("plots.buy", { price = Map.PLOT_PRICE }), "main", { Size = UDim2.new(1, 0, 0, 44), LayoutOrder = 6, Parent = info }, function()
				local ok, msg = Store.act("buyPlot", p.index)
				if ok then
					win.Visible = false
				else
					result(false, msg)
				end
			end)
			if (s.money or 0) < Map.PLOT_PRICE then
				b.BackgroundColor3 = C.panel2
				b.TextColor3 = C.dim
			end
			Kit.label({ Text = L.t("plots.starter"), TextSize = 12, TextColor3 = C.dim, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 7, Parent = info })
		end
	end
	refreshers.plots = function()
		local s = Store.state or {}
		if not selected then
			selected = s.plot
		end
		draw()
	end
end

-- Настройки ---------------------------------------------------------------

local function buildSettings()
	local win, body, title = Kit.window(gui, 460, 380)
	windows.settings = win
	local scroll = Kit.scroll({ Parent = body }, { Kit.list(nil, 8) })
	local function draw()
		title.Text = L.t("settings.title")
		Kit.clear(scroll)
		Kit.label({ Text = L.t("settings.lang"), Font = Kit.BOLD, LayoutOrder = 1, Parent = scroll })
		local langs = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = scroll })
		Kit.new("UIGridLayout", { CellSize = UDim2.new(0, 130, 0, 36), CellPadding = UDim2.new(0, 6, 0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = langs })
		for n, code in L.LANGS do
			Kit.button(L.NATIVE[code], if L.lang() == code then "main" else "plain", { TextSize = 14, LayoutOrder = n, Parent = langs }, function()
				L.set(code)
				Store.act("setPref", "lang", code)
				draw()
			end)
		end
		Kit.label({ Text = L.t("settings.gfx"), Font = Kit.BOLD, LayoutOrder = 3, Parent = scroll })
		local g = Kit.frame({ BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 4, Parent = scroll })
		Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), Parent = g })
		local s = Store.state or {}
		local current = (s.prefs and s.prefs.gfx) or "auto"
		for _, mode in { "auto", "low", "high" } do
			Kit.button(L.t("gfx." .. mode), if current == mode then "main" else "plain", { Size = UDim2.new(0, 130, 1, 0), TextSize = 14, Parent = g }, function()
				if s.prefs then
					s.prefs.gfx = mode
				end
				Store.act("setPref", "gfx", mode)
				onGraphics(mode)
				draw()
			end)
		end
		Kit.label({ Text = L.t("settings.gfx_hint"), TextColor3 = C.dim, TextSize = 12, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 5, Parent = scroll })
	end
	refreshers.settings = draw
end

function M.start(screen: ScreenGui, toastFn: (string, string?) -> (), graphicsFn: (string) -> ())
	gui = screen
	toast = toastFn
	onGraphics = graphicsFn
	buildJobs()
	buildStorage()
	buildMarket()
	buildPlots()
	buildSettings()
	Store.on(function()
		for name, w in windows do
			if w.Visible and name ~= "market" then
				local r = refreshers[name]
				if r then
					r()
				end
			end
		end
	end)
	L.onChange(function()
		for name, w in windows do
			if w.Visible then
				local r = refreshers[name]
				if r then
					r()
				end
			end
		end
	end)
end

M.closeAll = closeAll
return M
