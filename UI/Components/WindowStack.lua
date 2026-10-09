-- One event-driven stack for every Booty product; never patch foreign frames.
local UI = BootyLib.UI.Components
local Stack = {windows = {}, overlays = {}, bandSize = 512}
UI.WindowStack = Stack
local order, context, applying = {}, nil, false
local FIRST_LEVEL, CHILD_LIMIT = 64, 510
local function Visible(frame) return frame and frame.IsVisible and frame:IsVisible() end
local function Source(owner) if type(owner) == "function" then return owner() end; return owner end
local function Find(frame, depth)
    frame = Source(frame)
    depth = depth or 0
    if depth > 64 then return nil end
    while frame do
        local record = frame.bootyWindowStackRecord
        if record then
            if record.kind == "window" then return record end
            return Find(Source(record.owner), depth + 1) or record
        end
        local attachment = frame.bootyWindowStackAttachment
        if attachment then return Find(Source(attachment.owner), depth + 1) end
        frame = frame.GetParent and frame:GetParent()
    end
end
function Stack.GetWindow(frame) local record = Find(frame); return record and record.frame end
function Stack.GetOwner(frame)
    local record = frame and frame.bootyWindowStackRecord
    local owner = record and Source(record.owner)
    return Stack.GetWindow(owner) or owner or nil
end
function Stack.GetBand(frame) local record = Find(frame); if record then return record.low, record.high end end
local function NativeLevel(frame, value)
    if frame:GetFrameLevel() ~= value then (frame.bootyStackSetLevel or frame.SetFrameLevel)(frame, value) end
end
local function NativeStrata(frame)
    if frame:GetFrameStrata() ~= "FULLSCREEN_DIALOG" then (frame.bootyStackSetStrata or frame.SetFrameStrata)(frame, "FULLSCREEN_DIALOG") end
end
local function Bound(record, value) return math.max(record.low + 1, math.min(record.low + CHILD_LIMIT, value)) end
local function SetLevel(self, value)
    local record = Find(self)
    if applying or not record or not record.low then return self.bootyStackSetLevel(self, value) end
    if self == record.frame then return end -- A root's order belongs to the stack.
    local parent = self:GetParent()
    local parentLevel = parent and parent.GetFrameLevel and parent:GetFrameLevel() or record.frame:GetFrameLevel()
    self.bootyStackLevelOffset = math.max(0, math.min(100, value - parentLevel))
    return self.bootyStackSetLevel(self, Bound(record, parentLevel + self.bootyStackLevelOffset))
end
local function SetStrata(self, value)
    if not applying and Find(self) then value = "FULLSCREEN_DIALOG" end
    return self.bootyStackSetStrata(self, value)
end
local function FocusInput(frame, handler)
    return function()
        Stack.FocusFrom(frame)
        if handler then handler() end
    end
end
local function TrackInput(frame)
    if frame.bootyStackInputSetScript or not frame.SetScript then return end
    frame.bootyStackInputSetScript = frame.SetScript
    frame.SetScript = function(self, eventName, handler)
        if eventName == "OnMouseDown" or eventName == "OnDragStart" then
            handler = FocusInput(self, handler)
        end
        return self.bootyStackInputSetScript(self, eventName, handler)
    end
    frame:SetScript("OnMouseDown", frame:GetScript("OnMouseDown"))
    frame:SetScript("OnDragStart", frame:GetScript("OnDragStart"))
end
function Stack.Track(frame)
    if not frame or frame.bootyStackSetLevel or not frame.SetFrameLevel then return frame end
    frame.bootyStackSetLevel, frame.bootyStackSetStrata = frame.SetFrameLevel, frame.SetFrameStrata
    local parent = frame.GetParent and frame:GetParent()
    local parentLevel = parent and parent.GetFrameLevel and parent:GetFrameLevel() or 0
    frame.bootyStackLevelOffset = math.max(1, math.min(100, frame:GetFrameLevel() - parentLevel))
    frame.SetFrameLevel, frame.SetFrameStrata = SetLevel, SetStrata
    TrackInput(frame)
    local record = not applying and Find(frame)
    if record and record.low and frame ~= record.frame then
        NativeStrata(frame)
        NativeLevel(frame, Bound(record, parentLevel + frame.bootyStackLevelOffset))
    end
    return frame
end
local function CaptureTree(frame, root)
    if frame ~= root and frame.bootyWindowStackRecord and frame.bootyWindowStackRecord.kind == "window" then return end
    Stack.Track(frame)
    if frame.GetChildren then
        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do CaptureTree(child, root) end
    end
end
local function ApplyTree(frame, record, root, level)
    if frame ~= root and frame.bootyWindowStackRecord and frame.bootyWindowStackRecord.kind == "window" then return end
    Stack.Track(frame)
    NativeStrata(frame)
    if frame == root then NativeLevel(frame, level)
    else
        local parent = frame:GetParent()
        local base = parent and parent.GetFrameLevel and parent:GetFrameLevel() or level
        NativeLevel(frame, Bound(record, base + (frame.bootyStackLevelOffset or 1)))
    end
    if frame.GetChildren then
        local children = {frame:GetChildren()}
        for _, child in ipairs(children) do ApplyTree(child, record, root, level) end
    end
end
local function PopupDepth(record)
    local depth, owner = 0, Source(record.owner)
    while owner and depth < 4 do
        local popup = owner.bootyWindowStackRecord
        if not popup or popup.kind ~= "popup" then break end
        depth = depth + 1; owner = Source(popup.owner)
    end
    return depth
end
local function OwnsBand(record) return record.kind == "window" or not Find(Source(record.owner)) end
local function ApplyOverlay(overlay, record)
    local owner = Source(overlay.owner)
    local base = overlay.kind == "popup" and record.low + 386 + PopupDepth(overlay) * 24
        or (owner and owner.GetFrameLevel and owner:GetFrameLevel() or record.frame:GetFrameLevel()) + (overlay.offset or 1)
    ApplyTree(overlay.frame, record, overlay.frame, Bound(record, base))
end
local function Reflow()
    if applying then return end
    applying = true
    -- Capture offsets before any native parent propagation changes its tree.
    for _, record in ipairs(order) do
        if Visible(record.frame) or record.opening then CaptureTree(record.frame, record.frame) end
    end
    for _, overlay in ipairs(Stack.overlays) do
        if Visible(overlay.frame) or overlay.opening then CaptureTree(overlay.frame, overlay.frame) end
    end
    local position = 0
    for _, record in ipairs(order) do
        if OwnsBand(record) and (Visible(record.frame) or record.opening) then
            record.low = FIRST_LEVEL + position * Stack.bandSize
            record.high = record.low + Stack.bandSize - 1
            position = position + 1
            ApplyTree(record.frame, record, record.frame, record.low + 2)
        end
    end
    for _, overlay in ipairs(Stack.overlays) do
        local record = Find(Source(overlay.owner))
        if record and record.low and (Visible(overlay.frame) or overlay.opening) then
            ApplyOverlay(overlay, record)
        end
    end
    applying = false
end
local function ParentRecord(record) return record.owner and Find(Source(record.owner)) end
local function Family(record)
    local count = 0
    while record and count < 64 do
        local parent = ParentRecord(record)
        if not parent or parent == record then return record end
        record = parent; count = count + 1
    end
    return record
end
local function InBranch(record, ancestor)
    local count = 0
    while record and count < 64 do
        if record == ancestor then return true end
        local parent = ParentRecord(record)
        if parent == record then return false end
        record = parent; count = count + 1
    end
    return false
end
local function BringForward(record)
    if Stack.focused == record then return false end
    Stack.focused = record
    local family = Family(record)
    local pending = {}
    for index = table.getn(order), 1, -1 do
        local item = order[index]
        if Family(item) == family then table.insert(pending, 1, table.remove(order, index)) end
    end
    -- Keep siblings in order, then move the selected child branch to the end.
    for _, item in ipairs(pending) do if not InBranch(item, record) then table.insert(order, item) end end
    for _, item in ipairs(pending) do if InBranch(item, record) then table.insert(order, item) end end
    Reflow()
    return true
end
local function SetLogicalOwner(record, owner)
    if owner == false then record.owner = nil; return end
    owner = Source(owner)
    local candidate = Find(owner)
    if candidate == record or candidate and InBranch(candidate, record) then return end
    record.owner = owner
end
local function ResolveOpener(record)
    if record.defaultOwner == false then return end
    local proposed = context or this
    if proposed == record.frame or Find(proposed) == record then proposed = nil end
    if not proposed or not Find(proposed) then proposed = Source(record.defaultOwner) or record.owner end
    if proposed then SetLogicalOwner(record, proposed) end
end
function Stack.SetOwner(frame, owner)
    local record = frame and frame.bootyWindowStackRecord
    if record then
        local previous = ParentRecord(record)
        record.defaultOwner = owner; SetLogicalOwner(record, owner)
        if ParentRecord(record) ~= previous then Stack.focused = nil end
    end
end
function Stack.Raise(frame, owner)
    local record = Find(frame)
    if not record then return end
    if owner ~= nil then SetLogicalOwner(record, owner); Stack.focused = nil end
    BringForward(record)
end
function Stack.FocusFrom(frame)
    local record = Find(frame)
    if record then BringForward(record) end
end
function Stack.Sync(frame)
    if applying then return end
    frame = Source(frame)
    local record = Find(frame)
    if not record or not (Visible(record.frame) or record.opening) then return end
    if not record.low then Reflow(); return end
    applying = true
    CaptureTree(frame, frame)
    for _, overlay in ipairs(Stack.overlays) do
        if overlay.frame ~= frame and (Visible(overlay.frame) or overlay.opening) and Find(Source(overlay.owner)) == record then
            CaptureTree(overlay.frame, overlay.frame)
        end
    end
    local own = frame.bootyWindowStackRecord or frame.bootyWindowStackAttachment
    if own and own ~= record then ApplyOverlay(own, record)
    else
        local parent = frame.GetParent and frame:GetParent()
        local level = frame == record.frame and record.low + 2
            or Bound(record, (parent and parent.GetFrameLevel and parent:GetFrameLevel() or record.frame:GetFrameLevel()) + (frame.bootyStackLevelOffset or 1))
        ApplyTree(frame, record, frame, level)
    end
    for _, overlay in ipairs(Stack.overlays) do
        if overlay.frame ~= frame and (Visible(overlay.frame) or overlay.opening) and Find(Source(overlay.owner)) == record then
            ApplyOverlay(overlay, record)
        end
    end
    applying = false
end
function Stack.WithOwner(owner, callback)
    local previous = context; context = owner
    local ok, result = pcall(callback)
    context = previous
    if not ok then error(result) end
    return result
end
local function CloseOverlays(owner)
    for _, overlay in ipairs(Stack.overlays) do
        if Find(Source(overlay.owner)) == owner and overlay.frame:IsShown() then overlay.frame:Hide() end
    end
end
local function OnEvent(frame, eventName, handler)
    return function()
        local record = frame.bootyWindowStackRecord
        if eventName == "OnMouseDown" or eventName == "OnDragStart" then Stack.FocusFrom(frame) end
        if handler then handler() end
        if eventName == "OnShow" then
            frame.bootyStackShowRevision = (frame.bootyStackShowRevision or 0) + 1
            Stack.Sync(frame)
        elseif eventName == "OnHide" then
            frame.bootyStackHideRevision = (frame.bootyStackHideRevision or 0) + 1
            if record and record.kind == "window" then CloseOverlays(record) end
            if record and OwnsBand(record) then
                if Stack.focused == record then Stack.focused = nil end
                Reflow()
            end
        end
    end
end
local function Hook(frame)
    if frame.bootyStackSetScript then return end
    frame.bootyStackSetScript = frame.SetScript
    frame.SetScript = function(self, eventName, handler)
        if eventName == "OnShow" or eventName == "OnHide" or eventName == "OnMouseDown" or eventName == "OnDragStart" then
            return self.bootyStackSetScript(self, eventName, OnEvent(self, eventName, handler))
        end
        return self.bootyStackSetScript(self, eventName, handler)
    end
    for _, eventName in ipairs({"OnShow", "OnHide", "OnMouseDown", "OnDragStart"}) do
        frame:SetScript(eventName, frame:GetScript(eventName))
    end
    frame.bootyStackShow, frame.bootyStackHide = frame.Show, frame.Hide
    frame.Show = function(self)
        local record = self.bootyWindowStackRecord
        local visible, revision = Visible(self), self.bootyStackShowRevision
        if record and OwnsBand(record) then
            local previous = ParentRecord(record)
            ResolveOpener(record)
            if ParentRecord(record) ~= previous then Stack.focused = nil end
            record.opening = true
            if not BringForward(record) and not visible then Reflow() end
        end
        self.bootyStackShow(self)
        if record then record.opening = nil end
        if revision == self.bootyStackShowRevision then Stack.Sync(self) end
    end
    frame.Hide = function(self)
        local visible, revision = Visible(self), self.bootyStackHideRevision
        self.bootyStackHide(self)
        local record = self.bootyWindowStackRecord
        if revision == self.bootyStackHideRevision then
            if record and record.kind == "window" then CloseOverlays(record) end
            if record and OwnsBand(record) and visible then
                if Stack.focused == record then Stack.focused = nil end
                Reflow()
            end
        end
    end
    frame.Raise = function(self) Stack.Raise(self) end
    if frame.SetToplevel then frame:SetToplevel(false) end
end
function Stack.Register(frame, options)
    if not frame then return end
    options = options or {}
    local record = frame.bootyWindowStackRecord
    if not record then
        record = {frame = frame, kind = options.kind or "window", owner = options.owner, defaultOwner = options.owner}
        frame.bootyWindowStackRecord = record
        Stack.Track(frame); Hook(frame)
        if record.kind == "window" then table.insert(Stack.windows, record); table.insert(order, record)
        else table.insert(Stack.overlays, record); table.insert(order, record) end
    elseif options.owner ~= nil then Stack.SetOwner(frame, options.owner) end
    if options.dismiss then
        Stack.Attach(options.dismiss, function()
            if record.kind == "popup" then return Stack.GetWindow(Source(record.owner)) or frame end
            return frame
        end, -1)
    end
    if Visible(frame) then Stack.Raise(frame); Stack.Sync(frame) end
    return frame
end
function Stack.Attach(frame, owner, offset)
    if not frame then return end
    local attachment = frame.bootyWindowStackAttachment
    if not attachment then
        attachment = {frame = frame, owner = owner, offset = offset or 1, kind = "attachment"}
        frame.bootyWindowStackAttachment = attachment
        table.insert(Stack.overlays, attachment)
        Stack.Track(frame); Hook(frame)
    else
        if attachment.owner == owner and attachment.offset == (offset or 1) then return frame end
        attachment.owner, attachment.offset = owner, offset or 1
    end
    Stack.Sync(owner)
    return frame
end
