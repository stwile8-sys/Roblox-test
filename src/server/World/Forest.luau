-- Лес в долине и на склонах: ели и осенние лиственные деревья.

local B = require(script.Parent.Builders)
local T = require(script.Parent.Terrain)

local Forest = {}

function Forest.generate(parent: Instance, rng: Random, onProgress: (number) -> ())
	local folder = Instance.new("Folder")
	folder.Name = "Лес"
	folder.Parent = parent

	local spacing = 13
	local LIMIT = 640
	local placed = 0
	local row = 0
	for x = -LIMIT, LIMIT, spacing do
		row += 1
		for z = -LIMIT, LIMIT, spacing do
			local px = x + rng:NextNumber(-5, 5)
			local pz = z + rng:NextNumber(-5, 5)
			local r = math.sqrt(px * px + pz * pz)
			if r > T.PLATEAU_R + 22 and r < LIMIT then
				local mask = math.noise(px / 170, pz / 170, 3.3) + math.noise(px / 45, pz / 45, 8.1) * 0.35
				local chance = mask > -0.05 and 0.2 or 0.03
				if rng:NextNumber() < chance then
					local h = T.heightAt(px, pz)
					if h > T.WATER + 4 and h < 235 and T.slopeAt(px, pz) < 0.8 then
						local near = r < 260
						local props = {
							CastShadow = near,
							CanCollide = false,
							CanQuery = false,
							CanTouch = false,
						}
						local base = Vector3.new(px, h, pz)
						local leafyChance = h < 80 and 0.45 or 0.15
						if rng:NextNumber() < leafyChance then
							B.leafy(folder, base, rng:NextNumber(18, 28), rng, props)
						else
							B.pine(folder, base, rng:NextNumber(22, 40), rng, props)
						end
						placed += 1
					end
				end
			end
		end
		if row % 6 == 0 then
			onProgress(row * spacing / (LIMIT * 2))
			task.wait()
		end
	end
	return placed
end

return Forest
