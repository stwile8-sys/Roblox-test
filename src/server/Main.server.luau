-- «Вершина»: лобби и ралли строятся кодом при запуске сервера.
-- Порядок запуска важен, поэтому всё вызывается последовательно.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local World = script.Parent:WaitForChild("World")
local Rally = script.Parent:WaitForChild("Rally")
local Sky = require(World.Sky)
local T = require(World.Terrain)
local Track = require(World.Track)
local Lobby = require(World.Lobby)
local Forest = require(World.Forest)
local StartArea = require(Rally.StartArea)
local Cars = require(Rally.Cars)
local Race = require(Rally.Race)

local rng = Random.new(2026)

ReplicatedStorage:SetAttribute("WorldReady", false)
ReplicatedStorage:SetAttribute("WorldProgress", 0)
ReplicatedStorage:SetAttribute("WaterLevel", T.WATER)

-- свет и направление вида: смотровая смотрит в сторону заката (со сдвигом)
Sky.apply()
local sun = Lighting:GetSunDirection()
local flatSun = Vector3.new(sun.X, 0, sun.Z)
if flatSun.Magnitude < 0.01 then
	flatSun = Vector3.new(0, 0, -1)
end
local viewDir = CFrame.Angles(0, math.rad(40), 0):VectorToWorldSpace(flatSun.Unit)
T.setup(viewDir)

-- трасса врезается в рельеф, поэтому строится до ландшафта
local track = Track.build(viewDir, T.naturalHeightAt, T.WATER)
T.setRoad(track)
print(string.format("Трасса: %d м, точек %d", math.floor(track.length * 0.28), track.count))

local center = Vector3.new(0, T.H0, 0)
local lobbyCF = CFrame.lookAt(center, center + viewDir)
ReplicatedStorage:SetAttribute("LobbyCF", lobbyCF)

local world = Instance.new("Folder")
world.Name = "Мир"
world.Parent = workspace

-- 1. постройки
local deckCF, lobbyPortal, lobbyArrival = Lobby.build(world, lobbyCF, rng)
ReplicatedStorage:SetAttribute("DeckCF", deckCF)
local area = StartArea.build(world, track)
StartArea.linkPortals(lobbyPortal, area.arrival, area.backPortal, lobbyArrival)

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

-- 4. машины и хронометраж (после ландшафта, чтобы было на что встать)
Cars.spawn(world, area.slots, track)
Race.start(track, Cars.driverCar, area.board)

ReplicatedStorage:SetAttribute("WorldProgress", 1)
ReplicatedStorage:SetAttribute("WorldReady", true)
