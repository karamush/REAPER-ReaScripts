-- @noindex

local script_path = debug.getinfo(1, "S").source:sub(2)
local script_dir = script_path:match("^(.*[\\/])")

local LR = dofile(script_dir .. "_lib/LiveRecGroups.lua")

local _, _, section_id, cmd_id, _, _, _ = reaper.get_action_context()

local GROUP_ID = 1

LR.select_group(GROUP_ID)
