--[[
    Basic Usage Example
    Load and use the pathfinding module
]]

-- Load the module
local PathfindModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/pathfind-api/main/src/PathfindModule.lua"))()

-- Get local player
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

-- Create pathfinder to move to a position
local pathfinder = PathfindModule.new(character, Vector3.new(0, 10, 0), {
    VisualizePath = true,
    SpeedMultiplier = 1.5,
    DebugMode = true
})

-- Set up callbacks
pathfinder:On("OnStart", function()
    print("Started pathfinding!")
end)

pathfinder:On("OnArrived", function()
    print("Successfully reached destination!")
end)

pathfinder:On("OnStuck", function()
    print("Got stuck, recalculating...")
end)

pathfinder:On("OnError", function(error)
    warn("Error: " .. error)
end)

-- Start moving
pathfinder:Start()

-- Optional: Stop after 10 seconds
task.wait(10)
pathfinder:Stop()
