local Booty = BootyLib
local Window = {}
local projectBackdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 } }
Booty.UI.Components.Window = Window
Window.MinimizedHeight = Booty.UI.Components.MinimizedWindowHeight or 30

function Window.ApplyProjectSurface(frame)
    -- Registered dropdowns may already own a skinned nine-slice. Hide it before
    -- applying the native project border, including after a skin change.
    frame.bootyUseNativeSurface = true
    if Booty.UI.Components.SetSurfaceCompact then Booty.UI.Components.SetSurfaceCompact(frame, false) end
    frame:SetBackdrop(projectBackdrop)
    frame:SetBackdropColor(0.015, 0.015, 0.015, 1)
    frame:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
end

function Window.Create(options)
    local view
    local window = Booty.UI.Components.CreateContainer(options.name, UIParent)
    window:SetWidth(780); window:SetHeight(620)
    window:SetPoint("CENTER", UIParent, "CENTER", 40, 10)
    window:SetFrameStrata("FULLSCREEN_DIALOG"); window:SetFrameLevel(200); window:SetMovable(true); window:SetResizable(true)
    if window.SetClampedToScreen then window:SetClampedToScreen(true) end
    window:SetMinResize(350, 420); window:SetMaxResize(1100, 760)
    window:EnableMouse(true); window:RegisterForDrag("LeftButton")
    window:SetScript("OnDragStart", function() this:StartMoving() end)
    window:SetScript("OnDragStop", function() this:StopMovingOrSizing() end)
    local windowBackdrop = projectBackdrop
    Window.ApplyProjectSurface(window)

    local titleBar = Booty.UI.Components.CreateContainer(nil, window)
    titleBar:SetFrameLevel(window:GetFrameLevel() + 1)
    local function ApplyTitleBarGeometry(minimized)
        local inset = (minimized or options.plainHeader) and -4 or -8
        titleBar:ClearAllPoints(); titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 4, inset); titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -4, inset)
        titleBar:SetHeight(minimized and (Window.MinimizedHeight - 8) or (options.plainHeader and 26 or (options.compact and 28 or 36)))
    end
    ApplyTitleBarGeometry(false)
    if not options.plainHeader then
        Booty.UI.Components.RegisterSkinnedSurface(titleBar, "title", { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }, { 0.025, 0.022, 0.018, 0.98 }, { 0.42, 0.42, 0.40, 1 })
    end
    local title = Booty.UI.Components.CreateHeading(titleBar, "", options.compact and 3 or 1, "gold", options.icon or "settings")
    if options.compact then local font, size, flags = title:GetFont(); title:SetFont(font, size - 1, flags) end
    title:SetPoint("LEFT", titleBar, "LEFT", options.plainHeader and 4 or 8, 0); title:SetText(options.title)
    local close = Booty.UI.Components.CreateWindowButton(titleBar, nil, "close")
    close:SetPoint("RIGHT", titleBar, "RIGHT", -4, 0)
    local minimize = Booty.UI.Components.CreateWindowButton(titleBar, nil, "minimize")
    minimize:SetPoint("RIGHT", close, "LEFT", -4, 0)
    local settings
    if options.onSettings then
        settings = Booty.UI.Components.CreateSettingsButton(titleBar)
        settings:SetPoint("RIGHT", minimize, "LEFT", -4, 0)
        settings:SetScript("OnClick", function() return options.onSettings(window) end)
        Booty.UI.Components.AttachTooltip(settings, "Settings", "Open settings for this addon.")
        title:SetPoint("RIGHT", settings, "LEFT", -6, 0)
    end
    local content = Booty.UI.Components.CreateContainer(nil, window)
    content:SetFrameLevel(window:GetFrameLevel() + 1)
    content:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", 0, 0); content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -4, options.compact and 4 or 14)
    content.bootyUseNativeSurface = false
    Booty.UI.Components.RegisterSkinnedSurface(content, "content", options.plainHeader and windowBackdrop or { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } }, { 0.02, 0.02, 0.02, 1 }, options.plainHeader and {0.68,0.54,0.27,1} or { 0.36, 0.36, 0.34, 1 })
    if options.plainHeader then Booty.UI.Components.JoinSurfaceEdges(content, true, false) end
    local resize = Booty.UI.Components.CreateResizeGrip(window)
    if options.compact then
        resize.texture:Hide(); resize:ClearAllPoints(); resize:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", 0, 0)
    end
    resize:SetFrameLevel(window:GetFrameLevel() + 1); resize:EnableMouse(true)
    Booty.UI.Components.AttachTooltip(resize, "Resize Settings", "Drag to change the window size.")
    resize:SetScript("OnMouseDown", function() window:StartSizing("BOTTOMRIGHT") end)
    resize:SetScript("OnMouseUp", function() window:StopMovingOrSizing(); if view then options.update(view) end end)

    resize:SetScript("OnHide", function() window:StopMovingOrSizing() end)

    local function RememberTop()
        if options.minimizedWidth then
            local left = window.GetLeft and window:GetLeft()
            local top = window.GetTop and window:GetTop()
            if left and top then window.bootyCompactLeft, window.bootyCompactTop = left, top end
        end
    end
    local function ResizeKeepingTop(width, height)
        RememberTop()
        if options.minimizedWidth then
            if window.bootyCompactLeft and window.bootyCompactTop then
                window:ClearAllPoints(); window:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", window.bootyCompactLeft, window.bootyCompactTop)
            end
        end
        window:SetWidth(width); window:SetHeight(height)
    end
    local function ApplyResizeBounds(desiredWidth, desiredHeight)
        local screenWidth = (UIParent.GetWidth and UIParent:GetWidth()) or 1100
        local screenHeight = (UIParent.GetHeight and UIParent:GetHeight()) or 760
        local maximumWidth = math.max(320, math.min(1100, screenWidth - 32))
        local maximumHeight = math.max(260, math.min(760, screenHeight - 32))
        local minimumWidth = math.min(350, maximumWidth)
        local minimumHeight = math.min(420, maximumHeight)
        window:SetMinResize(minimumWidth, minimumHeight); window:SetMaxResize(maximumWidth, maximumHeight)
        local width = math.max(minimumWidth, math.min(maximumWidth, desiredWidth or window:GetWidth()))
        local height = math.max(minimumHeight, math.min(maximumHeight, desiredHeight or window:GetHeight()))
        if width ~= window:GetWidth() or height ~= window:GetHeight() then ResizeKeepingTop(width, height) end
    end
    window:SetScript("OnSizeChanged", function() if view and not window.minimized and window:IsVisible() then options.update(view) end end)

    local function CloseWindow() RememberTop(); window:Hide() end
    close:SetScript("OnClick", CloseWindow)
    minimize:SetScript("OnClick", function()
        if not view then return end
        if window.minimized then
            window.minimized = false
            ApplyTitleBarGeometry(false)
            if options.minimizedWidth then ApplyResizeBounds(window.expandedWidth, window.expandedHeight)
            else window:SetHeight(window.expandedHeight or 620) end
            content:Show(); resize:Show(); view.viewport:Show(); Booty.UI.Components.SetWindowButtonAction(minimize, "minimize")
            options.update(view)
        else
            window.minimized = true; window.expandedHeight = window:GetHeight(); window.expandedWidth = window:GetWidth()
            window:SetScript("OnUpdate", nil)
            view.viewport:Hide(); content:Hide(); resize:Hide()
            local height = Window.MinimizedHeight
            ApplyTitleBarGeometry(true)
            if options.minimizedWidth then
                local width = math.min(options.minimizedWidth, UIParent:GetWidth() - 16)
                window:SetMinResize(width, height); window:SetMaxResize(width, height)
                ResizeKeepingTop(width, height)
            else window:SetHeight(height) end
            Booty.UI.Components.SetWindowButtonAction(minimize, "maximize")
        end
    end)
    local function FinishOpen()
        window:SetScript("OnUpdate", nil)
        if not window:IsVisible() or not view or window.minimized then return end
        view.viewport:SetScrollChild(view.page)
        view.page:Show()
        options.update(view)
        if view.viewport.UpdateScrollChildRect then view.viewport:UpdateScrollChildRect() end
    end
    window:SetScript("OnHide", function() window:SetScript("OnUpdate", nil) end)
    window.Open = function()
        ApplyTitleBarGeometry(false)
        if not view then return end
        if window:IsVisible() then
            if window.minimized then minimize:GetScript("OnClick")() end
            window:Raise()
            return
        end
        local minimized = window.minimized
        window.minimized = false
        ApplyResizeBounds(minimized and window.expandedWidth or nil, minimized and window.expandedHeight or nil)
        content:Show(); resize:Show(); Booty.UI.Components.SetWindowButtonAction(minimize, "minimize")
        window:Show(); view.viewport:SetVerticalScroll(0); view.viewport:Show()
        if view.scrollBar then view.scrollBar:SetValue(0) end
        if options.refresh then options.refresh(view) end
        options.update(view)
        window:SetScript("OnUpdate", FinishOpen)
    end
    window.Toggle = function() if window:IsVisible() then CloseWindow() else window.Open() end end
    window.AttachView = function(settingsView)
        view = settingsView
        view.viewport.bootyWidthOwner = window
        view.viewport.bootyWidthInset = options.viewportWidthInset
        view.viewport.bootyHeightOwner = window
        view.viewport.bootyHeightInset = options.viewportHeightInset
        options.attach(view, content)
        view.viewport:Hide()
    end
    window.titleBar = titleBar
    window.title = title
    window.closeButton = close
    window.minimizeButton = minimize
    window.settingsButton = settings
    window.content = content
    window.resizeGrip = resize
    window.ApplyResizeBounds = ApplyResizeBounds
    window:Hide()
    if Booty.UI.Components.WindowStack then Booty.UI.Components.WindowStack.Register(window, {owner = options.owner}) end
    return window
end

-- Attached panels inherit visibility from their feature page and follow the owner's anchors.
function Window.CreateAttached(parent, owner, width, height, onClose)
    local C = Booty.UI.Components
    local frame = C.CreateContainer(nil, parent)
    frame:SetWidth(width); frame:SetHeight(height)
    frame:SetPoint("TOPLEFT", owner, "TOPRIGHT", 0, 0)
    frame:SetBackdrop(projectBackdrop)
    frame:SetBackdropColor(0.015, 0.015, 0.015, 1)
    frame:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
    frame:SetFrameStrata(owner:GetFrameStrata()); frame:SetFrameLevel(owner:GetFrameLevel() + 30)
    frame:EnableMouse(true)
    frame.close = C.CreateWindowButton(frame, nil, "close")
    frame.close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -6)
    frame.close:SetScript("OnClick", function() frame:Hide(); if onClose then onClose() end end)
    frame:Hide()
    if C.WindowStack then C.WindowStack.Register(frame, {owner = owner}) end
    return frame
end

-- Compact project dialog chrome shared by feature dialogs.
function Window.StyleProjectDialog(frame, iconKey)
    local UI = Booty.UI.Components
    Window.ApplyProjectSurface(frame)
    UI.RegisterSkinCallback(function() Window.ApplyProjectSurface(frame) end)
    frame:SetMovable(true); frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function() frame:StartMoving() end)
    frame:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)
    if frame.title then
        UI.SetHeadingIcon(frame.title, iconKey or frame.title.bootyHeadingIconKey or "info")
        local font, _, flags = frame.title:GetFont()
        frame.title:SetFont(font, 13, flags); frame.title:SetTextColor(unpack(UI.Theme.colors.goldText))
        -- The header interior is y=4..24. Center anchors keep text and its icon
        -- balanced even when a caller supplies a different title rectangle.
        if frame.title.bootyHeadingIcon then frame.title.bootyHeadingIconInset = 19 end
        frame.title:ClearAllPoints(); frame.title:SetPoint("LEFT", frame, "TOPLEFT", 8, -14)
        frame.title:SetPoint("RIGHT", frame, "TOPRIGHT", -42, -14)
        frame.title:SetHeight(13); frame.title:SetJustifyH("LEFT"); frame.title:SetJustifyV("MIDDLE")
    end
    frame.projectDivider = UI.CreateContainer(nil, frame)
    frame.projectDivider:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -24)
    frame.projectDivider:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -24); frame.projectDivider:SetHeight(4)
    UI.RegisterSkinnedSurface(frame.projectDivider, "content", nil, {0,0,0,0}, {0.68,0.54,0.27,1})
    UI.JoinSurfaceEdges(frame.projectDivider, true, false)
    if frame.close then frame.close:ClearAllPoints(); frame.close:SetPoint("RIGHT", frame, "TOPRIGHT", -6, -14) end
    if UI.WindowStack then UI.WindowStack.Register(frame) end
end

function Window.CreateProjectConfirmation(name, title, action, iconKey, options)
    local UI = Booty.UI.Components
    local frame = UI.CreateConfirmation(name, options)
    frame.title:SetText(title); Window.StyleProjectDialog(frame, iconKey or "info")
    frame:SetWidth(320); frame:SetHeight(118)
    frame.label:ClearAllPoints(); frame.label:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -38)
    frame.label:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -38); frame.label:SetHeight(36)
    frame.label:SetJustifyH("CENTER"); frame.label:SetJustifyV("MIDDLE")
    frame.no:SetText("Cancel"); frame.yes:SetText(action)
    frame.no:ClearAllPoints(); frame.no:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -116, 12)
    frame.yes:ClearAllPoints(); frame.yes:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 12)
    frame.no:SetWidth(96); frame.yes:SetWidth(96)
    UI.AttachGoldHoverBorder(frame.no, 0.35, 0.35, 0.35, 1)
    UI.AttachGoldHoverBorder(frame.yes, 0.35, 0.35, 0.35, 1)
    frame.no:ClearAllPoints(); frame.no:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -112, 8)
    frame.yes:ClearAllPoints(); frame.yes:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    local open = frame.Open
    frame.Open = function(self, message, onYes, onNo)
        open(self, message, onYes, onNo)
        self.label:SetText(message)
        local textHeight = math.max(32, UI.MeasureTextHeight(self.label, self:GetWidth() - 16))
        self.label:SetHeight(textHeight)
        self:SetHeight(textHeight + 78)
    end
    return frame
end
