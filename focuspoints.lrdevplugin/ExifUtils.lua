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

local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import "LrStringUtils"

ExifUtils = {}
exiftool = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftool = LrPathUtils.child(exiftool, "exiftool")
exiftool = LrPathUtils.child(exiftool, "exiftool")

function ExifUtils.getExifCmd(targetPhoto)
  local path = targetPhoto:getRawMetadata("path")
  local metaDataFile = LrPathUtils.removeExtension(path)
  metaDataFile = metaDataFile .. "-metadata.txt"

  local cmd = "'"..exiftool .. "' -a -u -sort '" .. path .. "' > '" .. metaDataFile .. "'";

  return cmd, metaDataFile
end

function ExifUtils.readMetaData(targetPhoto)
  local cmd, metaDataFile = ExifUtils.getExifCmd(targetPhoto)
  LrTasks.execute(cmd)
  local fileInfo = LrFileUtils.readFile(metaDataFile)
  LrFileUtils.delete(metaDataFile)
  return fileInfo
end

--[[
-- Transforms the output of ExifUtils.readMetaData and returns a key/value lua Table
-- targetPhoto - LrPhoto to extract the Exif from
--]]
function ExifUtils.readMetaDataAsTable(targetPhoto)
  local metaData = ExifUtils.readMetaData(targetPhoto)
  if metaData == nil then
    return nil
  end

  local parsedTable = {}

  for keyword, value in string.gmatch(metaData, "([^\:]+)\:([^\r\n]*)\r?\n") do
    keyword = LrStringUtils.trimWhitespace(keyword)
    value = LrStringUtils.trimWhitespace(value)
    parsedTable[keyword] = value
    log("EXIF | Parsed '" .. keyword .. "' = '" .. value .. "'")
  end

  return parsedTable
end

--[[
-- Returns the first value of "keys" that could be found within the metaDataTable table
-- Ignores nil and "(none)" as valid values
-- metaDataTable - the medaData key/value table
-- keys - the keys to be search for in order of importance
--]]
function ExifUtils.findFirstMatchingValue(metaDataTable, keys)
  local value = nil

  for key, keyword in pairs(keys) do
    value = metaDataTable[keyword]
    if value == nil then
      log("EXIF | Searching for " .. keyword .. " [" .. string.gsub(keyword, "%s+", "") .. "] -> NIL")
    else
      log("EXIF | Searching for " .. keyword .. " [" .. string.gsub(keyword, "%s+", "") .. "] -> " .. value)
    end

    if value ~= nil and value ~= "(none)" then
      return value
    end
  end

  return nil
end

function ExifUtils.filterInput(str)
  --local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=-\\[\\]~`]", "?");
  -- FIXME: doesn't strip - or ] correctly
  local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=\\-\\[\\\n\\\t~`-]", "?");
  return result
end
