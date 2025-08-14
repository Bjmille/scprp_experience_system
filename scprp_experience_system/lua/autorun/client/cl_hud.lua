-- SCP-RP Experience System - Client HUD
-- File: scprp_experience_system/lua/autorun/client/cl_hud.lua

-- HUD Settings
SCPXP.HUD = SCPXP.HUD or {}
SCPXP.HUD.Enabled = true
SCPXP.HUD.ShowLevel = true
SCPXP.HUD.ShowProgress = true
SCPXP.HUD.Position = { x = 50, y = ScrH() - 150 }

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
    
    -- Draw the HUD
    self:DrawFullHUD(currentCategory)
end

-- Draw full HUD with all categories
function SCPXP:DrawFullHUD(currentCategory)
    local x, y = self.HUD.Position.x, self.HUD.Position.y
    local width, height = 280, 120
    
    -- Background
    surface.SetDrawColor(40, 40, 40, 200)
    surface.DrawRect(x, y, width, height)
    
    -- Header
    surface.SetDrawColor(60, 60, 60, 255)
    surface.DrawRect(x, y, width, 25)
    
    draw.SimpleText("Experience", "DermaDefault", x + 10, y + 5, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    
    -- Draw categories
    local categories = self:GetSortedCategories(currentCategory)
    local startY = y + 30
    local lineHeight = 20
    
    for i, category in ipairs(categories) do
        local drawY = startY + (i - 1) * lineHeight
        self:DrawCategoryLine(x + 10, drawY, width - 20, category, category == currentCategory)
    end
end

-- Draw individual category line
function SCPXP:DrawCategoryLine(x, y, width, category, isActive)
    local xp = self:GetClientXP(category)
    local level = self:GetPlayerLevel({GetClientXP = function() return xp end, SteamID64 = function() return "local" end}, category)
    local progress = self:GetLevelProgress({GetClientXP = function() return xp end, SteamID64 = function() return "local" end}, category)
    
    local color = self:GetCategoryColor(category)
    local textColor = isActive and Color(255, 255, 255) or Color(200, 200, 200)
    
    -- Category name and level
    local categoryName = self:GetCategoryName(category)
    local text = categoryName .. " - Level " .. level
    
    draw.SimpleText(text, "DermaDefault", x, y, textColor, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    
    -- Progress bar if enabled
    if self.HUD.ShowProgress then
        local barWidth = 100
        local barHeight = 8
        local barX = x + width - barWidth
        local barY = y + 2
        
        -- Background
        surface.SetDrawColor(60, 60, 60, 255)
        surface.DrawRect(barX, barY, barWidth, barHeight)
        
        -- Progress
        surface.SetDrawColor(color.r, color.g, color.b, 255)
        surface.DrawRect(barX, barY, barWidth * progress, barHeight)
        
        -- Border
        surface.SetDrawColor(100, 100, 100, 255)
        surface.DrawOutlinedRect(barX, barY, barWidth, barHeight)
    end
end

-- Get sorted categories (current first)
function SCPXP:GetSortedCategories(currentCategory)
    local categories = {}
    
    -- Add current category first
    if currentCategory and self:IsValidCategory(currentCategory) then
        table.insert(categories, currentCategory)
    end
    
    -- Add other categories
    for category, _ in pairs(self.Config.XPCategories) do
        if category ~= currentCategory then
            table.insert(categories, category)
        end
    end
    
    return categories
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

concommand.Add("scpxp_hud_position", function(ply, cmd, args)
    if #args >= 2 then
        local x = tonumber(args[1])
        local y = tonumber(args[2])
        
        if x and y then
            SCPXP.HUD.Position.x = math.Clamp(x, 0, ScrW() - 300)
            SCPXP.HUD.Position.y = math.Clamp(y, 0, ScrH() - 150)
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

-- Mini HUD for bottom corner
function SCPXP:DrawMiniHUD()
    if not self.HUD.Enabled then return end
    if not LocalPlayer():IsValid() or not LocalPlayer():Alive() then return end
    
    local currentCategory = self:GetPlayerJobCategory(LocalPlayer())
    if not currentCategory then return end
    
    local x, y = ScrW() - 200, ScrH() - 50
    local xp = self:GetClientXP(currentCategory)
    local level = self:GetPlayerLevel({GetClientXP = function() return xp end}, currentCategory)
    
    local categoryName = self:GetCategoryName(currentCategory)
    local color = self:GetCategoryColor(currentCategory)
    
    -- Background
    surface.SetDrawColor(0, 0, 0, 100)
    surface.DrawRect(x, y, 180, 30)
    
    -- Text
    draw.SimpleText(categoryName .. " Level " .. level, "DermaDefault", x + 5, y + 8, color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    -- XP text
    draw.SimpleText(self:FormatXP(xp) .. " XP", "DermaDefault", x + 5, y + 20, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end

-- Alternative mini HUD hook
hook.Add("HUDPaint", "SCPXP_MiniHUD", function()
    -- Uncomment the line below if you prefer the mini HUD instead of full HUD
    -- SCPXP:DrawMiniHUD()
end)