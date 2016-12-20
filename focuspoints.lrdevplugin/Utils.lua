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

local LrMobdebug = import 'LrMobdebug'
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

isDebug = true

exiftool = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftool = LrPathUtils.child(exiftool, "exiftool")
exiftool = LrPathUtils.child(exiftool, "exiftool")

function startDebug()
  if isDebug then
    LrMobdebug.start()
  end
end

function getExifCmd(targetPhoto) 
  
  local path = targetPhoto:getRawMetadata("path")
  local metaDataFile = LrPathUtils.removeExtension(path)
  metaDataFile = metaDataFile .. "-metadata.txt"
  
  local cmd = "'"..exiftool .. "' -a -u -g1 '" .. path .. "' > '" .. metaDataFile .. "'";
  return cmd, metaDataFile
  
end

function readMetaData(targetPhoto)
  local cmd, metaDataFile = getExifCmd(targetPhoto)
  LrTasks.execute(cmd)
  local fileInfo = LrFileUtils.readFile(metaDataFile)
  LrFileUtils.delete(metaDataFile)
  return fileInfo
end

function filterInput(str)
  --local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=-\\[\\]~`]", "?");
  -- FIXME: doesn't strip - or ] correctly
  local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=\\-\\[\\\n\\\t~`-]", "?");
  return result
end

function splitText(str, delim)
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

function log(str)
  myLogger:warn(str)
end

function parseDimens(strDimens) 
  local index = string.find(strDimens, "x")
  if (index == nill) then return nill end
  local w = string.sub(strDimens, 0, index-1)
  local h = string.sub(strDimens, index+1)
  w = LrStringUtils.trimWhitespace(w)
  h = LrStringUtils.trimWhitespace(h)
  return tonumber(w), tonumber(h)  
end