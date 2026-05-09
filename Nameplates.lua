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

        -- Farben
        classColorPlayers  = true,
        useReactionColors  = true,
        colorFriendly      = {0.20, 0.80, 0.20},
        colorNeutral       = {0.90, 0.85, 0.20},
        colorEnemy         = {0.90, 0.20, 0.20},
        colorTapped        = {0.50, 0.50, 0.50},
        colorBackground    = {0.04, 0.04, 0.04, 1.00},
        colorBorder        = {0.08, 0.08, 0.08, 1.00},

        -- Texte
        showName           = true,
        maxNameLength      = 16,
        showLevel          = true,
        showHealthPercent  = true,
        showHealthAbsolute = false,
        abbreviateNumbers  = true,

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

        -- Castbar
        showCastbar        = true,
        showCastIcon       = true,
        showCastSpark      = true,
        colorCastNormal    = {0.90, 0.70, 0.10},
        colorCastChannel   = {0.30, 0.60, 1.00},
        colorCastUninter   = {0.50, 0.50, 0.50},
        colorCastInterrupt = {1.00, 0.20, 0.20},

        -- Auras
        showAuras          = true,
        auraCount          = 6,
        auraIconSize       = 14,
        auraSpacing        = 2,
        auraFilter         = "all",  -- mine, important, all
        auraWhitelist      = {},  -- [spellID] = true
        auraBlacklist      = {},  -- [spellID] = true
        auraImportant      = {},  -- [spellID] = true (immer zeigen)

        -- Aura-Slot-Positionen (6 Positionen rund ums Nameplate)
        -- Jeder Slot hat enabled (sichtbar) und kind (Aura-Typ).
        -- kinds: "debuffs", "buffs", "ccs", "raidmarker", "elite", "none"
        auraSlots = {
            top      = { enabled = true,  kind = "debuffs"    },
            left     = { enabled = true,  kind = "buffs"      },
            topleft  = { enabled = false, kind = "elite"      },
            right    = { enabled = true,  kind = "ccs"        },
            topright = { enabled = false, kind = "raidmarker" },
            bottom   = { enabled = true,  kind = "none"       },
        },

        -- Target
        targetHighlight    = true,
        targetGlowColor    = {1, 1, 1, 1},
        targetScale        = 1.15,
        nonTargetAlpha     = 0.85,

        -- Execute Range
        showExecute        = true,
        executeThreshold   = 35,  -- in % HP
        executeColor       = {1.00, 0.30, 0.30},

        -- Mods (NPC-spezifische Anpassungen)
        mods               = {},
        -- Format pro Mod:
        -- {
        --   id = "uniqueid",
        --   name = "Anzeigename",
        --   enabled = true,
        --   trigger = { type = "npcid", value = 12345 },
        --     -- types: npcid, npcname, spellcast, aurapresent
        --   actions = {
        --     { type = "setcolor", color = {1,0,0} },
        --     { type = "setborder", color = {1,1,0,1}, size = 2 },
        --     { type = "setscale", value = 1.3 },
        --     { type = "glow", color = {1,1,0,1} },
        --     { type = "hide" },
        --     { type = "important", text = "FOCUS!", color = {1,0,0} },
        --   }
        -- }
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

local function GetReactionColor(unit, profile)
    if UnitIsTapDenied(unit) then
        return unpack(profile.colorTapped)
    end
    local r = UnitReaction(unit, "player")
    if not r then return unpack(profile.colorEnemy) end
    if r >= 5 then return unpack(profile.colorFriendly)
    elseif r == 4 then return unpack(profile.colorNeutral)
    else return unpack(profile.colorEnemy) end
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
    return unpack(profile.colorEnemy)
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

    local SLOT_SIZE = P(profile.auraIconSize + 4)  -- etwas größer als alte Aura-Icons

    local function CreateSlotIcon()
        local icon = CreateFrame("Frame", nil, f, "BackdropTemplate")
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

        icon:Hide()
        return icon
    end

    -- Slot-Anker: Position relativ zum Nameplate
    -- Top/Bottom mittig oberhalb/unterhalb, Left/Right an Bar-Seiten
    local function AnchorSlot(slot, slotID)
        slot:ClearAllPoints()
        if     slotID == "top" then
            slot:SetPoint("BOTTOM", hpContainer, "TOP", 0, P(2))
        elseif slotID == "bottom" then
            slot:SetPoint("TOP", castContainer, "BOTTOM", 0, -P(2))
        elseif slotID == "left" then
            slot:SetPoint("RIGHT", hpContainer, "LEFT", -P(2), 0)
        elseif slotID == "right" then
            slot:SetPoint("LEFT", hpContainer, "RIGHT", P(2), 0)
        elseif slotID == "topleft" then
            slot:SetPoint("BOTTOMRIGHT", hpContainer, "TOPLEFT", -P(2), P(2))
        elseif slotID == "topright" then
            slot:SetPoint("BOTTOMLEFT", hpContainer, "TOPRIGHT", P(2), P(2))
        end
    end

    -- 6 Slots erstellen
    f.auraSlotFrames = {}
    for _, slotID in ipairs({"top","left","topleft","right","topright","bottom"}) do
        local slot = CreateSlotIcon()
        AnchorSlot(slot, slotID)
        f.auraSlotFrames[slotID] = slot
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
    f.castIcon      = castIcon
    f.castSpark     = castSpark
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
    local function FillSlotWithAura(slot, d)
        slot.tex:SetTexture(d.icon)
        slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        -- Border-Farbe nach Dispel-Type. dispelName kann ein secret value
        -- sein in WoW 12.0 - mit issecretvalue() guarden bevor als Key
        -- benutzen.
        local dispel = d.dispelName
        local c
        if dispel and not issecretvalue(dispel) then
            c = DEBUFF_TYPE_COLORS[dispel] or DEBUFF_TYPE_COLORS.none
        else
            c = DEBUFF_TYPE_COLORS.none
        end
        slot:SetBackdropBorderColor(c[1], c[2], c[3], 1)

        -- Stack-Count. stackStr von GetAuraApplicationDisplayCount kann ein
        -- secret string sein - wir können ihn mit SetText durchreichen, aber
        -- NICHT mit == oder ~= vergleichen. Wir nutzen daher applications
        -- als Sichtbarkeits-Steuerung (numerisch, nicht-secret durch SafeNum).
        local apps = SafeNum(d.applications)
        local showCount = apps and apps > 1
        if showCount and C_UnitAuras.GetAuraApplicationDisplayCount and d.auraInstanceID then
            local stackStr = C_UnitAuras.GetAuraApplicationDisplayCount(
                unit, d.auraInstanceID, 2, 999)
            if stackStr then
                -- secret-safe: SetText akzeptiert secret strings
                slot.count:SetText(stackStr)
                slot.count:Show()
            else
                slot.count:Hide()
            end
        elseif showCount then
            slot.count:SetText(apps)
            slot.count:Show()
        else
            slot.count:Hide()
        end

        -- Cooldown via DurationObject (secret-safe)
        if C_UnitAuras.GetAuraDuration and d.auraInstanceID
           and slot.cd.SetCooldownFromDurationObject then
            local durObj = C_UnitAuras.GetAuraDuration(unit, d.auraInstanceID)
            if durObj then
                slot.cd:SetCooldownFromDurationObject(durObj)
                slot.cd:Show()
            else
                slot.cd:Hide()
            end
        else
            local dur = SafeNum(d.duration)
            local exp = SafeNum(d.expirationTime)
            if dur and exp and dur > 0 then
                slot.cd:SetCooldown(exp - dur, dur)
                slot.cd:Show()
            else
                slot.cd:Hide()
            end
        end

        slot:Show()
    end

    -- Finde die wichtigste Aura eines Filter-Typs ("HARMFUL"/"HELPFUL")
    -- Priorität: 1) eigene mit Dauer, 2) Whitelist, 3) erste mit Dauer
    local function FindBestAura(filter, p)
        local imp = p.auraImportant or {}
        local wl  = p.auraWhitelist or {}
        local bestMine, bestImportant, bestAny
        for idx = 1, 40 do
            local d = C_UnitAuras.GetAuraDataByIndex(unit, idx, filter)
            if not d then break end
            if canaccesstable(d) and ShouldShowAura(d, p) then
                local id = d.spellId
                local idSafe = (id ~= nil and not issecretvalue(id))
                local src = d.sourceUnit
                local srcSafe = (src and not issecretvalue(src))
                local isMine = srcSafe and UnitIsUnit(src, "player")

                if isMine and not bestMine then
                    bestMine = d
                end
                if idSafe and (imp[id] or wl[id]) and not bestImportant then
                    bestImportant = d
                end
                if not bestAny then
                    bestAny = d
                end
            end
        end
        return bestMine or bestImportant or bestAny
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
        end

        if kind == "debuffs" then
            local d = FindBestAura("HARMFUL", p)
            if d then
                FillSlotWithAura(slot, d)
            else
                slot:Hide()
            end

        elseif kind == "buffs" then
            local d = FindBestAura("HELPFUL", p)
            if d then
                FillSlotWithAura(slot, d)
            else
                slot:Hide()
            end

        elseif kind == "ccs" then
            -- Heuristik: zeige aktive CC wenn vorhanden (Magic/Stun/etc.)
            -- Wir suchen harmful auras mit einem dispelName das "Magic" ist
            -- und kurze Duration (typisch für CC). Erweiterbar.
            local found
            for idx = 1, 40 do
                local d = C_UnitAuras.GetAuraDataByIndex(unit, idx, "HARMFUL")
                if not d then break end
                if canaccesstable(d) then
                    -- Einfacher CC-Filter: hat dispelName und kurze Duration
                    local dur = SafeNum(d.duration)
                    local dispel = d.dispelName
                    local hasDispel = dispel and not issecretvalue(dispel)
                    if hasDispel and dur and dur > 0 and dur <= 30 then
                        found = d
                        break
                    end
                end
            end
            if found then
                FillSlotWithAura(slot, found)
            else
                slot:Hide()
            end

        elseif kind == "raidmarker" then
            local mark = GetRaidTargetIndex and GetRaidTargetIndex(unit)
            if mark and RAIDMARKER_ICONS[mark] then
                slot.tex:SetTexture(RAIDMARKER_ICONS[mark])
                slot.tex:SetTexCoord(0, 1, 0, 1)  -- Marker haben keinen Border-Crop
                slot:SetBackdropBorderColor(0, 0, 0, 0)  -- kein Border bei Marker
                slot.count:Hide()
                slot.cd:Hide()
                slot:Show()
            else
                slot:Hide()
                -- TexCoord zurücksetzen für nächste Aura-Verwendung
                slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            end

        elseif kind == "elite" then
            local classification = UnitClassification(unit)
            if classification == "elite" or classification == "rareelite" then
                -- Elite-Krone (gold)
                slot.tex:SetTexture("Interface\\Icons\\Achievement_PVP_A_06")
                slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                slot:SetBackdropBorderColor(1.0, 0.85, 0.2, 1)
                slot.count:Hide()
                slot.cd:Hide()
                slot:Show()
            elseif classification == "rare" then
                slot.tex:SetTexture("Interface\\Icons\\Achievement_PVP_H_06")
                slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                slot:SetBackdropBorderColor(0.7, 0.85, 1.0, 1)
                slot.count:Hide()
                slot.cd:Hide()
                slot:Show()
            elseif classification == "worldboss" or classification == "boss" then
                slot.tex:SetTexture("Interface\\Icons\\Achievement_Boss_LichKing")
                slot.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                slot:SetBackdropBorderColor(1.0, 0.3, 0.3, 1)
                slot.count:Hide()
                slot.cd:Hide()
                slot:Show()
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
            -- Master-toggle aus oder Slots noch nicht erstellt
            if self.auraSlotFrames then
                for _, slot in pairs(self.auraSlotFrames) do slot:Hide() end
            end
            return
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
        self.castText:SetText(name or "")

        if castDuration then
            -- Bar via SetTimerDuration animieren - secret-safe
            local direction = isChannel
                and Enum.StatusBarTimerDirection.RemainingTime
                or Enum.StatusBarTimerDirection.ElapsedTime
            local smoothing = Enum.StatusBarInterpolation.Immediate
            pcall(function()
                self.castBar:SetTimerDuration(castDuration, smoothing, direction)
            end)
        end

        if p.showCastIcon then
            self.castIcon:SetTexture(tex)
            self.castIcon:Show()
        else
            self.castIcon:Hide()
        end

        if p.showCastSpark then
            self.castSpark:Show()
        else
            self.castSpark:Hide()
        end

        local c
        if notInterruptible then     c = p.colorCastUninter
        elseif isChannel    then     c = p.colorCastChannel
        else                          c = p.colorCastNormal end
        self.castBar:SetStatusBarColor(c[1], c[2], c[3])
        self.interruptBar:SetColorTexture(c[1], c[2], c[3], 1)
        self.castContainer:Show()

        -- Mods nochmal triggern (falls Spell-Trigger)
        ApplyMods(self, unit, p)
    end

    function f:StopCast(interrupted)
        local p = NP:GetActiveProfile()
        self.casting = false
        self.castSpellName = nil
        self.castSpellID = nil
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

        -- Aura-Icons rebuilden falls Anzahl/Größe geändert
        for _, ic in ipairs(auraFrame.icons) do ic:Hide() end
        while #auraFrame.icons < p.auraCount do
            table.insert(auraFrame.icons,
                CreateAuraIcon(#auraFrame.icons + 1))
        end
        for _, ic in ipairs(auraFrame.icons) do
            ic:SetSize(P(p.auraIconSize), P(p.auraIconSize))
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
--  SLASH COMMAND
-- ============================================================

SLASH_VULONAMEPLATES1 = "/vnp"
SLASH_VULONAMEPLATES2 = "/vuloplates"
SlashCmdList["VULONAMEPLATES"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+",""):gsub("%s+$","")
    if msg == "reapply" or msg == "reload" then
        NP:Reapply()
        print("|cff9370DBVuloUI Nameplates:|r reapplied.")
    elseif msg == "options" or msg == "config" or msg == "" then
        if VuloUI_NP_Options and VuloUI_NP_Options.Toggle then
            VuloUI_NP_Options:Toggle()
        else
            print("|cffFF6060Options-Modul nicht geladen|r")
        end
    elseif msg:match("^profile%s+(.+)") then
        local name = msg:match("^profile%s+(.+)")
        NP:SetActiveProfile(name)
        print("|cff9370DBVuloUI Nameplates:|r Profil → "..name)
    else
        print("|cff9370DB/vnp|r          – Options öffnen")
        print("|cff9370DB/vnp reapply|r  – Settings neu anwenden")
        print("|cff9370DB/vnp profile X|r – Profil wechseln")
    end
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