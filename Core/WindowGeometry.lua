local Lib = BootyLib
local Geometry = {}
Lib.Core.WindowGeometry = Geometry
local keys = {"left", "bottom", "width", "height"}

local function Finite(value)
    return type(value) == "number" and value == value and value - value == 0
end
local function Copy(rect)
    local result = {}
    for _, key in ipairs(keys) do result[key] = rect and rect[key] end
    return result
end
local function Equal(first, second)
    for _, key in ipairs(keys) do if first[key] ~= second[key] then return false end end
    return true
end
local function Failure(code, message, rollback)
    return false, {code = code, message = tostring(message or code), rollbackError = rollback}
end

-- Each host supplies its existing store and layout callback. The manager owns
-- only transient previews; registration and reads never construct windows.
function Geometry.Create(options)
    local pose = options.extended and Lib.Core.WindowPose
    local keys = pose and pose.fields or keys
    local Copy = pose and pose.Copy or Copy
    local function Equal(first, second)
        for _,key in ipairs(keys) do
            local a,b=first[key],second[key]
            if a~=b and not (pose and Finite(a) and Finite(b) and math.abs(a-b)<0.00001) then return false end
        end
        return true
    end
    local manager, sessions, tokens, busy = {}, {}, {}, false
    local visible, listeners = {}, {}
    local function Changed(id)
        local callback = listeners[id]
        if not callback then return true end
        local ok, reason = pcall(callback)
        if not ok then return Failure("notification-failed", reason) end
        return true
    end
    local subscribed, pendingContext, onContext = false, false, nil
    local function Context()
        local context = options.getContext()
        if type(context) ~= "table" or not Finite(context.width) or context.width <= 0
            or not Finite(context.height) or context.height <= 0 or not Finite(context.scale) or context.scale <= 0 then
            error("Window screen context is unavailable.")
        end
        return {width = context.width, height = context.height, scale = context.scale}
    end
    local function Stored(id)
        local stored = options.getStored(id)
        if stored ~= nil and type(stored) ~= "table" then error("Invalid saved window geometry.") end
        local result = Copy(stored)
        for _, key in ipairs(keys) do
            local value = result[key]
            if value ~= nil and type(value) ~= "string" and not Finite(value) then error("Invalid saved geometry field: " .. key) end
        end
        return result
    end
    local function OverlayStored(rect,stored)
        for _,key in ipairs(keys) do
            local value=stored[key]
            if value~=nil then
                if key~="anchor" and key~="relativeId" and key~="relativePoint" and type(value)=="string" then
                    value=tonumber(value)
                    if not Finite(value) then error("Invalid saved numeric geometry field: "..key) end
                end
                rect[key]=value
            end
        end
        return rect
    end
    local function Limits(id, context)
        local wanted = options.getLimits(id, context)
        local result = {}
        for _, key in ipairs({"minWidth", "minHeight", "maxWidth", "maxHeight"}) do
            if not wanted or not Finite(wanted[key]) or wanted[key] <= 0 then error("Invalid window limits.") end
            result[key] = wanted[key]
        end
        result.maxWidth = math.max(1, math.min(result.maxWidth, context.width - 24))
        result.maxHeight = math.max(1, math.min(result.maxHeight, context.height - 24))
        result.minWidth = math.min(result.minWidth, result.maxWidth)
        result.minHeight = math.min(result.minHeight, result.maxHeight)
        return result
    end
    local function Normalize(id, rect, context)
        if pose then return pose.Normalize(rect,context,Limits(id,context),options.referenceId and options.referenceId(id)) end
        if type(rect) ~= "table" then error("Expected a complete window rectangle.") end
        for _, key in ipairs(keys) do if not Finite(rect[key]) then error("Invalid window rectangle field: " .. key) end end
        if rect.width <= 0 or rect.height <= 0 then error("Window dimensions must be positive.") end
        local limits = Limits(id, context)
        local result = Copy(rect)
        result.width = math.max(limits.minWidth, math.min(limits.maxWidth, result.width))
        result.height = math.max(limits.minHeight, math.min(limits.maxHeight, result.height))
        result.left = math.max(0, math.min(math.max(0, context.width - result.width), result.left))
        result.bottom = math.max(0, math.min(math.max(0, context.height - result.height), result.bottom))
        return result
    end
    local function Rect(frame)
        if pose then
            return pose.Capture(frame,Context())
        end
        local rect = {left = frame:GetLeft(), bottom = frame:GetBottom(), width = frame:GetWidth(), height = frame:GetHeight()}
        for _, key in ipairs(keys) do if not Finite(rect[key]) then error("Window bounds are not available.") end end
        if rect.width <= 0 or rect.height <= 0 then error("Window dimensions are not positive.") end
        return rect
    end
    local function Anchors(frame)
        local result = {}
        if type(frame.GetPoint) ~= "function" then return result end
        local count = type(frame.GetNumPoints) == "function" and frame:GetNumPoints() or 1
        if not Finite(count) or count < 0 or count > 8 then error("Invalid window anchor count.") end
        for index = 1, count do
            local point, relative, relativePoint, x, y = frame:GetPoint(index)
            if point then table.insert(result, {point = point, relative = relative, relativePoint = relativePoint, x = x or 0, y = y or 0}) end
        end
        return result
    end
    local function ApplyRect(id, frame, rect, anchors)
        local context = Context()
        local limits = Limits(id, context)
        local layoutChanged=not pose or frame:GetWidth()~=rect.width or frame:GetHeight()~=rect.height
            or math.abs(frame:GetEffectiveScale()/context.scale-(rect.scale or 1))>0.00001
        if frame.SetMinResize then frame:SetMinResize(limits.minWidth, limits.minHeight) end
        if frame.SetMaxResize then frame:SetMaxResize(limits.maxWidth, limits.maxHeight) end
        if pose and not anchors then
            local normalized,reference=Normalize(id,rect,context)
            pose.Draw(frame,normalized,reference)
        else
        if pose then frame:SetScale(rect.scale or 1);frame.mosGeometryPose=Copy(rect) end
        frame:SetWidth(rect.width); frame:SetHeight(rect.height);frame:ClearAllPoints()
        if anchors and table.getn(anchors) > 0 then
            for _, anchor in ipairs(anchors) do frame:SetPoint(anchor.point, anchor.relative, anchor.relativePoint, anchor.x, anchor.y) end
        else frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rect.left, rect.bottom) end
        end
        if pose then frame.mosGeometryProjection,frame.mosGeometryProjectionStore=nil,nil end
        if options.refresh and layoutChanged then
            local ok, message = options.refresh(id)
            if ok == false then error(message or "Window layout declined the geometry.") end
        end
    end
    local function Notify(session, reason, result)
        sessions[session.id], tokens[session.token] = nil, nil
        local cleanup
        if subscribed and not next(sessions) and not next(visible) then
            local ok, message = pcall(Lib.Unsubscribe, "CVAR_UPDATE", manager)
            if ok then subscribed = false else cleanup = tostring(message) end
        end
        if session.onEnded then
            local ok, value, message = pcall(session.onEnded, reason, result)
            if not ok or value == false then return false, tostring(ok and message or value) end
        end
        if cleanup then return false, cleanup end
        return true
    end
    local function Restore(session)
        local read, current = pcall(Rect, session.frame)
        if read and not Equal(current, session.last) then return false, "Window geometry changed outside its owner." end
        if not read and session.frame:IsVisible() then return false, current end
        ApplyRect(session.id, session.frame, session.original, session.anchors)
        if pose then
            session.frame.mosGeometryProjection=session.projection
            session.frame.mosGeometryProjectionStore=session.projectionStore
        end
        return true
    end
    local function Finish(session, reason, restore)
        local restored, message = true, nil
        if restore then
            local ok, value, failure = pcall(Restore, session)
            restored, message = ok and value ~= false, ok and failure or value
        end
        local notified, notification = Notify(session, reason, restored and Copy(session.original) or {code = "restore-failed", message = tostring(message)})
        if not restored then return Failure("restore-failed", message, notification) end
        if not notified then return Failure("notification-failed", notification) end
        return true, Copy(session.original)
    end
    local function Session(token)
        local session = type(token) == "table" and tokens[token]
        if not session or sessions[session.id] ~= session then return nil, "stale-token" end
        return session
    end
    local function Check(session)
        if options.getFrame(session.id) ~= session.frame then
            Notify(session, "unavailable", {code = "unavailable"}); return Failure("unavailable", "The window instance changed.")
        end
        local stored = Stored(session.id)
        if not Equal(stored, session.stored) then
            local context = Context()
            local latest = Copy(options.getDefaults(session.id, context))
            OverlayStored(latest,stored)
            local ok, message = pcall(ApplyRect, session.id, session.frame, Normalize(session.id, latest, context))
            Notify(session, "external-change", {code = "external-change"})
            return Failure("external-change", "Saved geometry changed while editing.", not ok and tostring(message) or nil)
        end
        local context = Context()
        if context.width ~= session.context.width or context.height ~= session.context.height or context.scale ~= session.context.scale then
            local committed = Normalize(session.id, session.original, context)
            local ok, message = pcall(ApplyRect, session.id, session.frame, committed)
            if pose and ok then
                session.frame.mosGeometryProjection=Copy(committed)
                session.frame.mosGeometryProjectionStore=Copy(session.stored)
            end
            Notify(session, "screen-change", {code = "screen-change"})
            return Failure("screen-change", "The screen or UI scale changed while editing.", not ok and tostring(message) or nil)
        end
        return true
    end
    local function Protected(callback, token)
        if busy then return Failure("busy", "A geometry operation is already in progress.") end
        busy = true
        local ok, result, detail = pcall(callback)
        local rollback
        if not ok then
            local session = token and Session(token)
            if session then
                local restored, value, message = pcall(Restore, session)
                if not restored or value == false then rollback = tostring(restored and message or value) end
                local notified, failure = Notify(session, "error", {code = "geometry-error", message = tostring(result)})
                if not notified then rollback = rollback or failure end
            end
        end
        busy = false
        if pendingContext and onContext then
            local editing = token and tokens[token] ~= nil
            pendingContext = false; onContext(true)
            if ok and result == true and editing and not tokens[token] then
                return Failure("screen-change", "The screen or UI scale changed while applying the preview.")
            end
        end
        if not ok then return Failure("geometry-error", result, rollback) end
        return result, detail
    end
    function manager.IsApplying() return busy end
    function manager.HasPreview(id) return sessions[id] ~= nil end
    function manager.WatchGeometry(id, callback)
        if type(callback) ~= "function" then return Failure("invalid-callback", "Expected a geometry observer.") end
        if listeners[id] and listeners[id] ~= callback then return Failure("busy", "This window already has a geometry observer.") end
        listeners[id] = callback
        return true
    end
    function manager.UnwatchGeometry(id, callback)
        if listeners[id] == callback then listeners[id] = nil end
        return true
    end
    function manager.ReadGeometry(id)
        local ok, result, detail = pcall(function()
            local available, reason = true, nil
            if options.isAvailable then available, reason = options.isAvailable(id) end
            local context, frame = Context(), options.getFrame(id)
            local data = {available = available == true and frame ~= nil and not (options.isMinimized and options.isMinimized(id)),
                reason = reason, stored = Stored(id), defaults = Normalize(id, options.getDefaults(id, context), context), limits = Limits(id, context)}
            data.extended=pose~=nil
            if pose then data.context=context;data.warning=frame and frame.mosGeometryWarning end
            if not available then data.reason = reason or "unavailable"
            elseif not frame then data.reason = "not-created"
            elseif options.isMinimized and options.isMinimized(id) then data.reason = "minimized"
            elseif not frame:IsVisible() then data.available, data.reason = false, "hidden"
            else data.rect = Rect(frame) end
            return true, data
        end)
        if not ok then return Failure("geometry-error", result) end
        return result, detail
    end
    function manager.BeginGeometryPreview(id, onEnded)
        return Protected(function()
            if sessions[id] then return Failure("busy", "This window is already being edited.") end
            if onEnded ~= nil and type(onEnded) ~= "function" then return Failure("invalid-callback", "Expected an editing completion callback.") end
            local ok, reason = true, nil
            if options.isAvailable then ok, reason = options.isAvailable(id) end
            local frame = options.getFrame(id)
            if not ok or not frame or not frame:IsVisible() or options.isMinimized and options.isMinimized(id) then
                return Failure(reason or "unavailable", "Open and expand the window before editing it.")
            end
            local rect = Rect(frame)
            local token = {}
            local session = {id = id, frame = frame, stored = Stored(id), original = Copy(rect), last = Copy(rect), token = token,
                anchors = Anchors(frame), context = Context(), onEnded = onEnded}
            if pose then session.projection,session.projectionStore=frame.mosGeometryProjection,frame.mosGeometryProjectionStore end
            if not subscribed and type(Lib.Subscribe) == "function" and type(Lib.Unsubscribe) == "function" then
                local subscribedOk, value = pcall(Lib.Subscribe, "CVAR_UPDATE", manager, onContext)
                if not subscribedOk or value ~= true then return Failure("subscribe-failed", subscribedOk and "Window context subscription declined." or value) end
                subscribed = true
            end
            sessions[id], tokens[token] = session, session
            return true, token
        end)
    end
    function manager.PreviewGeometry(token, rect)
        return Protected(function()
            local session, reason = Session(token)
            if not session then return Failure(reason) end
            local ok, detail = Check(session); if not ok then return ok, detail end
            local valid, candidate = pcall(Normalize, session.id, rect, session.context)
            if not valid then return Failure("invalid-rectangle", candidate) end
            if Equal(candidate, session.last) then return true, Copy(candidate) end
            local applied, message = pcall(ApplyRect, session.id, session.frame, candidate)
            if not applied then
                -- Partial native setters still belong to this attempt. Restore
                -- its snapshot before releasing the editing token.
                local recovered, failure = pcall(ApplyRect, session.id, session.frame, session.original, session.anchors)
                Notify(session, "error", {code = "layout-failed", message = tostring(message)})
                return Failure("layout-failed", message, not recovered and tostring(failure) or nil)
            end
            session.last = Rect(session.frame)
            return true, Copy(session.last)
        end, token)
    end
    function manager.ApplyGeometry(token)
        return Protected(function()
            local session, reason = Session(token)
            if not session then return Failure(reason) end
            local ok, detail = Check(session); if not ok then return ok, detail end
            local current = Rect(session.frame)
            if not Equal(current, session.last) then
                Notify(session, "external-change", {code = "external-change"})
                return Failure("external-change", "The window changed outside its owner.")
            end
            local rect = Normalize(session.id, current, session.context)
            local wrote, value, message = pcall(options.writeStored, session.id, Copy(rect))
            local verified, currentStore = pcall(Stored, session.id)
            if not wrote or value ~= true or not verified or not Equal(currentStore, rect) then
                local ownsWrite = verified
                if ownsWrite then
                    for _, key in ipairs(keys) do
                        if currentStore[key] ~= session.stored[key] and currentStore[key] ~= rect[key] then ownsWrite = false; break end
                    end
                end
                local rolled, result, rollback = true, false, "Saved geometry changed during commit; the later value was preserved."
                if ownsWrite then rolled, result, rollback = pcall(options.writeStored, session.id, Copy(session.stored)) end
                local restored, failure, restoreDetail
                if ownsWrite then
                    restored, failure, restoreDetail = pcall(Restore, session)
                    if restored and failure == false then restored, failure = false, restoreDetail end
                elseif verified then
                    local latest = Copy(options.getDefaults(session.id, session.context))
                    OverlayStored(latest,currentStore)
                    restored, failure = pcall(ApplyRect, session.id, session.frame, Normalize(session.id, latest, session.context))
                else restored, failure = false, "Saved geometry could not be read after commit." end
                Notify(session, "error", {code = "commit-failed"})
                return Failure("commit-failed", wrote and (message or "Window store did not confirm the written rectangle.") or value,
                    not rolled and tostring(result) or result ~= true and tostring(rollback or "Store rollback declined.") or not restored and tostring(failure) or nil)
            end
            local notified, notification = Notify(session, "apply", Copy(rect))
            if not notified then
                local rollback
                if Equal(Stored(session.id), rect) then
                    local rolled, value, message = pcall(options.writeStored, session.id, Copy(session.stored))
                    if not rolled or value ~= true then rollback = tostring(rolled and message or value) end
                    local restored, value, failure = pcall(Restore, session)
                    if not restored or value == false then rollback = rollback or tostring(restored and failure or value) end
                else rollback = "Saved geometry changed during completion; the later value was preserved." end
                return Failure("notification-failed", notification, rollback)
            end
            return true, Copy(rect)
        end, token)
    end
    function manager.CancelGeometry(token)
        return Protected(function()
            local session, reason = Session(token)
            if not session then return Failure(reason) end
            local ok, detail = Check(session); if not ok then return ok, detail end
            return Finish(session, "cancel", true)
        end, token)
    end
    function manager.ResetGeometry(token)
        local session, reason = Session(token)
        if not session then return Failure(reason) end
        local ok, defaults = pcall(options.getDefaults, session.id, session.context)
        if not ok then return Failure("geometry-error", defaults) end
        return manager.PreviewGeometry(token, defaults)
    end
    function manager.GetGeometryReference(id)
        local ok,result=pcall(function()
            local available,reason=true,nil
            if options.isAvailable then available,reason=options.isAvailable(id) end
            local frame=options.getFrame(id)
            return {frame=frame,stored=Stored(id),available=available==true and frame~=nil and frame:IsVisible()
                and not (options.isMinimized and options.isMinimized(id)),reason=reason}
        end)
        if not ok then return Failure("reference-error",result) end
        return true,result
    end
    function manager.RestoreCommitted(id)
        return Protected(function()
            if sessions[id] then return Failure("busy","Finish the preview before restoring geometry.") end
            local frame=options.getFrame(id)
            if not frame then return Failure("unavailable","The window has not been created.") end
            local context=Context()
            local rect=Copy(options.getDefaults(id,context));local stored=Stored(id)
            OverlayStored(rect,stored)
            if pose then
                local resolved,reference,warning=pose.Normalize(rect,context,Limits(id,context),options.referenceId and options.referenceId(id),true)
                frame.mosGeometryWarning=warning
                pose.Draw(frame,resolved,reference)
                frame.mosGeometryProjection,frame.mosGeometryProjectionStore=Copy(resolved),Copy(stored)
                if options.refresh then local ok,reason=options.refresh(id);if ok==false then error(reason or "Window layout declined geometry.") end end
                local notified, failure = Changed(id); if not notified then return notified, failure end
                return true,Copy(resolved)
            end
            rect=Normalize(id,rect,context);ApplyRect(id,frame,rect);return true,Copy(rect)
        end)
    end
    function manager.SaveManual(id)
        if sessions[id] then return manager.CaptureManual(id) end
        return Protected(function()
            local frame=options.getFrame(id)
            if not frame then return Failure("unavailable") end
            local stored=Stored(id)
            local captured=Rect(frame)
            if pose and frame.mosGeometryProjection and Equal(captured,frame.mosGeometryProjection)
                and Equal(stored,frame.mosGeometryProjectionStore) then return true,Copy(captured) end
            local rect=Normalize(id,captured,Context())
            ApplyRect(id,frame,rect)
            local wrote,value,reason=pcall(options.writeStored,id,Copy(rect))
            local read,current=pcall(Stored,id)
            if not wrote or value~=true or not read or not Equal(current,rect) then
                local owns=read
                if owns then for _,key in ipairs(keys) do
                    if current[key]~=stored[key] and current[key]~=rect[key] then owns=false;break end
                end end
                local rollback
                if owns then
                    local ok,result,detail=pcall(options.writeStored,id,Copy(stored))
                    if not ok or result~=true then rollback=tostring(ok and detail or result) end
                    local committed=OverlayStored(Copy(options.getDefaults(id,Context())),stored)
                    local restored,failure=pcall(function() ApplyRect(id,frame,Normalize(id,committed,Context())) end)
                    if not restored then rollback=rollback or tostring(failure) end
                else rollback="A later saved geometry value was preserved." end
                return Failure("commit-failed",wrote and (reason or "Window store did not confirm manual geometry.") or value,rollback)
            end
            local notified, failure = Changed(id); if not notified then return notified, failure end
            return true,Copy(rect)
        end)
    end
    function manager.SetVisible(id,shown)
        if not pose then return true end
        if shown then visible[id]=true else visible[id]=nil end
        if (next(visible) or next(sessions)) and not subscribed and Lib.Subscribe and Lib.Unsubscribe then
            local ok,value=pcall(Lib.Subscribe,"CVAR_UPDATE",manager,onContext)
            if not ok or value~=true then return Failure("subscribe-failed",ok and "Screen event subscription declined." or value) end
            subscribed=true
        elseif subscribed and not next(visible) and not next(sessions) then
            local ok,value=pcall(Lib.Unsubscribe,"CVAR_UPDATE",manager)
            if not ok then return Failure("unsubscribe-failed",value) end
            subscribed=false
        end
        return true
    end
    function manager.CaptureManual(id)
        local token = sessions[id] and sessions[id].token
        return Protected(function()
            local session = sessions[id]
            if not session then return Failure("no-preview") end
            local ok, detail = Check(session); if not ok then return ok, detail end
            local candidate = Normalize(id, Rect(session.frame), session.context)
            ApplyRect(id, session.frame, candidate); session.last = Rect(session.frame)
            local notified, failure = Changed(id); if not notified then return notified, failure end
            return true, Copy(session.last)
        end, token)
    end
    function manager.EndPreview(id, reason)
        local token = sessions[id] and sessions[id].token
        return Protected(function()
            local session = sessions[id]
            if not session then return true end
            local ok, detail = Check(session); if not ok then return ok, detail end
            return Finish(session, reason or "cancel", true)
        end, token)
    end
    onContext = function(force)
        local name = type(arg1) == "string" and string.lower(arg1) or nil
        if force ~= true and name and name ~= "uiscale" and name ~= "useuiscale" and name ~= "gxresolution" then return end
        if busy then pendingContext = true; return end
        for id in pairs(sessions) do
            local ok, failure = manager.EndPreview(id, "screen-change")
            if not ok and failure.code ~= "screen-change" and type(Lib.Print) == "function" then Lib.Print(failure.message) end
        end
        for id in pairs(visible) do
            if not (options.isMinimized and options.isMinimized(id)) then
                local ok,failure=manager.RestoreCommitted(id)
                if not ok and type(Lib.Print)=="function" then Lib.Print(failure.message) end
            end
        end
    end
    return manager
end
