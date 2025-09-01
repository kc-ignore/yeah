print([[
KuromiWare On Top
==========================================================
|                        KuromiWare                      |
|--------------------------------------------------------|
| Version: v1                                            |
|                                                        |
| Undected: Maybe:3                                      |
| Loaded? Yes! Thanks for using KittenWare!              |
| Status: Loaded and ready to use!                       |
==========================================================
]])

if getgenv().KittenWareLoaded or getgenv().KittenWareLoading then return end
getgenv().KittenWareLoading = true

----------------------------------------------------------------
-- Services & Locals
----------------------------------------------------------------
local Players     = game:GetService("Players")
local RunService  = game:GetService("RunService")
local UIS         = game:GetService("UserInputService")
local StarterGui  = game:GetService("StarterGui")
local Lighting    = game:GetService("Lighting")
local Workspace   = game:GetService("Workspace")
local Stats       = game:GetService("Stats")
local MPS         = game:GetService("MarketplaceService")

local LP          = Players.LocalPlayer
local Camera      = Workspace.CurrentCamera

local function notify(t,x,d) pcall(function() StarterGui:SetCore("SendNotification",{Title=t,Text=x,Duration=d or 3}) end) end
local function clamp(v,a,b) return (v<a) and a or ((v>b) and b or v) end
local function lerp(a,b,t) return a + (b-a)*t end

----------------------------------------------------------------
-- UI (Exunys)
----------------------------------------------------------------
loadstring(game:HttpGet("https://raw.githubusercontent.com/Exunys/Roblox-Functions-Library/main/Library.lua"))()
local GUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/kitty92pm/AirHub-V2/refs/heads/main/src/UI%20Library.lua"))()

-- Tabs
local MainUI   = GUI:Load()
local Combat   = MainUI:Tab("Combat")
local ESPTab   = MainUI:Tab("Visual")
local World    = MainUI:Tab("World")
local HUDTab   = MainUI:Tab("HUD")
local Config   = MainUI:Tab("Whitelist")
local About    = MainUI:Tab("Settings")

----------------------------------------------------------------
-- GLOBAL COLORS
----------------------------------------------------------------
local Theme = {
  Accent       = Color3.fromRGB(170, 120, 255),
  Good         = Color3.fromRGB(50, 220, 140),
  Danger       = Color3.fromRGB(255, 120, 120),
  Secondary    = Color3.fromRGB(230, 230, 235),
  PanelDark    = Color3.fromRGB(20, 20, 26),
  PanelMid     = Color3.fromRGB(40, 40, 55),
}

----------------------------------------------------------------
-- No Recoil (rename "Recoil" tags)
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

Combat:Section({Name="No Recoil", Side="Left"})
:Toggle({Name="Enabled",Flag="KW_NR",Default=false,Callback=function(v) if v then enableNR() else disableNR() end end})

----------------------------------------------------------------
-- ESP++ (Players + Drones) — Drawing API
----------------------------------------------------------------
local hasDrawing = (typeof(Drawing)=="table" and typeof(Drawing.new)=="function")
if not hasDrawing then notify("KuromiWare","Drawing API not found | ESP & HUD disabled.",5) end

local esp = {
  enabled          = false,
  conn             = nil,
  perfMode         = "Auto", -- Auto | Fast | Max
  updateEvery      = 1,
  counter          = 0,

  -- Players
  showSkeleton     = true,
  showBox          = true,
  showCornerBox    = true,
  showFilledBox    = false,
  cornerLen        = 8,
  fillAlpha        = 0.15,

  showTracers      = true,
  tracerOrigin     = "Bottom",

  showNames        = true,
  showHealth       = true,
  showDistance     = true,

  teamCheck        = false,
  useTeamColors    = false,
  onlyVisible      = false,
  passiveESP       = true,
  passiveTag       = " (P)",
  passiveColor     = Color3.fromRGB(150,210,255),

  maxDistance      = 2500,
  fadeByDistance   = true,
  visColor         = Color3.fromRGB(0,255,255),
  occColor         = Color3.fromRGB(255,100,100),
  thicknessBase    = 2.5,
  nearThick        = 3.0,
  farThick         = 1.0,
  alphaBase        = 0.9,

  itemESP          = true,
  itemESPColor     = Color3.fromRGB(255, 200, 120),
  itemSize         = 13,
  itemOffsetY      = 14,
  itemWhenNoTool   = false,

  -- Drones
  droneEnabled     = true,
  droneColor       = Color3.fromRGB(255, 180, 60),
  droneName        = "DRONE",
  droneMaxDist     = 3000,
  droneTracers     = true,
  droneFilled      = true,
  droneFillAlpha   = 0.12,
}

local whitelist, ignorelist = {}, {}

local function sameTeam(plr)
  if not esp.teamCheck then return false end
  if LP.Team and plr.Team then return LP.Team==plr.Team end
  if LP.TeamColor and plr.TeamColor then return LP.TeamColor==plr.TeamColor end
  return false
end

local function isPassive(char)
  if not char then return false end
  if char:FindFirstChildOfClass("ForceField") then return true end
  for _,bp in ipairs(char:GetDescendants()) do
    if bp:IsA("BasePart") and bp.Material==Enum.Material.ForceField then return true end
  end
  local hum = char:FindFirstChildOfClass("Humanoid")
  if hum and (hum:GetAttribute("Passive")==true or hum:GetAttribute("Invulnerable")==true) then return true end
  if char:GetAttribute("Passive")==true then return true end
  return false
end

local function parts(char)
  return {
    hum = char:FindFirstChildOfClass("Humanoid"),
    hrp = char:FindFirstChild("HumanoidRootPart"),
    head= char:FindFirstChild("Head"),
    torso= char:FindFirstChild("Torso") or char:FindFirstChild("UpperTorso"),
    lower= char:FindFirstChild("LowerTorso"),
    luArm= char:FindFirstChild("LeftUpperArm") or char:FindFirstChild("Left Arm"),
    llArm= char:FindFirstChild("LeftLowerArm"),
    lHand= char:FindFirstChild("LeftHand"),
    ruArm= char:FindFirstChild("RightUpperArm") or char:FindFirstChild("Right Arm"),
    rlArm= char:FindFirstChild("RightLowerArm"),
    rHand= char:FindFirstChild("RightHand"),
    luLeg= char:FindFirstChild("LeftUpperLeg") or char:FindFirstChild("Left Leg"),
    llLeg= char:FindFirstChild("LeftLowerLeg"),
    ruLeg= char:FindFirstChild("RightUpperLeg") or char:FindFirstChild("Right Leg"),
    rlLeg= char:FindFirstChild("RightLowerLeg"),
  }
end

local function vp(v3) local v,o=Camera:WorldToViewportPoint(v3); return Vector2.new(v.X,v.Y), o end

-- Drawing constructors
local function mkLine() local l=Drawing.new("Line") l.Visible=false l.Color=Color3.new(1,1,1) l.Thickness=esp.thicknessBase l.Transparency=esp.alphaBase return l end
local function mkText() local t=Drawing.new("Text") t.Visible=false t.Center=true t.Size=14 t.Outline=true t.Transparency=1 t.Color=Theme.Secondary return t end
local function mkSquare() local s=Drawing.new("Square") s.Visible=false s.Thickness=esp.thicknessBase s.Filled=false s.Color=Theme.Secondary s.Transparency=esp.alphaBase return s end

-- Player ESP buckets
local buckets, signalMap = {}, {}
local function getBucket(plr)
  if buckets[plr] then return buckets[plr] end
  local b = {
    torso=mkLine(), lower=mkLine(), head=mkLine(),
    luArm=mkLine(), llArm=mkLine(), lHand=mkLine(),
    ruArm=mkLine(), rlArm=mkLine(), rHand=mkLine(),
    luLeg=mkLine(), llLeg=mkLine(), ruLeg=mkLine(), rlLeg=mkLine(),
    boxT=mkLine(), boxB=mkLine(), boxL=mkLine(), boxR=mkLine(),
    cTL1=mkLine(), cTL2=mkLine(), cTR1=mkLine(), cTR2=mkLine(),
    cBL1=mkLine(), cBL2=mkLine(), cBR1=mkLine(), cBR2=mkLine(),
    boxFill=mkSquare(),
    tracer=mkLine(),
    nameText=mkText(),
    distText=mkText(),
    itemText=mkText(),
    hpBack=mkSquare(),
    hpBar=mkSquare(),
  }
  buckets[plr]=b; return b
end
local function hideBucket(b) if not b then return end for _,o in pairs(b) do o.Visible=false end end
local function cleanPlayer(plr)
  local b=buckets[plr]; if b then for _,o in pairs(b) do o:Remove() end end buckets[plr]=nil
  local sigs=signalMap[plr]; if sigs then for _,c in ipairs(sigs) do if c then c:Disconnect() end end end signalMap[plr]=nil
end

-- Drone ESP buckets
local droneMap = {}  -- [Model] = bucket
local function mkDroneBucket()
  return {
    boxT=mkLine(), boxB=mkLine(), boxL=mkLine(), boxR=mkLine(),
    fill=mkSquare(),
    tracer=mkLine(),
    label=mkText(),
    dist=mkText(),
  }
end
local function hideDroneBucket(b) if not b then return end for _,o in pairs(b) do o.Visible=false end end
local function cleanDrone(m) local b=droneMap[m]; if b then for _,o in pairs(b) do o:Remove() end end droneMap[m]=nil end

local function dynThickness(dist)
  if not esp.fadeByDistance then return esp.thicknessBase, esp.alphaBase end
  local t = clamp(dist/esp.maxDistance, 0, 1)
  return lerp(esp.nearThick, esp.farThick, t), lerp(esp.alphaBase, 0.35, t)
end

local function LOS(part, char)
  local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist
  rp.FilterDescendantsInstances={LP.Character, char}
  local origin=Camera.CFrame.Position
  local dir=part.Position-origin
  return Workspace:Raycast(origin,dir,rp)==nil
end

local function computeBBox(model)
  local cf,size = model:GetBoundingBox()
  local hx,hy,hz=size.X/2,size.Y/2,size.Z/2
  local C={Vector3.new( hx, hy, hz),Vector3.new(-hx, hy, hz),Vector3.new( hx, hy,-hz),Vector3.new(-hx, hy,-hz),
           Vector3.new( hx,-hy, hz),Vector3.new(-hx,-hy, hz),Vector3.new( hx,-hy,-hz),Vector3.new(-hx,-hy,-hz)}
  local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
  local on=false
  for _,c in ipairs(C) do
    local p=cf:PointToWorldSpace(c)
    local v,vis=Camera:WorldToViewportPoint(p)
    if vis then on=true end
    minX=math.min(minX,v.X); minY=math.min(minY,v.Y)
    maxX=math.max(maxX,v.X); maxY=math.max(maxY,v.Y)
  end
  return minX,minY,maxX,maxY,on
end

local function setLine(line,a,b,col,th,al)
  local av,ao=vp(a); local bv,bo=vp(b)
  if ao and bo then line.From=av line.To=bv line.Color=col line.Thickness=th line.Transparency=al line.Visible=true else line.Visible=false end
end

local function drawBoxLines(b,tl,tr,bl,br,col,th,al)
  b.boxT.From=tl; b.boxT.To=tr; b.boxT.Color=col; b.boxT.Thickness=th; b.boxT.Transparency=al; b.boxT.Visible=true
  b.boxB.From=bl; b.boxB.To=br; b.boxB.Color=col; b.boxB.Thickness=th; b.boxB.Transparency=al; b.boxB.Visible=true
  b.boxL.From=tl; b.boxL.To=bl; b.boxL.Color=col; b.boxL.Thickness=th; b.boxL.Transparency=al; b.boxL.Visible=true
  b.boxR.From=tr; b.boxR.To=br; b.boxR.Color=col; b.boxR.Thickness=th; b.boxR.Transparency=al; b.boxR.Visible=true
end

local function corners(b,tl,tr,bl,br,col,th,al,L)
  local function set(ln,a,b2) ln.From=a; ln.To=b2; ln.Color=col; ln.Thickness=th; ln.Transparency=al; ln.Visible=true end
  set(b.cTL1, tl, tl + Vector2.new(L,0)); set(b.cTL2, tl, tl + Vector2.new(0,L))
  set(b.cTR1, tr, tr + Vector2.new(-L,0)); set(b.cTR2, tr, tr + Vector2.new(0,L))
  set(b.cBL1, bl, bl + Vector2.new(L,0)); set(b.cBL2, bl, bl + Vector2.new(0,-L))
  set(b.cBR1, br, br + Vector2.new(-L,0)); set(b.cBR2, br, br + Vector2.new(0,-L))
end

local function tracerAnchor()
  if esp.tracerOrigin=="Center" then return Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y/2)
  elseif esp.tracerOrigin=="Mouse" then local m=UIS:GetMouseLocation(); return Vector2.new(m.X,m.Y)
  else return Vector2.new(Camera.ViewportSize.X/2,Camera.ViewportSize.Y) end
end

local function equippedName(ch)
  if not ch then return nil end
  for _,o in ipairs(ch:GetChildren()) do if o:IsA("Tool") then return o.Name end end
  return nil
end

-- Players update
local function updatePlayer(plr)
  if plr==LP or ignorelist[plr.Name] then local b=buckets[plr]; if b then hideBucket(b) end return end
  if sameTeam(plr) then local b=buckets[plr]; if b then hideBucket(b) end return end

  local ch=plr.Character; if not ch then local b=buckets[plr]; if b then hideBucket(b) end return end
  local p=parts(ch); local hum,hrp=p.hum,p.hrp
  if not hrp or not hum or hum.Health<=0 then local b=buckets[plr]; if b then hideBucket(b) end return end

  local dist=(hrp.Position - Camera.CFrame.Position).Magnitude
  if dist>esp.maxDistance then local b=buckets[plr]; if b then hideBucket(b) end return end

  local vis = LOS(hrp, ch) or (p.torso and LOS(p.torso, ch))
  if esp.onlyVisible and not vis then local b=buckets[plr]; if b then hideBucket(b) end return end

  local base = vis and esp.visColor or esp.occColor
  if esp.useTeamColors and plr.TeamColor then base = plr.TeamColor.Color end
  if esp.passiveESP and isPassive(ch) then base = esp.passiveColor end
  local col=base
  local th,a = dynThickness(dist)

  local b=getBucket(plr)

  if esp.showSkeleton then
    if p.torso then
      setLine(b.torso, p.torso.Position, hrp.Position, col, th, a)
      setLine(b.head,  (p.head and p.head.Position) or p.torso.Position, p.torso.Position, col, th, a)
      setLine(b.lower, (p.lower and p.lower.Position) or p.torso.Position, p.torso.Position, col, th, a)
    else b.torso.Visible=false b.head.Visible=false b.lower.Visible=false end
    setLine(b.luArm, (p.luArm and p.luArm.Position), (p.torso and p.torso.Position) or hrp.Position, col, th, a)
    if p.llArm then setLine(b.llArm, p.llArm.Position, (p.luArm and p.luArm.Position) or ((p.torso or hrp).Position), col, th, a) else b.llArm.Visible=false end
    if p.lHand then setLine(b.lHand, p.lHand.Position, (p.llArm and p.llArm.Position) or (p.luArm and p.luArm.Position), col, th, a) else b.lHand.Visible=false end
    setLine(b.ruArm, (p.ruArm and p.ruArm.Position), (p.torso and p.torso.Position) or hrp.Position, col, th, a)
    if p.rlArm then setLine(b.rlArm, p.rlArm.Position, (p.ruArm and p.ruArm.Position) or ((p.torso or hrp).Position), col, th, a) else b.rlArm.Visible=false end
    if p.rHand then setLine(b.rHand, p.rHand.Position, (p.rlArm and p.rlArm.Position) or (p.ruArm and p.ruArm.Position), col, th, a) else b.rHand.Visible=false end
    local pelvis = p.lower or p.torso or hrp
    setLine(b.luLeg, (p.luLeg and p.luLeg.Position), pelvis.Position, col, th, a)
    if p.llLeg then setLine(b.llLeg, p.llLeg.Position, (p.luLeg and p.luLeg.Position), col, th, a) else b.llLeg.Visible=false end
    setLine(b.ruLeg, (p.ruLeg and p.ruLeg.Position), pelvis.Position, col, th, a)
    if p.rlLeg then setLine(b.rlLeg, p.rlLeg.Position, (p.ruLeg and p.ruLeg.Position), col, th, a) else b.rlLeg.Visible=false end
  else
    b.torso.Visible=false b.head.Visible=false b.lower.Visible=false
    b.luArm.Visible=false b.llArm.Visible=false b.lHand.Visible=false
    b.ruArm.Visible=false b.rlArm.Visible=false b.rHand.Visible=false
    b.luLeg.Visible=false b.llLeg.Visible=false b.ruLeg.Visible=false b.rlLeg.Visible=false
  end

  local minX,minY,maxX,maxY,onScr = computeBBox(ch)
  local tl,tr,bl,br = Vector2.new(minX,minY), Vector2.new(maxX,minY), Vector2.new(minX,maxY), Vector2.new(maxX,maxY)
  if esp.showBox and onScr then
    drawBoxLines(b, tl,tr,bl,br, col, th, a)
    if esp.showCornerBox then corners(b, tl,tr,bl,br, col, th+0.5, a, esp.cornerLen)
    else b.cTL1.Visible=false b.cTL2.Visible=false b.cTR1.Visible=false b.cTR2.Visible=false
         b.cBL1.Visible=false b.cBL2.Visible=false b.cBR1.Visible=false b.cBR2.Visible=false end
    if esp.showFilledBox then
      b.boxFill.Filled=true; b.boxFill.Color=col; b.boxFill.Transparency=clamp(esp.fillAlpha,0.05,0.8)
      b.boxFill.Position=tl; b.boxFill.Size=Vector2.new(maxX-minX, maxY-minY); b.boxFill.Visible=true
    else b.boxFill.Visible=false end
  else
    b.boxT.Visible=false b.boxB.Visible=false b.boxL.Visible=false b.boxR.Visible=false
    b.cTL1.Visible=false b.cTL2.Visible=false b.cTR1.Visible=false b.cTR2.Visible=false
    b.cBL1.Visible=false b.cBL2.Visible=false b.cBR1.Visible=false b.cBR2.Visible=false
    b.boxFill.Visible=false
  end

  if esp.showHealth and hum and onScr then
    local hp, mh = hum.Health, math.max(1, hum.MaxHealth)
    local pct = clamp(hp/mh, 0, 1)
    local H   = (maxY - minY)
    local fill= H * pct
    local bw  = 4
    b.hpBack.Filled=true; b.hpBack.Color=Color3.fromRGB(30,30,30); b.hpBack.Transparency=0.6
    b.hpBack.Position=Vector2.new(minX - (bw+3), minY); b.hpBack.Size=Vector2.new(bw, H); b.hpBack.Visible=true
    local colhp = Color3.new(lerp(1,0,pct), 1, 0)
    b.hpBar.Filled=true; b.hpBar.Color=colhp; b.hpBar.Transparency=0.2
    b.hpBar.Position=Vector2.new(minX - (bw+3), maxY - fill); b.hpBar.Size=Vector2.new(bw, fill); b.hpBar.Visible=true
  else b.hpBack.Visible=false b.hpBar.Visible=false end

  local nameY = math.max(0, minY - 14)
  if esp.showNames and onScr then
    local name = plr.Name
    if esp.passiveESP and isPassive(ch) then name = name .. esp.passiveTag end
    local base = plr.TeamColor and esp.useTeamColors and plr.TeamColor.Color or Theme.Secondary
    if esp.passiveESP and isPassive(ch) then base = esp.passiveColor end
    b.nameText.Text = name; b.nameText.Color=base; b.nameText.Position=Vector2.new((minX+maxX)/2, nameY); b.nameText.Size=14; b.nameText.Visible=true
  else b.nameText.Visible=false end

  if esp.showDistance and onScr then
    b.distText.Text = string.format("%.0f", dist).."s"
    b.distText.Color=Theme.Secondary; b.distText.Position=Vector2.new((minX+maxX)/2, maxY+12); b.distText.Size=13; b.distText.Visible=true
  else b.distText.Visible=false end

  if esp.itemESP and onScr then
    local tname = equippedName(ch)
    if tname or esp.itemWhenNoTool then
      b.itemText.Text  = tname or ""
      b.itemText.Color = esp.itemESPColor
      b.itemText.Size  = esp.itemSize
      b.itemText.Position = Vector2.new((minX+maxX)/2, nameY + esp.itemOffsetY)
      b.itemText.Visible = (tname ~= nil) or esp.itemWhenNoTool
    else b.itemText.Visible=false end
  else b.itemText.Visible=false end

  if esp.showTracers and onScr then
    local p,_=Camera:WorldToViewportPoint(hrp.Position)
    b.tracer.From = tracerAnchor()
    b.tracer.To   = Vector2.new(p.X,p.Y)
    b.tracer.Color= col; b.tracer.Thickness=th; b.tracer.Transparency=a; b.tracer.Visible=true
  else b.tracer.Visible=false end
end

-- Drones update
local function updateDrone(model)
  local b = droneMap[model] or mkDroneBucket(); droneMap[model]=b
  if not esp.droneEnabled then hideDroneBucket(b) return end

  local cf,_ = model:GetBoundingBox()
  local center = cf.Position
  local dist = (center - Camera.CFrame.Position).Magnitude
  if dist > esp.droneMaxDist then hideDroneBucket(b) return end

  local minX,minY,maxX,maxY,onScr = computeBBox(model)
  if not onScr then hideDroneBucket(b) return end

  local tl,tr,bl,br = Vector2.new(minX,minY), Vector2.new(maxX,minY), Vector2.new(minX,maxY), Vector2.new(maxX,maxY)
  local th, al = 2, 0.9
  drawBoxLines(b, tl,tr,bl,br, esp.droneColor, th, al)

  if esp.droneFilled then
    b.fill.Filled=true; b.fill.Color=esp.droneColor; b.fill.Transparency=clamp(esp.droneFillAlpha,0.05,0.8)
    b.fill.Position=tl; b.fill.Size=Vector2.new(maxX-minX, maxY-minY); b.fill.Visible=true
  else b.fill.Visible=false end

  b.label.Text = (model.Name and model.Name ~= "" and model.Name) or "DRONE"
  b.label.Color = esp.droneColor
  b.label.Size = 14
  b.label.Position = Vector2.new((minX+maxX)/2, math.max(0, minY - 14))
  b.label.Visible = true

  b.dist.Text = string.format("%.0f", dist).."s"
  b.dist.Color = Theme.Secondary
  b.dist.Size = 13
  b.dist.Position = Vector2.new((minX+maxX)/2, maxY + 12)
  b.dist.Visible = true

  if esp.droneTracers then
    local v,_ = Camera:WorldToViewportPoint(center)
    b.tracer.From = tracerAnchor()
    b.tracer.To = Vector2.new(v.X, v.Y)
    b.tracer.Color = esp.droneColor
    b.tracer.Thickness = 2
    b.tracer.Transparency = 0.9
    b.tracer.Visible = true
  else b.tracer.Visible=false end
end

-- Track drone models by name anywhere in the game
local DroneFolderSet = {} -- [Model] = true
local function considerInstance(inst)
  if inst:IsA("Model") and inst.Name == "DroneModel" then
    DroneFolderSet[inst] = true
  end
end
for _,d in ipairs(Workspace:GetDescendants()) do considerInstance(d) end
local descAddConn = Workspace.DescendantAdded:Connect(considerInstance)
local descRemConn = Workspace.DescendantRemoving:Connect(function(inst)
  if DroneFolderSet[inst] then DroneFolderSet[inst]=nil cleanDrone(inst) end
end)

-- Master ESP update
local signalMapGlobal = {}
local function hookSignals(plr)
  signalMap[plr] = signalMap[plr] or {}
  table.insert(signalMap[plr], plr.CharacterRemoving:Connect(function() local b=buckets[plr]; if b then hideBucket(b) end end))
end

local function updateESP()
  esp.counter += 1
  local stepEvery = (esp.perfMode=="Fast") and 2 or 1
  if esp.perfMode=="Max" then stepEvery=1 end
  if esp.counter % stepEvery ~= 0 then return end

  for _,plr in ipairs(Players:GetPlayers()) do updatePlayer(plr) end
  for model,_ in pairs(DroneFolderSet) do
    if model and model.Parent then updateDrone(model) else DroneFolderSet[model]=nil cleanDrone(model) end
  end
end

local function enableESP()
  if not hasDrawing then notify("KuromiWare","ESP requires Drawing API",4) return end
  if esp.conn then esp.conn:Disconnect() end
  esp.enabled=true
  esp.conn = RunService.RenderStepped:Connect(updateESP)
  for _,plr in ipairs(Players:GetPlayers()) do hookSignals(plr) end
  if not signalMapGlobal.__rem then
    signalMapGlobal.__rem = Players.PlayerRemoving:Connect(function(plr) cleanPlayer(plr) end)
    signalMapGlobal.__add = Players.PlayerAdded:Connect(function(plr) hookSignals(plr) end)
  end
end
local function disableESP()
  esp.enabled=false
  if esp.conn then esp.conn:Disconnect() esp.conn=nil end
  for plr in pairs(buckets) do cleanPlayer(plr) end
  for m in pairs(droneMap) do cleanDrone(m) end
end

-- ESP UI
do
  local L = ESPTab:Section({Name="Players | Core", Side="Left"})
  L:Toggle({Name="Enable ESP", Flag="KW_ESP_EN", Default=false, Callback=function(v) if v then enableESP() else disableESP() end end})
  L:Dropdown({Name="Performance", Flag="KW_ESP_PERF", Content={"Auto","Fast","Max"}, Default="Auto", Callback=function(v) esp.perfMode=v end})
  L:Slider({Name="Max Distance", Flag="KW_ESP_MD", Default=esp.maxDistance, Min=200, Max=6000, Callback=function(v) esp.maxDistance=v end})
  L:Toggle({Name="Fade by Distance", Flag="KW_ESP_FBD", Default=esp.fadeByDistance, Callback=function(v) esp.fadeByDistance=v end})
  L:Toggle({Name="Only Visible (LOS)", Flag="KW_ESP_VIS", Default=esp.onlyVisible, Callback=function(v) esp.onlyVisible=v end})
  L:Toggle({Name="Team Check", Flag="KW_ESP_TC", Default=esp.teamCheck, Callback=function(v) esp.teamCheck=v end})
  L:Toggle({Name="Use Team Colors", Flag="KW_ESP_UCT", Default=esp.useTeamColors, Callback=function(v) esp.useTeamColors=v end})

  local R = ESPTab:Section({Name="Players | Elements", Side="Right"})
  R:Toggle({Name="Skeleton", Flag="KW_ESP_SKEL", Default=esp.showSkeleton, Callback=function(v) esp.showSkeleton=v end})
  R:Toggle({Name="Box", Flag="KW_ESP_BOX", Default=esp.showBox, Callback=function(v) esp.showBox=v end})
  R:Toggle({Name="Corner Box", Flag="KW_ESP_CBOX", Default=esp.showCornerBox, Callback=function(v) esp.showCornerBox=v end})
  R:Slider({Name="Corner Length", Flag="KW_ESP_CL", Default=esp.cornerLen, Min=4, Max=24, Callback=function(v) esp.cornerLen=v end})
  R:Toggle({Name="Fill Box", Flag="KW_ESP_FILL", Default=esp.showFilledBox, Callback=function(v) esp.showFilledBox=v end})
  R:Slider({Name="Fill Alpha %", Flag="KW_ESP_FA", Default=math.floor(esp.fillAlpha*100), Min=5, Max=80, Callback=function(v) esp.fillAlpha=clamp(v/100,0.05,0.8) end})
  R:Toggle({Name="Tracers", Flag="KW_ESP_TR", Default=esp.showTracers, Callback=function(v) esp.showTracers=v end})
  R:Dropdown({Name="Tracer Origin", Flag="KW_ESP_TO", Content={"Bottom","Center","Mouse"}, Default=esp.tracerOrigin, Callback=function(v) esp.tracerOrigin=v end})
  R:Toggle({Name="Name", Flag="KW_ESP_NAME", Default=esp.showNames, Callback=function(v) esp.showNames=v end})
  R:Toggle({Name="Health Bar", Flag="KW_ESP_HP", Default=esp.showHealth, Callback=function(v) esp.showHealth=v end})
  R:Toggle({Name="Distance", Flag="KW_ESP_DIST", Default=esp.showDistance, Callback=function(v) esp.showDistance=v end})

  local I = ESPTab:Section({Name="Players | Item ESP | Style", Side="Left"})
  I:Toggle({Name="Item ESP", Flag="KW_ITEM_EN", Default=esp.itemESP, Callback=function(v) esp.itemESP=v end})
  I:Colorpicker({Name="Item Text Color", Flag="KW_ITEM_COL", Default=esp.itemESPColor, Callback=function(c) esp.itemESPColor=c end})
  I:Slider({Name="Item Size", Flag="KW_ITEM_SZ", Default=esp.itemSize, Min=10, Max=22, Callback=function(v) esp.itemSize=math.floor(v) end})
  I:Slider({Name="Item Offset Y", Flag="KW_ITEM_OY", Default=esp.itemOffsetY, Min=8, Max=28, Callback=function(v) esp.itemOffsetY=math.floor(v) end})
  I:Toggle({Name="Show When No Tool", Flag="KW_ITEM_SNT", Default=esp.itemWhenNoTool, Callback=function(v) esp.itemWhenNoTool=v end})

  local P = ESPTab:Section({Name="Players | Passive | Colors", Side="Right"})
  P:Toggle({Name="Show (P) tag", Flag="KW_PAS_TAG", Default=esp.passiveESP, Callback=function(v) esp.passiveESP=v end})
  P:Colorpicker({Name="Passive Color", Flag="KW_PAS_COL", Default=esp.passiveColor, Callback=function(c) esp.passiveColor=c end})
  P:Colorpicker({Name="Visible Color", Flag="KW_C_V", Default=esp.visColor, Callback=function(c) esp.visColor=c end})
  P:Colorpicker({Name="Occluded Color", Flag="KW_C_O", Default=esp.occColor, Callback=function(c) esp.occColor=c end})

  local D = ESPTab:Section({Name="Drones | DroneModel ESP", Side="Left"})
  D:Toggle({Name="Enable Drone ESP", Flag="KW_DR_EN", Default=esp.droneEnabled, Callback=function(v) esp.droneEnabled=v end})
  D:Slider({Name="Max Distance", Flag="KW_DR_MD", Default=esp.droneMaxDist, Min=300, Max=8000, Callback=function(v) esp.droneMaxDist=v end})
  D:Toggle({Name="Tracer", Flag="KW_DR_TR", Default=esp.droneTracers, Callback=function(v) esp.droneTracers=v end})
  D:Toggle({Name="Filled Box", Flag="KW_DR_FILL", Default=esp.droneFilled, Callback=function(v) esp.droneFilled=v end})
  D:Slider({Name="Fill Alpha %", Flag="KW_DR_FA", Default=math.floor(esp.droneFillAlpha*100), Min=5, Max=80, Callback=function(v) esp.droneFillAlpha=clamp(v/100,0.05,0.8) end})
  D:Colorpicker({Name="Drone Color", Flag="KW_DR_COL", Default=esp.droneColor, Callback=function(c) esp.droneColor=c end})
end

----------------------------------------------------------------
-- Aimbot (stutter-fixed | min HP stop)
----------------------------------------------------------------
local aim = {
  enabled       = false,
  holdToUse     = false,
  toggleKey     = Enum.KeyCode.Q,
  holdButton    = Enum.UserInputType.MouseButton2,

  teamCheck     = false,
  wallCheck     = true,
  passiveIgnore = true,
  targetPart    = "Head",
  fov           = 150,
  smooth        = 0.18,
  maxDistance   = 1200,
  showHUD       = true,

  minHPToLock   = 1,

  prediction    = false,
  bulletSpeed   = 300,
  leadStrength  = 1.0,

  selectInterval= 0.08,
  losRefresh    = 0.20,
  lastSelect    = 0,
  lastLOSCheck  = 0,
  currentPart   = nil,

  conn          = nil,
  fovCircle     = nil,
  hudText       = nil,
}

if hasDrawing then
  aim.fovCircle = Drawing.new("Circle")
  aim.fovCircle.Visible=false
  aim.fovCircle.Filled=false
  aim.fovCircle.Thickness=1.5
  aim.fovCircle.Transparency=0.9
  aim.fovCircle.Color=Color3.fromRGB(180,220,255)

  aim.hudText = Drawing.new("Text")
  aim.hudText.Visible=false
  aim.hudText.Center=true
  aim.hudText.Size=14
  aim.hudText.Outline=true
  aim.hudText.Color=Color3.fromRGB(230,230,255)
end

local holding=false
UIS.InputBegan:Connect(function(i,gpe)
  if gpe then return end
  if i.UserInputType==aim.holdButton then holding=true end
  if i.KeyCode==aim.toggleKey then
    aim.enabled = not aim.enabled
    if aim.fovCircle then aim.fovCircle.Visible = aim.enabled end
    if not aim.enabled then aim.currentPart=nil end
  end
end)
UIS.InputEnded:Connect(function(i) if i.UserInputType==aim.holdButton then holding=false end end)

local function setAimHUD(txt)
  if aim.hudText then
    if aim.showHUD and txt then
      aim.hudText.Text = txt
      aim.hudText.Position = Vector2.new(Camera.ViewportSize.X/2, 72) -- under the header
      aim.hudText.Visible = true
    else aim.hudText.Visible=false end
  end
end

local function updFOV()
  if not aim.fovCircle then return end
  local m=UIS:GetMouseLocation()
  aim.fovCircle.Position=Vector2.new(m.X,m.Y)
  aim.fovCircle.Radius=aim.fov
end

local function canSee(part, char)
  if not aim.wallCheck then return true end
  local rp=RaycastParams.new(); rp.FilterType=Enum.RaycastFilterType.Blacklist
  rp.FilterDescendantsInstances={LP.Character, char}
  local o=Camera.CFrame.Position
  local d=part.Position - o
  return Workspace:Raycast(o,d,rp)==nil
end

local function validHealth(hum)
  if not hum then return false end
  if hum.Health <= 0 then return false end
  if hum.Health <= aim.minHPToLock then return false end
  return true
end

local function findCandidate()
  local m=UIS:GetMouseLocation()
  local best, bd = nil, math.huge
  local camPos = Camera.CFrame.Position
  for _,plr in ipairs(Players:GetPlayers()) do
    if plr~=LP and not ignorelist[plr.Name] then
      if not (aim.teamCheck and sameTeam(plr)) then
        local ch=plr.Character
        if ch and not (aim.passiveIgnore and isPassive(ch)) then
          local hum = ch:FindFirstChildOfClass("Humanoid")
          if validHealth(hum) then
            local part = ch:FindFirstChild(aim.targetPart) or ch:FindFirstChild("HumanoidRootPart")
            if part then
              local dist = (part.Position - camPos).Magnitude
              if dist <= aim.maxDistance then
                local p, on = Camera:WorldToViewportPoint(part.Position)
                if on then
                  local d = (Vector2.new(p.X,p.Y) - Vector2.new(m.X,m.Y)).Magnitude
                  if d <= aim.fov and d < bd then
                    if canSee(part, ch) then
                      best, bd = part, d
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end
  return best
end

local function predictedPosition(part)
  if not aim.prediction then return part.Position end
  local vel = (part.AssemblyLinearVelocity or Vector3.zero)
  local dist = (part.Position - Camera.CFrame.Position).Magnitude
  local t = dist / math.max(20, aim.bulletSpeed)
  return part.Position + vel * t * aim.leadStrength
end

local function framerateSmooth(dt, s)
  local perFrame = clamp(s, 0.01, 1)
  local factor = 1 - math.pow(1 - perFrame, dt * 60)
  return clamp(factor, 0.01, 1)
end

local function aimAt(part, dt)
  local cf = Camera.CFrame
  local goal = CFrame.new(cf.Position, predictedPosition(part))
  local blend = framerateSmooth(dt, aim.smooth)
  Camera.CFrame = cf:Lerp(goal, blend)
end

local lastStep = tick()
local function stepAim()
  local now = tick()
  local dt = now - lastStep
  lastStep = now

  updFOV()
  if not aim.enabled or (aim.holdToUse and not holding) then setAimHUD(nil) aim.currentPart=nil return end

  if (now - aim.lastSelect) >= aim.selectInterval or not aim.currentPart then
    aim.currentPart = findCandidate()
    aim.lastSelect = now
    aim.lastLOSCheck = now
  else
    local part = aim.currentPart
    local ch = part and part.Parent
    local hum = ch and ch:FindFirstChildOfClass("Humanoid")
    if not part or not ch or not hum or not validHealth(hum) then
      aim.currentPart = nil
    else
      local camPos = Camera.CFrame.Position
      local dist = (part.Position - camPos).Magnitude
      if dist > aim.maxDistance then aim.currentPart=nil
      else
        local m=UIS:GetMouseLocation()
        local p,on = Camera:WorldToViewportPoint(part.Position)
        if not on or (Vector2.new(p.X,p.Y)-Vector2.new(m.X,m.Y)).Magnitude > aim.fov then
          aim.currentPart=nil
        elseif (now - aim.lastLOSCheck) >= aim.losRefresh then
          if not canSee(part, ch) then aim.currentPart=nil end
          aim.lastLOSCheck = now
        end
      end
    end
  end

  local t = aim.currentPart
  if t then
    aimAt(t, dt)
    local ch = t.Parent
    local pl = ch and Players:GetPlayerFromCharacter(ch)
    local who = pl and pl.Name or "Target"
    if ch and isPassive(ch) then who = who.." (P)" end
    local dist = (t.Position - Camera.CFrame.Position).Magnitude
    setAimHUD(string.format("%s  |  %.0fs", who, dist))
  else
    setAimHUD(nil)
  end
end

local function enableAim() if aim.conn then aim.conn:Disconnect() end aim.conn = RunService.RenderStepped:Connect(stepAim); if aim.fovCircle then aim.fovCircle.Visible=true end end
local function disableAim() if aim.conn then aim.conn:Disconnect() aim.conn=nil end if aim.fovCircle then aim.fovCircle.Visible=false end setAimHUD(nil) aim.currentPart=nil end

-- Aimbot UI
do
  local L = Combat:Section({Name="Aimbot | Core", Side="Left"})
  L:Toggle({Name="Enabled", Flag="KW_AIM_EN", Default=false, Callback=function(v) if v then enableAim() else disableAim() end end})
  L:Toggle({Name="Hold RMB", Flag="KW_AIM_HOLD", Default=false, Callback=function(v) aim.holdToUse=v end})
  L:Keybind({Name="Toggle Key", Flag="KW_AIM_KEY", Default=aim.toggleKey, Callback=function(k) if typeof(k)=="EnumItem" then aim.toggleKey=k end end})
  L:Slider({Name="FOV", Flag="KW_AIM_FOV", Default=aim.fov, Min=40, Max=600, Callback=function(v) aim.fov=v end})
  L:Slider({Name="Smooth", Flag="KW_AIM_SM", Default=math.floor(aim.smooth*100), Min=1, Max=100, Callback=function(v) aim.smooth=clamp(v/100,0.01,1) end})
  L:Slider({Name="Max Distance", Flag="KW_AIM_MD", Default=aim.maxDistance, Min=200, Max=6000, Callback=function(v) aim.maxDistance=v end})

  local F = Combat:Section({Name="Aimbot | Filters", Side="Right"})
  F:Toggle({Name="Team Check", Flag="KW_AIM_TC", Default=aim.teamCheck, Callback=function(v) aim.teamCheck=v end})
  F:Toggle({Name="Wall Check", Flag="KW_AIM_WC", Default=aim.wallCheck, Callback=function(v) aim.wallCheck=v end})
  F:Toggle({Name="Ignore Passive", Flag="KW_AIM_PI", Default=aim.passiveIgnore, Callback=function(v) aim.passiveIgnore=v end})
  F:Dropdown({Name="Target Part", Flag="KW_AIM_TP", Content={"Head","HumanoidRootPart"}, Default=aim.targetPart, Callback=function(v) aim.targetPart=v end})
  F:Slider({Name="Min HP to Lock", Flag="KW_AIM_MHP", Default=aim.minHPToLock, Min=0, Max=100, Callback=function(v) aim.minHPToLock=math.max(0, math.floor(v)) end})
  F:Slider({Name="Select Interval (ms)", Flag="KW_AIM_SI", Default=math.floor(aim.selectInterval*1000), Min=30, Max=200, Callback=function(v) aim.selectInterval=clamp(v/1000,0.03,0.2) end})

  local P = Combat:Section({Name="Aimbot | Prediction", Side="Left"})
  P:Toggle({Name="Velocity Prediction", Flag="KW_AIM_PR", Default=false, Callback=function(v) aim.prediction=v end})
  P:Slider({Name="Bullet Speed", Flag="KW_AIM_BS", Default=aim.bulletSpeed, Min=100, Max=1200, Callback=function(v) aim.bulletSpeed=math.floor(v) end})
  P:Slider({Name="Lead Strength", Flag="KW_AIM_LS", Default=math.floor(aim.leadStrength*10), Min=5, Max=20, Callback=function(v) aim.leadStrength=clamp(v/10,0.5,2.0) end})
end

----------------------------------------------------------------
-- Insta Reload (animation speed)
----------------------------------------------------------------
local ir = {
  enabled   = true,
  speed     = 4.0,
  cooldown  = 300,   -- ms
  interval  = 0.06,  -- s
  conn      = nil,
  acc       = 0,
  touched   = {},
}
local function isReloadTrack(track)
  local n=(track.Name or ""):lower()
  if n:find("reload") or n:find("mag") or n:find("clip") then return true end
  local anim=track.Animation
  if anim and anim.AnimationId then
    local id=tostring(anim.AnimationId):lower()
    if id:find("reload") or id:find("mag") or id:find("clip") then return true end
  end
  return false
end
local function irStep(dt)
  ir.acc += dt
  if ir.acc < ir.interval then return end
  ir.acc = 0
  if not ir.enabled then return end
  local ch=LP.Character; if not ch then return end
  local hum=ch:FindFirstChildOfClass("Humanoid"); if not hum then return end
  local animator=hum:FindFirstChildOfClass("Animator"); if not animator then return end
  for _,track in ipairs(animator:GetPlayingAnimationTracks()) do
    if isReloadTrack(track) then
      local now=os.clock()
      if ir.touched[track] and (now - ir.touched[track]) * 1000 < ir.cooldown then
      else
        ir.touched[track]=now
        pcall(function() track:AdjustSpeed(clamp(ir.speed,1,20)) end)
      end
    end
  end
end
local function enableIR() if ir.conn then ir.conn:Disconnect() end ir.enabled=true ir.acc=0 ir.conn=RunService.Heartbeat:Connect(irStep) end
local function disableIR() if ir.conn then ir.conn:Disconnect() ir.conn=nil end ir.enabled=false end

do
  local L = Combat:Section({Name="Insta Reload (Speed)", Side="Left"})
  L:Toggle({Name="Enabled", Flag="KW_IR_EN", Default=ir.enabled, Callback=function(v) if v then enableIR() else disableIR() end end})
  L:Slider({Name="Reload Speed ×", Flag="KW_IR_SPD", Default=ir.speed, Min=1, Max=20, Callback=function(v) ir.speed=v end})
  local R = Combat:Section({Name="IR | Advanced", Side="Right"})
  R:Slider({Name="Per-Reload Cooldown (ms)", Flag="KW_IR_CD", Default=ir.cooldown, Min=100, Max=1000, Callback=function(v) ir.cooldown=math.floor(v) end})
  R:Slider({Name="Scan Interval (ms)", Flag="KW_IR_IV", Default=math.floor(ir.interval*1000), Min=30, Max=150, Callback=function(v) ir.interval=clamp(v/1000,0.03,0.15) end})
end

----------------------------------------------------------------
-- World / Camera
----------------------------------------------------------------
local fb = { enabled=false, brightness=3, clock=14, noShadows=true, noFog=true, conn=nil, saved={}, cc=nil }
local fov = { lock=false, value=80, conn=nil }
local function saveLight()
  fb.saved.Ambient=Lighting.Ambient; fb.saved.OutdoorAmbient=Lighting.OutdoorAmbient
  fb.saved.Brightness=Lighting.Brightness; fb.saved.ClockTime=Lighting.ClockTime
  fb.saved.GlobalShadows=Lighting.GlobalShadows; fb.saved.FogStart=Lighting.FogStart; fb.saved.FogEnd=Lighting.FogEnd
end
local function applyFB()
  Lighting.Ambient=Color3.new(1,1,1); Lighting.OutdoorAmbient=Color3.new(1,1,1)
  Lighting.Brightness=fb.brightness; Lighting.ClockTime=fb.clock; Lighting.GlobalShadows=not fb.noShadows
  if fb.noFog then Lighting.FogStart=0 Lighting.FogEnd=1e6 end
  if not fb.cc then fb.cc=Instance.new("ColorCorrectionEffect") fb.cc.Name="KW_Fullbright" fb.cc.Brightness=0.05 fb.cc.Contrast=0.05 fb.cc.Saturation=0.05 fb.cc.Parent=Lighting end
end
local function enableFB() if fb.enabled then return end saveLight() applyFB() fb.conn=RunService.RenderStepped:Connect(applyFB) fb.enabled=true end
local function disableFB() if not fb.enabled then return end fb.enabled=false if fb.conn then fb.conn:Disconnect() fb.conn=nil end if fb.cc then fb.cc:Destroy() fb.cc=nil end for k,v in pairs(fb.saved) do Lighting[k]=v end end
local function enableFOV() if fov.conn then fov.conn:Disconnect() end fov.lock=true fov.conn=RunService.RenderStepped:Connect(function() Camera.FieldOfView=fov.value end) end
local function disableFOV() fov.lock=false if fov.conn then fov.conn:Disconnect() fov.conn=nil end end

do
  local L=World:Section({Name="Fullbright", Side="Left"})
  L:Toggle({Name="Enabled (lock)", Flag="KW_FB_EN", Default=false, Callback=function(v) if v then enableFB() else disableFB() end end})
  L:Slider({Name="Brightness", Flag="KW_FB_BR", Default=fb.brightness, Min=1, Max=6, Callback=function(v) fb.brightness=v end})
  L:Slider({Name="ClockTime", Flag="KW_FB_CT", Default=fb.clock, Min=0, Max=24, Callback=function(v) fb.clock=v end})
  L:Toggle({Name="No Shadows", Flag="KW_FB_NS", Default=fb.noShadows, Callback=function(v) fb.noShadows=v end})
  L:Toggle({Name="No Fog", Flag="KW_FB_NF", Default=fb.noFog, Callback=function(v) fb.noFog=v end})

  local R=World:Section({Name="Camera FOV", Side="Right"})
  R:Toggle({Name="FOV Lock", Flag="KW_FOV_L", Default=false, Callback=function(v) if v then enableFOV() else disableFOV() end end})
  R:Slider({Name="FOV", Flag="KW_FOV_V", Default=fov.value, Min=40, Max=120, Callback=function(v) fov.value=v end})
end

----------------------------------------------------------------
-- HUD | Modern Centered Header + Crosshair
----------------------------------------------------------------
local placeName = "Place"
pcall(function()
  local info = MPS:GetProductInfo(game.PlaceId)
  if info and info.Name and #info.Name > 0 then placeName = info.Name end
end)

local hud = {
  -- Header
  showHeaderBar   = true,     -- bar background
  showAccentLine  = true,     -- animated accent strip
  accentPulse     = true,
  accentSpeed     = 0.12,     -- hue speed
  headerAlpha     = 0.18,
  shadowAlpha     = 0.35,
  headerHeight    = 34,
  headerAutoWidth = true,
  headerWidth     = 480,
  headerFontSize  = 15,

  showFPS         = true,
  showPing        = true,
  showPlayers     = true,
  showTime        = true,
  showPlace       = true,
  showUsername    = false,

  -- Crosshair
  showCrosshair   = true,
  crossGap        = 7,
  crossLen        = 9,
  crossThick      = 1.5,
}

-- Drawing objects for header
local headerBar, headerShadow, headerText, accentLine
local statText = nil
if hasDrawing then
  headerBar    = Drawing.new("Square")
  headerShadow = Drawing.new("Square")
  headerText   = Drawing.new("Text")
  accentLine   = Drawing.new("Line")
  statText     = Drawing.new("Text")

  for _,sq in ipairs({headerBar, headerShadow}) do
    sq.Visible=false; sq.Filled=true; sq.Color=Theme.PanelMid; sq.Thickness=1
  end
  headerShadow.Color = Theme.PanelDark

  headerText.Visible=true; headerText.Center=true; headerText.Size=hud.headerFontSize; headerText.Outline=true; headerText.Color=Theme.Secondary
  statText.Visible=true; statText.Center=true; statText.Size=hud.headerFontSize-1; statText.Outline=true; statText.Color=Color3.fromRGB(200,200,210)

  accentLine.Visible=true; accentLine.Thickness=2
end

-- Crosshair
local crossLines = {}
if hasDrawing then
  for i=1,4 do local l=Drawing.new("Line"); l.Color=Theme.Secondary; l.Thickness=hud.crossThick; l.Visible=false; crossLines[i]=l end
end

-- Stats helpers
local pingItem = Stats and Stats.Network and Stats.Network.ServerStatsItem and Stats.Network.ServerStatsItem["Data Ping"] or nil
local fpsCounter,lastFPS,fpsAccum = 0,60,0

local function buildHeaderStrings()
  local left = "KuromiWare - By list"
  local rightParts = {}

  if hud.showFPS then table.insert(rightParts, ("FPS %d"):format(lastFPS)) end
  if hud.showPing and pingItem then table.insert(rightParts, ("Ping %dms"):format(math.max(0, math.floor(pingItem:GetValue() or 0)))) end
  if hud.showPlayers then table.insert(rightParts, ("Players %d"):format(#Players:GetPlayers())) end
  if hud.showTime then table.insert(rightParts, os.date("%H:%M:%S")) end
  if hud.showPlace then table.insert(rightParts, placeName) end
  if hud.showUsername then table.insert(rightParts, ("@%s"):format(LP.Name)) end

  local right = table.concat(rightParts, " | ")
  return left, right
end

RunService.RenderStepped:Connect(function(dt)
  if not hasDrawing then return end

  -- FPS calc
  fpsAccum += dt; fpsCounter += 1
  if fpsAccum >= 0.25 then lastFPS = math.floor(fpsCounter / fpsAccum + 0.5); fpsAccum, fpsCounter = 0, 0 end

  -- Header content
  local left, right = buildHeaderStrings()
  local combined = (right ~= "" and (left.." | "..right)) or left

  -- Measure width (approx)
  local vw = Camera.ViewportSize.X
  local vh = Camera.ViewportSize.Y
  local textSize = hud.headerFontSize
  headerText.Size = textSize
  statText.Size   = textSize - 1

  local approxWidth = math.clamp(#combined * textSize * 0.56 + 40, 260, math.min(vw - 24, 720))
  local w = hud.headerAutoWidth and approxWidth or hud.headerWidth
  local h = hud.headerHeight
  local x = math.floor((vw - w) / 2)
  local y = 8

  -- Background bar + shadow
  if hud.showHeaderBar then
    headerShadow.Position     = Vector2.new(x, y+2)
    headerShadow.Size         = Vector2.new(w, h)
    headerShadow.Transparency = hud.shadowAlpha
    headerShadow.Visible      = true

    headerBar.Position        = Vector2.new(x, y)
    headerBar.Size            = Vector2.new(w, h)
    headerBar.Transparency    = hud.headerAlpha
    headerBar.Visible         = true
  else
    headerShadow.Visible = false
    headerBar.Visible    = false
  end

  -- Accent pulse color
  local accent = Theme.Accent
  if hud.accentPulse then
    local hue = (os.clock() * hud.accentSpeed) % 1
    accent = Color3.fromHSV(hue, 0.5, 1)
  end
  if hud.showAccentLine then
    accentLine.From         = Vector2.new(x+8, y+h-2)
    accentLine.To           = Vector2.new(x+w-8, y+h-2)
    accentLine.Color        = accent
    accentLine.Transparency = 0.9
    accentLine.Visible      = true
  else
    accentLine.Visible = false
  end

  -- Centered text
  headerText.Text      = combined
  headerText.Color     = Theme.Secondary
  headerText.Position  = Vector2.new(vw/2, y + h/2 + 1)
  headerText.Visible   = true

  -- Subtext (credits subtle accent)
  statText.Text        = " "
  statText.Color       = accent
  statText.Position    = Vector2.new(vw/2, y + h + 14)
  statText.Visible     = true

  -- Crosshair
  local m=UIS:GetMouseLocation()
  local cgap,clen=hud.crossGap,hud.crossLen
  local pts={{Vector2.new(m.X - cgap - clen, m.Y), Vector2.new(m.X - cgap, m.Y)},
             {Vector2.new(m.X + cgap, m.Y),       Vector2.new(m.X + cgap + clen, m.Y)},
             {Vector2.new(m.X, m.Y - cgap - clen), Vector2.new(m.X, m.Y - cgap)},
             {Vector2.new(m.X, m.Y + cgap),        Vector2.new(m.X, m.Y + cgap + clen)}}
  for i=1,4 do
    local L=crossLines[i]
    if hud.showCrosshair then
      L.Thickness = hud.crossThick
      L.From=pts[i][1]; L.To=pts[i][2]; L.Visible=true
    else L.Visible=false end
  end
end)

-- HUD UI
do
  local H = HUDTab:Section({Name="Header | Centered Banner", Side="Left"})
  H:Toggle({Name="Show Header Bar", Flag="KW_HD_BAR", Default=hud.showHeaderBar, Callback=function(v) hud.showHeaderBar=v end})
  H:Toggle({Name="Accent Pulse", Flag="KW_HD_AP", Default=hud.accentPulse, Callback=function(v) hud.accentPulse=v end})
  H:Toggle({Name="Accent Line", Flag="KW_HD_AL", Default=hud.showAccentLine, Callback=function(v) hud.showAccentLine=v end})
  H:Slider({Name="Header Height", Flag="KW_HD_H", Default=hud.headerHeight, Min=24, Max=50, Callback=function(v) hud.headerHeight=math.floor(v) end})
  H:Slider({Name="Header Alpha %", Flag="KW_HD_A", Default=math.floor(hud.headerAlpha*100), Min=0, Max=80, Callback=function(v) hud.headerAlpha=clamp(v/100,0,0.8) end})
  H:Slider({Name="Shadow Alpha %", Flag="KW_HD_SA", Default=math.floor(hud.shadowAlpha*100), Min=0, Max=80, Callback=function(v) hud.shadowAlpha=clamp(v/100,0,0.8) end})
  H:Toggle({Name="Auto Width", Flag="KW_HD_AW", Default=hud.headerAutoWidth, Callback=function(v) hud.headerAutoWidth=v end})
  H:Slider({Name="Manual Width", Flag="KW_HD_MW", Default=hud.headerWidth, Min=260, Max=720, Callback=function(v) hud.headerWidth=math.floor(v) end})
  H:Slider({Name="Font Size", Flag="KW_HD_FS", Default=hud.headerFontSize, Min=12, Max=20, Callback=function(v) hud.headerFontSize=math.floor(v) end})

  local D = HUDTab:Section({Name="Header | Data Chips", Side="Right"})
  D:Toggle({Name="Show FPS", Flag="KW_HD_FPS", Default=hud.showFPS, Callback=function(v) hud.showFPS=v end})
  D:Toggle({Name="Show Ping", Flag="KW_HD_PING", Default=hud.showPing, Callback=function(v) hud.showPing=v end})
  D:Toggle({Name="Show Players", Flag="KW_HD_PLR", Default=hud.showPlayers, Callback=function(v) hud.showPlayers=v end})
  D:Toggle({Name="Show Time", Flag="KW_HD_TIME", Default=hud.showTime, Callback=function(v) hud.showTime=v end})
  D:Toggle({Name="Show Place Name", Flag="KW_HD_PLACE", Default=hud.showPlace, Callback=function(v) hud.showPlace=v end})
  D:Toggle({Name="Show Username", Flag="KW_HD_USER", Default=hud.showUsername, Callback=function(v) hud.showUsername=v end})

  local C = HUDTab:Section({Name="Crosshair", Side="Left"})
  C:Toggle({Name="Enabled", Flag="KW_CH_EN", Default=hud.showCrosshair, Callback=function(v) hud.showCrosshair=v end})
  C:Slider({Name="Gap (px)", Flag="KW_CH_GAP", Default=hud.crossGap, Min=3, Max=24, Callback=function(v) hud.crossGap=math.floor(v) end})
  C:Slider({Name="Length (px)", Flag="KW_CH_LEN", Default=hud.crossLen, Min=4, Max=24, Callback=function(v) hud.crossLen=math.floor(v) end})
  C:Slider({Name="Thickness", Flag="KW_CH_TH", Default=math.floor(hud.crossThick*10), Min=10, Max=40, Callback=function(v) hud.crossThick=clamp(v/10,0.5,4) end})
end

----------------------------------------------------------------
-- Config | Lists
----------------------------------------------------------------
do
  local R = Config:Section({Name="Friends | Ignores", Side="Left"})
  local userBox = R:Box({Name="Player Name", Flag="KW_USER_BOX", Placeholder="Exact name"})
  R:Button({Name="Add to Friends (Whitelist)", Callback=function() local n=GUI.flags["KW_USER_BOX"]; if n and n~="" then whitelist[n]=true end userBox:Set("") end})
  R:Button({Name="Remove Friend", Callback=function() local n=GUI.flags["KW_USER_BOX"]; if n then whitelist[n]=nil end userBox:Set("") end})
  R:Button({Name="Add to Ignore", Callback=function() local n=GUI.flags["KW_USER_BOX"]; if n and n~="" then ignorelist[n]=true end userBox:Set("") end})
  R:Button({Name="Remove Ignore", Callback=function() local n=GUI.flags["KW_USER_BOX"]; if n then ignorelist[n]=nil end userBox:Set("") end})
end

----------------------------------------------------------------
-- Settings / Lifecycle
----------------------------------------------------------------
local S = About:Section({Name="KuromiWare", Side="Left"})
S:Keybind({Name="Toggle UI", Flag="KW_UI_TOG", Default=Enum.KeyCode.RightShift, Callback=function(_, newKey) if not newKey then GUI:Close() end end})
S:Button({Name="Unload", Callback=function()
  disableESP(); if descAddConn then descAddConn:Disconnect() end; if descRemConn then descRemConn:Disconnect() end
  disableAim(); disableIR(); disableFB(); disableFOV()
  GUI:Unload(); getgenv().KittenWareLoaded=nil
end})

-- Quick hotkeys
UIS.InputBegan:Connect(function(i,gpe)
  if gpe then return end
  if i.KeyCode==Enum.KeyCode.N then if nrEnabled then disableNR() else enableNR() end end
  if i.KeyCode==Enum.KeyCode.B then if esp.enabled then disableESP() else enableESP() end end
end)

-- Start essentials
enableIR()

game:BindToClose(function()
  disableESP(); disableAim(); disableIR(); disableFB(); disableFOV()
end)

getgenv().KittenWareLoaded = true
getgenv().KittenWareLoading = nil
GUI:Close()
