-- Shared initialization file for SCPXP System
-- Place this in: addons/scprp_experience_system/lua/autorun/sh_scpxp_init.lua

-- Initialize SCPXP table
SCPXP = SCPXP or {}

-- Load config first (shared)
if file.Exists("autorun/scpxp_config.lua", "LUA") then
    include("autorun/scpxp_config.lua")
else
    print("[SCPXP] Warning: Config file not found! Make sure scpxp_config.lua exists.")
end

-- Load shared functions
if file.Exists("autorun/scpxp_shared.lua", "LUA") then
    include("autorun/scpxp_shared.lua")
else
    print("[SCPXP] Warning: Shared file not found! Make sure scpxp_shared.lua exists.")
end

-- Server-side initialization
if SERVER then
    -- Add network strings first
    util.AddNetworkString("SCPXP_UpdateClient")
    util.AddNetworkString("SCPXP_ShowGain")
    util.AddNetworkString("SCPXP_LevelUp")
    util.AddNetworkString("SCPXP_OpenMenu")
    util.AddNetworkString("SCPXP_ShowTimedXP")
    util.AddNetworkString("SCPXP_CreditRequest")
    util.AddNetworkString("SCPXP_CreditApproval")
    
    -- Load server files
    if file.Exists("autorun/scpxp_server.lua", "LUA") then
        include("autorun/scpxp_server.lua")
    else
        print("[SCPXP] Error: Server file not found! Make sure scpxp_server.lua exists.")
    end
    
    -- Send client files to players
    AddCSLuaFile("autorun/scpxp_config.lua")
    AddCSLuaFile("autorun/scpxp_shared.lua")
    AddCSLuaFile("autorun/client/scpxp_client.lua")
    AddCSLuaFile("autorun/client/scpxp_approval_ui.lua")
    AddCSLuaFile("autorun/cl_init.lua")
    
    print("[SCPXP] Server initialized successfully!")
end

-- Client-side initialization
if CLIENT then
    -- Load client files
    if file.Exists("autorun/client/scpxp_client.lua", "LUA") then
        include("autorun/client/scpxp_client.lua")
    else
        print("[SCPXP] Error: Client file not found! Make sure scpxp_client.lua exists.")
    end
    
    print("[SCPXP] Client initialized successfully!")
end