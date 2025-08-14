-- SCP-RP Experience System Configuration
-- File: scprp_experience_system/lua/autorun/config/sh_config.lua

SCPXP = SCPXP or {}
SCPXP.Config = {}

-- XP Categories and Colors
SCPXP.Config.XPCategories = {
    ["research"] = {
        name = "Research", 
        color = Color(50, 150, 200),
        displayName = "Research"
    },
    ["security"] = {
        name = "Security", 
        color = Color(200, 50, 50),
        displayName = "Security"
    },
    ["prisoner"] = {
        name = "Prisoner", 
        color = Color(255, 140, 0),
        displayName = "D-Class"
    },
    ["scp"] = {
        name = "SCP", 
        color = Color(100, 50, 200),
        displayName = "SCP"
    }
}

-- XP Configuration
SCPXP.Config.BaseXP = 100                   -- Base XP needed for level 1
SCPXP.Config.XPMultiplier = 1.009            -- Exponential multiplier per level
SCPXP.Config.CreditCooldown = 600           -- 10 minutes in seconds
SCPXP.Config.ActivityInterval = 1800        -- 30 minutes in seconds
SCPXP.Config.ActivityXP = 15                -- XP gained from activity bonus
SCPXP.Config.CreditResearcherXP = 50        -- XP researcher gets from !credit
SCPXP.Config.CreditTargetXP = 100           -- XP target gets from !credit

-- Combat XP Values
SCPXP.Config.CombatXP = {
    kill = 25,          -- Base XP for killing
    assist = 10,        -- XP for assists
    breach = 50,        -- XP for SCP breach
    recontain = 75      -- XP for SCP recontainment
}

-- Job Level Requirements
SCPXP.Config.JobRequirements = {
    -- Security Jobs
    ["GENSEC : Cadet"] = {category = "security", level = 0},
    ["GENSEC : Security Officer"] = {category = "security", level = 0},
    ["GENSEC : Sergeant"] = {category = "security", level = 10},
    ["GENSEC : Lieutenant"] = {category = "security", level = 25},
    ["GENSEC : Riot Response Team"] = {category = "security", level = 15},
    ["GENSEC : Breach Response Team"] = {category = "security", level = 20},
    ["GENSEC : Tactical Medical Team"] = {category = "security", level = 15},
    ["Security Coordinator"] = {category = "security", level = 25},
    
    -- Research Jobs
    ["Junior Researcher"] = {category = "research", level = 0},
    ["Researcher"] = {category = "research", level = 0}
    ["Senior Researcher"] = {category = "research", level = 10},
    ["Executive Researcher"] = {category = "research", level = 25},
    ["Biological Researcher"] = {category = "research", level = 15},
    ["Research Coordinator"] = {category = "research", level = 25},
    
    
    -- D-Class Jobs (if any specialized ones exist)
	["Class-D Personnel"] = {category = "prisoner", level = 0},
    ["D-Class Trusted"] = {category = "prisoner", level = 10},
    ["D-Class Saboteur"] = {category = "prisoner", level = 15},
    ["D-Class Representative"] = {category = "prisoner", level = 20},
    
    -- SCP Jobs (if level-based SCPs exist)
    
    
    -- Add custom SCP jobs here if needed
}

-- Job Category Detection
SCPXP.Config.JobCategories = {
    -- Research keywords
    research = {
        "Junior", "Senior", "Executive", "Researcher", "Research", "Biological", 
    },
    
    -- Security keywords  
    security = {
        "GENSEC", "Security", "Officer", "Sergeant", "Lieutenant", "Breach Response Team", 
        "Riot Response Team", "Tactical Medical Team", "Cadet",
    },
    
    -- SCP keywords
    --scp = {
    --    "scp", "scp-", "anomaly", "entity"
   -- },
    
    -- D-Class keywords (default fallback)
    prisoner = {
        "Class-D", "Trusted", "Saboteur", "Representative",
    }
}

-- Notification Settings
SCPXP.Config.Notifications = {
    duration = 5,           -- Default notification duration
    maxNotifications = 5,   -- Maximum notifications shown at once
    fadeTime = 0.5,        -- Fade in/out time
    position = {           -- Notification position
        x = 20,            -- Pixels from right edge
        y = 20             -- Pixels from top
    }
}

-- Database Settings
SCPXP.Config.Database = {
    autoSaveInterval = 60,     -- Auto-save every 5 minutes
    maxCreditRequests = 10      -- Maximum pending credit requests
}

-- Admin Permissions
SCPXP.Config.AdminGroups = {
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
    "lgm"
}

-- UI Settings
SCPXP.Config.UI = {
    panelWidth = 600,
    panelHeight = 400,
    backgroundColor = Color(40, 40, 40, 250),
    headerColor = Color(60, 60, 60, 255),
    progressBarHeight = 12
}