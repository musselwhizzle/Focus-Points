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

local LrTasks       = import 'LrTasks'
local LrFileUtils   = import 'LrFileUtils'
local LrPathUtils   = import 'LrPathUtils'
local LrStringUtils = import "LrStringUtils"
local LrErrors      = import "LrErrors"

require "Utils"
require "Log"


ExifUtils = {}
exiftool = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftool = LrPathUtils.child(exiftool, "exiftool")
exiftool = LrPathUtils.child(exiftool, "exiftool")

exiftoolWindows = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftoolWindows = LrPathUtils.child(exiftoolWindows, "exiftool.exe")

metaDataFile = getTempFileName()


function ExifUtils.getMetaDataFile()
  return metaDataFile
end


function ExifUtils.filterInput(str)
  local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=-\\[\\]~`]", "?");
  return result
end


function ExifUtils.getExifCmd(targetPhoto)
  local path = targetPhoto:getRawMetadata("path")
  local singleQuoteWrap = '\'"\'"\''
  local cmd
  if WIN_ENV then
    -- windows needs " around the entire command and then " around each path
    -- example: ""C:\Users\Joshua\Desktop\Focus Points\focuspoints.lrdevplugin\bin\exiftool.exe" -a -u -sort "C:\Users\Joshua\Desktop\DSC_4636.NEF" > "C:\Users\Joshua\Desktop\DSC_4636-metadata.txt""
    cmd = '""' .. exiftoolWindows .. '" -a -u -sort ' .. '"'.. path .. '" > "' .. metaDataFile .. '""'
  else
    exiftool = string.gsub(exiftool, "'", singleQuoteWrap)
    path = string.gsub(path, "'", singleQuoteWrap)
    cmd = "'".. exiftool .. "' -a -u -sort '" .. path .. "' > '" .. metaDataFile .. "'"
  end

  return cmd, metaDataFile
end


function ExifUtils.readMetaData(targetPhoto)
  local cmd, metaDataFile = ExifUtils.getExifCmd(targetPhoto)
  local rc = LrTasks.execute(cmd)
  Log.logDebug("ExifUtils", "ExifTool command: " .. cmd)
  if rc ~= 0 then
    local errorText = "Unable to read photo metadata (ExifTool rc=" .. rc .. ")"
    Log.logError("ExifUtils", errorText)
    errorMessage(errorText)
    LrErrors.throwUserError("Fatal Error. Plugin execution stopped")
    -- LrErrors.throwUserError(getPhotoFileName(targetPhoto) .. "\nFATAL error reading metadata (ExifTool rc=" .. rc .. ")")
  else
    local fileInfo = LrFileUtils.readFile(metaDataFile)
    return fileInfo
  end
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
    Log.logFull("ExifUtils", "Parsed '" .. keyword .. "' = '" .. value .. "'")
  end

  return parsedTable
end


--[[
-- Returns the value of "exifTag" within the metaDataTable table
-- Ignores nil and "(none)" and "n/a" as valid values
-- metaDataTable - the medaData key/value table
-- exifTag - the tag to be searched for
-- return value of the tag
--]]
function ExifUtils.findValue(metaDataTable, exifTag)
  if exifTag then
    for t, v in pairs(metaDataTable) do
      -- search for exact match
      if (t == exifTag) then
        -- even though we don't return them as a result, we'll log (none) and n/a entries
        Log.logDebug("ExifUtils", "Searching for " .. exifTag .. " -> " .. v)
        if v and (string.lower(v) ~= "(none)") and (string.lower(v) ~= "n/a") then
          -- this is the only way out with a result!
          return v
        end
      end
    end
    Log.logDebug("ExifUtils", "Searching for " .. exifTag .. " returned nothing")
  end
  return nil
end


-- Returns the first value of "keys" that could be found within the metaDataTable table
-- Ignores nil and "(none)" as valid values
-- metaData - the medaData key/value table
-- keys - the keys to be search for in order of importance
-- return 1. value of the first key match, 2. which key was used
--]]
function ExifUtils.findFirstMatchingValue(metaData, keys)
  local exifValue
  for key, value in pairs(keys) do          -- value in the keys table is the current exif keyword to be searched
    exifValue = metaData[value]
    if exifValue and (string.lower(exifValue) ~= "(none)") and (string.lower(exifValue) ~= "n/a") then
      Log.logDebug("ExifUtils", "Searching for " .. value .. " -> " .. exifValue)
      return exifValue, keys[key]
    end
  end
  Log.logDebug("ExifUtils", "Searching for { " .. table.concat(keys, " ") .. " } returned nothing")
  return nil
end


--[[
  @@public boolean function getBinaryValue(table photo, string key)
  Retrieves the value for an EXIF tag in binary mode.
  Useful for tags, where ExifTool produces a simplified or shortened output,
  e.g. AFPointSelected or FaceDetectArea for Olympus cameras
--]]
function ExifUtils.getBinaryValue(photo, key)
  local path = photo:getRawMetadata("path")
  local output = getTempFileName()
  local singleQuoteWrap = '\'"\'"\''
  local cmd, result

  if key then
    -- Compose the command line string
    -- Unlike searching the ExifTool listing output, when asking for a specific key its name must have no blanks
    key = string.gsub(key, " ", "")
    if WIN_ENV then
      -- windows needs " around the entire command and then " around each path
      cmd = '""' .. exiftoolWindows .. '" -b -' .. key .. ' "' .. path .. '" > "' .. output .. '""'
    else
      exiftool = string.gsub(exiftool, "'", singleQuoteWrap)
      path = string.gsub(path, "'", singleQuoteWrap)
      cmd = "'" .. exiftool .. "' -b -" .. key .. " '" .. path .. "' > '" .. output .. "'"
    end

    -- Call ExifTool to output key's value in binary format
    local rc = LrTasks.execute(cmd)
    if (rc == 0) then
      -- Read redirected stdout from temp file to save output
      result = LrFileUtils.readFile(output)
      Log.logDebug("ExifUtils", "Binary mode (-b) value for " .. key .. " -> " .. result)
    else
      Log.logDebug("ExifUtils", "ExifTool command failed (rc=" .. rc ..") : " .. cmd)
    end
    -- Clean up: remove the temp file
    if LrFileUtils.exists(output) and not LrFileUtils.delete(output) then
      Log.logWarn("Utils", "Unable to delete ExifTool output file " .. output)
    end
  end
  return result
end


--[[
  @@public boolean function ExifUtils.decodeXmpMWGRegions(table result, table metaData)
  ----
  Decodes a region scheme according to XMP MWG specification.
  Tags are expected in "metaData" table
  Returns whether regions have been found. Areas to be visualized are returnd "result" focus points table.
--]]
function ExifUtils.decodeXmpMWGRegions(result, metaData)

  local focusDetected = false

  -- Region detection
  local regionTypeStr = ExifUtils.findValue(metaData, "Region Type")
  if regionTypeStr then
    -- Region scheme present, decode individual tags
    local regionType          = split(regionTypeStr, ", ")
    local regionAreaX         = split(ExifUtils.findValue(metaData, "Region Area X"), ", ")
    local regionAreaY         = split(ExifUtils.findValue(metaData, "Region Area Y"), ", ")
    local regionAreaW         = split(ExifUtils.findValue(metaData, "Region Area W"), ", ")
    local regionAreaH         = split(ExifUtils.findValue(metaData, "Region Area H"), ", ")
    local regionAppliedToDimW = ExifUtils.findValue(metaData, "Region Applied To Dimensions W")
    local regionAppliedToDimH = ExifUtils.findValue(metaData, "Region Applied To Dimensions H")

    if (regionType and regionAreaX and regionAreaY and regionAreaW and regionAreaH) then
      for i=1, #regionType, 1 do
        -- Scale the normalized region coordinates
        local x = regionAreaX[i] * regionAppliedToDimW
        local y = regionAreaY[i] * regionAppliedToDimH
        local w = regionAreaW[i] * regionAppliedToDimW
        local h = regionAreaH[i] * regionAppliedToDimH
        Log.logInfo("XMP-mwg-Regions",
         string.format("'%s' region detected at [x:%s, y:%s, w:%s, h:%s]",
            regionType[i], math.floor(x), math.floor(y), math.floor(w), math.floor(h)))
        -- Determine the region type and handle accordingly
        local pointType
        if (string.lower(regionType[i]) == "face") or (string.lower(regionType[i]) == "pet") then
          pointType = DefaultDelegates.POINTTYPE_FACE
          -- make detection frame slightly bigger to avoid complete overlap with focus frame
          w = w * 1.04
          h = h * 1.04
        elseif string.lower(regionType[i]) == "focus" then
          pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
          focusDetected = true
        else
          Log.logError("XMP-mwg-Regions",
            string.format("Unexpteced region type '%s' encountered.", regionType[i]))
        end
        -- Add region frame to focus point table
        if pointType then
          table.insert(result.points, {
            pointType = pointType,
            x = x,
            y = y,
            width = w,
            height = h
          })
        end
      end
    else
      Log.logError("XMP-mwg-Regions",
        string.format("Inconistent region scheme definitions encountered."))
    end
  end
  return focusDetected
end
