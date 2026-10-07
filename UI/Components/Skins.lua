local MOS = BootyLib
local UI = MOS.UI.Components

UI.Skins = UI.Skins or {}
local Skins = UI.Skins
local CLASSIC_ROOT = "Interface\\AddOns\\BootyLib\\Assets\\Skins\\Classic\\"

Skins.definitions = {
    default = { id = "default", name = "Classic WIP" },
    classic = { id = "classic", name = "Default", root = CLASSIC_ROOT },
}
Skins.controls = Skins.controls or {}
Skins.surfaces = Skins.surfaces or {}
Skins.navigation = Skins.navigation or {}
Skins.callbacks = Skins.callbacks or {}
Skins.scrollbars = Skins.scrollbars or {}
Skins.current = Skins.current or "default"

local CLASSIC_ICONS = {
    roster = "roster", raid = "raids", statistics = "guild_stats", raidStatistics = "raid_stats",
    csr = "csr", performance = "performance", profiler = "performance", plugins = "groups",
    configuration = "settings", about = "about",
}

local function ClassicPath(path)
    return CLASSIC_ROOT .. path
end

local function CreateNineSlice(parent, path, width, height, inset, layer, region)
    local set = { textures = {}, inset = inset }
    local x, y = inset / width, inset / height
    local coords = {
        { 0, x, 0, y }, { x, 1 - x, 0, y }, { 1 - x, 1, 0, y },
        { 0, x, y, 1 - y }, { x, 1 - x, y, 1 - y }, { 1 - x, 1, y, 1 - y },
        { 0, x, 1 - y, 1 }, { x, 1 - x, 1 - y, 1 }, { 1 - x, 1, 1 - y, 1 },
    }
    local index
    for index = 1, 9 do
        local texture = parent:CreateTexture(nil, layer or "BACKGROUND")
        texture:SetTexture(path)
        local uv = coords[index]
        if region then
            texture:SetTexCoord(region[1] + uv[1] * (region[2] - region[1]), region[1] + uv[2] * (region[2] - region[1]), region[3] + uv[3] * (region[4] - region[3]), region[3] + uv[4] * (region[4] - region[3]))
        else texture:SetTexCoord(unpack(uv)) end
        set.textures[index] = texture
    end
    local tl, top, tr = set.textures[1], set.textures[2], set.textures[3]
    local left, middle, right = set.textures[4], set.textures[5], set.textures[6]
    local bl, bottom, br = set.textures[7], set.textures[8], set.textures[9]
    tl:SetWidth(inset); tl:SetHeight(inset); tl:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    tr:SetWidth(inset); tr:SetHeight(inset); tr:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bl:SetWidth(inset); bl:SetHeight(inset); bl:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    br:SetWidth(inset); br:SetHeight(inset); br:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    top:SetHeight(inset); top:SetPoint("TOPLEFT", tl, "TOPRIGHT", 0, 0); top:SetPoint("TOPRIGHT", tr, "TOPLEFT", 0, 0)
    bottom:SetHeight(inset); bottom:SetPoint("BOTTOMLEFT", bl, "BOTTOMRIGHT", 0, 0); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT", 0, 0)
    left:SetWidth(inset); left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT", 0, 0); left:SetPoint("BOTTOMLEFT", bl, "TOPLEFT", 0, 0)
    right:SetWidth(inset); right:SetPoint("TOPRIGHT", tr, "BOTTOMRIGHT", 0, 0); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT", 0, 0)
    middle:SetPoint("TOPLEFT", tl, "BOTTOMRIGHT", 0, 0); middle:SetPoint("BOTTOMRIGHT", br, "TOPLEFT", 0, 0)
    return set
end

local function SizeNineSlice(set, inset)
    if set.inset == inset then return end
    set.inset = inset
    local t = set.textures
    local index
    for index = 1, 9 do
        if index == 1 or index == 3 or index == 7 or index == 9 then t[index]:SetWidth(inset); t[index]:SetHeight(inset) end
    end
    t[2]:SetHeight(inset); t[8]:SetHeight(inset); t[4]:SetWidth(inset); t[6]:SetWidth(inset)
end

local function SetAtlasArtwork(set, style)
    if set.style == style then return end
    local x, y = style.inset / style.width, style.inset / style.height
    local region = style.coords
    local index
    for index = 1, 9 do
        local column, row = math.mod(index - 1, 3), math.floor((index - 1) / 3)
        local left, right = column == 0 and 0 or column == 1 and x or 1 - x, column == 0 and x or column == 1 and 1 - x or 1
        local top, bottom = row == 0 and 0 or row == 1 and y or 1 - y, row == 0 and y or row == 1 and 1 - y or 1
        local texture = set.textures[index]
        texture:SetTexture(style.path)
        texture:SetTexCoord(region[1] + left * (region[2] - region[1]), region[1] + right * (region[2] - region[1]), region[3] + top * (region[4] - region[3]), region[3] + bottom * (region[4] - region[3]))
    end
    SizeNineSlice(set, style.inset); set.style = style
end

local function SetNineSliceShown(set, shown)
    local index
    if not set then return end
    for index = 1, 9 do
        if shown then set.textures[index]:Show() else set.textures[index]:Hide() end
    end
end

local function SetNineSliceTexture(set, path)
    local index
    if not set then return end
    for index = 1, 9 do set.textures[index]:SetTexture(path) end
end

local function CreateClassicHoverOutline(frame, path, fullEdges)
    local outline = CreateNineSlice(frame, path, 128, 32, 6, "HIGHLIGHT")
    outline.textures[5]:Hide()
    if not fullEdges then
        outline.textures[2]:SetHeight(2); outline.textures[8]:SetHeight(2)
        outline.textures[4]:SetWidth(2); outline.textures[6]:SetWidth(2)
    end
    return outline
end

local projectOutlineGold = {1, 0.78, 0.2}
function UI.SetProjectButtonOutline(button, visible, size, color, topInset, minimumLevel)
    if not button.mosProjectOutline then
        local border = UI.CreateContainer(nil, button)
        border:SetAllPoints(button); border:EnableMouse(false)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        UI.ApplyDropdownChoiceSurface(border)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(1, 0.78, 0.2, 1)
        button.mosProjectOutline = border
    end
    local border = button.mosProjectOutline
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -(topInset or 0))
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(math.max(button:GetFrameLevel() + 1, minimumLevel or 0))
    local edgeSize = math.max(1, math.min(6, tonumber(size) or 2)) * 4
    if border.mosEdgeSize ~= edgeSize then
        local backdrop = border:GetBackdrop(); backdrop.edgeSize = edgeSize
        border:SetBackdrop(backdrop); border:SetBackdropColor(0, 0, 0, 0); border.mosEdgeSize = edgeSize
    end
    color = color or projectOutlineGold
    border:SetBackdropBorderColor(color[1], color[2], color[3], 1)
    if visible then button.mosProjectOutline:Show() else button.mosProjectOutline:Hide() end
end

-- Asset metadata belongs to the caller. These pooled primitives also support
-- atlas regions, preserving authored corners when the owner is resized.
local function ApplyAtlasSurface(frame)
    if not frame.mosAtlasStyle then
        SetNineSliceShown(frame.mosAtlasSurface, false)
        SetNineSliceShown(frame.mosAtlasHighlight, false)
        return false
    end
    local style = frame.mosAtlasStyle
    if not frame.mosAtlasSurface then
        frame.mosAtlasSurface = CreateNineSlice(frame, style.path, style.width, style.height, style.inset, "BACKGROUND", style.coords)
        frame.mosAtlasSurface.style = style
    end
    SetAtlasArtwork(frame.mosAtlasSurface, style)
    frame:SetBackdropColor(0,0,0,0); frame:SetBackdropBorderColor(0,0,0,0)
    if frame.mosColorFill then frame.mosColorFill:Hide() end
    if frame.mosClassicRowShade then frame.mosClassicRowShade:Hide() end
    SetNineSliceShown(frame.mosAtlasSurface, true)
    return true
end

function UI.SetAtlasHighlight(frame, visible, style, size, color)
    if not visible then SetNineSliceShown(frame.mosAtlasHighlight, false); return end
    if visible and not frame.mosAtlasHighlight then
        frame.mosAtlasHighlight = CreateNineSlice(frame, style.path, style.width, style.height, style.inset, "BORDER", style.coords)
        frame.mosAtlasHighlight.style = style
    end
    if not frame.mosAtlasHighlight then return end
    SetAtlasArtwork(frame.mosAtlasHighlight, style)
    SizeNineSlice(frame.mosAtlasHighlight, math.min(style.height / 2, frame:GetHeight() / 2, frame:GetWidth() / 2, style.inset * (size or 1)))
    local index
    for index = 1, 9 do
        local texture = frame.mosAtlasHighlight.textures[index]
        texture:SetBlendMode("ADD")
        texture:SetVertexColor(color[1], color[2], color[3], 1)
    end
    SetNineSliceShown(frame.mosAtlasHighlight, visible and frame.mosAtlasStyle ~= nil)
    frame.mosAtlasHighlight.textures[5]:Hide()
end

function UI.SetAtlasOutline(frame, visible, style, size, color, topInset, minimumLevel)
    if not frame.mosAtlasOutline and not visible then return end
    if not frame.mosAtlasOutline then
        local border = UI.CreateContainer(nil, frame)
        border:EnableMouse(false)
        border.art = CreateNineSlice(border, style.path, style.width, style.height, style.inset, "OVERLAY", style.coords)
        border.art.style = style
        border.art.textures[5]:Hide()
        frame.mosAtlasOutline = border
    end
    local border = frame.mosAtlasOutline
    border:ClearAllPoints(); border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(topInset or 0)); border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(math.max(frame:GetFrameLevel() + 1, minimumLevel or 0))
    SetAtlasArtwork(border.art, style)
    SizeNineSlice(border.art, math.min(frame:GetWidth() / 2, math.max(1, frame:GetHeight() - (topInset or 0)) / 2, style.inset * (size or 1)))
    for index = 1, 9 do border.art.textures[index]:SetVertexColor(color[1], color[2], color[3], 1) end
    if visible then border:Show() else border:Hide() end
end

local function ApplyButtonArtwork(button, entry)
    local art = button.mosButtonArtwork
    if not art then return end
    SetNineSliceShown(entry.classicSkin, false); SetNineSliceShown(entry.classicHoverBorder, false); SetNineSliceShown(entry.classicSelectedBorder, false)
    if entry.classicRedFill then entry.classicRedFill:Hide() end
    if entry.redHover then entry.redHover:Hide() end
    if button.mosHighlight then button.mosHighlight:Hide() end
    button:SetBackdropColor(0,0,0,0); button:SetBackdropBorderColor(0,0,0,0)
    button:SetNormalTexture(art.normal); button:SetPushedTexture(art.pushed)
    button:SetDisabledTexture(art.disabled); button:SetHighlightTexture(art.highlight, "ADD")
    for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture"}) do
        local region = button[getter] and button[getter](button)
        if region and region.SetTexCoord then region:SetTexCoord(unpack(art.coords)) end
    end
end

function UI.ApplyDropdownChoiceSurface(button)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8, insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    button:SetBackdropColor(0.08, 0.08, 0.08, 0.95)
    if button.mosClassicSelected then button:SetBackdropBorderColor(1, 0.78, 0.2, 1)
    else button:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end
end

local function ApplySolidButton(entry)
    local button = entry.frame
    UI.ApplyDropdownChoiceSurface(button)
    button:EnableMouse(true)
    if button.mosHighlight then button.mosHighlight:Hide() end
    SetNineSliceShown(entry.classicSkin, false); SetNineSliceShown(entry.classicHoverBorder, false)
    SetNineSliceShown(entry.classicSelectedBorder, false)
    if entry.classicRedFill then entry.classicRedFill:Hide() end
    if entry.redHover then entry.redHover:Hide() end
    button:SetHighlightTexture(nil); button:SetPushedTexture(nil); button:SetDisabledTexture(nil)
end

local function ApplySizedButtonGeometry(button, entry)
    if not button.mosButtonScale then
        if UI.ApplyButtonCaptionBaseline then UI.ApplyButtonCaptionBaseline(button) end
        return
    end
    local scale = button.mosButtonScale
    local iconSize = (button.mosBaseIconSize or 13) * scale
    local inset = (button.mosBaseIconInset or 7) * scale
    if button.mosClassicIconKey then
        button.mosClassicIconSize = iconSize; button.mosClassicIconInset = inset; button.mosClassicIconYOffset = 0
        if entry and entry.classicIcon then
            entry.classicIcon:SetWidth(iconSize); entry.classicIcon:SetHeight(iconSize)
            entry.classicIcon:ClearAllPoints(); entry.classicIcon:SetPoint("LEFT", button, "LEFT", inset, 0)
            entry.classicIcon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
        end
    end
    if button.label then
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT", button, "TOPLEFT", button.mosClassicIconKey and inset + iconSize + 4 or 0, 0)
        button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 0)
        button.label:SetJustifyH(button.mosClassicIconKey and "LEFT" or "CENTER"); button.label:SetJustifyV("MIDDLE")
    end
    if UI.ApplyButtonCaptionBaseline then UI.ApplyButtonCaptionBaseline(button) end
end

local function ApplyControl(entry)
    local button = entry.frame
    if Skins.current ~= "classic" or button.mosClassicVariant ~= "red" then entry.hovered = nil end
    local solid = button.mosClassicKeepNormalSurface
    if Skins.current == "classic" then
        local useSelectedSurface = button.mosClassicSelected and not button.mosClassicKeepNormalSurface
        local variant = useSelectedSurface and "red" or (button.mosClassicVariant or "dark")
        local state = (useSelectedSurface or variant == "red" or button.mosClassicPersistentRed) and "selected" or "normal"
        if not button.mosClassicKeepNormalSurface then
            if not entry.classicSkin then entry.classicSkin = CreateNineSlice(button, ClassicPath("Buttons\\" .. variant .. "-" .. state .. ".tga"), 128, 32, 6, "BACKGROUND")
            else SetNineSliceTexture(entry.classicSkin, ClassicPath("Buttons\\" .. variant .. "-" .. state .. ".tga")) end
            local center = entry.classicSkin.textures[5]
            center:ClearAllPoints(); center:SetPoint("TOPLEFT", entry.classicSkin.textures[1], "BOTTOMRIGHT", 0, 0)
            center:SetPoint("BOTTOMRIGHT", entry.classicSkin.textures[9], "TOPLEFT", 0, 0); center:SetVertexColor(1,1,1,1)
            button:SetBackdropColor(0, 0, 0, 0); button:SetBackdropBorderColor(0, 0, 0, 0); SetNineSliceShown(entry.classicSkin, true)
            button:SetHighlightTexture(nil)
            if button.mosHighlight then button.mosHighlight:Hide() end
            if not entry.classicHoverBorder then entry.classicHoverBorder = CreateClassicHoverOutline(button, ClassicPath("Buttons\\" .. variant .. "-selected.tga"), true)
            else SetNineSliceTexture(entry.classicHoverBorder, ClassicPath("Buttons\\" .. variant .. "-selected.tga")) end
            SetNineSliceShown(entry.classicHoverBorder, true); entry.classicHoverBorder.textures[5]:Hide()
            if not entry.classicSelectedBorder then entry.classicSelectedBorder = CreateNineSlice(button, ClassicPath("Buttons\\" .. variant .. "-selected.tga"), 128, 32, 6, "OVERLAY")
            else SetNineSliceTexture(entry.classicSelectedBorder, ClassicPath("Buttons\\" .. variant .. "-selected.tga")) end
            -- The selected surface keeps its thin outline; only hover adds the stronger outline.
            SetNineSliceShown(entry.classicSelectedBorder, false)
            entry.classicSelectedBorder.textures[5]:Hide()
            button:SetPushedTexture(ClassicPath("Buttons\\" .. variant .. (state == "selected" and "-selected.tga" or "-pressed.tga")))
            button:SetDisabledTexture(ClassicPath("Buttons\\" .. variant .. "-disabled.tga"))
            if not entry.classicRedFill then
                entry.classicRedFill = button:CreateTexture(nil, "ARTWORK")
                entry.classicRedFill:SetTexture("Interface\\Buttons\\WHITE8X8")
                entry.classicRedFill:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
                entry.classicRedFill:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 5)
                entry.classicRedFill:SetVertexColor(0.55, 0.04, 0.04, 0.27)
            end
            if state == "selected" and not button.mosClassicCompactControl then entry.classicRedFill:Show() else entry.classicRedFill:Hide() end
        end
        if button.mosClassicVariant == "red" and not button.mosClassicCompactControl then
            SetNineSliceShown(entry.classicHoverBorder, false)
            if not entry.redHover then
                entry.redHover = button:CreateTexture(nil, "HIGHLIGHT")
                entry.redHover:SetTexture(ClassicPath("Buttons\\red-hover-radial.tga"))
                entry.redHover:SetTexCoord(0, 1, 0, 1)
                entry.redHover:SetBlendMode("ADD")
                entry.redHover:SetVertexColor(1, 1, 1, 0.30)
                entry.redHover:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
                entry.redHover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 5)
            end
            entry.redHover:ClearAllPoints(); entry.redHover:SetPoint("TOPLEFT", button, "TOPLEFT", 6, -5)
            entry.redHover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -6, 5); entry.redHover:Show()
        elseif entry.redHover then entry.redHover:Hide() end
        local disabled = button.mosClassicDisabled
        local gold = not disabled and (button.mosClassicGold or button.mosClassicSelected)
        local red, green, blue = 1, 1, 1
        if disabled then red, green, blue = 0.48, 0.48, 0.46
        elseif gold then red, green, blue = 1, 0.82, 0.28 end
        if button.label then button.label:SetTextColor(red, green, blue) end
        if button.mosClassicIconKey then
            if not entry.classicIcon then
                entry.classicIcon = button:CreateTexture(nil, "OVERLAY")
                entry.classicIcon:SetPoint("LEFT", button, "LEFT", 7, 0)
            end
            entry.classicIcon:SetWidth(button.mosClassicIconSize or 13); entry.classicIcon:SetHeight(button.mosClassicIconSize or 13)
            entry.classicIcon:SetTexture(ClassicPath("Icons\\" .. button.mosClassicIconKey .. ".tga")); entry.classicIcon:Show()
            entry.classicIcon:ClearAllPoints(); entry.classicIcon:SetPoint("LEFT", button, "LEFT", button.mosClassicIconInset or 7, button.mosClassicIconYOffset or 0)
            entry.classicIcon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
            -- Keep the label on its original full button bounds. Reserving space
            -- for the icon moved the visual centre of every caption.
            if button.label and entry.labelPoints then
                button.label:ClearAllPoints()
                if button.mosClassicReserveIconSpace then
                    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", (button.mosClassicIconInset or 7) + (button.mosClassicIconSize or 13) + 3, 0)
                    button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 0)
                else
                    local pointIndex
                    for pointIndex = 1, table.getn(entry.labelPoints) do button.label:SetPoint(unpack(entry.labelPoints[pointIndex])) end
                end
                button.label:SetJustifyH("CENTER")
            end
        else
            if entry.classicIcon then entry.classicIcon:Hide() end
            if button.label and entry.labelPoints then
                button.label:ClearAllPoints()
                local pointIndex
                for pointIndex = 1, table.getn(entry.labelPoints) do button.label:SetPoint(unpack(entry.labelPoints[pointIndex])) end
            end
        end
        if button.label and button.mosClassicLabelYOffset then
            button.label:ClearAllPoints()
            button.label:SetPoint("TOPLEFT", button, "TOPLEFT", button.mosClassicLabelXOffset or 0, button.mosClassicLabelYOffset)
            button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", button.mosClassicLabelXOffset or 0, button.mosClassicLabelYOffset)
            button.label:SetJustifyH("CENTER"); button.label:SetJustifyV("MIDDLE")
        end
        if button.mosHighlight then button.mosHighlight:SetTexture("Interface\\Buttons\\WHITE8X8"); button.mosHighlight:SetVertexColor(0.55, 0.38, 0.08, 0.35) end
        if button.mosClassicCompactControl then
            SetNineSliceShown(entry.classicSkin, false)
            SetNineSliceShown(entry.classicHoverBorder, false)
            SetNineSliceShown(entry.classicSelectedBorder, false)
            UI.ApplyDropdownChoiceSurface(button)
            button:SetPushedTexture(nil); button:SetDisabledTexture(nil)
            if button.label then
                button.label:ClearAllPoints()
                button.label:SetAllPoints(button)
                button.label:SetJustifyH("CENTER"); button.label:SetJustifyV("MIDDLE")
            end
        end
    else
        if entry.redHover then entry.redHover:Hide() end
        SetNineSliceShown(entry.classicSkin, false)
        SetNineSliceShown(entry.classicHoverBorder, false)
        SetNineSliceShown(entry.classicSelectedBorder, false)
        if entry.classicRedFill then entry.classicRedFill:Hide() end
        if entry.classicIcon then entry.classicIcon:Hide() end
        if button.label and entry.labelPoints then
            button.label:ClearAllPoints()
            local pointIndex
            for pointIndex = 1, table.getn(entry.labelPoints) do button.label:SetPoint(unpack(entry.labelPoints[pointIndex])) end
        end
        button:SetBackdrop(entry.backdrop)
        button:SetBackdropColor(unpack(entry.background)); button:SetBackdropBorderColor(unpack(entry.border))
        if button.label and entry.labelColor then button.label:SetTextColor(unpack(entry.labelColor)) end
        if button.mosHighlight then button.mosHighlight:Show(); button.mosHighlight:SetAlpha(1); button.mosHighlight:SetTexture(unpack(entry.highlight)); button.mosHighlight:SetVertexColor(1, 1, 1, 1) end
    end
    if button.label and button.mosTextColor then button.label:SetTextColor(unpack(button.mosClassicSelected and button.mosSelectedTextColor or button.mosTextColor)) end
    if solid then
        ApplySolidButton(entry)
    elseif Skins.current == "classic" and not button.mosClassicCompactControl and button.mosClassicVariant ~= "red" and not button.mosClassicSelected then
        UI.ApplyDropdownChoiceSurface(button)
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicSkin then
            local center = entry.classicSkin.textures[5]
            center:ClearAllPoints(); center:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3); center:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3); center:Show()
        end
        SetNineSliceShown(entry.classicHoverBorder, false)
        SetNineSliceShown(entry.classicSelectedBorder, false)
        button:SetPushedTexture(nil); button:SetDisabledTexture(nil)
        if button.mosClassicVariant == "red" or button.mosClassicSelected then button:SetBackdropBorderColor(1, 0.78, 0.2, 1) end
    end
    if button.label and not button.mosTextColor and entry.hovered and Skins.current == "classic" and button.mosClassicVariant == "red" and not button.mosClassicDisabled then
        entry.restR, entry.restG, entry.restB, entry.restA = button.label:GetTextColor()
        button.label:SetTextColor(0.82, 0.82, 0.78)
    end
    if button.label and button.mosLabelInsets then
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", button.mosLabelInsets[1], 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -button.mosLabelInsets[2], 0)
        button.label:SetJustifyH("LEFT")
    end
    if button.label and button.mosClassicCompactControl and button.mosClassicLabelYOffset then
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT", button, "TOPLEFT", button.mosClassicLabelXOffset or 0, button.mosClassicLabelYOffset)
        button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", button.mosClassicLabelXOffset or 0, button.mosClassicLabelYOffset)
    end
    ApplySizedButtonGeometry(button, entry)
    if button.mosBorderless then
        if Skins.current == "classic" and entry.classicSkin and not solid then
            SetNineSliceShown(entry.classicSkin, false)
            local center = entry.classicSkin.textures[5]
            center:ClearAllPoints(); center:SetAllPoints(button)
            local brightness = button.mosClassicDisabled and 0.45 or 1
            center:SetVertexColor(brightness,brightness,brightness,1); center:Show()
        end
        SetNineSliceShown(entry.classicHoverBorder, false); SetNineSliceShown(entry.classicSelectedBorder, false)
        if entry.redHover then entry.redHover:ClearAllPoints(); entry.redHover:SetAllPoints(button) end
        if entry.classicRedFill then entry.classicRedFill:Hide() end
        button:SetPushedTexture(nil); button:SetDisabledTexture(nil); button:SetBackdropBorderColor(0,0,0,0)
        if button.mosProjectOutline then button.mosProjectOutline:Hide() end
    end
    if button.mosWarmListRow then UI.StyleWarmListRow(button, button.mosWarmListSelected) end
    if button.mosSelectableTableRow and UI.StyleSelectableTableRow then UI.StyleSelectableTableRow(button,button.mosTableRowEven,button.mosTableRowSelected) end
    ApplyButtonArtwork(button, entry)
end

function UI.SetButtonTextColor(button, color)
    if not button then return end
    button.mosTextColor = color
    if button.label then button.label:SetTextColor(unpack(color)) end
end

local function GoldHoverEnter()
    if this.IsEnabled and not this:IsEnabled() then return end
    this:SetBackdropBorderColor(1, 0.78, 0.2, 1)
    if this.mosHoverTextColor and this.label then this.label:SetTextColor(unpack(this.mosHoverTextColor)) end
end

local function GoldHoverLeave()
    if this.mosHoverTextColor and this.label then this.label:SetTextColor(unpack(this.mosClassicSelected and this.mosHoverTextColor or this.mosTextColor or {1,1,1})) end
    if this.mosClassicKeepNormalSurface and this.mosClassicSelected then this:SetBackdropBorderColor(1, 0.78, 0.2, 1); return end
    local color = this.mosNormalBorder
    if color then this:SetBackdropBorderColor(color[1], color[2], color[3], color[4]) end
end

function UI.AttachGoldHoverBorder(button, red, green, blue, alpha)
    button.mosNormalBorder = { red, green, blue, alpha }
    button:SetScript("OnEnter", GoldHoverEnter)
    button:SetScript("OnLeave", GoldHoverLeave)
end

local SURFACE_STYLES = {
    window = { file = "Frames\\window.tga", width = 64, height = 64, inset = 12, fill = "Surfaces\\black.tga" },
    title = { file = "Frames\\header-panel.tga", width = 32, height = 32, inset = 6, fill = "Surfaces\\header.tga" },
    sidebar = { file = "Frames\\panel.tga", width = 32, height = 32, inset = 6, fill = "Surfaces\\sidebar.tga" },
    content = { file = "Frames\\panel.tga", width = 32, height = 32, inset = 6, fill = "Surfaces\\black.tga" },
    status = { file = "Frames\\panel.tga", width = 32, height = 32, inset = 6, fill = "Surfaces\\stone.tga" },
    panel = { file = "Frames\\panel.tga", width = 32, height = 32, inset = 6, fill = "Surfaces\\black.tga" },
    warning = { file = "Frames\\warning.tga", width = 32, height = 32, inset = 6, fill = "Surfaces\\black.tga" },
    row = { file = "Surfaces\\row-normal.tga", width = 256, height = 32, inset = 3 },
}

local function ApplySurface(entry)
    local frame = entry.frame
    if ApplyAtlasSurface(frame) then
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicFill then entry.classicFill:Hide() end
        return
    end
    if frame.mosTransparentSurface then
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicFill then entry.classicFill:Hide() end
        frame:SetBackdropColor(0,0,0,0); frame:SetBackdropBorderColor(0,0,0,0)
        return
    end
    if not frame.mosUseNativeSurface and (Skins.current == "classic" or frame.mosJoinedTop ~= nil or frame.mosHorizontalBorders) then
        local style = SURFACE_STYLES[entry.kind] or SURFACE_STYLES.panel
        if entry.kind == "row" and not entry.classicFill then
            -- Rows have a fixed height and a horizontally authored surface.
            -- One reused region per row is substantially cheaper than nine.
            entry.classicFill = frame:CreateTexture(nil, "BACKGROUND"); entry.classicFill:SetTexture(ClassicPath(style.file)); entry.classicFill:SetAllPoints(frame)
        elseif style.fill and not entry.classicFill then
            entry.classicFill = frame:CreateTexture(nil, "BACKGROUND"); entry.classicFill:SetTexture(ClassicPath(style.fill)); entry.classicFill:SetAllPoints(frame)
        end
        -- Keep the opaque body below the decorated frame. Creating both on the
        -- same layer made the later fill cover the complete nine-slice border.
        if entry.kind ~= "row" and not entry.classicSkin then entry.classicSkin = CreateNineSlice(frame, ClassicPath(style.file), style.width, style.height, style.inset, "BORDER") end
        frame:SetBackdropColor(0, 0, 0, 0); frame:SetBackdropBorderColor(0, 0, 0, 0)
        if entry.classicFill then entry.classicFill:Show() end
        if frame.mosClassicRowShade then frame.mosClassicRowShade:Show() end
        SetNineSliceShown(entry.classicSkin, true)
        if entry.classicSkin then
            local index
            for index = 1, 9 do entry.classicSkin.textures[index]:SetAlpha(frame.mosCompactBorder and 0.2 or 1) end
        end
    else
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicFill then entry.classicFill:Hide() end
        if frame.mosClassicRowShade then frame.mosClassicRowShade:Hide() end
        frame:SetBackdrop(entry.backdrop)
        frame:SetBackdropColor(unpack(entry.background)); frame:SetBackdropBorderColor(unpack(entry.border))
        if frame.mosCompactBorder then frame:SetBackdropBorderColor(entry.border[1], entry.border[2], entry.border[3], 0.2) end
    end
    if entry.classicSkin and frame.mosJoinedTop ~= nil then
        local t = entry.classicSkin.textures
        if frame.mosJoinedTop then
            t[1]:SetTexCoord(0, 6/32, 6/32, 26/32); t[3]:SetTexCoord(26/32, 1, 6/32, 26/32)
        end
        if frame.mosJoinedBottom then
            t[7]:SetTexCoord(0, 6/32, 6/32, 26/32); t[9]:SetTexCoord(26/32, 1, 6/32, 26/32); t[8]:Hide()
        end
    end
    if frame.mosSeparatorsOnly and entry.classicSkin then
        local t = entry.classicSkin.textures
        local index
        for index = 1, 9 do if index ~= 2 or not frame.mosJoinedTop then t[index]:Hide() end end
        t[2]:ClearAllPoints(); t[2]:SetPoint("TOPLEFT",frame,"TOPLEFT",-(frame.mosBorderOutsetLeft or 0),0); t[2]:SetPoint("TOPRIGHT",frame,"TOPRIGHT",frame.mosBorderOutsetRight or 0,0)
        if entry.classicFill then entry.classicFill:Hide() end
    end
    if frame.mosHorizontalBorders and entry.classicSkin then
        local t = entry.classicSkin.textures
        t[1]:Hide(); t[3]:Hide(); t[4]:Hide(); t[5]:Hide(); t[6]:Hide(); t[7]:Hide(); t[9]:Hide()
        t[2]:ClearAllPoints(); t[2]:SetPoint("TOPLEFT",frame,"TOPLEFT",-(frame.mosBorderOutsetLeft or 0),0); t[2]:SetPoint("TOPRIGHT",frame,"TOPRIGHT",frame.mosBorderOutsetRight or 0,0)
        t[8]:ClearAllPoints(); t[8]:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",-(frame.mosBorderOutsetLeft or 0),0); t[8]:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",frame.mosBorderOutsetRight or 0,0)
        if entry.kind == "title" then
            -- Omit the black inner bevel authored above the visible separator.
            t[8]:SetTexCoord(6/32, 26/32, 29/32, 1); t[8]:SetHeight(3)
        end
        if not frame.mosBorderTop then t[2]:Hide() end
        if not frame.mosBorderBottom then t[8]:Hide() end
        if frame.mosBorderRight then
            t[6]:Show(); t[6]:ClearAllPoints(); t[6]:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0); t[6]:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
        end
    end
    if frame.mosRowColor then UI.SetRowColor(frame, frame.mosRowColor, frame.mosRowAlpha) end
    if frame.mosSurfaceBorderHidden then
        SetNineSliceShown(entry.classicSkin, false); frame:SetBackdropBorderColor(0,0,0,0)
    end
end

local function ApplyNavigation(entry)
    local icon = entry.frame.icon
    if not icon then return end
    if Skins.current == "classic" then
        local asset = CLASSIC_ICONS[entry.key]
        icon:SetTexture(asset and ClassicPath("Icons\\" .. asset .. ".tga") or entry.defaultIcon or ClassicPath("Icons\\about.tga"))
        if not entry.classicHoverBorder then entry.classicHoverBorder = CreateClassicHoverOutline(entry.frame, ClassicPath("Buttons\\dark-selected.tga"), true)
        else SetNineSliceShown(entry.classicHoverBorder, true); entry.classicHoverBorder.textures[5]:Hide() end
        if entry.frame.navigationMode == "tabs" then SetNineSliceShown(entry.classicHoverBorder, false) end
        if entry.frame.iconBorder then entry.frame.iconBorder:Hide() end
    else
        if entry.classicHoverBorder then SetNineSliceShown(entry.classicHoverBorder, false) end
        if entry.backdrop then entry.frame:SetBackdrop(entry.backdrop) end
        icon:SetTexture(entry.defaultIcon)
        if entry.iconColor then icon:SetVertexColor(unpack(entry.iconColor)) end
        if entry.frame.iconBorder then entry.frame.iconBorder:Show() end
    end
end

local function ApplyScrollBar(entry)
    -- WoW 1.12 templates own the slider thumb, arrows and visibility state.
    -- Leave them intact; replacing individual regions produced overlapping
    -- controls and a non-functional hit area on some clients.
    if entry.track then entry.track:Hide() end
    if entry.upTexture then entry.upTexture:SetAlpha(1) end
    if entry.downTexture then entry.downTexture:SetAlpha(1) end
    if entry.upIcon then entry.upIcon:Hide() end
    if entry.downIcon then entry.downIcon:Hide() end
end

local function RedHoverEnter()
    local entry = this.mosSkinEntry
    if entry.onEnter then entry.onEnter() end
    if Skins.current == "classic" and not this.mosClassicDisabled then this:SetBackdropBorderColor(1, 0.78, 0.2, 1) end
    local enabled = not this.IsEnabled or this:IsEnabled()
    if Skins.current ~= "classic" or this.mosClassicVariant ~= "red" or this.mosClassicCompactControl or this.mosClassicDisabled or enabled == false or enabled == 0 then return end
    if not entry.hovered then entry.restR, entry.restG, entry.restB, entry.restA = this.label:GetTextColor() end
    entry.hovered = true
    if not this.mosTextColor then this.label:SetTextColor(0.82, 0.82, 0.78) end
end

local function RedHoverLeave()
    local entry = this.mosSkinEntry
    if entry.hovered then
        entry.hovered = nil
        if this.mosClassicDisabled then this.label:SetTextColor(0.48, 0.48, 0.46)
        else this.label:SetTextColor(entry.restR, entry.restG, entry.restB, entry.restA) end
    end
    if entry.onLeave then entry.onLeave() end
    if Skins.current == "classic" then
        if this.mosClassicVariant == "red" or this.mosClassicSelected then this:SetBackdropBorderColor(1, 0.78, 0.2, 1)
        else this:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end
    end
end

function UI.RegisterSkinnedControl(frame, backdrop, background, border, highlight)
    -- Authored red artwork owns its outline. Later action/hover styling must
    -- never add the native backdrop edge over it.
    if not frame.mosBorderSetterInstalled then
        local setBorder = frame.SetBackdropBorderColor
        frame.SetBackdropBorderColor = function(self, red, green, blue, alpha)
            if self.mosButtonArtwork or self.mosBorderless or (Skins.current == "classic" and self.mosClassicVariant == "red" and not self.mosClassicCompactControl and not self.mosClassicKeepNormalSurface) then
                return setBorder(self, 0, 0, 0, 0)
            end
            return setBorder(self, red, green, blue, alpha)
        end
        frame.mosBorderSetterInstalled = true
    end
    local labelColor = nil
    local labelPoints = nil
    if frame.label and frame.label.GetTextColor then
        local r, g, b, a = frame.label:GetTextColor(); labelColor = { r, g, b, a }
        labelPoints = {}
        local pointIndex
        for pointIndex = 1, frame.label:GetNumPoints() do labelPoints[pointIndex] = { frame.label:GetPoint(pointIndex) } end
    end
    local entry = { frame = frame, backdrop = backdrop, background = background, border = border, highlight = highlight, labelColor = labelColor, labelPoints = labelPoints }
    entry.onEnter, entry.onLeave = frame:GetScript("OnEnter"), frame:GetScript("OnLeave")
    frame.mosSkinEntry = entry
    frame:SetScript("OnEnter", RedHoverEnter); frame:SetScript("OnLeave", RedHoverLeave)
    local onHide = frame:GetScript("OnHide")
    frame:SetScript("OnHide", function()
        if entry.hovered then
            entry.hovered = nil
            frame.label:SetTextColor(entry.restR, entry.restG, entry.restB, entry.restA)
        end
        if onHide then onHide() end
    end)
    Skins.controls[table.getn(Skins.controls) + 1] = entry
    ApplyControl(entry)
end

function UI.RegisterSkinnedSurface(frame, kind, backdrop, background, border)
    -- Some content containers request only a semantic surface kind. Retain
    -- their existing native colors so switching to the default skin is safe.
    if not background then
        local r,g,b,a
        if frame.GetBackdropColor then r,g,b,a=frame:GetBackdropColor() end
        background={r or 0,g or 0,b or 0,a or 0}
    end
    if not border then
        local r,g,b,a
        if frame.GetBackdropBorderColor then r,g,b,a=frame:GetBackdropBorderColor() end
        border={r or 0,g or 0,b or 0,a or 0}
    end
    if not backdrop and frame.GetBackdrop then backdrop=frame:GetBackdrop() end
    local entry = { frame = frame, kind = kind, backdrop = backdrop, background = background, border = border }
    frame.mosSurfaceEntry = entry
    Skins.surfaces[table.getn(Skins.surfaces) + 1] = entry
    ApplySurface(entry)
end

function UI.SetSurfaceCompact(frame, compact)
    local wanted = compact and true or false
    if frame.mosCompactBorder == wanted then return end
    frame.mosCompactBorder = wanted
    if frame.mosSurfaceEntry then ApplySurface(frame.mosSurfaceEntry) end
end

function UI.RegisterDialogSurface(frame, kind, background)
    local backdrop = frame.GetBackdrop and frame:GetBackdrop() or {
        bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 16, edgeSize = 16, insets = { left = 6, right = 6, top = 6, bottom = 6 },
    }
    local currentBackground = background
    if not currentBackground and frame.GetBackdropColor then
        local r, g, b, a = frame:GetBackdropColor()
        currentBackground = { r, g, b, a }
    end
    local currentBorder = { 1, 1, 1, 1 }
    if frame.GetBackdropBorderColor then
        local r, g, b, a = frame:GetBackdropBorderColor()
        currentBorder = { r, g, b, a }
    end
    UI.RegisterSkinnedSurface(frame, kind or "panel", backdrop, currentBackground or { 0.025, 0.025, 0.022, 1 }, currentBorder)
end

function UI.RegisterSkinnedNavigation(frame, key, defaultIcon)
    local iconColor = nil
    if frame.icon and frame.icon.GetVertexColor then
        local r, g, b, a = frame.icon:GetVertexColor(); iconColor = { r, g, b, a }
    end
    local entry = { frame = frame, key = key, defaultIcon = defaultIcon, backdrop = frame.GetBackdrop and frame:GetBackdrop() or nil, iconColor = iconColor }
    frame.mosNavigationSkinEntry = entry
    Skins.navigation[table.getn(Skins.navigation) + 1] = entry
    ApplyNavigation(entry)
end

function UI.SetNavigationTabBorder(frame, visible)
    local entry = frame.mosNavigationSkinEntry
    if entry and entry.classicTabBorder then SetNineSliceShown(entry.classicTabBorder, false) end
    if entry and entry.classicHoverBorder then SetNineSliceShown(entry.classicHoverBorder, false) end
    UI.SetOpenButtonBorder(frame, visible, frame.navigationBottom and "top" or "bottom")
    if visible and frame.openBorder then
        if frame.navigationSelected then frame.openBorder.border:SetBackdropBorderColor(1, 0.78, 0.2, 1)
        else frame.openBorder.border:SetBackdropBorderColor(0.62, 0.54, 0.34, 1) end
    end
end

function UI.RegisterSkinCallback(callback)
    Skins.callbacks[table.getn(Skins.callbacks) + 1] = callback
    callback(Skins.current)
end

function UI.GetSkin()
    return Skins.current
end

function UI.IsClassicSkin()
    return Skins.current == "classic"
end

function UI.SetSkin(value, persist)
    local wanted = string.lower(tostring(value or "default"))
    if not Skins.definitions[wanted] then wanted = "default" end
    Skins.current = wanted
    if persist and Skins.persist then Skins.persist(wanted) end
    local index
    for index = 1, table.getn(Skins.controls) do ApplyControl(Skins.controls[index]) end
    for index = 1, table.getn(Skins.surfaces) do ApplySurface(Skins.surfaces[index]) end
    for index = 1, table.getn(Skins.navigation) do ApplyNavigation(Skins.navigation[index]) end
    for index = 1, table.getn(Skins.scrollbars) do ApplyScrollBar(Skins.scrollbars[index]) end
    for index = 1, table.getn(Skins.callbacks) do Skins.callbacks[index](wanted) end
    return wanted
end

-- Registration owns this reference. State changes affect one control; SetSkin
-- remains the explicit full invalidation, including reapplying the same skin.
local function ApplyButtonState(button)
    if button.mosSkinEntry then ApplyControl(button.mosSkinEntry) end
end

function UI.SetClassicButtonVariant(button, variant)
    if not button then return end
    local wanted = variant == "red" and "red" or "dark"
    if button.mosClassicVariant == wanted then return end
    button.mosClassicVariant = wanted
    if Skins.current ~= "classic" then return end
    ApplyButtonState(button)
end

function UI.SetButtonBorderless(button, borderless)
    local wanted = borderless and true or false
    if button.mosBorderless == wanted then return end
    button.mosBorderless = wanted; ApplyButtonState(button)
end

function UI.SetButtonArtwork(button, artwork)
    if button.mosButtonArtwork == artwork then return end
    button.mosButtonArtwork = artwork
    if not artwork then button:SetNormalTexture(nil) end
    ApplyButtonState(button)
end

function UI.SetAtlasSurface(frame, style)
    if frame.mosAtlasStyle == style then return end
    frame.mosAtlasStyle = style
    if frame.mosSurfaceEntry then ApplySurface(frame.mosSurfaceEntry)
    else ApplyAtlasSurface(frame) end
end

function UI.SetTextureBackground(frame, path, color, alpha)
    if not path then
        if frame.mosTextureBackground then frame.mosTextureBackground:Hide() end
        frame.mosBackgroundPath = nil
        return
    end
    if not frame.mosTextureBackground then
        frame.mosTextureBackground = frame:CreateTexture(nil, "BACKGROUND")
        frame.mosTextureBackground:SetAllPoints(frame)
    end
    local texture = frame.mosTextureBackground
    if frame.mosBackgroundPath ~= path then texture:SetTexture(path); frame.mosBackgroundPath = path end
    if color then texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    else texture:SetVertexColor(1,1,1,alpha or 1) end
    texture:Show()
end

function UI.SetClassicButtonSelected(button, selected)
    if not button then return end
    local wanted = selected and true or false
    if button.mosClassicSelected == wanted then return end
    button.mosClassicSelected = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonCompact(button, compact)
    if not button then return end
    local wanted = compact and true or false
    if button.mosClassicCompactControl == wanted then return end
    button.mosClassicCompactControl = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonGold(button, gold)
    if not button then return end
    local wanted = gold and true or false
    if button.mosClassicGold == wanted then return end
    button.mosClassicGold = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonDisabled(button, disabled)
    if not button then return end
    local wanted = disabled and true or false
    if button.mosClassicDisabled == wanted then return end
    button.mosClassicDisabled = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonIcon(button, iconKey, size, inset, yOffset)
    if not button then return end
    local wantedSize, wantedInset, wantedY = size or 13, inset or 7, yOffset or 0
    -- Compare requested geometry, not the effective values derived by sizing.
    if button.mosClassicIconKey == iconKey and button.mosBaseIconSize == wantedSize and button.mosBaseIconInset == wantedInset and button.mosBaseIconYOffset == wantedY then return end
    button.mosClassicIconKey = iconKey
    button.mosClassicIconSize = wantedSize
    button.mosBaseIconSize = wantedSize; button.mosBaseIconInset = wantedInset; button.mosBaseIconYOffset = wantedY
    button.mosClassicIconInset = wantedInset
    button.mosClassicIconYOffset = wantedY
    ApplyButtonState(button)
end

function UI.SetClassicButtonLabelOffset(button, offset, xOffset)
    if not button then return end
    local wantedX = xOffset or 0
    if button.mosClassicLabelYOffset == offset and button.mosClassicLabelXOffset == wantedX then return end
    button.mosClassicLabelYOffset = offset
    button.mosClassicLabelXOffset = wantedX
    ApplyButtonState(button)
end

function UI.SizeClassicButton(button, width, height, fontScale)
    if not button then return end
    button:SetScale(1)
    button:SetWidth(width); button:SetHeight(height)
    button.mosButtonScale = fontScale or 1
    ApplySizedButtonGeometry(button, button.mosSkinEntry)
    if not button.label then return end
    if not button.mosBaseFontSize then
        button.mosBaseFontPath, button.mosBaseFontSize, button.mosBaseFontFlags = button.label:GetFont()
    end
    if button.mosBaseFontPath and button.mosBaseFontSize then
        button.label:SetFont(button.mosBaseFontPath, button.mosBaseFontSize * (fontScale or 1), button.mosBaseFontFlags)
    end
end

function UI.SetRowColor(row, color, alpha)
    row.mosRowColor = color; row.mosRowAlpha = alpha
    if row.mosAtlasStyle then
        if row.mosColorFill then row.mosColorFill:Hide() end
        return
    end
    row:SetBackdropColor(0, 0, 0, 0)
    if not row.mosColorFill then
        row.mosColorFill = row:CreateTexture(nil, "BORDER")
        row.mosColorFill:SetAllPoints(row)
        row.mosColorFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    -- Set opacity through the region API; never overwrite it with SetAlpha(1).
    row.mosColorFill:SetVertexColor(color[1], color[2], color[3])
    row.mosColorFill:SetAlpha(alpha or 1); row.mosColorFill:Show()
    local entry = row.mosSurfaceEntry
    if entry and entry.classicFill then entry.classicFill:Hide() end
    if row.mosClassicRowShade then row.mosClassicRowShade:Hide() end
end

function UI.SetClassicRowShade(row, even, hovered, selected)
    if not row then return end
    if row.mosAtlasStyle then return end
    if row.mosRowColor then UI.SetRowColor(row, row.mosRowColor, row.mosRowAlpha); return end
    if not row.mosClassicRowShade then
        row.mosClassicRowShade = row:CreateTexture(nil, "BORDER")
        row.mosClassicRowShade:SetAllPoints(row)
        row.mosClassicRowShade:SetTexture(1, 1, 1, 1)
    end
    if Skins.current == "classic" then
        row.mosClassicRowShade:SetAlpha(selected and 0.13 or hovered and 0.10 or even and 0.055 or 0.01)
        row.mosClassicRowShade:Show()
    else row.mosClassicRowShade:Hide() end
end

function UI.RegisterSkinnedScrollBar(slider)
    if not slider then return end
    local sliderName = slider:GetName()
    local up = sliderName and getglobal(sliderName .. "ScrollUpButton") or nil
    local down = sliderName and getglobal(sliderName .. "ScrollDownButton") or nil
    local entry = { slider = slider, upTexture = up and up:GetNormalTexture() or nil, downTexture = down and down:GetNormalTexture() or nil }
    Skins.scrollbars[table.getn(Skins.scrollbars) + 1] = entry
    ApplyScrollBar(entry)
end

function UI.ClassicAsset(path)
    return ClassicPath(path)
end

function UI.SetSkinPersistence(callback)
    Skins.persist = callback
end

function UI.SetSurfaceBorderVisible(frame, visible)
    if frame.mosSurfaceBorderHidden == not visible then return end
    frame.mosSurfaceBorderHidden = not visible
    if frame.mosSurfaceEntry then ApplySurface(frame.mosSurfaceEntry) end
end

function UI.SetSurfaceHorizontalBorders(frame, top, bottom, right)
    frame.mosHorizontalBorders = true
    frame.mosBorderTop = top ~= false; frame.mosBorderBottom = bottom ~= false; frame.mosBorderRight = right == true
    if frame.mosSurfaceEntry then ApplySurface(frame.mosSurfaceEntry) end
end

function UI.JoinSurfaceEdges(frame, top, bottom, leftOutset, rightOutset)
    if frame.mosJoinedTop == top and frame.mosJoinedBottom == bottom and frame.mosBorderOutsetLeft == leftOutset and frame.mosBorderOutsetRight == rightOutset then return end
    frame.mosBorderOutsetLeft = leftOutset; frame.mosBorderOutsetRight = rightOutset
    frame.mosJoinedTop = top; frame.mosJoinedBottom = bottom
    frame.mosSeparatorsOnly = true
    if frame.mosSurfaceEntry then ApplySurface(frame.mosSurfaceEntry) end
end

function UI.SetSurfaceTransparent(frame, transparent)
    frame.mosTransparentSurface = transparent and true or false
    if frame.mosSurfaceEntry then ApplySurface(frame.mosSurfaceEntry) end
end
