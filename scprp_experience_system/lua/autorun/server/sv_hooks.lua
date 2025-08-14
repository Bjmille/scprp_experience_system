-- SCP-RP Experience System - Server Hooks
-- File: scprp_experience_system/lua/autorun/server/sv_hooks.lua

-- Player Connection Hooks
hook.Add("PlayerInitialSpawn", "SCPXP_PlayerJoin", function(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    
    timer.Simple(2, function()
        if IsValid(ply) then
            SCPXP.Database:LoadPlayer(ply)
            SCPXP:Debug("Loaded XP data for " .. ply:Nick())
        end
    end)
end)

hook.Add("PlayerDisconnected", "SCPXP_PlayerLeave", function(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    
    SCPXP.Database:SavePlayer(ply)
    SCPXP:Debug("Saved XP data for " .. ply:Nick())
    
    -- Clean up combat data
    local steamid = ply:SteamID64()
    if SCPXP.CombatData[steamid] then
        SCPXP.CombatData[steamid] = nil
    end
    
    -- Remove from memory after delay to allow for saves
    timer.Simple(5, function()
        SCPXP.Players[steamid] = nil
    end)
end)

-- Combat Hooks
hook.Add("PlayerHurt", "SCPXP_TrackDamage", function(victim, attacker, healthRemaining, damageTaken)
    if not IsValid(victim) or not IsValid(attacker) then return end
    if victim == attacker or not attacker:IsPlayer() then return end
    
    SCPXP:TrackDamage(victim, attacker, damageTaken)
end)

hook.Add("PlayerDeath", "SCPXP_PlayerDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) then return end
    
    -- Process kill XP if attacker is valid
    if IsValid(attacker) and attacker:IsPlayer() and attacker ~= victim then
        SCPXP:ProcessKillXP(victim, attacker)
    end
    
    -- Check if this was an SCP being killed (recontainment)
    local victimCategory = SCPXP:GetPlayerJobCategory(victim)
    if victimCategory == "scp" and IsValid(attacker) and attacker:IsPlayer() then
        local attackerCategory = SCPXP:GetPlayerJobCategory(attacker)
        if attackerCategory == "security" then
            SCPXP:ProcessRecontainmentXP(victim, attacker)
        end
    end
end)

-- Job Change Hooks
hook.Add("canChangeJob", "SCPXP_JobLevelCheck", function(ply, job)
    if not IsValid(ply) or not job then return end
    
    return SCPXP:CanChangeJob(ply, job.name)
end)

hook.Add("OnPlayerChangedTeam", "SCPXP_JobChanged", function(ply, before, after)
    if not IsValid(ply) then return end
    
    -- Check if player just became an SCP and might have breached
    timer.Simple(1, function()
        if IsValid(ply) then
            local newCategory = SCPXP:GetPlayerJobCategory(ply)
            if newCategory == "scp" then
                -- Small delay to check if this is a breach scenario
                timer.Simple(2, function()
                    if IsValid(ply) and SCPXP:GetPlayerJobCategory(ply) == "scp" then
                        -- Check if player is outside containment (implement your own logic)
                        -- This is a placeholder - you'd need to implement containment zone detection
                        -- SCPXP:ProcessBreachXP(ply)
                    end
                end)
            end
        end
    end)
end)

-- Chat Commands
hook.Add("PlayerSay", "SCPXP_ChatCommands", function(ply, text, teamChat)
    if not IsValid(ply) then return end
    
    local args = string.Explode(" ", text)
    local cmd = string.lower(args[1])
    
    if cmd == "!credit" then
        if #args < 2 then
            SCPXP:SendNotification(ply, "error", "Usage: !credit <player>")
        else
            local targetName = args[2]
            local target = DarkRP.findPlayer(targetName)
            
            if IsValid(target) then
                SCPXP:ProcessCreditRequest(ply, target)
            else
                SCPXP:SendNotification(ply, "error", "Player '" .. targetName .. "' not found!")
            end
        end
        return ""
        
    elseif cmd == "!xp" or cmd == "!level" or cmd == "!levels" then
        -- Send player's XP data
        net.Start("SCPXP_RequestData")
        net.Send(ply)
        return ""
        
    elseif cmd == "!xptop" or cmd == "!toplevel" then
        local category = "research"
        if args[2] then
            category = string.lower(args[2])
            if not SCPXP:IsValidCategory(category) then
                SCPXP:SendNotification(ply, "error", "Invalid category! Use: research, security, prisoner, scp")
                return ""
            end
        end
        
        local topPlayers = SCPXP.Database:GetTopPlayers(category, 5)
        
        ply:ChatPrint("=== Top 5 " .. SCPXP:GetCategoryName(category) .. " Players ===")
        
        if #topPlayers == 0 then
            ply:ChatPrint("No data available.")
        else
            for i, playerData in ipairs(topPlayers) do
                local xp = tonumber(playerData.xp) or 0
                local level = SCPXP:GetPlayerLevel({SteamID64 = function() return playerData.steamid end}, category)
                
                local onlinePlayer = player.GetBySteamID64(playerData.steamid)
                local playerName = IsValid(onlinePlayer) and onlinePlayer:Nick() or "Offline Player"
                
                ply:ChatPrint(i .. ". " .. playerName .. " - Level " .. level .. " (" .. SCPXP:FormatXP(xp) .. " XP)")
            end
        end
        return ""
    end
end)

-- DarkRP Money Hooks (if you want to integrate with DarkRP economy)
hook.Add("playerBoughtCustomEntity", "SCPXP_Research", function(ply, entTable, entity, price)
    if not IsValid(ply) then return end
    
    local plyCategory = SCPXP:GetPlayerJobCategory(ply)
    if plyCategory == "research" then
        -- Give small XP bonus for purchasing research equipment
        SCPXP:AddXP(ply, "research", 5, "Purchased research equipment")
    end
end)

-- Custom SCP Events (you'll need to implement these based on your SCP addon)
-- These are example hooks - adapt them to your specific SCP addon

--[[
hook.Add("SCP_Breach", "SCPXP_SCPBreach", function(scp)
    if IsValid(scp) and scp:IsPlayer() then
        SCPXP:ProcessBreachXP(scp)
    end
end)

hook.Add("SCP_Recontained", "SCPXP_SCPRecontain", function(scp, recontainer)
    if IsValid(scp) and IsValid(recontainer) and scp:IsPlayer() and recontainer:IsPlayer() then
        SCPXP:ProcessRecontainmentXP(scp, recontainer)
    end
end)

hook.Add("SCP_EscapeFacility", "SCPXP_SCPEscape", function(scp)
    if IsValid(scp) and scp:IsPlayer() then
        local escapeXP = SCPXP.Config.CombatXP.breach * 3
        SCPXP:AddXP(scp, "scp", escapeXP, "Escaped the facility")
    end
end)

hook.Add("DClass_Escape", "SCPXP_DClassEscape", function(dclass)
    if IsValid(dclass) and dclass:IsPlayer() then
        local escapeXP = 200
        SCPXP:AddXP(dclass, "prisoner", escapeXP, "Escaped the facility")
    end
end)
--]]

-- Server Performance Monitoring
local lastPerformanceCheck = 0
hook.Add("Think", "SCPXP_PerformanceMonitor", function()
    local currentTime = CurTime()
    if currentTime - lastPerformanceCheck < 30 then return end -- Check every 30 seconds
    
    lastPerformanceCheck = currentTime
    
    -- Clean up old combat data more aggressively if server is struggling
    local fps = math.Round(1 / FrameTime())
    if fps < 20 then
        local cleaned = 0
        local cutoffTime = currentTime - 5 -- More aggressive cleanup
        
        for victimID, attackers in pairs(SCPXP.CombatData) do
            for attackerID, data in pairs(attackers) do
                if data.lastHit < cutoffTime then
                    SCPXP.CombatData[victimID][attackerID] = nil
                    cleaned = cleaned + 1
                end
            end
            
            if table.IsEmpty(SCPXP.CombatData[victimID]) then
                SCPXP.CombatData[victimID] = nil
            end
        end
        
        if cleaned > 0 then
            SCPXP:Debug("Performance cleanup: removed " .. cleaned .. " combat entries")
        end
    end
end)

-- Shutdown Hook
hook.Add("ShutDown", "SCPXP_Shutdown", function()
    print("[SCPXP] Server shutting down, saving all player data...")
    
    for _, ply in ipairs(player.GetAll()) do
        if IsValid(ply) and not ply:IsBot() then
            SCPXP.Database:SavePlayer(ply)
        end
    end
    
    print("[SCPXP] All player data saved!")
end)

-- Error Handling
hook.Add("LuaError", "SCPXP_ErrorHandler", function(err, realm, stack, name, id)
    if string.find(err, "SCPXP") then
        print("[SCPXP ERROR] " .. err)
        print("[SCPXP ERROR] Stack: " .. (stack or "No stack trace"))
    end
end)