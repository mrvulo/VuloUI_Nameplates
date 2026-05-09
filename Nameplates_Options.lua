-- ============================================================
--  VuloUI_Nameplates - Options / Designer
--  Tab-basiertes Konfigurations-Panel mit Live-Preview
-- ============================================================

if not VuloUI or not VuloUI_Nameplates then return end

local V    = VuloUI
local NP   = VuloUI_Nameplates
local LSM  = LibStub("LibSharedMedia-3.0")

local OPT  = {}
VuloUI_NP_Options = OPT

-- ============================================================
--  HELPERS
-- ============================================================

local function P(v)
    local s = UIParent:GetEffectiveScale()
    return math.floor(v * s + 0.5) / s
end

local function GetProfile() return NP:GetActiveProfile() end

local function Apply()
    NP:Reapply()
end

-- Setze einen verschachtelten Wert im aktiven Profil
local function SetVal(key, value)
    GetProfile()[key] = value
    Apply()
end

local function GetVal(key)
    return GetProfile()[key]
end

-- ============================================================
--  WIDGET FACTORIES
-- ============================================================

local function MakeLabel(parent, text, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetText(text)
    if size then
        local f, _, fl = fs:GetFont()
        fs:SetFont(f, size, fl or "")
    end
    if color then fs:SetTextColor(unpack(color)) end
    return fs
end

local function MakeHeader(parent, text)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetText(text)
    fs:SetTextColor(0.58, 0.44, 0.86)
    return fs
end

local function MakeCheckbox(parent, label, key, onChange)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb.text = cb:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    cb.text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
    cb.text:SetText(label)
    cb:SetSize(24, 24)

    cb.Refresh = function()
        cb:SetChecked(GetVal(key))
    end

    cb:SetScript("OnClick", function(self)
        local v = self:GetChecked()
        SetVal(key, v)
        if onChange then onChange(v) end
    end)

    cb.key = key
    return cb
end

local function MakeSlider(parent, label, key, minV, maxV, step, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(220, 40)

    local title = MakeLabel(frame, label)
    title:SetPoint("TOPLEFT", 0, 0)

    local valueText = MakeLabel(frame, "")
    valueText:SetPoint("TOPRIGHT", 0, 0)

    local slider = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", 0, -18)
    slider:SetWidth(220)
    slider:SetMinMaxValues(minV, maxV)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    if slider.Low  then slider.Low:SetText("")  end
    if slider.High then slider.High:SetText("") end
    if slider.Text then slider.Text:SetText("") end

    slider.Refresh = function()
        local v = GetVal(key) or minV
        slider:SetValue(v)
        valueText:SetText(string.format(step < 1 and "%.2f" or "%d", v))
    end

    slider:SetScript("OnValueChanged", function(self, val)
        if step >= 1 then val = math.floor(val + 0.5) end
        valueText:SetText(string.format(step < 1 and "%.2f" or "%d", val))
        SetVal(key, val)
        if onChange then onChange(val) end
    end)

    frame.slider = slider
    frame.Refresh = slider.Refresh
    frame.key = key
    return frame
end

local function MakeColorPicker(parent, label, key, hasAlpha)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(200, 22)

    local title = MakeLabel(frame, label)
    title:SetPoint("LEFT", 26, 0)

    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    btn:SetSize(20, 20)
    btn:SetPoint("LEFT", 0, 0)
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    btn:SetBackdropBorderColor(0.4, 0.4, 0.4, 1)

    frame.Refresh = function()
        local c = GetVal(key) or {1,1,1,1}
        btn:SetBackdropColor(c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1)
    end

    btn:SetScript("OnClick", function()
        local current = GetVal(key) or {1,1,1,1}
        local r, g, b, a = current[1] or 1, current[2] or 1,
                            current[3] or 1, current[4] or 1

        local function swatch()
            local nr, ng, nb = ColorPickerFrame:GetColorRGB()
            local na = hasAlpha and
                       (1 - (OpacitySliderFrame and OpacitySliderFrame:GetValue() or 0))
                       or a
            local newC = hasAlpha and {nr, ng, nb, na} or {nr, ng, nb}
            -- Originalformat erhalten
            if hasAlpha and #current == 4 then
                SetVal(key, {nr, ng, nb, na})
            else
                SetVal(key, {nr, ng, nb})
            end
            frame.Refresh()
        end

        local function cancel(prev)
            if hasAlpha then
                SetVal(key, {prev.r, prev.g, prev.b, 1 - (prev.opacity or 0)})
            else
                SetVal(key, {prev.r, prev.g, prev.b})
            end
            frame.Refresh()
        end

        if ColorPickerFrame.SetupColorPickerAndShow then
            ColorPickerFrame:SetupColorPickerAndShow({
                r = r, g = g, b = b,
                opacity = hasAlpha and (1 - a) or nil,
                hasOpacity = hasAlpha,
                swatchFunc  = swatch,
                opacityFunc = swatch,
                cancelFunc  = cancel,
            })
        else
            -- Legacy
            ColorPickerFrame.func        = swatch
            ColorPickerFrame.opacityFunc = swatch
            ColorPickerFrame.cancelFunc  = cancel
            ColorPickerFrame.hasOpacity  = hasAlpha
            ColorPickerFrame.opacity     = hasAlpha and (1 - a) or 0
            ColorPickerFrame:SetColorRGB(r, g, b)
            ColorPickerFrame.previousValues = { r=r, g=g, b=b, opacity=1-a }
            ColorPickerFrame:Hide()
            ColorPickerFrame:Show()
        end
    end)

    frame.btn = btn
    frame.key = key
    return frame
end

local function MakeDropdown(parent, label, key, options, onChange)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(220, 40)

    local title = MakeLabel(frame, label)
    title:SetPoint("TOPLEFT", 16, 0)

    local dd = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 0, -16)
    UIDropDownMenu_SetWidth(dd, 180)

    UIDropDownMenu_Initialize(dd, function(self, level)
        for _, opt in ipairs(options) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = opt.text
            info.value = opt.value
            info.func  = function()
                SetVal(key, opt.value)
                UIDropDownMenu_SetSelectedValue(dd, opt.value)
                UIDropDownMenu_SetText(dd, opt.text)
                if onChange then onChange(opt.value) end
            end
            info.checked = (GetVal(key) == opt.value)
            UIDropDownMenu_AddButton(info, level)
        end
    end)

    frame.Refresh = function()
        local v = GetVal(key)
        for _, opt in ipairs(options) do
            if opt.value == v then
                UIDropDownMenu_SetSelectedValue(dd, opt.value)
                UIDropDownMenu_SetText(dd, opt.text)
                return
            end
        end
    end

    frame.dd = dd
    frame.key = key
    return frame
end

-- LSM-Dropdown (für Font/Texture)
local function MakeLSMDropdown(parent, label, key, mediaType)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(220, 40)

    local title = MakeLabel(frame, label)
    title:SetPoint("TOPLEFT", 16, 0)

    local dd = CreateFrame("Frame", nil, frame, "UIDropDownMenuTemplate")
    dd:SetPoint("TOPLEFT", 0, -16)
    UIDropDownMenu_SetWidth(dd, 180)

    UIDropDownMenu_Initialize(dd, function()
        local list = LSM:List(mediaType)
        for _, name in ipairs(list) do
            local info = UIDropDownMenu_CreateInfo()
            info.text  = name
            info.value = name
            info.func  = function()
                SetVal(key, name)
                UIDropDownMenu_SetSelectedValue(dd, name)
                UIDropDownMenu_SetText(dd, name)
            end
            info.checked = (GetVal(key) == name)
            UIDropDownMenu_AddButton(info)
        end
    end)

    frame.Refresh = function()
        UIDropDownMenu_SetSelectedValue(dd, GetVal(key))
        UIDropDownMenu_SetText(dd, GetVal(key) or "")
    end

    frame.key = key
    return frame
end

local function MakeButton(parent, text, w, h, onClick)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetSize(w or 100, h or 22)
    b:SetText(text)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

-- ============================================================
--  MAIN FRAME
-- ============================================================

local main = CreateFrame("Frame", "VuloUI_NP_OptionsFrame",
                         UIParent, "BackdropTemplate")
main:SetSize(720, 540)
main:SetPoint("CENTER")
main:SetFrameStrata("DIALOG")
main:SetMovable(true)
main:EnableMouse(true)
main:RegisterForDrag("LeftButton")
main:SetScript("OnDragStart", main.StartMoving)
main:SetScript("OnDragStop",  main.StopMovingOrSizing)
main:SetClampedToScreen(true)
main:SetBackdrop({
    bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeSize = 1,
    insets   = {left=1, right=1, top=1, bottom=1},
})
main:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
main:SetBackdropBorderColor(0.30, 0.20, 0.45, 1)
main:Hide()

-- Title bar
local titleBar = CreateFrame("Frame", nil, main, "BackdropTemplate")
titleBar:SetHeight(28)
titleBar:SetPoint("TOPLEFT", 0, 0)
titleBar:SetPoint("TOPRIGHT", 0, 0)
titleBar:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
})
titleBar:SetBackdropColor(0.10, 0.06, 0.18, 1)

local title = MakeLabel(titleBar,
    "|cff9370DBVuloUI|r |cffFFFFFFNameplates|r |cff7381ff– Designer|r", 14)
title:SetPoint("LEFT", 12, 0)

local closeBtn = CreateFrame("Button", nil, main, "UIPanelCloseButton")
closeBtn:SetPoint("TOPRIGHT", -2, -2)
closeBtn:SetScript("OnClick", function() main:Hide() end)

-- Active profile label
local profLabel = MakeLabel(titleBar, "", 11, {0.7, 0.7, 0.7})
profLabel:SetPoint("RIGHT", -32, 0)

-- ============================================================
--  TAB SYSTEM
-- ============================================================

local TABS = {
    "Allgemein", "Healthbar", "Texte", "Auras",
    "Threat", "Castbar", "Mods", "Profile",
}

local tabButtons = {}
local tabContents = {}
local activeTab = 1

local function ShowTab(idx)
    activeTab = idx
    for i, btn in ipairs(tabButtons) do
        if i == idx then
            btn:SetBackdropColor(0.30, 0.20, 0.45, 1)
            btn.text:SetTextColor(1, 1, 1)
        else
            btn:SetBackdropColor(0.08, 0.08, 0.10, 1)
            btn.text:SetTextColor(0.7, 0.7, 0.7)
        end
    end
    for i, content in ipairs(tabContents) do
        content:SetShown(i == idx)
    end
    -- Refresh widgets im aktiven Tab
    if tabContents[idx] and tabContents[idx].Refresh then
        tabContents[idx].Refresh()
    end
end

-- Tab-Buttons (links vertikal)
local TAB_W, TAB_H = 110, 32
for i, name in ipairs(TABS) do
    local btn = CreateFrame("Button", nil, main, "BackdropTemplate")
    btn:SetSize(TAB_W, TAB_H)
    btn:SetPoint("TOPLEFT", 8, -36 - (i-1) * (TAB_H + 2))
    btn:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    btn:SetBackdropColor(0.08, 0.08, 0.10, 1)
    btn:SetBackdropBorderColor(0.20, 0.20, 0.25, 1)
    btn.text = MakeLabel(btn, name, 12)
    btn.text:SetPoint("CENTER")
    btn:SetScript("OnClick", function() ShowTab(i) end)
    tabButtons[i] = btn

    local content = CreateFrame("Frame", nil, main)
    content:SetPoint("TOPLEFT", TAB_W + 16, -36)
    content:SetPoint("BOTTOMRIGHT", -8, 36)
    content:Hide()
    tabContents[i] = content
end

-- Footer
local footer = CreateFrame("Frame", nil, main, "BackdropTemplate")
footer:SetHeight(28)
footer:SetPoint("BOTTOMLEFT", 4, 4)
footer:SetPoint("BOTTOMRIGHT", -4, 4)
footer:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
footer:SetBackdropColor(0.10, 0.06, 0.18, 0.6)

local applyBtn = MakeButton(footer, "Reapply", 90, 22, function()
    NP:Reapply()
end)
applyBtn:SetPoint("RIGHT", -8, 0)

local hint = MakeLabel(footer, "Änderungen werden live übernommen.",
                        10, {0.6, 0.6, 0.6})
hint:SetPoint("LEFT", 8, 0)

-- ============================================================
--  TAB 1: ALLGEMEIN
-- ============================================================

do
    local c = tabContents[1]
    local widgets = {}

    local h = MakeHeader(c, "Allgemein")
    h:SetPoint("TOPLEFT", 0, -4)

    local cb1 = MakeCheckbox(c, "Modul aktiviert", "enabled")
    cb1:SetPoint("TOPLEFT", 0, -28)
    table.insert(widgets, cb1)

    local cb2 = MakeCheckbox(c, "Klassenfarben für Spieler",
                              "classColorPlayers")
    cb2:SetPoint("TOPLEFT", 0, -56)
    table.insert(widgets, cb2)

    local cb3 = MakeCheckbox(c, "Reaktionsfarben (Feind/Freund/Neutral)",
                              "useReactionColors")
    cb3:SetPoint("TOPLEFT", 0, -84)
    table.insert(widgets, cb3)

    local s1 = MakeSlider(c, "Skalierung", "scale", 0.5, 2.0, 0.05)
    s1:SetPoint("TOPLEFT", 0, -116)
    table.insert(widgets, s1)

    local s2 = MakeSlider(c, "Breite", "width", 80, 400, 1)
    s2:SetPoint("TOPLEFT", 0, -160)
    table.insert(widgets, s2)

    local s3 = MakeSlider(c, "Höhe (HP-Bar)", "height", 6, 40, 1)
    s3:SetPoint("TOPLEFT", 0, -204)
    table.insert(widgets, s3)

    local s4 = MakeSlider(c, "Castbar-Höhe", "castbarHeight", 4, 30, 1)
    s4:SetPoint("TOPLEFT", 0, -248)
    table.insert(widgets, s4)

    local d1 = MakeLSMDropdown(c, "Bar-Textur", "barTexture", "statusbar")
    d1:SetPoint("TOPLEFT", 250, -116)
    table.insert(widgets, d1)

    local d2 = MakeLSMDropdown(c, "Schriftart", "font", "font")
    d2:SetPoint("TOPLEFT", 250, -160)
    table.insert(widgets, d2)

    local s5 = MakeSlider(c, "Schriftgröße", "fontSize", 6, 20, 1)
    s5:SetPoint("TOPLEFT", 250, -204)
    table.insert(widgets, s5)

    local d3 = MakeDropdown(c, "Schrift-Outline", "fontOutline", {
        { text = "Keine",       value = "NONE" },
        { text = "Outline",     value = "OUTLINE" },
        { text = "Thick",       value = "THICKOUTLINE" },
        { text = "Monochrome",  value = "MONOCHROME,OUTLINE" },
    })
    d3:SetPoint("TOPLEFT", 250, -248)
    table.insert(widgets, d3)

    local cp1 = MakeColorPicker(c, "Hintergrund", "colorBackground", true)
    cp1:SetPoint("TOPLEFT", 0, -296)
    table.insert(widgets, cp1)

    local cp2 = MakeColorPicker(c, "Rand", "colorBorder", true)
    cp2:SetPoint("TOPLEFT", 0, -322)
    table.insert(widgets, cp2)

    local cp3 = MakeColorPicker(c, "Freundlich", "colorFriendly")
    cp3:SetPoint("TOPLEFT", 250, -296)
    table.insert(widgets, cp3)

    local cp4 = MakeColorPicker(c, "Feindlich", "colorEnemy")
    cp4:SetPoint("TOPLEFT", 250, -322)
    table.insert(widgets, cp4)

    local cp5 = MakeColorPicker(c, "Neutral", "colorNeutral")
    cp5:SetPoint("TOPLEFT", 250, -348)
    table.insert(widgets, cp5)

    c.Refresh = function()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
end

-- ============================================================
--  TAB 2: HEALTHBAR
-- ============================================================

do
    local c = tabContents[2]
    local widgets = {}

    local h = MakeHeader(c, "Healthbar")
    h:SetPoint("TOPLEFT", 0, -4)

    local cb1 = MakeCheckbox(c, "HP in Prozent zeigen", "showHealthPercent")
    cb1:SetPoint("TOPLEFT", 0, -28)
    table.insert(widgets, cb1)

    local cb2 = MakeCheckbox(c, "HP absolut zeigen", "showHealthAbsolute")
    cb2:SetPoint("TOPLEFT", 0, -56)
    table.insert(widgets, cb2)

    local cb3 = MakeCheckbox(c, "Zahlen abkürzen (1.2M)", "abbreviateNumbers")
    cb3:SetPoint("TOPLEFT", 0, -84)
    table.insert(widgets, cb3)

    local hd = MakeHeader(c, "Execute-Range")
    hd:SetPoint("TOPLEFT", 0, -124)

    local cb4 = MakeCheckbox(c, "Execute-Indikator zeigen", "showExecute")
    cb4:SetPoint("TOPLEFT", 0, -148)
    table.insert(widgets, cb4)

    local s1 = MakeSlider(c, "Schwellwert (%)", "executeThreshold", 5, 50, 1)
    s1:SetPoint("TOPLEFT", 0, -180)
    table.insert(widgets, s1)

    local cp1 = MakeColorPicker(c, "Execute-Farbe", "executeColor")
    cp1:SetPoint("TOPLEFT", 0, -228)
    table.insert(widgets, cp1)

    local hd2 = MakeHeader(c, "Target-Highlight")
    hd2:SetPoint("TOPLEFT", 0, -264)

    local cb5 = MakeCheckbox(c, "Target hervorheben", "targetHighlight")
    cb5:SetPoint("TOPLEFT", 0, -288)
    table.insert(widgets, cb5)

    local s2 = MakeSlider(c, "Alpha für Nicht-Targets", "nonTargetAlpha",
                           0.3, 1.0, 0.05)
    s2:SetPoint("TOPLEFT", 0, -320)
    table.insert(widgets, s2)

    local cp2 = MakeColorPicker(c, "Target-Glow-Farbe", "targetGlowColor", true)
    cp2:SetPoint("TOPLEFT", 0, -368)
    table.insert(widgets, cp2)

    c.Refresh = function()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
end

-- ============================================================
--  TAB 3: TEXTE
-- ============================================================

do
    local c = tabContents[3]
    local widgets = {}

    local h = MakeHeader(c, "Texte")
    h:SetPoint("TOPLEFT", 0, -4)

    local cb1 = MakeCheckbox(c, "Name zeigen", "showName")
    cb1:SetPoint("TOPLEFT", 0, -28)
    table.insert(widgets, cb1)

    local cb2 = MakeCheckbox(c, "Level zeigen", "showLevel")
    cb2:SetPoint("TOPLEFT", 0, -56)
    table.insert(widgets, cb2)

    local cb3 = MakeCheckbox(c, "Schatten unter Text", "fontShadow")
    cb3:SetPoint("TOPLEFT", 0, -84)
    table.insert(widgets, cb3)

    local s1 = MakeSlider(c, "Max. Namenslänge", "maxNameLength", 4, 30, 1)
    s1:SetPoint("TOPLEFT", 0, -120)
    table.insert(widgets, s1)

    c.Refresh = function()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
end

-- ============================================================
--  TAB 4: AURAS
-- ============================================================

do
    local c = tabContents[4]
    local widgets = {}

    local h = MakeHeader(c, "Auras (Buffs/Debuffs)")
    h:SetPoint("TOPLEFT", 0, -4)

    local cb1 = MakeCheckbox(c, "Auras anzeigen", "showAuras")
    cb1:SetPoint("TOPLEFT", 0, -28)
    table.insert(widgets, cb1)

    local s1 = MakeSlider(c, "Anzahl Icons", "auraCount", 1, 12, 1)
    s1:SetPoint("TOPLEFT", 0, -60)
    table.insert(widgets, s1)

    local s2 = MakeSlider(c, "Icon-Größe", "auraIconSize", 8, 32, 1)
    s2:SetPoint("TOPLEFT", 0, -104)
    table.insert(widgets, s2)

    local s3 = MakeSlider(c, "Abstand", "auraSpacing", 0, 8, 1)
    s3:SetPoint("TOPLEFT", 0, -148)
    table.insert(widgets, s3)

    local d1 = MakeDropdown(c, "Filter", "auraFilter", {
        { text = "Alle Auras",                  value = "all" },
        { text = "Nur eigene",                  value = "mine" },
        { text = "Wichtige (eigene + Liste)",   value = "important" },
    })
    d1:SetPoint("TOPLEFT", 250, -60)
    table.insert(widgets, d1)

    -- ── SpellID-Listen Editor ─────────────────────────────────
    local function MakeSpellListEditor(parent, title, dbKey, x, y)
        local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        box:SetSize(200, 180)
        box:SetPoint("TOPLEFT", x, y)
        box:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = 1,
        })
        box:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
        box:SetBackdropBorderColor(0.20, 0.15, 0.30, 1)

        local lbl = MakeLabel(box, title, 12)
        lbl:SetPoint("TOPLEFT", 6, -4)

        -- ScrollFrame
        local scroll = CreateFrame("ScrollFrame", nil, box, "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 4, -22)
        scroll:SetPoint("BOTTOMRIGHT", -24, 32)

        local content = CreateFrame("Frame", nil, scroll)
        content:SetSize(170, 1)
        scroll:SetScrollChild(content)

        local edit = CreateFrame("EditBox", nil, box, "InputBoxTemplate")
        edit:SetSize(120, 18)
        edit:SetPoint("BOTTOMLEFT", 8, 8)
        edit:SetAutoFocus(false)
        edit:SetNumeric(true)

        local addBtn = MakeButton(box, "Add", 50, 20, function()
            local id = tonumber(edit:GetText())
            if id and id > 0 then
                GetProfile()[dbKey][id] = true
                edit:SetText("")
                box:Refresh()
                Apply()
            end
        end)
        addBtn:SetPoint("LEFT", edit, "RIGHT", 4, 0)

        function box:Refresh()
            for _, c in ipairs({content:GetChildren()}) do
                c:Hide(); c:SetParent(nil)
            end
            local list = GetProfile()[dbKey] or {}
            local i = 0
            for id in pairs(list) do
                local row = CreateFrame("Frame", nil, content)
                row:SetSize(170, 18)
                row:SetPoint("TOPLEFT", 0, -i * 20)

                local nameStr = "Spell "..id
                local info = C_Spell and C_Spell.GetSpellInfo(id)
                if info and info.name then nameStr = info.name end

                local txt = MakeLabel(row, id.." – "..nameStr, 11)
                txt:SetPoint("LEFT", 0, 0)

                local del = CreateFrame("Button", nil, row,
                                         "UIPanelCloseButtonNoScripts")
                del:SetSize(16, 16)
                del:SetPoint("RIGHT", 0, 0)
                del:SetScript("OnClick", function()
                    GetProfile()[dbKey][id] = nil
                    box:Refresh()
                    Apply()
                end)
                i = i + 1
            end
            content:SetHeight(math.max(1, i * 20))
        end

        return box
    end

    local impList = MakeSpellListEditor(c, "Wichtige Spells",
                     "auraImportant", 0, -200)
    table.insert(widgets, impList)

    local blackList = MakeSpellListEditor(c, "Blacklist",
                       "auraBlacklist", 220, -200)
    table.insert(widgets, blackList)

    local whiteList = MakeSpellListEditor(c, "Whitelist",
                       "auraWhitelist", 440, -200)
    table.insert(widgets, whiteList)

    c.Refresh = function()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
end

-- ============================================================
--  TAB 5: THREAT
-- ============================================================

do
    local c = tabContents[5]
    local widgets = {}

    local h = MakeHeader(c, "Threat / Aggro")
    h:SetPoint("TOPLEFT", 0, -4)

    local cb1 = MakeCheckbox(c, "Threat-Färbung aktiviert", "showThreat")
    cb1:SetPoint("TOPLEFT", 0, -28)
    table.insert(widgets, cb1)

    local d1 = MakeDropdown(c, "Threat-Modus", "threatMode", {
        { text = "Auto (basierend auf Rolle)", value = "auto" },
        { text = "Tank-Modus",                  value = "tank" },
        { text = "DPS/Heiler-Modus",            value = "dps" },
    })
    d1:SetPoint("TOPLEFT", 0, -60)
    table.insert(widgets, d1)

    local s1 = MakeSlider(c, "Glow-Größe", "threatGlowSize", 1, 6, 1)
    s1:SetPoint("TOPLEFT", 0, -104)
    table.insert(widgets, s1)

    local hd = MakeHeader(c, "Farben")
    hd:SetPoint("TOPLEFT", 0, -148)

    local cp1 = MakeColorPicker(c, "Tank: Aggro halte ich", "colorThreatTank")
    cp1:SetPoint("TOPLEFT", 0, -176)
    table.insert(widgets, cp1)

    local cp2 = MakeColorPicker(c, "Tank: Off-Tank hat Aggro", "colorThreatOffTank")
    cp2:SetPoint("TOPLEFT", 0, -202)
    table.insert(widgets, cp2)

    local cp3 = MakeColorPicker(c, "DPS: leichtes Risiko", "colorThreatLow")
    cp3:SetPoint("TOPLEFT", 0, -228)
    table.insert(widgets, cp3)

    local cp4 = MakeColorPicker(c, "DPS: hohes Risiko", "colorThreatMid")
    cp4:SetPoint("TOPLEFT", 0, -254)
    table.insert(widgets, cp4)

    local cp5 = MakeColorPicker(c, "DPS: volle Aggro", "colorThreatHigh")
    cp5:SetPoint("TOPLEFT", 0, -280)
    table.insert(widgets, cp5)

    c.Refresh = function()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
end

-- ============================================================
--  TAB 6: CASTBAR
-- ============================================================

do
    local c = tabContents[6]
    local widgets = {}

    local h = MakeHeader(c, "Castbar")
    h:SetPoint("TOPLEFT", 0, -4)

    local cb1 = MakeCheckbox(c, "Castbar zeigen", "showCastbar")
    cb1:SetPoint("TOPLEFT", 0, -28)
    table.insert(widgets, cb1)

    local cb2 = MakeCheckbox(c, "Spell-Icon zeigen", "showCastIcon")
    cb2:SetPoint("TOPLEFT", 0, -56)
    table.insert(widgets, cb2)

    local cb3 = MakeCheckbox(c, "Spark zeigen", "showCastSpark")
    cb3:SetPoint("TOPLEFT", 0, -84)
    table.insert(widgets, cb3)

    local cp1 = MakeColorPicker(c, "Normaler Cast", "colorCastNormal")
    cp1:SetPoint("TOPLEFT", 0, -124)
    table.insert(widgets, cp1)

    local cp2 = MakeColorPicker(c, "Channel", "colorCastChannel")
    cp2:SetPoint("TOPLEFT", 0, -150)
    table.insert(widgets, cp2)

    local cp3 = MakeColorPicker(c, "Nicht unterbrechbar", "colorCastUninter")
    cp3:SetPoint("TOPLEFT", 0, -176)
    table.insert(widgets, cp3)

    local cp4 = MakeColorPicker(c, "Unterbrochen", "colorCastInterrupt")
    cp4:SetPoint("TOPLEFT", 0, -202)
    table.insert(widgets, cp4)

    c.Refresh = function()
        for _, w in ipairs(widgets) do
            if w.Refresh then w:Refresh() end
        end
    end
end

-- ============================================================
--  TAB 7: MODS
-- ============================================================

do
    local c = tabContents[7]

    local h = MakeHeader(c, "Mods (NPC-spezifische Anpassungen)")
    h:SetPoint("TOPLEFT", 0, -4)

    local hint = MakeLabel(c,
        "Wende Aktionen auf bestimmte NPCs an. Beispiel: NPC-ID 12345 → SetColor rot.",
        10, {0.6, 0.6, 0.6})
    hint:SetPoint("TOPLEFT", 0, -24)

    -- Linke Liste: Mod-Übersicht
    local listFrame = CreateFrame("Frame", nil, c, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 0, -50)
    listFrame:SetPoint("BOTTOMLEFT", 0, 40)
    listFrame:SetWidth(220)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    listFrame:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
    listFrame:SetBackdropBorderColor(0.20, 0.15, 0.30, 1)

    local listScroll = CreateFrame("ScrollFrame", nil, listFrame,
                                    "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(190, 1)
    listScroll:SetScrollChild(listContent)

    -- Rechte Detail-Ansicht
    local detail = CreateFrame("Frame", nil, c, "BackdropTemplate")
    detail:SetPoint("TOPLEFT", 230, -50)
    detail:SetPoint("BOTTOMRIGHT", 0, 40)
    detail:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    detail:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
    detail:SetBackdropBorderColor(0.20, 0.15, 0.30, 1)
    detail:Hide()

    local selectedMod = nil

    -- Trigger-Typen
    local TRIGGER_TYPES = {
        { text = "NPC-ID",          value = "npcid" },
        { text = "NPC-Name",        value = "npcname" },
        { text = "Spell-Cast",      value = "spellcast" },
        { text = "Aura vorhanden",  value = "aurapresent" },
    }

    -- Aktions-Typen
    local ACTION_TYPES = {
        { text = "HP-Bar Farbe",    value = "setcolor"  },
        { text = "Rand-Farbe",      value = "setborder" },
        { text = "Skalierung",      value = "setscale"  },
        { text = "Glow",            value = "glow"      },
        { text = "Verstecken",      value = "hide"      },
        { text = "Wichtig-Text",    value = "important" },
    }

    local function RebuildList()
        for _, child in ipairs({listContent:GetChildren()}) do
            child:Hide(); child:SetParent(nil)
        end
        local mods = GetProfile().mods or {}
        for i, mod in ipairs(mods) do
            local row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
            row:SetSize(180, 24)
            row:SetPoint("TOPLEFT", 0, -(i-1) * 26)
            row:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            })
            if selectedMod == mod then
                row:SetBackdropColor(0.30, 0.20, 0.45, 0.6)
            else
                row:SetBackdropColor(0.10, 0.10, 0.12, 0.6)
            end
            local lbl = MakeLabel(row, mod.name or "(unbenannt)", 11)
            lbl:SetPoint("LEFT", 4, 0)
            if not mod.enabled then
                lbl:SetTextColor(0.5, 0.5, 0.5)
            end
            row:SetScript("OnClick", function()
                selectedMod = mod
                RebuildList()
                BuildDetail()
            end)
        end
        listContent:SetHeight(math.max(1, #mods * 26))
    end

    local detailWidgets = {}
    local function ClearDetail()
        for _, w in ipairs(detailWidgets) do
            w:Hide(); w:SetParent(nil)
        end
        wipe(detailWidgets)
    end

    function BuildDetail()
        ClearDetail()
        if not selectedMod then
            detail:Hide()
            return
        end
        detail:Show()

        local nameLabel = MakeLabel(detail, "Name:", 11)
        nameLabel:SetPoint("TOPLEFT", 8, -8)
        table.insert(detailWidgets, nameLabel)

        local nameBox = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
        nameBox:SetSize(200, 20)
        nameBox:SetPoint("TOPLEFT", 60, -6)
        nameBox:SetAutoFocus(false)
        nameBox:SetText(selectedMod.name or "")
        nameBox:SetScript("OnEnterPressed", function(self)
            selectedMod.name = self:GetText()
            self:ClearFocus()
            RebuildList()
            Apply()
        end)
        table.insert(detailWidgets, nameBox)

        local enabledCB = CreateFrame("CheckButton", nil, detail,
                                       "UICheckButtonTemplate")
        enabledCB:SetPoint("TOPLEFT", 270, -4)
        enabledCB:SetSize(22, 22)
        enabledCB.text = MakeLabel(enabledCB, "Aktiv")
        enabledCB.text:SetPoint("LEFT", enabledCB, "RIGHT", 2, 0)
        enabledCB:SetChecked(selectedMod.enabled)
        enabledCB:SetScript("OnClick", function(s)
            selectedMod.enabled = s:GetChecked()
            RebuildList()
            Apply()
        end)
        table.insert(detailWidgets, enabledCB)

        -- Trigger
        local trigHeader = MakeHeader(detail, "Trigger")
        trigHeader:SetPoint("TOPLEFT", 8, -42)
        table.insert(detailWidgets, trigHeader)

        local trigDD = CreateFrame("Frame", nil, detail, "UIDropDownMenuTemplate")
        trigDD:SetPoint("TOPLEFT", -8, -64)
        UIDropDownMenu_SetWidth(trigDD, 130)
        UIDropDownMenu_Initialize(trigDD, function()
            for _, opt in ipairs(TRIGGER_TYPES) do
                local info = UIDropDownMenu_CreateInfo()
                info.text  = opt.text
                info.value = opt.value
                info.func  = function()
                    selectedMod.trigger = selectedMod.trigger or {}
                    selectedMod.trigger.type = opt.value
                    UIDropDownMenu_SetSelectedValue(trigDD, opt.value)
                    UIDropDownMenu_SetText(trigDD, opt.text)
                    Apply()
                end
                info.checked = selectedMod.trigger
                                and selectedMod.trigger.type == opt.value
                UIDropDownMenu_AddButton(info)
            end
        end)
        if selectedMod.trigger then
            UIDropDownMenu_SetSelectedValue(trigDD, selectedMod.trigger.type)
            for _, opt in ipairs(TRIGGER_TYPES) do
                if opt.value == selectedMod.trigger.type then
                    UIDropDownMenu_SetText(trigDD, opt.text)
                end
            end
        end
        table.insert(detailWidgets, trigDD)

        local trigValueBox = CreateFrame("EditBox", nil, detail, "InputBoxTemplate")
        trigValueBox:SetSize(140, 20)
        trigValueBox:SetPoint("LEFT", trigDD, "RIGHT", 0, 2)
        trigValueBox:SetAutoFocus(false)
        trigValueBox:SetText(selectedMod.trigger
                              and tostring(selectedMod.trigger.value or "") or "")
        trigValueBox:SetScript("OnEnterPressed", function(self)
            selectedMod.trigger = selectedMod.trigger or {}
            local txt = self:GetText()
            local num = tonumber(txt)
            selectedMod.trigger.value = num or txt
            self:ClearFocus()
            Apply()
        end)
        local trigHint = MakeLabel(detail,
            "Wert (NPC-ID, Spell-ID/Name, etc.) – Enter zum Bestätigen",
            9, {0.55, 0.55, 0.55})
        trigHint:SetPoint("TOPLEFT", trigValueBox, "BOTTOMLEFT", 0, -2)
        table.insert(detailWidgets, trigValueBox)
        table.insert(detailWidgets, trigHint)

        -- Aktionen
        local actHeader = MakeHeader(detail, "Aktionen")
        actHeader:SetPoint("TOPLEFT", 8, -116)
        table.insert(detailWidgets, actHeader)

        selectedMod.actions = selectedMod.actions or {}
        local yOff = -140
        for actIdx, action in ipairs(selectedMod.actions) do
            local row = CreateFrame("Frame", nil, detail, "BackdropTemplate")
            row:SetSize(420, 28)
            row:SetPoint("TOPLEFT", 8, yOff)
            row:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
            row:SetBackdropColor(0.08, 0.08, 0.10, 0.6)

            local actDD = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
            actDD:SetPoint("LEFT", -16, 0)
            UIDropDownMenu_SetWidth(actDD, 110)
            UIDropDownMenu_Initialize(actDD, function()
                for _, opt in ipairs(ACTION_TYPES) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = opt.text
                    info.func = function()
                        action.type = opt.value
                        UIDropDownMenu_SetText(actDD, opt.text)
                        BuildDetail()
                        Apply()
                    end
                    info.checked = (action.type == opt.value)
                    UIDropDownMenu_AddButton(info)
                end
            end)
            for _, opt in ipairs(ACTION_TYPES) do
                if opt.value == action.type then
                    UIDropDownMenu_SetText(actDD, opt.text)
                end
            end
            table.insert(detailWidgets, actDD)

            -- Wert je nach Action-Typ
            if action.type == "setcolor" or action.type == "glow"
               or action.type == "setborder" or action.type == "important" then

                local cBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
                cBtn:SetSize(20, 20)
                cBtn:SetPoint("LEFT", 110, 0)
                cBtn:SetBackdrop({
                    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
                    edgeSize = 1,
                })
                local col = action.color or {1,1,1,1}
                cBtn:SetBackdropColor(col[1], col[2], col[3], col[4] or 1)
                cBtn:SetScript("OnClick", function()
                    local c = action.color or {1,1,1,1}
                    local r,g,b,a = c[1] or 1, c[2] or 1, c[3] or 1, c[4] or 1
                    local function swatch()
                        local nr, ng, nb = ColorPickerFrame:GetColorRGB()
                        action.color = {nr, ng, nb, a}
                        cBtn:SetBackdropColor(nr, ng, nb, a)
                        Apply()
                    end
                    if ColorPickerFrame.SetupColorPickerAndShow then
                        ColorPickerFrame:SetupColorPickerAndShow({
                            r=r, g=g, b=b, hasOpacity=false,
                            swatchFunc=swatch,
                            cancelFunc=function() end,
                        })
                    else
                        ColorPickerFrame.func = swatch
                        ColorPickerFrame.hasOpacity = false
                        ColorPickerFrame:SetColorRGB(r, g, b)
                        ColorPickerFrame.previousValues = {r=r,g=g,b=b}
                        ColorPickerFrame:Hide()
                        ColorPickerFrame:Show()
                    end
                end)
                table.insert(detailWidgets, cBtn)
            end

            if action.type == "setscale" then
                local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                eb:SetSize(60, 20)
                eb:SetPoint("LEFT", 116, 0)
                eb:SetAutoFocus(false)
                eb:SetText(tostring(action.value or 1.0))
                eb:SetScript("OnEnterPressed", function(self)
                    action.value = tonumber(self:GetText()) or 1
                    self:ClearFocus()
                    Apply()
                end)
                table.insert(detailWidgets, eb)
            end

            if action.type == "important" then
                local eb = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
                eb:SetSize(150, 20)
                eb:SetPoint("LEFT", 140, 0)
                eb:SetAutoFocus(false)
                eb:SetText(action.text or "")
                eb:SetScript("OnEnterPressed", function(self)
                    action.text = self:GetText()
                    self:ClearFocus()
                    Apply()
                end)
                table.insert(detailWidgets, eb)
            end

            -- Delete button
            local del = CreateFrame("Button", nil, row, "UIPanelCloseButtonNoScripts")
            del:SetSize(18, 18)
            del:SetPoint("RIGHT", -2, 0)
            del:SetScript("OnClick", function()
                table.remove(selectedMod.actions, actIdx)
                BuildDetail()
                Apply()
            end)
            table.insert(detailWidgets, del)

            table.insert(detailWidgets, row)
            yOff = yOff - 32
        end

        -- Add Action Button
        local addAct = MakeButton(detail, "+ Aktion", 90, 22, function()
            table.insert(selectedMod.actions, { type = "setcolor", color = {1,0,0,1} })
            BuildDetail()
            Apply()
        end)
        addAct:SetPoint("TOPLEFT", 8, yOff)
        table.insert(detailWidgets, addAct)

        -- Export-Button
        local exportBtn = MakeButton(detail, "Export", 80, 22, function()
            local str = NP:ExportMod(selectedMod)
            if str then OPT:ShowImportExportDialog("Export Mod", str, false) end
        end)
        exportBtn:SetPoint("TOPRIGHT", -8, -8)
        table.insert(detailWidgets, exportBtn)
    end

    -- Footer-Buttons
    local addBtn = MakeButton(c, "+ Neuer Mod", 110, 22, function()
        local mods = GetProfile().mods
        local newMod = {
            id      = tostring(GetTime()),
            name    = "Neuer Mod",
            enabled = true,
            trigger = { type = "npcid", value = 0 },
            actions = {},
        }
        table.insert(mods, newMod)
        selectedMod = newMod
        RebuildList()
        BuildDetail()
        Apply()
    end)
    addBtn:SetPoint("BOTTOMLEFT", listFrame, "BOTTOMLEFT", 4, -28)

    local delBtn = MakeButton(c, "Löschen", 80, 22, function()
        if not selectedMod then return end
        local mods = GetProfile().mods
        for i, m in ipairs(mods) do
            if m == selectedMod then
                table.remove(mods, i); break
            end
        end
        selectedMod = nil
        RebuildList()
        BuildDetail()
        Apply()
    end)
    delBtn:SetPoint("LEFT", addBtn, "RIGHT", 4, 0)

    local importBtn = MakeButton(c, "Mod importieren", 130, 22, function()
        OPT:ShowImportExportDialog("Mod importieren", "", true,
            function(str)
                local mod, err = NP:ImportMod(str)
                if mod then
                    table.insert(GetProfile().mods, mod)
                    RebuildList()
                    Apply()
                    print("|cff9370DBVuloUI:|r Mod importiert.")
                else
                    print("|cffFF6060Import-Fehler:|r "..(err or "?"))
                end
            end)
    end)
    importBtn:SetPoint("LEFT", delBtn, "RIGHT", 4, 0)

    c.Refresh = function()
        RebuildList()
        BuildDetail()
    end
end

-- ============================================================
--  TAB 8: PROFILE
-- ============================================================

do
    local c = tabContents[8]

    local h = MakeHeader(c, "Profile")
    h:SetPoint("TOPLEFT", 0, -4)

    local activeLabel = MakeLabel(c, "", 12, {0.6, 0.85, 0.6})
    activeLabel:SetPoint("TOPLEFT", 0, -28)

    -- Profil-Liste
    local listFrame = CreateFrame("Frame", nil, c, "BackdropTemplate")
    listFrame:SetPoint("TOPLEFT", 0, -54)
    listFrame:SetSize(220, 180)
    listFrame:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = 1,
    })
    listFrame:SetBackdropColor(0.04, 0.04, 0.05, 0.9)
    listFrame:SetBackdropBorderColor(0.20, 0.15, 0.30, 1)

    local listScroll = CreateFrame("ScrollFrame", nil, listFrame,
                                    "UIPanelScrollFrameTemplate")
    listScroll:SetPoint("TOPLEFT", 4, -4)
    listScroll:SetPoint("BOTTOMRIGHT", -24, 4)
    local listContent = CreateFrame("Frame", nil, listScroll)
    listContent:SetSize(190, 1)
    listScroll:SetScrollChild(listContent)

    local function RefreshProfileList()
        activeLabel:SetText("Aktives Profil: |cffFFFFFF"
            ..(VuloUI_NameplatesDB.activeProfile or "?").."|r")

        for _, child in ipairs({listContent:GetChildren()}) do
            child:Hide(); child:SetParent(nil)
        end

        local i = 0
        for _, name in ipairs(NP:GetProfileList()) do
            local row = CreateFrame("Button", nil, listContent, "BackdropTemplate")
            row:SetSize(180, 24)
            row:SetPoint("TOPLEFT", 0, -i * 26)
            row:SetBackdrop({
                bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
            })
            if name == VuloUI_NameplatesDB.activeProfile then
                row:SetBackdropColor(0.30, 0.20, 0.45, 0.6)
            else
                row:SetBackdropColor(0.10, 0.10, 0.12, 0.6)
            end

            local lbl = MakeLabel(row, name, 11)
            lbl:SetPoint("LEFT", 4, 0)

            row:SetScript("OnClick", function()
                NP:SetActiveProfile(name)
                RefreshProfileList()
            end)
            i = i + 1
        end
        listContent:SetHeight(math.max(1, i * 26))
    end

    -- Buttons
    local nameInput = CreateFrame("EditBox", nil, c, "InputBoxTemplate")
    nameInput:SetSize(150, 20)
    nameInput:SetPoint("TOPLEFT", 240, -54)
    nameInput:SetAutoFocus(false)

    local newBtn = MakeButton(c, "Neues Profil", 110, 22, function()
        local n = nameInput:GetText()
        if n and n ~= "" then
            if NP:CreateProfile(n) then
                nameInput:SetText("")
                RefreshProfileList()
                print("|cff9370DBProfil erstellt:|r "..n)
            else
                print("|cffFF6060Profil existiert bereits|r")
            end
        end
    end)
    newBtn:SetPoint("TOPLEFT", 240, -82)

    local copyBtn = MakeButton(c, "Aktives kopieren", 130, 22, function()
        local n = nameInput:GetText()
        if n and n ~= "" then
            if NP:CreateProfile(n, VuloUI_NameplatesDB.activeProfile) then
                nameInput:SetText("")
                RefreshProfileList()
            end
        end
    end)
    copyBtn:SetPoint("TOPLEFT", 240, -110)

    local delBtn = MakeButton(c, "Aktives löschen", 130, 22, function()
        local n = VuloUI_NameplatesDB.activeProfile
        if n == "Default" then
            print("|cffFF6060Default-Profil kann nicht gelöscht werden|r")
            return
        end
        NP:DeleteProfile(n)
        RefreshProfileList()
    end)
    delBtn:SetPoint("TOPLEFT", 240, -138)

    local exportBtn = MakeButton(c, "Aktives exportieren", 150, 22, function()
        local str = NP:ExportProfile(VuloUI_NameplatesDB.activeProfile)
        if str then
            OPT:ShowImportExportDialog("Profil-Export", str, false)
        end
    end)
    exportBtn:SetPoint("TOPLEFT", 240, -174)

    local importBtn = MakeButton(c, "Profil importieren", 150, 22, function()
        OPT:ShowImportExportDialog("Profil importieren", "", true,
            function(str)
                local n = nameInput:GetText()
                if n == "" then n = nil end
                local ok, result = NP:ImportProfile(str, n)
                if ok then
                    print("|cff9370DBProfil importiert:|r "..result)
                    nameInput:SetText("")
                    RefreshProfileList()
                else
                    print("|cffFF6060Import-Fehler:|r "..(result or "?"))
                end
            end)
    end)
    importBtn:SetPoint("TOPLEFT", 240, -202)

    -- Spec-Mapping
    local specHeader = MakeHeader(c, "Spec-basiertes Profil-Mapping")
    specHeader:SetPoint("TOPLEFT", 0, -250)

    local specHint = MakeLabel(c,
        "Weise jeder Spec ein Profil zu. Wechselt automatisch beim Spec-Wechsel.",
        10, {0.6, 0.6, 0.6})
    specHint:SetPoint("TOPLEFT", 0, -270)

    local specRows = {}
    local function RefreshSpecMapping()
        for _, r in ipairs(specRows) do r:Hide(); r:SetParent(nil) end
        wipe(specRows)

        local numSpecs = GetNumSpecializations() or 0
        for i = 1, numSpecs do
            local id, name = GetSpecializationInfo(i)
            if id then
                local row = CreateFrame("Frame", nil, c)
                row:SetSize(550, 28)
                row:SetPoint("TOPLEFT", 0, -290 - (i-1) * 30)

                local lbl = MakeLabel(row, name or ("Spec "..i), 11)
                lbl:SetPoint("LEFT", 0, 0)
                lbl:SetWidth(140)
                lbl:SetJustifyH("LEFT")

                local dd = CreateFrame("Frame", nil, row, "UIDropDownMenuTemplate")
                dd:SetPoint("LEFT", 130, 0)
                UIDropDownMenu_SetWidth(dd, 150)
                UIDropDownMenu_Initialize(dd, function()
                    do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text  = "(automatisch / aktives)"
                        info.value = nil
                        info.func  = function()
                            VuloUI_NameplatesDB.specMapping["spec"..id] = nil
                            UIDropDownMenu_SetText(dd, info.text)
                            NP:Reapply()
                        end
                        UIDropDownMenu_AddButton(info)
                    end
                    for _, pName in ipairs(NP:GetProfileList()) do
                        local info = UIDropDownMenu_CreateInfo()
                        info.text  = pName
                        info.value = pName
                        info.func  = function()
                            VuloUI_NameplatesDB.specMapping["spec"..id] = pName
                            UIDropDownMenu_SetText(dd, pName)
                            NP:Reapply()
                        end
                        UIDropDownMenu_AddButton(info)
                    end
                end)
                local current = VuloUI_NameplatesDB.specMapping["spec"..id]
                UIDropDownMenu_SetText(dd, current or "(automatisch / aktives)")

                table.insert(specRows, row)
            end
        end
    end

    c.Refresh = function()
        RefreshProfileList()
        RefreshSpecMapping()
    end
end

-- ============================================================
--  IMPORT / EXPORT DIALOG
-- ============================================================

local ieDialog
function OPT:ShowImportExportDialog(title, defaultText, allowImport, onImport)
    if not ieDialog then
        ieDialog = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        ieDialog:SetSize(500, 320)
        ieDialog:SetPoint("CENTER")
        ieDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        ieDialog:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = 1,
        })
        ieDialog:SetBackdropColor(0.06, 0.06, 0.08, 0.97)
        ieDialog:SetBackdropBorderColor(0.30, 0.20, 0.45, 1)
        ieDialog:SetMovable(true)
        ieDialog:EnableMouse(true)
        ieDialog:RegisterForDrag("LeftButton")
        ieDialog:SetScript("OnDragStart", ieDialog.StartMoving)
        ieDialog:SetScript("OnDragStop",  ieDialog.StopMovingOrSizing)

        ieDialog.title = MakeLabel(ieDialog, "", 13)
        ieDialog.title:SetPoint("TOP", 0, -10)

        local close = CreateFrame("Button", nil, ieDialog, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)

        local scroll = CreateFrame("ScrollFrame", nil, ieDialog,
                                    "UIPanelScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT", 12, -36)
        scroll:SetPoint("BOTTOMRIGHT", -32, 44)

        local edit = CreateFrame("EditBox", nil, scroll)
        edit:SetMultiLine(true)
        edit:SetFontObject(ChatFontNormal)
        edit:SetWidth(440)
        edit:SetAutoFocus(false)
        edit:SetScript("OnEscapePressed", function() ieDialog:Hide() end)
        scroll:SetScrollChild(edit)
        ieDialog.edit = edit

        ieDialog.copyBtn = MakeButton(ieDialog, "Alles markieren", 130, 22,
            function()
                ieDialog.edit:HighlightText()
                ieDialog.edit:SetFocus()
            end)
        ieDialog.copyBtn:SetPoint("BOTTOMLEFT", 12, 12)

        ieDialog.importBtn = MakeButton(ieDialog, "Importieren", 110, 22,
            function()
                if ieDialog.onImport then
                    ieDialog.onImport(ieDialog.edit:GetText())
                end
                ieDialog:Hide()
            end)
        ieDialog.importBtn:SetPoint("BOTTOMRIGHT", -12, 12)
    end

    ieDialog.title:SetText(title)
    ieDialog.edit:SetText(defaultText or "")
    ieDialog.onImport = onImport
    ieDialog.importBtn:SetShown(allowImport == true)
    ieDialog:Show()
    if not allowImport then
        ieDialog.edit:HighlightText()
        ieDialog.edit:SetFocus()
    end
end

-- ============================================================
--  PUBLIC API
-- ============================================================

function OPT:Show()
    main:Show()
    profLabel:SetText("Profil: "..(VuloUI_NameplatesDB.activeProfile or "?"))
    ShowTab(activeTab)
end

function OPT:Hide()
    main:Hide()
end

function OPT:Toggle()
    if main:IsShown() then self:Hide() else self:Show() end
end

-- Settings-Panel registrieren (Retail Settings API)
local function RegisterSettings()
    local category = Settings.RegisterCanvasLayoutCategory(
        CreateFrame("Frame"), "VuloUI Nameplates")
    category.ID = "VuloUI_Nameplates"
    Settings.RegisterAddOnCategory(category)

    -- Stub-Frame mit Button "Open Designer"
    local sub = category:GetLayout()
    -- Falls layout-API nicht verfügbar: einfach ein Button frame
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local stub = CreateFrame("Frame")
        stub.name = "VuloUI Nameplates"
        local btn = CreateFrame("Button", nil, stub, "UIPanelButtonTemplate")
        btn:SetSize(180, 26)
        btn:SetPoint("TOPLEFT", 16, -16)
        btn:SetText("Designer öffnen")
        btn:SetScript("OnClick", function() OPT:Show() end)
        local txt = stub:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        txt:SetPoint("TOPLEFT", btn, "BOTTOMLEFT", 0, -12)
        txt:SetText("Öffne den Designer für alle Einstellungen.\nOder nutze /vnp im Chat.")
        txt:SetJustifyH("LEFT")

        local cat = Settings.RegisterCanvasLayoutCategory(stub, "VuloUI Nameplates")
        cat.ID = "VuloUI_Nameplates"
        Settings.RegisterAddOnCategory(cat)
    end
end)