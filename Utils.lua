--[[
    Pathfind Utilities - Helper functions
]]

local Utils = {}

-- Check if position is valid
function Utils.IsValidPosition(position)
    return position and typeof(position) == "Vector3" and position.Magnitude > 0 and position.Magnitude < 1e6
end

-- Get nearest player
function Utils.GetNearestPlayer(character, ignoreList)
    local localPlayer = game.Players.LocalPlayer
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    
    if not rootPart then return nil end
    
    local nearest = nil
    local nearestDist = math.huge
    
    for _, player in ipairs(game.Players:GetPlayers()) do
        if player ~= localPlayer and (not ignoreList or not ignoreList[player]) then
            local char = player.Character
            if char and char:FindFirstChild("HumanoidRootPart") then
                local dist = (rootPart.Position - char.HumanoidRootPart.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearest = player
                end
            end
        end
    end
    
    return nearest
end

-- Create waypoint list from positions
function Utils.CreateWaypointList(positions)
    local waypoints = {}
    for _, pos in ipairs(positions) do
        table.insert(waypoints, {
            Position = pos,
            Action = Enum.PathWaypointAction.Walk
        })
    end
    return waypoints
end

-- Smooth path (remove unnecessary waypoints)
function Utils.SmoothPath(waypoints, threshold)
    threshold = threshold or 3
    local smoothed = {}
    
    for i, waypoint in ipairs(waypoints) do
        if i == 1 or i == #waypoints then
            table.insert(smoothed, waypoint)
        else
            local prev = waypoints[i-1].Position
            local curr = waypoint.Position
            local next = waypoints[i+1].Position
            
            local angle1 = (curr - prev).Unit
            local angle2 = (next - curr).Unit
            
            if angle1:Dot(angle2) < threshold then
                table.insert(smoothed, waypoint)
            end
        end
    end
    
    return smoothed
end

-- Calculate path length
function Utils.CalculatePathLength(waypoints)
    local length = 0
    for i = 1, #waypoints - 1 do
        length = length + (waypoints[i+1].Position - waypoints[i].Position).Magnitude
    end
    return length
end

-- Check if target is reachable
function Utils.IsReachable(character, target, config)
    local path = PathfindingService:CreatePath(config or {})
    local success = pcall(function()
        path:ComputeAsync(character.HumanoidRootPart.Position, target)
    end)
    return success and path.Status == Enum.PathStatus.Success
end

return Utils
