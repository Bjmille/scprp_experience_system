-- SCP-RP Experience System - Client Initialization
-- File: scprp_experience_system/lua/autorun/client/cl_init.lua

-- Include shared files
include("autorun/shared/sh_init.lua")

-- Client-side initialization
print("[SCPXP] Client initialization starting...")

-- Initialize client data
SCPXP.ClientData = SCPXP.ClientData or {
    research = 0,
    security = 0,
    prisoner = 0,
    scp = 0,
    lastUpdate = 0
}

-- Request XP data from server
function SCPXP:RequestXPData()
    if IsValid(LocalPlayer()) then
        net.Start("SCPXP_RequestData")
        net.SendToServer()
    end
end

-- Update local XP data
function SCPXP:UpdateXPData(data)
    if type(data) ~= "table" then return end
    
    for category, xp in pairs(data) do
        if SCPXP:IsValidCategory(category) and type(xp) == "number" then
            SCPXP.ClientData[category] = xp
        end
    end
    
    SCPXP.ClientData.lastUpdate = CurTime()
end

-- Get local XP data
function SCPXP:GetLocalXP(category)
    return SCPXP.ClientData[category] or 0
end

-- Network handlers
net.Receive("SCPXP_SendData", function()
    local data = net.ReadTable()
    SCPXP:UpdateXPData(data)
end)

-- Auto-request data when spawning
hook.Add("OnPlayerSpawn", "SCPXP_RequestOnSpawn", function()
    timer.Simple(1, function()
        SCPXP:RequestXPData()
    end)
end)

-- Request data when client fully loads
hook.Add("InitPostEntity", "SCPXP_InitialRequest", function()
    timer.Simple(3, function()
        SCPXP:RequestXPData()
    end)
end)

-- Periodic data refresh
timer.Create("SCPXP_DataRefresh", 300, 0, function() -- Every 5 minutes
    SCPXP:RequestXPData()
end)

-- Chat commands
hook.Add("OnPlayerChat", "SCPXP_ChatCommands", function(ply, text)
    if ply ~= LocalPlayer() then return end
    
    local cmd = string.lower(string.Trim(text))
    
    if cmd == "!xp" or cmd == "!level" or cmd == "/xp" or cmd == "/level" then
        SCPXP:RequestXPData()
        
        timer.Simple(0.5, function()
            SCPXP:ShowXPMenu()
        end)
        
        return true
    end
end)

-- Show XP menu/panel
function SCPXP:ShowXPMenu()
    -- Simple XP display in chat for now
    chat.AddText(Color(100, 255, 100), "[SCPXP] ", Color(255, 255, 255), "Your Experience:")
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        local xp = self:GetLocalXP(category)
        local level = self:GetPlayerLevel({SteamID64 = function() return "local" end}, category)
        local color = config.color
        
        chat.AddText(Color(color.r, color.g, color.b), config.displayName, Color(255, 255, 255), ": Level ", Color(255, 255, 100), tostring(level), Color(255, 255, 255), " (", Color(200, 200, 200), SCPXP:FormatXP(xp), Color(255, 255, 255), " XP)")
    end
end

-- Override GetPlayerLevel for local player
local originalGetPlayerLevel = SCPXP.GetPlayerLevel
function SCPXP:GetPlayerLevel(ply, category)
    if ply and ply.SteamID64 and ply:SteamID64() == "local" then
        local xp = self:GetLocalXP(category)
        if xp <= 0 then return 0 end
        
        local multiplier = self.Config.XPMultiplier
        local baseXP = self.Config.BaseXP
        
        local level = math.log(xp * (multiplier - 1) / baseXP + 1) / math.log(multiplier)
        return math.floor(level)
    else
        return originalGetPlayerLevel(self, ply, category)
    end
end

-- Override GetPlayerXP for local player
local originalGetPlayerXP = SCPXP.GetPlayerXP
function SCPXP:GetPlayerXP(ply, category)
    if ply and ply.SteamID64 and ply:SteamID64() == "local" then
        return self:GetLocalXP(category)
    else
        return originalGetPlayerXP(self, ply, category)
    end
end

print("[SCPXP] Client initialization complete")