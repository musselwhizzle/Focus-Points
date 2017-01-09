--[[
  Copyright 2016 Joshua Musselwhite, Whizzbang Inc

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


local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrLogger = import 'LrLogger'
local LrStringUtils = import "LrStringUtils"


local myLogger = LrLogger( 'libraryLogger' )
myLogger:enable( "logfile" )

isDebug = false
isLog = true

--[[
-- Breaks a string in 2 parts at the position of the delimiter and returns a key/value table
-- split("A=D E", "=") -> { "A" = "DE" }
-- str - string to be broken into pieces
-- delim - delimiter
--]]
function splitToKeyValue(str, delim)
  if str == nill then return nill end
  local index = string.find(str, delim)
  if index == nill then
    return nill
  end
  local r = {}
  r.key = string.sub(str, 0, index-1)
  r.value = string.sub(str, index+1, #str)
  return r
end

--[[
-- Breaks a delimited string into a table of substrings
-- split("A B C,D E", " ") -> { "A", "B", "C,D", "E" }
-- str - string to be broken into pieces
-- delim - delimiter
--]]
function split(str, delim)
  local t = {}
  local i = 1
  for str in string.gmatch(str, "([^" .. delim .. "]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

--[[
-- Split a key/value table and returns 2 strings being the ordered list of keys and the ordered list of value
-- as well as the max key length, the max value length and the number of lines in both strings
-- tab - the table
--]]
function splitForColumns(tab)
  local keys = ""
  local values = ""
  local keys_max_length = 0
  local values_max_length = 0
  local line_count = 0

  for key, value in pairsByKeys(tab) do
    if string.len(value) >= 1024 then         -- This might not be needed on mac and other platform but it is on Windows to prevent unwanted wrap
      value = string.sub(value, 1, 1024)      -- We could check for the platform but limiting to 1K of data for each feld does not seem to be a limitation
    end

    keys = keys .. key .. "\n"
    values = values .. value .. "\n"

    keys_max_length = math.max(keys_max_length, string.len(key))
    values_max_length = math.max(values_max_length, string.len(value))
    line_count = line_count + 1
  end

  return keys, values, keys_max_length, values_max_length, line_count
end

--[[
 Splits a string into 2 parts: key and value.
 @str  the string to split
 @delim the character used for splitting the string
--]]
function stringToKeyValue(str, delim)
  if str == nill then return nill end
  local index = string.find(str, delim)
  if index == nill then
    return nill
  end
  local r = {}
  r.key = string.sub(str, 0, index-1)
  r.value = string.sub(str, index+1, #str)
  return r
end



--[[
-- Logging function. If the global variable isLog is false, does nothing
-- str - string to be sent to the logger
--]]
function log(str)
  if (isLog) then
    myLogger:warn(str)
  end
end

--[[
-- Parses a string in the form of "(width)x(height)"" and returns width and height
-- strDimens - string to be parsed
--]]
function parseDimens(strDimens)
  local index = string.find(strDimens, "x")
  if (index == nill) then return nill end
  local w = string.sub(strDimens, 0, index-1)
  local h = string.sub(strDimens, index+1)
  w = LrStringUtils.trimWhitespace(w)
  h = LrStringUtils.trimWhitespace(h)
  return tonumber(w), tonumber(h)
end

--[[
-- Searches for a value in a table and returns the corresponding key
-- tab - table to search inside
-- val - value to search for
--]]
function arrayKeyOf(tab, val)
  for k,v in pairs(tab) do
    log(k .. " | " .. v .. " | " .. val)
      if v == val then
        return k
      end
  end
  return nil
end

--[[
-- Return a table iterator which iterates through the table keys in alphabetical order
-- tab - the table to iterate through
-- comp - a comparison functon to be passed the native table.sort function
--]]
function pairsByKeys (tab, comp)
    local a = {}
    for key in pairs(tab) do
        table.insert(a, key)
    end

    table.sort(a, comp)

    local i = 0      -- iterator variable
    local iter = function ()   -- iterator function
      i = i + 1
      if a[i] == nil then
        return nil
      else
        return a[i], tab[a[i]]
      end
    end

    return iter
  end

--[[
-- Transform the coordinates around a center point and scale them
-- x, y - the coordinates to be transformed
-- oX, oY - the coordinates of the center
-- angle - the rotation angle
-- scaleX, scaleY - scaleing factors
--]]
function transformCoordinates(x, y, oX, oY, angle, scaleX, scaleY)
  -- Rotation around 0,0
  local rX = x * math.cos(angle) + y * math.sin(angle)
  local rY = -x * math.sin(angle) + y * math.cos(angle)

  -- Rotation of origin corner
  local roX = oX * math.cos(angle) + oY * math.sin(angle)
  local roY = -oX * math.sin(angle) + oY * math.cos(angle)

  -- Translation so the top left corner become the origin
  local tX = rX - roX
  local tY = rY - roY

  -- Let's resize everything to match the view
  tX = tX * scaleX
  tY = tY * scaleY

  return tX, tY
end
