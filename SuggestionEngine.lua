### SuggestionEngine.lua
```lua
local addonName, HCP = ...

function HCP:AnalyzePull()
  local dangerT = HCP:adaptiveThreshold()
  local report = {}
  for _, event in ipairs(HCP.dangerWindows) do
    table.insert(report, event)
  end

  local mana = UnitPower("player", 0)
  table.insert(report, {t=GetTime(), type="mana", detail=mana})

  HCP.lastReport = report
  return report
end
```
