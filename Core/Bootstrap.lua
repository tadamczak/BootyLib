local memoryBeforeLoad = type(gcinfo) == "function" and gcinfo() or nil
BootyLib = BootyLib or {}
local Lib = BootyLib
Lib.version = "0.1.0-dev.18"
Lib.API_VERSION = 1
Lib.Core = Lib.Core or {}
Lib.Services = Lib.Services or {}
Lib.UI = Lib.UI or { Components = {} }
Lib.UI.Components = Lib.UI.Components or {}
Lib.Diagnostics = Lib.Diagnostics or {startedAt = type(GetTime) == "function" and GetTime() or 0, events = 0, uiRefreshes = 0, scans = 0}
Lib.Diagnostics.memoryBeforeLoad = memoryBeforeLoad
function Lib.Diagnostics.Count(metric)
    Lib.Diagnostics[metric] = (tonumber(Lib.Diagnostics[metric]) or 0) + 1
end
function Lib.Print(message)
    if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffffd36b[Booty]|r " .. tostring(message)) end
end
