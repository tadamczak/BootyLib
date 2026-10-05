local MOS = BootyLib
local Diagnostics = MOS.Diagnostics

Diagnostics.operations = Diagnostics.operations or {}
Diagnostics.trackOperations = false
Diagnostics.coverage = Diagnostics.coverage or {}
Diagnostics.scopes = Diagnostics.scopes or {}
local measurementDepth = 0

local function AddSample(operations, name, elapsed, memoryChange)
    local entry = operations[name]
    if not entry then
        entry = { count = 0, time = 0, memory = 0, maxTime = 0, maxMemory = 0 }
        operations[name] = entry
    end
    entry.count = entry.count + 1
    entry.time = entry.time + elapsed
    entry.memory = entry.memory + memoryChange
    if elapsed > entry.maxTime then entry.maxTime = elapsed end
    if memoryChange > entry.maxMemory then entry.maxMemory = memoryChange end
end

function Diagnostics.Record(name, elapsed, memoryChange)
    if not Diagnostics.trackOperations then
        return
    end
    elapsed = math.max(0, tonumber(elapsed) or 0)
    memoryChange = tonumber(memoryChange) or 0
    AddSample(Diagnostics.operations, name, elapsed, memoryChange)
    local _, scope
    for _, scope in pairs(Diagnostics.scopes) do AddSample(scope.operations, name, elapsed, memoryChange) end
    if Diagnostics.sampleObserver then
        local ok, failure = pcall(Diagnostics.sampleObserver, name, elapsed, memoryChange)
        if not ok then Diagnostics.sampleObserver = nil; Diagnostics.observerError = tostring(failure) end
    end
end

function Diagnostics.SetSampleObserver(callback)
    Diagnostics.sampleObserver = callback
    Diagnostics.observerError = nil
end

function Diagnostics.SetTracking(enabled)
    Diagnostics.trackOperations = enabled and true or false
end

function Diagnostics.BeginScope(name)
    local scope = { name = name, operations = {} }
    Diagnostics.scopes[name] = scope
    return scope
end

function Diagnostics.EndScope(scope)
    if scope and Diagnostics.scopes[scope.name] == scope then Diagnostics.scopes[scope.name] = nil end
    return scope
end

local function FinishMeasurement(name, timeBefore, memoryBefore, ...)
    measurementDepth = 0
    if not arg[1] then
        error(arg[2], 0)
        -- Some 1.12 clients report error() without throwing. Stock assert
        -- uses luaL_error, so retain callback failure rather than continuing.
        assert(false, tostring(arg[2])); return
    end
    Diagnostics.Record(name, GetTime() - timeBefore, (type(gcinfo) == "function" and gcinfo() or memoryBefore) - memoryBefore)
    -- Stock Lua 5.0 unpack has no range form. Shift the protected-call flag,
    -- retaining arg.n so embedded and trailing nil return values survive.
    local index
    for index = 1, arg.n - 1 do arg[index] = arg[index + 1] end
    arg[arg.n] = nil; arg.n = arg.n - 1
    return unpack(arg)
end

local function RunMeasured(name, callback, ...)
    measurementDepth = 1
    local memoryBefore = type(gcinfo) == "function" and gcinfo() or 0
    local timeBefore = GetTime()
    return FinishMeasurement(name, timeBefore, memoryBefore, pcall(callback, unpack(arg)))
end

local function ShouldMeasure() return Diagnostics.trackOperations and measurementDepth == 0 end

local wrapperFactories = {
    [0] = function(name, callback) return function()
        if not ShouldMeasure() then return callback() end
        return RunMeasured(name, callback)
    end end,
    [1] = function(name, callback) return function(a)
        if not ShouldMeasure() then return callback(a) end
        return RunMeasured(name, callback, a)
    end end,
    [2] = function(name, callback) return function(a, b)
        if not ShouldMeasure() then return callback(a, b) end
        return RunMeasured(name, callback, a, b)
    end end,
    [3] = function(name, callback) return function(a, b, c)
        if not ShouldMeasure() then return callback(a, b, c) end
        return RunMeasured(name, callback, a, b, c)
    end end,
    [4] = function(name, callback) return function(a, b, c, d)
        if not ShouldMeasure() then return callback(a, b, c, d) end
        return RunMeasured(name, callback, a, b, c, d)
    end end,
    [5] = function(name, callback) return function(a, b, c, d, e)
        if not ShouldMeasure() then return callback(a, b, c, d, e) end
        return RunMeasured(name, callback, a, b, c, d, e)
    end end,
    [6] = function(name, callback) return function(a, b, c, d, e, f)
        if not ShouldMeasure() then return callback(a, b, c, d, e, f) end
        return RunMeasured(name, callback, a, b, c, d, e, f)
    end end,
    [7] = function(name, callback) return function(a, b, c, d, e, f, g)
        if not ShouldMeasure() then return callback(a, b, c, d, e, f, g) end
        return RunMeasured(name, callback, a, b, c, d, e, f, g)
    end end,
}

function Diagnostics.Wrap(name, callback, arity)
    Diagnostics.coverage[name] = true
    local factory = wrapperFactories[arity]
    if factory then return factory(name, callback) end
    -- Generic compatibility path: Lua 5.0 itself creates arg on entry.
    -- Fixed-arity wrappers avoid that input table while measurements are off.
    return function(...)
        if not ShouldMeasure() then return callback(unpack(arg)) end
        return RunMeasured(name, callback, unpack(arg))
    end
end

function Diagnostics.GetOperationTotals(scope)
    local calls, elapsed, memoryChange, largestIncrease, slowestTime, slowestName = 0, 0, 0, 0, 0, nil
    local name, entry
    for name, entry in pairs(scope and scope.operations or Diagnostics.operations) do
        calls = calls + entry.count
        elapsed = elapsed + entry.time
        memoryChange = memoryChange + entry.memory
        if entry.maxMemory > largestIncrease then largestIncrease = entry.maxMemory end
        if entry.maxTime > slowestTime then slowestTime = entry.maxTime; slowestName = name end
    end
    return calls, elapsed, memoryChange, largestIncrease, slowestName, slowestTime
end
