--!strict
-- Короткие числа: 1.2K, 34.5M, 7.8B …

local SUFFIX = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local M = {}

function M.num(n: number): string
	if n ~= n then
		return "0"
	end
	local neg = n < 0
	n = math.abs(n)
	if n < 1000 then
		local s = tostring(math.floor(n))
		return if neg then "-" .. s else s
	end
	local i = 1
	while n >= 1000 and i < #SUFFIX do
		n /= 1000
		i += 1
	end
	local s
	if n >= 100 then
		s = string.format("%d", math.floor(n))
	elseif n >= 10 then
		s = string.format("%.1f", math.floor(n * 10) / 10)
	else
		s = string.format("%.2f", math.floor(n * 100) / 100)
	end
	s = s:gsub("%.?0+$", "")
	return (if neg then "-" else "") .. s .. SUFFIX[i]
end

-- 12,345m
function M.dist(d: number): string
	local s = tostring(math.floor(d))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out .. "m"
end

function M.time(sec: number): string
	sec = math.max(0, math.floor(sec))
	local m = sec // 60
	local s = sec % 60
	if m >= 60 then
		return string.format("%d:%02d:%02d", m // 60, m % 60, s)
	end
	return string.format("%d:%02d", m, s)
end

return M
