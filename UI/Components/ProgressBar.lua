local MOS = BootyLib
local UI = MOS.UI.Components

local ProgressBar = {}
UI.ProgressBar = ProgressBar

local function OnProgressUpdate()
    if not this.active or not this.startedAt then this:SetScript("OnUpdate", nil); return end
    local percent = math.min(this.progressCap, math.floor((GetTime() - this.startedAt) * this.progressRate))
    if percent ~= this.progressPercent then
        this.progressPercent = percent
        this:SetValue(percent)
        this.text:SetText(this.progressLabel .. "... " .. percent .. "%")
    end
    -- The controller continues its request; an animation at its cap is idle.
    if percent >= this.progressCap then this:SetScript("OnUpdate", nil) end
end

local function SetProgressUpdate(bar)
    if bar.active and bar.startedAt and bar:IsVisible() and bar.progressPercent < bar.progressCap then
        bar:SetScript("OnUpdate", OnProgressUpdate)
    else bar:SetScript("OnUpdate", nil) end
end

local function OnProgressShow()
    SetProgressUpdate(this)
end

local function OnProgressHide()
    -- A hidden ancestor suspends display work, not the explicit scan request.
    this:SetScript("OnUpdate", nil)
end

function ProgressBar.Create(parent, width, height)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetWidth(width or 280)
    bar:SetHeight(height or 16)
    bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    bar:SetStatusBarColor(0.72, 0.48, 0.08, 1)
    bar:SetMinMaxValues(0, 100)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 10, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bar:SetBackdropColor(0.03, 0.03, 0.03, 0.97)
    bar.text = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    bar:SetScript("OnShow", OnProgressShow)
    bar:SetScript("OnHide", OnProgressHide)
    bar:Hide()
    return bar
end

function ProgressBar.Start(bar, label, startedAt, rate, cap)
    bar.progressLabel = label or "Working"
    bar.startedAt = startedAt or GetTime()
    bar.progressRate = rate or 7
    bar.progressCap = cap or 94
    bar.active = true
    bar.progressPercent = 0
    bar:SetValue(0)
    bar.text:SetText(bar.progressLabel .. "... 0%")
    bar:Show()
    SetProgressUpdate(bar)
end

function ProgressBar.Stop(bar)
    bar.active = false
    bar.startedAt = nil
    bar:SetScript("OnUpdate", nil)
    bar:Hide()
end

function ProgressBar.Complete(bar)
    bar:SetValue(100)
    ProgressBar.Stop(bar)
end
