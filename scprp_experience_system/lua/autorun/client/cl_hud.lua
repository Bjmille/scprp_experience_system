-- SCP-RP Experience System - HUD Display
-- File: scprp_experience_system/lua/autorun/client/cl_hud.lua

-- HUD Configuration
SCPXP.Config.ShowHUD = true
SCPXP.Config.HUDPosition = {x = 20, y = ScrH() - 150}
SCPXP.Config.CompactHUD = false

-- Draw XP HUD
function SCPXP:DrawXPHUD()
    if not SCPXP.Config.ShowHUD then return end
    if not LocalPlayer():Alive() then return end
    
    local ply = LocalPlayer()
    local currentCategory = self:GetPlayerJobCategory(ply)
    
    if SCPXP.Config.CompactHUD then
        self:DrawCompactHUD(currentCategory)
    else
        self:DrawFullHUD()
    end
end

-- Draw Full HUD
function SCPXP:DrawFullHUD()
    local x, y = SCPXP.Config.HUDPosition.x, SCPXP.Config.HUDPosition.y
    local panelW, panelH = 280, 120
    
    -- Background
    draw.RoundedBox(8, x, y, panelW, panelH, Color(20, 20, 20, 200))
    draw.RoundedBox(8, x + 2, y + 2, panelW - 4, panelH - 4, Color(30, 30, 30, 150))
    
    -- Header
    draw.RoundedBox(6, x + 4, y + 4, panelW - 8, 20, Color(50, 50, 50, 200))
    draw.SimpleText("Experience Progress", "DermaDefaultBold", x + 8, y + 14, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
    
    local startY = y + 28
    local categoryHeight = 20
    local barHeight = 4
    
    for i, categoryData in ipairs(self:GetSortedCategories()) do
        local category = categoryData.category
        local config = categoryData.config
        
        local catY = startY + (i - 1) * categoryHeight
        
        local xp = SCPXP:GetClientXP(category)
        local level = SCPXP:GetClientLevel(category)
        local progress = SCPXP:GetClientLevelProgress(category)
        
        -- Category name and level
        draw.SimpleText(config.displayName, "DermaDefault", x + 8, catY, config.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText("Lv." .. level, "DermaDefault", x + 100, catY, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
        draw.SimpleText(SCPXP:FormatXP(xp), "DermaDefault", x + panelW - 8, catY, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
        
        -- Progress bar
        local barY = catY + 12
        local barW = panelW - 16
        
        draw.RoundedBox(2, x + 8, barY, barW, barHeight, Color(0, 0, 0, 150))
        if progress > 0 then
            draw.RoundedBox(2, x + 8, barY, barW * progress, barHeight, config.color)
        end
    end
end

-- Draw Compact HUD (shows only current job category)
function SCPXP:DrawCompactHUD(currentCategory)
    local x, y = SCPXP.Config.HUDPosition.x, SCPXP.Config.HUDPosition.y + 80
    local panelW, panelH = 200, 50
    
    if not SCPXP:IsValidCategory(currentCategory) then return end
    
    local config = SCPXP.Config.XPCategories[currentCategory]
    local xp = SCPXP:GetClientXP(currentCategory)
    local level = SCPXP:GetClientLevel(currentCategory)
    local progress = SCPXP:GetClientLevelProgress(currentCategory)
    
    -- Background
    draw.RoundedBox(6, x, y, panelW, panelH, Color(20, 20, 20, 200))
    draw.RoundedBox(6, x + 1, y + 1, panelW - 2, panelH - 2, Color(30, 30, 30, 150))
    
    -- Category info
    draw.SimpleText(config.displayName .. " - Level " .. level, "DermaDefaultBold", x + 8, y + 8, config.color, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    draw.SimpleText(SCPXP:FormatXP(xp) .. " XP", "DermaDefault", x + panelW - 8, y + 8, Color(200, 200, 200), TEXT_ALIGN_RIGHT, TEXT_ALIGN_TOP)
    
    -- Progress bar
    local barW, barH = panelW - 16, 6
    local barX, barY = x + 8, y + panelH - barH - 8
    
    draw.RoundedBox(3, barX, barY, barW, barH, Color(0, 0, 0, 150))
    if progress > 0 then
        draw.RoundedBox(3, barX, barY, barW * progress, barH, config.color)
    end
    
    -- Progress text
    local progressText = math.Round(progress * 100, 1) .. "%"
    draw.SimpleText(progressText, "DermaDefault", x + panelW/2, y + 28, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end

-- Get sorted categories for display
function SCPXP:GetSortedCategories()
    local categories = {}
    
    for category, config in pairs(SCPXP.Config.XPCategories) do
        table.insert(categories, {
            category = category,
            config = config,
            xp = SCPXP:GetClientXP(category)
        })
    end
    
    -- Sort by XP (highest first)
    table.sort(categories, function(a, b) return a.xp > b.xp end)
    
    return categories
end

-- XP Gain Animation
SCPXP.XPAnimations = {}

function SCPXP:AddXPGainAnimation(category, amount)
    local config = SCPXP.Config.XPCategories[category]
    if not config then return end
    
    local animation = {
        category = category,
        amount = amount,
        color = config.color,
        startTime = CurTime(),
        duration = 3,
        alpha = 255,
        yOffset = 0
    }
    
    table.insert(SCPXP.XPAnimations, animation)
    
    -- Limit animations
    while #SCPXP.XPAnimations > 5 do
        table.remove(SCPXP.XPAnimations, 1)
    end
end

function SCPXP:DrawXPAnimations()
    if #SCPXP.XPAnimations == 0 then return end
    
    local baseX = SCPXP.Config.HUDPosition.x + 300
    local baseY = SCPXP.Config.HUDPosition.y
    
    for i = #SCPXP.XPAnimations, 1, -1 do
        local anim = SCPXP.XPAnimations[i]
        local elapsed = CurTime() - anim.startTime
        local progress = elapsed / anim.duration
        
        -- Remove expired animations
        if progress >= 1 then
            table.remove(SCPXP.XPAnimations, i)
            continue
        end
        
        -- Calculate position and alpha
        anim.yOffset = -progress * 60 -- Move up
        anim.alpha = 255 * (1 - progress) -- Fade out
        
        local x = baseX
        local y = baseY + anim.yOffset + (i - 1) * 25
        
        -- Draw XP gain text
        local text = "+" .. anim.amount .. " XP"
        draw.SimpleTextOutlined(text, "DermaDefaultBold", x, y, 
            Color(anim.color.r, anim.color.g, anim.color.b, anim.alpha), 
            TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP,
            1, Color(0, 0, 0, anim.alpha))
    end
end

-- Level Up Effect
SCPXP.LevelUpEffects = {}

function SCPXP:AddLevelUpEffect(category, level)
    local config = SCPXP.Config.XPCategories[category]
    if not config then return end
    
    local effect = {
        category = category,
        level = level,
        color = config.color,
        displayName = config.displayName,
        startTime = CurTime(),
        duration = 4,
        scale = 1,
        alpha = 255
    }
    
    table.insert(SCPXP.LevelUpEffects, effect)
    
    -- Play sound effect
    LocalPlayer():EmitSound("buttons/lightswitch2.wav", 75, 150, 0.5)
end

function SCPXP:DrawLevelUpEffects()
    if #SCPXP.LevelUpEffects == 0 then return end
    
    local scrW, scrH = ScrW(), ScrH()
    local centerX, centerY = scrW / 2, scrH / 2 - 100
    
    for i = #SCPXP.LevelUpEffects, 1, -1 do
        local effect = SCPXP.LevelUpEffects[i]
        local elapsed = CurTime() - effect.startTime
        local progress = elapsed / effect.duration
        
        -- Remove expired effects
        if progress >= 1 then
            table.remove(SCPXP.LevelUpEffects, i)
            continue
        end
        
        -- Animation phases
        if progress < 0.3 then
            -- Scale up
            effect.scale = Lerp(progress / 0.3, 0.5, 1.2)
            effect.alpha = 255
        elseif progress < 0.7 then
            -- Hold
            effect.scale = Lerp((progress - 0.3) / 0.4, 1.2, 1)
            effect.alpha = 255
        else
            -- Fade out
            effect.scale = 1
            effect.alpha = 255 * (1 - ((progress - 0.7) / 0.3))
        end
        
        -- Draw effect
        local oldScale = draw.GetFontScale and draw.GetFontScale() or 1
        
        -- Title
        draw.SimpleTextOutlined("LEVEL UP!", "DermaLarge", centerX, centerY, 
            Color(255, 255, 100, effect.alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            2, Color(0, 0, 0, effect.alpha))
        
        -- Category and level
        local categoryText = effect.displayName .. " Level " .. effect.level
        draw.SimpleTextOutlined(categoryText, "DermaDefaultBold", centerX, centerY + 30, 
            Color(effect.color.r, effect.color.g, effect.color.b, effect.alpha), 
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
            1, Color(0, 0, 0, effect.alpha))
        
        -- Decorative stars
        for j = 1, 5 do
            local angle = (j * 72 + elapsed * 50) * math.pi / 180
            local radius = 80 * effect.scale
            local starX = centerX + math.cos(angle) * radius
            local starY = centerY + math.sin(angle) * radius
            
            draw.SimpleTextOutlined("★", "DermaLarge", starX, starY, 
                Color(255, 215, 0, effect.alpha * 0.7), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER,
                1, Color(0, 0, 0, effect.alpha * 0.7))
        end
    end
end

-- HUD Toggle Commands
concommand.Add("scpxp_hud_compact", function()
    SCPXP.Config.CompactHUD = not SCPXP.Config.CompactHUD
    chat.AddText(Color(100, 200, 100), "[SCPXP] ", Color(255, 255, 255), 
        "HUD mode: " .. (SCPXP.Config.CompactHUD and "Compact" or "Full"))
end)

concommand.Add("scpxp_hud_position", function(ply, cmd, args)
    if #args >= 2 then
        local x = tonumber(args[1]) or SCPXP.Config.HUDPosition.x
        local y = tonumber(args[2]) or SCPXP.Config.HUDPosition.y
        
        x = math.Clamp(x, 0, ScrW() - 300)
        y = math.Clamp(y, 0, ScrH() - 150)
        
        SCPXP.Config.HUDPosition = {x = x, y = y}
        chat.AddText(Color(100, 200, 100), "[SCPXP] ", Color(255, 255, 255), 
            "HUD position set to " .. x .. ", " .. y)
    else
        chat.AddText(Color(200, 100, 100), "[SCPXP] ", Color(255, 255, 255), 
            "Usage: scpxp_hud_position <x> <y>")
    end
end)

-- Network receivers for animations
net.Receive("SCPXP_Notification", function()
    local type = net.ReadString()
    local data = net.ReadTable()
    
    if type == "xp_gained" then
        SCPXP:AddXPGainAnimation(data.category, data.amount)
    elseif type == "level_up" then
        SCPXP:AddLevelUpEffect(data.category, data.level)
    end
end)

-- HUD Drawing Hooks
hook.Add("HUDPaint", "SCPXP_DrawHUD", function()
    if not SCPXP.Config.ShowHUD then return end
    
    SCPXP:DrawXPHUD()
    SCPXP:DrawXPAnimations()
    SCPXP:DrawLevelUpEffects()
end)

-- Hide HUD in certain situations
hook.Add("HUDShouldDraw", "SCPXP_HideHUD", function(name)
    -- Hide HUD when taking screenshots or in certain gamemode states
    if name == "CHudHealth" and GetConVar("screenshot_mode") and GetConVar("screenshot_mode"):GetBool() then
        SCPXP.Config.ShowHUD = false
        timer.Simple(1, function()
            SCPXP.Config.ShowHUD = true
        end)
    end
end)