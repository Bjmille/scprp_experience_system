-- CLIENT-SIDE CODE
-- Place this in: addons/scprp_experience_system/lua/autorun/client/scpxp_client.lua

if not CLIENT then return end

SCPXP = SCPXP or {}
SCPXP.PlayerData = {}
SCPXP.NotificationQueue = {}
SCPXP.ActiveNotifications = {}
SCPXP.ActiveApprovals = {} -- For approval notifications

-- Create XP gain notification
function SCPXP:ShowXPGain(category, amount, reason)
    local notification = {
        category = category,
        amount = amount,
        reason = reason or "",
        timestamp = CurTime(),
        type = "xp_gain"
    }
    
    table.insert(self.NotificationQueue, notification)
    self:ProcessNotificationQueue()
end

-- Create level up notification
function SCPXP:ShowLevelUp(category, newLevel, message)
    local notification = {
        category = category,
        level = newLevel,
        message = message or "Level Up!",
        timestamp = CurTime(),
        type = "level_up"
    }
    
    table.insert(self.NotificationQueue, notification)
    self:ProcessNotificationQueue()
end

-- Create timed XP notification
function SCPXP:ShowTimedXP(category, amount)
    local notification = {
        category = category,
        amount = amount,
        reason = "Hourly Activity Bonus",
        timestamp = CurTime(),
        type = "timed_xp"
    }
    
    table.insert(self.NotificationQueue, notification)
    self:ProcessNotificationQueue()
end

-- Process notification queue
function SCPXP:ProcessNotificationQueue()
    if #self.NotificationQueue == 0 then return end
    if #self.ActiveNotifications >= 3 then return end -- Max 3 notifications at once
    
    local notification = table.remove(self.NotificationQueue, 1)
    self:CreateNotificationPanel(notification)
end

-- Create notification panel
function SCPXP:CreateNotificationPanel(notification)
    local scrW, scrH = ScrW(), ScrH()
    
    -- Create main panel
    local panel = vgui.Create("DPanel")
    panel:SetSize(350, 80)
    panel:SetPos(scrW + 50, 20) -- Start off-screen
    
    -- Store metadata for tracking
    panel.SCPXPData = {
        timestamp = CurTime(),
        type = notification.type,
        category = notification.category
    }
    
    -- Get category info
    local categoryInfo = self.Config.Categories[notification.category]
    if not categoryInfo then 
        panel:Remove()
        return 
    end
    
    -- Colors based on notification type
    local bgColor = Color(30, 30, 35, 250)
    local accentColor = categoryInfo.color or Color(100, 149, 237)
    
    if notification.type == "level_up" then
        accentColor = Color(255, 215, 0) -- Gold for level up
    elseif notification.type == "timed_xp" then
        accentColor = Color(147, 112, 219) -- Purple for timed XP
    end
    
    panel.Paint = function(self, w, h)
        -- Main background
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
        
        -- Accent line
        draw.RoundedBox(8, 0, 0, 4, h, accentColor)
        
        -- Inner glow
        draw.RoundedBox(8, 2, 2, w-4, h-4, Color(45, 45, 50, 100))
    end
    
    -- Icon
    local icon = vgui.Create("DLabel", panel)
    icon:SetPos(15, 15)
    icon:SetSize(30, 30)
    icon:SetTextColor(accentColor)
    icon:SetFont("DermaLarge")
    
    -- Title and content based on type
    local title = vgui.Create("DLabel", panel)
    title:SetPos(55, 10)
    title:SetSize(280, 20)
    title:SetTextColor(Color(255, 255, 255))
    title:SetFont("DermaDefaultBold")
    
    local subtitle = vgui.Create("DLabel", panel)
    subtitle:SetPos(55, 30)
    subtitle:SetSize(280, 40)
    subtitle:SetTextColor(Color(200, 200, 200))
    subtitle:SetFont("DermaDefault")
    subtitle:SetWrap(true)
    
    if notification.type == "xp_gain" or notification.type == "timed_xp" then
        icon:SetText("+")
        title:SetText(string.format("+%d %s XP", notification.amount, categoryInfo.name))
        subtitle:SetText(notification.reason)
    elseif notification.type == "level_up" then
        icon:SetText("★")
        title:SetText(string.format("%s Level %d!", categoryInfo.name, notification.level))
        subtitle:SetText(notification.message)
    end
    
    -- Add to active notifications
    table.insert(self.ActiveNotifications, panel)
    
    -- Calculate position
    local yPos = self:GetNextXPNotificationY()
    
    -- Slide-in animation
    panel:MoveTo(scrW - 370, yPos, 0.4, 0, 1)
    
    -- Auto-remove after delay with safety check
    local removeTime = notification.type == "level_up" and 8 or 3
    local timerName = "SCPXP_Remove_" .. tostring(panel)
    
    timer.Create(timerName, removeTime, 1, function()
        if IsValid(panel) then
            self:RemoveXPNotification(panel)
        end
    end)
    
    -- Failsafe: Force remove after maximum time
    local failsafeTime = removeTime + 5
    timer.Simple(failsafeTime, function()
        if IsValid(panel) then
            print("[SCPXP] Failsafe: Removing stuck notification")
            self:RemoveXPNotification(panel, true)
        end
    end)
    
    -- Play sound
    if notification.type == "level_up" then
        surface.PlaySound("buttons/button3.wav")
    elseif notification.type == "timed_xp" then
        surface.PlaySound("buttons/button17.wav")
    else
        surface.PlaySound("buttons/button15.wav")
    end
end

-- Calculate Y position for XP notifications (separate from approval notifications)
function SCPXP:GetNextXPNotificationY()
    local yPos = 20
    local spacing = 10
    
    -- Account for approval notifications first
    for _, approval in pairs(self.ActiveApprovals) do
        if IsValid(approval.panel) then
            yPos = yPos + approval.height + spacing
        end
    end
    
    -- Then account for existing XP notifications
    for _, panel in ipairs(self.ActiveNotifications) do
        if IsValid(panel) then
            yPos = yPos + panel:GetTall() + spacing
        end
    end
    
    return yPos
end

-- Remove XP notification
function SCPXP:RemoveXPNotification(panel, isFailsafe)
    if not IsValid(panel) then return end
    
    -- Clean up timer if it exists
    local timerName = "SCPXP_Remove_" .. tostring(panel)
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    -- Remove from active list
    for i, activePanel in ipairs(self.ActiveNotifications) do
        if activePanel == panel then
            table.remove(self.ActiveNotifications, i)
            break
        end
    end
    
    -- Slide out animation (or immediate removal for failsafe)
    if isFailsafe then
        panel:Remove()
        self:ProcessNotificationQueue()
        timer.Simple(0.1, function()
            self:RepositionXPNotifications()
        end)
    else
        panel:MoveTo(ScrW() + 50, panel.y, 0.3, 0, 1, function()
            if IsValid(panel) then
                panel:Remove()
            end
            
            -- Process queue and reposition
            self:ProcessNotificationQueue()
            timer.Simple(0.1, function()
                self:RepositionXPNotifications()
            end)
        end)
    end
end

-- Reposition XP notifications
function SCPXP:RepositionXPNotifications()
    local yPos = 20
    local spacing = 10
    
    -- Account for approval notifications first
    for _, approval in pairs(self.ActiveApprovals) do
        if IsValid(approval.panel) then
            yPos = yPos + approval.height + spacing
        end
    end
    
    -- Reposition XP notifications
    for _, panel in ipairs(self.ActiveNotifications) do
        if IsValid(panel) then
            panel:MoveTo(ScrW() - 370, yPos, 0.2, 0, 1)
            yPos = yPos + panel:GetTall() + spacing
        end
    end
end

-- Clean up stuck notifications (call this manually if needed)
function SCPXP:CleanupStuckNotifications()
    local currentTime = CurTime()
    local cleaned = 0
    
    for i = #self.ActiveNotifications, 1, -1 do
        local panel = self.ActiveNotifications[i]
        if IsValid(panel) and panel.SCPXPData then
            local age = currentTime - panel.SCPXPData.timestamp
            local maxAge = panel.SCPXPData.type == "level_up" and 15 or 10
            
            if age > maxAge then
                print("[SCPXP] Cleaning up stuck notification (age: " .. math.Round(age, 1) .. "s)")
                self:RemoveXPNotification(panel, true)
                cleaned = cleaned + 1
            end
        elseif IsValid(panel) then
            -- Panel without metadata, assume it's stuck
            print("[SCPXP] Cleaning up notification without metadata")
            self:RemoveXPNotification(panel, true)
            cleaned = cleaned + 1
        else
            -- Invalid panel, remove from list
            table.remove(self.ActiveNotifications, i)
        end
    end
    
    if cleaned > 0 then
        print("[SCPXP] Cleaned up " .. cleaned .. " stuck notifications")
    end
end

-- Auto cleanup check every 30 seconds
timer.Create("SCPXP_AutoCleanup", 30, 0, function()
    if SCPXP and SCPXP.CleanupStuckNotifications then
        SCPXP:CleanupStuckNotifications()
    end
end)

-- Console command for manual cleanup
concommand.Add("scpxp_cleanup", function()
    SCPXP:CleanupStuckNotifications()
    print("[SCPXP] Manual cleanup completed")
end)

-- Update player data from server
function SCPXP:UpdatePlayerData(data)
    self.PlayerData = data
    hook.Run("SCPXP_DataUpdated", data)
end

-- Get player's current XP in category
function SCPXP:GetPlayerXP(category)
    if not self.PlayerData[category] then return 0 end
    return self.PlayerData[category].totalXP or 0
end

-- Get player's current level in category
function SCPXP:GetPlayerLevel(category)
    if not self.PlayerData[category] then return 1 end
    return self.PlayerData[category].level or 1
end

-- Calculate XP needed for next level
function SCPXP:GetXPForNextLevel(category)
    local currentLevel = self:GetPlayerLevel(category)
    local currentXP = self:GetPlayerXP(category)
    local nextLevelXP = self:GetXPRequiredForLevel(currentLevel + 1)
    
    return nextLevelXP - currentXP
end

-- Get XP progress as percentage
function SCPXP:GetLevelProgress(category)
    local currentLevel = self:GetPlayerLevel(category)
    local currentXP = self:GetPlayerXP(category)
    local currentLevelXP = self:GetXPRequiredForLevel(currentLevel)
    local nextLevelXP = self:GetXPRequiredForLevel(currentLevel + 1)
    
    if nextLevelXP == currentLevelXP then return 100 end
    
    local progress = (currentXP - currentLevelXP) / (nextLevelXP - currentLevelXP)
    return math.Clamp(progress * 100, 0, 100)
end

-- Network receivers
net.Receive("SCPXP_UpdateClient", function()
    local data = net.ReadTable()
    SCPXP:UpdatePlayerData(data)
end)

net.Receive("SCPXP_ShowGain", function()
    local category = net.ReadString()
    local amount = net.ReadInt(32)
    local reason = net.ReadString()
    
    SCPXP:ShowXPGain(category, amount, reason)
end)

net.Receive("SCPXP_LevelUp", function()
    local category = net.ReadString()
    local newLevel = net.ReadInt(8)
    local message = net.ReadString()
    
    SCPXP:ShowLevelUp(category, newLevel, message)
end)

net.Receive("SCPXP_ShowTimedXP", function()
    local category = net.ReadString()
    local amount = net.ReadInt(32)
    
    SCPXP:ShowTimedXP(category, amount)
end)

net.Receive("SCPXP_ShowBriefNotification", function()
    local text = net.ReadString()
    local color = net.ReadColor()
    
    -- Simple brief notification (you can customize this)
    chat.AddText(color, "[SCPXP] ", Color(255, 255, 255), text)
end)

-- Menu system
net.Receive("SCPXP_OpenMenu", function()
    SCPXP:OpenMainMenu()
end)

function SCPXP:OpenMainMenu()
    if IsValid(self.MainMenu) then
        self.MainMenu:Close()
        return
    end
    
    local scrW, scrH = ScrW(), ScrH()
    
    -- Main frame
    local frame = vgui.Create("DFrame")
    frame:SetSize(800, 600)
    frame:Center()
    frame:SetTitle("SCP-RP Experience System")
    frame:SetDeleteOnClose(true)
    frame:MakePopup()
    
    self.MainMenu = frame
    
    -- Category tabs
    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:SetPadding(10)
    
    -- Create tabs for each category
    for categoryId, categoryData in pairs(self.Config.Categories) do
        local panel = vgui.Create("DPanel")
        panel:Dock(FILL)
        panel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 100))
        end
        
        -- Category info
        local currentLevel = self:GetPlayerLevel(categoryId)
        local currentXP = self:GetPlayerXP(categoryId)
        local progress = self:GetLevelProgress(categoryId)
        local nextLevelXP = self:GetXPForNextLevel(categoryId)
        
        -- Level display
        local levelLabel = vgui.Create("DLabel", panel)
        levelLabel:SetPos(20, 20)
        levelLabel:SetSize(300, 30)
        levelLabel:SetText(string.format("Level %d (%d XP)", currentLevel, currentXP))
        levelLabel:SetFont("DermaLarge")
        levelLabel:SetTextColor(categoryData.color or Color(255, 255, 255))
        
        -- Progress bar
        local progressBar = vgui.Create("DPanel", panel)
        progressBar:SetPos(20, 60)
        progressBar:SetSize(400, 20)
        progressBar.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(60, 60, 60))
            draw.RoundedBox(4, 2, 2, (w-4) * (progress/100), h-4, categoryData.color or Color(100, 149, 237))
        end
        
        -- Progress text
        local progressLabel = vgui.Create("DLabel", panel)
        progressLabel:SetPos(20, 85)
        progressLabel:SetSize(400, 20)
        progressLabel:SetText(string.format("%.1f%% - %d XP to next level", progress, nextLevelXP))
        progressLabel:SetTextColor(Color(200, 200, 200))
        
        sheet:AddSheet(categoryData.name, panel, "icon16/star.png")
    end
    
    -- Close button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetPos(350, 560)
    closeBtn:SetSize(100, 30)
    closeBtn:SetText("Close")
    closeBtn.DoClick = function()
        frame:Close()
    end
end

-- Clean up on disconnect
hook.Add("ShutDown", "SCPXP_ClientCleanup", function()
    -- Clean up timers
    timer.Remove("SCPXP_AutoCleanup")
    
    -- Clean up XP notifications
    for _, panel in ipairs(SCPXP.ActiveNotifications) do
        if IsValid(panel) then
            panel:Remove()
        end
    end
    SCPXP.ActiveNotifications = {}
    SCPXP.NotificationQueue = {}
    
    -- Clean up approval notifications
    for requestId, approval in pairs(SCPXP.ActiveApprovals) do
        if IsValid(approval.panel) then
            approval.panel:Remove()
        end
    end
    SCPXP.ActiveApprovals = {}
    
    -- Close menu
    if IsValid(SCPXP.MainMenu) then
        SCPXP.MainMenu:Close()
    end
end)

-- Handle screen size changes
hook.Add("OnScreenSizeChanged", "SCPXP_HandleResize", function()
    timer.Simple(0.1, function()
        -- Reposition XP notifications
        SCPXP:RepositionXPNotifications()
        
        -- Reposition approval notifications (handled in approval UI file)
        if SCPXP.RepositionApprovalNotifications then
            SCPXP:RepositionApprovalNotifications()
        end
    end)
end)