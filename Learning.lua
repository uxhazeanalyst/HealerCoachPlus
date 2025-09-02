### Learning.lua (Added Coach Summary + Scorecard)
```lua
local addonName, HCP = ...

function HCP:GenerateCoachSummary()
  if #HCP.history == 0 then print("No pulls recorded.") return end

  local summaryText = {}  -- store lines
  table.insert(summaryText, "───────────── HealerCoachPlus Report ─────────────")
  table.insert(summaryText, string.format("Pulls Analyzed: %d", #HCP.history))

  -- Aggregate stats
  local statTotals = {Haste=0, Mastery=0, Versatility=0, CriticalStrike=0}
  local pullCount = #HCP.history
  for _, pull in ipairs(HCP.history) do
    local rec = HCP:RecommendStats() -- per pull
    for stat, val in pairs(rec) do statTotals[stat] = statTotals[stat] + val end
  end
  table.insert(summaryText, "Overall Stat Trend:")
  for stat, total in pairs(statTotals) do
    table.insert(summaryText, string.format("  %s = %.2f", stat, total/pullCount))
  end

  -- Simple scorecard
  local function grade(value)
    if value >= 0.3 then return "A" elseif value >= 0.25 then return "B" elseif value >= 0.2 then return "C" else return "D" end
  end
  table.insert(summaryText, "\nScorecard:")
  table.insert(summaryText, string.format("  Cooldowns: %s", grade(statTotals.Versatility/pullCount)))
  table.insert(summaryText, string.format("  Mana: %s", grade(statTotals.Haste/pullCount)))
  table.insert(summaryText, string.format("  Stat Focus: %s", grade(statTotals.Mastery/pullCount)))

  -- Pull-wise verdicts
  table.insert(summaryText, "\nVerdicts by Pull:")
  for i, pull in ipairs(HCP.history) do
    table.insert(summaryText, string.format(" Pull %d: %d events, moment verdicts included.", i, #pull))
  end

  table.insert(summaryText, "───────────── End of Report ─────────────")

  for _, line in ipairs(summaryText) do print(line) end
end
```
