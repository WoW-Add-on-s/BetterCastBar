local addonName, addon = ...
local BCB = BetterCastBar

local Tracker = {}
BCB.Tracker = Tracker

local HISTORY_CAP = 50

local function NewRun()
    return {
        startTime        = time(),
        endTime          = nil,
        instanceID       = nil,
        instanceName     = nil,
        instanceType     = nil,
        difficultyID     = nil,
        difficultyName   = nil,
        keystoneLevel    = nil,
        isChallenge      = false,
        status           = "in_progress",
        spells           = {},
        spellCasts       = 0,
        cancelledSpells  = {},
        cancelledCasts   = 0,
        bossKills        = {},
        deaths           = 0,
    }
end

local function FillInstanceInfo(run)
    local name, instanceType, difficultyID, difficultyName, _, _, _, instanceID = GetInstanceInfo()
    run.instanceID     = instanceID
    run.instanceName   = name
    run.instanceType   = instanceType
    run.difficultyID   = difficultyID
    run.difficultyName = difficultyName
end

local function CurrentInstanceIsParty()
    local inInstance, instanceType = IsInInstance()
    return inInstance and instanceType == "party"
end

local function ArchiveRun(run, status)
    if not run then return end
    run.status  = status or run.status
    run.endTime = run.endTime or time()
    local db = BetterCastBarTrackerDB
    db.history = db.history or {}
    table.insert(db.history, 1, run)
    while #db.history > (db.historyCap or HISTORY_CAP) do
        table.remove(db.history)
    end
end

function Tracker:StartRun(reason)
    local db = BetterCastBarTrackerDB
    if db.currentRun then
        ArchiveRun(db.currentRun, "abandoned")
        db.currentRun = nil
    end
    if not CurrentInstanceIsParty() then return end
    local run = NewRun()
    FillInstanceInfo(run)
    run.startReason = reason
    db.currentRun = run
end

function Tracker:FinishRun(status)
    local db = BetterCastBarTrackerDB
    local run = db.currentRun
    if not run then return end
    ArchiveRun(run, status)
    db.currentRun = nil

    if status == "completed" and BCB.Recap and BCB.Recap.ShowLatest then
        C_Timer.After(2, function() BCB.Recap:ShowLatest() end)
    end
end

function Tracker:OnEnterChallenge()
    local db = BetterCastBarTrackerDB
    if not db.currentRun then
        self:StartRun("challenge")
    end
    local run = db.currentRun
    if not run then return end
    run.isChallenge = true
    if C_ChallengeMode and C_ChallengeMode.GetActiveKeystoneInfo then
        local level = C_ChallengeMode.GetActiveKeystoneInfo()
        run.keystoneLevel = level
    end
    FillInstanceInfo(run)
end

function Tracker:OnZoneCheck()
    local db = BetterCastBarTrackerDB
    local inParty = CurrentInstanceIsParty()

    if inParty and not db.currentRun then
        self:StartRun("zone")
        return
    end

    if (not inParty) and db.currentRun and db.currentRun.status == "in_progress" then
        ArchiveRun(db.currentRun, "abandoned")
        db.currentRun = nil
    end
end

function Tracker:OnSpellSucceeded(spellID)
    local db = BetterCastBarTrackerDB
    local run = db.currentRun
    if not run then return end
    if not spellID then return end
    run.spells[spellID] = (run.spells[spellID] or 0) + 1
    run.spellCasts = run.spellCasts + 1
end

function Tracker:OnSpellInterrupted(spellID)
    local db = BetterCastBarTrackerDB
    local run = db.currentRun
    if not run then return end
    if not spellID then return end
    run.cancelledSpells = run.cancelledSpells or {}
    run.cancelledSpells[spellID] = (run.cancelledSpells[spellID] or 0) + 1
    run.cancelledCasts = (run.cancelledCasts or 0) + 1
end

function Tracker:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)
    local db = BetterCastBarTrackerDB
    local run = db.currentRun
    if not run then return end
    if success == 1 then
        table.insert(run.bossKills, { id = encounterID, name = encounterName, time = time() })
    end
end

function Tracker:OnPlayerDead()
    local db = BetterCastBarTrackerDB
    local run = db.currentRun
    if not run then return end
    run.deaths = (run.deaths or 0) + 1
end

function Tracker:ResumeOrFinalizeOnLogin()
    local db = BetterCastBarTrackerDB
    local run = db.currentRun
    if not run then return end

    if CurrentInstanceIsParty() then
        local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
        if instanceID and run.instanceID == instanceID then
            return
        end
    end

    ArchiveRun(run, "abandoned")
    db.currentRun = nil
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        BetterCastBarTrackerDB = BetterCastBarTrackerDB or {}
        local db = BetterCastBarTrackerDB
        db.history    = db.history or {}
        db.historyCap = db.historyCap or HISTORY_CAP

    elseif event == "PLAYER_LOGIN" then
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
        self:RegisterEvent("CHALLENGE_MODE_START")
        self:RegisterEvent("CHALLENGE_MODE_COMPLETED")
        self:RegisterEvent("CHALLENGE_MODE_RESET")
        self:RegisterEvent("LFG_COMPLETION_REWARD")
        self:RegisterEvent("ENCOUNTER_END")
        self:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        self:RegisterEvent("PLAYER_DEAD")

        Tracker:ResumeOrFinalizeOnLogin()

    elseif event == "PLAYER_ENTERING_WORLD" then
        Tracker:OnZoneCheck()

    elseif event == "ZONE_CHANGED_NEW_AREA" then
        Tracker:OnZoneCheck()

    elseif event == "CHALLENGE_MODE_START" then
        Tracker:OnEnterChallenge()

    elseif event == "CHALLENGE_MODE_COMPLETED" then
        Tracker:FinishRun("completed")

    elseif event == "CHALLENGE_MODE_RESET" then
        Tracker:FinishRun("abandoned")

    elseif event == "LFG_COMPLETION_REWARD" then
        Tracker:FinishRun("completed")

    elseif event == "ENCOUNTER_END" then
        local encounterID, encounterName, difficultyID, groupSize, success = arg1, ...
        Tracker:OnEncounterEnd(encounterID, encounterName, difficultyID, groupSize, success)

    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = arg1, ...
        Tracker:OnSpellSucceeded(spellID)

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        local unit, castGUID, spellID = arg1, ...
        Tracker:OnSpellInterrupted(spellID)

    elseif event == "PLAYER_DEAD" then
        Tracker:OnPlayerDead()
    end
end)
