-- SCP-RP Experience System - Database Management
-- File: scprp_experience_system/lua/autorun/server/sv_database.lua

SCPXP.Database = SCPXP.Database or {}

-- Initialize SQLite Database
function SCPXP.Database:Initialize()
    -- Create players table
    if not sql.TableExists("scpxp_players") then
        local query = [[
            CREATE TABLE scpxp_players (
                steamid TEXT PRIMARY KEY,
                research_xp INTEGER DEFAULT 0,
                security_xp INTEGER DEFAULT 0,
                prisoner_xp INTEGER DEFAULT 0,
                scp_xp INTEGER DEFAULT 0,
                last_activity INTEGER DEFAULT 0,
                last_credit INTEGER DEFAULT 0,
                created_at INTEGER DEFAULT 0,
                updated_at INTEGER DEFAULT 0
            )
        ]]
        
        local result = sql.Query(query)
        if result == false then
            error("[SCPXP] Failed to create scpxp_players table: " .. sql.LastError())
        else
            print("[SCPXP] Created scpxp_players table")
        end
    end
    
    -- Create credit requests table
    if not sql.TableExists("scpxp_credit_requests") then
        local query = [[
            CREATE TABLE scpxp_credit_requests (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                requester_steamid TEXT NOT NULL,
                target_steamid TEXT NOT NULL,
                requester_name TEXT DEFAULT '',
                target_name TEXT DEFAULT '',
                timestamp INTEGER NOT NULL,
                status TEXT DEFAULT 'pending',
                admin_steamid TEXT DEFAULT '',
                admin_name TEXT DEFAULT '',
                processed_at INTEGER DEFAULT 0
            )
        ]]
        
        local result = sql.Query(query)
        if result == false then
            error("[SCPXP] Failed to create scpxp_credit_requests table: " .. sql.LastError())
        else
            print("[SCPXP] Created scpxp_credit_requests table")
        end
    end
    
    -- Create xp_logs table for tracking
    if not sql.TableExists("scpxp_logs") then
        local query = [[
            CREATE TABLE scpxp_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                steamid TEXT NOT NULL,
                category TEXT NOT NULL,
                xp_change INTEGER NOT NULL,
                reason TEXT DEFAULT '',
                timestamp INTEGER NOT NULL,
                admin_steamid TEXT DEFAULT ''
            )
        ]]
        
        local result = sql.Query(query)
        if result == false then
            error("[SCPXP] Failed to create scpxp_logs table: " .. sql.LastError())
        else
            print("[SCPXP] Created scpxp_logs table")
        end
    end
    
    -- Clean up old credit requests
    self:CleanupOldRequests()
end

-- Load Player Data
function SCPXP.Database:LoadPlayer(ply)
    if not IsValid(ply) then return nil end
    
    local steamid = ply:SteamID64()
    local data = sql.QueryRow("SELECT * FROM scpxp_players WHERE steamid = " .. sql.SQLStr(steamid))
    
    if not data then
        -- Create new player entry
        local currentTime = os.time()
        local insertQuery = string.format([[
            INSERT INTO scpxp_players 
            (steamid, research_xp, security_xp, prisoner_xp, scp_xp, last_activity, last_credit, created_at, updated_at) 
            VALUES (%s, 0, 0, 0, 0, %d, 0, %d, %d)
        ]], sql.SQLStr(steamid), currentTime, currentTime, currentTime)
        
        sql.Query(insertQuery)
        
        data = {
            research_xp = 0,
            security_xp = 0,
            prisoner_xp = 0,
            scp_xp = 0,
            last_activity = currentTime,
            last_credit = 0
        }
    end
    
    -- Store in memory
    SCPXP.Players[steamid] = {
        research = tonumber(data.research_xp) or 0,
        security = tonumber(data.security_xp) or 0,
        prisoner = tonumber(data.prisoner_xp) or 0,
        scp = tonumber(data.scp_xp) or 0,
        last_activity = tonumber(data.last_activity) or 0,
        last_credit = tonumber(data.last_credit) or 0
    }
    
    SCPXP:Debug("Loaded data for " .. ply:Nick() .. " (" .. steamid .. ")")
    return SCPXP.Players[steamid]
end

-- Save Player Data
function SCPXP.Database:SavePlayer(ply)
    if not IsValid(ply) then return false end
    
    local steamid = ply:SteamID64()
    local data = SCPXP.Players[steamid]
    
    if not data then return false end
    
    local currentTime = os.time()
    local updateQuery = string.format([[
        UPDATE scpxp_players SET 
        research_xp = %d,
        security_xp = %d,
        prisoner_xp = %d,
        scp_xp = %d,
        last_activity = %d,
        last_credit = %d,
        updated_at = %d
        WHERE steamid = %s
    ]], 
        data.research or 0,
        data.security or 0,
        data.prisoner or 0,
        data.scp or 0,
        data.last_activity or 0,
        data.last_credit or 0,
        currentTime,
        sql.SQLStr(steamid)
    )
    
    local result = sql.Query(updateQuery)
    if result == false then
        SCPXP:Debug("Failed to save data for " .. ply:Nick() .. ": " .. sql.LastError())
        return false
    end
    
    return true
end

-- Credit Request Functions
function SCPXP.Database:CreateCreditRequest(requester, target)
    if not IsValid(requester) or not IsValid(target) then return false end
    
    local currentTime = os.time()
    local insertQuery = string.format([[
        INSERT INTO scpxp_credit_requests 
        (requester_steamid, target_steamid, requester_name, target_name, timestamp)
        VALUES (%s, %s, %s, %s, %d)
    ]], 
        sql.SQLStr(requester:SteamID64()),
        sql.SQLStr(target:SteamID64()),
        sql.SQLStr(requester:Nick()),
        sql.SQLStr(target:Nick()),
        currentTime
    )
    
    local result = sql.Query(insertQuery)
    if result == false then
        SCPXP:Debug("Failed to create credit request: " .. sql.LastError())
        return false
    end
    
    return sql.QueryValue("SELECT last_insert_rowid()")
end

function SCPXP.Database:GetPendingCreditRequests()
    local query = "SELECT * FROM scpxp_credit_requests WHERE status = 'pending' ORDER BY timestamp ASC"
    return sql.Query(query) or {}
end

function SCPXP.Database:UpdateCreditRequestStatus(requestID, status, admin)
    if not requestID or not status then return false end
    
    local adminSteamID = ""
    local adminName = ""
    
    if IsValid(admin) then
        adminSteamID = admin:SteamID64()
        adminName = admin:Nick()
    end
    
    local updateQuery = string.format([[
        UPDATE scpxp_credit_requests SET 
        status = %s,
        admin_steamid = %s,
        admin_name = %s,
        processed_at = %d
        WHERE id = %d
    ]], 
        sql.SQLStr(status),
        sql.SQLStr(adminSteamID),
        sql.SQLStr(adminName),
        os.time(),
        tonumber(requestID)
    )
    
    local result = sql.Query(updateQuery)
    return result ~= false
end

-- XP Logging
function SCPXP.Database:LogXPChange(ply, category, amount, reason, admin)
    if not IsValid(ply) then return false end
    
    local adminSteamID = ""
    if IsValid(admin) then
        adminSteamID = admin:SteamID64()
    end
    
    local insertQuery = string.format([[
        INSERT INTO scpxp_logs 
        (steamid, category, xp_change, reason, timestamp, admin_steamid)
        VALUES (%s, %s, %d, %s, %d, %s)
    ]], 
        sql.SQLStr(ply:SteamID64()),
        sql.SQLStr(category),
        tonumber(amount) or 0,
        sql.SQLStr(reason or ""),
        os.time(),
        sql.SQLStr(adminSteamID)
    )
    
    sql.Query(insertQuery)
end

-- Cleanup Functions
function SCPXP.Database:CleanupOldRequests()
    local cutoffTime = os.time() - (24 * 60 * 60) -- 24 hours ago
    local query = string.format([[
        DELETE FROM scpxp_credit_requests 
        WHERE timestamp < %d AND status != 'pending'
    ]], cutoffTime)
    
    sql.Query(query)
    SCPXP:Debug("Cleaned up old credit requests")
end

function SCPXP.Database:CleanupOldLogs()
    local cutoffTime = os.time() - (7 * 24 * 60 * 60) -- 7 days ago
    local query = string.format([[
        DELETE FROM scpxp_logs WHERE timestamp < %d
    ]], cutoffTime)
    
    sql.Query(query)
    SCPXP:Debug("Cleaned up old XP logs")
end

-- Get Player Statistics
function SCPXP.Database:GetPlayerStats(steamid)
    local query = string.format([[
        SELECT * FROM scpxp_players WHERE steamid = %s
    ]], sql.SQLStr(steamid))
    
    return sql.QueryRow(query)
end

function SCPXP.Database:GetTopPlayers(category, limit)
    limit = limit or 10
    local column = category .. "_xp"
    
    local query = string.format([[
        SELECT steamid, %s as xp FROM scpxp_players 
        WHERE %s > 0 
        ORDER BY %s DESC 
        LIMIT %d
    ]], column, column, column, limit)
    
    return sql.Query(query) or {}
end

-- Backup and restore functions
function SCPXP.Database:BackupData()
    local backupFile = "scpxp_backup_" .. os.date("%Y%m%d_%H%M%S") .. ".txt"
    local data = {
        players = sql.Query("SELECT * FROM scpxp_players") or {},
        requests = sql.Query("SELECT * FROM scpxp_credit_requests") or {},
        timestamp = os.time()
    }
    
    file.Write(backupFile, util.TableToJSON(data, true))
    print("[SCPXP] Backup created: " .. backupFile)
    return backupFile
end