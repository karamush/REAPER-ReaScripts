-- @description LiveRecGroups
-- @version 1.0.1
-- @author Karamush
-- @about
--    LiveRecGroups provides track grouping features for live recording/streaming in REAPER.
-- @metapackage
-- @provides
--    [main] Toggle Track Group 01 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 01 (LiveRecGroups).lua
--    [main] Select Tracks In Group 01 (LiveRecGroups).lua
--    [main] Toggle Track Group 02 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 02 (LiveRecGroups).lua
--    [main] Select Tracks In Group 02 (LiveRecGroups).lua
--    [main] Toggle Track Group 03 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 03 (LiveRecGroups).lua
--    [main] Select Tracks In Group 03 (LiveRecGroups).lua
--    [main] Toggle Track Group 04 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 04 (LiveRecGroups).lua
--    [main] Select Tracks In Group 04 (LiveRecGroups).lua
--    [main] Toggle Track Group 05 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 05 (LiveRecGroups).lua
--    [main] Select Tracks In Group 05 (LiveRecGroups).lua
--    [main] Toggle Track Group 06 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 06 (LiveRecGroups).lua
--    [main] Select Tracks In Group 06 (LiveRecGroups).lua
--    [main] Toggle Track Group 07 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 07 (LiveRecGroups).lua
--    [main] Select Tracks In Group 07 (LiveRecGroups).lua
--    [main] Toggle Track Group 08 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 08 (LiveRecGroups).lua
--    [main] Select Tracks In Group 08 (LiveRecGroups).lua
--    [main] Toggle Track Group 09 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 09 (LiveRecGroups).lua
--    [main] Select Tracks In Group 09 (LiveRecGroups).lua
--    [main] Toggle Track Group 10 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 10 (LiveRecGroups).lua
--    [main] Select Tracks In Group 10 (LiveRecGroups).lua
--    [main] Toggle Track Group 11 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 11 (LiveRecGroups).lua
--    [main] Select Tracks In Group 11 (LiveRecGroups).lua
--    [main] Toggle Track Group 12 (LiveRecGroups).lua
--    [main] Save Selected Tracks To Group 12 (LiveRecGroups).lua
--    [main] Select Tracks In Group 12 (LiveRecGroups).lua
--    [nomain] _lib/LiveRecGroups.lua

-- This file is auto-generated.

--[[
  Changelog:
* 1.0.0 (2026-05-25)
  + Первый релиз. Основной функционал работает 🐧
* 1.0.1 (2026-05-26)
  + Показ списка сохранённых треков (чтоб убедиться ещё разок)
  + Подтверждение при перезаписи не пустой группы
  + Подтверждение при очистке группы
  + Оповещение, если группа пуста и выбрано 0 треков :)
]]
