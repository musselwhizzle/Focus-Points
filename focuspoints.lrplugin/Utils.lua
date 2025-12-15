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


local LrFileUtils   = import  'LrFileUtils'
local LrPathUtils   = import  'LrPathUtils'
local LrShell       = import  'LrShell'
local LrStringUtils = import  'LrStringUtils'
local LrTasks       = import  'LrTasks'
local LrUUID        = import  'LrUUID'
local Log           = require 'Log'

Utils = {}


--[[--------------------------------------------------------------------------------------------------------------------
   Utilities for string handling
----------------------------------------------------------------------------------------------------------------------]]

--[[
-- Breaks a string in 2 parts at the position of the delimiter and returns a key/value table
-- split("A=D E", "=") -> { "A" = "DE" }
-- str - string to be broken into pieces
-- delim - delimiter
--]]
function Utils.splitToKeyValue(str, delim)
  if str == nil then return nil end
  local index = string.find(str, delim)
  if index == nil then
    return nil
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
function Utils.splitoriginal(str, delim)
  if str == nil then return nil end
  local t = {}
  local i = 1
  for str in string.gmatch(str, "([^" .. delim .. "]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

function Utils.split(str, delimiters)
  -- Build a pattern that matches any sequence of characters
  -- that are not one of the delimiters.
  -- This is an extension to the original split function that supported a single delimiter
  if not str then return nil end
  local pattern = "([^" .. delimiters .. "]+)"
  local result = {}
  for token in string.gmatch(str, pattern) do
    table.insert(result, token)
  end
  return result
end

--[[
-- Breaks a delimited string into a table of substrings and removes whitespace
-- split("A B C,D E", " ") -> { "A", "B", "C,D", "E" }
-- str - string to be broken into pieces
-- delim - delimiter
--]]
function Utils.splitTrim(str, delim)
  if str == nil then return nil end
  local t = {}
  local i = 1
  for str in string.gmatch(str, "([^" .. delim .. "]+)") do
    t[i] = LrStringUtils.trimWhitespace(str)
    i = i + 1
  end
  return t
end

--[[
 Splits a string into 2 parts: key and value.
 @str  the string to split
 @delim the character used for splitting the string
--]]
function Utils.stringToKeyValue(str, delim)
  if str == nil then return nil end
  local index = string.find(str, delim)
  if index == nil then
    return nil
  end
  local r = {}
  r.key = string.sub(str, 0, index-1)
  r.value = string.sub(str, index+1, #str)
  return r
end

--[[
 Gets the nth word from a string
 @str  the string to split into words
 @delim the character used for splitting the string
--]]
function Utils.get_nth_Word(str, n, delimiter)
    delimiter = delimiter or ";" -- Default to semicolon if not provided
    local pattern = "([^" .. delimiter .. "]+)" -- Dynamic delimiter pattern
    local count = 0
    for word in string.gmatch(str, pattern) do
        count = count + 1
        if count == n then
            return word:match("^%s*(.-)%s*$") -- Trim leading/trailing spaces
        end
    end
    return nil -- Return nil if n is out of range
end


--- Wrap a string to a specified line length using multiple delimiters.
-- @param input The input string to wrap.
-- @param maxLen Maximum line length.
-- @param delimiters A table of delimiters (e.g., { " ", "-", "/" }).
-- @return A string wrapped with line breaks (`\n`).
function Utils.wrapText(input, delimiters, maxLen)
  if not input then return "" end
  -- Escape delimiters for pattern use
  local delimSet = {}
  for _, d in ipairs(delimiters) do
      delimSet[d] = true
  end
  local escaped = {}
  for d in pairs(delimSet) do
      table.insert(escaped, "%" .. d)
  end
  local pattern = "([^" .. table.concat(escaped) .. "]+)([" .. table.concat(escaped) .. "]?)"

  local lines = {}
  local currentLine = ""

  for word, delim in input:gmatch(pattern) do
      local part = word .. delim
      if #currentLine + #part > maxLen then
          if #currentLine > 0 then
              -- Trim trailing spaces from the current line before pushing
              -- Wrap gsub call in parentheses so it only returns one result value and not more)
              table.insert(lines, (currentLine:gsub("[%s" .. table.concat(escaped) .. "]+$", "")))
          end
          -- Trim leading whitespace in the new line part
          currentLine = part:gsub("^%s+", "")
      else
          currentLine = currentLine .. part
      end
  end

  if #currentLine > 0 then
      table.insert(lines, (currentLine:gsub("%s+$", "")))
  end

  return table.concat(lines, "\n")
end


--[[
-- Parses a string in the form of "(width)x(height)"" and returns width and height
-- strDimens - string to be parsed
--]]
function Utils.parseDimens(strDimens)
  local index = string.find(strDimens, "x")
  if index == nil then return nil end
  local w = string.sub(strDimens, 0, index-1)
  local h = string.sub(strDimens, index+1)
  w = LrStringUtils.trimWhitespace(w)
  h = LrStringUtils.trimWhitespace(h)
  return tonumber(w), tonumber(h)
end

--[[--------------------------------------------------------------------------------------------------------------------
   Miscellaneous utilities
----------------------------------------------------------------------------------------------------------------------]]

--[[
-- Searches for a value in a table and returns the corresponding key
-- table - table to search inside
-- val - value to search for
--]]
function Utils.arrayKeyOf(table, val)
  for k,v in pairs(table) do
    if v == val then
      return k
    end
  end
  return nil
end


--[[
  @@public string Utils.getTempFileName()
  ----
  Create new UUID name for a temporary file
--]]
function Utils.getTempFileName()
  local fileName = LrPathUtils.child(LrPathUtils.getStandardFilePath("temp"), LrUUID.generateUUID() .. ".txt")
  return fileName
end


--[[
-- Open filename in associated application as per file extension
-- https://community.adobe.com/t5/lightroom-classic/developing-a-publish-plugin-some-api-questions/m-p/11643928#M214559
--]]
function Utils.openFileInApp(filename)
  if WIN_ENV then
    LrShell.openFilesInApp({""}, filename)
  else
    LrShell.openFilesInApp({filename}, "open")
  end
end

--[[
  @@public string Utils.getPhotoFileName(table)
  Retrieves name of current photo, used by centralized error handling
--]]
function Utils.getPhotoFileName(photo)
  if not photo then
    photo = FocusPointDialog.currentPhoto
  end
  if photo then
    return photo:getFormattedMetadata( "fileName" )
  end
end


--[[
  @@public string getPluginVersion()
  ----
  Retrieves the plugin version number as string
--]]
function Utils.getPluginVersion()
  return require 'Info.lua'.VERSION.display
end


--[[
  @@public int Utils.getWinScalingFactor()
  ----
  Retrieves Windows DPI scaling level registry key (HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics, AppliedDPI)
  Returns display scaling level as factor (100/scale_in_percent)
--]]
function Utils.getWinScalingFactor()
  local output = Utils.getTempFileName()
  local cmd = "reg.exe query \"HKEY_CURRENT_USER\\Control Panel\\Desktop\\WindowMetrics\" -v AppliedDPI >\"" .. output .. "\""
  local result

  -- Query registry value by calling REG.EXE
  local rc = LrTasks.execute(cmd)
  Log.logDebug("Utils", "Retrieving DPI scaling level from Windosws registry using REG.EXE")
  Log.logDebug("Utils", "REG command: " .. cmd .. ", rc=" .. rc)

  -- Read redirected stdout from temp file and find the line that starts with "AppliedDPI"
  local regOutput = LrFileUtils.readFile(output)
  local regOutputStr = "^"
  local dpiValue, scale
  for line in string.gmatch(regOutput, ("[^\r\n]+")) do
    local item = Utils.split(line, " ")
    if item and #item >= 3 then
      if item[1] == "AppliedDPI" and item[2] == "REG_DWORD" then
        dpiValue = item[3]
        scale = math.floor(tonumber(dpiValue) * 100/96 + 0.5)
      end
    end
    regOutputStr = regOutputStr .. line .. "^"
  end
  Log.logDebug("Utils", "REG output: " .. regOutputStr)

  -- Set and log the result
  if dpiValue then
    result = 100 / scale
    Log.logDebug("Utils", string.format("DPI scaling level %s = %sdpi ~ %s%%", dpiValue, tonumber(dpiValue), scale))
  else
    result = 100 / 125
    Log.logWarn("Utils", "Unable to retrieve Windows scaling level, using 125% instead")
  end

  -- Clean up: remove the temp file
  if LrFileUtils.exists(output) and not LrFileUtils.delete(output) then
    Log.logWarn("Utils", "Unable to delete REG output file " .. output)
  end

  return result
end


return Utils
