--!strict
-- Транспорт на сервере: появление, посадка (только хозяин), владелец физики, переворот, удаление.
-- Единственный владелец всех машин в мире.

local Players = game:GetService("Players")

local Shared = game.ReplicatedStorage.Shared
local Config = require(Shared.Vehicles.Config)
local Builder = require(script.Parent.Builder)

local M = {}

type Entry = { car: Model, owner: Player, kind: string }

local entries: { [Model]: Entry } = {}
local folder: Folder

local function seatOf(car: Model): VehicleSeat?
	local s = car:FindFirstChild("DriverSeat")
	return if s and s:IsA("VehicleSeat") then s else nil
end

local function driverOf(car: Model): Player?
	local s = seatOf(car)
	local occ = s and s.Occupant
	return if occ then Players:GetPlayerFromCharacter(occ.Parent) else nil
end

local function onOccupant(entry: Entry)
	local body = entry.car.PrimaryPart
	if not body then
		return
	end
	local driver = driverOf(entry.car)
	if driver then
		body.Anchored = false
		pcall(function()
			body:SetNetworkOwner(driver)
		end)
	else
		-- водитель вышел: машина стоит, где оставили
		pcall(function()
			body:SetNetworkOwner(nil)
		end)
		body.AssemblyLinearVelocity = Vector3.zero
		body.AssemblyAngularVelocity = Vector3.zero
		body.Anchored = true
	end
end

-- Посадить игрока за руль
function M.seat(player: Player, car: Model): boolean
	local entry = entries[car]
	local ch = player.Character
	local hum = ch and ch:FindFirstChildOfClass("Humanoid")
	local s = seatOf(car)
	if not entry or entry.owner ~= player or not hum or not s or hum.Health <= 0 then
		return false
	end
	if s.Occupant ~= nil then
		return false
	end
	if hum.SeatPart then
		hum.Sit = false
		task.wait()
	end
	local character = ch :: Model
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and (root.Position - s.Position).Magnitude > 20 then
		character:PivotTo(s.CFrame * CFrame.new(-3, 2, 0))
		task.wait()
	end
	s:Sit(hum)
	return true
end

function M.spawn(player: Player, kind: string, cf: CFrame, sitNow: boolean?): Model?
	local t = Config.TYPES[kind]
	if not t then
		return nil
	end
	local placed = cf + Vector3.new(0, Config.rideHeight(t) + 0.3, 0)
	local car: Model
	if kind == "van" then
		car = Builder.van(placed, folder)
	elseif kind == "forklift" then
		car = Builder.forklift(placed, folder)
	else
		car = Builder.cart(placed, folder)
	end
	car:SetAttribute("Owner", player.UserId)
	car.Name = kind .. "_" .. player.UserId
	local entry: Entry = { car = car, owner = player, kind = kind }
	entries[car] = entry
	local s = seatOf(car)
	if s then
		s:GetPropertyChangedSignal("Occupant"):Connect(function()
			onOccupant(entry)
		end)
	end
	local prompt = car:FindFirstChild("DrivePrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(who)
			if who == player then
				M.seat(player, car)
			end
		end)
	end
	if sitNow then
		task.defer(M.seat, player, car)
	end
	return car
end

function M.remove(car: Model?)
	if car and entries[car] then
		entries[car] = nil
		car:Destroy()
	end
end

function M.removeKind(player: Player, kind: string)
	for car, e in entries do
		if e.owner == player and e.kind == kind then
			M.remove(car)
		end
	end
end

function M.driving(player: Player): Model?
	for car in entries do
		if driverOf(car) == player then
			return car
		end
	end
	return nil
end

function M.ownedOf(player: Player, kind: string): Model?
	for car, e in entries do
		if e.owner == player and e.kind == kind then
			return car
		end
	end
	return nil
end

-- Перевернуть/поставить машину на колёса на месте
local lastFlip: { [Player]: number } = {}
function M.flip(player: Player): (boolean, string?)
	local now = os.clock()
	if lastFlip[player] and now - lastFlip[player] < 2 then
		return false, "err.slow"
	end
	local car = M.driving(player)
	local body = car and car.PrimaryPart
	if not car or not body then
		return false, "err.bad"
	end
	lastFlip[player] = now
	local look = body.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	pcall(function()
		body:SetNetworkOwner(nil)
	end)
	body.Anchored = true
	car:PivotTo(CFrame.lookAt(body.Position + Vector3.new(0, 4, 0), body.Position + Vector3.new(0, 4, 0) + flat.Unit))
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	task.delay(0.1, function()
		if body.Parent and driverOf(car) == player then
			body.Anchored = false
			pcall(function()
				body:SetNetworkOwner(player)
			end)
		end
	end)
	return true, nil
end

function M.start()
	folder = Instance.new("Folder")
	folder.Name = "Vehicles"
	folder.Parent = workspace
	Players.PlayerRemoving:Connect(function(leaving: Player)
		for car, e in entries do
			if e.owner == leaving then
				M.remove(car)
			end
		end
		lastFlip[leaving] = nil
	end)
end

return M
