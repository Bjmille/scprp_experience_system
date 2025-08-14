-- SCP-RP Experience System - Server Initialization
-- File: scprp_experience_system/lua/autorun/server/sv_init.lua

-- Include shared files
include("shared/sh_init.lua")

-- Include server modules
include("server/sv_database.lua")
include("server/sv_xp.lua") 
include("server/sv_credit.lua")
include("server/sv_combat.lua")
include("server/sv_admin.lua")
include("server/sv_hooks.lua")
include("server/main.lua")

-- Server-side initialization
hook.Add("Initialize", "SCPXP_ServerInit", function()
    SCPXP:Debug("Starting server initialization...")
    
    -- Initialize database
    if SCPXP.Database and SCPXP.Database.Initialize then
        SCPXP.Database:Initialize()
        SCPXP:Debug("Database initialized")
    end
    
    -- Start activity timer
    if SCPXP.StartActivityTimer then
        SCPXP:StartActivityTimer()
        SCPXP:Debug("Activity timer started")
    end
    
    -- Initialize admin system
    if SCPXP.InitializeAdmin then
        SCPXP:InitializeAdmin()
        SCPXP:Debug("Admin system initialized")
    end
    
    print("[SCPXP] Server initialization complete")
end)

-- Auto-save timer
timer.Create("SCPXP_AutoSave", SCPXP.Config.Database.autoSaveInterval, 0, function()
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsBot() then
            SCPXP.Database:SavePlayer(ply)
        end
    end
    SCPXP:Debug("Auto-save completed for " .. #player.GetAll() .. " players")
end)