local Lib = BootyLib
local Pose = {}; Lib.Core.WindowPose = Pose
Pose.fields = {"left", "bottom", "width", "height", "scale", "anchor", "relativeId", "relativePoint", "offsetX", "offsetY"}
Pose.points = {"TOPLEFT", "TOP", "TOPRIGHT", "LEFT", "CENTER", "RIGHT", "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT"}
local fractions = {TOPLEFT={0,1}, TOP={0.5,1}, TOPRIGHT={1,1}, LEFT={0,0.5}, CENTER={0.5,0.5},
    RIGHT={1,0.5}, BOTTOMLEFT={0,0}, BOTTOM={0.5,0}, BOTTOMRIGHT={1,0}}
function Pose.Finite(value) return type(value)=="number" and value==value and value-value==0 end
function Pose.Copy(value)
    local result={};for _,key in ipairs(Pose.fields) do result[key]=value and value[key] end;return result
end
function Pose.Reference(id)
    local owner, viewId
    if id=="booty.suite.window" then owner=Lib.GetSuite and Lib.GetSuite();viewId="suite"
    elseif type(id)=="string" then
        local _,_,product,view=string.find(id,"^booty%.([%w]+)%.window%.([%w]+)$")
        if product and Lib.GetProductHost then owner=Lib.GetProductHost(product);viewId=view end
    end
    if not owner or not owner.GetGeometryReference then return nil,"The anchor element is unavailable." end
    local ok,result,detail=pcall(owner.GetGeometryReference,viewId)
    if not ok then return nil,tostring(result) end
    if result~=true or type(detail)~="table" then return nil,type(detail)=="table" and detail.message or detail or "The anchor element is unavailable." end
    return detail
end
local function Reference(rect,context,selfId,allowMissing)
    if rect.relativeId=="screen" then return {left=0,bottom=0,width=context.width,height=context.height} end
    local cursor,seen=rect.relativeId,{}
    for depth=1,16 do
        if cursor==selfId or seen[cursor] then error("Anchor dependencies contain a cycle.") end
        seen[cursor]=true
        local reference,reason=Pose.Reference(cursor)
        if not reference or not reference.available then
            if allowMissing then return nil,reason or "The anchor element is not open." end
            error(reason or "Open and restore the anchor element before editing.")
        end
        local nextId=reference.stored and reference.stored.relativeId
        if not nextId or nextId=="screen" then break end
        cursor=nextId
        if depth==16 then error("Anchor dependency limit exceeded.") end
    end
    local reference,reason=Pose.Reference(rect.relativeId)
    if not reference then error(reason) end
    local frame=reference.frame
    if not frame or not frame.GetEffectiveScale then error("The anchor has no readable bounds.") end
    local scale=frame:GetEffectiveScale()/context.scale
    local left,bottom=frame:GetLeft(),frame:GetBottom()
    if not Pose.Finite(scale) or scale<=0 or not Pose.Finite(left) or not Pose.Finite(bottom) then error("Anchor bounds are unavailable.") end
    return {frame=frame,left=left*scale,bottom=bottom*scale,width=frame:GetWidth()*scale,height=frame:GetHeight()*scale}
end
function Pose.Normalize(value,context,limits,selfId,allowMissing)
    local rect=Pose.Copy(value)
    for _,key in ipairs({"left","bottom","width","height"}) do if not Pose.Finite(rect[key]) then error("Invalid window geometry: "..key) end end
    if rect.width<=0 or rect.height<=0 then error("Window dimensions must be positive.") end
    rect.scale=rect.scale or 1
    if not Pose.Finite(rect.scale) or rect.scale<0.5 or rect.scale>2 then error("Window scale must be between50% and200%.") end
    -- Preserve the owner's usable minimum dimensions on a small display.
    rect.scale=math.min(rect.scale,math.max(0.5,math.min(2,(context.width-24)/limits.minWidth,(context.height-24)/limits.minHeight)))
    rect.anchor,rect.relativeId=rect.anchor or "BOTTOMLEFT",rect.relativeId or "screen"
    rect.relativePoint=rect.relativePoint or rect.anchor
    if not fractions[rect.anchor] or not fractions[rect.relativePoint] then error("Unknown window anchor point.") end
    if type(rect.relativeId)~="string" then error("Invalid anchor element.") end
    local maxWidth=math.min(limits.maxWidth,math.max(1,context.width-24)/rect.scale)
    local maxHeight=math.min(limits.maxHeight,math.max(1,context.height-24)/rect.scale)
    rect.width=math.max(math.min(limits.minWidth,maxWidth),math.min(maxWidth,rect.width))
    rect.height=math.max(math.min(limits.minHeight,maxHeight),math.min(maxHeight,rect.height))
    local reference,warning=Reference(rect,context,selfId,allowMissing)
    if not reference then
        rect.relativeId,rect.anchor,rect.relativePoint="screen","BOTTOMLEFT","BOTTOMLEFT"
        rect.offsetX,rect.offsetY=nil,nil
        reference={left=0,bottom=0,width=context.width,height=context.height}
    end
    local point,relative=fractions[rect.anchor],fractions[rect.relativePoint]
    local originX=reference.left+reference.width*relative[1]-rect.width*rect.scale*point[1]
    local originY=reference.bottom+reference.height*relative[2]-rect.height*rect.scale*point[2]
    if rect.offsetX~=nil or rect.offsetY~=nil then
        if not Pose.Finite(rect.offsetX) or not Pose.Finite(rect.offsetY) then error("Anchor offsets must be finite numbers.") end
        rect.left,rect.bottom=originX+rect.offsetX,originY+rect.offsetY
    end
    rect.left=math.max(0,math.min(math.max(0,context.width-rect.width*rect.scale),rect.left))
    rect.bottom=math.max(0,math.min(math.max(0,context.height-rect.height*rect.scale),rect.bottom))
    rect.offsetX,rect.offsetY=rect.left-originX,rect.bottom-originY
    return rect,reference,warning
end
function Pose.Capture(frame,context)
    local rect=Pose.Copy(frame.mosGeometryPose)
    local scale=frame:GetEffectiveScale()/context.scale
    rect.scale=scale;rect.width,rect.height=frame:GetWidth(),frame:GetHeight()
    local left,bottom=frame:GetLeft(),frame:GetBottom()
    if not Pose.Finite(left) or not Pose.Finite(bottom) or not Pose.Finite(scale) or scale<=0 then error("Window bounds are unavailable.") end
    rect.left,rect.bottom=left*scale,bottom*scale
    rect.anchor,rect.relativeId=rect.anchor or "BOTTOMLEFT",rect.relativeId or "screen"
    rect.relativePoint=rect.relativePoint or rect.anchor
    local reference=Reference(rect,context,nil,true)
    if not reference then
        rect.anchor,rect.relativeId,rect.relativePoint="BOTTOMLEFT","screen","BOTTOMLEFT"
        reference={left=0,bottom=0,width=context.width,height=context.height}
    end
    local point,relative=fractions[rect.anchor],fractions[rect.relativePoint]
    if not point or not relative then error("Unknown window anchor point.") end
    rect.offsetX=rect.left-reference.left-reference.width*relative[1]+rect.width*scale*point[1]
    rect.offsetY=rect.bottom-reference.bottom-reference.height*relative[2]+rect.height*scale*point[2]
    return rect
end
function Pose.Draw(frame,rect,reference)
    if math.abs(frame:GetEffectiveScale()/UIParent:GetEffectiveScale()-rect.scale)>0.00001 then frame:SetScale(rect.scale) end
    if math.abs(frame:GetEffectiveScale()/UIParent:GetEffectiveScale()-rect.scale)>0.0001 then error("The client declined the window scale.") end
    if frame:GetWidth()~=rect.width then frame:SetWidth(rect.width) end
    if frame:GetHeight()~=rect.height then frame:SetHeight(rect.height) end
    frame:ClearAllPoints()
    frame:SetPoint(rect.anchor,reference.frame or UIParent,rect.relativePoint,rect.offsetX/rect.scale,rect.offsetY/rect.scale)
    frame.mosGeometryPose=Pose.Copy(rect)
end
function Pose.Snap(value,step)
    if not Pose.Finite(value) or not Pose.Finite(step) or step<4 or step>100 then error("Invalid grid position or spacing.") end
    return math.floor(value/step+0.5)*step
end
