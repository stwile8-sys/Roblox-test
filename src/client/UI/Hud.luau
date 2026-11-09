--!nonstrict
-- Основной экран: деньги, кнопки, текущая работа, туториал, уведомления, сводка «пока вас не было».

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local L = require(Shared.Lang.L)
local Items = require(Shared.Config.Items)
local JobsCfg = require(Shared.Config.Jobs)
local Kit = require(script.Parent.Kit)
local Store = require(script.Parent.Parent.Store)

local C = Kit.C
local player = Players.LocalPlayer

local M = {}

local gui: ScreenGui
local moneyLabel: TextLabel
local popLabel: TextLabel
local buttons: { [string]: TextButton } = {}
local toastHolder: Frame
local jobPanel: Frame
local jobTitle: TextLabel
local jobHint: TextLabel
local tutPanel: Frame
local tutText: TextLabel
local tutStep: TextLabel
local summaryWin: Frame
local summaryBody: ScrollingFrame
local cooldownLabel: TextLabel

local handlers: { [string]: () -> () } = {}

function M.onButton(name: string, fn: () -> ())
	handlers[name] = fn
end

function M.gui(): ScreenGui
	return gui
end

local BUTTONS = {
	{ id = "build", icon = "🏗️", key = "hud.build" },
	{ id = "storage", icon = "📦", key = "hud.storage" },
	{ id = "market", icon = "💰", key = "hud.market" },
	{ id = "plots", icon = "🗺️", key = "hud.plots" },
	{ id = "travel", icon = "🏠", key = "hud.my_plot" },
	{ id = "settings", icon = "⚙️", key = "hud.settings" },
}

local function pill(parent: Instance, order: number, icon: string): TextLabel
	local f = Kit.frame({
		Size = UDim2.new(0, 150, 0, 38),
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.15,
		LayoutOrder = order,
		Parent = parent,
		AutomaticSize = Enum.AutomaticSize.X,
	}, { Kit.corner(19), Kit.pad(8) })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center, Parent = f })
	Kit.label({ Text = icon, Size = UDim2.new(0, 22, 1, 0), TextSize = 18, Parent = f })
	return Kit.label({ Text = "0", Font = Kit.BOLD, TextSize = 18, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, Parent = f })
end

function M.toast(text: string, kind: string?)
	local color = if kind == "error" then C.bad elseif kind == "money" or kind == "success" then C.good elseif kind == "badge" then C.accent else C.panel2
	local t = Kit.frame({
		Size = UDim2.new(0, 360, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		Parent = toastHolder,
	}, { Kit.corner(10), Kit.stroke(color, 2), Kit.pad(10) })
	Kit.label({ Text = text, AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, Parent = t })
	Kit.pop(t)
	task.delay(if kind == "badge" then 6 else 3.5, function()
		t:Destroy()
	end)
end

local function jobView(s: { [string]: any })
	local id = player:GetAttribute("Job")
	if type(id) ~= "string" or id == "" then
		jobPanel.Visible = false
		local cd = s.jobCooldown or 0
		cooldownLabel.Visible = cd > 0.5
		cooldownLabel.Text = L.t("job.cooldown_left", { s = math.ceil(cd) })
		return
	end
	cooldownLabel.Visible = false
	local job = JobsCfg.byId[id]
	if not job then
		return
	end
	local progress = player:GetAttribute("JobProgress") or 0
	local carry = player:GetAttribute("JobCarry") == true
	jobPanel.Visible = true
	jobTitle.Text = L.t("job." .. id) .. "  ·  " .. tostring(progress) .. "/" .. tostring(job.count)
	local hintKey = "jobhint." .. id
	if job.kind == "carry" then
		hintKey ..= if carry then ".drop" else ".pickup"
	end
	jobHint.Text = L.t(hintKey)
end

local function tutorialView(s: { [string]: any })
	local step = s.tutorial or 6
	tutPanel.Visible = step < 6
	if step >= 6 then
		return
	end
	tutStep.Text = L.t("tut.title", { n = step })
	tutText.Text = L.t("tut." .. step, { goal = 900 })
end

local function refresh(s: { [string]: any })
	moneyLabel.Text = L.money(s.money or 0)
	local city = s.city
	local popPill = popLabel.Parent :: Frame
	popPill.Visible = city ~= nil
	if city then
		popLabel.Text = L.num(city.stats.pop or 0)
	end
	buttons.build.Visible = s.plot ~= nil
	buttons.travel.Visible = s.plot ~= nil
	jobView(s)
	tutorialView(s)
end

function M.showSummary(sum: { [string]: any })
	Kit.clear(summaryBody)
	local lines = {}
	if sum.seconds then
		table.insert(lines, { L.t("sum.away", { t = L.duration(sum.seconds) }), C.dim })
	end
	if sum.income and sum.income > 0 then
		table.insert(lines, { "+" .. L.money(sum.income) .. "  " .. L.t("sum.income"), C.good })
	end
	if sum.costs and sum.costs > 0 then
		table.insert(lines, { "−" .. L.money(sum.costs) .. "  " .. L.t("sum.costs"), C.bad })
	end
	if sum.payout and sum.payout > 0 then
		table.insert(lines, { "+" .. L.money(sum.payout) .. "  " .. L.t("sum.payout"), C.good })
	end
	for _, item in Items.list do
		local n = sum.items and sum.items[item.id]
		if n and n ~= 0 then
			local sign = if n > 0 then "+" else "−"
			table.insert(lines, { sign .. L.num(math.abs(n)) .. " " .. L.t("item." .. item.id), if n > 0 then C.good else C.bad })
		end
	end
	for n, line in lines do
		Kit.label({ Text = line[1], TextColor3 = line[2], LayoutOrder = n, TextSize = 17, Parent = summaryBody })
	end
	summaryWin.Visible = true
	Kit.pop(summaryWin)
end

function M.start()
	gui = Kit.screen("Hud", 1)

	-- верх слева: деньги и население
	local top = Kit.frame({ BackgroundTransparency = 1, Position = UDim2.new(0, 10, 0, 8), Size = UDim2.new(0, 400, 0, 40), Parent = gui })
	Kit.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), Parent = top })
	moneyLabel = pill(top, 1, "💰")
	popLabel = pill(top, 2, "👥")

	-- кнопки справа столбиком
	local side = Kit.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -10, 0.5, 0),
		Size = UDim2.new(0, 64, 0, 420),
		Parent = gui,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Parent = side })
	for n, b in BUTTONS do
		local btn = Kit.button(b.icon, "plain", {
			Size = UDim2.new(0, 60, 0, 56),
			TextSize = 26,
			BackgroundColor3 = C.bg,
			BackgroundTransparency = 0.1,
			LayoutOrder = n,
			Parent = side,
		})
		local cap = Kit.label({
			Text = L.t(b.key),
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			Position = UDim2.new(0, 0, 1, -14),
			Size = UDim2.new(1, 0, 0, 12),
			TextColor3 = C.dim,
			Parent = btn,
		})
		btn.TextYAlignment = Enum.TextYAlignment.Top
		Kit.new("UIPadding", { PaddingTop = UDim.new(0, 6), Parent = btn })
		L.onChange(function()
			cap.Text = L.t(b.key)
		end)
		btn.Activated:Connect(function()
			local fn = handlers[b.id]
			if fn then
				fn()
			end
		end)
		buttons[b.id] = btn
	end

	-- уведомления
	toastHolder = Kit.frame({
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 120),
		Size = UDim2.new(0, 360, 0, 300),
		Parent = gui,
		ZIndex = 20,
	})
	Kit.new("UIListLayout", { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, Parent = toastHolder })

	-- текущая работа
	jobPanel = Kit.frame({
		Position = UDim2.new(0, 10, 0, 56),
		Size = UDim2.new(0, 260, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = gui,
	}, { Kit.corner(10), Kit.pad(10), Kit.list(nil, 6) })
	jobTitle = Kit.label({ Font = Kit.BOLD, TextColor3 = C.accent, LayoutOrder = 1, Parent = jobPanel })
	jobHint = Kit.label({ TextSize = 14, AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = C.text, LayoutOrder = 2, Parent = jobPanel })
	local cancel = Kit.button(L.t("job.cancel"), "plain", { Size = UDim2.new(0, 110, 0, 30), TextSize = 13, LayoutOrder = 3, Parent = jobPanel }, function()
		Store.act("cancelJob")
	end)
	L.onChange(function()
		cancel.Text = L.t("job.cancel")
	end)
	cooldownLabel = Kit.label({
		Position = UDim2.new(0, 10, 0, 56),
		Size = UDim2.new(0, 260, 0, 24),
		TextSize = 14,
		TextColor3 = C.dim,
		Visible = false,
		Parent = gui,
	})

	-- туториал
	tutPanel = Kit.frame({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.new(0, 380, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = C.bg,
		BackgroundTransparency = 0.05,
		Visible = false,
		Parent = gui,
	}, { Kit.corner(12), Kit.stroke(C.accent, 2), Kit.pad(10), Kit.list(nil, 4) })
	tutStep = Kit.label({ Font = Kit.BOLD, TextColor3 = C.accent, TextSize = 14, LayoutOrder = 1, Parent = tutPanel })
	tutText = Kit.label({ TextSize = 16, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = tutPanel })

	-- сводка «пока вас не было»
	local win, body, title = Kit.window(gui, 420, 320)
	summaryWin = win
	title.Text = L.t("sum.title")
	summaryBody = Kit.scroll({ Parent = body }, { Kit.list(nil, 6) })
	L.onChange(function()
		title.Text = L.t("sum.title")
	end)

	Store.on(refresh)
	for _, attr in { "Job", "JobProgress", "JobCarry" } do
		player:GetAttributeChangedSignal(attr):Connect(function()
			if Store.state then
				refresh(Store.state)
			end
		end)
	end
	L.onChange(function()
		if Store.state then
			refresh(Store.state)
		end
	end)
	-- обратный отсчёт перерыва между работами
	task.spawn(function()
		while true do
			task.wait(1)
			local s = Store.state
			if s and s.jobCooldown and s.jobCooldown > 0 then
				s.jobCooldown = math.max(0, s.jobCooldown - 1)
				jobView(s)
			end
		end
	end)
end

function M.setTravelIcon(atPlot: boolean)
	local b = buttons.travel
	if b then
		b.Text = if atPlot then "🏛️" else "🏠"
	end
end

function M.hideFor(build: boolean)
	gui.Enabled = not build
end

return M
