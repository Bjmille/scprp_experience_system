-- CLIENT-SIDE CODE
-- Place this in: addons/scprp_experience_system/lua/autorun/client/scpxp_approval_ui.lua

if not CLIENT then return end

SCPXP = SCPXP or {}
SCPXP.ActiveApprovals = {}

-- Create the approval notification panel (EXP-style)
function SCPXP:CreateApprovalNotification(requestId, researcherName, targetName, autoApproved)
    local scrW, scrH = ScrW(), ScrH()
    
    -- Create main panel
    local panel = vgui.Create("DPanel")
    panel:SetSize(400, autoApproved and 80 or 120)
    panel:SetPos(scrW + 50, 20) -- Start off-screen
    panel:MakePopup()
    panel:SetKeyboardInputEnabled(false)
    panel:SetMouseInputEnabled(not autoApproved) -- Only enable mouse for manual approvals
    
    -- Colors and styling
    local bgColor = Color(30, 30, 35, 250)
    local accentColor = autoApproved and Color(46, 204, 113) or Color(230, 126, 34)
    local textColor = Color(255, 255, 255)
    
    panel.Paint = function(self, w, h)
        -- Main background with slight transparency
        draw.RoundedBox(8, 0, 0, w, h, bgColor)
        
        -- Accent border/line
        draw.RoundedBox(8, 0, 0, 4, h, accentColor)
        
        -- Subtle inner glow
        draw.RoundedBox(8, 2, 2, w-4, h-4, Color(45, 45, 50, 100))
    end
    
    -- Icon (checkmark for auto, exclamation for manual)
    local icon = vgui.Create("DLabel", panel)
    icon:SetPos(15, 10)
    icon:SetSize(30, 30)
    icon:SetText(autoApproved and "✓" or "!")
    icon:SetTextColor(accentColor)
    icon:SetFont("DermaLarge")
    
    -- Title text
    local titleText = autoApproved and "CREDIT AUTO-APPROVED" or "CREDIT APPROVAL NEEDED"
    local title = vgui.Create("DLabel", panel)
    title:SetPos(50, 8)
    title:SetSize(300, 20)
    title:SetText(titleText)
    title:SetTextColor(textColor)
    title:SetFont("DermaDefaultBold")
    
    -- Info text
    local infoText = string.format("%s → %s", researcherName, targetName)
    if autoApproved then
        infoText = infoText .. " (No staff online)"
    end
    
    local info = vgui.Create("DLabel", panel)
    info:SetPos(50, 28)
    info:SetSize(300, 20)
    info:SetText(infoText)
    info:SetTextColor(Color(200, 200, 200))
    info:SetFont("DermaDefault")
    
    if not autoApproved then
        -- Approve button
        local approveBtn = vgui.Create("DButton", panel)
        approveBtn:SetSize(80, 30)
        approveBtn:SetPos(50, 55)
        approveBtn:SetText("")
        approveBtn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(39, 174, 96) or Color(46, 204, 113)
            draw.RoundedBox(4, 0, 0, w, h, col)
            draw.SimpleText("APPROVE", "DermaDefaultBold", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        approveBtn.DoClick = function()
            net.Start("SCPXP_CreditApproval")
                net.WriteString(requestId)
                net.WriteBool(true)
            net.SendToServer()
            
            SCPXP:RemoveApprovalNotification(requestId)
            
            -- Show brief feedback
            SCPXP:ShowBriefFeedback("APPROVED", Color(46, 204, 113))
        end
        
        -- Deny button
        local denyBtn = vgui.Create("DButton", panel)
        denyBtn:SetSize(80, 30)
        denyBtn:SetPos(140, 55)
        denyBtn:SetText("")
        denyBtn.Paint = function(self, w, h)
            local col = self:IsHovered() and Color(192, 57, 43) or Color(231, 76, 60)
            draw.RoundedBox(4, 0, 0, w, h, col)
            draw.SimpleText("DENY", "DermaDefaultBold", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
        denyBtn.DoClick = function()
            net.Start("SCPXP_CreditApproval")
                net.WriteString(requestId)
                net.WriteBool(false)
            net.SendToServer()
            
            SCPXP:RemoveApprovalNotification(requestId)
            
            -- Show brief feedback
            SCPXP:ShowBriefFeedback("DENIED", Color(231, 76, 60))
        end
    end
    
    -- Close button (X)
    local closeBtn = vgui.Create("DButton", panel)
    closeBtn:SetSize(20, 20)
    closeBtn:SetPos(370, 8)
    closeBtn:SetText("")
    closeBtn.Paint = function(self, w, h)
        local col = self:IsHovered() and Color(200, 200, 200, 150) or Color(150, 150, 150, 100)
        draw.RoundedBox(10, 0, 0, w, h, col)
        draw.SimpleText("×", "DermaDefault", w/2, h/2-1, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    closeBtn.DoClick = function()
        SCPXP:RemoveApprovalNotification(requestId)
    end
    
    -- Store the panel with metadata
    self.ActiveApprovals[requestId] = {
        panel = panel,
        timestamp = CurTime(),
        autoApproved = autoApproved or false,
        height = panel:GetTall()
    }
    
    -- Position calculation
    local yPos = self:GetNextNotificationY()
    
    -- Slide-in animation from right
    panel:MoveTo(scrW - 420, yPos, 0.4, 0, 1)
    
    -- Auto-remove timing
    local removeTime = autoApproved and 5 or 30 -- 5 seconds for auto-approved, 30 for manual
    timer.Simple(removeTime, function()
        if self.ActiveApprovals[requestId] then
            self:RemoveApprovalNotification(requestId)
        end
    end)
    
    -- Play notification sound
    surface.PlaySound(autoApproved and "buttons/button14.wav" or "buttons/button15.wav")
end

-- Calculate Y position for next notification
function SCPXP:GetNextNotificationY()
    local yPos = 20
    local spacing = 10
    
    -- Sort by timestamp to maintain order
    local sortedApprovals = {}
    for id, approval in pairs(self.ActiveApprovals) do
        if IsValid(approval.panel) then
            table.insert(sortedApprovals, {id = id, approval = approval})
        end
    end
    
    table.sort(sortedApprovals, function(a, b)
        return a.approval.timestamp < b.approval.timestamp
    end)
    
    -- Calculate position based on existing notifications
    for _, item in ipairs(sortedApprovals) do
        yPos = yPos + item.approval.height + spacing
    end
    
    return yPos
end

-- Remove approval notification with animation
function SCPXP:RemoveApprovalNotification(requestId)
    local approval = self.ActiveApprovals[requestId]
    if not approval or not IsValid(approval.panel) then return end
    
    local panel = approval.panel
    
    -- Slide out to the right
    panel:MoveTo(ScrW() + 50, panel.y, 0.3, 0, 1, function()
        if IsValid(panel) then
            panel:Remove()
        end
    end)
    
    -- Remove from active list
    self.ActiveApprovals[requestId] = nil
    
    -- Reposition remaining notifications after animation
    timer.Simple(0.35, function()
        self:RepositionApprovalNotifications()
    end)
end

-- Reposition all notifications to fill gaps
function SCPXP:RepositionApprovalNotifications()
    -- Sort by timestamp
    local sortedApprovals = {}
    for id, approval in pairs(self.ActiveApprovals) do
        if IsValid(approval.panel) then
            table.insert(sortedApprovals, {id = id, approval = approval})
        end
    end
    
    table.sort(sortedApprovals, function(a, b)
        return a.approval.timestamp < b.approval.timestamp
    end)
    
    -- Reposition each notification
    local yPos = 20
    local spacing = 10
    
    for _, item in ipairs(sortedApprovals) do
        local panel = item.approval.panel
        if IsValid(panel) then
            panel:MoveTo(ScrW() - 420, yPos, 0.2, 0, 1)
            yPos = yPos + item.approval.height + spacing
        end
    end
end

-- Show brief feedback when staff makes decision
function SCPXP:ShowBriefFeedback(action, color)
    local feedback = vgui.Create("DPanel")
    feedback:SetSize(150, 40)
    feedback:SetPos(ScrW() - 170, ScrH() - 100)
    
    feedback.Paint = function(self, w, h)
        draw.RoundedBox(4, 0, 0, w, h, Color(color.r, color.g, color.b, 200))
        draw.SimpleText(action, "DermaDefaultBold", w/2, h/2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end
    
    -- Fade out after 2 seconds
    timer.Simple(2, function()
        if IsValid(feedback) then
            feedback:AlphaTo(0, 0.5, 0, function()
                if IsValid(feedback) then
                    feedback:Remove()
                end
            end)
        end
    end)
end

-- Network receiver for approval requests
net.Receive("SCPXP_CreditRequest", function()
    local requestId = net.ReadString()
    local researcherName = net.ReadString()
    local targetName = net.ReadString()
    local researcherSteamID = net.ReadString()
    local targetSteamID = net.ReadString()
    local autoApproved = net.ReadBool()
    
    SCPXP:CreateApprovalNotification(requestId, researcherName, targetName, autoApproved)
    
    -- Optional chat notification (less prominent now)
    local chatColor = autoApproved and Color(100, 255, 100) or Color(255, 200, 100)
    local chatText = autoApproved and "Auto-approved credit: " or "Credit request: "
    
    chat.AddText(chatColor, "[SCPXP] ", Color(255, 255, 255), 
        chatText .. researcherName .. " → " .. targetName)
end)

-- Clean up on disconnect
hook.Add("ShutDown", "SCPXP_CleanupApprovals", function()
    for requestId, approval in pairs(SCPXP.ActiveApprovals) do
        if IsValid(approval.panel) then
            approval.panel:Remove()
        end
    end
    SCPXP.ActiveApprovals = {}
end)

-- Handle window resize (reposition notifications)
hook.Add("OnScreenSizeChanged", "SCPXP_HandleResize", function()
    timer.Simple(0.1, function()
        SCPXP:RepositionApprovalNotifications()
    end)
end)