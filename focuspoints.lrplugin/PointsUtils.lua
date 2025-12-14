--[[
  Copyright 2016 Whizzbang Inc

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
--]]

local LrFileUtils   = import 'LrFileUtils'
local LrPathUtils   = import 'LrPathUtils'
local LrStringUtils = import 'LrStringUtils'
local Utils         = import require 'Utils'
local Log           = import require 'Log'

PointsUtils = {}

function PointsUtils.readFromFile(folder, filename)
  local file = LrPathUtils.child( _PLUGIN.path, "focus_points" )
  file = LrPathUtils.child(file, folder)
  file = LrPathUtils.child(file, filename)

  -- replace special character.  '*' is an invalid char on windows file systems
  file = string.gsub(file, "*", "_a_")
  Log.logDebug("PointsUtils", "Reading focus point mapping from file: " .. file)

  if (LrFileUtils.exists(file) ~= false) then
    local data = LrFileUtils.readFile(file)
    return data
  else
    Log.logError("PointsUtils", "Mapping file not found: " .. file)
    FocusInfo.severeErrorEncountered = true
    return nil
  end
end

function PointsUtils.readIntoTable(folder, filename)
  local focusPoints = {}
  local focusPointDimens = {}
  local fullSizeDimens = {}
  local data = PointsUtils.readFromFile(folder, filename)
  if (data == nil) then return nil end
  for i in string.gmatch(data, "[^\\\n]+") do
    -- skip comment lines
    if i:match("^%s*%-%-") == nil then
      local p = Utils.splitToKeyValue(i, "=")
      if p ~= nil then

        -- variable or focus point name
        local pointName = p.key
        pointName = LrStringUtils.trimWhitespace(pointName)

        -- variable value
        local value = LrStringUtils.trimWhitespace(p.value)
        value = string.gsub(value, "{", "")
        value = string.gsub(value, "}", "")
        value = LrStringUtils.trimWhitespace(p.value)
        local dataPoints = Utils.splitTrim(value, ",")

        -- parse the single value items: x, y, [h, w]
        local points = {}
        for i in pairs(dataPoints) do
          local item = dataPoints[i]
          item = string.gsub(item, "[^0-9]", "")
          item = LrStringUtils.trimWhitespace(item)
          points[i] = item
        end

        if #dataPoints > 2 then
          Log.logFull("PointsUtils",
            string.format("Point name: %s = (x:%s, y:%s, w:%s, h:%s)",
                                       pointName, points[1], points[2], points[3], points[4]))
        else
          Log.logFull("PointsUtils",
            string.format("Point name: %s = (x:%s, y:%s)", pointName, points[1], points[2]))
        end

        if (pointName == "focusPointDimens") then
          focusPointDimens = points
        elseif (pointName == "fullSizeDimens") then
          fullSizeDimens = points
        else
          focusPoints[pointName] = points
        end

      end
    end
  end
  return focusPoints, focusPointDimens, fullSizeDimens
end


return PointsUtils
