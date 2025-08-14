-- SCP-RP Experience System - Main Initialization
-- File: scprp_experience_system/lua/autorun/scprp_xp_init.lua

-- Determine the base path for includes
local basePath = "scprp_experience_system/"

-- Print loading message
print("=====================================")
print("    SCP-RP Experience System v1.0")
print("         Loading modules...")
print("=====================================")

-- Initialize the main SCPXP table
SCPXP = SCPXP or {}
SCPXP.Version = "1.0"
SCPXP.LoadedModules = {}

-- Module loading function
function SCPXP.LoadModule(path, realm)
    local fullPath = basePath .. path
    
    if realm == "shared" or realm == SERVER then
        if SERVER then
            include(fullPath)
            AddCSLuaFile(fullPath)
            SCPXP.LoadedModules[path] = "server+client"
        end
    elseif realm == CLIENT then
        if CLIENT then
            include(fullPath)
            SCPXP.LoadedModules[path] = "client"
        end
    elseif realm == "server" then
        if SERVER then
            include(fullPath)
            SCPXP.LoadedModules[path] = "server"
        end
    end
    
    print("[SCPXP] Loaded: " .. path .. " (" .. (realm or "unknown") .. ")")
end

-- Load modules in correct order

-- 1. Load configuration first (shared)
SCPXP.LoadModule("config/sh_config.lua", "shared")

-- 2. Load shared initialization
SCPXP.LoadModule("shared/sh_init.lua", "shared")

-- 3. Load server modules
if SERVER then
    SCPXP.LoadModule("server/sv_database.lua", "server")
    SCPXP.LoadModule("server/sv_xp.lua", "server")
    SCPXP.LoadModule("server/sv_credit.lua", "server")
    SCPXP.LoadModule("server/sv_combat.lua", "server")
    SCPXP.LoadModule("server/sv_admin.lua", "server")
    SCPXP.LoadModule("server/sv_hooks.lua", "server")
    SCPXP.LoadModule("server/sv_init.lua", "server")
end

-- 4. Load client modules
if CLIENT then
    SCPXP.LoadModule("client/cl_notifications.lua", CLIENT)
    SCPXP.LoadModule("client/cl_ui.lua", CLIENT)
    SCPXP.LoadModule("client/cl_hud.lua", CLIENT)
    SCPXP.LoadModule("client/cl_admin.lua", CLIENT)
    SCPXP.LoadModule("client/cl_init.lua", CLIENT)
elseif SERVER then
    -- Add client files to download
    AddCSLuaFile(basePath .. "client/cl_notifications.lua")
    AddCSLuaFile(basePath .. "client/cl_ui.lua")
    AddCSLuaFile(basePath .. "client/cl_hud.lua")
    AddCSLuaFile(basePath .. "client/cl_admin.lua")
    AddCSLuaFile(basePath .. "client/cl_init.lua")
end

-- Final initialization message
timer.Simple(1, function()
    print("=====================================")
    print("  SCP-RP Experience System Loaded")
    print("    Modules: " .. table.Count(SCPXP.LoadedModules))
    print("    Version: " .. SCPXP.Version)
    print("=====================================")
end)