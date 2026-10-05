BootyLib = BootyLib or {}
local Directory = { WORK_LIMIT = 32 }
BootyLib.GuildDirectory = Directory
local api, generation, snapshot, memberIndex, job, requestedGeneration = nil, 0, nil, {}, nil, nil
local buffers = { { members = {}, rows = {}, index = {} }, { members = {}, rows = {}, index = {} } }
local activeBuffer = 2

local native = {
    isInGuild = function() return type(IsInGuild) == "function" and IsInGuild() end,
    getGuildInfo = function() if type(GetGuildInfo) == "function" then return GetGuildInfo("player") end end,
    getRealmName = function() return type(GetRealmName) == "function" and GetRealmName() or "UnknownRealm" end,
    getNumGuildMembers = function() return type(GetNumGuildMembers) == "function" and GetNumGuildMembers(true) or 0 end,
    getGuildRosterInfo = function(index) if type(GetGuildRosterInfo) == "function" then return GetGuildRosterInfo(index) end end,
    requestRoster = function() if type(GuildRoster) == "function" then GuildRoster(); return true end return false end,
    now = function() return type(time) == "function" and time() or 0 end,
}
api = native

local function Identity()
    if api.isInGuild then
        local value = api.isInGuild()
        if value == nil or value == false or value == 0 then return nil end
    end
    local guild = api.getGuildInfo and api.getGuildInfo()
    if type(guild) ~= "string" or guild == "" then return nil end
    local realm = api.getRealmName and api.getRealmName() or "UnknownRealm"
    return guild, realm
end

function Directory.Invalidate()
    generation = generation + 1
    snapshot, memberIndex, job = nil, nil, nil
    return generation
end

function Directory.Configure(adapter)
    api = adapter or native
    requestedGeneration = nil
    Directory.Invalidate()
end

function Directory.GetGeneration() return generation end

function Directory.GetSnapshot()
    if not snapshot then return nil, "not-ready" end
    local guild, realm = Identity()
    if guild ~= snapshot.guildName or realm ~= snapshot.realmName then Directory.Invalidate(); return nil, "guild-changed" end
    return snapshot
end

function Directory.Find(name)
    if not Directory.GetSnapshot() then return nil end
    return memberIndex[string.lower(tostring(name or ""))]
end

-- Publishing consumes a completed read-only guild snapshot. It neither copies
-- durable roster data nor changes the producer's member records.
function Directory.Publish(value)
    if type(value) ~= "table" or type(value.members) ~= "table" then return false, "Invalid guild snapshot." end
    local guild, realm = Identity()
    if not guild or value.guildName ~= guild or value.realmName ~= realm then return false, "guild-changed" end
    local index, member = {}, nil
    for _, member in ipairs(value.members) do
        if type(member) == "table" and type(member.name) == "string" and member.name ~= "" then index[string.lower(member.name)] = member end
    end
    job, snapshot, memberIndex = nil, value, index
    return true
end

function Directory.Request()
    if requestedGeneration == generation then return true, "already-requested" end
    if not Identity() or not api.requestRoster then return false, "not-in-guild" end
    local ok = api.requestRoster()
    if ok == false then return false, "request-failed" end
    requestedGeneration = generation
    return true
end

function Directory.Begin()
    if job and job.generation == generation then return job, "working" end
    local guild, realm = Identity()
    if not guild then return nil, "not-in-guild" end
    local total = tonumber(api.getNumGuildMembers and api.getNumGuildMembers())
    if not total or total ~= total or total < 1 or total >= 1e300 then return nil, "not-ready" end
    total = math.floor(total)
    local bufferIndex = activeBuffer == 1 and 2 or 1
    local buffer = buffers[bufferIndex]
    job = { generation = generation, guildName = guild, realmName = realm, total = total, index = 1,
        phase = "clear", buffer = buffer, bufferIndex = bufferIndex }
    return job, "working"
end

local function ReadMember(index, target)
    local name, rank, rankIndex, level, class, zone, publicNote, officerNote, online = api.getGuildRosterInfo(index)
    if type(name) ~= "string" or name == "" then return false end
    target.name, target.rank, target.rankIndex = name, rank or "", rankIndex
    target.level, target.class, target.zone = level or 0, class or "", zone or ""
    target.publicNote, target.officerNote = publicNote or "", officerNote or ""
    target.online = online ~= nil and online ~= false and online ~= 0
    return true
end

-- The caller schedules this only while a capture is pending. Every invocation
-- performs at most 32 row reads/cleanup operations, with no frames or timers.
function Directory.Step(workLimit)
    if not job then return "idle" end
    local guild, realm = Identity()
    local total = tonumber(api.getNumGuildMembers and api.getNumGuildMembers())
    if job.generation ~= generation or guild ~= job.guildName or realm ~= job.realmName or total ~= job.total then
        Directory.Invalidate(); return "invalidated", "roster-changed"
    end
    local limit = tonumber(workLimit) or Directory.WORK_LIMIT
    if limit ~= limit or limit < 1 then limit = 1 end
    limit = math.min(Directory.WORK_LIMIT, math.floor(limit))
    local buffer, used = job.buffer, 0
    while used < limit and job.phase == "clear" do
        local count = table.getn(buffer.members)
        if count == 0 then job.phase = "capture"
        else
            local member = buffer.members[count]
            buffer.index[string.lower(member.name or "")] = nil
            table.remove(buffer.members, count)
            used = used + 1
        end
    end
    while used < limit and job.index <= job.total do
        local row = buffer.rows[job.index]
        if not row then row = {}; buffer.rows[job.index] = row end
        if not api.getGuildRosterInfo or not ReadMember(job.index, row) then job = nil; return "not-ready" end
        table.insert(buffer.members, row)
        buffer.index[string.lower(row.name)] = row
        job.index, used = job.index + 1, used + 1
    end
    if job.index <= job.total then return "working" end
    buffer.guildName, buffer.realmName, buffer.generation = job.guildName, job.realmName, generation
    buffer.scannedAt = api.now and api.now() or 0
    activeBuffer, snapshot, memberIndex = job.bufferIndex, buffer, buffer.index
    job = nil
    return "ready", snapshot
end

function Directory.IsPending() return job ~= nil end
function Directory.Cancel() job = nil end
