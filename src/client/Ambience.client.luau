-- Живой свет: мерцание огня, фонарей и окон.

local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local lights: { PointLight } = {}

local function add(light: Instance)
	if light:IsA("PointLight") then
		table.insert(lights, light)
	end
end
for _, l in CollectionService:GetTagged("Flicker") do
	add(l)
end
CollectionService:GetInstanceAddedSignal("Flicker"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Flicker"):Connect(function(l)
	local i = table.find(lights, l)
	if i then
		table.remove(lights, i)
	end
end)

RunService.RenderStepped:Connect(function()
	local t = os.clock()
	for i, light in lights do
		local base = light:GetAttribute("BaseBrightness") or 1
		local amount = light:GetAttribute("Flicker") or 0.1
		local n = math.noise(t * 3.1, i * 7.31) * 2 + math.noise(t * 11.3, i * 3.17) * 0.8
		light.Brightness = base * math.max(0.2, 1 + n * amount)
	end
end)
