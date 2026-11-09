-- Машины на сервере: появление, посадка, владелец физики, сброс и возврат.
-- Единственный владелец состояния машин.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Rally")
local CarConfig = require(Shared:WaitForChild("CarConfig"))
local CarPhysics = require(Shared:WaitForChild("CarPhysics"))
local CarBuilder = require(script.Parent.CarBuilder)

local Cars = {}

local RESET_COOLDOWN = 2.5
local ABANDON_TIME = 40
local IDLE_INPUT = { throttle = 0, brake = 0, steer = 0, handbrake = true }

type Entry = {
	car: Model,
	slot: CFrame,
	state: any,
	lastUsed: number,
	still: number,
}

local entries: { Entry } = {}
local lastReset: { [Player]: number } = {}
local track = nil

local function driverOf(entry: Entry): Player?
	local seat = entry.car:FindFirstChild("DriverSeat") :: VehicleSeat?
	local occupant = seat and seat.Occupant
	return occupant and Players:GetPlayerFromCharacter(occupant.Parent) or nil
end

function Cars.driverCar(player: Player): Model?
	for _, entry in entries do
		if driverOf(entry) == player then
			return entry.car
		end
	end
	return nil
end

local function placeAt(entry: Entry, cf: CFrame)
	local body = entry.car.PrimaryPart
	if not body then
		return
	end
	local wasAnchored = body.Anchored
	body.Anchored = true
	entry.car:PivotTo(cf)
	body.AssemblyLinearVelocity = Vector3.zero
	body.AssemblyAngularVelocity = Vector3.zero
	if not wasAnchored then
		body.Anchored = false
	end
end

local function onOccupantChanged(entry: Entry)
	local body = entry.car.PrimaryPart
	if not body then
		return
	end
	local player = driverOf(entry)
	entry.lastUsed = os.clock()
	if player then
		body.Anchored = false
		local ok = pcall(function()
			body:SetNetworkOwner(player)
		end)
		if not ok then
			warn("Не удалось передать машину игроку", player.Name)
		end
	else
		entry.still = 0
		if not body.Anchored then
			pcall(function()
				body:SetNetworkOwner(nil)
			end)
		end
	end
end

local function onPrompt(entry: Entry, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local seat = entry.car:FindFirstChild("DriverSeat") :: VehicleSeat?
	local body = entry.car.PrimaryPart
	if not (humanoid and root and seat and body) then
		return
	end
	if humanoid.Health <= 0 or humanoid.SeatPart ~= nil or seat.Occupant ~= nil then
		return
	end
	if (root.Position - body.Position).Magnitude > 16 then
		return
	end
	seat:Sit(humanoid)
end

function Cars.spawn(parent: Instance, slots: { CFrame }, trackObj)
	track = trackObj
	local folder = Instance.new("Folder")
	folder.Name = "Машины"
	folder.Parent = parent

	for i, slot in slots do
		local typeName = CarConfig.TYPE_ORDER[(i - 1) % #CarConfig.TYPE_ORDER + 1]
		local car = CarBuilder.build(typeName, slot, folder)
		local entry: Entry = { car = car, slot = slot, state = CarPhysics.newState(car), lastUsed = os.clock(), still = 0 }
		table.insert(entries, entry)
		local seat = car:FindFirstChild("DriverSeat") :: VehicleSeat
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			onOccupantChanged(entry)
		end)
		local prompt = car:FindFirstChild("DrivePrompt", true) :: ProximityPrompt
		prompt.Triggered:Connect(function(player)
			onPrompt(entry, player)
		end)
		-- пока кто-то за рулём, подсказку прячем
		seat:GetPropertyChangedSignal("Occupant"):Connect(function()
			prompt.Enabled = seat.Occupant == nil
		end)
	end

	-- сброс машины на трассу (переворот)
	local resetEvent = Instance.new("RemoteEvent")
	resetEvent.Name = "ResetCar"
	resetEvent.Parent = Shared
	resetEvent.OnServerEvent:Connect(function(player)
		local now = os.clock()
		if lastReset[player] and now - lastReset[player] < RESET_COOLDOWN then
			return
		end
		for _, entry in entries do
			if driverOf(entry) == player then
				lastReset[player] = now
				local body = entry.car.PrimaryPart
				if not body then
					return
				end
				local i = track:nearestAnywhere(body.Position)
				local cf = track:frameAt(i) + Vector3.new(0, CarConfig.RIDE_HEIGHT + 1.5, 0)
				pcall(function()
					body:SetNetworkOwner(nil)
				end)
				placeAt(entry, cf)
				task.delay(0.15, function()
					if driverOf(entry) == player and not body.Anchored then
						pcall(function()
							body:SetNetworkOwner(player)
						end)
					end
				end)
				return
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastReset[player] = nil
	end)

	-- физика пустых машин на сервере, «усыпление» и возврат брошенных
	RunService.PreSimulation:Connect(function(dt)
		local now = os.clock()
		for _, entry in entries do
			local body = entry.car.PrimaryPart
			if body and not body.Anchored and driverOf(entry) == nil then
				CarPhysics.step(entry.car, IDLE_INPUT, dt, entry.state)
				local still = body.AssemblyLinearVelocity.Magnitude < 0.6 and body.AssemblyAngularVelocity.Magnitude < 0.3
				entry.still = still and entry.still + dt or 0
				if entry.still > 1.5 and entry.state.grounded >= 3 then
					body.Anchored = true
				end
				if body.Position.Y < -40 then
					placeAt(entry, entry.slot)
					body.Anchored = true
				end
			end
			if body and driverOf(entry) == nil and now - entry.lastUsed > ABANDON_TIME then
				if (body.Position - entry.slot.Position).Magnitude > 25 then
					placeAt(entry, entry.slot)
					body.Anchored = true
				end
				entry.lastUsed = now
			end
		end
	end)
end

return Cars
