-- Server-side code for SCPXP System
-- Place this in: addons/scprp_experience_system/lua/autorun/scpxp_server.lua

if not SERVER then return end

SCPXP = SCPXP or {}

-- Add network strings for the new approval system
util.AddNetworkString("SCPXP_CreditRequest")
util.AddNetworkString("SCPXP_CreditApproval")
util.AddNetworkString("SCPXP_ShowBriefNotification")

-- Configuration: Define what ranks count as "staff"
SCPXP.StaffRanks = {
    "tmod",
    "mod", 
    "smod",
    "jadmin",
    "admin",
    "sadmin",
    "hadmin",
    "tgm",
    "gm",
    "sgm",
    "lgm",
    "superadmin",
    -- Add other staff ranks as needed
}

-- Initialize player XP data
function SCPXP:InitializePlayer(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    
    ply.SCPXPData = ply.SCPXPData or {}
    
    -- Initialize all categories
    for category, _ in pairs(self.Config.Categories) do
        ply.SCPXPData[category] = ply.SCPXPData[category] or {}
        ply.SCPXPData[category].totalXP = ply.SCPXPData[category].totalXP or 0
        ply.SCPXPData[category].level = self:GetLevelFromXP(ply.SCPXPData[category].totalXP)
    end
    
    self:SyncToClient(ply)
end

-- Give XP to player in specific category (now with logging)
function SCPXP:GiveXP(ply, category, amount, reason)
    if not IsValid(ply) or ply:IsBot() then return end
    if not self.Config.Categories[category] then return end
    if not ply.SCPXPData then self:InitializePlayer(ply) end
    
    local oldLevel = ply.SCPXPData[category].level
    ply.SCPXPData[category].totalXP = ply.SCPXPData[category].totalXP + amount
    ply.SCPXPData[category].level = self:GetLevelFromXP(ply.SCPXPData[category].totalXP)
    
    -- Log the XP gain
    self:LogXPGain(ply, category, amount, reason or "Unknown")
    
    -- Show XP gain notification
    net.Start("SCPXP_ShowGain")
        net.WriteString(category)
        net.WriteInt(amount, 32)
        net.WriteString(reason or "")
    net.Send(ply)
    
    -- Check for level up
    if ply.SCPXPData[category].level > oldLevel then
        self:HandleLevelUp(ply, category, ply.SCPXPData[category].level)
    end
    
    -- Save data
    self:SavePlayerData(ply)
    self:SyncToClient(ply)
end

-- Handle level up rewards (FIXED)
function SCPXP:HandleLevelUp(ply, category, newLevel)
    local reward = self.Config.LevelRewards[category] and self.Config.LevelRewards[category][newLevel]
    
    -- Send level up notification
    net.Start("SCPXP_LevelUp")
        net.WriteString(category)
        net.WriteInt(newLevel, 8)
        net.WriteString(reward and reward.message or "Level Up!")
    net.Send(ply)
    
    -- Give monetary reward
    if reward and reward.money and reward.money > 0 then
        ply:addMoney(reward.money)
    end
    
    -- Broadcast to server
    local categoryName = self.Config.Categories[category].name
    local msg = string.format("%s has reached %s Level %d!", ply:Nick(), categoryName, newLevel)
    
    for _, v in ipairs(player.GetAll()) do
        DarkRP.notify(v, 0, 5, msg)
    end
    
    -- Call hook for job unlock checking and other systems
    hook.Call("SCPXP_DataUpdated", nil, ply)
end

-- Check if player can access job
function SCPXP:CanAccessJob(ply, jobName)
    local requirement = self.Config.JobRequirements[jobName]
    if not requirement then return true end -- No requirement = accessible
    
    if not ply.SCPXPData then self:InitializePlayer(ply) end
    
    local playerLevel = ply.SCPXPData[requirement.category].level
    return playerLevel >= requirement.level
end

-- Get required level for job
function SCPXP:GetJobRequirement(jobName)
    return self.Config.JobRequirements[jobName]
end

-- Sync data to client
function SCPXP:SyncToClient(ply)
    net.Start("SCPXP_UpdateClient")
        net.WriteTable(ply.SCPXPData or {})
    net.Send(ply)
    
    -- Call hook for job unlock checking and other systems
    hook.Call("SCPXP_DataUpdated", nil, ply)
end

-- Database System
function SCPXP:InitializeDatabase()
    -- Player data table
    if not sql.TableExists("scpxp_players") then
        sql.Query([[
            CREATE TABLE scpxp_players (
                steamid TEXT PRIMARY KEY,
                nick TEXT,
                research_xp INTEGER DEFAULT 0,
                security_xp INTEGER DEFAULT 0,
                dclass_xp INTEGER DEFAULT 0,
                scp_xp INTEGER DEFAULT 0,
                research_level INTEGER DEFAULT 1,
                security_level INTEGER DEFAULT 1,
                dclass_level INTEGER DEFAULT 1,
                scp_level INTEGER DEFAULT 1,
                last_seen TEXT,
                total_playtime INTEGER DEFAULT 0
            )
        ]])
    end
    
    -- XP transaction log
    if not sql.TableExists("scpxp_logs") then
        sql.Query([[
            CREATE TABLE scpxp_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                steamid TEXT,
                nick TEXT,
                category TEXT,
                amount INTEGER,
                reason TEXT,
                timestamp TEXT,
                server_info TEXT
            )
        ]])
    end
    
    -- Credit approval log
    if not sql.TableExists("scpxp_credits") then
        sql.Query([[
            CREATE TABLE scpxp_credits (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                researcher_steamid TEXT,
                researcher_nick TEXT,
                target_steamid TEXT,
                target_nick TEXT,
                staff_steamid TEXT,
                staff_nick TEXT,
                status TEXT,
                timestamp TEXT,
                reason TEXT
            )
        ]])
    end
    
    print("[SCPXP] Database initialized successfully!")
end

-- Logging System
function SCPXP:LogXPGain(ply, category, amount, reason)
    if not IsValid(ply) then return end
    
    local steamid = ply:SteamID64()
    local nick = sql.SQLStr(ply:Nick())
    local timestamp = sql.SQLStr(os.date("%Y-%m-%d %H:%M:%S"))
    local server = sql.SQLStr(GetHostName() or "Unknown Server")
    
    sql.Query(string.format([[
        INSERT INTO scpxp_logs (steamid, nick, category, amount, reason, timestamp, server_info)
        VALUES ('%s', %s, '%s', %d, '%s', %s, %s)
    ]], steamid, nick, category, amount, sql.SQLStr(reason), timestamp, server))
    
    -- Console log for real-time monitoring
    print(string.format("[SCPXP LOG] %s (%s) gained %d %s XP - %s", 
        ply:Nick(), steamid, amount, category, reason))
end

-- Save player data to database
function SCPXP:SavePlayerData(ply)
    if not IsValid(ply) or not ply.SCPXPData then return end
    
    local steamid = ply:SteamID64()
    local nick = sql.SQLStr(ply:Nick())
    local timestamp = sql.SQLStr(os.date("%Y-%m-%d %H:%M:%S"))
    
    -- Calculate total playtime
    local playtime = (ply.SCPXPPlaytime or 0) + (CurTime() - (ply.SCPXPJoinTime or CurTime()))
    
    sql.Query(string.format([[
        REPLACE INTO scpxp_players (
            steamid, nick, research_xp, security_xp, dclass_xp, scp_xp,
            research_level, security_level, dclass_level, scp_level,
            last_seen, total_playtime
        ) VALUES (
            '%s', %s, %d, %d, %d, %d, %d, %d, %d, %d, %s, %d
        )
    ]], steamid, nick,
        ply.SCPXPData.research.totalXP, ply.SCPXPData.security.totalXP,
        ply.SCPXPData.dclass.totalXP, ply.SCPXPData.scp.totalXP,
        ply.SCPXPData.research.level, ply.SCPXPData.security.level,
        ply.SCPXPData.dclass.level, ply.SCPXPData.scp.level,
        timestamp, math.floor(playtime)
    ))
end

-- Load player data from database
function SCPXP:LoadPlayerData(ply)
    if not IsValid(ply) then return end
    
    local steamid = ply:SteamID64()
    local result = sql.Query("SELECT * FROM scpxp_players WHERE steamid = '" .. steamid .. "'")
    
    if result and result[1] then
        local data = result[1]
        ply.SCPXPData = {
            research = {
                totalXP = tonumber(data.research_xp) or 0,
                level = tonumber(data.research_level) or 1
            },
            security = {
                totalXP = tonumber(data.security_xp) or 0,
                level = tonumber(data.security_level) or 1
            },
            dclass = {
                totalXP = tonumber(data.dclass_xp) or 0,
                level = tonumber(data.dclass_level) or 1
            },
            scp = {
                totalXP = tonumber(data.scp_xp) or 0,
                level = tonumber(data.scp_level) or 1
            }
        }
        ply.SCPXPPlaytime = tonumber(data.total_playtime) or 0
    else
        -- New player
        ply.SCPXPPlaytime = 0
    end
    
    ply.SCPXPJoinTime = CurTime()
    self:InitializePlayer(ply)
end

-- AUTO-APPROVAL SYSTEM

-- Function to check if any staff are online
function SCPXP:IsStaffOnline()
    for _, ply in pairs(player.GetAll()) do
        if IsValid(ply) and ply:IsConnected() then
            local usergroup = ply:GetUserGroup()
            if table.HasValue(self.StaffRanks, usergroup) then
                return true
            end
        end
    end
    return false
end

-- Function to get online staff members (for notifications)
function SCPXP:GetOnlineStaff()
    local staff = {}
    for _, ply in pairs(player.GetAll()) do
        if IsValid(ply) and ply:IsConnected() then
            local usergroup = ply:GetUserGroup()
            if table.HasValue(self.StaffRanks, usergroup) then
                table.insert(staff, ply)
            end
        end
    end
    return staff
end

-- Function to award credit (implement this according to your system)
function SCPXP:AwardCredit(researcher, target, reason)
    if not IsValid(researcher) or not IsValid(target) then return end
    
    -- Give XP to researcher
    self:GiveXP(researcher, "research", 30, reason)
    
    -- Give XP to target based on their role
    local targetJob = string.lower(target:getDarkRPVar("job") or "")
    if string.find(targetJob, "d-class") then
        self:GiveXP(target, "dclass", 25, "Participated in Test")
    elseif string.find(targetJob, "scp") then
        self:GiveXP(target, "scp", 20, "Test Subject")
    elseif string.find(targetJob, "research") or string.find(targetJob, "scientist") then
        self:GiveXP(target, "research", 20, "Assisted Research")
    else
        self:GiveXP(target, "research", 15, "Test Participation")
    end
    
    -- Notify players
    researcher:ChatPrint(string.format("Successfully awarded credits to %s! Both players received XP.", target:Nick()))
    target:ChatPrint(string.format("You received XP for participating in research with %s.", researcher:Nick()))
end

-- Function to log credit actions
function SCPXP:LogCreditAction(researcher, target, reason, action, approver)
    if not IsValid(researcher) or not IsValid(target) then return end
    
    local logEntry = string.format("[%s] %s: %s → %s | Reason: %s | Approved by: %s",
                                   os.date("%Y-%m-%d %H:%M:%S"),
                                   action,
                                   researcher:GetName() .. "(" .. researcher:SteamID() .. ")",
                                   target:GetName() .. "(" .. target:SteamID() .. ")",
                                   reason,
                                   approver)
    
    print(logEntry)
    
    -- Database logging
    sql.Query(string.format([[
        INSERT INTO scpxp_credits (
            researcher_steamid, researcher_nick, target_steamid, target_nick,
            staff_steamid, staff_nick, status, timestamp, reason
        ) VALUES (
            '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s', '%s'
        )
    ]], 
        researcher:SteamID64(),
        sql.SQLStr(researcher:GetName()),
        target:SteamID64(), 
        sql.SQLStr(target:GetName()),
        approver == "SYSTEM" and "SYSTEM" or "SYSTEM",
        sql.SQLStr(approver),
        action,
        sql.SQLStr(os.date("%Y-%m-%d %H:%M:%S")),
        sql.SQLStr(reason)
    ))
end

-- Credit Approval System with Auto-Approval
SCPXP.PendingCredits = {}

-- Modified credit request function
function SCPXP:RequestCreditApproval(researcher, target)
    if not IsValid(researcher) or not IsValid(target) then return end
    
    local requestId = "credit_" .. researcher:SteamID64() .. "_" .. target:SteamID64() .. "_" .. CurTime()
    local staffOnline = self:IsStaffOnline()
    local reason = "Conducted Research Test"
    
    if not staffOnline then
        -- Auto-approve when no staff online
        print(string.format("[SCPXP] Auto-approving credit request: %s → %s (No staff online)", 
              researcher:GetName(), target:GetName()))
        
        -- Grant the credit directly
        self:AwardCredit(researcher, target, reason .. " (Auto-Approved)")
        
        -- Notify all players about the auto-approval
        net.Start("SCPXP_CreditRequest")
            net.WriteString(requestId)
            net.WriteString(researcher:GetName())
            net.WriteString(target:GetName())
            net.WriteString(researcher:SteamID())
            net.WriteString(target:SteamID())
            net.WriteBool(true) -- Auto-approved
        net.Broadcast()
        
        -- Log the auto-approval
        self:LogCreditAction(researcher, target, reason, "AUTO-APPROVED", "SYSTEM")
        
        return true
    else
        -- Send to staff for manual approval
        local onlineStaff = self:GetOnlineStaff()
        
        -- Store the pending request
        self.PendingCredits[requestId] = {
            researcher = researcher,
            target = target,
            reason = reason,
            timestamp = CurTime(),
            researcherName = researcher:GetName(),
            targetName = target:GetName()
        }
        
        -- Send notification to staff members
        net.Start("SCPXP_CreditRequest")
            net.WriteString(requestId)
            net.WriteString(researcher:GetName())
            net.WriteString(target:GetName())
            net.WriteString(researcher:SteamID())
            net.WriteString(target:SteamID())
            net.WriteBool(false) -- Manual approval needed
        net.Send(onlineStaff)
        
        -- Notify researcher and target
        researcher:ChatPrint("Credit request sent to staff for approval. Please wait...")
        target:ChatPrint("A researcher has requested to credit you with test XP. Waiting for staff approval...")
        
        -- Notify staff in chat as well (less intrusive backup)
        for _, staff in ipairs(onlineStaff) do
            staff:ChatPrint(string.format("[SCPXP] Credit request: %s → %s (Check top-right notification)", 
                researcher:GetName(), target:GetName()))
        end
        
        print(string.format("[SCPXP] Credit request sent to %d staff members: %s → %s", 
              #onlineStaff, researcher:GetName(), target:GetName()))
        
        -- Auto-timeout after 2 minutes
        timer.Simple(120, function()
            if self.PendingCredits[requestId] then
                self.PendingCredits[requestId] = nil
                if IsValid(researcher) then
                    researcher:ChatPrint("Credit request timed out.")
                end
                if IsValid(target) then
                    target:ChatPrint("Credit request timed out.")
                end
            end
        end)
        
        return true
    end
end

-- Process manual approval responses from staff
function SCPXP:ProcessCreditApproval(staffMember, requestId, approved)
    local request = self.PendingCredits[requestId]
    if not request then return end
    
    local researcher = request.researcher
    local target = request.target
    
    -- Log the approval/denial
    local status = approved and "APPROVED" or "DENIED"
    self:LogCreditAction(researcher, target, request.reason, status, staffMember:GetName())
    
    -- Send brief confirmation to staff member who made the decision
    net.Start("SCPXP_ShowBriefNotification")
        net.WriteString(string.format("Credit request %s", status))
        net.WriteColor(approved and Color(100, 255, 100) or Color(255, 100, 100))
    net.Send(staffMember)
    
    if approved then
        -- Give XP if both players are still valid
        if IsValid(researcher) and IsValid(target) then
            self:AwardCredit(researcher, target, request.reason .. " (Staff Approved)")
        end
        
        -- Notify all staff
        for _, ply in ipairs(player.GetAll()) do
            if table.HasValue(self.StaffRanks, ply:GetUserGroup()) then
                ply:ChatPrint(string.format("[SCPXP] %s APPROVED credit: %s -> %s", 
                    staffMember:GetName(), request.researcherName, request.targetName))
            end
        end
    else
        -- Denied
        if IsValid(researcher) then
            researcher:ChatPrint("Credit request DENIED by " .. staffMember:GetName() .. ".")
        end
        if IsValid(target) then
            target:ChatPrint("Credit request was denied by staff.")
        end
        
        -- Notify all staff
        for _, ply in ipairs(player.GetAll()) do
            if table.HasValue(self.StaffRanks, ply:GetUserGroup()) then
                ply:ChatPrint(string.format("[SCPXP] %s DENIED credit: %s -> %s", 
                    staffMember:GetName(), request.researcherName, request.targetName))
            end
        end
    end
    
    -- Clean up
    self.PendingCredits[requestId] = nil
end

-- Handle manual approval responses from staff
net.Receive("SCPXP_CreditApproval", function(len, ply)
    if not table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then 
        ply:ChatPrint("[SCPXP] You don't have permission to approve credits!")
        return 
    end
    
    local requestId = net.ReadString()
    local approved = net.ReadBool()
    
    SCPXP:ProcessCreditApproval(ply, requestId, approved)
end)

-- Auto-detect job category based on job name
function SCPXP:GetJobCategory(jobName)
    if not jobName then return nil end
    
    local job = string.lower(jobName)
    
    -- Research jobs
    if string.find(job, "research") or string.find(job, "scientist") or 
       string.find(job, "doctor") or string.find(job, "medic") then
        return "research"
    end
    
    -- Security jobs
    if string.find(job, "security") or string.find(job, "guard") or 
       string.find(job, "mtf") or string.find(job, "officer") or
       string.find(job, "captain") or string.find(job, "sergeant") or
       string.find(job, "cadet") then
        return "security"
    end
    
    -- D-Class jobs
    if string.find(job, "d-class") or string.find(job, "d class") or
       string.find(job, "prisoner") then
        return "dclass"
    end
    
    -- SCP jobs
    if string.find(job, "scp") then
        return "scp"
    end
    
    return nil
end

-- Initialize database on server start
hook.Add("Initialize", "SCPXP_DatabaseInit", function()
    SCPXP:InitializeDatabase()
end)

-- Timed XP System
function SCPXP:StartTimedXP(ply)
    if not IsValid(ply) or ply:IsBot() then return end
    
    local timerName = "SCPXP_TimedXP_" .. ply:SteamID64()
    
    -- Remove existing timer if it exists
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    -- Create new timer for hourly XP
    timer.Create(timerName, 3600, 0, function() -- 3600 seconds = 1 hour
        if not IsValid(ply) then
            timer.Remove(timerName)
            return
        end
        
        local currentJob = ply:getDarkRPVar("job")
        local category = SCPXP:GetJobCategory(currentJob)
        
        if category then
            SCPXP:GiveXP(ply, category, 25, "Hourly Activity Bonus")
            
            -- Send special notification for timed XP
            net.Start("SCPXP_ShowTimedXP")
                net.WriteString(category)
                net.WriteInt(25, 32)
            net.Send(ply)
        end
    end)
    
    -- Store the start time for this session
    ply.SCPXPTimerStart = CurTime()
end

-- Stop timed XP when player leaves or changes to non-qualifying job
function SCPXP:StopTimedXP(ply)
    if not IsValid(ply) then return end
    
    local timerName = "SCPXP_TimedXP_" .. ply:SteamID64()
    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end
    
    ply.SCPXPTimerStart = nil
end

-- Hooks
hook.Add("PlayerInitialSpawn", "SCPXP_PlayerJoin", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            SCPXP:LoadPlayerData(ply)
            -- Start timed XP after they spawn and potentially get a job
            timer.Simple(5, function()
                if IsValid(ply) then
                    SCPXP:StartTimedXP(ply)
                end
            end)
        end
    end)
end)

hook.Add("PlayerDisconnected", "SCPXP_PlayerLeave", function(ply)
    SCPXP:StopTimedXP(ply)
    SCPXP:SavePlayerData(ply)
end)

-- Hook for when players change jobs
hook.Add("OnPlayerChangedTeam", "SCPXP_JobChange", function(ply, before, after)
    -- Restart the timer when job changes
    SCPXP:StartTimedXP(ply)
end)

-- Alternative job change hook (some DarkRP versions use this)
hook.Add("playerBoughtCustomEntity", "SCPXP_JobChange2", function(ply, entity_table, ent, price)
    if entity_table.isJob then
        timer.Simple(0.1, function()
            if IsValid(ply) then
                SCPXP:StartTimedXP(ply)
            end
        end)
    end
end)

-- XP Event System - Specific to SCP-RP gameplay mechanics

-- Research: !credit command system (now with auto-approval when no staff online)
hook.Add("PlayerSay", "SCPXP_ResearchCredit", function(ply, text)
    local args = string.Explode(" ", text)
    local cmd = string.lower(args[1] or "")
    
    if cmd == "!credit" then
        local job = string.lower(ply:getDarkRPVar("job") or "")
        
        -- Only researchers can use !credit
        if not (string.find(job, "research") or string.find(job, "scientist") or string.find(job, "doctor")) then
            ply:ChatPrint("Only research personnel can use !credit!")
            return ""
        end
        
        if #args < 2 then
            ply:ChatPrint("Usage: !credit <player_name>")
            ply:ChatPrint("This command requests XP for conducting a test with the specified player.")
            ply:ChatPrint("If no staff are online, credits will be automatically approved.")
            return ""
        end
        
        -- Find target player
        local targetName = string.lower(args[2])
        local target = nil
        
        for _, v in ipairs(player.GetAll()) do
            if string.find(string.lower(v:Nick()), targetName) then
                target = v
                break
            end
        end
        
        if not IsValid(target) then
            ply:ChatPrint("Player '" .. args[2] .. "' not found!")
            return ""
        end
        
        -- Send approval request to staff or auto-approve
        SCPXP:RequestCreditApproval(ply, target)
        
        return ""
    end
end)

-- Combat-based XP system
hook.Add("PlayerDeath", "SCPXP_CombatSystem", function(victim, inflictor, attacker)
    if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
    if not IsValid(victim) or not victim:IsPlayer() then return end
    
    local attackerJob = string.lower(attacker:getDarkRPVar("job") or "")
    local victimJob = string.lower(victim:getDarkRPVar("job") or "")
    
    -- Security XP System
    if string.find(attackerJob, "security") or string.find(attackerJob, "guard") or 
       string.find(attackerJob, "mtf") or string.find(attackerJob, "officer") or 
       string.find(attackerJob, "captain") or string.find(attackerJob, "sergeant") then
        
        -- Security kills D-Class
        if string.find(victimJob, "d-class") then
            SCPXP:GiveXP(attacker, "security", 20, "Eliminated D-Class Threat")
        end
        
        -- Security assists in SCP kill (gets XP for any SCP death)
        if string.find(victimJob, "scp") then
            SCPXP:GiveXP(attacker, "security", 40, "Terminated SCP Entity")
            
            -- Give assist XP to other nearby security
            for _, ply in ipairs(player.GetAll()) do
                if ply ~= attacker and IsValid(ply) and ply:Alive() then
                    local plyJob = string.lower(ply:getDarkRPVar("job") or "")
                    if (string.find(plyJob, "security") or string.find(plyJob, "guard") or 
                        string.find(plyJob, "mtf")) and ply:GetPos():Distance(victim:GetPos()) <= 500 then
                        SCPXP:GiveXP(ply, "security", 15, "SCP Kill Assist")
                    end
                end
            end
        end
    end
    
    -- SCP XP System - SCPs get XP for killing any player
    if string.find(attackerJob, "scp") then
        local xpAmount = 25 -- Base XP for killing
        local reason = "Eliminated Human"
        
        -- Bonus XP based on victim type
        if string.find(victimJob, "research") or string.find(victimJob, "scientist") then
            xpAmount = 30
            reason = "Eliminated Researcher"
        elseif string.find(victimJob, "security") or string.find(victimJob, "guard") or string.find(victimJob, "mtf") then
            xpAmount = 35
            reason = "Eliminated Security Personnel"
        elseif string.find(victimJob, "d-class") then
            xpAmount = 20
            reason = "Eliminated D-Class"
        end
        
        SCPXP:GiveXP(attacker, "scp", xpAmount, reason)
    end
    
    -- D-Class XP System - D-Class gets XP for killing foundation personnel
    if string.find(attackerJob, "d-class") then
        -- Kill researchers/scientists
        if string.find(victimJob, "research") or string.find(victimJob, "scientist") or string.find(victimJob, "doctor") then
            SCPXP:GiveXP(attacker, "dclass", 25, "Eliminated Researcher")
        end
        
        -- Kill security
        if string.find(victimJob, "security") or string.find(victimJob, "guard") or 
           string.find(victimJob, "mtf") or string.find(victimJob, "officer") or string.find(victimJob, "sergeant") then
            SCPXP:GiveXP(attacker, "dclass", 30, "Eliminated Security")
        end
        
        -- Kill other foundation staff
        if string.find(victimJob, "administrator") or string.find(victimJob, "staff") or 
           string.find(victimJob, "janitor") or string.find(victimJob, "engineer") then
            SCPXP:GiveXP(attacker, "dclass", 25, "Eliminated Foundation Staff")
        end
    end
end)

-- Additional D-Class XP for escaping/surviving
hook.Add("PlayerSpawn", "SCPXP_DClassSurvival", function(ply)
    local job = string.lower(ply:getDarkRPVar("job") or "")
    if string.find(job, "d-class") then
        -- Give small survival XP on respawn (they lasted long enough to be "reassigned")
        timer.Simple(2, function()
            if IsValid(ply) and ply:Alive() then
                SCPXP:GiveXP(ply, "dclass", 8, "Survival Reassignment")
            end
        end)
    end
end)

-- Clean up old pending requests (run every 5 minutes)
timer.Create("SCPXP_CleanupRequests", 300, 0, function()
    if not SCPXP.PendingCredits then return end
    
    local currentTime = CurTime()
    for requestId, request in pairs(SCPXP.PendingCredits) do
        -- Remove requests older than 10 minutes
        if currentTime - request.timestamp > 600 then
            print(string.format("[SCPXP] Cleaning up expired request: %s", requestId))
            SCPXP.PendingCredits[requestId] = nil
        end
    end
end)

-- Helper function to find player by partial name or ID
local function FindPlayer(identifier)
    if not identifier then return nil end
    
    -- Try to find by ID first
    local id = tonumber(identifier)
    if id then
        local ply = player.GetByID(id)
        if IsValid(ply) then return ply end
    end
    
    -- Try to find by partial name
    local name = string.lower(identifier)
    for _, ply in ipairs(player.GetAll()) do
        if string.find(string.lower(ply:Nick()), name) then
            return ply
        end
    end
    
    return nil
end

-- Admin commands for database management
concommand.Add("scpxp_give", function(ply, cmd, args)
    -- Allow server console to use this command
    if IsValid(ply) and not table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then 
        ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
        return 
    end
    
    if #args < 4 then 
        local msg = "Usage: scpxp_give <player_name_or_id> <category> <amount> <reason>\nCategories: research, security, dclass, scp\nExample: scpxp_give john research 50 Admin reward"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print("[SCPXP] " .. msg)
        end
        return 
    end
    
    local target = FindPlayer(args[1])
    if not IsValid(target) then
        local msg = "Player '" .. args[1] .. "' not found!\nUse player name or ID. Online players:"
        if IsValid(ply) then
            ply:ChatPrint(msg)
            for _, p in ipairs(player.GetAll()) do
                ply:ChatPrint("  " .. p:EntIndex() .. " - " .. p:Nick())
            end
        else
            print("[SCPXP] " .. msg)
            for _, p in ipairs(player.GetAll()) do
                print("  " .. p:EntIndex() .. " - " .. p:Nick())
            end
        end
        return
    end
    
    local category = string.lower(args[2])
    if not SCPXP.Config or not SCPXP.Config.Categories or not SCPXP.Config.Categories[category] then
        local msg = "Invalid category! Valid categories: research, security, dclass, scp"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    local amount = tonumber(args[3])
    if not amount or amount == 0 then
        local msg = "Invalid amount! Must be a number (can be negative)"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    local reason = table.concat(args, " ", 4)
    local giver = IsValid(ply) and ply:Nick() or "Console"
    
    SCPXP:GiveXP(target, category, amount, giver .. ": " .. reason)
    
    local action = amount > 0 and "Gave" or "Removed"
    local msg = string.format("[SCPXP] %s %d %s XP %s %s", action, math.abs(amount), category, amount > 0 and "to" or "from", target:Nick())
    
    if IsValid(ply) then
        ply:ChatPrint(msg)
    else
        print(msg)
    end
    
    target:ChatPrint(string.format("[SCPXP] %s %s you %d %s XP - %s", giver, string.lower(action), math.abs(amount), category, reason))
end)

-- View player stats
concommand.Add("scpxp_stats", function(ply, cmd, args)
    -- Allow server console to use this command
    if IsValid(ply) and not table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then 
        ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
        return 
    end
    
    local target = ply
    if args[1] then
        target = FindPlayer(args[1])
    elseif not IsValid(ply) then
        -- Console usage without specifying player
        local msg = "Console usage requires player name/ID: scpxp_stats <player>"
        print("[SCPXP] " .. msg)
        return
    end
    
    if not IsValid(target) then
        local msg = "Player '" .. (args[1] or "self") .. "' not found!"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    if not target.SCPXPData then
        local msg = target:Nick() .. " has no XP data"
        if IsValid(ply) then
            ply:ChatPrint("[SCPXP] " .. msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    local header = "=== " .. target:Nick() .. "'s XP Stats ==="
    if IsValid(ply) then
        ply:ChatPrint(header)
    else
        print(header)
    end
    
    if SCPXP.Config and SCPXP.Config.Categories then
        for category, data in pairs(target.SCPXPData) do
            local categoryName = SCPXP.Config.Categories[category] and SCPXP.Config.Categories[category].name or category
            local msg = string.format("%s: Level %d (%d XP)", categoryName, data.level or 1, data.totalXP or 0)
            if IsValid(ply) then
                ply:ChatPrint(msg)
            else
                print(msg)
            end
        end
    else
        local msg = "SCPXP Config not loaded - showing raw data:"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
        for category, data in pairs(target.SCPXPData) do
            local msg2 = string.format("%s: Level %d (%d XP)", category, data.level or 1, data.totalXP or 0)
            if IsValid(ply) then
                ply:ChatPrint(msg2)
            else
                print(msg2)
            end
        end
    end
end)

-- View recent XP logs
concommand.Add("scpxp_logs", function(ply, cmd, args)
    -- Allow server console to use this command, otherwise require superadmin
    if IsValid(ply) and not ply:IsSuperAdmin() then 
        ply:ChatPrint("[SCPXP] You need to be a superadmin to use this command!")
        return 
    end
    
    local limit = tonumber(args[1]) or 10
    if limit > 50 then limit = 50 end -- Cap at 50 to prevent spam
    
    local result = sql.Query("SELECT * FROM scpxp_logs ORDER BY id DESC LIMIT " .. limit)
    
    if not result then
        local msg = "No XP logs found or database error"
        if IsValid(ply) then
            ply:ChatPrint("[SCPXP] " .. msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    local header = "=== Recent " .. #result .. " XP Logs ==="
    if IsValid(ply) then
        ply:ChatPrint(header)
    else
        print(header)
    end
    
    for _, log in ipairs(result) do
        local msg = string.format("[%s] %s gained %d %s XP - %s", 
            log.timestamp or "Unknown", log.nick or "Unknown", 
            tonumber(log.amount) or 0, log.category or "unknown", log.reason or "No reason")
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    end
end)

-- View credit approval logs  
concommand.Add("scpxp_creditlogs", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then 
        ply:ChatPrint("[SCPXP] You need to be a superadmin to use this command!")
        return 
    end
    
    local limit = tonumber(args[1]) or 10
    if limit > 50 then limit = 50 end -- Cap at 50 to prevent spam
    
    local result = sql.Query("SELECT * FROM scpxp_credits ORDER BY id DESC LIMIT " .. limit)
    
    if not result then
        local msg = "No credit logs found or database error"
        if IsValid(ply) then
            ply:ChatPrint("[SCPXP] " .. msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    local header = "=== Recent " .. #result .. " Credit Approvals ==="
    if IsValid(ply) then
        ply:ChatPrint(header)
    else
        print(header)
    end
    
    for _, log in ipairs(result) do
        local msg = string.format("[%s] %s -> %s | %s by %s | Reason: %s", 
            log.timestamp or "Unknown", 
            log.researcher_nick or "Unknown", 
            log.target_nick or "Unknown", 
            log.status or "Unknown", 
            log.staff_nick or "Unknown",
            log.reason or "No reason")
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print(msg)
        end
    end
end)

-- Check player's current job category
concommand.Add("scpxp_checkjob", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then 
        ply:ChatPrint("[SCPXP] You need to be a superadmin to use this command!")
        return 
    end
    
    local target = ply
    if args[1] then
        target = FindPlayer(args[1])
    elseif not IsValid(ply) then
        local msg = "Console usage requires player name/ID: scpxp_checkjob <player>"
        print("[SCPXP] " .. msg)
        return
    end
    
    if not IsValid(target) then
        local msg = "Player '" .. (args[1] or "self") .. "' not found!"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    local job = target:getDarkRPVar("job") or "Unknown"
    local category = SCPXP:GetJobCategory(job) or "None"
    local msg = string.format("%s's job: '%s' -> Category: %s", target:Nick(), job, category)
    
    if IsValid(ply) then
        ply:ChatPrint("[SCPXP] " .. msg)
    else
        print("[SCPXP] " .. msg)
    end
end)

-- Force restart timed XP for a player
concommand.Add("scpxp_restart_timer", function(ply, cmd, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then 
        ply:ChatPrint("[SCPXP] You need to be a superadmin to use this command!")
        return 
    end
    
    local target = ply
    if args[1] then
        target = FindPlayer(args[1])
    elseif not IsValid(ply) then
        local msg = "Console usage requires player name/ID: scpxp_restart_timer <player>"
        print("[SCPXP] " .. msg)
        return
    end
    
    if not IsValid(target) then
        local msg = "Player '" .. (args[1] or "self") .. "' not found!"
        if IsValid(ply) then
            ply:ChatPrint(msg)
        else
            print("[SCPXP] " .. msg)
        end
        return
    end
    
    SCPXP:StartTimedXP(target)
    local msg = string.format("Restarted timed XP for %s", target:Nick())
    if IsValid(ply) then
        ply:ChatPrint("[SCPXP] " .. msg)
    else
        print("[SCPXP] " .. msg)
    end
end)

-- Check staff online status (admin command)
concommand.Add("scpxp_check_staff", function(ply, cmd, args)
    if IsValid(ply) and not table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then 
        ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
        return 
    end
    
    local staff = SCPXP:GetOnlineStaff()
    
    if #staff == 0 then
        local msg = "No staff currently online - credits will be auto-approved"
        if IsValid(ply) then
            ply:ChatPrint("[SCPXP] " .. msg)
        else
            print("[SCPXP] " .. msg)
        end
    else
        local header = "Online staff members (" .. #staff .. "):"
        if IsValid(ply) then
            ply:ChatPrint("[SCPXP] " .. header)
        else
            print("[SCPXP] " .. header)
        end
        for _, staffMember in ipairs(staff) do
            local msg = " - " .. staffMember:GetName() .. " (" .. staffMember:GetUserGroup() .. ")"
            if IsValid(ply) then
                ply:ChatPrint(msg)
            else
                print(msg)
            end
        end
    end
end)

-- Manually approve/deny pending credits (admin command)
concommand.Add("scpxp_manual_approval", function(ply, cmd, args)
    if not table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then 
        ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
        return 
    end
    
    if #args < 2 then
        ply:ChatPrint("Usage: scpxp_manual_approval <request_number> <approve/deny>")
        ply:ChatPrint("Use 'scpxp_pending' to see pending requests")
        return
    end
    
    local requestNum = tonumber(args[1])
    local action = string.lower(args[2])
    
    if not requestNum or (action ~= "approve" and action ~= "deny") then
        ply:ChatPrint("Invalid arguments. Use 'approve' or 'deny'")
        return
    end
    
    local requests = {}
    for id, _ in pairs(SCPXP.PendingCredits) do
        table.insert(requests, id)
    end
    
    if not requests[requestNum] then
        ply:ChatPrint("Invalid request number (1-" .. #requests .. ")")
        return
    end
    
    SCPXP:ProcessCreditApproval(ply, requests[requestNum], action == "approve")
end)

-- View pending credit requests
concommand.Add("scpxp_pending", function(ply, cmd, args)
    if not table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then 
        ply:ChatPrint("[SCPXP] You don't have permission to use this command!")
        return 
    end
    
    local count = 0
    ply:ChatPrint("=== Pending Credit Requests ===")
    
    for requestId, request in pairs(SCPXP.PendingCredits) do
        count = count + 1
        local timeAgo = math.floor(CurTime() - request.timestamp)
        ply:ChatPrint(string.format("%d. %s → %s (%d seconds ago)", 
            count, request.researcherName, request.targetName, timeAgo))
    end
    
    if count == 0 then
        ply:ChatPrint("No pending requests")
    else
        ply:ChatPrint("Use 'scpxp_manual_approval <number> <approve/deny>' to process")
    end
end)

-- Menu command
concommand.Add("scpxp_menu", function(ply, cmd, args)
    net.Start("SCPXP_OpenMenu")
    net.Send(ply)
end)

-- Debug command to reload player data
concommand.Add("scpxp_reload_player", function(ply, cmd, args)
    if not ply:IsSuperAdmin() then 
        ply:ChatPrint("[SCPXP] You need to be a superadmin to use this command!")
        return 
    end
    
    local target = ply
    if args[1] then
        target = FindPlayer(args[1])
    end
    
    if not IsValid(target) then
        ply:ChatPrint("Player '" .. (args[1] or "self") .. "' not found!")
        return
    end
    
    SCPXP:LoadPlayerData(target)
    ply:ChatPrint(string.format("[SCPXP] Reloaded data for %s", target:Nick()))
end)

-- List all commands
concommand.Add("scpxp_help", function(ply, cmd, args)
    ply:ChatPrint("=== SCPXP Commands ===")
    
    if table.HasValue(SCPXP.StaffRanks, ply:GetUserGroup()) then
        ply:ChatPrint("Staff Commands:")
        ply:ChatPrint("  scpxp_give <player> <category> <amount> <reason> - Give/remove XP")
        ply:ChatPrint("  scpxp_stats [player] - View XP stats")
        ply:ChatPrint("  scpxp_check_staff - Check online staff")
        ply:ChatPrint("  scpxp_pending - View pending credit requests")
        ply:ChatPrint("  scpxp_manual_approval <num> <approve/deny> - Manually process credits")
        ply:ChatPrint("  scpxp_checkjob [player] - Check job category")
        ply:ChatPrint("  scpxp_restart_timer [player] - Restart timed XP")
    end
    
    if ply:IsSuperAdmin() then
        ply:ChatPrint("SuperAdmin Commands:")
        ply:ChatPrint("  scpxp_logs [limit] - View XP transaction logs")
        ply:ChatPrint("  scpxp_creditlogs [limit] - View credit approval logs")
        ply:ChatPrint("  scpxp_reload_player [player] - Reload player data from DB")
    end
    
    ply:ChatPrint("Player Commands:")
    ply:ChatPrint("  !credit <player> - Request research XP (researchers only)")
    ply:ChatPrint("  scpxp_menu - Open XP menu")
end)