BootyLib = BootyLib or {}
BootyLib.Data = BootyLib.Data or {}
local Data = BootyLib.Data
local owners, order = {}, {}

local function Identifier(value)
    return type(value) == "string" and value ~= "" and not string.find(value, "[^%w_%-]")
end

function Data.RegisterOwner(id, dbGlobal, ownsField, defaultInitializer)
    if not Identifier(id) or not Identifier(dbGlobal) or type(ownsField) ~= "function"
        or defaultInitializer ~= nil and type(defaultInitializer) ~= "function" then
        return nil, "Invalid data owner declaration."
    end
    if owners[id] then return nil, "This data owner is already registered." end
    local owner = { id = id, dbGlobal = dbGlobal, OwnsField = ownsField, InitializeDefaults = defaultInitializer }
    owners[id] = owner
    table.insert(order, id)
    return owner
end

function Data.GetOwner(id) return owners[id] end
function Data.ListOwners() return order end

-- Registering an owner never creates its SavedVariables. The product decides
-- when its own ADDON_LOADED data is ready, then explicitly calls Ensure.
function Data.Ensure(id)
    local owner = owners[id]
    if not owner then return nil, "Unknown data owner." end
    local store = _G[owner.dbGlobal]
    if type(store) ~= "table" then store = {}; _G[owner.dbGlobal] = store end
    if owner.ensuring then return store end
    owner.ensuring = true
    local migration = BootyLib.LegacyMigration
    local migrated, failure = true, nil
    if migration and migration.HasSource() then migrated, failure = migration.ImportOwner(id, store) end
    if migrated and owner.InitializeDefaults then
        local ok, message = pcall(owner.InitializeDefaults, store, id)
        if not ok then migrated, failure = false, tostring(message) end
    end
    owner.ensuring = nil
    if not migrated then return nil, failure end
    return store
end

function Data.Get(id, key)
    local store, failure = Data.Ensure(id)
    if not store then return nil, failure end
    if key == nil then return store end
    return store[key]
end
