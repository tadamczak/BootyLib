BootyLib = BootyLib or {}
local Migration = {}
BootyLib.LegacyMigration = Migration
local source, information
local MARKER, SCHEMA = "_bootyMigration", 1
Migration.MARKER = MARKER

local function Copy(value, copies, active)
    local kind = type(value)
    if kind == "number" then
        if value ~= value or value - value ~= 0 then error("Invalid durable number.") end
        return value
    end
    if kind == "string" or kind == "boolean" or kind == "nil" then return value end
    if kind ~= "table" then error("Unsupported durable value: " .. kind) end
    if active[value] then error("Cyclic legacy data cannot be persisted safely.") end
    if copies[value] then return copies[value] end
    local target = {}
    copies[value], active[value] = target, true
    local key, child
    for key, child in pairs(value) do
        if type(key) ~= "string" and type(key) ~= "number" then error("Unsupported durable table key.") end
        target[Copy(key, copies, active)] = Copy(child, copies, active)
    end
    active[value] = nil
    return target
end

function Migration.HasSource() return type(source) == "table" end

local function Prepare(owner, target)
    local pending, count, key, value = {}, 0, nil, nil
    local copies, active = {}, {}
    for key, value in pairs(source) do
        if key ~= MARKER and type(key) == "string" and target[key] == nil and owner.OwnsField(key, value) then
            pending[key] = Copy(value, copies, active)
            count = count + 1
        end
    end
    return pending, count
end

-- Missing-only import is atomic: invalid data or a failing field policy leaves
-- the target untouched and unmarked, so the same owner can retry later.
function Migration.ImportOwner(id, target)
    if not Migration.HasSource() then return false, "Legacy SavedVariables are not available." end
    local owner = BootyLib.Data and BootyLib.Data.GetOwner(id)
    if not owner then return false, "Unknown data owner." end
    if type(target) ~= "table" or target == source then return false, "Invalid migration target." end
    local marker = target[MARKER]
    if type(marker) == "table" and marker.schema == SCHEMA and marker.source == information.id and marker.owner == id then
        return true, "already-imported", 0
    end
    local ok, pending, count = pcall(Prepare, owner, target)
    if not ok then return false, tostring(pending) end
    local key, value
    for key, value in pairs(pending) do target[key] = value end
    target[MARKER] = { schema = SCHEMA, owner = id, source = information.id, sourceVersion = information.version, fields = count }
    return true, "imported", count
end

function Migration.Offer(legacySource, metadata)
    if type(legacySource) ~= "table" then return false, "Legacy SavedVariables are not available." end
    metadata = type(metadata) == "table" and metadata or {}
    source = legacySource
    information = {
        id = type(metadata.id) == "string" and metadata.id ~= "" and metadata.id or "MuklaOfficerSuiteDB",
        version = type(metadata.version) == "string" and metadata.version or type(source.addonVersion) == "string" and source.addonVersion or nil,
    }
    local result = { imported = {}, failures = {}, absent = {} }
    local data = BootyLib.Data
    if data then
        local _, id
        for _, id in ipairs(data.ListOwners()) do
            local owner = data.GetOwner(id)
            local target = _G[owner.dbGlobal]
            if type(target) == "table" then
                local ok, reason = Migration.ImportOwner(id, target)
                if ok then table.insert(result.imported, id) else result.failures[id] = reason end
            else table.insert(result.absent, id) end
        end
    end
    return true, result
end
