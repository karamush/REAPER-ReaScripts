-- @noindex

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("^(.*[\\/])")

local LR = dofile(script_dir .. "_lib/LiveRecGroups.lua")

local _, _, section_id, cmd_id, _, _, _ = reaper.get_action_context()

local GROUP_ID = 7

reaper.Undo_BeginBlock()

local count = LR.save_selected_tracks_to_group(GROUP_ID)

reaper.Undo_EndBlock(
    "Save selected tracks to LiveRecGroups",
    -1
)

reaper.ShowConsoleMsg(
    ("Saved %d track(s) to group %d\n")
    :format(count, GROUP_ID)
)
