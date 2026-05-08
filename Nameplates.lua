-- ============================================================
--  VuloUI – Nameplates
--  Plater-style: HP, Castbar, Debuffs, Threat, Elite-Icons
--  WoW Midnight 12.0.5 API
-- ============================================================
-- ============================================================
--  VuloUI_Nameplates
--  Läuft nur wenn VuloUI Core geladen ist
-- ============================================================

-- Sicherheits-Check: Core vorhanden?
if not VuloUI then
    print("|cffFF6060VuloUI_Nameplates:|r " ..
          "VuloUI Core nicht gefunden!")
    return  -- Modul lädt nicht ohne Core
end

local V   = VuloUI
local LSM = LibStub("LibSharedMedia-3.0")

local NP  = {}
NP.plates = {}
V:RegisterModule("Nameplates", NP)


local V   = VuloUI
local LSM = LibStub("LibSharedMedia-3.0")

local NP  = {}
NP.plates = {}  -- aktive Nameplates: unitToken → frame

V:RegisterModule("Nameplates", NP)

-- ============================================================
--  PIXEL-PERFECT (identisch mit UnitFrames)
-- ============================================================

local function P(v)
    local s = UIParent:GetEffectiveScale()
    return math.floor(v * s + 0.5) / s
end

local function GetBarTex()
    return LSM:Fetch("statusbar",
        V:Get("theme", "barTexture") or "Blizzard")
        or "Interface\\TargetingFrame\\UI-StatusBar"
end

local function GetFont()
    return LSM:Fetch("font",
        V:Get("theme", "font") or "Friz Quadrata TT")
        or "Interface\\AddOns\\VuloUI\\Media\\font.ttf"
end

-- ============================================================
--  FARB-SYSTEM
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

-- Reaktionsfarben (Feind / Freund / Neutral)
local REACTION_COLORS = {
    friendly = {0.20, 0.80, 0.20},
    neutral  = {0.90, 0.85, 0.20},
    enemy    = {0.90, 0.20, 0.20},
    tapped   = {0.50, 0.50, 0.50},
}

-- Threat-Farben (wie Plater)
local THREAT_COLORS = {
    [0] = {0.69, 0.69, 0.69},  -- kein Threat
    [1] = {1.00, 0.75, 0.10},  -- Aggro-Warning (orange)
    [2] = {1.00, 0.45, 0.10},  -- Aggro-Übergang (rot-orange)
    [3] = {1.00, 0.10, 0.10},  -- Volle Aggro (rot)
}

local DEBUFF_COLORS = {
    Magic   = {0.20, 0.60, 1.00},
    Curse   = {0.60, 0.00, 1.00},
    Disease = {0.60, 0.40, 0.00},
    Poison  = {0.00, 0.60, 0.00},
    none    = {0.80, 0.00, 0.00},
}

local function GetNPHealthColor(unit)
    local db = V.db.nameplates
    -- Klassenfarben für Spieler
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        if db.classColorPlayers and CLASS_COLORS[class] then
            local c = CLASS_COLORS[class]
            return c[1], c[2], c[3]
        end
    end
    -- Reaktionsfarbe
    if UnitIsTapDenied(unit) then
        return table.unpack(REACTION_COLORS.tapped)
    elseif UnitReaction(unit, "player") then
        local reaction = UnitReaction(unit, "player")
        if reaction >= 5 then
            return table.unpack(REACTION_COLORS.friendly)
        elseif reaction == 4 then
            return table.unpack(REACTION_COLORS.neutral)
        else
            return table.unpack(REACTION_COLORS.enemy)
        end
    end
    return table.unpack(REACTION_COLORS.enemy)
end

-- ============================================================
--  EINZELNE NAMEPLATE ERSTELLEN
-- ============================================================

local function BuildNameplate(baseFrame, unit)
    local db  = V.db.nameplates
    local w   = P(db.width  or 200)
    local h   = P(db.height or 14)
    local cbh = P(db.castbarHeight or 10)

    -- Basis-Container (hängt am Blizzard-Frame)
    local f = CreateFrame("Frame", nil, baseFrame, "BackdropTemplate")
    f:SetSize(w, h + cbh + P(20))
    f:SetPoint("CENTER", baseFrame, "CENTER", 0, 0)
    f:SetFrameLevel(baseFrame:GetFrameLevel() + 10)

    -- ── HP-BAR CONTAINER ─────────────────────────────────────
    local hpContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    hpContainer:SetSize(w, h)
    hpContainer:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
    hpContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(1),
        insets   = {left=0,right=0,top=0,bottom=0},
    })
    hpContainer:SetBackdropColor(0.05, 0.05, 0.05, 0.9)
    hpContainer:SetBackdropBorderColor(0.08, 0.08, 0.08, 1)

    -- HP-Bar
    local hpBar = CreateFrame("StatusBar", nil, hpContainer)
    hpBar:SetSize(w - P(2), h - P(2))
    hpBar:SetPoint("LEFT", hpContainer, "LEFT", P(1), 0)
    hpBar:SetStatusBarTexture(GetBarTex())
    hpBar:SetMinMaxValues(0, 1)
    hpBar:SetValue(1)

    -- HP-Bar Hintergrund
    local hpBg = hpBar:CreateTexture(nil, "BACKGROUND")
    hpBg:SetAllPoints()
    hpBg:SetColorTexture(0.04, 0.04, 0.04, 1)

    -- Absorb-Shield (wie Plater – zeigt Shields an)
    local absorbBar = CreateFrame("StatusBar", nil, hpContainer)
    absorbBar:SetSize(w - P(2), h - P(2))
    absorbBar:SetPoint("LEFT", hpBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    absorbBar:SetStatusBarTexture(GetBarTex())
    absorbBar:SetMinMaxValues(0, 1)
    absorbBar:SetValue(0)
    absorbBar:SetStatusBarColor(0.85, 0.85, 1.00, 0.7)
    absorbBar:SetReverseFill(false)

    -- ── NAME TEXT ────────────────────────────────────────────
    local nameText = hpBar:CreateFontString(nil, "OVERLAY")
    nameText:SetFont(GetFont(), P(db.fontSize or 10), "OUTLINE")
    nameText:SetPoint("LEFT", hpBar, "LEFT", P(4), 0)
    nameText:SetTextColor(1, 1, 1)
    nameText:SetShadowColor(0, 0, 0, 1)
    nameText:SetShadowOffset(P(1), -P(1))

    -- ── LEVEL TEXT ───────────────────────────────────────────
    local levelText = hpBar:CreateFontString(nil, "OVERLAY")
    levelText:SetFont(GetFont(), P(9), "OUTLINE")
    levelText:SetPoint("RIGHT", hpBar, "RIGHT", -P(4), 0)
    levelText:SetShadowColor(0, 0, 0, 1)
    levelText:SetShadowOffset(P(1), -P(1))

    -- ── HP-TEXT (Prozent oder Absolut) ───────────────────────
    local hpText = hpBar:CreateFontString(nil, "OVERLAY")
    hpText:SetFont(GetFont(), P(9), "OUTLINE")
    hpText:SetPoint("RIGHT", levelText, "LEFT", -P(4), 0)
    hpText:SetTextColor(0.9, 0.9, 0.9)
    hpText:SetShadowColor(0, 0, 0, 1)
    hpText:SetShadowOffset(P(1), -P(1))

    -- ── ELITE / BOSS ICON ────────────────────────────────────
    local eliteIcon = hpContainer:CreateTexture(nil, "OVERLAY")
    eliteIcon:SetSize(P(14), P(14))
    eliteIcon:SetPoint("LEFT", hpContainer, "RIGHT", P(3), 0)
    eliteIcon:Hide()

    -- ── THREAT-GLOW (Rahmen leuchtet bei Aggro) ───────────────
    local threatGlow = CreateFrame("Frame", nil, hpContainer, "BackdropTemplate")
    threatGlow:SetPoint("TOPLEFT",    hpContainer, "TOPLEFT",    -P(2), P(2))
    threatGlow:SetPoint("BOTTOMRIGHT",hpContainer, "BOTTOMRIGHT", P(2), -P(2))
    threatGlow:SetBackdrop({
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(2),
        insets   = {left=P(2),right=P(2),top=P(2),bottom=P(2)},
    })
    threatGlow:SetBackdropBorderColor(0, 0, 0, 0)
    threatGlow:SetFrameLevel(hpContainer:GetFrameLevel() - 1)

    -- ── CASTBAR ──────────────────────────────────────────────
    local castContainer = CreateFrame("Frame", nil, f, "BackdropTemplate")
    castContainer:SetSize(w, cbh)
    castContainer:SetPoint("TOP", hpContainer, "BOTTOM", 0, -P(2))
    castContainer:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = P(1),
        insets   = {left=0,right=0,top=0,bottom=0},
    })
    castContainer:SetBackdropColor(0.04, 0.04, 0.04, 0.9)
    castContainer:SetBackdropBorderColor(0.08, 0.08, 0.08, 1)

    local castBar = CreateFrame("StatusBar", nil, castContainer)
    castBar:SetSize(w - P(2), cbh - P(2))
    castBar:SetPoint("LEFT", castContainer, "LEFT", P(1), 0)
    castBar:SetStatusBarTexture(GetBarTex())
    castBar:SetMinMaxValues(0, 1)
    castBar:SetValue(0)
    castBar:SetStatusBarColor(0.9, 0.7, 0.1)

    local castBg = castBar:CreateTexture(nil, "BACKGROUND")
    castBg:SetAllPoints()
    castBg:SetColorTexture(0.04, 0.04, 0.04, 1)

    -- Castbar Spell-Name
    local castText = castBar:CreateFontString(nil, "OVERLAY")
    castText:SetFont(GetFont(), P(8), "OUTLINE")
    castText:SetPoint("LEFT", castBar, "LEFT", P(3), 0)
    castText:SetTextColor(1, 0.95, 0.8)
    castText:SetShadowColor(0, 0, 0, 1)
    castText:SetShadowOffset(P(1), -P(1))

    -- Castbar Spell-Icon
    local castIcon = castContainer:CreateTexture(nil, "ARTWORK")
    castIcon:SetSize(cbh, cbh)
    castIcon:SetPoint("RIGHT", castContainer, "LEFT", -P(2), 0)
    castIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- Interruptbar-Indikator (links, farbig wenn interruptbar)
    local interruptBar = castContainer:CreateTexture(nil, "OVERLAY")
    interruptBar:SetSize(P(2), cbh)
    interruptBar:SetPoint("LEFT", castContainer, "LEFT", 0, 0)
    interruptBar:SetColorTexture(0.9, 0.7, 0.1, 1)

    -- Spark
    local castSpark = castBar:CreateTexture(nil, "OVERLAY")
    castSpark:SetSize(P(2), cbh + P(2))
    castSpark:SetColorTexture(1, 1, 1, 0.9)
    castSpark:SetPoint("CENTER",
        castBar:GetStatusBarTexture(), "RIGHT", 0, 0)

    castContainer:Hide()

    -- ── DEBUFF-ICONS ─────────────────────────────────────────
    local debuffFrame = CreateFrame("Frame", nil, f)
    debuffFrame:SetSize(w, P(16))
    debuffFrame:SetPoint("TOP", castContainer, "BOTTOM", 0, -P(2))
    debuffFrame.icons = {}

    for i = 1, 6 do
        local icon = CreateFrame("Frame", nil, debuffFrame, "BackdropTemplate")
        icon:SetSize(P(14), P(14))
        icon:SetPoint("LEFT", debuffFrame, "LEFT",
            (i-1) * P(16), 0)
        icon:SetBackdrop({
            bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
            edgeSize = P(1),
            insets   = {left=0,right=0,top=0,bottom=0},
        })
        icon:SetBackdropColor(0, 0, 0, 1)
        icon:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

        icon.tex = icon:CreateTexture(nil, "ARTWORK")
        icon.tex:SetSize(P(12), P(12))
        icon.tex:SetPoint("CENTER")
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        icon.cd = CreateFrame("Cooldown", nil, icon,
                              "CooldownFrameTemplate")
        icon.cd:SetAllPoints(icon.tex)
        icon.cd:SetDrawEdge(false)
        icon.cd:SetSwipeColor(0, 0, 0, 0.75)

        icon.count = icon:CreateFontString(nil, "OVERLAY")
        icon.count:SetFont(GetFont(), P(8), "OUTLINE")
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", P(1), P(1))
        icon.count:SetTextColor(1, 1, 1)

        icon:Hide()
        debuffFrame.icons[i] = icon
    end

    -- ── UPDATE-FUNKTIONEN ────────────────────────────────────

    -- Speichere alle Referenzen
    f.unit         = unit
    f.hpBar        = hpBar
    f.hpBg         = hpBg
    f.absorbBar    = absorbBar
    f.nameText     = nameText
    f.levelText    = levelText
    f.hpText       = hpText
    f.eliteIcon    = eliteIcon
    f.threatGlow   = threatGlow
    f.castBar      = castBar
    f.castText     = castText
    f.castIcon     = castIcon
    f.castSpark    = castSpark
    f.castContainer= castContainer
    f.interruptBar = interruptBar
    f.debuffFrame  = debuffFrame
    f.casting      = false
    f.endTime      = 0
    f.maxTime      = 0

    function f:UpdateHealth()
        local hp    = UnitHealth(unit)
        local hpMax = UnitHealthMax(unit)
        local pct   = hpMax > 0 and (hp / hpMax) or 0

        self.hpBar:SetMinMaxValues(0, hpMax)
        self.hpBar:SetValue(hp)

        local r, g, b = GetNPHealthColor(unit)
        self.hpBar:SetStatusBarColor(r, g, b)

        -- Absorb-Shield
        local absorb = UnitGetTotalAbsorbs(unit) or 0
        if absorb > 0 and hpMax > 0 then
            local absorbPct = math.min(absorb / hpMax, 1 - pct)
            self.absorbBar:SetMinMaxValues(0, 1)
            self.absorbBar:SetValue(absorbPct)
        else
            self.absorbBar:SetValue(0)
        end

        -- HP-Text
        local db = V.db.nameplates
        if db.showHealthPercent then
            if pct == 1 then
                self.hpText:SetText("")
            else
                self.hpText:SetText(
                    string.format("%d%%", math.floor(pct * 100)))
            end
        elseif db.showHealthAbsolute then
            if hp >= 1e6 then
                self.hpText:SetText(
                    string.format("%.1fM", hp / 1e6))
            elseif hp >= 1e3 then
                self.hpText:SetText(
                    string.format("%.0fk", hp / 1e3))
            else
                self.hpText:SetText(hp)
            end
        end
    end

    function f:UpdateName()
        local name  = UnitName(unit) or ""
        local db    = V.db.nameplates
        local maxLen= db.maxNameLength or 16
        if #name > maxLen then
            name = name:sub(1, maxLen) .. ".."
        end
        self.nameText:SetText(name)
    end

    function f:UpdateLevel()
        local level      = UnitLevel(unit)
        local isElite    = UnitClassification(unit)
        local isBoss     = isElite == "worldboss" or isElite == "boss"
        local isRare     = isElite == "rare" or isElite == "rareelite"
        local isEliteMob = isElite == "elite" or isElite == "rareelite"

        -- Level-Farbe
        local levelColor = "|cffAAAAAA"
        if isBoss then
            levelColor = "|cffFF6060"
        elseif isRare then
            levelColor = "|cffAA88FF"
        elseif level == -1 then  -- ?? Boss
            levelColor = "|cffFF4040"
        end

        local levelStr = level == -1 and "??" or tostring(level)

        -- Elite-Suffix
        local suffix = ""
        if isBoss         then suffix = " |cffFF6060[Boss]|r"
        elseif isRare     then suffix = " |cffAA88FF[Rare]|r"
        elseif isEliteMob then suffix = " |cffFFD700+|r"
        end

        self.levelText:SetText(levelColor .. levelStr .. "|r" .. suffix)

        -- Elite-Icon (Drache-Symbol)
        if isEliteMob or isRare then
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
        if not UnitExists(unit) then return end
        local db = V.db.nameplates
        if not db.showThreat then
            self.threatGlow:SetBackdropBorderColor(0,0,0,0)
            return
        end

        local _, _, threatPct, threatValue =
            UnitDetailedThreatSituation("player", unit)

        if threatValue and threatValue > 0 then
            local isTank  = UnitGroupRolesAssigned("player") == "TANK"
            local status  = UnitThreatSituation("player", unit) or 0

            if isTank then
                -- Tank: grün wenn Aggro, orange wenn jemand anderes Aggro hat
                if status >= 3 then
                    self.threatGlow:SetBackdropBorderColor(
                        0.1, 0.9, 0.1, 0.9)
                elseif status >= 1 then
                    self.threatGlow:SetBackdropBorderColor(
                        1.0, 0.6, 0.1, 0.9)
                else
                    self.threatGlow:SetBackdropBorderColor(0,0,0,0)
                end
            else
                -- DPS/Healer: Plater-Style Warnung
                local c = THREAT_COLORS[status] or THREAT_COLORS[0]
                if status >= 1 then
                    self.threatGlow:SetBackdropBorderColor(
                        c[1], c[2], c[3], 0.9)
                else
                    self.threatGlow:SetBackdropBorderColor(0,0,0,0)
                end
            end
        else
            self.threatGlow:SetBackdropBorderColor(0, 0, 0, 0)
        end
    end

    function f:UpdateDebuffs()
        local index     = 1
        local auraIndex = 1

        while index <= #self.debuffFrame.icons do
            local auraData = C_UnitAuras.GetAuraDataByIndex(
                unit, auraIndex, "HARMFUL")
            if not auraData then break end

            -- Nur eigene Debuffs anzeigen
            if UnitIsUnit(auraData.sourceUnit or "", "player") then
                local icon = self.debuffFrame.icons[index]
                icon.tex:SetTexture(auraData.icon)

                -- Debuff-Typ Farbe
                local c = auraData.dispelName and
                          DEBUFF_COLORS[auraData.dispelName] or
                          DEBUFF_COLORS.none
                icon:SetBackdropBorderColor(c[1], c[2], c[3], 1)

                -- Stack-Count
                if auraData.applications and auraData.applications > 1 then
                    icon.count:SetText(auraData.applications)
                    icon.count:Show()
                else
                    icon.count:Hide()
                end

                -- Cooldown-Sweep
                if auraData.duration and auraData.duration > 0 then
                    icon.cd:SetCooldown(
                        auraData.expirationTime - auraData.duration,
                        auraData.duration)
                    icon.cd:Show()
                else
                    icon.cd:Hide()
                end

                icon:Show()
                index = index + 1
            end
            auraIndex = auraIndex + 1
        end

        -- Rest verstecken
        for i = index, #self.debuffFrame.icons do
            self.debuffFrame.icons[i]:Hide()
        end
    end

    -- Castbar OnUpdate
    f:SetScript("OnUpdate", function(self, elapsed)
        if not self.casting then return end
        local now     = GetTime()
        local remain  = math.max(0, self.endTime - now)
        local progress= 1 - (remain / self.maxTime)
        self.castBar:SetValue(math.min(1, progress))
        -- Spark
        self.castSpark:SetPoint("CENTER",
            self.castBar:GetStatusBarTexture(), "RIGHT", 0, 0)
    end)

    function f:StartCast(name, tex, startTime, endTime,
                         isChannel, notInterruptible)
        self.casting  = true
        self.maxTime  = math.max(endTime - startTime, 0.001)
        self.endTime  = endTime
        self.castText:SetText(name or "")
        self.castIcon:SetTexture(tex)

        -- Kanal: blau, Cast: gold, nicht-unterbrechbar: grau
        if notInterruptible then
            self.castBar:SetStatusBarColor(0.5, 0.5, 0.5)
            self.interruptBar:SetColorTexture(0.5, 0.5, 0.5, 1)
        elseif isChannel then
            self.castBar:SetStatusBarColor(0.3, 0.6, 1.0)
            self.interruptBar:SetColorTexture(0.3, 0.6, 1.0, 1)
        else
            self.castBar:SetStatusBarColor(0.9, 0.7, 0.1)
            self.interruptBar:SetColorTexture(0.9, 0.7, 0.1, 1)
        end

        self.castContainer:Show()
    end

    function f:StopCast(interrupted)
        self.casting = false
        if interrupted then
            self.castBar:SetStatusBarColor(1, 0.2, 0.2)
            self.castBar:SetValue(1)
            self.castText:SetText(
                "|cffFF4444Unterbrochen|r")
            C_Timer.After(0.5, function()
                if not self.casting then
                    self.castContainer:Hide()
                end
            end)
        else
            self.castContainer:Hide()
        end
    end

    function f:UpdateAll()
        self:UpdateHealth()
        self:UpdateName()
        self:UpdateLevel()
        self:UpdateThreat()
        self:UpdateDebuffs()
    end

    return f
end

-- ============================================================
--  BLIZZARD NAMEPLATE HOOKS
--  WoW erstellt Nameplates selbst – wir hängen uns rein
-- ============================================================

local function OnNameplateAdded(unitToken)
    local baseFrame = C_NamePlate.GetNamePlateForUnit(unitToken)
    if not baseFrame then return end

    -- Blizzard-Standard-Elemente ausblenden
    if baseFrame.UnitFrame then
        baseFrame.UnitFrame:Hide()
        baseFrame.UnitFrame:UnregisterAllEvents()
    end

    -- Unseren Frame erstellen
    local plate = BuildNameplate(baseFrame, unitToken)
    NP.plates[unitToken] = plate

    -- Initialer Update
    plate:UpdateAll()
end

local function OnNameplateRemoved(unitToken)
    local plate = NP.plates[unitToken]
    if plate then
        plate:Hide()
        plate:SetParent(nil)
        NP.plates[unitToken] = nil
    end
end

-- ============================================================
--  GLOBALE EVENT-HANDLER
-- ============================================================

-- Nameplate erscheint/verschwindet
V:RegisterEvent("NAME_PLATE_UNIT_ADDED", function(_, unit)
    OnNameplateAdded(unit)
end)

V:RegisterEvent("NAME_PLATE_UNIT_REMOVED", function(_, unit)
    OnNameplateRemoved(unit)
end)

-- Health Updates für alle Nameplates
V:RegisterEvent("UNIT_HEALTH", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateHealth() end
end)

V:RegisterEvent("UNIT_MAXHEALTH", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateHealth() end
end)

-- Absorb-Shields
V:RegisterEvent("UNIT_ABSORB_AMOUNT_CHANGED", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateHealth() end
end)

-- Debuffs
V:RegisterEvent("UNIT_AURA", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateDebuffs() end
end)

-- Threat
V:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateThreat() end
end)

V:RegisterEvent("UNIT_THREAT_LIST_UPDATE", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:UpdateThreat() end
end)

-- Castbar Events
V:RegisterEvent("UNIT_SPELLCAST_START", function(_, unit)
    local plate = NP.plates[unit]
    if not plate then return end
    local name, _, tex, startMS, endMS, _, _, notInterruptible =
        UnitCastingInfo(unit)
    if name then
        plate:StartCast(name, tex,
            startMS/1000, endMS/1000, false, notInterruptible)
    end
end)

V:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START", function(_, unit)
    local plate = NP.plates[unit]
    if not plate then return end
    local name, _, tex, startMS, endMS, _, notInterruptible =
        UnitChannelInfo(unit)
    if name then
        plate:StartCast(name, tex,
            startMS/1000, endMS/1000, true, notInterruptible)
    end
end)

V:RegisterEvent("UNIT_SPELLCAST_STOP", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:StopCast(false) end
end)

V:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:StopCast(true) end
end)

V:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:StopCast(false) end
end)

V:RegisterEvent("UNIT_SPELLCAST_FAILED", function(_, unit)
    local plate = NP.plates[unit]
    if plate then plate:StopCast(true) end
end)

-- Kampf-Ende: alle Nameplates updaten
V:RegisterEvent("PLAYER_REGEN_ENABLED", function()
    for _, plate in pairs(NP.plates) do
        plate:UpdateThreat()
    end
end)

-- ============================================================
--  CVARs SETZEN (wie Plater)
-- ============================================================

local function SetNameplateCVars()
    -- Sichtweite
    SetCVar("nameplateMaxDistance",        "40")
    SetCVar("nameplateOtherTopInset",      "0.1")
    SetCVar("nameplateOtherBottomInset",  "-0.1")
    SetCVar("nameplateLargeTopInset",      "0.1")
    SetCVar("nameplateLargeBottomInset",  "-0.1")
    -- Überlappungsschutz
    SetCVar("nameplateOverlapH",           "0.8")
    SetCVar("nameplateOverlapV",           "1.1")
    -- Eigene Nameplates
    SetCVar("nameplateShowSelf",           "0")
    SetCVar("nameplateShowFriends",        "0")
    SetCVar("nameplateShowEnemies",        "1")
    -- Größe (unsere Frames übernehmen das Layout)
    SetCVar("nameplateGlobalScale",        "1")
    SetCVar("NamePlateHorizontalScale",    "1")
    SetCVar("NamePlateVerticalScale",      "1")
end

-- ============================================================
--  MODUL INIT
-- ============================================================

function NP:OnInitialize()
    -- Config-Defaults für Nameplates sicherstellen
    local db = V.db.nameplates
    db.width              = db.width              or 200
    db.height             = db.height             or 14
    db.castbarHeight      = db.castbarHeight      or 10
    db.fontSize           = db.fontSize           or 10
    db.maxNameLength      = db.maxNameLength      or 16
    db.showHealthPercent  = db.showHealthPercent  ~= false
    db.showHealthAbsolute = db.showHealthAbsolute or false
    db.showThreat         = db.showThreat         ~= false
    db.classColorPlayers  = db.classColorPlayers  ~= false

    -- CVars nach Login setzen
    V:RegisterEvent("PLAYER_LOGIN", function()
        SetNameplateCVars()
    end)

    -- Alle bereits vorhandenen Nameplates initialisieren
    -- (falls Addon während Session geladen wird)
    for _, unit in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if unit.namePlateUnitToken then
            OnNameplateAdded(unit.namePlateUnitToken)
        end
    end
end

function NP:OnEnable()
    SetNameplateCVars()
    for unit in pairs(NP.plates) do
        NP.plates[unit]:UpdateAll()
    end
end

function NP:OnDisable()
    -- Blizzard-Nameplates wiederherstellen
    for _, plate in pairs(NP.plates) do
        plate:Hide()
    end
    -- CVars zurücksetzen
    SetCVar("nameplateGlobalScale", "1")
end