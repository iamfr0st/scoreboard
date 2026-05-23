-- client.lua - Toggle scoreboard with PGDN + fade (no Backspace)
local RSGCore = exports['rsg-core']:GetCoreObject()

local scoreboardVisible = false
local KEY = RSGCore.Shared.Keybinds['PGDN']
local AUTO_REFRESH_SEC = 10
local CLOCK_SAVE_SEC = 60
local CLOCK_SAMPLE_SEC = 5
local DEFAULT_MS_PER_GAME_MINUTE = 2000
local lastClockText = nil
local ClockAuthority = nil
local LastNativeSample = nil
local ObservedMsPerGameMinute = nil
local warnedMissingClockTimeNative = false
local warnedMissingClockRateNative = false
local warnedMissingClockDateNative = false
local warnedMissingPauseClockNative = false

local DayNames = {
    [0] = 'Sunday',
    [1] = 'Monday',
    [2] = 'Tuesday',
    [3] = 'Wednesday',
    [4] = 'Thursday',
    [5] = 'Friday',
    [6] = 'Saturday',
}

local MonthNames = {
    [1] = 'January',
    [2] = 'February',
    [3] = 'March',
    [4] = 'April',
    [5] = 'May',
    [6] = 'June',
    [7] = 'July',
    [8] = 'August',
    [9] = 'September',
    [10] = 'October',
    [11] = 'November',
    [12] = 'December',
}

local function setVisible(show)
    if scoreboardVisible == show then
        return
    end

    scoreboardVisible = show
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'toggle', display = show })
    if show then
        TriggerServerEvent('scoreboard:requestPlayers')
        lastClockText = nil
    end
end

local function dateTimeToMinutes(year, month, day, hour, minute)
    local a = math.floor((14 - month) / 12)
    local y = year + 4800 - a
    local m = month + 12 * a - 3
    local julianDay = day + math.floor((153 * m + 2) / 5) + 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) - 32045
    return julianDay * 1440 + hour * 60 + minute
end

local function minutesToDateTime(totalMinutes)
    local julianDay = math.floor(totalMinutes / 1440)
    local minuteOfDay = totalMinutes % 1440
    if minuteOfDay < 0 then
        minuteOfDay = minuteOfDay + 1440
        julianDay = julianDay - 1
    end

    local l = julianDay + 68569
    local n = math.floor((4 * l) / 146097)
    l = l - math.floor((146097 * n + 3) / 4)
    local i = math.floor((4000 * (l + 1)) / 1461001)
    l = l - math.floor((1461 * i) / 4) + 31
    local j = math.floor((80 * l) / 2447)
    local day = l - math.floor((2447 * j) / 80)
    l = math.floor(j / 11)
    local month = j + 2 - 12 * l
    local year = 100 * (n - 49) + i + l

    local hour = math.floor(minuteOfDay / 60)
    local minute = minuteOfDay % 60

    return {
        year = year,
        month = month,
        day = day,
        hour = hour,
        minute = minute,
        julianDay = julianDay,
    }
end

local function getNativeClockState()
    return {
        year = tonumber(GetClockYear()) or 1898,
        month = (tonumber(GetClockMonth()) or 0) + 1,
        day = tonumber(GetClockDayOfMonth()) or 1,
        hour = tonumber(GetClockHours()) or 0,
        minute = tonumber(GetClockMinutes()) or 0,
        weekday = tonumber(GetClockDayOfWeek()) or 0,
    }
end

local function getEffectiveMsPerGameMinute()
    if ClockAuthority and ClockAuthority.msPerGameMinute then
        return ClockAuthority.msPerGameMinute
    end

    if ObservedMsPerGameMinute then
        return ObservedMsPerGameMinute
    end

    return DEFAULT_MS_PER_GAME_MINUTE
end

local function getAuthoritativeClockState()
    if not ClockAuthority then
        return nil
    end

    local elapsedMs = math.max(0, GetGameTimer() - ClockAuthority.syncedAtMs)
    local elapsedMinutes = math.floor(elapsedMs / ClockAuthority.msPerGameMinute)
    local totalMinutes = ClockAuthority.baseTotalMinutes + elapsedMinutes
    local dayOffset = math.floor(elapsedMinutes / 1440)
    local state = minutesToDateTime(totalMinutes)
    state.weekday = (ClockAuthority.baseWeekday + dayOffset) % 7
    return state
end

local function getDisplayClockState()
    return getNativeClockState()
end

local function formatClockText(state)
    local hour24 = state.hour or 0
    local minute = state.minute or 0
    local ampm = 'AM'
    local hour12 = hour24

    if hour24 == 0 then
        hour12 = 12
    elseif hour24 == 12 then
        ampm = 'PM'
    elseif hour24 > 12 then
        hour12 = hour24 - 12
        ampm = 'PM'
    end

    return string.format(
        '%s %s %d, %d %d:%02d %s',
        DayNames[state.weekday] or 'Unknown',
        MonthNames[state.month] or 'Unknown',
        state.day,
        state.year,
        hour12,
        minute,
        ampm
    )
end

local function applyWorldClock(state)
    if not state then
        return
    end

    if PauseClock then
        PauseClock(true)
    elseif not warnedMissingPauseClockNative then
        warnedMissingPauseClockNative = true
        print('[scoreboard] PauseClock is unavailable; another resource or the game may continue advancing local time.')
    end

    local overrideMsPerMinute = NetworkOverrideClockMillisecondsPerGameMinute or _NetworkOverrideClockMillisecondsPerGameMinute
    if overrideMsPerMinute then
        overrideMsPerMinute(math.floor(getEffectiveMsPerGameMinute()))
    elseif not warnedMissingClockRateNative then
        warnedMissingClockRateNative = true
        print('[scoreboard] Clock-rate override native is unavailable; falling back to manual time correction.')
    end

    if SetClockDate then
        SetClockDate(state.day or 1, (state.month or 1) - 1, state.year or 1898)
    elseif not warnedMissingClockDateNative then
        warnedMissingClockDateNative = true
        print('[scoreboard] SetClockDate is unavailable; only the clock time will be corrected.')
    end

    if NetworkOverrideClockTime then
        NetworkOverrideClockTime(state.hour or 0, state.minute or 0, 0)
    elseif AdvanceClockTimeTo then
        AdvanceClockTimeTo(state.hour or 0, state.minute or 0, 0)
    elseif SetClockTime then
        SetClockTime(state.hour or 0, state.minute or 0, 0)
    elseif not warnedMissingClockTimeNative then
        warnedMissingClockTimeNative = true
        print('[scoreboard] No supported clock override native is available; scoreboard UI will continue, but world time cannot be forced.')
    end
end

local function updateNativeClockSample()
    local nowMs = GetGameTimer()
    local native = getNativeClockState()
    local nativeTotalMinutes = dateTimeToMinutes(native.year, native.month, native.day, native.hour, native.minute)

    if LastNativeSample then
        local realElapsedMs = nowMs - LastNativeSample.realMs
        local gameElapsedMinutes = nativeTotalMinutes - LastNativeSample.totalMinutes

        if realElapsedMs > 0 and gameElapsedMinutes > 0 then
            local estimate = realElapsedMs / gameElapsedMinutes
            if estimate >= 200 and estimate <= 300000 then
                if ObservedMsPerGameMinute then
                    ObservedMsPerGameMinute = math.floor((ObservedMsPerGameMinute * 3 + estimate) / 4)
                else
                    ObservedMsPerGameMinute = math.floor(estimate)
                end
            end
        end
    end

    LastNativeSample = {
        realMs = nowMs,
        totalMinutes = nativeTotalMinutes,
        weekday = native.weekday,
    }
end

local function syncAuthoritativeClock()
    local state = lib.callback.await('scoreboard:server:getClockState', false)
    if type(state) ~= 'table' then
        ClockAuthority = nil
        return
    end

    local year = tonumber(state.year)
    local month = tonumber(state.month)
    local day = tonumber(state.day)
    local hour = tonumber(state.hour)
    local minute = tonumber(state.minute)
    local weekday = tonumber(state.weekday)
    local savedAt = tonumber(state.savedAt)
    local msPerGameMinute = tonumber(state.msPerGameMinute) or getEffectiveMsPerGameMinute()

    if not year or not month or not day or not hour or not minute then
        ClockAuthority = nil
        return
    end

    if not weekday then
        weekday = getNativeClockState().weekday
    end

    local baseTotalMinutes = dateTimeToMinutes(year, month, day, hour, minute)
    local elapsedOfflineMs = 0
    if savedAt then
        elapsedOfflineMs = math.max(0, (GetCloudTimeAsInt() - savedAt) * 1000)
    end
    local advancedMinutes = math.floor(elapsedOfflineMs / msPerGameMinute)
    local remainderMs = elapsedOfflineMs % msPerGameMinute

    ClockAuthority = {
        baseTotalMinutes = baseTotalMinutes + advancedMinutes,
        baseWeekday = (weekday + math.floor(advancedMinutes / 1440)) % 7,
        msPerGameMinute = msPerGameMinute,
        syncedAtMs = GetGameTimer() - remainderMs,
    }

    applyWorldClock(getAuthoritativeClockState())
end

local function pushClockToUi(force)
    if not scoreboardVisible and not force then
        return
    end

    local text = formatClockText(getDisplayClockState())
    if not force and text == lastClockText then
        return
    end

    lastClockText = text
    SendNUIMessage({
        type = 'clock',
        text = text
    })
end

local function pushClockState()
    local state = getNativeClockState()
    TriggerServerEvent('scoreboard:saveClockState', {
        year = state.year,
        month = state.month,
        day = state.day,
        hour = state.hour,
        minute = state.minute,
        weekday = state.weekday,
        msPerGameMinute = getEffectiveMsPerGameMinute(),
    })
end

CreateThread(function()
    syncAuthoritativeClock()
    updateNativeClockSample()
    pushClockToUi(true)
end)

CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, KEY) then
            setVisible(not scoreboardVisible)
        end
    end
end)

RegisterNetEvent('scoreboard:update', function(payload)
    payload = payload or {}
    payload.type = payload.type or 'update'
    SendNUIMessage(payload)
end)

RegisterNetEvent('scoreboard:clockStateUpdated', function()
    syncAuthoritativeClock()
    pushClockToUi(true)
end)

RegisterNUICallback('hideUI', function(_, cb)
    setVisible(false)
    cb({})
end)

CreateThread(function()
    while true do
        Wait(AUTO_REFRESH_SEC * 1000)
        if scoreboardVisible then
            TriggerServerEvent('scoreboard:requestPlayers')
        end
    end
end)

CreateThread(function()
    while true do
        if ClockAuthority then
            applyWorldClock(getAuthoritativeClockState())
        end

        pushClockToUi(false)
        Wait(1000)
    end
end)

CreateThread(function()
    while true do
        Wait(CLOCK_SAMPLE_SEC * 1000)
        updateNativeClockSample()
    end
end)

CreateThread(function()
    while true do
        Wait(CLOCK_SAVE_SEC * 1000)
        pushClockState()
    end
end)

AddEventHandler('onClientResourceStop', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    if PauseClock then
        PauseClock(false)
    end

    pushClockState()
end)

RegisterNetEvent('RSGCore:Client:OnPlayerLoaded', function()
    lastClockText = nil
    syncAuthoritativeClock()
    pushClockToUi(true)
end)
