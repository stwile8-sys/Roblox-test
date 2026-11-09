--!nonstrict
-- Аналитика: события ТЗ (раздел 13) через AnalyticsService. Ошибки не мешают игре.

local AnalyticsService = game:GetService("AnalyticsService")

local Ctx = require(script.Parent.Ctx)

local M: any = {}

function M.track(S: any, event: string, value: number?, extra: { [string]: any }?)
	if not S or not S.player or S.isBot then
		return
	end
	local fields = nil
	if extra then
		fields = {}
		local i = 0
		for k, v in extra do
			i += 1
			if i > 3 then
				break
			end
			fields[((Enum.AnalyticsCustomFieldKeys :: any)["CustomField0" .. i]).Name] = tostring(k) .. "=" .. tostring(v)
		end
	end
	pcall(function()
		AnalyticsService:LogCustomEvent(S.player, event, value or 1, fields)
	end)
	if event == "purchase_completed" then
		pcall(function()
			AnalyticsService:LogEconomyEvent(S.player, Enum.AnalyticsEconomyFlowType.Source, "Robux", value or 0, 0, Enum.AnalyticsEconomyTransactionType.IAP.Name, extra and tostring(extra.item) or nil)
		end)
	end
end

Ctx.api.track = M.track

return M
