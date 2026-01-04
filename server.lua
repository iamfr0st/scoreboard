-- scoreboard/server.lua — governors counted by presence (no duty), via governors.identifier

local RSGCore = exports['rsg-core']:GetCoreObject()

-- UI text (hardcoded EN). Replace with locales if you want.
local MSG_TITLE = 'Server Status'

-- DB config
local GOV_TABLE   = 'governors'    -- table name
local GOV_FIELD   = 'identifier'   -- column with any identifier (license:, steam:, etc.)
local REFRESH_SEC = 60             -- refresh cache every N seconds

-- Debug (set to false after verifying)
local GOV_DEBUG = false

-- Job alias helpers (for law/medic duty counting)
local MED_ALIASES = { 'medic', 'ems', 'doctor' }
local LEO_ALIASES = { 'leo', 'law', 'police', 'sheriff', 'marshal', 'ranger' }

local function lower(s) return type(s) == 'string' and s:lower() or '' end
local function anyMatch(value, aliases)
    for _, a in ipairs(aliases) do
        if value:find(a, 1, true) then return true end
    end
    return false
end

local function normalizeJob(p)
    local job = (p.PlayerData and p.PlayerData.job) or {}
    local jtype  = lower(job.type or '')
    local jname  = lower(job.name or job.label or job.title or '')
    local onduty = (job.onduty == true) or (job.onDuty == true)
    return jtype, jname, onduty
end

-- Identifier normalization (robust)
local function stripPrefix(id)
    if type(id) ~= 'string' then return nil end
    id = id:lower()
    return id:gsub('^(license2?:|steam:|fivem:|discord:)', '')
end

local function variants(id)
    if type(id) ~= 'string' or id == '' then return {} end
    local raw = id:lower()
    local noP = stripPrefix(raw) or raw
    if raw == noP then return { raw } else return { raw, noP } end
end

local function getAllIdentifierVariants(src)
    local set = {}
    local function add(s)
        for _, v in ipairs(variants(s)) do set[v] = true end
    end

    if GetPlayerIdentifierByType then
        local list = {
            GetPlayerIdentifierByType(src, 'license'),
            GetPlayerIdentifierByType(src, 'license2'),
            GetPlayerIdentifierByType(src, 'steam'),
            GetPlayerIdentifierByType(src, 'fivem'),
            GetPlayerIdentifierByType(src, 'discord'),
        }
        for _, v in ipairs(list) do if v then add(v) end end
    end

    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        add(id)
    end

    return set
end

-- Governor cache (identifier -> true), stores both raw and stripped forms (lowercased)
local GovernorCache = {}

local function refreshGovernorCache(cb)
    local sql = ('SELECT `%s` FROM `%s`'):format(GOV_FIELD, GOV_TABLE)
    exports.oxmysql:execute(sql, {}, function(rows)
        local map = {}
        if rows then
            for _, r in ipairs(rows) do
                local val = r[GOV_FIELD]
                if type(val) == 'string' and val ~= '' then
                    for _, v in ipairs(variants(val)) do
                        map[v] = true
                    end
                end
            end
        end
        GovernorCache = map

        if GOV_DEBUG then
            local c=0; for _ in pairs(map) do c=c+1 end
            print(("[scoreboard] Governor cache loaded: %d entries"):format(c))
        end

        if cb then cb() end
    end)
end

CreateThread(function()
    refreshGovernorCache()
    while true do
        Wait(REFRESH_SEC * 1000)
        refreshGovernorCache()
    end
end)

RegisterCommand('refresh_gov_cache', function(src)
    refreshGovernorCache(function()
        print('[scoreboard] Governor cache refreshed.')
        if src and src > 0 then
            TriggerClientEvent('chat:addMessage', src, { args = { '^2Scoreboard', 'Governor cache refreshed.' } })
        end
    end)
end, true)

-- Optional debug command: prints each player's identifiers and whether they match the cache
RegisterCommand('debug_gov', function(src)
    local cacheCount=0; for _ in pairs(GovernorCache) do cacheCount=cacheCount+1 end
    print(('--- Governor Debug ---\nCache entries: %d'):format(cacheCount))
    for _, playerId in ipairs(GetPlayers()) do
        local tSrc = tonumber(playerId)
        local ids = getAllIdentifierVariants(tSrc)
        local matched = false
        local collected = {}
        for idVariant,_ in pairs(ids) do
            table.insert(collected, idVariant)
            if GovernorCache[idVariant] then matched = true end
        end
        print(('[%s] governor=%s ids={%s}'):format(
            tSrc, matched and 'YES' or 'no', table.concat(collected, ', ')
        ))
    end
end, true)

-- Main handler: send counters only
RegisterNetEvent('scoreboard:requestPlayers', function()
    local src = source
    local Player = RSGCore.Functions.GetPlayer(src)
    if not Player then return end

    local totalPlayers, lawmen, medics, governors = 0, 0, 0, 0

    for _, playerId in ipairs(GetPlayers()) do
        local tSrc = tonumber(playerId)
        local target = RSGCore.Functions.GetPlayer(tSrc)
        if target then
            totalPlayers = totalPlayers + 1

            -- Governors: count if online (ignore duty completely)
            do
                local ids = getAllIdentifierVariants(tSrc)
                local matched = false
                for idVariant, _ in pairs(ids) do
                    if GovernorCache[idVariant] then
                        matched = true
                        break
                    end
                end
                if matched then
                    governors = governors + 1
                    if GOV_DEBUG then print(("[gov-match] src=%s matched a governor identifier"):format(tSrc)) end
                elseif GOV_DEBUG then
                    local shown = {}
                    for k,_ in pairs(ids) do table.insert(shown, k) end
                    print(("[gov-miss] src=%s no match; ids=%s"):format(tSrc, table.concat(shown, ", ")))
                end
            end

            -- Lawmen / Medics: still require onduty
            local jtype, jname, onduty = normalizeJob(target)
            if onduty then
                if jtype == 'leo' or (jtype == '' and anyMatch(jname, LEO_ALIASES)) then
                    lawmen = lawmen + 1
                elseif jtype == 'medic' or (jtype == '' and anyMatch(jname, MED_ALIASES)) then
                    medics = medics + 1
                end
            end
        end
    end

    TriggerClientEvent('scoreboard:update', src, {
        type      = 'update',
        title     = MSG_TITLE,
        total     = totalPlayers,
        lawmen    = lawmen,
        medics    = medics,
        governors = governors
    })
end)
