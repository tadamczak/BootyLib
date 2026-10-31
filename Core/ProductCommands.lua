local Lib = BootyLib
local Commands = {}
Lib.Core.ProductCommands = Commands

function Commands.Inventory()
    local result = {}
    if type(GetNumAddOns) ~= "function" or type(GetAddOnInfo) ~= "function" then return result, false end
    local ok, count = pcall(GetNumAddOns)
    if not ok or type(count) ~= "number" or count ~= count or count < 0 or count > 4096 or count ~= math.floor(count) then return result, false end
    for index = 1, count do
        local success, name, title, notes, enabled, loadable, reason = pcall(GetAddOnInfo, index)
        if success and type(name) == "string" and name ~= "" then
            result[name] = {name=name, title=title, notes=type(notes)=="string" and notes or nil,
                enabled=enabled~=nil and enabled~=false and enabled~=0,
                loadable=loadable~=nil and loadable~=false and loadable~=0, reason=reason, index=index}
        end
    end
    return result, true
end

function Commands.Version(name)
    if name == "BootyLib" then return Lib.version or "Unknown" end
    if name == "BootySuite" and BootySuite then return BootySuite.version end
    for _, id in ipairs(Lib.GetProducts()) do
        local product = Lib.GetProduct(id)
        if (product.addonName or product.name) == name and product.initialized then return product.version or "Unknown" end
    end
    if type(GetAddOnMetadata) == "function" then
        local ok, version = pcall(GetAddOnMetadata, name, "Version")
        if ok and type(version) == "string" and version ~= "" then return version end
    end
    return "Unknown"
end

function Commands.Help(name, command)
    Lib.Print("Available commands:",name)
    Lib.Print(command .. " open - Open the addon window.",name)
    Lib.Print(command .. " settings - Open addon settings.",name)
    Lib.Print(command .. " about - Show addon information.",name)
    Lib.Print(command .. " versions - " .. (name=="BootySuite" and "List versions of all installed Booty addons." or "Show this addon's version."),name)
end

function Commands.PrintVersions(name)
    if name then Lib.Print("Version: " .. Commands.Version(name), name); return end
    local inventory = Commands.Inventory()
    local names, seen = {}, {}
    local function Add(value)
        if not seen[value] then seen[value]=true; table.insert(names,value) end
    end
    Add("BootyLib")
    if BootySuite then Add("BootySuite") end
    for _, id in ipairs(Lib.GetProducts()) do local product=Lib.GetProduct(id); Add(product.addonName or product.name) end
    for addon in pairs(inventory) do if string.find(addon,"^Booty") then Add(addon) end end
    table.sort(names)
    for _, addon in ipairs(names) do Lib.Print(addon .. ": " .. Commands.Version(addon), "BootySuite") end
end

function Commands.Available(product)
    if not product or not product.initialized or product.stopped or product.failure then return false end
    local name = product.addonName or product.name
    local suite = Lib.Core.Runtime.suite
    if suite and suite.IsProductAvailable then return suite.IsProductAvailable(product) end
    local inventory, known = Commands.Inventory()
    return not known or inventory[name] ~= nil and inventory[name].enabled
end

function Lib.OpenBoundView(id)
    local runtime = Lib.Core.Runtime
    if runtime.suite and (id == "suite" or id == "plugins" or id == "about") then
        local suite = runtime.suite
        local toggle = suite.ToggleView or suite.OpenView
        return toggle(id == "suite" and (suite.active or suite.order[1]) or id)
    end
    local owner = runtime.viewOwners[id]
    local product, host = runtime.products[owner], runtime.hosts[owner]
    if not Commands.Available(product) or not host then Lib.Print("This Booty addon is unavailable.", product and product.name); return false end
    local toggle = host.ToggleView or host.OpenView
    return toggle(id)
end

function Commands.Install(product, host)
    SlashCmdList = SlashCmdList or {}
    local key = string.upper(product.name)
    if product.bootyCommandsInstalled then return end
    local original = SlashCmdList[key]
    if product.ownsCommands and product.Command then
        if not original then _G["SLASH_" .. key .. "1"] = "/" .. string.lower(product.name) end
        SlashCmdList[key]=product.Command;product.bootyCommandsInstalled=true;return
    end
    if not original then _G["SLASH_" .. key .. "1"] = "/" .. string.lower(product.name) end
    SlashCmdList[key] = function(message)
        local _, _, command, argument = string.find(tostring(message or ""), "^%s*(%S*)%s*(.-)%s*$")
        command = string.lower(command or "")
        if command == "versions" then Commands.PrintVersions(product.addonName or product.name)
        elseif command == "about" then Lib.Print("Version " .. Commands.Version(product.addonName or product.name) .. ". " .. (product.description or "Booty addon"), product.name)
        elseif command == "help" then Commands.Help(product.name, "/" .. string.lower(product.name))
        elseif command == "open" or command == "settings" or not original and command == "" then
            if command == "settings" then
                if original then return original(message) end
                return host.OpenSettings()
            end
            if not Commands.Available(product) then Lib.Print("This Booty addon is unavailable.", product and product.name); return false end
            local id = product.views[1] and product.views[1].id
            if argument ~= "" then
                id = nil
                for _, view in ipairs(product.views) do if string.lower(view.id) == string.lower(argument) then id=view.id end end
            end
            if id then return host.OpenView(id) end
            Lib.Print("Unknown section. Use " .. "/" .. string.lower(product.name) .. " help for available commands.", product.name)
        elseif original then return original(message)
        else Commands.Help(product.name, "/" .. string.lower(product.name)) end
    end
    product.bootyCommandsInstalled = true
end

BINDING_HEADER_BOOTYOPEN = "Booty addons and tabs"
local bindings = {SUITE="Booty Suite", ROSTER="Guild", STATISTICS="Guild Statistics", RAID="Raid",
    RAIDSTATISTICS="Raid Statistics", CSR="CSR", PROFILER="Profiler", ACTIONBARS="Action Bars",
    CHAT="Chat", MAP="Map", FRAME="Frames", FOCUS="Focus", PLUGINS="Plugins", ABOUT="About"}
for key, label in pairs(bindings) do _G["BINDING_NAME_BOOTYOPEN_" .. key] = "Open " .. label end
