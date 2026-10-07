local Lib = BootyLib
local Runtime = { products = {}, order = {}, hosts = {}, subscriptions = {}, viewOwners = {}, started = false }
Lib.Core.Runtime = Runtime
local clientEvents = {PLAYER_LOGIN = true, ADDON_LOADED = true, GUILD_ROSTER_UPDATE = true,
    PLAYER_GUILD_UPDATE = true, RAID_ROSTER_UPDATE = true}
local function Flag(value) return value ~= nil and value ~= false and value ~= 0 end

local function Compatible(value)
    return value.apiVersion == Lib.API_VERSION and
        (not value.namespace or value.namespace.API_VERSION == nil or value.namespace.API_VERSION == Lib.API_VERSION)
end
local function Message(value, fallback)
    if type(value) == "table" then value = value.message or value.code end
    return tostring(value or fallback or "Initialization failed.")
end
local function Failure(product, message)
    product.failure = Message(message)
    Lib.Print(product.name .. ": " .. product.failure)
    return false, product.failure
end
local function CleanupActivation(product)
    local failures={}
    local host=product.activationCleanupHost
    if host then
        local hostClean=true
        if host.Hide then
            local ok,result,reason=pcall(host.Hide)
            if not ok or result==false then
                hostClean=false;table.insert(failures,"Host cleanup failed: "..Message(reason or result))
            end
        end
        if host.minimap and host.minimap.Hide then
            local ok,result,reason=pcall(host.minimap.Hide,host.minimap)
            if not ok or result==false then
                hostClean=false;table.insert(failures,"Minimap cleanup failed: "..Message(reason or result))
            end
        end
        if hostClean then product.activationCleanupHost=nil end
    end
    local cleanup = product.OnActivationFailed or product.Stop
    if type(cleanup) == "function" then
        local ok, result, reason = pcall(cleanup, product.activationFailure)
        if not ok or result == false then table.insert(failures,Message(reason or result,"Activation cleanup failed.")) end
    end
    if table.getn(failures)>0 then return false,table.concat(failures," ") end
    return true
end
local function ActivationFailure(product, reason, host)
    product.activationFailure = Message(reason)
    local failure = product.activationFailure
    product.activationCleanupHost=host
    Runtime.hosts[product.id] = nil
    local cleaned, message = CleanupActivation(product)
    product.activationCleanupPending = not cleaned or nil
    if cleaned then product.featureInitialized = nil
    else failure = failure .. " Activation cleanup failed: " .. message end
    return Failure(product, failure)
end
-- Registration is metadata only: migration and feature startup wait for login.
function Lib.RegisterProduct(product)
    if type(product) ~= "table" or type(product.id) ~= "string" or product.id == "" or
        type(product.name) ~= "string" or type(product.views) ~= "table" then
        return nil, "Invalid Booty product descriptor."
    end
    if not Compatible(product) then return nil, "Unsupported Booty integration API. Update BootyLib and this addon together." end
    if Runtime.products[product.id] then return nil, "Duplicate Booty product identifier." end
    local views = {}
    for _, view in ipairs(product.views) do
        if type(view) ~= "table" or type(view.id) ~= "string" or view.id == "" or type(view.create) ~= "function" then
            return nil, "Invalid Booty view descriptor."
        end
        if views[view.id] or Runtime.viewOwners[view.id] then return nil, "Duplicate Booty view identifier: " .. view.id end
        views[view.id] = true
    end
    for id in pairs(views) do Runtime.viewOwners[id] = product.id end
    Runtime.products[product.id] = product; table.insert(Runtime.order, product.id)
    if Runtime.started then Runtime.pendingProduct = true end
    return product
end
function Lib.GetProduct(id) return Runtime.products[id] end
function Lib.GetProducts() return Runtime.order end
function Lib.RegisterSuite(suite)
    if type(suite) ~= "table" or not Compatible(suite) or type(suite.Attach) ~= "function" then
        return nil, "Unsupported Booty Suite integration API."
    end
    if Runtime.suite then return nil, "Booty Suite is already registered." end
    -- Normal Suite loading precedes login. Keep live raids and windows in their
    -- current host if Suite is installed late; integration applies after reload.
    if Runtime.started then
        Runtime.pendingSuite = suite
        Lib.Print("Booty Suite loaded after login. Reload the UI to integrate the Booty addons.")
        return nil, "Reload required."
    end
    Runtime.suite = suite
    return suite
end
function Lib.Subscribe(name, owner, callback)
    if type(name) ~= "string" or owner == nil or type(callback) ~= "function" then return false end
    local subscribers = Runtime.subscriptions[name]
    if not subscribers then subscribers = {}; Runtime.subscriptions[name] = subscribers; Runtime.frame:RegisterEvent(name) end
    subscribers[owner] = callback
    return true
end
function Lib.Unsubscribe(name, owner)
    local subscribers = Runtime.subscriptions[name]
    if not subscribers then return end
    subscribers[owner] = nil
    if not next(subscribers) then
        Runtime.subscriptions[name] = nil
        if not clientEvents[name] then Runtime.frame:UnregisterEvent(name) end
    end
end
function Runtime.Activate(product)
    if product.initialized then return true end
    if not Compatible(product) then return Failure(product, "Unsupported Booty integration API.") end
    if product.activationCleanupPending then
        local cleaned, reason = CleanupActivation(product)
        if not cleaned then return Failure(product, product.activationFailure .. " Activation cleanup failed: " .. reason) end
        product.activationCleanupPending, product.featureInitialized = nil, nil
    end
    -- Retained failed hosts remain blocked until cleanup has completed. The
    -- fresh host's OnHostReady may then open its own views during activation.
    product.failure=nil
    if not product.featureInitialized then
        if product.Initialize then
            local ok, result, reason = pcall(product.Initialize)
            if not ok or result == false then return ActivationFailure(product, reason or result) end
        end
        product.featureInitialized = true
    end
    local ok, host, reason
    if Runtime.suite then ok, host, reason = pcall(Runtime.suite.Attach, product)
    else ok, host, reason = pcall(Lib.Core.ProductHost.Create, product, {integrated = false}) end
    if not ok or type(host) ~= "table" then return ActivationFailure(product, reason or host or "Presentation host is unavailable.") end
    Runtime.hosts[product.id] = host
    if product.OnHostReady then
        local ready, result, failure = pcall(product.OnHostReady, host)
        if not ready or result == false then
            return ActivationFailure(product, failure or result, host)
        end
    end
    product.initialized, product.failure, product.activationFailure = true, nil, nil
    return true
end
local function WantsDirectory(product)
    if not product.initialized or product.stopped or type(product.GetGuildDirectoryDemand) ~= "function" then return false end
    local ok, wanted = pcall(product.GetGuildDirectoryDemand)
    return ok and wanted ~= nil and wanted ~= false and wanted ~= 0
end
local function DirectoryWanted()
    for _, id in ipairs(Runtime.order) do if WantsDirectory(Runtime.products[id]) then return true end end
    return false
end
local function PublishDirectory(snapshot)
    for _, id in ipairs(Runtime.order) do
        local product = Runtime.products[id]
        if WantsDirectory(product) and product.OnGuildDirectoryUpdated then
            local ok, failure = pcall(product.OnGuildDirectoryUpdated, snapshot)
            if not ok then Lib.Print(product.name .. ": " .. tostring(failure)) end
        end
    end
end
local function DirectoryUpdate()
    local directory = Lib.GuildDirectory
    if not DirectoryWanted() then directory.Cancel(); Runtime.frame:SetScript("OnUpdate", nil); return end
    local state, snapshot = directory.Step(32)
    if state == "ready" then PublishDirectory(snapshot) end
    if not directory.IsPending() then
        -- Guild may publish its own completed scan while this worker is queued.
        -- Use that shared snapshot instead of silently dropping the notification.
        if state == "idle" then
            local shared = directory.GetSnapshot()
            if shared then PublishDirectory(shared) end
        end
        Runtime.frame:SetScript("OnUpdate", nil)
    end
end
function Runtime.RefreshDirectory(request)
    local directory = Lib.GuildDirectory
    if not directory then return end
    if not DirectoryWanted() then directory.Cancel(); Runtime.frame:SetScript("OnUpdate", nil); return end
    if request then directory.Request() end
    if directory.GetSnapshot() then return end
    directory.Begin()
    if directory.IsPending() then Runtime.frame:SetScript("OnUpdate", DirectoryUpdate) end
end
function Runtime.Start()
    if Runtime.started then return true end
    if type(MuklaOfficerSuiteDB) == "table" then Lib.LegacyMigration.Offer(MuklaOfficerSuiteDB, {id = "MuklaOfficerSuiteDB"}) end
    local db, failure = Lib.Data.Ensure("lib")
    if not db then Lib.Print(failure); return false, failure end
    if Lib.UI.Components.SetSkin then Lib.UI.Components.SetSkin(db.uiSkin or "classic") end
    if Runtime.suite and Runtime.suite.Initialize then
        local ok, result, reason = pcall(Runtime.suite.Initialize)
        if not ok or result == false then return Failure(Runtime.suite, reason or result) end
    end
    Runtime.started = true
    for _, id in ipairs(Runtime.order) do Runtime.Activate(Runtime.products[id]) end
    if Runtime.suite and Runtime.suite.Ready then
        local ok, failure = pcall(Runtime.suite.Ready)
        if not ok then Failure(Runtime.suite, failure) end
    end
    Runtime.RefreshDirectory(true)
    return true
end
function Runtime.CanReload()
    for _, id in ipairs(Runtime.order) do
        local product = Runtime.products[id]
        if product.IsBusy then
            local ok, busy = pcall(product.IsBusy)
            if not ok then return false, tostring(busy) end
            if Flag(busy) then return false, "Finish the active raid or recording before reloading." end
        end
    end
    return true
end
function Runtime.StopProduct(id)
    local product = Runtime.products[id]
    if not product then return false, "Product is not loaded." end
    if not product.stopCleanupPending then
        if product.IsBusy then
            local ok, busy = pcall(product.IsBusy)
            if not ok then return false, Message(busy) end
            if Flag(busy) then return false, "Finish the active raid or recording before stopping this addon." end
        end
        if product.Stop then
            local ok, result, reason = pcall(product.Stop)
            if not ok then return false, Message(result) end
            if result == false then return false, Message(reason, "The addon could not stop safely.") end
        end
        -- Domain resources are already stopped. Keep entry points paused while
        -- retrying presentation cleanup, without repeating the owner's Stop.
        product.stopped, product.stopCleanupPending = true, true
    end
    Runtime.RefreshDirectory(false)
    local host = Runtime.hosts[id]
    if host and host.Hide then
        local ok, result, reason = pcall(host.Hide)
        if not ok or result == false or result == 0 then
            return false, Message(reason or result, "The presentation host could not stop safely.")
        end
    end
    product.stopCleanupPending = nil
    return true
end

Lib.Data.RegisterOwner("lib", "BootyLibDB", function(key)
    return key == "uiSkin" or key == "chatActionLogs" or key == "suppressLoginMessage" or key == "settingsProfiles" or key == "currentSettingsProfile"
end, function(db)
    if db.uiSkin == nil then db.uiSkin = "classic" end
    if db.chatActionLogs == nil then db.chatActionLogs = false end
    if db.suppressLoginMessage == nil then db.suppressLoginMessage = false end
end)
local frame = CreateFrame("Frame", "BootyLibRuntime")
Runtime.frame = frame
for name in pairs(clientEvents) do frame:RegisterEvent(name) end
frame:SetScript("OnEvent", function()
    if event == "PLAYER_LOGIN" then Runtime.Start()
    elseif event == "ADDON_LOADED" and Runtime.started and Runtime.pendingProduct then
        Runtime.pendingProduct = nil
        for _, id in ipairs(Runtime.order) do Runtime.Activate(Runtime.products[id]) end
        if Runtime.suite and Runtime.suite.Ready then
            local ok, failure = pcall(Runtime.suite.Ready)
            if not ok then Failure(Runtime.suite, failure) end
        end
        Runtime.RefreshDirectory(true)
    elseif event == "GUILD_ROSTER_UPDATE" or event == "PLAYER_GUILD_UPDATE" then
        Lib.GuildDirectory.Invalidate()
        if Runtime.started then Runtime.RefreshDirectory(event == "PLAYER_GUILD_UPDATE") end
    elseif event == "RAID_ROSTER_UPDATE" and Runtime.started then Runtime.RefreshDirectory(true) end
    local subscribers = Runtime.subscriptions[event]
    if subscribers then
        for _, callback in pairs(subscribers) do
            local ok, failure = pcall(callback)
            if not ok then Lib.Print(tostring(failure)) end
        end
    end
end)
