### UI.lua
```lua
local addonName, HCP = ...

-- Main History & Coach Summary Panel
local hist = CreateFrame("Frame", "HCP_HistoryUI", UIParent, "BackdropTemplate")
hist:SetSize(400, 500)
hist:SetPoint("CENTER")
hist:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
hist:SetBackdropColor(0, 0, 0, 0.85)
hist:Hide()

hist.title = hist:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hist.title:SetPoint("TOP", 0, -10)
hist.title:SetText("HCP Pull History & Summary")
HCP.HistoryUI = hist

-- Scrollable frame for summary content
local scrollFrame = CreateFrame("ScrollFrame", "HCP_ScrollFrame", hist, "UIPanelScrollFrameTemplate")
scrollFrame:SetSize(380, 430)
scrollFrame:SetPoint("TOP", hist, "TOP", 0, -40)

local content = CreateFrame("Frame", nil, scrollFrame)
content:SetSize(380, 1)
scrollFrame:SetScrollChild(content)

content.text = content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
content.text:SetPoint("TOPLEFT", 0, 0)
content.text:SetJustifyH("LEFT")
content.text:SetWidth(380)

function HCP:RefreshSummaryUI()
  local lines = {}
  table.insert(lines, "───────────── HealerCoachPlus Report ─────────────")
  table.insert(lines, string.format("Pulls Analyzed: %d", #HCP.history))

  -- Aggregate stats
  local statTotals = {Haste=0, Mastery=0, Versatility=0, CriticalStrike=0}
  local pullCount = #HCP.history
  for _, pull in ipairs(HCP.history) do
    local rec = HCP:RecommendStats()
    for stat, val in pairs(rec) do statTotals[stat] = statTotals[stat] + val end
  end

  table.insert(lines, "Overall Stat Trend:")
  for stat, total in pairs(statTotals) do
    table.insert(lines, string.format("  %s = %.2f", stat, total/pullCount))
  end

  -- Scorecard
  local function grade(value)
    if value >= 0.3 then return "A" elseif value >= 0.25 then return "B" elseif value >= 0.2 then return "C" else return "D" end
  end
  table.insert(lines, "\nScorecard:")
  table.insert(lines, string.format("  Cooldowns: %s", grade(statTotals.Versatility/pullCount)))
  table.insert(lines, string.format("  Mana: %s", grade(statTotals.Haste/pullCount)))
  table.insert(lines, string.format("  Stat Focus: %s", grade(statTotals.Mastery/pullCount)))

  -- Pull-wise verdicts
  table.insert(lines, "\nVerdicts by Pull:")
  for i, pull in ipairs(HCP.history) do
    table.insert(lines, string.format(" Pull %d: %d events, moment verdicts included.", i, #pull))
  end

  table.insert(lines, "───────────── End of Report ─────────────")
  content.text:SetText(table.concat(lines, "\n"))
  content:SetHeight(content.text:GetStringHeight())
end

hist:SetScript("OnShow", function() HCP:RefreshSummaryUI() end)
```
