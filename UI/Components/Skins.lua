local Booty = BootyLib
local UI = Booty.UI.Components

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

local function CreateNineSlice(parent, path, width, height, inset, layer, region, firstTexture, target)
    local set = target or { textures = {}, inset = inset }
    set.complete = false
    local x, y = inset / width, inset / height
    local coords = {
        { 0, x, 0, y }, { x, 1 - x, 0, y }, { 1 - x, 1, 0, y },
        { 0, x, y, 1 - y }, { x, 1 - x, y, 1 - y }, { 1 - x, 1, y, 1 - y },
        { 0, x, 1 - y, 1 }, { x, 1 - x, 1 - y, 1 }, { 1 - x, 1, 1 - y, 1 },
    }
    local index
    for index = 1, 9 do
        local texture = set.textures[index] or index == 1 and firstTexture or parent:CreateTexture(nil, layer or "BACKGROUND")
        set.textures[index] = texture
        if target then texture:Hide(); texture:ClearAllPoints() else texture:SetTexture(path) end
        local uv = coords[index]
        if target then -- The rounded painter checks its first texture/UV writes.
        elseif region then
            texture:SetTexCoord(region[1] + uv[1] * (region[2] - region[1]), region[1] + uv[2] * (region[2] - region[1]), region[3] + uv[3] * (region[4] - region[3]), region[3] + uv[4] * (region[4] - region[3]))
        else texture:SetTexCoord(unpack(uv)) end
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
    set.inset, set.complete = inset, true
    return set
end

local function SizeNineSlice(set, inset)
    if set.inset == inset then return end
    -- Publish only after every native write succeeds: a setter may mutate and
    -- throw, and a retry with this same inset must repair the whole geometry.
    set.inset = nil
    local t = set.textures
    local index
    for index = 1, 9 do
        if index == 1 or index == 3 or index == 7 or index == 9 then t[index]:SetWidth(inset); t[index]:SetHeight(inset) end
    end
    t[2]:SetHeight(inset); t[8]:SetHeight(inset); t[4]:SetWidth(inset); t[6]:SetWidth(inset)
    set.inset = inset
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
local roundedGold = "Interface\\AddOns\\BootyLib\\Assets\\HoverNativeOutline"
local roundedSurfaces = "Interface\\AddOns\\BootyLib\\Assets\\HoverRoundedSurfaces"
local function RoundedArtwork(set, path, left, right, top, bottom, sourceInset, renderedInset, r, g, b, a)
    set.ready = false
    local inset = sourceInset / 16
    for index = 1, 9 do
        local column, row = math.mod(index - 1, 3), math.floor((index - 1) / 3)
        local u0 = column == 0 and 0 or column == 1 and 15 / 16 or inset
        local u1 = column == 0 and inset or column == 1 and 1 or 0
        local v0 = row == 0 and 0 or row == 1 and 15 / 16 or inset
        local v1 = row == 0 and inset or row == 1 and 1 or 0
        local texture = set.textures[index]
        if texture:SetTexture(path) == false then error("Rounded project artwork was declined.") end
        if texture:SetTexCoord(left + u0 * (right - left), left + u1 * (right - left),
            top + v0 * (bottom - top), top + v1 * (bottom - top)) == false then error("Rounded project coordinates were declined.") end
        if texture:SetVertexColor(r, g, b, a) == false then error("Rounded project color was declined.") end
    end
    SizeNineSlice(set, renderedInset)
end
local function RoundedVisibility(set, visible, background)
    local failure
    set.visible = nil
    for index = 1, 9 do
        local texture, shown = set.textures[index], visible and (background or index ~= 5)
        if texture then
        local ok, reason = pcall(shown and texture.Show or texture.Hide, texture)
        if ok and reason == false then ok, reason = false, "Rounded project visibility was declined." end
        if ok then
            ok, reason = pcall(texture.IsShown, texture)
            if ok and (reason ~= nil and reason ~= false and reason ~= 0) ~= shown then ok, reason = false, "Rounded project visibility was declined." end
        end
        if not ok then failure = failure or tostring(reason) end
        end
    end
    if failure then set.ready = false; error(failure) end
    set.visible = visible
end
local function RoundedArea(set, parent, expansion)
    local textures = set.textures
    textures[1]:ClearAllPoints(); textures[1]:SetPoint("TOPLEFT", parent, "TOPLEFT", -expansion, expansion)
    textures[3]:ClearAllPoints(); textures[3]:SetPoint("TOPRIGHT", parent, "TOPRIGHT", expansion, expansion)
    textures[7]:ClearAllPoints(); textures[7]:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", -expansion, -expansion)
    textures[9]:ClearAllPoints(); textures[9]:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", expansion, -expansion)
end
-- Both surfaces reuse one caller-owned primary texture. Extra slices are
-- allocated only on the first visible hover and survive later style changes.
function UI.SetRoundedHoverSurface(parent, primary, visible, kind, extent, radius, r, g, b, a)
    visible=visible~=nil and visible~=false and visible~=0
    local set = primary.bootyRoundedHover
    if not visible and not set then
        if primary:Hide() == false then error("Rounded project visibility was declined.") end
        local shown = primary:IsShown()
        if shown ~= nil and shown ~= false and shown ~= 0 then error("Rounded project visibility was declined.") end
        return
    end
    local background = kind == "background"
    radius = math.ceil(math.min(radius, extent / 2))
    local sourceRadius = math.min(10, radius)
    local sourceInset = math.max(background and 2 or 8, sourceRadius)
    local inset = math.min(math.max(sourceInset, radius), extent / 2)
    if not set then set = {textures = {}}; primary.bootyRoundedHover = set end
    if not visible and not set.complete then RoundedVisibility(set, false, background); return end
    if not set.complete then
        CreateNineSlice(parent, roundedSurfaces, 32, 32, sourceInset, background and "ARTWORK" or "OVERLAY", nil, primary, set)
    end
    if not set.ready or set.kind ~= kind or set.extent ~= extent or set.radius ~= radius
        or set.r ~= r or set.g ~= g or set.b ~= b or set.a ~= a or set.ownerWidth ~= parent:GetWidth() then
        local slot = sourceRadius * 2 + (background and 0 or 1)
        local column, row = math.mod(slot, 8), math.floor(slot / 8)
        RoundedArtwork(set, roundedSurfaces, (column * 18 + 1) / 256, (column * 18 + 17) / 256,
            (row * 18 + 1) / 64, (row * 18 + 17) / 64, sourceInset, inset, r, g, b, a)
        RoundedArea(set, parent, (extent - parent:GetWidth()) / 2)
        for index = 1, 9 do set.textures[index]:SetBlendMode(background and "BLEND" or "ADD") end
        set.kind, set.extent, set.radius, set.r, set.g, set.b, set.a, set.ownerWidth = kind, extent, radius, r, g, b, a, parent:GetWidth()
    end
    if not set.ready or set.visible ~= visible then RoundedVisibility(set, visible, background) end
    set.ready = true
end

-- 1.12 has no arbitrary texture mask. Reused horizontal crops clip icons without
-- opaque corner covers, borrowed minimaps, per-frame allocations or idle handlers.
function UI.RoundedTextureRow(width, height, radius, index, count)
    radius = math.max(0, math.min(radius, width / 2, height / 2))
    local top, bottom = (index - 1) * height / count, index * height / count
    local y = (top + bottom) / 2
    local distance = math.max(0, radius - math.min(y, height - y))
    local inset = radius - math.sqrt(math.max(0, radius * radius - distance * distance))
    return inset, top, width - inset * 2, bottom - top
end
local function TextureWrite(texture, method, first, second, third, fourth, fifth)
    local result
    if fifth ~= nil then result=texture[method](texture,first,second,third,fourth,fifth)
    elseif fourth ~= nil then result=texture[method](texture,first,second,third,fourth)
    elseif third ~= nil then result=texture[method](texture,first,second,third)
    elseif second ~= nil then result=texture[method](texture,first,second)
    elseif first ~= nil or method == "SetTexture" then result=texture[method](texture,first)
    else result=texture[method](texture) end
    if result == false then error("Rounded texture rejected " .. method .. ".") end
end
local function TextureVisibility(texture,visible)
    local shown=texture:IsShown()
    if (shown~=nil and shown~=false and shown~=0)~=visible then TextureWrite(texture,visible and "Show" or "Hide") end
    shown=texture:IsShown()
    if (shown~=nil and shown~=false and shown~=0)~=visible then error("Rounded texture visibility was declined.") end
end
local function SetRoundedTextureColor(primary, r, g, b, a)
    TextureWrite(primary, "SetVertexColor", r, g, b, a)
    local set = primary.bootyRoundedTexture
    if set and (not set.ready or set.r ~= r or set.g ~= g or set.b ~= b or set.a ~= a) then
        set.ready = false
        for _, region in ipairs(set.textures) do TextureWrite(region, "SetVertexColor", r, g, b, a) end
        set.r, set.g, set.b, set.a, set.ready = r, g, b, a, true
    end
end
local function SetRoundedTexture(primary, options)
    local width, height, radius = options.width, options.height, options.radius or 0
    if type(width) ~= "number" or type(height) ~= "number" or width <= 0 or height <= 0
        or width ~= width or height ~= height or type(radius) ~= "number" or radius ~= radius then
        error("Rounded texture geometry is invalid.")
    end
    radius = math.max(0, math.min(radius, width / 2, height / 2))
    local set = primary.bootyRoundedTexture
    local visible = options.visible ~= nil and options.visible ~= false and options.visible ~= 0 and options.path ~= nil
    local left, right, top, bottom = options.left or 0, options.right or 1, options.top or 0, options.bottom or 1
    local x, y = options.x or 0, options.y or 0
    local clipTop,clipBottom=options.clipTop or 0,options.clipBottom or height
    if type(clipTop)~="number" or type(clipBottom)~="number" or clipTop~=clipTop or clipBottom~=clipBottom
        or clipTop<0 or clipBottom>height or clipTop>clipBottom then error("Rounded texture clipping is invalid.") end
    if radius == 0 or not visible then
        if set and set.visible then for _, region in ipairs(set.textures) do TextureVisibility(region,false) end;set.visible=false end
        if set and radius==0 then set.radius=0;set.ready=false end
        if radius == 0 and (not primary.bootySquareReady or primary.bootySquarePath~=options.path
            or primary.bootySquareLeft~=left or primary.bootySquareRight~=right or primary.bootySquareTop~=top or primary.bootySquareBottom~=bottom) then
            primary.bootySquareReady=false
            TextureWrite(primary,"SetTexture",options.path);TextureWrite(primary,"SetTexCoord",left,right,top,bottom)
            primary.bootySquarePath,primary.bootySquareLeft,primary.bootySquareRight,primary.bootySquareTop,primary.bootySquareBottom=options.path,left,right,top,bottom
            primary.bootySquareReady=true
        end
        local shown=primary:IsShown()
        TextureVisibility(primary,visible and radius==0)
        return
    end
    if not set then set={textures={}};primary.bootyRoundedTexture=set end
    local changed = not set.ready or set.width ~= width or set.height ~= height or set.radius ~= radius or set.path ~= options.path
        or set.left ~= left or set.right ~= right or set.top ~= top or set.bottom ~= bottom or set.x ~= x or set.y ~= y
        or set.clipTop~=clipTop or set.clipBottom~=clipBottom
    set.ready=false
    if changed or not set.visible then
    for index=1,32 do
        local region=set.textures[index]
        if not region then region=UI.CreateTexture(options.owner,nil,options.layer or "BACKGROUND");set.textures[index]=region;changed=true end
        local rx,ry,rw,rh=UI.RoundedTextureRow(width,height,radius,index,32)
        local clippedY=math.max(ry,clipTop);local clippedHeight=math.min(ry+rh,clipBottom)-clippedY
        if changed and clippedHeight>0 then
            ry,rh=clippedY,clippedHeight
            TextureWrite(region,"SetTexture",options.path);TextureWrite(region,"ClearAllPoints")
            TextureWrite(region,"SetPoint","TOPLEFT",options.owner,"TOPLEFT",x+rx,y-ry)
            TextureWrite(region,"SetWidth",rw);TextureWrite(region,"SetHeight",rh)
            TextureWrite(region,"SetTexCoord",left+rx/width*(right-left),left+(rx+rw)/width*(right-left),top+ry/height*(bottom-top),top+(ry+rh)/height*(bottom-top))
            TextureWrite(region,"SetBlendMode",options.blend or "BLEND")
        end
        if changed or not set.visible then TextureVisibility(region,clippedHeight>0) end
    end
    end
    primary.bootySquareReady=false
    TextureVisibility(primary,false)
    set.width,set.height,set.radius,set.path,set.left,set.right,set.top,set.bottom,set.x,set.y=width,height,radius,options.path,left,right,top,bottom,x,y
    set.clipTop,set.clipBottom=clipTop,clipBottom
    set.visible,set.ready=true,true
    SetRoundedTextureColor(primary,options.r or 1,options.g or 1,options.b or 1,options.a or 1)
end

local function RoundedCall(callback,primary,first,second,third,fourth)
    local savedThis,savedEvent,a1,a2,a3,a4,a5,a6,a7,a8,a9=this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9
    local ok,reason=pcall(callback,primary,first,second,third,fourth)
    this,event,arg1,arg2,arg3,arg4,arg5,arg6,arg7,arg8,arg9=savedThis,savedEvent,a1,a2,a3,a4,a5,a6,a7,a8,a9
    if not ok then error(reason,0) end
end
function UI.SetRoundedTexture(primary,options) return RoundedCall(SetRoundedTexture,primary,options) end
function UI.SetRoundedTextureColor(primary,r,g,b,a) return RoundedCall(SetRoundedTextureColor,primary,r,g,b,a) end
function UI.IsRoundedTextureShown(primary)
    local set=primary.bootyRoundedTexture
    if set and set.radius>0 then return set.visible==true end
    return primary:IsShown()
end
function UI.SetProjectButtonOutline(button, visible, size, color, topInset, minimumLevel, radius, extent)
    visible=visible~=nil and visible~=false and visible~=0
    if not button.bootyProjectOutline then
        local border = UI.CreateContainer(nil, button)
        border:SetAllPoints(button); border:EnableMouse(false)
        border:SetFrameLevel(button:GetFrameLevel() + 1)
        UI.ApplyDropdownChoiceSurface(border)
        border:SetBackdropColor(0, 0, 0, 0)
        border:SetBackdropBorderColor(1, 0.78, 0.2, 1)
        button.bootyProjectOutline = border
    end
    local border = button.bootyProjectOutline
    border:ClearAllPoints()
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, -(topInset or 0))
    border:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(math.max(button:GetFrameLevel() + 1, minimumLevel or 0))
    color = color or projectOutlineGold
    if radius ~= nil then
        local thickness = math.floor(math.max(1, math.min(10, tonumber(size) or 2)))
        radius = math.max(0, math.min(50, (extent or button:GetWidth()) / 2, tonumber(radius) or 0))
        local sourceRadius = math.min(10, math.floor(radius))
        local sourceInset = math.max(sourceRadius, thickness)
        local inset = math.max(radius, thickness)
        local set = border.bootyRoundedOutline
        if visible and not set then set = {textures = {}}; border.bootyRoundedOutline = set end
        local diameter=extent or button:GetWidth()
        local circular=diameter>0 and radius>=diameter/2
        if circular and set then
            if set.complete then RoundedVisibility(set,false,false) end
            local texture=set.circleTexture
            if visible and not texture then texture=UI.CreateTexture(border,nil,"OVERLAY");set.circleTexture=texture end
            if texture then
                local band=math.max(1,math.min(30,math.floor(thickness*60/diameter+0.5)))
                local slot=band-1;local column,row=math.mod(slot,8),math.floor(slot/8)
                if not set.circleReady or set.circleBand~=band or set.r~=color[1] or set.g~=color[2] or set.b~=color[3] then
                    set.circleReady=false
                    TextureWrite(texture,"SetTexture","Interface\\AddOns\\BootyLib\\Assets\\HoverNativeCircles")
                    TextureWrite(texture,"SetAllPoints",border)
                    TextureWrite(texture,"SetTexCoord",(column*62+1)/512,(column*62+61)/512,(row*62+1)/256,(row*62+61)/256)
                    TextureWrite(texture,"SetVertexColor",color[1],color[2],color[3],1)
                    set.circleReady,set.circleBand=true,band
                end
                TextureVisibility(texture,visible)
            end
            set.radius,set.inset,set.thickness,set.r,set.g,set.b=radius,radius,thickness,color[1],color[2],color[3]
            set.ready=false
        else
        if set and set.circleTexture then TextureVisibility(set.circleTexture,false);set.circleReady=false end
        if set and not set.complete and visible then
            CreateNineSlice(border, roundedGold, 32, 32, inset, "OVERLAY", nil, nil, set)
        end
        if set and set.complete then
            if not set.ready or set.radius ~= radius or set.thickness ~= thickness
                or set.r ~= color[1] or set.g ~= color[2] or set.b ~= color[3] then
                local sourceThickness = math.max(1, math.floor(thickness * sourceInset / inset + 0.5))
                local slot = sourceRadius * 10 + sourceThickness - 1
                local column, row = math.mod(slot, 16), math.floor(slot / 16)
                RoundedArtwork(set, roundedGold, (column * 18 + 1) / 512, (column * 18 + 17) / 512,
                    (row * 18 + 1) / 128, (row * 18 + 17) / 128, sourceInset, inset, color[1], color[2], color[3], 1)
                set.radius, set.thickness, set.r, set.g, set.b = radius, thickness, color[1], color[2], color[3]
            end
            if not set.ready or set.visible ~= visible then RoundedVisibility(set, visible, false) end
            set.ready = true
        elseif set then RoundedVisibility(set, false, false)
        end
        end
        border:SetBackdropBorderColor(0, 0, 0, 0); border.bootyRoundedOutlineActive = true
    else
        if border.bootyRoundedOutline then
            RoundedVisibility(border.bootyRoundedOutline,false,false)
            if border.bootyRoundedOutline.circleTexture then TextureVisibility(border.bootyRoundedOutline.circleTexture,false) end
        end
        border.bootyRoundedOutlineActive = nil; border:SetAlpha(1)
    end
    local edgeSize = math.max(1, math.min(6, tonumber(size) or 2)) * 4
    if radius == nil and border.bootyEdgeSize ~= edgeSize then
        local backdrop = border:GetBackdrop(); backdrop.edgeSize = edgeSize
        border:SetBackdrop(backdrop); border:SetBackdropColor(0, 0, 0, 0); border.bootyEdgeSize = edgeSize
    end
    if radius == nil then border:SetBackdropBorderColor(color[1], color[2], color[3], 1) end
    if visible then button.bootyProjectOutline:Show() else button.bootyProjectOutline:Hide() end
end

-- Asset metadata belongs to the caller. These pooled primitives also support
-- atlas regions, preserving authored corners when the owner is resized.
local function ApplyAtlasSurface(frame)
    if not frame.bootyAtlasStyle then
        SetNineSliceShown(frame.bootyAtlasSurface, false)
        SetNineSliceShown(frame.bootyAtlasHighlight, false)
        return false
    end
    local style = frame.bootyAtlasStyle
    if not frame.bootyAtlasSurface then
        frame.bootyAtlasSurface = CreateNineSlice(frame, style.path, style.width, style.height, style.inset, "BACKGROUND", style.coords)
        frame.bootyAtlasSurface.style = style
    end
    SetAtlasArtwork(frame.bootyAtlasSurface, style)
    frame:SetBackdropColor(0,0,0,0); frame:SetBackdropBorderColor(0,0,0,0)
    if frame.bootyColorFill then frame.bootyColorFill:Hide() end
    if frame.bootyClassicRowShade then frame.bootyClassicRowShade:Hide() end
    SetNineSliceShown(frame.bootyAtlasSurface, true)
    return true
end

function UI.SetAtlasHighlight(frame, visible, style, size, color)
    if not visible then SetNineSliceShown(frame.bootyAtlasHighlight, false); return end
    if visible and not frame.bootyAtlasHighlight then
        frame.bootyAtlasHighlight = CreateNineSlice(frame, style.path, style.width, style.height, style.inset, "BORDER", style.coords)
        frame.bootyAtlasHighlight.style = style
    end
    if not frame.bootyAtlasHighlight then return end
    SetAtlasArtwork(frame.bootyAtlasHighlight, style)
    SizeNineSlice(frame.bootyAtlasHighlight, math.min(style.height / 2, frame:GetHeight() / 2, frame:GetWidth() / 2, style.inset * (size or 1)))
    local index
    for index = 1, 9 do
        local texture = frame.bootyAtlasHighlight.textures[index]
        texture:SetBlendMode("ADD")
        texture:SetVertexColor(color[1], color[2], color[3], 1)
    end
    SetNineSliceShown(frame.bootyAtlasHighlight, visible and frame.bootyAtlasStyle ~= nil)
    frame.bootyAtlasHighlight.textures[5]:Hide()
end

function UI.SetAtlasOutline(frame, visible, style, size, color, topInset, minimumLevel)
    if not frame.bootyAtlasOutline and not visible then return end
    if not frame.bootyAtlasOutline then
        local border = UI.CreateContainer(nil, frame)
        border:EnableMouse(false)
        border.art = CreateNineSlice(border, style.path, style.width, style.height, style.inset, "OVERLAY", style.coords)
        border.art.style = style
        border.art.textures[5]:Hide()
        frame.bootyAtlasOutline = border
    end
    local border = frame.bootyAtlasOutline
    border:ClearAllPoints(); border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -(topInset or 0)); border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    border:SetFrameLevel(math.max(frame:GetFrameLevel() + 1, minimumLevel or 0))
    SetAtlasArtwork(border.art, style)
    SizeNineSlice(border.art, math.min(frame:GetWidth() / 2, math.max(1, frame:GetHeight() - (topInset or 0)) / 2, style.inset * (size or 1)))
    for index = 1, 9 do border.art.textures[index]:SetVertexColor(color[1], color[2], color[3], 1) end
    if visible then border:Show() else border:Hide() end
end

local function ApplyButtonArtwork(button, entry)
    local art = button.bootyButtonArtwork
    if not art then return end
    SetNineSliceShown(entry.classicSkin, false); SetNineSliceShown(entry.classicHoverBorder, false); SetNineSliceShown(entry.classicSelectedBorder, false)
    if entry.classicRedFill then entry.classicRedFill:Hide() end
    if entry.redHover then entry.redHover:Hide() end
    if button.bootyHighlight then button.bootyHighlight:Hide() end
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
    if button.bootyClassicSelected then button:SetBackdropBorderColor(1, 0.78, 0.2, 1)
    else button:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end
end

local function ApplySolidButton(entry)
    local button = entry.frame
    UI.ApplyDropdownChoiceSurface(button)
    button:EnableMouse(true)
    if button.bootyHighlight then button.bootyHighlight:Hide() end
    SetNineSliceShown(entry.classicSkin, false); SetNineSliceShown(entry.classicHoverBorder, false)
    SetNineSliceShown(entry.classicSelectedBorder, false)
    if entry.classicRedFill then entry.classicRedFill:Hide() end
    if entry.redHover then entry.redHover:Hide() end
    button:SetHighlightTexture(nil); button:SetPushedTexture(nil); button:SetDisabledTexture(nil)
end

local function ApplySizedButtonGeometry(button, entry)
    if not button.bootyButtonScale then
        if UI.ApplyButtonCaptionBaseline then UI.ApplyButtonCaptionBaseline(button) end
        return
    end
    local scale = button.bootyButtonScale
    local iconSize = (button.bootyBaseIconSize or 13) * scale
    local inset = (button.bootyBaseIconInset or 7) * scale
    if button.bootyClassicIconKey then
        button.bootyClassicIconSize = iconSize; button.bootyClassicIconInset = inset; button.bootyClassicIconYOffset = 0
        if entry and entry.classicIcon then
            entry.classicIcon:SetWidth(iconSize); entry.classicIcon:SetHeight(iconSize)
            entry.classicIcon:ClearAllPoints(); entry.classicIcon:SetPoint("LEFT", button, "LEFT", inset, 0)
            entry.classicIcon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
        end
    end
    if button.label then
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT", button, "TOPLEFT", button.bootyClassicIconKey and inset + iconSize + 4 or 0, 0)
        button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 0)
        button.label:SetJustifyH(button.bootyClassicIconKey and "LEFT" or "CENTER"); button.label:SetJustifyV("MIDDLE")
    end
    if UI.ApplyButtonCaptionBaseline then UI.ApplyButtonCaptionBaseline(button) end
end

local function ApplyControl(entry)
    local button = entry.frame
    if Skins.current ~= "classic" or button.bootyClassicVariant ~= "red" then entry.hovered = nil end
    local solid = button.bootyClassicKeepNormalSurface
    if Skins.current == "classic" then
        local useSelectedSurface = button.bootyClassicSelected and not button.bootyClassicKeepNormalSurface
        local variant = useSelectedSurface and "red" or (button.bootyClassicVariant or "dark")
        local state = (useSelectedSurface or variant == "red" or button.bootyClassicPersistentRed) and "selected" or "normal"
        if not button.bootyClassicKeepNormalSurface then
            if not entry.classicSkin then entry.classicSkin = CreateNineSlice(button, ClassicPath("Buttons\\" .. variant .. "-" .. state .. ".tga"), 128, 32, 6, "BACKGROUND")
            else SetNineSliceTexture(entry.classicSkin, ClassicPath("Buttons\\" .. variant .. "-" .. state .. ".tga")) end
            local center = entry.classicSkin.textures[5]
            center:ClearAllPoints(); center:SetPoint("TOPLEFT", entry.classicSkin.textures[1], "BOTTOMRIGHT", 0, 0)
            center:SetPoint("BOTTOMRIGHT", entry.classicSkin.textures[9], "TOPLEFT", 0, 0); center:SetVertexColor(1,1,1,1)
            button:SetBackdropColor(0, 0, 0, 0); button:SetBackdropBorderColor(0, 0, 0, 0); SetNineSliceShown(entry.classicSkin, true)
            button:SetHighlightTexture(nil)
            if button.bootyHighlight then button.bootyHighlight:Hide() end
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
            if state == "selected" and not button.bootyClassicCompactControl then entry.classicRedFill:Show() else entry.classicRedFill:Hide() end
        end
        if button.bootyClassicVariant == "red" and not button.bootyClassicCompactControl then
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
        local disabled = button.bootyClassicDisabled
        local gold = not disabled and (button.bootyClassicGold or button.bootyClassicSelected)
        local red, green, blue = 1, 1, 1
        if disabled then red, green, blue = 0.48, 0.48, 0.46
        elseif gold then red, green, blue = 1, 0.82, 0.28 end
        if button.label then button.label:SetTextColor(red, green, blue) end
        if button.bootyClassicIconKey then
            if not entry.classicIcon then
                entry.classicIcon = button:CreateTexture(nil, "OVERLAY")
                entry.classicIcon:SetPoint("LEFT", button, "LEFT", 7, 0)
            end
            entry.classicIcon:SetWidth(button.bootyClassicIconSize or 13); entry.classicIcon:SetHeight(button.bootyClassicIconSize or 13)
            entry.classicIcon:SetTexture(ClassicPath("Icons\\" .. button.bootyClassicIconKey .. ".tga")); entry.classicIcon:Show()
            entry.classicIcon:ClearAllPoints(); entry.classicIcon:SetPoint("LEFT", button, "LEFT", button.bootyClassicIconInset or 7, button.bootyClassicIconYOffset or 0)
            entry.classicIcon:SetVertexColor(unpack(UI.Theme.colors.goldIcon))
            -- Keep the label on its original full button bounds. Reserving space
            -- for the icon moved the visual centre of every caption.
            if button.label and entry.labelPoints then
                button.label:ClearAllPoints()
                if button.bootyClassicReserveIconSpace then
                    button.label:SetPoint("TOPLEFT", button, "TOPLEFT", (button.bootyClassicIconInset or 7) + (button.bootyClassicIconSize or 13) + 3, 0)
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
        if button.label and button.bootyClassicLabelYOffset then
            button.label:ClearAllPoints()
            button.label:SetPoint("TOPLEFT", button, "TOPLEFT", button.bootyClassicLabelXOffset or 0, button.bootyClassicLabelYOffset)
            button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", button.bootyClassicLabelXOffset or 0, button.bootyClassicLabelYOffset)
            button.label:SetJustifyH("CENTER"); button.label:SetJustifyV("MIDDLE")
        end
        if button.bootyHighlight then button.bootyHighlight:SetTexture("Interface\\Buttons\\WHITE8X8"); button.bootyHighlight:SetVertexColor(0.55, 0.38, 0.08, 0.35) end
        if button.bootyClassicCompactControl then
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
        if button.bootyHighlight then button.bootyHighlight:Show(); button.bootyHighlight:SetAlpha(1); button.bootyHighlight:SetTexture(unpack(entry.highlight)); button.bootyHighlight:SetVertexColor(1, 1, 1, 1) end
    end
    if button.label and button.bootyTextColor then button.label:SetTextColor(unpack(button.bootyClassicSelected and button.bootySelectedTextColor or button.bootyTextColor)) end
    if solid then
        ApplySolidButton(entry)
    elseif Skins.current == "classic" and not button.bootyClassicCompactControl and button.bootyClassicVariant ~= "red" and not button.bootyClassicSelected then
        UI.ApplyDropdownChoiceSurface(button)
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicSkin then
            local center = entry.classicSkin.textures[5]
            center:ClearAllPoints(); center:SetPoint("TOPLEFT", button, "TOPLEFT", 3, -3); center:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -3, 3); center:Show()
        end
        SetNineSliceShown(entry.classicHoverBorder, false)
        SetNineSliceShown(entry.classicSelectedBorder, false)
        button:SetPushedTexture(nil); button:SetDisabledTexture(nil)
        if button.bootyClassicVariant == "red" or button.bootyClassicSelected then button:SetBackdropBorderColor(1, 0.78, 0.2, 1) end
    end
    if button.label and not button.bootyTextColor and entry.hovered and Skins.current == "classic" and button.bootyClassicVariant == "red" and not button.bootyClassicDisabled then
        entry.restR, entry.restG, entry.restB, entry.restA = button.label:GetTextColor()
        button.label:SetTextColor(0.82, 0.82, 0.78)
    end
    if button.label and button.bootyLabelInsets then
        button.label:ClearAllPoints()
        button.label:SetPoint("LEFT", button, "LEFT", button.bootyLabelInsets[1], 0)
        button.label:SetPoint("RIGHT", button, "RIGHT", -button.bootyLabelInsets[2], 0)
        button.label:SetJustifyH("LEFT")
    end
    if button.label and button.bootyClassicCompactControl and button.bootyClassicLabelYOffset then
        button.label:ClearAllPoints()
        button.label:SetPoint("TOPLEFT", button, "TOPLEFT", button.bootyClassicLabelXOffset or 0, button.bootyClassicLabelYOffset)
        button.label:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", button.bootyClassicLabelXOffset or 0, button.bootyClassicLabelYOffset)
    end
    ApplySizedButtonGeometry(button, entry)
    if button.bootyBorderless then
        if Skins.current == "classic" and entry.classicSkin and not solid then
            SetNineSliceShown(entry.classicSkin, false)
            local center = entry.classicSkin.textures[5]
            center:ClearAllPoints(); center:SetAllPoints(button)
            local brightness = button.bootyClassicDisabled and 0.45 or 1
            center:SetVertexColor(brightness,brightness,brightness,1); center:Show()
        end
        SetNineSliceShown(entry.classicHoverBorder, false); SetNineSliceShown(entry.classicSelectedBorder, false)
        if entry.redHover then entry.redHover:ClearAllPoints(); entry.redHover:SetAllPoints(button) end
        if entry.classicRedFill then entry.classicRedFill:Hide() end
        button:SetPushedTexture(nil); button:SetDisabledTexture(nil); button:SetBackdropBorderColor(0,0,0,0)
        if button.bootyProjectOutline then button.bootyProjectOutline:Hide() end
    end
    if button.bootyWarmListRow then UI.StyleWarmListRow(button, button.bootyWarmListSelected) end
    if button.bootySelectableTableRow and UI.StyleSelectableTableRow then UI.StyleSelectableTableRow(button,button.bootyTableRowEven,button.bootyTableRowSelected) end
    ApplyButtonArtwork(button, entry)
end

function UI.SetButtonTextColor(button, color)
    if not button then return end
    button.bootyTextColor = color
    if button.label then button.label:SetTextColor(unpack(color)) end
end

local function GoldHoverEnter()
    if this.IsEnabled and not this:IsEnabled() then return end
    this:SetBackdropBorderColor(1, 0.78, 0.2, 1)
    if this.bootyHoverTextColor and this.label then this.label:SetTextColor(unpack(this.bootyHoverTextColor)) end
end

local function GoldHoverLeave()
    if this.bootyHoverTextColor and this.label then this.label:SetTextColor(unpack(this.bootyClassicSelected and this.bootyHoverTextColor or this.bootyTextColor or {1,1,1})) end
    if this.bootyClassicKeepNormalSurface and this.bootyClassicSelected then this:SetBackdropBorderColor(1, 0.78, 0.2, 1); return end
    local color = this.bootyNormalBorder
    if color then this:SetBackdropBorderColor(color[1], color[2], color[3], color[4]) end
end

function UI.AttachGoldHoverBorder(button, red, green, blue, alpha)
    button.bootyNormalBorder = { red, green, blue, alpha }
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
    if frame.bootyTransparentSurface then
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicFill then entry.classicFill:Hide() end
        frame:SetBackdropColor(0,0,0,0); frame:SetBackdropBorderColor(0,0,0,0)
        return
    end
    if not frame.bootyUseNativeSurface and (Skins.current == "classic" or frame.bootyJoinedTop ~= nil or frame.bootyHorizontalBorders) then
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
        if frame.bootyClassicRowShade then frame.bootyClassicRowShade:Show() end
        SetNineSliceShown(entry.classicSkin, true)
        if entry.classicSkin then
            local index
            for index = 1, 9 do entry.classicSkin.textures[index]:SetAlpha(frame.bootyCompactBorder and 0.2 or 1) end
        end
    else
        SetNineSliceShown(entry.classicSkin, false)
        if entry.classicFill then entry.classicFill:Hide() end
        if frame.bootyClassicRowShade then frame.bootyClassicRowShade:Hide() end
        frame:SetBackdrop(entry.backdrop)
        frame:SetBackdropColor(unpack(entry.background)); frame:SetBackdropBorderColor(unpack(entry.border))
        if frame.bootyCompactBorder then frame:SetBackdropBorderColor(entry.border[1], entry.border[2], entry.border[3], 0.2) end
    end
    if entry.classicSkin and frame.bootyJoinedTop ~= nil then
        local t = entry.classicSkin.textures
        if frame.bootyJoinedTop then
            t[1]:SetTexCoord(0, 6/32, 6/32, 26/32); t[3]:SetTexCoord(26/32, 1, 6/32, 26/32)
        end
        if frame.bootyJoinedBottom then
            t[7]:SetTexCoord(0, 6/32, 6/32, 26/32); t[9]:SetTexCoord(26/32, 1, 6/32, 26/32); t[8]:Hide()
        end
    end
    if frame.bootySeparatorsOnly and entry.classicSkin then
        local t = entry.classicSkin.textures
        local index
        for index = 1, 9 do if index ~= 2 or not frame.bootyJoinedTop then t[index]:Hide() end end
        t[2]:ClearAllPoints(); t[2]:SetPoint("TOPLEFT",frame,"TOPLEFT",-(frame.bootyBorderOutsetLeft or 0),0); t[2]:SetPoint("TOPRIGHT",frame,"TOPRIGHT",frame.bootyBorderOutsetRight or 0,0)
        if entry.classicFill then entry.classicFill:Hide() end
    end
    if frame.bootyHorizontalBorders and entry.classicSkin then
        local t = entry.classicSkin.textures
        t[1]:Hide(); t[3]:Hide(); t[4]:Hide(); t[5]:Hide(); t[6]:Hide(); t[7]:Hide(); t[9]:Hide()
        t[2]:ClearAllPoints(); t[2]:SetPoint("TOPLEFT",frame,"TOPLEFT",-(frame.bootyBorderOutsetLeft or 0),0); t[2]:SetPoint("TOPRIGHT",frame,"TOPRIGHT",frame.bootyBorderOutsetRight or 0,0)
        t[8]:ClearAllPoints(); t[8]:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",-(frame.bootyBorderOutsetLeft or 0),0); t[8]:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",frame.bootyBorderOutsetRight or 0,0)
        if entry.kind == "title" then
            -- Omit the black inner bevel authored above the visible separator.
            t[8]:SetTexCoord(6/32, 26/32, 29/32, 1); t[8]:SetHeight(3)
        end
        if not frame.bootyBorderTop then t[2]:Hide() end
        if not frame.bootyBorderBottom then t[8]:Hide() end
        if frame.bootyBorderRight then
            t[6]:Show(); t[6]:ClearAllPoints(); t[6]:SetPoint("TOPRIGHT",frame,"TOPRIGHT",0,0); t[6]:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
        end
    end
    if frame.bootyRowColor then UI.SetRowColor(frame, frame.bootyRowColor, frame.bootyRowAlpha) end
    if frame.bootySurfaceBorderHidden then
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
    local entry = this.bootySkinEntry
    if entry.onEnter then entry.onEnter() end
    if Skins.current == "classic" and not this.bootyClassicDisabled then this:SetBackdropBorderColor(1, 0.78, 0.2, 1) end
    local enabled = not this.IsEnabled or this:IsEnabled()
    if Skins.current ~= "classic" or this.bootyClassicVariant ~= "red" or this.bootyClassicCompactControl or this.bootyClassicDisabled or enabled == false or enabled == 0 then return end
    if not entry.hovered then entry.restR, entry.restG, entry.restB, entry.restA = this.label:GetTextColor() end
    entry.hovered = true
    if not this.bootyTextColor then this.label:SetTextColor(0.82, 0.82, 0.78) end
end

local function RedHoverLeave()
    local entry = this.bootySkinEntry
    if entry.hovered then
        entry.hovered = nil
        if this.bootyClassicDisabled then this.label:SetTextColor(0.48, 0.48, 0.46)
        else this.label:SetTextColor(entry.restR, entry.restG, entry.restB, entry.restA) end
    end
    if entry.onLeave then entry.onLeave() end
    if Skins.current == "classic" then
        if this.bootyClassicVariant == "red" or this.bootyClassicSelected then this:SetBackdropBorderColor(1, 0.78, 0.2, 1)
        else this:SetBackdropBorderColor(0.35, 0.35, 0.35, 1) end
    end
end

function UI.RegisterSkinnedControl(frame, backdrop, background, border, highlight)
    -- Authored red artwork owns its outline. Later action/hover styling must
    -- never add the native backdrop edge over it.
    if not frame.bootyBorderSetterInstalled then
        local setBorder = frame.SetBackdropBorderColor
        frame.SetBackdropBorderColor = function(self, red, green, blue, alpha)
            if self.bootyButtonArtwork or self.bootyBorderless or (Skins.current == "classic" and self.bootyClassicVariant == "red" and not self.bootyClassicCompactControl and not self.bootyClassicKeepNormalSurface) then
                return setBorder(self, 0, 0, 0, 0)
            end
            return setBorder(self, red, green, blue, alpha)
        end
        frame.bootyBorderSetterInstalled = true
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
    frame.bootySkinEntry = entry
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
    frame.bootySurfaceEntry = entry
    Skins.surfaces[table.getn(Skins.surfaces) + 1] = entry
    ApplySurface(entry)
end

function UI.SetSurfaceCompact(frame, compact)
    local wanted = compact and true or false
    if frame.bootyCompactBorder == wanted then return end
    frame.bootyCompactBorder = wanted
    if frame.bootySurfaceEntry then ApplySurface(frame.bootySurfaceEntry) end
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
    frame.bootyNavigationSkinEntry = entry
    Skins.navigation[table.getn(Skins.navigation) + 1] = entry
    ApplyNavigation(entry)
end

function UI.SetNavigationTabBorder(frame, visible)
    local entry = frame.bootyNavigationSkinEntry
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
    if button.bootySkinEntry then ApplyControl(button.bootySkinEntry) end
end

function UI.SetClassicButtonVariant(button, variant)
    if not button then return end
    local wanted = variant == "red" and "red" or "dark"
    if button.bootyClassicVariant == wanted then return end
    button.bootyClassicVariant = wanted
    if Skins.current ~= "classic" then return end
    ApplyButtonState(button)
end

function UI.SetButtonBorderless(button, borderless)
    local wanted = borderless and true or false
    if button.bootyBorderless == wanted then return end
    button.bootyBorderless = wanted; ApplyButtonState(button)
end

function UI.SetButtonArtwork(button, artwork)
    if button.bootyButtonArtwork == artwork then return end
    button.bootyButtonArtwork = artwork
    if not artwork then button:SetNormalTexture(nil) end
    ApplyButtonState(button)
end

function UI.SetAtlasSurface(frame, style)
    if frame.bootyAtlasStyle == style then return end
    frame.bootyAtlasStyle = style
    if frame.bootySurfaceEntry then ApplySurface(frame.bootySurfaceEntry)
    else ApplyAtlasSurface(frame) end
end

function UI.SetTextureBackground(frame, path, color, alpha)
    if not path then
        if frame.bootyTextureBackground then frame.bootyTextureBackground:Hide() end
        frame.bootyBackgroundPath = nil
        return
    end
    if not frame.bootyTextureBackground then
        frame.bootyTextureBackground = frame:CreateTexture(nil, "BACKGROUND")
        frame.bootyTextureBackground:SetAllPoints(frame)
    end
    local texture = frame.bootyTextureBackground
    if frame.bootyBackgroundPath ~= path then texture:SetTexture(path); frame.bootyBackgroundPath = path end
    if color then texture:SetVertexColor(color[1], color[2], color[3], alpha or 1)
    else texture:SetVertexColor(1,1,1,alpha or 1) end
    texture:Show()
end

function UI.SetClassicButtonSelected(button, selected)
    if not button then return end
    local wanted = selected and true or false
    if button.bootyClassicSelected == wanted then return end
    button.bootyClassicSelected = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonCompact(button, compact)
    if not button then return end
    local wanted = compact and true or false
    if button.bootyClassicCompactControl == wanted then return end
    button.bootyClassicCompactControl = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonGold(button, gold)
    if not button then return end
    local wanted = gold and true or false
    if button.bootyClassicGold == wanted then return end
    button.bootyClassicGold = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonDisabled(button, disabled)
    if not button then return end
    local wanted = disabled and true or false
    if button.bootyClassicDisabled == wanted then return end
    button.bootyClassicDisabled = wanted
    ApplyButtonState(button)
end

function UI.SetClassicButtonIcon(button, iconKey, size, inset, yOffset)
    if not button then return end
    local wantedSize, wantedInset, wantedY = size or 13, inset or 7, yOffset or 0
    -- Compare requested geometry, not the effective values derived by sizing.
    if button.bootyClassicIconKey == iconKey and button.bootyBaseIconSize == wantedSize and button.bootyBaseIconInset == wantedInset and button.bootyBaseIconYOffset == wantedY then return end
    button.bootyClassicIconKey = iconKey
    button.bootyClassicIconSize = wantedSize
    button.bootyBaseIconSize = wantedSize; button.bootyBaseIconInset = wantedInset; button.bootyBaseIconYOffset = wantedY
    button.bootyClassicIconInset = wantedInset
    button.bootyClassicIconYOffset = wantedY
    ApplyButtonState(button)
end

function UI.SetClassicButtonLabelOffset(button, offset, xOffset)
    if not button then return end
    local wantedX = xOffset or 0
    if button.bootyClassicLabelYOffset == offset and button.bootyClassicLabelXOffset == wantedX then return end
    button.bootyClassicLabelYOffset = offset
    button.bootyClassicLabelXOffset = wantedX
    ApplyButtonState(button)
end

function UI.SizeClassicButton(button, width, height, fontScale)
    if not button then return end
    button:SetScale(1)
    button:SetWidth(width); button:SetHeight(height)
    button.bootyButtonScale = fontScale or 1
    ApplySizedButtonGeometry(button, button.bootySkinEntry)
    if not button.label then return end
    if not button.bootyBaseFontSize then
        button.bootyBaseFontPath, button.bootyBaseFontSize, button.bootyBaseFontFlags = button.label:GetFont()
    end
    if button.bootyBaseFontPath and button.bootyBaseFontSize then
        button.label:SetFont(button.bootyBaseFontPath, button.bootyBaseFontSize * (fontScale or 1), button.bootyBaseFontFlags)
    end
end

function UI.SetRowColor(row, color, alpha)
    row.bootyRowColor = color; row.bootyRowAlpha = alpha
    if row.bootyAtlasStyle then
        if row.bootyColorFill then row.bootyColorFill:Hide() end
        return
    end
    row:SetBackdropColor(0, 0, 0, 0)
    if not row.bootyColorFill then
        row.bootyColorFill = row:CreateTexture(nil, "BORDER")
        row.bootyColorFill:SetAllPoints(row)
        row.bootyColorFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    end
    -- Set opacity through the region API; never overwrite it with SetAlpha(1).
    row.bootyColorFill:SetVertexColor(color[1], color[2], color[3])
    row.bootyColorFill:SetAlpha(alpha or 1); row.bootyColorFill:Show()
    local entry = row.bootySurfaceEntry
    if entry and entry.classicFill then entry.classicFill:Hide() end
    if row.bootyClassicRowShade then row.bootyClassicRowShade:Hide() end
end

function UI.SetClassicRowShade(row, even, hovered, selected)
    if not row then return end
    if row.bootyAtlasStyle then return end
    if row.bootyRowColor then UI.SetRowColor(row, row.bootyRowColor, row.bootyRowAlpha); return end
    if not row.bootyClassicRowShade then
        row.bootyClassicRowShade = row:CreateTexture(nil, "BORDER")
        row.bootyClassicRowShade:SetAllPoints(row)
        row.bootyClassicRowShade:SetTexture(1, 1, 1, 1)
    end
    if Skins.current == "classic" then
        row.bootyClassicRowShade:SetAlpha(selected and 0.13 or hovered and 0.10 or even and 0.055 or 0.01)
        row.bootyClassicRowShade:Show()
    else row.bootyClassicRowShade:Hide() end
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
    if frame.bootySurfaceBorderHidden == not visible then return end
    frame.bootySurfaceBorderHidden = not visible
    if frame.bootySurfaceEntry then ApplySurface(frame.bootySurfaceEntry) end
end

function UI.SetSurfaceHorizontalBorders(frame, top, bottom, right)
    frame.bootyHorizontalBorders = true
    frame.bootyBorderTop = top ~= false; frame.bootyBorderBottom = bottom ~= false; frame.bootyBorderRight = right == true
    if frame.bootySurfaceEntry then ApplySurface(frame.bootySurfaceEntry) end
end

function UI.JoinSurfaceEdges(frame, top, bottom, leftOutset, rightOutset)
    if frame.bootyJoinedTop == top and frame.bootyJoinedBottom == bottom and frame.bootyBorderOutsetLeft == leftOutset and frame.bootyBorderOutsetRight == rightOutset then return end
    frame.bootyBorderOutsetLeft = leftOutset; frame.bootyBorderOutsetRight = rightOutset
    frame.bootyJoinedTop = top; frame.bootyJoinedBottom = bottom
    frame.bootySeparatorsOnly = true
    if frame.bootySurfaceEntry then ApplySurface(frame.bootySurfaceEntry) end
end

function UI.SetSurfaceTransparent(frame, transparent)
    frame.bootyTransparentSurface = transparent and true or false
    if frame.bootySurfaceEntry then ApplySurface(frame.bootySurfaceEntry) end
end
