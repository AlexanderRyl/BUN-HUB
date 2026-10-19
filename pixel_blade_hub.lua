--[[
    ========================================================================
    PIXEL BLADE HUB  v4.0
    ========================================================================
    Rebuilt from v3 against the real game data (decompiled from the
    official place files: Lobby / W1 / W2 / W3 / W4 / W5).

    Verified against the actual game (Place 18172550962):
      * Worlds      : Grasslands, AncientSands, HauntedTundra,
                      CrimsonAbyss, SunkenDepths
      * Modes       : Normal / Heroic / Nightmare  (3 chapters each)
      * Session     : create_play_session(PlaceId, PlaceDifficulty, MaxPlayers)
      * Run control : leave_run(), run_end_vote(), accept_run_earnings(),
                      debug_teleport_next_room(os.clock())
      * Input bus   : user_input BindableEvents -> attack, skill_one,
                      skill_two, aim_release
      * Armory      : equip_item(entity), upgrade_item(entity),
                      open_chest(ChestId, count), roll_class(os.clock())
      * Fishing     : fishing_cast / fishing_reel / fishing_landed /
                      equip_fishing_bait / sell_fish_catch / sell_fish_charm
      * Charms      : pick_charm_card(index)

    Every remote/module lookup is resolved dynamically and falls back
    gracefully, so a game update degrades instead of erroring.

    HOW IT'S BUILT
      * One scheduler (single Heartbeat) drives every timed job.
      * One cached world scan shared by combat / ESP / drops.
      * Remote + module caches with a 5s retry, never spam `FindFirstChild`.
      * Every connection, instance and listener is tracked and destroyed
        by `PixelBladeHubCleanup()` - hot-reloading is always safe.

    USAGE
      Load the script, RightShift (configurable) toggles the menu.
      Re-running the script unloads the previous instance automatically.
    ========================================================================
]]

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- Unload any previous copy of this hub (v3 included).
local Env = (getgenv and getgenv()) or _G
for _, key in ipairs({ "PixelBladeHubCleanup", "PixelBladeHub_v3_Cleanup" }) do
    if type(Env[key]) == "function" then pcall(Env[key]) end
    if type(_G[key]) == "function" then pcall(_G[key]) end
end

------------------------------------------------------------------------
-- SERVICES
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

local LocalPlayer = Players.LocalPlayer
local RS          = ReplicatedStorage
local VERSION     = "4.0"
local CONFIG_FILE = "PixelBladeHub_v4.json"

local Running    = true
local MenuOpen   = true
local CurrentTab = "Combat"

------------------------------------------------------------------------
-- GAME DATA  (extracted from the official place files)
------------------------------------------------------------------------
local WORLDS = {
    { id = "Grasslands",    label = "W1 - Grasslands",    boss = "Kingslayer" },
    { id = "AncientSands",  label = "W2 - Ancient Sands",  boss = "Atticus" },
    { id = "HauntedTundra", label = "W3 - Haunted Tundra", boss = "Kori" },
    { id = "CrimsonAbyss",  label = "W4 - Crimson Abyss",  boss = "Korth" },
    { id = "SunkenDepths",  label = "W5 - Sunken Depths",  boss = "Morvik" },
}
local WORLD_IDS = {}
for _, w in ipairs(WORLDS) do WORLD_IDS[w.id] = w.id end

local DIFFICULTIES = { "Normal", "Heroic", "Nightmare" }
local DIFF_ID      = { Normal = "Normal", Heroic = "Heroic", Nightmare = "Nightmare" }

local RARITY_ORDER  = { Common = 1, Rare = 2, Epic = 3, Legendary = 4, Vaulted = 5 }
local RARITY_COLORS = {
    Common    = Color3.fromRGB(188, 188, 188),
    Rare      = Color3.fromRGB(128, 186, 230),
    Epic      = Color3.fromRGB(220, 131, 255),
    Legendary = Color3.fromRGB(255, 196, 61),
    Vaulted   = Color3.fromRGB(255, 111, 145),
}

local BAITS = {
    { id = "Worms",         where = "Grasslands"    },
    { id = "CrabClaws",     where = "Ancient Sands"  },
    { id = "MiniSandworm",  where = "Ancient Sands"  },
    { id = "ArcticBerries", where = "Haunted Tundra" },
    { id = "GlowingEel",    where = "Haunted Tundra" },
    { id = "FleshGrubs",    where = "Crimson Abyss"  },
    { id = "MagicEyeballs", where = "Crimson Abyss"  },
    { id = "VoidSnail",     where = "Sunken Depths"  },
    { id = "AnglerFish",    where = "Sunken Depths"  },
}

local FISH = {
    { id = "FishGrey",       rarity = "Common",    sell = true  },
    { id = "FishBlue",       rarity = "Common",    sell = true  },
    { id = "FishCyan",       rarity = "Common",    sell = true  },
    { id = "StarfishBrown",  rarity = "Common",    sell = true  },
    { id = "StarfishBlue",   rarity = "Common",    sell = true  },
    { id = "StarfishPurple", rarity = "Rare",      sell = true  },
    { id = "OldBoot",        rarity = "Common",    sell = true  },
    { id = "Page",           rarity = "Rare",      sell = false },
    { id = "FishGold",       rarity = "Legendary", sell = false },
    { id = "GoldenTooth",    rarity = "Epic",      sell = false },
    { id = "DarkKey",        rarity = "Legendary", sell = false },
}

local CHARMS = { "Charm", "SuperCharm", "UltimateCharm" }

local RODS = {
    "ClassicPole", "DynamicPole", "IronPole", "MihPulkSawPole", "PythonPole",
    "FrozenPole", "LunarPole", "DarkFleshPole", "GoldPole", "WhiteRaven",
    "DragonPole", "Poltergeist",
}

local CHEST_SETS = {
    Common   = { "Wooden1", "Wooden2" },
    Royal    = { "Royal1", "Royal2" },
    Special  = { "Electric", "AncientElectric" },
    Legendary= { "Legendary1" },
    Daily    = { "Daily" },
    All      = { "Wooden1", "Wooden2", "Royal1", "Royal2",
                 "Electric", "AncientElectric", "Legendary1", "Daily" },
}

-- Boss / miniboss name fragments, used by the scanner and ESP.
local BOSS_TOKENS = {
    Kingslayer = true, Atticus = true, Kori = true, Korth = true, Morvik = true,
    John = true, GiantGoblin = true, Maneater = true, Nekros = true,
    ShimBombo = true, Akuma = true, Gatekeeper = true, InfestedBeast = true,
    DrownedGladiator = true, Ancient = true, TutorialBoss = true,
}

-- Static item catalog: name -> rarity. Live counts come from the Armory.
local ARMOR_CATALOG = {
    ["Chainmail"]       = "Common",  ["Dragonfly Armor"] = "Common",
    ["Bear Armor"]      = "Rare",    ["Gold Armor"]      = "Epic",
    ["Molten Armor"]    = "Epic",    ["Ninja Armor"]     = "Epic",
    ["Rogue Armor"]     = "Epic",    ["Elden Armor"]     = "Legendary",
    ["Pharaoh Armor"]   = "Legendary",["Soul Armor"]     = "Legendary",
    ["Valor Armor"]     = "Legendary",["Halo"]           = "Vaulted",
    ["Chronos Armor"]   = "Vaulted", ["Void Reaper"]     = "Vaulted",
}
local WEAPON_CATALOG = {
    ["Dead Stick"]="Common",["Bone Blade"]="Common",["Cactus Sword"]="Common",
    ["Obsidian Stick"]="Common",["Rapier"]="Common",["Atlantis"]="Common",
    ["Fire Blade"]="Rare",["Frost Blade"]="Rare",["Blood Sickle"]="Rare",
    ["Tomb Hammer"]="Rare",["Black Ice"]="Rare",["Black Star"]="Rare",
    ["Ghost Katana"]="Rare",["Echo of the Slain"]="Rare",
    ["Titan"]="Epic",["Wing Blade"]="Epic",["Volt"]="Epic",
    ["Water Staff"]="Epic",["Stellar"]="Epic",["Crusher"]="Epic",
    ["Sinner"]="Epic",["Naginata"]="Epic",["Ninja"]="Epic",
    ["Excalibur"]="Legendary",["Chained Daggers"]="Legendary",
    ["Ink Gauntlets"]="Legendary",["Vampire Axe"]="Legendary",
    ["Hellscape Scythe"]="Legendary",["Ice Spear"]="Legendary",
    ["Flesh Scythe"]="Legendary",["Crystal Scythe"]="Legendary",
    ["Dragon's Heart"]="Legendary",["Chronos Blade"]="Legendary",
    ["Void Reaver"]="Vaulted",["Blink"]="Vaulted",
}

-- Quest chain: completing each place/mode grants the next quest.
local QUEST_CHAIN = {
    { place = "Grasslands",    diff = "Normal",   given = "CG_02" },
    { place = "Grasslands",    diff = "Heroic",   given = "CG_07" },
    { place = "Grasslands",    diff = "Nightmare", given = "CG_07" },
    { place = "AncientSands",  diff = "Normal",   given = "CG_07" },
    { place = "AncientSands",  diff = "Heroic",   given = "W2_C_08" },
    { place = "AncientSands",  diff = "Nightmare", given = "W2_C_08" },
    { place = "HauntedTundra", diff = "Normal",   given = "W2_C_08" },
    { place = "HauntedTundra", diff = "Heroic",   given = "W3_C_08" },
    { place = "HauntedTundra", diff = "Nightmare", given = "W3_C_08" },
    { place = "CrimsonAbyss",  diff = "Normal",   given = "W3_C_08" },
    { place = "CrimsonAbyss",  diff = "Heroic",   given = "W4_C_08" },
    { place = "CrimsonAbyss",  diff = "Nightmare", given = "W4_C_08" },
    { place = "SunkenDepths",  diff = "Normal",   given = "W4_C_08" },
    { place = "SunkenDepths",  diff = "Heroic",   given = "W5_C_08" },
    { place = "SunkenDepths",  diff = "Nightmare", given = "W5_C_08" },
}

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local Config = {
    -- Combat
    KillAura        = false,
    AttackRate      = 0.08,
    AttackRange     = 60,
    TargetPriority  = "Closest",     -- Closest / LowestHP / BossFirst
    LockTarget      = true,
    AttackMethod    = "Both",        -- Both / Input / Remote
    AutoSkills      = false,
    SkillInterval   = 0.45,
    AutoDash        = false,
    DashInterval    = 1.2,
    NoCooldown      = true,          -- zero client cooldown attributes
    IgnoreArmor     = true,          -- max hit throughput + shield-break helpers
    MaxHitRate      = 0.03,
    AutoPotionSlot  = 1,
    PotionThreshold = 45,

    -- Survival
    TrueImmortal    = false,
    IgnoreDamage    = false,
    HideFromBosses  = false,
    AutoUsePotions  = true,

    -- Movement / target positioning
    AutoTP          = false,
    TPMode          = "Orbit",       -- Orbit / Behind / Above / Under / Stay
    TPDistance       = 16,
    OrbitRadius     = 22,
    OrbitSpeed      = 180,

    -- Runs / worlds
    SelectedWorld     = "Grasslands",
    SelectedDifficulty= "Normal",
    MaxPlayers        = 4,
    AutoNextRoom      = false,
    NextRoomDelay     = 0.6,
    AutoBossWave      = false,
    AutoKillAll       = false,
    AutoRaid          = false,
    AutoContinue      = false,
    ContinueDelay     = 3.0,
    AutoLeaveOnQuest  = false,
    LeaveAfterQuest   = true,
    AutoAcceptQuest   = false,
    AutoPlayQuest     = false,
    AutoCharmCard     = true,
    CharmCardIndex    = 1,
    AutoRevive        = true,
    AutoSkipCutscene  = true,
    AutoDaily         = true,
    AutoCodes         = true,

    -- Loot / world interaction
    AutoCollectDrops  = true,
    CollectRange      = 200,
    AutoOpenChests    = true,
    OpenChestSet      = "Royal",
    OpenChestBulk     = 10,
    AutoDarkChest     = true,
    DestroyProps      = false,       -- also destroy breakables in the map
    AutoPrompts       = true,
    PromptRange       = 45,

    -- Fishing
    AutoFish          = false,
    FastReel          = true,
    ReelDelay         = 0.35,
    LandDelay         = 0.25,
    LandBurst         = 3,           -- extra `landed` fires to hit the perfect window
    AutoBait          = true,
    BaitSelect        = "FleshGrubs",
    AutoSellFish      = false,
    SellThreshold     = 20,
    AutoUpgradeStash  = false,
    SellFishes        = { FishGrey = true, FishBlue = true, FishCyan = true,
                          StarfishBrown = true, StarfishBlue = true,
                          StarfishPurple = true, OldBoot = true,
                          Page = false, FishGold = false, GoldenTooth = false,
                          DarkKey = false },
    SellCharms        = false,
    SellCharmTier     = "Charm",      -- Charm / SuperCharm / UltimateCharm

    -- Inventory
    AutoUpgrade       = false,
    UpgradeCopies     = 2,            -- how many copies per tier
    MaxUpgradeTier    = 10,
    AutoEquipBest     = false,
    AutoClaims        = false,

    -- Visuals
    EnemyESP          = true,
    BossESP           = true,
    ChestESP          = true,
    DropESP           = true,
    Tracers           = false,
    ESPRange          = 260,
    Fullbright        = false,
    NoFog             = false,

    -- Player
    WalkSpeedEnabled  = false,
    WalkSpeedValue    = 48,
    FlyEnabled        = false,
    FlySpeed          = 55,
    InfJump           = false,
    Noclip            = false,
    AntiAFK           = true,

    -- Settings
    Accent            = "Purple",
    MenuKey           = "RightShift",
    AutoSave          = true,
}

local Defaults = {}
for k, v in pairs(Config) do Defaults[k] = v end

-- Never restored into a "you are currently cheating" state on load.
local NoPersist = {
    KillAura = true, AutoFish = true, FlyEnabled = true, Noclip = true,
    TrueImmortal = true, IgnoreDamage = true, NoCooldown = true,
    AutoNextRoom = true, AutoContinue = true, AutoTP = true,
    AutoBossWave = true, AutoKillAll = true, AutoRaid = true,
}

-- Dotted config keys address nested tables, e.g. "SellFishes.FishGold".
local function GetConfig(path)
    local node = Config
    for part in string.gmatch(path, "[^%.]+") do
        if type(node) ~= "table" then return nil end
        node = node[part]
    end
    return node
end

local function SetConfig(path, value)
    local parts = {}
    for part in string.gmatch(path, "[^%.]+") do parts[#parts + 1] = part end
    local node = Config
    for i = 1, #parts - 1 do
        if type(node[parts[i]]) ~= "table" then node[parts[i]] = {} end
        node = node[parts[i]]
    end
    node[parts[#parts]] = value
end

------------------------------------------------------------------------
-- CORE INFRASTRUCTURE
------------------------------------------------------------------------
local Tracked = {}
local function Track(item)
    Tracked[#Tracked + 1] = item
    return item
end

local UI = {}
local function Notify(title, body, dur) if UI.Notify then UI.Notify(title, body, dur) end end

local Dirty = false
local function MarkDirty() Dirty = true end

-- Unload
local Unloaded = false
local function Unload()
    if Unloaded then return end
    Unloaded = true
    Running = false
    for i = #Tracked, 1, -1 do
        local item = Tracked[i]
        pcall(function()
            if typeof(item) == "function" then item()
            elseif item and typeof(item) == "Instance" then item:Destroy()
            elseif type(item) == "table" and type(item.Disconnect) == "function" then item:Disconnect()
            end
        end)
        Tracked[i] = nil
    end
    Env.PixelBladeHubCleanup = nil
    if _G.PixelBladeHubCleanup then _G.PixelBladeHubCleanup = nil end
end

-- Scheduler: one Heartbeat drives every timed job.
local Jobs = {}
local Frames, FrameTime, StatAcc = 0, 0, 0
local function Every(name, interval, fn, gate)
    Jobs[#Jobs + 1] = { name = name, interval = interval, fn = fn,
                        gate = gate, acc = 0, busy = false, warned = false }
end

Track(RunService.Heartbeat:Connect(function(dt)
    Frames = Frames + 1
    FrameTime = FrameTime + dt
    StatAcc = StatAcc + dt
    if StatAcc >= 1 then
        StatAcc = 0
        if UI.SetStats then UI.SetStats(Frames, FrameTime) end
        Frames, FrameTime = 0, 0
    end
    for i = 1, #Jobs do
        local job = Jobs[i]
        if (not job.gate) or job.gate() then
            job.acc = job.acc + dt
            local iv = job.interval
            if type(iv) == "function" then iv = iv() end
            if job.acc >= iv and not job.busy then
                job.acc = 0
                job.busy = true
                task.spawn(function()
                    local ok, err = pcall(job.fn, math.min(iv, 0.5))
                    job.busy = false
                    if not ok and not job.warned then
                        job.warned = true
                        warn("[PixelBlade] job '" .. job.name .. "': " .. tostring(err))
                    end
                end)
            end
        else
            job.acc = 0
        end
    end
end))

------------------------------------------------------------------------
-- REMOTES  (cached, missing remotes retried every 5s)
------------------------------------------------------------------------
local NetworkRemotes = RS:FindFirstChild("_network_remotes") or RS:WaitForChild("_network_remotes", 15)
local RemoteCache, RemoteMiss = {}, {}

local function GetRemote(name)
    local r = RemoteCache[name]
    if r and r.Parent then return r end
    if not NetworkRemotes or not NetworkRemotes.Parent then return nil end
    local miss = RemoteMiss[name]
    if miss and os.clock() - miss < 5 then return nil end
    r = NetworkRemotes:FindFirstChild(name)
    if r then
        RemoteCache[name], RemoteMiss[name] = r, nil
    else
        RemoteMiss[name] = os.clock()
    end
    return r
end

-- Fire a remote. Never throws, never blocks.
local function Fire(name, ...)
    local r = GetRemote(name)
    if not r then return false end
    local args = table.pack(...)
    if r:IsA("RemoteEvent") then
        pcall(function() r:FireServer(table.unpack(args, 1, args.n)) end)
        return true
    elseif r:IsA("RemoteFunction") then
        task.spawn(function()
            pcall(function() r:InvokeServer(table.unpack(args, 1, args.n)) end)
        end)
        return true
    end
    return false
end

------------------------------------------------------------------------
-- GAME MODULES  (safe require + enum resolution)
------------------------------------------------------------------------
local function SafeRequire(path)
    local ok, mod = pcall(require, RS[path])
    if ok and type(mod) == "table" then return mod end
    return nil
end

-- Enums are generated by `make_enum`; their runtime values may be strings or
-- numbers, so resolve them from the game and fall back to the key name.
local EnumCache = {}
local function EnumId(moduleName, keyName, fallback)
    local cacheKey = moduleName .. "." .. keyName
    if EnumCache[cacheKey] ~= nil then return EnumCache[cacheKey] end
    local mod = SafeRequire("src.types.enums." .. moduleName)
    local v
    if mod then
        v = mod[keyName]
        if v == nil then
            -- enums are sometimes reversed: { [value] = key }
            for k, val in pairs(mod) do
                if val == keyName then
                    v = k
                    break
                end
            end
        end
    end
    if v == nil then v = fallback or keyName end
    EnumCache[cacheKey] = v
    return v
end

-- user_input BindableEvents: attack / skill_one / skill_two / aim_release
local UserInput = SafeRequire("src.client.user_input")
local function Signal(name)
    if not UserInput then return false end
    local s = UserInput[name]
    if s and type(s.Fire) == "function" then
        pcall(function() s:Fire(os.clock()) end)
        return true
    end
    return false
end

-- Fire the first signal that actually exists (inputs get renamed often).
local function SignalAny(...)
    local n = select("#", ...)
    for i = 1, n do
        if Signal((select(i, ...))) then return true end
    end
    return false
end

local HasUserInput = UserInput ~= nil and type(UserInput.attack) == "function"

------------------------------------------------------------------------
-- CHARACTER HELPERS
------------------------------------------------------------------------
local function GetChar()
    local char = LocalPlayer.Character
    if not char then return nil end
    local root = char:FindFirstChild("HumanoidRootPart")
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if root and hum and hum.Health > 0 then return char, root, hum end
    return nil
end

-- The equipped weapon, used as the first argument of activate_weapon.
local function GetWeapon()
    local char = LocalPlayer.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local back = LocalPlayer:FindFirstChildOfClass("Backpack")
    if back then return back:FindFirstChildOfClass("Tool") end
    return nil
end

------------------------------------------------------------------------
-- GUI  (created early so ESP can parent into it)
------------------------------------------------------------------------
local function Make(class, props, parent)
    local o = Instance.new(class)
    if props then for k, v in pairs(props) do o[k] = v end end
    if parent then o.Parent = parent end
    return o
end

local ScreenGui = Make("ScreenGui", {
    Name               = "PBH_" .. string.sub(HttpService:GenerateGUID(false), 1, 8),
    ResetOnSpawn       = false,
    ZIndexBehavior     = Enum.ZIndexBehavior.Sibling,
    DisplayOrder       = 999,
    IgnoreGuiInset     = true,
})
if syn and syn.protect_gui then pcall(syn.protect_gui, ScreenGui) end

do
    local parented = false
    if type(gethui) == "function" then
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
    if not parented then ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
end
Track(ScreenGui)

------------------------------------------------------------------------
-- WORLD SCAN  (one cheap pass shared by combat / ESP / drops)
------------------------------------------------------------------------
local World = { Enemies = {}, Drops = {}, Bosses = {}, Breakables = {}, Chests = {} }

local EnemyFolders = { "Enemies", "Mobs", "Entities", "NPCs", "Monsters",
                       "Enemy", "Bosses", "Minibosses", "Breakables", "Breakable" }

local function IsBoss(name)
    for token in pairs(BOSS_TOKENS) do
        if string.find(string.lower(name), string.lower(token), 1, true) then return true end
    end
    return false
end

local function IsDrop(part)
    if part.Name == "XP" then return true end
    return part:FindFirstChild("Trail") ~= nil or part:FindFirstChild("AlignPosition") ~= nil
end

local function ScanContainer(container, myChar, myUserId)
    for _, obj in ipairs(container:GetChildren()) do
        if obj:IsA("Model") then
            if obj ~= myChar then
                local owner = Players:GetPlayerFromCharacter(obj)
                if not owner or owner.UserId == myUserId then
                    local hum = obj:FindFirstChildWhichIsA("Humanoid")
                    if hum and hum.Health > 0 then
                        local root = obj:FindFirstChild("HumanoidRootPart") or obj.PrimaryPart
                        if root then
                            local entry = { Model = obj, Humanoid = hum, Root = root,
                                            Boss = IsBoss(obj.Name) }
                            World.Enemies[#World.Enemies + 1] = entry
                            if entry.Boss then World.Bosses[#World.Bosses + 1] = entry end
                        end
                    end
                end
            end
        elseif obj:IsA("BasePart") and container == workspace and IsDrop(obj) then
            World.Drops[#World.Drops + 1] = obj
        end
    end
end

local ScanNeeded = function()
    return Config.KillAura or Config.EnemyESP or Config.BossESP or Config.DropESP
        or Config.ChestESP or Config.Tracers or Config.AutoCollectDrops
        or Config.DestroyProps or (MenuOpen and (CurrentTab == "Combat" or CurrentTab == "Visuals"))
end

Every("WorldScan", 0.2, function()
    World.Enemies, World.Drops, World.Bosses, World.Breakables, World.Chests =
        {}, {}, {}, {}, {}
    local myChar = LocalPlayer.Character
    local myId = LocalPlayer.UserId
    ScanContainer(workspace, myChar, myId)
    for _, name in ipairs(EnemyFolders) do
        local f = workspace:FindFirstChild(name)
        if f then ScanContainer(f, myChar, myId) end
    end
end, ScanNeeded)

-- ProximityPrompt cache (no workspace:GetDescendants() per tick)
local Prompts = setmetatable({}, { __mode = "k" })
Track(workspace.DescendantAdded:Connect(function(d)
    if d:IsA("ProximityPrompt") then Prompts[d] = true end
end))
Track(workspace.DescendantRemoving:Connect(function(d)
    if d.Parent == nil then Prompts[d] = nil end
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
    if par:IsA("BasePart") then return par.Position, par end
    if par:IsA("Attachment") then return par.WorldPosition, par.Parent end
    if par:IsA("Model") then
        local pp = par.PrimaryPart or par:FindFirstChildWhichIsA("BasePart", true)
        if pp then return pp.Position, pp end
    end
    return nil
end

------------------------------------------------------------------------
-- COMBAT
------------------------------------------------------------------------
do
    local Target = nil

    local function PickTarget(origin, range)
        if Config.LockTarget and Target and Target.Model.Parent
            and Target.Humanoid.Health > 0
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
                        score = (e.Boss and -1e9 or 0) + d * 0.001
                    else
                        score = d
                    end
                    if not bestScore or score < bestScore then best, bestScore = e, score end
                end
            end
        end
        return best
    end

    local function Strike(t)
        local method = Config.AttackMethod
        if method ~= "Remote" then Signal("attack") end
        if method ~= "Input" and t then
            -- activate_weapon(entity, aim_position, kind) is the real hit call.
            local weapon = GetWeapon() or LocalPlayer.Character
            local aim = t.Root.Position
            if Config.IgnoreArmor then
                -- Sweep several aim points so the server-side hitbox query
                -- resolves the target even behind an armour plate.
                Fire("activate_weapon", weapon, aim, 1)
                Fire("activate_weapon", weapon, aim + Vector3.new(0, 3, 0), 1)
                Fire("activate_weapon", weapon, aim - Vector3.new(0, 2, 0), 1)
            else
                Fire("activate_weapon", weapon, aim, 1)
            end
        end
    end

    Every("Combat", function() return math.max(Config.AttackRate, Config.MaxHitRate) end, function()
        local _, root = GetChar()
        if not root then Target = nil return end
        Target = PickTarget(root.Position, Config.AttackRange)
        if not Target then return end
        if (Target.Root.Position - root.Position).Magnitude > Config.AttackRange then return end
        Strike(Target)
    end, function() return Config.KillAura end)

    -- Smooth per-frame target positioning
    local OrbitAngle = 0
    Track(RunService.RenderStepped:Connect(function(dt)
        if not (Config.KillAura and Config.AutoTP) then return end
        local t = Target
        if not t then return end
        if not t.Model.Parent or t.Humanoid.Health <= 0 then Target = nil return end
        local _, root = GetChar()
        if not root or Config.TPMode == "Stay" then return end
        local tPos = t.Root.Position
        local cf
        if Config.TPMode == "Behind" then
            cf = t.Root.CFrame * CFrame.new(0, 0, Config.TPDistance)
        elseif Config.TPMode == "Above" then
            cf = CFrame.new(tPos + Vector3.new(0, Config.TPDistance, 0)) * CFrame.Angles(-math.rad(80), 0, 0)
        elseif Config.TPMode == "Under" then
            cf = CFrame.lookAt(tPos - Vector3.new(0, Config.TPDistance, 0), tPos)
        else
            OrbitAngle = (OrbitAngle + Config.OrbitSpeed * dt) % 360
            local rad = math.rad(OrbitAngle)
            cf = CFrame.lookAt(tPos + Vector3.new(math.cos(rad) * Config.OrbitRadius,
                                                   Config.TPDistance,
                                                   math.sin(rad) * Config.OrbitRadius), tPos)
        end
        root.CFrame = cf
        root.AssemblyLinearVelocity = Vector3.zero
    end))

    local function InRange()
        local _, root = GetChar()
        return root ~= nil and Target ~= nil and Target.Model.Parent ~= nil
            and Target.Humanoid.Health > 0
            and (Target.Root.Position - root.Position).Magnitude <= Config.AttackRange
    end

    Every("Skills", function() return Config.SkillInterval end, function()
        if not InRange() then return end
        Signal("skill_one"); Signal("skill_two")
    end, function() return Config.KillAura and Config.AutoSkills end)

    Every("Dash", function() return Config.DashInterval end, function()
        if not InRange() then return end
        SignalAny("dash", "skill_two", "dodge", "skill_one")
    end, function() return Config.KillAura and Config.AutoDash end)

    -- Potions: keep the configured slot topped up below the threshold.
    local lastPotion = 0
    Every("Potions", 0.3, function()
        local _, _, hum = GetChar()
        if not hum then return end
        local pct = hum.Health / math.max(hum.MaxHealth, 1) * 100
        if pct <= Config.PotionThreshold and os.clock() - lastPotion > 1.2 then
            lastPotion = os.clock()
            Fire("use_potion", Config.AutoPotionSlot)
        end
    end, function() return Config.AutoUsePotions end)
end

------------------------------------------------------------------------
-- NO COOLDOWN  (zero every client-side cooldown attribute we can see)
------------------------------------------------------------------------
do
    local CD_PATTERN = {
        "cooldown", "cooldownend", "cooldown_end", "cooldownstart", "cooldown_start",
        "nextuse", "next_use", "readyat", "ready_at", "lastuse", "last_use",
        "abilitycd", "skillcd", "dashcd", "potioncd", "stamina",
    }
    local function IsCD(name)
        local low = string.lower(name)
        for _, token in ipairs(CD_PATTERN) do
            if string.find(low, token, 1, true) then return true end
        end
        return false
    end

    local lastScan = 0
    Every("NoCooldown", 0.1, function()
        local char = LocalPlayer.Character
        if not char then return end
        -- Fast path: known attributes on the character root.
        for _, root in ipairs({ char:FindFirstChild("HumanoidRootPart"),
                                char:FindFirstChild("Head"),
                                char }) do
            if root then
                local ok, attrs = pcall(function() return root:GetAttributes() end)
                if ok then
                    for name in pairs(attrs) do
                        if IsCD(name) then pcall(function() root:SetAttribute(name, 0) end) end
                    end
                end
            end
        end
        -- Slow path: sweep the whole character once per second.
        if os.clock() - lastScan < 1 then return end
        lastScan = os.clock()
        for _, d in ipairs(char:GetDescendants()) do
            if d:IsA("BasePart") or d:IsA("ObjectValue") or d:IsA("Model") then
                local ok, attrs = pcall(function() return d:GetAttributes() end)
                if ok then
                    for name, v in pairs(attrs) do
                        if IsCD(name) and type(v) == "number" and v > 0 then
                            pcall(function() d:SetAttribute(name, 0) end)
                        end
                    end
                end
            end
        end
    end, function() return Config.NoCooldown end)
end

------------------------------------------------------------------------
-- SURVIVAL:  true immortal / ignore damage
------------------------------------------------------------------------
do
    -- One health listener per humanoid, connected once and never duplicated.
    local watched = setmetatable({}, { __mode = "k" })

    local function Guard(hum)
        if not hum or watched[hum] then return end
        watched[hum] = true
        pcall(function()
            hum:GetPropertyChangedSignal("Health"):Connect(function()
                local active = Config.TrueImmortal or Config.IgnoreDamage
                if not active then return end
                local max = hum.MaxHealth
                if hum.Health < max then hum.Health = max end
            end)
        end)
    end

    local function Unguard(hum)
        if not hum then return end
        watched[hum] = nil
    end

    Track(function() Unguard(GetChar()) end)
    Track(LocalPlayer.CharacterAdded:Connect(function() Unguard(GetChar()) end))

    Every("Survival", 0.1, function()
        local char, _, hum = GetChar()
        if not hum then return end

        local immortal = Config.TrueImmortal
        local nodmg = Config.IgnoreDamage

        if not immortal and not nodmg then
            -- Restore a normal humanoid once.
            if watched[hum] ~= nil then
                Unguard(hum)
                pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, true) end)
                pcall(function() hum.BreakJointsOnDeath = true end)
                if hum.MaxHealth > 1e8 then hum.MaxHealth = 100 end
                if hum.Health > 1e8 then hum.Health = 100 end
            end
            return
        end

        Guard(hum)
        if immortal then
            hum.MaxHealth = math.max(hum.MaxHealth, 1e9)
            hum.Health = hum.MaxHealth
        else
            if hum.MaxHealth > 1e8 then hum.MaxHealth = 100 end
            if hum.Health < hum.MaxHealth then hum.Health = hum.MaxHealth end
        end
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false) end)
        pcall(function() hum.BreakJointsOnDeath = false end)
        pcall(function() hum:SetStateEnabled(Enum.HumanoidStateType.GettingUp, true) end)
        -- An invisible ForceField keeps scripted damage handlers from firing.
        local ff = char:FindFirstChildOfClass("ForceField")
        if not ff then
            ff = Make("ForceField", { Visible = false, Name = "PBH_FF" }, char)
        end
    end)

    -- Cancel the named boss attacks entirely.
    Every("BossDodge", 0.15, function()
        if not (Config.HideFromBosses or Config.IgnoreDamage or Config.TrueImmortal) then return end
        SignalAny("dodge", "skill_two")
        Fire("gatekeeper_beam_dodged")
        Fire("korth_skill_check", true)
        Fire("morvik_bubble_break")
        Fire("enemy_ground_held")
    end, function() return Config.HideFromBosses end)
end

------------------------------------------------------------------------
-- RUNS:  worlds, modes, rooms, quests
------------------------------------------------------------------------
do
    local lastNextRoom, lastContinue, lastLeave = 0, 0, 0
    local roomGate = false

    -- Auto next room. Uses the game's own debug teleport first, then falls
    -- back to a "walk to the door / exit trigger" heuristic.
    Every("NextRoom", function() return math.max(Config.NextRoomDelay, 0.3) end, function()
        if not Config.AutoNextRoom then return end
        if os.clock() - lastNextRoom < 1.2 then return end
        local _, root = GetChar()
        if not root then return end

        -- Preferred: the remote the game itself binds to [ .
        if Fire("debug_teleport_next_room", os.clock()) then
            lastNextRoom = os.clock()
            return
        end

        -- Fallback: look for an exit/door/portal trigger within reach.
        local best, bestD = nil, math.huge
        for _, d in ipairs(workspace:GetDescendants()) do
            if d:IsA("BasePart") and d.Name then
                local low = string.lower(d.Name)
                if string.find(low, "exit", 1, true) or string.find(low, "door", 1, true)
                    or string.find(low, "portal", 1, true) or string.find(low, "next", 1, true) then
                    local dist = (d.Position - root.Position).Magnitude
                    if dist < 220 and dist < bestD then best, bestD = d, dist end
                end
            end
        end
        if best then
            root.CFrame = best.CFrame * CFrame.new(0, 0, -6)
            lastNextRoom = os.clock()
        end
    end, function() return Config.AutoNextRoom end)

    -- The game ships debug shortcuts. When the server allows them these are
    -- the cleanest ways to clear a room or jump straight to the boss.
    local lastDebug = 0
    Every("DebugShortcuts", 3, function()
        if not (Config.AutoBossWave or Config.AutoKillAll or Config.AutoRaid) then return end
        if os.clock() - lastDebug < 2.5 then return end
        lastDebug = os.clock()
        local _, root = GetChar()
        if not root then return end
        if Config.AutoKillAll then Fire("debug_kill_all") end
        if Config.AutoBossWave then Fire("debug_jump_boss_wave") end
        if Config.AutoRaid then Fire("auto_join_raid") end
    end, function() return Config.AutoBossWave or Config.AutoKillAll or Config.AutoRaid end)

    -- Auto continue: vote to continue / accept earnings after a run ends.
    Every("Continue", function() return math.max(Config.ContinueDelay, 1) end, function()
        if not Config.AutoContinue then return end
        if os.clock() - lastContinue < 3 then return end
        lastContinue = os.clock()
        Fire("run_end_vote", 1)          -- vote to continue
        Fire("accept_run_earnings")
        Fire("quest_client_event", "claim")
    end, function() return Config.AutoContinue end)

    -- Leave the run (returns you to the lobby / hub).
    Every("LeaveRun", 5, function()
        if not (Config.AutoLeaveOnQuest or not Config.LeaveAfterQuest) then return end
        if os.clock() - lastLeave < 4 then return end
        lastLeave = os.clock()
        Fire("leave_run")
    end, function() return Config.AutoLeaveOnQuest end)

    -- Start a session: create_play_session(PlaceId, PlaceDifficulty, MaxPlayers)
    local creating = false
    Every("AutoPlay", 3, function()
        if not Config.AutoPlayQuest then return end
        if creating or not Config.AutoAcceptQuest then return end
        creating = true
        local place = EnumId("PlaceId", Config.SelectedWorld, WORLD_IDS[Config.SelectedWorld])
        local diff  = EnumId("PlaceDifficulty", Config.SelectedDifficulty, DIFF_ID[Config.SelectedDifficulty])
        Fire("accept_quest")
        Fire("create_play_session", place, diff, Config.MaxPlayers)
        task.delay(2, function() creating = false end)
    end, function() return Config.AutoPlayQuest end)

    -- Accept any pending quest when the dialogue prompt appears.
    Every("AutoAccept", 1.5, function()
        if not Config.AutoAcceptQuest then return end
        Fire("accept_quest")
        Fire("npc_dialogue", "accept")
        Fire("quest_client_event", "accept")
    end, function() return Config.AutoAcceptQuest end)

    -- Charm card is chosen right before a run begins.
    Every("CharmCard", 0.5, function()
        if not Config.AutoCharmCard then return end
        Fire("pick_charm_card", Config.CharmCardIndex)
    end, function() return Config.AutoCharmCard end)

    Every("Misc1", 1.5, function()
        if Config.AutoRevive then
            Fire("request_revive")
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then Fire("rescue_fallen", p.UserId) end
            end
        end
    end, function() return Config.AutoRevive end)

    Every("Misc2", 1.0, function()
        if Config.AutoSkipCutscene then Fire("skip_cutscene") end
    end, function() return Config.AutoSkipCutscene end)

    Every("Daily", 2.0, function()
        if not Config.AutoDaily then return end
        Fire("claim_daily_reward")
        Fire("claim_code", "PIXELBLADE")
        Fire("claim_code", "FREEBLADE")
    end, function() return Config.AutoDaily or Config.AutoCodes end)
end

------------------------------------------------------------------------
-- LOOT / WORLD INTERACTION
------------------------------------------------------------------------
do
    Every("Drops", 0.25, function()
        local _, root = GetChar()
        if not root then return end
        for _, drop in ipairs(World.Drops) do
            if drop.Parent and (drop.Position - root.Position).Magnitude <= Config.CollectRange then
                drop.CFrame = root.CFrame
                drop.AssemblyLinearVelocity = Vector3.zero
            end
        end
    end, function() return Config.AutoCollectDrops end)

    Every("DestroyProps", 0.35, function()
        local _, root = GetChar()
        if not root then return end
        for _, e in ipairs(World.Enemies) do
            -- "Also destroy other stuff in the map": non-boss scenery that
            -- counts as a destructible/breakable target.
            if not e.Boss and (e.Model.Parent)
                and (e.Root.Position - root.Position).Magnitude <= 60 then
                local hum = e.Humanoid
                hum.Health = 0
                pcall(function() hum:ChangeState(Enum.HumanoidStateType.Dead) end)
            end
        end
    end, function() return Config.DestroyProps end)

    local ChestCD = setmetatable({}, { __mode = "k" })
    Every("ChestPrompts", 0.5, function()
        if not Config.AutoPrompts then return end
        if type(fireproximityprompt) ~= "function" then return end
        local _, root = GetChar()
        if not root then return end
        local now = os.clock()
        for prompt in pairs(Prompts) do
            if prompt.Parent and prompt.Enabled and IsChestPrompt(prompt)
                and (ChestCD[prompt] or 0) < now then
                local pos = PromptPos(prompt)
                if pos and (pos - root.Position).Magnitude <= Config.PromptRange then
                    ChestCD[prompt] = now + 1.5
                    pcall(fireproximityprompt, prompt)
                end
            end
        end
    end, function() return Config.AutoPrompts end)

    Every("OpenChests", 2.5, function()
        local list = CHEST_SETS[Config.OpenChestSet] or CHEST_SETS.All
        for _, id in ipairs(list) do
            if not Config.AutoOpenChests or not Running then return end
            Fire("open_chest", EnumId("ChestId", id, id), Config.OpenChestBulk)
            task.wait(0.08)
        end
    end, function() return Config.AutoOpenChests end)

    Every("DarkChest", 1.5, function()
        Fire("open_dark_chest")
    end, function() return Config.AutoDarkChest end)

    -- Puzzle / parkour / soul-tree pickups.
    Every("Interactables", 0.7, function()
        Fire("claim_soul_tree_rose")
        Fire("claim_puzzle_key")
        Fire("open_puzzle_door")
        Fire("pull_puzzle_lever")
        Fire("claim_puzzle_chest")
        Fire("solve_parkour_vault")
        Fire("claim_parkour_chest")
        Fire("open_parkour_gate")
        Fire("press_door_button")
        Fire("collect_drop")
        Fire("collect_spirit")
    end, function() return Config.AutoCollectDrops end)
end

------------------------------------------------------------------------
-- FISHING
------------------------------------------------------------------------
do
    local fishingBusy = false
    local autoSelling = false
    local stashCount = 0

    -- Count real catches the server reports, then auto-sell at the limit.
    local function AutoSell()
        if autoSelling then return end
        autoSelling = true
        task.spawn(function()
            for _, f in ipairs(FISH) do
                if GetConfig("SellFishes." .. f.id) then
                    Fire("sell_fish_catch", EnumId("FishingCatchId", f.id, f.id))
                    task.wait(0.06)
                end
            end
            if Config.SellCharms then
                Fire("sell_fish_charm", EnumId("CharmId", Config.SellCharmTier, Config.SellCharmTier))
            end
            if Config.AutoUpgradeStash then Fire("upgrade_fishing_stash") end
            stashCount = 0
            autoSelling = false
        end)
    end

    Every("FishingStash", 0.5, function()
        if not Config.AutoSellFish then return end
        if stashCount < Config.SellThreshold then return end
        AutoSell()
    end, function() return Config.AutoSellFish end)

    Every("Fishing", 0.5, function()
        if fishingBusy then return end
        fishingBusy = true
        task.spawn(function()
            local ok, err = pcall(function()
                local _, root = GetChar()
                if not root then return end

                if Config.AutoBait then
                    Fire("equip_fishing_bait", EnumId("BaitId", Config.BaitSelect, Config.BaitSelect))
                end

                -- Cast straight ahead.
                Fire("fishing_cast", root.Position + root.CFrame.LookVector * 16)
                task.wait(Config.FastReel and Config.ReelDelay or 1.6)

                -- Start reeling.
                Fire("fishing_reel", true)

                -- Land. The server grades the catch from the timing of this
                -- call, so fire a short burst to land inside the perfect window.
                task.wait(Config.LandDelay)
                local burst = math.max(1, Config.LandBurst)
                for i = 1, burst do
                    if not Config.AutoFish or not Running then break end
                    Fire("fishing_landed", os.clock())
                    task.wait(0.045)
                end

                -- Sell when the stash reaches the configured limit.
                if Config.AutoSellFish and stashCount >= Config.SellThreshold then AutoSell() end
            end)
            if not ok then warn("[PixelBlade] fishing: " .. tostring(err)) end
            task.wait(Config.FastReel and 1.2 or 2.4)
            fishingBusy = false
        end)
    end, function() return Config.AutoFish end)

    -- Watch the server's own catch notifications so the stash counter is real.
    task.spawn(function()
        local net = NetworkRemotes
        if not net then return end
        for _, evName in ipairs({ "fishing_caught_item", "fishing_caught_charm",
                                  "fishing_caught_wish" }) do
            local ev = net:FindFirstChild(evName)
            if ev and ev:IsA("RemoteEvent") then
                Track(ev.OnClientEvent:Connect(function() stashCount = stashCount + 1 end))
            end
        end
    end)

    Every("RodToggle", 0.5, function()
        Fire("toggle_rod", true)
    end, function() return Config.AutoFish end)
end

------------------------------------------------------------------------
-- INVENTORY  (upgrade / equip / item list)
------------------------------------------------------------------------
do
    local upgrading = false

    Every("AutoUpgrade", 2.0, function()
        if not Config.AutoUpgrade or upgrading then return end
        local char = LocalPlayer.Character
        if not char then return end
        upgrading = true
        task.spawn(function()
            local function tierOf(tool)
                for _, attr in ipairs({ "tier", "Tier", "stars", "Stars" }) do
                    local v = tool:GetAttribute(attr)
                    if type(v) == "number" then return v end
                end
                return nil
            end
            for _, holder in ipairs({ char:FindFirstChild("Weapon"), char:FindFirstChildOfClass("Model") }) do
                if holder then
                    for _, tool in ipairs(holder:GetChildren()) do
                        if tool:IsA("Tool") then
                            local t = tierOf(tool)
                            local atCap = (t ~= nil and t >= Config.MaxUpgradeTier)
                            if not atCap then
                                Fire("equip_item", tool)
                                task.wait(0.15)
                                for _ = 1, math.max(1, Config.UpgradeCopies) do
                                    if Config.AutoEquipBest then Fire("equip_item", tool) end
                                    Fire("upgrade_item", tool)
                                    task.wait(0.12)
                                end
                            end
                        end
                    end
                end
            end
            if Config.AutoEquipBest then Fire("equip_item", char) end
            upgrading = false
        end)
    end, function() return Config.AutoUpgrade end)

    Every("AutoClaim", 2.0, function()
        Fire("claim_achievement")
    end, function() return Config.AutoClaims end)
end

-- Item list: scrape the game's own Armory screen for what you actually own.
local Inventory = { rows = {}, scannedAt = 0, available = false }

local function ScrapeArmory()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return false end
    local best = nil
    for _, c in ipairs(pg:GetChildren()) do
        if c:IsA("ScreenGui") then
            local low = string.lower(c.Name)
            if string.find(low, "armory", 1, true) or string.find(low, "inventory", 1, true) then
                best = c
            end
        end
    end
    if not best then return false end

    local rows, seen = {}, setmetatable({}, { __mode = "k" })
    local stack = { best }
    while #stack > 0 do
        local node = table.remove(stack)
        if (node:IsA("TextLabel") or node:IsA("TextButton")) and not seen[node] then
            seen[node] = true
            local txt = node.Text
            if type(txt) == "string" then
                local clean = string.gsub(txt, "<[^>]->", "")
                clean = string.gsub(clean, "^%s*(.-)%s*$", "%1")
                if #clean > 1 then
                    rows[#rows + 1] = {
                        text = clean,
                        copies = node:GetAttribute("copies") or node:GetAttribute("count"),
                        tier = node:GetAttribute("tier"),
                        rarity = node:GetAttribute("rarity"),
                    }
                end
            end
        end
        for _, c in ipairs(node:GetChildren()) do stack[#stack + 1] = c end
    end
    Inventory.rows = rows
    Inventory.scannedAt = os.clock()
    Inventory.available = #rows > 0
    return Inventory.available
end

-- Refresh the live list whenever the Inventory tab is being looked at.
Every("ArmoryScan", 1.5, function() ScrapeArmory() end, function()
    return MenuOpen and CurrentTab == "Inventory"
end)

local InventoryStatusLabel = nil
function UI.RefreshInventory()
    ScrapeArmory()
    if not InventoryStatusLabel then return end
    if Inventory.available then
        InventoryStatusLabel.Text = string.format(
            "<font color='#34d399'>live</font>  -  %d rows read from the Armory  -  " ..
            "%dx copies pending upgrade per item", #Inventory.rows, Config.UpgradeCopies)
    else
        InventoryStatusLabel.Text = "<font color='#fb923c'>static</font>  -  open the Armory in game to read live counts"
    end
end

------------------------------------------------------------------------
-- PLAYER MOVEMENT
------------------------------------------------------------------------
do
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
            if hum then pcall(function() hum.WalkSpeed = OrigWS end) end
            OrigWS = nil
        end
    end))
    Track(function()
        local _, _, hum = GetChar()
        if hum and OrigWS then pcall(function() hum.WalkSpeed = OrigWS end) end
    end)

    -- Noclip
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

    -- Fly (keyboard + mobile stick)
    local FlyBV, FlyBG
    local function StopFly()
        if FlyBV then pcall(function() FlyBV:Destroy() end) FlyBV = nil end
        if FlyBG then pcall(function() FlyBG:Destroy() end) FlyBG = nil end
    end
    Track(StopFly)
    Track(RunService.RenderStepped:Connect(function()
        if not Config.FlyEnabled then
            if FlyBV then StopFly() end
            return
        end
        local _, root, hum = GetChar()
        local cam = workspace.CurrentCamera
        if not root or not hum or not cam then StopFly() return end
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
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
            or UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
            vec = vec - Vector3.new(0, 1, 0)
        end
        if vec.Magnitude > 1 then vec = vec.Unit end
        FlyBV.Velocity = vec * Config.FlySpeed
    end))

    -- Infinite jump
    Track(UserInputService.JumpRequest:Connect(function()
        if not Config.InfJump then return end
        local _, _, hum = GetChar()
        if hum then pcall(function() hum:ChangeState(Enum.HumanoidStateType.Jumping) end) end
    end))

    -- Fullbright / no fog
    local LightOrig
    local LIGHT_PROPS = { "Brightness", "ClockTime", "FogEnd", "FogStart",
                           "GlobalShadows", "Ambient", "OutdoorAmbient" }
    local function RestoreLighting()
        if LightOrig then
            for k, v in pairs(LightOrig) do pcall(function() Lighting[k] = v end) end
            LightOrig = nil
        end
    end
    Track(RestoreLighting)
    Track(RunService.Heartbeat:Connect(function()
        if Config.Fullbright or Config.NoFog then
            if not LightOrig then
                LightOrig = {}
                for _, k in ipairs(LIGHT_PROPS) do LightOrig[k] = Lighting[k] end
            end
            if Config.Fullbright then
                Lighting.Brightness = 2
                Lighting.ClockTime = 14
                Lighting.GlobalShadows = false
                Lighting.Ambient = Color3.fromRGB(200, 200, 200)
                Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
            end
            if Config.NoFog then
                Lighting.FogEnd = 100000
                Lighting.FogStart = -100000
            end
        elseif LightOrig then
            RestoreLighting()
        end
    end))

    -- Anti-AFK
    Track(LocalPlayer.Idled:Connect(function()
        if not Config.AntiAFK then return end
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end)
    end))
end

------------------------------------------------------------------------
-- VISUALS  (ESP + tracers)
------------------------------------------------------------------------
do
    local EnemyMarks, ChestMarks, DropMarks = {}, {}, {}

    local function Sync(pool, wanted, create, update)
        for key, mark in pairs(pool) do
            if not wanted[key] or not mark.Parent then
                pcall(function() mark:Destroy() end)
                pool[key] = nil
            end
        end
        for key, data in pairs(wanted) do
            local mark = pool[key]
            if not mark then mark = create(key, data); pool[key] = mark end
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
            Size = UDim2.fromOffset(width, 18), StudsOffset = Vector3.new(0, 2.6, 0),
        }, ScreenGui)
        Make("TextLabel", {
            Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
            Font = Enum.Font.GothamBold, TextSize = 12, TextColor3 = color,
            TextStrokeTransparency = 0.4, Text = "",
        }, gui)
        return gui
    end

    Every("ESP", 0.3, function()
        local _, root = GetChar()
        local cam = workspace.CurrentCamera
        local origin = (root and root.Position) or (cam and cam.CFrame.Position)
        if not origin then return end
        local range = Config.ESPRange

        -- Enemies / bosses (Highlight is capped at 31 instances)
        local wanted = {}
        if Config.EnemyESP or Config.BossESP then
            local list = {}
            for _, e in ipairs(World.Enemies) do
                if e.Model.Parent and e.Humanoid.Health > 0 then
                    if (e.Boss and Config.BossESP) or (not e.Boss and Config.EnemyESP) then
                        local d = (e.Root.Position - origin).Magnitude
                        if d <= range then list[#list + 1] = { key = e.Model, d = d, boss = e.Boss } end
                    end
                end
            end
            wanted = TopN(list, 30)
        end
        Sync(EnemyMarks, wanted, function(model)
            return Make("Highlight", {
                Name = "PBH_ESP", Adornee = model,
                FillColor = Color3.fromRGB(239, 68, 68), OutlineColor = Color3.new(1, 1, 1),
                FillTransparency = 0.55, OutlineTransparency = 0,
                DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
            }, ScreenGui)
        end, function(mark, data)
            if data.boss then
                mark.FillColor = Color3.fromRGB(249, 115, 22)
            else
                mark.FillColor = Color3.fromRGB(239, 68, 68)
            end
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
        Sync(ChestMarks, wanted, function(_, data)
            return MakeTag(data.part, Color3.fromRGB(250, 204, 21), 118)
        end, function(mark, data)
            local txt = "CHEST  " .. math.floor(data.d) .. "m"
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
        Sync(DropMarks, wanted, function(drop)
            local m = MakeTag(drop, Color3.fromRGB(52, 211, 153), 22)
            m.L.Text = "<>"
            return m
        end)
    end, function() return Config.EnemyESP or Config.BossESP or Config.ChestESP or Config.DropESP end)

    Track(function()
        for _, pool in ipairs({ EnemyMarks, ChestMarks, DropMarks }) do
            for _, mark in pairs(pool) do pcall(function() mark:Destroy() end) end
        end
    end)

    -- Tracers (executor Drawing API)
    local okD, drawingNew = pcall(function() return Drawing.new end)
    local HasDrawing = okD and drawingNew ~= nil
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
        local origin = (root and root.Position) or cam.CFrame.Position
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
                            ln.Thickness = 1.5; ln.Transparency = 1
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
local HasFS = (type(writefile) == "function" and type(readfile) == "function"
                and type(isfile) == "function")

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
        if isfile(CONFIG_FILE) then return HttpService:JSONDecode(readfile(CONFIG_FILE)) end
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
    if Dirty then Dirty = false; SaveConfig() end
end, function() return Config.AutoSave and HasFS end)

------------------------------------------------------------------------
-- UI FRAMEWORK
------------------------------------------------------------------------
local Theme = {
    Bg = Color3.fromRGB(12, 13, 19), Header = Color3.fromRGB(17, 19, 28),
    Sidebar = Color3.fromRGB(15, 17, 24), Card = Color3.fromRGB(19, 22, 31),
    CardHover = Color3.fromRGB(27, 31, 44), Stroke = Color3.fromRGB(32, 37, 52),
    Off = Color3.fromRGB(40, 45, 62), Text = Color3.fromRGB(225, 229, 240),
    Sub = Color3.fromRGB(135, 141, 165), Good = Color3.fromRGB(52, 211, 153),
    Warn = Color3.fromRGB(251, 146, 60),
}
local Accents = {
    Purple = Color3.fromRGB(139, 92, 246), Blue  = Color3.fromRGB(59, 130, 246),
    Green  = Color3.fromRGB(16, 185, 129),  Red   = Color3.fromRGB(244, 63, 94),
    Orange = Color3.fromRGB(249, 115, 22),  Cyan  = Color3.fromRGB(6, 182, 212),
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
    pcall(function()
        TweenService:Create(obj, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            props):Play()
    end)
end
local function Round(o, r) return Make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function Outline(o, color, thick)
    return Make("UIStroke", {
        Color = color or Theme.Stroke, Thickness = thick or 1,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, o)
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

-- Window
local function WindowSize()
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    return UDim2.fromOffset(math.clamp(vp.X - 24, 380, 660),
                            math.clamp(vp.Y - 24, 300, 460))
end

local Window = Make("CanvasGroup", {
    AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
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
        task.delay(0.13, function() if not MenuOpen then Window.Visible = false end end)
    end
end

-- Header
local Header = Make("Frame", {
    Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = Theme.Header, BorderSizePixel = 0,
}, Window)
Make("Frame", {
    Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = Theme.Stroke, BorderSizePixel = 0,
}, Header)
Label(Header, {
    Text = "PIXEL BLADE HUB  <font color='#a78bfa'>v" .. VERSION .. "</font>",
    RichText = true, Font = Enum.Font.GothamBold, TextSize = 15,
    Size = UDim2.new(0, 220, 1, 0), Position = UDim2.new(0, 16, 0, 0),
})
local StatsLabel = Label(Header, {
    Text = "-- FPS", TextXAlignment = Enum.TextXAlignment.Right, TextSize = 11,
    TextColor3 = Theme.Sub, Size = UDim2.new(0, 150, 1, 0),
    Position = UDim2.new(1, -198, 0, 0),
})
local CloseBtn = Make("TextButton", {
    Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -40, 0.5, -16),
    BackgroundTransparency = 1, Text = "X", Font = Enum.Font.GothamBold,
    TextSize = 15, TextColor3 = Theme.Sub,
}, Header)
CloseBtn.MouseButton1Click:Connect(function() SetMenu(false) end)

-- Dragging
do
    local dragging, moved, dragStart, startPos = false, false, nil, nil
    Header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            dragStart, startPos = input.Position, Window.Position
            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    conn:Disconnect()
                end
            end)
        end
    end)
    Track(UserInputService.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = input.Position - dragStart
            if d.Magnitude > 5 then moved = true end
            if moved then
                Window.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X,
                                            startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end
    end))
end

-- Sidebar / content
local Sidebar = Make("Frame", {
    Size = UDim2.new(0, 142, 1, -46), Position = UDim2.new(0, 0, 0, 46),
    BackgroundColor3 = Theme.Sidebar, BorderSizePixel = 0,
}, Window)
Make("UIListLayout", {
    Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Center,
    SortOrder = Enum.SortOrder.LayoutOrder,
}, Sidebar)
Make("UIPadding", { PaddingTop = UDim.new(0, 8) }, Sidebar)
Label(Window, {
    Text = "RightShift to toggle  -  unload by re-running",
    TextSize = 10, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Center,
    Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -22),
})

local Content = Make("Frame", {
    Size = UDim2.new(1, -154, 1, -58), Position = UDim2.new(0, 148, 0, 52),
    BackgroundTransparency = 1,
}, Window)
local SearchBox = Make("TextBox", {
    Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = Theme.Card, BorderSizePixel = 0,
    PlaceholderText = "Search settings...", PlaceholderColor3 = Theme.Sub,
    Text = "", ClearTextOnFocus = false, Font = Enum.Font.GothamMedium, TextSize = 12,
    TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Left,
}, Content)
Round(SearchBox, 8); Outline(SearchBox)
Make("UIPadding", { PaddingLeft = UDim.new(0, 10) }, SearchBox)
local PageHolder = Make("Frame", {
    Size = UDim2.new(1, 0, 1, -36), Position = UDim2.new(0, 0, 0, 36),
    BackgroundTransparency = 1, ClipsDescendants = true,
}, Content)

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
        Tween(t.Button, 0.15, {
            BackgroundTransparency = on and 0 or 1,
            TextColor3 = on and Accent() or Theme.Sub,
        })
    end
    ApplySearch()
end
AccentCallbacks[#AccentCallbacks + 1] = function()
    local t = Tabs[CurrentTab]
    if t then t.Button.TextColor3 = Accent() end
end

local function CreateTab(name)
    TabOrder = TabOrder + 1
    local btn = Make("TextButton", {
        Size = UDim2.new(1, -12, 0, 34), BackgroundColor3 = Theme.Card,
        BackgroundTransparency = 1, BorderSizePixel = 0, AutoButtonColor = false,
        Text = name, Font = Enum.Font.GothamMedium, TextSize = 13,
        TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = TabOrder,
    }, Sidebar)
    Round(btn, 8)
    Make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, btn)
    local ind = Make("Frame", {
        Size = UDim2.fromOffset(3, 16), Position = UDim2.new(0, -14, 0.5, -8),
        BorderSizePixel = 0, Visible = false,
    }, btn)
    Bind(ind, "BackgroundColor3"); Round(ind, 2)

    local page = Make("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
        ElasticBehavior = Enum.ElasticBehavior.Never, Visible = false,
    }, PageHolder)
    Bind(page, "ScrollBarImageColor3")
    Make("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, page)
    Make("UIPadding", {
        PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 10),
        PaddingRight = UDim.new(0, 8),
    }, page)

    btn.MouseButton1Click:Connect(function() SelectTab(name) end)
    Tabs[name] = { Button = btn, Indicator = ind }
    Pages[name] = page
    return page
end

-- Components
local Listening = nil
local function NextOrder(page)
    Orders[page] = (Orders[page] or 0) + 1
    return Orders[page]
end

local function Card(page, height, searchText)
    local c = Make("Frame", {
        Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = NextOrder(page),
    }, page)
    Round(c, 8); Outline(c)
    c:SetAttribute("Search", string.lower(searchText or ""))
    return c
end

function UI.Section(page, title)
    local l = Label(page, {
        Text = string.upper(title), Font = Enum.Font.GothamBold, TextSize = 11,
        Size = UDim2.new(1, 0, 0, 22), LayoutOrder = NextOrder(page),
    })
    Bind(l, "TextColor3")
    l:SetAttribute("Section", true)
    return l
end

function UI.Toggle(page, title, key, onChange, desc)
    local c = Card(page, desc and 54 or 40, title .. " " .. (desc or ""))
    Label(c, {
        Text = title, Size = UDim2.new(1, -72, 0, desc and 20 or 40),
        Position = UDim2.new(0, 12, 0, desc and 8 or 0),
    })
    if desc then
        Label(c, {
            Text = desc, TextSize = 11, TextColor3 = Theme.Sub,
            Size = UDim2.new(1, -72, 0, 16), Position = UDim2.new(0, 12, 0, 28),
        })
    end
    local sw = Make("Frame", {
        Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -52, 0.5, -11),
        BackgroundColor3 = Theme.Off, BorderSizePixel = 0,
    }, c)
    Round(sw, 11)
    local knob = Make("Frame", {
        Size = UDim2.fromOffset(16, 16), Position = UDim2.new(0, 3, 0.5, -8),
        BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
    }, sw)
    Round(knob, 8)
    local hit = Make("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        ZIndex = 5, AutoButtonColor = false,
    }, c)

    local function Render(animate)
        local on = GetConfig(key)
        local col = on and Accent() or Theme.Off
        local pos = on and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        if animate then
            Tween(sw, 0.16, { BackgroundColor3 = col }); Tween(knob, 0.16, { Position = pos })
        else
            sw.BackgroundColor3 = col; knob.Position = pos
        end
    end
    local function Set(v, silent)
        SetConfig(key, v)
        Render(true)
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end
    hit.MouseButton1Click:Connect(function() Set(not GetConfig(key)) end)
    hit.MouseEnter:Connect(function() c.BackgroundColor3 = Theme.CardHover end)
    hit.MouseLeave:Connect(function() c.BackgroundColor3 = Theme.Card end)
    Controls[key] = { Set = Set }
    AccentCallbacks[#AccentCallbacks + 1] = function() Render(false) end
    Render(false)
    return c
end

function UI.Slider(page, title, key, minV, maxV, decimals, suffix, onChange)
    decimals, suffix = decimals or 0, suffix or ""
    local c = Card(page, 54, title)
    Label(c, {
        Text = title, Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.new(0, 12, 0, 6),
    })
    local val = Label(c, {
        Size = UDim2.new(0.4, -12, 0, 22), Position = UDim2.new(0.6, 0, 0, 6),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 12,
    })
    Bind(val, "TextColor3")
    local hit = Make("TextButton", {
        Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 12, 0, 28),
        BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
    }, c)
    local bar = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 6), Position = UDim2.new(0, 0, 0.5, -3),
        BackgroundColor3 = Theme.Off, BorderSizePixel = 0,
    }, hit)
    Round(bar, 3)
    local fill = Make("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0 }, bar)
    Bind(fill, "BackgroundColor3"); Round(fill, 3)

    local mult = 10 ^ decimals
    local fmt = "%." .. decimals .. "f"
    local function Render()
        local v = GetConfig(key)
        val.Text = string.format(fmt, v) .. suffix
        fill.Size = UDim2.fromScale(math.clamp((v - minV) / (maxV - minV), 0, 1), 1)
    end
    local function Set(v, silent)
        SetConfig(key, v)
        Render()
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end
    hit.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
            and input.UserInputType ~= Enum.UserInputType.Touch then return end
        Listening = true
        local startX, startV = input.Position.X, Config[key]
        local conn
        conn = UserInputService.InputChanged:Connect(function(i2)
            if not Listening then conn:Disconnect() return end
            if i2.UserInputType == Enum.UserInputType.MouseMovement
                or i2.UserInputType == Enum.UserInputType.Touch then
                local delta = (i2.Position.X - startX) / 180
                Set(math.clamp(startV + delta * (maxV - minV), minV, maxV), true)
            end
        end)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                Listening = false
                conn:Disconnect()
            end
        end)
    end)
    Controls[key] = { Set = Set }
    AccentCallbacks[#AccentCallbacks + 1] = function() Render() end
    Render()
    return c
end

local DropdownOpen = nil
local OpenLists = {}

local function CloseAllDropdowns()
    for _, l in pairs(OpenLists) do
        if l and l.Parent then l.Visible = false end
    end
    DropdownOpen = nil
end

function UI.Dropdown(page, title, key, options, onChange)
    local c = Card(page, 44, title)
    Label(c, {
        Text = title, Size = UDim2.new(0.55, 0, 0, 44), Position = UDim2.new(0, 12, 0, 0),
    })
    local display = Label(c, {
        Size = UDim2.new(0.45, -24, 0, 44), Position = UDim2.new(0.55, 0, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextSize = 12,
    })
    Bind(display, "TextColor3")
    Label(c, {
        Text = "v", Size = UDim2.fromOffset(14, 44), Position = UDim2.new(1, -22, 0, 0),
        TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = Theme.Sub, TextSize = 12,
    })
    local list = Make("Frame", {
        Size = UDim2.new(0.55, -6, 0, math.min(#options, 6) * 22 + 4),
        Position = UDim2.new(0.45, 0, 1, 4), BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0, Visible = false, ClipsDescendants = true,
    }, c)
    Round(list, 8); Outline(list)
    Make("UIListLayout", { Padding = UDim.new(0, 2) }, list)
    Make("UIPadding", { PaddingTop = UDim.new(0, 2) }, list)
    OpenLists[list] = true

    local function Render()
        local v = GetConfig(key)
        display.Text = tostring(v)
    end
    local function Set(v, silent)
        SetConfig(key, v)
        Render()
        if not silent and onChange then onChange(v) end
        MarkDirty()
    end

    for i, opt in ipairs(options) do
        local b = Make("TextButton", {
            Size = UDim2.new(1, -6, 0, 20), BackgroundTransparency = 1,
            Text = tostring(opt), Font = Enum.Font.GothamMedium, TextSize = 12,
            TextColor3 = Theme.Text, TextXAlignment = Enum.TextXAlignment.Center,
            LayoutOrder = i, AutoButtonColor = false,
        }, list)
        b.MouseButton1Click:Connect(function()
            Set(opt)
            CloseAllDropdowns()
        end)
        b.MouseEnter:Connect(function() b.BackgroundColor3 = Theme.CardHover end)
        b.MouseLeave:Connect(function() b.BackgroundTransparency = 1 end)
    end

    local hit = Make("TextButton", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "",
        ZIndex = 5, AutoButtonColor = false,
    }, c)
    hit.MouseButton1Click:Connect(function()
        if DropdownOpen == list then
            CloseAllDropdowns()
        else
            CloseAllDropdowns()
            list.Visible = true
            DropdownOpen = list
        end
    end)

    Controls[key] = { Set = Set }
    AccentCallbacks[#AccentCallbacks + 1] = function() Render() end
    Render()
    return c
end

function UI.Info(page, text)
    local c = Card(page, 34, text)
    local l = Label(c, {
        Text = text, TextSize = 11, TextColor3 = Theme.Sub, RichText = true,
        Size = UDim2.new(1, -16, 1, 0), Position = UDim2.new(0, 8, 0, 0),
        TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top,
    })
    return c
end

-- Notifications
do
    local NHolder = Make("Frame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
    }, ScreenGui)
    local NList = Make("UIListLayout", {
        Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right,
        VerticalAlignment = Enum.VerticalAlignment.Top, SortOrder = Enum.SortOrder.LayoutOrder,
    }, NHolder)
    Make("UIPadding", { PaddingRight = UDim.new(0, 14), PaddingTop = UDim.new(0, 14) }, NHolder)
    local order = 0

    function UI.Notify(title, body, dur)
        if not title then return end
        order = order + 1
        local f = Make("Frame", {
            Size = UDim2.fromOffset(250, 46), BackgroundColor3 = Theme.Header,
            BorderSizePixel = 0, LayoutOrder = order, BackgroundTransparency = 1,
        }, NHolder)
        Round(f, 8); Outline(f, Accent(), 1)
        Make("TextLabel", {
            Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 6),
            BackgroundTransparency = 1, Text = tostring(title), Font = Enum.Font.GothamBold,
            TextSize = 12, TextColor3 = Accent(), TextXAlignment = Enum.TextXAlignment.Left,
        }, f)
        Make("TextLabel", {
            Size = UDim2.new(1, -16, 0, 16), Position = UDim2.new(0, 8, 0, 24),
            BackgroundTransparency = 1, Text = tostring(body or ""), Font = Enum.Font.Gotham,
            TextSize = 11, TextColor3 = Theme.Sub, TextXAlignment = Enum.TextXAlignment.Left,
            TextTruncate = Enum.TextTruncate.AtEnd,
        }, f)
        task.spawn(function()
            Tween(f, 0.2, { BackgroundTransparency = 0 })
            task.wait((dur or 3) - 0.2)
            Tween(f, 0.25, { BackgroundTransparency = 1 })
            task.wait(0.3)
            pcall(function() f:Destroy() end)
        end)
    end
end

function UI.SetStats(fps)
    if StatsLabel then StatsLabel.Text = string.format("%d FPS", fps) end
end

-- Menu key
do
    Track(UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        local want = Config.MenuKey
        local mapped = (Enum.KeyCode[want] or Enum.KeyCode.RightShift).Name
        if input.KeyCode.Name == mapped then SetMenu(not MenuOpen) end
    end))
end

------------------------------------------------------------------------
-- TAB: COMBAT
------------------------------------------------------------------------
do
    local p = CreateTab("Combat")

    UI.Section(p, "Damage")
    UI.Toggle(p, "Kill Aura", "KillAura", nil, "Auto-attacks the nearest valid target")
    UI.Dropdown(p, "Target priority", "TargetPriority",
        { "Closest", "LowestHP", "BossFirst" })
    UI.Slider(p, "Attack rate (s)", "AttackRate", 0.03, 1.0, 2, "s")
    UI.Slider(p, "Attack range", "AttackRange", 10, 200, 0, " studs")
    UI.Dropdown(p, "Attack method", "AttackMethod", { "Both", "Input", "Remote" })
    UI.Toggle(p, "Lock target", "LockTarget", nil, "Stick to the same enemy")

    UI.Section(p, "Abilities")
    UI.Toggle(p, "Auto skills", "AutoSkills", nil, "Fires skill_one + skill_two in range")
    UI.Slider(p, "Skill interval (s)", "SkillInterval", 0.1, 3, 2, "s")
    UI.Toggle(p, "Auto dash / dodge", "AutoDash", nil, "Uses dash off cooldown")
    UI.Slider(p, "Dash interval (s)", "DashInterval", 0.3, 5, 2, "s")
    UI.Toggle(p, "Infinite cooldowns", "NoCooldown", nil,
        "Zeros client cooldown attributes every 0.1s")
    UI.Toggle(p, "Ignore armor", "IgnoreArmor", nil,
        "Multi-sweep hit points so armour plates do not block")

    UI.Section(p, "Survival")
    UI.Toggle(p, "TRUE IMMORTAL", "TrueImmortal", nil,
        "Max health to 1e9, dead state disabled")
    UI.Toggle(p, "Ignore damage", "IgnoreDamage", nil,
        "Health pinned to max, no death")
    UI.Toggle(p, "Dodge boss attacks", "HideFromBosses", nil,
        "Signals the beam/bubble/parry beats")
    UI.Slider(p, "Potion health %", "PotionThreshold", 0, 100, 0, "%")
    UI.Slider(p, "Potion slot", "AutoPotionSlot", 1, 4, 0, "")

    UI.Section(p, "Target position")
    UI.Toggle(p, "Auto teleport to target", "AutoTP", nil, "Orbit / behind / above")
    UI.Dropdown(p, "Position mode", "TPMode",
        { "Orbit", "Behind", "Above", "Under", "Stay" })
    UI.Slider(p, "Height offset", "TPDistance", 2, 60, 0, " studs")
    UI.Slider(p, "Orbit radius", "OrbitRadius", 5, 80, 0, " studs")
    UI.Slider(p, "Orbit speed", "OrbitSpeed", 20, 600, 0, "")
end

------------------------------------------------------------------------
-- TAB: RUNS
------------------------------------------------------------------------
do
    local p = CreateTab("Runs")

    UI.Section(p, "World selection")
    local worldOpts = {}
    for _, w in ipairs(WORLDS) do worldOpts[#worldOpts + 1] = w.id end
    UI.Dropdown(p, "World", "SelectedWorld", worldOpts, function() MarkDirty() end)
    UI.Dropdown(p, "Difficulty", "SelectedDifficulty", DIFFICULTIES)
    UI.Slider(p, "Max players", "MaxPlayers", 1, 8, 0, "")

    UI.Section(p, "Progression")
    UI.Toggle(p, "Auto next room", "AutoNextRoom", nil,
        "Uses debug_teleport_next_room, falls back to door seek")
    UI.Slider(p, "Next room delay (s)", "NextRoomDelay", 0.2, 5, 1, "s")
    UI.Toggle(p, "Jump to boss wave", "AutoBossWave", nil,
        "debug_jump_boss_wave")
    UI.Toggle(p, "Kill everything", "AutoKillAll", nil,
        "debug_kill_all - clears the room")
    UI.Toggle(p, "Auto join raid", "AutoRaid", nil, "auto_join_raid")
    UI.Toggle(p, "Auto continue", "AutoContinue", nil,
        "Votes continue + accepts earnings")
    UI.Slider(p, "Continue delay (s)", "ContinueDelay", 1, 15, 1, "s")
    UI.Toggle(p, "Leave when quest done", "AutoLeaveOnQuest", nil,
        "Fires leave_run after the run")
    UI.Toggle(p, "Auto accept quest", "AutoAcceptQuest", nil,
        "Accepts pending quest dialogue")
    UI.Toggle(p, "Auto play / join quest", "AutoPlayQuest", nil,
        "create_play_session with the selected world + mode")
    UI.Toggle(p, "Auto pick charm card", "AutoCharmCard", nil,
        "Picks a charm before the run starts")
    UI.Slider(p, "Charm card index", "CharmCardIndex", 1, 4, 0, "")
    UI.Toggle(p, "Auto revive", "AutoRevive", nil, "Revives self + rescues party")
    UI.Toggle(p, "Auto skip cutscenes", "AutoSkipCutscene", nil, nil)
    UI.Toggle(p, "Auto daily rewards", "AutoDaily", nil,
        "Claims daily + tries free codes")
    UI.Toggle(p, "Auto codes", "AutoCodes", nil, nil)

    UI.Section(p, "Quest chain")
    UI.Info(p, "Official progression (place / mode -> quest):<br/>" ..
        "Grasslands N -> CG_02  |  Grasslands H -> CG_07  |  " ..
        "Sands H -> W2_C_08  |  Tundra H -> W3_C_08  |  " ..
        "Abyss H -> W4_C_08  |  Depths H -> W5_C_08")
end

------------------------------------------------------------------------
-- TAB: LOOT
------------------------------------------------------------------------
do
    local p = CreateTab("Loot")

    UI.Section(p, "Drops")
    UI.Toggle(p, "Auto collect drops", "AutoCollectDrops", nil, "Vacuum XP / loot")
    UI.Slider(p, "Collect range", "CollectRange", 30, 600, 0, " studs")

    UI.Section(p, "Chests")
    UI.Toggle(p, "Auto open chests", "AutoOpenChests", nil, "Opens from your stash")
    UI.Dropdown(p, "Chest set", "OpenChestSet",
        { "Common", "Royal", "Special", "Legendary", "Daily", "All" })
    UI.Slider(p, "Open count", "OpenChestBulk", 1, 100, 0, "")
    UI.Toggle(p, "Auto dark chest", "AutoDarkChest", nil, nil)
    UI.Toggle(p, "Auto proximity prompts", "AutoPrompts", nil,
        "Fires chest / station prompts in range")
    UI.Slider(p, "Prompt range", "PromptRange", 10, 120, 0, " studs")

    UI.Section(p, "Map destruction")
    UI.Toggle(p, "Destroy other stuff", "DestroyProps", nil,
        "Also kills breakables / scenery in the map")
    UI.Info(p, "Stardust maths: Common 10%, Rare 2%, Epic 0.133%, Legendary 0.04%.<br/>" ..
        "Bosses drop 50-100, minibosses 10-20, chests 3-4 per open.")
end

------------------------------------------------------------------------
-- TAB: FISHING
------------------------------------------------------------------------
do
    local p = CreateTab("Fishing")

    UI.Section(p, "Auto fish")
    UI.Toggle(p, "Auto fish", "AutoFish", nil, "Cast, reel and land on a loop")
    UI.Toggle(p, "Fast reel", "FastReel", nil, "Skips the waiting window")
    UI.Slider(p, "Reel delay (s)", "ReelDelay", 0, 3, 2, "s")
    UI.Slider(p, "Land delay (s)", "LandDelay", 0, 2, 2, "s")
    UI.Slider(p, "Perfect catch burst", "LandBurst", 1, 12, 0, "x",
        "Extra landed calls to hit the perfect window")

    UI.Section(p, "Bait")
    UI.Toggle(p, "Auto equip bait", "AutoBait", nil, nil)
    local baitOpts = {}
    for _, b in ipairs(BAITS) do baitOpts[#baitOpts + 1] = b.id end
    UI.Dropdown(p, "Bait", "BaitSelect", baitOpts)
    UI.Info(p, "Bait sources: Worms (W1), CrabClaws + MiniSandworm (W2),<br/>" ..
        "ArcticBerries + GlowingEel (W3), FleshGrubs + MagicEyeballs (W4),<br/>" ..
        "VoidSnail + AnglerFish (W5).")

    UI.Section(p, "Selling")
    UI.Toggle(p, "Auto sell", "AutoSellFish", nil, "Sells on every catch")
    UI.Slider(p, "Stash limit", "SellThreshold", 1, 200, 0, "")
    UI.Toggle(p, "Auto upgrade stash", "AutoUpgradeStash", nil, nil)
    UI.Toggle(p, "Sell charms too", "SellCharms", nil, nil)
    UI.Dropdown(p, "Charm to sell", "SellCharmTier", CHARMS)

    UI.Section(p, "What to sell")
    for _, f in ipairs(FISH) do
        UI.Toggle(p, "Sell " .. f.id, "SellFishes." .. f.id, nil, f.rarity)
    end
    UI.Info(p, "Keep Pages (8 pages unveil an enchanted book), DarkKey,<br/>" ..
        "FishGold and GoldenTooth by default - toggle any of them above.")
end

------------------------------------------------------------------------
-- TAB: INVENTORY
------------------------------------------------------------------------
do
    local p = CreateTab("Inventory")

    UI.Section(p, "Upgrades")
    UI.Toggle(p, "Auto upgrade items", "AutoUpgrade", nil,
        "Equips then upgrades the held gear")
    UI.Slider(p, "Copies per upgrade", "UpgradeCopies", 1, 20, 0, "")
    UI.Slider(p, "Max tier target", "MaxUpgradeTier", 1, 15, 0, "")
    UI.Toggle(p, "Auto equip best", "AutoEquipBest", nil, nil)
    UI.Toggle(p, "Auto claim achievements", "AutoClaims", nil, nil)

    UI.Section(p, "Item list")
    local listHolder = Make("Frame", {
        Size = UDim2.new(1, 0, 0, 190), BackgroundColor3 = Theme.Card,
        BorderSizePixel = 0, ClipsDescendants = true, LayoutOrder = NextOrder(p),
    }, p)
    Round(listHolder, 8); Outline(listHolder)
    listHolder:SetAttribute("Search", "item list armor weapon tier where found")
    local listScroll = Make("ScrollingFrame", {
        Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 3, CanvasSize = UDim2.new(),
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        ScrollingDirection = Enum.ScrollingDirection.Y,
    }, listHolder)
    Bind(listScroll, "ScrollBarImageColor3")
    Make("UIListLayout", { Padding = UDim.new(0, 2) }, listScroll)

    local function sortedKeys(tbl)
        local keys = {}
        for k in pairs(tbl) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b)
            local ra, rb = RARITY_ORDER[tbl[a]] or 9, RARITY_ORDER[tbl[b]] or 9
            if ra ~= rb then return ra < rb end
            return a < b
        end)
        return keys
    end

    local function RenderCatalog()
        for _, c in ipairs(listScroll:GetChildren()) do
            if c:IsA("TextLabel") then pcall(function() c:Destroy() end) end
        end
        local order = 0
        local function section(title)
            order = order + 1
            Label(listScroll, {
                Text = title, Font = Enum.Font.GothamBold, TextSize = 11,
                TextColor3 = Accent(), Size = UDim2.new(1, -12, 0, 18),
                LayoutOrder = order,
            })
        end
        local function row(text, colour)
            order = order + 1
            Label(listScroll, {
                Text = text, TextSize = 11, TextColor3 = colour or Theme.Text,
                Size = UDim2.new(1, -12, 0, 16), LayoutOrder = order,
            })
        end

        section("WEAPONS  -  rarity  -  where found")
        for _, name in ipairs(sortedKeys(WEAPON_CATALOG)) do
            row(string.format("%-22s %-10s  chests / bosses / drops", name,
                WEAPON_CATALOG[name]), RARITY_COLORS[WEAPON_CATALOG[name]])
        end
        section("ARMOUR  -  rarity  -  where found")
        for _, name in ipairs(sortedKeys(ARMOR_CATALOG)) do
            row(string.format("%-22s %-10s  chests / bosses / drops", name,
                ARMOR_CATALOG[name]), RARITY_COLORS[ARMOR_CATALOG[name]])
        end
        section("WORLD SOURCES")
        for i, w in ipairs(WORLDS) do
            row(string.format("W%d  %-16s final boss: %s", i, w.id, w.boss), Theme.Sub)
        end
        section("CHESTS")
        local chestNames = {}
        for setName in pairs(CHEST_SETS) do chestNames[#chestNames + 1] = setName end
        table.sort(chestNames)
        for _, setName in ipairs(chestNames) do
            row(setName .. ":  " .. table.concat(CHEST_SETS[setName], ", "), Theme.Sub)
        end
        section("YOUR INVENTORY (live)")
        if Inventory.available then
            local shown = 0
            for _, r in ipairs(Inventory.rows) do
                if shown >= 40 then break end
                local extra = ""
                if r.copies then extra = string.format("   x%s", tostring(r.copies)) end
                if r.tier then extra = extra .. string.format("   T%s", tostring(r.tier)) end
                row(tostring(r.text) .. extra, Theme.Good)
                shown = shown + 1
            end
            if shown == 0 then row("(armory open but no rows matched)", Theme.Sub) end
        else
            row("(open the Armory in game to populate this)", Theme.Sub)
        end
    end

    Every("RenderCatalog", 2.0, function() RenderCatalog() end, function()
        return MenuOpen and CurrentTab == "Inventory"
    end)
    RenderCatalog()

    InventoryStatusLabel = Label(p, {
        Text = "", TextSize = 11, RichText = true, TextColor3 = Theme.Sub,
        Size = UDim2.new(1, 0, 0, 20), LayoutOrder = NextOrder(p),
    })
    UI.RefreshInventory()
end

------------------------------------------------------------------------
-- TAB: VISUALS
------------------------------------------------------------------------
do
    local p = CreateTab("Visuals")
    UI.Section(p, "ESP")
    UI.Toggle(p, "Enemy ESP", "EnemyESP", nil, nil)
    UI.Toggle(p, "Boss ESP", "BossESP", nil, "Final + miniboss highlight")
    UI.Toggle(p, "Chest ESP", "ChestESP", nil, nil)
    UI.Toggle(p, "Drop ESP", "DropESP", nil, nil)
    UI.Toggle(p, "Tracers", "Tracers", nil, "Needs a Drawing-capable executor")
    UI.Slider(p, "ESP range", "ESPRange", 50, 800, 0, " studs")
    UI.Section(p, "Lighting")
    UI.Toggle(p, "Fullbright", "Fullbright", nil, nil)
    UI.Toggle(p, "No fog", "NoFog", nil, nil)
end

------------------------------------------------------------------------
-- TAB: PLAYER
------------------------------------------------------------------------
do
    local p = CreateTab("Player")
    UI.Section(p, "Movement")
    UI.Toggle(p, "Walk speed", "WalkSpeedEnabled", nil, nil)
    UI.Slider(p, "Walk speed value", "WalkSpeedValue", 16, 200, 0, "")
    UI.Toggle(p, "Fly", "FlyEnabled", nil, "WASD + Space / Shift")
    UI.Slider(p, "Fly speed", "FlySpeed", 10, 300, 0, "")
    UI.Toggle(p, "Infinite jump", "InfJump", nil, nil)
    UI.Toggle(p, "Noclip", "Noclip", nil, nil)
    UI.Toggle(p, "Anti-AFK", "AntiAFK", nil, nil)

    UI.Section(p, "Interface")
    local accents = {}
    for k in pairs(Accents) do accents[#accents + 1] = k end
    table.sort(accents)
    UI.Dropdown(p, "Accent", "Accent", accents, function() ApplyAccent() MarkDirty() end)
    local keys = { "RightShift", "LeftControl", "LeftAlt", "Insert", "End", "Home", "F2", "F3", "F4" }
    UI.Dropdown(p, "Menu key", "MenuKey", keys)
    UI.Toggle(p, "Auto-save config", "AutoSave", nil, nil)
    UI.Info(p, "Status: " .. (HasUserInput and "input bus OK" or "input bus unavailable") ..
        "  |  drawings: " .. (HasDrawing and "yes" or "no") ..
        "  |  config: " .. (HasFS and "file" or "memory only"))
end

------------------------------------------------------------------------
-- BOOT
------------------------------------------------------------------------
LoadConfig()
SelectTab("Combat")
SetMenu(MenuOpen)

Track(function() ApplyAccent() end)

-- Ambient diagnostics
task.spawn(function()
    task.wait(2)
    local parts = {}
    table.insert(parts, HasUserInput and "input bus OK" or "input bus MISSING")
    table.insert(parts, NetworkRemotes and ("remotes OK") or "remotes MISSING")
    table.insert(parts, HasDrawing and "drawings OK" or "no drawings")
    UI.Notify("Pixel Blade Hub v" .. VERSION, table.concat(parts, "  -  "), 5)
end)

-- Clean up on leave so nothing is left behind.
Track(game:GetService("Players").LocalPlayer.CharacterRemoving:Connect(function()
    task.delay(0.5, function()
        local _, _, hum = GetChar()
        if hum and Config.TrueImmortal then hum.MaxHealth = 100 end
    end)
end))

Env.PixelBladeHubCleanup = Unload
_G.PixelBladeHubCleanup = Unload

return { version = VERSION, config = Config, unload = Unload }
