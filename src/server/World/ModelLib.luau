--!strict
-- Библиотека 3D-моделей: при первом require загружает ассеты из Shared.Config.Models через InsertService:LoadAsset
-- (ассеты принадлежат владельцу плейса, поэтому загрузка разрешена), приводит их к общему виду и кладёт в
-- ServerStorage.Models. ModelLib.get(name) возвращает копию или nil — тогда игра строит старый вариант из деталей.
--
-- Что делает подготовка модели:
--   * масштаб — по Shared.Config.ModelSizes (импорт glTF может прийти в других единицах);
--   * точка опоры — низ по центру габарита (исключения — Shared.Config.ModelPivots), перед на −Z (см. docs/MODELS.md);
--   * детали Anchored, без коллизий (модель — только вид); цвета вершин не затемняются (Color = белый);
--   * детали с именем Glow_RRGGBB[_Tnn] — Neon нужного цвета, Tnn — прозрачность в процентах.

local InsertService = game:GetService("InsertService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Models = require(Shared.Config.Models) :: { [string]: number }
local Sizes = require(Shared.Config.ModelSizes) :: { [string]: Vector3 }
local Pivots = require(Shared.Config.ModelPivots) :: { [string]: Vector3 }

local M = {}

local LOAD_TRIES = 3
local PARALLEL = 6 -- сколько LoadAsset одновременно

local folder = Instance.new("Folder")
folder.Name = "Models"
folder.Parent = ServerStorage

local ready: { [string]: Model } = {}
local pending = 0
local started = false
local finished = false

local function maxAxis(v: Vector3): number
	return math.max(v.X, v.Y, v.Z)
end

local function prepare(name: string, asset: Instance): Model?
	local model = Instance.new("Model")
	model.Name = name
	local count = 0
	for _, d in asset:GetDescendants() do
		if d:IsA("BasePart") then
			local glow, rest = string.match(d.Name, "Glow_(%x%x%x%x%x%x)(.*)")
			d.Anchored = true
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			if glow then
				d.Material = Enum.Material.Neon
				d.Color = Color3.fromHex(glow)
				d.CastShadow = false
				local t = rest and string.match(rest, "_T(%d+)")
				if t then
					d.Transparency = math.clamp((tonumber(t) or 0) / 100, 0, 1)
				end
				d:SetAttribute("Glow", true)
			else
				d.Material = Enum.Material.SmoothPlastic
				d.Color = Color3.new(1, 1, 1)
			end
			d.Parent = model
			count += 1
		end
	end
	if count == 0 then
		model:Destroy()
		return nil
	end
	-- масштаб: сравниваем наибольшую сторону с ожидаемой
	local want = Sizes[name]
	local have = model:GetExtentsSize()
	if want and maxAxis(have) > 0 then
		local k = maxAxis(want) / maxAxis(have)
		if math.abs(k - 1) > 0.02 then
			model:ScaleTo(k)
			have = model:GetExtentsSize()
		end
		if math.abs(have.Y - want.Y) > math.max(0.5, want.Y * 0.1) then
			warn(("[ModelLib] %s: габарит %s не похож на ожидаемый %s (оси импорта?)"):format(name, tostring(have), tostring(want)))
		end
	end
	-- точка опоры: низ по центру (или своя — Config.ModelPivots: ось петель крышки, центр кольца конвейера)
	local cf, size = model:GetBoundingBox()
	model.WorldPivot = CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0) + (Pivots[name] or Vector3.zero))
	model:PivotTo(CFrame.new())
	model:SetAttribute("AssetId", Models[name])
	return model
end

local function loadOne(name: string, id: number)
	for try = 1, LOAD_TRIES do
		local ok, res = pcall(function()
			return InsertService:LoadAsset(id)
		end)
		if ok and typeof(res) == "Instance" then
			local model = prepare(name, res)
			res:Destroy()
			if model then
				model.Parent = folder
				ready[name] = model
			else
				warn(("[ModelLib] %s (%d): в ассете нет деталей"):format(name, id))
			end
			return
		end
		if try == LOAD_TRIES then
			warn(("[ModelLib] %s (%d) не загрузилась: %s"):format(name, id, tostring(res)))
		else
			task.wait(1.5 * try)
		end
	end
end

-- Запускает загрузку (один раз). Вызывается сам при require.
function M.start()
	if started then
		return
	end
	started = true
	local queue: { string } = {}
	for name, id in Models do
		if type(id) == "number" and id > 0 then
			table.insert(queue, name)
		end
	end
	table.sort(queue)
	pending = #queue
	if pending == 0 then
		finished = true
		return
	end
	local nextIndex = 1
	for _ = 1, math.min(PARALLEL, #queue) do
		task.spawn(function()
			while nextIndex <= #queue do
				local name = queue[nextIndex]
				nextIndex += 1
				loadOne(name, Models[name])
				pending -= 1
			end
			if pending <= 0 and not finished then
				finished = true
				local n = 0
				for _ in ready do
					n += 1
				end
				print(("[ModelLib] загружено моделей: %d из %d"):format(n, #queue))
			end
		end)
	end
end

-- Ждёт окончания загрузки (не дольше timeout секунд). Возвращает true, если всё закончилось.
function M.wait(timeout: number?): boolean
	local deadline = os.clock() + (timeout or 20)
	while not finished and os.clock() < deadline do
		task.wait(0.1)
	end
	return finished
end

-- Копия модели или nil, если её нет (не загружена / ID = 0 / ещё грузится).
function M.get(name: string): Model?
	local src = ready[name]
	if not src then
		return nil
	end
	return src:Clone()
end

function M.has(name: string): boolean
	return if ready[name] then true else false
end

M.start()

return M
