-- SCP-RP Experience System - Client Admin Panel
-- File: scprp_experience_system/lua/autorun/client/cl_admin.lua

SCPXP.Admin = SCPXP.Admin or {}

-- Admin Panel Creation
function SCPXP.Admin:OpenPanel()
    if IsValid(self.Panel) then
        self.Panel:Close()
    end
    
    self.Panel = self:CreateAdminPanel()
end

function SCPXP.Admin:CreateAdminPanel()
    local frame = vgui.Create("DFrame")
    frame:SetTitle("SCPXP Admin Panel")
    frame:SetSize(800, 600)
    frame:Center()
    frame:MakePopup()
    frame:SetDeleteOnClose(true)
    
    frame.Paint = function(self, w, h)
        draw.RoundedBox(8, 0, 0, w, h, Color(40, 40, 40, 250))
        draw.RoundedBox(8, 0, 0, w, 30, Color(60, 60, 60, 255))
    end
    
    -- Create tabs
    local sheet = vgui.Create("DPropertySheet", frame)
    sheet:Dock(FILL)
    sheet:DockMargin(8, 35, 8, 8)
    
    -- Player Management Tab
    local playerTab = self:CreatePlayerManagementTab()
    sheet:AddSheet("Players", playerTab, "icon16/user.png")
    
    -- Credit Requests Tab
    local creditTab = self:CreateCreditRequestsTab()
    sheet:AddSheet("Credit Requests", creditTab, "icon16/money.png")
    
    -- Server Stats Tab
    local statsTab = self:CreateServerStatsTab()
    sheet:AddSheet("Statistics", statsTab, "icon16/chart_bar.png")
    
    -- System Tools Tab
    local toolsTab = self:CreateSystemToolsTab()
    sheet:AddSheet("Tools", toolsTab, "icon16/wrench.png")
    
    return frame
end

-- Player Management Tab
function SCPXP.Admin:CreatePlayerManagementTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    -- Refresh button
    local refreshBtn = vgui.Create("DButton", panel)
    refreshBtn:SetText("Refresh Player List")
    refreshBtn:Dock(TOP)
    refreshBtn:SetHeight(25)
    refreshBtn:DockMargin(5, 5, 5, 5)
    refreshBtn.DoClick = function()
        net.Start("SCPXP_AdminPanel")
        net.WriteString("get_player_list")
        net.SendToServer()
    end
    
    -- Player list
    local listView = vgui.Create("DListView", panel)
    listView:Dock(FILL)
    listView:DockMargin(5, 0, 5, 5)
    listView:AddColumn("Player")
    listView:AddColumn("Job")
    listView:AddColumn("Research")
    listView:AddColumn("Security")
    listView:AddColumn("Prisoner")
    listView:AddColumn("SCP")
    listView:SetMultiSelect(false)
    
    panel.PlayerList = listView
    
    -- Player modification panel
    local modPanel = vgui.Create("DPanel", panel)
    modPanel:Dock(BOTTOM)
    modPanel:SetHeight(100)
    modPanel:DockMargin(5, 0, 5, 5)
    modPanel.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 200))
    end
    
    -- Selected player label
    local selectedLabel = vgui.Create("DLabel", modPanel)
    selectedLabel:SetText("No player selected")
    selectedLabel:SetPos(10, 10)
    selectedLabel:SetSize(200, 20)
    
    -- Category selector
    local categoryBox = vgui.Create("DComboBox", modPanel)
    categoryBox:SetPos(10, 35)
    categoryBox:SetSize(100, 20)
    categoryBox:SetValue("Category")
    for category, config in pairs(SCPXP.Config.XPCategories) do
        categoryBox:AddChoice(config.displayName, category)
    end
    
    -- Action selector
    local actionBox = vgui.Create("DComboBox", modPanel)
    actionBox:SetPos(120, 35)
    actionBox:SetSize(80, 20)
    actionBox:SetValue("Action")
    actionBox:AddChoice("Set", "set")
    actionBox:AddChoice("Add", "add")
    actionBox:AddChoice("Remove", "remove")
    
    -- Amount input
    local amountEntry = vgui.Create("DNumberWang", modPanel)
    amountEntry:SetPos(210, 35)
    amountEntry:SetSize(80, 20)
    amountEntry:SetValue(0)
    
    -- Reason input
    local reasonEntry = vgui.Create("DTextEntry", modPanel)
    reasonEntry:SetPos(300, 35)
    reasonEntry:SetSize(150, 20)
    reasonEntry:SetPlaceholderText("Reason (optional)")
    
    -- Apply button
    local applyBtn = vgui.Create("DButton", modPanel)
    applyBtn:SetText("Apply")
    applyBtn:SetPos(460, 35)
    applyBtn:SetSize(60, 20)
    applyBtn.DoClick = function()
        local selectedLine = listView:GetSelectedLine()
        if not selectedLine then
            chat.AddText(Color(255, 100, 100), "[SCPXP] No player selected!")
            return
        end
        
        local playerData = listView:GetLine(selectedLine)
        local steamid = playerData.steamid
        local category = categoryBox:GetOptionData(categoryBox:GetSelectedID())
        local action = actionBox:GetOptionData(actionBox:GetSelectedID())
        local amount = amountEntry:GetValue()
        local reason = reasonEntry:GetValue()
        
        if not category or not action then
            chat.AddText(Color(255, 100, 100), "[SCPXP] Please select category and action!")
            return
        end
        
        if action == "remove" then
            amount = -amount
            action = "add"
        end
        
        net.Start("SCPXP_AdminPanel")
        net.WriteString("modify_xp")
        net.WriteString(steamid)
        net.WriteString(category)
        net.WriteString(action)
        net.WriteInt(amount, 32)
        net.WriteString(reason)
        net.SendToServer()
    end
    
    -- Update selected player info
    listView.OnRowSelected = function(self, index, row)
        selectedLabel:SetText("Selected: " .. row:GetColumnText(1))
        row.steamid = row.steamid or "unknown" -- Store steamid in row data
    end
    
    return panel
end

-- Credit Requests Tab
function SCPXP.Admin:CreateCreditRequestsTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    -- Refresh button
    local refreshBtn = vgui.Create("DButton", panel)
    refreshBtn:SetText("Refresh Requests")
    refreshBtn:Dock(TOP)
    refreshBtn:SetHeight(25)
    refreshBtn:DockMargin(5, 5, 5, 5)
    refreshBtn.DoClick = function()
        net.Start("SCPXP_CreditResponse")
        net.WriteString("get_pending")
        net.WriteInt(0, 32)
        net.SendToServer()
    end
    
    -- Requests list
    local listView = vgui.Create("DListView", panel)
    listView:Dock(FILL)
    listView:DockMargin(5, 0, 5, 50)
    listView:AddColumn("ID")
    listView:AddColumn("Requester")
    listView:AddColumn("Target")
    listView:AddColumn("Time")
    listView:SetMultiSelect(false)
    
    panel.RequestsList = listView
    
    -- Action buttons
    local buttonPanel = vgui.Create("DPanel", panel)
    buttonPanel:Dock(BOTTOM)
    buttonPanel:SetHeight(40)
    buttonPanel:DockMargin(5, 0, 5, 5)
    buttonPanel.Paint = function() end
    
    local approveBtn = vgui.Create("DButton", buttonPanel)
    approveBtn:SetText("Approve Request")
    approveBtn:Dock(LEFT)
    approveBtn:SetWidth(120)
    approveBtn:DockMargin(0, 5, 5, 5)
    approveBtn.DoClick = function()
        local selectedLine = listView:GetSelectedLine()
        if not selectedLine then
            chat.AddText(Color(255, 100, 100), "[SCPXP] No request selected!")
            return
        end
        
        local requestData = listView:GetLine(selectedLine)
        local requestID = tonumber(requestData:GetColumnText(1))
        
        net.Start("SCPXP_CreditResponse")
        net.WriteString("approve")
        net.WriteInt(requestID, 32)
        net.SendToServer()
        
        listView:RemoveLine(selectedLine)
    end
    
    local denyBtn = vgui.Create("DButton", buttonPanel)
    denyBtn:SetText("Deny Request")
    denyBtn:Dock(LEFT)
    denyBtn:SetWidth(100)
    denyBtn:DockMargin(0, 5, 5, 5)
    denyBtn.DoClick = function()
        local selectedLine = listView:GetSelectedLine()
        if not selectedLine then
            chat.AddText(Color(255, 100, 100), "[SCPXP] No request selected!")
            return
        end
        
        local requestData = listView:GetLine(selectedLine)
        local requestID = tonumber(requestData:GetColumnText(1))
        
        -- Simple deny for now - could add reason popup
        net.Start("SCPXP_CreditResponse")
        net.WriteString("deny")
        net.WriteInt(requestID, 32)
        net.WriteString("") -- Empty reason
        net.SendToServer()
        
        listView:RemoveLine(selectedLine)
    end
    
    return panel
end

-- Server Stats Tab
function SCPXP.Admin:CreateServerStatsTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    -- Refresh button
    local refreshBtn = vgui.Create("DButton", panel)
    refreshBtn:SetText("Refresh Statistics")
    refreshBtn:Dock(TOP)
    refreshBtn:SetHeight(25)
    refreshBtn:DockMargin(5, 5, 5, 5)
    refreshBtn.DoClick = function()
        net.Start("SCPXP_AdminPanel")
        net.WriteString("get_stats")
        net.SendToServer()
    end
    
    -- Stats display
    local scroll = vgui.Create("DScrollPanel", panel)
    scroll:Dock(FILL)
    scroll:DockMargin(5, 0, 5, 5)
    
    panel.StatsPanel = scroll
    
    return panel
end

-- System Tools Tab
function SCPXP.Admin:CreateSystemToolsTab()
    local panel = vgui.Create("DPanel")
    panel.Paint = function() end
    
    -- Backup button
    local backupBtn = vgui.Create("DButton", panel)
    backupBtn:SetText("Create Data Backup")
    backupBtn:Dock(TOP)
    backupBtn:SetHeight(30)
    backupBtn:DockMargin(5, 5, 5, 5)
    backupBtn.DoClick = function()
        RunConsoleCommand("scpxp_backup")
    end
    
    -- Mass XP tools
    local massPanel = vgui.Create("DCollapsibleCategory", panel)
    massPanel:Dock(TOP)
    massPanel:SetHeight(150)
    massPanel:DockMargin(5, 0, 5, 5)
    massPanel:SetLabel("Mass XP Operations")
    massPanel:SetExpanded(false)
    
    local massContent = vgui.Create("DPanel", massPanel)
    massContent:Dock(FILL)
    massContent.Paint = function() end
    
    -- Add more system tools as needed
    
    return panel
end

-- Network Receivers
net.Receive("SCPXP_AdminPanel", function()
    local action = net.ReadString()
    
    if action == "open_panel" then
        SCPXP.Admin:OpenPanel()
        
    elseif action == "server_stats" then
        local stats = net.ReadTable()
        if IsValid(SCPXP.Admin.Panel) and SCPXP.Admin.Panel.StatsPanel then
            SCPXP.Admin:UpdateServerStats(stats)
        end
        
    elseif action == "player_list" then
        local players = net.ReadTable()
        if IsValid(SCPXP.Admin.Panel) and SCPXP.Admin.Panel.PlayerList then
            SCPXP.Admin:UpdatePlayerList(players)
        end
    end
end)

net.Receive("SCPXP_CreditRequest", function()
    local action = net.ReadString()
    
    if action == "pending_list" then
        local requests = net.ReadTable()
        if IsValid(SCPXP.Admin.Panel) and SCPXP.Admin.Panel.RequestsList then
            SCPXP.Admin:UpdateCreditRequests(requests)
        end
    else
        -- New credit request notification
        local data = net.ReadTable()
        SCPXP:AddNotification("info", {
            message = "New credit request: " .. data.requesterName .. " → " .. data.targetName
        }, 10)
    end
end)

-- Update Functions
function SCPXP.Admin:UpdateServerStats(stats)
    local panel = self.Panel.StatsPanel
    panel:Clear()
    
    local statsList = {
        {"Total Players", stats.totalPlayers},
        {"Online Players", stats.onlinePlayers},
        {"Pending Credit Requests", stats.pendingRequests},
        {"Server Uptime", SCPXP:FormatTime(stats.uptime)}
    }
    
    for _, stat in ipairs(statsList) do
        local statPanel = vgui.Create("DPanel", panel)
        statPanel:Dock(TOP)
        statPanel:SetHeight(30)
        statPanel:DockMargin(0, 5, 0, 0)
        
        statPanel.Paint = function(self, w, h)
            draw.RoundedBox(4, 0, 0, w, h, Color(50, 50, 50, 100))
            draw.SimpleText(stat[1] .. ":", "DermaDefaultBold", 10, 8, Color(255, 255, 255))
            draw.SimpleText(tostring(stat[2]), "DermaDefault", 10, 18, Color(200, 200, 200))
        end
    end
end

function SCPXP.Admin:UpdatePlayerList(players)
    local listView = self.Panel.PlayerList
    listView:Clear()
    
    for _, player in ipairs(players) do
        local line = listView:AddLine(
            player.name,
            player.job,
            "Lv." .. player.xp.research.level .. " (" .. SCPXP:FormatXP(player.xp.research.current) .. ")",
            "Lv." .. player.xp.security.level .. " (" .. SCPXP:FormatXP(player.xp.security.current) .. ")",
            "Lv." .. player.xp.prisoner.level .. " (" .. SCPXP:FormatXP(player.xp.prisoner.current) .. ")",
            "Lv." .. player.xp.scp.level .. " (" .. SCPXP:FormatXP(player.xp.scp.current) .. ")"
        )
        line.steamid = player.steamid
    end
end

function SCPXP.Admin:UpdateCreditRequests(requests)
    local listView = self.Panel.RequestsList
    listView:Clear()
    
    for _, request in ipairs(requests) do
        listView:AddLine(
            tostring(request.id),
            request.requesterName,
            request.targetName,
            request.timeText
        )
    end
end