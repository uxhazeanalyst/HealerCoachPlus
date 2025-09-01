### UI.lua
```lua
local addonName, HCP = ...

local frame = CreateFrame("Frame", "HCP_UI", UIParent, "BackdropTemplate")
frame:SetSize(220, 150)
frame:SetPoint("CENTER")
frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
frame:SetBackdropColor(0, 0, 0, 0.7)
frame:EnableMouse(true)
frame:SetMovable(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
frame.title:SetPoint("TOP", 0, -10)
frame.title:SetText("HealerCoachPlus")

HCP.UI = frame

-- Show tracked CDs
HCP.bars = {}
function HCP:UpdateUI()
  local cds = HCP.DEFAULT_CD_BY_SPEC["DRUID_Restoration"]
  for i, spell in ipairs(cds) do
    if not HCP.bars[i] then
      local bar = CreateFrame("StatusBar", nil, frame)
      bar:SetSize(200, 16)
      bar:SetPoint("TOP", frame, "TOP", 0, -30 - (i-1)*18)
      bar:SetStatusBarTexture("Interface/TargetingFrame/UI-StatusBar")
      bar.bg = bar:CreateTexture(nil, "BACKGROUND")
      bar.bg:SetAllPoints(true)
      bar.bg:SetColorTexture(0.1,0.1,0.1,0.7)
      bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      bar.text:SetPoint("LEFT", bar, "LEFT", 4, 0)
      HCP.bars[i] = bar
    end
    local start, duration, enabled = GetSpellCooldown(spell)
    local remaining = (enabled == 1 and duration > 1) and (start+duration-GetTime()) or 0
    local bar = HCP.bars[i]
    bar:SetMinMaxValues(0, duration)
    bar:SetValue(duration-remaining)
    bar.text:SetText(spell .. (remaining>0 and (" - "..math.floor(remaining).."s") or " - Ready"))
  end
end

frame:SetScript("OnUpdate", function() HCP:UpdateUI() end)

-- History Browser Panel
local hist = CreateFrame("Frame", "HCP_HistoryUI", UIParent, "BackdropTemplate")
hist:SetSize(300, 400)
hist:SetPoint("CENTER", 300, 0)
hist:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background"})
hist:SetBackdropColor(0, 0, 0, 0.85)
hist:Hide()

hist.title = hist:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
hist.title:SetPoint("TOP", 0, -10)
hist.title:SetText("HCP Pull History")

HCP.HistoryUI = hist

hist.buttons = {}

function HCP:RefreshHistoryUI()
  for _, b in ipairs(hist.buttons) do b:Hide() end
  wipe(hist.buttons)

  local max = math.min(20, #HCP.history)
  for i=1,max do
    local rep = HCP.history[#HCP.history - i + 1]
    local btn = CreateFrame("Button", nil, hist, "UIPanelButtonTemplate")
    btn:SetSize(260, 20)
    btn:SetPoint("TOP", 0, -40 - (i-1)*22)
    btn:SetText("Pull "..(#HCP.history - i + 1))
    btn:SetScript("OnClick", function()
      print("=== Pull "..(#HCP.history - i + 1).." Summary ===")
      for _, e in ipairs(rep) do
        print("-", e.type, e.detail or "")
      end
      local rec = HCP:RecommendStats()
      print("Recommended Stats:")
      for stat,val in pairs(rec) do
        print(string.format("  %s: %.2f", stat, val))
      end
    end)

    -- Sparkline background
    btn.spark = btn:CreateTexture(nil, "ARTWORK")
    btn.spark:SetSize(80, 12)
    btn.spark:SetPoint("RIGHT", -10, 0)
    btn.spark:SetColorTexture(0.2, 0.8, 0.2, 0.8) -- default green

    -- Color-shift based on stress: red if deaths, yellow if spikes, green if smooth
    local stressLevel = 0
    for _, e in ipairs(rep) do
      if e.type == "death" then stressLevel = stressLevel + 2 end
      if e.type == "lowHP" then stressLevel = stressLevel + 1 end
    end
    if stressLevel >= 3 then
      btn.spark:SetColorTexture(0.8, 0.2, 0.2, 0.9) -- red
    elseif stressLevel == 2 then
      btn.spark:SetColorTexture(0.9, 0.9, 0.2, 0.9) -- yellow
    else
      btn.spark:SetColorTexture(0.2, 0.8, 0.2, 0.9) -- green
    end

    table.insert(hist.buttons, btn)
  end
end

hist:SetScript("OnShow", function() HCP:RefreshHistoryUI() end)
```
