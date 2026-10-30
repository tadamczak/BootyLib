local UI = BootyLib.UI.Components

local function ToggleChoices()
    if this.panel:IsVisible() then this.panel:Hide() else this:RefreshChoiceValues();this.panel:Show() end
end

local function RefreshChoiceValue(owner)
    if owner.getChoices then owner:SetChoices(owner.getChoices()) end
    local value = owner.getValue()
    if owner.multiple then
        local selectedCaptions=owner.selectedCaptions
        for index,choice in ipairs(owner.choices) do
            local selected=type(value)=="table" and value[choice.value] and true or false
            owner.panel.options[index].check:SetChecked(selected)
            selectedCaptions[choice.text]=selected
        end
        UI.FilterPanel.SetCaption(owner,owner.choiceCaptions,selectedCaptions)
        return
    end
    local index
    for index = 1, table.getn(owner.choices) do
        local choice = owner.choices[index]
        if choice.value == value then
            if owner.labelValue then owner.label:SetText(choice.text) else owner:SetText(choice.text) end
            return
        end
    end
    local caption=tostring(value or owner.initialText or "")
    if owner.labelValue then owner.label:SetText(caption) else owner:SetText(caption) end
end
local function RefreshChoice() RefreshChoiceValue(this) end

local function SelectChoice()
    local owner, value = this.choiceOwner, this.choiceValue
    if owner.multiple then
        local selected={}
        for key,enabled in pairs(owner.getValue() or {}) do if enabled then selected[key]=true end end
        selected[value]=not selected[value] or nil
        owner.onSelect(selected);RefreshChoiceValue(owner)
        if owner.onChanged then owner.onChanged(selected) end
        return
    end
    owner.onSelect(value)
    RefreshChoiceValue(owner)
    owner.panel:Hide()
    if owner.onChanged then owner.onChanged(value) end
end

local function SetChoices(owner,choices)
    owner.choices=choices or {}
    local panel,options=owner.panel,owner.choiceLayout
    if owner.multiple then
        for index=table.getn(owner.choiceCaptions),1,-1 do table.remove(owner.choiceCaptions,index) end
        for key in pairs(owner.selectedCaptions) do owner.selectedCaptions[key]=nil end
    end
    for index,value in ipairs(owner.choices) do
        local choice=panel.options[index]
        if not choice then
            choice=UI.CreateButton(panel,nil,value.text,options.width-14,18)
            UI.StyleDropdownChoice(choice);choice.choiceOwner=owner;choice:SetScript("OnClick",SelectChoice)
            if owner.multiple then
                choice.check=UI.CreateCheckButton(nil,choice,"UICheckButtonTemplate")
                choice.check:SetWidth(18);choice.check:SetHeight(18);choice.check:SetPoint("LEFT",choice,"LEFT",2,0);choice.check:EnableMouse(false)
                choice.label:ClearAllPoints();choice.label:SetPoint("LEFT",choice,"LEFT",24,0);choice.label:SetJustifyH("LEFT")
            end
            table.insert(panel.options,choice)
        end
        choice:SetText(value.text);choice.choiceValue=value.value;choice.choiceText=value.text
        choice:SetWidth(math.max(1,panel:GetWidth()-14))
        if choice.label then
            choice.label:SetWidth(math.max(1,panel:GetWidth()-(owner.multiple and 44 or 30)))
            if value.color then choice.label:SetTextColor(unpack(value.color)) else choice.label:SetTextColor(1,1,1) end
        end
        choice:ClearAllPoints();choice:SetPoint("TOPLEFT",panel,"TOPLEFT",7,options.firstY-(index-1)*options.step)
        choice:Show()
        if owner.multiple then table.insert(owner.choiceCaptions,value.text) end
    end
    for index=table.getn(owner.choices)+1,table.getn(panel.options) do panel.options[index]:Hide() end
    if owner.getChoices then panel:SetHeight(math.max(32,table.getn(owner.choices)*options.step+12)) end
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
    button.initialText=options.initialText
    button.getChoices=options.getChoices;button.SetChoices=SetChoices
    button.choiceLayout={width=options.width,firstY=options.firstY,step=options.step}
    button.multiple=options.multiple;button.RefreshChoiceValues=RefreshChoiceValue
    if options.multiple then button.choiceCaptions={};button.selectedCaptions={} end
    button.labelValue = options.labelValue
    button.onSelect = options.onSelect; button.onChanged = options.onChanged
    local panel = UI.CreateDropdownPanel(parent, button, options.width, options.height, 20)
    button.panel = panel
    button:SetChoices(options.choices)
    button:SetScript("OnClick", ToggleChoices)
    button:SetScript("OnShow", RefreshChoice)
    return label, button, panel
end
