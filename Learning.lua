### Learning.lua
```lua
local addonName, HCP = ...

HCP.history = HCP.history or {}

function HCP:SavePull()
  local report = HCP:AnalyzePull()
  table.insert(HCP.history, report)
  HealerCoachDB = HCP.history
end

function HCP:PrintHistory(n)
  print("HealerCoachPlus History:")
  for i = math.max(1, #HCP.history-n+1), #HCP.history do
    local rep = HCP.history[i]
    print("Pull "..i..": events="..#rep)
  end
end
```
