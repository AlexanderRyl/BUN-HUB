--[[
    ========================================================================
    PIXEL BLADE HUB v3.0
    Rewritten from v2: faster, cleaner, safer unload, better UI.

    What's new
      * Kill Aura only ever attacks enemies inside Attack Range
      * Target lock, 3 priorities, selectable attack method
      * Separate skill / dash timers (no more per-tick spam)
      * One scheduler + one cached world scan (no GetChildren/GetDescendants spam)
      * Cached ProximityPrompts, throttled & range-limited remote firing
      * Working ESP (enemies / chests / drops), tracers (if Drawing exists)
      * Fly works on mobile joystick, WalkSpeed/Noclip/Fullbright restore properly
      * Config auto-save/load that actually updates the UI
      * Search bar, accent themes, notifications, FPS/ping, draggable header
      * Everything is tracked and cleaned up on Unload
    ========================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

local Env = (getgenv and getgenv()) or _G
if Env.PixelBladeHubCleanup then pcall(Env.PixelBladeHubCleanup) end
if _G.PixelBladeHubCleanup then pcall(_G.PixelBladeHubCleanup) end -- v2 leftovers

------------------------------------------------------------------------
-- SERVICES / CONSTANTS
------------------------------------------------------------------------
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local UserInputService  = game:GetService("UserInputService")
local TweenService      = game:GetService("TweenService")
local Lighting          = game:GetService("Lighting")
local CoreGui           = game:GetService("CoreGui")
local HttpService       = game:GetService("HttpService")
local VirtualUser       = game:GetService("VirtualUser")
local StatsService      = game:GetService("Stats")

local LocalPlayer = Players.LocalPlayer
local VERSION     = "3.0"
local CONFIG_FILE = "PixelBladeHub_v3.json"

local Running     = true
local MenuOpen    = true
local CurrentTab  = nil
local Target      = nil   -- current kill-aura target

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local Config = {
    -- Combat
    KillAura = false,
    TargetPriority = "Closest",   -- Closest / LowestHP / BossFirst
    LockTarget = true,
    AttackMethod = "Both",        -- Both / Input Module / Remote
    AttackRate = 0.08,
    AttackRange = 60,
    AutoSkills = false,
    SkillInterval = 0.6,
    AutoDodge = false,
    DashInterval = 1.5,
    KillAuraKey = "None",

    -- Teleport
    AutoTP = false,
    TPMode = "Orbit",             -- Orbit / Above / Behind / Under
    TPDistance = 18,
    OrbitRadius = 25,
    OrbitSpeed = 160,
    TPSeekRange = 150,

    -- Dungeon
    AutoReplay = true,
    AutoCardPick = true,
    CardPriority = 1,
    AutoCollectDrops = true,
    CollectRange = 150,
    AutoDarkChest = true,
    ChestRange = 40,
    AutoOpenChests = true,
    OpenChestType = "All",
    AutoKorth = true,
    AutoMorvik = true,
    AutoRevive = true,
    AutoSkipCutscenes = true,

    -- Fishing
    AutoFish = false,
    InstantReel = true,
    AutoBait = true,
    BaitType = "FleshGrubs",
    AutoSellFish = false,
    AutoUpgradeStash = false,

    -- Potions
    AutoUsePotions = true,
    PotionThreshold = 40,

    -- Player
    WalkSpeedEnabled = false,
    WalkSpeedValue = 48,
    FlyEnabled = false,
    FlySpeed = 50,
    InfJump = false,
    Noclip = false,
    Fullbright = false,
    AntiAFK = true,

    -- Visuals
    EnemyESP = true,
    ChestESP = true,
    DropESP = true,
    Tracers = false,
    ESPRange = 250,

    -- Settings
    Accent = "Purple",
    MenuKey = "RightShift",
    AutoSave = true,
}

local Defaults = {}
for k, v in pairs(Config) do Defaults[k] = v end

-- Settings that are never persisted (so you never load into a flying/aura state)
local NoPersist = { KillAura = true, AutoFish = true, FlyEnabled = true, Noclip = true }

-- Remote names (edit here if the game renames them)
local R = {
    Attack = "activate_weapon", Korth = "korth_skill_check", Morvik = "morvik_bubble_break",
    Card = "pick_charm_card", EndVote = "run_end_vote", Skip = "skip_cutscene",
    Revive = "request_revive", Rescue = "rescue_fallen", DarkChest = "open_dark_chest",
    OpenChest = "open_chest", Potion = "use_potion", Bait = "equip_fishing_bait",
    Cast = "fishing_cast", Reel = "fishing_reel", Landed = "fishing_landed",
    SellCatch = "sell_fish_catch", SellCharm = "sell_fish_charm", Stash = "upgrade_fishing_stash",
    Daily = "claim_daily_reward", Puzzle = "claim_puzzle_chest", Parkour = "claim_parkour_chest",
    Rose = "claim_soul_tree_rose",
}

local ChestSets = {
    Wooden = { "Wooden1", "Wooden2" },
    Royal = { "Royal1", "Royal2" },
    Electric = { "Electric", "AncientElectric" },
    Legendary = { "Legendary1" },
    All = { "Wooden1", "Wooden2", "Royal1", "Royal2", "Electric", "AncientElectric", "Legendary1", "Daily" },
}

local EnemyFolders = { "Enemies", "Mobs", "Entities", "NPCs", "Monsters" }

------------------------------------------------------------------------
-- CORE HELPERS (cleanup tracking, scheduler, remotes)
------------------------------------------------------------------------
local Tracked = {}
local function Track(item)
    Tracked[#Tracked + 1] = item
    return item
end

local UI = {}
local function Notify(title, body, dur)
    if UI.Notify then UI.Notify(title, body, dur) end
end

local Dirty = false
local function MarkDirty() Dirty = true end

-- Scheduler: one Heartbeat connection drives every timed job
local Jobs = {}
local Frames, FrameTime = 0, 0

local function Every(name, interval, fn, gate)
    Jobs[#Jobs + 1] = { name = name, interval = interval, fn = fn, gate = gate, acc = 0, busy = false, warned = false }
end

Track(RunService.Heartbeat:Connect(function(dt)
    Frames = Frames + 1
    FrameTime = FrameTime + dt
    for i = 1, #Jobs do
        local job = Jobs[i]
        if (not job.gate) or job.gate() then
            job.acc = job.acc + dt
            local iv = job.interval
            if type(iv) == "function" then iv = iv() end
            if job.acc >= iv and not job.busy then
                local elapsed = math.min(job.acc, 0.5)
                job.acc = 0
                job.busy = true
                task.spawn(function()
                    local ok, err = pcall(job.fn, elapsed)
                    job.busy = false
                    if not ok and not job.warned then
                        job.warned = true
                        warn("[PixelBlade] job '" .. job.name .. "' error: " .. tostring(err))
                    end
                end)
            end
        else
            job.acc = 0
        end
    end
end))

-- Remotes (cached, missing remotes are retried every 5s)
local NetworkRemotes = ReplicatedStorage:WaitForChild("_network_remotes", 10)
local RemoteCache, RemoteMissing = {}, {}

local function GetRemote(name)
    local r = RemoteCache[name]
    if r and r.Parent then return r end
    if not NetworkRemotes then return nil end
    local lastMiss = RemoteMissing[name]
    if lastMiss and os.clock() - lastMiss < 5 then return nil end
    r = NetworkRemotes:FindFirstChild(name)
    if r then
        RemoteCache[name] = r
        RemoteMissing[name] = nil
    else
        RemoteMissing[name] = os.clock()
    end
    return r
end

local function Fire(name, ...)
    local r = GetRemote(name)
    if not r then return false end
    if r:IsA("RemoteEvent") then
        r:FireServer(...)
        return true
    elseif r:IsA("RemoteFunction") then
        local args = table.pack(...)
        task.spawn(function()
            pcall(function() r:InvokeServer(table.unpack(args, 1, args.n)) end)
        end)
        return true
    end
    return false
end

-- Game input module (legit attack / skill signals)
local InputOK, InputModule = pcall(function()
    return require(ReplicatedStorage.src.client.user_input)
end)
local function FireSignal(name)
    if InputOK and type(InputModule) == "table" then
        local sig = InputModule[name]
        if sig and sig.Fire then
            pcall(function() sig:Fire(os.clock()) end)
        end
    end
end

-- Character
local function GetChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if root and hum and hum.Health > 0 then
        return char, root, hum
    end
    return nil
end

------------------------------------------------------------------------
-- GUI ROOT (created early so ESP can parent to it)
------------------------------------------------------------------------
local function Make(class, props, parent)
    local obj = Instance.new(class)
    if props then
        for k, v in pairs(props) do obj[k] = v end
    end
    if parent then obj.Parent = parent end
    return obj
end

local ScreenGui = Make("ScreenGui", {
    Name = "PBH_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
    ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
    DisplayOrder = 999,
    IgnoreGuiInset = true,
})
if syn and syn.protect_gui then pcall(syn.protect_gui, ScreenGui) end

do
    local parented = false
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then
            ScreenGui.Parent = h
            parented = ScreenGui.Parent ~= nil
        end
    end
    if not parented then
        pcall(function() ScreenGui.Parent = CoreGui end)
        parented = ScreenGui.Parent ~= nil
    end
    if not parented then
        ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end
end
Track(ScreenGui)

------------------------------------------------------------------------
-- WORLD SCAN (one cheap pass shared by combat, ESP, drops)
------------------------------------------------------------------------
local World = { Enemies = {}, Drops = {} }

local function IsDrop(part)
    return part.Name == "XP" or part:FindFirstChild("Trail") ~= nil or part:FindFirstChild("AlignPosition") ~= nil
end

local function ScanContainer(container, myChar, enemies, drops)
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Model") then
            if obj ~= myChar and not Players:GetPlayerFromCharacter(obj) then
                local hum = obj:FindFirstChildWhichIsA("Humanoid")
                if hum and hum.Health > 0 then
                    local hrp = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                    if hrp then
                        enemies[#enemies + 1] = { Model = obj, Humanoid = hum, Root = hrp }
                    end
                end
            end
        elseif obj:IsA("BasePart") and container == workspace and IsDrop(obj) then
            drops[#drops + 1] = obj
        end
    end
end

Every("WorldScan", 0.2, function()
    local enemies, drops = {}, {}
    local myChar = LocalPlayer.Character
    ScanContainer(workspace, myChar, enemies, drops)
    for _, name in ipairs(EnemyFolders) do
        local f = workspace:FindFirstChild(name)
        if f then ScanContainer(f, myChar, enemies, drops) end
    end
    World.Enemies = enemies
    World.Drops = drops
end, function()
    return Config.KillAura or Config.EnemyESP or Config.DropESP or Config.Tracers
        or Config.AutoCollectDrops or (MenuOpen and CurrentTab == "Combat")
end)

-- ProximityPrompt cache (no more workspace:GetDescendants() every tick)
local Prompts = {}
Track(workspace.DescendantAdded:Connect(function(d)
    if d:IsA("ProximityPrompt") then Prompts[d] = true end
end))
Track(workspace.DescendantRemoving:Connect(function(d)
    if Prompts[d] then Prompts[d] = nil end
end))
task.spawn(function()
    local n = 0
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then Prompts[d] = true end
        n = n + 1
        if n % 4000 == 0 then task.wait() end
    end
end)

local function IsChestPrompt(p)
    local par = p.Parent
    if not par then return false end
    if string.find(string.lower(par.Name), "chest", 1, true) then return true end
    local gp = par.Parent
    return gp ~= nil and string.find(string.lower(gp.Name), "chest", 1, true) ~= nil
end

local function PromptPos(p)
    local par = p.Parent
    if not par then return nil end
    if par:IsA("BasePart") then
        return par.Position, par
    elseif par:IsA("Attachment") then
        return par.WorldPosition, par.Parent
    elseif par:IsA("Model") then
        local pp = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.Position, pp end
    end
    return nil
end

------------------------------------------------------------------------
-- COMBAT
------------------------------------------------------------------------
do
    local OrbitAngle = 0

    local function PickTarget(origin, range)
        if Config.LockTarget and Target and Target.Model.Parent and Target.Humanoid.Health > 0
            and (Target.Root.Position - origin).Magnitude <= range then
            return Target
        end
        local best, bestScore
        local mode = Config.TargetPriority
        for _, e in ipairs(World.Enemies) do
            if e.Model.Parent and e.Humanoid.Health > 0 then
                local d = (e.Root.Position - origin).Magnitude
                if d <= range then
                    local score
                    if mode == "LowestHP" then
                        score = e.Humanoid.Health
                    elseif mode == "BossFirst" then
                        score = -e.Humanoid.MaxHealth + d * 0.001
                    else
                        score = d
                    end
                    if not bestScore or score < bestScore then
                        best, bestScore = e, score
                    end
                end
            end
        end
        return best
    end

    local function InRange()
        local _, root = GetChar()
        return root ~= nil and Target ~= nil and Target.Model.Parent ~= nil
            and Target.Humanoid.Health > 0
            and (Target.Root.Position - root.Position).Magnitude <= Config.AttackRange
    end

    local function Attack(t)
        local m = Config.AttackMethod
        if m ~= "Remote" then FireSignal("attack") end
        if m ~= "Input Module" then Fire(R.Attack, 1, t.Root.Position) end
    end

    local function PositionOn(root, t, dt)
        local tRoot = t.Root
        local tPos = tRoot.Position
        local mode = Config.TPMode
        local d = Config.TPDistance
        local cf
        if mode == "Above" then
            cf = CFrame.new(tPos + Vector3.new(0, d, 0)) * CFrame.Angles(-math.rad(80), 0, 0)
        elseif mode == "Behind" then
            cf = tRoot.CFrame * CFrame.new(0, 0, d)
        elseif mode == "Under" then
            cf = CFrame.lookAt(tPos - Vector3.new(0, d, 0), tPos)
        else
            OrbitAngle = (OrbitAngle + Config.OrbitSpeed * dt) % 360
            local rad = math.rad(OrbitAngle)
            local offset = Vector3.new(math.cos(rad) * Config.OrbitRadius, d, math.sin(rad) * Config.OrbitRadius)
            cf = CFrame.lookAt(tPos + offset, tPos)
        end
        root.CFrame = cf
        root.AssemblyLinearVelocity = Vector3.zero
    end

    -- Target picking + attack. Only enemies INSIDE Attack Range are ever attacked.
    Every("Combat", function() return math.max(Config.AttackRate, 0.03) end, function()
        local _, root = GetChar()
        if not root then Target = nil return end

        -- with Auto-TP we may *seek* further than we attack, but we never swing out of range
        local seek = Config.AttackRange
        if Config.AutoTP then seek = math.max(Config.TPSeekRange, Config.AttackRange) end

        Target = PickTarget(root.Position, seek)
        if not Target then return end
        if (Target.Root.Position - root.Position).Magnitude > Config.AttackRange then return end
        Attack(Target)
    end, function() return Config.KillAura end)

    -- Smooth per-frame positioning (orbit etc.)
    Track(RunService.Heartbeat:Connect(function(dt)
        if not (Config.KillAura and Config.AutoTP) then return end
        local t = Target
        if not t then return end
        if not t.Model.Parent or t.Humanoid.Health <= 0 then Target = nil return end
        local _, root = GetChar()
        if root then PositionOn(root, t, dt) end
    end))

    Every("Skills", function() return Config.SkillInterval end, function()
        if not InRange() then return end
        FireSignal("skill_one")
        FireSignal("skill_two")
    end, function() return Config.KillAura and Config.AutoSkills end)

    Every("Dash", function() return Config.DashInterval end, function()
        if not InRange() then return end
        FireSignal("dash")
    end, function() return Config.KillAura and Config.AutoDodge end)
end

------------------------------------------------------------------------
-- DUNGEON / ITEMS AUTOMATION
------------------------------------------------------------------------
do
    Every("Korth", 0.25, function() Fire(R.Korth, true) end, function() return Config.AutoKorth end)
    Every("Morvik", 0.25, function() Fire(R.Morvik) end, function() return Config.AutoMorvik end)
    Every("Cards", 1.0, function() Fire(R.Card, Config.CardPriority) end, function() return Config.AutoCardPick end)
    Every("EndVote", 2.0, function() Fire(R.EndVote, 1) end, function() return Config.AutoReplay end)
    Every("Cutscene", 1.0, function() Fire(R.Skip) end, function() return Config.AutoSkipCutscenes end)

    Every("Revive", 1.0, function()
        Fire(R.Revive)
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer then Fire(R.Rescue, p.UserId) end
        end
    end, function() return Config.AutoRevive end)

    Every("DarkChestRemote", 1.5, function() Fire(R.DarkChest) end, function() return Config.AutoDarkChest end)

    local PromptCD = setmetatable({}, { __mode = "k" })
    local warnedPrompt = false
    Every("ChestPrompts", 0.5, function()
        if not fireproximityprompt then
            if not warnedPrompt then
                warnedPrompt = true
                Notify("Executor limitation", "fireproximityprompt is not supported here.", 5)
            end
            return
        end
        local _, root = GetChar()
        if not root then return end
        local now = os.clock()
        for prompt in pairs(Prompts) do
            if prompt.Parent and prompt.Enabled and (PromptCD[prompt] or 0) < now and IsChestPrompt(prompt) then
                local pos = PromptPos(prompt)
                if pos and (pos - root.Position).Magnitude <= Config.ChestRange then
                    PromptCD[prompt] = now + 1.5
                    pcall(fireproximityprompt, prompt)
                end
            end
        end
    end, function() return Config.AutoDarkChest end)

    Every("Drops", 0.25, function()
        local _, root = GetChar()
        if not root then return end
        local range = Config.CollectRange
        for _, drop in ipairs(World.Drops) do
            if drop.Parent and (drop.Position - root.Position).Magnitude <= range then
                drop.CFrame = root.CFrame
                drop.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end, function() return Config.AutoCollectDrops end)

    Every("InventoryChests", 3.0, function()
        local list = ChestSets[Config.OpenChestType] or ChestSets.All
        for _, id in ipairs(list) do
            if not Config.AutoOpenChests or not Running then return end
            Fire(R.OpenChest, id, 10)
            task.wait(0.05)
        end
    end, function() return Config.AutoOpenChests end)

    local lastPotion = 0
    Every("Potions", 0.3, function()
        local _, _, hum = GetChar()
        if not hum then return end
        if hum.Health / math.max(hum.MaxHealth, 1) * 100 <= Config.PotionThreshold and os.clock() - lastPotion > 1.5 then
            lastPotion = os.clock()
            Fire(R.Potion, 1)
            FireSignal("use_potion")
        end
    end, function() return Config.AutoUsePotions end)
end

------------------------------------------------------------------------
-- FISHING
------------------------------------------------------------------------
do
    Every("Fishing", 0.5, function()
        local _, root = GetChar()
        if not root then return end

        if Config.AutoBait then Fire(R.Bait, Config.BaitType) end
        Fire(R.Cast, root.Position + root.CFrame.LookVector * 16)

        task.wait(Config.InstantReel and 0.8 or 2.2)
        if not Config.AutoFish or not Running then return end

        Fire(R.Reel, true)
        task.wait(0.2)
        Fire(R.Landed, os.clock())

        if Config.AutoSellFish then
            Fire(R.SellCatch)
            Fire(R.SellCharm)
        end
        if Config.AutoUpgradeStash then
            Fire(R.Stash)
        end
    end, function() return Config.AutoFish end)
end

------------------------------------------------------------------------
-- MOVEMENT / PLAYER
------------------------------------------------------------------------
do
    -- WalkSpeed (restores the real original value)
    local OrigWS
    Track(LocalPlayer.CharacterAdded:Connect(function() OrigWS = nil end))
    Track(RunService.Heartbeat:Connect(function()
        local _, _, hum = GetChar()
        if Config.WalkSpeedEnabled then
            if hum then
                if not OrigWS then OrigWS = hum.WalkSpeed end
                if hum.WalkSpeed ~= Config.WalkSpeedValue then hum.WalkSpeed = Config.WalkSpeedValue end
            end
        elseif OrigWS then
            if hum then hum.WalkSpeed = OrigWS end
            OrigWS = nil
        end
    end))
    Track(function()
        local _, _, hum = GetChar()
        if hum and OrigWS then hum.WalkSpeed = OrigWS end
    end)

    -- Noclip (cached part list, restores collisions)
    local Touched = {}
    local CachedChar, CachedParts, LastBuild = nil, {}, 0
    local function RestoreNoclip()
        for part in pairs(Touched) do
            if part.Parent then part.CanCollide = true end
            Touched[part] = nil
        end
    end
    Track(RunService.Stepped:Connect(function()
        if not Config.Noclip then
            if next(Touched) then RestoreNoclip() end
            return
        end
        local char = LocalPlayer.Character
        if not char then return end
        if char ~= CachedChar or os.clock() - LastBuild > 2 then
            CachedChar, LastBuild = char, os.clock()
            CachedParts = {}
            for _, d in ipairs(char:GetDescendants()) do
                if d:IsA("BasePart") then CachedParts[#CachedParts + 1] = d end
            end
        end
        for i = 1, #CachedParts do
            local part = CachedParts[i]
            if part.CanCollide then
                Touched[part] = true
                part.CanCollide = false
            end
        end
    end))
    Track(RestoreNoclip)

    -- Fly (keyboard + mobile joystick; look up/down to climb/descend while moving)
    local FlyBV, FlyBG
    local function StopFly()
        if FlyBV then FlyBV:Destroy() FlyBV = nil end
        if FlyBG then FlyBG:Destroy() FlyBG = nil end
    end
    Track(StopFly)
    Track(RunService.RenderStepped:Connect(function()
        if not Config.FlyEnabled then
            if FlyBV then StopFly() end
            return
        end
        local _, root, hum = GetChar()
        local cam = workspace.CurrentCamera
        if not root or not cam then StopFly() return end

        if not FlyBV or FlyBV.Parent ~= root then
            StopFly()
            FlyBV = Make("BodyVelocity", { MaxForce = Vector3.new(9e9, 9e9, 9e9), Velocity = Vector3.zero }, root)
            FlyBG = Make("BodyGyro", { MaxTorque = Vector3.new(9e9, 9e9, 9e9), P = 9e4 }, root)
        end

        local _, yaw = cam.CFrame:ToOrientation()
        FlyBG.CFrame = CFrame.Angles(0, yaw, 0)

        local vec = Vector3.zero
        local dir = hum.MoveDirection
        if dir.Magnitude > 0.01 then
            local look = cam.CFrame.LookVector
            local flat = Vector3.new(look.X, 0, look.Z)
            local fwd = 0
            if flat.Magnitude > 0.01 then fwd = dir:Dot(flat.Unit) end
            vec = dir + Vector3.new(0, look.Y * fwd, 0)
        end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then vec = vec + Vector3.new(0, 1, 0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            vec = vec - Vector3.new(0, 1, 0)
        end
        if vec.Magnitude > 1 then vec = vec.Unit end
        FlyBV.Velocity = vec * Config.FlySpeed
    end))

    -- Infinite jump
    Track(UserInputService.JumpRequest:Connect(function()
        if Config.InfJump then
            local _, _, hum = GetChar()
            if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
        end
    end))

    -- Fullbright (snapshots + restores real lighting)
    local LightOrig
    local LightProps = { "Brightness", "ClockTime", "FogEnd", "GlobalShadows", "Ambient", "OutdoorAmbient" }
    local function RestoreLighting()
        if LightOrig then
            for k, v in pairs(LightOrig) do pcall(function() Lighting[k] = v end) end
            LightOrig = nil
        end
    end
    Track(RunService.Heartbeat:Connect(function()
        if Config.Fullbright then
            if not LightOrig then
                LightOrig = {}
                for _, k in ipairs(LightProps) do LightOrig[k] = Lighting[k] end
            end
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.FogEnd = 100000
            Lighting.GlobalShadows = false
            Lighting.Ambient = Color3.fromRGB(200, 200, 200)
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        elseif LightOrig then
            RestoreLighting()
        end
    end))
    Track(RestoreLighting)

    -- Anti AFK
    Track(LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end))
end

------------------------------------------------------------------------
-- VISUALS (ESP / Tracers)
------------------------------------------------------------------------
do
    local EnemyMarks, ChestMarks, DropMarks = {}, {}, {}

    local function SyncMarkers(pool, wanted, create, update)
        for key, mark in pairs(pool) do
            if not wanted[key] or not mark.Parent then
                mark:Destroy()
                pool[key] = nil
            end
        end
        for key, data in pairs(wanted) do
            local mark = pool[key]
            if not mark then
                mark = create(key, data)
                pool[key] = mark
            end
            if update then update(mark, data) end
        end
    end

    local function TopN(list, n)
        table.sort(list, function(a, b) return a.d < b.d end)
        local out = {}
        for i = 1, math.min(n, #list) do out[list[i].key] = list[i] end
        return out
    end

    local function MakeTag(adornee, color, width)
        local gui = Make("BillboardGui", {
            Adornee = adornee, AlwaysOnTop = true, ResetOnSpawn = false,
            Size = UDim2.fromOffset(width, 18), StudsOffset = Vector3.new(0, 2.5, 0),
        }, ScreenGui)
        Make("TextLabel", {
            Name = "L", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = color,
            TextStrokeTransparency = 0.4, Text = "",
        }, gui)
        return gui
    end

    Every("ESP", 0.3, function()
        local _, root = GetChar()
        local cam = workspace.CurrentCamera
        local origin = root and root.Position or (cam and cam.CFrame.Position)
        if not origin then return end
        local range = Config.ESPRange

        -- Enemies (Highlight limit is 31, so cap at 30 nearest)
        local wanted = {}
        if Config.EnemyESP then
            local list = {}
            for _, e in ipairs(World.Enemies) do
                if e.Model.Parent and e.Humanoid.Health > 0 then
                    local d = (e.Root.Position - origin).Magnitude
                    if d <= range then list[#list + 1] = { key = e.Model, d = d } end
                end
            end
            wanted = TopN(list, 30)
        end
        SyncMarkers(EnemyMarks, wanted, function(model)
            return Make("Highlight", {
                Name = "PBH_ESP", Adornee = model,
                FillColor = Color3.fromRGB(239, 68, 68), OutlineColor = Color3.new(1, 1, 1),
                FillTransparency = 0.55, OutlineTransparency = 0,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, ScreenGui)
        end)

        -- Chests
        wanted = {}
        if Config.ChestESP then
            local list = {}
            for prompt in pairs(Prompts) do
                if prompt.Parent and IsChestPrompt(prompt) then
                    local pos, part = PromptPos(prompt)
                    if pos then
                        local d = (pos - origin).Magnitude
                        if d <= range then list[#list + 1] = { key = prompt, d = d, part = part } end
                    end
                end
            end
            wanted = TopN(list, 40)
        end
        SyncMarkers(ChestMarks, wanted, function(_, data)
            return MakeTag(data.part, Color3.fromRGB(250, 204, 21), 110)
        end, function(mark, data)
            local txt = "Chest " .. math.floor(data.d) .. "m"
            if mark.L.Text ~= txt then mark.L.Text = txt end
        end)

        -- Drops
        wanted = {}
        if Config.DropESP then
            local list = {}
            for _, drop in ipairs(World.Drops) do
                if drop.Parent then
                    local d = (drop.Position - origin).Magnitude
                    if d <= range then list[#list + 1] = { key = drop, d = d } end
                end
            end
            wanted = TopN(list, 40)
        end
        SyncMarkers(DropMarks, wanted, function(drop)
            local m = MakeTag(drop, Color3.fromRGB(52, 211, 153), 20)
            m.L.Text = "◆"
            return m
        end)
    end)

    Track(function()
        for _, pool in ipairs({ EnemyMarks, ChestMarks, DropMarks }) do
            for key, mark in pairs(pool) do
                pcall(function() mark:Destroy() end)
                pool[key] = nil
            end
        end
    end)

    -- Tracers (needs executor Drawing API)
    local okD, newFn = pcall(function() return Drawing.new end)
    local HasDrawing = okD and newFn ~= nil
    UI.HasDrawing = HasDrawing
    local Lines, Shown = {}, false

    Track(RunService.RenderStepped:Connect(function()
        if not HasDrawing then return end
        if not Config.Tracers then
            if Shown then
                for i = 1, #Lines do Lines[i].Visible = false end
                Shown = false
            end
            return
        end
        Shown = true
        local cam = workspace.CurrentCamera
        if not cam then return end
        local vp = cam.ViewportSize
        local from = Vector2.new(vp.X / 2, vp.Y)
        local _, root = GetChar()
        local origin = root and root.Position or cam.CFrame.Position

        local n = 0
        for _, e in ipairs(World.Enemies) do
            if n >= 30 then break end
            if e.Model.Parent and e.Humanoid.Health > 0 then
                local pos = e.Root.Position
                if (pos - origin).Magnitude <= Config.ESPRange then
                    local sp, onScreen = cam:WorldToViewportPoint(pos)
                    if onScreen then
                        n = n + 1
                        local ln = Lines[n]
                        if not ln then
                            ln = Drawing.new("Line")
                            ln.Thickness = 1.5
                            ln.Transparency = 1
                            ln.Color = Color3.fromRGB(239, 68, 68)
                            Lines[n] = ln
                        end
                        ln.From = from
                        ln.To = Vector2.new(sp.X, sp.Y)
                        ln.Visible = true
                    end
                end
            end
        end
        for i = n + 1, #Lines do Lines[i].Visible = false end
    end))

    Track(function()
        for i = 1, #Lines do pcall(function() Lines[i]:Remove() end) end
        Lines = {}
    end)
end

------------------------------------------------------------------------
-- PERSISTENCE
------------------------------------------------------------------------
local Controls = {}
local HasFS = (writefile and readfile and isfile) and true or false

local function SaveConfig()
    if not HasFS then return false end
    local out = {}
    for k, v in pairs(Config) do
        if not NoPersist[k] then out[k] = v end
    end
    return (pcall(function() writefile(CONFIG_FILE, HttpService:JSONEncode(out)) end))
end

local function LoadConfig()
    if not HasFS then return false end
    local ok, data = pcall(function()
        if isfile(CONFIG_FILE) then
            return HttpService:JSONDecode(readfile(CONFIG_FILE))
        end
    end)
    if not ok or type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if Defaults[k] ~= nil and not NoPersist[k] and type(v) == type(Defaults[k]) then
            if Controls[k] then Controls[k].Set(v) else Config[k] = v end
        end
    end
    Dirty = false
    return true
end

Every("AutoSave", 3, function()
    if Dirty then
        Dirty = false
        SaveConfig()
    end
end, function() return Config.AutoSave and HasFS end)

------------------------------------------------------------------------
-- UI: THEME & BUILDERS
------------------------------------------------------------------------
local Theme = {
    Bg = Color3.fromRGB(12, 13, 19),
    Header = Color3.fromRGB(17, 19, 28),
    Sidebar = Color3.fromRGB(15, 17, 24),
    Content = Color3.fromRGB(11, 12, 17),
    Card = Color3.fromRGB(19, 22, 31),
    CardHover = Color3.fromRGB(27, 31, 44),
    Stroke = Color3.fromRGB(32, 37, 52),
    Off = Color3.fromRGB(40, 45, 62),
    Text = Color3.fromRGB(225, 229, 240),
    Sub = Color3.fromRGB(135, 141, 165),
}
local Accents = {
    Purple = Color3.fromRGB(139, 92, 246),
    Blue = Color3.fromRGB(59, 130, 246),
    Green = Color3.fromRGB(16, 185, 129),
    Red = Color3.fromRGB(244, 63, 94),
    Orange = Color3.fromRGB(249, 115, 22),
    Cyan = Color3.fromRGB(6, 182, 212),
}
local AccentBound, AccentCallbacks = {}, {}

local function Accent() return Accents[Config.Accent] or Accents.Purple end
local function Bind(inst, prop)
    AccentBound[#AccentBound + 1] = { inst, prop }
    inst[prop] = Accent()
    return inst
end
local function ApplyAccent()
    local c = Accent()
    for i = #AccentBound, 1, -1 do
        local b = AccentBound[i]
        if b[1].Parent then b[1][b[2]] = c else table.remove(AccentBound, i) end
    end
    for _, fn in ipairs(AccentCallbacks) do pcall(fn) end
end

local function Tween(obj, t, props)
    local tw = TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function Round(o, r) return Make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function Outline(o, color, thick)
    return Make("UIStroke", { Color = color or Theme.Stroke, Thickness = thick or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o)
end
local function Label(parent, props)
    local p = {
        BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        Font = Enum.Font.GothamMedium, TextSize = 13, TextColor3 = Theme.Text,
        TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
    }
    for k, v in pairs(props) do p[k] = v end
    return Make("TextLabel", p, parent)
end

-- Dragging (header drags the window; tap-vs-drag detection for the floating button)
local function MakeDraggable(handle, target, onTap)
    local dragging, moved, dragStart, startPos = false, false, nil, nil
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, target.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    conn:Disconnect()
                    if onTap and not moved then onTap() end
                end
            end)
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end
            if moved then
                target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
end

-- Window
local function WindowSize()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return UDim2.fromOffset(math.clamp(vp.X - 24, 360, 640), math.clamp(vp.Y - 24, 260, 430))
end

local Window = Make("CanvasGroup", {
    Name = "Window", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = WindowSize(), BackgroundColor3 = Theme.Bg, BorderSizePixel = 0,
}, ScreenGui)
Round(Window, 12)
Outline(Window, Theme.Stroke, 1)
if workspace.CurrentCamera then
    Track(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        Window.Size = WindowSize()
    end))
end

local function SetMenu(open)
    MenuOpen = open
    if open then
        Window.Visible = true
        Window.GroupTransparency = 1
        Tween(Window, 0.15, { GroupTransparency = 0 })
    else
        Tween(Window, 0.12, { GroupTransparency = 1 })
        task.delay(0.13, function()
            if not MenuOpen then Window.Visible = false end
        end)
    end
end

-- Header
local Header = Make("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Header, BorderSizePixel = 0 }, Window)
Make("Frame", { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0 }, Header)
local Title = Label(Header, {
    Text = "⚔  PIXEL BLADE <font color='#a78bfa'>HUB</font>", RichText = true,
    Font = Enum.Font.GothamBold, TextSize = 15, Size = UDim2.new(0, 190, 1, 0), Position = UDim2.new(0, 16, 0, 0),
})
local StatsLabel = Label(Header, {
    Text = "-- FPS", TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11, TextColor3 = Theme.Sub,
    Size = UDim2.new(0, 120, 1, 0), Position = UDim2.new(1, -168, 0, 0),
})
local CloseBtn = Make("TextButton", {
    Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -40, 0.5, -16), BackgroundTransparency = 1,
    Text = "✕", Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Theme.Sub,
}, Header)
CloseBtn.MouseButton1Click:Connect(function() SetMenu(false) end)
MakeDraggable(Header, Window)

-- Sidebar / Content
local Sidebar = Make("Frame", { Size = UDim2.new(0, 138, 1, -46), Position = UDim2.new(0, 0, 0, 46), BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0 }, Window)
Make("UIListLayout", { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }, Sidebar)
Make("UIPadding", { PaddingTop = UDim.new(0, 8) }, Sidebar)
Label(Window, {
    Text = "v" .. VERSION, TextSize = 10, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Center,
    Size = UDim2.new(0, 138, 0, 18), Position = UDim2.new(0, 0, 1, -22),
})

local Content = Make("Frame", { Size = UDim2.new(1, -150, 1, -58), Position = UDim2.new(0, 144, 0, 52), BackgroundTransparency = 1 }, Window)
local SearchBox = Make("TextBox", {
    Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
    PlaceholderText = "🔍  Search settings…", PlaceholderColor3 = Theme.Sub, Text = "", ClearTextOnFocus = false,
    Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
}, Content)
Round(SearchBox, 8)
Outline(SearchBox)
Make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SearchBox)
local PageHolder = Make("Frame", { Size = UDim2.new(1, 0, 1, -36), Position = UDim2.new(0, 0, 0, 36), BackgroundTransparency = 1, ClipsDescendants = true }, Content)

-- Tabs
local Tabs, Pages, TabOrder, Orders = {}, {}, 0, {}

local function ApplySearch()
    local page = Pages[CurrentTab]
    if not page then return end
    local q = string.lower(SearchBox.Text)
    for _, child in ipairs(page:GetChildren()) do
        local s = child:GetAttribute("Search")
        if s ~= nil then
            child.Visible = (q == "") or (string.find(s, q, 1, true) ~= nil)
        elseif child:GetAttribute("Section") then
            child.Visible = (q == "")
        end
    end
end
Track(SearchBox:GetPropertyChangedSignal("Text"):Connect(ApplySearch))

local function SelectTab(name)
    CurrentTab = name
    for n, page in pairs(Pages) do page.Visible = (n == name) end
    for n, t in pairs(Tabs) do
        local on = (n == name)
        t.Indicator.Visible = on
        Tween(t.Button, 0.15, { BackgroundTransparency = on and 0 or 1, TextColor3 = on and Accent() or Theme.Sub })
    end
    ApplySearch()
end
AccentCallbacks[#AccentCallbacks + 1] = function()
    local t = Tabs[CurrentTab]
    if t then t.Button.TextColor3 = Accent() end
end

local function CreateTab(name, icon)
    TabOrder = TabOrder + 1
    local btn = Make("TextButton", {
        Name = name, Size = UDim2.new(1, -12, 0, 34), BackgroundColor3 = Theme.Card, BackgroundTransparency = 1,
        BorderSizePixel = 0, AutoButtonColor = false, Text = icon .. "  " .. name, Font = Enum.Font.GothamMedium,
        TextSize = 13, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = TabOrder,
    }, Sidebar)
    Round(btn, 8)
    Make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, btn)
    local ind = Make("Frame", { Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, -14, 0.5, -8), BorderSizePixel = 0, Visible = false }, btn)
    Bind(ind, "BackgroundColor3")
    Round(ind, 2)

    local page = Make("ScrollingFrame", {
        Name = name .. "Page", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y, ElasticBehavior = Enum.ElasticBehavior.Never, Visible = false,
    }, PageHolder)
    Bind(page, "ScrollBarImageColor3")
    Make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    Make("UIPadding", { PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10), PaddingRight = UDim.new(0, 8) }, page)

    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    Tabs[name] = { Button = btn, Indicator = ind }
    Pages[name] = page
    return page
end

-- Components
local ActiveSlider, Listening = nil, nil
local function NextOrder(page)
    Orders[page] = (Orders[page] or 0) + 1
    return Orders[page]
end

local function Card(page, height, searchText)
    local c = Make("Frame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
        ClipsDescendants = true, LayoutOrder = NextOrder(page),
    }, page)
    Round(c, 8)
    Outline(c)
    c:SetAttribute("Search", string.lower(searchText or ""))
    return c
end

function UI.Section(page, title)
    local l = Label(page, { Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 11, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = NextOrder(page) })
    Bind(l, "TextColor3")
    l:SetAttribute("Section", true)
    return l
end

function UI.Toggle(page, title, key, onChange, desc)
    local c = Card(page, desc and 54 or 40, title .. " " .. (desc or ""))
    Label(c, { Text = title, Size = UDim2.new(1, -72, 0, desc and 20 or 40), Position = UDim2.new(0, 12, 0, desc and 8 or 0) })
    if desc then
        Label(c, { Text = desc, TextSize = 11, TextColor3 = Theme.Sub, Size = UDim2.new(1, -72, 0, 16), Position = UDim2.new(0, 12, 0, 28) })
    end
    local sw = Make("Frame", { Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -52, 0.5, -11), BackgroundColor3 = Theme.Off, BorderSizePixel = 0 }, c)
    Round(sw, 11)
    local knob = Make("Frame", { Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, sw)
    Round(knob, 8)
    local hit = Make("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, c)

    local function Render(animate)
        local on = Config[key]
        local col = on and Accent() or Theme.Off
        local pos = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        if animate then
            Tween(sw, 0.16, { BackgroundColor3 = col })
            Tween(knob, 0.16, { Position = pos })
        else
            sw.BackgroundColor3 = col
            knob.Position = pos
        end
    end
    local function Set(v, silent)
        Config[key] = v
        Render(true)
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end
    hit.MouseButton1Click:Connect(function() Set(not Config[key]) end)
    Controls[key] = { Set = Set }
    AccentCallbacks[#AccentCallbacks + 1] = function() Render(false) end
    Render(false)
    return c
end

function UI.Slider(page, title, key, minV, maxV, decimals, suffix, onChange)
    decimals, suffix = decimals or 0, suffix or ""
    local c = Card(page, 54, title)
    Label(c, { Text = title, Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.new(0, 12, 0, 6) })
    local val = Label(c, {
        Size = UDim2.new(0.4, -12, 0, 22), Position = UDim2.new(0.6, 0, 0, 6),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 12,
    })
    Bind(val, "TextColor3")
    local hit = Make("TextButton", { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 28), BackgroundTransparency = 1, Text = "" }, c)
    local bar = Make("Frame", { Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3), BackgroundColor3 = Theme.Off, BorderSizePixel = 0 }, hit)
    Round(bar, 3)
    local fill = Make("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, bar)
    Bind(fill, "BackgroundColor3")
    Round(fill, 3)

    local mult = 10 ^ decimals
    local fmt = "%." .. decimals .. "f"
    local function Render()
        local v = Config[key]
        fill.Size = UDim2.fromScale(math.clamp((v - minV) / (maxV - minV), 0, 1), 1)
        val.Text = string.format(fmt, v) .. suffix
    end
    local function Set(v, silent)
        v = math.clamp(v, minV, maxV)
        v = math.floor(v * mult + 0.5) / mult
        Config[key] = v
        Render()
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end
    local function FromInput(input)
        local w = bar.AbsoluteSize.X
        if w <= 0 then return end
        local r = math.clamp((input.Position.X - bar.AbsolutePosition.X) / w, 0, 1)
        Set(minV + (maxV - minV) * r)
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            ActiveSlider = { fn = FromInput, page = page }
            page.ScrollingEnabled = false
            FromInput(input)
        end
    end)
    Controls[key] = { Set = Set }
    Render()
    return c
end

function UI.Dropdown(page, title, key, options, onChange)
    local HEAD = 40
    local full = HEAD + #options * 30 + 6
    local c = Card(page, HEAD, title)
    Label(c, { Text = title, Size = UDim2.new(0.5, 0, 0, HEAD), Position = UDim2.new(0, 12, 0, 0) })
    local valueLbl = Label(c, {
        Size = UDim2.new(0.5, -12, 0, HEAD), Position = UDim2.new(0.5, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 12,
    })
    Bind(valueLbl, "TextColor3")

    local btns = {}
    for i, opt in ipairs(options) do
        local b = Make("TextButton", {
            Size = UDim2.new(1, -16, 0, 26), Position = UDim2.new(0, 8, 0, HEAD + (i - 1) * 30),
            BackgroundColor3 = Theme.Card, BorderSizePixel = 0, AutoButtonColor = false,
            Text = opt, Font = Enum.Font.GothamMedium, TextSize = 12, TextColor3 = Theme.Sub,
        }, c)
        Round(b, 6)
        btns[opt] = b
    end
    local head = Make("TextButton", { Size = UDim2.new(1, 0, 0, HEAD), BackgroundTransparency = 1, Text = "", ZIndex = 5 }, c)

    local open = false
    local function Collapse()
        open = false
        Tween(c, 0.18, { Size = UDim2.new(1, 0, 0, HEAD) })
    end
    local function Render()
        valueLbl.Text = tostring(Config[key]) .. "  ▾"
        for opt, b in pairs(btns) do
            local sel = (opt == Config[key])
            b.TextColor3 = sel and Accent() or Theme.Sub
            b.BackgroundColor3 = sel and Theme.CardHover or Theme.Card
        end
    end
    local function Set(v, silent)
        Config[key] = v
        Render()
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end
    head.MouseButton1Click:Connect(function()
        open = not open
        Tween(c, 0.18, { Size = UDim2.new(1, 0, 0, open and full or HEAD) })
    end)
    for opt, b in pairs(btns) do
        b.MouseButton1Click:Connect(function()
            Set(opt)
            Collapse()
        end)
    end
    Controls[key] = { Set = Set }
    AccentCallbacks[#AccentCallbacks + 1] = Render
    Render()
    return c
end

function UI.Keybind(page, title, key, onChange)
    local c = Card(page, 40, title)
    Label(c, { Text = title, Size = UDim2.new(1, -130, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
    local btn = Make("TextButton", {
        Size = UDim2.fromOffset(100, 26), Position = UDim2.new(1, -112, 0.5, -13), BackgroundColor3 = Theme.Off,
        BorderSizePixel = 0, AutoButtonColor = true, Text = Config[key], Font = Enum.Font.GothamBold,
        TextSize = 12, TextColor3 = Theme.Text,
    }, c)
    Round(btn, 6)
    local function Set(v, silent)
        Config[key] = v
        btn.Text = v
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end
    btn.MouseButton1Click:Connect(function()
        btn.Text = "Press a key…"
        Listening = function(kc)
            if kc == Enum.KeyCode.Escape or kc == Enum.KeyCode.Backspace then Set("None") else Set(kc.Name) end
        end
    end)
    Controls[key] = { Set = Set }
    return c
end

function UI.Button(page, title, text, onClick)
    local c = Card(page, 40, title)
    Label(c, { Text = title, Size = UDim2.new(1, -120, 1, 0), Position = UDim2.new(0, 12, 0, 0) })
    local b = Make("TextButton", {
        Size = UDim2.fromOffset(90, 26), Position = UDim2.new(1, -102, 0.5, -13), BorderSizePixel = 0,
        AutoButtonColor = true, Text = text, Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = Color3.new(1, 1, 1),
    }, c)
    Bind(b, "BackgroundColor3")
    Round(b, 6)
    b.MouseButton1Click:Connect(function()
        local ok, err = pcall(onClick)
        if not ok then warn("[PixelBlade] button error: " .. tostring(err)) end
    end)
    return c
end

function UI.Info(page, title)
    local c = Card(page, 34, title)
    Label(c, { Text = title, Size = UDim2.new(0.45, 0, 1, 0), Position = UDim2.new(0, 12, 0, 0), TextColor3 = Theme.Sub, TextSize = 12 })
    local v = Label(c, {
        Text = "—", Size = UDim2.new(0.55, -12, 1, 0), Position = UDim2.new(0.45, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 12,
    })
    return function(text)
        if v.Text ~= text then v.Text = text end
    end
end

-- Global slider drag + keybind listening (single connections for the whole UI)
Track(UserInputService.InputChanged:Connect(function(input)
    if ActiveSlider and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        ActiveSlider.fn(input)
    end
end))
Track(UserInputService.InputEnded:Connect(function(input)
    if ActiveSlider and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
        ActiveSlider.page.ScrollingEnabled = true
        ActiveSlider = nil
    end
end))

-- Notifications
local NotifyHolder = Make("Frame", {
    AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -14, 1, -14), Size = UDim2.fromOffset(250, 400),
    BackgroundTransparency = 1,
}, ScreenGui)
Make("UIListLayout", {
    Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder,
    VerticalAlignment = Enum.VerticalAlignment.Bottom, HorizontalAlignment = Enum.HorizontalAlignment.Right,
}, NotifyHolder)

function UI.Notify(title, body, dur)
    local t = Make("CanvasGroup", {
        Size = UDim2.fromOffset(240, 0), AutomaticSize = Enum.AutomaticSize.Y,
        BackgroundColor3 = Theme.Header, BorderSizePixel = 0, GroupTransparency = 1,
    }, NotifyHolder)
    Round(t, 8)
    Bind(Outline(t, Theme.Stroke, 1.2), "Color")
    Make("UIPadding", { PaddingTop = UDim.new(0, 9), PaddingBottom = UDim.new(0, 9), PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, t)
    Make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, t)
    Label(t, { Text = title, Font = Enum.Font.GothamBold, TextSize = 13, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 1 })
    if body then
        Label(t, {
            Text = body, TextSize = 12, TextColor3 = Theme.Sub, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
            AutomaticSize = Enum.AutomaticSize.Y, Size = UDim2.new(1, 0, 0, 0), LayoutOrder = 2,
            TextYAlignment = Enum.TextYAlignment.Top,
        })
    end
    Tween(t, 0.2, { GroupTransparency = 0 })
    task.delay(dur or 3, function()
        if t.Parent then
            Tween(t, 0.25, { GroupTransparency = 1 })
            task.wait(0.3)
            t:Destroy()
        end
    end)
end

-- Floating button (tap = toggle, drag = move)
local MobileBtn = Make("TextButton", {
    Name = "Toggle", Size = UDim2.fromOffset(46, 46), Position = UDim2.new(0, 14, 0.4, 0),
    BackgroundColor3 = Theme.Header, BorderSizePixel = 0, Text = "⚔", TextSize = 22,
    TextColor3 = Color3.new(1, 1, 1), AutoButtonColor = false, Active = true,
}, ScreenGui)
Round(MobileBtn, 23)
Bind(Outline(MobileBtn, Theme.Stroke, 2), "Color")
MakeDraggable(MobileBtn, MobileBtn, function() SetMenu(not MenuOpen) end)

------------------------------------------------------------------------
-- UI: PAGES
------------------------------------------------------------------------
local TargetInfo, CountInfo

do -- Combat
    local p = CreateTab("Combat", "⚔️")
    UI.Section(p, "Kill Aura")
    UI.Toggle(p, "Kill Aura", "KillAura", function(v) if not v then Target = nil end end, "Only attacks enemies inside Attack Range")
    TargetInfo = UI.Info(p, "Current target")
    CountInfo = UI.Info(p, "Enemies in range")
    UI.Dropdown(p, "Target Priority", "TargetPriority", { "Closest", "LowestHP", "BossFirst" })
    UI.Toggle(p, "Lock Onto Target", "LockTarget", nil, "Stay on one enemy until it dies or leaves range")
    UI.Dropdown(p, "Attack Method", "AttackMethod", { "Both", "Input Module", "Remote" })
    UI.Slider(p, "Attack Rate", "AttackRate", 0.03, 0.5, 2, "s")
    UI.Slider(p, "Attack Range", "AttackRange", 10, 200, 0, " studs")
    UI.Keybind(p, "Kill Aura Hotkey", "KillAuraKey")

    UI.Section(p, "Abilities")
    UI.Toggle(p, "Auto Skills (1 & 2)", "AutoSkills")
    UI.Slider(p, "Skill Interval", "SkillInterval", 0.2, 3, 1, "s")
    UI.Toggle(p, "Auto Dodge / Dash", "AutoDodge")
    UI.Slider(p, "Dash Interval", "DashInterval", 0.5, 5, 1, "s")

    UI.Section(p, "Teleport & Orbit")
    UI.Toggle(p, "Teleport to Target", "AutoTP", nil, "Keep Attack Range above your orbit distance")
    UI.Dropdown(p, "Position Mode", "TPMode", { "Orbit", "Above", "Behind", "Under" })
    UI.Slider(p, "Height / Distance", "TPDistance", 5, 40, 0)
    UI.Slider(p, "Orbit Radius", "OrbitRadius", 10, 50, 0)
    UI.Slider(p, "Orbit Speed", "OrbitSpeed", 60, 360, 0, "°/s")
    UI.Slider(p, "Teleport Seek Range", "TPSeekRange", 20, 400, 0, " studs")
end

do -- Dungeon
    local p = CreateTab("Dungeon", "🏰")
    UI.Section(p, "Progression")
    UI.Toggle(p, "Auto Replay / End Vote", "AutoReplay")
    UI.Toggle(p, "Auto Pick Charm Cards", "AutoCardPick")
    UI.Slider(p, "Card Priority Slot", "CardPriority", 1, 3, 0)
    UI.Toggle(p, "Auto Skip Cutscenes", "AutoSkipCutscenes")
    UI.Toggle(p, "Auto Rescue Fallen Teammates", "AutoRevive")

    UI.Section(p, "Loot")
    UI.Toggle(p, "Auto Collect Drops", "AutoCollectDrops")
    UI.Slider(p, "Collect Range", "CollectRange", 20, 300, 0, " studs")
    UI.Toggle(p, "Auto Unlock Dark Chests", "AutoDarkChest")
    UI.Slider(p, "Chest Interaction Range", "ChestRange", 10, 150, 0, " studs")

    UI.Section(p, "Boss Mechanics")
    UI.Toggle(p, "Auto Pass Korth Skill Check", "AutoKorth")
    UI.Toggle(p, "Auto Break Morvik Bubbles", "AutoMorvik")
end

do -- Fishing
    local p = CreateTab("Fishing", "🎣")
    UI.Section(p, "Auto Fishing")
    UI.Toggle(p, "Auto Fishing (Cast & Reel)", "AutoFish")
    UI.Toggle(p, "Instant Reel / Fast Hook", "InstantReel")
    UI.Toggle(p, "Auto Equip Bait", "AutoBait")
    UI.Dropdown(p, "Bait", "BaitType", { "FleshGrubs", "MagicEyeballs", "Nightcrawlers" })
    UI.Toggle(p, "Auto Sell Caught Fish", "AutoSellFish")
    UI.Toggle(p, "Auto Upgrade Fishing Stash", "AutoUpgradeStash")
    UI.Button(p, "Sell everything now", "SELL", function()
        Fire(R.SellCatch)
        Fire(R.SellCharm)
        Notify("Fishing", "Sell request sent.", 2)
    end)
end

do -- Items
    local p = CreateTab("Items", "🎒")
    UI.Section(p, "Chests")
    UI.Toggle(p, "Auto Open Inventory Chests", "AutoOpenChests")
    UI.Dropdown(p, "Chest Type", "OpenChestType", { "All", "Wooden", "Royal", "Electric", "Legendary" })
    UI.Section(p, "Daily & Quests")
    UI.Button(p, "Daily Reward", "CLAIM", function() Fire(R.Daily) Notify("Claimed", "Daily reward requested.", 2) end)
    UI.Button(p, "Puzzle / Parkour / Rose", "CLAIM", function()
        Fire(R.Puzzle)
        Fire(R.Parkour)
        Fire(R.Rose)
        Notify("Claimed", "Quest chests requested.", 2)
    end)
    UI.Section(p, "Potions")
    UI.Toggle(p, "Auto Use Health Potions", "AutoUsePotions")
    UI.Slider(p, "Potion HP Threshold", "PotionThreshold", 15, 80, 0, "%")
end

do -- Player
    local p = CreateTab("Player", "⚡")
    UI.Section(p, "Movement")
    UI.Toggle(p, "Custom WalkSpeed", "WalkSpeedEnabled")
    UI.Slider(p, "Speed", "WalkSpeedValue", 16, 120, 0)
    UI.Toggle(p, "Fly", "FlyEnabled", nil, "WASD / joystick, Space & Shift (or look up/down)")
    UI.Slider(p, "Fly Speed", "FlySpeed", 20, 150, 0)
    UI.Toggle(p, "Infinite Jump", "InfJump")
    UI.Toggle(p, "Noclip", "Noclip")
    UI.Section(p, "Quality of Life")
    UI.Toggle(p, "Fullbright", "Fullbright")
    UI.Toggle(p, "Anti AFK", "AntiAFK")
end

do -- Visuals
    local p = CreateTab("Visuals", "👁️")
    UI.Section(p, "ESP")
    UI.Toggle(p, "Enemy ESP", "EnemyESP")
    UI.Toggle(p, "Chest ESP", "ChestESP")
    UI.Toggle(p, "Drop ESP", "DropESP")
    UI.Toggle(p, "Enemy Tracers", "Tracers", function(v)
        if v and not UI.HasDrawing then
            Notify("Tracers unavailable", "Your executor has no Drawing API.", 4)
        end
    end)
    UI.Slider(p, "ESP Range", "ESPRange", 50, 500, 0, " studs")
end

do -- Settings
    local p = CreateTab("Settings", "⚙️")
    UI.Section(p, "Interface")
    UI.Dropdown(p, "Accent Color", "Accent", { "Purple", "Blue", "Green", "Red", "Orange", "Cyan" }, ApplyAccent)
    UI.Keybind(p, "Menu Key (Delete / Insert also work)", "MenuKey")
    UI.Button(p, "Reset window position", "RESET", function() Window.Position = UDim2.fromScale(0.5, 0.5) end)

    UI.Section(p, "Config")
    UI.Toggle(p, "Auto Save", "AutoSave", nil, HasFS and "Saves a few seconds after any change" or "Executor has no file access")
    UI.Button(p, "Save now", "SAVE", function()
        Notify("Config", SaveConfig() and "Saved." or "Could not save (no file access).", 2)
    end)
    UI.Button(p, "Load saved config", "LOAD", function()
        Notify("Config", LoadConfig() and "Loaded." or "No saved config found.", 2)
    end)
    UI.Button(p, "Reset to defaults", "RESET", function()
        for k, v in pairs(Defaults) do
            if Controls[k] then Controls[k].Set(v) else Config[k] = v end
        end
        Notify("Config", "All settings reset.", 2)
    end)

    UI.Section(p, "Tools")
    UI.Button(p, "Dump game remotes", "DUMP", function()
        if not NetworkRemotes then
            Notify("Remote dump", "_network_remotes folder not found.", 3)
            return
        end
        local names = {}
        for _, r in ipairs(NetworkRemotes:GetChildren()) do
            names[#names + 1] = r.Name .. " (" .. r.ClassName .. ")"
        end
        table.sort(names)
        local text = table.concat(names, "\n")
        print("[PixelBlade] Remotes:\n" .. text)
        local copied = false
        if setclipboard then copied = pcall(setclipboard, text) end
        Notify("Remote dump", #names .. " remotes printed to console" .. (copied and " and copied." or "."), 4)
    end)
    UI.Button(p, "Unload script", "UNLOAD", function()
        if Env.PixelBladeHubCleanup then Env.PixelBladeHubCleanup() end
    end)
end

------------------------------------------------------------------------
-- UI-DEPENDENT JOBS & INPUT
------------------------------------------------------------------------
Every("Stats", 0.5, function()
    local fps = FrameTime > 0 and math.floor(Frames / FrameTime + 0.5) or 0
    Frames, FrameTime = 0, 0
    local ping = 0
    pcall(function()
        ping = math.floor(StatsService.Network.ServerStatsItem["Data Ping"]:GetValue())
    end)
    StatsLabel.Text = fps .. " FPS · " .. ping .. " ms"
end, function() return MenuOpen end)

Every("CombatInfo", 0.25, function()
    local _, root = GetChar()
    if Target and root and Target.Model.Parent and Target.Humanoid.Health > 0 then
        local d = math.floor((Target.Root.Position - root.Position).Magnitude)
        TargetInfo(Target.Model.Name .. " · " .. d .. " studs")
    else
        TargetInfo("None in range")
    end
    local n = 0
    if root then
        for _, e in ipairs(World.Enemies) do
            if e.Model.Parent and e.Humanoid.Health > 0 and (e.Root.Position - root.Position).Magnitude <= Config.AttackRange then
                n = n + 1
            end
        end
    end
    CountInfo(tostring(n))
end, function() return MenuOpen and CurrentTab == "Combat" end)

Track(UserInputService.InputBegan:Connect(function(input, gpe)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if Listening then
        local f = Listening
        Listening = nil
        f(input.KeyCode)
        return
    end
    if gpe then return end
    local kc = input.KeyCode
    if kc == Enum.KeyCode.Delete or kc == Enum.KeyCode.Insert or kc.Name == Config.MenuKey then
        SetMenu(not MenuOpen)
    elseif Config.KillAuraKey ~= "None" and kc.Name == Config.KillAuraKey then
        local v = not Config.KillAura
        Controls.KillAura.Set(v)
        Notify("Kill Aura", v and "Enabled" or "Disabled", 1.5)
    end
end))

------------------------------------------------------------------------
-- CLEANUP / STARTUP
------------------------------------------------------------------------
local function Cleanup()
    if not Running then return end
    Running = false
    if Config.AutoSave and HasFS then pcall(SaveConfig) end
    for i = #Tracked, 1, -1 do
        local item = Tracked[i]
        local t = typeof(item)
        if t == "RBXScriptConnection" then
            pcall(function() item:Disconnect() end)
        elseif t == "Instance" then
            pcall(function() item:Destroy() end)
        elseif t == "function" then
            pcall(item)
        end
    end
    Tracked = {}
    Env.PixelBladeHubCleanup = nil
    print("⚔️ Pixel Blade Hub unloaded.")
end
Env.PixelBladeHubCleanup = Cleanup

LoadConfig()
ApplyAccent()
SelectTab("Combat")
SetMenu(true)

Notify("Pixel Blade Hub v" .. VERSION, "Loaded. Press " .. Config.MenuKey .. " (or tap ⚔) to toggle.", 4)
print("⚔️ Pixel Blade Hub v" .. VERSION .. " loaded.")
