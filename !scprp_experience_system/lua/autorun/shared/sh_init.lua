-- Shared functions for SCPXP System
-- Place this in: addons/scprp_experience_system/lua/autorun/scpxp_shared.lua
SCPXP = SCPXP or {}

-- Network message strings (defined once for consistency)
SCPXP.NetworkMessages = {
    "SCPXP_OpenMenu",
    "SCPXP_UpdateClient", 
    "SCPXP_ShowGain",
    "SCPXP_LevelUp",
    "SCPXP_ShowTimedXP",
    "SCPXP_CreditRequest",
    "SCPXP_CreditApproval"
}

-- Register all network messages (server-side only)
if SERVER then
    for _, msgName in ipairs(SCPXP.NetworkMessages) do
        util.AddNetworkString(msgName)
    end
end

-- Utility Functions (shared between client and server)
function SCPXP:GetXPForLevel(level)
    if level <= 1 then return 0 end
    return math.floor(self.Config.BaseXP * (self.Config.XPMultiplier ^ (level - 1)))
end

function SCPXP:GetTotalXPForLevel(level)
    local total = 0
    for i = 2, level do
        total = total + self:GetXPForLevel(i)
    end
    return total
end

function SCPXP:GetLevelFromXP(totalXP)
    local level = 1
    local xpUsed = 0
    
    while level < self.Config.MaxLevel do
        local xpNeeded = self:GetXPForLevel(level + 1)
        if xpUsed + xpNeeded > totalXP then
            break
        end
        xpUsed = xpUsed + xpNeeded
        level = level + 1
    end
    
    return level
end

function SCPXP:GetCurrentLevelProgress(totalXP)
    local level = self:GetLevelFromXP(totalXP)
    local xpForCurrentLevel = self:GetTotalXPForLevel(level)
    local xpForNextLevel = self:GetTotalXPForLevel(level + 1)
    local currentXP = totalXP - xpForCurrentLevel
    local neededXP = xpForNextLevel - xpForCurrentLevel
    
    return currentXP, neededXP
end

-- Network message handlers (shared)
if SERVER then
    -- Server receives client requests here
    net.Receive("SCPXP_OpenMenu", function(len, ply)
        -- Handle menu open request if needed
    end)
    
    -- Handle credit approval responses from staff
    net.Receive("SCPXP_CreditApproval", function(len, ply)
        local requestId = net.ReadString()
        local approved = net.ReadBool()
        
        -- Verify the player has permission to approve credits
        if not SCPXP:CanPlayerApproveCredits(ply) then
            return
        end
        
        -- Handle the approval/denial
        if SCPXP.HandleCreditApproval then
            SCPXP:HandleCreditApproval(requestId, approved, ply)
        end
    end)
end

if CLIENT then
    -- Client receives server updates
    net.Receive("SCPXP_UpdateClient", function()
        local data = net.ReadTable()
        LocalPlayer().SCPXPData = data
        
        -- Update UI if menu is open
        if SCPXP.MenuPanel and IsValid(SCPXP.MenuPanel) then
            SCPXP:RefreshMenu()
        end
    end)
    
    net.Receive("SCPXP_ShowGain", function()
        local category = net.ReadString()
        local amount = net.ReadInt(32)
        local reason = net.ReadString()
        
        SCPXP:ShowXPGain(category, amount, reason)
    end)
    
    net.Receive("SCPXP_LevelUp", function()
        local category = net.ReadString()
        local level = net.ReadInt(8)
        local message = net.ReadString()
        
        SCPXP:ShowLevelUp(category, level, message)
    end)
    
    net.Receive("SCPXP_ShowTimedXP", function()
        local category = net.ReadString()
        local amount = net.ReadInt(32)
        
        SCPXP:ShowTimedXPGain(category, amount)
    end)
    
    net.Receive("SCPXP_CreditRequest", function()
        local requestId = net.ReadString()
        local researcherName = net.ReadString()
        local targetName = net.ReadString()
        local researcherSteamID = net.ReadString()
        local targetSteamID = net.ReadString()
        local autoApproved = net.ReadBool()
        
        -- Handle the credit request (UI creation is handled by approval_ui.lua)
        if SCPXP.CreateApprovalNotification then
            SCPXP:CreateApprovalNotification(requestId, researcherName, targetName, autoApproved)
        end
        
        -- Optional chat notification (less prominent now)
        local chatColor = autoApproved and Color(100, 255, 100) or Color(255, 200, 100)
        local chatText = autoApproved and "Auto-approved credit: " or "Credit request: "
        
        chat.AddText(chatColor, "[SCPXP] ", Color(255, 255, 255), 
            chatText .. researcherName .. " → " .. targetName)
    end)
end

-- Shared utility functions for credit approval system
function SCPXP:GenerateRequestId()
    -- Generate a unique request ID (server-side only)
    if SERVER then
        return "req_" .. os.time() .. "_" .. math.random(1000, 9999)
    end
    return nil
end

-- Permission checking function (to be implemented server-side)
function SCPXP:CanPlayerApproveCredits(ply)
    -- This should be implemented in the server-side code
    -- Default to false for safety
    return false
end