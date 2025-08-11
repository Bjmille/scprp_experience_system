-- F4 Menu Integration for SCPRP Experience System
-- Place this file in: addons/scprp_experience_system/lua/autorun/client/scpxp_f4_integration.lua

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
            
            for jobName, requirement in pairs(SCPXP.Config.JobRequirements) do
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

-- Console command to test the F4 integration
concommand.Add("scpxp_test_f4", function()
    if onyx and onyx.f4 and onyx.f4.OpenFrame then
        onyx.f4.OpenFrame()
        print("[SCPXP] F4 menu opened for testing")
    else
        print("[SCPXP] F4 system not available")
    end
end)
