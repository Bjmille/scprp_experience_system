-- SCP-RP Experience System - Credit System
-- File: scprp_experience_system/lua/autorun/server/sv_credit.lua

-- Process Credit Request
function SCPXP:ProcessCreditRequest(requester, target)
    if not IsValid(requester) or not IsValid(target) then return false end
    
    -- Prevent self-crediting
    if requester == target then
        self:SendNotification(requester, "error", "You cannot credit yourself!")
        return false
    end
    
    local requesterSteamID = requester:SteamID64()
    local targetSteamID = target:SteamID64()
    local currentTime = os.time()
    
    -- Check if requester is researcher
    local requesterCategory = self:GetPlayerJobCategory(requester)
    if requesterCategory ~= "research" then
        self:SendNotification(requester, "error", "Only researchers can use !credit")
        return false
    end
    
    -- Load target data if needed
    if not SCPXP.Players[targetSteamID] then
        SCPXP.Database:LoadPlayer(target)
    end
    
    -- Check cooldown
    local lastCredit = SCPXP.Players[targetSteamID].last_credit or 0
    if lastCredit + SCPXP.Config.CreditCooldown > currentTime then
        local remaining = lastCredit + SCPXP.Config.CreditCooldown - currentTime
        local minutes = math.ceil(remaining / 60)
        self:SendNotification(requester, "error", "Target is on credit cooldown (" .. minutes .. "m remaining)")
        return false
    end
    
    -- Check if there are too many pending requests
    local pendingCount = #SCPXP.Database:GetPendingCreditRequests()
    if pendingCount >= SCPXP.Config.Database.maxCreditRequests then
        self:SendNotification(requester, "error", "Too many pending credit requests. Please wait.")
        return false
    end
    
    -- Create credit request in database
    local requestID = SCPXP.Database:CreateCreditRequest(requester, target)
    if not requestID then
        self:SendNotification(requester, "error", "Failed to create credit request")
        return false
    end
    
    -- Notify all online staff
    local staffNotified = 0
    for _, admin in ipairs(player.GetAll()) do
        if IsValid(admin) and SCPXP:IsAdmin(admin) then
            net.Start("SCPXP_CreditRequest")
            net.WriteTable({
                id = tonumber(requestID),
                requesterName = requester:Nick(),
                targetName = target:Nick(),
                requesterSteamID = requesterSteamID,
                targetSteamID = targetSteamID,
                timestamp = currentTime
            })
            net.Send(admin)
            staffNotified = staffNotified + 1
        end
    end
    
    if staffNotified > 0 then
        self:SendNotification(requester, "success", "Credit request sent to " .. staffNotified .. " staff member(s)")
        SCPXP:Debug("Credit request #" .. requestID .. " created by " .. requester:Nick() .. " for " .. target:Nick())
    else
        self:SendNotification(requester, "warning", "Credit request created but no staff online to approve")
    end
    
    return true
end

-- Approve Credit Request
function SCPXP:ApproveCreditRequest(requestID, admin)
    if not requestID or not IsValid(admin) then return false end
    
    -- Get request data
    local requestData = sql.QueryRow("SELECT * FROM scpxp_credit_requests WHERE id = " .. tonumber(requestID) .. " AND status = 'pending'")
    if not requestData then
        self:SendNotification(admin, "error", "Credit request not found or already processed")
        return false
    end
    
    local requester = player.GetBySteamID64(requestData.requester_steamid)
    local target = player.GetBySteamID64(requestData.target_steamid)
    
    -- Check if players are still online
    if not IsValid(requester) then
        self:SendNotification(admin, "error", "Requester is no longer online")
        return false
    end
    
    if not IsValid(target) then
        self:SendNotification(admin, "error", "Target is no longer online")
        return false
    end
    
    -- Double-check cooldown
    local targetSteamID = target:SteamID64()
    if not SCPXP.Players[targetSteamID] then
        SCPXP.Database:LoadPlayer(target)
    end
    
    local currentTime = os.time()
    local lastCredit = SCPXP.Players[targetSteamID].last_credit or 0
    if lastCredit + SCPXP.Config.CreditCooldown > currentTime then
        self:SendNotification(admin, "error", "Target is still on cooldown")
        return false
    end
    
    -- Give XP
    local targetCategory = self:GetPlayerJobCategory(target)
    self:AddXP(requester, "research", SCPXP.Config.CreditResearcherXP, "Credit given to " .. target:Nick())
    self:AddXP(target, targetCategory, SCPXP.Config.CreditTargetXP, "Credit received from " .. requester:Nick())
    
    -- Update cooldown
    SCPXP.Players[targetSteamID].last_credit = currentTime
    SCPXP.Database:SavePlayer(target)
    
    -- Update request status
    SCPXP.Database:UpdateCreditRequestStatus(requestID, "approved", admin)
    
    -- Send notifications
    self:SendNotification(requester, "success", "Credit approved! +" .. SCPXP.Config.CreditResearcherXP .. " Research XP")
    self:SendNotification(target, "success", "Credit received! +" .. SCPXP.Config.CreditTargetXP .. " " .. SCPXP:GetCategoryName(targetCategory) .. " XP")
    self:SendNotification(admin, "success", "Credit request approved")
    
    SCPXP:Debug("Admin " .. admin:Nick() .. " approved credit request #" .. requestID)
    return true
end

-- Deny Credit Request
function SCPXP:DenyCreditRequest(requestID, admin, reason)
    if not requestID or not IsValid(admin) then return false end
    
    -- Get request data
    local requestData = sql.QueryRow("SELECT * FROM scpxp_credit_requests WHERE id = " .. tonumber(requestID) .. " AND status = 'pending'")
    if not requestData then
        self:SendNotification(admin, "error", "Credit request not found or already processed")
        return false
    end
    
    local requester = player.GetBySteamID64(requestData.requester_steamid)
    
    -- Update request status
    SCPXP.Database:UpdateCreditRequestStatus(requestID, "denied", admin)
    
    -- Send notifications
    if IsValid(requester) then
        local denyMessage = "Credit request denied"
        if reason and reason ~= "" then
            denyMessage = denyMessage .. ": " .. reason
        end
        self:SendNotification(requester, "error", denyMessage)
    end
    
    self:SendNotification(admin, "success", "Credit request denied")
    
    SCPXP:Debug("Admin " .. admin:Nick() .. " denied credit request #" .. requestID .. (reason and (" - " .. reason) or ""))
    return true
end

-- Get Pending Requests for Admin Panel
function SCPXP:GetPendingRequestsForAdmin(admin)
    if not IsValid(admin) or not SCPXP:IsAdmin(admin) then return {} end
    
    local requests = SCPXP.Database:GetPendingCreditRequests()
    local formattedRequests = {}
    
    for _, request in ipairs(requests) do
        local timeDiff = os.time() - tonumber(request.timestamp)
        local timeText = SCPXP:FormatTime(timeDiff) .. " ago"
        
        table.insert(formattedRequests, {
            id = tonumber(request.id),
            requesterName = request.requester_name,
            targetName = request.target_name,
            requesterSteamID = request.requester_steamid,
            targetSteamID = request.target_steamid,
            timestamp = tonumber(request.timestamp),
            timeText = timeText
        })
    end
    
    return formattedRequests
end

-- Network Handlers
net.Receive("SCPXP_CreditResponse", function(len, ply)
    if not IsValid(ply) or not SCPXP:IsAdmin(ply) then return end
    
    local action = net.ReadString()
    local requestID = net.ReadInt(32)
    
    if action == "approve" then
        SCPXP:ApproveCreditRequest(requestID, ply)
    elseif action == "deny" then
        local reason = net.ReadString()
        SCPXP:DenyCreditRequest(requestID, ply, reason)
    elseif action == "get_pending" then
        local pendingRequests = SCPXP:GetPendingRequestsForAdmin(ply)
        
        net.Start("SCPXP_CreditRequest")
        net.WriteString("pending_list")
        net.WriteTable(pendingRequests)
        net.Send(ply)
    end
end)

-- Send Notification Helper
function SCPXP:SendNotification(ply, type, message)
    if not IsValid(ply) then return end
    
    net.Start("SCPXP_Notification")
    net.WriteString(type)
    net.WriteTable({
        message = message
    })
    net.Send(ply)
end

-- Auto-cleanup old requests
timer.Create("SCPXP_CleanupRequests", 3600, 0, function() -- Every hour
    SCPXP.Database:CleanupOldRequests()
end)