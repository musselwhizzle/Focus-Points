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

local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import "LrStringUtils"
require "Utils"

PointsUtils = {}

function PointsUtils.readFromFile(folder, filename)
  local file = LrPathUtils.child( _PLUGIN.path, "focus_points" )
  file = LrPathUtils.child(file, folder)
  file = LrPathUtils.child(file, filename)

  if (LrFileUtils.exists(file) ~= false) then
    local data = LrFileUtils.readFile(file)
    return data
  else
    return nil
  end
end

function PointsUtils.readIntoTable(folder, filename)
  local focusPoints = {}
  local focusPointDimens = {}
  local data = PointsUtils.readFromFile(folder, filename)
  if (data == nil) then return nil end
  for i in string.gmatch(data, "[^\\\n]+") do
    p = splitToKeyValue(i, "=")
    if p ~= nil then
      
      -- variable or focus point name
      local pointName = p.key
      pointName = LrStringUtils.trimWhitespace(pointName)
      
      -- variable value
      local value = LrStringUtils.trimWhitespace(p.value)
      value = string.gsub(value, "{", "")
      value = string.gsub(value, "}", "")
      value = LrStringUtils.trimWhitespace(p.value)
      local dataPoints = splitTrim(value, ",")
      
      local points = {}
      for i in pairs(dataPoints) do
        local item = dataPoints[i]
        item = string.gsub(item, "[^0-9]", "")
        item = LrStringUtils.trimWhitespace(item)
        points[i] = item
      end
      
      --logDebug("PointsUtils", "pointName: " .. pointName .. ", x: " .. x .. ", y: " .. y)

      if (pointName == "focusPointDimens") then
        focusPointDimens = points
      else
        focusPoints[pointName] = points
      end
    end
  end
  return focusPoints, focusPointDimens
end
