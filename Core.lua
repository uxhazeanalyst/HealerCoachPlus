### Core.lua
-- Event tracking for healing, deaths, dungeon completion
local frame = CreateFrame("Frame")
frame:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("CHALLENGE_MODE_COMPLETED")


frame:SetScript("OnEvent", function(_, event, ...)
if event == "COMBAT_LOG_EVENT_UNFILTERED" then
local _, subEvent, _, _, _, _, _, destGUID, _, _, _, spellID, spellName, _, amount = CombatLogGetCurrentEventInfo()
if subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
table.insert(HCP.healingEvents, {t=GetTime(), spell=spellName, amount=amount, target=destGUID})
elseif subEvent == "UNIT_DIED" then
table.insert(HCP.dangerWindows, {t=GetTime(), type="death", detail=destGUID})
end
elseif event == "PLAYER_ENTERING_WORLD" then
HCP.activeSpec = GetSpecializationInfo(GetSpecialization() or 0)
elseif event == "CHALLENGE_MODE_COMPLETED" then
HCP:GenerateCoachSummary()
end
end)


-- Slash commands
SLASH_HCP1 = "/hcp"
SlashCmdList["HCP"] = function(msg)
if msg == "recommend" then
local rec = HCP:RecommendStats()
print("HealerCoachPlus Stat Recommendation:")
for stat, val in pairs(rec) do
print(string.format(" %s: %.2f", stat, val))
end
elseif msg:match("^history") then
local n = tonumber(msg:match("history (%d+)") or 5)
HCP:PrintHistory(n)
elseif msg == "ui" then
if HCP.HistoryUI then HCP.HistoryUI:Show() end
elseif msg == "summary" then
HCP:GenerateCoachSummary()
elseif msg == "debug" then
HCP.debug = not HCP.debug
print("HCP Debug:", HCP.debug)
else
print("/hcp recommend - show stat recommendations")
print("/hcp history <n> - show last n pull summaries")
print("/hcp ui - open history browser")
print("/hcp summary - post-dungeon summary report")
end
end
```
