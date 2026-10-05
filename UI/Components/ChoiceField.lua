local UI = BootyLib.UI.Components

local function ToggleChoices()
    if this.panel:IsVisible() then this.panel:Hide() else this.panel:Show() end
end

local function RefreshChoice()
    local value = this.getValue()
    local index
    for index = 1, table.getn(this.choices) do
        local choice = this.choices[index]
        if choice.value == value then
            if this.labelValue then this.label:SetText(choice.text) else this:SetText(choice.text) end
            return
        end
    end
end

local function SelectChoice()
    local owner, value, text = this.choiceOwner, this.choiceValue, this.choiceText
    owner.onSelect(value)
    if owner.labelValue then owner.label:SetText(text) else owner:SetText(text) end
    owner.panel:Hide()
    if owner.onChanged then owner.onChanged(value) end
end

function UI.CreateChoiceField(options)
    local parent = options.parent
    local labelOwner = options.labelOwner or parent
    if options.foregroundLabel then
        local overlay = UI.CreateContainer(nil, labelOwner)
        overlay:SetAllPoints(labelOwner); overlay:SetFrameLevel(parent:GetFrameLevel() + 3); overlay:EnableMouse(false)
        labelOwner = overlay
    end
    local label = UI.CreateComponentLabel(labelOwner, "", "white")
    if options.font then label:SetFontObject(options.font); UI.ApplyTextSizeDelta(label, options.labelOwner or parent) end
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", options.x, options.y + (options.labelOffset or 0))
    label:SetText(options.label)
    if options.color then label:SetTextColor(unpack(options.color)); label:SetAlpha(1) end
    local button = UI.CreateDropdownButton(parent, nil, options.initialText, options.width)
    if options.buttonOffset then button:SetPoint("TOPLEFT", parent, "TOPLEFT", options.x + options.buttonOffset, options.y)
    else button:SetPoint("LEFT", label, "RIGHT", 10, 0) end
    button.fieldLabel = label
    button.choices = options.choices; button.getValue = options.getValue
    button.labelValue = options.labelValue
    button.onSelect = options.onSelect; button.onChanged = options.onChanged
    local panel = UI.CreateDropdownPanel(parent, button, options.width, options.height, 20)
    button.panel = panel
    local index
    for index = 1, table.getn(options.choices) do
        local value = options.choices[index]
        local choice = UI.CreateButton(panel, nil, value.text, options.width - 14, 18)
        UI.StyleDropdownChoice(choice)
        choice:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, options.firstY - ((index - 1) * options.step))
        choice.choiceOwner = button; choice.choiceValue = value.value; choice.choiceText = value.text
        choice:SetScript("OnClick", SelectChoice)
        table.insert(panel.options, choice)
    end
    button:SetScript("OnClick", ToggleChoices)
    button:SetScript("OnShow", RefreshChoice)
    return label, button, panel
end
