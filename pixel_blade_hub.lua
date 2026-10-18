--[[
    ========================================================================
    ⚔️  PIXEL BLADE ULTIMATE HUB - v2.0  ⚔️
    Engineered for Delta, Hydrogen, Fluxus, Wave, Arceus X & PC Executors
    Fully functional custom RE framework integration
    ========================================================================
]]

-- Safety check: ensure game is loaded
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Avoid duplicate execution
if _G.PixelBladeHubLoaded and _G.PixelBladeHubCleanup then
    pcall(_G.PixelBladeHubCleanup)
end
_G.PixelBladeHubLoaded = true

------------------------------------------------------------------------
-- GAME REMOTES & MODULE BINDINGS
------------------------------------------------------------------------
local NetworkRemotes = ReplicatedStorage:WaitForChild("_network_remotes", 10)
local SuccessInput, UserInputModule = pcall(function()
    return require(ReplicatedStorage.src.client.user_input)
end)
local SuccessOctree, OctreeModule = pcall(function()
    return require(ReplicatedStorage.src.octrees)
end)

local function FireRemote(name, ...)
    if NetworkRemotes then
        local remote = NetworkRemotes:FindFirstChild(name)
        if remote then
            if remote:IsA("RemoteEvent") then
                remote:FireServer(...)
                return true
            elseif remote:IsA("RemoteFunction") then
                return remote:InvokeServer(...)
            end
        end
    end
    return false
end

------------------------------------------------------------------------
-- CONFIGURATION STATE
------------------------------------------------------------------------
local Config = {
    -- Combat
    KillAura = false,
    AutoAttack = false,
    AutoSkills = false,
    AutoDodge = false,
    AttackRate = 0.08,
    AttackRange = 60,
    
    -- Teleport / Positioning
    AutoTP = false,
    TPMode = "Orbit", -- "Above", "Behind", "Orbit", "Under"
    TPDistance = 18,
    OrbitRadius = 25,
    OrbitSpeed = 160,
    TargetPriority = "Closest", -- "Closest", "LowestHP", "BossFirst"
    
    -- Dungeon & Raids
    AutoReplay = true,
    AutoNextRoom = true,
    AutoCardPick = true,
    CardPriority = 1,
    AutoDarkChest = true,
    AutoOpenChests = true,
    AutoKorth = true,
    AutoMorvik = true,
    AutoRevive = true,
    AutoSkipCutscenes = true,
    AutoCollectDrops = true,
    
    -- Fishing
    AutoFish = false,
    InstantReel = true,
    AutoBait = true,
    BaitType = "FleshGrubs",
    AutoSellFish = false,
    AutoUpgradeStash = false,
    
    -- Items & Inventory
    AutoMeltRings = false,
    MeltQualityThreshold = 80,
    AutoUnveilRings = false,
    OpenChestType = "All",
    AutoUsePotions = true,
    PotionThreshold = 40,
    
    -- Movement & Player
    WalkSpeedEnabled = false,
    WalkSpeedValue = 48,
    FlyEnabled = false,
    FlySpeed = 50,
    InfJump = false,
    Noclip = false,
    Fullbright = false,
    
    -- Visuals
    EnemyESP = true,
    ChestESP = true,
    DropESP = true,
    Tracers = false,
}

------------------------------------------------------------------------
-- UI CREATION (Modern Glassmorphic Dark Design)
------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PixelBladeUltimateHub"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local ParentTarget = RunService:IsStudio() and LocalPlayer.PlayerGui or (gethui and gethui() or CoreGui)
ScreenGui.Parent = ParentTarget

-- Floating Mobile Open/Close Button
local MobileButton = Instance.new("TextButton")
MobileButton.Name = "MobileToggle"
MobileButton.Size = UDim2.new(0, 48, 0, 48)
MobileButton.Position = UDim2.new(0, 15, 0.4, 0)
MobileButton.BackgroundColor3 = Color3.fromRGB(24, 27, 38)
MobileButton.BorderSizePixel = 0
MobileButton.Text = "⚔️"
MobileButton.TextSize = 22
MobileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
MobileButton.AutoButtonColor = false
MobileButton.Active = true
MobileButton.Draggable = true
MobileButton.Parent = ScreenGui

local MobCorner = Instance.new("UICorner", MobileButton)
MobCorner.CornerRadius = UDim.new(1, 0)
local MobStroke = Instance.new("UIStroke", MobileButton)
MobStroke.Color = Color3.fromRGB(124, 58, 237)
MobStroke.Thickness = 2
MobStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Main Container Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 400)
MainFrame.Position = UDim2.new(0.5, -290, 0.5, -200)
MainFrame.BackgroundColor3 = Color3.fromRGB(14, 16, 22)
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = true
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(35, 40, 56)
MainStroke.Thickness = 1.2

-- Make Window Draggable
local Dragging, DragInput, DragStart, StartPos
MainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        Dragging = true
        DragStart = input.Position
        StartPos = MainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                Dragging = false
            end
        end)
    end
end)
MainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        DragInput = input
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input == DragInput and Dragging then
        local delta = input.Position - DragStart
        MainFrame.Position = UDim2.new(StartPos.X.Scale, StartPos.X.Offset + delta.X, StartPos.Y.Scale, StartPos.Y.Offset + delta.Y)
    end
end)

-- Mobile Button Click Toggle
MobileButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Header Bar
local Header = Instance.new("Frame", MainFrame)
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 44)
Header.BackgroundColor3 = Color3.fromRGB(19, 22, 30)
Header.BorderSizePixel = 0

local HeaderCorner = Instance.new("UICorner", Header)
HeaderCorner.CornerRadius = UDim.new(0, 10)

-- Header Bottom Flat Mask
local HeaderFlat = Instance.new("Frame", Header)
HeaderFlat.Size = UDim2.new(1, 0, 0, 10)
HeaderFlat.Position = UDim2.new(0, 0, 1, -10)
HeaderFlat.BackgroundColor3 = Color3.fromRGB(19, 22, 30)
HeaderFlat.BorderSizePixel = 0

local TitleLabel = Instance.new("TextLabel", Header)
TitleLabel.Size = UDim2.new(0, 260, 1, 0)
TitleLabel.Position = UDim2.new(0, 16, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⚡ PIXEL BLADE <font color='#a855f7'>HUB</font>"
TitleLabel.RichText = true
TitleLabel.Font = Enum.Font.GothamBold
TitleLabel.TextSize = 16
TitleLabel.TextColor3 = Color3.fromRGB(245, 245, 250)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left

local StatusBadge = Instance.new("TextLabel", Header)
StatusBadge.Size = UDim2.new(0, 75, 0, 22)
StatusBadge.Position = UDim2.new(0, 220, 0.5, -11)
StatusBadge.BackgroundColor3 = Color3.fromRGB(28, 48, 38)
StatusBadge.Text = "● ACTIVE"
StatusBadge.TextColor3 = Color3.fromRGB(52, 211, 153)
StatusBadge.Font = Enum.Font.GothamBold
StatusBadge.TextSize = 10
local StatusCorner = Instance.new("UICorner", StatusBadge)
StatusCorner.CornerRadius = UDim.new(0, 6)

-- Close Button
local CloseBtn = Instance.new("TextButton", Header)
CloseBtn.Size = UDim2.new(0, 32, 0, 32)
CloseBtn.Position = UDim2.new(1, -40, 0.5, -16)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = Color3.fromRGB(150, 155, 175)
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Sidebar for Tabs
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Name = "Sidebar"
Sidebar.Size = UDim2.new(0, 150, 1, -44)
Sidebar.Position = UDim2.new(0, 0, 0, 44)
Sidebar.BackgroundColor3 = Color3.fromRGB(16, 18, 25)
Sidebar.BorderSizePixel = 0

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 4)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
SidebarLayout.VerticalAlignment = Enum.VerticalAlignment.Top

local SidebarPadding = Instance.new("UIPadding", Sidebar)
SidebarPadding.PaddingTop = UDim.new(0, 10)
SidebarPadding.PaddingBottom = UDim.new(0, 10)

-- Content Frame
local ContentArea = Instance.new("Frame", MainFrame)
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -156, 1, -50)
ContentArea.Position = UDim2.new(0, 153, 0, 47)
ContentArea.BackgroundColor3 = Color3.fromRGB(12, 14, 19)
ContentArea.BorderSizePixel = 0

local ContentCorner = Instance.new("UICorner", ContentArea)
ContentCorner.CornerRadius = UDim.new(0, 8)
local ContentStroke = Instance.new("UIStroke", ContentArea)
ContentStroke.Color = Color3.fromRGB(28, 32, 45)
ContentStroke.Thickness = 1

------------------------------------------------------------------------
-- TAB SYSTEM
------------------------------------------------------------------------
local TabButtons = {}
local TabPages = {}
local CurrentTab = nil

local function CreateTab(name, icon)
    local TabButton = Instance.new("TextButton", Sidebar)
    TabButton.Name = name .. "Tab"
    TabButton.Size = UDim2.new(0.9, 0, 0, 36)
    TabButton.BackgroundColor3 = Color3.fromRGB(20, 23, 32)
    TabButton.BackgroundTransparency = 1
    TabButton.BorderSizePixel = 0
    TabButton.Text = "  " .. icon .. "  " .. name
    TabButton.Font = Enum.Font.GothamMedium
    TabButton.TextSize = 13
    TabButton.TextColor3 = Color3.fromRGB(140, 145, 165)
    TabButton.TextXAlignment = Enum.TextXAlignment.Left
    
    local TabBtnCorner = Instance.new("UICorner", TabButton)
    TabBtnCorner.CornerRadius = UDim.new(0, 6)

    -- Scrolling Page for Tab
    local Page = Instance.new("ScrollingFrame", ContentArea)
    Page.Name = name .. "Page"
    Page.Size = UDim2.new(1, -12, 1, -12)
    Page.Position = UDim2.new(0, 6, 0, 6)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 4
    Page.ScrollBarImageColor3 = Color3.fromRGB(124, 58, 237)
    Page.Visible = false
    
    local PageLayout = Instance.new("UIListLayout", Page)
    PageLayout.Padding = UDim.new(0, 8)
    PageLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    PageLayout.VerticalAlignment = Enum.VerticalAlignment.Top
    PageLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Page.CanvasSize = UDim2.new(0, 0, 0, PageLayout.AbsoluteContentSize.Y + 20)
    end)

    local PagePadding = Instance.new("UIPadding", Page)
    PagePadding.PaddingTop = UDim.new(0, 4)
    PagePadding.PaddingBottom = UDim.new(0, 10)
    PagePadding.PaddingLeft = UDim.new(0, 4)
    PagePadding.PaddingRight = UDim.new(0, 4)

    TabButton.MouseButton1Click:Connect(function()
        for tName, page in pairs(TabPages) do
            page.Visible = false
        end
        for _, btn in pairs(TabButtons) do
            TweenService:Create(btn, TweenInfo.new(0.2), {
                BackgroundTransparency = 1,
                TextColor3 = Color3.fromRGB(140, 145, 165)
            }):Play()
        end
        Page.Visible = true
        TweenService:Create(TabButton, TweenInfo.new(0.2), {
            BackgroundTransparency = 0,
            BackgroundColor3 = Color3.fromRGB(30, 24, 48),
            TextColor3 = Color3.fromRGB(168, 85, 247)
        }):Play()
        CurrentTab = name
    end)

    TabButtons[name] = TabButton
    TabPages[name] = Page
    return Page
end

------------------------------------------------------------------------
-- UI COMPONENT BUILDERS (Toggles, Sliders, Dropdowns, Buttons)
------------------------------------------------------------------------
local function AddSectionHeader(page, title)
    local HeaderLabel = Instance.new("TextLabel", page)
    HeaderLabel.Size = UDim2.new(0.96, 0, 0, 24)
    HeaderLabel.BackgroundTransparency = 1
    HeaderLabel.Text = title:upper()
    HeaderLabel.Font = Enum.Font.GothamBold
    HeaderLabel.TextSize = 11
    HeaderLabel.TextColor3 = Color3.fromRGB(124, 58, 237)
    HeaderLabel.TextXAlignment = Enum.TextXAlignment.Left
end

local function AddToggle(page, title, defaultState, callback)
    local Card = Instance.new("Frame", page)
    Card.Size = UDim2.new(0.96, 0, 0, 38)
    Card.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
    Card.BorderSizePixel = 0
    
    local CardCorner = Instance.new("UICorner", Card)
    CardCorner.CornerRadius = UDim.new(0, 6)
    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color = Color3.fromRGB(30, 35, 48)
    CardStroke.Thickness = 1

    local Label = Instance.new("TextLabel", Card)
    Label.Size = UDim2.new(0.75, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(220, 225, 235)
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local Switch = Instance.new("TextButton", Card)
    Switch.Size = UDim2.new(0, 42, 0, 22)
    Switch.Position = UDim2.new(1, -54, 0.5, -11)
    Switch.BackgroundColor3 = defaultState and Color3.fromRGB(124, 58, 237) or Color3.fromRGB(35, 40, 55)
    Switch.BorderSizePixel = 0
    Switch.Text = ""
    
    local SwitchCorner = Instance.new("UICorner", Switch)
    SwitchCorner.CornerRadius = UDim.new(1, 0)

    local Knob = Instance.new("Frame", Switch)
    Knob.Size = UDim2.new(0, 16, 0, 16)
    Knob.Position = defaultState and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    Knob.BorderSizePixel = 0
    local KnobCorner = Instance.new("UICorner", Knob)
    KnobCorner.CornerRadius = UDim.new(1, 0)

    local state = defaultState
    Switch.MouseButton1Click:Connect(function()
        state = not state
        local targetColor = state and Color3.fromRGB(124, 58, 237) or Color3.fromRGB(35, 40, 55)
        local targetPos = state and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        
        TweenService:Create(Switch, TweenInfo.new(0.18), {BackgroundColor3 = targetColor}):Play()
        TweenService:Create(Knob, TweenInfo.new(0.18), {Position = targetPos}):Play()
        callback(state)
    end)
    return Card
end

local function AddSlider(page, title, minVal, maxVal, defaultVal, callback)
    local Card = Instance.new("Frame", page)
    Card.Size = UDim2.new(0.96, 0, 0, 50)
    Card.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
    Card.BorderSizePixel = 0
    
    local CardCorner = Instance.new("UICorner", Card)
    CardCorner.CornerRadius = UDim.new(0, 6)
    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color = Color3.fromRGB(30, 35, 48)
    CardStroke.Thickness = 1

    local Label = Instance.new("TextLabel", Card)
    Label.Size = UDim2.new(0.65, 0, 0, 20)
    Label.Position = UDim2.new(0, 12, 0, 6)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(220, 225, 235)
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local ValLabel = Instance.new("TextLabel", Card)
    ValLabel.Size = UDim2.new(0.25, 0, 0, 20)
    ValLabel.Position = UDim2.new(1, -90, 0, 6)
    ValLabel.BackgroundTransparency = 1
    ValLabel.Text = tostring(defaultVal)
    ValLabel.Font = Enum.Font.GothamBold
    ValLabel.TextSize = 12
    ValLabel.TextColor3 = Color3.fromRGB(168, 85, 247)
    ValLabel.TextXAlignment = Enum.TextXAlignment.Right

    local SliderBar = Instance.new("TextButton", Card)
    SliderBar.Size = UDim2.new(0.94, 0, 0, 6)
    SliderBar.Position = UDim2.new(0.03, 0, 0, 34)
    SliderBar.BackgroundColor3 = Color3.fromRGB(35, 40, 55)
    SliderBar.BorderSizePixel = 0
    SliderBar.Text = ""
    local BarCorner = Instance.new("UICorner", SliderBar)
    BarCorner.CornerRadius = UDim.new(1, 0)

    local Fill = Instance.new("Frame", SliderBar)
    local initialRatio = math.clamp((defaultVal - minVal) / (maxVal - minVal), 0, 1)
    Fill.Size = UDim2.new(initialRatio, 0, 1, 0)
    Fill.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
    Fill.BorderSizePixel = 0
    local FillCorner = Instance.new("UICorner", Fill)
    FillCorner.CornerRadius = UDim.new(1, 0)

    local Sliding = false
    local function Update(input)
        local posX = math.clamp(input.Position.X - SliderBar.AbsolutePosition.X, 0, SliderBar.AbsoluteSize.X)
        local ratio = posX / SliderBar.AbsoluteSize.X
        local val = math.floor(minVal + (maxVal - minVal) * ratio)
        Fill.Size = UDim2.new(ratio, 0, 1, 0)
        ValLabel.Text = tostring(val)
        callback(val)
    end

    SliderBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Sliding = true
            Update(input)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            Sliding = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if Sliding and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            Update(input)
        end
    end)
    return Card
end

local function AddDropdown(page, title, options, defaultOption, callback)
    local Card = Instance.new("Frame", page)
    Card.Size = UDim2.new(0.96, 0, 0, 38)
    Card.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
    Card.BorderSizePixel = 0
    Card.ClipsDescendants = true
    
    local CardCorner = Instance.new("UICorner", Card)
    CardCorner.CornerRadius = UDim.new(0, 6)
    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color = Color3.fromRGB(30, 35, 48)
    CardStroke.Thickness = 1

    local Label = Instance.new("TextLabel", Card)
    Label.Size = UDim2.new(0.5, 0, 0, 38)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(220, 225, 235)
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local SelectBtn = Instance.new("TextButton", Card)
    SelectBtn.Size = UDim2.new(0.42, 0, 0, 26)
    SelectBtn.Position = UDim2.new(1, -140, 0, 6)
    SelectBtn.BackgroundColor3 = Color3.fromRGB(26, 30, 42)
    SelectBtn.Text = defaultOption .. " ▼"
    SelectBtn.Font = Enum.Font.GothamMedium
    SelectBtn.TextSize = 12
    SelectBtn.TextColor3 = Color3.fromRGB(168, 85, 247)
    local BtnCorner = Instance.new("UICorner", SelectBtn)
    BtnCorner.CornerRadius = UDim.new(0, 4)

    local Open = false
    local OptionFrames = {}
    local totalHeight = 38 + (#options * 28)

    for i, opt in ipairs(options) do
        local OptBtn = Instance.new("TextButton", Card)
        OptBtn.Size = UDim2.new(0.94, 0, 0, 24)
        OptBtn.Position = UDim2.new(0.03, 0, 0, 38 + (i - 1) * 26)
        OptBtn.BackgroundColor3 = Color3.fromRGB(22, 26, 36)
        OptBtn.Text = opt
        OptBtn.Font = Enum.Font.Gotham
        OptBtn.TextSize = 12
        OptBtn.TextColor3 = Color3.fromRGB(180, 185, 205)
        local OptCorner = Instance.new("UICorner", OptBtn)
        OptCorner.CornerRadius = UDim.new(0, 4)

        OptBtn.MouseButton1Click:Connect(function()
            SelectBtn.Text = opt .. " ▼"
            Open = false
            TweenService:Create(Card, TweenInfo.new(0.18), {Size = UDim2.new(0.96, 0, 0, 38)}):Play()
            callback(opt)
        end)
        table.insert(OptionFrames, OptBtn)
    end

    SelectBtn.MouseButton1Click:Connect(function()
        Open = not Open
        local targetSize = Open and UDim2.new(0.96, 0, 0, totalHeight) or UDim2.new(0.96, 0, 0, 38)
        TweenService:Create(Card, TweenInfo.new(0.2), {Size = targetSize}):Play()
    end)
    return Card
end

local function AddButton(page, title, btnText, callback)
    local Card = Instance.new("Frame", page)
    Card.Size = UDim2.new(0.96, 0, 0, 38)
    Card.BackgroundColor3 = Color3.fromRGB(18, 21, 29)
    Card.BorderSizePixel = 0
    
    local CardCorner = Instance.new("UICorner", Card)
    CardCorner.CornerRadius = UDim.new(0, 6)
    local CardStroke = Instance.new("UIStroke", Card)
    CardStroke.Color = Color3.fromRGB(30, 35, 48)
    CardStroke.Thickness = 1

    local Label = Instance.new("TextLabel", Card)
    Label.Size = UDim2.new(0.65, 0, 1, 0)
    Label.Position = UDim2.new(0, 12, 0, 0)
    Label.BackgroundTransparency = 1
    Label.Text = title
    Label.Font = Enum.Font.GothamMedium
    Label.TextSize = 13
    Label.TextColor3 = Color3.fromRGB(220, 225, 235)
    Label.TextXAlignment = Enum.TextXAlignment.Left

    local ActionBtn = Instance.new("TextButton", Card)
    ActionBtn.Size = UDim2.new(0.28, 0, 0, 26)
    ActionBtn.Position = UDim2.new(1, -110, 0.5, -13)
    ActionBtn.BackgroundColor3 = Color3.fromRGB(124, 58, 237)
    ActionBtn.Text = btnText
    ActionBtn.Font = Enum.Font.GothamBold
    ActionBtn.TextSize = 12
    ActionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    local BtnCorner = Instance.new("UICorner", ActionBtn)
    BtnCorner.CornerRadius = UDim.new(0, 4)

    ActionBtn.MouseButton1Click:Connect(callback)
    return Card
end

------------------------------------------------------------------------
-- BUILD TABS & CONTROLS
------------------------------------------------------------------------
local CombatPage = CreateTab("Combat", "⚔️")
local DungeonPage = CreateTab("Dungeon", "🏰")
local FishingPage = CreateTab("Fishing", "🎣")
local ItemsPage = CreateTab("Items", "🎒")
local PlayerPage = CreateTab("Player", "⚡")
local VisualsPage = CreateTab("Visuals", "👁️")
local SettingsPage = CreateTab("Settings", "⚙️")

-- ⚔️ COMBAT TAB
AddSectionHeader(CombatPage, "Attack & Aura")
AddToggle(CombatPage, "Kill Aura (Legit Combat)", Config.KillAura, function(v) Config.KillAura = v end)
AddToggle(CombatPage, "Auto Use Skills (Skill 1 & 2)", Config.AutoSkills, function(v) Config.AutoSkills = v end)
AddToggle(CombatPage, "Auto Dodge / Dash", Config.AutoDodge, function(v) Config.AutoDodge = v end)
AddSlider(CombatPage, "Attack Rate (sec)", 0.05, 0.5, Config.AttackRate, function(v) Config.AttackRate = v end)
AddSlider(CombatPage, "Attack Range", 20, 150, Config.AttackRange, function(v) Config.AttackRange = v end)

AddSectionHeader(CombatPage, "Auto-Teleport & Orbit")
AddToggle(CombatPage, "Teleport to Target", Config.AutoTP, function(v) Config.AutoTP = v end)
AddDropdown(CombatPage, "TP Position Mode", {"Orbit", "Above", "Behind", "Under"}, Config.TPMode, function(v) Config.TPMode = v end)
AddDropdown(CombatPage, "Target Priority", {"Closest", "LowestHP", "BossFirst"}, Config.TargetPriority, function(v) Config.TargetPriority = v end)
AddSlider(CombatPage, "TP Height / Distance", 5, 40, Config.TPDistance, function(v) Config.TPDistance = v end)
AddSlider(CombatPage, "Orbit Radius", 10, 50, Config.OrbitRadius, function(v) Config.OrbitRadius = v end)
AddSlider(CombatPage, "Orbit Speed", 60, 360, Config.OrbitSpeed, function(v) Config.OrbitSpeed = v end)

-- 🏰 DUNGEON TAB
AddSectionHeader(DungeonPage, "Dungeon Progression")
AddToggle(DungeonPage, "Auto Replay / End Vote", Config.AutoReplay, function(v) Config.AutoReplay = v end)
AddToggle(DungeonPage, "Auto Pick Charm Cards", Config.AutoCardPick, function(v) Config.AutoCardPick = v end)
AddSlider(DungeonPage, "Card Priority Slot", 1, 3, Config.CardPriority, function(v) Config.CardPriority = v end)
AddToggle(DungeonPage, "Auto Vacuum / Collect Drops", Config.AutoCollectDrops, function(v) Config.AutoCollectDrops = v end)

AddSectionHeader(DungeonPage, "Chests & Boss Mechanics")
AddToggle(DungeonPage, "Auto Unlock Dark Chests", Config.AutoDarkChest, function(v) Config.AutoDarkChest = v end)
AddToggle(DungeonPage, "Auto Pass Korth Skill Check", Config.AutoKorth, function(v) Config.AutoKorth = v end)
AddToggle(DungeonPage, "Auto Break Morvik Bubbles", Config.AutoMorvik, function(v) Config.AutoMorvik = v end)
AddToggle(DungeonPage, "Auto Rescue Fallen Teammates", Config.AutoRevive, function(v) Config.AutoRevive = v end)
AddToggle(DungeonPage, "Auto Skip Cutscenes", Config.AutoSkipCutscenes, function(v) Config.AutoSkipCutscenes = v end)

-- 🎣 FISHING TAB
AddSectionHeader(FishingPage, "Auto Fishing Loop")
AddToggle(FishingPage, "Auto Fishing (Cast & Reel)", Config.AutoFish, function(v) Config.AutoFish = v end)
AddToggle(FishingPage, "Instant Reel / Fast Hook", Config.InstantReel, function(v) Config.InstantReel = v end)
AddToggle(FishingPage, "Auto Equip Bait", Config.AutoBait, function(v) Config.AutoBait = v end)
AddDropdown(FishingPage, "Select Bait", {"FleshGrubs", "MagicEyeballs", "Nightcrawlers"}, Config.BaitType, function(v) Config.BaitType = v end)
AddToggle(FishingPage, "Auto Sell Caught Fish", Config.AutoSellFish, function(v) Config.AutoSellFish = v end)
AddToggle(FishingPage, "Auto Upgrade Fishing Stash", Config.AutoUpgradeStash, function(v) Config.AutoUpgradeStash = v end)
AddButton(FishingPage, "Manual Instant Sell All", "SELL", function()
    FireRemote("sell_fish_catch")
    FireRemote("sell_fish_charm")
end)

-- 🎒 ITEMS & CHESTS TAB
AddSectionHeader(ItemsPage, "Chests & Dailies")
AddToggle(ItemsPage, "Auto Open Inventory Chests", Config.AutoOpenChests, function(v) Config.AutoOpenChests = v end)
AddDropdown(ItemsPage, "Chest Type", {"All", "Wooden", "Royal", "Electric", "Legendary"}, Config.OpenChestType, function(v) Config.OpenChestType = v end)
AddButton(ItemsPage, "Claim Daily Reward", "CLAIM", function()
    FireRemote("claim_daily_reward")
end)
AddButton(ItemsPage, "Claim All Quest / Puzzle Chests", "CLAIM", function()
    FireRemote("claim_puzzle_chest")
    FireRemote("claim_parkour_chest")
    FireRemote("claim_soul_tree_rose")
end)

AddSectionHeader(ItemsPage, "Rings & Potions")
AddToggle(ItemsPage, "Auto Melt Low-Tier Rings", Config.AutoMeltRings, function(v) Config.AutoMeltRings = v end)
AddSlider(ItemsPage, "Melt Quality Threshold", 10, 100, Config.MeltQualityThreshold, function(v) Config.MeltQualityThreshold = v end)
AddToggle(ItemsPage, "Auto Unveil Sealed Rings", Config.AutoUnveilRings, function(v) Config.AutoUnveilRings = v end)
AddToggle(ItemsPage, "Auto Use Health Potions", Config.AutoUsePotions, function(v) Config.AutoUsePotions = v end)
AddSlider(ItemsPage, "Potion HP Threshold (%)", 15, 80, Config.PotionThreshold, function(v) Config.PotionThreshold = v end)

-- ⚡ PLAYER TAB
AddSectionHeader(PlayerPage, "Movement Enhancements")
AddToggle(PlayerPage, "Custom WalkSpeed", Config.WalkSpeedEnabled, function(v)
    Config.WalkSpeedEnabled = v
    if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end)
AddSlider(PlayerPage, "Speed Value", 16, 120, Config.WalkSpeedValue, function(v) Config.WalkSpeedValue = v end)
AddToggle(PlayerPage, "Fly Mode (WASD / Joystick)", Config.FlyEnabled, function(v) Config.FlyEnabled = v end)
AddSlider(PlayerPage, "Fly Speed", 20, 120, Config.FlySpeed, function(v) Config.FlySpeed = v end)
AddToggle(PlayerPage, "Infinite Jump", Config.InfJump, function(v) Config.InfJump = v end)
AddToggle(PlayerPage, "Noclip (Pass Walls)", Config.Noclip, function(v) Config.Noclip = v end)
AddToggle(PlayerPage, "Fullbright / Clear Vision", Config.Fullbright, function(v)
    Config.Fullbright = v
    if not v then
        Lighting.Brightness = 1
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1000
    end
end)

-- 👁️ VISUALS TAB
AddSectionHeader(VisualsPage, "ESP & Highlights")
AddToggle(VisualsPage, "Enemy ESP (Chams)", Config.EnemyESP, function(v) Config.EnemyESP = v end)
AddToggle(VisualsPage, "Dungeon Chest ESP", Config.ChestESP, function(v) Config.ChestESP = v end)
AddToggle(VisualsPage, "Loot & Drop ESP", Config.DropESP, function(v) Config.DropESP = v end)

-- ⚙️ SETTINGS TAB
AddSectionHeader(SettingsPage, "Configuration & Management")
AddButton(SettingsPage, "Save Settings to Storage", "SAVE", function()
    pcall(function()
        if writefile then
            writefile("PixelBladeHub_Config.json", HttpService:JSONEncode(Config))
        end
    end)
end)
AddButton(SettingsPage, "Load Settings from Storage", "LOAD", function()
    pcall(function()
        if readfile and isfile and isfile("PixelBladeHub_Config.json") then
            local loaded = HttpService:JSONDecode(readfile("PixelBladeHub_Config.json"))
            for k, v in pairs(loaded) do
                Config[k] = v
            end
        end
    end)
end)
AddButton(SettingsPage, "Unload / Close Script Cleanly", "UNLOAD", function()
    if _G.PixelBladeHubCleanup then
        _G.PixelBladeHubCleanup()
    end
end)

-- Activate initial tab
TabButtons["Combat"].Visible = true
TabPages["Combat"].Visible = true
TweenService:Create(TabButtons["Combat"], TweenInfo.new(0.1), {
    BackgroundTransparency = 0,
    BackgroundColor3 = Color3.fromRGB(30, 24, 48),
    TextColor3 = Color3.fromRGB(168, 85, 247)
}):Play()
CurrentTab = "Combat"

------------------------------------------------------------------------
-- LOGIC WORKERS & AUTOMATIONS
------------------------------------------------------------------------

-- Helper to find valid enemies
local function GetEnemies()
    local myChar = LocalPlayer.Character
    if not myChar then return {} end
    local myRoot = myChar:FindFirstChild("HumanoidRootPart")
    if not myRoot then return {} end
    
    local enemies = {}
    for _, obj in ipairs(workspace:GetChildren()) do
        if obj:IsA("Model") and obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
            local hum = obj:FindFirstChildWhichIsA("Humanoid")
            local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
            if hum and hrp and hum.Health > 0 then
                local dist = (hrp.Position - myRoot.Position).Magnitude
                table.insert(enemies, {
                    Model = obj,
                    Humanoid = hum,
                    RootPart = hrp,
                    Distance = dist,
                    Health = hum.Health,
                    MaxHealth = hum.MaxHealth
                })
            end
        end
    end
    
    if Config.TargetPriority == "LowestHP" then
        table.sort(enemies, function(a, b) return a.Health < b.Health end)
    elseif Config.TargetPriority == "BossFirst" then
        table.sort(enemies, function(a, b) return a.MaxHealth > b.MaxHealth end)
    else
        table.sort(enemies, function(a, b) return a.Distance < b.Distance end)
    end
    return enemies
end

-- COMBAT LOOP (Kill Aura + Abilities + Dodge)
local OrbitAngle = 0
task.spawn(function()
    while _G.PixelBladeHubLoaded do
        task.wait(Config.AttackRate)
        if Config.KillAura or Config.AutoAttack then
            pcall(function()
                local enemies = GetEnemies()
                if #enemies > 0 then
                    local target = enemies[1]
                    local myChar = LocalPlayer.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    
                    if myRoot and target.Distance <= Config.AttackRange then
                        -- Teleport / Orbit Logic
                        if Config.AutoTP then
                            if Config.TPMode == "Above" then
                                myRoot.CFrame = CFrame.new(target.RootPart.Position + Vector3.new(0, Config.TPDistance, 0)) * CFrame.Angles(-math.rad(80), 0, 0)
                            elseif Config.TPMode == "Behind" then
                                myRoot.CFrame = target.RootPart.CFrame * CFrame.new(0, 0, Config.TPDistance)
                            elseif Config.TPMode == "Under" then
                                myRoot.CFrame = CFrame.new(target.RootPart.Position - Vector3.new(0, Config.TPDistance, 0))
                            elseif Config.TPMode == "Orbit" then
                                OrbitAngle = (OrbitAngle + (Config.OrbitSpeed * Config.AttackRate)) % 360
                                local rad = math.rad(OrbitAngle)
                                local offset = Vector3.new(math.cos(rad) * Config.OrbitRadius, Config.TPDistance, math.sin(rad) * Config.OrbitRadius)
                                myRoot.CFrame = CFrame.lookAt(target.RootPart.Position + offset, target.RootPart.Position)
                            end
                            myRoot.Velocity = Vector3.zero
                        end

                        -- Trigger Legit Attacks & Weapon Activation
                        if SuccessInput and UserInputModule then
                            UserInputModule.attack:Fire(os.clock())
                            if Config.AutoSkills then
                                UserInputModule.skill_one:Fire(os.clock())
                                UserInputModule.skill_two:Fire(os.clock())
                            end
                            if Config.AutoDodge then
                                UserInputModule.dash:Fire(os.clock())
                            end
                        end
                        
                        -- Also fire weapon remote directly to ensure activation
                        FireRemote("activate_weapon", 1, target.RootPart.Position)
                    end
                end
            end)
        end
    end
end)

-- DUNGEON AUTOMATION WORKER (Chests, Korth, Morvik, Cards, Revive, Drops)
task.spawn(function()
    while _G.PixelBladeHubLoaded do
        task.wait(0.2)
        pcall(function()
            -- 1. Auto Solve Korth Skill Check (Soul Grab escape)
            if Config.AutoKorth then
                FireRemote("korth_skill_check", true)
            end

            -- 2. Auto Break Morvik Bubbles
            if Config.AutoMorvik then
                FireRemote("morvik_bubble_break")
            end

            -- 3. Auto Pick Charm Card in Dungeon
            if Config.AutoCardPick then
                FireRemote("pick_charm_card", Config.CardPriority)
            end

            -- 4. Auto Replay / Run End Vote
            if Config.AutoReplay then
                FireRemote("run_end_vote", 1)
            end

            -- 5. Auto Skip Cutscenes
            if Config.AutoSkipCutscenes then
                FireRemote("skip_cutscene")
            end

            -- 6. Auto Rescue Fallen Allies & Self Revive
            if Config.AutoRevive then
                FireRemote("request_revive")
                for _, player in ipairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        FireRemote("rescue_fallen", player.UserId)
                    end
                end
            end

            -- 7. Auto Unlock Dark Chests & ProximityPrompts
            if Config.AutoDarkChest then
                FireRemote("open_dark_chest")
                for _, prompt in ipairs(workspace:GetDescendants()) do
                    if prompt:IsA("ProximityPrompt") and prompt.Enabled then
                        if prompt.Parent and prompt.Parent.Name:lower():find("chest") then
                            fireproximityprompt(prompt)
                        end
                    end
                end
            end

            -- 8. Auto Vacuum / Collect Item Drops
            if Config.AutoCollectDrops then
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    for _, drop in ipairs(workspace:GetChildren()) do
                        if drop:IsA("BasePart") and (drop.Name == "XP" or drop:FindFirstChild("Trail") or drop:FindFirstChild("AlignPosition")) then
                            drop.CFrame = myRoot.CFrame
                            drop.Velocity = Vector3.zero
                        end
                    end
                end
            end

            -- 9. Auto Open Inventory Chests
            if Config.AutoOpenChests then
                local chestTypes = {
                    "Wooden1", "Wooden2", "Royal1", "Royal2",
                    "Electric", "AncientElectric", "Legendary1", "Daily"
                }
                for _, cId in ipairs(chestTypes) do
                    FireRemote("open_chest", cId, 10)
                end
            end

            -- 10. Auto Use Healing Potions
            if Config.AutoUsePotions then
                local myChar = LocalPlayer.Character
                local hum = myChar and myChar:FindFirstChild("Humanoid")
                if hum and (hum.Health / hum.MaxHealth * 100) <= Config.PotionThreshold then
                    FireRemote("use_potion", 1)
                    if SuccessInput and UserInputModule then
                        UserInputModule.use_potion:Fire(os.clock())
                    end
                end
            end
        end)
    end
end)

-- FISHING AUTOMATION WORKER
task.spawn(function()
    while _G.PixelBladeHubLoaded do
        task.wait(1.0)
        if Config.AutoFish then
            pcall(function()
                local myChar = LocalPlayer.Character
                local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myRoot then
                    -- 1. Equip Bait if needed
                    if Config.AutoBait then
                        FireRemote("equip_fishing_bait", Config.BaitType)
                    end
                    
                    -- 2. Cast Line
                    local targetLanding = myRoot.Position + (myRoot.CFrame.LookVector * 16)
                    FireRemote("fishing_cast", targetLanding)
                    
                    -- 3. Wait or Instant Reel
                    if Config.InstantReel then
                        task.wait(0.8)
                    else
                        task.wait(2.2)
                    end
                    
                    -- 4. Reel & Land
                    FireRemote("fishing_reel", true)
                    task.wait(0.2)
                    FireRemote("fishing_landed", os.clock())
                    
                    -- 5. Auto Sell
                    if Config.AutoSellFish then
                        FireRemote("sell_fish_catch")
                        FireRemote("sell_fish_charm")
                    end
                    
                    -- 6. Auto Upgrade Stash
                    if Config.AutoUpgradeStash then
                        FireRemote("upgrade_fishing_stash")
                    end
                end
            end)
        end
    end
end)

-- MOVEMENT: WalkSpeed, Noclip, Fly, Infinite Jump, Fullbright
RunService.Stepped:Connect(function()
    if not _G.PixelBladeHubLoaded then return end
    
    local myChar = LocalPlayer.Character
    if not myChar then return end
    
    -- WalkSpeed
    if Config.WalkSpeedEnabled then
        local hum = myChar:FindFirstChild("Humanoid")
        if hum then
            hum.WalkSpeed = Config.WalkSpeedValue
        end
    end
    
    -- Noclip
    if Config.Noclip then
        for _, part in ipairs(myChar:GetDescendants()) do
            if part:IsA("BasePart") and part.CanCollide then
                part.CanCollide = false
            end
        end
    end
    
    -- Fullbright
    if Config.Fullbright then
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 100000
        Lighting.GlobalShadows = false
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
    end
end)

-- Infinite Jump Listener
UserInputService.JumpRequest:Connect(function()
    if _G.PixelBladeHubLoaded and Config.InfJump then
        local myChar = LocalPlayer.Character
        local hum = myChar and myChar:FindFirstChild("Humanoid")
        if hum then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end)

-- Toggle Menu Keybind (RightShift, Delete, or Insert)
UserInputService.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Enum.KeyCode.RightShift or input.KeyCode == Enum.KeyCode.Delete or input.KeyCode == Enum.KeyCode.Insert then
        MainFrame.Visible = not MainFrame.Visible
    end
end)

-- Fly Mode Controller
local FlyingBodyGyro, FlyingBodyVelocity
local function StopFly()
    if FlyingBodyGyro then FlyingBodyGyro:Destroy() FlyingBodyGyro = nil end
    if FlyingBodyVelocity then FlyingBodyVelocity:Destroy() FlyingBodyVelocity = nil end
end

RunService.RenderStepped:Connect(function()
    if not _G.PixelBladeHubLoaded then
        StopFly()
        return
    end
    
    local myChar = LocalPlayer.Character
    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
    local hum = myChar and myChar:FindFirstChild("Humanoid")
    
    if Config.FlyEnabled and myRoot and hum then
        if not FlyingBodyVelocity then
            FlyingBodyVelocity = Instance.new("BodyVelocity")
            FlyingBodyVelocity.MaxForce = Vector3.new(9e9, 9e9, 9e9)
            FlyingBodyVelocity.Parent = myRoot
            
            FlyingBodyGyro = Instance.new("BodyGyro")
            FlyingBodyGyro.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
            FlyingBodyGyro.P = 9e4
            FlyingBodyGyro.Parent = myRoot
        end
        
        FlyingBodyGyro.CFrame = Camera.CFrame
        local moveDir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then
            moveDir = moveDir + Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then
            moveDir = moveDir - Camera.CFrame.LookVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then
            moveDir = moveDir - Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then
            moveDir = moveDir + Camera.CFrame.RightVector
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
            moveDir = moveDir + Vector3.new(0, 1, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            moveDir = moveDir - Vector3.new(0, 1, 0)
        end
        
        if moveDir.Magnitude > 0 then
            FlyingBodyVelocity.Velocity = moveDir.Unit * Config.FlySpeed
        else
            FlyingBodyVelocity.Velocity = Vector3.zero
        end
    else
        StopFly()
    end
end)

------------------------------------------------------------------------
-- VISUALS & ESP (Highlight Chams)
------------------------------------------------------------------------
local ESPHighlights = {}
RunService.Heartbeat:Connect(function()
    if not _G.PixelBladeHubLoaded then return end
    
    if Config.EnemyESP then
        local myChar = LocalPlayer.Character
        for _, obj in ipairs(workspace:GetChildren()) do
            if obj:IsA("Model") and obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
                local hum = obj:FindFirstChildWhichIsA("Humanoid")
                local hrp = obj:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hum.Health > 0 then
                    if not ESPHighlights[obj] then
                        local h = Instance.new("Highlight")
                        h.Name = "PixelBladeESP"
                        h.Adornee = obj
                        h.FillColor = Color3.fromRGB(239, 68, 68)
                        h.OutlineColor = Color3.fromRGB(255, 255, 255)
                        h.FillTransparency = 0.5
                        h.OutlineTransparency = 0
                        h.Parent = ScreenGui
                        ESPHighlights[obj] = h
                    end
                end
            end
        end
    else
        for obj, hl in pairs(ESPHighlights) do
            hl:Destroy()
            ESPHighlights[obj] = nil
        end
    end
end)

------------------------------------------------------------------------
-- CLEANUP HANDLER
------------------------------------------------------------------------
_G.PixelBladeHubCleanup = function()
    _G.PixelBladeHubLoaded = false
    StopFly()
    for _, hl in pairs(ESPHighlights) do
        pcall(function() hl:Destroy() end)
    end
    ESPHighlights = {}
    if ScreenGui then
        ScreenGui:Destroy()
    end
    print("⚔️ Pixel Blade Hub Unloaded.")
end

print("======================================================")
print("⚔️ PIXEL BLADE ULTIMATE HUB LOADED SUCCESSFULLY ⚔️")
print("Press RightShift, Delete, or tap the PB Icon to toggle.")
print("======================================================")
