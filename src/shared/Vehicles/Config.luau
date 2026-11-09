--!strict
-- Параметры транспорта. Единицы: шпильки и секунды (1 шп/с ≈ 1 км/ч на спидометре).
-- Геометрия в координатах кузова: X — вправо, Y — вверх, −Z — вперёд.

export type VehicleType = {
	id: string,
	body: Vector3, -- размер невидимого корпуса (столкновения)
	wheels: { [string]: Vector3 },
	radius: number, -- радиус колеса
	sMin: number,
	sMax: number,
	rest: number, -- сжатие подвески в покое
	frontShare: number, -- доля тяги на передней оси
	accel: number,
	power: number,
	topSpeed: number,
	grip: number,
	brake: number,
	maxSteer: number,
	cargo: Vector3, -- где лежит груз (локально)
}

local TYPES: { [string]: VehicleType } = {
	van = {
		id = "van",
		body = Vector3.new(6.4, 2, 13),
		wheels = {
			FL = Vector3.new(-2.9, 0, -4.3),
			FR = Vector3.new(2.9, 0, -4.3),
			RL = Vector3.new(-2.9, 0, 4.1),
			RR = Vector3.new(2.9, 0, 4.1),
		},
		radius = 1.3,
		sMin = 0.1,
		sMax = 1.5,
		rest = 0.9,
		frontShare = 0,
		accel = 32,
		power = 32 * 40,
		topSpeed = 95,
		grip = 0.5,
		brake = 70,
		maxSteer = 32,
		cargo = Vector3.new(0, 2.6, 2.5),
	},
	forklift = {
		id = "forklift",
		body = Vector3.new(4.4, 1.6, 7),
		wheels = {
			FL = Vector3.new(-1.9, 0, -2.3),
			FR = Vector3.new(1.9, 0, -2.3),
			RL = Vector3.new(-1.9, 0, 2.1),
			RR = Vector3.new(1.9, 0, 2.1),
		},
		radius = 0.95,
		sMin = 0.1,
		sMax = 1.0,
		rest = 0.6,
		frontShare = 1,
		accel = 26,
		power = 26 * 30,
		topSpeed = 42,
		grip = 0.65,
		brake = 70,
		maxSteer = 42,
		cargo = Vector3.new(0, 0.6, -5.2),
	},
	cart = {
		id = "cart",
		body = Vector3.new(3.6, 1, 5),
		wheels = {
			FL = Vector3.new(-1.5, 0, -1.6),
			FR = Vector3.new(1.5, 0, -1.6),
			RL = Vector3.new(-1.5, 0, 1.6),
			RR = Vector3.new(1.5, 0, 1.6),
		},
		radius = 0.8,
		sMin = 0.1,
		sMax = 0.8,
		rest = 0.5,
		frontShare = 0.5,
		accel = 14,
		power = 14 * 18,
		topSpeed = 24,
		grip = 0.6,
		brake = 50,
		maxSteer = 38,
		cargo = Vector3.new(0, 1.2, 0),
	},
}

local M = {}
M.TYPES = TYPES
M.WHEEL_ORDER = { "FL", "FR", "RL", "RR" }

-- сцепление по поверхности (множитель к grip)
M.SURFACE = {
	[Enum.Material.Asphalt] = 1.15,
	[Enum.Material.Concrete] = 1.15,
	[Enum.Material.Pavement] = 1.1,
	[Enum.Material.Ground] = 1,
	[Enum.Material.Mud] = 0.8,
	[Enum.Material.Grass] = 0.85,
	[Enum.Material.LeafyGrass] = 0.82,
	[Enum.Material.Sand] = 0.72,
	[Enum.Material.Snow] = 0.6,
	[Enum.Material.Rock] = 1.05,
	[Enum.Material.Slate] = 1.05,
	[Enum.Material.Cobblestone] = 1.05,
	[Enum.Material.WoodPlanks] = 1,
}
M.DEFAULT_SURFACE = 0.95

function M.rideHeight(t: VehicleType): number
	return t.radius + (t.sMax - t.rest)
end

return M
