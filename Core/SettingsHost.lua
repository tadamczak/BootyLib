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
function SettingsHost.BuildTree(providers, integrated, product)
    local roots = {}
    local ownerView = product and product.views and product.views[1]
    local ownerLabel = not integrated and product and (product.settingsLabel or ownerView and ownerView.label or product.title or product.name)
    for _, provider in ipairs(providers) do
        local schema = provider.GetSettings and provider.GetSettings()
        if schema then
            for _, field in ipairs(schema.fields or {}) do
                if not field.profileOnly then
                local path = field.path or {}
                local caption = ownerLabel or integrated and provider.id == "profiler" and "Profiler"
                if caption and path[1] ~= caption then
                    local nested = {caption}; for _, item in ipairs(path) do table.insert(nested, item) end; path = nested
                end
                local children = AddPath(roots, path)
                table.insert(children, {text = field.label or field.key, key = field.key, field = field, db = schema.db, provider = provider})
                end
            end
        end
    end
    if ownerLabel and roots[1] then roots[1].icon = ownerView and ownerView.icon end
    Lib.Core.SettingsSearch.Index(roots)
    return roots
end
local function GetValue(node)
    local field = node.field
    local value
    if field.get then value = field.get(node.db) else value = node.db[field.key] end
    if value == nil then
        if field.default ~= nil then return field.default end
        if field.type == "slider" then return field.min or 0 end
        if field.type == "color" then return defaultColor end
    end
    return value
end
local function SetValue(node, value, state)
    local field = node.field
    if field.set then field.set(value, node.db) else node.db[field.key] = value end
    if field.onChange then field.onChange(value) end
    if node.provider.OnSettingChanged then node.provider.OnSettingChanged(field.key) end
    if node.provider.OnSettingsChanged then node.provider.OnSettingsChanged(field.key) end
    if state and state.host.ApplySettings then state.host.ApplySettings() end
end
local function CommitPending(nodes)
    for _, node in ipairs(nodes) do
        if node.field and node.control and node.control.CommitValue and node.control.mosEditing then
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
local function CreateProfileControls(node, page, state)
    local api, view = state.ProfileContext, {rows = {}, first = 1}
    view.frame = UI.CreateContainer(nil, page)
    node.control, node.profileView, state.profiles = view.frame, view, view
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
                    control.mosFlowWidth = math.min(control == view.current and 180 or width, NaturalLabelWidth(control))
                    control:SetWidth(control.mosFlowWidth); control:SetHeight(math.max(16, NaturalLabelHeight(control, control.mosFlowWidth)))
                elseif control == view.name or control == view.select then control.mosFlowWidth = math.min(180, width)
                else control.mosFlowWidth = 58; control.mosFlowFitLabel = true end
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
    if kind == "checkbox" then
        control = UI.Settings.CreateCheckbox(page, 0, 0, node.text, field.key, nil, binding)
        node.height = 30
    elseif kind == "slider" then
        serial = serial + 1
        control = UI.Settings.CreateSlider(page, "BootySettingsSlider" .. serial, 0, 0, node.text, field.key, field.min or 0, field.max or 100, nil, binding)
        if field.step then control:SetValueStep(field.step) end
        node.height = 52
    elseif kind == "color" then
        control = UI.Settings.CreateColor(page, 0, 0, node.text, field.key, nil, binding); node.height = 32
    elseif kind == "dropdown" or kind == "choice" then
        local choices = {}
        for _, option in ipairs(field.choices or field.options or {}) do
            if type(option) == "table" then table.insert(choices, {text = option.text or option.label or tostring(option.value), value = option.value})
            else table.insert(choices, {text = tostring(option), value = option}) end
        end
        label, control = UI.CreateChoiceField({parent = page, x = 0, y = 0, label = node.text,
            initialText = tostring(GetValue(node) or ""), choices = choices, getValue = function() return GetValue(node) end,
            onSelect = function(value) SetValue(node, value, state); state.RefreshEnabled() end,
            width = 180, height = math.max(32, table.getn(choices) * 24 + 12), firstY = -7, step = 24,
            buttonOffset = 220, color = UI.TextColors.white})
        node.label = label; node.height = 36
    else
        label = UI.CreateComponentLabel(page, nil, "white"); label:SetText(node.text)
        control = UI.Settings.CreateSavedTextField(page, field.key, binding)
        if field.maxLength then control:SetMaxLetters(field.maxLength) end
        node.label = label; node.height = 58
    end
    node.control = control
    if field.tooltip then UI.AttachTooltip(control, node.text, field.tooltip) end
    return control
end
local function Synchronize(node)
    local control, field, value = node.control, node.field, GetValue(node)
    if field.type == "checkbox" then control:SetChecked(value and value ~= 0 and 1 or nil)
    elseif field.type == "slider" then UI.Settings.SynchronizeSlider(control, tonumber(value) or field.min or 0)
    elseif field.type == "color" then
        value = type(value) == "table" and value or defaultColor
        control.swatch:SetTexture(value[1] or 1, value[2] or 1, value[3] or 1, 1)
    elseif field.type == "choice" or field.type == "dropdown" then
        local caption = tostring(value or "")
        for _, choice in ipairs(control.choices) do if choice.value == value then caption = choice.text; break end end
        control:SetText(caption)
    elseif control.RefreshValue then control:RefreshValue() end
end
NaturalLabelWidth = function(label)
    local text = label:GetText()
    local font, size, flags
    if label.GetFont then font, size, flags = label:GetFont() end
    if label.mosNaturalText == text and label.mosNaturalFont == font and label.mosNaturalSize == size and label.mosNaturalFlags == flags and label.mosNaturalWidth then
        return label.mosNaturalWidth
    end
    label:SetWidth(0)
    local width = math.max(1, math.ceil(label:GetStringWidth()) + 2)
    label.mosNaturalText, label.mosNaturalFont, label.mosNaturalSize, label.mosNaturalFlags = text, font, size, flags
    label.mosNaturalWidth, label.mosNaturalHeight = width, nil
    return width
end
NaturalLabelHeight = function(label, width)
    if not label.mosNaturalHeight or label.mosNaturalHeightWidth ~= width then
        label.mosNaturalHeight = math.max(14, UI.MeasureTextHeight(label, width))
        label.mosNaturalHeightWidth = width
    end
    return label.mosNaturalHeight
end
local function MeasureField(node)
    local control, kind = node.control, node.field.type
    if node.label then
        local width = math.max(180, NaturalLabelWidth(node.label))
        if kind == "choice" or kind == "dropdown" then
            width = math.max(width, NaturalLabelWidth(control.label or control) + 32)
            for _, option in ipairs(control.panel.options) do
                width = math.max(width, NaturalLabelWidth(option.label or option) + 32)
            end
        end
        return width
    elseif kind == "slider" then
        local name = control:GetName()
        local label = getglobal(name .. "Text")
        local font, size, flags = label:GetFont()
        if node.mosSliderMeasureText == label:GetText() and node.mosSliderMeasureFont == font and node.mosSliderMeasureSize == size and node.mosSliderMeasureFlags == flags and node.mosSliderMeasureWidth then
            return node.mosSliderMeasureWidth
        end
        local caption, width = label:GetText(), NaturalLabelWidth(label)
        label:SetText(node.text .. ": " .. tostring(node.field.min or 0)); width = math.max(width, NaturalLabelWidth(label))
        label:SetText(node.text .. ": " .. tostring(node.field.max or 100)); width = math.max(width, NaturalLabelWidth(label))
        label:SetText(caption)
        width = math.max(170, width + 8,
            NaturalLabelWidth(getglobal(name .. "Low")) + NaturalLabelWidth(getglobal(name .. "High")) + 32)
        node.mosSliderMeasureText, node.mosSliderMeasureFont, node.mosSliderMeasureSize, node.mosSliderMeasureFlags = caption, font, size, flags
        node.mosSliderMeasureWidth = width
        return width
    end
    return (kind == "color" and 26 or control:GetWidth() + 2) + NaturalLabelWidth(control.label) + 4
end
local function LayoutField(node, page, x, y, width)
    local control, kind = node.control, node.field.type
    local label = node.label or control.label or kind == "slider" and getglobal(control:GetName() .. "Text")
    local labelWidth = label and NaturalLabelWidth(label)
    local labelHeight = label and NaturalLabelHeight(label, labelWidth)
    if node.mosLayoutX == x and node.mosLayoutY == y and node.mosLayoutWidth == width and node.mosLayoutLabelWidth == labelWidth and node.mosLayoutLabelHeight == labelHeight and control:IsShown() then return node.height end
    node.mosLayoutX, node.mosLayoutY, node.mosLayoutWidth = x, y, width
    node.mosLayoutLabelWidth, node.mosLayoutLabelHeight = labelWidth, labelHeight
    control:ClearAllPoints()
    if node.label then
        node.label:SetWidth(labelWidth)
        node.label:SetJustifyH("LEFT")
        node.label:SetHeight(labelHeight); node.label:Show()
        node.label:ClearAllPoints(); node.label:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
        control:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - labelHeight - 4)
        control:SetWidth(width)
        node.height = labelHeight + 4 + control:GetHeight() + 10
        if kind == "choice" or kind == "dropdown" then
            if control.mosDropdownText then control.mosTextWidth = nil; UI.ReflowControlText(control) end
            control.panel:SetWidth(control:GetWidth())
            for _, option in ipairs(control.panel.options) do
                option:SetWidth(math.max(1, width - 14))
                if option.label then option.label:SetWidth(math.max(1, width - 30)) end
            end
        end
    else
        control:SetPoint("TOPLEFT", page, "TOPLEFT", x, y - (kind == "slider" and 18 or 0))
        if kind == "slider" then
            control:SetWidth(width)
            label:SetWidth(labelWidth); label:SetJustifyH("LEFT")
            node.height = 52
        elseif control.label then
            control.label:SetWidth(labelWidth); control.label:SetJustifyH("LEFT")
            local height = math.max(control:GetHeight(), labelHeight)
            control.label:SetHeight(height)
            if kind == "color" then control:SetWidth(width) end
            if control.labelHit then control.labelHit:SetWidth(labelWidth); control.labelHit:SetHeight(height) end
            node.height = math.max(kind == "color" and 32 or 30, height + 8)
        end
    end
    control:Show()
    return node.height
end
local function Visible(node) return node.visible ~= false end
local function ToggleAccordion()
    -- Lua 5.0 clears a generic-for variable after traversal.
    -- Resolve the clicked node from its pooled control instead.
    local selected = this.mosSettingsNode
    selected.expanded = not selected.expanded; this.mosSettingsState.Reflow()
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
                    items = {mosNoWrap = true, mosMeasureItem = MeasureField, mosLayoutItem = LayoutField}
                    node.gridItems = items
                end
                while table.getn(items) > 0 do table.remove(items) end
                while index <= table.getn(nodes) and nodes[index].field do
                    local fieldNode = nodes[index]
                    if Visible(fieldNode) then
                        fieldNode.layoutVisible = true
                        if not fieldNode.control then CreateField(fieldNode, page, state); Synchronize(fieldNode)
                        elseif not state.geometryOnly then Synchronize(fieldNode) end
                        table.insert(items, fieldNode)
                    end
                    index = index + 1
                end
                y = y - UI.Settings.LayoutGrid(page, items, x, y, math.max(1, page:GetWidth() - x - 4), 0)
                state.requiredContentWidth = math.max(state.requiredContentWidth, x + items.mosRequiredWidth + 4)
                index = index - 1
            else
                if not node.control then
                    if depth == 0 then node.control = UI.Settings.CreateSectionAccordion(page, node.text, 0, 0, 2, node.icon or icons[node.text] or "list")
                    else node.control = UI.Settings.CreateAccordion(page, node.text, 0) end
                    node.control.mosSettingsNode = node
                    node.control.mosSettingsState = state
                    node.control:SetScript("OnClick", ToggleAccordion)
                end
                if node.mosLayoutX ~= x or node.mosLayoutY ~= y then
                    node.control:ClearAllPoints(); node.control:SetPoint("TOPLEFT", page, "TOPLEFT", x, y)
                    node.control:SetPoint("TOPRIGHT", page, "TOPRIGHT", -4, y)
                    node.mosLayoutX, node.mosLayoutY = x, y
                end
                if node.mosLayoutExpanded ~= node.expanded then
                    if node.control.indicator then node.control.indicator:SetText(node.expanded and "-" or "+") end
                    if node.control.SetExpanded then node.control:SetExpanded(node.expanded) end
                    node.mosLayoutExpanded = node.expanded
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
    local inset = state.viewport.mosWidthInset or 16
    local maximum = math.max(320, math.min(1100, UIParent:GetWidth() - 32))
    local required = math.max(math.min(350, maximum), state.requiredContentWidth + inset + (state.viewport.mosScrollGutter or 0))
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
    local state = this.mosSettingsState
    this:SetScript("OnUpdate", nil)
    state.resizeQueued = nil
    if state.window:IsVisible() and not state.window.minimized and (state.window:GetWidth() ~= state.lastWindowWidth or state.window:GetHeight() ~= state.lastWindowHeight or state.page:GetWidth() ~= state.lastPageWidth) then
        state.geometryOnly = true
        local ok, failure = pcall(state.Reflow)
        state.geometryOnly = nil
        if not ok then error(failure, 0) end
    end
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
    if Lib.Core.SettingsProfiles then
        state.ProfileContext = Lib.Core.SettingsProfiles.Create(providers, {id = owner,
            onApplied = function() if host.ApplySettings then host.ApplySettings() end; state.Reflow() end})
        state.profileNode = {key = "profileControls", text = "Current profile Load profile New profile Save Add Delete Export", profileControls = true}
        table.insert(state.tree, 1, {key = "Profile", text = "Profile", expanded = false, children = {
            {key = "General", text = "General", expanded = false, children = {state.profileNode}}
        }})
        Lib.Core.SettingsSearch.Index(state.tree)
    end
    state.RefreshEnabled = function() RefreshNodes(state.tree) end
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
            state.viewport.mosScrollAnchor = content; state.viewport.mosScrollTop = 36
        end,
        update = function() state.Resize() end, refresh = function() state.Reflow() end})
    state.window = window
    local hidden = window:GetScript("OnHide")
    window:SetScript("OnHide", function()
        if hidden then hidden() end
        window:SetScript("OnUpdate", nil)
        state.viewport:SetScript("OnUpdate", nil); state.resizeQueued = nil
        CommitPending(state.tree); CloseChoices(state.tree)
        if state.profiles then state.profiles.Close() end
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
        if state.profiles then state.profiles.Close() end
        if state.profileConfirm then state.profileConfirm:Hide() end
    end)
    state.page = UI.CreateContainer(nil, state.viewport); state.page:SetWidth(700); state.page:SetHeight(1)
    -- Preserve the compact Settings typography used before the product split.
    -- This presentation scope does not alter any saved feature font preference.
    state.page.mosTextSizeDelta = -2
    state.page.ReflowSettings = function()
        state.layingOut = true
        local ok, failure = pcall(state.Reflow)
        state.layingOut = nil
        if not ok then error(failure, 0) end
    end
    state.viewport.mosSettingsState = state
    state.viewport:SetScrollChild(state.page)
    state.viewport:SetScript("OnSizeChanged", function() if state.page then state.Resize() end end)
    window.AttachView(state)
    Lib.Core.SettingsSearch.Apply(state.tree, "")
    SettingsHost.windows[owner] = state
    window.Open()
    return state
end
