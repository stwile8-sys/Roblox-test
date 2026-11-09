--!strict
-- Переводчик. Ключ → строка на языке игрока, {имя} заменяется аргументом.
-- Язык: выбранный в настройках, иначе язык Roblox у игрока, иначе английский.

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

local current = "en"
local listeners: { () -> () } = {}

function M.isLang(code: any): boolean
	return type(code) == "string" and M.NATIVE[code] ~= nil
end

function M.fromLocale(locale: string): string
	local code = string.lower(string.sub(locale, 1, 2))
	return if M.NATIVE[code] then code else "en"
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
		s = row[current] or row.en or key
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

function M.money(n: number): string
	return M.num(n) .. " c"
end

function M.duration(seconds: number): string
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return M.t("time.hm", { h = h, m = m })
	end
	return M.t("time.m", { m = math.max(1, m) })
end

return M
