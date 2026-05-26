-- @noindex
-- @description Shared library for LiveRecGroups scripts
-- @author karamush
-- @version 0.0.0-dev+952fd0f

local M = {}

M.EXTNAME = "LiveRecGroups"

local function proj()
  return 0
end

local function trim(s)
  return (s or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function split_lines(s)
  local t = {}
  s = (s or "") .. "\n"
  for line in s:gmatch("(.-)\n") do
    line = trim(line)
    if line ~= "" then
      t[#t + 1] = line
    end
  end
  return t
end

--- Функция склонения существительных по числу
--- @param count number само число
--- @param titles table массив из 3 вариантов слова (например: {"яблоко", "яблока", "яблок"})
--- @return string строка с числом и правильным словом
local function declOfNum(count, titles)
    local absCount = math.abs(count) % 100
    local lastDigit = absCount % 10

    -- Teen exceptions (11-14)
    if absCount > 10 and absCount < 20 then
        return titles[3]
    end

    if lastDigit == 1 then
        return titles[1]
    elseif lastDigit >= 2 and lastDigit <= 4 then
        return titles[2]
    else
        return titles[3]
    end
end

function M.group_key(group_id)
  return ("group_%02d"):format(group_id)
end

function M.get_script_context()
  local _, _, section_id, cmd_id = reaper.get_action_context()
  return section_id, cmd_id
end

function M.refresh_toolbar(section_id, cmd_id, state)
  reaper.SetToggleCommandState(section_id, cmd_id, state and 1 or 0)
  reaper.RefreshToolbar2(section_id, cmd_id)
end

function M.count_tracks()
  return reaper.CountTracks(proj())
end

function M.get_track_by_index(idx)
  return reaper.GetTrack(proj(), idx)
end

function M.deselect_all_tracks()
  local track_count = M.count_tracks()
  for i = 0, track_count - 1 do
    local tr = M.get_track_by_index(i)
    if tr then
      reaper.SetTrackSelected(tr, false)
    end
  end
end

function M.get_selected_tracks()
  local tracks = {}
  local count = reaper.CountSelectedTracks(proj())
  for i = 0, count - 1 do
    tracks[#tracks + 1] = reaper.GetSelectedTrack(proj(), i)
  end
  return tracks
end

function M.get_track_guid(tr)
  return reaper.GetTrackGUID(tr)
end

function M.find_track_by_guid(guid)
  if not guid or guid == "" then return nil end

  local count = M.count_tracks()
  for i = 0, count - 1 do
    local tr = M.get_track_by_index(i)
    if tr and reaper.GetTrackGUID(tr) == guid then
      return tr
    end
  end

  return nil
end

-- Из списка треков вернуть нумерованный список (по порядку) с названиями треков (string)
function M.format_tracks_str_list(tracks)
  local track_titles = {}
  for i, track in ipairs(tracks) do
      local _, name = reaper.GetTrackName(track)
      table.insert(track_titles, ("- %s"):format(name))
  end

  return table.concat(track_titles, "\n")
end

function M.print_saved_tracks_status(count, group_id)
  if count == 0 then
    reaper.ShowMessageBox(("Группа %d очищена"):format(group_id), "Info", 0)
    return
  end

  local selected_tracks = M.load_group_tracks(group_id)
  local track_word = declOfNum(count, {"трек", "трека", "треков"})
  local write_word = declOfNum(count, {"Записан", "Записано", "Записано"})

  local msg = ("%s %d %s в группу %d\n\n"):format(write_word, count, track_word, group_id)
  local title = ("Сохранено в группу %d"):format(group_id)

  msg = msg .. M.format_tracks_str_list(selected_tracks)
  reaper.ShowMessageBox(msg, title, 0)
end

---Сохранить выбранные треки в группу group_id, но с проверкой НЕ пустой группы и подтверждением перезаписи
---@param group_id integer
---@return integer retval
function M.save_selected_tracks_to_group(group_id)
  local exists_tracks = M.load_group_tracks(group_id)
  local group_is_empty = #exists_tracks == 0
  local selected_tracks = M.get_selected_tracks()
  local selected_zero = #selected_tracks == 0

  -- Группа пустая и ничего не выбрано - оповещаем, что ничего не нужно делать :)
  if group_is_empty and selected_zero then
    reaper.ShowMessageBox("Ничего не выбрано и группа " .. group_id .. " пустая, пропускаем :)", "Info", 0)
    return 0
  end

  -- Группа НЕ пустая, но выбрано ноль треков. Надо уточнить очистку)
  if not group_is_empty and selected_zero then
    local msg = ("Выбрано ноль треков, а группа не пустая: \n%s\n\nХотите очистить эту группу?"):format(
                  M.format_tracks_str_list(exists_tracks))
    local result = reaper.ShowMessageBox(msg, "Подтверждение очистки группы " .. group_id, 4)

    if result == 7 then return 0 end
  end

  -- Группа не пустая и есть треки, надо уточнить)
  if not group_is_empty and not selected_zero then
    local msg = ("Эта группа не пустая и содержит следующие треки: \n%s\n\nПерезаписать выбранные треки в эту группу?"):format(
    M.format_tracks_str_list(exists_tracks))
    local result = reaper.ShowMessageBox(msg, "Подтверждение перезаписи группы " .. group_id, 4)
    if result == 7 then return 0 end
  end

  local guids = {}
  for _, tr in ipairs(M.get_selected_tracks()) do
    guids[#guids + 1] = M.get_track_guid(tr)
  end

  reaper.SetProjExtState(proj(), M.EXTNAME, M.group_key(group_id), table.concat(guids, "\n"))

  M.print_saved_tracks_status(#guids, group_id)

  return #guids
end

function M.load_group_guids(group_id)
  local _, value = reaper.GetProjExtState(proj(), M.EXTNAME, M.group_key(group_id))
  return split_lines(value)
end

function M.load_group_tracks(group_id)
  local tracks = {}
  for _, guid in ipairs(M.load_group_guids(group_id)) do
    local tr = M.find_track_by_guid(guid)
    if tr then
      tracks[#tracks + 1] = tr
    end
  end
  return tracks
end

function M.is_all_track_in_mon_only_mode(tracks)
  for _, tr in ipairs(tracks) do
    if reaper.GetMediaTrackInfo_Value(tr, "I_RECMODE") == 0 then
      return true
    end
  end
  return false
end

function M.set_track_group_record_state(tr, armed)
  reaper.SetMediaTrackInfo_Value(tr, "I_RECMON", 1)
  reaper.SetMediaTrackInfo_Value(tr, "I_RECARM", 1)
  reaper.SetMediaTrackInfo_Value(tr, "I_RECMODE", armed and 0 or 2)
end

function M.set_group_record_state(group_id, armed)
  local tracks = M.load_group_tracks(group_id)
  if #tracks == 0 then
    return false, 0, "group is empty"
  end

  reaper.PreventUIRefresh(1)
  for _, tr in ipairs(tracks) do
    M.set_track_group_record_state(tr, armed)
  end
  reaper.PreventUIRefresh(-1)

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  return true, #tracks, nil
end

function M.toggle_group(group_id)
  local tracks = M.load_group_tracks(group_id)
  if #tracks == 0 then
    return nil, 0, "group is empty"
  end

  local turn_on = not M.is_all_track_in_mon_only_mode(tracks)
  local ok, count, err = M.set_group_record_state(group_id, turn_on)
  if not ok then
    return nil, count, err
  end

  return turn_on, count, nil
end

function M.select_group(group_id)
  local tracks = M.load_group_tracks(group_id)

  M.deselect_all_tracks()
  for _, tr in ipairs(tracks) do
    reaper.SetTrackSelected(tr, true)
  end

  reaper.TrackList_AdjustWindows(false)
  reaper.UpdateArrange()
  return #tracks
end

function M.sync_group_button(group_id, section_id, cmd_id)
  local tracks = M.load_group_tracks(group_id)
  local on = M.is_all_track_in_mon_only_mode(tracks)
  M.refresh_toolbar(section_id, cmd_id, on)
  return on
end

return M
