-- scoreboard/server.lua - governors counted by presence (no duty), via governors.identifier

local RSGCore = exports['rsg-core']:GetCoreObject()

local MSG_TITLE = 'Server Status'

local GOV_TABLE   = 'governors'
local GOV_FIELD   = 'identifier'
local REFRESH_SEC = 60
local CLOCK_FILE  = 'clock_state.json'

local GOV_DEBUG = false

local MED_ALIASES = { 'medic', 'ems', 'doctor' }
local LEO_ALIASES = { 'leo', 'law', 'police', 'sheriff', 'marshal', 'ranger' }

local GovernorCache = {}
local ClockState = nil

local function lower(s)
    return type(s) == 'string' and s:lower() or ''
end

local function anyMatch(value, aliases)
    for _, a in ipairs(aliases) do
        if value:find(a, 1, true) then
            return true
        end
    end
    return false
end

local function normalizeJob(p)
    local job = (p.PlayerData and p.PlayerData.job) or {}
    local jtype = lower(job.type or '')
    local jname = lower(job.name or job.label or job.title or '')
    local onduty = (job.onduty == true) or (job.onDuty == true)
    return jtype, jname, onduty
end

local function stripPrefix(id)
    if type(id) ~= 'string' then
        return nil
    end

    id = id:lower()
    return id:gsub('^(license2?:|steam:|fivem:|discord:)', '')
end

local function variants(id)
    if type(id) ~= 'string' or id == '' then
        return {}
    end

    local raw = id:lower()
    local noPrefix = stripPrefix(raw) or raw
    if raw == noPrefix then
        return { raw }
    end

    return { raw, noPrefix }
end

local function getAllIdentifierVariants(src)
    local set = {}
    local function add(value)
        for _, variant in ipairs(variants(value)) do
            set[variant] = true
        end
    end

    if GetPlayerIdentifierByType then
        local list = {
            GetPlayerIdentifierByType(src, 'license'),
            GetPlayerIdentifierByType(src, 'license2'),
            GetPlayerIdentifierByType(src, 'steam'),
            GetPlayerIdentifierByType(src, 'fivem'),
            GetPlayerIdentifierByType(src, 'discord'),
        }

        for _, value in ipairs(list) do
            if value then
                add(value)
            end
        end
    end

    for _, id in ipairs(GetPlayerIdentifiers(src) or {}) do
        add(id)
    end

    return set
end

local function normalizeClockState(state)
    if type(state) ~= 'table' then
        return nil
    end

    local year = tonumber(state.year)
    local month = tonumber(state.month)
    local day = tonumber(state.day)
    local hour = tonumber(state.hour)
    local minute = tonumber(state.minute)
    local weekday = tonumber(state.weekday)
    local savedAt = tonumber(state.savedAt)
    local msPerGameMinute = tonumber(state.msPerGameMinute)

    if not year or not month or not day or not hour or not minute then
        return nil
    end

    if month < 1 or month > 12 then
        return nil
    end

    if day < 1 or day > 31 then
        return nil
    end

    if hour < 0 or hour > 23 then
        return nil
    end

    if minute < 0 or minute > 59 then
        return nil
    end

    if weekday and (weekday < 0 or weekday > 6) then
        weekday = nil
    end

    if msPerGameMinute and msPerGameMinute < 200 then
        msPerGameMinute = nil
    end

    return {
        year = math.floor(year),
        month = math.floor(month),
        day = math.floor(day),
        hour = math.floor(hour),
        minute = math.floor(minute),
        weekday = weekday and math.floor(weekday) or nil,
        savedAt = savedAt and math.floor(savedAt) or os.time(),
        msPerGameMinute = msPerGameMinute and math.floor(msPerGameMinute) or nil,
    }
end

local function loadClockState()
    local raw = LoadResourceFile(GetCurrentResourceName(), CLOCK_FILE)
    if not raw or raw == '' then
        return nil
    end

    local ok, decoded = pcall(json.decode, raw)
    if not ok then
        return nil
    end

    return normalizeClockState(decoded)
end

local function saveClockState(state)
    state = normalizeClockState(state)
    if not state then
        return false
    end

    state.savedAt = os.time()
    ClockState = state
    SaveResourceFile(GetCurrentResourceName(), CLOCK_FILE, json.encode(state), -1)
    return true
end

local function refreshGovernorCache(cb)
    local sql = ('SELECT `%s` FROM `%s`'):format(GOV_FIELD, GOV_TABLE)
    exports.oxmysql:execute(sql, {}, function(rows)
        local map = {}
        if rows then
            for _, row in ipairs(rows) do
                local value = row[GOV_FIELD]
                if type(value) == 'string' and value ~= '' then
                    for _, variant in ipairs(variants(value)) do
                        map[variant] = true
                    end
                end
            end
        end

        GovernorCache = map

        if GOV_DEBUG then
            local count = 0
            for _ in pairs(map) do
                count = count + 1
            end
            print(('[scoreboard] Governor cache loaded: %d entries'):format(count))
        end

        if cb then
            cb()
        end
    end)
end

CreateThread(function()
    ClockState = loadClockState()
    refreshGovernorCache()

    while true do
        Wait(REFRESH_SEC * 1000)
        refreshGovernorCache()
    end
end)

lib.callback.register('scoreboard:server:getClockState', function()
    return ClockState
end)

RegisterNetEvent('scoreboard:saveClockState', function(state)
    if saveClockState(state) then
        TriggerClientEvent('scoreboard:clockStateUpdated', -1)
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

RegisterCommand('debug_gov', function(src)
    local cacheCount = 0
    for _ in pairs(GovernorCache) do
        cacheCount = cacheCount + 1
    end

    print(('--- Governor Debug ---\nCache entries: %d'):format(cacheCount))
    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)
        local ids = getAllIdentifierVariants(targetSrc)
        local matched = false
        local collected = {}

        for idVariant in pairs(ids) do
            table.insert(collected, idVariant)
            if GovernorCache[idVariant] then
                matched = true
            end
        end

        print(('[%s] governor=%s ids={%s}'):format(
            targetSrc,
            matched and 'YES' or 'no',
            table.concat(collected, ', ')
        ))
    end
end, true)

RegisterNetEvent('scoreboard:requestPlayers', function()
    local src = source
    local player = RSGCore.Functions.GetPlayer(src)
    if not player then
        return
    end

    local totalPlayers, lawmen, medics, governors = 0, 0, 0, 0

    for _, playerId in ipairs(GetPlayers()) do
        local targetSrc = tonumber(playerId)
        local target = RSGCore.Functions.GetPlayer(targetSrc)
        if target then
            totalPlayers = totalPlayers + 1

            local ids = getAllIdentifierVariants(targetSrc)
            local matched = false
            for idVariant in pairs(ids) do
                if GovernorCache[idVariant] then
                    matched = true
                    break
                end
            end

            if matched then
                governors = governors + 1
                if GOV_DEBUG then
                    print(('[gov-match] src=%s matched a governor identifier'):format(targetSrc))
                end
            elseif GOV_DEBUG then
                local shown = {}
                for key in pairs(ids) do
                    table.insert(shown, key)
                end
                print(('[gov-miss] src=%s no match; ids=%s'):format(targetSrc, table.concat(shown, ', ')))
            end

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
        type = 'update',
        title = MSG_TITLE,
        total = totalPlayers,
        lawmen = lawmen,
        medics = medics,
        governors = governors,
    })
end)
