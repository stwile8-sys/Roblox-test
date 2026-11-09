--!nonstrict
-- Клиент рисует и анимирует существ поверх невидимых серверных якорей (тег "Art").
-- Все анимации — кодом, плавно (синусы, сглаживание), один проход за кадр, без создания инстансов в кадре.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Defs = require(Shared.Art.Defs)
local Build = require(Shared.Art.Build)
local Assets = require(Shared.Config.Assets)
local Palette = require(Shared.Config.Palette)

local M: any = {}

local RANGE = 220
local LIGHTS = 24
local player = Players.LocalPlayer

local folder = Instance.new("Folder")
folder.Name = "ClientArts"
folder.Parent = workspace

local visuals: { [BasePart]: any } = {}
local anchors: { [BasePart]: boolean } = {}
local voicesPlaying = 0

local FACE = { head = true, eye = true, lid = true, mouth = true }

local function build(anchor: BasePart): any
	local id = anchor:GetAttribute("Id")
	local d = Defs.BY_ID[id]
	if not d then
		return nil
	end
	local scale = anchor:GetAttribute("Scale") or 1
	local model = Build.model(id, scale, false)
	local root = model.PrimaryPart
	local parts, offsets, roles = {}, {}, {}
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p ~= root then
			table.insert(parts, p)
			table.insert(offsets, p.CFrame) -- модель собрана в начале координат
			table.insert(roles, {
				role = p:GetAttribute("Role") or "body",
				phase = p:GetAttribute("Phase") or math.random() * 6,
				wing = p:GetAttribute("Wing"),
				glitch = p:GetAttribute("Glitch"),
				t0 = p.Transparency,
				y = p.Size.Y,
			})
		end
	end
	local k = model:GetAttribute("K") or 1
	local v = {
		anchor = anchor,
		model = model,
		root = root,
		parts = parts,
		offsets = offsets,
		roles = roles,
		def = d,
		k = k,
		rarity = Defs.RARITY[d.rarity].index,
		phase = math.random() * 10,
		blinkAt = os.clock() + math.random() * 5 + 2,
		lookAt = os.clock() + math.random() * 3 + 5,
		yaw = 0,
		yawTarget = 0,
		anim = nil,
		animT0 = 0,
		lastAnimT = anchor:GetAttribute("AnimT"),
		light = root:FindFirstChild("Glow"),
		voiceAt = os.clock() + math.random(10, 20),
		glitchOff = {},
		glitchUntil = 0,
		lagCF = nil,
		cfs = table.create(#parts),
	}
	v.lightBase = v.light and v.light.Brightness or 0
	-- эхо-двойник у хроно-аномалий
	if d.rarity == "chrono" then
		local echo = model:Clone()
		for _, p in echo:GetDescendants() do
			if p:IsA("BasePart") then
				p.Transparency = math.max(p.Transparency, 0.75)
				p.Material = Enum.Material.ForceField
			elseif p:IsA("Light") or p:IsA("ParticleEmitter") then
				p:Destroy()
			end
		end
		echo.Parent = folder
		local eparts = {}
		for _, p in echo:GetDescendants() do
			if p:IsA("BasePart") and p.Name ~= "Root" then
				table.insert(eparts, p)
			end
		end
		v.echo = echo
		v.eparts = eparts
		v.ecfs = table.create(#eparts)
	end
	model.Parent = folder
	return v
end

local function destroy(v: any)
	v.model:Destroy()
	if v.echo then
		v.echo:Destroy()
	end
end

local function baseCF(v: any, now: number): CFrame
	local a = v.anchor
	local kind = a:GetAttribute("Kind")
	if kind == "belt" then
		local from, to = a:GetAttribute("From"), a:GetAttribute("To")
		local t0, dur = a:GetAttribute("T0"), a:GetAttribute("Dur")
		if from and to and t0 and dur then
			local t = math.clamp((workspace:GetServerTimeNow() - t0) / dur, 0, 1)
			local p = from:Lerp(to, t)
			-- переваливание с боку на бок во время езды
			local wob = math.sin(now * 8 + v.phase) * 0.12
			return CFrame.lookAt(p, to) * CFrame.Angles(0, 0, wob) * CFrame.new(0, math.abs(math.sin(now * 8 + v.phase)) * 0.15 * v.k, 0)
		end
	end
	return a.CFrame
end

local function playVoice(v: any)
	local key = ({ "voiceCommon", "voiceRare", "voiceEpic", "voiceLegendary", "voiceChrono" })[v.rarity]
	local id = Assets.sfx[key]
	if not id or id == 0 or voicesPlaying >= 2 then
		return
	end
	local s = Instance.new("Sound")
	s.SoundId = "rbxassetid://" .. id
	s.Volume = 0.35 + v.rarity * 0.08
	s.RollOffMaxDistance = if v.rarity >= 4 then 160 else 45
	s.PlaybackSpeed = 0.9 + math.random() * 0.25
	s.Parent = v.root
	voicesPlaying += 1
	s.Ended:Connect(function()
		voicesPlaying -= 1
		s:Destroy()
	end)
	s:Play()
	task.delay(4, function()
		if s.Parent then
			voicesPlaying -= 1
			s:Destroy()
		end
	end)
end

local function ease(t: number): number
	return t * t * (3 - 2 * t)
end

-- кадр одного существа
local function step(v: any, now: number, dt: number, myPos: Vector3?, allParts: { BasePart }, allCFs: { CFrame })
	local a = v.anchor
	local animT = a:GetAttribute("AnimT")
	if animT ~= v.lastAnimT then
		v.lastAnimT = animT
		v.anim = a:GetAttribute("Anim")
		v.animT0 = now
	end
	local t = now + v.phase
	local k = v.k
	local r = v.rarity
	local cf = baseCF(v, now)
	local kind = a:GetAttribute("Kind")
	-- покачивание (Idle float): 0.1 стада × масштаб, цикл 2 сек
	local bob = math.sin(t * math.pi) * 0.1 * math.max(1, k * 0.5)
	if kind == "carry" then
		bob = math.sin(t * 6) * 0.15
	end
	local spin = 0
	if r == 4 then
		spin = t * 0.25 -- легендарные медленно вращаются
	end
	local scale = 1
	if r >= 3 then
		scale = 1 + math.sin(t * 1.6) * 0.035 -- «дыхание»
	end
	local hide = false
	local extraY = 0
	local flicker = false
	-- одноразовые анимации
	if v.anim then
		local e = now - v.animT0
		if v.anim == "collect" then
			if e < 0.3 then
				extraY = math.sin(e / 0.3 * math.pi) * 0.6 * math.max(1, k * 0.4)
			else
				v.anim = nil
			end
		elseif v.anim == "stolen" then
			if e < 0.35 then
				scale *= 1 - 0.4 * ease(e / 0.35)
				flicker = math.floor(e * 30) % 2 == 0
			else
				hide = true
				if e > 0.6 then
					v.anim = nil
				end
			end
		elseif v.anim == "return" then
			if e < 0.8 then
				scale *= 1 + math.sin(e / 0.8 * math.pi) * 0.25
			else
				v.anim = nil
			end
		elseif v.anim == "rebirth" then
			if e < 1.2 then
				extraY = ease(e / 1.2) * 8
				flicker = e > 0.6 and math.floor(e * 20) % 2 == 0
			else
				hide = true
			end
		end
	end
	-- моргание
	local blink = 0
	if now >= v.blinkAt then
		local e = now - v.blinkAt
		if e < 0.16 then
			blink = math.sin(e / 0.16 * math.pi)
		else
			v.blinkAt = now + 2.5 + math.random() * 4
		end
	end
	-- поворот головы к игроку (Rare+), раз в 5–8 сек, плавно
	if r >= 2 and myPos and now >= v.lookAt then
		v.lookAt = now + 5 + math.random() * 3
		local rel = cf:PointToObjectSpace(myPos)
		if rel.Magnitude < 30 then
			v.yawTarget = math.clamp(math.atan2(-rel.X, -rel.Z), -0.7, 0.7)
		else
			v.yawTarget = 0
		end
		task.delay(2.5, function()
			v.yawTarget = 0
		end)
	end
	v.yaw += (v.yawTarget - v.yaw) * math.min(1, dt * 4)
	-- глитч хроно
	local glitchJump = Vector3.zero
	if r == 5 then
		if now > v.glitchUntil and math.random() < dt * 1.5 then
			v.glitchUntil = now + 0.12
			glitchJump = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit * 0.2
			v.gj = glitchJump
			for i, info in v.roles do
				if info.glitch then
					v.glitchOff[i] = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.25 * k
				end
			end
		elseif now < v.glitchUntil then
			glitchJump = v.gj or Vector3.zero
		else
			table.clear(v.glitchOff)
		end
	end
	local rootCF = cf * CFrame.new(glitchJump + Vector3.new(0, bob + extraY, 0)) * CFrame.Angles(0, spin, 0)
	if hide then
		rootCF = rootCF * CFrame.new(0, -1000, 0)
	end
	v.root.CFrame = rootCF
	local faceRot = CFrame.Angles(0, v.yaw, 0)
	for i, p in v.parts do
		local off = v.offsets[i]
		local info = v.roles[i]
		local pos = off.Position * scale
		local local_ = CFrame.new(pos) * off.Rotation
		local role = info.role
		if FACE[role] then
			local_ = faceRot * local_
			if role == "lid" and blink > 0 then
				local_ = local_ * CFrame.new(0, -blink * info.y * 1.2, 0)
			end
		elseif role == "ring" then
			local_ = CFrame.Angles(0, t * (0.9 + r * 0.15), 0) * local_
		elseif role == "shard" then
			local_ = CFrame.Angles(0, t * 0.7, 0) * CFrame.new(0, math.sin(t * 2 + info.phase) * 0.12 * k, 0) * local_
		elseif role == "limb" then
			if info.wing then
				local_ = local_ * CFrame.Angles(0, 0, math.sin(t * 7) * 0.35 * info.wing)
			else
				local_ = local_ * CFrame.Angles(math.sin(t * 2.2 + info.phase) * 0.12, 0, 0)
			end
		end
		local g = v.glitchOff[i]
		if g then
			local_ = CFrame.new(g) * local_
		end
		local final = rootCF * local_
		table.insert(allParts, p)
		table.insert(allCFs, final)
		-- пульс свечения и мерцание
		if role == "glow" or role == "pillar" or (r == 5 and info.glitch) then
			local pulse = (math.sin(t * math.pi / 0.75) + 1) / 2
			local base = info.t0
			if role == "pillar" then
				p.Transparency = 0.7 + pulse * 0.15
			elseif r == 5 then
				p.Transparency = if flicker or (now < v.glitchUntil and i % 3 == 0) then 0.8 else base
				p.Color = v.def.color:Lerp(v.def.glow, pulse)
			else
				p.Transparency = base + pulse * 0.15
			end
		elseif flicker then
			p.LocalTransparencyModifier = 0.7
		elseif p.LocalTransparencyModifier ~= 0 then
			p.LocalTransparencyModifier = 0
		end
	end
	if v.light then
		local pulse = 0.8 + 0.4 * (math.sin(t * math.pi / 0.75) + 1) / 2 -- 0.8 → 1.2
		v.light.Brightness = v.lightBase * pulse
	end
	-- эхо-двойник отстаёт от оригинала
	if v.echo then
		v.lagCF = if v.lagCF then v.lagCF:Lerp(rootCF, math.min(1, dt * 3)) else rootCF
		local lag = v.lagCF * CFrame.new(math.sin(t * 1.3) * 0.4 * k, 0, math.cos(t) * 0.3 * k)
		for i, p in v.eparts do
			local off = v.offsets[i]
			if off then
				table.insert(allParts, p)
				table.insert(allCFs, if hide then lag * CFrame.new(0, -1000, 0) else lag * off)
			end
		end
	end
	-- голоса
	if myPos and now >= v.voiceAt then
		v.voiceAt = now + 10 + math.random() * 10
		if (rootCF.Position - myPos).Magnitude < (if r >= 4 then 120 else 40) then
			playVoice(v)
		end
	end
end

local function myPosition(): Vector3?
	local char = player.Character
	local r = char and char:FindFirstChild("HumanoidRootPart")
	return r and r.Position
end

local function camPos(): Vector3
	return workspace.CurrentCamera.CFrame.Position
end

-- раз в 0.5 сек: что строить, что убрать, у кого свет
local function cull()
	local cp = camPos()
	local built = 0
	for anchor in anchors do
		local v = visuals[anchor]
		if not anchor.Parent then
			if v then
				destroy(v)
				visuals[anchor] = nil
			end
			anchors[anchor] = nil
		else
			local dist = (anchor.Position - cp).Magnitude
			local id = anchor:GetAttribute("Id")
			if v and v.def.id ~= id then
				destroy(v)
				visuals[anchor] = nil
				v = nil
			end
			if dist <= RANGE and not v and built < 4 then
				local ok, nv = pcall(build, anchor)
				if ok and nv then
					visuals[anchor] = nv
					built += 1
				end
			elseif dist > RANGE + 30 and v then
				destroy(v)
				visuals[anchor] = nil
			end
		end
	end
	-- свет только у ближайших
	local list = {}
	for _, v in visuals do
		if v.light then
			table.insert(list, { v = v, d = (v.root.Position - cp).Magnitude })
		end
	end
	table.sort(list, function(a, b)
		return a.d < b.d
	end)
	for i, e in list do
		e.v.light.Enabled = i <= LIGHTS
	end
end

function M.start()
	for _, a in CollectionService:GetTagged("Art") do
		if a:IsA("BasePart") then
			anchors[a] = true
		end
	end
	CollectionService:GetInstanceAddedSignal("Art"):Connect(function(a)
		if a:IsA("BasePart") then
			anchors[a] = true
		end
	end)
	CollectionService:GetInstanceRemovedSignal("Art"):Connect(function(a)
		local v = visuals[a]
		if v then
			-- дать доиграть «кражу»/«ребёрс»
			local anim = v.anim
			task.delay(if anim == "stolen" or anim == "rebirth" then 1.2 else 0, function()
				if visuals[a] == v then
					destroy(v)
					visuals[a] = nil
				end
			end)
		end
		anchors[a] = nil
	end)
	task.spawn(function()
		while true do
			pcall(cull)
			task.wait(0.5)
		end
	end)
	local allParts, allCFs = {}, {}
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		local my = myPosition()
		table.clear(allParts)
		table.clear(allCFs)
		for anchor, v in visuals do
			if anchor.Parent then
				local ok, err = pcall(step, v, now, dt, my, allParts, allCFs)
				if not ok then
					warn("[Art]", err)
					destroy(v)
					visuals[anchor] = nil
				end
			end
		end
		if #allParts > 0 then
			workspace:BulkMoveTo(allParts, allCFs, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

local _p = Palette
return M
