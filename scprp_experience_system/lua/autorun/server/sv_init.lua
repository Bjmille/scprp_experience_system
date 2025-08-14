-- SCP-RP Experience System - Server Initialization
-- File: scprp_experience_system/lua/autorun/server/sv_init.lua

-- This version is self-contained and doesn't depend on other modules being loaded first

-- Server-side initialization with proper error handling
local function InitializeSCPXP()
    print("[SCPXP] Starting server initialization...")
    
    -- Ensure SCPXP table exists
    if not SCPXP then
        print("[SCPXP ERROR] SCPXP global table not found!")
        return false
    end
    
    -- Ensure Config exists
    if not SCPXP.Config then
        print("[SCPXP ERROR] SCPXP.Config not found!")
        return false
    end
    
    -- Initialize database if available
    if SCPXP.Database and type(SCPXP.Database.Initialize) == "function" then
        local success, err = pcall(SCPXP.Database.Initialize, SCPXP.Database)
        if success then
            print("[SCPXP] Database initialized successfully")
        else
            print("[SCPXP ERROR] Database initialization failed: " .. tostring(err))
            return false
        end
    else
        print("[SCPXP WARNING] Database module not available")
    end
    
    -- Start activity timer if available
    if SCPXP.StartActivityTimer and type(SCPXP.StartActivityTimer) == "function" then
        local success, err = pcall(SCPXP.StartActivityTimer, SCPXP)
        if success then
            print("[SCPXP] Activity timer started")
        else
            print("[SCPXP ERROR] Activity timer failed: " .. tostring(err))
        end
    else
        print("[SCPXP WARNING] StartActivityTimer function not available")
    end
    
    -- Initialize admin system if available
    if SCPXP.InitializeAdmin and type(SCPXP.InitializeAdmin) == "function" then
        local success, err = pcall(SCPXP.InitializeAdmin, SCPXP)
        if success then
            print("[SCPXP] Admin system initialized")
        else
            print("[SCPXP ERROR] Admin initialization failed: " .. tostring(err))
        end
    else
        print("[SCPXP WARNING] InitializeAdmin function not available")
    end
    
    print("[SCPXP] Server initialization complete")
    return true
end

-- Hook into server initialization
hook.Add("Initialize", "SCPXP_ServerInit", function()
    -- Add a delay to ensure all includes have been processed
    timer.Simple(0.5, function()
        InitializeSCPXP()
    end)
end)

-- Create auto-save timer (self-contained)
local function CreateAutoSave()
    if not SCPXP or not SCPXP.Config then
        print("[SCPXP WARNING] Cannot create auto-save timer - config not available")
        return
    end
    
    local interval = SCPXP.Config.Database and SCPXP.Config.Database.autoSaveInterval or 300
    
    timer.Create("SCPXP_AutoSave", interval, 0, function()
        local savedCount = 0
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and not ply:IsBot() then
                if SCPXP.Database and type(SCPXP.Database.SavePlayer) == "function" then
                    local success = pcall(SCPXP.Database.SavePlayer, SCPXP.Database, ply)
                    if success then
                        savedCount = savedCount + 1
                    end
                end
            end
        end
        if savedCount > 0 and SCPXP.Debug then
            SCPXP:Debug("Auto-save completed for " .. savedCount .. " players")
        end
    end)
end

-- Start auto-save after initialization
hook.Add("Initialize", "SCPXP_AutoSaveInit", function()
    timer.Simple(1, function()
        CreateAutoSave()
    end)
end)