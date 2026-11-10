--!nonstrict
-- «Одевание» мира в 3D-модели (ModelLib). Логика и коллизии остаются на старых деталях — их делаем невидимыми,
-- а поверх ставим модель-«кожу» (Model с именем Skin). Если модели нет — остаётся старый вид из деталей.

local CollectionService = game:GetService("CollectionService")

local ModelLib = require(script.Parent.ModelLib)
local BaseBuilder = require(script.Parent.BaseBuilder)
local Island = require(script.Parent.Island)
local Defs = require(game:GetService("ReplicatedStorage").Shared.Art.Defs)

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
	-- плита сбора дохода
	local collect = base:FindFirstChild("Collect")
	if collect and not base:FindFirstChild("CollectSkin") then
		local rim = base:FindFirstChild("CollectRim")
		local at = (cf - cf.Position) + Vector3.new(collect.Position.X, cf.Position.Y, collect.Position.Z)
		if place("collectPlate", base, at, nil, "CollectSkin") then
			hide(collect)
			if rim then
				hide(rim)
			end
		end
	end
	-- кнопка замка: модель-тумба, её деталь Button перекрашивает Raid (жёлтая / серая на перезарядке)
	local lock = base:FindFirstChild("LockButton")
	local btn = lock and lock:FindFirstChild("Button")
	if lock and btn and not lock:FindFirstChild("Skin") then
		local at = (cf - cf.Position) + Vector3.new(btn.Position.X, cf.Position.Y, btn.Position.Z)
		local m = place("lockButton", lock, at)
		if m then
			local mb = m:FindFirstChild("Button", true)
			if mb and mb:IsA("BasePart") then
				mb.Color = btn.Color
			end
			for _, p in lock:GetChildren() do
				if p:IsA("BasePart") then
					hide(p)
				end
			end
		end
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
	if hub then
		pcall(M.hub, hub)
	end
	local season = map:FindFirstChild("Season")
	if season then
		islandUnder(season, season, "islandMid", 86, 1)
		pcall(M.season, season)
	end
	for _, b in workspace.Bases:GetChildren() do
		if b:IsA("Model") then
			pcall(M.base, b)
		end
	end
end


-- список старых деталей снимаем ДО того, как положить модель внутрь
local function snapshot(root: Instance): { BasePart }
	local out = {}
	for _, p in root:GetDescendants() do
		if p:IsA("BasePart") then
			table.insert(out, p)
		end
	end
	return out
end

local function hideList(list: { BasePart }, keep: ((BasePart) -> boolean)?)
	for _, p in list do
		if not (keep and keep(p)) then
			hide(p)
		end
	end
end

local function flatLook(pos: Vector3, target: Vector3): CFrame
	local t = Vector3.new(target.X, pos.Y, target.Z)
	return CFrame.lookAt(pos, t)
end

-- ── Второй этаж: настил с колоннами и лестница (коллизии — старые детали) ──
function M.floor2(f2: Instance, cf: CFrame)
	if f2:FindFirstChild("FloorSkin") or not ModelLib.has("floor2") then
		return
	end
	local old = {}
	for _, p in f2:GetChildren() do
		if p:IsA("BasePart") then
			table.insert(old, p)
		end
	end
	if place("floor2", f2, cf * CFrame.new(0, 0, 33), nil, "FloorSkin") then
		place("stairs", f2, cf * CFrame.new(51, 0, -13), nil, "StairsSkin")
		hideList(old)
	end
	dressPedestals(f2, true)
end

-- ── Хаб: сундук, кольцевой конвейер, порталы, подиумы, доски, алтарь, статуи ──
function M.hub(hub: Instance)
	-- сундук на пьедестале, крышка приоткрыта на петлях
	local chest = hub:FindFirstChild("Chest")
	if chest and not chest:FindFirstChild("Skin") and ModelLib.has("chest") and ModelLib.has("chestPedestal") then
		local old = snapshot(chest)
		local ped = place("chestPedestal", chest, CFrame.new(0, 0, 0))
		local py = if ped then ped:GetExtentsSize().Y else 4.6
		local body = place("chest", chest, CFrame.new(0, py, 0), nil, "ChestSkin")
		local by = if body then body:GetExtentsSize().Y else 5.5
		place("chestLid", chest, CFrame.new(0, py + by - 0.15, 3.635) * CFrame.Angles(math.rad(32), 0, 0), nil, "LidSkin")
		hideList(old, function(p)
			return CollectionService:HasTag(p, "Float")
		end)
	end
	-- кольцевой конвейер: 44 дуги вокруг центра (опора дуги — центр кольца)
	local ring = hub:FindFirstChild("Ring")
	local R, A0, span = hub:GetAttribute("RingR"), hub:GetAttribute("RingA0"), hub:GetAttribute("RingSpan")
	if ring and R and A0 and span and not ring:FindFirstChild("Arcs") and ModelLib.has("beltArc") then
		local old = snapshot(ring)
		local arcs = Instance.new("Folder")
		arcs.Name = "Arcs"
		arcs.Parent = ring
		local N = 44
		local d = span / N
		for i = 0, N - 1 do
			local a = A0 + d * (i + 0.5)
			place("beltArc", arcs, CFrame.Angles(0, -a - math.pi / 2, 0), R / 26.969, "Arc")
		end
		local function portal(name: string, a: number)
			local cf = CFrame.new(math.cos(a) * R, 0, math.sin(a) * R) * CFrame.Angles(0, -a, 0)
			place(name, arcs, cf, 1.15, "Portal")
		end
		portal("portalStart", A0)
		portal("portalEnd", A0 + span)
		hideList(old)
	end
	-- подиумы скинов (манекен уже в модели)
	for i = 1, 4 do
		local pm = hub:FindFirstChild("Podium" .. i)
		local stand = pm and pm:FindFirstChild("Stand")
		if pm and stand and not pm:FindFirstChild("Skin") then
			local pos = Vector3.new(stand.Position.X, 0, stand.Position.Z)
			local old = snapshot(pm)
			if place("skinPodium", pm, flatLook(pos, Vector3.zero)) then
				hideList(old)
				local rig = pm:FindFirstChild("Mannequin")
				if rig then
					rig:Destroy()
				end
			end
		end
	end
	-- доски лидеров: тёмное поле модели, текст светлый
	for _, name in { "Board_Titan", "Board_Collection", "Board_Clans" } do
		local b = hub:FindFirstChild(name)
		if b and b:IsA("BasePart") and not b:GetAttribute("Dressed") then
			local pos = Vector3.new(b.Position.X, 0, b.Position.Z)
			local cf = flatLook(pos, Vector3.zero)
			local holder = Instance.new("Folder")
			holder.Name = name .. "_Skin"
			holder.Parent = hub
			if place("leaderboard", holder, cf) then
				b:SetAttribute("Dressed", true)
				b:SetAttribute("Ink", Color3.fromHex("#FFF4DE"))
				-- старые рамка и стойки рядом с доской
				for _, p in hub:GetChildren() do
					if p:IsA("BasePart") and p ~= b and p.Name == "Part" and (p.Position - b.Position).Magnitude < 14 then
						hide(p)
					end
				end
				b.Size = Vector3.new(14.6, 8.6, 0.2)
				b.CFrame = cf * CFrame.new(0, 9.3, -0.45)
				b.Transparency = 1
				local title = b:FindFirstChild("Gui") and b.Gui:FindFirstChild("Title")
				if title then
					title.TextColor3 = Color3.fromHex("#FFE066")
				end
				for _, t in (b:FindFirstChild("Gui") and b.Gui:FindFirstChild("List") or holder):GetChildren() do
					if t:IsA("TextLabel") then
						t.TextColor3 = Color3.fromHex("#FFF4DE")
					end
				end
			end
		end
	end
	-- алтарь ребёрса
	local altar = hub:FindFirstChild("Altar")
	local top = altar and altar:FindFirstChild("Top")
	if altar and top and not altar:FindFirstChild("Skin") then
		local old = snapshot(altar)
		if place("rebirthAltar", altar, CFrame.new(top.Position.X, 0, top.Position.Z)) then
			hideList(old)
		end
	end
	-- статуи на пьедесталах
	local statues = hub:FindFirstChild("Statues")
	if statues and not statues:GetAttribute("Dressed") then
		statues:SetAttribute("Dressed", true)
		for _, p in statues:GetChildren() do
			if p:IsA("BasePart") and not string.match(p.Name, "^Statue") then
				local pos = Vector3.new(p.Position.X, 0, p.Position.Z)
				if place("statuePedestal", statues, flatLook(pos, Vector3.zero), nil, "Pedestal") then
					hide(p)
				end
			end
		end
		-- существо стоит на верху пьедестала
		for _, a in statues:GetChildren() do
			if a:IsA("BasePart") and string.match(a.Name, "^Statue") then
				local d = Defs.BY_ID[a:GetAttribute("Id")]
				local size = (if d then Defs.RARITY[d.rarity].size else 2) * ((a:GetAttribute("Scale") or 1) :: number)
				a.CFrame = (a.CFrame - a.Position) + Vector3.new(a.Position.X, 4.11 + size / 2 + 0.1, a.Position.Z)
			end
		end
	end
	-- сезонный портал
	local sp = hub:FindFirstChild("SeasonPortal")
	if sp and sp:IsA("BasePart") and not hub:FindFirstChild("SeasonPortalSkin") then
		local pos = Vector3.new(sp.Position.X, 0.4, sp.Position.Z)
		if place("seasonPortal", hub, flatLook(pos, Vector3.zero), nil, "SeasonPortalSkin") then
			hide(sp)
		end
	end
end

-- ── Сезонный остров: алтарь Титана, клетка, декор сезона ────
local SEASON_PROPS = {
	{ "s1Pumpkin", "s1Torch" },
	{ "s2Tree", "s2Snowman" },
	{ "s3Palm", "s3Shells" },
	{ "s4Sakura", "s4Flowers" },
	{ "s5Planet", "s5Meteor" },
	{ "s6Coral", "s6Bubbles" },
}

function M.season(season: Instance)
	local vault = season:FindFirstChild("Vault")
	if vault and not season:FindFirstChild("AltarSkin") then
		local h = 3.8
		if place("titanAltar", season, CFrame.new(0, vault.Position.Y - 0.2 - h, 0), nil, "AltarSkin") then
			for _, p in season:GetChildren() do
				-- три яруса старого алтаря и их ободки — цилиндры в центре
				if p:IsA("BasePart") and p.Name == "Part" and p.Shape == Enum.PartType.Cylinder and Vector3.new(p.Position.X, 0, p.Position.Z).Magnitude < 1 and p.Position.Y > 89.5 then
					hide(p)
				end
			end
			hide(vault)
		end
	end
	local cage = season:FindFirstChild("Cage")
	local frame = season:FindFirstChild("CageFrame")
	if cage and frame and not season:FindFirstChild("CageSkin") then
		if place("cage", season, CFrame.new(0, (vault and vault.Position.Y or 93.2) + 0.1, 0), nil, "CageSkin") then
			for _, p in frame:GetChildren() do
				if p:IsA("BasePart") then
					hide(p)
				end
			end
			for _, p in cage:GetChildren() do
				if p:IsA("BasePart") then
					hide(p)
				end
			end
			M.cage((cage:GetAttribute("HP") or season:GetAttribute("CageHP") or 1) :: number > 0)
		end
	end
	M.seasonDecor(workspace:GetAttribute("Season") or 1)
end

-- клетка цела / сломана (вызывает Seasons)
function M.cage(intact: boolean)
	local season = workspace.Map:FindFirstChild("Season")
	local skin = season and season:FindFirstChild("CageSkin")
	if not skin then
		return
	end
	for _, p in skin:GetDescendants() do
		if p:IsA("BasePart") then
			local isBar = string.match(p.Name, "^Bar") ~= nil
			if isBar then
				p.Transparency = if intact then (p:GetAttribute("T0") or 0) else 1
			end
		end
	end
end

function M.seasonDecor(i: number)
	local season = workspace.Map:FindFirstChild("Season")
	local decor = season and season:FindFirstChild("Decor")
	local pair = SEASON_PROPS[i] or SEASON_PROPS[1]
	if not decor or not ModelLib.has(pair[1]) then
		return
	end
	decor:ClearAllChildren()
	local rng = Random.new(i * 77)
	for n = 1, 18 do
		local a = n / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		if math.abs(math.sin(a) - 1) < 0.12 then
			continue
		end
		local r = if n % 2 == 0 then rng:NextNumber(30, 40) else rng:NextNumber(17, 25)
		local name = pair[(n % 2) + 1]
		place(name, decor, CFrame.new(math.cos(a) * r, 90, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.9, 1.25), "Prop")
	end
end

-- 3D-существа для клиента: копии art_<id> в ReplicatedStorage.ArtMeshes
local function publishArt()
	local rs = game:GetService("ReplicatedStorage")
	local f = rs:FindFirstChild("ArtMeshes") or Instance.new("Folder")
	f.Name = "ArtMeshes"
	local Models = require(rs.Shared.Config.Models)
	for name in Models do
		if string.sub(name, 1, 4) == "art_" and not f:FindFirstChild(name) then
			local m = ModelLib.get(name)
			if m then
				m.Name = name
				m:PivotTo(CFrame.new())
				m.Parent = f
			end
		end
	end
	f.Parent = rs
end

-- Запуск: ждём загрузку моделей и переодеваем мир. Новое (стены при апгрейде, ловушки, второй этаж) —
-- через хуки BaseBuilder.dress.
function M.start()
	task.spawn(function()
		ModelLib.wait(120)
		BaseBuilder.dress = M
		Island.dress = M
		pcall(publishArt)
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
					local idx = b:GetAttribute("Index")
					if idx and not f2:FindFirstChild("FloorSkin") then
						pcall(M.floor2, f2, BaseBuilder.baseCFrame(idx))
					end
					pcall(dressPedestals, f2, true)
				end
			end
		end
	end)
end

local _cs = CollectionService
local _ht = hideTree
return M
