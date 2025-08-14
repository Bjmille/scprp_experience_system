-- SCP-RP Experience System - Client Initialization
-- File: scprp_experience_system/lua/autorun/client/cl_init.lua

-- Include shared files
include("shared/sh_init.lua")

-- Include client modules
include("client/cl_notifications.lua")
include("client/cl_ui.lua")
include("client/cl_hud.lua")
include("client/cl_admin.lua")

-- Client-side data storage
SCPXP.ClientData = {}
SCPXP.UI = SCPXP.UI or {}

-- Initialize client
hook.Add("InitPostEntity", "SCPXP_ClientInit", function()
    SCPXP:Debug("Client initialization complete")
    
    -- Request initial data from server
    timer.Simple(2, function()
        net.Start("SCPXP_RequestData")
        net.SendToServer()
    end)
end)

-- Network Receivers
net.Receive("SCPXP_SendData", function()
    local data = net.ReadTable()
    SCPXP.ClientData = data
    
    SCPXP:Debug("Received XP data from server")
    
    -- Update UI if it's open
    if SCPXP.UI.XPPanel and IsValid(SCPXP.UI.XPPanel) then
        SCPXP.UI:RefreshXPPanel()
    end
end)

-- Utility Functions for Client
function SCPXP:GetClientLevelProgress(category)
    local xp = self:GetClientXP(category)
    local currentLevel = self:GetClientLevel(category)
    local currentLevelXP = self:GetXPForLevel(currentLevel)
    local nextLevelXP = self:GetXPForLevel(currentLevel + 1)
    
    if nextLevelXP <= currentLevelXP then return 1 end
    
    return (xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
end

function SCPXP:GetClientXPForNextLevel(category)
    local currentLevel = self:GetClientLevel(category)
    local nextLevelXP = self:GetXPForLevel(currentLevel + 1)
    local currentXP = self:GetClientXP(category)
    return nextLevelXP - currentXP
end

-- Console Commands for Client
concommand.Add("scpxp_ui", function()
    SCPXP.UI:OpenXPPanel()
end)

concommand.Add("scpxp_hud_toggle", function()
    SCPXP.Config.ShowHUD = not SCPXP.Config.ShowHUD
    chat.AddText(Color(100, 200, 100), "[SCPXP] ", Color(255, 255, 255), "HUD " .. (SCPXP.Config.ShowHUD and "enabled" or "disabled"))
end)XP(category)
    return SCPXP.ClientData[category] or 0
end

function SCPXP:GetClientLevel(category)
    local xp = self:GetClientXP(category)
    if xp <= 0 then return 0 end
    
    local multiplier = SCPXP.Config.XPMultiplier
    local baseXP = SCPXP.Config.BaseXP
    
    local level = math.log(xp * (multiplier - 1) / baseXP + 1) / math.log(multiplier)
    return math.floor(level)
end

function SCPXP:GetClient