local Booty = BootyLib
local Match = Booty.Core and Booty.Core.Compatibility and Booty.Core.Compatibility.Match or string.match

Booty.Services.Version = Booty.Services.Version or {}
local Version = Booty.Services.Version

function Version.Parse(value)
    if type(value) ~= "string" then return nil end
    local major, minor, patch = Match(value, "^(%d+)%.(%d+)%.(%d+)$")
    if major then return { tonumber(major), tonumber(minor), tonumber(patch), nil } end
    local dev
    major, minor, patch, dev = Match(value, "^(%d+)%.(%d+)%.(%d+)%-dev%.(%d+)$")
    if not major then return nil end
    return { tonumber(major), tonumber(minor), tonumber(patch), tonumber(dev) }
end

function Version.Compare(left, right)
    local leftParts, rightParts = Version.Parse(left), Version.Parse(right)
    if not leftParts or not rightParts then return nil end
    local index
    for index = 1, 3 do
        if leftParts[index] < rightParts[index] then return -1 end
        if leftParts[index] > rightParts[index] then return 1 end
    end
    local leftDev, rightDev = leftParts[4], rightParts[4]
    if leftDev == nil and rightDev ~= nil then return 1 end
    if leftDev ~= nil and rightDev == nil then return -1 end
    if leftDev and rightDev then
        if leftDev < rightDev then return -1 end
        if leftDev > rightDev then return 1 end
    end
    return 0
end

function Version.IsNewer(candidate, installedRelease)
    return Version.Compare(candidate, installedRelease) == 1
end

function Version.SelectLatest(current, candidate)
    if not Version.Parse(candidate) then return current end
    if not current or Version.IsNewer(candidate, current) then return candidate end
    return current
end
