local Booty = BootyLib
Booty.UI = Booty.UI or {}
Booty.UI.Components = Booty.UI.Components or {}
local Components = Booty.UI.Components

-- A sibling control must receive the same click that dismisses a popup.
-- The lower outside catcher cannot see clicks already handled by that control.
function Components.DismissDropdownForControl(control)
    local panel = Components.openDropdownPanel
    if not panel or control == panel.toggle then return end
    local ancestor = control
    while ancestor do
        if ancestor == panel or ancestor.bootyDropdownRoot == panel then return end
        ancestor = ancestor.GetParent and ancestor:GetParent()
    end
    panel:Hide()
end

local function ControlMouseDown()
    Components.DismissDropdownForControl(this)
    if Components.WindowStack then Components.WindowStack.FocusFrom(this) end
end

local function WrapControlMouseDown(handler)
    -- Capture this specific handler. A later hook can safely call GetScript's
    -- previous callback without recursing through a mutable owner field.
    return function()
        Components.DismissDropdownForControl(this)
        if Components.WindowStack then Components.WindowStack.FocusFrom(this) end
        handler()
    end
end

function Components.InstallControlInput(control)
    if control.bootyInputInstalled then return control end
    control.bootyInputInstalled = true
    local setScript = control.SetScript
    control.bootyMouseDownHandler = control:GetScript("OnMouseDown")
    control.SetScript = function(self, eventName, handler)
        if eventName == "OnMouseDown" then
            self.bootyMouseDownHandler = handler
            setScript(self, eventName, handler and WrapControlMouseDown(handler) or ControlMouseDown)
        else setScript(self, eventName, handler) end
    end
    setScript(control, "OnMouseDown", control.bootyMouseDownHandler and WrapControlMouseDown(control.bootyMouseDownHandler) or ControlMouseDown)
    return control
end

-- Stock 1.12 sizes an unconstrained FontString through GetHeight (as in
-- Blizzard's StaticPopup_Resize). GetStringHeight is an optional backport.
-- Reuse one native measuring label for fixed-height/anchored source labels;
-- callers pass their resolved width, so stale child geometry is never a gutter.
local textHeightProbe
local probeFont, probeSize, probeFlags, probeSpacing, probeNonSpaceWrap
function Components.MeasureTextHeight(label, resolvedWidth, nonSpaceWrap)
    if resolvedWidth then resolvedWidth = math.max(1, resolvedWidth - (label.bootyHeadingIconInset or 0)) end
    if resolvedWidth then label.bootyTextMeasureWidth = math.max(1, resolvedWidth) end
    if type(label.GetStringHeight) == "function" then return label:GetStringHeight() or 0 end
    local text = label:GetText()
    if not text or text == "" then return 0 end
    if not textHeightProbe then
        textHeightProbe = Components.CreateLabel(UIParent, nil, "ARTWORK", "GameFontHighlightSmall")
        textHeightProbe:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 0, 0)
        textHeightProbe:SetHeight(0); textHeightProbe:SetAlpha(0)
        textHeightProbe:SetJustifyH("LEFT"); textHeightProbe:SetJustifyV("TOP")
    end
    local font, size, flags = label:GetFont()
    if font ~= probeFont or size ~= probeSize or flags ~= probeFlags then
        textHeightProbe:SetFont(font, size, flags)
        probeFont, probeSize, probeFlags = font, size, flags
    end
    local spacing = type(label.GetSpacing) == "function" and label:GetSpacing() or 0
    if spacing ~= probeSpacing and type(textHeightProbe.SetSpacing) == "function" then
        textHeightProbe:SetSpacing(spacing); probeSpacing = spacing
    end
    if type(label.CanNonSpaceWrap) == "function" then nonSpaceWrap = label:CanNonSpaceWrap() end
    nonSpaceWrap = nonSpaceWrap and true or false
    if nonSpaceWrap ~= probeNonSpaceWrap and type(textHeightProbe.SetNonSpaceWrap) == "function" then
        textHeightProbe:SetNonSpaceWrap(nonSpaceWrap); probeNonSpaceWrap = nonSpaceWrap
    end
    textHeightProbe:SetWidth(label.bootyTextMeasureWidth or math.max(1, label:GetWidth()))
    textHeightProbe:SetText(text)
    local height = textHeightProbe:GetHeight() or 0
    textHeightProbe:SetText("") -- Do not keep transient dialog text after measuring it.
    return height
end

-- Native construction is confined to this package. Feature modules compose
-- instances and attach domain callbacks; factories never reach into a module.
local function TrackFrame(frame)
    return Components.WindowStack and Components.WindowStack.Track(frame) or frame
end
function Components.CreateContainer(name, parent, template)
    return TrackFrame(CreateFrame("Frame", name, parent, template))
end

function Components.CreateModel(name, parent, template)
    return TrackFrame(CreateFrame("Model", name, parent, template))
end

function Components.CreateTooltip(name, parent, template)
    return TrackFrame(CreateFrame("GameTooltip", name, parent, template or "GameTooltipTemplate"))
end

function Components.CreateControl(name, parent, template)
    return Components.InstallControlInput(TrackFrame(CreateFrame("Button", name, parent, template)))
end

function Components.CreateCheckButton(name, parent, template)
    return Components.InstallControlInput(TrackFrame(CreateFrame("CheckButton", name, parent, template)))
end

function Components.CreateScrollFrame(name, parent, template)
    return TrackFrame(CreateFrame("ScrollFrame", name, parent, template))
end

function Components.CreateMessageFrame(name, parent, template)
    return TrackFrame(CreateFrame("ScrollingMessageFrame", name, parent, template))
end

function Components.CreateSliderFrame(name, parent, template)
    return TrackFrame(CreateFrame("Slider", name, parent, template))
end

function Components.CreateEditField(name, parent, template)
    return TrackFrame(CreateFrame("EditBox", name, parent, template))
end

function Components.CreateStatusFrame(name, parent, template)
    return TrackFrame(CreateFrame("StatusBar", name, parent, template))
end

function Components.CreateLabel(parent, name, layer, template)
    return parent:CreateFontString(name, layer, template)
end

function Components.CreateTexture(parent, name, layer, template)
    return parent:CreateTexture(name, layer, template)
end
