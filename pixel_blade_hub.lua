-- Pixel Blade Hub v1.0
local P=game.Players.LocalPlayer
local R=game.ReplicatedStorage._network_remotes
local W=workspace
local on={ka=false,aa=false,ac=false,as=false,af=false,au=false}
local range=200

-- UI
local sg=Instance.new("ScreenGui",P.PlayerGui)
sg.Name="PBHub" sg.ResetOnSpawn=false
local mf=Instance.new("Frame",sg)
mf.Size=UDim2.new(0,260,0,320) mf.Position=UDim2.new(0,10,0.5,-160)
mf.BackgroundColor3=Color3.fromRGB(25,25,25) mf.BorderSizePixel=0
local t=Instance.new("TextLabel",mf)
t.Size=UDim2.new(1,0,0,28) t.BackgroundColor3=Color3.fromRGB(45,45,45)
t.Text="Pixel Blade Hub" t.TextColor3=Color3.new(1,1,1) t.Font=Enum.Font.GothamBold t.TextSize=14

local function tog(name,y,cb)
    local l=Instance.new("TextLabel",mf)
    l.Size=UDim2.new(0.6,0,0,24) l.Position=UDim2.new(0,8,0,y)
    l.Text=name l.TextColor3=Color3.new(1,1,1) l.Font=Enum.Font.Gotham l.TextSize=12
    l.BackgroundTransparency=1 l.TextXAlignment=Enum.TextXAlignment.Left
    local b=Instance.new("TextButton",mf)
    b.Size=UDim2.new(0.3,0,0,20) b.Position=UDim2.new(0.68,0,0,y+2)
    b.BackgroundColor3=Color3.fromRGB(180,40,40) b.Text="OFF" b.TextColor3=Color3.new(1,1,1)
    b.Font=Enum.Font.GothamBold b.TextSize=11
    b.MouseButton1Click:Connect(function()
        on[name:lower():gsub(" ","")]=not on[name:lower():gsub(" ","")]
        local s=on[name:lower():gsub(" ","")]
        b.Text=s and "ON" or "OFF"
        b.BackgroundColor3=s and Color3.fromRGB(40,180,40) or Color3.fromRGB(180,40,40)
        cb(s)
    end)
end

tog("Kill Aura",32,function(s) on.ka=s end)
tog("Auto Attack",60,function(s) on.aa=s end)
tog("Auto Collect",88,function(s) on.ac=s end)
tog("Auto Sell",116,function(s) on.as=s end)
tog("Auto Fish",144,function(s) on.af=s end)
tog("Auto Upgrade",172,function(s) on.au=s end)

task.spawn(function()
    while true do
        task.wait(0.05)
        if on.ka or on.aa then
            pcall(function()
                local c=P.Character if not c then return end
                local h=c:FindFirstChild("HumanoidRootPart") if not h then return end
                for _,o in ipairs(W:GetDescendants()) do
                    if o:IsA("Model") and o:FindFirstChild("Humanoid") then
                        local hu=o.Humanoid local t=o:FindFirstChild("HumanoidRootPart")
                        if t and hu.Health>0 and o~=c and (h.Position-t.Position).Magnitude<=range then
                            R.replicate_hit:FireServer(o,1)
                        end
                    end
                end
            end)
        end
        if on.ac then pcall(function() R.collect_drop:FireServer() end) end
        if on.as then pcall(function() R.sell_fish_catch:FireServer() R.sell_fish_charm:FireServer() end) end
        if on.au then pcall(function() R.upgrade_fishing_stash:FireServer() end) end
    end
end)

task.spawn(function()
    while true do
        task.wait(1)
        if on.af then
            pcall(function() R.fishing_cast:FireServer() task.wait(2) R.fishing_reel:FireServer() end)
        end
    end
end)

print("Pixel Blade Hub loaded")