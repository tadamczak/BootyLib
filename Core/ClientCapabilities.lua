local Booty = BootyLib
Booty.Core.ClientCapabilities = Booty.Core.ClientCapabilities or {}
local Capabilities = Booty.Core.ClientCapabilities

-- Capture only on an explicit diagnostic request. Presence checks do not call
-- memory-update APIs, create probes, install handlers or modify client globals.
function Capabilities.Collect(label)
    local nativeText = label and type(label.GetStringHeight) == "function"
    local stockText = label and type(label.GetHeight) == "function"
        and type(label.GetFont) == "function" and type(label.GetText) == "function"
        and type(label.GetWidth) == "function"
    local nampowerVersion
    if type(GetNampowerVersion) == "function" then
        local ok, major, minor, patch = pcall(GetNampowerVersion)
        if ok and type(major) == "number" and type(minor) == "number" and type(patch) == "number" then
            nampowerVersion = tostring(major) .. "." .. tostring(minor) .. "." .. tostring(patch)
        end
    end
    local superwowVersion = type(SUPERWOW_VERSION) == "number" or type(SUPERWOW_VERSION) == "string"
    local classicAPIVersion = type(CLASSIC_API_VERSION) == "number" or type(CLASSIC_API_VERSION) == "string"
    local compatibility = Booty.Core.Compatibility
    return {
        lua = tostring(_VERSION or "unknown"),
        match = compatibility and compatibility.matchBackend or "not loaded",
        text = not label and "not probed" or nativeText and "GetStringHeight" or stockText and "GetHeight probe" or "missing metrics",
        addonMemory = type(UpdateAddOnMemoryUsage) == "function" and type(GetAddOnMemoryUsage) == "function"
            and type(GetNumAddOns) == "function" and type(GetAddOnInfo) == "function" or false,
        heap = type(gcinfo) == "function",
        clock = type(GetTime) == "function",
        classicAPI = type(ClassicAPI) == "table" or classicAPIVersion,
        classicAPIVersion = classicAPIVersion and tostring(CLASSIC_API_VERSION) or nil,
        superAPI = type(SuperAPI) == "table",
        superwow = superwowVersion and tostring(SUPERWOW_VERSION) or nil,
        nampower = nampowerVersion or (type(GetNampowerVersion) == "function" and "version unavailable" or nil),
    }
end

function Capabilities.Describe(snapshot)
    return "Runtime: " .. snapshot.lua .. "; Match=" .. snapshot.match .. "; text=" .. snapshot.text
        .. "; addon memory=" .. (snapshot.addonMemory and "available" or "unavailable")
        .. "; gcinfo=" .. (snapshot.heap and "available" or "unavailable")
        .. "; GetTime=" .. (snapshot.clock and "available" or "unavailable"),
        "Extension markers: ClassicAPI=" .. (snapshot.classicAPIVersion and "version code " .. snapshot.classicAPIVersion or snapshot.classicAPI and "present" or "absent")
        .. "; SuperAPI=" .. (snapshot.superAPI and "present" or "absent")
        .. "; SuperWoW=" .. (snapshot.superwow or "absent")
        .. "; Nampower=" .. (snapshot.nampower or "absent")
end
