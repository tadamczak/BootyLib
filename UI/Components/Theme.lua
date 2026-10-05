local MOS = BootyLib
local UI = MOS.UI.Components

UI.Theme = {
    classColors = {
        WARRIOR = { r = 0.78, g = 0.61, b = 0.43 },
        MAGE = { r = 0.41, g = 0.80, b = 0.94 },
        ROGUE = { r = 1, g = 0.96, b = 0.41 },
        DRUID = { r = 1, g = 0.49, b = 0.04 },
        HUNTER = { r = 0.67, g = 0.83, b = 0.45 },
        SHAMAN = { r = 0, g = 0.44, b = 0.87 },
        PRIEST = { r = 1, g = 1, b = 1 },
        WARLOCK = { r = 0.58, g = 0.51, b = 0.79 },
        PALADIN = { r = 0.96, g = 0.55, b = 0.73 },
    },
    colors = {
        goldText = { 0.82, 0.70, 0.43 },
        goldIcon = { 0.82, 0.70, 0.43 },
        activeGoldIcon = { 1, 0.82, 0.28 },
        button = { 0.08, 0.07, 0.05, 0.96 },
        buttonBorder = { 0.48, 0.38, 0.20, 1 },
        highlight = { 1, 0.72, 0.12, 0.10 },
        rowAlternate = { 1, 0.78, 0.25, 0.075 },
        rowSelected = { 0.16, 0.20, 0.17, 0.82 },
        rowSelectedBorder = { 0.46, 0.55, 0.47, 0.90 },
    },
    sizes = {
        buttonHeight = 22,
        rowHeight = 20,
        contentMargin = 3,
    },
}

function UI.StyleButton(button, text)
    UI.InstallControlInput(button)
    local colors = UI.Theme.colors
    local backdrop = {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 9,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    }
    button:SetBackdrop(backdrop)
    button:SetBackdropColor(colors.button[1], colors.button[2], colors.button[3], colors.button[4])
    button:SetBackdropBorderColor(colors.buttonBorder[1], colors.buttonBorder[2], colors.buttonBorder[3], colors.buttonBorder[4])
    if not button.label then
        button.label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        button.label:SetAllPoints(button)
    end
    button.label:SetText(text or "")
    button.SetText = function(self, value) self.label:SetText(value) end
    button.GetText = function(self) return self.label:GetText() end
    if not button.mosHighlight then
        button.mosHighlight = button:CreateTexture(nil, "HIGHLIGHT")
        button.mosHighlight:SetAllPoints(button)
        button.mosHighlight:SetTexture(colors.highlight[1], colors.highlight[2], colors.highlight[3], colors.highlight[4])
    end
    UI.RegisterSkinnedControl(button, backdrop, { colors.button[1], colors.button[2], colors.button[3], colors.button[4] }, { colors.buttonBorder[1], colors.buttonBorder[2], colors.buttonBorder[3], colors.buttonBorder[4] }, { colors.highlight[1], colors.highlight[2], colors.highlight[3], colors.highlight[4] })
    return button
end

function UI.CreateButton(parent, name, text, width, height)
    local button = CreateFrame("Button", name, parent)
    button:SetWidth(width or 120)
    button:SetHeight(height or UI.Theme.sizes.buttonHeight)
    return UI.StyleButton(button, text)
end

function UI.CreateSelectionButton(parent, name, text, width, height)
    local button = CreateFrame("Button", name, parent)
    button.mosClassicKeepNormalSurface = true
    button:SetWidth(width or 120); button:SetHeight(height or UI.Theme.sizes.buttonHeight)
    UI.StyleButton(button, text)
    UI.AttachGoldHoverBorder(button, 0.35, 0.35, 0.35, 1)
    return button
end

function UI.SetButtonLabelInsets(button, left, right)
    button.mosLabelInsets = { left, right }
    button.label:ClearAllPoints()
    button.label:SetPoint("LEFT", button, "LEFT", left, 0)
    button.label:SetPoint("RIGHT", button, "RIGHT", -right, 0)
    button.label:SetJustifyH("LEFT")
    if UI.ApplyButtonCaptionBaseline then UI.ApplyButtonCaptionBaseline(button) end
end

UI.TextColors = {
    white = { 1, 1, 1 }, gold = UI.Theme.colors.goldText,
    orange = { 1, 0.82, 0 }, gray = { 0.48, 0.48, 0.46 },
}
UI.HeadingSizes = { 18, 16, 14 }

function UI.GetTextSizeDelta(parent)
    while parent do
        if parent.mosTextSizeDelta then return parent.mosTextSizeDelta end
        parent = parent.GetParent and parent:GetParent()
    end
    return 0
end

function UI.ApplyTextSizeDelta(label, parent)
    local delta = UI.GetTextSizeDelta(parent)
    if delta == 0 then return end
    local font, size, flags = label:GetFont()
    if font and size then label:SetFont(font, math.max(1, size + delta), flags) end
end

local function CreateTextPreset(parent, text, template, color, size)
    local label = UI.CreateLabel(parent, nil, "OVERLAY", template)
    if size then
        local font, _, flags = label:GetFont()
        label:SetFont(font, size, flags)
    end
    UI.ApplyTextSizeDelta(label, parent)
    label:SetTextColor(unpack(UI.TextColors[color or "white"] or UI.TextColors.white))
    label:SetText(text or "")
    return label
end

-- Keep a native FontString contract while reserving a stable icon gutter.
-- Callers provide semantic icon keys; the reusable control owns no page rules.
function UI.SetHeadingIcon(label, key)
    if not label.mosHeadingIcon then
        local anchors = {}
        if label.GetPoint then
            for index = 1, label.GetNumPoints and label:GetNumPoints() or 1 do
                local anchor, relative, relativeAnchor, x, y = label:GetPoint(index)
                if anchor then table.insert(anchors, {anchor, relative, relativeAnchor, x, y}) end
            end
        end
        local icon = UI.CreateTexture(label:GetParent(), nil, "OVERLAY")
        local _, size = label:GetFont()
        local iconSize = math.max(10, math.min(20, size or 14))
        label.mosHeadingIcon, label.mosHeadingIconInset = icon, iconSize + 6
        icon:SetWidth(iconSize); icon:SetHeight(iconSize)
        icon:SetPoint("RIGHT", label, "LEFT", -6, 0)
        local point, width, show, hide, text, font = label.SetPoint, label.SetWidth, label.Show, label.Hide, label.SetText, label.SetFont
        label.SetPoint = function(self, anchor, relative, relativeAnchor, x, y)
            local inset = string.find(anchor, "LEFT", 1, true) and self.mosHeadingIconInset or anchor == "CENTER" and self.mosHeadingIconInset / 2 or 0
            if type(relative) == "number" then return point(self, anchor, relative + inset, relativeAnchor) end
            if type(relativeAnchor) == "number" then return point(self, anchor, relative, relativeAnchor + inset, x) end
            return point(self, anchor, relative, relativeAnchor, (x or 0) + inset, y or 0)
        end
        label.SetWidth = function(self, value)
            return width(self, value > 0 and math.max(1, value - self.mosHeadingIconInset) or value)
        end
        label.Show = function(self)
            show(self)
            if self:GetText() and self:GetText() ~= "" then self.mosHeadingIcon:Show() end
        end
        label.Hide = function(self) hide(self); self.mosHeadingIcon:Hide() end
        label.SetText = function(self, value)
            text(self, value)
            if value and value ~= "" and self:IsShown() then self.mosHeadingIcon:Show() else self.mosHeadingIcon:Hide() end
        end
        label.SetFont = function(self, path, value, flags)
            local result = font(self, path, value, flags)
            local fitted = math.max(10, math.min(20, value or 14))
            self.mosHeadingIcon:SetWidth(fitted); self.mosHeadingIcon:SetHeight(fitted)
            return result
        end
        if table.getn(anchors) > 0 then
            label:ClearAllPoints()
            for _,anchor in ipairs(anchors) do label:SetPoint(unpack(anchor)) end
        end
        label:SetJustifyH("LEFT")
    end
    label.mosHeadingIconKey = key
    label.mosHeadingIcon:SetTexture("Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\Icons\\" .. key .. ".tga")
    label.mosHeadingIcon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
    if label:GetText() and label:GetText() ~= "" and label:IsShown() then label.mosHeadingIcon:Show() else label.mosHeadingIcon:Hide() end
    return label
end

function UI.CreateHeading(parent, text, level, color, iconKey)
    local label = CreateTextPreset(parent, text, "GameFontNormalLarge", color or "orange", UI.HeadingSizes[level or 1] or UI.HeadingSizes[1])
    if iconKey then UI.SetHeadingIcon(label, iconKey) end
    return label
end

function UI.CreateComponentLabel(parent, text, color)
    return CreateTextPreset(parent, text, "GameFontHighlight", color)
end

function UI.CreateColumnLabel(parent, text, color)
    return CreateTextPreset(parent, text, "GameFontNormalSmall", color or "orange")
end

function UI.SetWindowButtonAction(button, action)
    if button.mosWindowAction == action then return end
    button.mosWindowAction = action
    button:SetText(action == "close" and "X" or action == "minimize" and "_" or "[]")
    UI.SetClassicButtonCompact(button, true)
    if button.mosClassicIconKey then UI.SetClassicButtonIcon(button, nil) end
    UI.SetButtonTextColor(button, UI.TextColors.gold)
    UI.SetClassicButtonLabelOffset(button, action == "minimize" and 2 or 0)
    if action == "maximize" and not button.mosSquare then
        button.mosSquare = {}
        local index
        for index = 1, 4 do
            local edge = UI.CreateTexture(button, nil, "OVERLAY")
            edge:SetTexture("Interface\\Buttons\\WHITE8X8")
            edge:SetVertexColor(unpack(UI.TextColors.gold))
            edge:SetWidth(index <= 2 and 8 or 1); edge:SetHeight(index <= 2 and 1 or 8)
            edge:SetPoint("CENTER", button, "CENTER", index == 3 and -4 or index == 4 and 4 or 0, index == 1 and 4 or index == 2 and -4 or 0)
            button.mosSquare[index] = edge
        end
    end
    if button.mosSquare then
        local index
        for index = 1, 4 do
            if action == "maximize" then button.mosSquare[index]:Show() else button.mosSquare[index]:Hide() end
        end
    end
    if action == "maximize" then button.label:Hide() else button.label:Show() end
end

function UI.CreateWindowButton(parent, name, action)
    local button = UI.CreateButton(parent, name, "", 18, 18)
    UI.SetWindowButtonAction(button, action or "close")
    UI.AttachGoldHoverBorder(button, 0.35, 0.35, 0.35, 1)
    return button
end

function UI.SetButtonEnabled(button, enabled)
    if enabled then button:Enable() else button:Disable() end
    if button.mosClassicVariant == "red" then
        button.mosTextColor = nil
        if UI.SetClassicButtonDisabled then UI.SetClassicButtonDisabled(button, not enabled) end
        if button.label then
            local hovered = button.mosSkinEntry and button.mosSkinEntry.hovered
            if not enabled then button.label:SetTextColor(unpack(UI.TextColors.gray))
            elseif hovered then button.label:SetTextColor(0.82, 0.82, 0.78)
            elseif button.mosClassicGold then button.label:SetTextColor(1, 0.82, 0.28)
            else button.label:SetTextColor(1, 1, 1) end
        end
    else UI.SetButtonTextColor(button, enabled and UI.TextColors.white or UI.TextColors.gray) end
    if button.mosActionIcon then button.mosActionIcon:SetAlpha(enabled and 1 or 0.35) end
end

function UI.SetAlternatingRowColor(row, background, index, percentage)
    local amount = math.mod(index or 1, 2) == 0 and math.max(0, math.min(100, tonumber(percentage) or 5)) / 100 or 0
    local color = row.memberBackground
    if not color then color = {}; row.memberBackground = color end
    color[1] = background[1] + (1 - background[1]) * amount
    color[2] = background[2] + (1 - background[2]) * amount
    color[3] = background[3] + (1 - background[3]) * amount
    UI.SetRowColor(row, color, 1)
end

function UI.UpdateWarmListBorder(button, visible)
    button:SetBackdropBorderColor(0, 0, 0, 0)
    UI.SetProjectButtonOutline(button, visible)
    if visible then button.warmListSelection:Show() else button.warmListSelection:Hide() end
end
function UI.WarmListEnter() this.mosWarmListHovered = true; UI.UpdateWarmListBorder(this, true) end
function UI.WarmListLeave() this.mosWarmListHovered = nil; UI.UpdateWarmListBorder(this, this.mosWarmListSelected) end

local warmListNormal = {0.12, 0.07, 0.02}
function UI.StyleWarmListRow(button, selected)
    button.mosWarmListRow = true; button.mosWarmListSelected = selected
    local entry = button.mosSkinEntry
    if entry and entry.classicSkin then entry.classicSkin.textures[5]:Hide() end
    UI.SetRowColor(button, warmListNormal, 0.96)
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.mosHighlight then button.mosHighlight:Hide() end
    if not button.warmListSelection then
        button.warmListSelection = button:CreateTexture(nil, "ARTWORK")
        button.warmListSelection:SetAllPoints(button)
        UI.ApplyGoldRadialHighlight(button.warmListSelection)
        button:SetScript("OnEnter", UI.WarmListEnter)
        button:SetScript("OnLeave", UI.WarmListLeave)
        button.warmListHover = button.warmListSelection
    end
    UI.UpdateWarmListBorder(button, selected or button.mosWarmListHovered)
end

local selectableTableColor={1,1,1}
function UI.SelectableTableRowEnter()
    this.mosTableRowHovered=true;this.mosTableRowHover:Show()
    if this.mosTableRowSelected then this.mosTableRowSelection:SetAlpha(1) end
end
function UI.SelectableTableRowLeave()
    this.mosTableRowHovered=nil;this.mosTableRowHover:Hide()
    if this.mosTableRowSelected then this.mosTableRowSelection:SetAlpha(0.68) end
end
function UI.StyleSelectableTableRow(button, even, selected)
    button.mosSelectableTableRow=true;button.mosTableRowEven=even and true or false;button.mosTableRowSelected=selected and true or false
    UI.SetRowColor(button,selectableTableColor,even and 0.14 or 0.025)
    button:SetBackdropBorderColor(0,0,0,0)
    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture("") end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.mosHighlight then button.mosHighlight:Hide() end
    if not button.mosTableRowSelection then
        button.mosTableRowSelection=button:CreateTexture(nil,"ARTWORK");button.mosTableRowSelection:SetAllPoints(button);UI.ApplyGoldRadialHighlight(button.mosTableRowSelection)
        button.mosTableRowHover=button:CreateTexture(nil,"ARTWORK");button.mosTableRowHover:SetAllPoints(button);button.mosTableRowHover:SetTexture(1,1,1,1);button.mosTableRowHover:SetAlpha(0.07);button.mosTableRowHover:Hide()
        button:SetScript("OnEnter",UI.SelectableTableRowEnter);button:SetScript("OnLeave",UI.SelectableTableRowLeave)
    end
    UI.SetProjectButtonOutline(button,selected)
    if selected then button.mosTableRowSelection:SetAlpha(button.mosTableRowHovered and 1 or 0.68);button.mosTableRowSelection:Show()
    else button.mosTableRowSelection:Hide() end
end
