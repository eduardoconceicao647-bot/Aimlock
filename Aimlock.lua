-- =====================================================
-- PAINEL RAYFIELD: ESP + AIMBOT + AIMLOCK + FOV
-- =====================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

-- =====================================================
-- CONFIGURAÇÕES
-- =====================================================
local Config = {
    -- Aimbot
    AimbotEnabled = false,
    AimlockEnabled = true,
    AimOnHold = true,
    AimPart = "Head",
    AimFOV = 150,
    AimSmoothness = 0.25,
    TeamCheck = true,

    -- ESP
    EspEnabled = false,
    EspFillColor = Color3.fromRGB(255, 0, 0),
    EspOutlineColor = Color3.fromRGB(255, 255, 255),
    EspFillTransparency = 0.5,
    EspTeamCheck = true,

    -- FOV
    FovEnabled = false,
    FovRadius = 150,
    FovColor = Color3.fromRGB(255, 255, 255),
}

local CurrentTarget = nil

-- =====================================================
-- UTILITÁRIOS
-- =====================================================
local function IsAlive(plr)
    if not plr or not plr.Character then return false end
    local hum = plr.Character:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function GetTargetPart(plr)
    if not plr.Character then return nil end
    if Config.AimPart == "Head" then
        return plr.Character:FindFirstChild("Head")
    elseif Config.AimPart == "Torso" then
        return plr.Character:FindFirstChild("UpperTorso")
            or plr.Character:FindFirstChild("Torso")
            or plr.Character:FindFirstChild("HumanoidRootPart")
    elseif Config.AimPart == "Random" then
        local parts = {
            plr.Character:FindFirstChild("Head"),
            plr.Character:FindFirstChild("UpperTorso") or plr.Character:FindFirstChild("Torso")
        }
        local valid = {}
        for _, p in ipairs(parts) do if p then table.insert(valid, p) end end
        return valid[math.random(1, #valid)]
    end
    return plr.Character:FindFirstChild("Head")
end

-- =====================================================
-- AIMBOT / AIMLOCK
-- =====================================================
local function GetClosestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closest, shortest = nil, Config.AimFOV

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and IsAlive(plr) then
            if not (Config.TeamCheck and plr.Team == LocalPlayer.Team) then
                local part = GetTargetPart(plr)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                        if dist < shortest then
                            shortest = dist
                            closest = plr
                        end
                    end
                end
            end
        end
    end
    return closest
end

local function IsTargetValid(plr)
    if not IsAlive(plr) then return false end
    if Config.TeamCheck and plr.Team == LocalPlayer.Team then return false end
    local part = GetTargetPart(plr)
    if not part then return false end
    local mousePos = UserInputService:GetMouseLocation()
    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
    if not onScreen then return false end
    local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
    return dist < Config.AimFOV
end

local function ApplyAim(target)
    if not target or not target.Character then return end
    local part = GetTargetPart(target)
    if not part then return end
    local targetCF = CFrame.new(Camera.CFrame.Position, part.Position)
    Camera.CFrame = Camera.CFrame:Lerp(targetCF, Config.AimSmoothness)
end

RunService:BindToRenderStep("AimLoop", Enum.RenderPriority.Camera.Value + 1, function()
    if not Config.AimbotEnabled then CurrentTarget = nil return end

    -- Modo Hold (botão direito)
    if Config.AimOnHold then
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            CurrentTarget = nil
            return
        end
    end

    if Config.AimlockEnabled then
        -- AIMLOCK: mantém o alvo
        if CurrentTarget and IsTargetValid(CurrentTarget) then
            ApplyAim(CurrentTarget)
        else
            CurrentTarget = GetClosestTarget()
            if CurrentTarget then ApplyAim(CurrentTarget) end
        end
    else
        -- AIMBOT normal: sempre pega o mais próximo
        CurrentTarget = GetClosestTarget()
        if CurrentTarget then ApplyAim(CurrentTarget) end
    end
end)

-- =====================================================
-- ESP
-- =====================================================
local function ApplyHighlight(character)
    if not character then return end
    local hl = character:FindFirstChild("ESPHL")
    if not hl then
        hl = Instance.new("Highlight")
        hl.Name = "ESPHL"
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = character
    end
    hl.FillColor = Config.EspFillColor
    hl.OutlineColor = Config.EspOutlineColor
    hl.FillTransparency = Config.EspFillTransparency
    hl.OutlineTransparency = 0
end

local function RemoveHighlight(character)
    if not character then return end
    local hl = character:FindFirstChild("ESPHL")
    if hl then hl:Destroy() end
end

local function UpdateESP()
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            if Config.EspEnabled and not (Config.EspTeamCheck and plr.Team == LocalPlayer.Team) then
                ApplyHighlight(plr.Character)
            else
                RemoveHighlight(plr.Character)
            end
        end
    end
end

local function HookPlayer(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.3)
        if Config.EspEnabled and not (Config.EspTeamCheck and plr.Team == LocalPlayer.Team) then
            ApplyHighlight(char)
        end
    end)
    if plr.Character and Config.EspEnabled then
        ApplyHighlight(plr.Character)
    end
end

for _, plr in ipairs(Players:GetPlayers()) do HookPlayer(plr) end
Players.PlayerAdded:Connect(HookPlayer)
Players.PlayerRemoving:Connect(function(plr)
    if plr.Character then RemoveHighlight(plr.Character) end
end)

-- =====================================================
-- FOV CIRCLE
-- =====================================================
local function GetGuiParent()
    return (gethui and gethui()) or game:GetService("CoreGui")
end

local fovGui, fovFrame, fovStroke

local function CreateFovCircle()
    if not fovGui then
        fovGui = Instance.new("ScreenGui")
        fovGui.Name = "FovCircleGui"
        fovGui.ResetOnSpawn = false
        fovGui.IgnoreGuiInset = true
        pcall(function() fovGui.Parent = GetGuiParent() end)

        fovFrame = Instance.new("Frame")
        fovFrame.Name = "Circle"
        fovFrame.BackgroundTransparency = 1
        fovFrame.AnchorPoint = Vector2.new(0.5, 0.5)
        fovFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
        fovFrame.Parent = fovGui

        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(1, 0) -- <- borda totalmente redonda
        corner.Parent = fovFrame

        fovStroke = Instance.new("UIStroke")
        fovStroke.Thickness = 1.5
        fovStroke.Transparency = 0
        fovStroke.Parent = fovFrame
    end

    fovFrame.Visible = Config.FovEnabled
    fovFrame.Size = UDim2.new(0, Config.FovRadius * 2, 0, Config.FovRadius * 2)
    fovStroke.Color = Config.FovColor
end

-- =====================================================
-- JANELA RAYFIELD
-- =====================================================
local Window = Rayfield:CreateWindow({
    Name = "Painel Completo",
    LoadingTitle = "Carregando painel...",
    LoadingSubtitle = "Aimbot • Aimlock • ESP • FOV",
    Theme = "Default",
    ToggleUIKeybind = "K",
    ConfigurationSaving = { Enabled = false },
    KeySystem = false,
})

-- ABA AIMBOT
local AimbotTab = Window:CreateTab("Aimbot", 4483362458)
AimbotTab:CreateSection("Aimbot")

AimbotTab:CreateToggle({
    Name = "Ativar Aimbot",
    CurrentValue = false,
    Flag = "AimbotToggle",
    Callback = function(v)
        Config.AimbotEnabled = v
        if not v then CurrentTarget = nil end
    end,
})

AimbotTab:CreateToggle({
    Name = "Aimlock (travar no alvo)",
    CurrentValue = true,
    Flag = "AimlockToggle",
    Callback = function(v) Config.AimlockEnabled = v end,
})

AimbotTab:CreateToggle({
    Name = "Segurar Botão Direito",
    CurrentValue = true,
    Flag = "AimHoldToggle",
    Callback = function(v) Config.AimOnHold = v end,
})

AimbotTab:CreateDropdown({
    Name = "Parte do Corpo",
    Options = {"Head", "Torso", "Random"},
    CurrentOption = {"Head"},
    Flag = "AimPartDropdown",
    Callback = function(opt)
        Config.AimPart = type(opt) == "table" and opt[1] or opt
    end,
})

AimbotTab:CreateSlider({
    Name = "FOV do Aimbot",
    Range = {50, 500},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 150,
    Flag = "AimFOVSlider",
    Callback = function(v) Config.AimFOV = v end,
})

AimbotTab:CreateSlider({
    Name = "Suavidade (Smoothness)",
    Range = {0.05, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.25,
    Flag = "AimSmoothSlider",
    Callback = function(v) Config.AimSmoothness = v end,
})

AimbotTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Flag = "AimTeamCheck",
    Callback = function(v) Config.TeamCheck = v end,
})

-- ABA ESP
local EspTab = Window:CreateTab("ESP", 4483362458)
EspTab:CreateSection("ESP")

EspTab:CreateToggle({
    Name = "Ativar ESP",
    CurrentValue = false,
    Flag = "EspToggle",
    Callback = function(v)
        Config.EspEnabled = v
        UpdateESP()
    end,
})

EspTab:CreateColorPicker({
    Name = "Cor do Preenchimento",
    Color = Color3.fromRGB(255, 0, 0),
    Flag = "EspFillColor",
    Callback = function(c)
        Config.EspFillColor = c
        UpdateESP()
    end,
})

EspTab:CreateColorPicker({
    Name = "Cor do Contorno",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "EspOutlineColor",
    Callback = function(c)
        Config.EspOutlineColor = c
        UpdateESP()
    end,
})

EspTab:CreateSlider({
    Name = "Transparência do Preenchimento",
    Range = {0, 1},
    Increment = 0.05,
    Suffix = "",
    CurrentValue = 0.5,
    Flag = "EspFillTransp",
    Callback = function(v)
        Config.EspFillTransparency = v
        UpdateESP()
    end,
})

EspTab:CreateToggle({
    Name = "Team Check",
    CurrentValue = true,
    Flag = "EspTeamCheck",
    Callback = function(v)
        Config.EspTeamCheck = v
        UpdateESP()
    end,
})

-- ABA FOV
local FovTab = Window:CreateTab("FOV", 4483362458)
FovTab:CreateSection("Círculo de FOV")

FovTab:CreateToggle({
    Name = "Mostrar Círculo FOV",
    CurrentValue = false,
    Flag = "FovToggle",
    Callback = function(v)
        Config.FovEnabled = v
        CreateFovCircle()
    end,
})

FovTab:CreateSlider({
    Name = "Tamanho do FOV",
    Range = {50, 600},
    Increment = 10,
    Suffix = "px",
    CurrentValue = 150,
    Flag = "FovSizeSlider",
    Callback = function(v)
        Config.FovRadius = v
        CreateFovCircle()
    end,
})

FovTab:CreateColorPicker({
    Name = "Cor do Círculo",
    Color = Color3.fromRGB(255, 255, 255),
    Flag = "FovColor",
    Callback = function(c)
        Config.FovColor = c
        CreateFovCircle()
    end,
})

-- =====================================================
-- INIT
-- =====================================================
UpdateESP()
CreateFovCircle()

Camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
    if fovFrame then CreateFovCircle() end
end)

print("[Painel] Carregado. Pressione K para abrir/fechar.")
