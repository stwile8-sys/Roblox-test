--!strict
-- Биомы и их ресурсы (из ТЗ, раздел 2.2). Ресурсы, которых ещё нет в игре,
-- показываются в описании участка — они пригодятся в следующих фазах.

export type Biome = {
	id: string,
	ground: Color3,
	resources: { string },
	food: boolean, -- стартовый «пищевой» биом
}

local B: { [string]: Biome } = {
	forest = {
		id = "forest",
		ground = Color3.fromRGB(86, 140, 70),
		resources = { "wood", "game", "honey", "mushrooms", "resin" },
		food = true,
	},
	field = {
		id = "field",
		ground = Color3.fromRGB(150, 180, 80),
		resources = { "grain", "livestock", "flax", "sunflower" },
		food = true,
	},
	meadow = {
		id = "meadow",
		ground = Color3.fromRGB(120, 175, 90),
		resources = { "grain", "livestock", "herbs" },
		food = true,
	},
	desert = {
		id = "desert",
		ground = Color3.fromRGB(222, 196, 138),
		resources = { "stone", "iron_ore", "copper_ore", "oil", "sand", "salt", "sulfur", "bauxite" },
		food = false,
	},
	river = {
		id = "river",
		ground = Color3.fromRGB(105, 160, 95),
		resources = { "fish", "clay", "water", "reed" },
		food = true,
	},
	lake = {
		id = "lake",
		ground = Color3.fromRGB(110, 165, 105),
		resources = { "fish", "salt", "silt", "algae" },
		food = true,
	},
	swamp = {
		id = "swamp",
		ground = Color3.fromRGB(95, 120, 80),
		resources = { "peat", "oil", "cranberry", "reed", "sulfur" },
		food = false,
	},
	mountains = {
		id = "mountains",
		ground = Color3.fromRGB(140, 140, 130),
		resources = { "stone", "iron_ore", "coal", "gold", "silver", "gems", "uranium", "limestone", "bauxite" },
		food = false,
	},
	coast = {
		id = "coast",
		ground = Color3.fromRGB(205, 195, 140),
		resources = { "fish", "salt", "oil", "algae", "sand", "gas" },
		food = true,
	},
}

local M = {}
M.byId = B
M.order = { "forest", "field", "meadow", "river", "lake", "coast", "swamp", "desert", "mountains" }
return M
