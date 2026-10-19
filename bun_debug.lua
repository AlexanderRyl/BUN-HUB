-- BUN Hub on-screen diagnostic (no console needed)
local URL = "https://raw.githubusercontent.com/AlexanderRyl/BUN-HUB/main/bun_hub.lua"
local Players = game:GetService("Players")

local sg = Instance.new("ScreenGui")
sg.Name = "BUN_Debug"
sg.ResetOnSpawn = false
sg.DisplayOrder = 9999
sg.IgnoreGuiInset = true

local parented = false
if type(gethui) == "function" then
    local ok, h = pcall(gethui)
    if ok and h then sg.Parent = h parented = sg.Parent ~= nil end
end
if not parented then
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    parented = sg.Parent ~= nil
end
if not parented then sg.Parent = Players.LocalPlayer:WaitForChild("PlayerGui") end

local box = Instance.new("TextButton")
box.Size = UDim2.new(0, 380, 0, 260)
box.Position = UDim2.new(0, 10, 0, 60)
box.BackgroundColor3 = Color3.new(0, 0, 0)
box.BackgroundTransparency = 0.1
box.BorderSizePixel = 0
box.Text = ""
box.AutoButtonColor = false
box.Parent = sg

local txt = Instance.new("TextLabel")
txt.Size = UDim2.new(1, -12, 1, -12)
txt.Position = UDim2.new(0, 6, 0, 6)
txt.BackgroundTransparency = 1
txt.TextColor3 = Color3.new(1, 1, 1)
txt.Font = Enum.Font.Code
txt.TextSize = 13
txt.TextWrapped = true
txt.TextXAlignment = Enum.TextXAlignment.Left
txt.TextYAlignment = Enum.TextYAlignment.Top
txt.Parent = box
box.MouseButton1Click:Connect(function() sg:Destroy() end)

local lines = { "BUN debug  (tap this box to close)" }
local function say(m)
    lines[#lines + 1] = m
    txt.Text = table.concat(lines, "\n")
    print("[BUN debug] " .. m)
end
local env = (type(getgenv) == "function" and getgenv()) or getfenv()
local function has(name) return type(env[name]) == "function" and "yes" or "no" end

say("1. script is running: OK")
say("2. executor: " .. tostring(type(identifyexecutor) == "function" and identifyexecutor() or "unknown"))
say("3. loadstring=" .. has("loadstring") .. "  gethui=" .. has("gethui")
    .. "  writefile=" .. has("writefile") .. "  getcustomasset=" .. has("getcustomasset")
    .. "  fireproximityprompt=" .. has("fireproximityprompt"))

local ok, src = pcall(function() return game:HttpGet(URL) end)
if not ok then say("4. DOWNLOAD FAILED: " .. tostring(src):sub(1, 200)) return end
say("4. download OK (" .. #src .. " bytes)")

local fn, cerr = loadstring(src)
if not fn then say("5. COMPILE FAILED: " .. tostring(cerr):sub(1, 250)) return end
say("5. compile OK")

local ran, rerr = xpcall(fn, debug.traceback)
if not ran then say("6. RUN ERROR: " .. tostring(rerr):sub(1, 400)) return end
say("6. ran without errors")

task.wait(1.5)
local found, roots = {}, {}
if type(gethui) == "function" then
    local okH, h = pcall(gethui)
    if okH and h then roots[#roots + 1] = h end
end
pcall(function() roots[#roots + 1] = game:GetService("CoreGui") end)
local pg = Players.LocalPlayer:FindFirstChild("PlayerGui")
if pg then roots[#roots + 1] = pg end
for _, root in ipairs(roots) do
    for _, c in ipairs(root:GetChildren()) do
        if c.Name:sub(1, 4) == "BUN_" and c ~= sg then found[#found + 1] = root.Name .. "/" .. c.Name end
    end
end
say("7. BUN gui present: " .. (#found > 0 and table.concat(found, ", ") or "NO"))
