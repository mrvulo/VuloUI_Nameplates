-- ============================================================
--  VuloUI_Nameplates - Engine
--  Plater-style Nameplates für WoW Midnight 12.0.5
--  Autarkes Modul mit eigenen Profilen, Spec-Switch,
--  Mod-Hooks und Import/Export
-- ============================================================

if not VuloUI then
    print("|cffFF6060VuloUI_Nameplates:|r VuloUI Core nicht gefunden!")
    return
end

local ADDON_NAME = ...
local V          = VuloUI
local LSM        = LibStub("LibSharedMedia-3.0")
local LibDeflate = LibStub("LibDeflate")
local LibSer     = LibStub("LibSerialize")

local NP = {}
NP.plates    = {}   -- unitToken -> frame
NP.allPlates = {}   -- weak list aller je erstellten Plates
V:RegisterModule("Nameplates", NP)

-- Expose global für Options-Datei
VuloUI_Nameplates = NP

-- ============================================================
--  PIXEL-PERFECT
-- ============================================================

local function P(v)
    local s = UIParent:GetEffectiveScale()
    return math.floor(v * s + 0.5) / s
end

-- ============================================================
--  SECRET-VALUE HELPERS (Midnight 12.0 / Anti-Snitch)
--  Pattern aus DandersFrames/LibCustomGlow:
--  - issecretvalue(x) prüft ob ein einzelner Wert secret ist
--  - canaccesstable(t) prüft ob eine Tabelle mit secret-Keys ist
--  Beide existieren erst ab WoW 12.0 - graceful fallback für ältere.
-- ============================================================

local issecretvalue  = _G.issecretvalue  or function() return false end
local canaccesstable = _G.canaccesstable or function() return true end

-- Helper: Liefert den Wert wenn nicht secret, sonst nil.
-- So können wir `if SafeNum(x) and SafeNum(x) > 0 then` schreiben
-- ohne pcall, weil bei secret values einfach nil rauskommt.
local function SafeNum(x)
    if x == nil then return nil end
    if issecretvalue(x) then return nil end
    if type(x) ~= "number" then return nil end
    return x
end

-- ============================================================
--  FARB-KONSTANTEN
-- ============================================================

local CLASS_COLORS = {
    WARRIOR={.78,.61,.43}, PALADIN={.96,.55,.73},
    HUNTER={.67,.83,.45},  ROGUE={1,.96,.41},
    PRIEST={1,1,1},        SHAMAN={0,.44,.87},
    MAGE={.41,.80,.94},    WARLOCK={.53,.53,.93},
    DRUID={1,.49,.04},     DEATHKNIGHT={.77,.12,.23},
    MONK={0,1,.59},        DEMONHUNTER={.64,.19,.79},
    EVOKER={.20,.58,.50},
}

local DEBUFF_TYPE_COLORS = {
    Magic   = {0.20, 0.60, 1.00},
    Curse   = {0.60, 0.00, 1.00},
    Disease = {0.60, 0.40, 0.00},
    Poison  = {0.00, 0.60, 0.00},
    none    = {0.80, 0.00, 0.00},
}

-- ============================================================
--  DEFAULT-PROFIL
--  Wird beim ersten Start angelegt. Alle Settings hier.
-- ============================================================

local function DefaultProfile()
    return {
        -- Allgemein
        enabled            = true,
        width              = 200,
        height             = 14,
        castbarHeight      = 10,
        scale              = 1.0,
        clickThrough       = false,

        -- Texture & Font
        barTexture         = "Blizzard",
        font               = "Friz Quadrata TT",
        fontSize           = 10,
        fontOutline        = "OUTLINE",  -- NONE, OUTLINE, THICKOUTLINE
        fontShadow         = true,

        -- Farben (Reaktion)
        classColorPlayers  = true,
        useReactionColors  = true,
        colorFriendly      = {0.20, 0.80, 0.20},
        colorNeutral       = {0.90, 0.85, 0.20},
        colorEnemy         = {0.90, 0.20, 0.20},
        colorTapped        = {0.50, 0.50, 0.50},
        colorCaster        = {0.23, 0.51, 0.96},
        colorMiniBoss      = {0.52, 0.24, 0.98},
        colorBackground    = {0.04, 0.04, 0.04, 1.00},
        colorBorder        = {0.08, 0.08, 0.08, 1.00},

        -- Quest-Mob Farbe
        questMobColorEnabled = false,
        questMobColor      = {0.16, 0.86, 0.48},

        -- Texte
        showName           = true,
        maxNameLength      = 16,
        showLevel          = true,
        showHealthPercent  = true,
        showHealthAbsolute = false,
        abbreviateNumbers  = true,
        nameYOffset        = 0,
        nameTextSize       = 11,

        -- Threat
        showThreat         = true,
        threatMode         = "auto",  -- auto, tank, dps
        threatGlowSize     = 2,
        colorThreatNone    = {0.69, 0.69, 0.69},
        colorThreatLow     = {1.00, 0.75, 0.10},
        colorThreatMid     = {1.00, 0.45, 0.10},
        colorThreatHigh    = {1.00, 0.10, 0.10},
        colorThreatTank    = {0.10, 0.90, 0.10},
        colorThreatOffTank = {0.10, 0.50, 1.00},
        offTankAggroEnabled = true,
        tankHasAggroEnabled = false,

        -- Castbar
        showCastbar        = true,
        showCastIcon       = true,
        showCastSpark      = true,
        castIconScale      = 1.0,
        castNameSize       = 10,
        castNameColor      = {1, 1, 1},
        castNameOffsetX    = 0,
        castNameOffsetY    = 0,
        castTargetSize     = 10,
        castTargetClassColor = true,
        castTargetColor    = {1, 1, 1},
        showCastTimer      = true,
        castTimerSize      = 10,
        castTimerColor     = {1, 1, 1},
        castTimerOffsetX   = 0,
        castTimerOffsetY   = 0,
        colorCastNormal    = {0.90, 0.70, 0.10},
        colorCastChannel   = {0.30, 0.60, 1.00},
        colorCastUninter   = {0.50, 0.50, 0.50},
        colorCastInterrupt = {1.00, 0.20, 0.20},
        interruptReadyColor = {0.92, 0.35, 0.20},

        -- Cast-Glow (wichtige Casts hervorheben)
        importantCastGlow      = false,
        importantCastGlowColor = {1, 0.2, 0.2},

        -- Pandemic-Glow (wenn Aura kurz vor Ablauf)
        pandemicGlow       = false,
        pandemicGlowColor  = {1.0, 0.80, 0.33},

        -- Dispel-Glow (dispellable auras)
        dispelGlow         = false,
        dispelGlowColor    = {1.0, 1.0, 1.0},
        dispelGlowUseTypeColor = false,

        -- Auras (allgemein)
        showAuras          = true,
        auraCount          = 6,
        auraIconSize       = 14,
        auraSpacing        = 2,
        auraFilter         = "all",  -- mine, important, all
        auraWhitelist      = {},
        auraBlacklist      = {},
        auraImportant      = {},

        -- Aura-Text Größen + Farben
        auraDurationTextSize  = 11,
        auraDurationTextColor = {1, 1, 1},
        auraStackTextSize     = 11,
        auraStackTextColor    = {1, 1, 1},
        showAuraDuration      = true,
        showAuraStacks        = true,

        -- Aura-Slot-Positionen (6 Positionen rund ums Nameplate)
        auraSlots = {
            top      = { enabled = true,  kind = "debuffs"    },
            left     = { enabled = true,  kind = "buffs"      },
            topleft  = { enabled = false, kind = "elite"      },
            right    = { enabled = true,  kind = "ccs"        },
            topright = { enabled = false, kind = "raidmarker" },
            bottom   = { enabled = true,  kind = "none"       },
        },

        -- Pro Slot: Größe + X/Y Offset
        topSlotSize        = 26, topSlotXOffset    = 0, topSlotYOffset    = 0,
        rightSlotSize      = 24, rightSlotXOffset  = 2, rightSlotYOffset  = 0,
        leftSlotSize       = 24, leftSlotXOffset   = 2, leftSlotYOffset   = 0,
        toprightSlotSize   = 24, toprightSlotXOffset = 0, toprightSlotYOffset = 0,
        topleftSlotSize    = 24, topleftSlotXOffset  = 0, topleftSlotYOffset  = 0,
        bottomSlotSize     = 26, bottomSlotXOffset = 0, bottomSlotYOffset = 0,

        -- Target
        targetHighlight    = true,
        targetGlowColor    = {1, 1, 1, 1},
        targetGlowStyle    = "vului",  -- vului, blizzard
        targetScale        = 115,        -- in % (für Slider)
        nonTargetAlpha     = 0.85,
        showTargetArrows   = false,
        targetArrowScale   = 1.0,

        -- Focus
        focusColorEnabled  = true,
        focusColor         = {0.05, 0.82, 0.62},
        focusOverlayAlpha  = 0.40,

        -- Execute Range
        showExecute        = true,
        executeThreshold   = 35,
        executeColor       = {1.00, 0.30, 0.30},

        -- Hash Line (Markierungs-Linie bei % HP)
        hashLineEnabled    = false,
        hashLinePercent    = 30,
        hashLineColor      = {1, 1, 1},

        -- Class Power Bar (Combo Points etc.)
        showClassPower     = false,
        classPowerPos      = "bottom",  -- bottom, top
        classPowerYOffset  = 1,
        classPowerXOffset  = 0,
        classPowerScale    = 1.0,
        classPowerClassColors = true,
        classPowerCustomColor = {1.00, 0.84, 0.30},
        classPowerBgColor  = {0.08, 0.08, 0.08, 1.0},
        classPowerEmptyColor = {0.2, 0.2, 0.2, 1.0},
        classPowerGap      = 2,

        -- Friendly NPCs / Players
        showFriendlyNPCs   = false,
        showFriendlyPlayers = true,
        friendlyNameOnly   = true,
        friendlyHealthBarHeight = 14,
        friendlyHealthBarWidth  = 150,
        classColorFriendly = true,
        friendlyBarColor   = {0.31, 0.80, 0.41},

        -- Stacking (überlappende Plates verhindern)
        stackingEnabled    = true,
        nameplateOverlapV  = 1.10,
        stackSpacingScale  = 100,

        -- Hitbox (klickbare Fläche)
        hitboxScaleX       = 100,
        hitboxScaleY       = 100,

        -- Border
        showBorder         = true,
        borderSize         = 1,

        -- Background
        bgAlpha            = 1.0,
        castBgAlpha        = 0.9,
        castBgColor        = {0.10, 0.10, 0.10},

        -- Mods (NPC-spezifische Anpassungen)
        mods               = {},
    }
end

-- ============================================================
--  SAVED VARIABLES & PROFIL-SYSTEM
-- ============================================================

NP.db = nil  -- wird in OnInitialize gefüllt

local function GetCurrentSpecKey()
    local specIdx = GetSpecialization()
    if not specIdx then return "default" end
    local id = GetSpecializationInfo(specIdx)
    return id and ("spec" .. id) or "default"
end

function NP:GetActiveProfile()
    if not VuloUI_NameplatesDB then return DefaultProfile() end

    local profileName
    if VuloUI_NameplatesDB.specMapping
       and VuloUI_NameplatesDB.specMapping[GetCurrentSpecKey()] then
        profileName = VuloUI_NameplatesDB.specMapping[GetCurrentSpecKey()]
    else
        profileName = VuloUI_NameplatesDB.activeProfile or "Default"
    end

    if not VuloUI_NameplatesDB.profiles[profileName] then
        profileName = "Default"
    end

    return VuloUI_NameplatesDB.profiles[profileName]
end

function NP:SetActiveProfile(name)
    if not VuloUI_NameplatesDB.profiles[name] then return end
    VuloUI_NameplatesDB.activeProfile = name
    self:Reapply()
end

function NP:CreateProfile(name, copyFrom)
    if VuloUI_NameplatesDB.profiles[name] then return false end
    if copyFrom and VuloUI_NameplatesDB.profiles[copyFrom] then
        VuloUI_NameplatesDB.profiles[name] =
            CopyTable(VuloUI_NameplatesDB.profiles[copyFrom])
    else
        VuloUI_NameplatesDB.profiles[name] = DefaultProfile()
    end
    return true
end

function NP:DeleteProfile(name)
    if name == "Default" then return false end
    VuloUI_NameplatesDB.profiles[name] = nil
    if VuloUI_NameplatesDB.activeProfile == name then
        VuloUI_NameplatesDB.activeProfile = "Default"
    end
    -- Spec-Mapping aufräumen
    for k, v in pairs(VuloUI_NameplatesDB.specMapping or {}) do
        if v == name then VuloUI_NameplatesDB.specMapping[k] = nil end
    end
    self:Reapply()
    return true
end

function NP:GetProfileList()
    local list = {}
    for name in pairs(VuloUI_NameplatesDB.profiles) do
        table.insert(list, name)
    end
    table.sort(list)
    return list
end

-- ============================================================
--  HELPER
-- ============================================================

local function GetBarTex(profile)
    return LSM:Fetch("statusbar", profile.barTexture or "Blizzard")
        or "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetFont(profile)
    return LSM:Fetch("font", profile.font or "Friz Quadrata TT")
        or STANDARD_TEXT_FONT
end

local function FormatHP(hp, abbreviate)
    -- Defense: nur normale Zahlen verarbeiten, sonst leerer String
    if type(hp) ~= "number" then return "" end
    if not abbreviate then return tostring(hp) end
    if hp >= 1e6 then return string.format("%.1fM", hp / 1e6)
    elseif hp >= 1e3 then return string.format("%.0fk", hp / 1e3)
    else return tostring(hp) end
end

local function GetUnitNpcID(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

-- Helper: liest entweder den Color-Picker-Wert (profile.colors[key])
-- oder den Default-Profile-Wert (z.B. profile.colorEnemy).
-- ColorPickers speichern als {r,g,b,a}-Tabelle, Profile als {1,2,3,a}-Array.
local function ReadColor(profile, pickerKey, fallbackKey)
    -- Priorität: ColorPicker-Wert (aus ConfigUI) > Profile-Default
    if profile.colors and profile.colors[pickerKey] then
        local c = profile.colors[pickerKey]
        if c.r then
            return c.r, c.g, c.b, c.a or 1
        elseif c[1] then
            return c[1], c[2], c[3], c[4] or 1
        end
    end
    -- Fallback: Profile-Default (Tabelle mit indices)
    local fb = profile[fallbackKey]
    if fb then
        return fb[1], fb[2], fb[3], fb[4] or 1
    end
    return 1, 1, 1, 1
end

local function GetReactionColor(unit, profile)
    if UnitIsTapDenied(unit) then
        return ReadColor(profile, "tapped", "colorTapped")
    end

    -- Quest-Mob-Color (höhere Priorität als Reaktion)
    if profile.questMobColorEnabled and IsUnitQuestMob and IsUnitQuestMob(unit) then
        return ReadColor(profile, "questMob", "questMobColor")
    end

    local r = UnitReaction(unit, "player")
    if not r then return ReadColor(profile, "hostileHP", "colorEnemy") end
    if r >= 5 then return ReadColor(profile, "friendlyHP", "colorFriendly")
    elseif r == 4 then return ReadColor(profile, "neutralHP", "colorNeutral")
    else return ReadColor(profile, "hostileHP", "colorEnemy") end
end

local function GetHealthColor(unit, profile)
    if UnitIsPlayer(unit) and profile.classColorPlayers then
        local _, class = UnitClass(unit)
        local c = CLASS_COLORS[class]
        if c then return c[1], c[2], c[3] end
    end
    if profile.useReactionColors then
        return GetReactionColor(unit, profile)
    end
    return ReadColor(profile, "hostileHP", "colorEnemy")
end

-- Helper: prüft ob ein Unit ein Quest-Mob ist (Quest-Marker)
function IsUnitQuestMob(unit)
    local ok, isQuest = pcall(function()
        if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
            return C_QuestLog.UnitIsRelatedToActiveQuest(unit)
        end
        return false
    end)
    return ok and isQuest
end

-- ============================================================
--  MOD-SYSTEM
--  Wendet Mods auf eine Plate an basierend auf Triggern.
-- ============================================================

local function CheckModTrigger(mod, unit, plate)
    local t = mod.trigger
    if not t then return false end

    -- Alle Vergleiche in pcall: einige Felder (spellId etc.) können
    -- secret values sein. Equality ist erlaubt, aber sicherer mit Schutz.
    local ok, result = pcall(function()
        if t.type == "npcid" then
            return GetUnitNpcID(unit) == tonumber(t.value)

        elseif t.type == "npcname" then
            return UnitName(unit) == t.value

        elseif t.type == "spellcast" then
            if not plate.casting then return false end
            return plate.castSpellName == t.value
                or plate.castSpellID == tonumber(t.value)

        elseif t.type == "aurapresent" then
            local valNum = tonumber(t.value)
            local idx = 1
            while idx <= 40 do
                local d = C_UnitAuras.GetAuraDataByIndex(unit, idx, "HARMFUL")
                if not d then
                    d = C_UnitAuras.GetAuraDataByIndex(unit, idx, "HELPFUL")
                end
                if not d then break end
                if (valNum and d.spellId == valNum) or
                   d.name == t.value then
                    return true
                end
                idx = idx + 1
            end
            return false
        end
        return false
    end)

    return ok and result or false
end

local function ApplyModAction(action, plate, profile)
    local t = action.type

    if t == "setcolor" and action.color then
        plate.hpBar:SetStatusBarColor(unpack(action.color))
        plate.modHealthOverride = true

    elseif t == "setborder" and action.color then
        plate.threatGlow:SetBackdropBorderColor(unpack(action.color))
        plate.modBorderOverride = true

    elseif t == "setscale" and action.value then
        plate:SetScale(action.value)

    elseif t == "glow" and action.color then
        plate.threatGlow:SetBackdropBorderColor(unpack(action.color))
        plate.modBorderOverride = true

    elseif t == "hide" then
        plate:Hide()

    elseif t == "important" and action.text then
        if not plate.modText then
            plate.modText = plate:CreateFontString(nil, "OVERLAY")
            plate.modText:SetFont(GetFont(profile),
                P((profile.fontSize or 10) + 4), "THICKOUTLINE")
            plate.modText:SetPoint("BOTTOM", plate, "TOP", 0, P(2))
        end
        plate.modText:SetText(action.text)
        if action.color then
            plate.modText:SetTextColor(unpack(action.color))
        end
        plate.modText:Show()
    end
end

local function ApplyMods(plate, unit, profile)
    plate.modHealthOverride = false
    plate.modBorderOverride = false
    if plate.modText then plate.modText:Hide() end
    plate:SetScale(profile.scale or 1.0)

    for _, mod in ipairs(profile.mods or {}) do
        if mod.enabled and CheckModTrigger(mod, unit, plate) then
            for _, action in ipairs(mod.actions or {}) do
                ApplyModAction(action, plate, profile)
            end
        end
    end
end

-- ============================================================
--  AURA-FILTER
-- ============================================================

local function ShouldShowAura(auraData, profile)
    if not auraData then return false end
    if not canaccesstable(auraData) then return false end

    local id = auraData.spellId

    -- Blacklist nur wenn id sicher als Tabellen-Key nutzbar
    if id ~= nil and not issecretvalue(id) and profile.auraBlacklist[id] then
        return false
    end

    -- sourceUnit kann ein secret value sein - UnitIsUnit verbietet das.
    -- Helper der nur dann checked wenn sicher.
    local src = auraData.sourceUnit
    local function isMine()
        if src == nil or issecretvalue(src) then return false end
        return UnitIsUnit(src, "player")
    end

    if profile.auraFilter == "all" then
        return true

    elseif profile.auraFilter == "mine" then
        return isMine()

    elseif profile.auraFilter == "important" then
        if isMine() then return true end
        if id ~= nil and not issecretvalue(id) then
            if profile.auraImportant[id] or profile.auraWhitelist[id] then
                return true
            end
        end
        return false
    end

    return false
end

-- ============================================================
--  NAMEPLATE BUILDER
-- ============================================================

local function BuildNameplate(baseFrame, unit)
    local profile = NP:GetActiveProfile()
    if not profile then return nil end
    local w   = P(profile.width)
    local h   = P(profile.height)
    local cbh = P(profile.castbarHeight)

    local f = CreateFrame("Frame", nil, baseFrame, "BackdropTemplate")
    f:SetSize(w, h + cbh + P(20))
    f:SetPoint("CENTER", baseFrame, "CENTER", 0, 0)
    f:SetFrameLevel(baseFrame:GetFrameLevel() + 10)
    f:SetScale(profile.scale or 1.0)

    -- ── HP-CONTAINER ─────────────────────────────────────────
    local hpContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hpContainer:SetSize(w, h)
    hpContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    hpContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(1),
    })
    hpContainer:SetBackdropColor(unpack(profile.colorBackground))
    hpContainer:SetBackdropBorderColor(unpack(profile.colorBorder))

    local hpBar = CreateFrame("StatusBar", nil, hpContainer)
    hpBar:SetSize(w - P(2), h - P(2))
    hpBar:SetPoint("LEFT", hpContainer, "LEFT", P(1), 0)
    hpBar:SetStatusBarTexture(GetBarTex(profile))
    hpBar:SetMinMaxValues(0, 1)
    hpBar:SetValue(1)

    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.04, 0.04, 0.04, 1)

    -- Absorb
    local absorbBar = CreateFrame("StatusBar", nil, hpContainer)
    absorbBar:SetSize(w - P(2), h - P(2))
    absorbBar:SetPoint("LEFT", hpBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    absorbBar:SetStatusBarTexture(GetBarTex(profile))
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetStatusBarColor(0.85, 0.85, 1.00, 0.7)

    -- Execute-Indikator (gefüllter Hintergrund bei niedriger HP)
    local executeBg = hpBar:CreateTexture(nil, "BORDER")
    executeBg:SetAllPoints(hpBar)
    executeBg:SetColorTexture(unpack(profile.executeColor))
    executeBg:SetAlpha(0.15)
    executeBg:Hide()

    -- ── TEXTE ────────────────────────────────────────────────
    local function MakeFS(parent, size)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        local outline = profile.fontOutline ~= "NONE" and profile.fontOutline or ""
        fs:SetFont(GetFont(profile), P(size or profile.fontSize), outline)
        if profile.fontShadow then
            fs:SetShadowColor(0, 0, 0, 1)
            fs:SetShadowOffset(P(1), -P(1))
        end
        return fs
    end

    local nameText  = MakeFS(hpBar, profile.fontSize)
    nameText:SetPoint("LEFT", hpBar, "LEFT", P(4), 0)
    nameText:SetTextColor(1, 1, 1)

    local levelText = MakeFS(hpBar, profile.fontSize - 1)
    levelText:SetPoint("RIGHT", hpBar, "RIGHT", -P(4), 0)

    local hpText    = MakeFS(hpBar, profile.fontSize - 1)
    hpText:SetPoint("RIGHT", levelText, "LEFT", -P(4), 0)
    hpText:SetTextColor(0.9, 0.9, 0.9)

    -- Elite-Icon
    local eliteIcon = hpContainer:CreateTexture(nil, "OVERLAY")
    eliteIcon:SetSize(P(14), P(14))
    eliteIcon:SetPoint("LEFT", hpContainer, "RIGHT", P(3), 0)
    eliteIcon:Hide()

    -- Threat-Glow
    local threatGlow = CreateFrame("Frame", nil, hpContainer, "BackdropTemplate")
    threatGlow:SetPoint("TOPLEFT",     hpContainer, "TOPLEFT",     -P(2), P(2))
    threatGlow:SetPoint("BOTTOMRIGHT", hpContainer, "BOTTOMRIGHT",  P(2), -P(2))
    threatGlow:SetBackdrop({
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(profile.threatGlowSize or 2),
    })
    threatGlow:SetBackdropBorderColor(0, 0, 0, 0)
    threatGlow:SetFrameLevel(hpContainer:GetFrameLevel() - 1)

    -- Target-Highlight (zusätzlicher äußerer Glow)
    local targetGlow = CreateFrame("Frame", nil, hpContainer, "BackdropTemplate")
    targetGlow:SetPoint("TOPLEFT",     hpContainer, "TOPLEFT",     -P(4), P(4))
    targetGlow:SetPoint("BOTTOMRIGHT", hpContainer, "BOTTOMRIGHT",  P(4), -P(4))
    targetGlow:SetBackdrop({
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(2),
    })
    targetGlow:SetBackdropBorderColor(unpack(profile.targetGlowColor))
    targetGlow:SetFrameLevel(hpContainer:GetFrameLevel() - 2)
    targetGlow:Hide()

    -- ── CASTBAR ──────────────────────────────────────────────
    local castContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    castContainer:SetSize(w, cbh)
    castContainer:SetPoint("TOP", hpContainer, "BOTTOM", 0, -P(2))
    castContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(1),
    })
    castContainer:SetBackdropColor(unpack(profile.colorBackground))
    castContainer:SetBackdropBorderColor(unpack(profile.colorBorder))

    local castBar = CreateFrame("StatusBar", nil, castContainer)
    castBar:SetSize(w - P(2), cbh - P(2))
    castBar:SetPoint("LEFT", castContainer, "LEFT", P(1), 0)
    castBar:SetStatusBarTexture(GetBarTex(profile))
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)

    local castBg = castBar:CreateTexture(nil, "BACKGROUND")
    castBg:SetAllPoints()
    castBg:SetColorTexture(0.04, 0.04, 0.04, 1)

    local castText = MakeFS(castBar, profile.fontSize - 2)
    castText:SetPoint("LEFT", castBar, "LEFT", P(3), 0)
    castText:SetTextColor(1, 0.95, 0.8)

    -- Cast-Timer (rechts in der Castbar)
    local castTimer = MakeFS(castBar, profile.fontSize - 2)
    castTimer:SetPoint("RIGHT", castBar, "RIGHT", -P(3), 0)
    castTimer:SetTextColor(1, 1, 1)

    -- Cast-Target (über der Castbar; zeigt wen der Mob castet)
    local castTarget = MakeFS(castContainer, profile.fontSize - 2)
    castTarget:SetPoint("BOTTOM", castContainer, "TOP", 0, P(2))
    castTarget:SetTextColor(1, 1, 1)
    castTarget:Hide()

    local castIcon = castContainer:CreateTexture(nil, "ARTWORK")
    castIcon:SetSize(cbh, cbh)
    castIcon:SetPoint("RIGHT", castContainer, "LEFT", -P(2), 0)
    castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local interruptBar = castContainer:CreateTexture(nil, "OVERLAY")
    interruptBar:SetSize(P(2), cbh)
    interruptBar:SetPoint("LEFT", castContainer, "LEFT", 0, 0)
    interruptBar:SetColorTexture(0.9, 0.7, 0.1, 1)

    local castSpark = castBar:CreateTexture(nil, "OVERLAY")
    castSpark:SetSize(P(2), cbh + P(2))
    castSpark:SetColorTexture(1, 1, 1, 0.9)
    castSpark:SetPoint("CENTER", castBar:GetStatusBarTexture(), "RIGHT", 0, 0)

    -- OnUpdate für den Cast-Timer-Text. Liest die verbleibende Zeit aus
    -- der TimerDuration-API (secret-safe) und schreibt sie in castTimer.
    castBar:SetScript("OnUpdate", function(self, elapsed)
        self._timerElapsed = (self._timerElapsed or 0) + elapsed
        if self._timerElapsed < 0.05 then return end
        self._timerElapsed = 0

        if not f.casting then return end
        if not f.castTimer or not f.castTimer:IsShown() then return end

        local remaining
        if self.GetTimerDuration then
            local ok, durObj = pcall(self.GetTimerDuration, self)
            if ok and durObj and durObj.GetRemainingDuration then
                local r = durObj:GetRemainingDuration()
                if r and not issecretvalue(r) then
                    remaining = r
                end
            end
        end

        if remaining and remaining > 0 then
            f.castTimer:SetText(string.format("%.1f", remaining))
        else
            f.castTimer:SetText("")
        end
    end)

    -- Cast-Glow für wichtige Casts (Texture-Layer über CastBar)
    local castGlow = castContainer:CreateTexture(nil, "OVERLAY", nil, 7)
    castGlow:SetPoint("TOPLEFT",     castContainer, "TOPLEFT",     -P(3), P(3))
    castGlow:SetPoint("BOTTOMRIGHT", castContainer, "BOTTOMRIGHT",  P(3), -P(3))
    castGlow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    castGlow:SetBlendMode("ADD")
    castGlow:Hide()

    castContainer:Hide()

    -- ── AURA-SLOTS (6 Positionen mit je einem Icon) ──────────
    -- Slots: top, left, topleft, right, topright, bottom
    -- Jeder Slot zeigt EIN Icon, abhängig vom auraSlots[id].kind:
    --   debuffs    -> wichtigstes Debuff
    --   buffs      -> wichtigstes Buff
    --   ccs        -> aktiver CC
    --   raidmarker -> Raid-Symbol (Stern/Mond/etc.)
    --   elite      -> Elite/Rare-Indikator
    --   none       -> nichts (Slot bleibt leer)

    -- Default-Slot-Größe (wird in ApplySlotSize live überschrieben)
    local SLOT_SIZE = P(profile.auraIconSize + 4)
    local MAX_ICONS_PER_SLOT = 2
    local ICON_SPACING = 2

    -- Erstellt EIN einzelnes Aura-Icon (Sub-Frame eines Slot-Containers)
    local function CreateAuraIcon(parent)
        local icon = CreateFrame("Frame", nil, parent, "BackdropTemplate")
        icon:SetSize(SLOT_SIZE, SLOT_SIZE)
        icon:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = P(1),
        })
        icon:SetBackdropColor(0, 0, 0, 1)
        icon:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetPoint("TOPLEFT",     icon, "TOPLEFT",     P(1), -P(1))
        icon.tex:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -P(1), P(1))
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints(icon.tex)
        icon.cd:SetDrawEdge(false)
        icon.cd:SetSwipeColor(0, 0, 0, 0.75)

        icon.count = MakeFS(icon, profile.fontSize - 2)
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", P(1), P(1))
        icon.count:SetTextColor(1, 1, 1)

        icon.duration = MakeFS(icon, profile.fontSize - 2)
        icon.duration:SetPoint("TOP", icon, "TOP", 0, P(8))
        icon.duration:SetTextColor(1, 1, 1)
        icon.duration:Hide()

        icon.glow = icon:CreateTexture(nil, "OVERLAY", nil, 7)
        icon.glow:SetPoint("TOPLEFT",     icon, "TOPLEFT",     -P(2), P(2))
        icon.glow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT",  P(2), -P(2))
        icon.glow:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
        icon.glow:SetBlendMode("ADD")
        icon.glow:Hide()

        icon:Hide()
        return icon
    end

    -- Erstellt einen Slot-Container der bis zu MAX_ICONS_PER_SLOT Icons hält.
    -- Die Icons sind horizontal nebeneinander angeordnet.
    local function CreateSlotIcon()
        local slot = CreateFrame("Frame", nil, f)
        slot.icons = {}
        for i = 1, MAX_ICONS_PER_SLOT do
            slot.icons[i] = CreateAuraIcon(slot)
        end
        slot:Hide()
        return slot
    end

    -- Slot-Anker: Position relativ zum Nameplate.
    -- Liest jetzt auch die per-Slot-Offsets aus dem Profile, plus
    -- per-Slot Alignment ("left" / "center" / "right" für top/bottom,
    -- "top" / "center" / "bottom" für left/right).
    local function AnchorSlot(slot, slotID, p)
        p = p or NP:GetActiveProfile()
        slot:ClearAllPoints()

        local xOff = SafeNum(p[slotID.."SlotXOffset"]) or 0
        local yOff = SafeNum(p[slotID.."SlotYOffset"]) or 0

        -- Default-Alignment je nach Slot:
        --   top       → "right" (rechtsbündig wie im Bild)
        --   bottom    → "center"
        --   left/right → "center"
        --   topleft   → "left" (an HP-Bar Linke Seite)
        --   topright  → "right"
        local defaultAlign = "center"
        if slotID == "top"      then defaultAlign = "right" end
        if slotID == "topleft"  then defaultAlign = "left"  end
        if slotID == "topright" then defaultAlign = "right" end
        local align = p[slotID.."SlotAlign"] or defaultAlign

        if     slotID == "top" then
            -- Top kann links/zentriert/rechts an HP-Bar ankern
            if align == "left" then
                slot:SetPoint("BOTTOMLEFT", hpContainer, "TOPLEFT",
                    P(xOff), P(2 + yOff))
            elseif align == "right" then
                slot:SetPoint("BOTTOMRIGHT", hpContainer, "TOPRIGHT",
                    P(xOff), P(2 + yOff))
            else
                slot:SetPoint("BOTTOM", hpContainer, "TOP",
                    P(xOff), P(2 + yOff))
            end

        elseif slotID == "bottom" then
            if align == "left" then
                slot:SetPoint("TOPLEFT", castContainer, "BOTTOMLEFT",
                    P(xOff), P(-2 + yOff))
            elseif align == "right" then
                slot:SetPoint("TOPRIGHT", castContainer, "BOTTOMRIGHT",
                    P(xOff), P(-2 + yOff))
            else
                slot:SetPoint("TOP", castContainer, "BOTTOM",
                    P(xOff), P(-2 + yOff))
            end

        elseif slotID == "left" then
            -- Left kann oben/zentriert/unten ankern
            if align == "top" then
                slot:SetPoint("TOPRIGHT", hpContainer, "TOPLEFT",
                    P(-2 + xOff), P(yOff))
            elseif align == "bottom" then
                slot:SetPoint("BOTTOMRIGHT", hpContainer, "BOTTOMLEFT",
                    P(-2 + xOff), P(yOff))
            else
                slot:SetPoint("RIGHT", hpContainer, "LEFT",
                    P(-2 + xOff), P(yOff))
            end

        elseif slotID == "right" then
            if align == "top" then
                slot:SetPoint("TOPLEFT", hpContainer, "TOPRIGHT",
                    P(2 + xOff), P(yOff))
            elseif align == "bottom" then
                slot:SetPoint("BOTTOMLEFT", hpContainer, "BOTTOMRIGHT",
                    P(2 + xOff), P(yOff))
            else
                slot:SetPoint("LEFT", hpContainer, "RIGHT",
                    P(2 + xOff), P(yOff))
            end

        elseif slotID == "topleft" then
            -- Über HP-Bar links-bündig (wachsen nach rechts ist default)
            slot:SetPoint("BOTTOMLEFT", hpContainer, "TOPLEFT",
                P(xOff), P(2 + yOff))

        elseif slotID == "topright" then
            -- Über HP-Bar rechts-bündig (wachsen nach links ist default)
            slot:SetPoint("BOTTOMRIGHT", hpContainer, "TOPRIGHT",
                P(xOff), P(2 + yOff))
        end
    end

    -- Slot-Größe aus dem Profile lesen + setzen.
    -- Berechnet Container-Breite (Icons * Größe + Spacing) und positioniert
    -- die Sub-Icons horizontal nebeneinander. Wachstumsrichtung je nach
    -- Slot-Position so dass sie nicht in das Plate hineinwachsen.
    local function ApplySlotSize(slot, slotID, p)
        p = p or NP:GetActiveProfile()
        local sz = SafeNum(p[slotID.."SlotSize"]) or (p.auraIconSize + 4)
        if sz < 12 then sz = 12 end
        if sz > 64 then sz = 64 end

        local iconSize = P(sz)
        local spacing  = P(ICON_SPACING)
        local count    = MAX_ICONS_PER_SLOT

        -- Container-Größe (genug Platz für alle Icons)
        local totalW = count * iconSize + (count - 1) * spacing
        slot:SetSize(totalW, iconSize)

        -- Wachstumsrichtung: hängt vom Slot-Alignment ab.
        --   align=right (top): erstes Icon rechts, wächst nach links
        --   align=left  (top): erstes Icon links, wächst nach rechts
        --   align=center: zentriert, erstes Icon Mitte (default rechts wachsend)
        local defaultAlign = "center"
        if slotID == "top"      then defaultAlign = "right" end
        if slotID == "topleft"  then defaultAlign = "left"  end
        if slotID == "topright" then defaultAlign = "right" end
        local align = p[slotID.."SlotAlign"] or defaultAlign

        local growLeft = false
        -- Wenn Slot rechts-bündig: Icons wachsen nach links
        if align == "right" then growLeft = true end
        -- Top/Left default zum links wachsen für gute Optik
        if align == "center" and (slotID == "top" or slotID == "left") then
            growLeft = true
        end

        for i, ic in ipairs(slot.icons) do
            ic:SetSize(iconSize, iconSize)
            ic:ClearAllPoints()
            local offset = (i - 1) * (iconSize + spacing)
            if growLeft then
                ic:SetPoint("RIGHT", slot, "RIGHT", -offset, 0)
            else
                ic:SetPoint("LEFT", slot, "LEFT", offset, 0)
            end
        end
    end

    -- 6 Slots erstellen
    f.auraSlotFrames = {}
    for _, slotID in ipairs({"top","left","topleft","right","topright","bottom"}) do
        local slot = CreateSlotIcon()
        ApplySlotSize(slot, slotID, profile)
        AnchorSlot(slot, slotID, profile)
        f.auraSlotFrames[slotID] = slot
    end

    -- Public API: Slots refreshen wenn Settings sich ändern
    f.RefreshSlotLayout = function(self)
        local p = NP:GetActiveProfile()
        if not self.auraSlotFrames then return end
        for slotID, slot in pairs(self.auraSlotFrames) do
            ApplySlotSize(slot, slotID, p)
            AnchorSlot(slot, slotID, p)
        end
    end

    -- ── REFERENZEN ───────────────────────────────────────────
    f.unit          = unit
    f.baseFrame     = baseFrame
    f.hpContainer   = hpContainer
    f.hpBar         = hpBar
    f.hpBg          = hpBg
    f.absorbBar     = absorbBar
    f.executeBg     = executeBg
    f.nameText      = nameText
    f.levelText     = levelText
    f.hpText        = hpText
    f.eliteIcon     = eliteIcon
    f.threatGlow    = threatGlow
    f.targetGlow    = targetGlow
    f.castBar       = castBar
    f.castText      = castText
    f.castTimer     = castTimer
    f.castTarget    = castTarget
    f.castIcon      = castIcon
    f.castSpark     = castSpark
    f.castGlow      = castGlow
    f.castContainer = castContainer
    f.interruptBar  = interruptBar
    f.casting       = false
    f.endTime       = 0
    f.maxTime       = 0

    -- ── UPDATE-FUNKTIONEN ────────────────────────────────────

    -- HealPrediction-Calculator (oUF/Platynator-Pattern für Midnight 12.0).
    if CreateUnitHealPredictionCalculator then
        f.healCalc = CreateUnitHealPredictionCalculator()
        if f.healCalc.SetMaximumHealthMode then
            f.healCalc:SetMaximumHealthMode(Enum.UnitMaximumHealthMode.Default)
        end
    end

    function f:UpdateHealth()
        local p = NP:GetActiveProfile()
        if not UnitExists(unit) then return end

        -- ============================================================
        -- HP-BAR: Werte mit Calculator holen, an Bar reichen.
        -- ALLE numerischen Vergleiche/Arithmetik in pcall verpacken,
        -- weil cur/max in extremen Fällen (Boss-Phasen) noch secret
        -- sein können.
        -- ============================================================
        local barOk = pcall(function()
            if self.healCalc and UnitGetDetailedHealPrediction then
                UnitGetDetailedHealPrediction(unit, nil, self.healCalc)
                local maxH = self.healCalc:GetMaximumHealth()
                local curH = self.healCalc:GetCurrentHealth()
                self.hpBar:SetMinMaxValues(0, maxH)
                self.hpBar:SetValue(curH)
            else
                -- Fallback: direkt SetValue mit raw API
                self.hpBar:SetMinMaxValues(0, UnitHealthMax(unit) or 1)
                self.hpBar:SetValue(UnitHealth(unit) or 0)
            end
        end)
        if not barOk then
            -- Hartlast: Bar auf voll setzen, kein Crash
            self.hpBar:SetMinMaxValues(0, 1)
            self.hpBar:SetValue(1)
        end

        if not self.modHealthOverride then
            local r, g, b = GetHealthColor(unit, p)
            self.hpBar:SetStatusBarColor(r, g, b)
        end

        -- ============================================================
        -- HP-TEXT: nutze CurveConstants.ScaleTo100 (Danders-Pattern).
        -- Das Ergebnis kann TROTZDEM secret sein - daher mit
        -- issecretvalue() prüfen vor jedem Vergleich.
        -- SetFormattedText (C-API) frisst secret values direkt.
        -- ============================================================
        local pct
        if UnitHealthPercent and CurveConstants and CurveConstants.ScaleTo100 then
            pcall(function()
                pct = UnitHealthPercent(unit, true, CurveConstants.ScaleTo100)
            end)
        end

        -- "Sicher" = nicht-nil und nicht-secret. Erst dann darf verglichen werden.
        local pctSafe = (pct ~= nil and not issecretvalue(pct))

        if p.showHealthPercent then
            if pctSafe then
                if pct < 100 then
                    self.hpText:SetFormattedText("%d%%", pct)
                else
                    self.hpText:SetText("")
                end
            else
                -- Secret pct: SetFormattedText kann's trotzdem
                -- (C-API frisst secret values), wir können nur kein
                -- "wenn voll dann leer" machen
                if pct ~= nil then
                    pcall(function()
                        self.hpText:SetFormattedText("%d%%", pct)
                    end)
                else
                    self.hpText:SetText("")
                end
            end
        elseif p.showHealthAbsolute and AbbreviateNumbers then
            -- AbbreviateNumbers ist eine C-Funktion, frisst secret values
            pcall(function()
                local hp = UnitHealth(unit, true)
                if hp ~= nil then
                    self.hpText:SetText(AbbreviateNumbers(hp))
                else
                    self.hpText:SetText("")
                end
            end)
        else
            self.hpText:SetText("")
        end

        -- Execute-Range: nur wenn pct sicher vergleichbar
        if p.showExecute and pctSafe
           and pct > 0 and pct <= p.executeThreshold then
            self.executeBg:SetColorTexture(unpack(p.executeColor))
            self.executeBg:SetAlpha(0.18)
            self.executeBg:Show()
        else
            self.executeBg:Hide()
        end

        -- Absorb-Bar deaktiviert (komplex)
        self.absorbBar:SetValue(0)
    end

    function f:UpdateName()
        local p = NP:GetActiveProfile()
        if not p.showName then
            self.nameText:SetText("")
            return
        end
        local name = UnitName(unit) or ""
        local maxLen = p.maxNameLength or 16
        if #name > maxLen then name = name:sub(1, maxLen) .. ".." end
        self.nameText:SetText(name)
    end

    function f:UpdateLevel()
        local p = NP:GetActiveProfile()
        if not p.showLevel then
            self.levelText:SetText("")
            self.eliteIcon:Hide()
            return
        end
        local level   = UnitLevel(unit)
        local class   = UnitClassification(unit)
        local isBoss  = class == "worldboss" or class == "boss"
        local isRare  = class == "rare" or class == "rareelite"
        local isElite = class == "elite" or class == "rareelite"

        local color = "|cffAAAAAA"
        if isBoss        then color = "|cffFF6060"
        elseif isRare    then color = "|cffAA88FF"
        elseif level==-1 then color = "|cffFF4040" end

        local lvl = level == -1 and "??" or tostring(level)
        local suffix = ""
        if isBoss      then suffix = " |cffFF6060[B]|r"
        elseif isRare  then suffix = " |cffAA88FF[R]|r"
        elseif isElite then suffix = " |cffFFD700+|r" end

        self.levelText:SetText(color .. lvl .. "|r" .. suffix)

        if isElite or isRare then
            self.eliteIcon:SetTexture(
                "Interface\\TargetingFrame\\UI-TargetingFrame-Elite")
            self.eliteIcon:Show()
        elseif isBoss then
            self.eliteIcon:SetTexture(
                "Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
            self.eliteIcon:Show()
        else
            self.eliteIcon:Hide()
        end
    end

    function f:UpdateThreat()
        local p = NP:GetActiveProfile()
        if not p.showThreat or self.modBorderOverride then
            if not self.modBorderOverride then
                self.threatGlow:SetBackdropBorderColor(0,0,0,0)
            end
            return
        end
        if not UnitExists(unit) or not UnitCanAttack("player", unit) then
            self.threatGlow:SetBackdropBorderColor(0,0,0,0)
            return
        end

        -- status: 0/1/2/3 (oder nil oder secret value).
        -- Platynator-Pattern: UnitThreatSituation("player", unit)
        -- gibt direkt die situation. Equality (==) ist erlaubt.
        local status = UnitThreatSituation("player", unit)
        -- if-Check als nil-Test (erlaubt mit secret values seit 12.0)
        if not status then status = 0 end

        local mode = p.threatMode
        if mode == "auto" then
            mode = (UnitGroupRolesAssigned("player") == "TANK")
                   and "tank" or "dps"
        end

        local c
        if mode == "tank" then
            if     status == 3 then c = p.colorThreatTank
            elseif status == 2 then c = p.colorThreatMid
            elseif status == 1 then c = p.colorThreatMid
            elseif status == 0 then c = p.colorThreatHigh
                -- (Tank ohne Aggro = jemand anders hat Aggro = rot)
            end
        else
            if     status == 3 then c = p.colorThreatHigh
            elseif status == 2 then c = p.colorThreatMid
            elseif status == 1 then c = p.colorThreatLow
            else                    c = nil end
        end

        if c then
            self.threatGlow:SetBackdropBorderColor(c[1], c[2], c[3], 0.9)
        else
            self.threatGlow:SetBackdropBorderColor(0,0,0,0)
        end
    end

    -- ============================================================
    -- AURA-SLOTS UPDATE
    -- Pro Slot wird ein Icon angezeigt, je nach kind:
    --  - debuffs: wichtigstes harmful aura (eigene priorisiert)
    --  - buffs:   wichtigstes helpful aura (eigene priorisiert)
    --  - ccs:     aktiver CC (Stun/Root/etc)
    --  - raidmarker: Raid-Symbol-Icon
    --  - elite:   Elite/Rare-Indikator (Krone)
    --  - none:    nichts (Slot bleibt leer)
    -- ============================================================

    -- Raid-Marker Icons (Blizzard-Pfade)
    local RAIDMARKER_ICONS = {
        [1] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1", -- Star
        [2] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2", -- Circle
        [3] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3", -- Diamond
        [4] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4", -- Triangle
        [5] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5", -- Moon
        [6] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6", -- Square
        [7] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7", -- Cross
        [8] = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8", -- Skull
    }

    -- CC-Mechaniken: dispelName-typen die "CC" sind
    local CC_DISPEL_TYPES = {
        ["Magic"]   = false,  -- nicht alle Magic sind CC
        ["Curse"]   = false,
        ["Disease"] = false,
        ["Poison"]  = false,
    }
    -- Heuristik: wir nutzen besser "isCharm" / "isStealable" oder die
    -- Aura-Effekte. Da das in WoW 12 nicht direkt verfügbar ist, fallen
    -- wir auf eine Whitelist von CC-spellIDs zurück oder zeigen alle
    -- harmful auras die "control" sind.
    -- Für jetzt: zeigen ein CC wenn dispelName=="Magic" UND es eines
    -- der bekannten CC-Spells ist. Erweiterbar via profile.

    -- Apply aura data to a slot icon
    -- Befüllt EIN einzelnes Icon-Sub-Frame mit Aura-Daten.
    -- (vorher hieß die Funktion FillSlotWithAura, jetzt arbeitet sie auf
    -- einer Icon-Sub-Frame statt auf dem ganzen Slot.)
    local function FillIconWithAura(icon, d, p)
        p = p or NP:GetActiveProfile()
        icon.tex:SetTexture(d.icon)
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Border-Farbe nach Dispel-Type
        local dispel = d.dispelName
        local hasDispel = dispel and not issecretvalue(dispel)
        local c
        if hasDispel then
            c = DEBUFF_TYPE_COLORS[dispel] or DEBUFF_TYPE_COLORS.none
        else
            c = DEBUFF_TYPE_COLORS.none
        end
        icon:SetBackdropBorderColor(c[1], c[2], c[3], 1)

        -- Stack-Count
        local apps = SafeNum(d.applications)
        local showCount = (p.showAuraStacks ~= false) and apps and apps > 1
        if showCount then
            local stackSize = SafeNum(p.auraStackTextSize) or 11
            local stackColor = p.auraStackTextColor or {1, 1, 1}
            icon.count:SetFont(GetFont(p), P(stackSize), "OUTLINE")
            icon.count:SetTextColor(stackColor[1], stackColor[2], stackColor[3], 1)

            if C_UnitAuras.GetAuraApplicationDisplayCount and d.auraInstanceID then
                local stackStr = C_UnitAuras.GetAuraApplicationDisplayCount(
                    unit, d.auraInstanceID, 2, 999)
                if stackStr then
                    icon.count:SetText(stackStr)
                    icon.count:Show()
                else
                    icon.count:Hide()
                end
            else
                icon.count:SetText(apps)
                icon.count:Show()
            end
        else
            icon.count:Hide()
        end

        -- Duration-Text (für mehrere Icons NICHT zentral - aus dem
        -- Cooldown-Frame liest WoW intern, wir setzen nur Style)
        if p.showAuraDuration ~= false and icon.duration then
            local durSize  = SafeNum(p.auraDurationTextSize) or 11
            local durColor = p.auraDurationTextColor or {1, 1, 1}
            icon.duration:SetFont(GetFont(p), P(durSize), "OUTLINE")
            icon.duration:SetTextColor(durColor[1], durColor[2], durColor[3], 1)
        end

        -- Cooldown
        if C_UnitAuras.GetAuraDuration and d.auraInstanceID
           and icon.cd.SetCooldownFromDurationObject then
            local durObj = C_UnitAuras.GetAuraDuration(unit, d.auraInstanceID)
            if durObj then
                icon.cd:SetCooldownFromDurationObject(durObj)
                icon.cd:Show()
            else
                icon.cd:Hide()
            end
        else
            local dur = SafeNum(d.duration)
            local exp = SafeNum(d.expirationTime)
            if dur and exp and dur > 0 then
                icon.cd:SetCooldown(exp - dur, dur)
                icon.cd:Show()
            else
                icon.cd:Hide()
            end
        end

        -- Pandemic-Glow
        local pandemicActive = false
        if p.pandemicGlow then
            local dur = SafeNum(d.duration)
            local exp = SafeNum(d.expirationTime)
            if dur and exp and dur > 0 then
                local now = GetTime()
                local remaining = exp - now
                if remaining > 0 and remaining < dur * 0.3 then
                    pandemicActive = true
                end
            end
        end

        -- Dispel-Glow
        local dispelActive = false
        if p.dispelGlow and hasDispel then
            dispelActive = true
        end

        if icon.glow then
            if pandemicActive then
                local glowColor = (p.colors and p.colors.pandemicGlow)
                              or {1.0, 0.80, 0.33, 1}
                icon.glow:SetVertexColor(glowColor[1], glowColor[2],
                                         glowColor[3], glowColor[4] or 1)
                icon.glow:Show()
            elseif dispelActive then
                local glowColor
                if p.dispelGlowUseTypeColor and hasDispel then
                    local dc = DEBUFF_TYPE_COLORS[dispel] or DEBUFF_TYPE_COLORS.none
                    glowColor = {dc[1], dc[2], dc[3], 1}
                else
                    glowColor = (p.colors and p.colors.dispelGlow)
                            or {1, 1, 1, 1}
                end
                icon.glow:SetVertexColor(glowColor[1], glowColor[2],
                                         glowColor[3], glowColor[4] or 1)
                icon.glow:Show()
            else
                icon.glow:Hide()
            end
        end

        icon:Show()
    end

    -- Befüllt einen Slot mit einer Liste von Auras (max MAX_ICONS_PER_SLOT).
    -- Überzählige Icon-Sub-Frames werden versteckt.
    local function FillSlotWithAuraList(slot, auraList, p)
        local count = math.min(#auraList, MAX_ICONS_PER_SLOT)
        for i, icon in ipairs(slot.icons) do
            if i <= count then
                FillIconWithAura(icon, auraList[i], p)
            else
                icon:Hide()
            end
        end
        if count > 0 then
            slot:Show()
        else
            slot:Hide()
        end
    end

    -- Befüllt einen Slot mit nur einer einzelnen Aura (legacy für single-
    -- icon kinds wie raidmarker/elite).
    local function FillSlotSingle(slot, d, p)
        FillIconWithAura(slot.icons[1], d, p)
        for i = 2, #slot.icons do
            slot.icons[i]:Hide()
        end
        slot:Show()
    end

    -- Befüllt einen Slot mit einer einzelnen Texture (Raidmarker/Elite-Icon).
    -- Setzt nur das erste Icon-Sub-Frame mit der gegebenen Texture.
    local function FillSlotTexture(slot, texture, borderColor)
        local icon = slot.icons[1]
        icon.tex:SetTexture(texture)
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        if borderColor then
            icon:SetBackdropBorderColor(borderColor[1], borderColor[2],
                                        borderColor[3], 1)
        else
            icon:SetBackdropBorderColor(0, 0, 0, 0)
        end
        icon.count:Hide()
        icon.cd:Hide()
        if icon.glow then icon.glow:Hide() end
        icon:Show()
        for i = 2, #slot.icons do
            slot.icons[i]:Hide()
        end
        slot:Show()
    end

    -- Finde die wichtigste Aura eines Filter-Typs ("HARMFUL"/"HELPFUL")
    -- Priorität: 1) eigene mit Dauer, 2) Whitelist, 3) erste mit Dauer
    -- Findet bis zu maxCount Auras eines Filter-Typs, sortiert nach Priorität:
    --   1. Eigene Auras (player als source)
    --   2. Important/Whitelist Auras
    --   3. Andere Auras
    -- Returniert eine Liste, beschränkt auf maxCount Einträge.
    local function FindBestAuras(filter, p, maxCount)
        maxCount = maxCount or MAX_ICONS_PER_SLOT
        local imp = p.auraImportant or {}
        local wl  = p.auraWhitelist or {}
        local mine, important, others = {}, {}, {}

        for idx = 1, 40 do
            local d = C_UnitAuras.GetAuraDataByIndex(unit, idx, filter)
            if not d then break end
            if canaccesstable(d) and ShouldShowAura(d, p) then
                local id = d.spellId
                local idSafe = (id ~= nil and not issecretvalue(id))
                local src = d.sourceUnit
                local srcSafe = (src and not issecretvalue(src))
                local isMine = srcSafe and UnitIsUnit(src, "player")

                if isMine then
                    table.insert(mine, d)
                elseif idSafe and (imp[id] or wl[id]) then
                    table.insert(important, d)
                else
                    table.insert(others, d)
                end
            end
        end

        -- Sortiere eigene Auras nach verbleibender Zeit (längste zuerst).
        -- Dadurch sind frische DoTs zuerst, kurz vor Ablauf zuletzt.
        local now = GetTime()
        local function sortByRemaining(a, b)
            local ea = SafeNum(a.expirationTime) or 0
            local eb = SafeNum(b.expirationTime) or 0
            -- 0 (no duration) ans Ende
            if ea == 0 and eb == 0 then return false end
            if ea == 0 then return false end
            if eb == 0 then return true end
            return (ea - now) > (eb - now)
        end
        pcall(table.sort, mine, sortByRemaining)
        pcall(table.sort, important, sortByRemaining)

        -- Resultat zusammenbauen: erst mine, dann important, dann others
        local result = {}
        for _, d in ipairs(mine) do
            if #result >= maxCount then break end
            table.insert(result, d)
        end
        for _, d in ipairs(important) do
            if #result >= maxCount then break end
            table.insert(result, d)
        end
        for _, d in ipairs(others) do
            if #result >= maxCount then break end
            table.insert(result, d)
        end
        return result
    end

    -- Update einer einzelnen Slot-Position basierend auf kind
    local function UpdateSlot(slot, slotID, slotCfg, p)
        if not slotCfg or slotCfg.enabled == false then
            slot:Hide()
            return
        end

        local kind = slotCfg.kind or "none"

        if kind == "none" then
            slot:Hide()
            return

        elseif kind == "debuffs" then
            -- Bis zu MAX_ICONS_PER_SLOT Debuffs (eigene priorisiert)
            local list = FindBestAuras("HARMFUL", p, MAX_ICONS_PER_SLOT)
            if #list > 0 then
                FillSlotWithAuraList(slot, list, p)
            else
                slot:Hide()
            end

        elseif kind == "buffs" then
            local list = FindBestAuras("HELPFUL", p, MAX_ICONS_PER_SLOT)
            if #list > 0 then
                FillSlotWithAuraList(slot, list, p)
            else
                slot:Hide()
            end

        elseif kind == "ccs" then
            -- CC-Detection: alle harmful/helpful auras mit kurzer Dauer
            -- werden als CC behandelt, plus Whitelist von bekannten
            -- CC-Spell-IDs.
            local ccList = {}
            local seen = {}

            -- Whitelist bekannter CC-Spells (cross-class).
            -- Diese werden IMMER als CC behandelt, egal welche Dauer.
            -- Quelle: spells.dbc / wowhead.com - aktuelle WoW 12.0 IDs.
            local CC_SPELL_IDS = {
                -- PRIEST
                [8122]   = true,   -- Psychischer Schrei
                [605]    = true,   -- Geistesbeherrschung
                [9484]   = true,   -- Schattenkette (Shackle Undead)
                [88625]  = true,   -- Schmerzwort
                [453676] = true,   -- Psychischer Schrei (Talent-Variante)
                -- MAGE
                [118]    = true,   -- Polymorph (Schaf)
                [28272]  = true,   -- Polymorph (Schwein)
                [28271]  = true,   -- Polymorph (Schildkröte)
                [61305]  = true,   -- Polymorph (Schwarze Katze)
                [61721]  = true,   -- Polymorph (Kaninchen)
                [61780]  = true,   -- Polymorph (Truthahn)
                [126819] = true,   -- Polymorph (Stachelschwein)
                [161353] = true,   -- Polymorph (Polarbärenjunges)
                [161354] = true,   -- Polymorph (Affe)
                [161355] = true,   -- Polymorph (Pinguin)
                [161372] = true,   -- Polymorph (Pfau)
                [277787] = true,   -- Polymorph (Direhorn-Junges)
                [277792] = true,   -- Polymorph (Mottenschwarm)
                [391622] = true,   -- Polymorph (Hirsch)
                [122]    = true,   -- Frostnova
                [33395]  = true,   -- Frostige Klauen (Wasserelementar Frostnova)
                [82691]  = true,   -- Eisring
                [31661]  = true,   -- Drachenodem
                -- WARLOCK
                [5782]   = true,   -- Furcht
                [710]    = true,   -- Verbannen
                [6789]   = true,   -- Tödliche Berührung
                [6358]   = true,   -- Verführung (Sukkubus)
                [30283]  = true,   -- Schattenfuror
                [118699] = true,   -- Furcht (alt)
                -- ROGUE
                [2094]   = true,   -- Blenden
                [6770]   = true,   -- Vermöbeln
                [1776]   = true,   -- Auge graben
                [408]    = true,   -- Nierenhieb
                [1833]   = true,   -- Halsabschneider
                [51722]  = true,   -- Verstümmeln
                -- DRUID
                [339]    = true,   -- Wurzeln greifen
                [2637]   = true,   -- Winterschlaf
                [33786]  = true,   -- Wirbelwind
                [102359] = true,   -- Gewaltige Wurzeln
                [99]     = true,   -- Demoralisierendes Brüllen (Stun)
                [5211]   = true,   -- Gewaltiger Schlag
                [22570]  = true,   -- Wütender Hieb
                -- HUNTER
                [3355]   = true,   -- Eisfalle
                [19386]  = true,   -- Wyvernstich
                [19503]  = true,   -- Ausschalten
                [187650] = true,   -- Eisfalle
                [117526] = true,   -- Bindender Schuss
                [24394]  = true,   -- Einschüchterung
                -- SHAMAN
                [51514]  = true,   -- Hex (Frosch)
                [211015] = true,   -- Hex (Gockel)
                [211010] = true,   -- Hex (Schlange)
                [210873] = true,   -- Hex (Krabbe)
                [211004] = true,   -- Hex (Spinne)
                [196942] = true,   -- Hex (Voodoo Totem)
                [77505]  = true,   -- Erdstoß
                [118905] = true,   -- Eingeengter Sturmschlag
                -- WARRIOR
                [5246]   = true,   -- Einschüchterndes Gebrüll
                [132168] = true,   -- Schockwelle
                [132169] = true,   -- Sturmangriff (Stun)
                [46968]  = true,   -- Schockwelle (Talent)
                [105771] = true,   -- Sturmangriff
                [107570] = true,   -- Sturmangriff (Stun)
                -- PALADIN
                [853]    = true,   -- Hammer der Gerechtigkeit
                [10326]  = true,   -- Vertreiben des Bösen
                [105421] = true,   -- Blendendes Licht
                [20066]  = true,   -- Buße (Repentance)
                [31935]  = true,   -- Avenger's Shield (Stun)
                -- DEATH KNIGHT
                [47476]  = true,   -- Erwürgen
                [108194] = true,   -- Asphyxieren
                [221562] = true,   -- Asphyxieren (Blood)
                [207171] = true,   -- Winters Biss
                -- DEMON HUNTER
                [217832] = true,   -- Imprison
                [179057] = true,   -- Chaosnova
                [205630] = true,   -- Illidans Griff
                [211881] = true,   -- Wirbelwind
                -- MONK
                [115078] = true,   -- Lähmung (Paralysis)
                [119381] = true,   -- Bein-Sweep
                [123407] = true,   -- Wirbelnder Drachenstoß
                [202274] = true,   -- Beschwörung Niuzao
                -- EVOKER
                [360806] = true,   -- Schlummer
                [357210] = true,   -- Tiefatem (Stun)
                [355689] = true,   -- Stollwurzel
            }

            -- DEBUG-Flag: nur für Entwicklung. Auf true setzen wenn neue
            -- CC-Spells getestet werden müssen.
            local _debugCC = false

            local function checkAura(d, filterName)
                if not canaccesstable(d) then return end

                local id = SafeNum(d.spellId)
                if id and seen[id] then return end

                local dur = SafeNum(d.duration)
                local dispel = d.dispelName
                local hasDispel = dispel and not issecretvalue(dispel)
                local src = d.sourceUnit
                local srcSafe = (src and not issecretvalue(src))
                local isMine = srcSafe and UnitIsUnit(src, "player")
                local isWhitelisted = id and CC_SPELL_IDS[id]

                if _debugCC then
                    local nm = d.name
                    if nm and not issecretvalue(nm) then
                        print(string.format(
                            "  %s: name=%s id=%s dur=%s dispel=%s mine=%s wl=%s",
                            filterName, tostring(nm), tostring(id), tostring(dur),
                            tostring(dispel), tostring(isMine),
                            tostring(isWhitelisted)))
                    end
                end

                -- 1) Whitelist hat höchste Priorität - immer akzeptieren
                if isWhitelisted then
                    if id then seen[id] = true end
                    table.insert(ccList, 1, d)  -- am Anfang einfügen
                    return
                end

                -- 2) Sonst: kurze Dauer als CC behandeln
                if not dur or dur <= 0 then return end
                if dur > 15 then return end

                if id then seen[id] = true end
                table.insert(ccList, d)
            end

            for idx = 1, 40 do
                if #ccList >= MAX_ICONS_PER_SLOT then break end
                local d = C_UnitAuras.GetAuraDataByIndex(unit, idx, "HARMFUL")
                if not d then break end
                checkAura(d, "HARMFUL")
            end

            for idx = 1, 40 do
                if #ccList >= MAX_ICONS_PER_SLOT then break end
                local d = C_UnitAuras.GetAuraDataByIndex(unit, idx, "HELPFUL")
                if not d then break end
                checkAura(d, "HELPFUL")
            end

            if #ccList > 0 then
                FillSlotWithAuraList(slot, ccList, p)
            else
                slot:Hide()
            end

        elseif kind == "raidmarker" then
            local mark = GetRaidTargetIndex and GetRaidTargetIndex(unit)
            if mark and RAIDMARKER_ICONS[mark] then
                FillSlotTexture(slot, RAIDMARKER_ICONS[mark], nil)
                -- Marker brauchen keinen Border-Crop
                slot.icons[1].tex:SetTexCoord(0, 1, 0, 1)
            else
                slot:Hide()
            end

        elseif kind == "elite" then
            local classification = UnitClassification(unit)
            if classification == "elite" or classification == "rareelite" then
                FillSlotTexture(slot,
                    "Interface\\Icons\\Achievement_PVP_A_06",
                    {1.0, 0.85, 0.2})
            elseif classification == "rare" then
                FillSlotTexture(slot,
                    "Interface\\Icons\\Achievement_PVP_H_06",
                    {0.7, 0.85, 1.0})
            elseif classification == "worldboss" or classification == "boss" then
                FillSlotTexture(slot,
                    "Interface\\Icons\\Achievement_Boss_LichKing",
                    {1.0, 0.3, 0.3})
            else
                slot:Hide()
            end

        else
            slot:Hide()
        end
    end

    function f:UpdateAuras()
        local p = NP:GetActiveProfile()
        if not p.showAuras or not self.auraSlotFrames then
            if self.auraSlotFrames then
                for _, slot in pairs(self.auraSlotFrames) do slot:Hide() end
            end
            return
        end

        -- Slot-Größen + Anker live aus Profile aktualisieren
        if self.RefreshSlotLayout then
            self:RefreshSlotLayout()
        end

        local slots = p.auraSlots or {}
        for slotID, slot in pairs(self.auraSlotFrames) do
            UpdateSlot(slot, slotID, slots[slotID], p)
        end
    end

    function f:UpdateTarget()
        local p = NP:GetActiveProfile()
        if not p.targetHighlight then
            self.targetGlow:Hide()
            self:SetAlpha(1)
            return
        end
        if UnitIsUnit(unit, "target") then
            self.targetGlow:SetBackdropBorderColor(unpack(p.targetGlowColor))
            self.targetGlow:Show()
            self:SetAlpha(1)
        else
            self.targetGlow:Hide()
            if UnitExists("target") then
                self:SetAlpha(p.nonTargetAlpha or 0.85)
            else
                self:SetAlpha(1)
            end
        end
    end

    -- Castbar nutzt SetTimerDuration (Platynator-Pattern für Midnight 12.0):
    -- UnitCastingDuration(unit) gibt ein DurationObject zurück (nicht-secret).
    -- SetTimerDuration animiert die Bar intern - kein OnUpdate nötig.
    -- Kein Lua-Arithmetik, kein /1000, keine secret-value-Probleme.

    function f:StartCast(name, tex, isChannel, notInterruptible, spellID)
        local p = NP:GetActiveProfile()
        if not p.showCastbar then return end
        if not name then return end

        -- DurationObject holen
        local castDuration
        local ok = pcall(function()
            if isChannel then
                castDuration = UnitChannelDuration and UnitChannelDuration(unit)
            else
                castDuration = UnitCastingDuration and UnitCastingDuration(unit)
            end
        end)
        if not ok or not castDuration then
            -- Wenn API nicht verfügbar, Castbar nur statisch zeigen
            self.casting = false
        end

        self.casting       = castDuration ~= nil
        self.castSpellName = name
        self.castSpellID   = spellID
        self.castIsChannel = isChannel and true or false

        -- Cast-Name mit Größe + Farbe + Offset aus Profile
        do
            local sz = SafeNum(p.castNameSize) or 10
            local col = p.castNameColor or {1, 1, 1}
            local ox = SafeNum(p.castNameOffsetX) or 0
            local oy = SafeNum(p.castNameOffsetY) or 0
            self.castText:SetFont(GetFont(p), P(sz), "OUTLINE")
            self.castText:SetTextColor(col[1], col[2], col[3], 1)
            self.castText:ClearAllPoints()
            self.castText:SetPoint("LEFT", self.castBar, "LEFT",
                P(3 + ox), P(oy))
            self.castText:SetText(name or "")
        end

        -- Cast-Timer (rechts) - aktivieren wenn enabled
        if p.showCastTimer ~= false and self.castTimer then
            local sz = SafeNum(p.castTimerSize) or 10
            local col = p.castTimerColor or {1, 1, 1}
            local ox = SafeNum(p.castTimerOffsetX) or 0
            local oy = SafeNum(p.castTimerOffsetY) or 0
            self.castTimer:SetFont(GetFont(p), P(sz), "OUTLINE")
            self.castTimer:SetTextColor(col[1], col[2], col[3], 1)
            self.castTimer:ClearAllPoints()
            self.castTimer:SetPoint("RIGHT", self.castBar, "RIGHT",
                P(-3 + ox), P(oy))
            self.castTimer:Show()
        elseif self.castTimer then
            self.castTimer:Hide()
        end

        -- Cast-Target (über Castbar): zeigen wen der Mob targetiert
        if self.castTarget then
            local targetUnit = unit .. "target"
            if UnitExists(targetUnit) then
                local tName = UnitName(targetUnit)
                if tName and not issecretvalue(tName) then
                    local sz = SafeNum(p.castTargetSize) or 10
                    self.castTarget:SetFont(GetFont(p), P(sz), "OUTLINE")
                    -- Klassenfarbe wenn aktiviert
                    if p.castTargetClassColor and UnitIsPlayer(targetUnit) then
                        local _, cls = UnitClass(targetUnit)
                        if cls and CLASS_COLORS[cls] then
                            local cc = CLASS_COLORS[cls]
                            self.castTarget:SetTextColor(cc[1], cc[2], cc[3], 1)
                        end
                    else
                        local col = p.castTargetColor or {1, 1, 1}
                        self.castTarget:SetTextColor(col[1], col[2], col[3], 1)
                    end
                    self.castTarget:SetText("→ "..tName)
                    self.castTarget:Show()
                else
                    self.castTarget:Hide()
                end
            else
                self.castTarget:Hide()
            end
        end

        -- Cast-Icon-Skalierung
        if p.showCastIcon and self.castIcon then
            local cbh = P(p.castbarHeight or 10)
            local scl = SafeNum(p.castIconScale) or 1.0
            self.castIcon:SetSize(cbh * scl, cbh * scl)
            self.castIcon:SetTexture(tex)
            self.castIcon:Show()
        elseif self.castIcon then
            self.castIcon:Hide()
        end

        if castDuration then
            local direction = isChannel
                and Enum.StatusBarTimerDirection.RemainingTime
                or Enum.StatusBarTimerDirection.ElapsedTime
            local smoothing = Enum.StatusBarInterpolation.Immediate
            pcall(function()
                self.castBar:SetTimerDuration(castDuration, smoothing, direction)
            end)
        end

        if p.showCastSpark then
            self.castSpark:Show()
        else
            self.castSpark:Hide()
        end

        -- Castbar-Farbe
        local c
        if notInterruptible then     c = p.colorCastUninter
        elseif isChannel    then     c = p.colorCastChannel
        else                          c = p.colorCastNormal end
        self.castBar:SetStatusBarColor(c[1], c[2], c[3])
        self.interruptBar:SetColorTexture(c[1], c[2], c[3], 1)

        -- Important-Cast-Glow: zeigt Glow um Castbar bei wichtigen Casts
        -- Heuristik: nicht-unterbrechbare Casts sind oft "wichtig" (Bosse,
        -- Cooldowns). Erweiterbar via Spell-ID-Whitelist.
        if self.castGlow then
            if p.importantCastGlow and notInterruptible then
                local gc = p.colors and p.colors.importantCastGlow
                       or p.importantCastGlowColor
                       or {1.0, 0.20, 0.20, 1.0}
                self.castGlow:SetVertexColor(gc[1], gc[2], gc[3], gc[4] or 1)
                self.castGlow:Show()
            else
                self.castGlow:Hide()
            end
        end

        self.castContainer:Show()

        ApplyMods(self, unit, p)
    end

    function f:StopCast(interrupted)
        local p = NP:GetActiveProfile()
        self.casting = false
        self.castSpellName = nil
        self.castSpellID = nil
        if self.castTimer then self.castTimer:SetText("") end
        if self.castTarget then self.castTarget:Hide() end
        if self.castGlow then self.castGlow:Hide() end
        if interrupted then
            local c = p.colorCastInterrupt
            self.castBar:SetStatusBarColor(c[1], c[2], c[3])
            self.castText:SetText("|cffFF4444Unterbrochen|r")
            C_Timer.After(0.5, function()
                if not self.casting then self.castContainer:Hide() end
            end)
        else
            self.castContainer:Hide()
        end
    end

    function f:UpdateAll()
        local p = NP:GetActiveProfile()
        ApplyMods(self, unit, p)
        self:UpdateHealth()
        self:UpdateName()
        self:UpdateLevel()
        self:UpdateThreat()
        self:UpdateAuras()
        self:UpdateTarget()
    end

    -- ApplyProfile: Geometrie/Style neu setzen ohne neu zu erstellen
    function f:ApplyProfile()
        local p = NP:GetActiveProfile()
        local W, H, CBH = P(p.width), P(p.height), P(p.castbarHeight)

        f:SetSize(W, H + CBH + P(20))
        hpContainer:SetSize(W, H)
        hpBar:SetSize(W - P(2), H - P(2))
        absorbBar:SetSize(W - P(2), H - P(2))
        castContainer:SetSize(W, CBH)
        castBar:SetSize(W - P(2), CBH - P(2))
        castIcon:SetSize(CBH, CBH)
        castSpark:SetSize(P(2), CBH + P(2))
        interruptBar:SetSize(P(2), CBH)

        hpBar:SetStatusBarTexture(GetBarTex(p))
        absorbBar:SetStatusBarTexture(GetBarTex(p))
        castBar:SetStatusBarTexture(GetBarTex(p))

        hpContainer:SetBackdropColor(unpack(p.colorBackground))
        hpContainer:SetBackdropBorderColor(unpack(p.colorBorder))
        castContainer:SetBackdropColor(unpack(p.colorBackground))
        castContainer:SetBackdropBorderColor(unpack(p.colorBorder))

        local outline = p.fontOutline ~= "NONE" and p.fontOutline or ""
        nameText:SetFont(GetFont(p), P(p.fontSize), outline)
        levelText:SetFont(GetFont(p), P(p.fontSize - 1), outline)
        hpText:SetFont(GetFont(p), P(p.fontSize - 1), outline)
        castText:SetFont(GetFont(p), P(p.fontSize - 2), outline)

        threatGlow:SetBackdrop({
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = P(p.threatGlowSize or 2),
        })
        threatGlow:ClearAllPoints()
        threatGlow:SetPoint("TOPLEFT",     hpContainer, "TOPLEFT",     -P(2), P(2))
        threatGlow:SetPoint("BOTTOMRIGHT", hpContainer, "BOTTOMRIGHT",  P(2), -P(2))

        -- Slot-Layout neu anwenden (Sizes + Anchor aus Profile)
        if f.RefreshSlotLayout then
            f:RefreshSlotLayout()
        end

        f:UpdateAll()
    end

    table.insert(NP.allPlates, f)
    return f
end

-- ============================================================
--  HOOKS
-- ============================================================

local function OnNameplateAdded(unit)
    local base = C_NamePlate.GetNamePlateForUnit(unit)
    if not base then return end

    if base.UnitFrame then
        base.UnitFrame:Hide()
        base.UnitFrame:UnregisterAllEvents()
    end

    local plate = BuildNameplate(base, unit)
    NP.plates[unit] = plate
    plate:UpdateAll()
end

local function OnNameplateRemoved(unit)
    local plate = NP.plates[unit]
    if plate then
        plate:Hide()
        plate:SetParent(UIParent)
        NP.plates[unit] = nil
    end
end

-- ============================================================
--  REAPPLY (Live-Update aus Options-Panel)
-- ============================================================

function NP:Reapply()
    for _, plate in pairs(self.plates) do
        if plate.ApplyProfile then plate:ApplyProfile() end
    end
end

function NP:UpdateAllTargets()
    for _, plate in pairs(self.plates) do
        plate:UpdateTarget()
    end
end

-- ============================================================
--  IMPORT / EXPORT (Profile + Mods)
--  LibSerialize → LibDeflate → Base64-ähnliche Print-Encoding
-- ============================================================

function NP:ExportTable(tbl)
    if not tbl then return nil end
    local serialized = LibSer:Serialize(tbl)
    local compressed = LibDeflate:CompressDeflate(serialized,
                          { level = 9 })
    return LibDeflate:EncodeForPrint(compressed)
end

function NP:ImportTable(str)
    if not str or str == "" then return nil, "Leer" end
    str = str:gsub("^%s+", ""):gsub("%s+$", "")
    local decoded = LibDeflate:DecodeForPrint(str)
    if not decoded then return nil, "Ungültiges Format" end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "Decompress-Fehler" end
    local ok, result = LibSer:Deserialize(decompressed)
    if not ok then return nil, "Deserialize-Fehler: "..tostring(result) end
    return result
end

function NP:ExportProfile(profileName)
    local p = VuloUI_NameplatesDB.profiles[profileName]
    if not p then return nil end
    return self:ExportTable({
        type    = "VuloUI_NP_Profile",
        version = 1,
        name    = profileName,
        data    = p,
    })
end

function NP:ImportProfile(str, newName)
    local data, err = self:ImportTable(str)
    if not data then return false, err end
    if data.type ~= "VuloUI_NP_Profile" then
        return false, "Kein gültiges Profil"
    end
    local name = newName or data.name or "Imported"
    -- Default-Werte für fehlende Keys ergänzen
    local merged = DefaultProfile()
    for k, v in pairs(data.data or {}) do merged[k] = v end
    VuloUI_NameplatesDB.profiles[name] = merged
    return true, name
end

function NP:ExportMod(mod)
    return self:ExportTable({
        type    = "VuloUI_NP_Mod",
        version = 1,
        data    = mod,
    })
end

function NP:ImportMod(str)
    local data, err = self:ImportTable(str)
    if not data then return nil, err end
    if data.type ~= "VuloUI_NP_Mod" then
        return nil, "Kein gültiger Mod"
    end
    return data.data
end

-- ============================================================
--  CVARS
-- ============================================================

local function SetNameplateCVars()
    SetCVar("nameplateMaxDistance",       "60")
    SetCVar("nameplateOtherTopInset",     "0.08")
    SetCVar("nameplateOtherBottomInset",  "0.1")
    SetCVar("nameplateLargeTopInset",     "0.08")
    SetCVar("nameplateLargeBottomInset",  "0.1")
    SetCVar("nameplateOverlapH",          "0.8")
    SetCVar("nameplateOverlapV",          "1.1")
    SetCVar("nameplateShowSelf",          "0")
    SetCVar("nameplateShowFriends",       "0")
    SetCVar("nameplateShowEnemies",       "1")
    SetCVar("nameplateGlobalScale",       "1")
    SetCVar("NamePlateHorizontalScale",   "1")
    SetCVar("NamePlateVerticalScale",     "1")
end

-- ============================================================
--  EVENTS
-- ============================================================

V:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
    OnNameplateAdded(unit)
end)

V:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    OnNameplateRemoved(unit)
end)

V:RegisterEvent("UNIT_HEALTH", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateHealth() end
end)

V:RegisterEvent("UNIT_MAXHEALTH", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateHealth() end
end)

V:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateHealth() end
end)

V:RegisterEvent("UNIT_AURA", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateAuras() end
end)

V:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateThreat() end
end)

V:RegisterEvent("UNIT_THREAT_LIST_UPDATE", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateThreat() end
end)

V:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit)
    local plate = NP.plates[unit]
    if not plate then return end
    -- Wir brauchen nur Name, Icon, notInterruptible und spellID.
    -- StartCast holt selbst UnitCastingDuration() für das DurationObject.
    pcall(function()
        local name, _, tex, _, _, _, _, notInter, spellID =
            UnitCastingInfo(unit)
        if name then
            plate:StartCast(name, tex, false, notInter, spellID)
        end
    end)
end)

V:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit)
    local plate = NP.plates[unit]
    if not plate then return end
    pcall(function()
        local name, _, tex, _, _, _, notInter, spellID =
            UnitChannelInfo(unit)
        if name then
            plate:StartCast(name, tex, true, notInter, spellID)
        end
    end)
end)

local function StopCastEvent(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:StopCast(false) end
end

local function InterruptCastEvent(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:StopCast(true) end
end

V:RegisterEvent("UNIT_SPELLCAST_STOP",          StopCastEvent)
V:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP",  StopCastEvent)
V:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED",   InterruptCastEvent)
V:RegisterEvent("UNIT_SPELLCAST_FAILED",        InterruptCastEvent)

V:RegisterEvent("PLAYER_TARGET_CHANGED", function()
    NP:UpdateAllTargets()
end)

V:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for _, plate in pairs(NP.plates) do plate:UpdateThreat() end
end)

V:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", function()
    NP:Reapply()
end)

-- ============================================================
--  INITIALIZE
-- ============================================================

function NP:OnInitialize()
    -- SavedVariables setup
    if not VuloUI_NameplatesDB then
        VuloUI_NameplatesDB = {
            activeProfile = "Default",
            profiles      = { Default = DefaultProfile() },
            specMapping   = {},
        }
    else
        -- Backfill
        VuloUI_NameplatesDB.profiles    = VuloUI_NameplatesDB.profiles or {}
        VuloUI_NameplatesDB.specMapping = VuloUI_NameplatesDB.specMapping or {}
        if not VuloUI_NameplatesDB.profiles.Default then
            VuloUI_NameplatesDB.profiles.Default = DefaultProfile()
        end
        VuloUI_NameplatesDB.activeProfile =
            VuloUI_NameplatesDB.activeProfile or "Default"

        -- Default-Keys in alle Profile mergen (für neue Settings)
        local defaults = DefaultProfile()
        for _, prof in pairs(VuloUI_NameplatesDB.profiles) do
            for k, v in pairs(defaults) do
                if prof[k] == nil then prof[k] = v end
            end
        end
    end

    self.db = VuloUI_NameplatesDB

    -- ============================================================
    --  ONE-SHOT MIGRATOR (v1.1)
    --  Frühere Versionen hatten einen Nameplates-Tab im zentralen
    --  ConfigUI, der in VuloUIDB.profile.nameplates schrieb. Diese
    --  Werte wurden vom Modul nie gelesen. Falls Bestandsuser dort
    --  Settings haben, einmalig ins aktive Profil übernehmen.
    -- ============================================================
    if VuloUIDB and VuloUIDB.profile and VuloUIDB.profile.nameplates
       and not VuloUI_NameplatesDB._migratedFromCentralDB then
        local active = VuloUI_NameplatesDB.profiles[
            VuloUI_NameplatesDB.activeProfile or "Default"]
        if active then
            for k, v in pairs(VuloUIDB.profile.nameplates) do
                if active[k] == nil then active[k] = v end
            end
        end
        VuloUIDB.profile.nameplates = nil
        VuloUI_NameplatesDB._migratedFromCentralDB = true
    end

    V:RegisterEvent("PLAYER_LOGIN", function()
        SetNameplateCVars()
    end)

    -- Bestehende Plates initialisieren
    for _, np in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if np.namePlateUnitToken then
            OnNameplateAdded(np.namePlateUnitToken)
        end
    end
end

function NP:OnEnable()
    SetNameplateCVars()
    self:Reapply()
end

function NP:OnDisable()
    for _, plate in pairs(self.plates) do plate:Hide() end
end

-- ============================================================
--  SELF-INIT
--  Der VuloUI-Core ruft OnInitialize nur auf wenn das Sub-Addon
--  zum Zeitpunkt von VuloUI's ADDON_LOADED bereits registriert
--  ist. Sub-Addons mit Dependencies laden aber NACH VuloUI -> der
--  initial-pass im Core wird verpasst. Wir triggern OnInitialize
--  daher selbst beim eigenen ADDON_LOADED.
-- ============================================================

local selfInitFrame = CreateFrame("Frame")
selfInitFrame:RegisterEvent("ADDON_LOADED")
selfInitFrame:SetScript("OnEvent", function(self, event, addon)
    if addon == "VuloUI_Nameplates" then
        if not NP.initialized then
            NP.initialized = true
            local ok, err = pcall(function() NP:OnInitialize() end)
            if not ok then
                print("|cffff0000VuloUI NP OnInitialize ERROR:|r "..tostring(err))
            end
        end
        self:UnregisterAllEvents()
    end
end)