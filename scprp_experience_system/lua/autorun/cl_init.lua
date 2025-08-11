-- Simple client initialization file
-- Place this in: addons/scprp_experience_system/lua/autorun/cl_init.lua

if not CLIENT then return end

-- Make sure SCPXP is initialized before we try to use it
SCPXP = SCPXP or {}

-- Wait for the main system to load
hook.Add("InitPostEntity", "SCPXP_ClientReady", function()
    -- Client is ready, system should be loaded
    print("[SCPXP] Client ready!")
end)