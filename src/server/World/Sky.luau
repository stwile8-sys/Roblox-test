-- Освещение, атмосфера и пост-эффекты (по умолчанию — закат).

local Lighting = game:GetService("Lighting")

local Sky = {}

local function make(className: string, name: string, props: { [string]: any })
	local inst = Lighting:FindFirstChild(name) or Instance.new(className)
	inst.Name = name
	for k, v in props do
		(inst :: any)[k] = v
	end
	inst.Parent = Lighting
	return inst
end

function Sky.apply()
	Lighting.ClockTime = 17.4
	Lighting.GeographicLatitude = 41.7
	Lighting.Brightness = 2.6
	Lighting.Ambient = Color3.fromRGB(70, 66, 76)
	Lighting.OutdoorAmbient = Color3.fromRGB(128, 118, 128)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 1
	Lighting.ShadowSoftness = 0.25
	Lighting.ExposureCompensation = 0.1
	Lighting.GlobalShadows = true

	make("Sky", "Sky", {
		StarCount = 4000,
		SunAngularSize = 14,
		MoonAngularSize = 10,
		CelestialBodiesShown = true,
	})
	make("Atmosphere", "Atmosphere", {
		Density = 0.3,
		Offset = 0.2,
		Color = Color3.fromRGB(255, 212, 172),
		Decay = Color3.fromRGB(122, 108, 140),
		Glare = 0.55,
		Haze = 1.6,
	})
	make("BloomEffect", "Bloom", {
		Intensity = 0.55,
		Size = 28,
		Threshold = 1.25,
	})
	make("SunRaysEffect", "SunRays", {
		Intensity = 0.09,
		Spread = 0.6,
	})
	make("ColorCorrectionEffect", "ColorCorrection", {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.14,
		TintColor = Color3.fromRGB(255, 244, 232),
	})
	make("DepthOfFieldEffect", "DepthOfField", {
		FarIntensity = 0.12,
		FocusDistance = 60,
		InFocusRadius = 120,
		NearIntensity = 0,
	})
end

return Sky
