-- SCP-RP Experience System - Client HUD (Compact Only Version)
-- File: scprp_experience_system/lua/autorun/client/cl_hud.lua

-- HUD Settings
SCPXP.HUD = SCPXP.HUD or {}
SCPXP.HUD.Enabled = true
SCPXP.HUD.Dragging = false
SCPXP.HUD.DragOffset = { x = 0, y = 0 }
SCPXP.HUD.Position = { x = ScrW() - 270, y = ScrH() - 100 } -- Bottom right positioning

-- Local player data cache
local playerXP = {
    research = 0,
    security = 0,
    prisoner = 0,
    scp = 0
}

-- Get client XP data
function SCPXP:GetClientXP(category)
    return playerXP[category] or 0
end

-- Update client XP data
function SCPXP:UpdateClientXP(data)
    if type(data) == "table" then
        for category, xp in pairs(data) do
            if type(xp) == "number" then
                playerXP[category] = xp
            end
        end
    end
end

-- Main HUD drawing function
function SCPXP:DrawXPHUD()
    if not self.HUD.Enabled then return end
    if not LocalPlayer():IsValid() then return end
    
    -- Don't show HUD if player is dead or in certain states
    if not LocalPlayer():Alive() then return end
    if LocalPlayer():InVehicle() then return end
    
    -- Get current job category
    local currentCategory = self:GetPlayerJobCategory(LocalPlayer())
    if not currentCategory then return end
    
    -- Draw the compact HUD
    self:DrawCompactHUD(currentCategory)
end

-- Draw compact HUD
function SCPXP:DrawCompactHUD(currentCategory)
    local width, height = 250, 40
    local x, y = self.HUD.Position.x, self.HUD.Position.y
    
    local xp = self:GetClientXP(currentCategory)
    local level = self:GetPlayerLevel({GetClientXP = function() return xp end}, currentCategory)
    local progress = self:GetLevelProgress({GetClientXP = function() return xp end}, currentCategory)
    
    local categoryName = self:GetCategoryName(currentCategory)
    local color = self:GetCategoryColor(currentCategory)
    
    -- Background with shadow
    self:DrawShadow(x, y, width, height, 2)
    draw.RoundedBox(6, x, y, width, height, Color(20, 20, 20, 230))
    
    -- Category color accent
    draw.RoundedBoxEx(6, x, y, 4, height, Color(color.r, color.g, color.b, 255), true, false, true, false)
    
    -- Text with shadow for better visibility
    draw.SimpleText(categoryName .. " • Lv." .. level, "DermaDefault", x + 13, y + 13, Color(0, 0, 0, 100), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(categoryName .. " • Lv." .. level, "DermaDefault", x + 12, y + 12, Color(255, 255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    draw.SimpleText(self:FormatXP(xp) .. " XP", "DermaDefault", x + 13, y + 27, Color(0, 0, 0, 80), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    draw.SimpleText(self:FormatXP(xp) .. " XP", "DermaDefault", x + 12, y + 26, Color(180, 180, 180, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    -- Compact progress bar
    local barWidth = 60
    local barHeight = 4
    local barX = x + width - barWidth - 10
    local barY = y + 18  -- FIXED: was using x instead of y
    
    draw.RoundedBox(2, barX, barY, barWidth, barHeight, Color(40, 40, 40, 200))
    if progress > 0 then
        draw.RoundedBox(2, barX, barY, barWidth * progress, barHeight, Color(color.r, color.g, color.b, 255))
    end
    
    -- Handle dragging
    self:HandleCompactHUDInput(x, y, width, height)
end

-- Draw shadow effect
function SCPXP:DrawShadow(x, y, width, height, blur)
    for i = 1, blur do
        local alpha = 30 - (i * 5)
        if alpha > 0 then
            draw.RoundedBox(6, x - i, y - i, width + (i * 2), height + (i * 2), Color(0, 0, 0, alpha))
        end
    end
end

-- Handle compact HUD input (dragging)
function SCPXP:HandleCompactHUDInput(x, y, width, height)
    -- Don't handle input if VGUI element has focus
    if vgui.GetKeyboardFocus() then
        self.HUD.Dragging = false
        return
    end
    
    local mx, my = gui.MousePos()
    local mousePressed = input.IsMouseDown(MOUSE_LEFT)
    
    -- Handle mouse release - stop dragging
    if not mousePressed then
        if self.HUD.Dragging then
            self.HUD.Dragging = false
        end
        self.HUD.LastMouseState = false
        return
    end
    
    -- Check if this is a new mouse press
    local justPressed = mousePressed and not self.HUD.LastMouseState
    self.HUD.LastMouseState = mousePressed
    
    -- Start dragging if clicking on HUD
    if justPressed then
        local mouseOverHUD = mx >= x and mx <= x + width and my >= y and my <= y + height
        
        if mouseOverHUD then
            self.HUD.Dragging = true
            self.HUD.DragOffset.x = mx - x
            self.HUD.DragOffset.y = my - y
        end
    end
    
    -- Handle dragging
    if self.HUD.Dragging then
        local newX = math.Clamp(mx - self.HUD.DragOffset.x, 0, ScrW() - width)
        local newY = math.Clamp(my - self.HUD.DragOffset.y, 0, ScrH() - height)
        
        self.HUD.Position.x = newX
        self.HUD.Position.y = newY
    end
end

-- Simplified player level calculation for client
function SCPXP:GetPlayerLevel(fakePlayer, category)
    local xp = fakePlayer.GetClientXP and fakePlayer:GetClientXP() or self:GetClientXP(category)
    if xp <= 0 then return 0 end
    
    local multiplier = self.Config.XPMultiplier
    local baseXP = self.Config.BaseXP
    
    local level = math.log(xp * (multiplier - 1) / baseXP + 1) / math.log(multiplier)
    return math.floor(level)
end

-- Simplified level progress for client
function SCPXP:GetLevelProgress(fakePlayer, category)
    local xp = fakePlayer.GetClientXP and fakePlayer:GetClientXP() or self:GetClientXP(category)
    local currentLevel = self:GetPlayerLevel(fakePlayer, category)
    local currentLevelXP = self:GetXPForLevel(currentLevel)
    local nextLevelXP = self:GetXPForLevel(currentLevel + 1)
    
    if nextLevelXP <= currentLevelXP then return 1 end
    
    return (xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
end

-- Network receivers
net.Receive("SCPXP_SendData", function()
    local data = net.ReadTable()
    SCPXP:UpdateClientXP(data)
end)

net.Receive("SCPXP_Notification", function()
    local type = net.ReadString()
    local data = net.ReadTable()
    
    if SCPXP.ShowNotification then
        SCPXP:ShowNotification(type, data)
    end
end)

-- Console commands
concommand.Add("scpxp_toggle_hud", function()
    SCPXP.HUD.Enabled = not SCPXP.HUD.Enabled
    chat.AddText(Color(100, 255, 100), "[SCPXP] ", Color(255, 255, 255), "HUD " .. (SCPXP.HUD.Enabled and "enabled" or "disabled"))
end)

concommand.Add("scpxp_reset_hud_position", function()
    SCPXP.HUD.Position.x = ScrW() - 270
    SCPXP.HUD.Position.y = ScrH() - 100
    chat.AddText(Color(100, 255, 100), "[SCPXP] ", Color(255, 255, 255), "HUD position reset to default")
end)

concommand.Add("scpxp_hud_position", function(ply, cmd, args)
    if #args >= 2 then
        local x = tonumber(args[1])
        local y = tonumber(args[2])
        
        if x and y then
            SCPXP.HUD.Position.x = math.Clamp(x, 0, ScrW() - 250)
            SCPXP.HUD.Position.y = math.Clamp(y, 0, ScrH() - 40)
            chat.AddText(Color(100, 255, 100), "[SCPXP] ", Color(255, 255, 255), "HUD position updated")
        end
    else
        chat.AddText(Color(100, 255, 100), "[SCPXP] ", Color(255, 255, 255), "Usage: scpxp_hud_position <x> <y>")
    end
end)

-- Request data when client loads
hook.Add("InitPostEntity", "SCPXP_RequestData", function()
    timer.Simple(2, function()
        if IsValid(LocalPlayer()) then
            net.Start("SCPXP_RequestData")
            net.SendToServer()
        end
    end)
end)

-- Hook into HUD paint
hook.Add("HUDPaint", "SCPXP_DrawHUD", function()
    SCPXP:DrawXPHUD()
end)
