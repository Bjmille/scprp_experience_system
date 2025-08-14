-- SCP-RP Experience System - Client Admin Panel
-- File: scprp_experience_system/lua/autorun/client/cl_admin.lua

-- Admin panel data
SCPXP.AdminPanel = SCPXP.AdminPanel or {}
SCPXP.AdminPanel.IsOpen = false

-- Create admin panel
function SCPXP:CreateAdminPanel()
    if IsValid(SCPXP.AdminPanel.Frame) then
        SCPXP.AdminPanel.Frame:Close()
    end
    
    local frame = vgui.Create("DFrame")
    frame:SetTitle("SCPXP Admin Panel")
    frame:SetSize(800, 600)
    frame:Center()
    frame:SetVisible(true)
    frame:SetDraggable(true)
    frame:ShowCloseButton(true)
    frame:MakePopup()
    
    frame.OnClose = function()
        SCPXP.AdminPanel.IsOpen = false
    end
    
    SCPXP.AdminPanel.Frame = frame
    SCPXP.AdminPanel.IsOpen = true
    
    -- Create tabs
    local tabs = vgui.Create("DPropertySheet", frame)
    tabs:Dock(FILL)
    tabs:DockMargin(5, 5, 5, 5)
    
    -- Player Management Tab
    local playerTab = vgui.Create("DPanel")
    tabs:AddSheet("Players", playerTab, "icon16/group.png")
    self:CreatePlayerManagementTab(playerTab)
    
    -- Credit Requests Tab
    local creditTab = vgui.Create("DPanel")
    tabs:AddSheet("Credit Requests", creditTab, "icon16/money.png")
    self:CreateCreditRequestsTab(creditTab)
    
    -- Server Stats Tab
    local statsTab = vgui.Create("DPanel")
    tabs:AddSheet("Statistics", statsTab, "icon16/chart_bar.png")
    self:CreateServerStatsTab(statsTab)
    
    -- Request initial data
    net.Start("SCPXP_AdminPanel")
    net.WriteString("get_player_list")
    net.SendToServer()
    
    return frame
end

-- Create Player Management Tab
function SCPXP:CreatePlayerManagementTab(parent)
    -- Player list
    local playerList = vgui.Create("DListView", parent)
    playerList:SetPos(10, 10)
    playerList:SetSize(parent:GetWide() - 220, parent:GetTall() - 20)
    playerList:SetMultiSelect(false)
    playerList:AddColumn("Player")
    playerList:AddColumn("Job")
    playerList:AddColumn("Research Lvl")
    playerList:AddColumn("Security Lvl")
    playerList:AddColumn("Prisoner Lvl")
    playerList:AddColumn("SCP Lvl")
    
    SCPXP.AdminPanel.PlayerList = playerList
    
    -- Controls panel
    local controlPanel = vgui.Create("DPanel", parent)
    controlPanel:SetPos(parent:GetWide() - 200, 10)
    controlPanel:SetSize(190, parent:GetTall() - 20)
    controlPanel.Paint = function(self, w, h)
        surface.SetDrawColor(50, 50, 50, 100)
        surface.DrawRect(0, 0, w, h)
    end
    
    -- Selected player label
    local selectedLabel = vgui.Create("DLabel", controlPanel)
    selectedLabel:SetPos(5, 5)
    selectedLabel:SetSize(180, 20)
    selectedLabel:SetText("No player selected")
    selectedLabel:SetTextColor(Color(255, 255, 255))
    
    SCPXP.AdminPanel.SelectedLabel = selectedLabel
    
    -- Category selector
    local categoryLabel = vgui.Create("DLabel", controlPanel)
    categoryLabel:SetPos(5, 35)
    categoryLabel:SetSize(180, 20)
    categoryLabel:SetText("Category:")
    categoryLabel:SetTextColor(Color(255, 255, 255))
    
    local categoryBox = vgui.Create("DComboBox", controlPanel)
    categoryBox:SetPos(5, 55)
    categoryBox:SetSize(180, 20)
    categoryBox:AddChoice("Research", "research")
    categoryBox:AddChoice("Security", "security")
    categoryBox:AddChoice("Prisoner", "prisoner")
    categoryBox:AddChoice("SCP", "scp")
    categoryBox:SetValue("Research")
    
    SCPXP.AdminPanel.CategoryBox = categoryBox
    
    -- XP amount entry
    local xpLabel = vgui.Create("DLabel", controlPanel)
    xpLabel:SetPos(5, 85)
    xpLabel:SetSize(180, 20)
    xpLabel:SetText("XP Amount:")
    xpLabel:SetTextColor(Color(255, 255, 255))
    
    local xpEntry = vgui.Create("DTextEntry", controlPanel)
    xpEntry:SetPos(5, 105)
    xpEntry:SetSize(180, 20)
    xpEntry:SetNumeric(true)
    xpEntry:SetText("100")
    
    SCPXP.AdminPanel.XPEntry = xpEntry
    
    -- Reason entry
    local reasonLabel = vgui.Create("DLabel", controlPanel)
    reasonLabel:SetPos(5, 135)
    reasonLabel:SetSize(180, 20)
    reasonLabel:SetText("Reason:")
    reasonLabel:SetTextColor(Color(255, 255, 255))
    
    local reasonEntry = vgui.Create("DTextEntry", controlPanel)
    reasonEntry:SetPos(5, 155)
    reasonEntry:SetSize(180, 40)
    reasonEntry:SetMultiline(true)
    reasonEntry:SetText("Admin adjustment")
    
    SCPXP.AdminPanel.ReasonEntry = reasonEntry
    
    -- Buttons
    local addXPBtn = vgui.Create("DButton", controlPanel)
    addXPBtn:SetPos(5, 205)
    addXPBtn:SetSize(85, 25)
    addXPBtn:SetText("Add XP")
    addXPBtn.DoClick = function()
        self:AdminModifyXP("add")
    end
    
    local setXPBtn = vgui.Create("DButton", controlPanel)
    setXPBtn:SetPos(100, 205)
    setXPBtn:SetSize(85, 25)
    setXPBtn:SetText("Set XP")
    setXPBtn.DoClick = function()
        self:AdminModifyXP("set")
    end
    
    local refreshBtn = vgui.Create("DButton", controlPanel)
    refreshBtn:SetPos(5, 240)
    refreshBtn:SetSize(180, 25)
    refreshBtn:SetText("Refresh Player List")
    refreshBtn.DoClick = function()
        net.Start("SCPXP_AdminPanel")
        net.WriteString("get_player_list")
        net.SendToServer()
    end
    
    -- Player selection handler
    playerList.OnRowSelected = function(panel, rowIndex, row)
        local steamid = row:GetColumnText(7) -- Hidden column for steamid
        local name = row:GetColumnText(1)
        selectedLabel:SetText("Selected: " .. name)
        SCPXP.AdminPanel.SelectedSteamID = steamid
    end
end

-- Create Credit Requests Tab
function SCPXP:CreateCreditRequestsTab(parent)
    -- Requests list
    local requestsList = vgui.Create("DListView", parent)
    requestsList:SetPos(10, 10)
    requestsList:SetSize(parent:GetWide() - 20, parent:GetTall() - 100)
    requestsList:SetMultiSelect(false)
    requestsList:AddColumn("ID")
    requestsList:AddColumn("Requester")
    requestsList:AddColumn("Target")
    requestsList:AddColumn("Time")
    requestsList:AddColumn("Status")
    
    SCPXP.AdminPanel.RequestsList = requestsList
    
    -- Control buttons
    local approveBtn = vgui.Create("DButton", parent)
    approveBtn:SetPos(10, parent:GetTall() - 80)
    approveBtn:SetSize(100, 30)
    approveBtn:SetText("Approve")
    approveBtn.DoClick = function()
        self:HandleCreditRequest("approve")
    end
    
    local denyBtn = vgui.Create("DButton", parent)
    denyBtn:SetPos(120, parent:GetTall() - 80)
    denyBtn:SetSize(100, 30)
    denyBtn:SetText("Deny")
    denyBtn.DoClick = function()
        self:HandleCreditRequest("deny")
    end
    
    local refreshCreditBtn = vgui.Create("DButton", parent)
    refreshCreditBtn:SetPos(230, parent:GetTall() - 80)
    refreshCreditBtn:SetSize(100, 30)
    refreshCreditBtn:SetText("Refresh")
    refreshCreditBtn.DoClick = function()
        net.Start("SCPXP_CreditResponse")
        net.WriteString("get_pending")
        net.WriteInt(0, 32)
        net.SendToServer()
    end
end

-- Create Server Stats Tab
function SCPXP:CreateServerStatsTab(parent)
    -- Stats labels
    local statsPanel = vgui.Create("DPanel", parent)
    statsPanel:Dock(FILL)
    statsPanel:DockMargin(10, 10, 10, 10)
    
    statsPanel.Paint = function(self, w, h)
        draw.SimpleText("Server Statistics", "DermaLarge", 10, 10, Color(255, 255, 255))
        
        -- Draw stats if available
        if SCPXP.AdminPanel.ServerStats then
            local stats = SCPXP.AdminPanel.ServerStats
            local y = 50
            
            draw.SimpleText("Total Players: " .. (stats.totalPlayers or 0), "DermaDefault", 10, y, Color(200, 200, 200))
            draw.SimpleText("Online Players: " .. (stats.onlinePlayers or 0), "DermaDefault", 10, y + 20, Color(200, 200, 200))
            draw.SimpleText("Pending Requests: " .. (stats.pendingRequests or 0), "DermaDefault", 10, y + 40, Color(200, 200, 200))
            
            local uptimeHours = math.floor((stats.uptime or 0) / 3600)
            local uptimeMinutes = math.floor(((stats.uptime or 0) % 3600) / 60)
            draw.SimpleText("Server Uptime: " .. uptimeHours .. "h " .. uptimeMinutes .. "m", "DermaDefault", 10, y + 60, Color(200, 200, 200))
        end
    end
    
    -- Request stats
    net.Start("SCPXP_AdminPanel")
    net.WriteString("get_stats")
    net.SendToServer()
end

-- Handle XP modification
function SCPXP:AdminModifyXP(action)
    if not SCPXP.AdminPanel.SelectedSteamID then
        Derma_Message("Please select a player first!", "Error", "OK")
        return
    end
    
    local category = SCPXP.AdminPanel.CategoryBox:GetOptionData(SCPXP.AdminPanel.CategoryBox:GetSelectedID())
    local amount = tonumber(SCPXP.AdminPanel.XPEntry:GetText())
    local reason = SCPXP.AdminPanel.ReasonEntry:GetText()
    
    if not amount then
        Derma_Message("Please enter a valid XP amount!", "Error", "OK")
        return
    end
    
    net.Start("SCPXP_AdminPanel")
    net.WriteString("modify_xp")
    net.WriteString(SCPXP.AdminPanel.SelectedSteamID)
    net.WriteString(category)
    net.WriteString(action)
    net.WriteInt(amount, 32)
    net.WriteString(reason)
    net.SendToServer()
end

-- Handle credit requests
function SCPXP:HandleCreditRequest(action)
    local selected = SCPXP.AdminPanel.RequestsList:GetSelectedLine()
    if not selected then
        Derma_Message("Please select a credit request first!", "Error", "OK")
        return
    end
    
    local requestID = tonumber(SCPXP.AdminPanel.RequestsList:GetLine(selected):GetColumnText(1))
    
    net.Start("SCPXP_CreditResponse")
    net.WriteString(action)
    net.WriteInt(requestID, 32)
    if action == "deny" then
        net.WriteString("Denied by admin") -- Default deny reason
    end
    net.SendToServer()
end

-- Network receivers
net.Receive("SCPXP_AdminPanel", function()
    local action = net.ReadString()
    
    if action == "open_panel" then
        SCPXP:CreateAdminPanel()
        
    elseif action == "player_list" and IsValid(SCPXP.AdminPanel.PlayerList) then
        local playerList = net.ReadTable()
        
        SCPXP.AdminPanel.PlayerList:Clear()
        for _, playerData in ipairs(playerList) do
            local line = SCPXP.AdminPanel.PlayerList:AddLine(
                playerData.name,
                playerData.job,
                playerData.xp.research.level,
                playerData.xp.security.level,
                playerData.xp.prisoner.level,
                playerData.xp.scp.level
            )
            line:SetColumnText(7, playerData.steamid) -- Hidden column
        end
        
    elseif action == "server_stats" then
        SCPXP.AdminPanel.ServerStats = net.ReadTable()
    end
end)

net.Receive("SCPXP_CreditRequest", function()
    local action = net.ReadString()
    
    if action == "pending_list" and IsValid(SCPXP.AdminPanel.RequestsList) then
        local requests = net.ReadTable()
        
        SCPXP.AdminPanel.RequestsList:Clear()
        for _, request in ipairs(requests) do
            SCPXP.AdminPanel.RequestsList:AddLine(
                request.id,
                request.requesterName,
                request.targetName,
                request.timeText,
                "Pending"
            )
        end
    else
        -- Single credit request notification
        local requestData = net.ReadTable()
        
        -- Show notification or update list
        if IsValid(SCPXP.AdminPanel.RequestsList) then
            SCPXP.AdminPanel.RequestsList:AddLine(
                requestData.id,
                requestData.requesterName,
                requestData.targetName,
                "Just now",
                "Pending"
            )
        end
    end
end)

-- Console command to open admin panel
concommand.Add("scpxp_admin", function()
    if LocalPlayer():IsAdmin() then
        SCPXP:CreateAdminPanel()
    else
        chat.AddText(Color(255, 100, 100), "[SCPXP] You don't have permission to use this command!")
    end
end)