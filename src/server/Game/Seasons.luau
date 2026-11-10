--!nonstrict
-- Сезоны: тема меняется каждые 2 недели строго по серверному времени.
-- Сезонный остров: на алтаре раз в 8 минут появляется сезонный артефакт за клеткой.
-- Клетку ломают как стену, артефакт крадут и несут на свою базу; ударить несущего может любой.

local Players = game:GetService("Players")

local Ctx = require(script.Parent.Ctx)
local Bases = require(script.Parent.Bases)
local Island = require(script.Parent.Parent.World.Island)

local Game = Ctx.Game
local api = Ctx.api

local M: any = {}

local theme = 0
local anchor: BasePart? = nil
local cageHp = 0
local nextSpawn = 0
local carrying = false

local function cageParts(): { BasePart }
	local cage = workspace.Map.Season:FindFirstChild("Cage")
	local out = {}
	if cage then
		for _, p in cage:GetChildren() do
			if p:IsA("BasePart") then
				table.insert(out, p)
			end
		end
	end
	return out
end

local function setState(st: string)
	workspace:SetAttribute("SeasonState", st)
end

local function setCage(hp: number)
	cageHp = hp
	if anchor then
		setState(if hp > 0 then "caged" else "open")
	end
	local broken = hp <= 0
	for _, p in cageParts() do
		p.Transparency = if broken then 1 else 0
		p.CanCollide = not broken
		p:SetAttribute("HP", hp)
	end
	workspace.Map.Season:SetAttribute("CageHP", hp)
end

local function spawnArt()
	if anchor or carrying then
		return
	end
	local vault = workspace.Map.Season:FindFirstChild("Vault")
	if not vault then
		return
	end
	local id = "s" .. theme
	anchor = Bases.makeAnchor(id, CFrame.new(vault.Position + Vector3.new(0, 3.2, 0)), { Kind = "season" })
	setCage(Game.SEASON_CAGE_HP)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Steal"
	prompt:SetAttribute("Role", "season")
	prompt.ActionText = "Украсть"
	prompt.HoldDuration = Game.STEAL_HOLD
	prompt.MaxActivationDistance = Game.STEAL_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor
	prompt.Triggered:Connect(function(player)
		local S = Ctx.session(player)
		if S and S.ready then
			M.trySteal(S)
		end
	end)
	Ctx.fx("seasonSpawn", vault.Position, { id = id })
	for _, S in Ctx.sessions do
		Ctx.notify(S, "msg.seasonSpawn", nil, "gold")
	end
end

function M.trySteal(S: any)
	local a = anchor
	if not a or carrying or S.carry or cageHp > 0 or S.shadow then
		return
	end
	local r = Ctx.root(S)
	if not r or (r.Position - a.Position).Magnitude > Game.STEAL_RANGE + 2 then
		return
	end
	if not api.hasRoom(S) then
		Ctx.notify(S, "msg.noRoomSteal", nil, "bad")
		return
	end
	local id = a:GetAttribute("Id")
	a:Destroy()
	anchor = nil
	carrying = true
	setState("carried")
	api.startCarry(S, {
		id = id,
		lvl = 1,
		kind = "season",
		onFail = function()
			carrying = false
			spawnArt()
		end,
		onDeliver = function()
			carrying = false
			nextSpawn = os.clock() + Game.SEASON_ART_EVERY
			setState("waiting")
			workspace:SetAttribute("SeasonNext", workspace:GetServerTimeNow() + Game.SEASON_ART_EVERY)
			return true, nil
		end,
	})
end

-- взлом клетки
function M.hackCage(S: any)
	if cageHp <= 0 or not anchor or S.carry then
		return
	end
	local now = os.clock()
	if now - (S.hackT or 0) < Game.HACK_INTERVAL * 0.9 then
		return
	end
	local r = Ctx.root(S)
	if not r or (r.Position - Vector3.new(0, 95, 0)).Magnitude > 14 then
		return
	end
	S.hackT = now
	local dmg = if S.shadow then 0 else Game.TOOLS[S.data.tool].dmg
	setCage(math.max(0, cageHp - dmg))
	api.setPose(S, "hack", 0.6)
	Ctx.fx("hack", Vector3.new(0, 95, 0), nil)
	if cageHp <= 0 then
		Ctx.fx("wallBreak", Vector3.new(0, 95, 0), nil)
	end
end

local function portals()
	local hub = workspace.Map.Hub
	local season = workspace.Map.Season
	local debounce = {}
	local function hook(part: BasePart, target: CFrame)
		part.Touched:Connect(function(hit)
			local player = Players:GetPlayerFromCharacter(hit.Parent)
			if not player then
				return
			end
			if debounce[player] and os.clock() - debounce[player] < 2 then
				return
			end
			debounce[player] = os.clock()
			local S = Ctx.session(player)
			local r = Ctx.root(player)
			if r then
				if S then
					S.serverMoved = true
				end
				r.CFrame = target
				Ctx.fx("whoosh", target.Position, nil, player)
			end
		end)
	end
	hook(hub.SeasonPortal, CFrame.new(0, 94, 28) * CFrame.Angles(0, math.pi, 0))
	local pp = hub.SeasonPortal.Position
	local back = pp + (-(pp * Vector3.new(1, 0, 1))).Unit * 8
	hook(season.ReturnPortal, CFrame.new(Vector3.new(back.X, 4, back.Z)))
end

function M.theme(): number
	return theme
end

function M.init()
	theme = Game.seasonTheme(os.time())
	pcall(Island.setSeason, theme)
	workspace:SetAttribute("Season", theme)
	workspace:SetAttribute("SeasonEnds", Game.seasonEnds(os.time()))
	portals()
	nextSpawn = os.clock() + 60
	setState("waiting")
	workspace:SetAttribute("SeasonNext", workspace:GetServerTimeNow() + 60)
	Ctx.doActions.hackCage = function(S)
		M.hackCage(S)
	end
	task.spawn(function()
		while true do
			task.wait(5)
			local t = Game.seasonTheme(os.time())
			if t ~= theme then
				theme = t
				pcall(Island.setSeason, theme)
				workspace:SetAttribute("Season", theme)
				workspace:SetAttribute("SeasonEnds", Game.seasonEnds(os.time()))
				if anchor then
					anchor:Destroy()
					anchor = nil
				end
				nextSpawn = 0
				setState("waiting")
			end
			if not anchor and not carrying and os.clock() >= nextSpawn then
				spawnArt()
			end
			-- клетка восстанавливается, если её бросили
			if anchor and cageHp > 0 and cageHp < Game.SEASON_CAGE_HP then
				setCage(math.min(Game.SEASON_CAGE_HP, cageHp + 50))
			end
		end
	end)
end

return M
