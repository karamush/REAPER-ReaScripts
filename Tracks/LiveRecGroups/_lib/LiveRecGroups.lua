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

function M.save_selected_tracks_to_group(group_id)
  local guids = {}
  for _, tr in ipairs(M.get_selected_tracks()) do
    guids[#guids + 1] = M.get_track_guid(tr)
  end

  reaper.SetProjExtState(proj(), M.EXTNAME, M.group_key(group_id), table.concat(guids, "\n"))
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

function M.debug_dump_track_flags(tr)
  if not tr then
    reaper.ShowConsoleMsg("debug_dump_track_flags: track is nil\n")
    return
  end

  local track_name_ret, track_name = reaper.GetTrackName(tr)

  reaper.ShowConsoleMsg("\n")
  reaper.ShowConsoleMsg("=====================================\n")
  reaper.ShowConsoleMsg("TRACK DEBUG FLAGS\n")
  reaper.ShowConsoleMsg("=====================================\n")

  if track_name_ret then
    reaper.ShowConsoleMsg("Track name: " .. tostring(track_name) .. "\n")
  end

  reaper.ShowConsoleMsg("GUID: " .. tostring(reaper.GetTrackGUID(tr)) .. "\n")
  reaper.ShowConsoleMsg("\n")

  local params = {
    -- basic
    "B_MUTE",
    "B_PHASE",
    "B_SOLO_DEFEAT",
    "B_AUTO_RECARM",
    "B_RECMON_IN_EFFECT",

    -- recording
    "I_RECARM",
    "I_RECINPUT",
    "I_RECMODE",
    "I_RECMODE_FLAGS",
    "I_RECMON",
    "I_RECMONITEMS",

    -- solo/fx
    "I_SOLO",
    "I_FXEN",

    -- automation
    "I_AUTOMODE",

    -- channels/meters
    "I_NCHAN",
    "I_VUMODE",

    -- visibility/layout
    "B_SHOWINTCP",
    "B_SHOWINMIXER",

    -- foldering
    "I_FOLDERDEPTH",

    -- track identity
    "IP_TRACKNUMBER",

    -- appearance
    "I_CUSTOMCOLOR",

    -- misc
    "D_VOL",
    "D_PAN",
    "D_WIDTH",
  }

  for _, param in ipairs(params) do
    local value = reaper.GetMediaTrackInfo_Value(tr, param)
    reaper.ShowConsoleMsg(
      string.format("%-24s = %s\n", param, tostring(value))
    )
  end

  local retval, flags = reaper.GetTrackState(tr)

  reaper.ShowConsoleMsg("\n")
  reaper.ShowConsoleMsg("GetTrackState flags: " .. tostring(flags) .. "\n")

  local state_flags = {
    {1, "folder"},
    {2, "selected"},
    {4, "fx enabled"},
    {8, "muted"},
    {16, "soloed"},
    {32, "solo in place"},
    {64, "rec armed"},
    {128, "rec monitoring on"},
    {256, "rec monitoring auto"},
    {512, "hidden in TCP"},
    {1024, "hidden in MCP"},
  }

  for _, flag_info in ipairs(state_flags) do
    local bit = flag_info[1]
    local name = flag_info[2]

    local enabled = (flags & bit) ~= 0

    reaper.ShowConsoleMsg(
      string.format(
        "  [%4d] %-24s : %s\n",
        bit,
        name,
        enabled and "YES" or "NO"
      )
    )
  end

  reaper.ShowConsoleMsg("=====================================\n")
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
