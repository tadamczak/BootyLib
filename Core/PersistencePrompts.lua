local MOS = BootyLib

MOS.Core = MOS.Core or {}
MOS.Core.Dialogs = MOS.Core.Dialogs or {}
local Dialogs = MOS.Core.Dialogs

local function ReloadInterface()
    if type(ReloadUI) == "function" then ReloadUI()
    elseif type(ConsoleExec) == "function" then ConsoleExec("reloadui") end
end

function Dialogs.RegisterPersistencePrompts(printMessage)
    StaticPopupDialogs["MUKLA_OFFICER_SUITE_RELOAD"] = {
        mosProjectTitle = "Export guild roster",
        text = "The guild roster scan is complete. Reload the UI now to write it to disk?",
        button1 = "Reload now", button2 = "Later", OnAccept = ReloadInterface,
        OnCancel = function() printMessage("Guild data remains in memory. Use /reload before closing the game to save it.") end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    StaticPopupDialogs["MUKLA_OFFICER_SUITE_CSR_RELOAD"] = {
        mosProjectTitle = "Save CSR snapshot",
        text = "The raid and guild data scan is complete. Reload the UI now to write the CSR snapshot to disk?",
        button1 = "Reload now", button2 = "Later", OnAccept = ReloadInterface,
        OnCancel = function() printMessage("CSR remains in memory. Use /reload before closing the game to save it.") end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
    StaticPopupDialogs["MUKLA_OFFICER_SUITE_ATTENDANCE_RELOAD"] = {
        mosProjectTitle = "Save attendance snapshot",
        text = "Attendance snapshot is ready. Reload the UI now to write it to disk?",
        button1 = "Reload now", button2 = "Later", OnAccept = ReloadInterface,
        OnCancel = function() printMessage("Attendance remains in memory. Use /reload before running Export-Attendance.ps1.") end,
        timeout = 0, whileDead = 1, hideOnEscape = 1,
    }
end
