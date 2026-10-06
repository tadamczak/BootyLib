local MOS = BootyLib
local UI = MOS.UI.Components
UI.MinimizedWindowHeight = 30

function UI.CreateResizeGrip(parent)
    local grip = UI.CreateControl(nil, parent)
    grip:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -7, 7)
    grip:SetWidth(18); grip:SetHeight(18)
    grip:SetFrameLevel(parent:GetFrameLevel() + 1)
    grip.texture = grip:CreateTexture(nil, "OVERLAY")
    local function ApplySkin(skin)
        grip.texture:ClearAllPoints()
        if skin == "classic" then
            grip.texture:SetTexture(UI.ClassicAsset("Icons\\resize.tga"))
            grip.texture:SetVertexColor(1, 0.78, 0.24)
            grip.texture:SetPoint("CENTER", grip, "CENTER", 0, 0)
            grip.texture:SetWidth(13); grip.texture:SetHeight(13)
        else
            grip.texture:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
            grip.texture:SetVertexColor(1, 1, 1); grip.texture:SetAllPoints(grip)
        end
    end
    ApplySkin(UI.IsClassicSkin() and "classic" or "default")
    UI.RegisterSkinCallback(ApplySkin)
    return grip
end

local function FinishClippedLayout()
    local viewport = this
    viewport:SetScript("OnUpdate", nil)
    UI.RefreshClippedContent(viewport, true)
end

function UI.RefreshClippedContent(viewport, settled)
    viewport.content:SetWidth(math.max(1, viewport:GetWidth()))
    if viewport.UpdateScrollChildRect then viewport:UpdateScrollChildRect() end
    viewport:SetVerticalScroll(math.max(0, math.min(viewport:GetVerticalScroll(), math.max(0, viewport.content:GetHeight() - viewport:GetHeight()))))
    if not settled and viewport:IsVisible() then viewport:SetScript("OnUpdate", FinishClippedLayout) end
end

function UI.CreateClippedContent(parent, contentHeight)
    local viewport = UI.CreateScrollFrame(nil, parent)
    local content = UI.CreateContainer(nil, viewport)
    content:SetHeight(contentHeight); viewport:SetScrollChild(content)
    viewport.content = content
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function()
        local maximum = math.max(0, this.content:GetHeight() - this:GetHeight())
        this:SetVerticalScroll(math.max(0, math.min(maximum, this:GetVerticalScroll() - arg1 * 24)))
    end)
    viewport:SetScript("OnShow", function() UI.RefreshClippedContent(this) end)
    viewport:SetScript("OnHide", function() this:SetScript("OnUpdate", nil) end)
    viewport:SetScript("OnSizeChanged", function()
        UI.RefreshClippedContent(this)
    end)
    return viewport, content
end

function UI.ShortenText(text, length)
    text = tostring(text or "")
    if string.len(text) > length then return string.sub(text, 1, length - 1) .. "~" end
    return text
end

local itemQualityHex = {
    [0] = "ff9d9d9d", [1] = "ffffffff", [2] = "ff1eff00", [3] = "ff0070dd",
    [4] = "ffa335ee", [5] = "ffff8000",
}

function UI.GetItemLabel(itemId)
    local itemName, _, itemQuality = GetItemInfo(itemId)
    if not itemName then return "|cffffffff[Item " .. itemId .. "]|r" end
    return "|c" .. (itemQualityHex[tonumber(itemQuality) or 1] or "ffffffff") .. "[" .. itemName .. "]|r"
end

function UI.AnchorTooltip(owner)
    GameTooltip:ClearAllPoints()
    if type(GameTooltip_SetDefaultAnchor) == "function" then
        GameTooltip_SetDefaultAnchor(GameTooltip, owner or UIParent)
    else
        GameTooltip:SetOwner(owner or UIParent, "ANCHOR_NONE")
        GameTooltip:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -(tonumber(CONTAINER_OFFSET_X) or 0) - 13, tonumber(CONTAINER_OFFSET_Y) or 70)
        GameTooltip.default = 1
    end
end

UI.AnchorTooltipRightOfCursor = UI.AnchorTooltip

function UI.ShowItemTooltip(owner)
    if not owner or not owner.itemId then return end
    UI.AnchorTooltipRightOfCursor(owner); GameTooltip:SetHyperlink("item:" .. owner.itemId .. ":0:0:0"); GameTooltip:Show()
    local texture = type(GetItemIcon) == "function" and GetItemIcon(owner.itemId) or nil
    if not texture then local _, _, _, _, _, _, _, _, _, cachedTexture = GetItemInfo(owner.itemId); texture = cachedTexture end
    if owner.iconRegion and texture then owner.iconRegion:SetTexture(texture) end
    if owner.label then owner.label:SetText((owner.labelPrefix or "") .. UI.GetItemLabel(owner.itemId) .. (owner.labelSuffix or "")) end
end

function UI.HandleItemClick(owner)
    if not owner or not owner.itemId then return false end
    local itemName, _, itemQuality = GetItemInfo(owner.itemId)
    itemName = itemName or owner.itemName
    if not itemName then
        UI.ShowItemTooltip(owner)
        itemName, _, itemQuality = GetItemInfo(owner.itemId)
    end
    local itemLink
    if itemName then
        local _, _, _, qualityColor = GetItemQualityColor(tonumber(itemQuality) or 1)
        local colorCode = qualityColor or "|cffffffff"
        if string.sub(colorCode, 1, 2) ~= "|c" then colorCode = "|cffffffff" end
        itemLink = "\124" .. string.sub(colorCode, 2) .. "\124Hitem:" .. owner.itemId .. ":0:0:0\124h[" .. itemName .. "]\124h\124r"
    end
    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
        if not itemLink then return true end
        if WIM_EditBoxInFocus then WIM_EditBoxInFocus:Insert(itemLink)
        elseif MessageBox and MessageBox.isInputFocused and MessageBox.whisperInput then MessageBox.whisperInput:Insert(itemLink)
        elseif ChatFrameEditBox and ChatFrameEditBox.Insert then ChatFrameEditBox:Insert(itemLink)
        elseif type(ChatEdit_InsertLink) == "function" then ChatEdit_InsertLink(itemLink) end
        return true
    end
    if type(IsControlKeyDown) == "function" and IsControlKeyDown() and type(DressUpItemLink) == "function" then
        if not itemLink then return true end
        DressUpItemLink(itemLink); return true
    end
    UI.ShowItemTooltip(owner)
    return true
end

function UI.ApplySelectionListStyle(buttons, items, selectedId, loadButton)
    local selectedAvailable = false
    local selectedColors = UI.Theme.colors.rowSelected
    local normalColors = UI.Theme.colors.button
    local index
    for index = 1, table.getn(buttons) do
        local selected = items[index] and items[index].id == selectedId
        if selected then selectedAvailable = true end
        local color = selected and selectedColors or normalColors
        local border = selected and { 0.85, 0.68, 0.22, 1 } or { 0.48, 0.38, 0.20, 1 }
        if not buttons[index].mosClassicKeepNormalSurface then
        buttons[index]:SetBackdropColor(color[1], color[2], color[3], color[4])
        buttons[index]:SetBackdropBorderColor(border[1], border[2], border[3], border[4])
        end
        if UI.SetClassicButtonSelected then UI.SetClassicButtonSelected(buttons[index], selected) end
        if buttons[index].mosClassicKeepNormalSurface then UI.ApplyDropdownChoiceSurface(buttons[index]) end
        -- Hover handlers restore mosNormalBorder on mouse leave. Keep that
        -- persistent state aligned with the current selection style.
        if buttons[index].mosNormalBorder and not buttons[index].mosClassicKeepNormalSurface then buttons[index].mosNormalBorder = border end
    end
    if loadButton then UI.SetButtonEnabled(loadButton, selectedAvailable) end
    return selectedAvailable
end

-- Keep the control's own logical font. A transient one-pixel layout must not
-- shrink it; numeric EditBoxes also need fresh metrics after inherited scaling.
function UI.ReflowControlText(control)
    local font = control.mosControlFont
    if not font then return end
    local width, height = control:GetWidth(), control:GetHeight()
    local scale = control.GetEffectiveScale and control:GetEffectiveScale() or 1
    if control.mosTextWidth == width and control.mosTextHeight == height and control.mosTextScale == scale then return end
    local label = control.label or control
    -- Preserve the current buffer across metric changes. Mark the bounds first
    -- to suppress synchronous size reentry before restoring the entered text.
    local text = not control.label and label:GetText() or nil
    control.mosTextWidth, control.mosTextHeight, control.mosTextScale = width, height, scale
    local ok, reason = pcall(label.SetFont, label, font[1], font[2], font[3])
    if not ok then
        control.mosTextWidth = nil
        if not control.label then label:SetText(text or "") end
        error(reason)
    end
    if control.label then
        label:SetWidth(math.max(1, width - 28)); label:SetHeight(math.max(1, height - 4))
    else label:SetText(text or "") end
end

local function ReflowControlText() UI.ReflowControlText(this) end

function UI.CreateDropdownButton(parent, name, text, width)
    local button = UI.CreateControl(name, parent)
    button:SetWidth(width or 84); button:SetHeight(24)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    button:SetBackdropColor(0.08, 0.07, 0.05, 0.95)
    button:SetBackdropBorderColor(0.42, 0.35, 0.20, 1)
    button.label = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    local font, size, flags = button.label:GetFont()
    if font then button.label:SetFont(font, size + math.min(0, UI.GetTextSizeDelta(parent) + 1), flags) end
    button.mosLabelJustify = "LEFT"
    button.label:SetPoint("LEFT", button, "LEFT", 4, 0); button.label:SetWidth(math.max(1,(width or 84)-28));button.label:SetJustifyH("LEFT");button.label:SetJustifyV("MIDDLE");button.label:SetText(text)
    font, size, flags = button.label:GetFont()
    button.mosControlFont = {font, size, flags}
    button.SetText = function(self, value) self.label:SetText(value); UI.ReflowControlText(self) end
    button.GetText = function(self) return self.label:GetText() end
    button.arrow = button:CreateTexture(nil, "OVERLAY")
    button.arrow:SetWidth(14); button.arrow:SetHeight(14); button.arrow:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    button.arrow:SetTexture("Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up")
    button.arrow:SetTexCoord(0.20, 0.80, 0.20, 0.80)
    button:SetScript("OnSizeChanged",ReflowControlText)
    UI.ReflowControlText(button)
    if UI.ApplyDropdownChoiceSurface then UI.ApplyDropdownChoiceSurface(button) end
    if UI.RegisterSkinCallback then UI.RegisterSkinCallback(function() UI.ApplyDropdownChoiceSurface(button) end) end
    return button
end

function UI.RefreshDropdownLayers(panel, toggle)
    if UI.WindowStack then
        UI.WindowStack.SetOwner(panel, toggle)
        UI.WindowStack.Attach(panel.dismiss, UI.WindowStack.GetWindow(toggle) and toggle or panel, -1)
        UI.WindowStack.Sync(panel)
        return
    end
    local strata = toggle:GetFrameStrata()
    local level = math.max(math.max(toggle:GetFrameLevel(), toggle:GetParent():GetFrameLevel()) + 20, panel.mosMinimumFrameLevel or 0)
    panel:SetFrameStrata(strata); panel:SetFrameLevel(level)
    -- Keep the outside-click catcher below sibling controls. This lets the same
    -- click close one menu and activate another control instead of being eaten.
    panel.dismiss:SetFrameStrata(strata); panel.dismiss:SetFrameLevel(math.max(0, toggle:GetFrameLevel() - 1))
    local index
    for index = 1, table.getn(panel.options) do
        local option = panel.options[index]
        option:SetFrameStrata(strata); option:SetFrameLevel(level + 1)
        if option.labelHit then option.labelHit:SetFrameStrata(strata); option.labelHit:SetFrameLevel(level + 2) end
    end
    if panel.selectAll then panel.selectAll:SetFrameStrata(strata); panel.selectAll:SetFrameLevel(level + 1) end
end

function UI.CreateDropdownPanel(parent, toggle, width, height, levelOffset)
    local panel = CreateFrame("Frame", nil, UIParent)
    panel.toggle = toggle
    panel.mosTextSizeDelta = UI.GetTextSizeDelta(parent)
    panel:SetPoint("TOPLEFT", toggle, "BOTTOMLEFT", 0, -2)
    panel:SetWidth(width or 130); panel:SetHeight(height or 230)
    panel.contentPadding = 4
    if panel.SetFrameStrata and toggle.GetFrameStrata then panel:SetFrameStrata(toggle:GetFrameStrata()) end
    panel:SetFrameLevel(math.max(parent:GetFrameLevel(), toggle:GetFrameLevel()) + (levelOffset or 50) + 100)
    if panel.SetToplevel then panel:SetToplevel(true) end
    panel:EnableMouse(true)
    panel:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    panel:SetBackdropColor(0.04, 0.03, 0.02, 0.98)
    local dismiss = CreateFrame("Button", nil, UIParent)
    dismiss:SetAllPoints(UIParent)
    if dismiss.SetFrameStrata and toggle.GetFrameStrata then dismiss:SetFrameStrata(toggle:GetFrameStrata()) end
    dismiss:SetFrameLevel(panel:GetFrameLevel() - 1)
    dismiss:EnableMouse(true)
    dismiss:SetScript("OnClick", function() panel:Hide() end)
    dismiss:Hide()
    panel.dismiss = dismiss
    panel.options = {}
    panel:SetScript("OnShow", function()
        if UI.openDropdownPanel and UI.openDropdownPanel ~= panel then UI.openDropdownPanel:Hide() end
        UI.openDropdownPanel = panel
        UI.RefreshDropdownLayers(panel, toggle); dismiss:Show()
    end)
    panel:SetScript("OnHide", function() dismiss:Hide(); if UI.openDropdownPanel == panel then UI.openDropdownPanel = nil end end)
    UI.StyleProjectPopup(panel)
    panel:Hide()
    if UI.WindowStack then
        UI.WindowStack.Register(panel, {kind = "popup", owner = function() return panel.toggle end})
        UI.WindowStack.Attach(dismiss, UI.WindowStack.GetWindow(toggle) and toggle or panel, -1)
    end
    return panel
end

function UI.StyleDropdownChoice(button)
    if UI.SetClassicButtonCompact then UI.SetClassicButtonCompact(button, true) end
    if UI.AttachGoldHoverBorder then UI.AttachGoldHoverBorder(button, 0.35, 0.35, 0.35, 1) end
    if button.label and button.label.GetFont then
        local font, _, flags = button.label:GetFont()
        if font then button.label:SetFont(font, 9 + math.min(0, UI.GetTextSizeDelta(button) + 1), flags) end
    end
    return button
end

function UI.AttachSubtleRowHover(row, alpha)
    if not row.mosSubtleHover then
        row.mosSubtleHover = UI.CreateTexture(row, nil, "ARTWORK")
        row.mosSubtleHover:SetAllPoints(row); row.mosSubtleHover:SetTexture(1,1,1,1); row.mosSubtleHover:Hide()
        row:SetScript("OnEnter", function() this.mosSubtleHover:Show() end)
        row:SetScript("OnLeave", function() this.mosSubtleHover:Hide() end)
    end
    row.mosSubtleHover:SetAlpha(alpha or 0.07)
    return row.mosSubtleHover
end

function UI.CreateSearchBox(parent, name, width)
    local box = CreateFrame("EditBox", name, parent, "InputBoxTemplate")
    box:SetWidth(width or 178); box:SetHeight(20); box:SetAutoFocus(false)
    box:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    return box
end

function UI.CreateFramedEditBox(parent, name, width)
    local box = CreateFrame("EditBox", name, parent)
    box:SetWidth(width or 92); box:SetHeight(24); box:SetAutoFocus(false); box:SetFontObject(GameFontHighlightSmall)
    UI.ApplyTextSizeDelta(box, parent)
    local font, size, flags = box:GetFont()
    box.mosControlFont = {font, size, flags}
    box:SetScript("OnSizeChanged", ReflowControlText)
    UI.ReflowControlText(box)
    box:SetTextInsets(7, 7, 2, 2)
    box:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 10, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    box:SetBackdropColor(0.018, 0.018, 0.016, 1); box:SetBackdropBorderColor(0.48, 0.34, 0.10, 1)
    box:SetScript("OnEscapePressed", function() this:ClearFocus() end); box:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    return box
end

function UI.CreateDatePicker(name)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(224); frame:SetHeight(206); frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(235); frame:EnableMouse(true)
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 14, insets = { left = 5, right = 5, top = 5, bottom = 5 } })
    frame:SetBackdropColor(0.025, 0.025, 0.022, 1)
    UI.RegisterDialogSurface(frame, "panel")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame.previous = UI.CreateButton(frame, nil, "<", 24, 22); frame.previous:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    frame.next = UI.CreateButton(frame, nil, ">", 24, 22); frame.next:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.monthLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal"); frame.monthLabel:SetPoint("LEFT", frame.previous, "RIGHT", 5, 0); frame.monthLabel:SetPoint("RIGHT", frame.next, "LEFT", -5, 0); frame.monthLabel:SetJustifyH("CENTER")
    local weekdayNames = { "Su", "Mo", "Tu", "We", "Th", "Fr", "Sa" }
    local index
    for index = 1, 7 do
        local label = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); label:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + ((index - 1) * 30), -41); label:SetWidth(28); label:SetJustifyH("CENTER"); label:SetText(weekdayNames[index])
    end
    frame.days = {}
    for index = 1, 42 do
        local column, row = math.mod(index - 1, 7), math.floor((index - 1) / 7)
        local button = UI.CreateButton(frame, nil, "", 28, 22); button:SetPoint("TOPLEFT", frame, "TOPLEFT", 8 + (column * 30), -57 - (row * 23)); button.datePicker = frame
        button:SetScript("OnClick", function()
            local picker = this.datePicker
            if this.day and picker.target then
                picker.target:SetText(string.format("%04d-%02d-%02d", picker.year, picker.month, this.day))
                picker:Hide()
                if picker.OnDateSelected then picker:OnDateSelected(picker.target) end
            end
        end)
        frame.days[index] = button
    end
    frame.Refresh = function(self)
        local nextYear, nextMonth = self.year, self.month + 1
        if nextMonth > 12 then nextMonth = 1; nextYear = nextYear + 1 end
        local lastStamp = time({ year = nextYear, month = nextMonth, day = 1, hour = 12 }) - 86400
        local daysInMonth = tonumber(date("%d", lastStamp)) or 30
        local firstWeekday = tonumber(date("%w", time({ year = self.year, month = self.month, day = 1, hour = 12 }))) or 0
        self.monthLabel:SetText(date("%B %Y", time({ year = self.year, month = self.month, day = 1, hour = 12 })))
        local buttonIndex
        for buttonIndex = 1, table.getn(self.days) do
            local day = buttonIndex - firstWeekday
            local button = self.days[buttonIndex]
            if day >= 1 and day <= daysInMonth then button.day = day; button:SetText(day); button:Show() else button.day = nil; button:Hide() end
        end
    end
    frame.ChangeMonth = function(self, delta)
        self.month = self.month + delta
        if self.month < 1 then self.month = 12; self.year = self.year - 1 elseif self.month > 12 then self.month = 1; self.year = self.year + 1 end
        self:Refresh()
    end
    frame.previous:SetScript("OnClick", function() frame:ChangeMonth(-1) end); frame.next:SetScript("OnClick", function() frame:ChangeMonth(1) end)
    frame.Open = function(self, owner, target)
        if UI.WindowStack then UI.WindowStack.SetOwner(self, owner) end
        self.target = target
        local value = target and target:GetText() or ""
        local _, _, year, month = string.find(value, "^(%d%d%d%d)%-(%d%d)%-%d%d$")
        local current = date("*t")
        self.year = tonumber(year) or current.year; self.month = tonumber(month) or current.month
        self:ClearAllPoints(); self:SetPoint("TOPLEFT", owner, "BOTTOMLEFT", 0, -3); self:Refresh(); self:Show()
    end
    frame:Hide()
    if UI.WindowStack then UI.WindowStack.Register(frame) end
    return frame
end

function UI.CreateTextPrompt(name, titleText, labelText, acceptText, onAccept, maxLetters)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(360); frame:SetHeight(145); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 30)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(220); frame:EnableMouse(true)
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetBackdropColor(0.025, 0.025, 0.022, 1)
    UI.RegisterDialogSurface(frame, "panel")
    frame.title = UI.CreateHeading(frame, "", 2, "orange", "fix")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16); frame.title:SetText(titleText or "Enter value")
    frame.label = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -43); frame.label:SetText(labelText or "Value")
    frame.edit = UI.CreateSearchBox(frame, nil, 320)
    frame.edit:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -61); frame.edit:SetMaxLetters(maxLetters or 48)
    frame.message = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    frame.message:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 20); frame.message:SetWidth(170); frame.message:SetJustifyH("LEFT")
    frame.accept = UI.CreateButton(frame, nil, acceptText or "OK", 72, 22)
    frame.accept:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -92, 16)
    frame.cancel = UI.CreateButton(frame, nil, "Cancel", 72, 22)
    frame.cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 16)
    local function Submit()
        frame.message:SetText("")
        local accepted, message = onAccept(frame.edit:GetText() or "")
        if accepted then frame:Hide() else frame.message:SetText(message or "Invalid value"); frame.message:SetTextColor(1, 0.25, 0.2) end
    end
    frame.accept:SetScript("OnClick", Submit); frame.edit:SetScript("OnEnterPressed", Submit)
    frame.edit:SetScript("OnEscapePressed", function() this:ClearFocus(); frame:Hide() end)
    frame.cancel:SetScript("OnClick", function() frame:Hide() end)
    frame.Open = function(self) self.edit:SetText(""); self.message:SetText(""); self:Show(); self.edit:SetFocus() end
    frame:Hide()
    if UI.WindowStack then UI.WindowStack.Register(frame) end
    return frame
end

local deleteIconTint = {0.72, 0.70, 0.8}
function UI.CreateDeleteButton(parent, name, size, iconInset)
    return UI.CreateIconButton(parent, name, "Interface\\AddOns\\BootyLib\\Assets\\DeleteRaid", size, iconInset, deleteIconTint)
end

function UI.CreateIconButton(parent, name, texturePath, size, iconInset, tint)
    local button = UI.CreateControl(name, parent)
    button:SetWidth(size or 20); button:SetHeight(size or 20)
    local normal = button:CreateTexture(nil, "ARTWORK")
    local inset = tonumber(iconInset) or 0
    local red, green, blue = tint and tint[1] or 1, tint and tint[2] or 1, tint and tint[3] or 1
    normal:SetVertexColor(red, green, blue)
    normal:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset); normal:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset); normal:SetTexture(texturePath)
    normal:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button:SetNormalTexture(normal)
    local disabled = button:CreateTexture(nil, "ARTWORK")
    disabled:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset); disabled:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset); disabled:SetTexture(texturePath); disabled:SetTexCoord(0.08, 0.92, 0.08, 0.92); disabled:SetVertexColor(0.35, 0.35, 0.35)
    button:SetDisabledTexture(disabled)
    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(button); highlight:SetTexture("Interface\\Buttons\\ButtonHilight-Square"); highlight:SetBlendMode("ADD")
    button:SetHighlightTexture(highlight)
    button.SetInactive = function(self, inactive)
        self.inactive = inactive and true or false
        local shade = self.inactive and 0.35 or 1
        normal:SetVertexColor(red * shade, green * shade, blue * shade)
        highlight:SetAlpha(self.inactive and 0 or 1)
    end
    button:SetScript("OnMouseDown", function()
        if not this.inactive then normal:SetVertexColor(red * 0.55, green * 0.55, blue * 0.55) end
    end)
    button:SetScript("OnMouseUp", function()
        local shade = this.inactive and 0.35 or 1
        normal:SetVertexColor(red * shade, green * shade, blue * shade)
    end)
    return button
end

function UI.CreateReadOnlyInput(parent, name, width)
    local field = UI.CreateFramedEditBox(parent, name, width)
    field.mosReadOnlyValue = ""
    field.SetValueText = function(self, value) self.mosReadOnlyValue = value or ""; self:SetText(self.mosReadOnlyValue) end
    field:SetScript("OnTextChanged", function()
        if this:GetText() ~= this.mosReadOnlyValue then this:SetText(this.mosReadOnlyValue) end
    end)
    return field
end

function UI.CreateConfirmation(name, options)
    local frame = UI.CreateTextPrompt(name, "Confirm", "", "No", function() return true end)
    frame:SetWidth(440); frame:SetHeight(150); frame:SetFrameLevel(600)
    frame.edit:Hide(); frame.message:Hide()
    frame.label:SetWidth(404); frame.label:SetHeight(56); frame.label:SetJustifyH("LEFT")
    frame.no, frame.yes = frame.accept, frame.cancel
    frame.no:SetFrameLevel(601); frame.yes:SetFrameLevel(601)
    frame.yes:SetText("Yes")
    local blocker
    if not options or options.modal ~= false then
        blocker = UI.CreateControl(nil, UIParent)
        blocker:SetAllPoints(UIParent); blocker:SetFrameStrata("FULLSCREEN_DIALOG"); blocker:SetFrameLevel(599); blocker:EnableMouse(true); blocker:Hide()
    end
    frame.mosModalBlocker = blocker
    frame:SetScript("OnHide", function() if blocker then blocker:Hide() end; frame.onYes = nil; frame.onNo = nil end)
    frame.no:SetScript("OnClick", function() local callback = frame.onNo; frame:Hide(); if callback then callback() end end)
    frame.yes:SetScript("OnClick", function() local callback = frame.onYes; frame:Hide(); if callback then callback() end end)
    frame.close = UI.CreateWindowButton(frame, nil, "close")
    frame.close:SetFrameLevel(601)
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12); frame.close:SetScript("OnClick", function() frame:Hide() end)
    frame.Open = function(self, message, onYes, onNo)
        self.label:SetText(message); self.onYes = onYes; self.onNo = onNo
        if blocker then blocker:Show() end; self:Show()
    end
    if UI.WindowStack then UI.WindowStack.Register(frame, {dismiss = blocker}) end
    return frame
end

function UI.AttachTooltip(frame, title, description, highlight)
    local onEnter, onLeave = frame:GetScript("OnEnter"), frame:GetScript("OnLeave")
    frame:SetScript("OnEnter", function()
        if onEnter then onEnter() end
        if highlight then this:LockHighlight() end
        UI.AnchorTooltipRightOfCursor(this)
        GameTooltip:AddLine(type(title) == "function" and title() or title, 1, 0.82, 0)
        GameTooltip:AddLine(type(description) == "function" and description() or description, 1, 1, 1, 1)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() if onLeave then onLeave() end; if highlight then this:UnlockHighlight() end; GameTooltip:Hide() end)
    return frame
end

function UI.KeepTooltipAboveWindows(tooltip)
    if not tooltip or tooltip.mosLayerHook then return end
    tooltip.mosLayerHook = true
    local previous = tooltip:GetScript("OnShow")
    tooltip:SetScript("OnShow", function()
        if previous then previous() end
        tooltip:SetFrameStrata("TOOLTIP")
    end)
    tooltip:SetFrameStrata("TOOLTIP")
end

function UI.CreateItemListDialog(name)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(430); frame:SetHeight(350); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(230); frame:SetMovable(true); frame:SetResizable(true); frame:EnableMouse(true)
    frame:SetMinResize(320, 220); frame:SetMaxResize(700, 700); frame:RegisterForDrag("LeftButton")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetBackdropColor(0.025, 0.025, 0.022, 1)
    UI.RegisterDialogSurface(frame, "panel")
    frame:SetScript("OnDragStart", function() this:StartMoving() end); frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame.title = UI.CreateHeading(frame, "", 2, "orange", "list"); frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -16); frame.title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -16); frame.title:SetJustifyH("LEFT")
    frame.close = UI.CreateWindowButton(frame, nil, "close"); frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -10)
    frame.ok = UI.CreateButton(frame, nil, "OK", 74, 22); frame.ok:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
    frame.scroll = CreateFrame("ScrollFrame", name .. "Scroll", frame, "FauxScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44); frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -30, 48)
    frame.scroll.ownerDialog = frame
    UI.RegisterSkinnedScrollBar(getglobal(name.."ScrollScrollBar"))
    frame.rows = {}; frame.items = {}
    local index
    for index = 1, 28 do
        local row = UI.CreateControl(nil, frame); row:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -48 - ((index - 1) * 24)); row:SetPoint("RIGHT", frame, "RIGHT", -34, 0); row:SetHeight(22)
        row.context = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); row.context:SetPoint("LEFT", row, "LEFT", 1, 0); row.context:SetWidth(150); row.context:SetJustifyH("LEFT"); row.context:Hide()
        row.iconRegion = row:CreateTexture(nil, "ARTWORK"); row.iconRegion:SetPoint("LEFT", row, "LEFT", 1, 0); row.iconRegion:SetWidth(20); row.iconRegion:SetHeight(20)
        row.label = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); row.label:SetPoint("LEFT", row.iconRegion, "RIGHT", 7, 0); row.label:SetPoint("RIGHT", row, "RIGHT", -2, 0); row.label:SetJustifyH("LEFT")
        local highlight = row:CreateTexture(nil, "HIGHLIGHT"); highlight:SetAllPoints(row); highlight:SetTexture(1, 0.72, 0.12, 0.14)
        row:SetScript("OnEnter", function() UI.ShowItemTooltip(this) end); row:SetScript("OnLeave", function() GameTooltip:Hide() end); row:SetScript("OnClick", function() UI.HandleItemClick(this) end)
        row:Hide(); frame.rows[index] = row
    end
    UI.Window.StyleProjectDialog(frame)
    frame.title:SetPoint("RIGHT",frame.close,"LEFT",-8,0)
    UI.StyleActionButton(frame.ok);frame.ok:ClearAllPoints();frame.ok:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-24,8)
    frame.Refresh = function(self)
        if self.refreshing then return end
        self.refreshing=true
        local offset,visible,width=UI.Table.LayoutViewport(self.scroll,self,8,36,self:GetWidth()-16,self:GetHeight()-78,table.getn(self.items),24,table.getn(self.rows))
        local rowIndex
        for rowIndex = 1, table.getn(self.rows) do
            local row, item = self.rows[rowIndex], self.items[offset + rowIndex]
            if item and rowIndex <= visible then
                row:ClearAllPoints();row:SetPoint("TOPLEFT",self,"TOPLEFT",8,-36-(rowIndex-1)*24);row:SetWidth(width)
                UI.ApplyRowBackground(row,offset+rowIndex,false)
                row.context:SetWidth(math.floor(width*0.35));row.label:SetJustifyV("MIDDLE")
                row.itemId = item.itemId; row.itemName = item.name; row.itemCount = item.count; row.labelSuffix = (tonumber(item.count) or 1) > 1 and (" x " .. item.count) or ""
                row.context:SetText(item.context or "")
                if item.missing or not item.itemId then
                    row.itemId = nil; row.iconRegion:Hide(); row.label:SetText("-")
                else
                    row.iconRegion:Show(); row.label:SetText(UI.GetItemLabel(item.itemId) .. row.labelSuffix)
                    local texture = type(GetItemIcon) == "function" and GetItemIcon(item.itemId) or nil
                    if texture then row.iconRegion:SetTexture(texture) else row.iconRegion:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
                end
                row:Show()
            else row.itemId = nil; row.iconRegion:Hide(); row:Hide() end
        end
        self.refreshing=false
    end
    frame.scroll.refreshCallback = function() frame:Refresh() end
    frame.scroll:SetScript("OnVerticalScroll", function() FauxScrollFrame_OnVerticalScroll(24, this.refreshCallback) end)
    frame:SetScript("OnSizeChanged", function() this:Refresh() end)
    frame.grip = UI.CreateControl(nil, frame); frame.grip:SetWidth(12); frame.grip:SetHeight(12); frame.grip:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    frame.grip:SetScript("OnMouseDown", function() frame:StartSizing("BOTTOMRIGHT") end); frame.grip:SetScript("OnMouseUp", function() frame:StopMovingOrSizing(); frame:Refresh() end)
    frame.close:SetScript("OnClick", function() frame:Hide() end); frame.ok:SetScript("OnClick", function() frame:Hide() end)
    frame.Open = function(self, title, items)
        self.title:SetText(title or "Items"); self.items = items or {}; self.scroll.offset = 0; self.scroll:SetVerticalScroll(0)
        local showContext, itemIndex = false, nil
        for itemIndex = 1, table.getn(self.items) do if self.items[itemIndex].context then showContext = true; break end end
        for itemIndex = 1, table.getn(self.rows) do
            local row = self.rows[itemIndex]; row.iconRegion:ClearAllPoints()
            if showContext then row.context:Show(); row.iconRegion:SetPoint("LEFT", row.context, "RIGHT", 5, 0) else row.context:Hide(); row.iconRegion:SetPoint("LEFT", row, "LEFT", 1, 0) end
        end
        self:Refresh(); self:Show()
    end
    frame:Hide()
    if UI.WindowStack then UI.WindowStack.Register(frame) end
    return frame
end

function UI.RegisterEscapeDialog(frame)
    local name = frame and frame.GetName and frame:GetName()
    if not name or frame.mosEscapeRegistered then return end
    UISpecialFrames = UISpecialFrames or {}
    table.insert(UISpecialFrames, name)
    frame.mosEscapeRegistered = true
end

function UI.ShowOpaquePopup(dialogKey, textArg1, textArg2)
    local definition = StaticPopupDialogs and StaticPopupDialogs[dialogKey]
    if definition and definition.mosProjectTitle then
        local frame = definition.mosProjectFrame
        if not frame then
            frame = UI.Window.CreateProjectConfirmation(dialogKey .. "ProjectDialog", definition.mosProjectTitle, definition.button1)
            UI.StyleActionButton(frame.yes); UI.StyleActionButton(frame.no)
            frame.no:SetText(definition.button2 or "Cancel")
            frame.close:SetScript("OnClick", function()
                local callback=frame.onNo;frame:Hide();if callback then callback() end
            end)
            definition.mosProjectFrame = frame
            if definition.hideOnEscape then UI.RegisterEscapeDialog(frame) end
        end
        local message = definition.text
        frame.yes:SetText(definition.button1 or "OK")
        frame.no:SetText(definition.button2 or "Cancel")
        if textArg1 ~= nil then
            if textArg2 ~= nil then message = string.format(message, textArg1, textArg2)
            else message = string.format(message, textArg1) end
        end
        if UI.WindowStack and definition.mosProjectOwner then UI.WindowStack.SetOwner(frame, definition.mosProjectOwner) end
        frame:Open(message, definition.OnAccept, definition.OnCancel)
        return frame
    end
    -- Never skin Blizzard's shared popup pool (including death/release dialogs).
    return StaticPopup_Show(dialogKey, textArg1, textArg2)
end

function UI.HideOpaquePopup(dialogKey)
    local definition = StaticPopupDialogs and StaticPopupDialogs[dialogKey]
    if definition and definition.mosProjectFrame then definition.mosProjectFrame:Hide()
    elseif type(StaticPopup_Hide) == "function" then return StaticPopup_Hide(dialogKey) end
end

function UI.CreateTextEditor(name, titleText, maxLetters, onSave)
    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(430); frame:SetHeight(250); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(220); frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    frame:SetBackdropColor(0.025, 0.025, 0.022, 1)
    UI.RegisterDialogSurface(frame, "panel")
    frame:SetScript("OnDragStart", function() this:StartMoving() end); frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame.title = UI.CreateHeading(frame, "", 2, "orange", "import"); frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -14); frame.title:SetText(titleText)
    frame.scroll = CreateFrame("ScrollFrame", name .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42); frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 52)
    frame.scrollBar = getglobal(name .. "ScrollScrollBar")
    frame.scroll:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } }); frame.scroll:SetBackdropColor(0.02, 0.02, 0.02, 0.96)
    frame.edit = CreateFrame("EditBox", nil, frame.scroll)
    frame.edit:SetWidth(390); frame.edit:SetHeight(150); frame.scroll:SetScrollChild(frame.edit)
    frame.edit:SetMultiLine(true); frame.edit:SetAutoFocus(false); frame.edit:SetMaxLetters(maxLetters or 500); frame.edit:SetFontObject(GameFontHighlightSmall)
    frame.edit:SetTextInsets(6, 6, 6, 6)
    frame.measure = frame:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    frame.measure:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); frame.measure:SetAlpha(0)
    frame.counter = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall"); frame.counter:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 28)
    frame.save = UI.CreateButton(frame, nil, "Save", 72, 20); frame.save:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -92, 18)
    frame.cancel = UI.CreateButton(frame, nil, "Cancel", 72, 20); frame.cancel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 18)
    local function UpdateEditorGeometry()
        -- Resolve the existing anchored rectangle from its owner; child bounds
        -- may still reflect the previous size during first-open/text callbacks.
        local viewportWidth = math.max(40, frame:GetWidth() - 16 - 32 - 4)
        local viewportHeight = math.max(1, frame:GetHeight() - (frame.mosEditorTopInset or 42) - 52)
        frame.edit:SetWidth(viewportWidth)
        frame.measure:SetWidth(math.max(20, viewportWidth - 12)); frame.measure:SetText(frame.edit:GetText() or "")
        local textHeight = UI.MeasureTextHeight(frame.measure, math.max(20, viewportWidth - 12))
        frame.edit:SetHeight(math.max(viewportHeight, textHeight + 14))
    end
    frame.edit:SetScript("OnTextChanged", function() frame.counter:SetText(string.len(this:GetText() or "") .. " / " .. (maxLetters or 500)); UpdateEditorGeometry() end)
    frame.scroll:SetScript("OnSizeChanged", UpdateEditorGeometry)
    frame.save:SetScript("OnClick", function()
        local shouldClose = true
        if onSave and onSave(frame.edit:GetText() or "") == false then shouldClose = false end
        if shouldClose then frame:Hide() end
    end)
    frame.cancel:SetScript("OnClick", function() frame:Hide() end)
    frame.SetMessage = function(self, message, isError)
        self.counter:SetText(message or "")
        if isError then self.counter:SetTextColor(1, 0.25, 0.2) else self.counter:SetTextColor(0.3, 1, 0.45) end
    end
    frame.Open = function(self, value)
        self.edit:SetText(value or ""); self.counter:SetTextColor(0.6, 0.6, 0.6)
        self.counter:SetText(string.len(value or "") .. " / " .. (maxLetters or 500)); UpdateEditorGeometry(); self.scroll:SetVerticalScroll(0); self:Show(); self.edit:SetFocus()
    end
    frame.BringToFront = function(self, level)
        if UI.WindowStack then
            UI.WindowStack.Raise(self); UI.WindowStack.Sync(self)
            self.scroll:Show(); self.edit:EnableMouse(true); self.edit:EnableKeyboard(true); self.edit:Show()
            self.save:EnableMouse(true); self.save:Enable(); self.cancel:EnableMouse(true); self.cancel:Enable()
            return
        end
        local baseLevel = level or 220
        self:SetFrameStrata("FULLSCREEN_DIALOG"); self:SetFrameLevel(baseLevel)
        self.scroll:SetFrameStrata("FULLSCREEN_DIALOG"); self.scroll:SetFrameLevel(baseLevel + 1); self.scroll:Show()
        if self.scrollBar then self.scrollBar:SetFrameStrata("FULLSCREEN_DIALOG"); self.scrollBar:SetFrameLevel(baseLevel + 2) end
        self.edit:SetFrameStrata("FULLSCREEN_DIALOG"); self.edit:SetFrameLevel(baseLevel + 2); self.edit:EnableMouse(true); self.edit:EnableKeyboard(true); self.edit:Show()
        self.save:SetFrameStrata("FULLSCREEN_DIALOG"); self.save:SetFrameLevel(baseLevel + 3); self.save:EnableMouse(true); self.save:Enable()
        self.cancel:SetFrameStrata("FULLSCREEN_DIALOG"); self.cancel:SetFrameLevel(baseLevel + 3); self.cancel:EnableMouse(true); self.cancel:Enable()
    end
    frame:Hide()
    if UI.WindowStack then UI.WindowStack.Register(frame) end
    return frame
end

function UI.CreateReadOnlyDialog(name, titleText, width, height, backgroundColor)
    local dismiss = CreateFrame("Button", nil, UIParent)
    dismiss:SetAllPoints(UIParent); dismiss:SetFrameStrata("FULLSCREEN_DIALOG"); dismiss:SetFrameLevel(219); dismiss:Hide()

    local frame = CreateFrame("Frame", name, UIParent)
    frame:SetWidth(width or 520); frame:SetHeight(height or 320); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    frame:SetFrameStrata("FULLSCREEN_DIALOG"); frame:SetFrameLevel(220); frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 6, right = 6, top = 6, bottom = 6 } })
    local dialogBackground = backgroundColor or { 0.025, 0.025, 0.022 }
    frame:SetBackdropColor(dialogBackground[1], dialogBackground[2], dialogBackground[3], 1)
    UI.RegisterDialogSurface(frame, "warning", { dialogBackground[1], dialogBackground[2], dialogBackground[3], 1 })
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    frame.title = UI.CreateHeading(frame, "", 2, "orange", "info")
    frame.title:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -15); frame.title:SetText(titleText or "Details")

    frame.close = UI.CreateWindowButton(frame, nil, "close")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -5, -5)
    frame.ok = UI.CreateButton(frame, nil, "OK", 74, 22)
    frame.ok:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 18)

    frame.scroll = CreateFrame("ScrollFrame", name .. "Scroll", frame, "UIPanelScrollFrameTemplate")
    frame.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -42); frame.scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 52)
    frame.scrollBar = getglobal(name .. "ScrollScrollBar")
    frame.canvas = CreateFrame("Frame", nil, frame.scroll); frame.canvas:SetWidth((width or 520) - 64); frame.canvas:SetHeight(1)
    frame.scroll:SetScrollChild(frame.canvas)
    frame.text = frame.canvas:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    frame.text:SetPoint("TOPLEFT", frame.canvas, "TOPLEFT", 4, -4); frame.text:SetWidth((width or 520) - 72); frame.text:SetJustifyH("LEFT"); frame.text:SetJustifyV("TOP")

    local function CloseDialog() frame:Hide() end
    frame.dismiss = dismiss
    dismiss:SetScript("OnClick", nil); frame:EnableMouse(true); frame.close:SetScript("OnClick", CloseDialog); frame.ok:SetScript("OnClick", CloseDialog)
    frame:SetScript("OnShow", function() dismiss:Show() end)
    frame:SetScript("OnHide", function() dismiss:Hide() end)
    frame.Open = function(self, value)
        self.text:SetText(value or "")
        local contentHeight = UI.MeasureTextHeight(self.text, (width or 520) - 72) + 12
        self.canvas:SetHeight(math.max(self.scroll:GetHeight(), contentHeight))
        if self.scrollBar then if contentHeight > self.scroll:GetHeight() then self.scrollBar:Show() else self.scrollBar:Hide() end end
        self.scroll:SetVerticalScroll(0)
        self:Show()
    end
    frame:Hide()
    if UI.WindowStack then UI.WindowStack.Register(frame, {dismiss = dismiss}) end
    return frame
end

function UI.AttachLabelTooltip(parent, label, title, description)
    local hit = UI.CreateControl(nil, parent)
    hit:SetAllPoints(label)
    UI.AttachTooltip(hit, title, description)
    return hit
end

function UI.CreateTextArea(parent, width, height, maxLetters)
    local field = UI.CreateFramedEditBox(parent, nil, width)
    field:SetHeight(height); field:SetMultiLine(true); field:SetMaxLetters(maxLetters or 255)
    field:SetScript("OnEnterPressed", nil)
    return field
end

function UI.CreateArrowButton(parent, direction)
    local icon = direction == "up" and "Interface\\Buttons\\UI-ScrollBar-ScrollUpButton-Up" or "Interface\\Buttons\\UI-ScrollBar-ScrollDownButton-Up"
    local button = UI.CreateIconButton(parent, nil, icon, 20)
    return button
end

function UI.CreateContextMenu(parent, specs, onAction)
    local menu = UI.CreateDropdownPanel(parent, parent, 138, 28 + table.getn(specs) * 18, 50)
    menu:SetFrameStrata("FULLSCREEN_DIALOG"); menu.dismiss:SetFrameStrata("FULLSCREEN_DIALOG")
    menu.dismiss:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    menu:SetClampedToScreen(true); menu.buttons = {}
    menu.title = UI.CreateComponentLabel(menu, "", "gold")
    menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 12, -8)
    local index
    for index = 1, table.getn(specs) do
        local spec = specs[index]
        local button = UI.CreateMenuItem(menu, spec[1], 126, 18)
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 6, -24 - (index - 1) * 18)
        button.action = spec[2]
        button:SetScript("OnClick", function() local action = this.action; menu:Hide(); onAction(action) end)
        menu.buttons[index] = button
    end
    function menu:Open(anchor)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        self:ClearAllPoints(); self:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale + 10, y / scale); self:Show()
    end
    return menu
end

function UI.CreateMenuItem(parent, text, width, height)
    local button = UI.CreateControl(nil, parent)
    button:SetWidth(width); button:SetHeight(height)
    button.label = UI.CreateColumnLabel(button, text, "white")
    button.label:SetPoint("LEFT", button, "LEFT", 6, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    button.label:SetJustifyH("LEFT")
    local hover = UI.CreateTexture(button, nil, "HIGHLIGHT")
    hover:SetAllPoints(button); hover:SetTexture(1, 0.82, 0.28, 0.12)
    return button
end

function UI.CreateNoteDisplay(parent, height)
    local button = UI.CreateControl(nil, parent)
    button:SetHeight(height or 76)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    button:SetBackdropColor(0.025, 0.025, 0.022, 1); button:SetBackdropBorderColor(0.45, 0.40, 0.28, 1)
    button.label = UI.CreateComponentLabel(button, "", "white")
    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", 10, -10)
    button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -10, 10)
    button.label:SetJustifyH("LEFT"); button.label:SetJustifyV("TOP")
    button.SetText = function(self, value) self.label:SetText(value) end
    button.GetText = function(self) return self.label:GetText() end
    return button
end

function UI.BindCheckboxLabel(checkbox, onChanged, width)
    checkbox.onLabelChanged = onChanged
    checkbox:SetScript("OnClick", function() this.onLabelChanged(this) end)
    if not checkbox.labelHit then
        local hit = UI.CreateControl(nil, checkbox)
        hit:SetPoint("LEFT", checkbox, "RIGHT", 0, 0)
        hit:SetHeight(checkbox:GetHeight())
        hit.owner = checkbox
        hit:SetScript("OnClick", function()
            local owner = this.owner
            owner:SetChecked(not owner:GetChecked())
            owner.onLabelChanged(owner)
        end)
        checkbox.labelHit = hit
    end
    checkbox.labelHit:SetWidth(width or math.max(20, checkbox.label:GetStringWidth() + 4))
    return checkbox
end

local function SetOpenBorderColor(self, r, g, b, a)
    local index
    for index = 1, 8 do self.pieces[index]:SetVertexColor(r, g, b, a or 1) end
end

function UI.SetOpenButtonBorder(button, visible, openEdge)
    local border = button.openBorder
    if not visible then if border then border:Hide() end; return end
    if not border then
        border = UI.CreateContainer(nil, button); border:EnableMouse(false); border:SetAllPoints(button)
        border.pieces = {}; border.border = border
        border.SetBackdropBorderColor = SetOpenBorderColor
        local index
        for index = 1, 8 do
            local texture = border:CreateTexture(nil, "OVERLAY")
            texture:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
            local left, right = (index - 1) / 8 + 1 / 128, index / 8 - 1 / 128
            if index == 3 or index == 4 then texture:SetTexCoord(left, 15/16, right, 15/16, left, 1/16, right, 1/16)
            else texture:SetTexCoord(left, right, 1/16, 15/16) end
            border.pieces[index] = texture
        end
        local corners = { "TOPLEFT", "TOPRIGHT", "BOTTOMLEFT", "BOTTOMRIGHT" }
        for index = 5, 8 do
            local texture = border.pieces[index]
            texture:SetWidth(8); texture:SetHeight(8); texture:SetPoint(corners[index-4], border, corners[index-4], 0, 0)
        end
        border.pieces[3]:SetHeight(8); border.pieces[3]:SetPoint("TOPLEFT", border, "TOPLEFT", 8, 0); border.pieces[3]:SetPoint("TOPRIGHT", border, "TOPRIGHT", -8, 0)
        border.pieces[4]:SetHeight(8); border.pieces[4]:SetPoint("BOTTOMLEFT", border, "BOTTOMLEFT", 8, 0); border.pieces[4]:SetPoint("BOTTOMRIGHT", border, "BOTTOMRIGHT", -8, 0)
        border:SetBackdropBorderColor(1, 0.78, 0.2, 1); button.openBorder = border
    end
    border:SetFrameStrata(button:GetFrameStrata()); border:SetFrameLevel(button:GetFrameLevel() + 1)
    local index
    for index = 1, 8 do border.pieces[index]:Show() end
    if openEdge == "top" then border.pieces[3]:Hide(); border.pieces[5]:Hide(); border.pieces[6]:Hide()
    elseif openEdge == "bottom" then border.pieces[4]:Hide(); border.pieces[7]:Hide(); border.pieces[8]:Hide() end
    for index = 1, 2 do
        local side = index == 1 and "LEFT" or "RIGHT"
        local texture = border.pieces[index]; texture:ClearAllPoints(); texture:SetWidth(8)
        texture:SetPoint("TOP"..side, border, "TOP"..side, 0, openEdge == "top" and 0 or -8)
        texture:SetPoint("BOTTOM"..side, border, "BOTTOM"..side, 0, openEdge == "bottom" and 0 or 8)
    end
    border.mosOpenEdge = openEdge; border:Show()
end

function UI.ApplyButtonCaptionBaseline(button)
    local bottom = tonumber(button.mosCaptionBottomInset)
    local label = button.label
    if not bottom or not label then return end
    local left = button.mosLabelInsets and button.mosLabelInsets[1]
        or (button.mosClassicIconKey and ((button.mosClassicIconInset or 7) + (button.mosClassicIconSize or 13) + 4) or 0)
    local right = button.mosLabelInsets and button.mosLabelInsets[2] or 4
    label:ClearAllPoints(); label:SetPoint("TOPLEFT", button, "TOPLEFT", left, 0)
    label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -right, 0)
    label:SetHeight(button:GetHeight()); label:SetJustifyV("MIDDLE")
    label:SetJustifyH(button.mosLabelJustify or (button.mosClassicIconKey and "LEFT" or "CENTER"))
end

function UI.FitButtonLabel(button, available)
    local label = button.label or button
    if not label or not label.GetFont then return end
    local font, size, flags = label:GetFont()
    button.mosFitFontSize = button.mosFitFontSize or size
    label:SetFont(font, button.mosFitFontSize, flags); label:SetWidth(0)
    label:SetHeight(button.mosFitFontSize + 3)
    if button.mosActionIcon then available=math.max(1,available-18-(button.mosActionTrailing or 0)) end
    -- Native metrics can differ from the rendered line by a pixel. Reserve a
    -- small allowance and keep the caption's remaining space, not a tight box
    -- around its measured ink: a one-line box otherwise renders an ellipsis.
    local width = math.max(1, math.ceil(label:GetStringWidth()))
    local fitted = math.max(1, button.mosFitFontSize * math.min(1, math.max(1, available-2-(label.mosHeadingIconInset or 0)) / width))
    label:SetFont(font, fitted, flags); label:SetWidth(math.max(1, available)); label:SetHeight(fitted + 3); label:SetJustifyH(button.mosLabelJustify or (button.label and "CENTER" or "LEFT"))
    if button.mosActionIcon then
        local textWidth=math.min(math.max(1,available),width*fitted/button.mosFitFontSize+2)
        local start=button.mosActionAlign=="LEFT" and 8 or math.max(8,(button:GetWidth()-(button.mosActionTrailing or 0)-18-textWidth)/2)
        button.mosActionIcon:ClearAllPoints();button.mosActionIcon:SetPoint("LEFT",button,"LEFT",start,0)
        label:ClearAllPoints();label:SetPoint("LEFT",button,"LEFT",start+18,0)
        label:SetWidth(math.max(1,button:GetWidth()-start-26-(button.mosActionTrailing or 0)))
        label:SetHeight(math.max(fitted+3,button:GetHeight()-4));label:SetJustifyH("LEFT");label:SetJustifyV("MIDDLE")
    end
    UI.ApplyButtonCaptionBaseline(button)
end

-- Shared action icons use the authored gold atlas in either visual skin.
function UI.SetActionButtonIcon(button,key,trailing)
    if not button.mosActionIcon then button.mosActionIcon=UI.CreateTexture(button,nil,"OVERLAY") end
    button.mosActionIcon:SetTexture("Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\Icons\\"..key..".tga")
    button.mosActionIcon:SetWidth(14);button.mosActionIcon:SetHeight(14)
    button.mosActionIcon:SetVertexColor(unpack(UI.Theme.colors.goldIcon));button.mosActionIcon:Show()
    button.mosActionIconKey=key;button.mosActionTrailing=trailing or 0
    UI.FitButtonLabel(button,math.max(1,button:GetWidth()-16))
    if not button.mosActionIconSkinCallback then
        button.mosActionIconSkinCallback=true
        UI.RegisterSkinCallback(function() UI.FitButtonLabel(button,math.max(1,button:GetWidth()-16)) end)
    end
end

function UI.CreateAspectImage(parent,path,aspect,alpha,uvBottom)
    local image=UI.CreateTexture(parent,nil,"BACKGROUND")
    image:SetTexture(path);image:SetTexCoord(0,1,0,uvBottom or 1);image:SetAlpha(alpha or 1)
    image.mosImageAspect=aspect
    return image
end

function UI.LayoutAspectImage(image,parent,width,height)
    local resolvedWidth=math.min(math.max(1,width),math.max(1,height)*image.mosImageAspect)
    image:ClearAllPoints();image:SetPoint("CENTER",parent,"CENTER",0,0)
    image:SetWidth(resolvedWidth);image:SetHeight(resolvedWidth/image.mosImageAspect)
end

function UI.CreatePerformanceBackground(parent,alpha)
    return UI.CreateAspectImage(parent,"Interface\\AddOns\\BootyLib\\Textures\\PerformanceBackground",1024/572,alpha or 0.28,0.55859375)
end

function UI.LayoutPerformanceBackground(image,parent,width,height)
    width,height=math.max(1,width),math.max(1,height)
    local aspect=image.mosImageAspect
    local shownWidth,shownHeight=math.min(1,width/(height*aspect)),math.min(1,height*aspect/width)
    local bottom=0.55859375
    image:ClearAllPoints();image:SetPoint("CENTER",parent,"CENTER",0,0)
    image:SetWidth(width);image:SetHeight(height)
    image:SetTexCoord((1-shownWidth)/2,(1+shownWidth)/2,(1-shownHeight)*bottom/2,(1+shownHeight)*bottom/2)
end

function UI.ApplyGoldRadialHighlight(texture)
    texture:SetTexture("Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\Buttons\\red-hover-radial.tga")
    texture:SetVertexColor(1, 0.8742857, 0.17, 0.42)
end

-- Resolve content width and overflow together, always starting without a gutter.
-- A second measurement is only needed if full-width content really overflows.
function UI.ResolveScrollLayout(fullWidth, viewportHeight, gutter, measure, context)
    fullWidth = math.max(1, fullWidth)
    viewportHeight = math.max(1, viewportHeight)
    local contentHeight = math.max(1, measure(fullWidth, context))
    local overflow = contentHeight > viewportHeight + 0.5
    local width = fullWidth
    if overflow then
        width = math.max(1, fullWidth - gutter)
        contentHeight = math.max(1, measure(width, context))
    end
    return width, contentHeight, overflow, math.max(0, contentHeight - viewportHeight)
end

function UI.GetFrameSpan(frame)
    local left = frame.GetLeft and frame:GetLeft()
    local right = frame.GetRight and frame:GetRight()
    local bottom = frame.GetBottom and frame:GetBottom()
    local top = frame.GetTop and frame:GetTop()
    return left and right and right - left or frame:GetWidth(), bottom and top and top - bottom or frame:GetHeight()
end

function UI.ApplyScrollRange(viewport, slider, maximum)
    local value = math.max(0, math.min(maximum, viewport:GetVerticalScroll()))
    viewport:SetVerticalScroll(value)
    if slider then
        slider:SetMinMaxValues(0, maximum); slider:SetValue(value)
        UI.SetScrollBarVisible(slider, maximum > 0.5)
    end
end

-- Only visible, unacknowledged controls run this animation; no data refreshes.
local function RestoreAttentionText(button)
    if button.label and button.mosAttentionTextColor then button.label:SetTextColor(unpack(button.mosAttentionTextColor)) end
end
local function AttentionPulseTick()
    this.mosAttentionElapsed = math.mod((this.mosAttentionElapsed or 0) + (arg1 or 0), 1)
    if this.mosAttentionElapsed < 0.5 then
        this.mosAttentionTexture:Show()
        if this.label then this.label:SetTextColor(1, 0.48, 0.42, 1) end
    else this.mosAttentionTexture:Hide(); RestoreAttentionText(this) end
end
local function AttentionPulseHide()
    this:SetScript("OnUpdate", nil)
    if this.mosAttentionTexture then this.mosAttentionTexture:Hide() end
    RestoreAttentionText(this)
end
local function AttentionPulseShow()
    if this.mosAttentionPending then this:SetScript("OnUpdate", AttentionPulseTick) end
end
function UI.SetAttentionPulse(button, pending)
    if not button.mosAttentionTexture then
        local texture = button:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints(button); UI.ApplyGoldRadialHighlight(texture); texture:Hide()
        button.mosAttentionTexture = texture
        button:SetScript("OnHide", AttentionPulseHide); button:SetScript("OnShow", AttentionPulseShow)
    end
    if pending and not button.mosAttentionPending then
        button.mosAttentionElapsed = 0
        if button.label then button.mosAttentionTextColor = {button.label:GetTextColor()} end
    end
    button.mosAttentionPending = pending and true or false
    if pending and button:IsVisible() then button:SetScript("OnUpdate", AttentionPulseTick)
    else button:SetScript("OnUpdate", nil); button.mosAttentionTexture:Hide(); RestoreAttentionText(button) end
end

-- Shared authored gear, including its asymmetric transparent-padding crop.
function UI.CreateSettingsButton(parent)
    local button = UI.CreateButton(parent, nil, "", 18, 18)
    UI.SetClassicButtonCompact(button, true)
    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetWidth(13); button.icon:SetHeight(13)
    button.icon:SetTexCoord(8 / 64, 47 / 64, 11 / 64, 50 / 64)
    button.icon:SetTexture("Interface\\AddOns\\BootyLib\\Assets\\SettingsGear")
    UI.AttachGoldHoverBorder(button, 0.35, 0.35, 0.35, 1)
    return button
end

function UI.CreateGoldToolbarButton(parent, iconKey)
    local button = UI.CreateButton(parent, nil, "", 18, 18)
    UI.SetClassicButtonCompact(button, true)
    button.icon = button:CreateTexture(nil, "OVERLAY")
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetWidth(13); button.icon:SetHeight(13)
    button.icon:SetTexture("Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\Icons\\" .. iconKey .. ".tga")
    button.icon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
    UI.AttachGoldHoverBorder(button, 0.35, 0.35, 0.35, 1)
    return button
end

-- A left-only accordion accent still uses the authored project border atlas.
-- Full interactive row outlines use SetProjectButtonOutline.
function UI.CreateProjectLeftAccent(row)
    local accent = UI.CreateTexture(row, nil, "BORDER")
    accent:SetTexture("Interface\\Tooltips\\UI-Tooltip-Border")
    accent:SetTexCoord(1 / 128, 15 / 128, 1 / 16, 15 / 16)
    accent:SetVertexColor(1, 0.78, 0.2, 1)
    accent:SetWidth(2); accent:Hide()
    return accent
end

function UI.CreateClassIcon(parent, size)
    local icon=UI.CreateTexture(parent,nil,"ARTWORK");icon:SetWidth(size or 16);icon:SetHeight(size or 16);icon:Hide();return icon
end

function UI.SetChevronButtonIcon(button,direction,size)
    if not button.chevronIcon then button.chevronIcon=UI.CreateTexture(button,nil,"ARTWORK") end
    button.chevronIcon:ClearAllPoints();button.chevronIcon:SetPoint("CENTER",button,"CENTER",0,0);button.chevronIcon:SetWidth(size or 13);button.chevronIcon:SetHeight(size or 13)
    button.chevronIcon:SetTexture("Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\Icons\\chevron_"..(direction=="right" and "right" or "left")..".tga");button.chevronIcon:Show()
    button.chevronIcon:SetVertexColor(unpack(UI.Theme.colors.goldText))
    if button.SetText then button:SetText("") end
end

function UI.AttachPlaceholder(field, text)
    local label = field.placeholder or UI.CreateLabel(field, nil, "OVERLAY", "GameFontDisableSmall")
    if not field.placeholder then label:SetPoint("LEFT", field, "LEFT", 6, 0) end
    label:SetText(text)
    field.placeholder = label
    local function Refresh()
        if field.mosHasFocus or (field:GetText() or "") ~= "" then label:Hide() else label:Show() end
    end
    local changed, gained, lost = field:GetScript("OnTextChanged"), field:GetScript("OnEditFocusGained"), field:GetScript("OnEditFocusLost")
    field:SetScript("OnTextChanged", function() if changed then changed() end; Refresh() end)
    field:SetScript("OnEditFocusGained", function() field.mosHasFocus=true; if gained then gained() end; Refresh() end)
    field:SetScript("OnEditFocusLost", function() field.mosHasFocus=false; if lost then lost() end; Refresh() end)
    Refresh()
end

-- Border and clipping viewport are separate; gutter is reserved only on overflow.
local textAreaSerial = 0
function UI.MakeTextAreaScrollable(field, parent)
    textAreaSerial = textAreaSerial + 1
    local area = UI.CreateContainer(nil, parent)
    area:SetBackdrop(field:GetBackdrop()); area:SetBackdropColor(0.018, 0.018, 0.016, 1)
    area:SetBackdropBorderColor(0.48, 0.34, 0.10, 1)
    local scroll = CreateFrame("ScrollFrame", "MOSScrollTextArea" .. textAreaSerial, area, "UIPanelScrollFrameTemplate")
    local bar = getglobal(scroll:GetName() .. "ScrollBar")
    field:SetBackdrop(nil); field:SetParent(scroll); field:ClearAllPoints(); scroll:SetScrollChild(field)
    field:SetTextInsets(2, 2, 2, 2)
    local measure = area:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    measure:SetAlpha(0)
    local function Measure(width)
        local font, size, flags = field:GetFont(); measure:SetFont(font, size, flags)
        measure:SetWidth(math.max(1, width - 4)); measure:SetText(field:GetText() or "")
        return UI.MeasureTextHeight(measure, math.max(1, width - 4)) + 8
    end
    local function Layout()
        local height = math.max(1, area:GetHeight() - 12)
        local width, contentHeight, overflow, maximum = UI.ResolveScrollLayout(math.max(1, area:GetWidth() - 12), height, 20, Measure)
        scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", area, "TOPLEFT", 6, -6)
        scroll:SetWidth(width); scroll:SetHeight(height)
        field:SetWidth(width); field:SetHeight(math.max(height, contentHeight))
        if bar then
            bar:ClearAllPoints(); bar:SetPoint("TOPRIGHT", area, "TOPRIGHT", -6, -22)
            bar:SetPoint("BOTTOMRIGHT", area, "BOTTOMRIGHT", -6, 22)
        end
        UI.ApplyScrollRange(scroll, bar, maximum)
    end
    local changed = field:GetScript("OnTextChanged")
    field:SetScript("OnTextChanged", function() if changed then changed() end; Layout() end)
    field:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    field:SetScript("OnCursorChanged", function()
        local top = scroll:GetVerticalScroll() or 0
        local cursor = -(arg2 or 0)
        if cursor < top then scroll:SetVerticalScroll(math.max(0, cursor))
        elseif cursor + (arg4 or 14) > top + scroll:GetHeight() then scroll:SetVerticalScroll(math.max(0, cursor + (arg4 or 14) - scroll:GetHeight())) end
    end)
    area:SetScript("OnSizeChanged", Layout)
    field.scrollMeasure = measure
    field.area, field.viewport, field.scrollBar, field.LayoutScroll = area, scroll, bar, Layout
    return area
end

-- Flow atomic controls left to right; wrapped rows release space immediately.
function UI.LayoutFlow(parent, controls, x, top, width, gap)
    local used, rowHeight, y = 0, 0, top
    gap = gap or 8
    for index=1,table.getn(controls) do
        local control=controls[index]
        local desired=math.min(width,control.mosFlowWidth or control:GetWidth())
        if used > 0 and used + desired > width then y=y+rowHeight+gap; used=0; rowHeight=0 end
        control:ClearAllPoints(); control:SetPoint("TOPLEFT",parent,"TOPLEFT",x+used,-y)
        control:SetWidth(math.max(1,desired)); rowHeight=math.max(rowHeight,control:GetHeight())
        if control.mosFlowFitLabel then UI.FitButtonLabel(control,math.max(1,desired-(control.mosFlowLabelPadding or 16)));control.label:SetJustifyV("MIDDLE") end
        if control.mosControlFont then UI.ReflowControlText(control) end
        used=used+desired+gap
    end
    return y+rowHeight
end
function UI.CreateToolbarSurface(parent, topBorder, bottomBorder)
    local toolbar = UI.CreateContainer(nil, parent)
    local backdrop={ bgFile = "Interface\\Buttons\\WHITE8X8" }
    toolbar:SetBackdrop(backdrop)
    toolbar:SetBackdropColor(0.025, 0.022, 0.016, 0.72)
    UI.RegisterSkinnedSurface(toolbar, "content",backdrop,{0.025,0.022,0.016,0.72},{0,0,0,0})
    UI.SetSurfaceHorizontalBorders(toolbar, topBorder, bottomBorder)
    return toolbar
end
function UI.AddToolbarBackground(toolbar, alpha)
    if not toolbar.mosToolbarBackground then
        toolbar.mosToolbarBackground=UI.CreateTexture(toolbar,nil,"BACKGROUND")
        toolbar.mosToolbarBackground:SetAllPoints(toolbar)
        toolbar.mosToolbarBackground:SetTexture("Interface\\Buttons\\WHITE8X8")
        toolbar.mosToolbarBackground:SetVertexColor(0.11,0.09,0.055,1)
    end
    toolbar.mosToolbarBackground:SetAlpha(alpha or 0.45);toolbar.mosToolbarBackground:Show()
    return toolbar.mosToolbarBackground
end
function UI.StyleActionButton(button)
    button.mosClassicKeepNormalSurface=true;button.mosFlowFitLabel=true
    UI.ApplyDropdownChoiceSurface(button); UI.AttachGoldHoverBorder(button,0.35,0.35,0.35,1)
    UI.SizeClassicButton(button,button:GetWidth(),26,1)
end
function UI.StyleProjectPopup(panel)
    if not UI.Window then panel.mosProjectPopupPending=true; return end
    if panel.mosProjectPopupStyled then UI.Window.ApplyProjectSurface(panel); return end
    panel.mosProjectPopupStyled=true
    UI.Window.ApplyProjectSurface(panel)
    UI.RegisterDialogSurface(panel,"panel",{0.015,0.015,0.015,1})
    UI.RegisterSkinCallback(function() UI.Window.ApplyProjectSurface(panel) end)
end

-- Only unusually short/narrow pages scroll as a whole. Normal layouts retain
-- the full host width and their independent table scroll positions.
function UI.CreateResponsiveCanvas(host, name)
    local viewport = UI.CreateScrollFrame(name, host, "UIPanelScrollFrameTemplate")
    local canvas = UI.CreateContainer(nil, viewport)
    viewport:SetScrollChild(canvas)
    canvas.layoutHost, canvas.layoutViewport = host, viewport
    UI.RegisterSkinnedScrollBar(getglobal(name .. "ScrollBar"))
    return canvas
end

function UI.LayoutResponsiveCanvas(canvas, measure, context, resolvedWidth, resolvedHeight)
    local width, height
    if resolvedWidth and resolvedHeight then width,height=resolvedWidth,resolvedHeight
    else width,height=UI.GetFrameSpan(canvas.layoutHost) end
    canvas.layoutHeight = height
    local function Measure(available)
        canvas:SetWidth(available)
        return math.max(height, measure(available, height, context))
    end
    local contentWidth, contentHeight, _, maximum = UI.ResolveScrollLayout(width, height, 20, Measure)
    local viewport = canvas.layoutViewport
    viewport:ClearAllPoints(); viewport:SetPoint("TOPLEFT", canvas.layoutHost, "TOPLEFT", 0, 0)
    viewport:SetWidth(contentWidth); viewport:SetHeight(height)
    canvas:SetWidth(contentWidth); canvas:SetHeight(contentHeight)
    local bar = getglobal(viewport:GetName() .. "ScrollBar")
    if bar then
        bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", canvas.layoutHost, "TOPLEFT", contentWidth + 4, -16)
        bar:SetWidth(16); bar:SetHeight(math.max(1, height - 32))
    end
    UI.ApplyScrollRange(viewport, bar, maximum)
end
