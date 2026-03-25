# Pathfind API - Advanced Pathfinding for Roblox Executors

A powerful, easy-to-use pathfinding module for Roblox executors (Synapse X, Krnl, ScriptWare, etc.) with dynamic path updating, stuck detection, and smooth movement.

## Features

- ✅ **Dynamic Path Updating** - Automatically recalculates paths around moving obstacles
- ✅ **Stuck Detection** - Detects when character is stuck and recalculates path
- ✅ **Smooth Movement** - Optional BodyVelocity-based movement
- ✅ **Path Visualization** - Visualize paths with customizable colors
- ✅ **Multiple Movement Modes** - Standard, smooth, or teleport movement
- ✅ **Noclip Support** - Optional noclip while pathfinding
- ✅ **Callback System** - Events for start, arrival, stuck, and errors
- ✅ **Manager System** - Manage multiple pathfinding instances
- ✅ **Utility Functions** - Helper functions for common tasks

## Installation

### Method 1: Raw GitHub URL
```lua
local PathfindModule = loadstring(game:HttpGet("https://raw.githubusercontent.com/yourusername/pathfind-api/main/src/PathfindModule.lua"))()
