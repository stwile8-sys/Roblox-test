-- Хронометраж кругов. Всё считает сервер по положению машины;
-- клиент только показывает атрибуты игрока.

local Players = game:GetService("Players")

local Race = {}

local SECTORS = 6

type PlayerRace = {
	prevFrac: number?,
	nextCp: number,
	lapStart: number?,
}

local races: { [Player]: PlayerRace } = {}
local best: { [Player]: number } = {}

local function fmt(t: number): string
	local m = math.floor(t / 60)
	return string.format("%d:%05.2f", m, t - m * 60)
end
Race.format = fmt

local function setStat(player: Player, value: string)
	local ls = player:FindFirstChild("leaderstats")
	local v = ls and ls:FindFirstChild("Лучший круг") :: StringValue?
	if v then
		v.Value = value
	end
end

function Race.start(track, driverCar: (Player) -> Model?, board: TextLabel?)
	local minLap = track.length / 230

	local function refreshBoard()
		if not board then
			return
		end
		local list = {}
		for player, t in best do
			if player.Parent then
				table.insert(list, { name = player.DisplayName, t = t })
			end
		end
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
		local lines = { "ЛУЧШИЕ КРУГИ" }
		for i = 1, math.min(5, #list) do
			table.insert(lines, string.format("%d. %s — %s", i, list[i].name, fmt(list[i].t)))
		end
		if #list == 0 then
			table.insert(lines, "пока пусто — будь первым!")
		end
		board.Text = table.concat(lines, "\n")
	end
	refreshBoard()

	local function setup(player: Player)
		local ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		local v = Instance.new("StringValue")
		v.Name = "Лучший круг"
		v.Value = "—"
		v.Parent = ls
		ls.Parent = player
		player:SetAttribute("LapStart", -1)
		player:SetAttribute("LapCount", 0)
		player:SetAttribute("Checkpoint", 0)
	end
	for _, p in Players:GetPlayers() do
		setup(p)
	end
	Players.PlayerAdded:Connect(setup)
	Players.PlayerRemoving:Connect(function(player)
		races[player] = nil
		best[player] = nil
		refreshBoard()
	end)

	local function stop(player: Player, r: PlayerRace)
		r.lapStart = nil
		r.prevFrac = nil
		r.nextCp = 1
		player:SetAttribute("LapStart", -1)
		player:SetAttribute("Checkpoint", 0)
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			for _, player in Players:GetPlayers() do
				local r = races[player]
				if not r then
					r = { prevFrac = nil, nextCp = 1, lapStart = nil }
					races[player] = r
				end
				local car = driverCar(player)
				local body = car and car.PrimaryPart
				if not body then
					if r.lapStart or r.prevFrac then
						stop(player, r)
					end
					continue
				end
				local d, _, i = track:query(body.Position.X, body.Position.Z)
				if not d or d > track.HALF_W + 14 then
					continue -- вне трассы: не считаем
				end
				local frac = track.cum[i] / track.length
				local prev = r.prevFrac
				r.prevFrac = frac
				if not prev then
					continue
				end
				local now = workspace:GetServerTimeNow()
				local forwardCross = prev > 0.8 and frac < 0.2
				local backwardCross = prev < 0.2 and frac > 0.8
				if backwardCross then
					stop(player, r)
					r.prevFrac = frac
				elseif forwardCross then
					if r.lapStart and r.nextCp > SECTORS - 1 then
						local t = now - r.lapStart
						if t >= minLap then
							player:SetAttribute("LastLap", t)
							player:SetAttribute("LapCount", (player:GetAttribute("LapCount") or 0) + 1)
							if not best[player] or t < best[player] then
								best[player] = t
								player:SetAttribute("BestLap", t)
								setStat(player, fmt(t))
								refreshBoard()
							end
						end
					end
					r.lapStart = now
					r.nextCp = 1
					player:SetAttribute("LapStart", now)
					player:SetAttribute("Checkpoint", 0)
				elseif r.lapStart and r.nextCp <= SECTORS - 1 then
					local cp = r.nextCp / SECTORS
					if frac >= cp and frac < cp + 0.1 then
						r.nextCp += 1
						player:SetAttribute("Checkpoint", r.nextCp - 1)
					end
				end
			end
		end
	end)
end

return Race
