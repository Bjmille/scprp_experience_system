-- SCP-RP Experience System - Client Notifications
-- File: scprp_experience_system/lua/autorun/client/cl_notifications.lua

-- Notification System
SCPXP.Notifications = {}

-- Add Notification
function SCPXP:AddNotification(type, data, duration)
    local notification = {
        type = type,
        data = data,
        startTime = CurTime(),
        duration = duration or SCPXP.Config.Notifications.duration,
        alpha = 0,
        targetAlpha = 255,
        yOffset = 0,
        targetY = 0
    }
    
    table.insert(SCPXP.Notifications, notification)
    
    -- Limit notifications
    while #SCPXP.Notifications > SCPXP.Config.Notifications.maxNotifications do
        table.remove(SCPXP.Notifications, 1)
    end
    
    -- Recalculate positions
    self:RecalculateNotificationPositions()
end

-- Recalculate notification positions
function SCPXP:RecalculateNotificationPositions()
    local notifHeight = 70
    local margin = 5
    
    for i, notif in ipairs(SCPXP.Notifications) do
        notif.targetY = (i - 1) * (notifHeight + margin)
    end
end

-- Draw Notifications
function SCPXP:DrawNotifications()
    if #SCPXP.Notifications == 0 then return end
    
    local scrW, scrH = ScrW(), ScrH()
    local notifW, notifH = 320, 65
    local startX = scrW - notifW - SCPXP.Config.Notifications.position.x
    local baseY = SCPXP.Config.Notifications.position.y
    
    for i = #SCPXP.Notifications, 1, -1 do
        local notif = SCPXP.Notifications[i]
        local elapsed = CurTime() - notif.startTime
        local progress = elapsed / notif.duration
        
        -- Remove expired notifications
        if progress >= 1 then
            table.remove(SCPXP.Notifications, i)
            self:RecalculateNotificationPositions()
            continue
        end
        
        -- Animate position
        notif.yOffset = Lerp(FrameTime() * 10, notif.yOffset, notif.targetY)
        
        -- Fade animation
        local fadeTime = SCPXP.Config.Notifications.fadeTime
        if progress < fadeTime then
            notif.alpha = Lerp(progress / fadeTime, 0, notif.targetAlpha)
        elseif progress > (1 - fadeTime) then
            notif.alpha = Lerp((progress - (1 - fadeTime)) / fadeTime, notif.targetAlpha, 0)
        else
            notif.alpha = notif.targetAlpha
        end
        
        local y = baseY + notif.yOffset
        
        -- Draw notification
        self:DrawNotification(startX, y, notifW, notifH, notif)
    end
end

-- Draw Individual Notification
function SCPXP:DrawNotification(x, y, w, h, notif)
    local alpha = math.max(0, notif.alpha)
    
    -- Background
    local bgColor = Color(30, 30, 30, alpha * 0.95)
    draw.RoundedBox(8, x, y, w, h, bgColor)
    
    -- Get notification colors and content
    local borderColor, icon, title, message = self:GetNotificationContent(notif)
    borderColor.a = alpha
    
    -- Border
    draw.RoundedBox(8, x, y, w, 4, borderColor)
    
    -- Icon background
    local iconBgColor = Color(borderColor.r, borderColor.g, borderColor.b, alpha * 0.3)
    draw.RoundedBox(6, x + 8, y + 8, 40, 40, iconBgColor)
    
    -- Icon
    draw.SimpleText(icon, "DermaLarge", x + 28, y + 28, 
        Color(255, 255, 255, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    
    -- Title
    draw.SimpleText(title, "DermaDefaultBold", x + 56, y + 12, 
        Color(255, 255, 255, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    
    -- Message
    surface.SetTextColor(200, 200, 200, alpha)
    surface.SetFont("DermaDefault")
    
    local wrappedText = self:WrapText(message, w - 64, "DermaDefault")
    local lineHeight = 14
    
    for i, line in ipairs(wrappedText) do
        if i > 3 then break end -- Max 3 lines
        draw.SimpleText(line, "DermaDefault", x + 56, y + 28 + (i - 1) * lineHeight, 
            Color(200, 200, 200, alpha), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    end
    
    -- Progress bar for longer notifications
    if notif.duration > 3 then
        local progress = (CurTime() - notif.startTime) / notif.duration
        local barW = w - 16
        local barH = 2
        local barX = x + 8
        local barY = y + h - 6
        
        draw.RoundedBox(1, barX, barY, barW, barH, Color(255, 255, 255, alpha * 0.3))
        draw.RoundedBox(1, barX, barY, barW * (1 - progress), barH, borderColor)
    end
end

-- Get notification content based on type
function SCPXP:GetNotificationContent(notif)
    local type = notif.type
    local data = notif.data
    
    if type == "xp_gained" then
        local categoryColor = SCPXP:GetCategoryColor(data.category)
        return categoryColor, "+", 
               "+" .. data.amount .. " " .. SCPXP:GetCategoryName(data.category) .. " XP",
               data.reason or "XP Gained"
               
    elseif type == "level_up" then
        local categoryColor = SCPXP:GetCategoryColor(data.category)
        return categoryColor, "★", 
               "Level Up!",
               SCPXP:GetCategoryName(data.category) .. " Level " .. data.level
               
    elseif type == "player_level_up" then
        local categoryColor = SCPXP:GetCategoryColor(data.category)
        return categoryColor, "★", 
               "Player Level Up!",
               data.playerName .. " reached " .. SCPXP:GetCategoryName(data.category) .. " Level " .. data.level
               
    elseif type == "job_level_required" then
        return Color(255, 100, 100), "!", 
               "Level Required",
               "Need " .. SCPXP:GetCategoryName(data.category) .. " Level " .. data.requiredLevel .. " for " .. data.job
               
    elseif type == "scp_breach" then
        return Color(200, 50, 50), "⚠", 
               "SCP Breach Alert",
               data.message
               
    elseif type == "success" then
        return Color(100, 200, 100), "✓", 
               "Success",
               data.message
               
    elseif type == "error" then
        return Color(200, 100, 100), "✗", 
               "Error",
               data.message
               
    elseif type == "warning" then
        return Color(255, 200, 100), "⚠", 
               "Warning",
               data.message
               
    elseif type == "info" then
        return Color(100, 150, 200), "i", 
               "Info",
               data.message
               
    else
        return Color(150, 150, 150), "?", 
               "Notification",
               tostring(data.message or data)
    end
end

-- Wrap text for notifications
function SCPXP:WrapText(text, maxWidth, font)
    surface.SetFont(font)
    local words = string.Explode(" ", text)
    local lines = {}
    local currentLine = ""
    
    for _, word in ipairs(words) do
        local testLine = currentLine == "" and word or (currentLine .. " " .. word)
        local textWidth, _ = surface.GetTextSize(testLine)
        
        if textWidth <= maxWidth then
            currentLine = testLine
        else
            if currentLine ~= "" then
                table.insert(lines, currentLine)
                currentLine = word
            else
                table.insert(lines, word)
            end
        end
    end
    
    if currentLine ~= "" then
        table.insert(lines, currentLine)
    end
    
    return lines
end

-- Network receiver for notifications
net.Receive("SCPXP_Notification", function()
    local type = net.ReadString()
    local data = net.ReadTable()
    
    SCPXP:AddNotification(type, data)
end)

-- Draw hook
hook.Add("HUDPaint", "SCPXP_DrawNotifications", function()
    SCPXP:DrawNotifications()
end)