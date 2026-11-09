-- «Вершина»: всё лобби строится кодом при запуске сервера.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent:WaitForChild("World")
local Sky = require(World.Sky)
local T = require(World.Terrain)
local Lobby = require(World.Lobby)
local Forest = require(World.Forest)

local rng = Random.new(2026)

ReplicatedStorage:SetAttribute("WorldReady", false)
ReplicatedStorage:SetAttribute("WorldProgress", 0)

-- свет и направление вида: смотровая смотрит в сторону заката (со сдвигом)
Sky.apply()
local sun = Lighting:GetSunDirection()
local flatSun = Vector3.new(sun.X, 0, sun.Z)
if flatSun.Magnitude < 0.01 then
	flatSun = Vector3.new(0, 0, -1)
end
local viewDir = CFrame.Angles(0, math.rad(40), 0):VectorToWorldSpace(flatSun.Unit)
T.setup(viewDir)

local center = Vector3.new(0, T.H0, 0)
local lobbyCF = CFrame.lookAt(center, center + viewDir)
ReplicatedStorage:SetAttribute("LobbyCF", lobbyCF)

local world = Instance.new("Folder")
world.Name = "Мир"
world.Parent = workspace

-- 1. постройки (сразу, чтобы было куда появиться)
local deckCF = Lobby.build(world, lobbyCF, rng)
ReplicatedStorage:SetAttribute("DeckCF", deckCF)

-- 2. ландшафт
T.applyLook()
local started = os.clock()
T.generate(function(p)
	ReplicatedStorage:SetAttribute("WorldProgress", p * 0.85)
end)
print(string.format("Ландшафт готов за %.1f с", os.clock() - started))

-- 3. лес
started = os.clock()
local trees = Forest.generate(world, rng, function(p)
	ReplicatedStorage:SetAttribute("WorldProgress", 0.85 + p * 0.15)
end)
print(string.format("Лес: %d деревьев за %.1f с", trees, os.clock() - started))

ReplicatedStorage:SetAttribute("WorldProgress", 1)
ReplicatedStorage:SetAttribute("WorldReady", true)
