--[[
    Vox Hub — Vox Seas (GameId: 7174773198)
    Mobile + PC | Executor: Delta, Hydrogen, Arceus X
    
    Estrutura derivada de análise de scripts públicos.
    Se o jogo atualizou e um path quebrou, os comentários
    com "[PATH]" indicam onde ajustar.
]]

-- ============================================================
-- SERVICES & VARS
-- ============================================================
local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local lp             = Players.LocalPlayer
local char, hum, hrp

local function refreshChar()
    char = lp.Character or lp.CharacterAdded:Wait()
    hum  = char:WaitForChild("Humanoid", 5)
    hrp  = char:WaitForChild("HumanoidRootPart", 5)
end
refreshChar()
lp.CharacterAdded:Connect(refreshChar)

-- ============================================================
-- DADOS DO JOGO
-- ============================================================

-- [PATH] workspace.NPCS.Quest{N}.ClickPart.QuestTake.QuestTake.{accept}.RemoteEvent
local QUESTS = {
    { label="Quest 1 (Lv 0-51)",   npc="Quest1", accept="Accept2" },
    { label="Quest 2 (Lv 51-101)", npc="Quest2", accept="Accept2" },
    { label="Quest 3 (Lv 100-251)",npc="Quest3", accept="Accept1" },
    { label="Quest 4 (Lv 251-550)",npc="Quest4", accept="Accept2" },
    { label="Quest 5 (Lv 550-901)",npc="Quest5", accept="Accept1" },
    { label="Quest 6 (Lv 901+)",   npc="Quest6", accept="Accept1" },
}

-- Range de level → quest + boss
-- [PATH] boss name = nome do modelo no workspace (folder abaixo)
local FARM_RANGES = {
    { min=0,   max=51,       quest="Quest1", accept="Accept2", boss="Boss"      },
    { min=51,  max=101,      quest="Quest2", accept="Accept2", boss="Snow Boss" },
    { min=100, max=251,      quest="Quest3", accept="Accept1", boss="Sand"      },
    { min=251, max=550,      quest="Quest4", accept="Accept2", boss="Enel"      },
    { min=550, max=901,      quest="Quest5", accept="Accept1", boss="Blue"      },
    { min=901, max=math.huge,quest="Quest6", accept="Accept1", boss="mmm"       },
}

-- [PATH] nomes das pastas de NPC no workspace (tenta todas por ordem)
local NPC_FOLDERS = { "NPC DAMAGE", "NPCs", "Mobs", "Enemies", "NPCS" }

-- Coordenadas das ilhas extraídas do script original
-- [PATH] ajusta se o mapa mudou
local ISLANDS = {
    { name="Ilha 1",  pos=Vector3.new(-969.31,  175.49,  387.69)  },
    { name="Ilha 2",  pos=Vector3.new(-708.96,   83.44, 1737.25)  },
    { name="Ilha 3",  pos=Vector3.new(-4594.53, 4283.94,  474.59) },
    { name="Ilha 4",  pos=Vector3.new(-2134.40,  109.18, 2247.32) },
    { name="Ilha 5",  pos=Vector3.new( 2570.05,   55.61,  -65.37) },
    { name="Ilha 6",  pos=Vector3.new(-3720.88,  150.64, 3811.50) },
}

-- ============================================================
-- HELPERS
-- ============================================================
local function safe(fn) return pcall(fn) end

local function getLevel()
    local ok, v = safe(function()
        return lp.Data.Levels.Value  -- [PATH] lp.Data.Levels.Value
    end)
    return ok and tonumber(v) or 0
end

local function getFarmData(lvl)
    for _, d in ipairs(FARM_RANGES) do
        if lvl >= d.min and lvl <= d.max then return d end
    end
    return FARM_RANGES[1]
end

local function getQuestRemote(npcName, acceptName)
    -- [PATH] workspace.NPCS.<npcName>.ClickPart.QuestTake.QuestTake.<acceptName>.RemoteEvent
    local folder = workspace:FindFirstChild("NPCS")
    if not folder then return nil end
    local npc = folder:FindFirstChild(npcName)
    if not npc then return nil end
    local p = npc:FindFirstChild("ClickPart")
    p = p and p:FindFirstChild("QuestTake")
    p = p and p:FindFirstChild("QuestTake")
    p = p and p:FindFirstChild(acceptName)
    return p and p:FindFirstChild("RemoteEvent")
end

local function findNPC(name)
    for _, fname in ipairs(NPC_FOLDERS) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            local npc = folder:FindFirstChild(name)
            if npc then return npc end
        end
    end
end

-- Dispara todos os hitbox remotes encontrados no PlayerGui
-- [PATH] PlayerGui.<tool>.Skill1b.Z.TextButtonm1.Hitbox
local function fireHitboxes()
    safe(function()
        for _, gui in ipairs(lp.PlayerGui:GetChildren()) do
            -- Busca profunda por RemoteEvent chamado "Hitbox"
            local hitbox = gui:FindFirstChild("Hitbox", true)
            if hitbox and hitbox:IsA("RemoteEvent") then
                hitbox:FireServer(8, 3)
            end
        end
    end)
end

local function tpTo(pos)
    safe(function()
        local c = lp.Character or lp.CharacterAdded:Wait()
        local root = c:FindFirstChild("HumanoidRootPart")
        if root then
            root.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        end
    end)
end

-- ============================================================
-- ESTADO
-- ============================================================
local S = { autoFarm=false, killAura=false, speed=false, infJump=false, noclip=false, esp=false }
local Conn = {}
local espMarks = {}

-- ============================================================
-- FEATURES
-- ============================================================

-- Auto Farm
local farmActive = false
local function startFarm()
    if farmActive then return end
    farmActive = true
    S.autoFarm = true
    task.spawn(function()
        while S.autoFarm do
            safe(function()
                local lvl = getLevel()
                local d   = getFarmData(lvl)

                -- Aceita a quest do nível
                local qRemote = getQuestRemote(d.quest, d.accept)
                if qRemote then qRemote:FireServer() end

                -- Vai até o boss do nível
                local boss = findNPC(d.boss)
                if boss then
                    local bhrp = boss:FindFirstChild("HumanoidRootPart")
                    if bhrp and hrp then
                        hrp.CFrame = bhrp.CFrame * CFrame.new(0, 0, -5)
                    end
                end

                -- Dispara hitbox
                fireHitboxes()
            end)
            task.wait(0.1)
        end
        farmActive = false
    end)
end

local function stopFarm()
    S.autoFarm = false
end

-- Kill Aura
local function setKillAura(on)
    S.killAura = on
    if Conn.aura then Conn.aura:Disconnect() Conn.aura = nil end
    if on then
        Conn.aura = RunService.Heartbeat:Connect(function()
            safe(fireHitboxes)
            if not hrp then return end
            -- TP para o mob mais próximo dentro de 40 studs
            for _, fname in ipairs(NPC_FOLDERS) do
                local folder = workspace:FindFirstChild(fname)
                if folder then
                    for _, npc in ipairs(folder:GetChildren()) do
                        local h    = npc:FindFirstChildOfClass("Humanoid")
                        local nhrp = npc:FindFirstChild("HumanoidRootPart")
                        if h and h.Health > 0 and nhrp then
                            if (nhrp.Position - hrp.Position).Magnitude < 40 then
                                safe(function()
                                    hrp.CFrame = nhrp.CFrame * CFrame.new(0, 0, -4)
                                end)
                                return
                            end
                        end
                    end
                end
            end
        end)
    end
end

-- Speed
local function setSpeed(on)
    S.speed = on
    if Conn.speed then Conn.speed:Disconnect() Conn.speed = nil end
    if on then
        Conn.speed = RunService.Heartbeat:Connect(function()
            safe(function()
                local c = lp.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then h.WalkSpeed = 60 end
                end
            end)
        end)
    else
        safe(function()
            if lp.Character then
                local h = lp.Character:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = 16 end
            end
        end)
    end
end

-- Infinite Jump
local function setInfJump(on)
    S.infJump = on
    if Conn.jump then Conn.jump:Disconnect() Conn.jump = nil end
    if on then
        Conn.jump = UserInputService.JumpRequest:Connect(function()
            safe(function()
                local c = lp.Character
                if c then
                    local h = c:FindFirstChildOfClass("Humanoid")
                    if h then h:ChangeState(Enum.HumanoidStateType.Jumping) end
                end
            end)
        end)
    end
end

-- Noclip
local function setNoclip(on)
    S.noclip = on
    if Conn.noclip then Conn.noclip:Disconnect() Conn.noclip = nil end
    if on then
        Conn.noclip = RunService.Stepped:Connect(function()
            safe(function()
                local c = lp.Character
                if c then
                    for _, p in ipairs(c:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = false end
                    end
                end
            end)
        end)
    end
end

-- ESP
local function clearESP()
    for _, h in ipairs(espMarks) do safe(function() h:Destroy() end) end
    espMarks = {}
end

local function setESP(on)
    S.esp = on
    clearESP()
    if not on then return end
    local function highlight(model, fillColor)
        safe(function()
            if model:FindFirstChildOfClass("Highlight") then return end
            local h = Instance.new("Highlight")
            h.FillColor       = fillColor
            h.OutlineColor    = Color3.new(1, 1, 1)
            h.FillTransparency = 0.5
            h.Parent = model
            table.insert(espMarks, h)
        end)
    end
    -- Mobs (vermelho)
    for _, fname in ipairs(NPC_FOLDERS) do
        local folder = workspace:FindFirstChild(fname)
        if folder then
            for _, npc in ipairs(folder:GetChildren()) do
                if npc:FindFirstChildOfClass("Humanoid") then
                    highlight(npc, Color3.fromRGB(255, 70, 70))
                end
            end
        end
    end
    -- Jogadores (azul)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= lp and plr.Character then
            highlight(plr.Character, Color3.fromRGB(70, 160, 255))
        end
    end
end

-- Cofres secretos
local function collectChests()
    safe(function()
        local map = workspace:FindFirstChild("MAP")
        if not map then return end
        for _, area in ipairs(map:GetChildren()) do
            local sc = area:FindFirstChild("Secret Chests")
            if sc then
                local rand = sc:FindFirstChild("RANDOM")
                if rand then
                    local cd = rand:FindFirstChildOfClass("ClickDetector")
                    if cd then
                        for _ = 1, 20 do
                            pcall(fireclickdetector, cd)
                            task.wait(0.05)
                        end
                    end
                end
            end
        end
    end)
end

-- ============================================================
-- GUI
-- ============================================================
safe(function()
    local old = lp.PlayerGui:FindFirstChild("VoxHub")
    if old then old:Destroy() end
end)

local sg = Instance.new("ScreenGui")
sg.Name          = "VoxHub"
sg.ResetOnSpawn  = false
sg.IgnoreGuiInset = true
sg.DisplayOrder  = 9999
sg.Parent        = lp.PlayerGui

-- Janela principal
local win = Instance.new("Frame")
win.Name              = "Win"
win.Size              = UDim2.new(0, 300, 0, 440)
win.Position          = UDim2.new(0.5, -150, 0.5, -220)
win.BackgroundColor3  = Color3.fromRGB(14, 14, 20)
win.BorderSizePixel   = 0
win.Parent            = sg
Instance.new("UICorner").Parent = win
do
    local sh = Instance.new("UIStroke", win)
    sh.Color       = Color3.fromRGB(90, 50, 180)
    sh.Thickness   = 1.5
end

-- Barra de título
local titleH = 44
local title = Instance.new("Frame")
title.Size            = UDim2.new(1, 0, 0, titleH)
title.BackgroundColor3 = Color3.fromRGB(90, 50, 180)
title.BorderSizePixel = 0
title.Parent          = win
do
    local c = Instance.new("UICorner", title)
    c.CornerRadius = UDim.new(0, 10)
    local fix = Instance.new("Frame", title)
    fix.Size = UDim2.new(1, 0, 0, 10)
    fix.Position = UDim2.new(0, 0, 1, -10)
    fix.BackgroundColor3 = Color3.fromRGB(90, 50, 180)
    fix.BorderSizePixel = 0
end

local titleLbl = Instance.new("TextLabel", title)
titleLbl.Size          = UDim2.new(1, -50, 1, 0)
titleLbl.Position      = UDim2.new(0, 12, 0, 0)
titleLbl.BackgroundTransparency = 1
titleLbl.Text          = "Vox Hub"
titleLbl.TextColor3    = Color3.new(1, 1, 1)
titleLbl.TextSize      = 17
titleLbl.Font          = Enum.Font.GothamBold
titleLbl.TextXAlignment = Enum.TextXAlignment.Left

local closeBtn = Instance.new("TextButton", title)
closeBtn.Size         = UDim2.new(0, 34, 0, 34)
closeBtn.Position     = UDim2.new(1, -38, 0, 5)
closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
closeBtn.BorderSizePixel = 0
closeBtn.Text         = "X"
closeBtn.TextColor3   = Color3.new(1, 1, 1)
closeBtn.TextSize     = 13
closeBtn.Font         = Enum.Font.GothamBold
Instance.new("UICorner").Parent = closeBtn
closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

-- Arraste (mobile + desktop)
do
    local dragging, dragInp, dragStart, startPos
    title.InputBegan:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseButton1
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragging  = true
            dragStart = inp.Position
            startPos  = win.Position
            inp.Changed:Connect(function()
                if inp.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    title.InputChanged:Connect(function(inp)
        if inp.UserInputType == Enum.UserInputType.MouseMovement
        or inp.UserInputType == Enum.UserInputType.Touch then
            dragInp = inp
        end
    end)
    UserInputService.InputChanged:Connect(function(inp)
        if inp == dragInp and dragging then
            local d = inp.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y
            )
        end
    end)
end

-- Tabs
local tabH = 36
local tabBar = Instance.new("Frame", win)
tabBar.Size           = UDim2.new(1, 0, 0, tabH)
tabBar.Position       = UDim2.new(0, 0, 0, titleH)
tabBar.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
tabBar.BorderSizePixel = 0
do
    local ll = Instance.new("UIListLayout", tabBar)
    ll.FillDirection = Enum.FillDirection.Horizontal
    ll.SortOrder     = Enum.SortOrder.LayoutOrder
end

local contentY = titleH + tabH
local contentH = 440 - contentY

-- Área de conteúdo
local contentArea = Instance.new("Frame", win)
contentArea.Size            = UDim2.new(1, 0, 0, contentH)
contentArea.Position        = UDim2.new(0, 0, 0, contentY)
contentArea.BackgroundTransparency = 1
contentArea.ClipsDescendants = true

-- Tab factory
local tabPages = {}
local activeTab = nil

local function newTab(name, order)
    local btn = Instance.new("TextButton", tabBar)
    btn.Size         = UDim2.new(0, 92, 1, 0)
    btn.LayoutOrder  = order
    btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
    btn.BorderSizePixel = 0
    btn.Text         = name
    btn.TextColor3   = Color3.fromRGB(140, 140, 160)
    btn.TextSize     = 13
    btn.Font         = Enum.Font.Gotham

    local scroll = Instance.new("ScrollingFrame", contentArea)
    scroll.Size           = UDim2.new(1, 0, 1, 0)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = Color3.fromRGB(90, 50, 180)
    scroll.Visible        = false

    local layout = Instance.new("UIListLayout", scroll)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding   = UDim.new(0, 6)

    local pad = Instance.new("UIPadding", scroll)
    pad.PaddingLeft  = UDim.new(0, 8)
    pad.PaddingRight = UDim.new(0, 8)
    pad.PaddingTop   = UDim.new(0, 8)

    layout.Changed:Connect(function()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 24)
    end)

    tabPages[name] = { btn=btn, scroll=scroll }

    btn.MouseButton1Click:Connect(function()
        for _, t in pairs(tabPages) do
            t.scroll.Visible     = false
            t.btn.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
            t.btn.TextColor3     = Color3.fromRGB(140, 140, 160)
        end
        scroll.Visible       = true
        btn.BackgroundColor3 = Color3.fromRGB(90, 50, 180)
        btn.TextColor3       = Color3.new(1, 1, 1)
        activeTab = name
    end)

    return scroll
end

-- Widgets
local function section(parent, text, order)
    local lbl = Instance.new("TextLabel", parent)
    lbl.Size         = UDim2.new(1, 0, 0, 22)
    lbl.BackgroundTransparency = 1
    lbl.Text         = text
    lbl.TextColor3   = Color3.fromRGB(90, 50, 180)
    lbl.TextSize     = 12
    lbl.Font         = Enum.Font.GothamBold
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.LayoutOrder  = order
end

local function toggle(parent, label, cb, order)
    local row = Instance.new("Frame", parent)
    row.Size         = UDim2.new(1, 0, 0, 44)
    row.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
    row.BorderSizePixel = 0
    row.LayoutOrder  = order
    Instance.new("UICorner").Parent = row

    local lbl = Instance.new("TextLabel", row)
    lbl.Size         = UDim2.new(1, -58, 1, 0)
    lbl.Position     = UDim2.new(0, 10, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text         = label
    lbl.TextColor3   = Color3.fromRGB(210, 210, 230)
    lbl.TextSize     = 13
    lbl.Font         = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextWrapped  = true

    local pill = Instance.new("TextButton", row)
    pill.Size        = UDim2.new(0, 44, 0, 24)
    pill.Position    = UDim2.new(1, -52, 0.5, -12)
    pill.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
    pill.BorderSizePixel = 0
    pill.Text        = "OFF"
    pill.TextColor3  = Color3.fromRGB(130, 130, 140)
    pill.TextSize    = 11
    pill.Font        = Enum.Font.GothamBold
    Instance.new("UICorner").Parent = pill

    local on = false
    pill.MouseButton1Click:Connect(function()
        on = not on
        if on then
            pill.BackgroundColor3 = Color3.fromRGB(90, 50, 180)
            pill.TextColor3       = Color3.new(1, 1, 1)
            pill.Text             = "ON"
        else
            pill.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
            pill.TextColor3       = Color3.fromRGB(130, 130, 140)
            pill.Text             = "OFF"
        end
        cb(on)
    end)
    return pill
end

local function button(parent, label, cb, order)
    local btn = Instance.new("TextButton", parent)
    btn.Size         = UDim2.new(1, 0, 0, 44)
    btn.BackgroundColor3 = Color3.fromRGB(90, 50, 180)
    btn.BorderSizePixel = 0
    btn.Text         = label
    btn.TextColor3   = Color3.new(1, 1, 1)
    btn.TextSize     = 13
    btn.Font         = Enum.Font.GothamBold
    btn.LayoutOrder  = order
    btn.TextWrapped  = true
    Instance.new("UICorner").Parent = btn
    btn.MouseButton1Click:Connect(cb)
    return btn
end

-- ============================================================
-- TAB: FARM
-- ============================================================
local farmScroll = newTab("Farm", 1)

section(farmScroll, "  Auto Farm", 1)
toggle(farmScroll, "Auto Farm (Quest + Boss)", function(on)
    if on then startFarm() else stopFarm() end
end, 2)
toggle(farmScroll, "Kill Aura", function(on) setKillAura(on) end, 3)

section(farmScroll, "  Quests Manuais", 10)
for i, q in ipairs(QUESTS) do
    button(farmScroll, q.label, function()
        safe(function()
            local r = getQuestRemote(q.npc, q.accept)
            if r then r:FireServer() end
        end)
    end, 10 + i)
end

-- ============================================================
-- TAB: MOVIMENTO
-- ============================================================
local moveScroll = newTab("Move", 2)

section(moveScroll, "  Movimento", 1)
toggle(moveScroll, "Speed Hack (60)", function(on) setSpeed(on) end, 2)
toggle(moveScroll, "Infinite Jump", function(on) setInfJump(on) end, 3)
toggle(moveScroll, "Noclip", function(on) setNoclip(on) end, 4)

section(moveScroll, "  Teleporte", 10)
for i, isl in ipairs(ISLANDS) do
    button(moveScroll, "TP " .. isl.name, function()
        tpTo(isl.pos)
    end, 10 + i)
end

-- ============================================================
-- TAB: MISC
-- ============================================================
local miscScroll = newTab("Misc", 3)

section(miscScroll, "  Visual", 1)
toggle(miscScroll, "ESP (Mobs + Players)", function(on) setESP(on) end, 2)
button(miscScroll, "Atualizar ESP", function()
    if S.esp then setESP(true) end
end, 3)

section(miscScroll, "  Misc", 10)
button(miscScroll, "Coletar Cofres Secretos", function()
    collectChests()
end, 11)
button(miscScroll, "Disparar Hitbox Manual", function()
    fireHitboxes()
end, 12)
button(miscScroll, "Rejoin", function()
    safe(function()
        game:GetService("TeleportService"):Teleport(game.PlaceId, lp)
    end)
end, 13)

-- Abre a aba Farm por padrão
tabPages["Farm"].scroll.Visible = true
tabPages["Farm"].btn.BackgroundColor3 = Color3.fromRGB(90, 50, 180)
tabPages["Farm"].btn.TextColor3 = Color3.new(1, 1, 1)
activeTab = "Farm"

print("[VoxHub] Carregado.")
