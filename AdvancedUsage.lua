--[[
    Advanced Usage Example
    Following players with dynamic targeting
]]

local PathfindModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/pathfind-api/main/src/PathfindModule.lua"))()
local PathfindManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/pathfind-api/main/src/PathfindManager.lua"))()
local Utils = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/pathfind-api/main/src/Utils.lua"))()

-- Create manager
local manager = PathfindManager.new()

-- Function to follow nearest player
function FollowNearestPlayer()
    local player = game.Players.LocalPlayer
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Create pathfinder that follows the nearest player
    local pathfinder = manager:Create(character, nil, {
        VisualizePath = true,
        UpdateInterval = 1,
        StuckTimeLimit = 1.5,
        SpeedMultiplier = 1.2,
        DebugMode = true
    })
    
    -- Update target every second to follow nearest player
    task.spawn(function()
        while pathfinder.IsActive do
            local nearest = Utils.GetNearestPlayer(character)
            if nearest then
                pathfinder:SetTarget(nearest)
            end
            task.wait(1)
        end
    end)
    
    -- Set up callbacks
    pathfinder:On("OnStart", function()
        print("Started following nearest player")
    end)
    
    pathfinder:On("OnArrived", function()
        print("Reached target player")
    end)
    
    -- Start following
    manager:Start(pathfinder)
    
    return pathfinder
end

-- Start following
local follower = FollowNearestPlayer()

-- Stop after 30 seconds
task.wait(30)
follower:Stop()

-- Print statistics
print(manager:GetStats())
