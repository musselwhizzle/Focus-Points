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
local LrSystemInfo = import "LrSystemInfo"

ExifUtils = {}
exiftool = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftool = LrPathUtils.child(exiftool, "exiftool")
exiftool = LrPathUtils.child(exiftool, "exiftool")

exiftoolWindows = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftoolWindows = LrPathUtils.child(exiftoolWindows, "exiftool.exe")

function ExifUtils.getExifCmd(targetPhoto)
  local path = targetPhoto:getRawMetadata("path")
  local metaDataFile = LrPathUtils.removeExtension(path)
  metaDataFile = metaDataFile .. "-metadata.txt"

  local cmd = "'".. exiftool .. "' -a -u -j '" .. path .. "' > '" .. metaDataFile .. "'";
  if (WIN_ENV) then
    cmd = "\"" .. exiftoolWindows .. "\" -a -u -j \"" .. path .. "\" > \"" .. metaDataFile .. "\"";
  end
  log("FILE | cmd: " .. cmd .. ", metaDataFile: " .. metaDataFile)

  return cmd, metaDataFile
end

function ExifUtils.readMetaData(targetPhoto)
  local cmd, metaDataFile = ExifUtils.getExifCmd(targetPhoto)
  LrTasks.execute(cmd)
  local fileInfo = LrFileUtils.readFile(metaDataFile)
  LrFileUtils.delete(metaDataFile)
  return fileInfo
end

function ExifUtils.findFirstMatchingValue(metaData, keys)
  local value = nil

  for key,keyword in pairs(keys) do
    value = metaData[string.gsub(keyword, "%s+", "")]
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
