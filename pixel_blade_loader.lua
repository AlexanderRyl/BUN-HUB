--[[
    Pixel Blade Hub - self diagnosing loader
    Paste this into the executor INSTEAD of the bare loadstring.
    It tells you exactly what went wrong, on screen, even with a dead console.
]]
do
    local URL = "https://raw.githubusercontent.com/AlexanderRyl/BUN-HUB/main/PixelBladeHub_v4.lua"

    local Players = game:GetService("Players")
    local HttpService = game:GetService("HttpService")

    ------------------------------------------------------------------
    -- On-screen log (works even when the executor console is broken)
    ------------------------------------------------------------------
    local lines, lineObjs = {}, {}
    local gui = Instance.new("ScreenGui")
    gui.Name = "PBH_Debug"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 10000
    gui.IgnoreGuiInset = true
    if type(gethui) == "function" then
        local ok, h = pcall(gethui)
        if ok and h then gui.Parent = h end
    end
    if not gui.Parent then
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
    end
    if not gui.Parent then gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(1, -24, 0, 300)
    frame.Position = UDim2.fromOffset(12, 12)
    frame.BackgroundColor3 = Color3.fromRGB(10, 11, 16)
    frame.BorderSizePixel = 0
    frame.Parent = gui
    Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

    local close = Instance.new("TextButton")
    close.Size = UDim2.fromOffset(34, 30)
    close.Position = UDim2.new(1, -38, 0, 4)
    close.BackgroundTransparency = 1
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 120, 120)
    close.TextSize = 18
    close.Font = Enum.Font.GothamBold
    close.Parent = frame
    close.MouseButton1Click:Connect(function() gui:Destroy() end)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -46, 0, 26)
    title.Position = UDim2.fromOffset(10, 4)
    title.BackgroundTransparency = 1
    title.Text = "Pixel Blade Hub - loader"
    title.TextColor3 = Color3.fromRGB(200, 210, 240)
    title.TextSize = 14
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -20, 1, -38)
    scroll.Position = UDim2.fromOffset(10, 30)
    scroll.BackgroundTransparency = 1
    scroll.ScrollBarThickness = 4
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.CanvasSize = UDim2.new()
    scroll.Parent = frame
    Instance.new("UIListLayout", scroll).Padding = UDim.new(0, 2)

    local function log(txt, color)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -6, 0, 0)
        l.AutomaticSize = Enum.AutomaticSize.Y
        l.BackgroundTransparency = 1
        l.Text = tostring(txt)
        l.TextColor3 = color or Color3.fromRGB(210, 215, 230)
        l.TextSize = 12
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextYAlignment = Enum.TextYAlignment.Top
        l.TextWrapped = true
        l.Font = Enum.Font.Code
        l.Parent = scroll
        lines[#lines + 1] = txt
        lineObjs[#lineObjs + 1] = l
        print("[PBH] " .. tostring(txt))
    end

    ------------------------------------------------------------------
    -- 1. fetch
    ------------------------------------------------------------------
    local bust = URL .. "?v=" .. HttpService:GenerateGUID(false):sub(1, 8)
    log("1. fetching " .. bust)

    local src
    local okFetch, errFetch = pcall(function()
        src = game:HttpGet(bust, true)
    end)
    if not okFetch or type(src) ~= "string" then
        log("FAIL fetch: " .. tostring(errFetch), Color3.fromRGB(255, 90, 90))
        log("If this says 404 the file/branch name is wrong.", Color3.fromRGB(255, 170, 90))
        return
    end
    log("2. got " .. #src .. " bytes")
    log("   sha-ish head: " .. src:sub(1, 40):gsub("\n", " "))

    if src:sub(1, 1) == "<" then
        log("FAIL: that is HTML, not Lua.", Color3.fromRGB(255, 90, 90))
        log("Use raw.githubusercontent.com, not github.com/.../blob/...", Color3.fromRGB(255, 170, 90))
        return
    end
    if not src:find("PIXEL BLADE HUB") then
        log("WARN: this does not look like the hub script.", Color3.fromRGB(255, 170, 90))
    end
    if not src:find("PBH_Toggle") then
        log("WARN: no floating button in this build - GitHub served a stale copy.",
            Color3.fromRGB(255, 170, 90))
    end

    ------------------------------------------------------------------
    -- 2. compile
    ------------------------------------------------------------------
    log("3. compiling...")
    local chunk, errCompile = loadstring(src, "PixelBladeHub_v4")
    if not chunk then
        log("FAIL compile: " .. tostring(errCompile), Color3.fromRGB(255, 90, 90))
        local ln = tostring(errCompile):match(":%d+")
        if ln then
            local n = tonumber(ln:match("(%d+)"))
            if n then
                local a = math.max(1, n - 2)
                local s = {}
                for i = a, math.min(n + 2, #src + 1) do
                    s[#s + 1] = string.format("%d| %s", i, src:match("([^\n]*)\n?", i) or "")
                end
                log("around line " .. n .. ":\n" .. table.concat(s, "\n"), Color3.fromRGB(255, 170, 90))
            end
        end
        return
    end
    log("4. compiled OK")

    ------------------------------------------------------------------
    -- 3. run with traceback
    ------------------------------------------------------------------
    log("5. running...")
    local okRun, errRun = xpcall(chunk, function(e)
        return tostring(e) .. "\n" .. debug.traceback("", 2)
    end)
    if not okRun then
        log("FAIL runtime:\n" .. tostring(errRun), Color3.fromRGB(255, 90, 90))
        local ln = tostring(errRun):match("PixelBladeHub_v4:(%d+)")
        if ln then
            local n = tonumber(ln)
            local s = {}
            for i = math.max(1, n - 2), math.min(n + 2, #src + 1) do
                s[#s + 1] = string.format("%d| %s", i, src:match("([^\n]*)\n?", i) or "")
            end
            log("around line " .. n .. ":\n" .. table.concat(s, "\n"), Color3.fromRGB(255, 170, 90))
        end
        return
    end

    log("6. DONE - the hub should be loaded.")
    log("   Look for the round PB button on the right edge of the screen.", Color3.fromRGB(120, 230, 160))
    task.delay(12, function() if gui and gui.Parent then gui:Destroy() end end)
end