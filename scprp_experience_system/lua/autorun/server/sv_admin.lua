-- SCP-RP Experience System - Admin Commands
-- File: scprp_experience_system/lua/autorun/server/sv_admin.lua

-- Initialize Admin System
function SCPXP:InitializeAdmin()
    -- Console commands
    self:CreateAdminCommands()
    
    -- Admin panel network handlers
    self:SetupAdminNetworking()
    
    SCPXP:Debug("Admin system initialized")
end

-- Create Console Commands
function SCPXP:CreateAdminCommands()
    -- Set XP Command
    concommand.Add("scpxp_setxp", function(ply, cmd, args)
        if IsValid(ply) and not SCPXP:IsAdmin(ply) then
            ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
            return
        end
        
        if #args < 3 then
            local usage = "[SCPXP] Usage: scpxp_setxp <player> <category> <amount>"
            if IsValid(ply) then
                ply:ChatPrint(usage)
            else
                print(usage)
            end
            return
        end
        
        local target = DarkRP.findPlayer(args[1])
        if not IsValid(target) then
            local msg = "[SCPXP] Player '" .. args[1] .. "' not found!"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        local category = string.lower(args[2])
        if not SCPXP:IsValidCategory(category) then
            local msg = "[SCPXP] Invalid category! Use: research, security, prisoner, scp"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        local amount = tonumber(args[3])
        if not amount or amount < 0 then
            local msg = "[SCPXP] Invalid amount! Must be a positive number."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        SCPXP:SetXP(target, category, amount, ply)
        
        local adminName = IsValid(ply) and ply:Nick() or "Console"
        local msg = "[SCPXP] " .. adminName .. " set " .. target:Nick() .. "'s " .. 
                   SCPXP:GetCategoryName(category) .. " XP to " .. SCPXP:FormatXP(amount)
        
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)
    
    -- Add XP Command
    concommand.Add("scpxp_addxp", function(ply, cmd, args)
        if IsValid(ply) and not SCPXP:IsAdmin(ply) then
            ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
            return
        end
        
        if #args < 3 then
            local usage = "[SCPXP] Usage: scpxp_addxp <player> <category> <amount> [reason]"
            if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
            return
        end
        
        local target = DarkRP.findPlayer(args[1])
        if not IsValid(target) then
            local msg = "[SCPXP] Player '" .. args[1] .. "' not found!"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        local category = string.lower(args[2])
        if not SCPXP:IsValidCategory(category) then
            local msg = "[SCPXP] Invalid category! Use: research, security, prisoner, scp"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        local amount = tonumber(args[3])
        if not amount then
            local msg = "[SCPXP] Invalid amount! Must be a number."
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        local reason = "Admin adjustment"
        if args[4] then
            reason = table.concat(args, " ", 4)
        end
        
        SCPXP:AddXP(target, category, amount, reason, ply)
        
        local adminName = IsValid(ply) and ply:Nick() or "Console"
        local action = amount > 0 and "gave" or "removed"
        local msg = "[SCPXP] " .. adminName .. " " .. action .. " " .. math.abs(amount) .. 
                   " " .. SCPXP:GetCategoryName(category) .. " XP " .. (amount > 0 and "to" or "from") .. " " .. target:Nick()
        
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)
    
    -- Reset Player Data Command
    concommand.Add("scpxp_resetplayer", function(ply, cmd, args)
        if IsValid(ply) and not SCPXP:IsAdmin(ply) then
            ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
            return
        end
        
        if #args < 1 then
            local usage = "[SCPXP] Usage: scpxp_resetplayer <player>"
            if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
            return
        end
        
        local target = DarkRP.findPlayer(args[1])
        if not IsValid(target) then
            local msg = "[SCPXP] Player '" .. args[1] .. "' not found!"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        SCPXP:ResetPlayerData(target, ply)
        
        local adminName = IsValid(ply) and ply:Nick() or "Console"
        local msg = "[SCPXP] " .. adminName .. " reset all XP data for " .. target:Nick()
        
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)
    
    -- View Player XP Command
    concommand.Add("scpxp_viewplayer", function(ply, cmd, args)
        if IsValid(ply) and not SCPXP:IsAdmin(ply) then
            ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
            return
        end
        
        if #args < 1 then
            local usage = "[SCPXP] Usage: scpxp_viewplayer <player>"
            if IsValid(ply) then ply:ChatPrint(usage) else print(usage) end
            return
        end
        
        local target = DarkRP.findPlayer(args[1])
        if not IsValid(target) then
            local msg = "[SCPXP] Player '" .. args[1] .. "' not found!"
            if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
            return
        end
        
        local targetSteamID = target:SteamID64()
        if not SCPXP.Players[targetSteamID] then
            SCPXP.Database:LoadPlayer(target)
        end
        
        local msg = "[SCPXP] " .. target:Nick() .. "'s XP:"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        
        for category, config in pairs(SCPXP.Config.XPCategories) do
            local xp = SCPXP:GetPlayerXP(target, category)
            local level = SCPXP:GetPlayerLevel(target, category)
            local categoryMsg = "  " .. config.displayName .. ": " .. SCPXP:FormatXP(xp) .. " XP (Level " .. level .. ")"
            if IsValid(ply) then ply:ChatPrint(categoryMsg) else print(categoryMsg) end
        end
    end)
    
    -- Backup Data Command
    concommand.Add("scpxp_backup", function(ply, cmd, args)
        if IsValid(ply) and not SCPXP:IsAdmin(ply) then
            ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
            return
        end
        
        local backupFile = SCPXP.Database:BackupData()
        local msg = "[SCPXP] Backup created: " .. backupFile
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
    end)
    
    -- Top Players Command
    concommand.Add("scpxp_top", function(ply, cmd, args)
        if IsValid(ply) and not SCPXP:IsAdmin(ply) then
            ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
            return
        end
        
        local category = "research"
        local limit = 10
        
        if args[1] then
            category = string.lower(args[1])
            if not SCPXP:IsValidCategory(category) then
                local msg = "[SCPXP] Invalid category! Use: research, security, prisoner, scp"
                if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
                return
            end
        end
        
        if args[2] then
            limit = math.Clamp(tonumber(args[2]) or 10, 1, 20)
        end
        
        local topPlayers = SCPXP.Database:GetTopPlayers(category, limit)
        
        local msg = "[SCPXP] Top " .. limit .. " " .. SCPXP:GetCategoryName(category) .. " Players:"
        if IsValid(ply) then ply:ChatPrint(msg) else print(msg) end
        
        for i, playerData in ipairs(topPlayers) do
            local steamid = playerData.steamid
            local xp = tonumber(playerData.xp) or 0
            local level = math.floor(xp / SCPXP.Config.XPPerLevel)
            
            -- Try to get player name
            local playerName = "Unknown"
            local onlinePlayer = player.GetBySteamID64(steamid)
            if IsValid(onlinePlayer) then
                playerName = onlinePlayer:Nick()
            else
                -- Could implement name caching here
                playerName = "Offline Player"
            end
            
            local rankMsg = "  " .. i .. ". " .. playerName .. " - " .. SCPXP:FormatXP(xp) .. " XP (Level " .. level .. ")"
            if IsValid(ply) then ply:ChatPrint(rankMsg) else print(rankMsg) end
        end
        
        if #topPlayers == 0 then
            local noDataMsg = "[SCPXP] No data found for " .. SCPXP:GetCategoryName(category) .. " category"
            if IsValid(ply) then ply:ChatPrint(noDataMsg) else print(noDataMsg) end
        end
    end)
end

-- Setup Admin Panel Networking
function SCPXP:SetupAdminNetworking()
    net.Receive("SCPXP_AdminPanel", function(len, ply)
        if not IsValid(ply) or not SCPXP:IsAdmin(ply) then return end
        
        local action = net.ReadString()
        
        if action == "get_stats" then
            -- Send server statistics
            local stats = {
                totalPlayers = #sql.Query("SELECT COUNT(*) as count FROM scpxp_players") or 0,
                pendingRequests = #SCPXP.Database:GetPendingCreditRequests(),
                onlinePlayers = #player.GetAll(),
                uptime = math.floor(CurTime())
            }
            
            net.Start("SCPXP_AdminPanel")
            net.WriteString("server_stats")
            net.WriteTable(stats)
            net.Send(ply)
            
        elseif action == "get_player_list" then
            -- Send online player list with XP data
            local playerList = {}
            
            for _, target in ipairs(player.GetAll()) do
                if IsValid(target) then
                    local steamid = target:SteamID64()
                    if not SCPXP.Players[steamid] then
                        SCPXP.Database:LoadPlayer(target)
                    end
                    
                    local playerData = {
                        name = target:Nick(),
                        steamid = steamid,
                        job = target:getDarkRPVar("job") or "Unknown",
                        xp = {}
                    }
                    
                    for category, _ in pairs(SCPXP.Config.XPCategories) do
                        playerData.xp[category] = {
                            current = SCPXP:GetPlayerXP(target, category),
                            level = SCPXP:GetPlayerLevel(target, category)
                        }
                    end
                    
                    table.insert(playerList, playerData)
                end
            end
            
            net.Start("SCPXP_AdminPanel")
            net.WriteString("player_list")
            net.WriteTable(playerList)
            net.Send(ply)
            
        elseif action == "modify_xp" then
            local targetSteamID = net.ReadString()
            local category = net.ReadString()
            local action_type = net.ReadString() -- "set" or "add"
            local amount = net.ReadInt(32)
            local reason = net.ReadString()
            
            local target = player.GetBySteamID64(targetSteamID)
            if not IsValid(target) then
                SCPXP:SendNotification(ply, "error", "Target player not found or offline")
                return
            end
            
            if not SCPXP:IsValidCategory(category) then
                SCPXP:SendNotification(ply, "error", "Invalid category")
                return
            end
            
            local success = false
            if action_type == "set" then
                success = SCPXP:SetXP(target, category, amount, ply)
            elseif action_type == "add" then
                success = SCPXP:AddXP(target, category, amount, reason, ply)
            end
            
            if success then
                SCPXP:SendNotification(ply, "success", "XP modified successfully")
            else
                SCPXP:SendNotification(ply, "error", "Failed to modify XP")
            end
        end
    end)
end

-- Chat Commands for Admins
hook.Add("PlayerSay", "SCPXP_AdminChat", function(ply, text)
    if not IsValid(ply) or not SCPXP:IsAdmin(ply) then return end
    
    local args = string.Explode(" ", text)
    local cmd = string.lower(args[1])
    
    if cmd == "!scpadmin" or cmd == "/scpadmin" then
        -- Open admin panel
        net.Start("SCPXP_AdminPanel")
        net.WriteString("open_panel")
        net.Send(ply)
        return ""
    elseif cmd == "!credits" or cmd == "/credits" then
        -- Show pending credit requests
        local pendingRequests = SCPXP:GetPendingRequestsForAdmin(ply)
        
        if #pendingRequests == 0 then
            ply:ChatPrint("[SCPXP] No pending credit requests")
        else
            ply:ChatPrint("[SCPXP] Pending Credit Requests (" .. #pendingRequests .. "):")
            for i, request in ipairs(pendingRequests) do
                ply:ChatPrint("  " .. i .. ". " .. request.requesterName .. " → " .. request.targetName .. " (" .. request.timeText .. ")")
            end
        end
        return ""
    end
end)