-- SCP-RP Experience System - Client Notifications
-- File: scprp_experience_system/lua/autorun/client/cl_notifications.lua

SCPXP.Notifications = SCPXP.Notifications or {}
SCPXP.Notifications.Queue = {}

-- Notification types and their colors
local notificationTypes = {
    ["xp_gained"] = {color = Color(100, 255, 100), icon = "+", duration = 3},
    ["level_up"] = {color = Color(255, 215, 0), icon = "★", duration = 5},
    ["player_level_up"] = {color = Color(255, 165, 0), icon = "★", duration = 4},
    ["success"] = {color = Color(100, 255, 100), icon = "✓", duration = 3},
    ["error"] = {color = Color(255, 100, 100), icon = "✗", duration = 4},
    ["warning"] = {color = Color(255, 255, 100), icon = "⚠", duration = 3},
    ["info"] = {color = Color(100, 200, 255), icon = "ⓘ", duration = 3},
    ["job_level_required"] = {color = Color(255, 100, 100), icon = "⚠", duration = 5},
    ["scp_breach"] = {color = Color(255, 0, 0), icon = "⚠", duration = 6},
    ["data_reset"] = {color = Color(255, 165, 0), icon = "⟲", duration = 4},
    ["admin_xp_set"] = {color = Color(255, 165, 0), icon = "⚡", duration = 4}
}

-- Show notification
function SCPXP:ShowNotification(type, data)
    local config = notificationTypes[type]
    if not config then
        config = notificationTypes["info"]
    end
    
    local notification = {
        type = type,
        data = data or {},
        color = config.color,
        icon = config.icon,
        duration = config.duration,
        startTime = CurTime(),
        alpha = 0,
        message = self:BuildNotificationMessage(type, data)
    }
    
    table.insert(self.Notifications.Queue, notification)
    
    -- Play sound
    self:PlayNotificationSound(type)
    
    -- Remove old notifications if too many
    while #self.Notifications.Queue > SCPXP.Config.Notifications.maxNotifications do
        table.remove(self.Notifications.Queue, 1)
    end
end

-- Build notification message
function SCPXP:BuildNotificationMessage(type, data)
    if type == "xp_gained" then
        local amount = data.amount or 0
        local category = data.category or "unknown"
        local reason = data.reason or ""
        local categoryName = self:GetCategoryName(category)
        
        local message = "+" .. amount .. " " .. categoryName .. " XP"
        if reason ~= "" and reason ~= "Unknown" then
            message = message .. " (" .. reason .. ")"
        end
        return message
        
    elseif type == "level_up" then
        local level = data.level or 1
        local category = data.category or "unknown"
        local categoryName = self:GetCategoryName(category)
        return "Level Up! " .. categoryName .. " Level " .. level
        
    elseif type == "player_level_up" then
        local playerName = data.playerName or "Someone"
        local level = data.level or 1
        local category = data.category or "unknown"
        local categoryName = self:GetCategoryName(category)
        return playerName .. " reached " .. categoryName .. " Level " .. level .. "!"
        
    elseif type == "job_level_required" then
        local job = data.job or "Unknown Job"
        local requiredLevel = data.requiredLevel or 1
        local currentLevel = data.currentLevel or 0
        local category = data.category or "unknown"
        local categoryName = self:GetCategoryName(category)
        return "Need " .. categoryName .. " Level " .. requiredLevel .. " for " .. job .. " (Current: " .. currentLevel .. ")"
        
    elseif type == "scp_breach" then
        return data.message or "SCP Breach Alert!"
        
    elseif type == "data_reset" then
        local admin = data.admin or "Admin"
        return admin .. " reset your XP data"
        
    elseif type == "admin_xp_set" then
        local admin = data.admin or "Admin"
        local category = data.category or "unknown"
        local amount = data.amount or 0
        local categoryName = self:GetCategoryName(category)
        return admin .. " set your " .. categoryName .. " XP to " .. self:FormatXP(amount)
        
    else
        return data.message or "Notification"
    end
end

-- Play notification sound
function SCPXP:PlayNotificationSound(type)
    if type == "level_up" then
        surface.PlaySound("buttons/bell1.wav")
    elseif type == "xp_gained" then
        surface.PlaySound("buttons/blip1.wav")
    elseif type == "error" then
        surface.PlaySound("buttons/button10.wav")
    elseif type == "scp_breach" then
        surface.PlaySound("ambient/alarms/warningbell1.wav")
    else
        surface.PlaySound("buttons/blip2.wav")
    end
end

-- Draw notifications
function SCPXP:DrawNotifications()
    local x = ScrW() - SCPXP.Config.Notifications.position.x
    local y = SCPXP.Config.Notifications.position.y
    local width = 300
    local height = 40
    
    for i = #self.Notifications.Queue, 1, -1 do
        local notification = self.Notifications.Queue[i]
        local timePassed = CurTime() - notification.startTime
        local progress = timePassed / notification.duration
        
        -- Remove expired notifications
        if progress >= 1 then
            table.remove(self.Notifications.Queue, i)
            continue
        end
        
        -- Calculate alpha for fade effect
        local fadeTime = SCPXP.Config.Notifications.fadeTime
        if timePassed < fadeTime then
            notification.alpha = math.Clamp(timePassed / fadeTime * 255, 0, 255)
        elseif progress > (1 - fadeTime / notification.duration) then
            local fadeProgress = (progress - (1 - fadeTime / notification.duration)) / (fadeTime / notification.duration)
            notification.alpha = math.Clamp(255 * (1 - fadeProgress), 0, 255)
        else
            notification.alpha = 255
        end
        
        -- Calculate position
        local drawY = y + (i - 1) * (height + 5)
        local drawX = x - width
        
        -- Slide animation
        if timePassed < 0.3 then
            local slideProgress = timePassed / 0.3
            drawX = drawX + (1 - slideProgress) * 200
        end
        
        -- Draw notification
        self:DrawNotification(notification, drawX, drawY, width, height)
    end
end

-- Draw individual notification
function SCPXP:DrawNotification(notification, x, y, width, height)
    local alpha = notification.alpha
    
    -- Background
    surface.SetDrawColor(40, 40, 40, alpha * 0.9)
    surface.DrawRect(x, y, width, height)
    
    -- Side bar (category color)
    if notification.data.category then
        local categoryColor = self:GetCategoryColor(notification.data.category)
        surface.SetDrawColor(categoryColor.r, categoryColor.g, categoryColor.b, alpha)
        surface.DrawRect(x, y, 4, height)
    end
    
    -- Icon
    draw.SimpleText(notification.icon, "DermaLarge", x + 15, y + height/2, ColorAlpha(notification.color, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Message
    draw.SimpleText(notification.message, "DermaDefault", x + 30, y + height/2, ColorAlpha(Color(255, 255, 255), alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    -- Progress bar
    local progressWidth = width - 10
    local progressHeight = 2
    local progressX = x + 5
    local progressY = y + height - progressHeight - 2
    
    surface.SetDrawColor(60, 60, 60, alpha)
    surface.DrawRect(progressX, progressY, progressWidth, progressHeight)
    
    local progress = (CurTime() - notification.startTime) / notification.duration
    surface.SetDrawColor(notification.color.r, notification.color.g, notification.color.b, alpha)
    surface.DrawRect(progressX, progressY, progressWidth * (1 - progress), progressHeight)
    
    -- Border
    surface.SetDrawColor(100, 100, 100, alpha * 0.5)
    surface.DrawOutlinedRect(x, y, width, height)
end

-- Network receiver
net.Receive("SCPXP_Notification", function()
    local type = net.ReadString()
    local data = net.ReadTable()
    
    SCPXP:ShowNotification(type, data)
end)

-- Hook for drawing notifications
hook.Add("HUDPaint", "SCPXP_DrawNotifications", function()
    SCPXP:DrawNotifications()
end)

-- Console command to test notifications
concommand.Add("scpxp_test_notification", function(ply, cmd, args)
    if #args > 0 then
        local type = args[1]
        local testData = {
            category = "research",
            amount = 50,
            reason = "Test notification",
            level = 5,
            playerName = "Test Player"
        }
        SCPXP:ShowNotification(type, testData)
    else
        SCPXP:ShowNotification("info", {message = "Test notification"})
    end
end)