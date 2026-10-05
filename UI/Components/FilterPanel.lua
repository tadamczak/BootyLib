local MOS = BootyLib
local UI = MOS.UI.Components

UI.FilterPanel = UI.FilterPanel or {}
local FilterPanel = UI.FilterPanel

local function SortText(a, b)
    return string.lower(a) < string.lower(b)
end

local function SetCaption(toggle, values, selected, allSelectedCaption, owner)
    if not toggle then return end
    owner.captionScratch = owner.captionScratch or {}
    local captions = owner.captionScratch
    local index
    -- table.insert records sequence length in stock Lua 5.0; raw nil writes do
    -- not clear that length. Remove backwards before reusing this scratch list.
    for index = table.getn(captions), 1, -1 do table.remove(captions, index) end
    for index = 1, table.getn(values or {}) do
        if selected[values[index]] then table.insert(captions, tostring(values[index])) end
    end
    if table.getn(captions) == table.getn(values or {}) and table.getn(captions) > 0 and allSelectedCaption then toggle:SetText(allSelectedCaption)
    elseif table.getn(captions) == 0 then toggle:SetText(owner.emptyMeansAll and (allSelectedCaption or "All") or "None")
    elseif table.getn(captions) == 1 then toggle:SetText(captions[1])
    else toggle:SetText(table.getn(captions) .. " selected") end
    if UI.FitButtonLabel then UI.FitButtonLabel(toggle, math.max(1, toggle:GetWidth() - 28)) end
end

local function RefreshToggleCaption(panel)
    SetCaption(panel.toggle,panel.values,panel.selected,panel.allSelectedCaption,panel)
end

function FilterPanel.SetCaption(toggle,values,selected,allSelectedCaption)
    toggle.mosCaptionOwner=toggle.mosCaptionOwner or {}
    SetCaption(toggle,values,selected,allSelectedCaption,toggle.mosCaptionOwner)
end

function FilterPanel.Refresh(panel, values, selected, onChanged, dynamicWidth, preserveOrder)
    if not preserveOrder then table.sort(values, SortText) end
    panel.values = values
    panel.selected = selected
    panel.onChanged = onChanged

    if not panel.selectAll then
        panel.selectAll = UI.CreateButton(panel, nil, "Select all", 82, 18)
        panel.selectAll:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 10, 9)
        panel.selectAll:SetScript("OnClick", function()
            local owner = this:GetParent()
            owner.selectionTouched = true
            local optionIndex, allSelected = nil, true
            for optionIndex = 1, table.getn(owner.values or {}) do
                if not owner.selected[owner.values[optionIndex]] then allSelected = false; break end
            end
            for optionIndex = 1, table.getn(owner.values or {}) do
                owner.selected[owner.values[optionIndex]] = not allSelected
                if owner.options[optionIndex] then owner.options[optionIndex]:SetChecked(not allSelected and 1 or nil) end
            end
            RefreshToggleCaption(owner)
            if owner.onChanged then owner.onChanged(true) end
        end)
    end

    local padding = panel.contentPadding or 10
    local panelWidth = panel:GetWidth()
    if dynamicWidth then
        local widest = 0
        local valueIndex
        for valueIndex = 1, table.getn(values) do widest = math.max(widest, string.len(tostring(values[valueIndex]))) end
        panelWidth = math.max(112, math.min(190, 42 + (widest * 7)))
        panel:SetWidth(panelWidth)
    end
    panel.selectAll:ClearAllPoints()
    panel.selectAll:SetPoint("BOTTOM", panel, "BOTTOM", 0, panel.contentPadding or 9)
    panel:SetHeight(panel.contentPadding and (padding * 2 + 22 + table.getn(values) * 20) or (38 + table.getn(values) * 20))

    local optionIndex
    for optionIndex = 1, table.getn(values) do
        local checkbox = panel.options[optionIndex]
        if not checkbox then
            checkbox = UI.CreateCheckButton(nil, panel, "UICheckButtonTemplate")
            checkbox:SetWidth(20)
            checkbox:SetHeight(20)
            checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", 10, -10 - ((optionIndex - 1) * 20))
            checkbox.label = checkbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            checkbox.label:SetPoint("LEFT", checkbox, "RIGHT", 2, 0)
            checkbox.label:SetWidth(80)
            checkbox.label:SetJustifyH("LEFT")
            UI.BindCheckboxLabel(checkbox, function(check)
                local owner = check:GetParent()
                owner.selectionTouched = true
                owner.selected[check.value] = check:GetChecked() and true or false
                RefreshToggleCaption(owner)
                if owner.onChanged then owner.onChanged(true) end
            end)
            panel.options[optionIndex] = checkbox
        end
        checkbox:ClearAllPoints()
        checkbox:SetPoint("TOPLEFT", panel, "TOPLEFT", padding, -padding - (optionIndex - 1) * 20)
        checkbox.value = values[optionIndex]
        checkbox.label:SetText(values[optionIndex])
        checkbox.label:SetWidth(panelWidth - (panel.contentPadding and (padding * 2 + 22) or 42))
        checkbox.labelHit:SetWidth(panelWidth - (panel.contentPadding and (padding * 2 + 18) or 38))
        checkbox:SetChecked(selected[values[optionIndex]] and true or false)
        checkbox:Show()
    end
    for optionIndex = table.getn(values) + 1, table.getn(panel.options) do
        panel.options[optionIndex]:Hide()
    end
    RefreshToggleCaption(panel)
end
