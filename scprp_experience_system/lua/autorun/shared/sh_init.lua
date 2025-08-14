-- SCP-RP Experience System - Shared Initialization
-- File: scprp_experience_system/lua/autorun/shared/sh_init.lua

SCPXP = SCPXP or {}
SCPXP.Players = SCPXP.Players or {}

-- Load configuration first (use autorun path since we're already in autorun folder)
-- Note: Config is already loaded by scprp_xp_init.lua, so we don't need to include it again
-- include("config/sh_config.lua")  -- This was causing the error

-- Network Strings
if SERVER then
    util.AddNetworkString("SCPXP_Notification")
    util.AddNetworkString("SCPXP_CreditRequest")
    util.AddNetworkString("SCPXP_CreditResponse")
    util.AddNetworkString("SCPXP_RequestData")
    util.AddNetworkString("SCPXP_SendData")
    util.AddNetworkString("SCPXP_AdminPanel")
end

-- Shared Utility Functions
function SCPXP:GetPlayerXP(ply, category)
    if not IsValid(ply) or not category then return 0 end
    
    local steamid = ply:SteamID64()
    if not SCPXP.Players[steamid] then return 0 end
    
    return SCPXP.Players[steamid][category] or 0
end

function SCPXP:GetPlayerLevel(ply, category)
    local xp = self:GetPlayerXP(ply, category)
    if xp <= 0 then return 0 end
    
    -- Calculate level using exponential formula
    -- XP for level n = BaseXP * (Multiplier^n - 1) / (Multiplier - 1)
    -- Solving for level: n = log(XP * (Multiplier - 1) / BaseXP + 1) / log(Multiplier)
    local multiplier = SCPXP.Config.XPMultiplier
    local baseXP = SCPXP.Config.BaseXP
    
    local level = math.log(xp * (multiplier - 1) / baseXP + 1) / math.log(multiplier)
    return math.floor(level)
end

function SCPXP:GetXPForLevel(level)
    if level <= 0 then return 0 end
    
    -- XP required for level n = BaseXP * (Multiplier^n - 1) / (Multiplier - 1)
    local multiplier = SCPXP.Config.XPMultiplier
    local baseXP = SCPXP.Config.BaseXP
    
    return math.floor(baseXP * (math.pow(multiplier, level) - 1) / (multiplier - 1))
end

function SCPXP:GetXPForNextLevel(ply, category)
    local currentLevel = self:GetPlayerLevel(ply, category)
    local nextLevelXP = self:GetXPForLevel(currentLevel + 1)
    local currentXP = self:GetPlayerXP(ply, category)
    return nextLevelXP - currentXP
end

function SCPXP:GetLevelProgress(ply, category)
    local xp = self:GetPlayerXP(ply, category)
    local currentLevel = self:GetPlayerLevel(ply, category)
    local currentLevelXP = self:GetXPForLevel(currentLevel)
    local nextLevelXP = self:GetXPForLevel(currentLevel + 1)
    
    if nextLevelXP <= currentLevelXP then return 1 end
    
    return (xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
end

-- Job Category Detection
function SCPXP:GetPlayerJobCategory(ply)
    if not IsValid(ply) then return "prisoner" end
    
    local job = ply:getDarkRPVar("job") or ""
    if job == "" and ply.GetJobTable then
        local jobTable = ply:GetJobTable()
        if jobTable then
            job = jobTable.name or ""
        end
    end
    
    job = string.lower(job)
    
    -- Check each category
    for category, keywords in pairs(SCPXP.Config.JobCategories) do
        for _, keyword in ipairs(keywords) do
            if string.find(job, string.lower(keyword), 1, true) then
                return category
            end
        end
    end
    
    -- Default to prisoner if no match
    return "prisoner"
end

-- Validation Functions
function SCPXP:IsValidCategory(category)
    return SCPXP.Config.XPCategories[category] ~= nil
end

function SCPXP:IsAdmin(ply)
    if not IsValid(ply) then return false end
    
    -- Check if player is in admin groups
    for _, group in ipairs(SCPXP.Config.AdminGroups) do
        if ply:IsUserGroup(group) then
            return true
        end
    end
    
    -- Fallback to built-in admin check
    return ply:IsAdmin() or ply:IsSuperAdmin()
end

-- Formatting Functions
function SCPXP:FormatXP(xp)
    if xp >= 1000000 then
        return string.format("%.1fM", xp / 1000000)
    elseif xp >= 1000 then
        return string.format("%.1fK", xp / 1000)
    else
        return tostring(xp)
    end
end

function SCPXP:FormatTime(seconds)
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    
    if hours > 0 then
        return string.format("%dh %dm", hours, minutes)
    elseif minutes > 0 then
        return string.format("%dm %ds", minutes, secs)
    else
        return string.format("%ds", secs)
    end
end

-- Color Functions
function SCPXP:GetCategoryColor(category)
    local config = SCPXP.Config.XPCategories[category]
    return config and config.color or Color(255, 255, 255)
end

function SCPXP:GetCategoryName(category)
    local config = SCPXP.Config.XPCategories[category]
    return config and config.displayName or "Unknown"
end

-- Debug Functions (only in development)
if GetConVar("developer") and GetConVar("developer"):GetInt() > 0 then
    function SCPXP:Debug(message)
        print("[SCPXP DEBUG] " .. tostring(message))
    end
else
    function SCPXP:Debug(message) end
end

-- Initialize shared data structure
for steamid, data in pairs(SCPXP.Players) do
    if type(data) ~= "table" then
        SCPXP.Players[steamid] = {
            research = 0,
            security = 0,
            prisoner = 0,
            scp = 0,
            last_activity = 0,
            last_credit = 0
        }
    end
end

print("[SCPXP] Shared initialization complete")