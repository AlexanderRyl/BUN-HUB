--[[
    ╔══════════════════════════════════════════════════════════════╗
    ║              PIXEL BLADE LOBBY SCRIPT                       ║
    ║         Full UI Hub — Sliders / Dropdowns / Toggles         ║
    ║               Built from game dump analysis                 ║
    ╚══════════════════════════════════════════════════════════════╝
    
    Features:
      • Combat   — Auto-attack, auto-dodge, auto-parry, aura, ability
      • Farming  — Auto-raid, auto-replay, auto-chest, auto-upgrade
      • Teleport — TP to NPC, TP to zones, orbital TP, speed
      • Fishing  — Auto-cast, auto-reel, auto-bait, fast-fish, sell
      • Charms   — Auto-charm pick, auto-melt rings, enchant
      • Party    — Auto-party, force-rejoin, reconnect
      • Visuals  — Fullbright, no-render, FPS boost, ESP
      • Misc     — Anti-AFK, noclip, infinite jump, walkspeed
]]

-- ══════════════════════════════════════════════════════════════
--  SERVICES
-- ══════════════════════════════════════════════════════════════
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local TweenService       = game:GetService("TweenService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Lighting           = game:GetService("Lighting")
local StarterGui         = game:GetService("StarterGui")
local Workspace          = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

-- ══════════════════════════════════════════════════════════════
--  REMOTE CACHE  (built from _network_remotes)
-- ══════════════════════════════════════════════════════════════
local Remotes = {}
local remotesFolder = ReplicatedStorage:FindFirstChild("_network_remotes")
if remotesFolder then
    for _, remote in remotesFolder:GetChildren() do
        Remotes[remote.Name] = remote
    end
end

local function fireRemote(name, ...)
    local r = Remotes[name]
    if r then
        if r:IsA("RemoteEvent") then
            r:FireServer(...)
        elseif r:IsA("RemoteFunction") then
            return r:InvokeServer(...)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  CONFIG STATE  (mirrors the GPBHub config structure)
-- ══════════════════════════════════════════════════════════════
local Config = {
    -- Combat
    aura            = true,
    ability         = true,
    autododge       = true,
    autoparry       = false,
    ignoredmg       = true,
    radius          = 200,
    speed           = 0.05,

    -- Farming
    autoraid        = true,
    autoreplay      = true,
    autochest       = true,
    autoupgrade     = true,
    autobook        = true,
    autocard        = true,
    autocontinue    = true,
    autoskip        = true,
    autoopenchests  = true,
    darkchest       = true,
    upweapons       = true,
    uparmor         = true,

    -- Teleport
    tp              = true,
    tpspeed         = 400,
    tpdist          = 40,
    tpmove          = "Instant",
    tpside          = "Above",
    tpbelow         = 0,
    tporbit         = true,
    tporbitr        = 60,
    tporbitspeed    = 180,

    -- Fishing
    fastfish        = false,
    autobait        = true,
    bait            = "FleshGrubs",

    -- Charms
    autocharm       = false,
    charmkey        = "UltimateCharm:Legendary",
    charmfallback   = true,
    autopick        = false,

    -- Rings (melt)
    meltcheck       = false,
    meltquality     = 81,
    meltkeeplegendary = true,
    meltRings = {
        SerpentRing  = true, PowerRing    = true, ForestRing  = true,
        ElementRing  = true, GhostRing    = true, DragonRing  = true,
        RageRing     = true, PolarRing    = true, ShadowRing  = true,
        HealthRing   = true, TimelessRing = true, VampireRing = true,
    },

    -- Party
    partyon         = true,
    partyforce      = true,
    partywait       = 60,
    party           = "Kiojunez,LioJuine,Niujioku,Kiojunir",

    -- Reconnect
    reconnect       = false,
    reconnectmode   = "Dungeon",
    reconnectworld  = "CrimsonAbyss",
    reconnectdiff   = "Normal",
    reconnectdelay  = 30,
    reconnectplayers = 4,

    -- Roll
    autoroll        = false,
    rollclass       = "Reaper",

    -- Potion
    autopotion      = false,
    potionhp        = 50,
    potionmin       = 10,
    potionrestock   = false,

    -- Misc
    antiafk         = true,
    noclip          = false,
    infjump         = false,
    fastwalk        = false,
    walkspeed       = 100,
    flyspeed        = 80,
    fly             = false,
    fullbright      = false,
    norender        = false,
    fpsboost        = false,
    circles         = true,
    props           = true,
    showbinds       = true,
    mode            = "All",

    -- Quest
    autoquest       = false,
    questleave      = false,

    -- Sell fish
    sellall         = false,
    sellFish = {
        GoldenTooth   = false, Page         = false, FishGrey     = true,
        DarkKey       = false, StarfishPurple = true, FishBlue    = true,
        StarfishBlue  = true,  FishGold     = false, OldBoot      = true,
        StarfishBrown = true,  FishCyan     = true,
    },

    -- Cards priority
    cards = {
        SpiritCapacity = "P1", LifeSteal     = "Off", PoisonElement = "P2",
        RageSpirits    = "P1", HealthBoost   = "Off", Recovery      = "Off",
        Agility        = "P3", ElementCircle = "P2",  CriticalBoost = "Off",
        Stamina        = "Off", FrostElement = "P2",  FlameElement  = "P2",
        Thorns         = "Off",
    },

    -- UI
    togglekey       = Enum.KeyCode.Delete,
    pausekey        = "Ctrl+P",
    uiscale         = 100,
}

-- ══════════════════════════════════════════════════════════════
--  NPC LIST (extracted from game dump)
-- ══════════════════════════════════════════════════════════════
local NPCs = {
    "npc_Wynn", "npc_WatchmanHalse", "npc_Odger", "npc_TheCharmDealer",
    "npc_Starry", "npc_Maren", "npc_Ash", "npc_WellkeeperWisp",
    "npc_EnchantedLibrarian", "npc_Cap", "npc_FinnTheFisher",
    "npc_QuartermasterVale", "npc_TheBlacksmith", "npc_RoadSentryTilda",
    "npc_CaptainBrenna", "npc_Bo", "npc_MarketWardenOrrin", "npc_Rook",
    "npc_ThePortalWatch", "npc_BrotherCass", "npc_MiloTheApprentice",
    "npc_Nessa", "npc_TreasureHunterDoyle", "npc_Eugene",
    "npc_JosephMavry", "npc_Gilda", "npc_Tam", "npc_ElowenTheSeer",
    "npc_DeliverymanDunn", "npc_StewardAlric", "npc_Corvin", "npc_Perrin",
    "npc_Nan", "npc_PortalwatchMorrow", "npc_HodorTheHorderer",
    "npc_SergeantBex", "npc_TheCharmCollector", "npc_ForagerFen",
    "npc_Clyde", "npc_Mill", "npc_PlagueDoctor", "npc_PipGilly",
}

local Worlds = {
    "CrimsonAbyss", "FrozenWastes", "ShadowRealm", "AncientRuins",
    "DarkForest", "MysticIslands", "VolcanicDepths", "CelestialTower",
}

local Difficulties = { "Normal", "Hard", "Nightmare" }
local Classes      = { "Reaper", "Mage", "Archer", "Warrior", "Assassin" }
local Baits        = { "FleshGrubs", "MagicEyeballs", "GlowWorms", "StarBugs" }
local TPMoves      = { "Instant", "Tween", "Lerp" }
local TPSides      = { "Above", "Behind", "Front" }
local Modes        = { "All", "Solo", "Party" }
local ReconnModes  = { "Dungeon", "Raid" }
local CardPrios    = { "Off", "P1", "P2", "P3" }

-- ══════════════════════════════════════════════════════════════
--  UI LIBRARY  (self-contained, premium dark theme)
-- ══════════════════════════════════════════════════════════════
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PixelBladeHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.DisplayOrder = 999
pcall(function() ScreenGui.Parent = game:GetService("CoreGui") end)
if not ScreenGui.Parent then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

-- ── Color Palette ──
local C = {
    bg          = Color3.fromRGB(18, 18, 22),
    bg2         = Color3.fromRGB(24, 24, 30),
    sidebar     = Color3.fromRGB(14, 14, 18),
    card        = Color3.fromRGB(30, 30, 38),
    cardHover   = Color3.fromRGB(38, 38, 48),
    accent      = Color3.fromRGB(110, 70, 255),
    accent2     = Color3.fromRGB(80, 200, 255),
    accentDim   = Color3.fromRGB(70, 45, 160),
    red         = Color3.fromRGB(255, 70, 70),
    green       = Color3.fromRGB(70, 255, 130),
    yellow      = Color3.fromRGB(255, 210, 60),
    text        = Color3.fromRGB(230, 230, 240),
    textDim     = Color3.fromRGB(140, 140, 160),
    textDark    = Color3.fromRGB(80, 80, 100),
    border      = Color3.fromRGB(45, 45, 60),
    toggle_on   = Color3.fromRGB(110, 70, 255),
    toggle_off  = Color3.fromRGB(55, 55, 70),
    slider_bg   = Color3.fromRGB(40, 40, 55),
    slider_fill = Color3.fromRGB(110, 70, 255),
    dropdown_bg = Color3.fromRGB(25, 25, 35),
}

local FONT        = Font.fromEnum(Enum.Font.GothamBold)
local FONT_MED    = Font.fromEnum(Enum.Font.GothamMedium)
local FONT_REG    = Font.fromEnum(Enum.Font.Gotham)
local CORNER_SM   = UDim.new(0, 6)
local CORNER_MD   = UDim.new(0, 8)
local CORNER_LG   = UDim.new(0, 12)
local CORNER_FULL = UDim.new(0, 999)

local function addCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = radius or CORNER_MD
    c.Parent = parent
    return c
end

local function addStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Color = color or C.border
    s.Thickness = thickness or 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = parent
    return s
end

local function addPadding(parent, t, b, l, r)
    local p = Instance.new("UIPadding")
    p.PaddingTop    = UDim.new(0, t or 8)
    p.PaddingBottom = UDim.new(0, b or 8)
    p.PaddingLeft   = UDim.new(0, l or 10)
    p.PaddingRight  = UDim.new(0, r or 10)
    p.Parent = parent
    return p
end

local function addList(parent, dir, pad, halign, valign)
    local l = Instance.new("UIListLayout")
    l.FillDirection = dir or Enum.FillDirection.Vertical
    l.Padding = UDim.new(0, pad or 6)
    l.HorizontalAlignment = halign or Enum.HorizontalAlignment.Left
    l.VerticalAlignment   = valign or Enum.VerticalAlignment.Top
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = parent
    return l
end

local function tween(obj, props, dur, style, dir)
    local info = TweenInfo.new(
        dur or 0.2,
        style or Enum.EasingStyle.Quad,
        dir or Enum.EasingDirection.Out
    )
    local t = TweenService:Create(obj, info, props)
    t:Play()
    return t
end

-- ══════════════════════════════════════════════════════════════
--  MAIN WINDOW
-- ══════════════════════════════════════════════════════════════
local WINDOW_W = 560
local WINDOW_H = 440
local SIDEBAR_W = 140
local TAB_CONTENT_W = WINDOW_W - SIDEBAR_W

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)
MainFrame.Position = UDim2.new(0.5, -WINDOW_W/2, 0.5, -WINDOW_H/2)
MainFrame.BackgroundColor3 = C.bg
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui
addCorner(MainFrame, CORNER_LG)
addStroke(MainFrame, C.border, 1.5)

-- Drop shadow
local Shadow = Instance.new("ImageLabel")
Shadow.Name = "Shadow"
Shadow.Size = UDim2.new(1, 40, 1, 40)
Shadow.Position = UDim2.new(0, -20, 0, -20)
Shadow.BackgroundTransparency = 1
Shadow.Image = "rbxassetid://6015897843"
Shadow.ImageColor3 = Color3.new(0, 0, 0)
Shadow.ImageTransparency = 0.5
Shadow.ScaleType = Enum.ScaleType.Slice
Shadow.SliceCenter = Rect.new(49, 49, 450, 450)
Shadow.ZIndex = -1
Shadow.Parent = MainFrame

-- ── Title Bar ──
local TitleBar = Instance.new("Frame")
TitleBar.Name = "TitleBar"
TitleBar.Size = UDim2.new(1, 0, 0, 36)
TitleBar.BackgroundColor3 = C.sidebar
TitleBar.BorderSizePixel = 0
TitleBar.Parent = MainFrame
addCorner(TitleBar, UDim.new(0, 12))

local TitleClip = Instance.new("Frame")
TitleClip.Size = UDim2.new(1, 0, 0, 14)
TitleClip.Position = UDim2.new(0, 0, 1, -14)
TitleClip.BackgroundColor3 = C.sidebar
TitleClip.BorderSizePixel = 0
TitleClip.Parent = TitleBar

local AccentLine = Instance.new("Frame")
AccentLine.Size = UDim2.new(1, 0, 0, 2)
AccentLine.Position = UDim2.new(0, 0, 0, 36)
AccentLine.BackgroundColor3 = C.accent
AccentLine.BorderSizePixel = 0
AccentLine.Parent = MainFrame

local AccentGrad = Instance.new("UIGradient")
AccentGrad.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, C.accent),
    ColorSequenceKeypoint.new(0.5, C.accent2),
    ColorSequenceKeypoint.new(1, C.accent),
}
AccentGrad.Parent = AccentLine

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -80, 1, 0)
TitleLabel.Position = UDim2.new(0, 14, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚔ PIXEL BLADE HUB"
TitleLabel.FontFace = FONT
TitleLabel.TextSize = 14
TitleLabel.TextColor3 = C.text
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = TitleBar

-- Close / Minimize buttons
local function titleBtn(text, pos, color)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0, 28, 0, 28)
    btn.Position = pos
    btn.BackgroundColor3 = C.card
    btn.Text = text
    btn.FontFace = FONT
    btn.TextSize = 14
    btn.TextColor3 = color or C.textDim
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.Parent = TitleBar
    addCorner(btn, CORNER_SM)
    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = C.cardHover}, 0.15) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = C.card}, 0.15) end)
    return btn
end

local MinBtn   = titleBtn("—", UDim2.new(1, -62, 0.5, -14), C.yellow)
local CloseBtn = titleBtn("✕", UDim2.new(1, -32, 0.5, -14), C.red)

CloseBtn.MouseButton1Click:Connect(function()
    tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, 0)}, 0.25)
    task.wait(0.26)
    ScreenGui:Destroy()
end)

local minimized = false
MinBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, 38)}, 0.25)
    else
        tween(MainFrame, {Size = UDim2.new(0, WINDOW_W, 0, WINDOW_H)}, 0.25)
    end
end)

-- ── Drag ──
local dragging, dragStart, startPos
TitleBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or
                     input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end)

-- ══════════════════════════════════════════════════════════════
--  SIDEBAR
-- ══════════════════════════════════════════════════════════════
local Sidebar = Instance.new("Frame")
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -38)
Sidebar.Position = UDim2.new(0, 0, 0, 38)
Sidebar.BackgroundColor3 = C.sidebar
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideScroll = Instance.new("ScrollingFrame")
SideScroll.Size = UDim2.new(1, 0, 1, 0)
SideScroll.BackgroundTransparency = 1
SideScroll.ScrollBarThickness = 0
SideScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
SideScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
SideScroll.BorderSizePixel = 0
SideScroll.Parent = Sidebar
addPadding(SideScroll, 8, 8, 8, 8)
addList(SideScroll, nil, 4)

local ContentFrame = Instance.new("Frame")
ContentFrame.Name = "Content"
ContentFrame.Size = UDim2.new(0, TAB_CONTENT_W, 1, -38)
ContentFrame.Position = UDim2.new(0, SIDEBAR_W, 0, 38)
ContentFrame.BackgroundColor3 = C.bg
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

-- ══════════════════════════════════════════════════════════════
--  TAB SYSTEM
-- ══════════════════════════════════════════════════════════════
local Tabs = {}
local TabButtons = {}
local ActiveTab = nil

local TabDefs = {
    {name = "⚔  Combat",   id = "combat"},
    {name = "🌾  Farm",     id = "farm"},
    {name = "📍  Teleport", id = "teleport"},
    {name = "🎣  Fishing",  id = "fishing"},
    {name = "💎  Charms",   id = "charms"},
    {name = "👥  Party",    id = "party"},
    {name = "👁  Visuals",  id = "visuals"},
    {name = "⚙  Misc",     id = "misc"},
}

for i, def in ipairs(TabDefs) do
    local btn = Instance.new("TextButton")
    btn.Name = "Tab_" .. def.id
    btn.Size = UDim2.new(1, 0, 0, 32)
    btn.BackgroundColor3 = C.sidebar
    btn.Text = def.name
    btn.FontFace = FONT_MED
    btn.TextSize = 12
    btn.TextColor3 = C.textDim
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = i
    btn.Parent = SideScroll
    addCorner(btn, CORNER_SM)
    addPadding(btn, 0, 0, 10, 0)

    local indicator = Instance.new("Frame")
    indicator.Name = "Indicator"
    indicator.Size = UDim2.new(0, 3, 0.6, 0)
    indicator.Position = UDim2.new(0, 0, 0.2, 0)
    indicator.BackgroundColor3 = C.accent
    indicator.BorderSizePixel = 0
    indicator.Visible = false
    indicator.Parent = btn
    addCorner(indicator, CORNER_FULL)

    local tabScroll = Instance.new("ScrollingFrame")
    tabScroll.Name = "TabContent_" .. def.id
    tabScroll.Size = UDim2.new(1, 0, 1, 0)
    tabScroll.BackgroundTransparency = 1
    tabScroll.ScrollBarThickness = 3
    tabScroll.ScrollBarImageColor3 = C.accent
    tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    tabScroll.BorderSizePixel = 0
    tabScroll.Visible = false
    tabScroll.Parent = ContentFrame
    addPadding(tabScroll, 10, 10, 12, 12)
    addList(tabScroll, nil, 6)

    Tabs[def.id] = tabScroll
    TabButtons[def.id] = {btn = btn, indicator = indicator}

    btn.MouseEnter:Connect(function()
        if ActiveTab ~= def.id then tween(btn, {BackgroundColor3 = C.card}, 0.15) end
    end)
    btn.MouseLeave:Connect(function()
        if ActiveTab ~= def.id then tween(btn, {BackgroundColor3 = C.sidebar}, 0.15) end
    end)

    btn.MouseButton1Click:Connect(function()
        if ActiveTab and TabButtons[ActiveTab] then
            local old = TabButtons[ActiveTab]
            tween(old.btn, {BackgroundColor3 = C.sidebar, TextColor3 = C.textDim}, 0.2)
            old.indicator.Visible = false
            Tabs[ActiveTab].Visible = false
        end
        ActiveTab = def.id
        tween(btn, {BackgroundColor3 = C.card, TextColor3 = C.text}, 0.2)
        indicator.Visible = true
        tabScroll.Visible = true
    end)
end

-- ══════════════════════════════════════════════════════════════
--  UI COMPONENT BUILDERS
-- ══════════════════════════════════════════════════════════════

local function createSection(parent, title, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 24)
    frame.BackgroundTransparency = 1
    frame.LayoutOrder = order or 0
    frame.Parent = parent

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = string.upper(title)
    label.FontFace = FONT
    label.TextSize = 11
    label.TextColor3 = C.accent
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = frame

    local line = Instance.new("Frame")
    line.Size = UDim2.new(1, 0, 0, 1)
    line.Position = UDim2.new(0, 0, 1, -1)
    line.BackgroundColor3 = C.border
    line.BorderSizePixel = 0
    line.Parent = frame
    return frame
end

local function createToggle(parent, label, configKey, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundColor3 = C.card
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order or 0
    frame.Parent = parent
    addCorner(frame, CORNER_SM)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -60, 1, 0)
    txt.Position = UDim2.new(0, 10, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.FontFace = FONT_REG
    txt.TextSize = 12
    txt.TextColor3 = C.text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = frame

    local toggleBg = Instance.new("Frame")
    toggleBg.Size = UDim2.new(0, 38, 0, 20)
    toggleBg.Position = UDim2.new(1, -48, 0.5, -10)
    toggleBg.BackgroundColor3 = Config[configKey] and C.toggle_on or C.toggle_off
    toggleBg.BorderSizePixel = 0
    toggleBg.Parent = frame
    addCorner(toggleBg, CORNER_FULL)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 16, 0, 16)
    knob.Position = Config[configKey] and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.Parent = toggleBg
    addCorner(knob, CORNER_FULL)

    local clickArea = Instance.new("TextButton")
    clickArea.Size = UDim2.new(1, 0, 1, 0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text = ""
    clickArea.Parent = frame

    clickArea.MouseButton1Click:Connect(function()
        Config[configKey] = not Config[configKey]
        local on = Config[configKey]
        tween(toggleBg, {BackgroundColor3 = on and C.toggle_on or C.toggle_off}, 0.2)
        tween(knob, {Position = on and UDim2.new(1, -18, 0.5, -8) or UDim2.new(0, 2, 0.5, -8)}, 0.2)
        if callback then callback(on) end
    end)

    clickArea.MouseEnter:Connect(function() tween(frame, {BackgroundColor3 = C.cardHover}, 0.12) end)
    clickArea.MouseLeave:Connect(function() tween(frame, {BackgroundColor3 = C.card}, 0.12) end)
    return frame
end

local function createSlider(parent, label, configKey, min, max, step, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 46)
    frame.BackgroundColor3 = C.card
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order or 0
    frame.Parent = parent
    addCorner(frame, CORNER_SM)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(0.6, 0, 0, 18)
    txt.Position = UDim2.new(0, 10, 0, 4)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.FontFace = FONT_REG
    txt.TextSize = 11
    txt.TextColor3 = C.text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = frame

    local valLabel = Instance.new("TextLabel")
    valLabel.Size = UDim2.new(0.35, 0, 0, 18)
    valLabel.Position = UDim2.new(0.65, -10, 0, 4)
    valLabel.BackgroundTransparency = 1
    valLabel.Text = tostring(Config[configKey])
    valLabel.FontFace = FONT
    valLabel.TextSize = 11
    valLabel.TextColor3 = C.accent2
    valLabel.TextXAlignment = Enum.TextXAlignment.Right
    valLabel.Parent = frame

    local sliderBg = Instance.new("Frame")
    sliderBg.Size = UDim2.new(1, -20, 0, 8)
    sliderBg.Position = UDim2.new(0, 10, 0, 30)
    sliderBg.BackgroundColor3 = C.slider_bg
    sliderBg.BorderSizePixel = 0
    sliderBg.Parent = frame
    addCorner(sliderBg, CORNER_FULL)

    local fillPct = math.clamp((Config[configKey] - min) / (max - min), 0, 1)
    local fill = Instance.new("Frame")
    fill.Size = UDim2.new(fillPct, 0, 1, 0)
    fill.BackgroundColor3 = C.slider_fill
    fill.BorderSizePixel = 0
    fill.Parent = sliderBg
    addCorner(fill, CORNER_FULL)

    local fillGrad = Instance.new("UIGradient")
    fillGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.accent2),
    }
    fillGrad.Parent = fill

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0, 14, 0, 14)
    knob.Position = UDim2.new(fillPct, -7, 0.5, -7)
    knob.BackgroundColor3 = Color3.new(1, 1, 1)
    knob.BorderSizePixel = 0
    knob.ZIndex = 3
    knob.Parent = sliderBg
    addCorner(knob, CORNER_FULL)
    addStroke(knob, C.accent, 2)

    local sliding = false
    local sliderInput = Instance.new("TextButton")
    sliderInput.Size = UDim2.new(1, 0, 1, 12)
    sliderInput.Position = UDim2.new(0, 0, 0, -6)
    sliderInput.BackgroundTransparency = 1
    sliderInput.Text = ""
    sliderInput.ZIndex = 4
    sliderInput.Parent = sliderBg

    local function updateSlider(inputPos)
        local absPos = sliderBg.AbsolutePosition.X
        local absSize = sliderBg.AbsoluteSize.X
        local pct = math.clamp((inputPos - absPos) / absSize, 0, 1)
        local raw = min + pct * (max - min)
        local stepped = math.floor(raw / step + 0.5) * step
        stepped = math.clamp(stepped, min, max)
        Config[configKey] = stepped
        local newPct = (stepped - min) / (max - min)
        fill.Size = UDim2.new(newPct, 0, 1, 0)
        knob.Position = UDim2.new(newPct, -7, 0.5, -7)
        valLabel.Text = tostring(stepped)
        if callback then callback(stepped) end
    end

    sliderInput.MouseButton1Down:Connect(function() sliding = true end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then sliding = false end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if sliding and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateSlider(input.Position.X)
        end
    end)
    sliderInput.MouseButton1Click:Connect(function()
        local mouse = UserInputService:GetMouseLocation()
        updateSlider(mouse.X)
    end)
    return frame
end

local function createDropdown(parent, label, configKey, options, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundColor3 = C.card
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order or 0
    frame.ClipsDescendants = false
    frame.Parent = parent
    addCorner(frame, CORNER_SM)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(0.5, 0, 1, 0)
    txt.Position = UDim2.new(0, 10, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.FontFace = FONT_REG
    txt.TextSize = 11
    txt.TextColor3 = C.text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = frame

    local dropBtn = Instance.new("TextButton")
    dropBtn.Size = UDim2.new(0.45, 0, 0, 24)
    dropBtn.Position = UDim2.new(0.53, 0, 0.5, -12)
    dropBtn.BackgroundColor3 = C.dropdown_bg
    dropBtn.Text = tostring(Config[configKey]) .. "  ▾"
    dropBtn.FontFace = FONT_MED
    dropBtn.TextSize = 11
    dropBtn.TextColor3 = C.accent2
    dropBtn.BorderSizePixel = 0
    dropBtn.AutoButtonColor = false
    dropBtn.ZIndex = 5
    dropBtn.Parent = frame
    addCorner(dropBtn, CORNER_SM)
    addStroke(dropBtn, C.border, 1)

    local optionsFrame = Instance.new("Frame")
    optionsFrame.Size = UDim2.new(0.45, 0, 0, 0)
    optionsFrame.Position = UDim2.new(0.53, 0, 1, 2)
    optionsFrame.BackgroundColor3 = C.dropdown_bg
    optionsFrame.BorderSizePixel = 0
    optionsFrame.ClipsDescendants = true
    optionsFrame.Visible = false
    optionsFrame.ZIndex = 100
    optionsFrame.Parent = frame
    addCorner(optionsFrame, CORNER_SM)
    addStroke(optionsFrame, C.accent, 1)

    local optScroll = Instance.new("ScrollingFrame")
    optScroll.Size = UDim2.new(1, 0, 1, 0)
    optScroll.BackgroundTransparency = 1
    optScroll.ScrollBarThickness = 2
    optScroll.ScrollBarImageColor3 = C.accent
    optScroll.CanvasSize = UDim2.new(0, 0, 0, #options * 24)
    optScroll.BorderSizePixel = 0
    optScroll.ZIndex = 101
    optScroll.Parent = optionsFrame
    addList(optScroll, nil, 0)

    local open = false
    local maxVis = math.min(#options, 6)
    local dropH = maxVis * 24

    for _, opt in ipairs(options) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.BackgroundColor3 = C.dropdown_bg
        optBtn.Text = tostring(opt)
        optBtn.FontFace = FONT_REG
        optBtn.TextSize = 11
        optBtn.TextColor3 = C.text
        optBtn.BorderSizePixel = 0
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 102
        optBtn.Parent = optScroll

        optBtn.MouseEnter:Connect(function() tween(optBtn, {BackgroundColor3 = C.accentDim}, 0.1) end)
        optBtn.MouseLeave:Connect(function() tween(optBtn, {BackgroundColor3 = C.dropdown_bg}, 0.1) end)

        optBtn.MouseButton1Click:Connect(function()
            Config[configKey] = opt
            dropBtn.Text = tostring(opt) .. "  ▾"
            open = false
            tween(optionsFrame, {Size = UDim2.new(0.45, 0, 0, 0)}, 0.15)
            task.wait(0.16)
            optionsFrame.Visible = false
            if callback then callback(opt) end
        end)
    end

    dropBtn.MouseButton1Click:Connect(function()
        open = not open
        if open then
            optionsFrame.Visible = true
            tween(optionsFrame, {Size = UDim2.new(0.45, 0, 0, dropH)}, 0.15)
        else
            tween(optionsFrame, {Size = UDim2.new(0.45, 0, 0, 0)}, 0.15)
            task.wait(0.16)
            optionsFrame.Visible = false
        end
    end)

    frame.MouseEnter:Connect(function() tween(frame, {BackgroundColor3 = C.cardHover}, 0.12) end)
    frame.MouseLeave:Connect(function() tween(frame, {BackgroundColor3 = C.card}, 0.12) end)
    return frame
end

local function createButton(parent, label, order, callback)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 30)
    btn.BackgroundColor3 = C.accentDim
    btn.Text = label
    btn.FontFace = FONT_MED
    btn.TextSize = 12
    btn.TextColor3 = C.text
    btn.BorderSizePixel = 0
    btn.AutoButtonColor = false
    btn.LayoutOrder = order or 0
    btn.Parent = parent
    addCorner(btn, CORNER_SM)

    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.accent),
        ColorSequenceKeypoint.new(1, C.accentDim),
    }
    grad.Rotation = 90
    grad.Parent = btn

    btn.MouseEnter:Connect(function() tween(btn, {BackgroundColor3 = C.accent}, 0.12) end)
    btn.MouseLeave:Connect(function() tween(btn, {BackgroundColor3 = C.accentDim}, 0.12) end)
    btn.MouseButton1Click:Connect(function()
        tween(btn, {BackgroundColor3 = C.accent2}, 0.08)
        task.wait(0.1)
        tween(btn, {BackgroundColor3 = C.accentDim}, 0.15)
        if callback then callback() end
    end)
    return btn
end

local function createTextInput(parent, label, configKey, order, callback)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 30)
    frame.BackgroundColor3 = C.card
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order or 0
    frame.Parent = parent
    addCorner(frame, CORNER_SM)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(0.4, 0, 1, 0)
    txt.Position = UDim2.new(0, 10, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.FontFace = FONT_REG
    txt.TextSize = 11
    txt.TextColor3 = C.text
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(0.55, -10, 0, 22)
    box.Position = UDim2.new(0.43, 0, 0.5, -11)
    box.BackgroundColor3 = C.dropdown_bg
    box.Text = tostring(Config[configKey])
    box.FontFace = FONT_REG
    box.TextSize = 11
    box.TextColor3 = C.accent2
    box.PlaceholderColor3 = C.textDark
    box.BorderSizePixel = 0
    box.ClearTextOnFocus = false
    box.Parent = frame
    addCorner(box, CORNER_SM)
    addStroke(box, C.border, 1)

    box.FocusLost:Connect(function()
        local val = box.Text
        if type(Config[configKey]) == "number" then
            val = tonumber(val) or Config[configKey]
        end
        Config[configKey] = val
        box.Text = tostring(val)
        if callback then callback(val) end
    end)
    return frame
end

-- ── Sub-toggle for nested tables (fish/rings) ──
local function createSubToggle(parent, label, tbl, key, order)
    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, 0, 0, 26)
    frame.BackgroundColor3 = C.card
    frame.BorderSizePixel = 0
    frame.LayoutOrder = order
    frame.Parent = parent
    addCorner(frame, CORNER_SM)

    local txt = Instance.new("TextLabel")
    txt.Size = UDim2.new(1, -60, 1, 0)
    txt.Position = UDim2.new(0, 10, 0, 0)
    txt.BackgroundTransparency = 1
    txt.Text = label
    txt.FontFace = FONT_REG
    txt.TextSize = 10
    txt.TextColor3 = C.textDim
    txt.TextXAlignment = Enum.TextXAlignment.Left
    txt.Parent = frame

    local togBg = Instance.new("Frame")
    togBg.Size = UDim2.new(0, 32, 0, 16)
    togBg.Position = UDim2.new(1, -42, 0.5, -8)
    togBg.BackgroundColor3 = tbl[key] and C.toggle_on or C.toggle_off
    togBg.BorderSizePixel = 0
    togBg.Parent = frame
    addCorner(togBg, CORNER_FULL)

    local kn = Instance.new("Frame")
    kn.Size = UDim2.new(0, 12, 0, 12)
    kn.Position = tbl[key] and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)
    kn.BackgroundColor3 = Color3.new(1, 1, 1)
    kn.BorderSizePixel = 0
    kn.Parent = togBg
    addCorner(kn, CORNER_FULL)

    local click = Instance.new("TextButton")
    click.Size = UDim2.new(1, 0, 1, 0)
    click.BackgroundTransparency = 1
    click.Text = ""
    click.Parent = frame
    click.MouseButton1Click:Connect(function()
        tbl[key] = not tbl[key]
        local on = tbl[key]
        tween(togBg, {BackgroundColor3 = on and C.toggle_on or C.toggle_off}, 0.2)
        tween(kn, {Position = on and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6)}, 0.2)
    end)
    return frame
end

-- ══════════════════════════════════════════════════════════════
--  POPULATE TABS
-- ══════════════════════════════════════════════════════════════

-- ── COMBAT TAB ──
do
    local tab = Tabs["combat"]
    createSection(tab, "Auto Combat", 1)
    createToggle(tab, "Aura (Attack Nearby)", "aura", 2)
    createToggle(tab, "Use Abilities", "ability", 3)
    createToggle(tab, "Auto Dodge", "autododge", 4)
    createToggle(tab, "Auto Parry", "autoparry", 5)
    createToggle(tab, "Ignore Damage Indicators", "ignoredmg", 6)
    createToggle(tab, "Show Circles", "circles", 7)

    createSection(tab, "Range & Speed", 10)
    createSlider(tab, "Aura Radius", "radius", 10, 500, 10, 11)
    createSlider(tab, "Attack Speed", "speed", 0.01, 0.5, 0.01, 12)

    createSection(tab, "Class", 20)
    createDropdown(tab, "Roll Class", "rollclass", Classes, 21)
    createToggle(tab, "Auto Roll Class", "autoroll", 22)

    createSection(tab, "Actions", 30)
    createButton(tab, "🗡  Kill All Enemies", 31, function() fireRemote("debug_kill_all") end)
    createButton(tab, "⏭  Skip to Next Room", 32, function() fireRemote("debug_teleport_next_room") end)
    createButton(tab, "🏰  Jump to Boss Wave", 33, function() fireRemote("debug_jump_boss_wave") end)
end

-- ── FARM TAB ──
do
    local tab = Tabs["farm"]
    createSection(tab, "Auto Farming", 1)
    createToggle(tab, "Auto Raid", "autoraid", 2)
    createToggle(tab, "Auto Replay", "autoreplay", 3)
    createToggle(tab, "Auto Continue", "autocontinue", 4)
    createToggle(tab, "Auto Skip Cutscenes", "autoskip", 5)

    createSection(tab, "Chests & Upgrades", 10)
    createToggle(tab, "Auto Open Chests", "autochest", 11)
    createToggle(tab, "Auto Open Dark Chests", "darkchest", 12)
    createToggle(tab, "Auto Open All Chests", "autoopenchests", 13)
    createToggle(tab, "Auto Upgrade Weapons", "upweapons", 14)
    createToggle(tab, "Auto Upgrade Armor", "uparmor", 15)
    createToggle(tab, "Auto Upgrade All", "autoupgrade", 16)

    createSection(tab, "Cards & Books", 20)
    createToggle(tab, "Auto Pick Cards", "autocard", 21)
    createToggle(tab, "Auto Enchant Books", "autobook", 22)

    createSection(tab, "Quest", 30)
    createToggle(tab, "Auto Quest", "autoquest", 31)
    createToggle(tab, "Leave After Quest", "questleave", 32)

    createSection(tab, "Card Bulk", 40)
    createButton(tab, "📜  Set All Cards P1", 41, function()
        for k in pairs(Config.cards) do Config.cards[k] = "P1" end
    end)
    createButton(tab, "❌  Disable All Cards", 42, function()
        for k in pairs(Config.cards) do Config.cards[k] = "Off" end
    end)
end

-- ── TELEPORT TAB ──
do
    local tab = Tabs["teleport"]
    createSection(tab, "Movement", 1)
    createToggle(tab, "Teleport Enabled", "tp", 2)
    createToggle(tab, "Orbital TP", "tporbit", 3)
    createDropdown(tab, "TP Method", "tpmove", TPMoves, 4)
    createDropdown(tab, "TP Side", "tpside", TPSides, 5)

    createSection(tab, "Speed Settings", 10)
    createSlider(tab, "TP Speed", "tpspeed", 50, 2000, 50, 11)
    createSlider(tab, "TP Distance", "tpdist", 5, 200, 5, 12)
    createSlider(tab, "TP Below Offset", "tpbelow", 0, 100, 5, 13)
    createSlider(tab, "Orbit Radius", "tporbitr", 10, 200, 5, 14)
    createSlider(tab, "Orbit Speed", "tporbitspeed", 30, 500, 10, 15)

    createSection(tab, "NPC Teleport", 20)
    local selectedNPC = NPCs[1]
    local npcNames = {}
    for _, n in ipairs(NPCs) do table.insert(npcNames, n:gsub("npc_", "")) end

    -- Use a local var for NPC selection so dropdown doesn't clash with config
    local npcDropFrame = Instance.new("Frame")
    npcDropFrame.Size = UDim2.new(1, 0, 0, 30)
    npcDropFrame.BackgroundColor3 = C.card
    npcDropFrame.BorderSizePixel = 0
    npcDropFrame.LayoutOrder = 21
    npcDropFrame.ClipsDescendants = false
    npcDropFrame.Parent = tab
    addCorner(npcDropFrame, CORNER_SM)

    local npcLbl = Instance.new("TextLabel")
    npcLbl.Size = UDim2.new(0.5, 0, 1, 0)
    npcLbl.Position = UDim2.new(0, 10, 0, 0)
    npcLbl.BackgroundTransparency = 1
    npcLbl.Text = "Select NPC"
    npcLbl.FontFace = FONT_REG
    npcLbl.TextSize = 11
    npcLbl.TextColor3 = C.text
    npcLbl.TextXAlignment = Enum.TextXAlignment.Left
    npcLbl.Parent = npcDropFrame

    local npcDropBtn = Instance.new("TextButton")
    npcDropBtn.Size = UDim2.new(0.45, 0, 0, 24)
    npcDropBtn.Position = UDim2.new(0.53, 0, 0.5, -12)
    npcDropBtn.BackgroundColor3 = C.dropdown_bg
    npcDropBtn.Text = npcNames[1] .. "  ▾"
    npcDropBtn.FontFace = FONT_MED
    npcDropBtn.TextSize = 11
    npcDropBtn.TextColor3 = C.accent2
    npcDropBtn.BorderSizePixel = 0
    npcDropBtn.AutoButtonColor = false
    npcDropBtn.ZIndex = 5
    npcDropBtn.Parent = npcDropFrame
    addCorner(npcDropBtn, CORNER_SM)
    addStroke(npcDropBtn, C.border, 1)

    local npcOptFrame = Instance.new("Frame")
    npcOptFrame.Size = UDim2.new(0.45, 0, 0, 0)
    npcOptFrame.Position = UDim2.new(0.53, 0, 1, 2)
    npcOptFrame.BackgroundColor3 = C.dropdown_bg
    npcOptFrame.BorderSizePixel = 0
    npcOptFrame.ClipsDescendants = true
    npcOptFrame.Visible = false
    npcOptFrame.ZIndex = 100
    npcOptFrame.Parent = npcDropFrame
    addCorner(npcOptFrame, CORNER_SM)
    addStroke(npcOptFrame, C.accent, 1)

    local npcScroll = Instance.new("ScrollingFrame")
    npcScroll.Size = UDim2.new(1, 0, 1, 0)
    npcScroll.BackgroundTransparency = 1
    npcScroll.ScrollBarThickness = 2
    npcScroll.ScrollBarImageColor3 = C.accent
    npcScroll.CanvasSize = UDim2.new(0, 0, 0, #npcNames * 24)
    npcScroll.BorderSizePixel = 0
    npcScroll.ZIndex = 101
    npcScroll.Parent = npcOptFrame
    addList(npcScroll, nil, 0)

    local npcOpen = false
    for _, name in ipairs(npcNames) do
        local optBtn = Instance.new("TextButton")
        optBtn.Size = UDim2.new(1, 0, 0, 24)
        optBtn.BackgroundColor3 = C.dropdown_bg
        optBtn.Text = name
        optBtn.FontFace = FONT_REG
        optBtn.TextSize = 11
        optBtn.TextColor3 = C.text
        optBtn.BorderSizePixel = 0
        optBtn.AutoButtonColor = false
        optBtn.ZIndex = 102
        optBtn.Parent = npcScroll
        optBtn.MouseEnter:Connect(function() tween(optBtn, {BackgroundColor3 = C.accentDim}, 0.1) end)
        optBtn.MouseLeave:Connect(function() tween(optBtn, {BackgroundColor3 = C.dropdown_bg}, 0.1) end)
        optBtn.MouseButton1Click:Connect(function()
            selectedNPC = "npc_" .. name
            npcDropBtn.Text = name .. "  ▾"
            npcOpen = false
            tween(npcOptFrame, {Size = UDim2.new(0.45, 0, 0, 0)}, 0.15)
            task.wait(0.16)
            npcOptFrame.Visible = false
        end)
    end
    npcDropBtn.MouseButton1Click:Connect(function()
        npcOpen = not npcOpen
        if npcOpen then
            npcOptFrame.Visible = true
            tween(npcOptFrame, {Size = UDim2.new(0.45, 0, 0, 144)}, 0.15)
        else
            tween(npcOptFrame, {Size = UDim2.new(0.45, 0, 0, 0)}, 0.15)
            task.wait(0.16)
            npcOptFrame.Visible = false
        end
    end)

    createButton(tab, "📍  Teleport to NPC", 22, function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local npc = Workspace:FindFirstChild(selectedNPC)
        if npc then
            local npcRoot = npc:FindFirstChild("HumanoidRootPart")
            if npcRoot then hrp.CFrame = npcRoot.CFrame * CFrame.new(0, 0, 5) end
        end
    end)
    createButton(tab, "🏠  Teleport to Lobby Spawn", 23, function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(3182, 190, -72)
        end
    end)
    createButton(tab, "⭐  Teleport to Wish Stand", 24, function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local map = Workspace:FindFirstChild("map")
        if map then
            local ws = map:FindFirstChild("wish_stand")
            if ws then
                local p = ws.PrimaryPart or ws:FindFirstChildWhichIsA("BasePart")
                if p then hrp.CFrame = p.CFrame * CFrame.new(0, 3, 5) end
            end
        end
    end)
    createButton(tab, "🐟  Teleport to Fishing Spot", 25, function()
        local char = LocalPlayer.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local map = Workspace:FindFirstChild("map")
        if map then
            local fp = map:FindFirstChild("FishingTpPosition")
            if fp then hrp.CFrame = fp.CFrame * CFrame.new(0, 3, 0) end
        end
    end)
end

-- ── FISHING TAB ──
do
    local tab = Tabs["fishing"]
    createSection(tab, "Auto Fishing", 1)
    createToggle(tab, "Fast Fish", "fastfish", 2)
    createToggle(tab, "Auto Bait", "autobait", 3)
    createDropdown(tab, "Bait Type", "bait", Baits, 4)

    createSection(tab, "Sell Fish", 10)
    createToggle(tab, "Sell All Fish", "sellall", 11)
    local fishOrder = 12
    for fishName, _ in pairs(Config.sellFish) do
        createSubToggle(tab, fishName:gsub("(%u)", " %1"):gsub("^%s", ""), Config.sellFish, fishName, fishOrder)
        fishOrder = fishOrder + 1
    end

    createSection(tab, "Actions", 30)
    createButton(tab, "🎣  Cast Line", 31, function() fireRemote("fishing_cast") end)
    createButton(tab, "🔄  Reel In", 32, function() fireRemote("fishing_reel") end)
    createButton(tab, "💰  Sell All Fish Catches", 33, function() fireRemote("sell_fish_catch") end)
    createButton(tab, "🧲  Toggle Fishing Rod", 34, function() fireRemote("toggle_rod") end)
end

-- ── CHARMS TAB ──
do
    local tab = Tabs["charms"]
    createSection(tab, "Auto Charms", 1)
    createToggle(tab, "Auto Charm Pick", "autocharm", 2)
    createToggle(tab, "Auto Pick Best", "autopick", 3)
    createToggle(tab, "Charm Fallback", "charmfallback", 4)

    createSection(tab, "Ring Melting", 10)
    createToggle(tab, "Melt Check", "meltcheck", 11)
    createToggle(tab, "Keep Legendary Rings", "meltkeeplegendary", 12)
    createSlider(tab, "Melt Quality Threshold", "meltquality", 1, 100, 1, 13)

    createSection(tab, "Melt Rings", 20)
    local ringOrder = 21
    for ringName, _ in pairs(Config.meltRings) do
        createSubToggle(tab, ringName:gsub("Ring", " Ring"), Config.meltRings, ringName, ringOrder)
        ringOrder = ringOrder + 1
    end

    createSection(tab, "Enchanting", 40)
    createButton(tab, "🔮  Roll Enchant", 41, function() fireRemote("roll_enchant") end)
    createButton(tab, "💰  Sell Enchant", 42, function() fireRemote("sell_enchant") end)
    createButton(tab, "🔗  Merge Enchants", 43, function() fireRemote("merge_enchants") end)

    createSection(tab, "Wishes", 50)
    createButton(tab, "⭐  Open Wish", 51, function() fireRemote("open_wish") end)
end

-- ── PARTY TAB ──
do
    local tab = Tabs["party"]
    createSection(tab, "Party Settings", 1)
    createToggle(tab, "Party Enabled", "partyon", 2)
    createToggle(tab, "Force Party Join", "partyforce", 3)
    createSlider(tab, "Party Wait (sec)", "partywait", 10, 300, 10, 4)
    createTextInput(tab, "Party Members", "party", 5)
    createDropdown(tab, "Mode", "mode", Modes, 6)

    createSection(tab, "Reconnect", 10)
    createToggle(tab, "Auto Reconnect", "reconnect", 11)
    createDropdown(tab, "Reconnect Mode", "reconnectmode", ReconnModes, 12)
    createDropdown(tab, "World", "reconnectworld", Worlds, 13)
    createDropdown(tab, "Difficulty", "reconnectdiff", Difficulties, 14)
    createSlider(tab, "Reconnect Delay (sec)", "reconnectdelay", 5, 300, 5, 15)
    createSlider(tab, "Min Players", "reconnectplayers", 1, 8, 1, 16)

    createSection(tab, "Actions", 20)
    createButton(tab, "👥  Invite Party", 21, function() fireRemote("invite_to_party") end)
    createButton(tab, "🚪  Leave Party", 22, function() fireRemote("leave_party") end)
    createButton(tab, "🎮  Create Play Session", 23, function() fireRemote("create_play_session") end)
    createButton(tab, "🏰  Join Raid Browser", 24, function() fireRemote("set_raid_browser_open", true) end)
    createButton(tab, "⚔  Auto Join Raid", 25, function() fireRemote("auto_join_raid") end)
end

-- ── VISUALS TAB ──
do
    local tab = Tabs["visuals"]
    createSection(tab, "Rendering", 1)
    createToggle(tab, "Fullbright", "fullbright", 2, function(on)
        if on then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1e6
            Lighting.GlobalShadows = false
        else
            Lighting.Brightness = 1
            Lighting.ClockTime = 14
            Lighting.FogEnd = 1000
            Lighting.GlobalShadows = true
        end
    end)
    createToggle(tab, "No Render (Performance)", "norender", 3, function(on)
        for _, v in Workspace:GetDescendants() do
            if v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Beam") then
                v.Enabled = not on
            end
        end
    end)
    createToggle(tab, "FPS Boost", "fpsboost", 4, function(on)
        pcall(function()
            if on then
                settings().Rendering.QualityLevel = Enum.QualityLevel.Level01
            else
                settings().Rendering.QualityLevel = Enum.QualityLevel.Automatic
            end
        end)
    end)
    createToggle(tab, "Show Props", "props", 5)
    createSlider(tab, "UI Scale", "uiscale", 50, 150, 5, 6, function(val)
        MainFrame.Size = UDim2.new(0, WINDOW_W * (val / 100), 0, WINDOW_H * (val / 100))
    end)

    createSection(tab, "ESP", 10)
    createButton(tab, "👁  Toggle Player ESP", 11, function()
        for _, plr in Players:GetPlayers() do
            if plr ~= LocalPlayer and plr.Character then
                local existing = plr.Character:FindFirstChild("ESP_Highlight")
                if existing then
                    existing:Destroy()
                else
                    local hl = Instance.new("Highlight")
                    hl.Name = "ESP_Highlight"
                    hl.FillColor = C.accent
                    hl.FillTransparency = 0.7
                    hl.OutlineColor = C.accent2
                    hl.OutlineTransparency = 0.2
                    hl.Adornee = plr.Character
                    hl.Parent = plr.Character
                end
            end
        end
    end)
    createButton(tab, "👁  Toggle NPC ESP", 12, function()
        for _, npcName in ipairs(NPCs) do
            local npc = Workspace:FindFirstChild(npcName)
            if npc then
                local existing = npc:FindFirstChild("ESP_Highlight")
                if existing then
                    existing:Destroy()
                else
                    local hl = Instance.new("Highlight")
                    hl.Name = "ESP_Highlight"
                    hl.FillColor = C.green
                    hl.FillTransparency = 0.8
                    hl.OutlineColor = C.green
                    hl.OutlineTransparency = 0.2
                    hl.Adornee = npc
                    hl.Parent = npc
                end
            end
        end
    end)
end

-- ── MISC TAB ──
do
    local tab = Tabs["misc"]
    createSection(tab, "Player Mods", 1)
    createToggle(tab, "Anti-AFK", "antiafk", 2)
    createToggle(tab, "Noclip", "noclip", 3)
    createToggle(tab, "Infinite Jump", "infjump", 4)
    createToggle(tab, "Fast Walk", "fastwalk", 5)
    createToggle(tab, "Fly", "fly", 6)

    createSection(tab, "Speed", 10)
    createSlider(tab, "Walk Speed", "walkspeed", 16, 500, 1, 11, function(val)
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum.WalkSpeed = val end
        end
    end)
    createSlider(tab, "Fly Speed", "flyspeed", 10, 500, 5, 12)

    createSection(tab, "Potions", 20)
    createToggle(tab, "Auto Potion", "autopotion", 21)
    createToggle(tab, "Potion Restock", "potionrestock", 22)
    createSlider(tab, "Potion HP Threshold (%)", "potionhp", 10, 90, 5, 23)
    createSlider(tab, "Min Potions to Keep", "potionmin", 1, 50, 1, 24)

    createSection(tab, "Character", 30)
    createButton(tab, "💀  Reset Character", 31, function() fireRemote("reset_character") end)
    createButton(tab, "🚑  Request Revive", 32, function() fireRemote("request_revive") end)
    createButton(tab, "🏳  Give Up", 33, function() fireRemote("give_up") end)
    createButton(tab, "🚀  Leave Run", 34, function() fireRemote("leave_run") end)
    createButton(tab, "💊  Use Potion", 35, function() fireRemote("use_potion") end)
    createButton(tab, "🎁  Claim Daily Reward", 36, function() fireRemote("claim_daily_reward") end)

    createSection(tab, "Keybinds", 40)
    createTextInput(tab, "Toggle Key", "togglekey", 41)
    createTextInput(tab, "Pause Key", "pausekey", 42)
    createToggle(tab, "Show Keybind Hints", "showbinds", 43)
end

-- ══════════════════════════════════════════════════════════════
--  ACTIVATE FIRST TAB
-- ══════════════════════════════════════════════════════════════
do
    local firstId = TabDefs[1].id
    ActiveTab = firstId
    Tabs[firstId].Visible = true
    local tb = TabButtons[firstId]
    tb.btn.BackgroundColor3 = C.card
    tb.btn.TextColor3 = C.text
    tb.indicator.Visible = true
end

-- ══════════════════════════════════════════════════════════════
--  RUNTIME LOOPS
-- ══════════════════════════════════════════════════════════════

-- Anti-AFK
pcall(function()
    LocalPlayer.Idled:Connect(function()
        if Config.antiafk then
            local vu = game:GetService("VirtualUser")
            vu:Button2Down(Vector2.new(0, 0), Camera.CFrame)
            task.wait(1)
            vu:Button2Up(Vector2.new(0, 0), Camera.CFrame)
        end
    end)
end)

-- Noclip
RunService.Stepped:Connect(function()
    if Config.noclip then
        local char = LocalPlayer.Character
        if char then
            for _, part in char:GetDescendants() do
                if part:IsA("BasePart") then part.CanCollide = false end
            end
        end
    end
end)

-- Infinite Jump
UserInputService.JumpRequest:Connect(function()
    if Config.infjump then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end
end)

-- Toggle key (DEL)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.Delete then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Walkspeed enforcement
RunService.Heartbeat:Connect(function()
    if Config.fastwalk then
        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum and hum.WalkSpeed ~= Config.walkspeed then
                hum.WalkSpeed = Config.walkspeed
            end
        end
    end
end)

-- Fly system
local flyActive = false
local flyBV, flyBG

local function startFly()
    local char = LocalPlayer.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if hum then hum.PlatformStand = true end
    flyBV = Instance.new("BodyVelocity")
    flyBV.MaxForce = Vector3.new(1e6, 1e6, 1e6)
    flyBV.Velocity = Vector3.zero
    flyBV.Parent = hrp
    flyBG = Instance.new("BodyGyro")
    flyBG.MaxTorque = Vector3.new(1e6, 1e6, 1e6)
    flyBG.D = 200
    flyBG.Parent = hrp
    flyActive = true
end

local function stopFly()
    flyActive = false
    if flyBV then flyBV:Destroy() end
    if flyBG then flyBG:Destroy() end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then hum.PlatformStand = false end
    end
end

RunService.RenderStepped:Connect(function()
    if Config.fly and not flyActive then
        startFly()
    elseif not Config.fly and flyActive then
        stopFly()
    end
    if flyActive and flyBV and flyBG then
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if hrp then
            local spd = Config.flyspeed
            local dir = Vector3.zero
            if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - Camera.CFrame.LookVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + Camera.CFrame.RightVector end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.yAxis end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir = dir - Vector3.yAxis end
            if dir.Magnitude > 0 then
                flyBV.Velocity = dir.Unit * spd
            else
                flyBV.Velocity = Vector3.zero
            end
            flyBG.CFrame = Camera.CFrame
        end
    end
end)

-- ══════════════════════════════════════════════════════════════
--  STARTUP NOTIFICATION
-- ══════════════════════════════════════════════════════════════
do
    local notif = Instance.new("Frame")
    notif.Size = UDim2.new(0, 280, 0, 50)
    notif.Position = UDim2.new(0.5, -140, 0, -60)
    notif.BackgroundColor3 = C.card
    notif.BorderSizePixel = 0
    notif.Parent = ScreenGui
    addCorner(notif, CORNER_MD)
    addStroke(notif, C.accent, 1)

    local nGrad = Instance.new("UIGradient")
    nGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, C.bg2),
        ColorSequenceKeypoint.new(1, C.card),
    }
    nGrad.Rotation = 90
    nGrad.Parent = notif

    local nText = Instance.new("TextLabel")
    nText.Size = UDim2.new(1, -20, 1, 0)
    nText.Position = UDim2.new(0, 10, 0, 0)
    nText.BackgroundTransparency = 1
    nText.Text = "⚔ Pixel Blade Hub loaded!  [DEL] to toggle"
    nText.FontFace = FONT_MED
    nText.TextSize = 13
    nText.TextColor3 = C.text
    nText.Parent = notif

    tween(notif, {Position = UDim2.new(0.5, -140, 0, 20)}, 0.5, Enum.EasingStyle.Back)
    task.delay(3, function()
        tween(notif, {Position = UDim2.new(0.5, -140, 0, -60)}, 0.4)
        task.wait(0.5)
        notif:Destroy()
    end)
end

-- ══════════════════════════════════════════════════════════════
--  STATUS BAR
-- ══════════════════════════════════════════════════════════════
do
    local statusBar = Instance.new("Frame")
    statusBar.Size = UDim2.new(1, 0, 0, 20)
    statusBar.Position = UDim2.new(0, 0, 1, -20)
    statusBar.BackgroundColor3 = C.sidebar
    statusBar.BorderSizePixel = 0
    statusBar.Parent = MainFrame

    local statusText = Instance.new("TextLabel")
    statusText.Size = UDim2.new(1, -100, 1, 0)
    statusText.Position = UDim2.new(0, 10, 0, 0)
    statusText.BackgroundTransparency = 1
    statusText.Text = "Player: " .. LocalPlayer.Name .. "  |  Pixel Blade Lobby"
    statusText.FontFace = FONT_REG
    statusText.TextSize = 10
    statusText.TextColor3 = C.textDim
    statusText.TextXAlignment = Enum.TextXAlignment.Left
    statusText.Parent = statusBar

    local fpsLabel = Instance.new("TextLabel")
    fpsLabel.Size = UDim2.new(0, 80, 1, 0)
    fpsLabel.Position = UDim2.new(1, -90, 0, 0)
    fpsLabel.BackgroundTransparency = 1
    fpsLabel.Text = "FPS: --"
    fpsLabel.FontFace = FONT_REG
    fpsLabel.TextSize = 10
    fpsLabel.TextColor3 = C.accent2
    fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
    fpsLabel.Parent = statusBar

    local frameCount = 0
    local elapsed = 0
    RunService.RenderStepped:Connect(function(dt)
        frameCount = frameCount + 1
        elapsed = elapsed + dt
        if elapsed >= 1 then
            fpsLabel.Text = "FPS: " .. tostring(frameCount)
            frameCount = 0
            elapsed = 0
        end
    end)
end

print("[PixelBladeHub] Script loaded successfully. Press DEL to toggle UI.")
