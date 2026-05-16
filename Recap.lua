local addonName = ...
local BCB = BetterCastBar

local Recap = {}
BCB.Recap = Recap

local frame, runList, runDetail, selectedIndex

local STATUS_COLORS = {
    completed     = { 0.40, 0.90, 0.40 },
    abandoned     = { 1.00, 0.40, 0.40 },
    in_progress   = { 0.90, 0.80, 0.30 },
}

local STATUS_LABEL = {
    completed   = "Completed",
    abandoned   = "Abandoned",
    in_progress = "In progress",
}

local function FormatDuration(seconds)
    if not seconds or seconds < 0 then return "--:--" end
    local m = math.floor(seconds / 60)
    local s = seconds % 60
    return string.format("%d:%02d", m, s)
end

local function FormatStart(epoch)
    if not epoch then return "" end
    return date("%m/%d %H:%M", epoch)
end

local function GetSpellInfoCompat(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local name, _, icon = GetSpellInfo(spellID)
        return name, icon
    end
    return nil, nil
end

local function CollectRuns()
    local list = {}
    local db = BetterCastBarTrackerDB or {}
    if db.currentRun then
        table.insert(list, db.currentRun)
    end
    if db.history then
        for _, run in ipairs(db.history) do
            table.insert(list, run)
        end
    end
    return list
end

local function RunHeader(run)
    local difficulty = run.difficultyName or ""
    if run.isChallenge and run.keystoneLevel then
        difficulty = "M+" .. run.keystoneLevel
    end
    local title = run.instanceName or "Unknown"
    if difficulty ~= "" then
        title = title .. " (" .. difficulty .. ")"
    end
    return title
end

local function RefreshDetail()
    if not runDetail then return end
    local runs = CollectRuns()
    local run = runs[selectedIndex]

    if not run then
        runDetail.title:SetText("Select a run on the left")
        runDetail.subtitle:SetText("")
        runDetail.summary:SetText("")
        for _, row in ipairs(runDetail.rows) do row:Hide() end
        return
    end

    runDetail.title:SetText(RunHeader(run))

    local status = STATUS_LABEL[run.status] or run.status or "?"
    local color = STATUS_COLORS[run.status] or { 1, 1, 1 }
    local duration = (run.endTime or time()) - (run.startTime or time())
    local subtitle = string.format(
        "|cff%02x%02x%02x%s|r  -  %s  -  duration %s",
        color[1]*255, color[2]*255, color[3]*255, status,
        FormatStart(run.startTime), FormatDuration(duration)
    )
    runDetail.subtitle:SetText(subtitle)

    local bossCount = run.bossKills and #run.bossKills or 0
    local succeeded = run.spellCasts or 0
    local cancelled = run.cancelledCasts or 0
    local attempts  = succeeded + cancelled
    local cancelPct = attempts > 0 and (cancelled / attempts * 100) or 0
    local uniqueSpells = 0
    if run.spells then
        for _ in pairs(run.spells) do uniqueSpells = uniqueSpells + 1 end
    end

    runDetail.summary:SetText(string.format(
        "Casts: %d  -  cancelled: %d (%.1f%%)  -  unique: %d  -  bosses: %d  -  deaths: %d",
        attempts, cancelled, cancelPct, uniqueSpells, bossCount, run.deaths or 0
    ))

    local sorted = {}
    if run.spells then
        for spellID, count in pairs(run.spells) do
            table.insert(sorted, { id = spellID, count = count })
        end
    end
    table.sort(sorted, function(a, b) return a.count > b.count end)

    for i, row in ipairs(runDetail.rows) do
        local entry = sorted[i]
        if entry then
            local name, icon = GetSpellInfoCompat(entry.id)
            row.icon:SetTexture(icon or 134400)
            row.name:SetText(name or ("Spell " .. entry.id))
            row.count:SetText(tostring(entry.count))
            row:Show()
        else
            row:Hide()
        end
    end
end

local function RefreshList()
    if not runList then return end
    local runs = CollectRuns()

    for i, btn in ipairs(runList.buttons) do
        local run = runs[i]
        if run then
            local status = STATUS_LABEL[run.status] or "?"
            local color = STATUS_COLORS[run.status] or { 1, 1, 1 }
            btn.title:SetText(RunHeader(run))
            btn.subtitle:SetFormattedText(
                "|cff%02x%02x%02x%s|r  %s",
                color[1]*255, color[2]*255, color[3]*255, status,
                FormatStart(run.startTime)
            )
            btn:Show()
            if i == selectedIndex then
                btn.selected:Show()
            else
                btn.selected:Hide()
            end
        else
            btn:Hide()
        end
    end

    RefreshDetail()
end

local function CreateRunButton(parent, index)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(220, 36)

    btn.selected = btn:CreateTexture(nil, "BACKGROUND")
    btn.selected:SetAllPoints()
    btn.selected:SetColorTexture(0.3, 0.5, 0.9, 0.25)
    btn.selected:Hide()

    btn.highlight = btn:CreateTexture(nil, "HIGHLIGHT")
    btn.highlight:SetAllPoints()
    btn.highlight:SetColorTexture(1, 1, 1, 0.08)

    btn.title = btn:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    btn.title:SetPoint("TOPLEFT", 6, -4)
    btn.title:SetPoint("RIGHT", -6, 0)
    btn.title:SetJustifyH("LEFT")
    btn.title:SetWordWrap(false)

    btn.subtitle = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    btn.subtitle:SetPoint("BOTTOMLEFT", 6, 4)
    btn.subtitle:SetPoint("RIGHT", -6, 0)
    btn.subtitle:SetJustifyH("LEFT")
    btn.subtitle:SetWordWrap(false)

    btn:SetScript("OnClick", function()
        selectedIndex = index
        RefreshList()
    end)

    return btn
end

local function CreateSpellRow(parent, index)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(280, 22)
    row:SetPoint("TOPLEFT", 0, -(index - 1) * 24)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 0, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
    row.name:SetJustifyH("LEFT")

    row.count = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    row.count:SetPoint("RIGHT", 0, 0)
    row.count:SetJustifyH("RIGHT")

    return row
end

local function CreateFrame_()
    if frame then return end

    frame = CreateFrame("Frame", "BetterCastBarRecapFrame", UIParent, "BackdropTemplate")
    frame:SetSize(620, 440)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetClampedToScreen(true)
    frame:Hide()

    frame:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 },
    })

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText("BetterCastBar - Dungeon Recap")

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    local clear = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clear:SetSize(110, 22)
    clear:SetPoint("BOTTOMRIGHT", -16, 14)
    clear:SetText("Clear history")
    clear:SetScript("OnClick", function()
        BetterCastBarTrackerDB.history = {}
        selectedIndex = 1
        RefreshList()
    end)

    runList = CreateFrame("Frame", nil, frame)
    runList:SetPoint("TOPLEFT", 16, -40)
    runList:SetPoint("BOTTOMLEFT", 16, 44)
    runList:SetWidth(220)

    runList.bg = runList:CreateTexture(nil, "BACKGROUND")
    runList.bg:SetAllPoints()
    runList.bg:SetColorTexture(0, 0, 0, 0.3)

    runList.buttons = {}
    local visibleCount = 9
    for i = 1, visibleCount do
        local btn = CreateRunButton(runList, i)
        if i == 1 then
            btn:SetPoint("TOPLEFT", 4, -4)
            btn:SetPoint("TOPRIGHT", -4, -4)
        else
            btn:SetPoint("TOPLEFT", runList.buttons[i-1], "BOTTOMLEFT", 0, -2)
            btn:SetPoint("TOPRIGHT", runList.buttons[i-1], "BOTTOMRIGHT", 0, -2)
        end
        runList.buttons[i] = btn
    end

    runDetail = CreateFrame("Frame", nil, frame)
    runDetail:SetPoint("TOPLEFT", runList, "TOPRIGHT", 10, 0)
    runDetail:SetPoint("BOTTOMRIGHT", -16, 44)

    runDetail.bg = runDetail:CreateTexture(nil, "BACKGROUND")
    runDetail.bg:SetAllPoints()
    runDetail.bg:SetColorTexture(0, 0, 0, 0.3)

    runDetail.title = runDetail:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    runDetail.title:SetPoint("TOPLEFT", 10, -10)
    runDetail.title:SetPoint("RIGHT", -10, 0)
    runDetail.title:SetJustifyH("LEFT")
    runDetail.title:SetWordWrap(false)

    runDetail.subtitle = runDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    runDetail.subtitle:SetPoint("TOPLEFT", runDetail.title, "BOTTOMLEFT", 0, -4)
    runDetail.subtitle:SetPoint("RIGHT", -10, 0)
    runDetail.subtitle:SetJustifyH("LEFT")

    runDetail.summary = runDetail:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    runDetail.summary:SetPoint("TOPLEFT", runDetail.subtitle, "BOTTOMLEFT", 0, -6)
    runDetail.summary:SetPoint("RIGHT", -10, 0)
    runDetail.summary:SetJustifyH("LEFT")

    local scroll = CreateFrame("ScrollFrame", nil, runDetail, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", runDetail.summary, "BOTTOMLEFT", 0, -10)
    scroll:SetPoint("BOTTOMRIGHT", -26, 10)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(320, 1)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w, h) content:SetWidth(w) end)

    runDetail.rows = {}
    for i = 1, 60 do
        runDetail.rows[i] = CreateSpellRow(content, i)
    end
    content:SetHeight(24 * 60)
end

function Recap:Toggle()
    CreateFrame_()
    if frame:IsShown() then
        frame:Hide()
    else
        selectedIndex = selectedIndex or 1
        RefreshList()
        frame:Show()
    end
end

function Recap:Show()
    CreateFrame_()
    selectedIndex = selectedIndex or 1
    RefreshList()
    frame:Show()
end

function Recap:ShowLatest()
    CreateFrame_()
    selectedIndex = 1
    RefreshList()
    frame:Show()
end
