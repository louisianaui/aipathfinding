--[[
    Pathfind Manager - Manage multiple pathfinding instances
]]

local PathfindModule = require(script.PathfindModule)

local PathfindManager = {}
PathfindManager.__index = PathfindManager

function PathfindManager.new()
    local self = setmetatable({}, PathfindManager)
    self.Instances = {}
    self.ActiveInstances = {}
    return self
end

-- Create new instance
function PathfindManager:Create(character, target, config)
    local pf = PathfindModule.new(character, target, config)
    table.insert(self.Instances, pf)
    return pf
end

-- Start instance
function PathfindManager:Start(instance)
    instance:Start()
    self.ActiveInstances[instance] = true
end

-- Stop all instances
function PathfindManager:StopAll()
    for _, instance in ipairs(self.Instances) do
        instance:Stop()
    end
    self.ActiveInstances = {}
end

-- Pause all
function PathfindManager:PauseAll()
    for _, instance in ipairs(self.Instances) do
        if instance.IsActive then
            instance:Pause()
        end
    end
end

-- Resume all
function PathfindManager:ResumeAll()
    for _, instance in ipairs(self.Instances) do
        if instance.IsActive then
            instance:Resume()
        end
    end
end

-- Destroy all
function PathfindManager:DestroyAll()
    for _, instance in ipairs(self.Instances) do
        instance:Destroy()
    end
    self.Instances = {}
    self.ActiveInstances = {}
end

-- Get statistics
function PathfindManager:GetStats()
    local stats = {
        TotalInstances = #self.Instances,
        ActiveInstances = 0,
        PausedInstances = 0
    }
    
    for _, instance in ipairs(self.Instances) do
        if instance.IsActive then
            if instance.IsPaused then
                stats.PausedInstances = stats.PausedInstances + 1
            else
                stats.ActiveInstances = stats.ActiveInstances + 1
            end
        end
    end
    
    return stats
end

return PathfindManager
