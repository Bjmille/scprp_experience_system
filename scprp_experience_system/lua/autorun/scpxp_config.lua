SCPXP = SCPXP or {}

-- Configuration
SCPXP.Config = {
    -- XP Requirements per level (exponential growth)
    BaseXP = 100,
    XPMultiplier = 1.4,
    MaxLevel = 100,
    
    -- Categories
    Categories = {
        research = {
            name = "Research",
            color = Color(52, 152, 219),
            icon = "icon16/book.png"
        },
        security = {
            name = "Security",
            color = Color(231, 76, 60),
            icon = "icon16/shield.png"
        },
        dclass = {
            name = "D-Class",
            color = Color(230, 126, 34),
            icon = "icon16/user_orange.png"
        },
        scp = {
            name = "SCP",
            color = Color(155, 89, 182),
            icon = "icon16/bug.png"
        }
    },
    
    -- XP Sources for each category
    XPSources = {
        research = {
            ["complete_experiment"] = 35,
            ["write_report"] = 20,
            ["discover_anomaly"] = 50,
            ["successful_interview"] = 25,
            ["use_scp_safely"] = 15,
            ["research_time"] = 2, -- per minute in research role
        },
        security = {
            ["kill_hostile"] = 25,
            ["contain_scp"] = 40,
            ["save_personnel"] = 30,
            ["patrol_duty"] = 1, -- per minute on patrol
            ["breach_response"] = 35,
            ["escort_mission"] = 20,
        },
        dclass = {
            ["survive_test"] = 30,
            ["complete_labor"] = 15,
            ["survive_breach"] = 40,
            ["escape_attempt"] = 25,
            ["cooperation_bonus"] = 10,
            ["survival_time"] = 1, -- per minute survived
        },
        scp = {
            ["kill_human"] = 20,
            ["breach_containment"] = 50,
            ["ability_usage"] = 10,
            ["cause_chaos"] = 25,
            ["avoid_recontainment"] = 30,
            ["terror_bonus"] = 15,
        }
    },
    
    -- Job Requirements (level required to unlock each job)
    JobRequirements = {
        -- Research Jobs
        ["Junior Researcher"] = {category = "research", level = 0},
        ["Researcher"] = {category = "research", level = 5},
        ["Senior Researcher"] = {category = "research", level = 15},
        ["Executive Researcher"] = {category = "research", level = 25},
        ["Biological Researcher"] = {category = "research", level = 35},
        
        -- Security Jobs
        ["GENSEC: Cadet"] = {category = "security", level = 0},
        ["GENSEC: Security Officer"] = {category = "security", level = 3},
        ["GENSEC: Sergeant"] = {category = "security", level = 8},
        ["GENSEC: Lieutenant"] = {category = "security", level = 15},
        ["GENSEC: Riot Response Team"] = {category = "security", level = 25},
        ["GENSEC: Breach Response Team"] = {category = "security", level = 25},
        ["GENSEC: Tactical Medical Team"] = {category = "security", level = 20},
        
        -- D-Class Jobs
        ["Class-D Personnel"] = {category = "dclass", level = 0},
        ["D-Class Trusted"] = {category = "dclass", level = 10},
        ["D-Class Saboteur"] = {category = "dclass", level = 20},
        ["D-Class Representative"] = {category = "dclass", level = 30},
        
        -- SCP Jobs (if you allow SCP player roles)
--        ["SCP-173"] = {category = "scp", level = 0},
 --       ["SCP-096"] = {category = "scp", level = 10},
 --       ["SCP-106"] = {category = "scp", level = 20},
   --     ["SCP-682"] = {category = "scp", level = 30},
    },
    
    -- Level Rewards for each category
    LevelRewards = {
        research = {
            [5] = {money = 500, message = "Research Grant Received!"},
            [10] = {money = 1000, message = "Equipment Access Upgraded!"},
            [20] = {money = 2000, message = "Senior Research Status!"},
            [30] = {money = 3500, message = "Research Department Recognition!"},
        },
        security = {
            [5] = {money = 750, message = "Security Clearance Upgrade!"},
            [10] = {money = 1200, message = "Tactical Equipment Unlocked!"},
            [20] = {money = 2500, message = "Command Training Complete!"},
            [30] = {money = 4000, message = "Elite Security Status!"},
        },
        dclass = {
            [5] = {money = 300, message = "Survival Bonus!"},
            [10] = {money = 600, message = "Veteran D-Class Status!"},
            [20] = {money = 1000, message = "D-Class Legend Status!"},
        },
        scp = {
            [5] = {money = 0, message = "Anomalous Powers Strengthened!"},
            [10] = {money = 0, message = "Containment Breach Mastery!"},
            [20] = {money = 0, message = "Apex Predator Status!"},
        }
    },
    
    -- UI Settings
    Colors = {
        Background = Color(44, 47, 51, 220),
        Text = Color(255, 255, 255),
        XPBar = Color(46, 204, 113),
        XPBarBG = Color(127, 140, 141),
        LevelUp = Color(241, 196, 15),
    }
}

-- Utility Functions
function SCPXP:GetXPForLevel(level)
    if level <= 1 then return 0 end
    return math.floor(self.Config.BaseXP * (self.Config.XPMultiplier ^ (level - 1)))
end

function SCPXP:GetTotalXPForLevel(level)
    local total = 0
    for i = 2, level do
        total = total + self:GetXPForLevel(i)
    end
    return total
end

function SCPXP:GetLevelFromXP(totalXP)
    local level = 1
    local xpUsed = 0
    
    while level < self.Config.MaxLevel do
        local xpNeeded = self:GetXPForLevel(level + 1)
        if xpUsed + xpNeeded > totalXP then
            break
        end
        xpUsed = xpUsed + xpNeeded
        level = level + 1
    end
    
    return level
end

function SCPXP:GetCurrentLevelProgress(totalXP)
    local level = self:GetLevelFromXP(totalXP)
    local xpForCurrentLevel = self:GetTotalXPForLevel(level)
    local xpForNextLevel = self:GetTotalXPForLevel(level + 1)
    local currentXP = totalXP - xpForCurrentLevel
    local neededXP = xpForNextLevel - xpForCurrentLevel
    
    return currentXP, neededXP
end