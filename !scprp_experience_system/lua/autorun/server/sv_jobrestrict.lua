-- Server-Side Job Restrictions for SCPRP Experience System
-- Place this file in: addons/scprp_experience_system/lua/autorun/server/scpxp_job_restrictions.lua

SCPXP = SCPXP or {}

-- Network message for job denial notification
util.AddNetworkString("SCPXP_JobDenied")
util.AddNetworkString("SCPXP_CloseF4")

print("[SCPXP] Server-side job restrictions loaded")

-- Debug function to print all job requirements
concommand.Add("scpxp_debug_jobs", function(ply)
    if not IsValid(ply) or not ply:IsAdmin() then 
        if IsValid(ply) then
            ply:ChatPrint("You must be an admin to use this command")
        end
        return 
    end
    
    print("[SCPXP] === DEBUG: Job Requirements ===")
    ply:ChatPrint("[SCPXP] === DEBUG: Job Requirements ===")
    
    if SCPXP.JobLevelRequirements then
        print("Found SCPXP.JobLevelRequirements:")
        ply:ChatPrint("Found SCPXP.JobLevelRequirements:")
        for job, req in pairs(SCPXP.JobLevelRequirements) do
            local msg = string.format("  %s: category=%s, level=%d", job, req.category or "nil", req.level or 0)
            print(msg)
            ply:ChatPrint(msg)
        end
    else
        print("SCPXP.JobLevelRequirements is nil")
        ply:ChatPrint("SCPXP.JobLevelRequirements is nil")
    end
    
    if SCPXP.Config and SCPXP.Config.JobRequirements then
        print("Found SCPXP.Config.JobRequirements:")
        ply:ChatPrint("Found SCPXP.Config.JobRequirements:")
        for job, req in pairs(SCPXP.Config.JobRequirements) do
            local msg = string.format("  %s: category=%s, level=%d", job, req.category or "nil", req.level or 0)
            print(msg)
            ply:ChatPrint(msg)
        end
    else
        print("SCPXP.Config.JobRequirements is nil")
        ply:ChatPrint("SCPXP.Config.JobRequirements is nil")
    end
    
    -- Check for other possible locations
    if SCPXP.JobRequirements then
        print("Found SCPXP.JobRequirements:")
        ply:ChatPrint("Found SCPXP.JobRequirements:")
        for job, req in pairs(SCPXP.JobRequirements) do
            local msg = string.format("  %s: category=%s, level=%d", job, req.category or "nil", req.level or 0)
            print(msg)
            ply:ChatPrint(msg)
        end
    else
        print("SCPXP.JobRequirements is nil")
        ply:ChatPrint("SCPXP.JobRequirements is nil")
    end
    
    print("[SCPXP] === END DEBUG ===")
    ply:ChatPrint("[SCPXP] === END DEBUG ===")
end)

-- Debug function to check player data
concommand.Add("scpxp_debug_player", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then 
        ply:ChatPrint("You must be an admin to use this command")
        return 
    end
    
    local targetName = args[1] or ply:Name()
    local target = ply
    
    if args[1] then
        for _, p in ipairs(player.GetAll()) do
            if string.find(string.lower(p:Name()), string.lower(targetName)) then
                target = p
                break
            end
        end
    end
    
    if not IsValid(target) then
        ply:ChatPrint("Player not found: " .. targetName)
        return
    end
    
    local msg = string.format("[SCPXP] === DEBUG: Player Data for %s ===", target:Name())
    print(msg)
    ply:ChatPrint(msg)
    
    local jobMsg = "Current job: " .. (team.GetName(target:Team()) or "Unknown")
    print(jobMsg)
    ply:ChatPrint(jobMsg)
    
    if target.SCPXPData then
        print("Player XP Data:")
        ply:ChatPrint("Player XP Data:")
        for category, data in pairs(target.SCPXPData) do
            local dataMsg = string.format("  %s: level=%d, totalXP=%d", category, data.level or 1, data.totalXP or 0)
            print(dataMsg)
            ply:ChatPrint(dataMsg)
        end
    else
        print("target.SCPXPData is nil")
        ply:ChatPrint("target.SCPXPData is nil")
    end
    
    print("[SCPXP] === END DEBUG ===")
    ply:ChatPrint("[SCPXP] === END DEBUG ===")
end)

-- Debug function to list all teams
concommand.Add("scpxp_debug_teams", function(ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    
    print("[SCPXP] === DEBUG: All Teams ===")
    ply:ChatPrint("[SCPXP] === DEBUG: All Teams ===")
    
    for i = 0, team.GetCount() do
        local teamName = team.GetName(i)
        if teamName then
            local msg = string.format("Team %d: %s", i, teamName)
            print(msg)
            ply:ChatPrint(msg)
        end
    end
    
    print("[SCPXP] === END DEBUG ===")
    ply:ChatPrint("[SCPXP] === END DEBUG ===")
end)

-- Function to send job denial notification
local function SendJobDenial(ply, jobName, requirements)
    if not IsValid(ply) or not requirements then return end
    
    local playerLevel = 1
    if ply.SCPXPData and ply.SCPXPData[requirements.category] then
        playerLevel = ply.SCPXPData[requirements.category].level or 1
    end
    
    local categoryName = "Unknown Category"
    if SCPXP.Config and SCPXP.Config.Categories and SCPXP.Config.Categories[requirements.category] then
        categoryName = SCPXP.Config.Categories[requirements.category].name
    else
        categoryName = requirements.category
    end
    
    -- Debug print
    print(string.format("[SCPXP] Sending job denial to %s for %s (needs %d, has %d)", 
          ply:Name(), jobName, requirements.level, playerLevel))
    
    -- Send styled notification to client
    net.Start("SCPXP_JobDenied")
        net.WriteString(jobName)
        net.WriteString(categoryName)
        net.WriteInt(requirements.level, 8)
        net.WriteInt(playerLevel, 8)
        net.WriteInt(requirements.level - playerLevel, 8)
    net.Send(ply)
    
    -- Close F4 menu on client
    timer.Simple(0.1, function()
        if IsValid(ply) then
            net.Start("SCPXP_CloseF4")
            net.Send(ply)
        end
    end)
end

-- Function to find job requirements from any available source
local function GetJobRequirements(jobName)
    -- Try multiple possible locations for job requirements
    local sources = {
        SCPXP.JobLevelRequirements,
        SCPXP.Config and SCPXP.Config.JobRequirements,
        SCPXP.JobRequirements,
        _G.SCPXPJobRequirements -- Sometimes stored globally
    }
    
    for _, source in ipairs(sources) do
        if source and source[jobName] then
            print(string.format("[SCPXP] Found requirements for %s: category=%s, level=%d", 
                  jobName, source[jobName].category, source[jobName].level))
            return source[jobName]
        end
    end
    
    -- Try case-insensitive search
    for _, source in ipairs(sources) do
        if source then
            for job, req in pairs(source) do
                if string.lower(job) == string.lower(jobName) then
                    print(string.format("[SCPXP] Found requirements for %s (case mismatch): category=%s, level=%d", 
                          jobName, req.category, req.level))
                    return req
                end
            end
        end
    end
    
    print(string.format("[SCPXP] No requirements found for job: %s", jobName))
    return nil
end

-- Enhanced canChangeJob hook with better debugging
hook.Add("canChangeJob", "SCPXP_JobRestrictions", function(ply, job)
    if not IsValid(ply) or not job then return end
    
    print(string.format("[SCPXP] canChangeJob hook triggered: %s trying to change to %s", ply:Name(), job.name))
    
    local jobName = job.name
    local requirements = GetJobRequirements(jobName)
    
    if not requirements then 
        return -- No restrictions for this job
    end
    
    -- Get player level from their data
    local playerLevel = 1
    if ply.SCPXPData and ply.SCPXPData[requirements.category] then
        playerLevel = ply.SCPXPData[requirements.category].level or 1
    end
    
    print(string.format("[SCPXP] Job %s requires %s level %d, player has level %d", 
          jobName, requirements.category, requirements.level, playerLevel))
    
    if playerLevel < requirements.level then
        -- Player doesn't meet requirements
        print(string.format("[SCPXP] BLOCKING job change for %s", ply:Name()))
        SendJobDenial(ply, jobName, requirements)
        return false -- Prevent job change
    end
    
    print(string.format("[SCPXP] ALLOWING job change for %s", ply:Name()))
end)

-- Hook into DarkRP's team selection with debugging
hook.Add("PlayerCanJoinTeam", "SCPXP_TeamJoinRestriction", function(ply, teamIndex)
    if not IsValid(ply) then return end
    
    -- Get job from team index
    local jobName = team.GetName(teamIndex)
    if not jobName then return end
    
    print(string.format("[SCPXP] PlayerCanJoinTeam hook triggered: %s trying to join team %d (%s)", ply:Name(), teamIndex, jobName))
    
    -- Check requirements
    local requirements = GetJobRequirements(jobName)
    
    if not requirements then return end
    
    -- Get player level
    local playerLevel = 1
    if ply.SCPXPData and ply.SCPXPData[requirements.category] then
        playerLevel = ply.SCPXPData[requirements.category].level or 1
    end
    
    print(string.format("[SCPXP] Job %s requires %s level %d, player has level %d", 
          jobName, requirements.category, requirements.level, playerLevel))
    
    if playerLevel < requirements.level then
        print(string.format("[SCPXP] BLOCKING team join for %s", ply:Name()))
        SendJobDenial(ply, jobName, requirements)
        return false
    end
    
    print(string.format("[SCPXP] ALLOWING team join for %s", ply:Name()))
end)

-- Additional hook for team changes
hook.Add("PlayerRequestedTeam", "SCPXP_TeamRequestRestriction", function(ply, teamIndex)
    if not IsValid(ply) then return end
    
    local jobName = team.GetName(teamIndex)
    if not jobName then return end
    
    print(string.format("[SCPXP] PlayerRequestedTeam hook triggered: %s requested team %d (%s)", ply:Name(), teamIndex, jobName))
    
    local requirements = GetJobRequirements(jobName)
    if not requirements then return end
    
    local playerLevel = 1
    if ply.SCPXPData and ply.SCPXPData[requirements.category] then
        playerLevel = ply.SCPXPData[requirements.category].level or 1
    end
    
    if playerLevel < requirements.level then
        print(string.format("[SCPXP] BLOCKING team request for %s", ply:Name()))
        SendJobDenial(ply, jobName, requirements)
        return false
    end
    
    print(string.format("[SCPXP] ALLOWING team request for %s", ply:Name()))
end)

-- Console command for admins to test job restrictions
concommand.Add("scpxp_test_job_restrict", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then 
        if IsValid(ply) then
            ply:ChatPrint("You must be an admin to use this command")
        end
        return 
    end
    
    if #args < 2 then
        ply:ChatPrint("Usage: scpxp_test_job_restrict <player_name> <job_name>")
        return
    end
    
    local targetName = args[1]
    local jobName = table.concat(args, " ", 2)
    
    local target = nil
    for _, p in ipairs(player.GetAll()) do
        if string.find(string.lower(p:Name()), string.lower(targetName)) then
            target = p
            break
        end
    end
    
    if not IsValid(target) then
        ply:ChatPrint("Player not found: " .. targetName)
        return
    end
    
    local requirements = GetJobRequirements(jobName)
    
    if not requirements then
        ply:ChatPrint("No restrictions found for job: " .. jobName)
        return
    end
    
    local playerLevel = 1
    if target.SCPXPData and target.SCPXPData[requirements.category] then
        playerLevel = target.SCPXPData[requirements.category].level or 1
    end
    
    if playerLevel < requirements.level then
        SendJobDenial(target, jobName, requirements)
        ply:ChatPrint(string.format("Sent job denial notification to %s for %s", target:Name(), jobName))
    else
        ply:ChatPrint(string.format("%s meets the requirements for %s (Level %d)", target:Name(), jobName, playerLevel))
    end
end)

-- Console command to test notifications directly
concommand.Add("scpxp_test_notification", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    
    -- Send a test notification
    net.Start("SCPXP_JobDenied")
        net.WriteString("Test Job")
        net.WriteString("Test Category")
        net.WriteInt(5, 8)
        net.WriteInt(1, 8)
        net.WriteInt(4, 8)
    net.Send(ply)
    
    ply:ChatPrint("Test notification sent!")
end)

-- Console command to force reload job requirements
concommand.Add("scpxp_reload_requirements", function(ply, cmd, args)
    if not IsValid(ply) or not ply:IsAdmin() then return end
    
    -- Try to reload the main SCPXP config
    if file.Exists("scprp_experience_system/lua/scpxp/config.lua", "LUA") then
        include("scprp_experience_system/lua/scpxp/config.lua")
        ply:ChatPrint("Attempted to reload SCPXP config")
    else
        ply:ChatPrint("Could not find SCPXP config file")
    end
end)

-- Hook to validate players on spawn
hook.Add("PlayerSpawn", "SCPXP_ValidateJobOnSpawn", function(ply)
    if not IsValid(ply) then return end
    
    timer.Simple(1, function() -- Small delay to ensure data is loaded
        if not IsValid(ply) then return end
        
        local currentJob = team.GetName(ply:Team())
        if not currentJob then return end
        
        local requirements = GetJobRequirements(currentJob)
        if not requirements then return end
        
        local playerLevel = 1
        if ply.SCPXPData and ply.SCPXPData[requirements.category] then
            playerLevel = ply.SCPXPData[requirements.category].level or 1
        end
        
        if playerLevel < requirements.level then
            -- Move them to citizen
            ply:changeTeam(TEAM_CITIZEN or 1, true, true)
            
            local categoryName = "Unknown"
            if SCPXP.Config and SCPXP.Config.Categories and SCPXP.Config.Categories[requirements.category] then
                categoryName = SCPXP.Config.Categories[requirements.category].name
            end
            
            DarkRP.notify(ply, 1, 8, string.format(
                "You were moved from %s due to insufficient XP. Need %s Level %d (You have Level %d)", 
                currentJob, categoryName, requirements.level, playerLevel
            ))
        end
    end)
end)