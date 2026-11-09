--!strict
-- Палитра из ТЗ (раздел 1). Один источник цветов для мира, существ и интерфейса.
local function hex(h: string): Color3
	return Color3.fromHex(h)
end

return {
	orange = hex("#FFB347"),
	gold = hex("#FFE066"),
	wood = hex("#8B5A2B"),
	stone = hex("#C2A878"),
	chrono = hex("#00E5FF"),
	thief = hex("#7B2FF7"),
	alarm = hex("#FF2E63"),
	steel = hex("#2C3E50"),
	night = hex("#1A1A2E"),
	white = hex("#FFFFFF"),
	success = hex("#39FF14"),
	grey = hex("#8A8FA0"),
	dark = hex("#14141F"),
	panel = hex("#22223A"),
}
