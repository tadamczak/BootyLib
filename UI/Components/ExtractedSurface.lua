local UI = BootyLib.UI.Components
local Catalog = UI.ExtractedTextures
local Assert = assert
local Surface = {}
UI.ExtractedSurface = Surface
local corners = {"tl","tr","bl","br"}
local edges = {"top","bottom","left","right"}
local solid = {path="Interface\\Buttons\\WHITE8X8",width=1,height=1,stretch=true}
local function Region(frame, key, part, x, y, width, height, alpha, u, v)
    local regions = frame.bootyExtractedRegions
    local texture = regions[key]
    if width<=0 or height<=0 then if texture then texture:Hide() end; return end
    if not texture then texture = UI.CreateTexture(frame,nil,key=="background" and "BACKGROUND" or "BORDER"); regions[key]=texture end
    if texture.bootyExtractedPath~=part.path then
        Assert(texture:SetTexture(part.path)~=false,"Extracted texture was rejected: "..part.path)
        texture.bootyExtractedPath=part.path
    end
    texture:ClearAllPoints();texture:SetPoint("TOPLEFT",frame,"TOPLEFT",x,-y)
    texture:SetWidth(math.max(0.01,width));texture:SetHeight(math.max(0.01,height))
    texture:SetTexCoord(0,u or 1,0,v or 1);texture:SetAlpha(alpha);texture:Show()
end
function Surface.Refresh(frame)
    local state=frame.bootyExtractedState
    if not state then return end
    local owner=state.owner or frame
    local width,height=owner:GetWidth()+(state.paddingX or 0),owner:GetHeight()+(state.paddingY or 0)
    if width<=0 or height<=0 then return end
    for _,texture in pairs(frame.bootyExtractedRegions) do texture:Hide() end
    local border=state.enabled and Catalog.chatBorders[state.border]
    -- Keep each rail's centreline on the owner's rectangle. Scale its art on
    -- both sides of that fixed axis, without changing the background bounds.
    local scale=state.scale/100
    local left,top,right,bottom=0,0,0,0
    if border then
        local p=border.parts
        left=(p.left.box[1]+p.left.box[3]/2)*scale
        top=(p.top.box[2]+p.top.box[4]/2)*scale
        right=(border.width-p.right.box[1]-p.right.box[3]/2)*scale
        bottom=(border.height-p.bottom.box[2]-p.bottom.box[4]/2)*scale
    end
    local background=Catalog.backgrounds[state.background] or (border and state.background=="color" and solid)
    if background and state.backgroundAlpha>=0 then
        local x,y,w,h=0,0,width,height
        Region(frame,"background",background,x,y,w,h,state.backgroundAlpha,
            background.stretch and 1 or w/background.width,background.stretch and 1 or h/background.height)
        local r,g,b=1,1,1
        if background==solid then
            if state.color then r,g,b=state.color[1],state.color[2],state.color[3]
            else r,g,b=frame:GetBackdropColor() end
        end
        frame.bootyExtractedRegions.background:SetVertexColor(r,g,b)
    end
    if not border then return end
    local p=border.parts
    local function X(value,far) return value*scale+(far and width+right-border.width*scale or -left) end
    local function Y(value,far) return value*scale+(far and height+bottom-border.height*scale or -top) end
    for _,name in ipairs(edges) do
        local part=p[name];local b=part.box;local x,y,w,h
        if name=="top" or name=="bottom" then
            local lower=name=="bottom";local a=p[lower and "bl" or "tl"].box;local z=p[lower and "br" or "tr"].box
            x=X(a[1]+a[3]-border.overlap,false);y=Y(b[2],lower)
            w=X(z[1]+border.overlap,true)-x;h=b[4]*scale
        else
            local right=name=="right";local a=p[right and "tr" or "tl"].box;local z=p[right and "br" or "bl"].box
            x=X(b[1],right);y=Y(a[2]+a[4]-border.overlap,false)
            w=b[3]*scale;h=Y(z[2]+border.overlap,true)-y
        end
        Region(frame,name,part,x,y,w,h,state.alpha,w/(part.width*scale),h/(part.height*scale))
    end
    for _,name in ipairs(corners) do
        local part=p[name];local b=part.box
        Region(frame,name,part,X(b[1],name=="tr" or name=="br"),Y(b[2],name=="bl" or name=="br"),b[3]*scale,b[4]*scale,state.alpha)
    end
end
local function Resize() if this:IsVisible() then Surface.Refresh(this) end end
function Surface.Apply(frame,background,border,enabled,scale,backgroundAlpha,alpha,owner,paddingX,paddingY,color)
    if not frame.bootyExtractedRegions and not Catalog.backgrounds[background] and not Catalog.chatBorders[border] then return end
    if not frame.bootyExtractedRegions then
        frame.bootyExtractedRegions={};frame.bootyExtractedState={}
        -- Only the dedicated surface is owned here; no native script is replaced.
        frame:SetScript("OnSizeChanged",Resize)
        frame:SetScript("OnShow",Resize)
    end
    local state=frame.bootyExtractedState
    state.background,state.border,state.enabled=background,border,enabled
    state.scale,state.backgroundAlpha,state.alpha=scale,backgroundAlpha,alpha
    -- Anchored child GetWidth/GetHeight can lag behind the native chat owner.
    state.owner,state.paddingX,state.paddingY=owner,paddingX,paddingY
    state.color=color
    Surface.Refresh(frame)
end
