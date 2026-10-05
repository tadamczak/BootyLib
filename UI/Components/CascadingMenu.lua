local UI = BootyLib.UI.Components
local serial = 0
local DEPTH_LIMIT, ROW_HEIGHT, GAP = 4, 20, 2
local BRANCH_GAP = 1
local ICON_PATH = "Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\Icons\\"

local function SetRowText(row, text) row.label:SetText(text) end
local function GetRowText(row) return row.label:GetText() end

-- Presentation data only: text, enabled, children, action/data, checked,
-- optional gold icon key and keepOpen. One pooled popup per depth.
function UI.CreateCascadingMenu(onChoose, options)
    options = options or {}
    serial = serial + 1
    local menu = {panels = {}, onChoose = onChoose}
    local fontSize = options.fontSize or 11
    local function ClearAfter(depth)
        for index = table.getn(menu.panels), depth + 1, -1 do
            local panel = menu.panels[index]
            if panel.entries or panel:IsShown() then
                panel:Hide(); panel.entries, panel.parentRow = nil, nil
                for _, row in ipairs(panel.options) do row.entry = nil; row:Hide() end
            end
        end
    end
    function menu:Close()
        if self.closing then return end
        self.closing = true; ClearAfter(0)
        if self.panels[1] then self.panels[1].dismiss:Hide() end
        if UI.openDropdownPanel == self.panels[1] then UI.openDropdownPanel = nil end
        self.anchor = nil; self.closing = false
    end
    local function Click()
        local row = this.menuRow or this
        if not row.entry or row.entry.enabled == false then return end
        if row.entry.children and not row.entry.action then menu:OpenBranch(row); return end
        local action, data, keepOpen = row.entry.action, row.entry.data, row.entry.keepOpen
        if not keepOpen then menu:Close() end
        if action then menu.onChoose(action, data) end
        if keepOpen then menu:RefreshVisible() end
    end
    local function Enter()
        local row = this.menuRow or this
        if not row.entry or row.entry.enabled == false then return end
        if row.entry.children then menu:OpenBranch(row) else ClearAfter(row.menuDepth) end
    end
    local function EnsurePanel(depth)
        local panel = menu.panels[depth]
        if panel then return panel end
        panel = UI.CreateDropdownPanel(UIParent, UIParent, 110, 32, 100)
        panel:SetFrameStrata("FULLSCREEN_DIALOG"); panel:SetFrameLevel(201 + depth * 5)
        if options.backgroundTexture then
            panel.art = UI.CreateAspectImage(panel, options.backgroundTexture, options.backgroundAspect or 1,
                options.backgroundAlpha or 0.16, options.backgroundUVBottom or 1)
        else panel.art = UI.CreatePerformanceBackground(panel, 0.12) end
        panel.host = UI.CreateContainer(nil, panel)
        panel.canvas = UI.CreateResponsiveCanvas(panel.host, "MOSQuickMenuCanvas" .. serial .. "Depth" .. depth)
        panel:SetScript("OnShow", function() end)
        panel:SetScript("OnHide", function()
            if depth == 1 then menu:Close() else ClearAfter(depth) end
        end)
        panel.dismiss:SetFrameStrata("FULLSCREEN_DIALOG"); panel.dismiss:SetFrameLevel(200)
        panel.dismiss:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        panel.dismiss:SetScript("OnClick", function() menu:Close() end)
        table.insert(menu.panels, panel)
        panel.mosDropdownRoot = menu.panels[1]
        return panel
    end
    local function EnsureRow(panel, depth, index)
        local row = panel.options[index]
        if row then return row end
        row = UI.CreateMenuItem(panel.canvas, "", 102, ROW_HEIGHT)
        row.SetText, row.GetText = SetRowText, GetRowText
        row.mosLabelJustify, row.mosFitFontSize = "LEFT", fontSize
        row.menuDepth, row.menuIndex = depth, index
        row:SetScript("OnClick", Click); row:SetScript("OnEnter", Enter)
        row.icon = UI.CreateTexture(row, nil, "OVERLAY")
        row.icon:SetWidth(10); row.icon:SetHeight(10)
        row.icon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
        row.icon:Hide()
        row.arrow = UI.CreateTexture(row, nil, "OVERLAY")
        row.arrow:SetTexture(ICON_PATH .. "chevron_right.tga")
        row.arrow:SetVertexColor(unpack(UI.Theme.colors.goldIcon)); row.arrow:SetWidth(10); row.arrow:SetHeight(10)
        row.arrow:SetPoint("RIGHT", row, "RIGHT", -5, 0)
        row.check = UI.CreateCheckButton(nil, row, "UICheckButtonTemplate")
        row.check:SetWidth(16); row.check:SetHeight(16); row.check:SetPoint("LEFT", row, "LEFT", 3, 0)
        row.check.menuRow = row; row.check:SetScript("OnClick", Click); row.check:SetScript("OnEnter", Enter)
        if row.label.SetWordWrap then row.label:SetWordWrap(false) end
        if row.label.SetNonSpaceWrap then row.label:SetNonSpaceWrap(false) end
        table.insert(panel.options, row)
        return row
    end
    local function ApplyLayers(panel, depth)
        if UI.WindowStack then
            UI.WindowStack.SetOwner(panel, depth == 1 and menu.anchor or menu.panels[depth - 1])
            UI.WindowStack.Attach(panel.dismiss, UI.WindowStack.GetWindow(menu.anchor) and menu.anchor or panel, -1)
            UI.WindowStack.Sync(panel)
            return
        end
        local level = (menu.baseLevel or 201) + depth * 5
        panel:SetFrameLevel(level); panel.host:SetFrameLevel(level + 1)
        local viewport = panel.canvas.layoutViewport
        if viewport then viewport:SetFrameLevel(level + 2) end
        panel.canvas:SetFrameLevel(level + 3)
        local bar = viewport and getglobal(viewport:GetName() .. "ScrollBar")
        if bar then bar:SetFrameLevel(level + 4) end
        panel.dismiss:SetFrameLevel(menu.dismissLevel or 200)
        for index = 1, table.getn(panel.options) do
            local row = panel.options[index]
            row:SetFrameLevel(level + 4); row.check:SetFrameLevel(level + 5)
        end
    end
    local function Present(row)
        local entry = row.entry
        local text, icon = entry.text or "", entry.icon
        local geometryChanged = row.presentedText ~= text or row.presentedIcon ~= icon
            or row.presentedChecked ~= (entry.checked ~= nil) or row.presentedBranch ~= (entry.children ~= nil)
        if row.presentedText ~= text then
            row:SetText(string.find(text, "[\r\n]") and string.gsub(text, "[\r\n]+", " ") or text)
            row.presentedText = text
        end
        if row.presentedIcon ~= icon then
            if icon then row.icon:SetTexture(ICON_PATH .. icon .. ".tga"); row.icon:Show() else row.icon:Hide() end
            row.presentedIcon = icon
        end
        if row.presentedEnabled ~= (entry.enabled ~= false) then
            local enabled = entry.enabled ~= false
            if enabled then row:Enable(); row.check:Enable() else row:Disable(); row.check:Disable() end
            row.label:SetTextColor(unpack(enabled and UI.TextColors.gold or UI.TextColors.gray))
            row.icon:SetAlpha(enabled and 1 or 0.35); row.arrow:SetAlpha(enabled and 1 or 0.35)
            row.presentedEnabled = enabled
        end
        if entry.checked ~= nil then row.check:SetChecked(entry.checked and 1 or nil); row.check:Show() else row.check:Hide() end
        if entry.children then row.arrow:Show() else row.arrow:Hide() end
        row.presentedChecked, row.presentedBranch = entry.checked ~= nil, entry.children ~= nil
        row.captionLeft = 6 + (entry.checked ~= nil and 18 or 0) + (icon and 14 or 0)
        row.captionRight = entry.children and 20 or 6
        row.icon:ClearAllPoints(); row.icon:SetPoint("LEFT", row, "LEFT", 6 + (entry.checked ~= nil and 18 or 0), 0)
        return geometryChanged
    end
    local function LayoutRows(width, _, panel)
        local y = 0
        for index = 1, table.getn(panel.entries) do
            local row = panel.options[index]
            local label = row.label
            local captionWidth = math.max(1, width - row.captionLeft - row.captionRight)
            label:ClearAllPoints(); label:SetPoint("LEFT", row, "LEFT", row.captionLeft, 0)
            UI.FitButtonLabel(row, captionWidth); label:SetJustifyV("MIDDLE")
            row.menuOffset = y
            row:ClearAllPoints(); row:SetPoint("TOPLEFT", panel.canvas, "TOPLEFT", 0, -y)
            row:SetWidth(width); row:SetHeight(ROW_HEIGHT)
            y = y + ROW_HEIGHT + GAP
        end
        panel.contentHeight = math.max(1, y - GAP)
        return panel.contentHeight
    end
    local function LayoutArt(panel, width, height)
        if options.backgroundTexture then
            local aspect = panel.art.mosImageAspect
            local shownWidth, shownHeight = math.min(1, width / (height * aspect)), math.min(1, height * aspect / width)
            local right, bottom = options.backgroundUVRight or 1, options.backgroundUVBottom or 1
            panel.art:ClearAllPoints(); panel.art:SetPoint("CENTER", panel, "CENTER", 0, 0)
            panel.art:SetWidth(width); panel.art:SetHeight(height)
            panel.art:SetTexCoord((1 - shownWidth) * right / 2, (1 + shownWidth) * right / 2,
                (1 - shownHeight) * bottom / 2, (1 + shownHeight) * bottom / 2)
        else UI.LayoutPerformanceBackground(panel.art, panel, width, height) end
    end
    local function LayoutPanel(panel, depth, left, top, widthLimit, retainedWidth)
        local count = table.getn(panel.entries)
        local screenWidth, screenHeight = UI.GetFrameSpan(UIParent)
        if widthLimit then panel.menuWidthLimit = widthLimit end
        local contentHeight = math.max(1, count * (ROW_HEIGHT + GAP) - GAP)
        local height = math.max(32, math.min(contentHeight + 8, screenHeight - 16))
        local gutter = contentHeight > height - 8 and 20 or 0
        local width = options.minimumWidth or 110
        for index = 1, count do
            local row, label = panel.options[index], panel.options[index].label
            local font, _, flags = label:GetFont(); label:SetFont(font, fontSize, flags); label:SetWidth(0)
            width = math.max(width, math.ceil(label:GetStringWidth()) + row.captionLeft + row.captionRight + 10)
        end
        if retainedWidth then width = math.max(width, retainedWidth - gutter) end
        width = math.max(1, math.min(options.maximumWidth or screenWidth - 16, panel.menuWidthLimit or screenWidth - 16,
            screenWidth - 16, width + gutter))
        if depth > 1 then
            local total = width + BRANCH_GAP * (depth - 1)
            for index = 1, depth - 1 do total = total + menu.panels[index].menuWidth end
            if total > screenWidth - 16 then
                -- Only screen-constrained trees reduce fonts. Keep every
                -- visible ancestor distinct instead of covering its controls.
                local limit = math.max(1, math.floor((screenWidth - 16 - BRANCH_GAP * (depth - 1)) / depth))
                for index = 1, depth - 1 do
                    local ancestor = menu.panels[index]
                    LayoutPanel(ancestor, index, ancestor.menuLeft, ancestor.menuTop, math.min(ancestor.menuWidth, limit))
                end
                width = math.min(width, limit); panel.menuWidthLimit = width
            end
            local minimum, maximum = screenWidth, 0
            for index = 1, depth - 1 do
                local ancestor = menu.panels[index]
                minimum = math.min(minimum, ancestor.menuLeft)
                maximum = math.max(maximum, ancestor.menuLeft + ancestor.menuWidth)
            end
            local right, leftSide = maximum + BRANCH_GAP, minimum - width - BRANCH_GAP
            local direction = menu.panels[depth - 1].menuDirection or 1
            if direction < 0 and leftSide >= 8 then left = leftSide
            elseif right + width <= screenWidth - 8 then direction, left = 1, right
            elseif leftSide >= 8 then direction, left = -1, leftSide
            else
                local shift
                if direction < 0 then shift, left = 8 - leftSide, 8
                else shift = screenWidth - 8 - right - width; left = right + shift end
                for index = 1, depth - 1 do
                    local ancestor = menu.panels[index]
                    ancestor.menuLeft = ancestor.menuLeft + shift
                    ancestor:ClearAllPoints(); ancestor:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", ancestor.menuLeft, ancestor.menuTop)
                end
            end
            panel.menuDirection = direction
        else left = math.max(8, math.min(screenWidth - width - 8, left)); panel.menuDirection = nil end
        top = math.max(height + 8, math.min(screenHeight - 8, top))
        panel.menuLeft, panel.menuTop, panel.menuWidth = left, top, width
        panel:ClearAllPoints(); panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
        panel:SetWidth(width); panel:SetHeight(height)
        panel.host:ClearAllPoints(); panel.host:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
        panel.host:SetWidth(width - 8); panel.host:SetHeight(height - 8)
        UI.LayoutResponsiveCanvas(panel.canvas, LayoutRows, panel, width - 8, height - 8)
        LayoutArt(panel, width, height)
    end
    function menu:RefreshVisible()
        for depth, panel in ipairs(self.panels) do
            if panel:IsShown() and panel.entries then
                local changed = false
                for index = 1, table.getn(panel.entries) do
                    local row = panel.options[index]
                    if Present(row) then changed = true end
                end
                if changed then LayoutPanel(panel, depth, panel.menuLeft, panel.menuTop, nil, panel.menuWidth) end
            end
        end
    end
    UI.RegisterSkinCallback(function()
        for depth, panel in ipairs(menu.panels) do
            if panel:IsShown() and panel.entries then LayoutPanel(panel, depth, panel.menuLeft, panel.menuTop) end
        end
    end)
    function menu:ShowPanel(depth, entries, left, top)
        if depth > DEPTH_LIMIT then return false end
        ClearAfter(depth)
        local panel = EnsurePanel(depth)
        if panel.entries ~= entries then panel.canvas.layoutViewport:SetVerticalScroll(0) end
        panel.entries, panel.menuWidthLimit = entries, nil
        local count = table.getn(entries)
        for index = 1, count do
            local row = EnsureRow(panel, depth, index)
            row.entry = entries[index]; Present(row); row:Show()
        end
        for index = count + 1, table.getn(panel.options) do panel.options[index].entry = nil; panel.options[index]:Hide() end
        ApplyLayers(panel, depth)
        LayoutPanel(panel, depth, left, top)
        if UI.WindowStack then UI.WindowStack.Sync(panel) end
        panel:Show(); panel.dismiss:Hide()
        return true
    end
    function menu:OpenBranch(row)
        if not row.entry or row.entry.enabled == false or not row.entry.children then return false end
        if row.menuDepth >= DEPTH_LIMIT then return false end
        local child = self.panels[row.menuDepth + 1]
        if child and child:IsShown() and child.parentRow == row and child.entries == row.entry.children then return true end
        local parent = self.panels[row.menuDepth]
        local scroll = parent.canvas.layoutViewport:GetVerticalScroll()
        local opened = self:ShowPanel(row.menuDepth + 1, row.entry.children,
            parent.menuLeft + parent.menuWidth + BRANCH_GAP, parent.menuTop - 4 - row.menuOffset + scroll)
        if opened then self.panels[row.menuDepth + 1].parentRow = row end
        return opened
    end
    function menu:IsOpen() return self.panels[1] and self.panels[1]:IsShown() or false end
    function menu:Open(anchor, entries)
        self:Close()
        if UI.openDropdownPanel then UI.openDropdownPanel:Hide() end
        self.anchor = anchor
        local anchorLevel = anchor and anchor.GetFrameLevel and tonumber(anchor:GetFrameLevel()) or 0
        self.baseLevel = math.max(201, anchorLevel + 2)
        self.dismissLevel = math.max(200, anchorLevel - 1)
        local x, y = GetCursorPosition()
        local scale = UIParent:GetEffectiveScale() or 1
        self:ShowPanel(1, entries, x / scale + 8, y / scale)
        local root = self.panels[1]
        root.toggle = anchor
        UI.openDropdownPanel = root; root.dismiss:Show()
    end
    return menu
end
