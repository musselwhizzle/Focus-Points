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

function ExifUtils.filterInput(str)
  --local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=-\\[\\]~`]", "?");
  -- FIXME: doesn't strip - or ] correctly
  local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=\\-\\[\\\n\\\t~`-]", "?");
  return result
end

function ExifUtils.findValue(metaData, key)
  local parts = ExifUtils.createParts(metaData)
  local labels = ""
  local values = ""
  for k in pairs(parts) do
    local l = parts[k].key
    local v = parts[k].value
    if (l == nill) then l = "" end
    if (v == nill) then v = "" end
    l = LrStringUtils.trimWhitespace(l)
    v = LrStringUtils.trimWhitespace(v)
    if (key == l) then
      return v
    end
  end

  return nil
end

function ExifUtils.findFirstMatchingValue(metaData, keys)
  local value = nil

  for key,keyword in pairs(keys) do
    value = ExifUtils.findValue(metaData, keyword)

    if value ~= nil and value ~= "(none)" then
      return value
    end
  end

  return nil
end

function ExifUtils.splitForColumns(metaData)
  local parts = ExifUtils.createParts(metaData)
  local labels = ""
  local values = ""
  for k in pairs(parts) do
    local l = parts[k].key
    local v = parts[k].value
    if (l == nill) then l = "" end
    if (v == nill) then v = "" end
    l = LrStringUtils.trimWhitespace(l)
    v = LrStringUtils.trimWhitespace(v)

    labels = labels .. l .. "\r"
    values = values .. v .. "\r"
  end
  return labels, values

end

function ExifUtils.createParts(metaData)
  local parts = {}
  local num = 0;
  for i in string.gmatch(metaData, "[^\\\n]+") do
    p = splitToKeyValue(i, ":")
    if (p ~= nill) then
      parts[num] = p
      num = num+1
    end
  end
  return parts
end
