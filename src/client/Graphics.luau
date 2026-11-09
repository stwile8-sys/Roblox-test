--!nonstrict
-- Две настройки графики: «Телефон» (без теней и эффектов) и «ПК» (тени, свечение, лучи).
-- «Авто» выбирает по устройству. Меняется только у этого игрока.

local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local M = {}

local function isPhone(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

function M.resolve(mode: string): string
	if mode == "low" or mode == "high" then
		return mode
	end
	return if isPhone() then "low" else "high"
end

function M.apply(mode: string)
	local q = M.resolve(mode)
	local high = q == "high"
	Lighting.GlobalShadows = high
	local bloom = Lighting:FindFirstChild("Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = high
	end
	local rays = Lighting:FindFirstChild("Rays")
	if rays and rays:IsA("SunRaysEffect") then
		rays.Enabled = high
	end
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = if high then 0.28 else 0.22
		atmo.Haze = if high then 1 else 0.5
	end
	local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds.Enabled = high
	end
	workspace.Terrain.WaterWaveSize = if high then 0.15 else 0
	workspace.Terrain.WaterReflectance = if high then 0.6 else 0.2
end

return M
