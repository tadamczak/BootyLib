local Lib, UI = BootyLib, BootyLib.UI.Components
if Lib.Core.AppearanceProvider then return end
local provider = {id = "booty.shared.appearance", apiVersion = 1}
Lib.Core.AppearanceProvider = provider
local active, busy = nil, false

local function Values(skin) return {skin = skin} end
local function Failure(code, message, rollback)
    return false, {code = code, message = tostring(message or code), rollbackError = rollback}
end
local function Combined(first, second)
    if first and second then return first .. "; " .. second end
    return first or second
end
local function Known(value)
    if type(value) ~= "string" then return false end
    for _, choice in ipairs(UI.GetAvailableSkins()) do if choice.value == value then return true end end
    return false
end
local function Validate(values)
    if type(values) ~= "table" then return Failure("invalid-values", "Expected appearance values.") end
    for key in pairs(values) do if key ~= "skin" then return Failure("unknown-field", "Shared appearance supports only skin.") end end
    if not Known(values.skin) then return Failure("invalid-skin", "Choose an available interface skin.") end
    return true, values.skin
end
local function Store()
    if type(BootyLibDB) ~= "table" then error("BootyLib appearance data is not ready.") end
    if BootyLibDB.uiSkin ~= nil and not Known(BootyLibDB.uiSkin) then error("Saved BootyLib skin is invalid; preserve it before repairing the data.") end
    return BootyLibDB
end
local function Current()
    local skin = UI.GetSkin()
    if not Known(skin) then error("The current interface skin is not available.") end
    return skin
end
local function End(session, reason, values)
    if active == session then active = nil end
    if session.onEnded then
        local ok, result, message = pcall(session.onEnded, reason, values)
        if not ok or result == false then return false, tostring(ok and message or result) end
    end
    return true
end
local function SetRuntime(skin)
    if Current() == skin then return end
    local result = UI.SetSkin(skin, false)
    if result ~= skin or Current() ~= skin then error("Another owner changed the runtime skin during application.") end
end
local function Restore(session, candidate)
    if BootyLibDB ~= session.store or session.store.uiSkin ~= session.stored then return false, "A later saved appearance was preserved." end
    local current = Current()
    if current ~= candidate and current ~= session.last then return false, "A later runtime appearance was preserved." end
    SetRuntime(session.original)
    if BootyLibDB ~= session.store or session.store.uiSkin ~= session.stored then return false, "Saved appearance changed during restoration." end
    return true
end
local function Recover(session, candidate)
    local ok, result, message = pcall(Restore, session, candidate)
    if not ok or result == false then return tostring(ok and message or result) end
end
local function Rollback(session, candidate)
    local errors = {}
    if BootyLibDB ~= session.store or (session.store.uiSkin ~= candidate and session.store.uiSkin ~= session.stored) then
        table.insert(errors, "A later saved appearance was preserved.")
    elseif session.store.uiSkin ~= session.stored then
        local ok, message = pcall(function() session.store.uiSkin = session.stored end)
        if not ok then table.insert(errors, tostring(message))
        elseif BootyLibDB ~= session.store or session.store.uiSkin ~= session.stored then
            table.insert(errors, "Appearance store did not confirm the rollback.")
        end
    end
    local runtimeError = Recover(session, candidate)
    if runtimeError then table.insert(errors, runtimeError) end
    if table.getn(errors) > 0 then return table.concat(errors, "; ") end
end
local function Check(session)
    if not session or active ~= session then return Failure("stale-token", "This appearance edit has ended.") end
    local store = Store()
    if store ~= session.store or store.uiSkin ~= session.stored then
        local applied, message = true, nil
        if Known(store.uiSkin) then applied, message = pcall(SetRuntime, store.uiSkin) end
        local notified, failure = End(session, "external-change", Values(Current()))
        return Failure("external-change", "Saved appearance changed while editing.", Combined(not applied and tostring(message) or nil, not notified and failure or nil))
    end
    if Current() ~= session.last then
        local notified, failure = End(session, "external-change", Values(Current()))
        return Failure("external-change", "Runtime appearance changed while editing.", not notified and failure or nil)
    end
    return true
end
local function Session(token)
    if type(token) ~= "table" or not active or active.token ~= token then return nil end
    return active
end
local function Run(callback, token)
    if busy then return Failure("busy", "An appearance operation is already in progress.") end
    busy = true
    local ok, result, detail = pcall(callback)
    local rollback
    if not ok then
        local session = Session(token)
        if session then
            rollback = Recover(session, session.last)
            local notified, failure = End(session, "error", {code = "appearance-error", message = tostring(result)})
            if not notified then rollback = Combined(rollback, failure) end
        end
    end
    busy = false
    if not ok then return Failure("appearance-error", result, rollback) end
    return result, detail
end

function provider.ReadAppearance(id)
    if id ~= provider.id then return Failure("unknown-element", "Unknown shared appearance element.") end
    local ok, result = pcall(function()
        local skin = Current()
        local ready, message = pcall(Store)
        return {available = ready, reason = not ready and tostring(message) or nil, values = Values(skin),
            choices = UI.GetAvailableSkins(), defaults = Values("classic")}
    end)
    if not ok then return Failure("appearance-error", result) end
    return true, result
end
function provider.BeginAppearancePreview(id, onEnded)
    return Run(function()
        if id ~= provider.id then return Failure("unknown-element", "Unknown shared appearance element.") end
        if active then return Failure("busy", "Shared appearance is already being edited.") end
        if onEnded ~= nil and type(onEnded) ~= "function" then return Failure("invalid-callback", "Expected an editing completion callback.") end
        local store, current = Store(), Current()
        local token = {}
        active = {token = token, store = store, stored = store.uiSkin, original = current, last = current, onEnded = onEnded}
        return true, token
    end)
end
function provider.PreviewAppearance(token, values)
    return Run(function()
        local session = Session(token)
        local checked, failure = Check(session); if not checked then return checked, failure end
        local valid, skin = Validate(values); if not valid then return valid, skin end
        if skin == session.last then return true, Values(skin) end
        local applied, message = pcall(SetRuntime, skin)
        if not applied then
            local rollback = Recover(session, skin)
            local notified, failure = End(session, "error", {code = "preview-failed", message = tostring(message)})
            return Failure("preview-failed", message, Combined(rollback, not notified and failure or nil))
        end
        session.last = skin
        checked, failure = Check(session); if not checked then return checked, failure end
        return true, Values(skin)
    end, token)
end
function provider.ApplyAppearance(token)
    return Run(function()
        local session = Session(token)
        local checked, failure = Check(session); if not checked then return checked, failure end
        local skin = session.last
        local wrote, message = pcall(function() session.store.uiSkin = skin end)
        if not wrote or BootyLibDB ~= session.store or session.store.uiSkin ~= skin then
            local rollback = Rollback(session, skin)
            local notified, notification = End(session, "error", {code = "commit-failed"})
            if not notified then rollback = Combined(rollback, notification) end
            return Failure("commit-failed", message or "Appearance store did not confirm the value.", rollback)
        end
        local notified, notification = End(session, "apply", Values(skin))
        if not notified then
            return Failure("notification-failed", notification, Rollback(session, skin))
        end
        return true, Values(skin)
    end, token)
end
function provider.CancelAppearance(token)
    return Run(function()
        local session = Session(token)
        local checked, failure = Check(session); if not checked then return checked, failure end
        local restored, result, message = pcall(Restore, session, session.last)
        if BootyLibDB ~= session.store or session.store.uiSkin ~= session.stored then return Check(session) end
        if not restored or result == false then
            local _, failure = Failure("restore-failed", restored and message or result)
            local notified, notification = End(session, "error", failure)
            failure.rollbackError = not notified and notification or nil
            return false, failure
        end
        local notified, notification = End(session, "cancel", Values(session.original))
        if not notified then return Failure("notification-failed", notification) end
        return true, Values(session.original)
    end, token)
end
function provider.ResetAppearance(token) return provider.PreviewAppearance(token, Values("classic")) end
function Lib.GetAppearanceProvider() return provider end

-- Settings and profile setters use this owner path. An external choice ends
-- the preview before any durable write, even when it equals the saved value.
function Lib.SetSharedSkin(value)
    local ok, result = Run(function()
        local valid, skin = Validate(Values(value)); if not valid then return valid, skin end
        local store = Store()
        local session = active
        local snapshot = {store = store, stored = store.uiSkin, original = session and session.original or Current(), last = Current()}
        -- Invalidate before the write; notify only after the resolved transition
        -- so consumers can read its final appearance in their completion callback.
        active = nil
        local writeAttempted = false
        local changed, changeResult, changeError = pcall(function()
            SetRuntime(skin)
            if BootyLibDB ~= store or store.uiSkin ~= snapshot.stored then
                return Failure("external-change", "Saved appearance changed during its application.")
            end
            writeAttempted = true
            store.uiSkin = skin
            if BootyLibDB ~= store or store.uiSkin ~= skin then
                return Failure("commit-failed", "Appearance store did not confirm the value.")
            end
            return true
        end)
        local failure
        if not changed then failure = {code = "setting-failed", message = tostring(changeResult)}
        elseif changeResult ~= true then failure = changeError end
        if failure then
            failure.rollbackError = writeAttempted and Rollback(snapshot, skin) or Recover(snapshot, skin)
            if session then
                local notified, notification = End(session, "error", failure)
                if not notified then failure.rollbackError = Combined(failure.rollbackError, notification) end
            end
            return false, failure
        end
        if session then
            local notified, notification = End(session, "external-change", Values(skin))
            if not notified then return Failure("notification-failed", notification, Rollback(snapshot, skin)) end
        end
        return true, skin
    end)
    if not ok then error(result.message .. (result.rollbackError and ("; rollback: " .. result.rollbackError) or ""), 2) end
    return result
end

-- One observer for this library instance. Direct external SetSkin calls also
-- invalidate the token, without undoing the newer runtime appearance.
UI.RegisterSkinCallback(function()
    if active and not busy then
        busy = true
        local session = active
        local notified, failure = End(session, "external-change", Values(UI.GetSkin()))
        busy = false
        if not notified and type(Lib.Print) == "function" then Lib.Print(failure) end
    end
end)
