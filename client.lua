-- client.lua — Toggle scoreboard with PGDN + fade (no Backspace)
local RSGCore = exports['rsg-core']:GetCoreObject()

local scoreboardVisible = false
local KEY = RSGCore.Shared.Keybinds['PGDN']  -- make sure PGDN is defined in your core
local AUTO_REFRESH_SEC = 10

local function setVisible(show)
    if scoreboardVisible == show then return end
    scoreboardVisible = show
    SetNuiFocus(false, false) -- no cursor, no focus
    SendNUIMessage({ type = "toggle", display = show })
    if show then
        TriggerServerEvent('scoreboard:requestPlayers')
    end
end

-- Toggle on press
CreateThread(function()
    while true do
        Wait(0)
        if IsControlJustPressed(0, KEY) then
            setVisible(not scoreboardVisible)
        end
    end
end)

-- Forward server payload AS-IS
RegisterNetEvent('scoreboard:update', function(payload)
    payload = payload or {}
    payload.type = payload.type or "update"
    SendNUIMessage(payload)
end)

-- NUI callback (not used, but kept for safety if UI calls it)
RegisterNUICallback('hideUI', function(_, cb)
    setVisible(false)
    cb({})
end)

-- Optional: auto-refresh while open
CreateThread(function()
    while true do
        Wait(AUTO_REFRESH_SEC * 1000)
        if scoreboardVisible then
            TriggerServerEvent('scoreboard:requestPlayers')
        end
    end
end)

-- =========================
-- In-game date/time to NUI (Monday - May 12, 1899 - 2:30 PM)
-- =========================
CreateThread(function()
    local days = {
        [0] = 'Sunday',
        [1] = 'Monday',
        [2] = 'Tuesday',
        [3] = 'Wednesday',
        [4] = 'Thursday',
        [5] = 'Friday',
        [6] = 'Saturday',
    }

    local months = {
        [0]  = 'January',
        [1]  = 'February',
        [2]  = 'March',
        [3]  = 'April',
        [4]  = 'May',
        [5]  = 'June',
        [6]  = 'July',
        [7]  = 'August',
        [8]  = 'September',
        [9]  = 'October',
        [10] = 'November',
        [11] = 'December',
    }

    while true do
        local hour24    = GetClockHours()         -- 0–23
        local minute    = GetClockMinutes()       -- 0–59
        local year      = GetClockYear()
        local month     = GetClockMonth()         -- 0–11
        local day       = GetClockDayOfMonth()    -- 1–31
        local dow       = GetClockDayOfWeek()     -- 0–6

        local weekday   = days[dow] or 'Unknown'
        local monthName = months[month] or 'Unknown'

        -- Convert 24h → 12h + AM/PM
        local ampm = "AM"
        local hour12 = hour24

        if hour24 == 0 then
            hour12 = 12
            ampm = "AM"
        elseif hour24 == 12 then
            hour12 = 12
            ampm = "PM"
        elseif hour24 > 12 then
            hour12 = hour24 - 12
            ampm = "PM"
        end

        -- Format: Monday - May 12, 1899 - 2:30 PM
        local text = string.format(
            '%s %s %d, %d %d:%02d %s',
            weekday, monthName, day, year, hour12, minute, ampm
        )

        SendNUIMessage({
            type = 'clock',
            text = text
        })

        Wait(1000)
    end
end)

