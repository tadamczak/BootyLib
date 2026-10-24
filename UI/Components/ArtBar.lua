local UI = BootyLib.UI.Components
local B = {}; UI.ArtBar = B
local function UV(bar, x, y)
    local u, v = x, y
    if bar.rotated then u, v = y, 1 - x end
    if bar.mirror then u = 1 - u end
    return u * bar.uMax, v * bar.vMax
end
local function Crop(bar, texture, x0, y0, x1, y1)
    texture:ClearAllPoints(); texture:SetPoint("TOPLEFT", bar, "TOPLEFT", x0 * bar.width, -y0 * bar.height)
    texture:SetWidth(math.max(0.001, (x1 - x0) * bar.width)); texture:SetHeight(math.max(0.001, (y1 - y0) * bar.height))
    local a, b = UV(bar, x0, y0); local c, d = UV(bar, x0, y1)
    local e, f = UV(bar, x1, y0); local g, h = UV(bar, x1, y1)
    texture:SetTexCoord(a, b, c, d, e, f, g, h)
end
function B.SetValue(bar, value)
    value = math.max(0, math.min(1, value or 0))
    if bar.value == value and not bar.dirty then return end
    bar.value, bar.dirty = value, false
    if value <= 0 then bar.fill:Hide(); bar.highlight:Hide(); return end
    local x0, y0, x1, y1 = bar.x0, bar.y0, bar.x1, bar.y1
    if bar.vertical then
        if bar.reverse then y1 = y0 + (y1 - y0) * value else y0 = y1 - (y1 - y0) * value end
    elseif bar.reverse then x0 = x1 - (x1 - x0) * value else x1 = x0 + (x1 - x0) * value end
    Crop(bar, bar.fill, x0, y0, x1, y1); bar.fill:Show()
    if bar.hasHighlight then Crop(bar, bar.highlight, x0, y0, x1, y1); bar.highlight:Show()
    else bar.highlight:Hide() end
end
function B.Create(parent)
    local bar = UI.CreateContainer(nil, parent)
    bar.background = UI.CreateTexture(bar, nil, "BACKGROUND")
    bar.fill = UI.CreateTexture(bar, nil, "BORDER")
    bar.highlight = UI.CreateTexture(bar, nil, "ARTWORK")
    bar.shell = UI.CreateTexture(bar, nil, "OVERLAY")
    -- The source socket is opaque. Its replacement must render above the shell,
    -- independent of ordering among textures in the same draw layer.
    bar.iconHost = UI.CreateContainer(nil, bar)
    bar.iconHost:SetAllPoints(bar); bar.iconHost:SetFrameLevel(bar:GetFrameLevel() + 1)
    bar.icon = UI.CreateTexture(bar.iconHost, nil, "OVERLAY")
    bar.dividers = {}
    for i = 1, 4 do bar.dividers[i] = UI.CreateTexture(bar, nil, "OVERLAY"); bar.dividers[i]:Hide() end
    return bar
end
function B.Apply(bar, options)
    local art = UI.HUDTextures and UI.HUDTextures[options.texture]
    bar.width, bar.height = options.width, options.height
    bar:SetWidth(bar.width); bar:SetHeight(bar.height)
    bar.vertical, bar.mirror = options.orientation == "vertical", options.mirror
    bar.reverse = bar.vertical and options.direction == "topToBottom" or not bar.vertical and options.direction == "rightToLeft"
    bar.rotated = art and ((art.orientation == "vertical") ~= bar.vertical) or false
    bar.uMax, bar.vMax = art and art.uMax or 1, art and art.vMax or 1
    local bounds = art and art.fillBounds
    local x0, y0, x1, y1 = 0, 0, 1, 1
    if bounds then x0, y0, x1, y1 = bounds[1], bounds[2], bounds[3], bounds[4] end
    if bar.mirror then x0, x1 = 1 - x1, 1 - x0 end
    if bar.rotated then x0, y0, x1, y1 = 1 - y1, x0, 1 - y0, x1 end
    bar.x0, bar.y0, bar.x1, bar.y1 = x0, y0, x1, y1
    local path = art and art.fill or options.texture == "flat" and "Interface\\Buttons\\WHITE8X8" or "Interface\\TargetingFrame\\UI-StatusBar"
    bar.background:SetTexture(path); bar.fill:SetTexture(path)
    bar.hasHighlight = art and art.highlight ~= nil
    if bar.hasHighlight then bar.highlight:SetTexture(art.highlight); bar.highlight:SetVertexColor(1, 1, 1, 1) end
    bar.background:SetVertexColor(options.background[1], options.background[2], options.background[3], options.backgroundOpacity)
    bar.fill:SetVertexColor(options.color[1], options.color[2], options.color[3], 1)
    Crop(bar, bar.background, 0, 0, 1, 1)
    if art and options.border then bar.shell:SetTexture(art.shell); Crop(bar, bar.shell, 0, 0, 1, 1); bar.shell:Show()
    else bar.shell:Hide() end
    bar.icon:Hide()
    if art and art.icon and options.icon then
        local x, y = art.icon.x, art.icon.y
        if bar.mirror then x = 1 - x end
        local iw, ih = art.icon.width, art.icon.height
        if bar.rotated then x, y, iw, ih = 1 - y, x, ih, iw end
        bar.icon:SetTexture(options.icon); bar.icon:SetTexCoord(0, 1, 0, 1)
        bar.icon:ClearAllPoints(); bar.icon:SetPoint("CENTER", bar, "TOPLEFT", x * bar.width, -y * bar.height)
        bar.icon:SetWidth(iw * bar.width); bar.icon:SetHeight(ih * bar.height); bar.icon:Show()
    end
    for i, divider in ipairs(bar.dividers) do
        if options.segments and not art then
            divider:SetTexture(0, 0, 0, 1); divider:ClearAllPoints()
            if bar.vertical then
                divider:SetPoint("CENTER", bar, "TOPLEFT", bar.width / 2, -bar.height * i / 5)
                divider:SetWidth(bar.width); divider:SetHeight(2)
            else
                divider:SetPoint("CENTER", bar, "TOPLEFT", bar.width * i / 5, -bar.height / 2)
                divider:SetWidth(2); divider:SetHeight(bar.height)
            end
            divider:Show()
        else divider:Hide() end
    end
    bar.dirty = true; B.SetValue(bar, bar.value or 0)
    return art ~= nil
end
