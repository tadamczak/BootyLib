local Booty = BootyLib

Booty.UI.Components.Dashboard = Booty.UI.Components.Dashboard or {}
local Dashboard = Booty.UI.Components.Dashboard

function Dashboard.HeaderNeedsCompactTitle(get, classic, width)
    if get("hideHeaderName") or not width then return false end
    local reserved = classic and not get("hideHeaderLogo") and 120 or 66
    return width - 8 - 2 * reserved < 374
end

function Dashboard.GetChromeLayout(get, classic, width)
    local compact = get("hideHeaderLogo") and get("hideHeaderName")
    local normalHeight = classic and 44 or 32
    local topTabs = get("menuStyle") == "tabs" or get("menuStyle") == "bottomTabs"
    local headerHeight = (compact and 20 or (topTabs and 20 or normalHeight)) + 4
    if Dashboard.HeaderNeedsCompactTitle(get, classic, width) then
        headerHeight = not topTabs and classic and not get("hideHeaderLogo") and 50 or 32
    end
    local bottom = get("hideStatusVersionBar") and 4 or (classic and 26 or 31)
    if get("hideHeaderBar") then local offset = get("menuStyle") == "tabs" and -28 or -4; return 0, offset, bottom, offset end
    local top = -4 - headerHeight
    return headerHeight, top, bottom, top
end

local function SetChromeVisible(region, shown) if shown then region:Show() else region:Hide() end end

function Dashboard.UpdateTitleMetrics(view)
    local title = view.classicTitle
    -- Measure at the current font without the previous clipping rectangle.
    -- A rounded width alone leaves no room for the native glyph edges.
    title:SetWidth(0)
    view.classicTitleWidth = math.max(1, math.ceil(title:GetStringWidth())) + 4
    title:SetWidth(view.classicTitleWidth)
    local _, size = title:GetFont()
    title:SetHeight(math.max(19, math.ceil(size or 16) + 3))
    return view.classicTitleWidth
end

function Dashboard.SetTabBody(view, protruding, topInset)
    topInset = topInset or 0
    local frame = view.frame
    if protruding or topInset > 0 then
        if not view.tabBody then
            local body = Booty.UI.Components.CreateContainer(nil, frame)
            body:EnableMouse(false); body:SetFrameLevel(frame:GetFrameLevel())
            body:SetBackdrop(frame.bootyWindowBackdrop)
            body:SetBackdropColor(0.02, 0.02, 0.02, 0.98); body:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
            body:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0); body:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 30)
            view.tabBody = body
        end
        view.tabBody:ClearAllPoints()
        view.tabBody:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -topInset)
        view.tabBody:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, protruding and 30 or 0)
        frame:SetBackdropColor(0, 0, 0, 0); frame:SetBackdropBorderColor(0, 0, 0, 0)
        view.tabBody:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
        view.tabBody:Show()
    else
        if view.tabBody then view.tabBody:Hide() end
        frame:SetBackdropColor(0.02, 0.02, 0.02, 0.98); frame:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
    end
    view.tabsProtruding = protruding
end

-- Reuse the exact main-window backdrop, including its textured gold edge.
-- Keep the transparent outline above inactive tabs and below the active tab.
function Dashboard.SetBottomTabSeam(view, shown)
    local seam = view.bottomTabSeam
    if shown then
        if not seam then
            seam = Booty.UI.Components.CreateContainer(nil, view.frame)
            seam:EnableMouse(false)
            seam:SetBackdrop(view.frame.bootyWindowBackdrop)
            seam:SetBackdropColor(0, 0, 0, 0)
            seam:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
            view.bottomTabSeam = seam
        end
        seam:ClearAllPoints()
        seam:SetPoint("TOPLEFT", view.frame, "TOPLEFT", 0, 0)
        seam:SetPoint("BOTTOMRIGHT", view.contentPanel, "BOTTOMRIGHT", 4, view.bottomTabsWithStatus and -26 or -4)
        seam:SetFrameStrata(view.frame:GetFrameStrata())
        seam:SetFrameLevel(view.frame:GetFrameLevel() + 23)
        if view.tabsProtruding then view.tabBody:SetBackdropBorderColor(0, 0, 0, 0) end
        seam:Show()
    elseif seam then seam:Hide() end
end

function Dashboard.PlaceWindowControls(view, inContent)
    local controls = view.windowControls
    controls:ClearAllPoints()
    if inContent then controls:SetPoint("TOPRIGHT", view.contentPanel, "TOPRIGHT", -3, -3)
    else controls:SetPoint("TOPRIGHT", view.titleBar, "TOPRIGHT", -3, -3) end
    controls:Show()
end

function Dashboard.ApplyMinimizedChrome(view)
    local frame = view.frame
    Dashboard.SetTabBody(view, false); Dashboard.SetBottomTabSeam(view, false)
    frame:SetBackdrop(frame.bootyWindowBackdrop)
    frame:SetBackdropColor(0, 0, 0, 1); frame:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
    -- One project outline owns the compact shell. Keep the inner header plain
    -- and center its controls; expanded TOPRIGHT anchors leave unequal margins.
    Booty.UI.Components.SetSurfaceTransparent(view.titleBar, true)
    view.titleBar:ClearAllPoints()
    view.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 5, -5)
    view.titleBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 5)
    view.titleBar:SetHeight(20); view.titleBar:Show()
    view.windowControls:ClearAllPoints()
    view.windowControls:SetPoint("RIGHT", view.titleBar, "RIGHT", -5, 0); view.windowControls:Show()
    view.title:ClearAllPoints(); view.title:SetPoint("LEFT", view.titleBar, "LEFT", 5, 0)
    view.title:SetWidth(156); view.title:SetHeight(18); view.title:SetJustifyH("LEFT"); view.title:SetFontObject(GameFontNormal)
    view.title:SetText(view.titleText or "Booty Suite"); view.title:SetTextColor(unpack(Booty.UI.Components.Theme.colors.goldText))
    view.classicTitle:Hide(); view.classicLogo:Hide(); view.classicTitleLeft:Hide(); view.classicTitleRight:Hide(); view.title:Show()
    view.sidebar:Hide(); view.contentPanel:Hide(); view.versionText:Hide(); view.resizeGrip:Hide(); view.sidebarToggle:Hide()
    if frame.bootyStatusBar then frame.bootyStatusBar:Hide() end
    if view.lootBorder then view.lootBorder:Hide() end
end

function Dashboard.ApplyChrome(view, get)
    if view.minimized then
        Dashboard.ApplyMinimizedChrome(view)
        return
    end
    local classic = Booty.UI.Components.IsClassicSkin()
    local height = Dashboard.GetChromeLayout(get, classic, view.frame:GetWidth())
    view.titleBar:ClearAllPoints()
    view.titleBar:SetPoint("TOPLEFT", view.frame, "TOPLEFT", classic and 4 or 9, -4)
    view.titleBar:SetPoint("TOPRIGHT", view.frame, "TOPRIGHT", -4, -4)
    view.titleBar:SetHeight(height)
    local topTabs = get("menuStyle") == "tabs" or get("menuStyle") == "bottomTabs"
    view.classicLogo:SetWidth(topTabs and 45 or 100); view.classicLogo:SetHeight(topTabs and 18 or 40)
    SetChromeVisible(view.title, not classic and not get("hideHeaderName"))
    SetChromeVisible(view.classicTitle, classic and not get("hideHeaderName"))
    SetChromeVisible(view.classicTitleLeft, classic and not get("hideHeaderName"))
    SetChromeVisible(view.classicTitleRight, classic and not get("hideHeaderName"))
    SetChromeVisible(view.classicLogo, classic and not get("hideHeaderLogo"))
    local fitted = Dashboard.HeaderNeedsCompactTitle(get, classic, view.frame:GetWidth())
    local titleLeft = classic and not get("hideHeaderLogo") and (topTabs and 72 or 128) or 8
    local titleWidth = Dashboard.UpdateTitleMetrics(view)
    view.classicTitle:ClearAllPoints(); view.title:ClearAllPoints()
    if fitted then
        view.classicTitleLeft:Hide(); view.classicTitleRight:Hide()
        view.classicTitle:SetPoint("LEFT", view.titleBar, "LEFT", titleLeft, 1.5)
        local wordWidth = math.max(1, math.min(titleWidth, view.frame:GetWidth() - titleLeft - 78))
        view.classicTitle:SetWidth(wordWidth)
        view.title:SetPoint("LEFT", view.titleBar, "LEFT", titleLeft, 1.5)
        view.title:SetWidth(math.max(1, view.frame:GetWidth() - titleLeft - 78)); view.title:SetJustifyH("LEFT")
    else
        view.classicTitle:SetPoint("CENTER", view.titleBar, "CENTER", 0, 1.5); view.classicTitle:SetWidth(titleWidth)
        view.title:SetPoint("CENTER", view.titleBar, "CENTER", 0, 1.5); view.title:SetJustifyH("CENTER")
    end
    local hiddenHeader = get("hideHeaderBar")
    SetChromeVisible(view.titleBar, not hiddenHeader)
    Dashboard.PlaceWindowControls(view, hiddenHeader)
    if view.pageHost then
        view.pageHost:ClearAllPoints(); view.pageHost:SetPoint("TOPLEFT", view.contentPanel, "TOPLEFT", 0, hiddenHeader and -19 or 0)
        view.pageHost:SetPoint("BOTTOMRIGHT", view.contentPanel, "BOTTOMRIGHT", 0, 0)
    end
    if not classic then
        view.sidebarToggle:SetParent(hiddenHeader and view.sidebar or view.titleBar); view.sidebarToggle:ClearAllPoints()
        if hiddenHeader then view.sidebarToggle:SetPoint("TOPRIGHT", view.sidebar, "TOPRIGHT", -6, -6)
        else view.sidebarToggle:SetPoint("LEFT", view.titleBar, "LEFT", 7, 0) end
    end
    local footer = not get("hideStatusVersionBar")
    local tabs = get("menuStyle") == "tabs" or get("menuStyle") == "bottomTabs"
    view.titleBar.bootyBorderOutsetLeft = (classic and 4 or 9) - 4
    view.titleBar.bootyBorderOutsetRight = 0
    view.contentPanel.bootyBorderOutsetLeft = tabs and ((classic and 4 or 9) - 4) or 0
    view.contentPanel.bootyBorderOutsetRight = 0
    Booty.UI.Components.SetSurfaceHorizontalBorders(view.titleBar, false, get("menuStyle") ~= "tabs")
    -- Each shared seam has one owner; adjacent strips must not overlap.
    Booty.UI.Components.SetSurfaceHorizontalBorders(view.contentPanel, get("menuStyle") == "tabs", false)
    if view.frame.bootyStatusBar then
        view.frame.bootyStatusBar.bootyBorderOutsetLeft = (classic and 4 or 9) - 4
        view.frame.bootyStatusBar.bootyBorderOutsetRight = 0
        Booty.UI.Components.SetSurfaceHorizontalBorders(view.frame.bootyStatusBar, true, false, true)
    end
    view.bottomTabsWithStatus = get("menuStyle") == "bottomTabs" and footer
    local footerBottom = get("menuStyle") == "bottomTabs" and 34 or (classic and 4 or 9)
    if view.frame.bootyStatusBar then
        local bar = view.frame.bootyStatusBar
        bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT", view.frame, "BOTTOMLEFT", classic and 4 or 9, footerBottom)
        bar:SetPoint("BOTTOMRIGHT", view.frame, "BOTTOMRIGHT", -126, footerBottom)
    end
    view.versionText:ClearAllPoints(); view.versionText:SetPoint("BOTTOMRIGHT", view.frame, "BOTTOMRIGHT", -32, footerBottom + 5)
    Dashboard.SetTabBody(view, get("menuStyle") == "bottomTabs" and not (view.lootBorder and view.lootBorder:IsVisible()), hiddenHeader and get("menuStyle") == "tabs" and 24 or 0)
    Dashboard.SetBottomTabSeam(view, get("menuStyle") == "bottomTabs")
    if view.frame.bootyStatusBar then SetChromeVisible(view.frame.bootyStatusBar, footer) end
    SetChromeVisible(view.versionText, footer)
    SetChromeVisible(view.resizeGrip.texture, footer)
    view.resizeGrip:ClearAllPoints()
    view.resizeGrip:SetPoint("BOTTOMRIGHT", view.tabsProtruding and view.tabBody or view.frame, "BOTTOMRIGHT", footer and -7 or 0, footer and 7 or 0)
end

function Dashboard.CreateWindow(version, options)
    options = options or {}; local view = { titleText = options.title or "Booty Suite" }
    view.frame = CreateFrame("Frame", options.name or "BootySuiteDashboard", UIParent)
    local frame = view.frame
    frame:SetWidth(840); frame:SetHeight(540)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true); frame:SetResizable(true)
    if frame.SetDontSavePosition then frame:SetDontSavePosition(true) end
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
    frame:SetMinResize(350, 380); frame:SetMaxResize(1100, 760)
    frame:EnableMouse(true); frame:RegisterForDrag("LeftButton")
    frame.bootyWindowBackdrop = { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 } }
    frame:SetBackdrop(frame.bootyWindowBackdrop)
    frame:SetBackdropColor(0.02, 0.02, 0.02, 0.98); frame:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
    view.lootBorder = CreateFrame("Frame", nil, frame)
    view.lootBorder:SetAllPoints(frame); view.lootBorder:EnableMouse(false)
    view.lootBorder:SetFrameLevel(frame:GetFrameLevel() + 80)
    view.lootBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    view.lootBorder:SetBackdropBorderColor(0.68, 0.54, 0.27, 1)
    view.lootBorder:Hide()
    frame.bootyLootBorder = view.lootBorder
    frame:Hide()

    view.resizeGrip = Booty.UI.Components.CreateResizeGrip(frame)
    frame.bootyResizeGrip = view.resizeGrip

    view.titleBar = CreateFrame("Frame", nil, frame)
    view.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -14)
    view.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -14)
    view.titleBar:SetHeight(32)
    view.titleBar:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } })
    view.titleBar:SetBackdropColor(0.025, 0.022, 0.018, 0.98); view.titleBar:SetBackdropBorderColor(0.42, 0.42, 0.40, 1)
    Booty.UI.Components.RegisterSkinnedSurface(view.titleBar, "title", { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 12, insets = { left = 3, right = 3, top = 3, bottom = 3 } }, { 0.025, 0.022, 0.018, 0.98 }, { 0.42, 0.42, 0.40, 1 })
    Booty.UI.Components.SetSurfaceHorizontalBorders(view.titleBar, false, true)
    view.title = view.titleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    view.title:SetPoint("CENTER", view.titleBar, "CENTER", 0, 2); view.title:SetText(view.titleText or "Booty Suite")
    view.title:SetTextColor(unpack(Booty.UI.Components.Theme.colors.goldText))
    view.classicTitle = view.titleBar:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    view.classicTitle:SetText(view.titleText); view.classicTitle:SetTextColor(unpack(Booty.UI.Components.Theme.colors.goldText))
    -- Decorations follow the rendered title, not the old fixed-width wordmark.
    Dashboard.UpdateTitleMetrics(view)
    view.classicTitle:SetPoint("CENTER", view.titleBar, "CENTER", 0, 1); view.classicTitle:Hide()
    view.classicLogo = view.titleBar:CreateTexture(nil, "ARTWORK")
    view.classicLogo:SetTexture(Booty.UI.Components.ClassicAsset("logo.tga")); view.classicLogo:SetTexCoord(0, 1, 0.08203125, 0.9140625)
    view.classicLogo:SetWidth(100); view.classicLogo:SetHeight(40); view.classicLogo:SetPoint("LEFT", view.titleBar, "LEFT", 20, 0); view.classicLogo:Hide()
    view.classicTitleLeft = view.titleBar:CreateTexture(nil, "ARTWORK"); view.classicTitleLeft:SetTexture(Booty.UI.Components.ClassicAsset("Decor\\title-left.tga")); view.classicTitleLeft:SetWidth(65); view.classicTitleLeft:SetHeight(8); view.classicTitleLeft:SetPoint("RIGHT", view.classicTitle, "LEFT", -8, 0); view.classicTitleLeft:Hide()
    view.classicTitleRight = view.titleBar:CreateTexture(nil, "ARTWORK"); view.classicTitleRight:SetTexture(Booty.UI.Components.ClassicAsset("Decor\\title-right.tga")); view.classicTitleRight:SetWidth(65); view.classicTitleRight:SetHeight(8); view.classicTitleRight:SetPoint("LEFT", view.classicTitle, "RIGHT", 8, 0); view.classicTitleRight:Hide()
    view.windowControls = Booty.UI.Components.CreateContainer(nil, frame)
    view.windowControls:SetWidth(58); view.windowControls:SetHeight(18); view.windowControls:SetFrameLevel(frame:GetFrameLevel() + 60)
    frame.bootyWindowControls = view.windowControls
    view.windowControls:SetPoint("RIGHT", view.titleBar, "RIGHT", -6, 0)
    view.closeButton = Booty.UI.Components.CreateWindowButton(view.windowControls, nil, "close")
    view.closeButton:SetPoint("RIGHT", view.windowControls, "RIGHT", 0, 0)
    view.closeButton:SetScript("OnClick", function() frame:Hide() end)
    view.minimizeButton = Booty.UI.Components.CreateWindowButton(view.windowControls, nil, "minimize")
    view.minimizeButton:SetPoint("RIGHT", view.closeButton, "LEFT", -2, 0)
    view.settingsButton = Booty.UI.Components.CreateSettingsButton(view.windowControls)
    view.settingsButton:SetPoint("RIGHT", view.minimizeButton, "LEFT", -2, 0)
    Booty.UI.Components.AttachTooltip(view.settingsButton, "Settings", "Open Settings in a separate movable window.")
    view.sidebarToggle = Booty.UI.Components.CreateButton(view.titleBar, nil, "<<", 28, 20)
    Booty.UI.Components.SetClassicButtonCompact(view.sidebarToggle, true)
    view.sidebarToggle:SetPoint("LEFT", view.titleBar, "LEFT", 5, 0)
    Booty.UI.Components.AttachTooltip(view.sidebarToggle, "Navigation", "Collapse or restore the left navigation menu.")
    local navigationTooltipEnter = view.sidebarToggle:GetScript("OnEnter")
    local navigationTooltipLeave = view.sidebarToggle:GetScript("OnLeave")
    Booty.UI.Components.AttachGoldHoverBorder(view.sidebarToggle, 0.35, 0.35, 0.35, 1)
    local navigationBorderEnter = view.sidebarToggle:GetScript("OnEnter")
    local navigationBorderLeave = view.sidebarToggle:GetScript("OnLeave")
    view.sidebarToggle:SetScript("OnEnter", function()
        if navigationTooltipEnter then navigationTooltipEnter() end
        if navigationBorderEnter then navigationBorderEnter() end
    end)
    view.sidebarToggle:SetScript("OnLeave", function()
        if navigationTooltipLeave then navigationTooltipLeave() end
        if navigationBorderLeave then navigationBorderLeave() end
    end)
    view.versionText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    view.versionText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, 17); view.versionText:SetText("v" .. version)

    view.sidebar = CreateFrame("Frame", nil, frame)
    view.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -68); view.sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 20, 42); view.sidebar:SetWidth(174)
    view.sidebar:SetBackdrop({ bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    view.sidebar:SetBackdropColor(0.05, 0.04, 0.02, 0.92); view.sidebar:SetBackdropBorderColor(0.36, 0.36, 0.34, 1)
    Booty.UI.Components.RegisterSkinnedSurface(view.sidebar, "sidebar", { bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } }, { 0.05, 0.04, 0.02, 0.92 }, { 0.36, 0.36, 0.34, 1 })
    view.sidebarToggleClassicIcon = view.sidebarToggle:CreateTexture(nil, "OVERLAY")
    view.sidebarToggleClassicIcon:SetWidth(11); view.sidebarToggleClassicIcon:SetHeight(11); view.sidebarToggleClassicIcon:SetPoint("CENTER", view.sidebarToggle, "CENTER", 0, 0); view.sidebarToggleClassicIcon:Hide()
    view.classicMenuTitle = view.sidebar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    view.classicMenuTitle:SetTextColor(unpack(Booty.UI.Components.Theme.colors.goldText))
    view.sidebarToggleClassicIcon:SetVertexColor(unpack(Booty.UI.Components.Theme.colors.goldText))
    view.classicMenuTitle:SetPoint("TOPLEFT", view.sidebar, "TOPLEFT", 10, -9); view.classicMenuTitle:SetText("Menu"); view.classicMenuTitle:Hide()
    view.sidebar.classicMenuTitle = view.classicMenuTitle
    view.contentPanel = CreateFrame("Frame", nil, frame)
    view.contentPanel.bootyHeaderAnchor = view.titleBar
    view.contentPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", 204, -68); view.contentPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 46)
    view.contentPanel:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    view.contentPanel:SetBackdropColor(0.02, 0.02, 0.02, 0.90); view.contentPanel:SetBackdropBorderColor(0.36, 0.36, 0.34, 1)
    Booty.UI.Components.RegisterSkinnedSurface(view.contentPanel, "content", { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 16, edgeSize = 16, insets = { left = 4, right = 4, top = 4, bottom = 4 } }, { 0.02, 0.02, 0.02, 0.90 }, { 0.36, 0.36, 0.34, 1 })
    Booty.UI.Components.SetSurfaceHorizontalBorders(view.contentPanel)
    view.pageHost = Booty.UI.Components.CreateContainer(nil, view.contentPanel)
    view.pageHost:SetAllPoints(view.contentPanel); view.contentPanel.bootyPageHost = view.pageHost
    local background = view.sidebar:CreateTexture(nil, "BACKGROUND")
    background:SetPoint("TOPLEFT", view.sidebar, "TOPLEFT", 5, -5); background:SetPoint("BOTTOMRIGHT", view.sidebar, "BOTTOMRIGHT", -5, 5)
    background:SetTexture("Interface\\AddOns\\BootyLib\\Textures\\DashboardBackground"); background:SetTexCoord(0.22, 0.58, 0, 1); background:SetAlpha(0.72)
    local backgroundShade = view.sidebar:CreateTexture(nil, "BORDER")
    backgroundShade:SetAllPoints(view.sidebar); backgroundShade:SetTexture(0, 0, 0, 0.40)
    view.contentShade = view.contentPanel:CreateTexture(nil, "BACKGROUND")
    view.contentShade:SetPoint("TOPLEFT", view.contentPanel, "TOPLEFT", 5, -5); view.contentShade:SetPoint("BOTTOMRIGHT", view.contentPanel, "BOTTOMRIGHT", -5, 5)
    view.contentShade:SetTexture(0.025, 0.022, 0.018, 0.96)
    Booty.UI.Components.RegisterSkinCallback(function(skin)
        local classic = skin == "classic"
        if view.minimized then
            Dashboard.ApplyChrome(view, function() end)
            return
        end
        if classic and not view.minimized then view.title:Hide(); view.classicTitle:Show() else view.classicTitle:Hide(); view.title:Show() end
        Dashboard.UpdateTitleMetrics(view)
        if classic and not view.minimized then view.classicLogo:Show(); view.classicTitleLeft:Show(); view.classicTitleRight:Show(); view.classicMenuTitle:Show()
        else view.classicLogo:Hide(); view.classicTitleLeft:Hide(); view.classicTitleRight:Hide(); view.classicMenuTitle:Hide() end
        view.titleBar:ClearAllPoints()
        if classic then view.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -8); view.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -8); view.titleBar:SetHeight(44)
        else view.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 9, -14); view.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -9, -14); view.titleBar:SetHeight(32) end
        local margin = classic and 4 or 9
        local sectionGap = classic and 4 or 6
        local sectionTop = -(classic and 52 or 46) - sectionGap
        local footerBottom = margin
        local sectionBottom = footerBottom + 22 + sectionGap
        view.sidebar:ClearAllPoints()
        view.sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", margin, sectionTop)
        view.sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", margin, sectionBottom)
        view.contentPanel:ClearAllPoints()
        view.contentPanel:SetPoint("TOPLEFT", frame, "TOPLEFT", classic and 153 or 184, sectionTop)
        view.contentPanel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -margin, sectionBottom)
        view.versionText:ClearAllPoints()
        view.versionText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -32, footerBottom + 5)
        if frame.bootyStatusBar then
            frame.bootyStatusBar:ClearAllPoints()
            frame.bootyStatusBar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", margin, footerBottom)
            frame.bootyStatusBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -126, footerBottom)
        end
        background:SetAlpha(classic and 0 or 0.72); backgroundShade:SetAlpha(classic and 0 or 1); view.contentShade:SetAlpha(classic and 0 or 1)
        if classic then
            view.sidebarToggle:SetParent(view.sidebar); view.sidebarToggle:ClearAllPoints(); view.sidebarToggle:SetPoint("TOPRIGHT", view.sidebar, "TOPRIGHT", -7, -7); view.sidebarToggle:SetWidth(18); view.sidebarToggle:SetHeight(18)
            view.sidebarToggle.label:SetText(""); view.sidebarToggleClassicIcon:Show()
        else
            view.sidebarToggle:SetParent(view.titleBar); view.sidebarToggle:ClearAllPoints(); view.sidebarToggle:SetPoint("LEFT", view.titleBar, "LEFT", 5, 0); view.sidebarToggle:SetWidth(28); view.sidebarToggle:SetHeight(20)
            view.sidebarToggleClassicIcon:Hide()
        end
    end)
    if Booty.UI.Components.WindowStack then Booty.UI.Components.WindowStack.Register(frame, {owner = false}) end
    return view
end

function Dashboard.CreateStatusBar(parent)
    local bar = CreateFrame("Frame", nil, parent)
    parent.bootyStatusBar = bar
    local margin = Booty.UI.Components.IsClassicSkin() and 4 or 9
    bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", margin, margin)
    bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -126, margin)
    bar:SetHeight(22)
    bar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bar:SetBackdropColor(0.025, 0.022, 0.018, 0.94)
    bar:SetBackdropBorderColor(0.30, 0.30, 0.28, 1)
    Booty.UI.Components.RegisterSkinnedSurface(bar, "status", { bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } }, { 0.025, 0.022, 0.018, 0.94 }, { 0.30, 0.30, 0.28, 1 })
    Booty.UI.Components.SetSurfaceHorizontalBorders(bar, true, false, true)
    bar.message = bar:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    bar.message:SetPoint("LEFT", bar, "LEFT", 8, 0)
    bar.message:SetWidth(270)
    bar.message:SetJustifyH("LEFT")
    return bar
end

function Dashboard.SetStatus(bar, message, kind)
    if not bar or not bar.message then return end
    bar.message:SetText(message or "Ready")
    if kind == "error" then bar.message:SetTextColor(1, 0.35, 0.25)
    elseif kind == "success" then bar.message:SetTextColor(0.45, 1, 0.45)
    else bar.message:SetTextColor(0.72, 0.72, 0.68) end
end

function Dashboard.CreatePages(contentPanel, definitions)
    local ownerPanel = contentPanel
    contentPanel = contentPanel.bootyPageHost or contentPanel
    local pages = {}
    local index
    for index = 1, table.getn(definitions) do
        local definition = definitions[index]
        local page = CreateFrame("Frame", nil, contentPanel)
        page.bootyContentPanel = ownerPanel
        if definition.anchor then page:SetAllPoints(pages[definition.anchor])

        else
            page:SetPoint("TOPLEFT", contentPanel, "TOPLEFT", 1.5, -3)
            page:SetPoint("BOTTOMRIGHT", contentPanel, "BOTTOMRIGHT", -1.5, 1.5)
        end
        if definition.hidden then page:Hide() end
        pages[definition.key] = page
    end
    return pages
end

function Dashboard.RestoreGeometry(frame, settings)
    if frame.bootyDashboardView then frame.bootyDashboardView.geometrySettings = settings end
    local width, height = tonumber(settings.windowWidth), tonumber(settings.windowHeight)
    if not width or width < 350 or not height or height < 380 then
        width, height = 840, 540
        settings.windowLeft = nil; settings.windowBottom = nil
    end
    width = math.max(350, math.min(1100, width)); height = math.max(380, math.min(760, height))
    settings.windowWidth = width; settings.windowHeight = height
    if frame.SetUserPlaced then frame:SetUserPlaced(false) end
    frame:SetScale(1); frame:SetMaxResize(1100, 760); frame:SetMinResize(350, 380)
    frame:SetWidth(width); frame:SetHeight(height)
    if tonumber(settings.windowLeft) and tonumber(settings.windowBottom) then
        frame:ClearAllPoints(); frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", tonumber(settings.windowLeft), tonumber(settings.windowBottom))
    else
        frame:ClearAllPoints(); frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    end
end

function Dashboard.OpenWindow(view)
    -- Opening an entry point must never act as a close toggle. Show the owner
    -- before restoring so its native compact bounds are available again.
    view.frame:Show()
    if view.minimized and view.ToggleMinimize then view.ToggleMinimize(true) end
end

function Dashboard.ToggleWindow(view)
    if view.frame:IsVisible() and not view.minimized then
        view.frame:Hide()
    else
        Dashboard.OpenWindow(view)
    end
end

function Dashboard.BindWindow(view, options)
    local frame, grip = view.frame, view.resizeGrip
    -- Anchored child bounds can still describe the 250x30 shell during Show.
    -- Reuse one finalizer and detach it after the next rendered frame.
    local finalizer = CreateFrame("Frame", nil, frame)
    finalizer:EnableMouse(false); finalizer:Hide()
    view.restoreLayoutFinalizer = finalizer
    local function CancelRestoreLayout()
        finalizer:SetScript("OnUpdate", nil); finalizer:Hide()
    end
    local function FinishRestoreLayout()
        CancelRestoreLayout()
        if frame:IsVisible() and not view.minimized and not options.isLootMasterMode() then options.applyOrRefreshLayout() end
    end
    finalizer:SetScript("OnHide", function() finalizer:SetScript("OnUpdate", nil) end)
    -- Native layout-cache is loaded after VARIABLES_LOADED and can contain the
    -- 250x30 minimized shell. SavedVariables alone own durable geometry.
    frame:RegisterEvent("PLAYER_LOGIN")
    frame:SetScript("OnEvent", function()
        if event ~= "PLAYER_LOGIN" then return end
        frame:UnregisterEvent("PLAYER_LOGIN")
        Dashboard.RestoreGeometry(frame, view.geometrySettings or {})
        options.applyOrRefreshLayout()
    end)
    frame.bootyDashboardView = view
    grip.UpdateLayout = function()
        this.layoutElapsed = this.layoutElapsed + arg1
        if this.layoutElapsed >= 0.08 then
            this.layoutElapsed = 0
            if options.isLootMasterMode() then options.refreshLayout()
            elseif options.isTabLayout() then options.applyLayout()
            else options.refreshLayout() end
        end
    end
    frame:SetScript("OnDragStart", function() this:StartMoving() end)
    frame:SetScript("OnDragStop", function()
        this:StopMovingOrSizing()
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
        if view.minimized then
            view.minimizedLeft, view.minimizedBottom = frame:GetLeft(), frame:GetBottom()
        elseif options.isLootMasterMode() then options.saveLootGeometry() else options.saveGeometry() end
    end)
    grip:SetScript("OnMouseDown", function()
        frame:StartSizing("BOTTOMRIGHT")
        this.layoutElapsed = 0
        this:SetScript("OnUpdate", this.UpdateLayout)
    end)
    grip:SetScript("OnMouseUp", function()
        frame:StopMovingOrSizing(); this:SetScript("OnUpdate", nil)
        if frame.SetUserPlaced then frame:SetUserPlaced(false) end
        if view.minimized then
            view.minimizedLeft, view.minimizedBottom = frame:GetLeft(), frame:GetBottom()
        elseif options.isLootMasterMode() then options.saveLootGeometry() else options.saveGeometry() end
        if options.isLootMasterMode() then options.refreshLayout() else options.applyOrRefreshLayout() end
    end)
    grip:SetScript("OnHide", function() frame:StopMovingOrSizing(); this:SetScript("OnUpdate", nil) end)

    view.ToggleMinimize = function(restoreOnly)
        if options.isLootMasterMode() and not (restoreOnly == true and view.minimized) then return end
        CancelRestoreLayout()
        if view.minimized then
            view.minimizedLeft, view.minimizedBottom = frame:GetLeft(), frame:GetBottom()
            view.minimized = false; frame.bootyMinimized = false
            frame:SetBackdrop(frame.bootyWindowBackdrop); frame:SetBackdropColor(0.02,0.02,0.02,0.98); frame:SetBackdropBorderColor(0.68,0.54,0.27,1)
            Booty.UI.Components.SetSurfaceTransparent(view.titleBar, false)
            Dashboard.SetTabBody(view, false)
            frame:SetMinResize(350, 380); frame:SetMaxResize(1100, 760)
            frame:SetWidth(view.widthBeforeMinimize or 840); frame:SetHeight(view.heightBeforeMinimize or 540)
            frame:ClearAllPoints()
            if view.leftBeforeMinimize and view.bottomBeforeMinimize then frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", view.leftBeforeMinimize, view.bottomBeforeMinimize) else frame:SetPoint("CENTER", UIParent, "CENTER", 0, 10) end
            view.title:ClearAllPoints(); view.title:SetPoint("CENTER", view.titleBar, "CENTER", 0, 2)
            view.title:SetFontObject(GameFontNormalLarge)
            view.title:SetTextColor(unpack(Booty.UI.Components.Theme.colors.goldText))
            Booty.UI.Components.SetWindowButtonAction(view.minimizeButton, "minimize"); view.title:SetText(view.titleText or "Booty Suite")
            view.classicTitle:ClearAllPoints(); view.classicTitle:SetPoint("CENTER", view.titleBar, "CENTER", 0, 1); Dashboard.UpdateTitleMetrics(view)
            if Booty.UI.Components.IsClassicSkin() then
                view.title:Hide(); view.classicTitle:Show(); view.classicLogo:Show(); view.classicTitleLeft:Show(); view.classicTitleRight:Show()
                view.titleBar:ClearAllPoints(); view.titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8); view.titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8); view.titleBar:SetHeight(44)
            end
            view.sidebar:Show(); options.statusBar:Show(); view.versionText:Show(); view.resizeGrip:Show(); view.sidebarToggle:Show()
            if options.setNavigationVisible then options.setNavigationVisible(true) end
            -- Restore owners and anchors before descendant OnShow handlers run;
            -- chrome also reapplies hidden sidebar/footer preferences.
            options.applyOrRefreshLayout()
            view.contentPanel:Show()
            finalizer:SetScript("OnUpdate", FinishRestoreLayout); finalizer:Show()
        else
            view.widthBeforeMinimize = frame:GetWidth(); view.heightBeforeMinimize = frame:GetHeight(); view.leftBeforeMinimize = frame:GetLeft(); view.bottomBeforeMinimize = frame:GetBottom()
            options.saveGeometry()
            Dashboard.SetTabBody(view, false)
            view.titleBar:Show(); Dashboard.PlaceWindowControls(view, false)
            view.minimized = true; frame.bootyMinimized = true
            view.sidebar:Hide(); view.contentPanel:Hide(); options.statusBar:Hide(); view.versionText:Hide(); view.resizeGrip:Hide(); view.sidebarToggle:Hide()
            if options.setNavigationVisible then options.setNavigationVisible(false) end
            local minimizedHeight = Booty.UI.Components.MinimizedWindowHeight or 30
            frame:SetMinResize(250, minimizedHeight); frame:SetMaxResize(250, minimizedHeight); frame:SetWidth(250); frame:SetHeight(minimizedHeight)
            frame:ClearAllPoints()
            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", view.minimizedLeft or view.leftBeforeMinimize or 0, view.minimizedBottom or ((view.bottomBeforeMinimize or 0) + view.heightBeforeMinimize - minimizedHeight))
            Booty.UI.Components.SetWindowButtonAction(view.minimizeButton, "maximize")
            Dashboard.ApplyMinimizedChrome(view)
        end
    end
    view.minimizeButton:SetScript("OnClick", view.ToggleMinimize)
end

function Dashboard.ResolveMinimapPosition(x, y, width, height)
    x, y = tonumber(x), tonumber(y)
    if not x or not y or x ~= x or y ~= y or math.abs(x) > 1e300 or math.abs(y) > 1e300 then return nil end
    return math.max(16, math.min(math.max(16, width - 16), x)), math.max(16, math.min(math.max(16, height - 16), y))
end

function Dashboard.CreateMinimapButton(options)
    local UI = Booty.UI.Components
    local button = Booty.UI.Components.CreateControl(options.name or "BootyLibMinimapButton", UIParent)
    button:SetWidth(32); button:SetHeight(32); button:SetFrameStrata("MEDIUM"); button:SetFrameLevel(8)
    button:SetMovable(true)
    if button.SetClampedToScreen then button:SetClampedToScreen(true) end
    if button.SetUserPlaced then button:SetUserPlaced(false) end
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp"); button:RegisterForDrag("LeftButton")
    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetWidth(20); icon:SetHeight(20); icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    icon:SetTexture(options.iconTexture or "Interface\\AddOns\\BootyLib\\Textures\\MinimapIcon")
    icon:SetTexCoord(0, 1, 0, 1)
    button.icon = icon
    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetWidth(52); border:SetHeight(52); border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    button.border = border

    button.Position = function()
        options.ensureDatabase()
        if button.SetUserPlaced then button:SetUserPlaced(false) end
        local x, y
        if options.getPosition then x, y = options.getPosition() end
        local width, height = UI.GetFrameSpan(UIParent)
        x, y = Dashboard.ResolveMinimapPosition(x, y, width, height)
        button:ClearAllPoints()
        if x then button:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
        else
            local radians = math.rad(options.getAngle and options.getAngle() or 220)
            button:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(radians), 80 * math.sin(radians))
        end
    end
    local function FinishDrag()
        if not button.dragging then return end
        button.dragging = false; button:StopMovingOrSizing()
        if button.SetUserPlaced then button:SetUserPlaced(false) end
        local x, y
        if button.GetCenter then x, y = button:GetCenter() end
        local width, height = UI.GetFrameSpan(UIParent)
        x, y = Dashboard.ResolveMinimapPosition(x, y, width, height)
        if x and options.setPosition then options.setPosition(x, y); button.Position() end
    end
    button:SetScript("OnClick", function()
        if arg1 == "RightButton" then
            if options.onContextMenu then options.onContextMenu(button)
            elseif options.onClick then options.onClick() end
        elseif options.onOpen then options.onOpen(button)
        elseif options.onClick then options.onClick() end
    end)
    local orange = UI.TextColors.orange
    local prefix = string.format("|cff%02x%02x%02x", math.floor(orange[1] * 255), math.floor(orange[2] * 255), math.floor(orange[3] * 255))
    local leftHint = prefix .. "Left click:|r |cffffffffopen or close the dashboard|r"
    local rightHint = prefix .. "Right click:|r |cffffffffquick menu|r"
    local dragHint = prefix .. "Shift + left drag:|r |cffffffffmove anywhere on screen|r"
    button:SetScript("OnEnter", function()
        Booty.UI.Components.AnchorTooltipRightOfCursor(this)
        GameTooltip:AddLine(options.title or "Booty Suite", unpack(UI.Theme.colors.goldText))
        GameTooltip:AddLine(leftHint, 1, 1, 1)
        GameTooltip:AddLine(rightHint, 1, 1, 1)
        GameTooltip:AddLine(dragHint, 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:SetScript("OnDragStart", function()
        if type(IsShiftKeyDown) ~= "function" or not IsShiftKeyDown() then return end
        button.dragging = true; button:StartMoving()
    end)
    button:SetScript("OnDragStop", FinishDrag)
    button:SetScript("OnHide", FinishDrag)
    return button
end
