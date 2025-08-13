-- F4 Menu Integration for SCPRP Experience System
-- Place this file in: addons/scprp_experience_system/lua/autorun/client/scpxp_f4_integration.lua

-- CLIENT-SIDE CODE
if CLIENT then
    -- Network message receivers
    net.Receive("SCPXP_JobDenied", function()
        local jobName = net.ReadString()
        local categoryName = net.ReadString()
        local requiredLevel = net.ReadInt(8)
        local currentLevel = net.ReadInt(8)
        local levelsNeeded = net.ReadInt(8)
        
        -- Create a styled notification
        local notificationText = string.format(
            "Access Denied: %s requires %s Level %d\nYou are Level %d (%d levels needed)",
            jobName, categoryName, requiredLevel, currentLevel, levelsNeeded
        )
        
        -- Use DarkRP notification system if available
        if DarkRP and DarkRP.notify then
            DarkRP.notify(LocalPlayer(), 1, 6, notificationText)
        else
            -- Fallback to chat notification
            chat.AddText(Color(255, 100, 100), "[XP System] ", Color(255, 255, 255), notificationText)
        end
        
        -- Also print to console for debugging
        print("[SCPXP] Job access denied: " .. notificationText)
    end)
    
    -- Handle F4 menu closing
    net.Receive("SCPXP_CloseF4", function()
        -- Try multiple methods to close F4 menu
        if onyx and onyx.f4 and onyx.f4.CloseFrame then
            onyx.f4.CloseFrame()
        elseif gui.GetWorldPanel then
            -- Find and close any F4 menu frames
            for _, child in ipairs(gui.GetWorldPanel():GetChildren()) do
                if IsValid(child) and (child.ClassName == "DFrame" or string.find(child.ClassName or "", "f4", 1, true)) then
                    if child:IsVisible() then
                        child:Close()
                    end
                end
            end
        end
        
        print("[SCPXP] F4 menu closed due to job restriction")
    end)
end

if not CLIENT then return end

-- Wait for both SCPXP and F4 systems to load
hook.Add("InitPostEntity", "SCPXP_F4Integration", function()
    timer.Simple(2, function() -- Small delay to ensure everything is loaded
        if not onyx or not onyx.f4 or not SCPXP then 
            print("[SCPXP] F4 Menu integration failed - missing dependencies")
            return 
        end
        
        -- Register the XP tab in the F4 menu
        onyx.f4:RegisterTab('scpxp', {
            order = 4,
            name = 'XP System',
            desc = 'View your experience and levels',
            icon = 'https://i.imgur.com/9z8XE5L.png', -- You can replace this with your own icon
            class = 'onyx.f4.SCPXP'
        })
        
        print("[SCPXP] Successfully integrated with F4 Menu!")
    end)
end)

-- Create the SCPXP F4 Panel class
local PANEL = {}

function PANEL:Init()
    self:SetBackgroundColor(Color(44, 47, 51, 220))
    self:DockPadding(20, 20, 20, 20) -- Increased padding for better fill
    
    -- Title
    local title = self:Add("DLabel")
    title:Dock(TOP)
    title:DockMargin(0, 0, 0, 20) -- Increased margin
    title:SetTall(40) -- Increased height
    title:SetText("SCP-RP Experience System")
    title:SetFont("DermaLarge") -- Larger font
    title:SetTextColor(Color(255, 255, 255))
    title:SetContentAlignment(5)
    
    -- Create category panels
    self:CreateCategoryPanels()
    
    -- Add spacer to fill remaining space
    self.spacer = self:Add("DPanel")
    self.spacer:Dock(FILL)
    self.spacer.Paint = function() end
    
    -- Initial data refresh
    self:RefreshData()
    
    -- Refresh data more frequently
    self.refreshTimer = timer.Create("SCPXP_F4Refresh_" .. tostring(self), 1, 0, function()
        if IsValid(self) then
            self:RefreshData()
        else
            timer.Remove("SCPXP_F4Refresh_" .. tostring(self))
        end
    end)
end

function PANEL:CreateCategoryPanels()
    if not SCPXP or not SCPXP.Config or not SCPXP.Config.Categories then return end
    
    self.categoryPanels = {}
    
    for categoryId, categoryData in pairs(SCPXP.Config.Categories) do
        -- Category container - increased height for better fill
        local container = self:Add("DPanel")
        container:Dock(TOP)
        container:DockMargin(0, 0, 0, 15) -- Increased margin
        container:SetTall(130) -- Increased from 100 to 130
        
        container.Paint = function(self, w, h)
            draw.RoundedBox(8, 0, 0, w, h, Color(35, 35, 40, 200))
            draw.RoundedBox(8, 0, 0, 4, h, categoryData.color or Color(100, 149, 237))
        end
        
        -- Category header with better margins
        local header = container:Add("DPanel")
        header:Dock(TOP)
        header:DockMargin(18, 12, 18, 8) -- Increased margins
        header:SetTall(32) -- Increased height
        header.Paint = function() end
        
        -- Category name 
        local nameLabel = header:Add("DLabel")
        nameLabel:Dock(LEFT)
        nameLabel:SetWide(140) -- Increased width
        nameLabel:SetText(categoryData.name)
        nameLabel:SetFont("DermaDefaultBold") -- Bold font back
        nameLabel:SetTextColor(categoryData.color or Color(255, 255, 255))
        nameLabel:SetContentAlignment(4)
        
        -- Level and XP info (right aligned)
        local infoLabel = header:Add("DLabel")
        infoLabel:Dock(FILL)
        infoLabel:SetFont("DermaDefault")
        infoLabel:SetTextColor(Color(200, 200, 200))
        infoLabel:SetContentAlignment(6)
        
        -- Progress bar container with better spacing
        local progressContainer = container:Add("DPanel")
        progressContainer:Dock(TOP)
        progressContainer:DockMargin(18, 0, 18, 8) -- Increased margins
        progressContainer:SetTall(28) -- Increased height
        progressContainer.Paint = function() end
        
        -- Progress bar background
        local progressBG = progressContainer:Add("DPanel")
        progressBG:Dock(TOP)
        progressBG:SetTall(20) -- Increased height
        progressBG.Paint = function(self, w, h)
            draw.RoundedBox(6, 0, 0, w, h, Color(60, 60, 60))
        end
        
        -- Progress bar fill
        local progressBar = progressBG:Add("DPanel")
        progressBar:Dock(LEFT)
        progressBar:SetWide(0)
        progressBar.Paint = function(self, w, h)
            if w > 0 then
                draw.RoundedBox(6, 0, 0, w, h, categoryData.color or Color(100, 149, 237))
            end
        end
        
        -- Progress text overlay
        local progressText = progressContainer:Add("DLabel")
        progressText:Dock(TOP)
        progressText:DockMargin(0, -20, 0, 0) -- Overlay on the progress bar
        progressText:SetTall(20)
        progressText:SetFont("DermaDefault")
        progressText:SetTextColor(Color(255, 255, 255))
        progressText:SetContentAlignment(5)
        
        -- Job requirements section with better margins
        local jobSection = container:Add("DPanel")
        jobSection:Dock(FILL)
        jobSection:DockMargin(18, 5, 18, 12) -- Increased margins
        jobSection.Paint = function() end
        
        local jobLabel = jobSection:Add("DLabel")
        jobLabel:Dock(FILL)
        jobLabel:SetFont("DermaDefault")
        jobLabel:SetTextColor(Color(180, 180, 180))
        jobLabel:SetContentAlignment(4)
        jobLabel:SetWrap(true)
        
        -- Store references
        self.categoryPanels[categoryId] = {
            container = container,
            infoLabel = infoLabel,
            progressBar = progressBar,
            progressBG = progressBG,
            progressText = progressText,
            jobLabel = jobLabel
        }
    end
end

function PANEL:RefreshData()
    if not SCPXP or not LocalPlayer() or not IsValid(LocalPlayer()) then return end
    
    -- Get current player data
    local playerData = SCPXP.PlayerData or {}
    
    -- Update category panels
    for categoryId, panel in pairs(self.categoryPanels or {}) do
        if IsValid(panel.container) then
            local categoryData = SCPXP.Config.Categories[categoryId]
            local data = playerData[categoryId] or {totalXP = 0, level = 1}
            
            -- Update info label
            local level = data.level or 1
            local totalXP = data.totalXP or 0
            panel.infoLabel:SetText(string.format("Level %d (%s XP)", level, string.Comma(totalXP)))
            
            -- Update progress bar
            local currentLevelXP = SCPXP:GetTotalXPForLevel(level)
            local nextLevelXP = SCPXP:GetTotalXPForLevel(level + 1)
            local progress = 0
            local xpInLevel = 0
            local xpNeeded = 0
            
            if nextLevelXP > currentLevelXP then
                xpInLevel = totalXP - currentLevelXP
                xpNeeded = nextLevelXP - currentLevelXP
                progress = math.Clamp(xpInLevel / xpNeeded, 0, 1)
            else
                progress = 1 -- Max level
                xpInLevel = totalXP - currentLevelXP
                xpNeeded = 0
            end
            
            local progressWidth = panel.progressBG:GetWide() * progress
            panel.progressBar:SetWide(progressWidth)
            
            if xpNeeded > 0 then
                panel.progressText:SetText(string.format("%s / %s XP (%.1f%%)", 
                    string.Comma(xpInLevel), string.Comma(xpNeeded), progress * 100))
            else
                panel.progressText:SetText("MAX LEVEL")
            end
            
            -- Update job requirements
            local unlockedJobs = {}
            local nextJob = nil
            local nextJobLevel = math.huge
            
            for jobName, requirement in pairs(SCPXP.Config.JobRequirements or {}) do
                if requirement.category == categoryId then
                    if level >= requirement.level then
                        table.insert(unlockedJobs, jobName)
                    elseif requirement.level < nextJobLevel then
                        nextJob = jobName
                        nextJobLevel = requirement.level
                    end
                end
            end
            
            local jobText = ""
            if #unlockedJobs > 0 then
                jobText = string.format("Unlocked: %d jobs", #unlockedJobs)
            end
            if nextJob then
                if jobText ~= "" then jobText = jobText .. " | " end
                jobText = jobText .. string.format("Next: %s (Level %d)", nextJob, nextJobLevel)
            end
            if jobText == "" then
                jobText = "No job requirements for this category"
            end
            
            panel.jobLabel:SetText(jobText)
        end
    end
end

function PANEL:Paint(w, h)
    -- Background is handled by parent class
end

function PANEL:OnRemove()
    -- Clean up timer
    timer.Remove("SCPXP_F4Refresh_" .. tostring(self))
end

function PANEL:Think()
    -- Refresh data more frequently during think (every frame when menu is visible)
    if not self.lastThink or CurTime() - self.lastThink > 0.1 then -- Update every 0.1 seconds when visible
        self.lastThink = CurTime()
        self:RefreshData()
    end
end

-- Add immediate refresh when menu becomes visible
function PANEL:OnCursorEntered()
    self:RefreshData()
end

function PANEL:SetVisible(visible)
    if visible then
        -- Immediately refresh when becoming visible
        self:RefreshData()
    end
    DPanel.SetVisible(self, visible)
end

-- Register the panel class
vgui.Register("onyx.f4.SCPXP", PANEL, "DPanel")

-- Hook to refresh when XP data is updated
hook.Add("SCPXP_DataUpdated", "SCPXP_F4Refresh", function(data)
    -- Find any open SCPXP F4 panels and refresh them
    for _, child in ipairs(vgui.GetWorldPanel():GetChildren()) do
        if IsValid(child) and child.ClassName == "onyx.f4.SCPXP" then
            child:RefreshData()
        end
    end
end)

-- Function to check if player can access a job
function SCPXP:CanPlayerAccessJob(jobName)
    local requirement = self.Config.JobRequirements[jobName]
    if not requirement then return true end -- No requirement = accessible
    
    if not self.PlayerData then return false end
    
    local categoryData = self.PlayerData[requirement.category]
    if not categoryData then return false end
    
    return (categoryData.level or 1) >= requirement.level
end

-- Hook to modify F4 menu job display
hook.Add("F4MenuPreDrawJob", "SCPXP_F4JobDisplay", function(job, panel)
    if not SCPXP or not SCPXP.Config then return end
    
    local jobName = job.name
    local requirement = SCPXP.Config.JobRequirements and SCPXP.Config.JobRequirements[jobName]
    
    if requirement then
        local canAccess = SCPXP:CanPlayerAccessJob(jobName)
        local categoryName = SCPXP.Config.Categories[requirement.category].name
        local playerLevel = 0
        
        if SCPXP.PlayerData and SCPXP.PlayerData[requirement.category] then
            playerLevel = SCPXP.PlayerData[requirement.category].level or 1
        end
        
        -- Modify job label to show requirement
        local originalText = job.name
        local levelText = string.format(" [%s L%d]", categoryName:sub(1,3):upper(), requirement.level)
        
        if not canAccess then
            -- Red text for inaccessible jobs
            job.name = originalText .. levelText .. " (Need L" .. requirement.level .. ")"
            if panel then
                panel:SetTextColor(Color(255, 100, 100)) -- Red
            end
        else
            -- Green text for accessible jobs
            job.name = originalText .. levelText
            if panel then
                panel:SetTextColor(Color(100, 255, 100)) -- Green
            end
        end
    end
end)

-- Console command to test the F4 integration
concommand.Add("scpxp_test_f4", function()
    if onyx and onyx.f4 and onyx.f4.OpenFrame then
        onyx.f4.OpenFrame()
        print("[SCPXP] F4 menu opened for testing")
    else
        print("[SCPXP] F4 system not available")
    end
end)

-- SERVER SIDE CODE (only runs on server)
if SERVER then
    SCPXP = SCPXP or {}

    -- Network message for job denial notification
    util.AddNetworkString("SCPXP_JobDenied")
    util.AddNetworkString("SCPXP_CloseF4")

    -- Debug function to print all job requirements
    concommand.Add("scpxp_debug_jobs", function(ply)
        if not IsValid(ply) or not ply:IsAdmin() then return end
        
        print("[SCPXP] === DEBUG: Job Requirements ===")
        
        if SCPXP.JobLevelRequirements then
            print("Found SCPXP.JobLevelRequirements:")
            for job, req in pairs(SCPXP.JobLevelRequirements) do
                print(string.format("  %s: category=%s, level=%d", job, req.category or "nil", req.level or 0))
            end
        else
            print("SCPXP.JobLevelRequirements is nil")
        end
        
        if SCPXP.Config and SCPXP.Config.JobRequirements then
            print("Found SCPXP.Config.JobRequirements:")
            for job, req in pairs(SCPXP.Config.JobRequirements) do
                print(string.format("  %s: category=%s, level=%d", job, req.category or "nil", req.level or 0))
            end
        else
            print("SCPXP.Config.JobRequirements is nil")
        end
        
        print("[SCPXP] === END DEBUG ===")
    end)

    -- Debug function to check player data
    concommand.Add("scpxp_debug_player", function(ply, cmd, args)
        if not IsValid(ply) or not ply:IsAdmin() then return end
        
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
        
        print(string.format("[SCPXP] === DEBUG: Player Data for %s ===", target:Name()))
        print("Current job:", team.GetName(target:Team()))
        
        if target.SCPXPData then
            print("Player XP Data:")
            for category, data in pairs(target.SCPXPData) do
                print(string.format("  %s: level=%d, totalXP=%d", category, data.level or 1, data.totalXP or 0))
            end
        else
            print("target.SCPXPData is nil")
        end
        
        print("[SCPXP] === END DEBUG ===")
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
        
        print(string.format("[SCPXP] No requirements found for job: %s", jobName))
        return nil
    end

    -- Enhanced canChangeJob hook with better debugging
    hook.Add("canChangeJob", "SCPXP_F4JobRestrictions", function(ply, job)
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
            SendJobDenial(ply, jobName, requirements)
            return false -- Prevent job change
        end
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
            SendJobDenial(ply, jobName, requirements)
            return false
        end
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
            SendJobDenial(ply, jobName, requirements)
            return false
        end
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
        
        local requirements = nil
        if SCPXP.JobLevelRequirements and SCPXP.JobLevelRequirements[jobName] then
            requirements = SCPXP.JobLevelRequirements[jobName]
        elseif SCPXP.Config and SCPXP.Config.JobRequirements and SCPXP.Config.JobRequirements[jobName] then
            requirements = SCPXP.Config.JobRequirements[jobName]
        end
        
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
end