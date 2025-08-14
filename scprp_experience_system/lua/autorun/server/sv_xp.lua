-- SCP-RP Experience System - XP Management
-- File: scprp_experience_system/lua/autorun/server/sv_xp.lua

-- Add XP to Player
function SCPXP:AddXP(ply, category, amount, reason, admin)
    if not IsValid(ply) or not SCPXP:IsValidCategory(category) then return false end
    
    amount = tonumber(amount) or 0
    if amount == 0 then return false end
    
    local steamid = ply:SteamID64()
    if not SCPXP.Players[steamid] then
        SCPXP.Database:LoadPlayer(ply)
    end
    
    local oldXP = SCPXP.Players[steamid][category] or 0
    local oldLevel = self:GetPlayerLevel(ply, category)
    
    -- Apply XP change
    SCPXP.Players[steamid][category] = math.max(0, oldXP + amount)
    local newXP = SCPXP.Players[steamid][category]
    local newLevel = self:GetPlayerLevel(ply, category)
    
    -- Log the change
    SCPXP.Database:LogXPChange(ply, category, amount, reason, admin)
    
    -- Send XP notification
    net.Start("SCPXP_Notification")
    net.WriteString("xp_gained")
    net.WriteTable({
        category = category,
        amount = amount,
        reason = reason or "Unknown",
        newXP = newXP,
        newLevel = newLevel
    })
    net.Send(ply)
    
    -- Check for level up
    if newLevel > oldLevel then
        net.Start("SCPXP_Notification")
        net.WriteString("level_up")
        net.WriteTable({
            category = category,
            level = newLevel,
            oldLevel = oldLevel
        })
        net.Send(ply)
        
        -- Broadcast level up to nearby players
        self:BroadcastLevelUp(ply, category, newLevel)
    end
    
    -- Save data
    SCPXP.Database:SavePlayer(ply)
    
    SCPXP:Debug(ply:Nick() .. " gained " .. amount .. " " .. category .. " XP (" .. reason .. ")")
    return true
end

-- Set XP (Admin function)
function SCPXP:SetXP(ply, category, amount, admin)
    if not IsValid(ply) or not SCPXP:IsValidCategory(category) then return false end
    
    amount = math.max(0, tonumber(amount) or 0)
    
    local steamid = ply:SteamID64()
    if not SCPXP.Players[steamid] then
        SCPXP.Database:LoadPlayer(ply)
    end
    
    local oldXP = SCPXP.Players[steamid][category] or 0
    local oldLevel = self:GetPlayerLevel(ply, category)
    
    SCPXP.Players[steamid][category] = amount
    local newLevel = self:GetPlayerLevel(ply, category)
    
    -- Log the change
    local reason = "Admin set XP to " .. amount
    SCPXP.Database:LogXPChange(ply, category, amount - oldXP, reason, admin)
    
    -- Send notification
    net.Start("SCPXP_Notification")
    net.WriteString("admin_xp_set")
    net.WriteTable({
        category = category,
        amount = amount,
        admin = IsValid(admin) and admin:Nick() or "Console"
    })
    net.Send(ply)
    
    -- Check for level change
    if newLevel ~= oldLevel then
        net.Start("SCPXP_Notification")
        net.WriteString("level_changed")
        net.WriteTable({
            category = category,
            level = newLevel,
            oldLevel = oldLevel
        })
        net.Send(ply)
    end
    
    -- Save data
    SCPXP.Database:SavePlayer(ply)
    
    SCPXP:Debug((IsValid(admin) and admin:Nick() or "Console") .. " set " .. ply:Nick() .. "'s " .. category .. " XP to " .. amount)
    return true
end

-- Reset Player Data
function SCPXP:ResetPlayerData(ply, admin)
    if not IsValid(ply) then return false end
    
    local steamid = ply:SteamID64()
    
    -- Reset all categories
    SCPXP.Players[steamid] = {
        research = 0,
        security = 0,
        prisoner = 0,
        scp = 0,
        last_activity = os.time(),
        last_credit = 0
    }
    
    -- Log the reset
    for category, _ in pairs(SCPXP.Config.XPCategories) do
        SCPXP.Database:LogXPChange(ply, category, 0, "Data reset by admin", admin)
    end
    
    -- Send notification
    net.Start("SCPXP_Notification")
    net.WriteString("data_reset")
    net.WriteTable({
        admin = IsValid(admin) and admin:Nick() or "Console"
    })
    net.Send(ply)
    
    -- Save data
    SCPXP.Database:SavePlayer(ply)
    
    SCPXP:Debug((IsValid(admin) and admin:Nick() or "Console") .. " reset all data for " .. ply:Nick())
    return true
end

-- Broadcast Level Up
function SCPXP:BroadcastLevelUp(ply, category, level)
    if not IsValid(ply) then return end
    
    local categoryName = SCPXP:GetCategoryName(category)
    local message = ply:Nick() .. " reached " .. categoryName .. " Level " .. level .. "!"
    
    -- Send to nearby players (within 500 units)
    for _, otherPly in ipairs(player.GetAll()) do
        if IsValid(otherPly) and otherPly ~= ply then
            local distance = ply:GetPos():Distance(otherPly:GetPos())
            if distance <= 500 then
                net.Start("SCPXP_Notification")
                net.WriteString("player_level_up")
                net.WriteTable({
                    playerName = ply:Nick(),
                    category = category,
                    level = level
                })
                net.Send(otherPly)
            end
        end
    end
end

-- Activity XP System
function SCPXP:StartActivityTimer()
    timer.Create("SCPXP_Activity", SCPXP.Config.ActivityInterval, 0, function()
        for _, ply in ipairs(player.GetAll()) do
            if IsValid(ply) and not ply:IsBot() then
                local category = self:GetPlayerJobCategory(ply)
                self:AddXP(ply, category, SCPXP.Config.ActivityXP, "Activity bonus")
            end
        end
        SCPXP:Debug("Activity XP distributed to " .. #player.GetAll() .. " players")
    end)
end

-- Give XP based on performance
function SCPXP:GivePerformanceXP(ply, action, target)
    if not IsValid(ply) then return end
    
    local category = self:GetPlayerJobCategory(ply)
    local xpAmount = 0
    local reason = ""
    
    -- Different XP amounts based on action and job category
    if action == "kill" then
        if category == "security" then
            local targetCategory = self:GetPlayerJobCategory(target)
            if targetCategory == "prisoner" then
                xpAmount = SCPXP.Config.CombatXP.kill
                reason = "Eliminated D-Class"
            elseif targetCategory == "scp" then
                xpAmount = SCPXP.Config.CombatXP.kill * 2
                reason = "Assisted SCP recontainment"
            end
        elseif category == "prisoner" then
            local targetCategory = self:GetPlayerJobCategory(target)
            if targetCategory == "security" or targetCategory == "research" then
                xpAmount = SCPXP.Config.CombatXP.kill
                reason = "Eliminated Foundation personnel"
            end
        elseif category == "scp" then
            xpAmount = SCPXP.Config.CombatXP.kill
            reason = "Eliminated target"
        end
    elseif action == "assist" then
        xpAmount = SCPXP.Config.CombatXP.assist
        reason = "Combat assist"
    elseif action == "breach" and category == "scp" then
        xpAmount = SCPXP.Config.CombatXP.breach
        reason = "Breached containment"
    elseif action == "recontain" and category == "security" then
        xpAmount = SCPXP.Config.CombatXP.recontain
        reason = "SCP recontainment"
    end
    
    if xpAmount > 0 then
        self:AddXP(ply, category, xpAmount, reason)
    end
end

-- Network handlers
net.Receive("SCPXP_RequestData", function(len, ply)
    if not IsValid(ply) then return end
    
    local steamid = ply:SteamID64()
    if not SCPXP.Players[steamid] then
        SCPXP.Database:LoadPlayer(ply)
    end
    
    local data = SCPXP.Players[steamid]
    if data then
        net.Start("SCPXP_SendData")
        net.WriteTable(data)
        net.Send(ply)
    end
end)

-- Job Level Check Integration
function SCPXP:CanChangeJob(ply, jobName)
    if not IsValid(ply) or not jobName then return true end
    
    local requirement = SCPXP.Config.JobRequirements[jobName]
    if not requirement then return true end
    
    local playerLevel = self:GetPlayerLevel(ply, requirement.category)
    if playerLevel < requirement.level then
        net.Start("SCPXP_Notification")
        net.WriteString("job_level_required")
        net.WriteTable({
            job = jobName,
            category = requirement.category,
            requiredLevel = requirement.level,
            currentLevel = playerLevel
        })
        net.Send(ply)
        return false
    end
    
    return true
end