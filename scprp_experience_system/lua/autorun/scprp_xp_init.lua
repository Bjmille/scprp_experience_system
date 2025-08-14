-- SCP-RP Experience System - Main Initialization (Simplified)
-- File: scprp_experience_system/lua/autorun/scprp_xp_init.lua

-- Print loading message
print("=====================================")
print("    SCP-RP Experience System v1.0")
print("         Loading modules...")
print("=====================================")

-- Initialize the main SCPXP table
SCPXP = SCPXP or {}
SCPXP.Version = "1.0"

-- Load configuration first (shared)
include("autorun/config/sh_config.lua")
AddCSLuaFile("autorun/config/sh_config.lua")
print("[SCPXP] Loaded: config/sh_config.lua (shared)")

-- Load shared initialization
include("autorun/shared/sh_init.lua") 
AddCSLuaFile("autorun/shared/sh_init.lua")
print("[SCPXP] Loaded: shared/sh_init.lua (shared)")

-- Server-side includes
if SERVER then
    include("autorun/server/sv_database.lua")
    print("[SCPXP] Loaded: server/sv_database.lua (server)")
    
    include("autorun/server/sv_xp.lua")
    print("[SCPXP] Loaded: server/sv_xp.lua (server)")
    
    include("autorun/server/sv_credit.lua")
    print("[SCPXP] Loaded: server/sv_credit.lua (server)")
    
    include("autorun/server/sv_combat.lua")
    print("[SCPXP] Loaded: server/sv_combat.lua (server)")
    
    include("autorun/server/sv_admin.lua")
    print("[SCPXP] Loaded: server/sv_admin.lua (server)")
    
    include("autorun/server/sv_hooks.lua")
    print("[SCPXP] Loaded: server/sv_hooks.lua (server)")
    
    -- Load sv_init.lua LAST to ensure all modules are available
    include("autorun/server/sv_init.lua")
    print("[SCPXP] Loaded: server/sv_init.lua (server)")
    
    -- Add client files to download
    AddCSLuaFile("autorun/client/cl_notifications.lua")
    AddCSLuaFile("autorun/client/cl_ui.lua") 
    AddCSLuaFile("autorun/client/cl_hud.lua")
    AddCSLuaFile("autorun/client/cl_admin.lua")
    AddCSLuaFile("autorun/client/cl_init.lua")
end

-- Client-side includes
if CLIENT then
    include("autorun/client/cl_notifications.lua")
    print("[SCPXP] Loaded: client/cl_notifications.lua (client)")
    
    include("autorun/client/cl_ui.lua")
    print("[SCPXP] Loaded: client/cl_ui.lua (client)")
    
    include("autorun/client/cl_hud.lua")
    print("[SCPXP] Loaded: client/cl_hud.lua (client)")
    
    include("autorun/client/cl_admin.lua")  
    print("[SCPXP] Loaded: client/cl_admin.lua (client)")
    
    include("autorun/client/cl_init.lua")
    print("[SCPXP] Loaded: client/cl_init.lua (client)")
end

-- Final initialization message
timer.Simple(1, function()
    print("=====================================")
    print("  SCP-RP Experience System Loaded")
    print("    Version: " .. SCPXP.Version)
    print("=====================================")
end)