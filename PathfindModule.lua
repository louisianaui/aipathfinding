--[[
    Pathfind API - Advanced Pathfinding Module for Roblox Executors
    GitHub: https://github.com/yourusername/pathfind-api
    Version: 1.0.0
    License: MIT
]]

local PathfindModule = {}
PathfindModule.__index = PathfindModule

-- Services
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local UserInputService = game:GetService("UserInputService")

-- Default Configuration
local DEFAULT_CONFIG = {
    -- Movement Settings
    AgentRadius = 2,
    AgentHeight = 5,
    AgentCanJump = true,
    AgentMaxSlope = 45,
    WaypointSpacing = 3,
    ArrivalDistance = 3,
    SpeedMultiplier = 1,
    AutoJump = true,
    
    -- Path Update Settings
    UpdateInterval = 1.5,
    RecalculateDistance = 10,
    MaxPathAttempts = 3,
    
    -- Stuck Detection
    StuckCheckInterval = 0.5,
    StuckThreshold = 0.5,
    StuckTimeLimit = 2.5,
    
    -- Visualization
    VisualizePath = true,
    PathColor = Color3.fromRGB(0, 255, 255),
    PathThickness = 0.2,
    ShowWaypoints = true,
    
    -- Advanced Options
    UseTeleport = false,
    UseNoclip = false,
    SmoothMovement = true,
    DebugMode = false
}

-- Constructor
function PathfindModule.new(character, target, config)
    local self = setmetatable({}, PathfindModule)
    
    -- Validate character
    self.Character = character or Players.LocalPlayer.Character
    if not self.Character then
        error("PathfindModule: No character provided and LocalPlayer character not found")
    end
    
    self.Humanoid = self.Character:FindFirstChild("Humanoid")
    self.RootPart = self.Character:FindFirstChild("HumanoidRootPart")
    
    if not self.Humanoid or not self.RootPart then
        error("PathfindModule: Character missing Humanoid or HumanoidRootPart")
    end
    
    -- Set target
    self.Target = target
    
    -- Merge config
    self.Config = {}
    for key, value in pairs(DEFAULT_CONFIG) do
        self.Config[key] = (config and config[key] ~= nil) and config[key] or value
    end
    
    -- Internal state
    self.CurrentPath = nil
    self.CurrentWaypoints = {}
    self.CurrentWaypointIndex = 1
    self.IsActive = false
    self.IsMoving = false
    self.IsPaused = false
    self.PathAttempts = 0
    self.StuckTimer = 0
    self.LastPosition = nil
    self.LastUpdateTime = 0
    
    -- Visualization
    self.VisualizationObjects = {}
    
    -- Callbacks
    self.Callbacks = {
        OnStart = nil,
        OnArrived = nil,
        OnStuck = nil,
        OnPathRecalculated = nil,
        OnError = nil
    }
    
    -- Setup smooth movement
    if self.Config.SmoothMovement then
        self:SetupSmoothMovement()
    end
    
    if self.Config.UseNoclip then
        self:SetupNoclip()
    end
    
    return self
end

-- Setup smooth movement with BodyVelocity
function PathfindModule:SetupSmoothMovement()
    -- Remove existing
    local existing = self.RootPart:FindFirstChild("PathfindVelocity")
    if existing then existing:Destroy() end
    
    self.BodyVelocity = Instance.new("BodyVelocity")
    self.BodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    self.BodyVelocity.P = 2000
    self.BodyVelocity.Name = "PathfindVelocity"
    self.BodyVelocity.Parent = self.RootPart
end

-- Setup noclip
function PathfindModule:SetupNoclip()
    self.OriginalCollisionGroups = {}
    for _, part in ipairs(self.Character:GetDescendants()) do
        if part:IsA("BasePart") then
            self.OriginalCollisionGroups[part] = part.CollisionGroup
            part.CollisionGroup = "Debris"
        end
    end
end

-- Disable noclip
function PathfindModule:DisableNoclip()
    if not self.Config.UseNoclip then return end
    
    for part, group in pairs(self.OriginalCollisionGroups) do
        if part and part.Parent then
            part.CollisionGroup = group
        end
    end
    self.OriginalCollisionGroups = {}
end

-- Get current target position
function PathfindModule:GetTargetPosition()
    if not self.Target then
        return nil
    end
    
    if type(self.Target) == "table" and self.Target.Type == "Function" then
        return self.Target.GetPosition()
    end
    
    if typeof(self.Target) == "Instance" then
        if self.Target:IsA("BasePart") then
            return self.Target.Position
        elseif self.Target:IsA("Model") then
            local primary = self.Target.PrimaryPart or self.Target:FindFirstChild("HumanoidRootPart")
            if primary then
                return primary.Position
            end
            return self.Target:GetPivot().Position
        elseif self.Target:IsA("Player") then
            local char = self.Target.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                return char.HumanoidRootPart.Position
            end
        end
    elseif typeof(self.Target) == "Vector3" then
        return self.Target
    end
    
    return nil
end

-- Create path
function PathfindModule:CreatePath()
    local targetPos = self:GetTargetPosition()
    if not targetPos then
        if self.Callbacks.OnError then
            self.Callbacks.OnError("Could not get target position")
        end
        return false
    end
    
    local startPos = self.RootPart.Position
    
    -- Check if already at target
    if (startPos - targetPos).Magnitude <= self.Config.ArrivalDistance then
        self:Arrived()
        return true
    end
    
    -- Create path parameters
    local pathParams = {
        AgentRadius = self.Config.AgentRadius,
        AgentHeight = self.Config.AgentHeight,
        AgentCanJump = self.Config.AgentCanJump,
        AgentMaxSlope = self.Config.AgentMaxSlope,
        WaypointSpacing = self.Config.WaypointSpacing
    }
    
    -- Create and compute path
    local path = PathfindingService:CreatePath(pathParams)
    local success = pcall(function()
        path:ComputeAsync(startPos, targetPos)
    end)
    
    if not success or path.Status == Enum.PathStatus.NoPath then
        self.PathAttempts = self.PathAttempts + 1
        
        if self.PathAttempts <= self.Config.MaxPathAttempts then
            task.wait(0.5)
            return self:CreatePath()
        else
            if self.Callbacks.OnError then
                self.Callbacks.OnError("No path found after " .. self.Config.MaxPathAttempts .. " attempts")
            end
            self:Stop()
            return false
        end
    end
    
    -- Get and filter waypoints
    local waypoints = path:GetWaypoints()
    self.CurrentWaypoints = self:FilterWaypoints(waypoints)
    self.CurrentWaypointIndex = 1
    self.PathAttempts = 0
    self.StuckTimer = 0
    self.LastPosition = startPos
    
    -- Visualize path
    if self.Config.VisualizePath then
        self:VisualizePath()
    end
    
    -- Trigger callback
    if self.Callbacks.OnPathRecalculated then
        self.Callbacks.OnPathRecalculated(#self.CurrentWaypoints)
    end
    
    return true
end

-- Filter waypoints to optimize path
function PathfindModule:FilterWaypoints(waypoints)
    local filtered = {}
    
    for i, waypoint in ipairs(waypoints) do
        if i == 1 then
            table.insert(filtered, waypoint)
        else
            local lastPos = filtered[#filtered].Position
            local distance = (waypoint.Position - lastPos).Magnitude
            
            if distance > self.Config.WaypointSpacing then
                table.insert(filtered, waypoint)
            end
        end
    end
    
    return filtered
end

-- Visualize path
function PathfindModule:VisualizePath()
    -- Clear existing
    for _, obj in ipairs(self.VisualizationObjects) do
        pcall(function() obj:Destroy() end)
    end
    self.VisualizationObjects = {}
    
    if #self.CurrentWaypoints < 2 then return end
    
    for i = 1, #self.CurrentWaypoints - 1 do
        local startPos = self.CurrentWaypoints[i].Position
        local endPos = self.CurrentWaypoints[i + 1].Position
        local distance = (endPos - startPos).Magnitude
        
        if distance > 0 then
            local part = Instance.new("Part")
            part.Size = Vector3.new(self.Config.PathThickness, self.Config.PathThickness, distance)
            part.CFrame = CFrame.new(startPos:Lerp(endPos, 0.5), endPos)
            part.Anchored = true
            part.CanCollide = false
            part.BrickColor = BrickColor.new(self.Config.PathColor)
            part.Material = Enum.Material.Neon
            part.Transparency = 0.5
            part.Parent = workspace
            
            Debris:AddItem(part, self.Config.UpdateInterval + 0.5)
            table.insert(self.VisualizationObjects, part)
        end
    end
    
    -- Add waypoint markers
    if self.Config.ShowWaypoints then
        for i, waypoint in ipairs(self.CurrentWaypoints) do
            local marker = Instance.new("Part")
            marker.Size = Vector3.new(0.5, 0.5, 0.5)
            marker.Position = waypoint.Position
            marker.Anchored = true
            marker.CanCollide = false
            marker.BrickColor = BrickColor.new(self.Config.PathColor)
            marker.Material = Enum.Material.Neon
            marker.Parent = workspace
            
            Debris:AddItem(marker, self.Config.UpdateInterval + 0.5)
            table.insert(self.VisualizationObjects, marker)
        end
    end
end

-- Move to next waypoint
function PathfindModule:MoveToNextWaypoint()
    if not self.IsActive or self.IsPaused or #self.CurrentWaypoints == 0 then
        return false
    end
    
    local currentWaypoint = self.CurrentWaypoints[self.CurrentWaypointIndex]
    if not currentWaypoint then
        return false
    end
    
    local distance = (self.RootPart.Position - currentWaypoint.Position).Magnitude
    
    if distance <= self.Config.WaypointSpacing then
        self.CurrentWaypointIndex = self.CurrentWaypointIndex + 1
        
        if self.CurrentWaypointIndex > #self.CurrentWaypoints then
            self:Arrived()
            return false
        end
    end
    
    -- Move towards waypoint
    local target = self.CurrentWaypoints[self.CurrentWaypointIndex]
    local direction = (target.Position - self.RootPart.Position).Unit
    
    if self.Config.UseTeleport then
        -- Teleport movement (for executors with teleport functions)
        local teleportFunc = getrenv and getrenv().teleport or teleport
        if teleportFunc then
            teleportFunc(self.RootPart, target.Position)
        end
    elseif self.Config.SmoothMovement and self.BodyVelocity then
        -- Smooth movement
        local speed = self.Humanoid.WalkSpeed * self.Config.SpeedMultiplier
        self.BodyVelocity.Velocity = direction * speed
        
        -- Handle jumping for waypoints that require it
        if self.Config.AutoJump and target.Action == Enum.PathWaypointAction.Jump then
            self.Humanoid.Jump = true
        end
    else
        -- Standard movement
        self.Humanoid:MoveTo(target.Position)
        
        -- Auto-jump
        if self.Config.AutoJump and target.Action == Enum.PathWaypointAction.Jump then
            self.Humanoid.Jump = true
        end
    end
    
    return true
end

-- Check if stuck
function PathfindModule:CheckStuck()
    if not self.IsActive or self.IsPaused then return end
    
    local currentPos = self.RootPart.Position
    local distanceMoved = (currentPos - self.LastPosition).Magnitude
    
    if distanceMoved < self.Config.StuckThreshold then
        self.StuckTimer = self.StuckTimer + self.Config.StuckCheckInterval
        
        if self.StuckTimer >= self.Config.StuckTimeLimit then
            if self.Config.DebugMode then
                warn("[Pathfind] Character stuck, recalculating path...")
            end
            
            if self.Callbacks.OnStuck then
                self.Callbacks.OnStuck()
            end
            
            self:RecalculatePath()
            self.StuckTimer = 0
        end
    else
        self.StuckTimer = math.max(0, self.StuckTimer - self.Config.StuckCheckInterval)
    end
    
    self.LastPosition = currentPos
end

-- Recalculate path
function PathfindModule:RecalculatePath()
    if not self.IsActive then return end
    
    local targetPos = self:GetTargetPosition()
    if not targetPos then
        self:Stop()
        return
    end
    
    local distance = (self.RootPart.Position - targetPos).Magnitude
    
    if distance > self.Config.RecalculateDistance then
        self:CreatePath()
    end
end

-- Path updater loop
function PathfindModule:PathUpdater()
    while self.IsActive and RunService:IsRunning() do
        task.wait(self.Config.UpdateInterval)
        if self.IsActive and not self.IsPaused then
            self:RecalculatePath()
        end
    end
end

-- Stuck checker loop
function PathfindModule:StuckChecker()
    while self.IsActive and RunService:IsRunning() do
        task.wait(self.Config.StuckCheckInterval)
        if self.IsActive and not self.IsPaused then
            self:CheckStuck()
        end
    end
end

-- Movement loop
function PathfindModule:MovementLoop()
    while self.IsActive and RunService:IsRunning() do
        if self.IsMoving and not self.IsPaused and #self.CurrentWaypoints > 0 then
            self:MoveToNextWaypoint()
        end
        task.wait()
    end
end

-- Arrived at destination
function PathfindModule:Arrived()
    if self.Config.DebugMode then
        print("[Pathfind] Arrived at destination")
    end
    
    if self.Callbacks.OnArrived then
        self.Callbacks.OnArrived()
    end
    
    self:Stop()
end

-- Start pathfinding
function PathfindModule:Start()
    if not self.Target then
        error("PathfindModule: No target specified")
    end
    
    self:Stop()
    
    local success = self:CreatePath()
    if not success then
        return false
    end
    
    self.IsActive = true
    self.IsMoving = true
    self.IsPaused = false
    self.LastPosition = self.RootPart.Position
    
    -- Start threads
    self.MovementThread = task.spawn(function() self:MovementLoop() end)
    self.UpdateThread = task.spawn(function() self:PathUpdater() end)
    self.StuckThread = task.spawn(function() self:StuckChecker() end)
    
    if self.Callbacks.OnStart then
        self.Callbacks.OnStart()
    end
    
    return true
end

-- Stop pathfinding
function PathfindModule:Stop()
    self.IsActive = false
    self.IsMoving = false
    self.IsPaused = false
    
    -- Stop movement
    if self.Humanoid then
        pcall(function() self.Humanoid:MoveTo(self.RootPart.Position) end)
    end
    
    if self.BodyVelocity then
        self.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
    
    -- Clear visualization
    for _, obj in ipairs(self.VisualizationObjects) do
        pcall(function() obj:Destroy() end)
    end
    self.VisualizationObjects = {}
    
    -- Clear waypoints
    self.CurrentWaypoints = {}
    self.CurrentWaypointIndex = 1
end

-- Pause movement
function PathfindModule:Pause()
    self.IsPaused = true
    self.IsMoving = false
    
    if self.Humanoid then
        pcall(function() self.Humanoid:MoveTo(self.RootPart.Position) end)
    end
    
    if self.BodyVelocity then
        self.BodyVelocity.Velocity = Vector3.new(0, 0, 0)
    end
end

-- Resume movement
function PathfindModule:Resume()
    self.IsPaused = false
    self.IsMoving = true
    self.LastPosition = self.RootPart.Position
    self.StuckTimer = 0
    
    self:RecalculatePath()
end

-- Set callback
function PathfindModule:On(event, callback)
    if self.Callbacks[event] ~= nil then
        self.Callbacks[event] = callback
    else
        error("PathfindModule: Unknown event '" .. event .. "'")
    end
end

-- Set target
function PathfindModule:SetTarget(newTarget)
    self.Target = newTarget
    self.PathAttempts = 0
    
    if self.IsActive then
        self:RecalculatePath()
    end
end

-- Get current status
function PathfindModule:GetStatus()
    return {
        Active = self.IsActive,
        Moving = self.IsMoving,
        Paused = self.IsPaused,
        WaypointsRemaining = #self.CurrentWaypoints - self.CurrentWaypointIndex + 1,
        DistanceToTarget = self.Target and (self:GetTargetPosition() and (self.RootPart.Position - self:GetTargetPosition()).Magnitude) or nil
    }
end

-- Destroy instance
function PathfindModule:Destroy()
    self:Stop()
    
    self:DisableNoclip()
    
    if self.BodyVelocity then
        self.BodyVelocity:Destroy()
    end
    
    -- Clear references
    self.Character = nil
    self.Humanoid = nil
    self.RootPart = nil
    self.Target = nil
    self.CurrentWaypoints = nil
    self.Callbacks = nil
end

-- Create a quick pathfinder instance
function PathfindModule.QuickStart(character, target, config)
    local pf = PathfindModule.new(character, target, config)
    pf:Start()
    return pf
end

return PathfindModule
