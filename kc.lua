--[[
  KittenWare • 2025
  No Recoil + Aimbot (Wall Check + Distance + HUD + Passive Check)
  Fullbright/FOV + Insta Reload (speed)
  ESP++ (Skeleton / Corner Boxes / Filled Boxes / Tracers / Names / Health / Distance / Item ESP / Off-Screen Arrows / Passive Tag)

  Menu layout is organized by sections.
]]

if getgenv().KittenWareLoaded or getgenv().KittenWareLoading then return end
getgenv().KittenWareLoading = true

----------------------------------------------------------------
-- Services & Helpers
----------------------------------------------------------------
local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS        = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Lighting   = game:GetService("Lighting")
local Workspace  = game:GetService("Workspace")

local LP     = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local function notify(t,x,d) pcall(function() StarterGui:SetCore("SendNotification",{Title=t,Text=x,Duration=d or 3}) end) end
local function clamp(v,a,b) return (v<a) and a or ((v>b) and b or v) end
local function lerp(a,b,t) return a + (b-a)*t end

-- UI lib (Exunys)
loadstring(game:HttpGet("https://raw.githubusercontent.com/Exunys/Roblox-Functions-Library/main/Library.lua"))()
local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/kitty92pm/AirHub-V2/refs/heads/main/src/UI%20Library.lua"))()

-- Tabs (organized)
local Main     = GUI:Load()
local Combat   = Main:Tab("Combat")
local Visual   = Main:Tab("Visual")
local Utility  = Main:Tab("World")
local Settings = Main:Tab("Settings")

----------------------------------------------------------------
-- No Recoil
----------------------------------------------------------------
local nrEnabled, nrConns, charAddedConn = false, {}, nil
local function renameOne(inst) if inst and inst.Name=="Recoil" and not inst:GetAttribute("KW") then inst:SetAttribute("KW",true) inst.Name="_Recoil" end end
local function revertOne(inst) if inst and inst.Name=="_Recoil" and inst:GetAttribute("KW") then inst.Name="Recoil" inst:SetAttribute("KW",nil) end end
local function sweep(c) if c then for _,d in ipairs(c:GetDescendants()) do renameOne(d) end renameOne(c) end end
local function revert(c) if c then for _,d in ipairs(c:GetDescendants()) do revertOne(d) end revertOne(c) end end
local function watch(c) if not c then return end table.insert(nrConns,c.DescendantAdded:Connect(renameOne)) table.insert(nrConns,c.ChildAdded:Connect(renameOne)) end
local function unwatch() for _,c in ipairs(nrConns) do if c then c:Disconnect() end end nrConns={} end
local function onCharacter(ch) if not nrEnabled then return end sweep(ch) watch(ch) local bp=LP:FindFirstChildOfClass("Backpack") if bp then sweep(bp) watch(bp) end end
local function enableNR() nrEnabled=true unwatch() sweep(LP) watch(LP) onCharacter(LP.Character or LP.CharacterAdded:Wait()) if charAddedConn then charAddedConn:Disconnect() end charAddedConn=LP.CharacterAdded:Connect(onCharacter) end
local function disableNR() nrEnabled=false unwatch() if charAddedConn then charAddedConn:Disconnect() charAddedConn=nil end revert(LP) if LP.Character then revert(LP.Character) end local bp=LP:FindFirstChildOfClass("Backpack") if bp then revert(bp) end end

do
    local S = Combat:Section({Name="No Recoil", Side="Left"})
    S:Toggle({Name="Enabled",Flag="KW_NR",Default=false,Callback=function(v) if v then enableNR() else disableNR() end end})
end

----------------------------------------------------------------
-- ESP++ (Drawing API)
----------------------------------------------------------------
local hasDrawing=(typeof(Drawing)=="table" and typeof(Drawing.new)=="function")
if not hasDrawing then notify("KittenWare","Drawing API not found; ESP disabled.",5) end

-- ESP Config (core)
local espEnabled, espConn=false,nil
local showSkeleton, showBoxes, showCornerBox, showFilledBox = true, true, true, false
local cornerLen = 8 -- px
local showTracers, showNames, showHealth, showDistance = true, true, true, true
local onlyVisible = false
local maxDistance = 2500
local fadeByDistance = true
local thicknessBase, alphaBase = 2.5, 0.9
local thicknessNear, thicknessFar = 3.0, 1.0
local tracerOrigin="Bottom" -- Bottom/Center/Mouse
local espTeamCheck=false
local useTeamColors=false
local visibleColor=Color3.fromRGB(0,255,255)
local occludedColor=Color3.fromRGB(255,100,100)
local fillAlpha = 0.15
local nameSize, infoSize = 14, 13
local friendList = {} -- {["PlayerName"]=true}

-- Item ESP
local itemESPEnabled = true
local itemESPColor = Color3.fromRGB(255, 200, 120)
local itemESPSize = 13
local itemESPOffsetY = 14
local itemESPShowWhenNoTool = false

-- Off-screen arrows
local arrowsEnabled = true
local arrowSize = 18
local arrowRadiusFactor = 0.45
local arrowsUseTeamColors = true
local arrowFadeWithDistance = true
local arrowBaseColor = Color3.fromRGB(255,255,255)

-- Passive check (ForceField)
local passiveESPEnabled = true
local passiveAimbotIgnore = true
local passiveTagColor = Color3.fromRGB(150, 210, 255)
local passiveTagText = " (P)"

-- Store draw objects
local playerDraw, espSignals = {}, {}
local playersSignal, playerAddedConn

-- Helpers
local function sameTeam(plr)
    if not espTeamCheck then return false end
    if LP.Team and plr.Team then return plr.Team==LP.Team end
    if LP.TeamColor and plr.TeamColor then return plr.TeamColor==LP.TeamColor end
    return false
end

local function characterIsPassive(ch)
    if not ch then return false end
    if ch:FindFirstChildOfClass("ForceField") then return true end
    for _,bp in ipairs(ch:GetDescendants()) do
        if bp:IsA("BasePart") and bp.Material == Enum.Material.ForceField then
            return true
        end
    end
    -- some games flag a passive attr on humanoid/character
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if hum and (hum:GetAttribute("Passive") == true or hum:GetAttribute("Invulnerable")==true) then
        return true
    end
    if ch:GetAttribute("Passive")==true then return true end
    return false
end

local function isVisibleLOS(part, targetChar)
    if not part then return false end
    local origin=Camera.CFrame.Position
    local dir=(part.Position-origin)
    local rp=RaycastParams.new()
    rp.FilterType=Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances={LP.Character, targetChar}
    return Workspace:Raycast(origin, dir, rp) == nil
end

local function healthColor(h, mh)
    local t = clamp(h / math.max(1, mh), 0, 1)
    local r = t < 0.5 and 1 or lerp(1, 0, (t-0.5)/0.5)
    local g = t < 0.5 and lerp(0,1,t/0.5) or 1
    return Color3.new(r, g, 0)
end

-- Drawing factory
local function makeLine() local l=Drawing.new("Line"); l.Visible=false; l.Thickness=thicknessBase; l.Transparency=alphaBase; l.Color=Color3.new(1,1,1); return l end
local function makeText() local t=Drawing.new("Text"); t.Visible=false; t.Center=true; t.Size=nameSize; t.Outline=true; t.Transparency=1; t.Color=Color3.new(1,1,1); return t end
local function makeSquare() local s=Drawing.new("Square"); s.Visible=false; s.Filled=false; s.Thickness=thicknessBase; s.Transparency=alphaBase; s.Color=Color3.new(1,1,1); return s end
local function makeTri() local tr=Drawing.new("Triangle"); tr.Visible=false; tr.Thickness=1; tr.Filled=true; tr.Color=Color3.fromRGB(255,255,255); tr.Transparency=0.9; return tr end

local function ensureBundle(plr)
    if playerDraw[plr] then return playerDraw[plr] end
    local b={
        -- Skeleton
        torso=makeLine(), lower=makeLine(), head=makeLine(),
        luArm=makeLine(), llArm=makeLine(), lHand=makeLine(),
        ruArm=makeLine(), rlArm=makeLine(), rHand=makeLine(),
        luLeg=makeLine(), llLeg=makeLine(), ruLeg=makeLine(), rlLeg=makeLine(),
        -- 2D box & corners
        boxT=makeLine(), boxB=makeLine(), boxL=makeLine(), boxR=makeLine(),
        cTL1=makeLine(), cTL2=makeLine(), cTR1=makeLine(), cTR2=makeLine(),
        cBL1=makeLine(), cBL2=makeLine(), cBR1=makeLine(), cBR2=makeLine(),
        boxFill=makeSquare(),
        -- Tracer
        tracer=makeLine(),
        -- Text & HP
        nameText=makeText(),
        distText=makeText(),
        itemText=makeText(),
        hpBack=makeSquare(),
        hpBar=makeSquare(),
        -- Off-screen arrow
        arrow=makeTri(),
    }
    playerDraw[plr]=b; return b
end
local function hideBundle(b) if not b then return end for _,ln in pairs(b) do ln.Visible=false end end
local function cleanup(plr) local t=playerDraw[plr] if t then for _,ln in pairs(t) do ln:Remove() end end playerDraw[plr]=nil local sigs=espSignals[plr] if sigs then for _,c in ipairs(sigs) do if c then c:Disconnect() end end end espSignals[plr]=nil end

local function getParts(c)
    return {
        hum=c:FindFirstChildOfClass("Humanoid"),
        hrp=c:FindFirstChild("HumanoidRootPart"),
        head=c:FindFirstChild("Head"),
        torso=c:FindFirstChild("Torso") or c:FindFirstChild("UpperTorso"),
        lower=c:FindFirstChild("LowerTorso"),
        luArm=c:FindFirstChild("LeftUpperArm") or c:FindFirstChild("Left Arm"),
        llArm=c:FindFirstChild("LeftLowerArm"),
        lHand=c:FindFirstChild("LeftHand"),
        ruArm=c:FindFirstChild("RightUpperArm") or c:FindFirstChild("Right Arm"),
        rlArm=c:FindFirstChild("RightLowerArm"),
        rHand=c:FindFirstChild("RightHand"),
        luLeg=c:FindFirstChild("LeftUpperLeg") or c:FindFirstChild("Left Leg"),
        llLeg=c:FindFirstChild("LeftLowerLeg"),
        ruLeg=c:FindFirstChild("RightUpperLeg") or c:FindFirstChild("Right Leg"),
        rlLeg=c:FindFirstChild("RightLowerLeg")
    }
end

local function vp(v3) local v,o=Camera:WorldToViewportPoint(v3); return Vector2.new(v.X,v.Y),o end
local function dynamicThickness(dist)
    if not fadeByDistance then return thicknessBase, alphaBase end
    local t = clamp(dist / maxDistance, 0, 1)
    local th = lerp(thicknessNear, thicknessFar, t)
    local al = lerp(alphaBase, 0.35, t)
    return th, al
end

local function drawLine(line, p1, p2, col, th, al)
    if p1 and p2 then
        local a2,ao=vp(p1.Position); local b2,bo=vp(p2.Position)
        if ao and bo then
            line.From=a2; line.To=b2; line.Color=col; line.Visible=true
            line.Thickness=th; line.Transparency=al
        else line.Visible=false end
    else line.Visible=false end
end

local function computeBBox(model)
    local cf,size = model:GetBoundingBox()
    local hx,hy,hz = size.X/2,size.Y/2,size.Z/2
    local C={Vector3.new( hx, hy, hz),Vector3.new(-hx, hy, hz),Vector3.new( hx, hy,-hz),Vector3.new(-hx, hy,-hz),
             Vector3.new( hx,-hy, hz),Vector3.new(-hx,-hy, hz),Vector3.new( hx,-hy,-hz),Vector3.new(-hx,-hy,-hz)}
    local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
    local any=false
    for _,corner in ipairs(C) do
        local world=cf:PointToWorldSpace(corner)
        local v,on=Camera:WorldToViewportPoint(world)
        if on then any=true end
        minX=math.min(minX,v.X); minY=math.min(minY,v.Y)
        maxX=math.max(maxX,v.X); maxY=math.max(maxY,v.Y)
    end
    return minX,minY,maxX,maxY,any
end

local function drawLineBox(lines, tl, tr, bl, br, col, th, al)
    lines.boxT.From=tl; lines.boxT.To=tr; lines.boxT.Color=col; lines.boxT.Visible=true
    lines.boxB.From=bl; lines.boxB.To=br; lines.boxB.Color=col; lines.boxB.Visible=true
    lines.boxL.From=tl; lines.boxL.To=bl; lines.boxL.Color=col; lines.boxL.Visible=true
    lines.boxR.From=tr; lines.boxR.To=br; lines.boxR.Color=col; lines.boxR.Visible=true
    lines.boxT.Thickness=th; lines.boxB.Thickness=th; lines.boxL.Thickness=th; lines.boxR.Thickness=th
    lines.boxT.Transparency=al; lines.boxB.Transparency=al; lines.boxL.Transparency=al; lines.boxR.Transparency=al
end

local function drawCorners(b, tl,tr,bl,br, col, th, al)
    local L = cornerLen
    local set = function(ln, a, b)
        ln.From = a; ln.To = b; ln.Color = col; ln.Visible = true; ln.Thickness = th; ln.Transparency = al
    end
    set(b.cTL1, tl, tl + Vector2.new(L,0))
    set(b.cTL2, tl, tl + Vector2.new(0,L))
    set(b.cTR1, tr, tr + Vector2.new(-L,0))
    set(b.cTR2, tr, tr + Vector2.new(0,L))
    set(b.cBL1, bl, bl + Vector2.new(L,0))
    set(b.cBL2, bl, bl + Vector2.new(0,-L))
    set(b.cBR1, br, br + Vector2.new(-L,0))
    set(b.cBR2, br, br + Vector2.new(0,-L))
end

local function tracerAnchor()
    if tracerOrigin=="Center" then return Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
    elseif tracerOrigin=="Mouse" then local m=UIS:GetMouseLocation(); return Vector2.new(m.X,m.Y)
    else return Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y) end
end

local function getEquippedToolName(ch)
    if not ch then return nil end
    for _,obj in ipairs(ch:GetChildren()) do
        if obj:IsA("Tool") then return obj.Name end
    end
    return nil
end

local function drawArrow(tri, worldPos, color, dist)
    local vpSize = Camera.ViewportSize
    local center = Vector2.new(vpSize.X/2, vpSize.Y/2)
    local p, on = Camera:WorldToViewportPoint(worldPos)
    local p2 = Vector2.new(p.X, p.Y)
    if on then tri.Visible=false return end

    local dir = (p2 - center)
    local mag = dir.Magnitude
    if mag < 1e-3 then tri.Visible=false return end
    dir = dir / mag

    local radius = arrowRadiusFactor * math.min(vpSize.X, vpSize.Y)
    local tip = center + dir * radius
    local baseCenter = tip - dir * arrowSize
    local perp = Vector2.new(-dir.Y, dir.X)

    local left = baseCenter + perp * (arrowSize * 0.5)
    local right = baseCenter - perp * (arrowSize * 0.5)

    tri.PointA = tip
    tri.PointB = left
    tri.PointC = right
    tri.Color = color
    tri.Transparency = arrowFadeWithDistance and clamp(1 - (dist / maxDistance), 0.25, 0.95) or 0.9
    tri.Visible = true
end

local function updateOne(plr)
    if not hasDrawing then return end
    if plr==LP or friendList[plr.Name] or (espTeamCheck and sameTeam(plr)) then local b=playerDraw[plr]; if b then hideBundle(b) end return end

    local ch=plr.Character; if not ch then local b=playerDraw[plr]; if b then hideBundle(b) end return end
    local P=getParts(ch)
    local hum=P.hum
    if hum and hum.Health<=0 then local b=playerDraw[plr]; if b then hideBundle(b) end return end
    if not P.hrp then local b=playerDraw[plr]; if b then hideBundle(b) end return end

    local camPos = Camera.CFrame.Position
    local dist = (P.hrp.Position - camPos).Magnitude
    if dist > maxDistance then local b=playerDraw[plr]; if b then hideBundle(b) end return end

    local vis = isVisibleLOS(P.hrp, ch) or (P.torso and isVisibleLOS(P.torso, ch))
    if onlyVisible and not vis then local b=playerDraw[plr]; if b then hideBundle(b) end return end

    local passive = passiveESPEnabled and characterIsPassive(ch) or false

    local baseCol = vis and visibleColor or occludedColor
    if useTeamColors and plr.TeamColor then baseCol = plr.TeamColor.Color end
    local col = baseCol
    local th, al = dynamicThickness(dist)

    local b=ensureBundle(plr)

    -- Skeleton
    if showSkeleton then
        if P.torso then
            drawLine(b.torso,P.torso,P.hrp,col,th,al)
            drawLine(b.head,P.head,P.torso,col,th,al)
            drawLine(b.lower,P.lower or P.torso,P.torso,col,th,al)
        else b.torso.Visible=false b.head.Visible=false b.lower.Visible=false end
        drawLine(b.luArm,P.luArm,P.torso or P.hrp,col,th,al); if P.llArm then drawLine(b.llArm,P.llArm,P.luArm,col,th,al) else b.llArm.Visible=false end
        if P.lHand then drawLine(b.lHand,P.lHand,P.llArm or P.luArm,col,th,al) else b.lHand.Visible=false end
        drawLine(b.ruArm,P.ruArm,P.torso or P.hrp,col,th,al); if P.rlArm then drawLine(b.rlArm,P.rlArm,P.ruArm,col,th,al) else b.rlArm.Visible=false end
        if P.rHand then drawLine(b.rHand,P.rHand,P.rlArm or P.ruArm,col,th,al) else b.rHand.Visible=false end
        local pelvis=P.lower or P.torso or P.hrp
        drawLine(b.luLeg,P.luLeg,pelvis,col,th,al); if P.llLeg then drawLine(b.llLeg,P.llLeg,P.luLeg,col,th,al) else b.llLeg.Visible=false end
        drawLine(b.ruLeg,P.ruLeg,pelvis,col,th,al); if P.rlLeg then drawLine(b.rlLeg,P.rlLeg,P.ruLeg,col,th,al) else b.rlLeg.Visible=false end
    else
        b.torso.Visible=false b.head.Visible=false b.lower.Visible=false
        b.luArm.Visible=false b.llArm.Visible=false b.lHand.Visible=false
        b.ruArm.Visible=false b.rlArm.Visible=false b.rHand.Visible=false
        b.luLeg.Visible=false b.llLeg.Visible=false b.ruLeg.Visible=false b.rlLeg.Visible=false
    end

    -- Boxes
    local minX,minY,maxX,maxY,onScr = computeBBox(ch)
    local tl,tr,bl,br=Vector2.new(minX,minY),Vector2.new(maxX,minY),Vector2.new(minX,maxY),Vector2.new(maxX,maxY)

    if showBoxes and onScr then
        drawLineBox(b, tl,tr,bl,br, col, th, al)
        if showCornerBox then drawCorners(b, tl,tr,bl,br, col, th+0.5, al) else
            b.cTL1.Visible=false b.cTL2.Visible=false b.cTR1.Visible=false b.cTR2.Visible=false
            b.cBL1.Visible=false b.cBL2.Visible=false b.cBR1.Visible=false b.cBR2.Visible=false
        end
        if showFilledBox then
            b.boxFill.Filled = true
            b.boxFill.Color = col
            b.boxFill.Transparency = clamp(fillAlpha, 0, 1)
            b.boxFill.Position = tl
            b.boxFill.Size = Vector2.new(maxX-minX, maxY-minY)
            b.boxFill.Visible = true
        else
            b.boxFill.Visible=false
        end
    else
        b.boxT.Visible=false b.boxB.Visible=false b.boxL.Visible=false b.boxR.Visible=false
        b.cTL1.Visible=false b.cTL2.Visible=false b.cTR1.Visible=false b.cTR2.Visible=false
        b.cBL1.Visible=false b.cBL2.Visible=false b.cBR1.Visible=false b.cBR2.Visible=false
        b.boxFill.Visible=false
    end

    -- Health bar
    if showHealth and hum and onScr then
        local hp = hum.Health
        local mh = math.max(1, hum.MaxHealth)
        local pct = clamp(hp/mh, 0, 1)
        local bw = 4
        local height = (maxY - minY)
        local filled = height * pct
        b.hpBack.Filled = true
        b.hpBack.Color = Color3.fromRGB(30,30,30)
        b.hpBack.Transparency = 0.6
        b.hpBack.Position = Vector2.new(minX - (bw+3), minY)
        b.hpBack.Size = Vector2.new(bw, height)
        b.hpBack.Visible = true

        b.hpBar.Filled = true
        b.hpBar.Color = healthColor(hp, mh)
        b.hpBar.Transparency = 0.2
        b.hpBar.Position = Vector2.new(minX - (bw+3), maxY - filled)
        b.hpBar.Size = Vector2.new(bw, filled)
        b.hpBar.Visible = true
    else
        b.hpBack.Visible=false
        b.hpBar.Visible=false
    end

    -- Name / Distance / Passive tag / Item
    local nameY = math.max(0, minY - 14)
    if showNames and onScr then
        local baseName = plr.Name
        if passive and passiveESPEnabled then
            baseName = baseName .. passiveTagText
            b.nameText.Color = passiveTagColor
        else
            b.nameText.Color = col
        end
        b.nameText.Text = baseName
        b.nameText.Position = Vector2.new((minX+maxX)/2, nameY)
        b.nameText.Size = nameSize
        b.nameText.Visible = true
    else b.nameText.Visible=false end

    if showDistance and onScr then
        b.distText.Text = string.format("%.0f", dist).."s"
        b.distText.Color = Color3.fromRGB(220,220,220)
        b.distText.Position = Vector2.new((minX+maxX)/2, maxY + 12)
        b.distText.Size = infoSize
        b.distText.Visible = true
    else b.distText.Visible=false end

    if itemESPEnabled and onScr then
        local toolName = getEquippedToolName(ch)
        if toolName or itemESPShowWhenNoTool then
            b.itemText.Text = toolName or ""
            b.itemText.Color = itemESPColor
            b.itemText.Position = Vector2.new((minX+maxX)/2, nameY + itemESPOffsetY)
            b.itemText.Size = itemESPSize
            b.itemText.Visible = (toolName ~= nil) or itemESPShowWhenNoTool
        else
            b.itemText.Visible = false
        end
    else
        b.itemText.Visible = false
    end

    -- Tracer
    if showTracers and onScr then
        local pos,_=Camera:WorldToViewportPoint(P.hrp.Position)
        b.tracer.From=tracerAnchor()
        b.tracer.To=Vector2.new(pos.X,pos.Y)
        b.tracer.Color=col
        b.tracer.Thickness=th
        b.tracer.Transparency=al
        b.tracer.Visible=true
    else b.tracer.Visible=false end

    -- Off-screen arrows
    if arrowsEnabled and not onScr then
        local arrowCol
        if passive and passiveESPEnabled then
            arrowCol = passiveTagColor
        else
            arrowCol = arrowsUseTeamColors and (plr.TeamColor and plr.TeamColor.Color or col) or arrowBaseColor
        end
        drawArrow(b.arrow, P.hrp.Position, arrowCol, dist)
    else
        b.arrow.Visible = false
    end
end

local function updateAll() for _,p in ipairs(Players:GetPlayers()) do updateOne(p) end end
local function hookPerPlayerSignals(plr)
    espSignals[plr]=espSignals[plr] or {}
    table.insert(espSignals[plr], plr.CharacterRemoving:Connect(function() local b=playerDraw[plr] if b then hideBundle(b) end end))
end
local function enableESP()
    if not hasDrawing then notify("KittenWare","ESP needs Drawing API",4) return end
    if espConn then espConn:Disconnect() end
    espEnabled = true
    espConn=RunService.RenderStepped:Connect(updateAll)
    if not playersSignal then playersSignal=Players.PlayerRemoving:Connect(function(plr) cleanup(plr) end) end
    if not playerAddedConn then playerAddedConn=Players.PlayerAdded:Connect(function(plr) hookPerPlayerSignals(plr) end) end
    for _,plr in ipairs(Players:GetPlayers()) do hookPerPlayerSignals(plr) end
end
local function disableESP()
    espEnabled=false
    if espConn then espConn:Disconnect() espConn=nil end
    if playersSignal then playersSignal:Disconnect() playersSignal=nil end
    if playerAddedConn then playerAddedConn:Disconnect() playerAddedConn=nil end
    for plr in pairs(playerDraw) do cleanup(plr) end
end

-- ESP UI (organized)
do
    local L=Visual:Section({Name="Core", Side="Left"})
    L:Toggle({Name="Enable ESP",Flag="KW_ESP",Default=false,Callback=function(v) if v then enableESP() else disableESP() end end})
    L:Toggle({Name="Team Check",Flag="KW_ESP_TEAM",Default=false,Callback=function(v) espTeamCheck=v end})
    L:Toggle({Name="Use Team Colors",Flag="KW_ESP_TCOL",Default=false,Callback=function(v) useTeamColors=v end})
    L:Toggle({Name="Only Visible (LOS)",Flag="KW_ESP_VIS",Default=false,Callback=function(v) onlyVisible=v end})
    L:Slider({Name="Max Distance",Flag="KW_ESP_DIST",Default=maxDistance,Min=200,Max=6000,Callback=function(v) maxDistance=v end})
    L:Toggle({Name="Fade By Distance",Flag="KW_ESP_FBD",Default=true,Callback=function(v) fadeByDistance=v end})
    L:Slider({Name="Base Thickness",Flag="KW_ESP_TB",Default=math.floor(thicknessBase),Min=1,Max=6,Callback=function(v) thicknessBase=v end})
    L:Slider({Name="Near Thickness",Flag="KW_ESP_TN",Default=math.floor(thicknessNear),Min=1,Max=8,Callback=function(v) thicknessNear=v end})
    L:Slider({Name="Far Thickness",Flag="KW_ESP_TF",Default=math.floor(thicknessFar),Min=1,Max=6,Callback=function(v) thicknessFar=v end})
    L:Slider({Name="Base Alpha x10",Flag="KW_ESP_AL",Default=math.floor(alphaBase*10),Min=3,Max=10,Callback=function(v) alphaBase=v/10 end})

    local R=Visual:Section({Name="Elements", Side="Right"})
    R:Toggle({Name="Skeleton",Flag="KW_ESPSkel",Default=true,Callback=function(v) showSkeleton=v end})
    R:Toggle({Name="Box (outline)",Flag="KW_ESPBox",Default=true,Callback=function(v) showBoxes=v end})
    R:Toggle({Name="Corner Box",Flag="KW_ESPCorner",Default=true,Callback=function(v) showCornerBox=v end})
    R:Slider({Name="Corner Length",Flag="KW_ESP_CL",Default=cornerLen,Min=4,Max=24,Callback=function(v) cornerLen=v end})
    R:Toggle({Name="Filled Box",Flag="KW_ESPFBox",Default=false,Callback=function(v) showFilledBox=v end})
    R:Slider({Name="Fill Alpha %",Flag="KW_ESPFill",Default=math.floor(fillAlpha*100),Min=5,Max=80,Callback=function(v) fillAlpha = clamp(v/100, 0.05, 0.8) end})
    R:Toggle({Name="Tracers",Flag="KW_ESPTracer",Default=true,Callback=function(v) showTracers=v end})
    R:Dropdown({Name="Tracer Origin",Flag="KW_TR_ORG",Content={"Bottom","Center","Mouse"},Default="Bottom",Callback=function(v) tracerOrigin=v end})
    R:Toggle({Name="Name Tags",Flag="KW_ESPName",Default=true,Callback=function(v) showNames=v end})
    R:Toggle({Name="Health Bar",Flag="KW_ESPHP",Default=true,Callback=function(v) showHealth=v end})
    R:Toggle({Name="Distance",Flag="KW_ESPDist",Default=true,Callback=function(v) showDistance=v end})
end

-- Item ESP UI
do
    local I = Visual:Section({Name="Item ESP", Side="Left"})
    I:Toggle({Name="Enabled", Flag="KW_ITEM_EN", Default=itemESPEnabled, Callback=function(v) itemESPEnabled=v end})
    I:Colorpicker({Name="Text Color", Flag="KW_ITEM_COL", Default=itemESPColor, Callback=function(c) itemESPColor=c end})
    I:Slider({Name="Text Size", Flag="KW_ITEM_SZ", Default=itemESPSize, Min=10, Max=22, Callback=function(v) itemESPSize=math.floor(v) end})
    I:Slider({Name="Offset Y", Flag="KW_ITEM_OFY", Default=itemESPOffsetY, Min=8, Max=28, Callback=function(v) itemESPOffsetY=math.floor(v) end})
    I:Toggle({Name="Show When No Tool", Flag="KW_ITEM_SNT", Default=false, Callback=function(v) itemESPShowWhenNoTool=v end})
end

-- Off-screen Arrows UI
do
    local A = Visual:Section({Name="Off-Screen Arrows", Side="Right"})
    A:Toggle({Name="Enabled", Flag="KW_AR_EN", Default=arrowsEnabled, Callback=function(v) arrowsEnabled=v end})
    A:Toggle({Name="Use Team Colors", Flag="KW_AR_TC", Default=arrowsUseTeamColors, Callback=function(v) arrowsUseTeamColors=v end})
    A:Toggle({Name="Fade With Distance", Flag="KW_AR_FD", Default=arrowFadeWithDistance, Callback=function(v) arrowFadeWithDistance=v end})
    A:Colorpicker({Name="Base Color", Flag="KW_AR_COL", Default=arrowBaseColor, Callback=function(c) arrowBaseColor=c end})
    A:Slider({Name="Arrow Size (px)", Flag="KW_AR_SZ", Default=arrowSize, Min=10, Max=40, Callback=function(v) arrowSize=math.floor(v) end})
    A:Slider({Name="Radius Factor %", Flag="KW_AR_RF", Default=math.floor(arrowRadiusFactor*100), Min=30, Max=49, Callback=function(v) arrowRadiusFactor=clamp(v/100,0.30,0.49) end})
end

-- Passive Check UI
do
    local P = Visual:Section({Name="Passive Check (ForceField)", Side="Left"})
    P:Toggle({Name="Show (P) on Passive", Flag="KW_PASSIVE_ESP", Default=passiveESPEnabled, Callback=function(v) passiveESPEnabled=v end})
    P:Colorpicker({Name="Passive Tag Color", Flag="KW_PASSIVE_COL", Default=passiveTagColor, Callback=function(c) passiveTagColor=c end})
end

----------------------------------------------------------------
-- Aimbot (Wall Check + Distance + HUD + Passive Check)
----------------------------------------------------------------
local aimEnabled=false
local aimHoldToUse=false
local aimKey=Enum.KeyCode.Q
local aimHoldKey=Enum.UserInputType.MouseButton2
local aimTargetPartName="Head"
local aimSmoothing=0.18
local aimFOV=150
local aimTeamCheck=false
local aimWallCheck=true
local aimMaxDistance = 1200
local showTargetHUD = true

local aimConn
local fovCircle, targetHUD
if hasDrawing then
    fovCircle=Drawing.new("Circle")
    fovCircle.Visible=false
    fovCircle.Filled=false
    fovCircle.Thickness=1.5
    fovCircle.Transparency=0.9
    fovCircle.Color=Color3.fromRGB(180,220,255)

    targetHUD=Drawing.new("Text")
    targetHUD.Visible=false
    targetHUD.Center=true
    targetHUD.Size=14
    targetHUD.Outline=true
    targetHUD.Color=Color3.fromRGB(230,230,255)
    targetHUD.Text=""
end
local function setFOVVisible(v) if fovCircle then fovCircle.Visible=v end end
local function updateFOVCircle()
    if not fovCircle then return end
    local m=UIS:GetMouseLocation()
    fovCircle.Position=Vector2.new(m.X,m.Y)
    fovCircle.Radius=aimFOV
end
local function setTargetHUD(txt, pos)
    if not targetHUD then return end
    if showTargetHUD and txt then
        targetHUD.Text = txt
        targetHUD.Position = pos or Vector2.new(Camera.ViewportSize.X/2, 40)
        targetHUD.Visible = true
    else
        targetHUD.Visible = false
    end
end
local function screenPoint(part) local v,o=Camera:WorldToViewportPoint(part.Position) return Vector2.new(v.X,v.Y),o end
local function sameTeamAim(plr) return aimTeamCheck and ((LP.Team and plr.Team and LP.Team==plr.Team) or (LP.TeamColor and plr.TeamColor and LP.TeamColor==plr.TeamColor)) end
local function clearLOSTo(part, targetChar)
    if not aimWallCheck then return true end
    local origin = Camera.CFrame.Position
    local dir = (part.Position - origin)
    local rp = RaycastParams.new()
    rp.FilterType = Enum.RaycastFilterType.Blacklist
    rp.FilterDescendantsInstances = {LP.Character, targetChar}
    return Workspace:Raycast(origin, dir, rp) == nil
end
local function getClosestTarget(fovCap, distCap)
    local m=UIS:GetMouseLocation(); local closest,bestDist=nil,math.huge
    local camPos = Camera.CFrame.Position
    for _,plr in ipairs(Players:GetPlayers()) do
        if plr~=LP and plr.Character and not sameTeamAim(plr) then
            local ch = plr.Character
            -- Passive ignore
            if not (passiveAimbotIgnore and characterIsPassive(ch)) then
                local hum=ch:FindFirstChildOfClass("Humanoid") if hum and hum.Health>0 then
                    local part=ch:FindFirstChild(aimTargetPartName) or ch:FindFirstChild("HumanoidRootPart")
                    if part then
                        local worldDist = (part.Position - camPos).Magnitude
                        if worldDist <= distCap then
                            local pos,on=screenPoint(part)
                            if on and clearLOSTo(part, ch) then
                                local d=(pos-Vector2.new(m.X,m.Y)).Magnitude
                                if d<=fovCap and d<bestDist then
                                    closest,bestDist=part,d
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return closest
end
local function aimAt(part)
    if not part then return end
    local cf=Camera.CFrame
    local target=CFrame.new(cf.Position,part.Position)
    Camera.CFrame=cf:Lerp(target,clamp(aimSmoothing,0.01,1))
end
local holding=false
UIS.InputBegan:Connect(function(i,gpe) if gpe then return end if i.UserInputType==aimHoldKey then holding=true end if i.KeyCode==aimKey then aimEnabled=not aimEnabled setFOVVisible(aimEnabled) end end)
UIS.InputEnded:Connect(function(i,gpe) if i.UserInputType==aimHoldKey then holding=false end end)
local function stepAimbot()
    if not aimEnabled then updateFOVCircle() setTargetHUD(nil) return end
    if aimHoldToUse and not holding then updateFOVCircle() setTargetHUD(nil) return end
    local t=getClosestTarget(aimFOV, aimMaxDistance)
    if t then
        aimAt(t)
        local ch = t.Parent
        local plr = ch and Players:GetPlayerFromCharacter(ch)
        local who = plr and plr.Name or "Target"
        local dist = (t.Position - Camera.CFrame.Position).Magnitude
        local isP = ch and characterIsPassive(ch)
        if isP then who = who .. " (P)" end
        setTargetHUD(string.format("%s  •  %.0fs", who, dist), Vector2.new(Camera.ViewportSize.X/2, 40))
    else
        setTargetHUD(nil)
    end
    updateFOVCircle()
end
local function enableAimbot() if aimConn then aimConn:Disconnect() end aimConn=RunService.RenderStepped:Connect(stepAimbot) setFOVVisible(true) end
local function disableAimbot() if aimConn then aimConn:Disconnect() aimConn=nil end setFOVVisible(false) setTargetHUD(nil) end

do
    local L=Combat:Section({Name="Aimbot • Core",Side="Left"})
    L:Toggle({Name="Enabled",Flag="KW_AIM_EN",Default=false,Callback=function(v) if v then enableAimbot() else disableAimbot() end end})
    L:Toggle({Name="Hold RMB",Flag="KW_AIM_HOLD",Default=false,Callback=function(v) aimHoldToUse=v end})
    L:Keybind({Name="Toggle Key",Flag="KW_AIM_KEY",Default=Enum.KeyCode.Q,Callback=function(k) if typeof(k)=="EnumItem" then aimKey=k end end})

    local R=Combat:Section({Name="Aimbot • Filters & Feel",Side="Right"})
    R:Toggle({Name="Team Check",Flag="KW_AIM_TEAM",Default=false,Callback=function(v) aimTeamCheck=v end})
    R:Toggle({Name="Wall Check (LOS)",Flag="KW_AIM_WALL",Default=true,Callback=function(v) aimWallCheck=v end})
    R:Toggle({Name="Ignore Passive (ForceField)",Flag="KW_AIM_PASSIVE",Default=true,Callback=function(v) passiveAimbotIgnore=v end})
    R:Slider({Name="Max Distance (studs)",Flag="KW_AIM_MAXD",Default=aimMaxDistance,Min=200,Max=6000,Callback=function(v) aimMaxDistance=v end})
    R:Dropdown({Name="Target Part",Flag="KW_AIM_PART",Content={"Head","HumanoidRootPart"},Default="Head",Callback=function(v) aimTargetPartName=v end})
    R:Slider({Name="FOV",Flag="KW_AIM_FOV",Default=aimFOV,Min=40,Max=600,Callback=function(v) aimFOV=v end})
    R:Slider({Name="Smooth",Flag="KW_AIM_SM",Default=math.floor(aimSmoothing*100),Min=1,Max=100,Callback=function(v) aimSmoothing=clamp(v/100,0.01,1) end})
    R:Toggle({Name="HUD (name + distance)",Flag="KW_AIM_HUD",Default=true,Callback=function(v) showTargetHUD=v if not v then setTargetHUD(nil) end end})
end

----------------------------------------------------------------
-- Insta Reload (speed multiplier)
----------------------------------------------------------------
local irEnabled = true
local irSpeed = 4.0        -- AdjustSpeed on reload animations
local irCooldownMs = 300   -- per track cooldown
local irScanInterval = 0.06
local irConn
local irAccum = 0
local lastTouched = {} -- [track] = os.clock()

local function isReloadTrack(track)
    local n = (track.Name or ""):lower()
    if n:find("reload") or n:find("mag") or n:find("clip") then return true end
    local anim = track.Animation
    if anim and anim.AnimationId then
        local id = tostring(anim.AnimationId):lower()
        if id:find("reload") or id:find("mag") or id:find("clip") then return true end
    end
    return false
end

local function instaReloadStep(dt)
    irAccum += dt
    if irAccum < irScanInterval then return end
    irAccum = 0

    if not irEnabled then return end
    local ch = LP.Character
    if not ch then return end
    local hum = ch:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local animator = hum:FindFirstChildOfClass("Animator")
    if not animator then return end

    for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
        if isReloadTrack(track) then
            local now = os.clock()
            if lastTouched[track] and (now - lastTouched[track]) * 1000 < irCooldownMs then
                -- cooling down
            else
                lastTouched[track] = now
                pcall(function()
                    track:AdjustSpeed(clamp(irSpeed, 1, 20))
                end)
            end
        end
    end
end

local function enableInstaReload()
    if irConn then irConn:Disconnect() end
    irEnabled = true
    irAccum = 0
    irConn = RunService.Heartbeat:Connect(instaReloadStep)
end
local function disableInstaReload()
    irEnabled = false
    if irConn then irConn:Disconnect() irConn=nil end
end

do
    local L = Combat:Section({Name="Insta Reload (Speed)", Side="Left"})
    L:Toggle({Name="Enabled", Flag="KW_IR_EN", Default=true, Callback=function(v) if v then enableInstaReload() else disableInstaReload() end end})
    L:Slider({Name="Reload Speed ×", Flag="KW_IR_SPD", Default=irSpeed, Min=1, Max=20, Callback=function(v) irSpeed = v end})

    local R = Combat:Section({Name="Insta Reload • Advanced", Side="Right"})
    R:Slider({Name="Per-Reload Cooldown (ms)", Flag="KW_IR_CD", Default=irCooldownMs, Min=100, Max=1000, Callback=function(v) irCooldownMs = math.floor(v) end})
    R:Slider({Name="Scan Interval (ms)", Flag="KW_IR_IV", Default=math.floor(irScanInterval*1000), Min=30, Max=150, Callback=function(v) irScanInterval = clamp(v/1000, 0.03, 0.15) end})
end

----------------------------------------------------------------
-- World / Camera (Fullbright & FOV)
----------------------------------------------------------------
local fbEnabled, fbConn=false,nil
local fbBrightness, fbClock, fbNoShadows=3,14,true
local fogEnabled=true
local savedLighting, cc = {}, nil
local function saveLighting() savedLighting.Ambient=Lighting.Ambient; savedLighting.OutdoorAmbient=Lighting.OutdoorAmbient; savedLighting.Brightness=Lighting.Brightness; savedLighting.ClockTime=Lighting.ClockTime; savedLighting.GlobalShadows=Lighting.GlobalShadows; savedLighting.FogStart=Lighting.FogStart; savedLighting.FogEnd=Lighting.FogEnd end
local function applyFullbrightOnce() Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1); Lighting.Brightness=fbBrightness; Lighting.ClockTime=fbClock; Lighting.GlobalShadows=not fbNoShadows; if not fogEnabled then Lighting.FogStart=0 Lighting.FogEnd=1e6 end if not cc then cc=Instance.new("ColorCorrectionEffect") cc.Name="KW_Fullbright" cc.Brightness=0.05 cc.Contrast=0.05 cc.Saturation=0.05 cc.Parent=Lighting end end
local function enableFullbright() if fbEnabled then return end saveLighting() applyFullbrightOnce() fbConn=RunService.RenderStepped:Connect(applyFullbrightOnce) fbEnabled=true end
local function disableFullbright() if not fbEnabled then return end fbEnabled=false if fbConn then fbConn:Disconnect() fbConn=nil end if cc then cc:Destroy() cc=nil end for k,v in pairs(savedLighting) do Lighting[k]=v end end
local fovValue=80; local fovConn
local function enableFOVLock() if fovConn then fovConn:Disconnect() end fovConn=RunService.RenderStepped:Connect(function() Camera.FieldOfView=fovValue end) end
local function disableFOVLock() if fovConn then fovConn:Disconnect() fovConn=nil end end

do
    local L=Utility:Section({Name="Fullbright",Side="Left"})
    L:Toggle({Name="Enabled (lock)",Flag="KW_FB",Default=false,Callback=function(v) if v then enableFullbright() else disableFullbright() end end})
    L:Slider({Name="Brightness",Flag="KW_FB_BR",Default=fbBrightness,Min=1,Max=6,Callback=function(v) fbBrightness=v end})
    L:Slider({Name="Time (Clock)",Flag="KW_FB_TM",Default=fbClock,Min=0,Max=24,Callback=function(v) fbClock=v end})
    L:Toggle({Name="No Shadows",Flag="KW_FB_NS",Default=fbNoShadows,Callback=function(v) fbNoShadows=v end})
    L:Toggle({Name="No Fog",Flag="KW_FB_NF",Default=true,Callback=function(v) fogEnabled=v end})

    local R=Utility:Section({Name="Camera (FOV)",Side="Right"})
    R:Toggle({Name="FOV Lock",Flag="KW_FOV_L",Default=false,Callback=function(v) if v then enableFOVLock() else disableFOVLock() end end})
    R:Slider({Name="FOV",Flag="KW_FOV_V",Default=fovValue,Min=40,Max=120,Callback=function(v) fovValue=v end})
end

----------------------------------------------------------------
-- Settings / Hotkeys / Lifecycle
----------------------------------------------------------------
local S = Settings:Section({Name="General", Side="Left"})
S:Keybind({Name="Toggle UI", Flag="KW_UI", Default=Enum.KeyCode.RightShift, Callback=function(_, newKey) if not newKey then GUI:Close() end end})
S:Button({Name="Unload", Callback=function()
    -- orderly shutdown
    if espEnabled then disableESP() end
    disableAimbot(); disableNR(); disableFullbright(); disableInstaReload()
    GUI:Unload(); getgenv().KittenWareLoaded=nil
end})

local H = Settings:Section({Name="Quick Hotkeys", Side="Right"})
H:Label("N  - Toggle No Recoil")
H:Label("B  - Toggle ESP")
UIS.InputBegan:Connect(function(i,gpe)
    if gpe then return end
    if i.KeyCode==Enum.KeyCode.N then if nrEnabled then disableNR() else enableNR() end
    elseif i.KeyCode==Enum.KeyCode.B then if espEnabled then disableESP() else enableESP() end end
end)

game:BindToClose(function()
    if espEnabled then disableESP() end
    disableAimbot(); disableNR(); disableFullbright(); disableInstaReload()
end)

-- start systems
enableInstaReload()

getgenv().KittenWareLoaded = true
getgenv().KittenWareLoading = nil
-- UI left open
