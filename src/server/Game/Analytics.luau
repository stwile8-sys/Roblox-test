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

-- Воронка обучения (Creator Hub → Analytics → Funnels → Onboarding): видно, на каком шаге бросают.
-- Шаги идут строго по порядку 1..8, каждый шаг у игрока пишется один раз.
local FUNNEL = {
	"1_start", -- получил первое существо
	"2_thief_came", -- вор унёс существо, стрелка ведёт в логово
	"3_stole_from_den", -- забрал Хроно-Жука из логова
	"4_first_steal_home", -- донёс добычу домой (первая кража)
	"5_raid_defend", -- рейдер у ворот, подсказка про замок
	"6_go_buy", -- подсказка купить существо на конвейере
	"7_bought", -- купил существо
	"8_done", -- донёс покупку, обучение пройдено
}

function M.funnel(S: any, stepIndex: number)
	if not S or not S.player or S.isBot or not FUNNEL[stepIndex] then
		return
	end
	S.funnelSeen = S.funnelSeen or {}
	if S.funnelSeen[stepIndex] then
		return
	end
	S.funnelSeen[stepIndex] = true
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(S.player, stepIndex, FUNNEL[stepIndex])
	end)
end

Ctx.api.track = M.track
Ctx.api.funnel = M.funnel

return M
