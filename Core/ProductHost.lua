local Lib = BootyLib
local UI = Lib.UI.Components
local ProductHost = {}
Lib.Core.ProductHost = ProductHost
local serial = 0

local function Finite(value)
    return type(value) == "number" and value == value and value > -1e300 and value < 1e300
end
local function Invoke(frame, callback)
    if not callback then return end
    local previous = this
    this = frame
    local ok, failure = pcall(callback)
    this = previous
    if not ok then error(failure) end
end
local function Store(product)
    local db = product.GetDatabase and product.GetDatabase() or product.namespace and product.namespace.Database and product.namespace.Database.Ensure()
    if type(db) ~= "table" then error("Product must expose its own database.") end
    if type(db.presentation) ~= "table" then db.presentation = {} end
    local presentation = db.presentation
    if type(presentation.windows) ~= "table" then presentation.windows = {} end
    if type(presentation.minimap) ~= "table" then presentation.minimap = { angle = 225 } end
    return presentation, db
end
function ProductHost.Create(product, options)
    options = options or {}
    serial = serial + 1
    local instance = serial
    local host = { product = product, standalone = not options.integrated, integrated = options.integrated and true or false,
        controllers = {}, windows = {}, window = options.window }
    local definitions = {}
    for _, definition in ipairs(product.views or {}) do definitions[definition.id] = definition end
    host.Print = options.Print or function(message)
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage("|cffe0b95a" .. (product.title or product.name) .. "|r: " .. tostring(message))
        end
    end
    host.GetPresentationSetting = function(key)
        local presentation = Store(product)
        return presentation[key]
    end
    local function Geometry(id)
        local presentation = Store(product)
        local geometry = presentation.windows[id]
        if type(geometry) ~= "table" then geometry = {}; presentation.windows[id] = geometry end
        return geometry
    end
    local function SaveGeometry(id)
        local window = host.windows[id]
        if not window or window.minimized then return end
        local geometry = Geometry(id)
        local width, height = window:GetWidth(), window:GetHeight()
        if Finite(width) and width > 0 then geometry.width = width end
        if Finite(height) and height > 0 then geometry.height = height end
        local left, bottom = window.GetLeft and window:GetLeft(), window.GetBottom and window:GetBottom()
        if Finite(left) and Finite(bottom) then geometry.left, geometry.bottom = left, bottom end
    end
    local function ResizeContent(id)
        local window, controller = host.windows[id], host.controllers[id]
        if not window or window.minimized then return end
        -- Permanent chrome owns the rectangle; there is no scrollbar gutter at
        -- this layer. A feature's own viewport reserves actual overflow space.
        window.content:SetWidth(math.max(1, window:GetWidth() - 8))
        window.content:SetHeight(math.max(1, window:GetHeight() - 34))
        if controller and controller.OnResize then controller:OnResize() end
    end
    local function RestoreBounds(window, definition, geometry)
        local screenWidth, screenHeight = UI.GetFrameSpan(UIParent)
        local maxWidth = math.max(1, math.min(definition.maxWidth or 1400, screenWidth - 24))
        local maxHeight = math.max(1, math.min(definition.maxHeight or 1000, screenHeight - 24))
        local minWidth = math.min(definition.minWidth or 350, maxWidth)
        local minHeight = math.min(definition.minHeight or 300, maxHeight)
        window:SetMinResize(minWidth, minHeight); window:SetMaxResize(maxWidth, maxHeight)
        local width = Finite(geometry.width) and geometry.width or definition.width or 900
        local height = Finite(geometry.height) and geometry.height or definition.height or 620
        window:SetWidth(math.max(minWidth, math.min(maxWidth, width)))
        window:SetHeight(math.max(minHeight, math.min(maxHeight, height)))
        if Finite(geometry.left) and Finite(geometry.bottom) then
            local left = math.max(0, math.min(math.max(0, screenWidth - window:GetWidth()), geometry.left))
            local bottom = math.max(0, math.min(math.max(0, screenHeight - window:GetHeight()), geometry.bottom))
            window:ClearAllPoints(); window:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
        end
    end
    local function CreateWindow(definition)
        local id = definition.id
        local window = UI.Window.Create({ name = product.name .. "View" .. id .. instance,
            title = definition.title or (table.getn(product.views) == 1 and product.name or definition.label),
            icon = definition.icon, plainHeader = true, compact = true, minimizedWidth = 400,
            attach = function() end,
            update = function() ResizeContent(id) end,
        })
        host.windows[id] = window
        host.window = window
        local geometry = Geometry(id)
        RestoreBounds(window, definition, geometry)
        window.content.mosWidthOwner, window.content.mosWidthInset = window, 8
        window.content.mosHeightOwner, window.content.mosHeightInset = window, 34
        ResizeContent(id)
        local controller = definition.create(window.content, host)
        host.controllers[id] = controller
        window.AttachView({ viewport = window.content, page = controller.frame })
        local hidden = window:GetScript("OnHide")
        window:SetScript("OnHide", function()
            SaveGeometry(id)
            if hidden then hidden() end
            if controller.Hide then controller:Hide() end
            if host.menu then host.menu:Close() end
        end)
        local dragged = window:GetScript("OnDragStop")
        window:SetScript("OnDragStop", function() if dragged then dragged() end; SaveGeometry(id) end)
        local minimize = window.minimizeButton
        if minimize then
            local clicked = minimize:GetScript("OnClick")
            minimize:SetScript("OnClick", function()
                if not window.minimized then SaveGeometry(id); if controller.Hide then controller:Hide() end end
                if clicked then clicked() end
                if not window.minimized then
                    RestoreBounds(window, definition, Geometry(id)); ResizeContent(id)
                    if controller.Show then controller:Show() end
                end
            end)
        end
        -- Window.Create supplies project chrome; its Settings-specific deferred
        -- scroll setup is not part of a standalone feature host.
        window.Open = function()
            if window.minimized and minimize then Invoke(minimize, minimize:GetScript("OnClick")) end
            window:SetScript("OnUpdate", nil)
            window.content:Show(); window.resizeGrip:Show(); window:Show(); window:Raise()
            ResizeContent(id)
            if controller.Show then controller:Show() end
            host.activeView = id
            return controller
        end
        window.Toggle = function()
            if window:IsVisible() and not window.minimized then window:Hide()
            else return window.Open() end
            return controller
        end
        return controller
    end
    host.GetView = function(id)
        if product.stopped then host.Print("This addon is paused. Resume it in Booty Suite Plugins."); return nil end
        local definition = definitions[id]
        if not definition or definition.IsAvailable and not definition.IsAvailable() then return nil end
        local controller = host.controllers[id]
        if controller then return controller end
        if not host.standalone then
            local parent = options.GetParent and options.GetParent(id) or options.parent
            if not parent then return nil end
            controller = definition.create(parent, host)
            host.controllers[id] = controller
            return controller
        end
        return CreateWindow(definition)
    end
    host.OpenView = function(id)
        local controller = host.GetView(id)
        if not controller then return false end
        if options.OpenView and not host.standalone then return options.OpenView(id, controller) end
        if host.standalone then return host.windows[id].Open() end
        for key, view in pairs(host.controllers) do if key ~= id and view.Hide then view:Hide() end end
        if controller.Show then controller:Show() end
        host.activeView = id
        return controller
    end
    host.OpenSettings = function()
        if host.menu then host.menu:Close() end
        local settings = Lib.Core.SettingsHost
        if not settings or not settings.Open then return false end
        return settings.Open(product, host)
    end
    host.Close = function()
        if host.menu then host.menu:Close() end
        for id, controller in pairs(host.controllers) do
            if host.windows[id] then host.windows[id]:Hide() end
            if controller.Hide then controller:Hide() end
        end
    end
    host.Hide = host.Close
    host.ToggleMenu = function(anchor)
        if host.menu and host.menu:IsOpen() then host.menu:Close();return end
        if not host.menu then
            host.menu = UI.CreateCascadingMenu(function(action, data)
                if type(action) == "function" then action(data) end
            end, { fontSize = 11 })
        end
        local entries = product.GetQuickMenu and product.GetQuickMenu(host) or {}
        host.menu:Open(anchor, entries)
    end
    host.ApplySettings = function()
        local presentation, db = Store(product)
        if host.minimap then
            if db.hideMinimapIcon or presentation.minimap.hidden then host.minimap:Hide() else host.minimap:Show() end
        end
    end
    host.RefreshPresentation = host.ApplySettings
    if host.standalone and options.minimap ~= false then
        local presentation = Store(product)
        host.minimap = UI.Dashboard.CreateMinimapButton({ name = product.name .. "MinimapButton",
            title = product.title or product.name, iconTexture = product.iconTexture or "Interface\\AddOns\\BootyLib\\Textures\\MinimapIcon",
            ensureDatabase = function() Store(product) end,
            getAngle = function() local data = Store(product); return data.minimap.angle or 225 end,
            getPosition = function() local data = Store(product); return data.minimap.x, data.minimap.y end,
            setPosition = function(x, y) local data = Store(product); data.minimap.x, data.minimap.y = x, y end,
            onOpen = function()
                local id = host.activeView or product.views and product.views[1] and product.views[1].id
                if not id then return end
                if host.GetView(id) and host.windows[id] then host.windows[id].Toggle() end
            end,
            onContextMenu = host.ToggleMenu,
        })
        host.minimap.Position()
        local _, db = Store(product)
        if db.hideMinimapIcon or presentation.minimap.hidden then host.minimap:Hide() end
    end
    return host
end
