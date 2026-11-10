--!strict
-- Геометрия площадки: где стоят пушки и откуда вылетает игрок. Нужна и серверу, и клиенту.

local Config = require(script.Parent.Config)

local M = {}

M.SPAWN = Vector3.new(0, 3, -70)
M.PLAZA_Z0 = -120
M.PLAZA_Z1 = 0

local ANGLE = math.rad(Config.LAUNCH_ANGLE)
M.DIR = Vector3.new(0, math.sin(ANGLE), math.cos(ANGLE)) -- направление ствола
M.BARREL_LEN = 30
M.BARREL_R = 5

function M.laneX(lane: number): number
	return (lane - (Config.LANES + 1) / 2) * Config.LANE_GAP
end

-- Ось вращения ствола (низ ствола)
function M.pivot(lane: number): Vector3
	return Vector3.new(M.laneX(lane), 9, -26)
end

function M.muzzle(lane: number): Vector3
	return M.pivot(lane) + M.DIR * (M.BARREL_LEN + 3)
end

-- Гонка: все стартуют из одной точки по центру площадки, чуть выше обычных пушек
function M.raceMuzzle(): Vector3
	return Vector3.new(0, 30, 2)
end

return M
