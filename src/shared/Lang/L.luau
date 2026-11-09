--!strict
-- Переводчик. Ключ → строка на языке игрока, {имя} заменяется аргументом.
-- Язык: выбранный в настройках, иначе язык Roblox у игрока, иначе русский (базовый).

local Strings = require(script.Parent.Strings)

local M = {}

M.LANGS = { "en", "ru", "es", "pt", "de", "fr", "tr", "id", "ja", "ko", "zh" }
M.NATIVE = {
	en = "English",
	ru = "Русский",
	es = "Español",
	pt = "Português",
	de = "Deutsch",
	fr = "Français",
	tr = "Türkçe",
	id = "Bahasa Indonesia",
	ja = "日本語",
	ko = "한국어",
	zh = "中文",
}

local current = "ru"
local listeners: { () -> () } = {}

function M.isLang(code: any): boolean
	return type(code) == "string" and M.NATIVE[code] ~= nil
end

function M.fromLocale(locale: string): string
	local code = string.lower(string.sub(locale, 1, 2))
	return if M.NATIVE[code] then code else "ru"
end

function M.lang(): string
	return current
end

function M.set(code: string)
	if not M.isLang(code) or code == current then
		return
	end
	current = code
	for _, fn in listeners do
		task.spawn(fn)
	end
end

function M.onChange(fn: () -> ())
	table.insert(listeners, fn)
end

function M.t(key: string, args: { [string]: any }?): string
	local row = Strings[key]
	local s: string
	if row then
		s = row[current] or row.ru or row.en or key
	else
		s = key
	end
	if args then
		s = string.gsub(s, "{(%w+)}", function(name)
			local v = args[name]
			if v == nil then
				return "{" .. name .. "}"
			end
			if type(v) == "number" then
				return M.num(v)
			end
			return tostring(v)
		end)
	end
	return s
end

-- 1234567 → "1 234 567"
function M.num(n: number): string
	local neg = n < 0
	local s = tostring(math.floor(math.abs(n)))
	local out = string.reverse((string.gsub(string.reverse(s), "(%d%d%d)", "%1 ")))
	out = string.gsub(out, "^ ", "")
	return (if neg then "-" else "") .. out
end

-- 1234567 → "1.2M" (короткая запись для HUD)
function M.short(n: number): string
	local a = math.abs(n)
	local units = { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
	for _, u in units do
		if a >= u[1] then
			local v = n / u[1]
			local s = if math.abs(v) >= 100 then string.format("%d", math.floor(v)) else string.format("%.1f", math.floor(v * 10) / 10)
			s = string.gsub(s, "%.0$", "")
			return s .. u[2]
		end
	end
	return tostring(math.floor(n))
end

function M.money(n: number): string
	return "$" .. M.short(n)
end

function M.name(t: { [string]: string }?): string
	if not t then
		return "?"
	end
	return t[current] or t.ru or t.en or "?"
end

function M.duration(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	local sec = math.floor(seconds % 60)
	if h > 0 then
		return string.format("%d:%02d:%02d", h, m, sec)
	end
	return string.format("%d:%02d", m, sec)
end

return M
