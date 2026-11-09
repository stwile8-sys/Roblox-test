-- Параметры машин. Общие для сервера и клиента; секретов здесь нет.
-- Единицы: шпильки и секунды; 1 шпилька/с ≈ 1 км/ч.

local CarConfig = {}

-- геометрия (локальные координаты кузова: X — вправо, Y — вверх, −Z — вперёд)
CarConfig.WHEEL_RADIUS = 1.25
CarConfig.S_MIN = 0.1 -- минимальная длина подвески (отбойник)
CarConfig.S_MAX = 1.5 -- полный ход вниз
CarConfig.REST_COMPRESSION = 0.9 -- сжатие в покое
CarConfig.RIDE_HEIGHT = 1.85 -- высота центра кузова над землёй в покое
CarConfig.WHEELS = {
	FL = Vector3.new(-2.8, 0, -4),
	FR = Vector3.new(2.8, 0, -4),
	RL = Vector3.new(-2.8, 0, 4),
	RR = Vector3.new(2.8, 0, 4),
}
CarConfig.WHEEL_ORDER = { "FL", "FR", "RL", "RR" }

CarConfig.TYPES = {
	Buran = {
		name = "Буран",
		drive = "Полный привод",
		number = 1,
		paint = Color3.fromRGB(28, 62, 150),
		accent = Color3.fromRGB(250, 196, 30),
		frontShare = 0.42,
		accel = 48, -- тяга на низах, шп/с²
		power = 48 * 42, -- ограничение мощности, шп²/с³
		topSpeed = 160,
		grip = 0.4,
		brake = 78,
		maxSteer = 30,
	},
	Strela = {
		name = "Стрела",
		drive = "Передний привод",
		number = 2,
		paint = Color3.fromRGB(236, 236, 232),
		accent = Color3.fromRGB(210, 30, 36),
		frontShare = 1,
		accel = 44,
		power = 44 * 42,
		topSpeed = 165,
		grip = 0.41,
		brake = 78,
		maxSteer = 31,
	},
	Groza = {
		name = "Гроза",
		drive = "Задний привод",
		number = 3,
		paint = Color3.fromRGB(230, 108, 20),
		accent = Color3.fromRGB(24, 24, 26),
		frontShare = 0,
		accel = 54,
		power = 54 * 45,
		topSpeed = 172,
		grip = 0.38,
		brake = 76,
		maxSteer = 33,
	},
}
CarConfig.TYPE_ORDER = { "Buran", "Strela", "Groza" }

-- сцепление по поверхности (множитель к grip)
CarConfig.SURFACE = {
	[Enum.Material.Ground] = 1,
	[Enum.Material.Mud] = 0.85,
	[Enum.Material.Grass] = 0.75,
	[Enum.Material.LeafyGrass] = 0.72,
	[Enum.Material.Sand] = 0.68,
	[Enum.Material.Snow] = 0.55,
	[Enum.Material.Rock] = 1.05,
	[Enum.Material.Slate] = 1.05,
	[Enum.Material.Concrete] = 1.15,
	[Enum.Material.Cobblestone] = 1.05,
}
CarConfig.DEFAULT_SURFACE = 0.95

-- рыхлые поверхности, из-под колёс летит грязь
CarConfig.LOOSE = {
	[Enum.Material.Ground] = Color3.fromRGB(112, 88, 64),
	[Enum.Material.Mud] = Color3.fromRGB(82, 66, 50),
	[Enum.Material.Grass] = Color3.fromRGB(92, 110, 56),
	[Enum.Material.LeafyGrass] = Color3.fromRGB(80, 100, 50),
	[Enum.Material.Sand] = Color3.fromRGB(196, 178, 138),
	[Enum.Material.Snow] = Color3.fromRGB(240, 244, 255),
}

return CarConfig
