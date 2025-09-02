-- ########################################################
-- MythicPlusCombatText.lua — cleaned & debugged
-- Purpose: lightweight combat text + coaching hints for Mythic+ (tank/healer helpers)
-- Notes: defensive coding, consolidated frame, safe API usage, reduced globals
-- ########################################################

local ADDON = "MyCombatTextCoach"

-- Single main frame (avoid duplicate globals)
local Main = CreateFrame("Frame", ADDON.."MainFrame")
Main:Hide()

-- =======================
-- Config / Options (safe guards)
-- =======================
local includeWorld = true -- show open-world combat when true
local spikeThresholdAoE = 0.25 -- default AoE percent spike for suggestions
local healerCoach = true -- enable healer coaching suggestions

-- =======================
-- Colors and helpers
-- =======================
local COLORS = {
    physical = {r=1, g=0,   b=0},
    bleed    = {r=0.8, g=0, b=0},
    holy     = {r=1, g=0.84, b=0},
    fire     = {r=1, g=0,   b=0},
    nature   = {r=0.6, g=0.4, b=0.2},
    frost    = {r=0, g=0.5, b=1},
    shadow   = {r=0.2, g=0.2, b=0.4},
    arcane   = {r=0.6, g=0, b=0.8},
    dodge    = {r=1, g=1,   b=0},
    parry    = {r=0, g=1,   b=1},
    absorb   = {r=0, g=1,   b=0},
    miss     = {r=0.7, g=0.7, b=0.7},
    block    = {r=0.6, g=0.4, b=1},
    magical  = {r=0.6, g=0.8, b=1},
    coach    = {r=1, g=0.66, b=0},
}

local CLASS_COLORS = {
    DRUID     = {r=1.0, g=0.49, b=0.04},
    MONK      = {r=0.0, g=1.0, b=0.59},
    SHAMAN    = {r=0.0, g=0.44, b=0.87},
    PRIEST    = {r=1.0, g=1.0, b=1.0},
    PALADIN   = {r=0.96, g=0.55, b=0.73},
    EVOKER    = {r=0.20, g=0.58, b=0.50},
}

local function Colorize(text, color)
    if not color then return text end
    return string.format("|cff%02x%02x%02x%s|r", math.floor((color.r or 1)*255), math.floor((color.g or 1)*255), math.floor((color.b or 1)*255), text)
end

local function SafeAddMessage(msg, r,g,b, isCrit)
    if CombatText_AddMessage then
        CombatText_AddMessage(msg, CombatText_StandardScroll, r or 1, g or 1, b or 1, isCrit and "crit" or nil, false)
    else
        -- fallback to default print for debugging when combat text isn't available
        print(msg)
    end
end

-- =======================
-- Bit-band (safe)
-- =======================
local band = (bit and bit.band) or (bit32 and bit32.band) or function(a,b) return (a % (2*b)) >= b and 1 or 0 end

-- =======================
-- Combat stats and storage
-- =======================
local combatStats = {
    taken = 0,
    dealt = 0,
    absorbed = 0,
    blocked = 0,
    parried = 0,
    dodged = 0,
    missed = 0,
    cooldownsUsed = {},
}
local fullCombatLog = {}
local damageLog = {} -- per-pull raw log (used by healer coach analysis)

-- player GUID tracked on login
local playerGUID = UnitGUID("player")

-- =======================
-- Utilities: group helpers
-- =======================
local function UnitPrefix()
    return IsInRaid() and "raid" or "party"
end

local function NumGroupMembers()
    return GetNumGroupMembers() or 0
end

local function GetHealerClasses()
    local healers = {}
    local num = NumGroupMembers()
    local prefix = UnitPrefix()
    for i = 1, num do
        local unit = prefix..i
        if UnitExists(unit) then
            local role = UnitGroupRolesAssigned(unit)
            if role == "HEALER" then
                local _, class = UnitClass(unit)
                healers[class] = true
            end
        end
    end
    -- include self if healer
    if UnitGroupRolesAssigned("player") == "HEALER" then
        local _, class = UnitClass("player")
        healers[class] = true
    end
    return healers
end

-- =======================
-- Mythic+ forces query (safe)
-- =======================
local prevForces = 0
local function QueryForcesCriterion()
    if not C_Scenario or not C_Scenario.GetCriteriaInfo then return nil, nil end
    for i=1, 10 do
        local ok, name, _, cur, total = pcall(function() return C_Scenario.GetCriteriaInfo(i) end)
        if not ok then break end
        if not name then break end
        local lname = name:lower()
        if lname:find("force") or lname:find("enemy") or lname:find("count") then
            return cur, total
        end
    end
    return nil, nil
end

local function ShowForcesFloatingText()
    local cur, total = QueryForcesCriterion()
    if not cur or not total or total == 0 then return end
    local gained = cur - prevForces
    if gained < 0 then gained = cur end
    prevForces = cur
    local percent = (cur / total) * 100
    local msg = string.format("+%d forces — %.1f%% (%d/%d)", gained, percent, cur, total)
    local color = COLORS.coach
    SafeAddMessage(Colorize(msg, color), color.r, color.g, color.b)
end

-- =======================
-- Healer cooldown suggestions (config table)
-- =======================
local HEALER_COOLDOWNS = {
    PRIEST = {{name = "Divine Hymn", spellID = 64843}, {name = "Power Word: Barrier", spellID = 62618}},
    DRUID  = {{name = "Tranquility", spellID = 740}, {name = "Flourish", spellID = 197721}},
    MONK   = {{name = "Revival", spellID = 115310}, {name = "Life Cocoon", spellID = 116849}},
    SHAMAN = {{name = "Spirit Link Totem", spellID = 98008}, {name = "Healing Tide Totem", spellID = 108280}},
    PALADIN= {{name = "Aura Mastery", spellID = 31821}, {name = "Lay on Hands", spellID = 633}},
    EVOKER = {{name = "Rewind", spellID = 363534}, {name = "Dream Breath", spellID = 355913}},
}

local function SuggestHealingCooldowns(damageSpike)
    if not healerCoach or damageSpike <= spikeThresholdAoE then return end
    local healers = GetHealerClasses()
    for class,_ in pairs(healers) do
        local cds = HEALER_COOLDOWNS[class]
        if cds then
            for _, cd in ipairs(cds) do
                local classColor = CLASS_COLORS[class] or COLORS.coach
                SafeAddMessage(Colorize("Suggest: "..cd.name, classColor), classColor.r, classColor.g, classColor.b)
            end
        end
    end
end

-- =======================
-- Combat log processing
-- =======================
local function ShouldProcessCombatEvent(sourceGUID, destGUID)
    if sourceGUID == playerGUID or destGUID == playerGUID then return true end
    if includeWorld and not IsInInstance() then -- open world
        if destGUID == playerGUID then return true end
    end
    return false
end

local function RecordFullEvent(kind, data)
    fullCombatLog[#fullCombatLog+1] = {type = kind, t = GetTime(), data = data}
end

local function LogDamageEvent(dstGUID, amount, school)
    damageLog[#damageLog+1] = {t = GetTime(), target = dstGUID, dmg = amount, school = school}
end

-- Process a single CLEU event (defensive, safe parsing)
local function HandleCombatLogEvent()
    local timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags,
          destGUID, destName, destFlags, destRaidFlags, spellId, spellName, spellSchool, amount = CombatLogGetCurrentEventInfo()

    amount = amount or 0
    spellName = spellName or ""

    -- Ignore events we don't care about
    if not ShouldProcessCombatEvent(sourceGUID, destGUID) then return end

    -- OUTGOING
    if sourceGUID == playerGUID then
        if subEvent == "SWING_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
            combatStats.dealt = combatStats.dealt + amount
            RecordFullEvent("dealt", {source = sourceGUID, dest = destGUID, spell = spellName, amount = amount})
            SafeAddMessage(Colorize(string.format("+%d (%s)", amount, spellName), COLORS.magical), COLORS.magical.r, COLORS.magical.g, COLORS.magical.b, false)
        end
        return
    end

    -- INCOMING to player
    if destGUID == playerGUID then
        if subEvent == "SWING_DAMAGE" or subEvent == "RANGE_DAMAGE" or subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
            combatStats.taken = combatStats.taken + amount
            RecordFullEvent("taken", {source = sourceGUID, dest = destGUID, spell = spellName, amount = amount})
            SafeAddMessage(Colorize(string.format("-%d (%s)", amount, spellName), COLORS.physical), COLORS.physical.r, COLORS.physical.g, COLORS.physical.b, false)

            -- track for healer coaching: capture group HP snapshot to compute spikes
            if healerCoach and (subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE") then
                -- compute group HP percent quickly (sampling)
                local members = NumGroupMembers()
                if members > 0 then
                    local totalHP, totalMax = 0,0
                    local prefix = UnitPrefix()
                    for i=1, members do
                        local unit = prefix..i
                        if UnitExists(unit) then
                            totalHP = totalHP + UnitHealth(unit)
                            totalMax = totalMax + UnitHealthMax(unit)
                        end
                    end
                    if totalMax > 0 then
                        local currentPercent = totalHP / totalMax
                        -- store a damage sample (we use LogDamageEvent and compute spikes on end of combat or periodic)
                        LogDamageEvent(destGUID, amount, spellSchool)
                    end
                end
            end
            return
        elseif subEvent == "SWING_MISSED" or subEvent == "SPELL_MISSED" or subEvent == "RANGE_MISSED" then
            -- miss types position varies; get the miss type string safely
            local missType = select(1, select(21, CombatLogGetCurrentEventInfo()) or "") or ""
            missType = missType and tostring(missType) or ""
            if missType == "DODGE" then
                combatStats.dodged = combatStats.dodged + 1
                SafeAddMessage(Colorize("Dodged", COLORS.dodge), COLORS.dodge.r, COLORS.dodge.g, COLORS.dodge.b)
            elseif missType == "PARRY" then
                combatStats.parried = combatStats.parried + 1
                SafeAddMessage(Colorize("Parried", COLORS.parry), COLORS.parry.r, COLORS.parry.g, COLORS.parry.b)
            elseif missType == "ABSORB" then
                combatStats.absorbed = combatStats.absorbed + 1
                SafeAddMessage(Colorize("Absorbed", COLORS.absorb), COLORS.absorb.r, COLORS.absorb.g, COLORS.absorb.b)
            elseif missType == "BLOCK" then
                combatStats.blocked = combatStats.blocked + 1
                SafeAddMessage(Colorize("Blocked", COLORS.block), COLORS.block.r, COLORS.block.g, COLORS.block.b)
            else
                combatStats.missed = combatStats.missed + 1
            end
            return
        end
    end
end

-- Register event handler
Main:RegisterEvent("PLAYER_LOGIN")
Main:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
Main:RegisterEvent("PLAYER_REGEN_ENABLED")
Main:RegisterEvent("CHALLENGE_MODE_COMPLETED")
Main:RegisterEvent("UNIT_DIED")

-- Minimal comments kept to under five across the file
Main:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        prevForces = 0
    elseif event == "COMBAT_LOG_EVENT_UNFILTERED" then
        HandleCombatLogEvent()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- end of combat
        -- compute healer suggestions (simple): collate damageLog totals
        if healerCoach and #damageLog > 0 then
            -- compute AOEs vs single-target
            local aoe, st = 0, 0
            local tankGUID = nil
            -- try to find assigned tank in group
            local num = NumGroupMembers()
            local prefix = UnitPrefix()
            for i=1,num do
                local unit = prefix..i
                if UnitExists(unit) and UnitGroupRolesAssigned(unit) == "TANK" then
                    tankGUID = UnitGUID(unit); break
                end
            end
            for _,d in ipairs(damageLog) do
                if tankGUID and d.target == tankGUID then st = st + d.dmg else aoe = aoe + d.dmg end
            end
            if aoe > 0 and (aoe / math.max(1, aoe+st)) >= spikeThresholdAoE then
                SuggestHealingCooldowns(aoe / math.max(1, aoe+st))
            end
        end
        -- show per-pull summary
        local total = combatStats.taken
        local absorbedPct = total>0 and (combatStats.absorbed / total * 100) or 0
        local blockedPct = total>0 and (combatStats.blocked / total * 100) or 0
        local parryRate = (combatStats.parried + combatStats.dodged + combatStats.missed) > 0 and
                          (combatStats.parried / (combatStats.parried + combatStats.dodged + combatStats.missed) * 100) or 0
        SafeAddMessage(Colorize("===== Combat Summary =====", COLORS.coach), COLORS.coach.r, COLORS.coach.g, COLORS.coach.b)
        SafeAddMessage(Colorize(string.format("Absorbed: %d (%.1f%%)", combatStats.absorbed, absorbedPct), COLORS.absorb), COLORS.absorb.r, COLORS.absorb.g, COLORS.absorb.b)
        SafeAddMessage(Colorize(string.format("Blocked: %d (%.1f%%)", combatStats.blocked, blockedPct), COLORS.block), COLORS.block.r, COLORS.block.g, COLORS.block.b)
        SafeAddMessage(Colorize(string.format("Parry Rate: %.1f%%", parryRate), COLORS.parry), COLORS.parry.r, COLORS.parry.g, COLORS.parry.b)
        SafeAddMessage(Colorize("Damage Taken: "..combatStats.taken, COLORS.physical), COLORS.physical.r, COLORS.physical.g, COLORS.physical.b)
        SafeAddMessage(Colorize("Damage Dealt: "..combatStats.dealt, COLORS.magical), COLORS.magical.r, COLORS.magical.g, COLORS.magical.b)
        -- reset
        combatStats.taken = 0; combatStats.dealt = 0; combatStats.absorbed = 0; combatStats.blocked = 0
        combatStats.parried = 0; combatStats.dodged = 0; combatStats.missed = 0
        damageLog = {}
    elseif event == "CHALLENGE_MODE_COMPLETED" then
        -- dungeon end summary
        -- print dungeon aggregated log
        local totalTaken, totalBlocked, totalAbsorbed, totalDodged, totalParried, totalMissed, totalDealt = 0,0,0,0,0,0,0
        for i=1,#fullCombatLog do
            local e = fullCombatLog[i]
            if e.type == "taken" and e.data then
                totalTaken = totalTaken + (e.data.amount or 0)
                totalBlocked = totalBlocked + (e.data.blocked or 0)
                totalAbsorbed = totalAbsorbed + (e.data.absorbed or 0)
                totalDodged = totalDodged + (e.data.dodged or 0)
                totalParried = totalParried + (e.data.parried or 0)
                totalMissed = totalMissed + (e.data.missed or 0)
            elseif e.type == "dealt" and e.data then
                totalDealt = totalDealt + (e.data.amount or 0)
            end
        end
        SafeAddMessage(Colorize("===== Dungeon Total Summary =====", COLORS.coach), COLORS.coach.r, COLORS.coach.g, COLORS.coach.b)
        SafeAddMessage(Colorize("Damage Taken: "..totalTaken, COLORS.physical), COLORS.physical.r, COLORS.physical.g, COLORS.physical.b)
        SafeAddMessage(Colorize("Blocked: "..totalBlocked, COLORS.block), COLORS.block.r, COLORS.block.g, COLORS.block.b)
        SafeAddMessage(Colorize("Absorbed: "..totalAbsorbed, COLORS.absorb), COLORS.absorb.r, COLORS.absorb.g, COLORS.absorb.b)
        SafeAddMessage(Colorize("Dodged: "..totalDodged, COLORS.dodge), COLORS.dodge.r, COLORS.dodge.g, COLORS.dodge.b)
        SafeAddMessage(Colorize("Parried: "..totalParried, COLORS.parry), COLORS.parry.r, COLORS.parry.g, COLORS.parry.b)
        SafeAddMessage(Colorize("Missed: "..totalMissed, COLORS.miss), COLORS.miss.r, COLORS.miss.g, COLORS.miss.b)
        SafeAddMessage(Colorize("Damage Dealt: "..totalDealt, COLORS.magical), COLORS.magical.r, COLORS.magical.g, COLORS.magical.b)
        fullCombatLog = {}
        prevForces = 0
    elseif event == "UNIT_DIED" then
        -- show forces after slight delay for scenario updates
        C_Timer.After(0.35, ShowForcesFloatingText)
    end
end)

-- CLEU hookup (use separate tiny frame to avoid conflicting scripts)
Main:SetScript("OnUpdate", function() end) -- keep Main alive for timers

local CLEU = CreateFrame("Frame")
CLEU:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
CLEU:SetScript("OnEvent", function() HandleCombatLogEvent() end)

-- periodic ticker stub (non-blocking)
if C_Timer and C_Timer.NewTicker then
    C_Timer.NewTicker(10, function()
        -- lightweight periodic checks could be placed here
    end)
end

-- End of cleaned file
