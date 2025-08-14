-- SCP-RP Experience System - Client UI
-- File: scprp_experience_system/lua/autorun/client/cl_ui.lua

-- UI Panel creation
function SCPXP:CreateXPPanel()
    if IsValid(SCPXP.XPPanel) then
        SCPXP.XPPanel:Close()
    end
    
    local frame = vgui.Create("DFrame")
    frame:SetTitle("SCP-RP Experience System")
    frame:SetSize(SCPXP.Config.UI.panelWidth, SCPXP.Config.UI.panelHeight)
    frame:Center()
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, SCPXP.Config.UI.backgroundColor)
        draw.RoundedBox(4, 0, 0, w, 25, SCPXP.Config.UI.headerColor)
    end
    
    SCPXP.XPPanel = frame
    
    -- Create category panels
    self:CreateCategoryPanels(frame)
    
    return frame
end

-- Create category display panels
function SCPXP:CreateCategoryPanels(parent)
    local yPos = 40
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        local panel = vgui.Create("DPanel", parent)
        panel:SetPos(10, yPos)
        panel:SetSize(parent:GetWide() - 20, 80)
        
        panel.Paint = function(self, w, h)
            -- Background
            surface.SetDrawColor(50, 50, 50, 200)
            surface.DrawRect(0, 0, w, h)
            
            -- Category color bar
            surface.SetDrawColor(config.color.r, config.color.g, config.color.b, 255)
            surface.DrawRect(0, 0, 4, h)
            
            -- Get XP data
            local xp = SCPXP:GetLocalXP(category)
            local level = SCPXP:GetPlayerLevel({SteamID64 = function() return "local" end}, category)
            local progress = SCPXP:GetLevelProgress({SteamID64 = function() return "local" end}, category)
            local currentLevelXP = SCPXP:GetXPForLevel(level)
            local nextLevelXP = SCPXP:GetXPForLevel(level + 1)
            local neededXP = nextLevelXP - xp
            
            -- Category name and level
            draw.SimpleText(config.displayName, "DermaLarge", 15, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT)
            draw.SimpleText("Level " .. level, "DermaDefault", 15, 35, config.color, TEXT_ALIGN_LEFT)
            
            -- XP text
            draw.SimpleText(SCPXP:FormatXP(xp) .. " XP", "DermaDefault", w - 15, 10, Color(200, 200, 200), TEXT_ALIGN_RIGHT)
            draw.SimpleText("Next: " .. SCPXP:FormatXP(neededXP) .. " XP", "DermaDefault", w - 15, 25, Color(150, 150, 150), TEXT_ALIGN_RIGHT)
            
            -- Progress bar
            local barX, barY = 15, h - 20
            local barW, barH = w - 30, SCPXP.Config.UI.progressBarHeight
            
            -- Background
            surface.SetDrawColor(30, 30, 30, 255)
            surface.DrawRect(barX, barY, barW, barH)
            
            -- Progress
            surface.SetDrawColor(config.color.r, config.color.g, config.color.b, 255)
            surface.DrawRect(barX, barY, barW * progress, barH)
            
            -- Border
            surface.SetDrawColor(100, 100, 100, 255)
            surface.DrawOutlinedRect(barX, barY, barW, barH)
            
            -- Progress percentage
            local percentText = math.Round(progress * 100, 1) .. "%"
            draw.SimpleText(percentText, "DermaDefault", barX + barW/2, barY + barH/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        
        yPos = yPos + 90
    end
end

-- Simple XP display function
function SCPXP:ShowXPDisplay()
    -- Create a simple notification-style display
    local frame = vgui.Create("DFrame")
    frame:SetTitle("")
    frame:SetSize(350, 250)
    frame:Center()
    frame:SetVisible(true)
    frame:SetDraggable(false)
    frame:ShowCloseButton(false)
    frame:MakePopup()
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 240))
        draw.RoundedBox(8, 0, 0, w, 30, Color(60, 60, 60, 255))
        
        draw.SimpleText("Experience Overview", "DermaDefault", w/2, 15, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    local yPos = 45
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        local xp = SCPXP:GetLocalXP(category)
        local level = SCPXP:GetPlayerLevel({SteamID64 = function() return "local" end}, category)
        
        local label = vgui.Create("DLabel", frame)
        label:SetPos(20, yPos)
        label:SetSize(200, 20)
        label:SetText(config.displayName .. ": Level " .. level)
        label:SetTextColor(config.color)
        
        local xpLabel = vgui.Create("DLabel", frame)
        xpLabel:SetPos(220, yPos)
        xpLabel:SetSize(100, 20)
        xpLabel:SetText(SCPXP:FormatXP(xp) .. " XP")
        xpLabel:SetTextColor(Color(200, 200, 200))
        
        yPos = yPos + 25
    end
    
    -- Close button
    local closeBtn = vgui.Create("DButton", frame)
    closeBtn:SetText("Close")
    closeBtn:SetPos(frame:GetWide()/2 - 50, frame:GetTall() - 35)
    closeBtn:SetSize(100, 25)
    closeBtn.DoClick = function()
        frame:Close()
    end
    
    -- Auto-close after 10 seconds
    timer.Simple(10, function()
        if IsValid(frame) then
            frame:Close()
        end
    end)
    
    return frame
end

-- Level progress calculation for fake player (client-side)
function SCPXP:GetLevelProgress(fakePlayer, category)
    local xp = self:GetLocalXP(category)
    local currentLevel = self:GetPlayerLevel(fakePlayer, category)
    local currentLevelXP = self:GetXPForLevel(currentLevel)
    local nextLevelXP = self:GetXPForLevel(currentLevel + 1)
    
    if nextLevelXP <= currentLevelXP then return 1 end
    
    return (xp - currentLevelXP) / (nextLevelXP - currentLevelXP)
end

-- Console command to open XP panel
concommand.Add("scpxp_panel", function()
    SCPXP:ShowXPDisplay()
end)

-- Context menu integration
hook.Add("OnContextMenuOpen", "SCPXP_ContextMenu", function()
    -- Add option to context menu if needed
end)

-- Simple leaderboard display
function SCPXP:ShowLeaderboard(category)
    category = category or "research"
    
    local frame = vgui.Create("DFrame")
    frame:SetTitle("Top " .. SCPXP:GetCategoryName(category) .. " Players")
    frame:SetSize(400, 500)
    frame:Center()
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    -- This would need server data - placeholder for now
    local scroll = vgui.Create("DScrollPanel", frame)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 5, 5)
    
    -- Add placeholder text
    local label = vgui.Create("DLabel", scroll)
    label:SetText("Leaderboard data would be loaded from server...")
    label:SetTextColor(Color(255, 255, 255))
    label:SizeToContents()
    label:Dock(TOP)
    
    return frame
end

-- Utility function for creating colored progress bars
function SCPXP:CreateProgressBar(parent, x, y, width, height, progress, color)
    local bar = vgui.Create("DPanel", parent)
    bar:SetPos(x, y)
    bar:SetSize(width, height)
    
    bar.Paint = function(self, w, h)
        -- Background
        surface.SetDrawColor(30, 30, 30, 255)
        surface.DrawRect(0, 0, w, h)
        
        -- Progress
        surface.SetDrawColor(color.r, color.g, color.b, 255)
        surface.DrawRect(0, 0, w * progress, h)
        
        -- Border
        surface.SetDrawColor(100, 100, 100, 255)
        surface.DrawOutlinedRect(0, 0, w, h)
    end
    
    return bar
end

-- Override the ShowXPMenu function from cl_init
function SCPXP:ShowXPMenu()
    self:ShowXPDisplay()
end