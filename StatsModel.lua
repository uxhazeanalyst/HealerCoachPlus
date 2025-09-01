### StatsModel.lua
```lua
local addonName, HCP = ...

HCP.STAT_WEIGHTS = {
  DRUID_Restoration = {Haste=0.35, Mastery=0.30, Versatility=0.20, CriticalStrike=0.15}
}

function HCP:RecommendStats()
  local spec = "DRUID_Restoration"
  local base = HCP.STAT_WEIGHTS[spec]
  local adaptive = {}

  local spikeCount, deathCount = 0, 0
  for _, e in ipairs(HCP.dangerWindows) do
    if e.type == "death" then deathCount = deathCount+1 end
    if e.type == "lowHP" then spikeCount = spikeCount+1 end
  end

  for stat, val in pairs(base) do adaptive[stat] = val end
  if spikeCount > 2 then adaptive["Mastery"] = adaptive["Mastery"] + 0.05 end
  if deathCount > 0 then adaptive["Versatility"] = adaptive["Versatility"] + 0.05 end

  return adaptive
end
```
