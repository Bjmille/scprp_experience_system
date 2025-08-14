-- SCP-RP Experience System - Combat XP
-- File: scprp_experience_system/lua/autorun/server/sv_combat.lua

-- Combat XP tracking
SCPXP.CombatData = {}

-- Track damage for assists
function SCPXP:TrackDamage(victim, attacker, damage)
    if not IsValid(victim) or not IsValid(attacker) or attacker == victim then return end
    if not attacker:IsPlayer() then return end
    
    local victimID = victim:SteamID64()
    if not SCPXP.CombatData[victimID] then
        SCPXP.CombatData[victimID] = {}
    end
    
    local attackerID = attacker:SteamID64()
    if not SCPXP.CombatData[victimID][attackerID] then
        SCPXP.CombatData[victimID][attackerID] = {
            damage = 0,
            lastHit = 0
        }
    end
    
    SCPXP.CombatData[victimID][attackerID].damage = SCPXP.CombatData[victimID][attackerID].damage + damage
    SCPXP.CombatData[victimID][attackerID].lastHit = CurTime()
end

-- Process kill XP and assists
function SCPXP:ProcessKillXP(victim, attacker)
    if not IsValid(victim) or not IsValid(attacker) then return end
    if attacker == victim or not attacker:IsPlayer() then return end
    
    local victimCategory = self:GetPlayerJobCategory(victim)
    local attackerCategory = self:GetPlayerJobCategory(attacker)
    
    -- Give kill XP to attacker
    local killXP = self:GetKillXP(attackerCategory, victimCategory)
    if killXP > 0 then
        local reason = self:GetKillReason(attackerCategory, victimCategory, victim:Nick())
        self:AddXP(attacker, attackerCategory, killXP, reason)
    end
    
    -- Process assists
    self:ProcessAssistXP(victim, attacker, victimCategory)
    
    -- Clean up combat data for this victim
    local victimID = victim:SteamID64()
    SCPXP.CombatData[victimID] = nil
end

-- Calculate kill XP based on job categories
function SCPXP:GetKillXP(attackerCategory, victimCategory)
    local baseXP = SCPXP.Config.CombatXP.kill
    
    if attackerCategory == "security" then
        if victimCategory == "prisoner" then
            return baseXP -- Standard D-Class elimination
        elseif victimCategory == "scp" then
            return baseXP * 3 -- High reward for killing SCP
        end
    elseif attackerCategory == "prisoner" then
        if victimCategory == "security" or victimCategory == "research" then
            return baseXP -- Foundation personnel elimination
        end
    elseif attackerCategory == "scp" then
        if victimCategory ~= "scp" then
            return baseXP -- SCP killing anyone
        end
    elseif attackerCategory == "research" then
        -- Researchers generally shouldn't get combat XP, but might in self-defense
        if victimCategory == "prisoner" then
            return math.floor(baseXP * 0.5) -- Reduced XP for researchers
        end
    end
    
    return 0
end

-- Get kill reason text
function SCPXP:GetKillReason(attackerCategory, victimCategory, victimName)
    if attackerCategory == "security" then
        if victimCategory == "prisoner" then
            return "Eliminated D-Class: " .. victimName
        elseif victimCategory == "scp" then
            return "Terminated SCP: " .. victimName
        end
    elseif attackerCategory == "prisoner" then
        if victimCategory == "security" then
            return "Eliminated Security: " .. victimName
        elseif victimCategory == "research" then
            return "Eliminated Researcher: " .. victimName
        end
    elseif attackerCategory == "scp" then
        return "Eliminated: " .. victimName
    elseif attackerCategory == "research" then
        return "Self-defense: " .. victimName
    end
    
    return "Eliminated: " .. victimName
end

-- Process assist XP
function SCPXP:ProcessAssistXP(victim, killer, victimCategory)
    local victimID = victim:SteamID64()
    local killerID = killer:SteamID64()
    
    if not SCPXP.CombatData[victimID] then return end
    
    local assistThreshold = CurTime() - 10 -- 10 second assist window
    local minDamagePercent = 0.1 -- Must do at least 10% damage
    local victimMaxHP = victim:GetMaxHealth()
    
    for attackerID, data in pairs(SCPXP.CombatData[victimID]) do
        -- Skip the killer and check assist conditions
        if attackerID ~= killerID and data.lastHit >= assistThreshold then
            local damagePercent = data.damage / victimMaxHP
            if damagePercent >= minDamagePercent then
                local assister = player.GetBySteamID64(attackerID)
                if IsValid(assister) then
                    local assisterCategory = self:GetPlayerJobCategory(assister)
                    
                    -- Check if this assist is valid (same "team")
                    if self:IsValidAssist(assisterCategory, victimCategory) then
                        local assistXP = SCPXP.Config.CombatXP.assist
                        local reason = "Combat assist vs " .. victim:Nick()
                        self:AddXP(assister, assisterCategory, assistXP, reason)
                    end
                end
            end
        end
    end
end

-- Check if assist is valid (same team effort)
function SCPXP:IsValidAssist(assisterCategory, victimCategory)
    if assisterCategory == "security" then
        return victimCategory == "prisoner" or victimCategory == "scp"
    elseif assisterCategory == "prisoner" then
        return victimCategory == "security" or victimCategory == "research"
    elseif assisterCategory == "scp" then
        return victimCategory ~= "scp"
    elseif assisterCategory == "research" then
        return victimCategory == "prisoner" -- Researchers might assist security
    end
    
    return false
end

-- SCP Breach XP
function SCPXP:ProcessBreachXP(scp)
    if not IsValid(scp) then return end
    
    local scpCategory = self:GetPlayerJobCategory(scp)
    if scpCategory == "scp" then
        local breachXP = SCPXP.Config.CombatXP.breach
        self:AddXP(scp, "scp", breachXP, "Breached containment")
        
        -- Announce breach to nearby security
        self:AnnounceBreachToSecurity(scp)
    end
end

-- SCP Recontainment XP
function SCPXP:ProcessRecontainmentXP(scp, recontainer)
    if not IsValid(scp) or not IsValid(recontainer) then return end
    
    local recontainerCategory = self:GetPlayerJobCategory(recontainer)
    if recontainerCategory == "security" then
        local recontainXP = SCPXP.Config.CombatXP.recontain
        local scpName = scp:Nick()
        self:AddXP(recontainer, "security", recontainXP, "Recontained " .. scpName)
        
        -- Give partial XP to nearby security who assisted
        self:ProcessRecontainmentAssists(scp, recontainer)
    end
end

-- Process recontainment assists
function SCPXP:ProcessRecontainmentAssists(scp, recontainer)
    local recontainerPos = recontainer:GetPos()
    local assistXP = math.floor(SCPXP.Config.CombatXP.recontain * 0.3)
    
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and ply ~= recontainer then
            local plyCategory = self:GetPlayerJobCategory(ply)
            if plyCategory == "security" then
                local distance = ply:GetPos():Distance(recontainerPos)
                if distance <= 300 then -- Within 300 units
                    self:AddXP(ply, "security", assistXP, "Assisted recontainment")
                end
            end
        end
    end
end

-- Announce breach to security
function SCPXP:AnnounceBreachToSecurity(scp)
    local message = scp:Nick() .. " has breached containment!"
    
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) then
            local plyCategory = self:GetPlayerJobCategory(ply)
            if plyCategory == "security" then
                net.Start("SCPXP_Notification")
                net.WriteString("scp_breach")
                net.WriteTable({
                    message = message,
                    scpName = scp:Nick()
                })
                net.Send(ply)
            end
        end
    end
end

-- Cleanup old combat data
timer.Create("SCPXP_CombatCleanup", 30, 0, function()
    local cutoffTime = CurTime() - 15 -- Remove data older than 15 seconds
    
    for victimID, attackers in pairs(SCPXP.CombatData) do
        for attackerID, data in pairs(attackers) do
            if data.lastHit < cutoffTime then
                SCPXP.CombatData[victimID][attackerID] = nil
            end
        end
        
        -- Remove empty victim entries
        if table.IsEmpty(SCPXP.CombatData[victimID]) then
            SCPXP.CombatData[victimID] = nil
        end
    end
end)