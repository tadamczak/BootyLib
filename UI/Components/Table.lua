local Booty = BootyLib
local UI = Booty.UI.Components

UI.Table = UI.Table or {}
local Table = UI.Table

function Table.ApplyHeaderHover(button)
    local highlight = button.headerHighlight
    if not highlight then highlight = UI.CreateTexture(button, nil, "HIGHLIGHT"); button.headerHighlight = highlight end
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 6, 0)
    highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    UI.ApplyGoldRadialHighlight(highlight)
    highlight:SetTexCoord(0.5, 1, 0, 1)
    local lead = button.headerHighlightLead
    if not lead then lead = UI.CreateTexture(button, nil, "HIGHLIGHT"); button.headerHighlightLead = lead end
    lead:ClearAllPoints(); lead:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    lead:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0); lead:SetWidth(6)
    UI.ApplyGoldRadialHighlight(lead); lead:SetTexCoord(0, 0.5, 0, 1)
    button:SetScript("OnEnter", nil); button:SetScript("OnLeave", nil)
end

local function OnHeaderClick() this.headerController.onSort(this.sortKey) end

function Table.CreateHeader(parent, controller, text, x, y, width, key, sortable)
    local button = UI.CreateControl(nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y); button:SetWidth(width); button:SetHeight(22)
    button.baseText = text; button.sortKey = key; button.headerController = controller
    button.label = UI.CreateColumnLabel(button, "", "orange")
    button.label:SetAllPoints(button); button.label:SetJustifyH("LEFT"); button.label:SetText(text)
    Table.ApplyHeaderHover(button)
    if sortable then button:SetScript("OnClick", OnHeaderClick) end
    return button
end

-- Consume the full width while borrowing unused space from short columns.
function Table.AllocateColumnWidths(columns, available)
    local total, minimum, growth, index = 0, 0, 0, nil
    for index = 1, table.getn(columns) do
        total = total + columns[index].desiredWidth
        minimum = minimum + columns[index].minimumWidth
        growth = growth + (columns[index].growthWeight or columns[index].fraction)
    end
    local used = 0
    for index = 1, table.getn(columns) do
        local column = columns[index]
        local width
        if available >= total then width = column.desiredWidth + (available - total) * (column.growthWeight or column.fraction) / math.max(0.001, growth)
        elseif available >= minimum then width = column.minimumWidth + (available - minimum) * (column.desiredWidth - column.minimumWidth) / math.max(1, total - minimum)
        else width = available * column.minimumWidth / math.max(1, minimum) end
        column.width = index == table.getn(columns) and math.max(1, available - used) or math.max(1, math.floor(width))
        used = used + column.width
    end
end

function Table.Create(options)
    local parent, rows = options.parent, {}
    local scroll = UI.CreateScrollFrame(options.name, parent, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", options.x - 4, options.scrollTop)
    scroll:SetWidth(options.width); scroll:SetHeight(options.scrollHeight)
    scroll.refreshCallback = options.refresh
    scroll:SetScript("OnVerticalScroll", options.onScroll)
    UI.RegisterSkinnedScrollBar(getglobal(options.name .. "ScrollBar"))
    local index, columnIndex
    for index = 1, options.rowCount do
        local row = UI.CreateControl(nil, parent)
        row:SetPoint("TOPLEFT", parent, "TOPLEFT", options.x, options.rowTop - ((index - 1) * options.rowStep))
        row:SetWidth(options.width - 16); row:SetHeight(options.rowHeight)
        local backdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } }
        row:SetBackdrop(backdrop); row:SetBackdropColor(0, 0, 0, 0); row:SetBackdropBorderColor(0, 0, 0, 0)
        UI.RegisterSkinnedSurface(row, "row", backdrop, { 0, 0, 0, 0 }, { 0, 0, 0, 0 })
        for columnIndex = 1, table.getn(options.columns) do
            local column = options.columns[columnIndex]
            local region
            if column.texture then region = UI.CreateTexture(row, nil, "ARTWORK")
            else region = UI.CreateLabel(row, nil, "OVERLAY", column.font or "GameFontHighlightSmall") end
            region:SetPoint(column.side, row, column.side, column.x, 0); region:SetWidth(column.width)
            if column.height then region:SetHeight(column.height) end
            if not column.texture then region:SetJustifyH(column.side) end
            row[column.key] = region
        end
        if options.bindRow then options.bindRow(row) end
        row:Hide(); rows[index] = row
    end
    scroll:Hide()
    return { scroll = scroll, rows = rows }
end

function UI.CalculateVisibleRows(containerHeight, reservedHeight, rowHeight, rowPoolSize, minimum)
    return math.max(minimum or 3, math.min(rowPoolSize, math.floor((containerHeight - reservedHeight) / rowHeight)))
end

function UI.SetScrollBarVisible(slider, shown)
    if not slider then return end
    local sliderName = slider:GetName()
    local upButton = sliderName and getglobal(sliderName .. "ScrollUpButton")
    local downButton = sliderName and getglobal(sliderName .. "ScrollDownButton")
    if shown then
        slider:Show(); if upButton then upButton:Show() end; if downButton then downButton:Show() end
    else
        slider:Hide(); if upButton then upButton:Hide() end; if downButton then downButton:Hide() end
    end
end

function UI.UpdateScrollFrame(scrollFrame, totalRows, visibleRows, rowHeight)
    local offset = math.max(0, math.min(FauxScrollFrame_GetOffset(scrollFrame) or 0, math.max(0, totalRows - visibleRows)))
    scrollFrame.offset = offset
    FauxScrollFrame_Update(scrollFrame, totalRows, visibleRows, rowHeight)
    local slider = scrollFrame:GetName() and getglobal(scrollFrame:GetName() .. "ScrollBar")
    if slider and slider:GetValue() ~= offset * rowHeight then slider:SetValue(offset * rowHeight) end
    if totalRows > visibleRows then
        scrollFrame:Show()
        UI.SetScrollBarVisible(slider, true)
    else
        scrollFrame:Hide()
        -- In the 1.12 templates the named slider may be parented beside the
        -- logical scroll frame, so hiding only the frame can leave its arrows.
        UI.SetScrollBarVisible(slider, false)
    end
    return offset
end

function UI.ApplyRowBackground(row, absoluteIndex, selected)
    local colors = UI.Theme.colors
    if selected then
        row:SetBackdropColor(colors.rowSelected[1], colors.rowSelected[2], colors.rowSelected[3], colors.rowSelected[4])
        row:SetBackdropBorderColor(colors.rowSelectedBorder[1], colors.rowSelectedBorder[2], colors.rowSelectedBorder[3], colors.rowSelectedBorder[4])
    elseif math.mod(absoluteIndex, 2) == 0 then
        row:SetBackdropColor(colors.rowAlternate[1], colors.rowAlternate[2], colors.rowAlternate[3], colors.rowAlternate[4])
        row:SetBackdropBorderColor(0, 0, 0, 0)
    else
        row:SetBackdropColor(0, 0, 0, 0); row:SetBackdropBorderColor(0, 0, 0, 0)
    end
end

-- A single rectangle owns rows and the optional scrollbar gutter.
local function MeasureFixedRows(_, context) return context.totalHeight end
function Table.LayoutViewport(scroll, parent, x, y, width, height, count, step, poolSize)
    height = math.max(step, height)
    local visible = math.max(1, math.min(poolSize, math.floor(height / step)))
    scroll.totalHeight = count * step
    local contentWidth = UI.ResolveScrollLayout(math.max(1, width), visible * step, 20, MeasureFixedRows, scroll)
    scroll:ClearAllPoints(); scroll:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    scroll:SetWidth(contentWidth); scroll:SetHeight(visible * step)
    local offset = UI.UpdateScrollFrame(scroll, count, visible, step)
    local bar = scroll:GetName() and getglobal(scroll:GetName() .. "ScrollBar")
    if bar then
        bar:ClearAllPoints(); bar:SetPoint("TOPLEFT", parent, "TOPLEFT", x + contentWidth + 4, -y - 16)
        bar:SetHeight(math.max(1, visible * step - 32)); bar:SetWidth(16)
        -- Faux scrolling is a logical row offset, not a native scroll child.
        local maximum=math.max(0,count-visible)*step
        bar:SetMinMaxValues(0,maximum)
        if bar:GetValue()~=offset*step then bar:SetValue(offset*step) end
        UI.SetScrollBarVisible(bar,maximum>0)
    end
    return offset, visible, contentWidth
end
function Table.Cell(label, owner, x, width, height, text)
    label:ClearAllPoints(); label:SetPoint("TOPLEFT", owner, "TOPLEFT", x, 0)
    label:SetWidth(math.max(1,width)); label:SetHeight(height); label:SetJustifyH("LEFT"); label:SetJustifyV("MIDDLE")
    if label.SetWordWrap then label:SetWordWrap(false) end
    if label.SetNonSpaceWrap then label:SetNonSpaceWrap(false) end
    if text ~= nil then label:SetText(text) end
end
function Table.FitHeaders(headers, baseSize)
    local scale, index = 1, nil
    for index=1,table.getn(headers) do
        local label=headers[index].label
        local font, _, flags=label:GetFont(); label:SetFont(font,baseSize or 12,flags); label:SetWidth(0)
        scale=math.min(scale,math.max(1,headers[index]:GetWidth()-4)/math.max(1,label:GetStringWidth()))
    end
    for index=1,table.getn(headers) do
        local header=headers[index]; local font, _, flags=header.label:GetFont()
        header.label:SetFont(font,(baseSize or 12)*scale,flags)
        Table.Cell(header.label,header,0,header:GetWidth(),header:GetHeight())
    end
end
