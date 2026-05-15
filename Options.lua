local addonName = ...
local BCB = BetterCastBar

local function Apply() BCB.ApplyAppearance() end

local function OpenColorPicker(key, hasOpacity)
    local db = BetterCastBarDB
    local current = db[key]
    local r, g, b, a = current[1], current[2], current[3], current[4] or 1

    local function swatch()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = hasOpacity and ColorPickerFrame:GetColorAlpha() or a
        db[key] = { nr, ng, nb, na }
        Apply()
    end
    local function opacityFunc()
        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
        local na = ColorPickerFrame:GetColorAlpha()
        db[key] = { nr, ng, nb, na }
        Apply()
    end
    local function cancel(prev)
        db[key] = { prev.r, prev.g, prev.b, prev.opacity or a }
        Apply()
    end

    local info = {
        swatchFunc  = swatch,
        opacityFunc = opacityFunc,
        cancelFunc  = cancel,
        hasOpacity  = hasOpacity and true or false,
        opacity     = a,
        r = r, g = g, b = b,
    }

    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow(info)
    else
        ColorPickerFrame:Hide()
        for k, v in pairs(info) do ColorPickerFrame[k] = v end
        ShowUIPanel(ColorPickerFrame)
    end
end

local function MakeColorRow(parent, anchorTo, label, key, hasOpacity)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, 26)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -8)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", 0, 0)
    text:SetText(label)
    text:SetWidth(260)
    text:SetJustifyH("LEFT")

    local swatch = CreateFrame("Button", nil, row, "BackdropTemplate")
    swatch:SetSize(50, 18)
    swatch:SetPoint("LEFT", text, "RIGHT", 10, 0)
    swatch:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets   = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    local function refresh()
        local c = BetterCastBarDB[key]
        swatch:SetBackdropColor(c[1], c[2], c[3], c[4] or 1)
    end
    swatch:SetScript("OnClick", function()
        OpenColorPicker(key, hasOpacity)
        C_Timer.After(0.05, refresh)
    end)
    swatch:SetScript("OnShow", refresh)
    refresh()

    return row
end

local function MakeSliderRow(parent, anchorTo, label, key, minV, maxV, step, suffix)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, 38)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -10)

    local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("TOPLEFT", 0, 0)
    text:SetText(label)

    local slider = CreateFrame("Slider", nil, row, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", text, "BOTTOMLEFT", 0, -4)
    slider:SetWidth(260)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if slider.Low then slider.Low:SetText(tostring(minV)) end
    if slider.High then slider.High:SetText(tostring(maxV)) end

    local valText = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    valText:SetPoint("LEFT", slider, "RIGHT", 12, 0)

    local function fmt(v)
        if step < 1 then
            return string.format("%.2f", v) .. (suffix or "")
        end
        return tostring(math.floor(v + 0.5)) .. (suffix or "")
    end

    slider:SetValue(BetterCastBarDB[key])
    valText:SetText(fmt(BetterCastBarDB[key]))

    slider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / step + 0.5) * step
        BetterCastBarDB[key] = v
        valText:SetText(fmt(v))
        Apply()
    end)

    return row
end

local function MakeCheckRow(parent, anchorTo, label, key, onChange)
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(420, 26)
    row:SetPoint("TOPLEFT", anchorTo, "BOTTOMLEFT", 0, -6)

    local cb = CreateFrame("CheckButton", nil, row, "UICheckButtonTemplate")
    cb:SetPoint("LEFT", 0, 0)
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
    cb.text:SetText(label)
    cb:SetChecked(BetterCastBarDB[key])
    cb:SetScript("OnClick", function(self)
        BetterCastBarDB[key] = self:GetChecked() and true or false
        if onChange then onChange(BetterCastBarDB[key]) end
        Apply()
    end)

    return row
end

function BCB.RegisterOptions()
    local panel = CreateFrame("Frame", "BetterCastBarOptionsPanel", UIParent)
    panel.name = "BetterCastBar"

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("BetterCastBar")

    local subtitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)
    subtitle:SetText("Customizable cast bar - type /bcb for commands")

    local scroll = CreateFrame("ScrollFrame", "BetterCastBarOptionsScroll", panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -12)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -28, 16)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(540, 860)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, w, h)
        content:SetWidth(w)
    end)

    local container = CreateFrame("Frame", nil, content)
    container:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -4)
    container:SetSize(440, 24)

    local last = container

    last = MakeCheckRow(content, last, "Unlock the bar (edit mode)", "locked", nil)
    do
        local cb = last:GetChildren()
        cb:SetChecked(not BetterCastBarDB.locked)
        cb:SetScript("OnClick", function(self)
            BCB:SetUnlocked(self:GetChecked())
        end)
    end

    last = MakeSliderRow(content, last, "Width",  "width",  80, 600, 5, " px")
    last = MakeSliderRow(content, last, "Height", "height", 10, 80,  1, " px")
    last = MakeSliderRow(content, last, "Text size", "fontSize", 8, 24, 1, " pt")
    last = MakeSliderRow(content, last, "Opacity", "frameAlpha", 0.10, 1.00, 0.05, "")

    last = MakeSliderRow(content, last, "Horizontal position (X)", "xOfs", -2000, 2000, 1, " px")
    last = MakeSliderRow(content, last, "Vertical position (Y)",   "yOfs", -1500, 1500, 1, " px")

    last = MakeCheckRow(content, last, "Show spell name", "showText")
    last = MakeCheckRow(content, last, "Show remaining time", "showTime")
    last = MakeCheckRow(content, last, "Show spell icon",  "showIcon")
    last = MakeCheckRow(content, last, "Icon on left (otherwise on right)", "iconOnLeft")
    last = MakeCheckRow(content, last, "Show queued spell icon (opposite side)", "showQueueIcon")
    last = MakeCheckRow(content, last, "Show safe zone (cancel window)", "showSafeZone")
    last = MakeSliderRow(content, last, "Safe zone size (multiplier)", "safeZoneScale", 0.25, 5.00, 0.05, "x")

    last = MakeColorRow(content, last, "Background color",              "backgroundColor",   true)
    last = MakeColorRow(content, last, "Bar color (cast)",              "barColor",          true)
    last = MakeColorRow(content, last, "Bar color (channel)",           "channelColor",      true)
    last = MakeColorRow(content, last, "Color (non-interruptible)",     "nonInterruptColor", true)
    last = MakeColorRow(content, last, "Color (failed / interrupted)",  "failedColor",       true)
    last = MakeColorRow(content, last, "Text color",                    "textColor",         true)
    last = MakeColorRow(content, last, "Safe zone color",               "safeZoneColor",     true)

    local resetBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    resetBtn:SetSize(140, 22)
    resetBtn:SetPoint("TOPLEFT", last, "BOTTOMLEFT", 0, -16)
    resetBtn:SetText("Reset to defaults")
    resetBtn:SetScript("OnClick", function()
        BetterCastBarDB = {}
        for k, v in pairs(BCB.defaults) do
            if type(v) == "table" then
                BetterCastBarDB[k] = {}
                for i = 1, #v do BetterCastBarDB[k][i] = v[i] end
            else
                BetterCastBarDB[k] = v
            end
        end
        Apply()
        ReloadUI()
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "BetterCastBar")
        Settings.RegisterAddOnCategory(category)
        BCB.categoryID = category:GetID()
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end
