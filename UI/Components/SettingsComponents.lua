local Booty = BootyLib

Booty.UI.Components.Settings = Booty.UI.Components.Settings or {}
local Settings = Booty.UI.Components.Settings

function Settings.CreateSection(parent, title, y)
    local heading = Booty.UI.Components.CreateHeading(parent, "", 2, "orange", "settings")
    heading:SetPoint("TOPLEFT", parent, "TOPLEFT", 12, y)
    heading:SetText(title)
    local rule = parent:CreateTexture(nil, "ARTWORK")
    rule:SetPoint("LEFT", heading, "RIGHT", 10, 0)
    rule:SetPoint("RIGHT", parent, "RIGHT", -12, 0)
    rule:SetHeight(1)
    rule:SetTexture(0.55, 0.42, 0.16, 0.75)
    return heading, rule
end

function Settings.CreateAccordion(parent, text, y, iconKey)
    local button = Booty.UI.Components.CreateControl(nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 24, y)
    button:SetWidth(180)
    button:SetHeight(16)
    button:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    button:SetBackdropColor(0, 0, 0, 0)
    button:SetBackdropBorderColor(0, 0, 0, 0)
    button.label = Booty.UI.Components.CreateHeading(button, "", 3, "orange")
    button.indicator = Booty.UI.Components.CreateHeading(button, "+", 3, "orange")
    button.indicator:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.indicator:SetJustifyH("LEFT"); button.indicator:SetJustifyV("MIDDLE")
    local function FitIndicator()
        -- Native FontStrings replace a clipped single glyph with dots. Measure
        -- both states without a width constraint, then keep one padded gutter.
        local indicator, current = button.indicator, button.indicator:GetText()
        indicator:SetWidth(0)
        indicator:SetText("+"); local plus = indicator:GetStringWidth()
        indicator:SetText("-"); local minus = indicator:GetStringWidth()
        local width = math.ceil(math.max(plus, minus)) + 2
        indicator:SetText(current); indicator:SetWidth(width)
        button.label.bootyAccordionPrefixInset = width + 4
        button.label:ClearAllPoints(); button.label:SetPoint("LEFT", button, "LEFT", width + 4, 0)
        if button.RefreshRule then button:RefreshRule() end
    end
    button.baseText = text
    -- Nested Settings accordions intentionally have no icon gutter.
    local setText, setFont, setColor = button.label.SetText, button.label.SetFont, button.label.SetTextColor
    button.label.SetText = function(self, value)
        local sign = string.sub(value or "", 1, 1)
        button.indicator:SetText((sign == "+" or sign == "-") and sign or "")
        setText(self, string.gsub(value or "", "^[%+%-]%s+", ""))
    end
    button.label.SetFont = function(self, path, size, flags)
        setFont(self, path, size, flags); button.indicator:SetFont(path, size, flags); FitIndicator()
    end
    button.label.SetTextColor = function(self, red, green, blue, alpha)
        setColor(self, red, green, blue, alpha); button.indicator:SetTextColor(red, green, blue, alpha)
    end
    button.label:SetText("+  " .. text)
    FitIndicator()
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    -- Section decoration belongs to the heading, so collapsed feature groups
    -- cannot leave their rules visible in the shared scroll child.
    button.rule = button:CreateTexture(nil, "ARTWORK")
    button.rule:SetTexture(0, 0, 0, 0)
    button.rule:Hide()
    return button
end

function Settings.CreateSectionAccordion(parent, text, y, inset, headingLevel, iconKey)
    if (inset or 0) > 0 then
        local child = Settings.CreateAccordion(parent, text, y, false)
        child.bootySectionInset = inset
        child.SetExpanded = function(self, expanded) self.sectionExpanded = expanded end
        child:ClearAllPoints(); child:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, y); child:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
        child:SetExpanded(false)
        return child
    end
    local button = Settings.CreateAccordion(parent, text, y, false)
    button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    button:SetHeight(20)
    button.label:SetTextColor(unpack(Booty.UI.Components.TextColors.gold))
    button:SetHighlightTexture(nil)
    button.sectionFill = button:CreateTexture(nil, "BACKGROUND")
    button.sectionFill:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.sectionFill:SetGradientAlpha("HORIZONTAL", 0.82, 0.70, 0.43, 0, 0.82, 0.70, 0.43, 0.24)
    button.sectionFill:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0); button.sectionFill:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 0, 0)
    button.sectionFade = button:CreateTexture(nil, "BACKGROUND")
    button.sectionFade:SetTexture("Interface\\Buttons\\WHITE8X8")
    button.sectionFade:SetGradientAlpha("HORIZONTAL", 0.82, 0.70, 0.43, 0.24, 0.82, 0.70, 0.43, 0)
    button.sectionFade:SetPoint("TOPLEFT", button.sectionFill, "TOPRIGHT", 0, 0); button.sectionFade:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
    button.ruleCap = button:CreateTexture(nil, "ARTWORK")
    local ornament = Booty.UI.Components.ClassicAsset("Decor\\title-right.tga")
    button.rule:SetTexture(ornament); button.rule:SetTexCoord(5/128, 100/128, 0, 1)
    button.ruleCap:SetTexture(ornament); button.ruleCap:SetTexCoord(100/128, 1, 0, 1)
    button.rule:SetVertexColor(1, 1, 1, 1); button.ruleCap:SetVertexColor(1, 1, 1, 1)
    button.ruleCap:SetPoint("RIGHT", button, "RIGHT", 0, 0); button.ruleCap:SetWidth(14); button.ruleCap:SetHeight(8)
    local ruleShow, ruleHide = button.rule.Show, button.rule.Hide
    button.rule.Show = function(self) ruleShow(self); button.ruleCap:Show() end
    button.rule.Hide = function(self) ruleHide(self); button.ruleCap:Hide() end
    button.RefreshRule = function(self)
        -- A FontString's anchored bounds may still describe its previous text.
        -- Measure the caption instead of anchoring a rule to that stale edge.
        local text = self.label:GetText()
        local font, size, flags = self.label:GetFont()
        local inset = (self.label.bootyAccordionPrefixInset or 0) + (self.label.bootyHeadingIconInset or 0)
        if self.bootyRuleText == text and self.bootyRuleFont == font and self.bootyRuleSize == size and self.bootyRuleFlags == flags and self.bootyRuleInset == inset then return end
        self.bootyRuleText, self.bootyRuleFont, self.bootyRuleSize, self.bootyRuleFlags, self.bootyRuleInset = text, font, size, flags, inset
        self.label:SetWidth(0)
        self.rule:ClearAllPoints()
        self.rule:SetPoint("LEFT", self, "LEFT", inset + self.label:GetStringWidth() + 10, 0)
        self.rule:SetPoint("RIGHT", self.ruleCap, "LEFT", 0, 0)
        self.rule:SetHeight(8)
    end
    button.SetExpanded = function(self, expanded)
        self.sectionExpanded = expanded
        self:RefreshRule()
        if self.sectionHovered then self.sectionFill:Show(); self.sectionFade:Show()
        else self.sectionFill:Hide(); self.sectionFade:Hide() end
    end
    button:SetScript("OnEnter", function() this.sectionHovered = true; this:SetExpanded(this.sectionExpanded) end)
    button:SetScript("OnLeave", function() this.sectionHovered = false; this:SetExpanded(this.sectionExpanded) end)
    button:SetScript("OnSizeChanged", function() this.sectionFill:SetWidth(math.min(30, math.max(1, this:GetWidth() - 1))); this:RefreshRule() end)
    button:SetScript("OnShow", function() this:RefreshRule() end)
    button.sectionFill:SetWidth(30); button:SetExpanded(false)
    local font, _, flags = button.label:GetFont()
    button.label:SetFont(font, Booty.UI.Components.HeadingSizes[headingLevel or 2] + Booty.UI.Components.GetTextSizeDelta(parent), flags)
    if Booty.UI.Components.SetHeadingIcon then Booty.UI.Components.SetHeadingIcon(button.label, iconKey or "list") end
    button.bootySectionInset = inset or 0
    button:ClearAllPoints(); button:SetPoint("TOPLEFT", parent, "TOPLEFT", button.bootySectionInset, y); button:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, y)
    button:RefreshRule()
    button.rule:Show()
    return button
end

function Settings.CreateCheckbox(parent, x, y, text, key, onChanged, binding)
    local button = Booty.UI.Components.CreateCheckButton(nil, parent, "UICheckButtonTemplate")
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local size = math.max(16, 22 + 2 * Booty.UI.Components.GetTextSizeDelta(parent))
    button:SetWidth(size)
    button:SetHeight(size)
    button.settingKey = key
    button.onChanged = onChanged
    button.label = Booty.UI.Components.CreateComponentLabel(button, "", "white")
    button.label:SetPoint("LEFT", button, "RIGHT", 2, 0)
    button.label:SetJustifyH("LEFT"); button.label:SetText(text)
    button.SaveSetting = function(owner)
        binding.ensure()
        local value = owner:GetChecked() and true or false
        if owner.invertSetting then value = not value end
        binding.set(owner.settingKey, value)
        if owner.onChanged then owner.onChanged(owner.settingKey) end
    end
    button:SetScript("OnShow", function()
        binding.ensure()
        local value = binding.get(this.settingKey)
        if this.invertSetting then value = not value end
        this:SetChecked(value and 1 or nil)
    end)
    button:SetScript("OnClick", function() this:SaveSetting() end)
    button.labelHit = Booty.UI.Components.CreateControl(nil, button)
    button.labelHit:SetPoint("LEFT", button, "RIGHT", 1, 0)
    button.labelHit:SetWidth(math.max(18, button.label:GetStringWidth() + 5))
    button.labelHit:SetHeight(size)
    button.labelHit.owner = button
    button.labelHit:SetScript("OnClick", function()
        local owner = this.owner
        if not owner:IsEnabled() or owner:IsEnabled() == 0 then return end
        owner:SetChecked(not owner:GetChecked())
        owner:SaveSetting()
    end)
    return button
end

function Settings.SetCheckboxEnabled(check, enabled)
    if enabled then check:Enable(); check.labelHit:Enable() else check:Disable(); check.labelHit:Disable() end
    check.label:SetTextColor(unpack(enabled and Booty.UI.Components.TextColors.white or Booty.UI.Components.TextColors.gray))
end

function Settings.CreateSlider(parent, name, x, y, label, key, minimum, maximum, onChanged, binding)
    local slider = CreateFrame("Slider", name, parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    slider:SetWidth(220)
    slider:SetHeight(16)
    slider:SetMinMaxValues(minimum, maximum)
    slider:SetValueStep(1)
    local delta = math.min(0, Booty.UI.Components.GetTextSizeDelta(parent) + 1)
    local _, suffix
    for _, suffix in ipairs({"Low", "High", "Text"}) do
        local text = getglobal(name .. suffix)
        local font, size, flags = text:GetFont()
        if font and size then text:SetFont(font, size + delta, flags) end
    end
    slider.settingKey = key
    slider.settingLabel = label
    slider.onChanged = onChanged
    getglobal(name .. "Low"):SetText(tostring(minimum))
    getglobal(name .. "High"):SetText(tostring(maximum))
    slider:SetScript("OnShow", function()
        binding.ensure()
        Settings.SynchronizeSlider(this, binding.get(this.settingKey))
    end)
    slider:SetScript("OnValueChanged", function()
        binding.ensure()
        local value = math.floor(this:GetValue() + 0.5)
        getglobal(this:GetName() .. "Text"):SetText(this.settingLabel .. ": " .. value)
        if this.bootySynchronizing then return end
        binding.set(this.settingKey, value)
        if this.onChanged then this.onChanged(this.settingKey) end
    end)
    return slider
end

function Settings.SynchronizeSlider(slider, value)
    getglobal(slider:GetName() .. "Text"):SetText(slider.settingLabel .. ": " .. math.floor(value + 0.5))
    slider.bootySynchronizing = true
    slider:SetValue(value)
    slider.bootySynchronizing = nil
    local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
    if thumb then thumb:SetAlpha(1); thumb:Show() end
end

function Settings.SetSliderEnabled(slider, enabled)
    if not slider then return end
    if slider.Enable and slider.Disable then
        if enabled then slider:Enable() else slider:Disable() end
    else
        slider:EnableMouse(enabled and true or false)
    end
    slider.bootyEnabled = enabled and true or false
    slider:SetAlpha(enabled and 1 or 0.42)
    local low = getglobal(slider:GetName() .. "Low")
    local high = getglobal(slider:GetName() .. "High")
    local text = getglobal(slider:GetName() .. "Text")
    local shade = enabled and 1 or 0.5
    if low then low:SetTextColor(shade, shade, shade) end
    if high then high:SetTextColor(shade, shade, shade) end
    if text then
        if enabled then text:SetTextColor(1, 0.82, 0) else text:SetTextColor(shade, shade, shade) end
    end
end

function Settings.CreateColor(parent, x, y, label, key, onChanged, binding)
    local button = Booty.UI.Components.CreateControl(nil, parent)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetWidth(176)
    button:SetHeight(20)
    button.settingKey = key
    button.onChanged = onChanged
    button.swatchBorder = CreateFrame("Frame", nil, button)
    button.swatchBorder:SetPoint("LEFT", button, "LEFT", 0, 0)
    button.swatchBorder:SetWidth(20)
    button.swatchBorder:SetHeight(20)
    button.swatchBorder:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", tile = true, tileSize = 8, edgeSize = 8, insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    button.swatchBorder:SetBackdropColor(0, 0, 0, 1)
    button.swatchBorder:SetBackdropBorderColor(0.65, 0.55, 0.32, 1)
    button.swatch = button.swatchBorder:CreateTexture(nil, "ARTWORK")
    button.swatch:SetPoint("TOPLEFT", button.swatchBorder, "TOPLEFT", 3, -3)
    button.swatch:SetPoint("BOTTOMRIGHT", button.swatchBorder, "BOTTOMRIGHT", -3, 3)
    button.label = Booty.UI.Components.CreateComponentLabel(button, "", "white")
    button.label:SetPoint("LEFT", button.swatchBorder, "RIGHT", 6, 0)
    button.label:SetJustifyH("LEFT")
    button.label:SetText(label)
    button:SetScript("OnShow", function()
        binding.ensure()
        local color = binding.get(this.settingKey)
        this.swatch:SetTexture(color[1], color[2], color[3], 1)
    end)
    button:SetScript("OnClick", function()
        binding.ensure()
        local owner = this
        local color = binding.get(owner.settingKey)
        local original = { color[1], color[2], color[3] }
        ColorPickerFrame:Hide()
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacity = nil
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = original
        ColorPickerFrame.func = function()
            local r, g, b = ColorPickerFrame:GetColorRGB()
            binding.set(owner.settingKey, { r, g, b })
            owner.swatch:SetTexture(r, g, b, 1)
            if owner.onChanged then owner.onChanged(owner.settingKey) end
        end
        ColorPickerFrame.cancelFunc = function()
            binding.set(owner.settingKey, original)
            owner.swatch:SetTexture(original[1], original[2], original[3], 1)
            if owner.onChanged then owner.onChanged(owner.settingKey) end
        end
        local pickerControls = {
            ColorPickerFrame,
            getglobal("ColorPickerOkayButton") or getglobal("ColorPickerFrameOkayButton"),
            getglobal("ColorPickerCancelButton") or getglobal("ColorPickerFrameCancelButton"),
            getglobal("DL_RedBox"),
            getglobal("DL_GreenBox"),
            getglobal("DL_BlueBox"),
        }
        local pickerIndex, snapshots = nil, {}
        for pickerIndex = 1, table.getn(pickerControls) do
            local control = pickerControls[pickerIndex]
            if control then
                snapshots[table.getn(snapshots) + 1] = {frame = control, strata = control:GetFrameStrata(),
                    level = control:GetFrameLevel(), foregroundLevel = 9999 + pickerIndex}
            end
        end
        -- The stock picker and Discord's RGB fields belong to other callers.
        -- Borrow only their drawing order, and release it on native Hide.
        for pickerIndex = 1, table.getn(snapshots) do
            local snapshot = snapshots[pickerIndex]
            snapshot.frame:SetFrameStrata("TOOLTIP"); snapshot.frame:SetFrameLevel(snapshot.foregroundLevel)
        end
        local previousHide, onHide = ColorPickerFrame:GetScript("OnHide"), nil
        local released = false
        local function Release()
            if released then return end
            released = true
            -- Decide ownership before restoring the parent: native frame-level
            -- changes may also move its children. Preserve a later caller's edits.
            for pickerIndex = 1, table.getn(snapshots) do
                local snapshot = snapshots[pickerIndex]
                snapshot.restoreStrata = snapshot.frame:GetFrameStrata() == "TOOLTIP"
                snapshot.restoreLevel = snapshot.frame:GetFrameLevel() == snapshot.foregroundLevel
            end
            for pickerIndex = 1, table.getn(snapshots) do
                local snapshot = snapshots[pickerIndex]
                if snapshot.restoreStrata then snapshot.frame:SetFrameStrata(snapshot.strata) end
                if snapshot.restoreLevel then snapshot.frame:SetFrameLevel(snapshot.level) end
            end
            if ColorPickerFrame:GetScript("OnHide") == onHide then ColorPickerFrame:SetScript("OnHide", previousHide) end
            if Settings.colorPickerRelease == Release then Settings.colorPickerRelease = nil end
            Settings.colorPickerDismiss:Hide()
        end
        onHide = function() Release(); if previousHide then previousHide() end end
        ColorPickerFrame:SetScript("OnHide", onHide)
        Settings.colorPickerRelease = Release
        ColorPickerFrame:SetColorRGB(color[1], color[2], color[3])
        if not Settings.colorPickerDismiss then
            local dismiss = CreateFrame("Button", nil, UIParent)
            dismiss:SetAllPoints(UIParent)
            dismiss:SetFrameStrata("FULLSCREEN")
            dismiss:SetFrameLevel(1)
            dismiss:EnableMouse(true)
            dismiss:SetScript("OnClick", function()
                local release = Settings.colorPickerRelease
                ColorPickerFrame:Hide(); if release then release() end
            end)
            Settings.colorPickerDismiss = dismiss
        end
        Settings.colorPickerDismiss:Show()
        ColorPickerFrame:Show()
        if ColorPickerFrame.Raise then ColorPickerFrame:Raise() end
        for pickerIndex = 1, table.getn(snapshots) do
            snapshots[pickerIndex].foregroundLevel = snapshots[pickerIndex].frame:GetFrameLevel()
        end
    end)
    return button
end

function Settings.CreateSavedCheckbox(parent, name, x, y, text, settingKey, tooltipTitle, tooltipText, onChanged, binding)
    local check = Booty.UI.Components.CreateCheckButton(name, parent, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    local size = math.max(16, 24 + 2 * Booty.UI.Components.GetTextSizeDelta(parent))
    check:SetWidth(size)
    check:SetHeight(size)
    check.settingKey = settingKey
    check.label = Booty.UI.Components.CreateComponentLabel(check, "", "white")
    check.label:SetPoint("LEFT", check, "RIGHT", 4, 0)
    check.label:SetJustifyH("LEFT"); check.label:SetText(text)
    check:SetScript("OnShow", function()
        binding.ensure()
        local value = binding.get(this.settingKey)
        if this.invertSetting then value = not value end
        this:SetChecked(value and 1 or nil)
    end)
    check.SaveSetting = function(owner)
        binding.ensure()
        local value = owner:GetChecked() and true or false
        if owner.invertSetting then value = not value end
        binding.set(owner.settingKey, value)
        if onChanged then onChanged(owner.settingKey) end
    end
    check:SetScript("OnClick", function() this:SaveSetting() end)
    check.labelHit = Booty.UI.Components.CreateControl(nil, check)
    check.labelHit:SetPoint("LEFT", check, "RIGHT", 2, 0)
    check.labelHit:SetWidth(math.max(18, check.label:GetStringWidth() + 8))
    check.labelHit:SetHeight(size)
    check.labelHit.owner = check
    check.labelHit:SetScript("OnClick", function()
        local owner = this.owner
        owner:SetChecked(not owner:GetChecked())
        owner:SaveSetting()
    end)
    if tooltipTitle then
        Booty.UI.Components.AttachTooltip(check, tooltipTitle, tooltipText)
        Booty.UI.Components.AttachTooltip(check.labelHit, tooltipTitle, tooltipText)
    end
    return check
end

function Settings.CreatePercentageField(parent, name, labelText, x, y, settingKey, fallback, binding)
    local labelOwner = Booty.UI.Components.CreateContainer(nil, parent)
    labelOwner:SetAllPoints(parent); labelOwner:SetFrameLevel(parent:GetFrameLevel() + 2)
    local label = Booty.UI.Components.CreateComponentLabel(labelOwner, name .. "Label", "white")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetText(labelText)
    label:SetTextColor(1, 1, 1, 1); label:SetAlpha(1)
    local field = Booty.UI.Components.CreateEditField(name, parent, "InputBoxTemplate")
    Booty.UI.Components.ApplyTextSizeDelta(field, parent)
    field:SetWidth(34)
    field:SetHeight(18)
    field:SetPoint("LEFT", label, "RIGHT", 8, 0)
    field:SetAutoFocus(false)
    field:SetMaxLetters(3)
    field.settingKey = settingKey
    field.fallback = fallback
    field:SetScript("OnEditFocusGained", function() this.bootyEditing = true end)
    field:SetScript("OnEnterPressed", function() this:ClearFocus() end)
    field:SetScript("OnEscapePressed", function() this:ClearFocus() end)
    field.CommitValue = function(owner)
        binding.ensure()
        local value = math.max(0, math.min(100, tonumber(owner:GetText()) or owner.fallback))
        binding.set(owner.settingKey, value)
        owner.bootySettingText = true; owner:SetText(value); owner.bootySettingText = nil
        if owner.onChanged then owner.onChanged(owner.settingKey) end
    end
    field:SetScript("OnTextChanged", function()
        if this.bootySettingText or not this.bootyEditing then return end
        local value = tonumber(this:GetText())
        if not value then return end
        value = math.max(0, math.min(100, value))
        if binding.get(this.settingKey) == value then return end
        binding.set(this.settingKey, value)
        if this.onChanged then this.onChanged(this.settingKey) end
    end)
    field:SetScript("OnEditFocusLost", function() this:CommitValue(); this.bootyEditing = nil end)
    return label, field
end

local function ClearTextFocus(field)
    if field.bootyClearingFocus or field.bootyCommitting then return end
    field.bootyClearingFocus = true
    local previousThis, previousEvent, previousArg = this, event, arg1
    this = field
    local ok, failure = pcall(field.ClearFocus, field)
    field.bootyClearingFocus = nil
    this, event, arg1 = previousThis, previousEvent, previousArg
    if not ok then error(failure, 0) end
end

function Settings.SetTextFieldEnabled(field, enabled)
    enabled = enabled and enabled ~= 0 and true or false
    field.bootyEnabled = enabled
    field:EnableMouse(enabled); field:EnableKeyboard(enabled)
    field:SetAlpha(enabled and 1 or 0.42)
    -- EditBox has Frame input gates, not Button Enable/Disable. ClearFocus
    -- delivers the existing save-on-focus-lost policy while it still owns focus.
    if not enabled and field.bootyEditing then ClearTextFocus(field) end
end

local function WriteSavedText(field, binding)
    binding.set(field.settingKey, string.gsub(field:GetText() or "", "[%c]", " "))
end

function Settings.CreateSavedTextField(parent, settingKey, binding)
    local field = Booty.UI.Components.CreateFramedEditBox(parent, nil, 300)
    field.settingKey = settingKey; field:SetMaxLetters(512)
    field.CommitValue = function(self)
        if not self.bootyEditing or self.bootyCommitting then return end
        self.bootyCommitting = true
        local previousThis, previousEvent, previousArg = this, event, arg1
        this = self
        local ok, failure = pcall(WriteSavedText, self, binding)
        self.bootyCommitting = nil
        this, event, arg1 = previousThis, previousEvent, previousArg
        if not ok then error(failure, 0) end
        self.bootyEditing = nil
    end
    field.RefreshValue = function(self)
        if not self.bootyEditing then self:SetText(binding.get(self.settingKey) or "") end
    end
    field:SetScript("OnShow", function() this:RefreshValue() end)
    field:SetScript("OnEditFocusGained", function()
        if this.bootyEnabled == false then ClearTextFocus(this)
        else this.bootyEditing = true end
    end)
    field:SetScript("OnEditFocusLost", function() this:CommitValue() end)
    field:SetScript("OnEnterPressed", function() this:CommitValue(); ClearTextFocus(this) end)
    field:SetScript("OnEscapePressed", function() this.bootyEditing = nil; this:RefreshValue(); ClearTextFocus(this) end)
    field:SetScript("OnHide", function() this:CommitValue(); ClearTextFocus(this) end)
    return field
end

function Settings.OnViewportSizeChanged()
    local page = this.settingsPage
    if page then Settings.UpdateScroll(this, page, page.settingsContentHeight or 960) end
end

local function MeasureSettingsWidth(width, page)
    local changed = math.abs(page:GetWidth() - width) > 0.5
    page:SetWidth(width)
    if changed and page.ReflowSettings then page.ReflowSettings() end
    return page.settingsContentHeight or page.bootyRequestedHeight or 960
end

local function UpdateSettingsScroll(viewport, page, pageHeight)
    local UI = Booty.UI.Components
    local fullWidth, height = UI.GetFrameSpan(viewport)
    local anchor = viewport.bootyScrollAnchor
    if viewport.bootyWidthOwner and viewport.bootyWidthInset then
        fullWidth = viewport.bootyWidthOwner:GetWidth() - viewport.bootyWidthInset
    else
        fullWidth = fullWidth + (viewport.bootyScrollGutter or 0)
    end
    if viewport.bootyHeightOwner and viewport.bootyHeightInset then
        height = viewport.bootyHeightOwner:GetHeight() - viewport.bootyHeightInset

    end
    page.bootyRequestedHeight = pageHeight
    local width, contentHeight, overflow, maximum = UI.ResolveScrollLayout(fullWidth, height, 20, MeasureSettingsWidth, page)
    if anchor then
        viewport:ClearAllPoints(); viewport:SetPoint("TOPLEFT", anchor, "TOPLEFT", 4, -(viewport.bootyScrollTop or 4))
        viewport:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", overflow and -24 or -4, 4)
    end
    page:SetHeight(contentHeight)
    viewport.bootyScrollGutter = overflow and 20 or 0
    if viewport.UpdateScrollChildRect then viewport:UpdateScrollChildRect() end
    UI.ApplyScrollRange(viewport, getglobal(viewport:GetName() .. "ScrollBar"), maximum)
end

function Settings.UpdateScroll(viewport, page, pageHeight)
    if not viewport or not page or viewport.bootyScrollLayoutBusy then return end
    viewport.bootyScrollLayoutBusy = true
    local ok, failure = pcall(UpdateSettingsScroll, viewport, page, pageHeight)
    viewport.bootyScrollLayoutBusy = nil
    if not ok then error(failure, 0) end
end

function Settings.CreateFactory(binding)
    local factory = {}
    factory.CreateCheckbox = function(parent, x, y, text, key, onChanged)
        return Settings.CreateCheckbox(parent, x, y, text, key, onChanged, binding)
    end
    factory.CreateSlider = function(parent, name, x, y, label, key, minimum, maximum, onChanged)
        return Settings.CreateSlider(parent, name, x, y, label, key, minimum, maximum, onChanged, binding)
    end
    factory.CreateColor = function(parent, x, y, label, key, onChanged)
        return Settings.CreateColor(parent, x, y, label, key, onChanged, binding)
    end
    factory.CreateSavedCheckbox = function(parent, name, x, y, text, settingKey, tooltipTitle, tooltipText, onChanged)
        return Settings.CreateSavedCheckbox(parent, name, x, y, text, settingKey, tooltipTitle, tooltipText, onChanged, binding)
    end
    factory.CreatePercentageField = function(parent, name, labelText, x, y, settingKey, fallback)
        return Settings.CreatePercentageField(parent, name, labelText, x, y, settingKey, fallback, binding)
    end
    factory.CreateSavedTextField = function(parent, settingKey) return Settings.CreateSavedTextField(parent, settingKey, binding) end
    return factory
end

-- Measure each column from its widest item; only reflow on explicit layout/resize.
function Settings.LayoutGrid(parent, items, x, y, available, step, sliders)
    local count = table.getn(items)
    if count == 0 then return 0 end
    available = math.max(1, available)
    local widths = items.bootyColumnWidths or {}; items.bootyColumnWidths = widths
    local cols, index, col, total = math.min(items.bootyMaxColumns or 4, count), nil, nil, nil
    local required = 0
    for index = 1, count do
        local item = items[index]
        if items.bootyMeasureItem then item.bootyGridWidth = items.bootyMeasureItem(item)
        else
            local label = sliders and getglobal(item:GetName() .. "Text") or item.label
            if label then
                label:SetWidth(0); label:SetJustifyH("LEFT")
                local _, size = label:GetFont(); label:SetHeight((size or 10) + 4)
            end
            item.bootyGridWidth = sliders and math.max(170, label:GetStringWidth() + 8) or ((item.swatchBorder and 26 or item:GetWidth() + 4) + (label and label:GetStringWidth() + 8 or 0))
        end
        required = math.max(required, item.bootyGridWidth)
    end
    while cols > 0 do
        for col = 1, cols do widths[col] = 0 end
        for index = 1, count do col = math.mod(index - 1, cols) + 1; widths[col] = math.max(widths[col], items[index].bootyGridWidth) end
        total = (cols - 1) * 14
        for col = 1, cols do total = total + widths[col] end
        if total <= available or cols == 1 then break end
        cols = cols - 1
    end
    if not items.bootyNoWrap then for col=1,cols do widths[col]=math.min(available,widths[col]) end end
    local offsetX, rowHeight, used = 0, step, 0
    for index = 1, count do
        col = math.mod(index - 1, cols) + 1
        if col == 1 and index > 1 then used = used + rowHeight; rowHeight = step; offsetX = 0 end
        local item = items[index]
        if items.bootyLayoutItem then
            rowHeight = math.max(rowHeight, items.bootyLayoutItem(item, parent, x + offsetX, y - used, widths[col]))
        else
            item:ClearAllPoints(); item:SetPoint("TOPLEFT", parent, "TOPLEFT", x + offsetX, y - used)
            local label = sliders and getglobal(item:GetName() .. "Text") or item.label
            local labelWidth = math.max(1, widths[col] - (sliders and 0 or (item.swatchBorder and 26 or item:GetWidth() + 4)))
            if label then label:SetWidth(labelWidth); label:SetJustifyH("LEFT"); rowHeight = math.max(rowHeight, Booty.UI.Components.MeasureTextHeight(label, labelWidth) + (sliders and 32 or 8)) end
            if sliders or item.swatchBorder then item:SetWidth(widths[col]) end
            if label and not sliders then
                label:ClearAllPoints(); label:SetPoint("TOPLEFT", item, "TOPLEFT", item.swatchBorder and 26 or item:GetWidth() + 4, -3)
            end
            if item.labelHit then
                item.labelHit:SetWidth(labelWidth); item.labelHit:SetHeight(math.max(item:GetHeight(), Booty.UI.Components.MeasureTextHeight(label, labelWidth) + 6))
                item.labelHit:ClearAllPoints(); item.labelHit:SetPoint("TOPLEFT", item, "TOPRIGHT", 2, 0)
            end
        end
        offsetX = offsetX + widths[col] + 14
    end
    items.bootyColumns = cols
    items.bootyRequiredWidth, items.bootyUsedWidth = required, total
    return used + rowHeight
end
