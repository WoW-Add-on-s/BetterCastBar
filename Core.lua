local addonName, addon = ...

BetterCastBar = {}
local BCB = BetterCastBar

BCB.defaults = {
    width = 250,
    height = 24,
    point = "CENTER",
    relativePoint = "CENTER",
    xOfs = 0,
    yOfs = -180,

    backgroundColor   = { 0.05, 0.05, 0.05, 0.85 },
    barColor          = { 1.00, 0.70, 0.00, 1.00 },
    channelColor      = { 0.30, 0.70, 1.00, 1.00 },
    nonInterruptColor = { 0.50, 0.50, 0.50, 1.00 },
    failedColor       = { 1.00, 0.10, 0.10, 1.00 },
    textColor         = { 1.00, 1.00, 1.00, 1.00 },
    safeZoneColor     = { 1.00, 0.10, 0.10, 0.55 },

    showText      = true,
    showTime      = true,
    showIcon      = true,
    iconOnLeft    = true,
    showSafeZone  = true,
    showQueueIcon = true,

    fontSize = 12,
    locked   = true,

    frameAlpha = 1.0,

    safeZoneScale = 1.0,

    barTexture = "Interface\\TargetingFrame\\UI-StatusBar",
}

local function CopyDefaults(src, dst)
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = dst[k] or {}
            for i = 1, #v do
                if dst[k][i] == nil then dst[k][i] = v[i] end
            end
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local frame
local castData = {}
local UpdateSafeZone

local function ApplyAppearance()
    if not frame then return end
    local db = BetterCastBarDB

    frame:SetSize(db.width, db.height)
    frame:ClearAllPoints()
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.xOfs, db.yOfs)
    frame:SetAlpha(db.frameAlpha or 1.0)

    frame.bg:SetColorTexture(unpack(db.backgroundColor))

    frame.bar:SetStatusBarTexture(db.barTexture)

    frame.text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    frame.time:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    frame.text:SetTextColor(unpack(db.textColor))
    frame.time:SetTextColor(unpack(db.textColor))

    frame.text:SetShown(db.showText)
    frame.time:SetShown(db.showTime)

    frame.icon:SetShown(db.showIcon)
    frame.icon:SetSize(db.height, db.height)
    frame.icon:ClearAllPoints()
    if db.iconOnLeft then
        frame.icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    else
        frame.icon:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    end

    local qSize = math.max(8, math.floor(db.height * 0.7))
    frame.queueIcon:SetSize(qSize, qSize)
    frame.queueIcon:ClearAllPoints()
    if db.iconOnLeft then
        frame.queueIcon:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    else
        frame.queueIcon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    end
    if not db.showQueueIcon then
        frame.queueIcon:Hide()
        castData.queueGUID = nil
    end

    frame.safeZone:SetColorTexture(unpack(db.safeZoneColor))
    frame.safeZone:SetShown(db.showSafeZone and castData.casting == true)
    if castData.casting then UpdateSafeZone() end

    frame:EnableMouse(not db.locked)
end
BCB.ApplyAppearance = ApplyAppearance

function UpdateSafeZone()
    local db = BetterCastBarDB
    if not db.showSafeZone or not castData.casting or castData.channel then
        frame.safeZone:Hide()
        return
    end

    local queueWindowMS = tonumber(GetCVar("SpellQueueWindow")) or 400
    local castDuration = (castData.endTime - castData.startTime) / 1000
    if castDuration <= 0 then
        frame.safeZone:Hide()
        return
    end

    local scale = db.safeZoneScale or 1.0
    local fraction = math.min(((queueWindowMS / 1000) / castDuration) * scale, 1)
    local barWidth = frame.bar:GetWidth()
    frame.safeZone:SetWidth(math.max(1, barWidth * fraction))
    frame.safeZone:Show()
end

local function StopCast()
    castData.casting = false
    castData.channel = false
    castData.queueGUID = nil
    frame.bar:SetValue(0)
    frame.safeZone:Hide()
    frame.queueIcon:Hide()
    frame:SetScript("OnUpdate", nil)
    frame:Hide()
end

local function ShowFailed(failedColor)
    local r, g, b, a = unpack(failedColor)
    frame.bar:SetStatusBarColor(r, g, b, a)
    frame.bar:SetValue(1)
    frame.time:SetText("")
    frame.safeZone:Hide()
    frame.queueIcon:Hide()
    castData.casting = false
    castData.channel = false
    castData.queueGUID = nil

    C_Timer.After(0.6, function()
        if not castData.casting and not castData.channel then
            frame:Hide()
            frame:SetScript("OnUpdate", nil)
        end
    end)
end

local function StartCast(unit, isChannel)
    local db = BetterCastBarDB
    local name, text, texture, startTime, endTime, _, castID, notInterruptible

    if isChannel then
        name, text, texture, startTime, endTime, _, notInterruptible = UnitChannelInfo(unit)
    else
        name, text, texture, startTime, endTime, _, castID, notInterruptible = UnitCastingInfo(unit)
    end

    if not name then
        StopCast()
        return
    end

    castData.casting    = true
    castData.channel    = isChannel
    castData.startTime  = startTime
    castData.endTime    = endTime
    castData.castID     = castID
    castData.notInterruptible = notInterruptible
    castData.queueGUID  = nil
    frame.queueIcon:Hide()

    frame.icon:SetTexture(texture)
    frame.text:SetText(text or name or "")

    if notInterruptible then
        frame.bar:SetStatusBarColor(unpack(db.nonInterruptColor))
    elseif isChannel then
        frame.bar:SetStatusBarColor(unpack(db.channelColor))
    else
        frame.bar:SetStatusBarColor(unpack(db.barColor))
    end

    frame.bar:SetMinMaxValues(startTime / 1000, endTime / 1000)
    frame.bar:SetValue(GetTime())

    UpdateSafeZone()
    frame:Show()

    frame:SetScript("OnUpdate", function(self)
        if not castData.casting then return end
        local now = GetTime()
        local s = castData.startTime / 1000
        local e = castData.endTime / 1000

        if now >= e then
            StopCast()
            return
        end

        if castData.channel then
            self.bar:SetValue(e - (now - s))
            self.time:SetText(string.format("%.1f", e - now))
        else
            self.bar:SetValue(now)
            self.time:SetText(string.format("%.1f", e - now))
        end
    end)
end

local function CreateCastBar()
    local db = BetterCastBarDB
    frame = CreateFrame("Frame", "BetterCastBarFrame", UIParent, "BackdropTemplate")
    frame:SetSize(db.width, db.height)
    frame:SetPoint(db.point, UIParent, db.relativePoint, db.xOfs, db.yOfs)
    frame:SetMovable(true)
    frame:SetClampedToScreen(false)
    frame:RegisterForDrag("LeftButton")
    frame:SetFrameStrata("MEDIUM")
    frame:Hide()

    frame.bg = frame:CreateTexture(nil, "BACKGROUND")
    frame.bg:SetAllPoints()
    frame.bg:SetColorTexture(unpack(db.backgroundColor))

    frame.bar = CreateFrame("StatusBar", nil, frame)
    frame.bar:SetPoint("TOPLEFT", 1, -1)
    frame.bar:SetPoint("BOTTOMRIGHT", -1, 1)
    frame.bar:SetStatusBarTexture(db.barTexture)
    frame.bar:SetStatusBarColor(unpack(db.barColor))
    frame.bar:SetMinMaxValues(0, 1)
    frame.bar:SetValue(0)

    frame.safeZone = frame.bar:CreateTexture(nil, "ARTWORK", nil, 7)
    frame.safeZone:SetColorTexture(unpack(db.safeZoneColor))
    frame.safeZone:SetPoint("TOPRIGHT", frame.bar, "TOPRIGHT")
    frame.safeZone:SetPoint("BOTTOMRIGHT", frame.bar, "BOTTOMRIGHT")
    frame.safeZone:Hide()

    frame.text = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.text:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    frame.text:SetPoint("LEFT", 6, 0)
    frame.text:SetTextColor(unpack(db.textColor))

    frame.time = frame.bar:CreateFontString(nil, "OVERLAY")
    frame.time:SetFont(STANDARD_TEXT_FONT, db.fontSize, "OUTLINE")
    frame.time:SetPoint("RIGHT", -6, 0)
    frame.time:SetTextColor(unpack(db.textColor))

    frame.icon = frame:CreateTexture(nil, "OVERLAY")
    frame.icon:SetSize(db.height, db.height)
    frame.icon:SetPoint("RIGHT", frame, "LEFT", -4, 0)
    frame.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    frame.queueIcon = frame:CreateTexture(nil, "OVERLAY")
    frame.queueIcon:SetSize(math.floor(db.height * 0.7), math.floor(db.height * 0.7))
    frame.queueIcon:SetPoint("LEFT", frame, "RIGHT", 4, 0)
    frame.queueIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    frame.queueIcon:Hide()

    frame.lockText = frame.bar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.lockText:SetPoint("CENTER")
    frame.lockText:SetText("BetterCastBar - drag to move")
    frame.lockText:Hide()

    frame:SetScript("OnDragStart", function(self)
        if not BetterCastBarDB.locked then self:StartMoving() end
    end)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        BetterCastBarDB.point         = point
        BetterCastBarDB.relativePoint = relativePoint
        BetterCastBarDB.xOfs          = xOfs
        BetterCastBarDB.yOfs          = yOfs
    end)

    frame:SetScript("OnShow", function() if not BetterCastBarDB.locked then frame.lockText:Show() end end)
    frame:SetScript("OnHide", function() frame.lockText:Hide() end)
end
BCB.CreateCastBar = CreateCastBar
BCB.GetFrame = function() return frame end

local function ShowQueuedSpell(spellID)
    if not spellID then return end
    if not BetterCastBarDB.showQueueIcon then return end
    if not castData.casting then return end
    local icon
    if C_Spell and C_Spell.GetSpellTexture then
        icon = C_Spell.GetSpellTexture(spellID)
    end
    if not icon and GetSpellTexture then
        icon = GetSpellTexture(spellID)
    end
    if not icon then return end
    frame.queueIcon:SetTexture(icon)
    frame.queueIcon:Show()
end

local hooksInstalled = false
function BCB.HookCastFunctions()
    if hooksInstalled then return end
    hooksInstalled = true

    if UseAction then
        hooksecurefunc("UseAction", function(slot)
            local actionType, id, subType = GetActionInfo(slot)
            if actionType == "spell" then
                ShowQueuedSpell(id)
            elseif actionType == "macro" then
                local spellID = GetMacroSpell and GetMacroSpell(id)
                if spellID then ShowQueuedSpell(spellID) end
            end
        end)
    end

    if CastSpellByID then
        hooksecurefunc("CastSpellByID", function(spellID)
            ShowQueuedSpell(spellID)
        end)
    end

    if CastSpellByName then
        hooksecurefunc("CastSpellByName", function(spellName)
            if not spellName then return end
            local spellID
            if C_Spell and C_Spell.GetSpellInfo then
                local info = C_Spell.GetSpellInfo(spellName)
                if info then spellID = info.spellID end
            end
            if not spellID and GetSpellInfo then
                spellID = select(7, GetSpellInfo(spellName))
            end
            if spellID then ShowQueuedSpell(spellID) end
        end)
    end

    if C_Spell and C_Spell.CastSpell then
        hooksecurefunc(C_Spell, "CastSpell", function(spellID)
            ShowQueuedSpell(spellID)
        end)
    end
end

function BCB:SetUnlocked(unlocked)
    BetterCastBarDB.locked = not unlocked
    ApplyAppearance()
    if unlocked then
        frame.bar:SetMinMaxValues(0, 1)
        frame.bar:SetValue(1)
        frame.bar:SetStatusBarColor(unpack(BetterCastBarDB.barColor))
        frame.text:SetText("BetterCastBar")
        frame.time:SetText("")
        frame.icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
        if BetterCastBarDB.showQueueIcon then
            frame.queueIcon:SetTexture("Interface\\Icons\\Spell_Nature_Lightning")
            frame.queueIcon:Show()
        end
        frame:Show()
        frame.lockText:Show()
    else
        frame.lockText:Hide()
        if not castData.casting then
            frame.queueIcon:Hide()
            frame:Hide()
        end
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")

events:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "ADDON_LOADED" and arg1 == addonName then
        BetterCastBarDB = BetterCastBarDB or {}
        CopyDefaults(BCB.defaults, BetterCastBarDB)

    elseif event == "PLAYER_LOGIN" then
        CreateCastBar()
        ApplyAppearance()

        self:RegisterUnitEvent("UNIT_SPELLCAST_START", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_STOP", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_FAILED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_DELAYED", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_START", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_STOP", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_CHANNEL_UPDATE", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_INTERRUPTIBLE", "player")
        self:RegisterUnitEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE", "player")

        BCB.HookCastFunctions()

        if BCB.RegisterOptions then BCB.RegisterOptions() end

    elseif event == "UNIT_SPELLCAST_START" then
        StartCast("player", false)

    elseif event == "UNIT_SPELLCAST_CHANNEL_START" then
        StartCast("player", true)

    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if castData.casting and not castData.channel then
            local _, _, _, startTime, endTime = UnitCastingInfo("player")
            if startTime then
                castData.startTime = startTime
                castData.endTime   = endTime
                frame.bar:SetMinMaxValues(startTime / 1000, endTime / 1000)
                UpdateSafeZone()
            end
        end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if castData.casting and castData.channel then
            local _, _, _, startTime, endTime = UnitChannelInfo("player")
            if startTime then
                castData.startTime = startTime
                castData.endTime   = endTime
                frame.bar:SetMinMaxValues(startTime / 1000, endTime / 1000)
            end
        end

    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        StopCast()

    elseif event == "UNIT_SPELLCAST_FAILED" then
        if castData.casting
           and not UnitCastingInfo("player")
           and not UnitChannelInfo("player") then
            ShowFailed(BetterCastBarDB.failedColor)
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        if castData.casting
           and not UnitCastingInfo("player")
           and not UnitChannelInfo("player") then
            ShowFailed(BetterCastBarDB.failedColor)
        end

    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" then
        if castData.casting and not castData.channel then
            frame.bar:SetStatusBarColor(unpack(BetterCastBarDB.barColor))
        elseif castData.casting and castData.channel then
            frame.bar:SetStatusBarColor(unpack(BetterCastBarDB.channelColor))
        end

    elseif event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if castData.casting then
            frame.bar:SetStatusBarColor(unpack(BetterCastBarDB.nonInterruptColor))
        end
    end
end)

SLASH_BETTERCASTBAR1 = "/bcb"
SLASH_BETTERCASTBAR2 = "/bettercastbar"
SlashCmdList["BETTERCASTBAR"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "unlock" then
        BCB:SetUnlocked(true)
        print("|cff7ec0eeBetterCastBar|r: unlocked - drag the bar to move it.")
    elseif msg == "lock" then
        BCB:SetUnlocked(false)
        print("|cff7ec0eeBetterCastBar|r: locked.")
    elseif msg == "reset" then
        BetterCastBarDB = {}
        CopyDefaults(BCB.defaults, BetterCastBarDB)
        ApplyAppearance()
        print("|cff7ec0eeBetterCastBar|r: settings reset to defaults.")
    elseif msg == "recap" then
        if BCB.Recap then BCB.Recap:Toggle() end
    elseif msg == "test" then
        castData.casting   = true
        castData.channel   = false
        castData.startTime = GetTime() * 1000
        castData.endTime   = (GetTime() + 3) * 1000
        frame.text:SetText("Test Cast")
        frame.icon:SetTexture("Interface\\Icons\\Spell_Holy_MagicalSentry")
        frame.bar:SetStatusBarColor(unpack(BetterCastBarDB.barColor))
        frame.bar:SetMinMaxValues(castData.startTime / 1000, castData.endTime / 1000)
        frame.bar:SetValue(GetTime())
        UpdateSafeZone()
        frame:Show()
        frame:SetScript("OnUpdate", function(self)
            local now = GetTime()
            if now >= castData.endTime / 1000 then StopCast() return end
            self.bar:SetValue(now)
            self.time:SetText(string.format("%.1f", castData.endTime / 1000 - now))
        end)
    else
        print("|cff7ec0eeBetterCastBar|r commands:")
        print("  /bcb unlock - unlock the bar to move it")
        print("  /bcb lock   - lock the bar")
        print("  /bcb test   - run a test cast (3s)")
        print("  /bcb recap  - open the dungeon recap window")
        print("  /bcb reset  - reset settings to defaults")
        print("  Options panel: ESC > Options > AddOns > BetterCastBar")
    end
end
