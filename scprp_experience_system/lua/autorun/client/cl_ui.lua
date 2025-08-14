-- SCP-RP Experience System - Client UI
-- File: scprp_experience_system/lua/autorun/client/cl_ui.lua

SCPXP.UI = SCPXP.UI or {}

-- Main XP Panel
function SCPXP.UI:OpenXPPanel()
    if IsValid(self.XPPanel) then
        self.XPPanel:Close()
    end
    
    self.XPPanel = self:CreateXPPanel()
end

function SCPXP.UI:CreateXPPanel()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("SCP-RP Experience System")
    frame:SetSize(SCPXP.Config.UI.panelWidth, SCPXP.Config.UI.panelHeight)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    frame:SetSizable(true)
    
    -- Custom paint
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, SCPXP.Config.UI.backgroundColor)
        draw.RoundedBox(8, 0, 0, w, 30, SCPXP.Config.UI.headerColor)
        
        -- Title
        draw.SimpleText("Experience System", "DermaDefaultBold", 10, 15, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    end
    
    -- Create tabs
    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(8, 35, 8, 8)
    
    -- XP Overview Tab
    local xpTab = self:CreateXPOverviewTab()
    sheet:AddSheet("Experience", xpTab, "icon16/chart_line.png")
    
    -- Statistics Tab
    local statsTab = self:CreateStatisticsTab()
    sheet:AddSheet("Statistics", statsTab, "icon16/chart_bar.png")
    
    -- Leaderboard Tab
    local leaderTab = self:CreateLeaderboardTab()
    sheet:AddSheet("Leaderboard", leaderTab, "icon16/award_star_gold_1.png")
    
    return frame
end

-- XP Overview Tab
function SCPXP.UI:CreateXPOverviewTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    -- Refresh button
    local refreshBtn = vgui.Create("DButton", panel)
    refreshBtn:SetText("Refresh Data")
    refreshBtn:Dock(TOP)
    refreshBtn:SetHeight(25)
    refreshBtn:DockMargin(0, 5, 0, 5)
    refreshBtn.DoClick = function()
        net.Start("SCPXP_RequestData")
        net.SendToServer()
        SCPXP:AddNotification("info", {message = "Refreshing data..."})
    end
    
    -- Scroll panel
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(0, 5, 0, 0)
    
    -- Store reference for refreshing
    panel.ScrollPanel = scroll
    
    self:PopulateXPOverview(scroll)
    
    return panel
end

function SCPXP.UI:PopulateXPOverview(scroll)
    scroll:Clear()
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        local categoryPanel = self:CreateCategoryPanel(category, config)
        categoryPanel:Dock(TOP)
        categoryPanel:DockMargin(5, 5, 5, 5)
        categoryPanel:SetHeight(100)
        categoryPanel:SetParent(scroll)
    end
end

function SCPXP.UI:CreateCategoryPanel(category, config)
    local panel = vgui.Create("DPanel")
    
    local xp = SCPXP:GetClientXP(category)
    local level = SCPXP:GetClientLevel(category)
    local progress = SCPXP:GetClientLevelProgress(category)
    local xpForNext = SCPXP:GetClientXPForNextLevel(category)
    
    panel.Paint = function(self, w, h)
        -- Background
        draw.RoundedBox(6, 0, 0, w, h, Color(50, 50, 50, 200))
        draw.RoundedBox(6, 2, 2, w-4, h-4, Color(35, 35, 35, 150))
        
        -- Category header
        local headerHeight = 25
        draw.RoundedBox(4, 4, 4, w-8, headerHeight, Color(config.color.r, config.color.g, config.color.b, 100))
        
        -- Category name and level
        draw.SimpleText(config.displayName, "DermaDefaultBold", 12, 16, config.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
        draw.SimpleText("Level " .. level, "DermaDefaultBold", w - 12, 16, Color(255, 255, 255), TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        
        -- XP Information
        local xpText = SCPXP:FormatXP(xp) .. " XP"
        local nextText = SCPXP:FormatXP(xpForNext) .. " XP to next level"
        
        draw.SimpleText(xpText, "DermaDefault", 12, 40, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(nextText, "DermaDefault", w - 12, 40, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        
        -- Progress bar
        local barW, barH = w - 24, SCPXP.Config.UI.progressBarHeight
        local barX, barY = 12, h - barH - 12
        
        -- Progress bar background
        draw.RoundedBox(4, barX, barY, barW, barH, Color(20, 20, 20, 200))
        
        -- Progress bar fill
        if progress > 0 then
            local fillW = math.max(4, barW * progress)
            draw.RoundedBox(4, barX, barY, fillW, barH, config.color)
        end
        
        -- Progress percentage
        local progressText = math.Round(progress * 100, 1) .. "%"
        draw.SimpleText(progressText, "DermaDefault", 
            barX + barW/2, barY + barH/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    return panel
end

-- Statistics Tab
function SCPXP.UI:CreateStatisticsTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 5, 5, 5)
    
    -- Total XP
    local totalXP = 0
    for category, _ in pairs(SCPXP.Config.XPCategories) do
        totalXP = totalXP + SCPXP:GetClientXP(category)
    end
    
    -- Stats panels
    local stats = {
        {label = "Total XP Earned", value = SCPXP:FormatXP(totalXP)},
        {label = "Total Levels", value = tostring(self:GetTotalLevels())},
        {label = "Highest Level Category", value = self:GetHighestLevelCategory()},
        {label = "Play Session", value = "Current Session"}
    }
    
    for _, stat in ipairs(stats) do
        local statPanel = vgui.Create("DPanel", scroll)
        statPanel:Dock(TOP)
        statPanel:DockMargin(0, 5, 0, 0)
        statPanel:SetHeight(40)
        
        statPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(40, 40, 40, 150))
            
            draw.SimpleText(stat.label, "DermaDefaultBold", 10, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText(stat.value, "DermaDefault", 10, 25, Color(200, 200, 200), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        end
    end
    
    return panel
end

-- Leaderboard Tab
function SCPXP.UI:CreateLeaderboardTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    -- Category selector
    local categoryBox = vgui.Create("DComboBox", panel)
    categoryBox:Dock(TOP)
    categoryBox:DockMargin(5, 5, 5, 5)
    categoryBox:SetHeight(25)
    categoryBox:SetValue("Select Category")
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        categoryBox:AddChoice(config.displayName, category)
    end
    
    -- Leaderboard list
    local listView = vgui.Create("DListView", panel)
    listView:Dock(FILL)
    listView:DockMargin(5, 0, 5, 5)
    listView:AddColumn("Rank")
    listView:AddColumn("Player")
    listView:AddColumn("Level")
    listView:AddColumn("XP")
    
    categoryBox.OnSelect = function(self, index, text, data)
        -- Request leaderboard data from server
        -- This would need to be implemented on server-side
        listView:Clear()
        
        -- Placeholder data
        listView:AddLine("1", "Player1", "50", "125,000")
        listView:AddLine("2", "Player2", "48", "118,500")
        listView:AddLine("3", "Player3", "45", "112,000")
    end
    
    return panel
end

-- Helper functions
function SCPXP.UI:GetTotalLevels()
    local total = 0
    for category, _ in pairs(SCPXP.Config.XPCategories) do
        total = total + SCPXP:GetClientLevel(category)
    end
    return total
end

function SCPXP.UI:GetHighestLevelCategory()
    local highest = 0
    local categoryName = "None"
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        local level = SCPXP:GetClientLevel(category)
        if level > highest then
            highest = level
            categoryName = config.displayName .. " (Level " .. level .. ")"
        end
    end
    
    return categoryName
end

-- Refresh function
function SCPXP.UI:RefreshXPPanel()
    if not IsValid(self.XPPanel) then return end
    
    -- Find and refresh the XP overview tab
    local sheet = self.XPPanel:GetChildren()[1]
    if IsValid(sheet) and sheet.Items and sheet.Items[1] then
        local xpTab = sheet.Items[1].Panel
        if xpTab.ScrollPanel then
            self:PopulateXPOverview(xpTab.ScrollPanel)
        end
    end
end

-- F4 Menu Integration (if using Onyx)
hook.Add("OnyxF4MenuOpened", "SCPXP_F4Integration", function(menu)
    if not menu then return end
    
    -- Add XP tab
    local xpTab = vgui.Create("DPanel", menu)
    xpTab.Paint = function() end
    
    -- Mini XP display
    local xpDisplay = vgui.Create("DPanel", xpTab)
    xpDisplay:Dock(TOP)
    xpDisplay:SetHeight(200)
    xpDisplay:DockMargin(10, 10, 10, 10)
    
    xpDisplay.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(30, 30, 30, 200))
        
        -- Title
        draw.SimpleText("Your Experience", "DermaLarge", 10, 10, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        
        -- Categories
        local y = 35
        for category, config in pairs(SCPXP.Config.XPCategories) do
            local level = SCPXP:GetClientLevel(category)
            local xp = SCPXP:GetClientXP(category)
            
            draw.SimpleText(config.displayName .. ":", "DermaDefaultBold", 15, y, config.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            draw.SimpleText("Level " .. level .. " (" .. SCPXP:FormatXP(xp) .. " XP)", "DermaDefault", 120, y, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            
            y = y + 20
        end
    end
    
    -- Open full panel button
    local openBtn = vgui.Create("DButton", xpTab)
    openBtn:SetText("Open Full Experience Panel")
    openBtn:Dock(TOP)
    openBtn:SetHeight(30)
    openBtn:DockMargin(10, 5, 10, 10)
    openBtn.DoClick = function()
        SCPXP.UI:OpenXPPanel()
    end
    
    menu:AddSheet("Experience", xpTab, "icon16/chart_line.png")
end)