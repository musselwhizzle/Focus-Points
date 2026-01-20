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
  ExifUtils.lua

  Purpose of this module:
  Helper functions to
  - Read metadata from file using ExifTool
  - Process and parse metadata

------------------------------------------------------------------------------]]
local ExifUtils = {}

-- Imported LR namespaces
local LrErrors          = import  'LrErrors'
local LrFileUtils       = import  'LrFileUtils'
local LrPathUtils       = import  'LrPathUtils'
local LrStringUtils     = import  'LrStringUtils'
local LrTasks           = import  'LrTasks'

-- Required Lua definitions
local DefaultDelegates  = require 'DefaultDelegates'
local Log               = require 'Log'
local _strict           = require 'strict'
local Utils             = require 'Utils'

ExifUtils.metaValueNA   = "N/A"

-- Local variables -------------------------------------------------------------
local exiftool           = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftool                 = LrPathUtils.child(exiftool, "exiftool")
exiftool                 = LrPathUtils.child(exiftool, "exiftool")

local exiftoolWindows    = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftoolWindows          = LrPathUtils.child(exiftoolWindows, "exiftool.exe")

local exiftoolConfigFile = LrPathUtils.child( _PLUGIN.path, "ExifTool.config" )

local metadataFileName   = Utils.getTempFileName()

--[[----------------------------------------------------------------------------
  public string
  getPhotoFileName(table photo)

  Retrieve the name of the current photo, used by centralized error handling
------------------------------------------------------------------------------]]
function ExifUtils.getMetadataFileName()
  return metadataFileName
end

--[[----------------------------------------------------------------------------
  public string
  getPhotoFileName(table photo)

  Retrieve the name of the current photo, used by centralized error handling
------------------------------------------------------------------------------]]
function ExifUtils.filterInput(str)
  local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=-\\[\\]~`]", "?");
  return result
end

--[[----------------------------------------------------------------------------
@TODO
  public string cmd, string outputFileName
  getPhotoFileName(table photo)

  Depending on the OS (WIN or MAC), the ExifTool command line is built to read
  metadata from the photo's image file and write the output to a text file.
  Returns the command line string and the name of the output file.
------------------------------------------------------------------------------]]
local function getExifCmd(targetPhoto)
  local path = targetPhoto:getRawMetadata("path")
  local singleQuoteWrap = '\'"\'"\''
  local options = '-a -u -sort --XMP-crs:all --XMP-crss:all'
  local cmd
  if WIN_ENV then
    -- WIN needs " around the entire command and then " around each path
    -- Example: ""C:\Users\Joshua\Desktop\Focus Points\focuspoints.lrdevplugin\bin\exiftool.exe" -a -u -sort "C:\Users\Joshua\Desktop\DSC_4636.NEF" > "C:\Users\Joshua\Desktop\DSC_4636-metadata.txt""
--  cmd = '""' .. exiftoolWindows .. '"' .. config ..  '"' .. exiftoolConfigFile .. '"' .. options .. '"'.. path .. '" > "' .. metadataFileName .. '""'
    cmd = string.format(
      '""%s" -config "%s" %s "%s" > "%s""',
      exiftoolWindows, exiftoolConfigFile, options, path, metadataFileName)
  else
    exiftool           = string.gsub(exiftool,           "'", singleQuoteWrap)
    exiftoolConfigFile = string.gsub(exiftoolConfigFile, "'", singleQuoteWrap)
    path               = string.gsub(path,               "'", singleQuoteWrap)
--  cmd = "'".. exiftool .. "'" .. options .. "'" .. path .. "' > '" .. metadataFileName .. "'"
    cmd = string.format(
      "'%s' -config '%s' %s '%s' > '%s'",
      exiftool, exiftoolConfigFile, options, path, metadataFileName)
  end

  return cmd, metadataFileName
end

--[[----------------------------------------------------------------------------
  public string
  readMetadata(table photo)

  Use the ExifTool command to read the metadata from the image file and write the
  output to a text file.
  Returns the output as string.
------------------------------------------------------------------------------]]
function ExifUtils.readMetadata(targetPhoto)
  local cmd, outputFileName = getExifCmd(targetPhoto)
  local rc = LrTasks.execute(cmd)

  -- Avoid Windows process queue saturation
  if WIN_ENV then
      LrTasks.sleep(0.02)
      LrTasks.yield()
  end

  Log.logDebug("ExifUtils", "ExifTool command: " .. cmd)
  if rc ~= 0 then
    -- something went wrong
    local errorText = "FATAL error: unable to read photo metadata (ExifTool rc=" .. rc .. ")"
    Log.logError("ExifUtils", errorText)
    LrErrors.throwUserError(
      string.format("%s\n\n%s", Utils.getPhotoFileName(targetPhoto), errorText))
  else
    local fileInfo = LrFileUtils.readFile(outputFileName)
    return fileInfo
  end
end

--[[----------------------------------------------------------------------------
  public table
  readMetadataAsTable(table photo)

  Transforms the output of readMetadata() and returns a key/value table
------------------------------------------------------------------------------]]
function ExifUtils.readMetadataAsTable(targetPhoto)
  local metadata = ExifUtils.readMetadata(targetPhoto)
  if metadata == nil then
    return nil
  end

  local parsedTable = {}

  for keyword, value in string.gmatch(metadata, "([^\:]+)\:([^\r\n]*)\r?\n") do
    keyword = LrStringUtils.trimWhitespace(keyword)
    value = LrStringUtils.trimWhitespace(value)
    parsedTable[keyword] = value
    Log.logFull("ExifUtils", "Parsed '" .. keyword .. "' = '" .. value .. "'")
  end

  return parsedTable
end

--[[----------------------------------------------------------------------------
  public string
  findValue(table metadata, string key)

  Returns the value of "key" within the metadata table.
  Ignores nil and "(none)" and "n/a" as valid values.
  metadataTable - the metadata key/value table
  key - the tag name to be searched for
  Returns value of the tag
------------------------------------------------------------------------------]]
function ExifUtils.findValue(metadata, key)
  if key then
    for k, v in pairs(metadata) do
      -- search for exact match
      if (k == key) then
        -- even though we don't return them as a result, we'll log (none) and n/a entries
        Log.logDebug("ExifUtils", "Searching for " .. key .. " -> " .. v)
        if v and (string.lower(v) ~= "(none)") and (string.lower(v) ~= "n/a") then
          -- this is the only way out with a result!
          return v
        end
      end
    end
    Log.logDebug("ExifUtils", "Searching for " .. key .. " returned nothing")
  end
  return nil
end

--[[----------------------------------------------------------------------------
  public string
  findFirstMatchingValue(metadata, keys)

  Returns the first value of "keys" that could be found within the metadata table.
  Ignores nil and "(none)" as valid values.
  metadata - the metadata key/value table
  keys - the keys to be search for in order of importance
  return 1. value of the first key match, 2. which key was used
------------------------------------------------------------------------------]]
function ExifUtils.findFirstMatchingValue(metadata, keys)
  local exifValue
  for key, value in pairs(keys) do          -- value in the keys table is the current exif keyword to be searched
    exifValue = metadata[value]
    if exifValue and (string.lower(exifValue) ~= "(none)") and (string.lower(exifValue) ~= "n/a") then
      Log.logDebug("ExifUtils", "Searching for " .. value .. " -> " .. exifValue)
      return exifValue, keys[key]
    end
  end
  Log.logDebug("ExifUtils", "Searching for { " .. table.concat(keys, " ") .. " } returned nothing")
  return nil
end

--[[----------------------------------------------------------------------------
  public string
  getBinaryValue(table photo, string key)

  Retrieves the value for an EXIF tag in binary mode.
  Useful for tags, where ExifTool produces a simplified or shortened output,
  e.g. AFPointSelected or FaceDetectArea for Olympus cameras

  Note: This function requires a separate call to ExifTool, which affects runtime performance.
------------------------------------------------------------------------------]]
function ExifUtils.getBinaryValue(photo, key)
  local path = photo:getRawMetadata("path")
  local output = Utils.getTempFileName()
  local singleQuoteWrap = '\'"\'"\''
  local cmd, result

  if key then
    -- Compose the command line string
    -- Unlike searching the ExifTool listing output, when asking for a specific key its name must have no blanks
    key = string.gsub(key, " ", "")
    if WIN_ENV then
      -- windows needs " around the entire command and then " around each path
      cmd = '""' .. exiftoolWindows .. '" -u -b -' .. key .. ' "' .. path .. '" > "' .. output .. '""'
    else
      exiftool = string.gsub(exiftool, "'", singleQuoteWrap)
      path = string.gsub(path, "'", singleQuoteWrap)
      cmd = "'" .. exiftool .. "' -u -b -" .. key .. " '" .. path .. "' > '" .. output .. "'"
    end

    -- Call ExifTool to output key's value in binary format
    local rc = LrTasks.execute(cmd)

    -- Avoid Windows process queue saturation
    if WIN_ENV then
        LrTasks.sleep(0.02)
        LrTasks.yield()
    end

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

--[[----------------------------------------------------------------------------
  public void
  cleanup()

  Delete the temporary file (metadata output file created by ExifTool)
------------------------------------------------------------------------------]]
function ExifUtils.cleanup()
  if LrFileUtils.exists(metadataFileName) then
    local _resultOK, errorMsg = LrFileUtils.delete( metadataFileName )
    if errorMsg ~= nil then
      Log.logWarn(string.format(
        'ExifUtils', "Error deleting metadata temp file %s: %s",  metadataFileName, errorMsg))
    end
  end
end

--[[----------------------------------------------------------------------------
  public boolean
  decodeXmpMWGRegions(table pointsTable, table metadata)

  Decodes a region scheme according to XMP MWG specification.
  Tags are expected in metadata table
  Returns whether regions have been found.
  Areas to be visualized are returned in pointsTable.
------------------------------------------------------------------------------]]
function ExifUtils.decodeXmpMWGRegions(pointsTable, metadata)

  local focusDetected = false

  -- Region detection
  local regionTypeStr = ExifUtils.findValue(metadata, "Region Type")
  if regionTypeStr then
    -- Region scheme present, decode individual tags
    local regionType          = Utils.split(regionTypeStr, ", ")
    local regionAreaX         = Utils.split(ExifUtils.findValue(metadata, "Region Area X"), ", ")
    local regionAreaY         = Utils.split(ExifUtils.findValue(metadata, "Region Area Y"), ", ")
    local regionAreaW         = Utils.split(ExifUtils.findValue(metadata, "Region Area W"), ", ")
    local regionAreaH         = Utils.split(ExifUtils.findValue(metadata, "Region Area H"), ", ")
    local regionAppliedToDimW = ExifUtils.findValue(metadata, "Region Applied To Dimensions W")
    local regionAppliedToDimH = ExifUtils.findValue(metadata, "Region Applied To Dimensions H")

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
          table.insert(pointsTable.points, {
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
        string.format("Inconsistent region scheme definitions encountered"))
    end
  end
  return focusDetected
end

return ExifUtils -- ok
