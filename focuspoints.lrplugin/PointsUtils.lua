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

--[[----------------------------------------------------------------------------
  PointsUtils.lua

  Purpose of this module:
  Functions to read the focus points layout .txt files (for Nikon and Pentax)
  and parse the information so symbolic focus point names (A1, B2, C3 etc)
  can be mapped to pixel coordinates.
------------------------------------------------------------------------------]]
local PointsUtils = {}

-- Imported LR namespaces
local LrFileUtils   = import  'LrFileUtils'
local LrPathUtils   = import  'LrPathUtils'
local LrStringUtils = import  'LrStringUtils'

-- Required Lua definitions
local FocusInfo     = require 'FocusInfo'
local Log           = require 'Log'
local _strict       = require 'strict'
local Utils         = require 'Utils'

--[[----------------------------------------------------------------------------
  private string
  readFromFile(string folder, string fileName)

  Reads the mapping file 'fileName' and returns its contents as a string.
------------------------------------------------------------------------------]]
local function readFromFile(folder, fileName)
  local file = LrPathUtils.child( _PLUGIN.path, "focus_points" )
  file = LrPathUtils.child(file, folder)
  file = LrPathUtils.child(file, fileName)

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

--[[----------------------------------------------------------------------------
  public table focusPoints, table focusPointDimens, table fullSizeDimens
  readIntoTable(string folder, string fileName)

  Reads the mapping file 'fileName' and parses its contents into three tables
  1. focusPoints:      x, y, width, heigth for each individual point listed
  2. focusPointDimens: width/heigth dimensions (applies to all points)
  3. fullSizeDimens:   full size image dimensions*

  * This information is required to handle crop modes for certain Pentax models,
    as the original image dimensions are not included in the photo's metadata.
------------------------------------------------------------------------------]]
function PointsUtils.readIntoTable(folder, fileName)
  local focusPoints = {}
  local focusPointDimens = {}
  local fullSizeDimens = {}
  local data = readFromFile(folder, fileName)

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

return PointsUtils -- ok
