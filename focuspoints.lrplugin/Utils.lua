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
  Utils.lua

  Purpose of this module:
  Helper functions for string handling and miscellaneous purposes
------------------------------------------------------------------------------]]
local Utils = {}

-- Imported LR namespaces
local LrPathUtils      = import  'LrPathUtils'
local LrShell          = import  'LrShell'
local LrStringUtils    = import  'LrStringUtils'
local LrUUID           = import  'LrUUID'

-- Required Lua definitions
local GlobalDefs       = require 'GlobalDefs'
local _strict          = require 'strict'

--[[----------------------------------------------------------------------------
  public table
  splitToKeyValue(string str, char delim)

  Breaks a string in 2 parts at the position of the delimiter and returns a key/value table
  split("A=D E", "=") -> { "A" = "DE" }
  str - string to be broken into pieces
  delim - delimiter
  Returns a spacer to provide extra separation between two rows
------------------------------------------------------------------------------]]
function Utils.splitToKeyValue(str, delim)
  if str == nil then return nil end
  local index = string.find(str, delim)
  if index == nil then
    return nil
  end
  local r = {}
  r.key   = string.sub(str, 0,       index-1)
  r.value = string.sub(str, index+1, #str)
  return r
end

--[[----------------------------------------------------------------------------
  public table
  splitoriginal(string str, char delim)

  Breaks a delimited string into a table of substrings
  split("A B C,D E", " ") -> { "A", "B", "C,D", "E" }
  str - string to be broken into pieces
  delim - delimiter
------------------------------------------------------------------------------]]
function Utils.splitoriginal(str, delim)
  if str == nil then return nil end
  local t = {}
  local i = 1
  for s in string.gmatch(str, "([^" .. delim .. "]+)") do
    t[i] = s
    i = i + 1
  end
  return t
end

--[[----------------------------------------------------------------------------
  public table
  split(string str, string delim)

  Create a pattern that matches any sequence of characters that is not one of the
  delimiters. This is an extension to the original split function, which only
  supported a single delimiter.
------------------------------------------------------------------------------]]
function Utils.split(str, delimiters)
  if not str then return nil end
  local pattern = "([^" .. delimiters .. "]+)"
  local result = {}
  for token in string.gmatch(str, pattern) do
    table.insert(result, token)
  end
  return result
end

--[[----------------------------------------------------------------------------
  public table
  splitTrim(string str, char delim)

  Breaks a delimited string into a table of substrings and removes whitespace
  split("A B C,D E", " ") -> { "A", "B", "C,D", "E" }
  str - string to be broken into pieces
  delim - delimiter
------------------------------------------------------------------------------]]
function Utils.splitTrim(str, delim)
  if str == nil then return nil end
  local t = {}
  local i = 1
  for s in string.gmatch(str, "([^" .. delim .. "]+)") do
    t[i] = LrStringUtils.trimWhitespace(s)
    i = i + 1
  end
  return t
end

--[[----------------------------------------------------------------------------
  public string
  get_nth_Word(string str, int n, char delim)

  Gets the nth word from a string
  @str  the string to split into words
  @delim the character used for splitting the string
------------------------------------------------------------------------------]]
function Utils.get_nth_Word(str, n, delimiter)
  delimiter = delimiter or ";"                  -- Default to semicolon if not provided
  local pattern = "([^" .. delimiter .. "]+)"   -- Dynamic delimiter pattern
  local count = 0
  for word in string.gmatch(str, pattern) do
    count = count + 1
    if count == n then
      return word:match("^%s*(.-)%s*$") -- Trim leading/trailing spaces
    end
  end
  return nil -- Return nil if n is out of range
end

--[[----------------------------------------------------------------------------
  public string
  wrapText(string input, table delimiters, int maxLen)

  Wrap a string to a specified line length using multiple delimiters.
  @param input The input string to wrap.
  @param maxLen Maximum line length.
  @param delimiters A table of delimiters (e.g., { " ", "-", "/" }).
  @return A string wrapped with line breaks (`\n`).
------------------------------------------------------------------------------]]
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
          -- trim trailing spaces from the current line before pushing
          -- wrap gsub call in parentheses so it only returns one result value and not more)
          table.insert(lines, (currentLine:gsub("[%s" .. table.concat(escaped) .. "]+$", "")))
      end
      -- trim leading whitespace in the new line part
      currentLine = part:gsub("^%s+", "")
    else
      currentLine = currentLine .. part
    end
  end

  -- Trim trailing spaces
  if #currentLine > 0 then
    table.insert(lines, (currentLine:gsub("%s+$", "")))
  end

  -- Concatenate the individual lines to form one string, with a newline character separating them
  return table.concat(lines, "\n")
end

--[[----------------------------------------------------------------------------
  public int width, int height
  parseDimens(string strDimens)

  Parses a string in the form of "(width)x(height)"" and returns width and height
  strDimens - string to be parsed
------------------------------------------------------------------------------]]
function Utils.parseDimens(strDimens)
  local index = string.find(strDimens, "x")
  if index == nil then return nil end
  local w = string.sub(strDimens, 0, index-1)
  local h = string.sub(strDimens, index+1)
  w = LrStringUtils.trimWhitespace(w)
  h = LrStringUtils.trimWhitespace(h)
  return tonumber(w), tonumber(h)
end

--[[----------------------------------------------------------------------------
  public any
  arrayKeyOf(table, any val)

  Searches for a value in a table and returns the corresponding key
  table - table to search inside
  val   - value to search for
------------------------------------------------------------------------------]]
function Utils.arrayKeyOf(table, val)
  for k,v in pairs(table) do
    if v == val then
      return k
    end
  end
  return nil
end

--[[----------------------------------------------------------------------------
  public string
  getTempFileName()

  Create new UUID name for a temporary file
------------------------------------------------------------------------------]]
function Utils.getTempFileName()
  local fileName =
    LrPathUtils.child(
      LrPathUtils.getStandardFilePath("temp"), LrUUID.generateUUID() .. ".txt")
  return fileName
end

--[[----------------------------------------------------------------------------
  public void
  openFileInApp(string fileName)

  Open 'fileName' in associated application as per file extension
  https://community.adobe.com/t5/lightroom-classic/developing-a-publish-plugin-some-api-questions/m-p/11643928#M214559
------------------------------------------------------------------------------]]
function Utils.openFileInApp(fileName)
  if WIN_ENV then
    LrShell.openFilesInApp({""}, fileName)
  else
    LrShell.openFilesInApp({fileName}, "open")
  end
end

--[[----------------------------------------------------------------------------
  public table
  getPhotoFileName(table photo)

  Retrieve the name of the current photo, used by centralized error handling
------------------------------------------------------------------------------]]
function Utils.getPhotoFileName(photo)
  if not photo then
    photo = GlobalDefs.currentPhoto
  end
  if photo then
    return photo:getFormattedMetadata( "fileName" )
  end
end

return Utils -- ok
