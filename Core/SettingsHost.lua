local Lib, UI = BootyLib, BootyLib.UI.Components
local SettingsHost = { windows = {} }
Lib.Core.SettingsHost = SettingsHost
local serial = 0
local defaultColor = {1, 1, 1}
local icons = { ["Addon UI"] = "list", ["Game UI"] = "monitor", ["Addon Messages"] = "loot_tools", ["Profiler"] = "performance", ["Profile"] = "archive", ["Keybindings"] = "link", ["Debug"] = "analyze" }

local function AddPath(roots, path)
    local children, current = roots, nil
    for _, caption in ipairs(path or {}) do
        current = nil
        for _, node in ipairs(children) do if node.text == caption and not node.field then current = node; break end end
        if not current then current = {text = caption, key = caption, children = {}, expanded = false}; table.insert(children, current) end
        children = current.children
    end
    return children
end
function SettingsHost.BuildTree(providers, integrated, product, includeViewSettings)
    local roots={}
    for _,provider in ipairs(providers) do
        local schema=provider.GetSettings and provider.GetSettings()
        if schema and (includeViewSettings or not provider.settingsInView) then
            local first=provider.views and provider.views[1]
            local caption=provider.id=="lib" and "General" or provider.name or provider.title or provider.id
            for _,field in ipairs(schema.fields or {}) do
                if not field.profileOnly then
                    local path,source={caption},field.path or {}
                    local skip=source[1]==caption or source[1]==provider.settingsLabel or first and source[1]==first.label
                    for index=skip and 2 or 1,table.getn(source) do table.insert(path,source[index]) end
                    local children=AddPath(roots,path)
                    table.insert(children,{text=field.label or field.key,key=field.key,field=field,db=schema.db,provider=provider})
                end
            end
            for _,root in ipairs(roots) do
                if root.key==caption then root.productId=provider.id;root.icon=UI.GetProductIcon and UI.GetProductIcon(provider) or first and first.icon or "settings" end
            end
        end
    end
    for index,root in ipairs(roots) do if root.key=="General" then table.remove(roots,index);table.insert(roots,1,root);break end end
    Lib.Core.SettingsSearch.Index(roots)
    return roots
end

local function GetValue(node)
    local field = node.field
    local value
    if field.get then value = field.get(node.db) else value = node.db[field.key] end
    if value == nil then
        if field.default ~= nil then value = field.default end
        if value==nil and field.type == "slider" then return field.min or 0 end
        if value==nil and field.type == "color" then return defaultColor end
    end
    if field.displayScale and type(value)=="number" then return value*field.displayScale end
    return value
end
local Synchronize
local function RefreshDependents(nodes, owner)
    for _, node in ipairs(nodes) do
        if node.provider == owner.provider and node.control and owner.field.refreshKeys[node.key] then Synchronize(node) end
        if node.children then RefreshDependents(node.children, owner) end
    end
end
local function SetValue(node, value, state)
    local field = node.field
    if field.displayScale then
        value=tonumber(value)
        assert(value,"Enter a numeric value.")
        value=value/field.displayScale
    end
    if field.set then field.set(value, node.db) else node.db[field.key] = value end
    if field.onChange then field.onChange(value) end
    if node.provider.OnSettingChanged then node.provider.OnSettingChanged(field.key) end
    if node.provider.OnSettingsChanged then node.provider.OnSettingsChanged(field.key) end
    if state and state.host.ApplySettings then state.host.ApplySettings() end
    if state and field.refreshKeys then RefreshDependents(state.tree, node) end
end
local function CommitPending(nodes)
    for _, node in ipairs(nodes) do
        if node.field and node.control and node.control.CommitValue and node.control.bootyEditing then
            node.control:CommitValue(); node.control:ClearFocus()
        end
        if node.children then CommitPending(node.children) end
    end
end
local function Confirm(state, title, message, action, yes, no)
    if not state.profileConfirm then
        state.profileConfirm = UI.Window.CreateProjectConfirmation(state.ownerName .. "ProfileConfirmation", title, action, "archive")
    end
    if UI.WindowStack then UI.WindowStack.SetOwner(state.profileConfirm, state.window) end
    state.profileConfirm.title:SetText(title); state.profileConfirm.yes:SetText(action)
    state.profileConfirm.no:SetText(no and "Discard" or "Cancel")
    state.profileConfirm:Open(message, yes, no)
end
local NaturalLabelWidth, NaturalLabelHeight
local function RefreshPreview(node, state)
    local drafts = state.previewDrafts and state.previewDrafts[node.db]
    local caption = node.field.preview(node.db, drafts) or ""
    if node.preview:GetText() == caption then return false end
    node.preview:SetText(caption)
    node.bootyPreviewVersion = (node.bootyPreviewVersion or 0) + 1
    return true
end
local function RefreshVisiblePreviews(state)
    local changed = false
    for _, node in ipairs(state.previewNodes or {}) do
        if node.layoutVisible and RefreshPreview(node, state) then changed = true end
    end
    return changed
end

local function AttachPreview(node, page, state)
    node.preview = UI.CreateComponentLabel(page, nil, "gray")
    node.preview:SetJustifyH("LEFT"); node.preview:SetJustifyV("TOP")
    state.previewNodes = state.previewNodes or {}; table.insert(state.previewNodes, node)
    node.previewState = state
    RefreshPreview(node, state)
    local control = node.control
    local changed = control:GetScript("OnTextChanged")
    control:SetScript("OnTextChanged", function()
        if changed then changed() end
        if not control.bootyEditing or state.previewBusy or state.reflowBusy or not state.window:IsVisible() then return end
        state.previewDrafts = state.previewDrafts or {}
        local drafts = state.previewDrafts[node.db]
        if not drafts then drafts = {}; state.previewDrafts[node.db] = drafts end
        drafts[node.field.key] = control:GetText()
        state.RefreshPreviews()
    end)
    local function AfterEdit(script)
        local previous = control:GetScript(script)
        control:SetScript(script, function()
            if previous then previous() end
            if not control.bootyEditing then
                local drafts = state.previewDrafts and state.previewDrafts[node.db]
                if drafts then drafts[node.field.key] = nil end
                state.RefreshPreviews()
            end
        end)
    end
    AfterEdit("OnEnterPressed"); AfterEdit("OnEscapePressed"); AfterEdit("OnEditFocusLost"); AfterEdit("OnHide")
end

local function CloseProfiles(state)
    for _,view in ipairs(state.profileViews or {}) do view.Close();view.name:ClearFocus() end
end
local function CreateProfileControls(node, page, state)
    local api, view = node.profileContext or state.ProfileContext, {rows = {}, first = 1}
    view.frame = UI.CreateContainer(nil, page)
    node.control, node.profileView = view.frame, view
    state.profileViews=state.profileViews or {};table.insert(state.profileViews,view)
    if api==state.ProfileContext then state.profiles=view end
    view.api = api
    local function Label(text, color)
        local label = UI.CreateComponentLabel(view.frame, nil, color or "white")
        label:SetText(text); label:SetHeight(16); return label
    end
    local function Action(text, width)
        local button = UI.CreateButton(view.frame, nil, text, width or 58, 24)
        UI.StyleActionButton(button); return button
    end
    view.currentLabel, view.current = Label("Current profile"), Label("", "gold")
    view.Save, view.Load, view.Delete, view.Export, view.Add = Action("Save"), Action("Load"), Action("Delete"), Action("Export"), Action("Add")
    view.loadLabel, view.newLabel = Label("Load profile"), Label("New profile")
    view.select = UI.CreateDropdownButton(view.frame, nil, "Select profile", 180)
    view.name = UI.CreateFramedEditBox(view.frame, nil, 180); view.name:SetMaxLetters(64)
    view.status = Label("", "gold")
    view.flows = {{view.currentLabel, view.current, view.Save}, {view.loadLabel, view.select, view.Load, view.Delete, view.Export}, {view.newLabel, view.name, view.Add}}
    view.panel = UI.CreateDropdownPanel(view.frame, view.select, 180, 154, 20)
    view.frame.panel = view.panel
    local function Message(text) view.status:SetText(text or ""); state.Reflow() end
    view.Refresh = function()
        local current = api.GetCurrent()
        view.current:SetText(current .. (api.IsDirty() and " *" or ""))
        if view.selected and not api.Exists(view.selected) then view.selected = nil end
        view.select:SetText(view.selected or "Select profile")
        UI.SetButtonEnabled(view.Load, view.selected ~= nil); UI.SetButtonEnabled(view.Delete, view.selected ~= nil); UI.SetButtonEnabled(view.Export, view.selected ~= nil)
    end
    local function RefreshMenu()
        view.names = api.List(); view.first = math.max(1, math.min(view.first, math.max(1, table.getn(view.names) - 5)))
        for index = 1, 6 do
            local row, name = view.rows[index], view.names[view.first + index - 1]
            row.profileName = name
            if name then row:SetText(name); row:Show() else row:Hide() end
        end
    end
    for index = 1, 6 do
        local row = UI.CreateButton(view.panel, nil, "", 166, 22)
        UI.StyleDropdownChoice(row); row:SetPoint("TOPLEFT", view.panel, "TOPLEFT", 7, -7 - (index - 1) * 23)
        row:SetScript("OnClick", function() view.selected = this.profileName; view.Refresh(); view.panel:Hide() end)
        view.rows[index] = row; table.insert(view.panel.options, row)
    end
    view.panel:EnableMouseWheel(true)
    view.panel:SetScript("OnMouseWheel", function() view.first = view.first - (arg1 or 0); RefreshMenu() end)
    view.select:SetScript("OnClick", function() if view.panel:IsVisible() then view.panel:Hide() else RefreshMenu(); view.panel:Show() end end)
    local function Switch(action, target)
        CommitPending(state.tree); view.panel:Hide()
        local function Apply()
            local ok, message = api[action](target)
            if ok and action == "Add" then view.name:SetText(""); view.selected = api.GetCurrent() end
            Message(message)
        end
        if api.IsDirty() then
            Confirm(state, "Unsaved profile changes", "Save current profile " .. api.GetCurrent() .. " before switching?", "Save", function()
                local ok, message = api.SaveCurrent(); if ok then Apply() else Message(message) end
            end, Apply)
        else Apply() end
    end
    view.Load:SetScript("OnClick", function() if view.selected then Switch("Load", view.selected) end end)
    view.Add:SetScript("OnClick", function()
        local ok, message = api.CanAdd(view.name:GetText())
        if ok then Switch("Add", view.name:GetText()) else Message(message) end
    end)
    view.Save:SetScript("OnClick", function() CommitPending(state.tree); local _, message = api.SaveCurrent(); Message(message) end)
    view.Delete:SetScript("OnClick", function()
        local selected = view.selected; if not selected then return end
        view.panel:Hide()
        Confirm(state, "Delete settings profile", "Delete profile " .. selected .. "?", "Delete", function()
            local _, message = api.Delete(selected); view.selected = nil; Message(message)
        end)
    end)
    view.Export:SetScript("OnClick", function()
        if not view.selected then return end
        local text, message = api.Export(view.selected)
        if not text then Message(message); return end
        if not view.export then
            view.export = UI.CreateTextEditor(state.ownerName .. "ProfileExport", "Export profile", 65535)
            view.export.save:Hide(); view.export.cancel:SetText("Close")
        end
        if UI.WindowStack then UI.WindowStack.SetOwner(view.export, state.window) end
        view.export:Open(text); view.export.edit:HighlightText(); view.export:SetMessage("Copy the selected text with Ctrl+C.", false)
        view.panel:Hide(); Message("Exported profile: " .. view.selected)
    end)
    view.Close = function()
        view.panel:Hide(); if view.export then view.export:Hide() end
        if state.profileConfirm then state.profileConfirm:Hide() end
    end
    view.frame:SetScript("OnHide", view.Close)
    view.Layout = function(x, y, width)
        if not state.geometryOnly then view.Refresh() end
        view.frame:ClearAllPoints(); view.frame:SetPoint("TOPLEFT", page, "TOPLEFT", x, y); view.frame:SetWidth(width)
        local top = 0
        for _, controls in ipairs(view.flows) do
            for _, control in ipairs(controls) do
                if control.GetStringWidth then
                    control.bootyFlowWidth = math.min(control == view.current and 180 or width, NaturalLabelWidth(control))
                    control:SetWidth(control.bootyFlowWidth); control:SetHeight(math.max(16, NaturalLabelHeight(control, control.bootyFlowWidth)))
                elseif control == view.name or control == view.select then control.bootyFlowWidth = math.min(180, width)
                else control.bootyFlowWidth = 58; control.bootyFlowFitLabel = true end
            end
            top = UI.LayoutFlow(view.frame, controls, 0, top, width, 6) + 8
        end
        if view.status:GetText() ~= "" then
            NaturalLabelWidth(view.status)
            view.status:SetWidth(width); view.status:SetHeight(math.max(16, NaturalLabelHeight(view.status, width)))
            view.status:ClearAllPoints(); view.status:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, -top); view.status:Show()
            top = top + view.status:GetHeight() + 6
        else view.status:Hide() end
        view.panel:SetWidth(view.select:GetWidth())
        for _, row in ipairs(view.rows) do row:SetWidth(math.max(1, view.select:GetWidth() - 14)) end
        node.height = top; view.frame:SetHeight(top); view.frame:Show()
    end
    return view
end
local function CreateField(node, page, state)
    local field = node.field
    local binding = {ensure = function() end, get = function() return GetValue(node) end,
        set = function(_, value) SetValue(node, value, state); state.RefreshEnabled() end}
    local kind = field.type
    local control, label
    if kind == "action" then
        control = UI.CreateButton(page, nil, node.text, 180, 24); UI.StyleActionButton(control)
        control:SetScript("OnClick", function()
            field.action(node.db)
            if field.refreshKeys then RefreshDependents(state.tree, node) end
            state.RefreshEnabled()
        end)
        node.height = 32
    elseif kind == "checkbox" then
        control = UI.Settings.CreateCheckbox(page, 0, 0, node.text, field.key, nil, binding)
        node.height = 30
    elseif kind == "slider" then
        serial = serial + 1
        control = UI.Settings.CreateSlider(page, "BootySettingsSlider" .. serial, 0, 0, node.text, field.key, field.min or 0, field.max or 100, nil, binding)
        if field.step then control:SetValueStep(field.step) end
        node.height = 52
    elseif kind == "color" then
        control = UI.Settings.CreateColor(page, 0, 0, node.text, field.key, nil, binding); node.height = 32
    elseif kind == "dropdown" or kind == "choice" or kind == "multiselect" then
        local choices = {}
        for _, option in ipairs(field.choices or field.options or {}) do
            if type(option) == "table" then table.insert(choices, {text = option.text or option.label or tostring(option.value), value = option.value})
            else table.insert(choices, {text = tostring(option), value = option}) end
        end
        label, control = UI.CreateChoiceField({parent = page, x = 0, y = 0, label = node.text,
            initialText = tostring(GetValue(node) or ""), choices = choices, getValue = function() return GetValue(node) end,
            onSelect = function(value) SetValue(node, value, state); state.RefreshEnabled() end,
            width = 180, height = math.max(32, table.getn(choices) * 24 + 12), firstY = -7, step = 24,
            buttonOffset = 220, color = UI.TextColors.white,multiple=kind=="multiselect"})
        node.label = label; node.height = 36
    else
        label = UI.CreateComponentLabel(page, nil, "white"); label:SetText(node.text)
        control = UI.Settings.CreateSavedTextField(page, field.key, binding)
        if field.maxLength then control:SetMaxLetters(field.maxLength) end
        node.label = label; node.height = 58
    end
    node.control = control
    if field.preview then AttachPreview(node, page, state) end
    if field.tooltip then UI.AttachTooltip(control, node.text, field.tooltip) end
    return control
end
Synchronize = function(node)
    if node.field.type == "action" then return end
    local control, field, value = node.control, node.field, GetValue(node)
    if field.type == "checkbox" then control:SetChecked(value and value ~= 0 and 1 or nil)
    elseif field.type == "slider" then UI.Settings.SynchronizeSlider(control, tonumber(value) or field.min or 0)
    elseif field.type == "color" then
        value = type(value) == "table" and value or defaultColor
        control.swatch:SetTexture(value[1] or 1, value[2] or 1, value[3] or 1, 1)
    elseif field.type=="multiselect" then control:RefreshChoiceValues()
    elseif field.type == "choice" or field.type == "dropdown" then
        local caption = tostring(value or "")
        for _, choice in ipairs(control.choices) do if choice.value == value then caption = choice.text; break end end
        control:SetText(caption)
    elseif control.RefreshValue then control:RefreshValue() end
    if node.preview then RefreshPreview(node, node.previewState) end
end
NaturalLabelWidth = function(label)
    local text = label:GetText()
    local font, size, flags
    if label.GetFont then font, size, flags = label:GetFont() end
    if label.bootyNaturalText == text and label.bootyNaturalFont == font and label.bootyNaturalSize == size and label.bootyNaturalFlags == flags and label.bootyNaturalWidth then
        return label.bootyNaturalWidth
    end
    label:SetWidth(0)
    local width = math.max(1, math.ceil(label:GetStringWidth()) + 2)
    label.bootyNaturalText, label.bootyNaturalFont, label.bootyNaturalSize, label.bootyNaturalFlags = text, font, size, flags
    label.bootyNaturalWidth, label.bootyNaturalHeight = width, nil
    return width
end
NaturalLabelHeight = function(label, width)
    if not label.bootyNaturalHeight or label.bootyNaturalHeightWidth ~= width then
        label.bootyNaturalHeight = math.max(14, UI.MeasureTextHeight(label, width))
        label.bootyNaturalHeightWidth = width
    end
    return label.bootyNaturalHeight
end
local function MeasureField(node)
    local control, kind = node.control, node.field.type
    if kind == "action" then return math.max(120, NaturalLabelWidth(control.label) + 24) end
    if node.label then
        local width = math.max(180, NaturalLabelWidth(node.label))
        if kind == "choice" or kind == "dropdown" or kind=="multiselect" then
            width = math.max(width, NaturalLabelWidth(control.label or control) + 32)
            for _, option in ipairs(control.panel.options) do
                width = math.max(width, NaturalLabelWidth(option.label or option) + (kind=="multiselect" and 44 or 32))
            end
        end
        return node.field.inlineLabel and width+NaturalLabelWidth(node.label)+10 or width
    elseif kind == "slider" then
        local name = control:GetName()
        local label = getglobal(name .. "Text")
        local font, size, flags = label:GetFont()
        if node.bootySliderMeasureText == label:GetText() and node.bootySliderMeasureFont == font and node.bootySliderMeasureSize == size and node.bootySliderMeasureFlags == flags and node.bootySliderMeasureWidth then
            return node.bootySliderMeasureWidth
        end
        local caption, width = label:GetText(), NaturalLabelWidth(label)
        label:SetText(node.text .. ": " .. tostring(node.field.min or 0)); width = math.max(width, NaturalLabelWidth(label))
        label:SetText(node.text .. ": " .. tostring(node.field.max or 100)); width = math.max(width, NaturalLabelWidth(label))
        label:SetText(caption)
        width = math.max(170, width + 8,
            NaturalLabelWidth(getglobal(name .. "Low")) + NaturalLabelWidth(getglobal(name .. "High")) + 32)
        node.bootySliderMeasureText, node.bootySliderMeasureFont, node.bootySliderMeasureSize, node.bootySliderMeasureFlags = caption, font, size, flags
        node.bootySliderMeasureWidth = width
        return width
    end
    return (kind == "color" and 26 or control:GetWidth() + 2) + NaturalLabelWidth(control.label) + 4
end
local function FieldLabelWidth(node, label, width)
    local natural = NaturalLabelWidth(label)
    if not node.bootyWrapWidth then return natural end
    width = width or node.bootyWrapWidth
    if node.label then
        if node.field.inlineLabel then width = width - math.min(80, width / 2) - 10 end
    elseif node.field.type == "checkbox" then width = width - node.control:GetWidth() - 6
    elseif node.field.type == "color" then width = width - 26
    elseif node.field.type == "action" then width = width - 24 end
    return math.max(1, math.min(natural, width))
end
local function MeasureFieldHeight(node, width)
    local control,kind=node.control,node.field.type
    local label=node.label or control.label or kind=="slider" and getglobal(control:GetName().."Text")
    local labelHeight=label and NaturalLabelHeight(label,FieldLabelWidth(node,label,width)) or 0
    local top=node.label and not node.field.inlineLabel and labelHeight+4 or kind=="slider" and math.max(18,labelHeight+4) or 0
    if node.label and node.field.inlineLabel then top=math.max(0,(labelHeight-control:GetHeight())/2) end
    local bottom=top+control:GetHeight()
    local height=node.label and bottom+10 or kind=="slider" and bottom+18 or math.max(kind=="color" and 32 or 30,labelHeight+8)
    if kind == "action" then height = math.max(24, labelHeight + 8) + 8 end
    if node.label and node.field.inlineLabel then height=math.max(control:GetHeight(),labelHeight)+10 end
    return height,bottom,top
end
local function LayoutField(node, page, x, y, width)
    local control, kind = node.control, node.field.type
    if node.preview then width = math.max(1, page:GetWidth() - x - 4) end
    local label = node.label or control.label or kind == "slider" and getglobal(control:GetName() .. "Text")
    local labelWidth = label and FieldLabelWidth(node, label, width)
    local labelHeight = label and NaturalLabelHeight(label, labelWidth)
    if node.bootyLayoutX == x and node.bootyLayoutY == y and node.bootyLayoutWidth == width and node.bootyLayoutLabelWidth == labelWidth and node.bootyLayoutLabelHeight == labelHeight and node.bootyLayoutPreviewVersion == node.bootyPreviewVersion and control:IsShown() then return node.height end
    node.bootyLayoutX, node.bootyLayoutY, node.bootyLayoutWidth = x, y, width
    node.bootyLayoutLabelWidth, node.bootyLayoutLabelHeight = labelWidth, labelHeight
    node.bootyLayoutPreviewVersion = node.bootyPreviewVersion
    control:ClearAllPoints()
    if node.label then
        node.label:SetWidth(labelWidth)
        node.label:SetJustifyH("LEFT")
        node.label:SetHeight(labelHeight); node.label:Show()
        node.label:ClearAllPoints()
        if node.field.inlineLabel then
            node.label:SetPoint("RIGHT",control,"LEFT",-10,0)
            local _,_,top=MeasureFieldHeight(node,width)
            control:SetPoint("TOPLEFT",page,"TOPLEFT",x+labelWidth+10,y-top)
            control:SetWidth(math.max(1,width-labelWidth-10));node.height=math.max(control:GetHeight(),labelHeight)+10
        else
            node.label:SetPoint("BOTTOMLEFT", control, "TOPLEFT", 0, 4)
            control:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - labelHeight - 4)
            control:SetWidth(width);node.height = labelHeight + 4 + control:GetHeight() + 10
        end
        if kind == "choice" or kind == "dropdown" or kind=="multiselect" then
            if control.bootyDropdownText then control.bootyTextWidth = nil; UI.ReflowControlText(control) end
            local popupWidth = control:GetWidth()
            local padding = kind == "multiselect" and 44 or 30
            if node.bootyWrapWidth then
                -- A narrow embedded toggle must not truncate its fixed-height
                -- choices. The existing popup is screen-owned, not pane-clipped.
                for _, option in ipairs(control.panel.options) do
                    if option.label then popupWidth = math.max(popupWidth, NaturalLabelWidth(option.label) + padding) end
                end
                popupWidth = math.min(popupWidth, math.max(1, UIParent:GetWidth() - 16))
                if control.panel.SetClampedToScreen then control.panel:SetClampedToScreen(true) end
            end
            control.panel:SetWidth(popupWidth)
            for _, option in ipairs(control.panel.options) do
                option:SetWidth(math.max(1, popupWidth - 14))
                if option.label then option.label:SetWidth(math.max(1, popupWidth - padding)) end
            end
        end
    else
        local _,_,top=MeasureFieldHeight(node,width)
        control:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - top)
        if kind == "action" then
            control:SetWidth(width); control:SetHeight(math.max(24, labelHeight + 8))
            control.label:SetWidth(labelWidth); node.height = control:GetHeight() + 8
        elseif kind == "slider" then
            control:SetWidth(width)
            label:SetWidth(labelWidth); label:SetJustifyH("LEFT")
            if node.bootyWrapWidth then label:SetHeight(labelHeight) end
            node.height = top+control:GetHeight()+18
        elseif control.label then
            control.label:SetWidth(labelWidth); control.label:SetJustifyH("LEFT")
            local height = math.max(control:GetHeight(), labelHeight)
            control.label:SetHeight(height)
            if kind == "color" then control:SetWidth(width) end
            if control.labelHit then control.labelHit:SetWidth(labelWidth); control.labelHit:SetHeight(height) end
            if node.bootyWrapWidth then
                local anchor = kind == "color" and control.swatchBorder or control
                local gap = kind == "color" and 6 or 2
                control.label:ClearAllPoints()
                if labelHeight > control:GetHeight() then control.label:SetPoint("TOPLEFT", anchor, "TOPRIGHT", gap, 0)
                else control.label:SetPoint("LEFT", anchor, "RIGHT", gap, 0) end
                if control.labelHit then
                    control.labelHit:ClearAllPoints()
                    control.labelHit:SetPoint(labelHeight > control:GetHeight() and "TOPLEFT" or "LEFT", control,
                        labelHeight > control:GetHeight() and "TOPRIGHT" or "RIGHT", 1, 0)
                end
            end
            node.height = math.max(kind == "color" and 32 or 30, height + 8)
        end
    end
    if node.preview then
        NaturalLabelWidth(node.preview)
        local height = NaturalLabelHeight(node.preview, width)
        node.preview:SetWidth(width); node.preview:SetHeight(height)
        node.preview:ClearAllPoints(); node.preview:SetPoint("TOPLEFT", control, "BOTTOMLEFT", 0, -6)
        node.preview:Show(); node.height = node.height + height + 6
    end
    control:Show()
    return node.height
end
local function Visible(node) return node.visible ~= false end
local function ToggleAccordion()
    -- Lua 5.0 clears a generic-for variable after traversal.
    -- Resolve the clicked node from its pooled control instead.
    local selected = this.bootySettingsNode
    selected.expanded = not selected.expanded; this.bootySettingsState.Reflow()
end
local function LayoutNodes(nodes, page, state, depth, y)
    local index = 1
    while index <= table.getn(nodes) do
        local node = nodes[index]
        local shown = Visible(node)
        if shown then
            node.layoutVisible = true
            local x = depth * 18
            if node.profileControls then
                local view = node.profileView or CreateProfileControls(node, page, state)
                view.Layout(x, y, math.max(1, page:GetWidth() - x - 4)); y = y - node.height
            elseif node.field then
                local items = node.gridItems
                if not items then
                    items = {bootyNoWrap = not state.wrapFields, bootyMeasureItem = MeasureField, bootyMeasureHeight = MeasureFieldHeight, bootyLayoutItem = LayoutField}
                    node.gridItems = items
                end
                while table.getn(items) > 0 do table.remove(items) end
                while index <= table.getn(nodes) and nodes[index].field do
                    local fieldNode = nodes[index]
                    if fieldNode.field.row~=node.field.row then break end
                    if fieldNode ~= node and (node.field.preview or fieldNode.field.preview) then break end
                    if Visible(fieldNode) then
                        fieldNode.layoutVisible = true
                        fieldNode.bootyWrapWidth = state.wrapFields and math.max(1, page:GetWidth() - x - 4) or nil
                        if not fieldNode.control then CreateField(fieldNode, page, state); Synchronize(fieldNode)
                        elseif not state.geometryOnly then Synchronize(fieldNode) end
                        table.insert(items, fieldNode)
                    end
                    index = index + 1
                end
                y = y - UI.Settings.LayoutGrid(page, items, x, y, math.max(1, page:GetWidth() - x - 4), 0)
                state.requiredContentWidth = math.max(state.requiredContentWidth, x + items.bootyRequiredWidth + 4)
                index = index - 1
            else
                if not node.control then
                    if depth == 0 then node.control = UI.Settings.CreateSectionAccordion(page, node.text, 0, 0, state.sectionHeadingLevel or 2, node.icon or icons[node.text] or "list")
                    else node.control = UI.Settings.CreateAccordion(page, node.text, 0) end
                    node.control.bootySettingsNode = node
                    node.control.bootySettingsState = state
                    node.control:SetScript("OnClick", ToggleAccordion)
                end
                if node.bootyLayoutX ~= x or node.bootyLayoutY ~= y then
                    node.control:ClearAllPoints(); node.control:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
                    node.control:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, y)
                    node.bootyLayoutX, node.bootyLayoutY = x, y
                end
                if node.bootyLayoutExpanded ~= node.expanded then
                    if node.control.indicator then node.control.indicator:SetText(node.expanded and "-" or "+") end
                    if node.control.SetExpanded then node.control:SetExpanded(node.expanded) end
                    node.bootyLayoutExpanded = node.expanded
                end
                if not node.control:IsShown() then node.control:Show() end
                y = y - (depth == 0 and 38 or 30)
                if node.expanded then y = LayoutNodes(node.children, page, state, depth + 1, y) end
            end
        end
        index = index + 1
    end
    return y
end
local function ClearLayout(nodes)
    for _, node in ipairs(nodes) do
        node.layoutVisible = false
        if node.children then ClearLayout(node.children) end
    end
end
local function CloseChoices(nodes)
    for _, node in ipairs(nodes) do
        if node.control and node.control.panel then node.control.panel:Hide() end
        if node.children then CloseChoices(node.children) end
    end
end
local function HideUnused(nodes)
    for _, node in ipairs(nodes) do
        if not node.layoutVisible then
            if node.control then node.control:Hide() end
            if node.label then node.label:Hide() end
            if node.preview then node.preview:Hide() end
        end
        if node.children then HideUnused(node.children) end
    end
end
local function RefreshNodes(nodes)
    for _, node in ipairs(nodes) do
        if node.field and node.control then
            local enabled = node.field.enabled
            if type(enabled) == "function" then enabled = enabled(node.db)
            elseif enabled == nil then enabled = true end
            enabled = enabled and enabled ~= 0
            if node.field.type == "checkbox" then UI.Settings.SetCheckboxEnabled(node.control, enabled)
            elseif node.field.type == "slider" then UI.Settings.SetSliderEnabled(node.control, enabled)
            else
                if node.control.CommitValue and node.control.RefreshValue then
                    UI.Settings.SetTextFieldEnabled(node.control, enabled)
                else
                    if enabled then node.control:Enable() else node.control:Disable() end
                    node.control:SetAlpha(enabled and 1 or 0.42)
                end
                local label = node.label or node.control.label
                if label then label:SetTextColor(unpack(enabled and UI.TextColors.white or UI.TextColors.gray)) end
            end
        elseif node.children then RefreshNodes(node.children) end
    end
end
local function ApplyFieldMinimum(state)
    if state.applyingMinimum then return end
    local inset = state.viewport.bootyWidthInset or 16
    local maximum = math.max(320, math.min(1100, UIParent:GetWidth() - 32))
    local required = math.max(math.min(350, maximum), state.requiredContentWidth + inset + (state.viewport.bootyScrollGutter or 0))
    local width = math.min(required, maximum)
    state.requiredWindowWidth, state.maximumWindowWidth = required, maximum
    state.minimumWidthFailure = required > maximum and "Natural settings fields exceed the available window width." or nil
    -- The longest indivisible field also bounds a one-column window. Reserving
    -- the gutter here follows the resolved layout, never a permanent scrollbar.
    state.window:SetMinResize(width, math.min(420, math.max(260, UIParent:GetHeight() - 32)))
    if state.window:GetWidth() < width then
        state.applyingMinimum = true
        state.window:SetWidth(width)
        state.applyingMinimum = nil
        -- The native size event is suppressed by the outer reflow guard. Resolve
        -- the new owner rectangle here, without entering a second outer refresh.
        UI.Settings.UpdateScroll(state.viewport, state.page, state.page.settingsContentHeight)
    end
end
local function ResizeSettingsTick()
    local state = this.bootySettingsState
    this:SetScript("OnUpdate", nil)
    state.resizeQueued = nil
    if state.window:IsVisible() and not state.window.minimized and (state.window:GetWidth() ~= state.lastWindowWidth or state.window:GetHeight() ~= state.lastWindowHeight or state.page:GetWidth() ~= state.lastPageWidth) then
        state.geometryOnly = true
        local ok, failure = pcall(state.Reflow)
        state.geometryOnly = nil
        if not ok then error(failure, 0) end
    end
end
local function AddProfiles(state, product, providers)
    if not Lib.Core.SettingsProfiles or product.id=="lib" then return end
    local suite=product.id=="suite" and state.host.integrated
    state.ProfileContext=Lib.Core.SettingsProfiles.Create(providers,{id=product.id or product.name,scoped=true,bundle=suite,
        onApplied=function() if state.host.ApplySettings then state.host.ApplySettings() end;state.Reflow() end})
    state.ProfileContexts={[product.id or product.name]=state.ProfileContext}
    local children={}
    local function AddProfile(owner,api,caption)
        local node={key="profileControls",text="Current profile Load profile New profile Save Add Delete Export",profileControls=true,profileContext=api}
        if api==state.ProfileContext then state.profileNode=node end
        table.insert(children,{key=caption,text=caption,expanded=false,children={node},icon=UI.GetProductIcon and UI.GetProductIcon(owner)})
    end
    AddProfile(product,state.ProfileContext,suite and "BootySuite" or "General")
    if suite then
        for _,provider in ipairs(providers) do
            local api=state.ProfileContext.addons[provider.id]
            if api then state.ProfileContexts[provider.id]=api;AddProfile(provider,api,provider.name) end
        end
    end
    table.insert(state.tree,state.tree[1] and state.tree[1].key=="General" and 2 or 1,{key="Profile",text="Profile",expanded=false,children=children})
    Lib.Core.SettingsSearch.Index(state.tree)
end

-- Product pages share the same schema controls and profile transactions as the
-- detached window. Their host owns geometry; only actual overflow adds a gutter.
function SettingsHost.CreatePanel(parent, product, host)
    local frame = UI.CreateContainer(nil, parent); frame:SetAllPoints(parent); frame:Hide()
    local state = {frame = frame, host = host, ownerName = product.name .. "Options", window = host.window or frame, wrapFields = true}
    state.tree = SettingsHost.BuildTree({product}, false, product, true)
    for _, root in ipairs(state.tree) do
        root.expanded = true
        for _, child in ipairs(root.children or {}) do if child.key == "General" then child.expanded = true end end
    end
    AddProfiles(state, product, {product})
    state.toolbar = UI.CreateToolbarSurface(frame, false, true); state.toolbar:SetHeight(32)
    state.search = UI.CreateFramedEditBox(state.toolbar, nil, 250)
    state.search:SetPoint("LEFT", state.toolbar, "LEFT", 0, 0); state.search:SetHeight(24)
    UI.AttachTooltip(state.search, "Search settings", "Filter labels and their full section path. Open sections to inspect matching fields.")
    UI.AttachPlaceholder(state.search, "Search settings")
    serial = serial + 1
    state.viewport = UI.CreateScrollFrame("BootySettingsPanelViewport" .. serial, frame, "UIPanelScrollFrameTemplate")
    state.scrollBar = getglobal(state.viewport:GetName() .. "ScrollBar")
    if state.scrollBar then UI.RegisterSkinnedScrollBar(state.scrollBar) end
    state.page = UI.CreateContainer(nil, state.viewport); state.page.bootyTextSizeDelta = -2
    state.page:SetWidth(1); state.page:SetHeight(1); state.viewport:SetScrollChild(state.page)
    state.RefreshPreviews = function()
        if state.previewBusy or not frame:IsVisible() then return end
        state.previewBusy = true
        local ok, changed = pcall(RefreshVisiblePreviews, state)
        state.previewBusy = nil
        if not ok then error(changed, 0) end
        if changed and not state.reflowBusy then state.Reflow() end
    end
    state.RefreshEnabled = function() RefreshNodes(state.tree); state.RefreshPreviews() end
    local function Measure(width)
        state.page:SetWidth(width); ClearLayout(state.tree); state.requiredContentWidth = 1
        local y = LayoutNodes(state.tree, state.page, state, 0, -4)
        HideUnused(state.tree)
        state.page.settingsContentHeight = math.max(1, -y + 4)
        return state.page.settingsContentHeight
    end
    local function Layout()
        state.window = host.window or frame
        local width, height = UI.GetFrameSpan(parent)
        width, height = math.max(1, width), math.max(1, height)
        frame:SetWidth(width); frame:SetHeight(height)
        state.toolbar:ClearAllPoints(); state.toolbar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -4)
        state.toolbar:SetWidth(math.max(1, width - 16))
        state.search:SetWidth(math.max(1, math.min(250, width - 16 - (state.reset and 66 or 0))))
        CloseChoices(state.tree)
        local fullWidth, viewportHeight = math.max(1, width - 16), math.max(1, height - 48)
        local contentWidth, contentHeight, overflow, maximum = UI.ResolveScrollLayout(fullWidth, viewportHeight, 20, Measure)
        state.viewportHeight, state.maximumScroll = viewportHeight, maximum
        state.viewport.bootyScrollGutter = overflow and 20 or 0
        state.viewport:ClearAllPoints(); state.viewport:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
        state.viewport:SetWidth(contentWidth); state.viewport:SetHeight(viewportHeight)
        state.page:SetWidth(contentWidth); state.page:SetHeight(contentHeight)
        if state.scrollBar then
            state.scrollBar:ClearAllPoints(); state.scrollBar:SetPoint("TOPLEFT", frame, "TOPLEFT", contentWidth + 12, -56)
            state.scrollBar:SetWidth(16); state.scrollBar:SetHeight(math.max(1, viewportHeight - 32))
        end
        UI.ApplyScrollRange(state.viewport, state.scrollBar, maximum)
        state.RefreshEnabled()
    end
    state.Reflow = function()
        if state.reflowBusy or not frame:IsVisible() then return end
        state.reflowBusy = true
        local ok, failure = pcall(Layout)
        state.reflowBusy = nil
        if not ok then error(failure, 0) end
    end
    state.search:SetScript("OnTextChanged", function()
        Lib.Core.SettingsSearch.Apply(state.tree, this:GetText()); state.viewport:SetVerticalScroll(0); state.Reflow()
    end)
    state.search:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus() end)
    if state.ProfileContext then
        state.reset = UI.CreateButton(state.toolbar, nil, "Reset", 58, 24); UI.StyleActionButton(state.reset)
        state.reset:SetPoint("RIGHT", state.toolbar, "RIGHT", 0, 0)
        UI.AttachTooltip(state.reset, "Reset settings to defaults", "Reset only this addon's preferences. Other addons and saved data are retained.")
        state.reset:SetScript("OnClick", function()
            CommitPending(state.tree)
            Confirm(state, "Reset settings", "Reset this addon's settings to defaults?", "Reset", function()
                local _, message = state.ProfileContext.ResetDefaults()
                if state.profiles then state.profiles.status:SetText(message) elseif host.Print then host.Print(message) end
                state.Reflow()
            end)
        end)
    end
    state.viewport:EnableMouseWheel(true)
    state.viewport:SetScript("OnMouseWheel", function()
        state.viewport:SetVerticalScroll(state.viewport:GetVerticalScroll() - (arg1 or 0) * 36)
        UI.ApplyScrollRange(state.viewport, state.scrollBar, state.maximumScroll or 0)
    end)
    local function Cleanup()
        CommitPending(state.tree); CloseChoices(state.tree); state.search:ClearFocus()
        CloseProfiles(state)
        if state.profileConfirm then state.profileConfirm:Hide() end
    end
    local function RefreshValues(nodes)
        for _, node in ipairs(nodes) do
            if node.layoutVisible and node.field and node.control then Synchronize(node) end
            if node.children then RefreshValues(node.children) end
        end
    end
    frame:SetScript("OnHide", Cleanup)
    function state:Show() frame:Show(); self.Reflow(); return true end
    function state:Hide() frame:Hide(); Cleanup(); return true end
    function state:Refresh()
        if not frame:IsVisible() or self.reflowBusy then return true end
        -- A setting can refresh its product while a multi-select is still open.
        -- Synchronize values without running geometry cleanup or closing menus.
        RefreshValues(self.tree); self.RefreshEnabled()
        for _,view in ipairs(self.profileViews or {}) do if view.frame:IsVisible() then view.Refresh() end end
        return true
    end
    function state:OnResize() self.Reflow() end
    Lib.Core.SettingsSearch.Apply(state.tree, "")
    return state
end

-- The feature-page header, tab strip and compact body follow Action Bars.
-- Domain schemas still own which settings and sections appear inside each tab.
function SettingsHost.CreateTabbedPanel(parent,product,host,options)
    options=options or {}
    local shell=UI.CreateContainer(nil,parent);shell:SetAllPoints(parent);shell.bootyTextSizeDelta=-2
    local header=UI.CreateToolbarSurface(shell,false,true)
    local heading=UI.CreateHeading(header,product.name,2,"gold",UI.GetProductIcon(product))
    heading:SetPoint("LEFT",header,"LEFT",12,0);heading:SetHeight(24);heading:SetJustifyH("LEFT")
    local navigation=UI.CreateToolbarSurface(shell,false,true)
    local body=UI.CreateContainer(nil,shell)
    local state=SettingsHost.CreatePanel(body,product,host)
    state.layoutHost=parent;state.allTree=state.tree;state.sections={};state.buttons={};state.selectionOrder={}
    state.header,state.heading,state.navigation,state.navigationFrame=header,heading,navigation,navigation
    state.sectionHeadingLevel=3
    for _,root in ipairs(state.allTree) do
        if root.productId==product.id then
            for _,section in ipairs(root.children) do state.sections[section.key]=section;table.insert(state.selectionOrder,section.key) end
        end
    end
    for _,root in ipairs(state.allTree) do
        if root.productId~=product.id then state.sections[root.key]=root;table.insert(state.selectionOrder,root.key) end
    end
    if options.prepareSections then options.prepareSections(state.sections) end
    Lib.Core.SettingsSearch.Index(state.allTree)
    local baseShow,baseHide,baseResize=state.Show,state.Hide,state.OnResize
    local tabRow={}
    function state:SelectSection(key)
        local section=self.sections[key];if not section then return false end
        if self.selectedSection~=key then
            baseHide(self)
            for _,node in ipairs(self.tree) do node.visible=false end
            baseShow(self)
            self.selectedSection=key;self.tree=section.children
            Lib.Core.SettingsSearch.Apply(self.tree,"");self.search:SetText("")
            for _,node in ipairs(self.tree) do if node.key=="General" then node.expanded=true end end
            self.viewport:SetVerticalScroll(0)
        end
        for id,button in pairs(self.buttons) do UI.SetOpenButtonBorder(button,id==key,"bottom") end
        self:OnResize();return true
    end
    for _,key in ipairs(state.selectionOrder) do
        local id=key
        local button=UI.CreateSelectionButton(navigation,nil,id,104,26)
        button:SetScript("OnClick",function() state:SelectSection(id) end)
        button.bootyTabWidth=math.max(82,math.ceil(button.label:GetStringWidth())+24)
        state.buttons[id]=button;table.insert(tabRow,button)
    end
    function state:OnResize()
        if not shell:IsVisible() then return end
        local width,height=UI.GetFrameSpan(parent);width,height=math.max(1,width),math.max(1,height)
        shell:SetWidth(width);shell:SetHeight(height)
        header:ClearAllPoints();header:SetPoint("TOPLEFT",shell,"TOPLEFT",0,0);header:SetWidth(width);header:SetHeight(36)
        heading:SetWidth(math.max(1,width-24))
        navigation:ClearAllPoints();navigation:SetPoint("TOPLEFT",shell,"TOPLEFT",0,-36);navigation:SetWidth(width)
        for _,button in ipairs(tabRow) do button:SetWidth(math.min(button.bootyTabWidth,math.max(1,width-16))) end
        local navigationHeight=UI.LayoutFlow(navigation,tabRow,8,8,math.max(1,width-16),6)+8
        navigation:SetHeight(navigationHeight)
        local top=36+navigationHeight+8
        body:ClearAllPoints();body:SetPoint("TOPLEFT",shell,"TOPLEFT",0,-top)
        body:SetWidth(width);body:SetHeight(math.max(1,height-top))
        baseResize(self)
    end
    function state:Show()
        shell:Show()
        if not self.selectedSection then return self:SelectSection(options.defaultSection or "General") end
        self:OnResize();return baseShow(self)
    end
    function state:Hide() baseHide(self);shell:Hide();return true end
    shell:Hide();return state
end

function SettingsHost.Toggle(product,host,providers)
    local state=SettingsHost.windows[product.id or product.name]
    if state and state.window:IsShown() and not state.window.minimized then state.window:Hide();return state end
    return SettingsHost.Open(product,host,providers)
end
function SettingsHost.Open(product, host, providers)
    local owner = product.id or product.name
    local state = SettingsHost.windows[owner]
    if state then
        if UI.WindowStack then UI.WindowStack.SetOwner(state.window, host.window) end
        state.window.Open(); state.Reflow(); return state
    end
    local window
    state = {host = host, ownerName = product.name}
    providers = providers or {product}
    state.tree = SettingsHost.BuildTree(providers, host.integrated, product)
    AddProfiles(state, product, providers)
    state.RefreshPreviews = function()
        if state.previewBusy or not state.window or not state.window:IsVisible() then return end
        state.previewBusy = true
        local ok, changed = pcall(RefreshVisiblePreviews, state)
        state.previewBusy = nil
        if not ok then error(changed, 0) end
        if changed and not state.reflowBusy and not state.layingOut then state.Reflow() end
    end
    state.RefreshEnabled = function() RefreshNodes(state.tree); state.RefreshPreviews() end
    state.Layout = function()
        CloseChoices(state.tree); ClearLayout(state.tree)
        if state.profileNode and state.profileNode.control and state.profileNode.control.panel then state.profileNode.control.panel:Hide() end
        if state.reset then
            state.search:SetWidth(math.max(70, math.min(250, state.window:GetWidth() - 16 - 66)))
        end
        local y = -4
        state.requiredContentWidth = 1
        y = LayoutNodes(state.tree, state.page, state, 0, y)
        HideUnused(state.tree)
        state.page.settingsContentHeight = math.max(1, -y + 4)
        if not state.geometryOnly then state.RefreshEnabled() end
        if not state.layingOut then
            UI.Settings.UpdateScroll(state.viewport, state.page, state.page.settingsContentHeight)
            ApplyFieldMinimum(state)
        end
    end
    state.Reflow = function()
        if state.window.minimized then return end
        if state.layingOut then return state.Layout() end
        if state.reflowBusy then return end
        state.reflowBusy = true
        state.viewport:SetScript("OnUpdate", nil); state.resizeQueued = nil
        local ok, failure = pcall(state.Layout)
        state.reflowBusy = nil
        if not ok then error(failure, 0) end
        state.layoutReady = true
        state.lastWindowWidth, state.lastWindowHeight, state.lastPageWidth = state.window:GetWidth(), state.window:GetHeight(), state.page:GetWidth()
    end
    state.Resize = function()
        if state.reflowBusy or state.window.minimized or not state.window:IsVisible() then return end
        if not state.layoutReady then state.Reflow(); return end
        if state.window:GetWidth() == state.lastWindowWidth and state.window:GetHeight() == state.lastWindowHeight and state.page:GetWidth() == state.lastPageWidth then return end
        if not state.resizeQueued then
            state.resizeQueued = true
            state.viewport:SetScript("OnUpdate", ResizeSettingsTick)
        end
    end
    window = UI.Window.Create({name = product.name .. "SettingsWindow", title = product.name .. " Settings", icon = "settings", compact = true, plainHeader = true, owner = host.window,
        viewportWidthInset = 16, viewportHeightInset = 74,
        attach = function(_, content)
            state.toolbar:SetParent(content); state.toolbar:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -2); state.toolbar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -4, -2)
            state.viewport:SetParent(content); state.viewport:SetPoint("TOPLEFT", content, "TOPLEFT", 4, -36); state.viewport:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -4, 4)
            state.viewport.bootyScrollAnchor = content; state.viewport.bootyScrollTop = 36
        end,
        update = function() state.Resize() end, refresh = function() state.Reflow() end})
    state.window = window
    local hidden = window:GetScript("OnHide")
    window:SetScript("OnHide", function()
        if hidden then hidden() end
        window:SetScript("OnUpdate", nil)
        state.viewport:SetScript("OnUpdate", nil); state.resizeQueued = nil
        CommitPending(state.tree); CloseChoices(state.tree)
        CloseProfiles(state)
        if state.profileConfirm then state.profileConfirm:Hide() end
        state.search:ClearFocus()
    end)
    state.toolbar = UI.CreateContainer(nil, window.content); state.toolbar:SetHeight(32)
    UI.SetSurfaceHorizontalBorders(state.toolbar, false, true)
    state.search = UI.CreateFramedEditBox(state.toolbar, nil, 250)
    state.search:SetPoint("LEFT", state.toolbar, "LEFT", 0, 0); state.search:SetHeight(24)
    UI.AttachTooltip(state.search, "Search settings", "Filter labels and their full section path. Open sections to inspect matching fields.")
    state.search:SetScript("OnTextChanged", function()
        Lib.Core.SettingsSearch.Apply(state.tree, this:GetText())
        state.viewport:SetVerticalScroll(0); state.Reflow()
    end)
    state.search:SetScript("OnEscapePressed", function() this:SetText(""); this:ClearFocus() end)
    UI.AttachPlaceholder(state.search, "Search settings")
    if state.ProfileContext then
        state.reset = UI.CreateButton(state.toolbar, nil, "Reset", 58, 24)
        UI.StyleActionButton(state.reset); state.reset:SetPoint("RIGHT", state.toolbar, "RIGHT", 0, 0)
        UI.AttachTooltip(state.reset, "Reset settings to defaults", "Reset only preferences for the addons shown in this window. Saved raids, loot and guild data are retained.")
        state.reset:SetScript("OnClick", function()
            CommitPending(state.tree)
            Confirm(state, "Reset settings", "Reset these settings to defaults? Saved raids, loot and guild data are retained.", "Reset", function()
                local _, message = state.ProfileContext.ResetDefaults()
                if state.profiles then state.profiles.status:SetText(message); state.Reflow()
                elseif host.Print then host.Print(message) end
            end)
        end)
    end
    serial = serial + 1
    state.viewport = UI.CreateScrollFrame("BootySettingsViewport" .. serial, window.content, "UIPanelScrollFrameTemplate")
    state.scrollBar = getglobal(state.viewport:GetName() .. "ScrollBar")
    if state.scrollBar then UI.RegisterSkinnedScrollBar(state.scrollBar) end
    state.viewport:EnableMouseWheel(true)
    state.viewport:SetScript("OnMouseWheel", function()
        local maximum = math.max(0, state.page.settingsContentHeight - math.max(1, window:GetHeight() - 74))
        state.viewport:SetVerticalScroll(state.viewport:GetVerticalScroll() - (arg1 or 0) * 36)
        UI.ApplyScrollRange(state.viewport, state.scrollBar, maximum)
    end)
    state.viewport:SetScript("OnHide", function()
        state.viewport:SetScript("OnUpdate", nil); state.resizeQueued = nil
        CommitPending(state.tree); CloseChoices(state.tree); state.search:ClearFocus()
        CloseProfiles(state)
        if state.profileConfirm then state.profileConfirm:Hide() end
    end)
    state.page = UI.CreateContainer(nil, state.viewport); state.page:SetWidth(700); state.page:SetHeight(1)
    -- Preserve the compact Settings typography used before the product split.
    -- This presentation scope does not alter any saved feature font preference.
    state.page.bootyTextSizeDelta = -2
    state.page.ReflowSettings = function()
        state.layingOut = true
        local ok, failure = pcall(state.Reflow)
        state.layingOut = nil
        if not ok then error(failure, 0) end
    end
    state.viewport.bootySettingsState = state
    state.viewport:SetScrollChild(state.page)
    state.viewport:SetScript("OnSizeChanged", function() if state.page then state.Resize() end end)
    window.AttachView(state)
    Lib.Core.SettingsSearch.Apply(state.tree, "")
    SettingsHost.windows[owner] = state
    window.Open()
    return state
end
