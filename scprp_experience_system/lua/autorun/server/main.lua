-- SCP-RP Experience System
-- Main Module
-- Author: Custom XP System for SCP-RP

SCPXP = SCPXP or {}
SCPXP.Config = {}
SCPXP.Database = {}
SCPXP.Players = {}

-- Configuration
SCPXP.Config.XPCategories = {
    ["research"] = {name = "Research", color = Color(50, 150, 200)},
    ["security"] = {name = "Security", color = Color(200, 50, 50)},
    ["prisoner"] = {name = "Prisoner", color = Color(255, 140, 0)},
    ["scp"] = {name = "SCP", color = Color(100, 50, 200)}
}

SCPXP.Config.XPPerLevel = 1000
SCPXP.Config.CreditCooldown = 600 -- 10 minutes
SCPXP.Config.ActivityInterval = 1800 -- 30 minutes
SCPXP.Config.ActivityXP = 15

-- Database Functions
if SERVER then
    -- Initialize SQLite Database
    function SCPXP.Database:Initialize()
        if not sql.TableExists("scpxp_players") then
            sql.Query([[
                CREATE TABLE scpxp_players (
                    steamid TEXT PRIMARY KEY,
                    research_xp INTEGER DEFAULT 0,
                    security_xp INTEGER DEFAULT 0,
                    prisoner_xp INTEGER DEFAULT 0,
                    scp_xp INTEGER DEFAULT 0,
                    last_activity INTEGER DEFAULT 0,
                    last_credit INTEGER DEFAULT 0
                )
            ]])
        end
        
        if not sql.TableExists("scpxp_credit_requests") then
            sql.Query([[
                CREATE TABLE scpxp_credit_requests (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    requester_steamid TEXT,
                    target_steamid TEXT,
                    timestamp INTEGER,
                    status TEXT DEFAULT 'pending',
                    admin_steamid TEXT DEFAULT ''
                )
            ]])
        end
    end
    
    -- Load Player Data
    function SCPXP.Database:LoadPlayer(ply)
        local steamid = ply:SteamID64()
        local data = sql.QueryRow("SELECT * FROM scpxp_players WHERE steamid = " .. sql.SQLStr(steamid))
        
        if not data then
            sql.Query("INSERT INTO scpxp_players (steamid) VALUES (" .. sql.SQLStr(steamid) .. ")")
            data = {
                research_xp = 0,
                security_xp = 0,
                prisoner_xp = 0,
                scp_xp = 0,
                last_activity = 0,
                last_credit = 0
            }
        end
        
        SCPXP.Players[steamid] = {
            research = tonumber(data.research_xp) or 0,
            security = tonumber(data.security_xp) or 0,
            prisoner = tonumber(data.prisoner_xp) or 0,
            scp = tonumber(data.scp_xp) or 0,
            last_activity = tonumber(data.last_activity) or 0,
            last_credit = tonumber(data.last_credit) or 0
        }
        
        return SCPXP.Players[steamid]
    end
    
    -- Save Player Data
    function SCPXP.Database:SavePlayer(ply)
        local steamid = ply:SteamID64()
        local data = SCPXP.Players[steamid]
        
        if not data then return end
        
        sql.Query(string.format([[
            UPDATE scpxp_players SET 
            research_xp = %d,
            security_xp = %d,
            prisoner_xp = %d,
            scp_xp = %d,
            last_activity = %d,
            last_credit = %d
            WHERE steamid = %s
        ]], 
            data.research,
            data.security,
            data.prisoner,
            data.scp,
            data.last_activity,
            data.last_credit,
            sql.SQLStr(steamid)
        ))
    end
end

-- XP Management Functions
function SCPXP:GetPlayerXP(ply, category)
    local steamid = ply:SteamID64()
    if not SCPXP.Players[steamid] then return 0 end
    return SCPXP.Players[steamid][category] or 0
end

function SCPXP:GetPlayerLevel(ply, category)
    local xp = self:GetPlayerXP(ply, category)
    return math.floor(xp / SCPXP.Config.XPPerLevel)
end

function SCPXP:GetXPForNextLevel(ply, category)
    local xp = self:GetPlayerXP(ply, category)
    local currentLevel = self:GetPlayerLevel(ply, category)
    local nextLevelXP = (currentLevel + 1) * SCPXP.Config.XPPerLevel
    return nextLevelXP - xp
end

if SERVER then
    -- Add XP to Player
    function SCPXP:AddXP(ply, category, amount, reason)
        if not IsValid(ply) or not SCPXP.Config.XPCategories[category] then return false end
        
        local steamid = ply:SteamID64()
        if not SCPXP.Players[steamid] then
            SCPXP.Database:LoadPlayer(ply)
        end
        
        local oldLevel = self:GetPlayerLevel(ply, category)
        SCPXP.Players[steamid][category] = SCPXP.Players[steamid][category] + amount
        local newLevel = self:GetPlayerLevel(ply, category)
        
        -- Send notification
        net.Start("SCPXP_Notification")
        net.WriteString("xp_gained")
        net.WriteString(category)
        net.WriteInt(amount, 32)
        net.WriteString(reason or "Unknown")
        net.Send(ply)
        
        -- Check for level up
        if newLevel > oldLevel then
            net.Start("SCPXP_Notification")
            net.WriteString("level_up")
            net.WriteString(category)
            net.WriteInt(newLevel, 32)
            net.Send(ply)
        end
        
        -- Save data
        SCPXP.Database:SavePlayer(ply)
        
        return true
    end
    
    -- Credit System
    function SCPXP:ProcessCreditRequest(requester, target)
        if not IsValid(requester) or not IsValid(target) then return false end
        
        local requesterSteamID = requester:SteamID64()
        local targetSteamID = target:SteamID64()
        local currentTime = os.time()
        
        -- Check if requester is researcher
        local requesterCategory = self:GetPlayerJobCategory(requester)
        if requesterCategory ~= "research" then
            self:SendNotification(requester, "error", "Only researchers can use !credit")
            return false
        end
        
        -- Check cooldown
        if SCPXP.Players[targetSteamID] and SCPXP.Players[targetSteamID].last_credit + SCPXP.Config.CreditCooldown > currentTime then
            local remaining = SCPXP.Players[targetSteamID].last_credit + SCPXP.Config.CreditCooldown - currentTime
            self:SendNotification(requester, "error", "Target is on credit cooldown (" .. math.ceil(remaining/60) .. "m remaining)")
            return false
        end
        
        -- Create credit request
        sql.Query(string.format([[
            INSERT INTO scpxp_credit_requests (requester_steamid, target_steamid, timestamp)
            VALUES (%s, %s, %d)
        ]], sql.SQLStr(requesterSteamID), sql.SQLStr(targetSteamID), currentTime))
        
        -- Notify staff
        for _, admin in ipairs(player.GetAll()) do
            if admin:IsAdmin() then
                net.Start("SCPXP_CreditRequest")
                net.WriteString(requester:Nick())
                net.WriteString(target:Nick())
                net.WriteString(requesterSteamID)
                net.WriteString(targetSteamID)
                net.WriteInt(sql.QueryValue("SELECT last_insert_rowid()"), 32)
                net.Send(admin)
            end
        end
        
        self:SendNotification(requester, "info", "Credit request sent to staff for approval")
        return true
    end
    
    -- Approve Credit Request
    function SCPXP:ApproveCreditRequest(requestID, admin)
        local request = sql.QueryRow("SELECT * FROM scpxp_credit_requests WHERE id = " .. requestID .. " AND status = 'pending'")
        if not request then return false end
        
        local requester = player.GetBySteamID64(request.requester_steamid)
        local target = player.GetBySteamID64(request.target_steamid)
        
        if IsValid(requester) and IsValid(target) then
            -- Give XP
            self:AddXP(requester, "research", 50, "Credit given")
            
            local targetCategory = self:GetPlayerJobCategory(target)
            self:AddXP(target, targetCategory, 100, "Credit received")
            
            -- Update cooldown
            SCPXP.Players[target:SteamID64()].last_credit = os.time()
            
            self:SendNotification(requester, "success", "Credit approved! +50 Research XP")
            self:SendNotification(target, "success", "Credit received! +100 " .. targetCategory:gsub("^%l", string.upper) .. " XP")
        end
        
        -- Update request status
        sql.Query(string.format([[
            UPDATE scpxp_credit_requests 
            SET status = 'approved', admin_steamid = %s 
            WHERE id = %d
        ]], sql.SQLStr(admin:SteamID64()), requestID))
        
        return true
    end
    
    -- Get Player Job Category
    function SCPXP:GetPlayerJobCategory(ply)
        if not IsValid(ply) then return "prisoner" end
        
        local job = ply:getDarkRPVar("job") or ""
        job = string.lower(job)
        
        if string.find(job, "research") or string.find(job, "scientist") then
            return "research"
        elseif string.find(job, "guard") or string.find(job, "security") or string.find(job, "mtf") then
            return "security"
        elseif string.find(job, "scp") then
            return "scp"
        else
            return "prisoner"
        end
    end
    
    -- Activity XP Timer
    function SCPXP:StartActivityTimer()
        timer.Create("SCPXP_Activity", SCPXP.Config.ActivityInterval, 0, function()
            for _, ply in ipairs(player.GetAll()) do
                if IsValid(ply) and not ply:IsBot() then
                    local category = self:GetPlayerJobCategory(ply)
                    self:AddXP(ply, category, SCPXP.Config.ActivityXP, "Activity bonus")
                end
            end
        end)
    end
    
    -- Send Notification
    function SCPXP:SendNotification(ply, type, message)
        if not IsValid(ply) then return end
        
        net.Start("SCPXP_Notification")
        net.WriteString(type)
        net.WriteString(message)
        net.Send(ply)
    end
    
    -- Admin Commands
    concommand.Add("scpxp_setxp", function(ply, cmd, args)
        if not ply:IsAdmin() then return end
        if #args < 3 then 
            ply:ChatPrint("Usage: scpxp_setxp <player> <category> <amount>")
            return 
        end
        
        local target = DarkRP.findPlayer(args[1])
        if not IsValid(target) then
            ply:ChatPrint("Player not found!")
            return
        end
        
        local category = string.lower(args[2])
        if not SCPXP.Config.XPCategories[category] then
            ply:ChatPrint("Invalid category! Use: research, security, prisoner, scp")
            return
        end
        
        local amount = tonumber(args[3])
        if not amount then
            ply:ChatPrint("Invalid amount!")
            return
        end
        
        local steamid = target:SteamID64()
        if not SCPXP.Players[steamid] then
            SCPXP.Database:LoadPlayer(target)
        end
        
        SCPXP.Players[steamid][category] = amount
        SCPXP.Database:SavePlayer(target)
        
        ply:ChatPrint("Set " .. target:Nick() .. "'s " .. category .. " XP to " .. amount)
        SCPXP:SendNotification(target, "info", "Admin set your " .. category .. " XP to " .. amount)
    end)
end

-- Job Level Requirements
if SERVER then
    -- DarkRP Job Integration
    function SCPXP:CanChangeJob(ply, job)
        local jobRequirements = {
            -- Security Jobs
            ["Security Sergeant"] = {category = "security", level = 10},
            ["Security Captain"] = {category = "security", level = 20},
            ["MTF Operative"] = {category = "security", level = 15},
            
            -- Research Jobs
            ["Senior Researcher"] = {category = "research", level = 10},
            ["Research Supervisor"] = {category = "research", level = 25},
            
            -- Add more as needed
        }
        
        local requirement = jobRequirements[job]
        if requirement then
            local playerLevel = self:GetPlayerLevel(ply, requirement.category)
            if playerLevel < requirement.level then
                self:SendNotification(ply, "error", 
                    "You need " .. requirement.category:gsub("^%l", string.upper) .. 
                    " Level " .. requirement.level .. " to access this job! (Current: " .. playerLevel .. ")")
                return false
            end
        end
        
        return true
    end
    
    -- Hook into DarkRP's job change system
    hook.Add("canChangeJob", "SCPXP_JobCheck", function(ply, job)
        return SCPXP:CanChangeJob(ply, job.name)
    end)
end

-- Network Strings
if SERVER then
    util.AddNetworkString("SCPXP_Notification")
    util.AddNetworkString("SCPXP_CreditRequest")
    util.AddNetworkString("SCPXP_RequestData")
    util.AddNetworkString("SCPXP_SendData")
end

-- Hooks
if SERVER then
    hook.Add("PlayerInitialSpawn", "SCPXP_PlayerJoin", function(ply)
        timer.Simple(1, function()
            if IsValid(ply) then
                SCPXP.Database:LoadPlayer(ply)
            end
        end)
    end)
    
    hook.Add("PlayerDisconnected", "SCPXP_PlayerLeave", function(ply)
        SCPXP.Database:SavePlayer(ply)
    end)
    
    hook.Add("Initialize", "SCPXP_Initialize", function()
        SCPXP.Database:Initialize()
        SCPXP:StartActivityTimer()
    end)
    
    -- Combat XP
    hook.Add("PlayerDeath", "SCPXP_Combat", function(victim, inflictor, attacker)
        if not IsValid(attacker) or not attacker:IsPlayer() or attacker == victim then return end
        
        local attackerCategory = SCPXP:GetPlayerJobCategory(attacker)
        local victimCategory = SCPXP:GetPlayerJobCategory(victim)
        local xpAmount = 25
        
        -- Security kills D-Class
        if attackerCategory == "security" and victimCategory == "prisoner" then
            SCPXP:AddXP(attacker, "security", xpAmount, "Eliminated D-Class")
        -- D-Class kills Foundation
        elseif attackerCategory == "prisoner" and (victimCategory == "security" or victimCategory == "research") then
            SCPXP:AddXP(attacker, "prisoner", xpAmount, "Eliminated Foundation Personnel")
        -- SCP kills anyone
        elseif attackerCategory == "scp" then
            SCPXP:AddXP(attacker, "scp", xpAmount, "Eliminated " .. victimCategory:gsub("^%l", string.upper))
        end
    end)
    
    -- Chat Commands
    hook.Add("PlayerSay", "SCPXP_Commands", function(ply, text)
        local args = string.Explode(" ", text)
        local cmd = string.lower(args[1])
        
        if cmd == "!credit" then
            if #args > 1 then
                local target = DarkRP.findPlayer(args[2])
                if IsValid(target) then
                    SCPXP:ProcessCreditRequest(ply, target)
                else
                    SCPXP:SendNotification(ply, "error", "Player not found!")
                end
            else
                SCPXP:SendNotification(ply, "error", "Usage: !credit <player>")
            end
            return ""
        elseif cmd == "!xp" or cmd == "!level" then
            net.Start("SCPXP_RequestData")
            net.Send(ply)
            return ""
        end
    end)
end