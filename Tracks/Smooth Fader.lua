--[[
 * ReaScript Name: Smooth Fader - Плавное подведение громкости трека после изменения
 * Version: 1.0.0
 * Author: Karamush
 * Author URI: https://karamush.ru
 * Repository: GitHub > Karamush > REAPER-ReaScripts
 * Repository URI: https://github.com/karamush/REAPER-ReaScripts
 * Licence: GPL v3
 * About:
   Скрипт плавно подводит громкость трека к новому значению после изменения, если пользователь не продолжает крутить ручку. Иначе скрипт не вмешивается и позволяет крутить дальше. Плавное подведение происходит после паузы в 2 мс, если за это время не было новых изменений. Длительность плавного перехода - 1.5 секунды, но это настраивается в константах ниже.
--]]

TIMEOUT = 0.002 -- таймаут определения разницы
EPSILON = 0.0001 -- порог изменения громкости (чувствительность)
SMOOTH_DURATION = 1.5 -- длительность плавного перехода (в секундах)

local state = {}
state.track_data = {}

-- **************************

function SetButtonState(set)
    set = set or 0
    local is_new_value, filename, sec, cmd, mode, resolution, val = reaper.get_action_context()
    reaper.SetToggleCommandState(sec, cmd, set)
    reaper.RefreshToolbar2(sec, cmd)
end

local function initMouseCap()
    gfx.init("invisible", 0, 0, 0, -100, -100)
    gfx.getchar()

    if reaper.JS_Window_Find and reaper.SetCursorContext then
        local hwnd = reaper.JS_Window_Find("REAPER", true)
        if hwnd then
            reaper.JS_Window_SetFocus(hwnd)
        end
        reaper.SetCursorContext(1)
    end
end

function OnExit()
    SetButtonState(0)
end

function IsShiftPressed()
    return gfx.mouse_cap & 8 ~= 0 -- нажат ли Shift?
end

local track_count = reaper.CountTracks(0)
for i = 0, track_count - 1 do
    local track = reaper.GetTrack(0, i)
    local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
    state.track_data[track] = {
        last_vol = vol,
        last_change_time = 0,
        last_change_old = vol,
        last_change_new = vol,
        series_started = false,
        smoothing = nil,
        expected_vol = nil
    }
end

local function loop()
    -- local runState = reaper.GetExtState("smooth_fader", "is_active")

    local cur_time = reaper.time_precise()

    -- проверка удалённых треков
    for track, data in pairs(state.track_data) do
        if not reaper.ValidatePtr(track, "MediaTrack*") then
            state.track_data[track] = nil
        end
    end

    -- проход по всем текущим трекам
    local track_count = reaper.CountTracks(0)
    for i = 0, track_count - 1 do
        local track = reaper.GetTrack(0, i)
        local vol = reaper.GetMediaTrackInfo_Value(track, "D_VOL")
        local data = state.track_data[track]

        if not data then
            -- Новый трек
            data = {
                last_vol = vol,
                last_change_time = 0,
                last_change_old = vol,
                last_change_new = vol,
                series_started = false,
                smoothing = nil,
                expected_vol = nil
            }
            state.track_data[track] = data
        else
            -- проверка изменения громкости (разница по модулю)
            if not IsShiftPressed() then
                if math.abs(vol - data.last_vol) > EPSILON then
                    if data.expected_vol and math.abs(vol - data.expected_vol) <= EPSILON then
                        data.last_vol = vol
                        data.expected_vol = nil
                    else
                        -- пользователь сам крутит
                        if data.smoothing then
                            data.smoothing = nil
                        end

                        local time_since_last = cur_time - data.last_change_time
                        if time_since_last > TIMEOUT then
                            data.series_started = false
                            data.last_change_old = data.last_vol
                            data.last_change_new = vol
                            data.last_change_time = cur_time
                        else
                            data.series_started = true
                            data.last_change_new = vol
                            data.last_change_time = cur_time
                        end
                        data.last_vol = vol
                    end
                else
                    if
                        not data.smoothing and data.last_change_time > 0 and
                            (cur_time - data.last_change_time) > TIMEOUT and
                            not data.series_started
                     then
                        data.smoothing = {
                            start_vol = data.last_change_old,
                            target_vol = data.last_change_new,
                            start_time = cur_time,
                            duration = SMOOTH_DURATION
                        }
                        data.last_change_time = 0
                    end
                end
            end
        end
    end

    -- Обрабатываем активные подведения
    for track, data in pairs(state.track_data) do
        if data.smoothing then
            local elapsed = cur_time - data.smoothing.start_time
            if elapsed >= data.smoothing.duration then
                -- Достигли целевого значения
                local target = data.smoothing.target_vol
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", target)
                data.expected_vol = target
                data.smoothing = nil
            else
                local t = elapsed / data.smoothing.duration
                local new_vol = data.smoothing.start_vol * (1 - t) + data.smoothing.target_vol * t
                reaper.SetMediaTrackInfo_Value(track, "D_VOL", new_vol)
                data.expected_vol = new_vol
            end
        end
    end

    reaper.defer(loop)
end

-- initMouseCap()
reaper.atexit(OnExit)
SetButtonState(1)

loop()
