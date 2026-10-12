local UI = BootyLib.UI.Components
local Catalog = UI.ExtractedTextures
local Assert = assert
local Surface = {}
UI.ExtractedSurface = Surface
local corners = {"tl","tr","bl","br"}
local edges = {"top","bottom","left","right"}
local function Region(frame, key, part, x, y, width, height, alpha, u, v)
    local regions = frame.bootyExtractedRegions
    local texture = regions[key]
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
    local width,height=frame:GetWidth(),frame:GetHeight()
    if width<=0 or height<=0 then return end
    for _,texture in pairs(frame.bootyExtractedRegions) do texture:Hide() end
    local border=state.enabled and Catalog.chatBorders[state.border]
    -- Fit tiny windows without crossing corners. Scaling never changes chat bounds.
    local scale=math.min(state.scale/100,width/220,height/130)
    local background=Catalog.backgrounds[state.background]
    if background and state.backgroundAlpha>=0 then
        local x,y,w,h=0,0,width,height
        if border then
            local p=border.parts
            x=(p.left.box[1]+p.left.box[3]-1)*scale;y=(p.top.box[2]+p.top.box[4]-1)*scale
            w=width+(p.right.box[1]-border.width+1)*scale-x
            h=height+(p.bottom.box[2]-border.height+1)*scale-y
        end
        Region(frame,"background",background,x,y,w,h,state.backgroundAlpha,
            background.stretch and 1 or w/background.width,background.stretch and 1 or h/background.height)
    end
    if not border then return end
    local p=border.parts
    local function X(value,right) return value*scale+(right and width-border.width*scale or 0) end
    local function Y(value,bottom) return value*scale+(bottom and height-border.height*scale or 0) end
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
function Surface.Apply(frame,background,border,enabled,scale,backgroundAlpha,alpha)
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
    Surface.Refresh(frame)
end
