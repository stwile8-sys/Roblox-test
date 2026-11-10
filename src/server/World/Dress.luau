--!nonstrict
-- «Одевание» мира в 3D-модели (ModelLib). Логика и коллизии остаются на старых деталях — их делаем невидимыми,
-- а поверх ставим модель-«кожу» (Model с именем Skin). Если модели нет — остаётся старый вид из деталей.

local CollectionService = game:GetService("CollectionService")

local ModelLib = require(script.Parent.ModelLib)
local BaseBuilder = require(script.Parent.BaseBuilder)
local Island = require(script.Parent.Island)

local M: any = {}

local function hide(p: Instance)
	if p:IsA("BasePart") then
		p.Transparency = 1
		p.CastShadow = false
	elseif p:IsA("Decal") or p:IsA("Texture") then
		(p :: any).Transparency = 1
	end
end

local function hideTree(root: Instance, keep: { [string]: boolean }?)
	for _, d in root:GetDescendants() do
		if not (keep and keep[d.Name]) and not d:IsDescendantOf(root:FindFirstChild("Skin") or Instance.new("Folder")) then
			hide(d)
		end
	end
end

-- поставить модель name в точку cf (низ по центру), необязательный масштаб
local function place(name: string, parent: Instance, cf: CFrame, scale: number?, skinName: string?): Model?
	local m = ModelLib.get(name)
	if not m then
		return nil
	end
	if scale and math.abs(scale - 1) > 0.01 then
		m:ScaleTo(scale)
	end
	m.Name = skinName or "Skin"
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("T0", p.Transparency)
		end
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

-- ── Стены ───────────────────────────────────────────────────
function M.wall(seg: BasePart, level: number)
	local old = seg:FindFirstChild("Skin")
	if old then
		old:Destroy()
	end
	local name = (if seg:GetAttribute("Gate") then "gate" else "wall") .. math.clamp(level, 1, 5)
	local skin = place(name, seg, seg.CFrame * CFrame.new(0, -seg.Size.Y / 2, 0), seg.Size.X / 39)
	if not skin then
		return
	end
	seg.Transparency = 1
	local decor = seg:FindFirstChild("Decor")
	if decor then
		for _, p in decor:GetDescendants() do
			hide(p)
		end
	end
	if seg:GetAttribute("Broken") then
		for _, p in skin:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = 1
			end
		end
	end
end

-- ── Ловушки ─────────────────────────────────────────────────
local TRAP_MODEL = { mine = "mine", slow = "slowField", decoy = "decoyPedestal" }
function M.trap(pad: BasePart, kind: string, skin: string?): boolean
	local name = if kind == "mine" and skin == "blackhole" then "blackHole" else TRAP_MODEL[kind]
	if not name or not ModelLib.has(name) then
		return false
	end
	local f = Instance.new("Folder")
	f.Name = "Vis"
	f.Parent = pad
	local m = place(name, f, pad.CFrame * CFrame.new(0, pad.Size.Y / 2, 0), if kind == "slow" then 2 else 1, "Model")
	if kind == "slow" and m then
		-- поле больше модели-излучателя: добавим прозрачный купол
		local dome = Instance.new("Part")
		dome.Shape = Enum.PartType.Ball
		dome.Size = Vector3.new(14, 7, 14)
		dome.CFrame = pad.CFrame
		dome.Material = Enum.Material.ForceField
		dome.Color = Color3.fromHex("#7B2FF7")
		dome.Anchored = true
		dome.CanCollide = false
		dome.CanQuery = false
		dome.CanTouch = false
		dome.Parent = f
	end
	return m ~= nil
end

-- ── База ────────────────────────────────────────────────────
local function dressPedestals(container: Instance, rich: boolean)
	for _, ped in container:GetChildren() do
		if ped:IsA("Model") and string.match(ped.Name, "^P%d+$") and not ped:FindFirstChild("Skin") then
			local top = ped:FindFirstChild("Top")
			if top and top:IsA("BasePart") then
				local floor = top.Position - Vector3.new(0, 3.3, 0)
				local look = top.CFrame - top.Position
				if place(if rich then "pedestalRich" else "pedestal", ped, CFrame.new(floor) * look) then
					for _, p in ped:GetChildren() do
						if p:IsA("BasePart") then
							hide(p)
						end
					end
				end
			end
		end
	end
end

local function islandUnder(holder: Instance, parent: Instance, name: string, topY: number, scale: number?)
	local center = holder:GetAttribute("IslandCenter")
	if not center then
		return
	end
	local size = if name == "islandBig" then 49.55 else 26.23
	local m = place(name, parent, CFrame.new(center.X, topY - size * (scale or 1), center.Z), scale, "IslandSkin")
	if m then
		for _, p in holder:GetChildren() do
			if p:IsA("BasePart") and p:GetAttribute("IslandVis") ~= nil then
				hide(p)
			end
		end
		-- кристаллы и слои острова (клоны травяной детали) тоже помечены IslandVis
	end
end

function M.base(base: any)
	local floor = base:FindFirstChild("Floor")
	if not floor then
		return
	end
	local cf = floor.CFrame * CFrame.new(0, floor.Size.Y / 2, 0)
	-- остров под базой: верх травы чуть ниже пола
	islandUnder(base, base, "islandBig", cf.Position.Y - 0.4)
	-- стены
	local lvl = 1
	for _, seg in base.Walls:GetChildren() do
		if seg:IsA("BasePart") then
			lvl = (seg:GetAttribute("Level") or 1) :: number
			M.wall(seg, lvl)
		end
	end
	-- пьедесталы
	dressPedestals(base.Pedestals, false)
	local f2 = base:FindFirstChild("Floor2")
	if f2 then
		dressPedestals(f2, true)
	end
	-- верстак
	local bench = base:FindFirstChild("Bench")
	local prompt = bench and bench:FindFirstChild("Prompt")
	if bench and prompt and not bench:FindFirstChild("Skin") then
		if place("bench", bench, (cf - cf.Position) + Vector3.new(prompt.Position.X, cf.Position.Y, prompt.Position.Z), 1.5) then
			for _, p in bench:GetChildren() do
				if p:IsA("BasePart") and p.Name ~= "Prompt" then
					hide(p)
				end
			end
		end
	end
	-- декор: кусты и ящики заменяем моделями, по острову вне стен — деревья, камни, грибы, кристаллы
	local decor = base:FindFirstChild("Decor")
	if decor and not decor:GetAttribute("Dressed") then
		decor:SetAttribute("Dressed", true)
		for _, p in decor:GetChildren() do
			if p:IsA("BasePart") and p.Material == Enum.Material.Grass then
				if place("bush", decor, CFrame.new(p.Position - Vector3.new(0, p.Size.Y / 2, 0)) * CFrame.Angles(0, math.random() * 6, 0), 1, "Bush") then
					hide(p)
				end
			elseif p:IsA("BasePart") and p.Material == Enum.Material.WoodPlanks and p.Size.X <= 3.2 then
				if place("crate", decor, CFrame.new(p.Position - Vector3.new(0, p.Size.Y / 2, 0)) * (p.CFrame - p.CFrame.Position), 1, "Crate") then
					hide(p)
				end
			end
		end
		local rng = Random.new((base:GetAttribute("Index") or 1) :: number)
		local props = { "tree", "tree", "rock", "mushroom", "crystalB", "tree", "crystalC", "rock", "tree", "mushroom" }
		for i, name in props do
			-- кольцо между стенами (58) и краем острова (~88); не ставить перед воротами (там мост)
			local a = (i / #props) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
			local r = rng:NextNumber(66, 80)
			local lp = Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
			if not (lp.Z < -55 and math.abs(lp.X) < 16) and not (math.abs(lp.X) > 55 and math.abs(lp.Z) < 12) then
				place(name, decor, cf * CFrame.new(lp.X, -0.4, lp.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.9, 1.3), "Prop")
			end
		end
	end
end

-- ── Хаб, мосты, сезонный остров ─────────────────────────────
local function dressBridge(rec: any, parent: Instance)
	local len = (rec.b - rec.a).Magnitude
	local n = math.max(1, math.floor(len / 30 + 0.5))
	local seg = len / n
	local dir = (rec.b - rec.a).Unit
	local ok = false
	for i = 0, n - 1 do
		local c = rec.a + dir * (seg * (i + 0.5))
		local m = place("bridge", parent, CFrame.lookAt(c - Vector3.new(0, 1.6, 0), c - Vector3.new(0, 1.6, 0) + dir), nil, "BridgeSkin")
		if m then
			ok = true
			-- подогнать длину секции и ширину
			local size = m:GetExtentsSize()
			local k = seg / math.max(1, size.Z)
			if math.abs(k - 1) > 0.03 then
				m:ScaleTo(k)
				m:PivotTo(CFrame.lookAt(c - Vector3.new(0, 1.6 * k, 0), c - Vector3.new(0, 1.6 * k, 0) + dir))
			end
		end
	end
	if ok then
		for _, p in rec.parts do
			if not p.CanCollide then
				hide(p)
			else
				-- доски пола остаются для ходьбы, но невидимы; перила тоже
				hide(p)
			end
		end
	end
end

function M.world()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	local hub = map:FindFirstChild("Hub")
	if hub then
		-- остров под хабом: верх травы −4
		islandUnder(hub, hub, "islandMid", -4, 1.55)
		-- деревья и кусты по краю хаба между мостами
		local deco = Instance.new("Folder")
		deco.Name = "Props"
		deco.Parent = hub
		local list = { "tree", "bush", "crystalC", "tree", "lantern", "bush", "tree", "crystalB" }
		for i = 1, 16 do
			local deg = (i - 0.5) / 16 * 360
			local a = math.rad(deg)
			-- мосты на 0,45,90…: ставим только посередине между ними
			if math.abs(((deg + 22.5) % 45) - 22.5) > 14 then
				place(list[(i - 1) % #list + 1], deco, CFrame.new(math.sin(a) * 66, 0, math.cos(a) * 66) * CFrame.Angles(0, a, 0), 1, "Prop")
			end
		end
	end
	for _, rec in Island.bridges or {} do
		local bridges = map:FindFirstChild("Bridges")
		if bridges then
			dressBridge(rec, bridges)
		end
	end
	local season = map:FindFirstChild("Season")
	if season then
		islandUnder(season, season, "islandMid", 86, 1)
	end
	for _, b in workspace.Bases:GetChildren() do
		if b:IsA("Model") then
			pcall(M.base, b)
		end
	end
end

-- Запуск: ждём загрузку моделей и переодеваем мир. Новое (стены при апгрейде, ловушки, второй этаж) —
-- через хуки BaseBuilder.dress.
function M.start()
	task.spawn(function()
		ModelLib.wait(40)
		BaseBuilder.dress = M
		local ok, err = pcall(M.world)
		if not ok then
			warn("[Dress]", err)
		end
		if M.onReady then
			pcall(M.onReady)
		end
		-- второй этаж строится позже — проверяем периодически
		while true do
			task.wait(5)
			for _, b in workspace.Bases:GetChildren() do
				local f2 = b:FindFirstChild("Floor2")
				if f2 and #f2:GetChildren() > 0 then
					pcall(dressPedestals, f2, true)
				end
			end
		end
	end)
end

local _cs = CollectionService
local _ht = hideTree
return M
