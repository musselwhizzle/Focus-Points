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

--[[
  A collection of delegate functions to be passed into the DefaultPointRenderer when
  the camera is Fuji
--]]

local LrStringUtils = import 'LrStringUtils'
local LrView        = import 'LrView'

require "FocusPointPrefs"
require "FocusPointDialog"
require "Utils"
require "Log"


FujifilmDelegates = {}

-- Tag indicating that makernotes / AF section exists
-- Note: The very first Fujifilm makernotes entry is "Version", but using a text-based approach
--       to read ExifTool output this term is too generic. "Internal Serial Number" is a better choice.
FujifilmDelegates.metaKeyAfInfoSection               = "Internal Serial Number"

-- AF-relevant tags
FujifilmDelegates.metaKeyExifImageWidth              = "Exif Image Width"
FujifilmDelegates.metaKeyExifImageHeight             = "Exif Image Height"
FujifilmDelegates.metaKeyFocusMode                   = {"Focus Mode 2", "Focus Mode" }
FujifilmDelegates.metaKeyAfMode                      = {"AF Area Mode", "AF Mode" }
FujifilmDelegates.metaKeyAfAreaPointSize             = "AF Area Point Size"
FujifilmDelegates.metaKeyAfAreaZoneSize              = "AF Area Zone Size"
FujifilmDelegates.metaKeyFocusPixel                  = "Focus Pixel"
FujifilmDelegates.metaKeyAfSPriority                 = "AF-S Priority"
FujifilmDelegates.metaKeyAfCPriority                 = "AF-C Priority"
FujifilmDelegates.metaKeyFocusWarning                = "Focus Warning"
FujifilmDelegates.FacesDetected                      = "Faces Detected"
FujifilmDelegates.FacesPositions                     = "Faces Positions"
FujifilmDelegates.FaceElementTypes                   = "Face Element Types"
FujifilmDelegates.FaceElementPositions               = "Face Element Positions"
FujifilmDelegates.metaKeyPreAf                       = "Pre AF"
FujifilmDelegates.metaKeyAfCSetting                  = "AF-C Setting"
FujifilmDelegates.metaKeyAfCTrackingSensitivity      = "AF-C Tracking Sensitivity"
FujifilmDelegates.metaKeyAfCSpeedTrackingSensitivity = "AF-C Speed Tracking Sensitivity"
FujifilmDelegates.metaKeyAfCZoneAreaSwitching        = "AF-C Zone Area Switching"

-- Image and Shooting Information relevant tags
FujifilmDelegates.metaKeyCropMode                    = "Crop Mode"
FujifilmDelegates.metaKeyDriveMode                   = "Drive Mode"
FujifilmDelegates.metaKeyDriveSpeed                  = "Drive Speed"
FujifilmDelegates.metaKeySequenceNumber              = "Sequence Number"
FujifilmDelegates.metaKeyImageStabilization          = "Image Stabilization"

-- To control output of AF-C relevant settings
FujifilmDelegates.focusMode                          = ""

--[[
  @@public table FujiFilmDelegates.getAfPoints(table photo, table metaData)
  ----
  Get the autofocus points from metadata
--]]
function FujifilmDelegates.getAfPoints(photo, metaData)

  -- Search EXIF for the focus point key
  local focusPoint = ExifUtils.findValue(metaData, FujifilmDelegates.metaKeyFocusPixel)
  if focusPoint then
    Log.logInfo("Fujifilm",
      string.format("Focus point tag '%s' found", FujifilmDelegates.metaKeyFocusPixel, focusPoint))
  else
    Log.logError("Fujifilm",
      string.format("Focus point tag '%s' not found", FujifilmDelegates.metaKeyFocusPixel))
    return nil
  end

  local x, y
  local values = split(focusPoint, " ")
  if values then
    x = LrStringUtils.trimWhitespace(values[1])
    y = LrStringUtils.trimWhitespace(values[2])
  end
  if x == nil or y == nil then
    Log.logError("Fujifilm", "Error at extracting x/y positions from focus point tag")
    return nil
  end

  local imageWidth  = ExifUtils.findValue(metaData, FujifilmDelegates.metaKeyExifImageWidth)
  local imageHeight = ExifUtils.findValue(metaData, FujifilmDelegates.metaKeyExifImageHeight)
  if imageWidth == nil or imageHeight == nil then
    Log.logError("Fujifilm",
      string.format("No valid information on image width/height. Relevant tags '%s' / '%s' not found",
        FujifilmDelegates.metaKeyExifImageWidth, FujifilmDelegates.metaKeyExifImageHeight))
    Log.logWarn("Fujifilm", FocusInfo.msgImageFileNotOoc)
    FocusInfo.makerNotesFound = false
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  Log.logInfo("Fujifilm", "AF points detected at [" .. math.floor(x * xScale) .. ", " .. math.floor(y * yScale) .. "]")

  -- the only real focus point is this - the below code just checks for visualization frames
  FocusInfo.focusPointsDetected = true
  local result = DefaultPointRenderer.createFocusFrame(x*xScale, y*yScale)

  -- Let see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metaData, FujifilmDelegates.FacesDetected)
  if detectedFaces ~= nil and detectedFaces ~= "0" then
    local coordinatesStr = ExifUtils.findValue(metaData, FujifilmDelegates.FacesPositions)
    if coordinatesStr ~= nil then
      local coordinatesTable = split(coordinatesStr, " ")
      if coordinatesTable then
        for i=1, detectedFaces, 1 do
          local x1 = coordinatesTable[4 * (i-1) + 1] * xScale
          local y1 = coordinatesTable[4 * (i-1) + 2] * yScale
          local x2 = coordinatesTable[4 * (i-1) + 3] * xScale
          local y2 = coordinatesTable[4 * (i-1) + 4] * yScale
          Log.logInfo("Fujifilm", "Face detected at [" .. math.floor((x1 + x2) / 2) .. ", " .. math.floor((y1 + y2) / 2) .. "]")
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_FACE,
            x = (x1 + x2) / 2,
            y = (y1 + y2) / 2,
            width = math.abs(x1 - x2),
            height = math.abs(y1 - y2)
          })
        end
      end
    end
  end

--[[
  Modified by Andy Lawrence AKA Greybeard to add visual representation of Fujifilm subject tracking
  Requires Exiftool minimum version 12.44
  (23rd August 2022)
--]]
  -- Subject detection
  local coordinatesStr = ExifUtils.findValue(metaData, FujifilmDelegates.FaceElementPositions)
  if coordinatesStr ~= nil then
    local coordinatesTable = split(coordinatesStr, " ")
    if coordinatesTable ~= nil then
      local objectCount = #(coordinatesTable) / 4
      for i=1, objectCount, 1 do
        local x1 = coordinatesTable[4 * (i-1) + 1] * xScale
        local y1 = coordinatesTable[4 * (i-1) + 2] * yScale
        local x2 = coordinatesTable[4 * (i-1) + 3] * xScale
        local y2 = coordinatesTable[4 * (i-1) + 4] * yScale
        Log.logInfo("Fujifilm", "Subject detected at [" .. math.floor((x1 + x2) / 2) .. ", " .. math.floor((y1 + y2) / 2) .. "]")
        table.insert(result.points, {
          pointType = DefaultDelegates.POINTTYPE_FACE,
          x = (x1 + x2) / 2,
          y = (y1 + y2) / 2,
          width = math.abs(x1 - x2),
          height = math.abs(y1 - y2)
        })
      end
    end
  end

--[[
  Modified by Andy Lawrence AKA Greybeard to add visual representation of Fujifilm tele-converter crop area
  Requires Exiftool minimum version 12.82
  (8th April 2024)
--]]
  -- Digital Tele-converter crop area
  local cropsizeStr = ExifUtils.findValue(metaData,  "Crop Size")
  local croptopleftStr = ExifUtils.findValue(metaData, "Crop Top Left")
  if cropsizeStr ~= nil then
    local cropsizeTable = split(cropsizeStr, " ")
    if cropsizeTable ~= nil then
      if croptopleftStr ~= nil then
        local croptopleftTable = split(croptopleftStr, " ")
        if croptopleftTable ~= nil then
          local x1 = croptopleftTable[1] * xScale
          local y1 = croptopleftTable[2] * yScale
          local x2 = (cropsizeTable[1]+croptopleftTable[1]) * xScale
          local y2 = (cropsizeTable[2]+croptopleftTable[2]) * yScale
          Log.logInfo("Fujifilm", "Crop area at [" .. math.floor((x1 + x2) / 2) .. ", " .. math.floor((y1 + y2) / 2) .. "]")
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_CROP,
            x = (x1 + x2) / 2,
            y = (y1 + y2) / 2,
            width = math.abs(x1 - x2),
            height = math.abs(y1 - y2)
          })
        end
      end
    end
  end
  return result
end


--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table FujifilmDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
function FujifilmDelegates.addInfo(title, key, props, metaData)
  local f = LrView.osFactory()

  -- Helper function to create and populate the property corresponding to metadata key
  local function populateInfo(key)
    local value
    if type(key) == "string" then
      value = ExifUtils.findValue(metaData, key)
    else
      -- type(key) == "table"
      value = ExifUtils.findFirstMatchingValue(metaData, key)
    end
    if (value == nil) then
      props[key] = ExifUtils.metaValueNA
    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if props[key] and props[key] ~= ExifUtils.metaValueNA then
    -- compose the row to be added
    local result = f:row {
      f:column{f:static_text{title = title .. ":", font="<system>"}},
      f:spacer{fill_horizontal = 1},
      f:column{f:static_text{title = wrapText(props[key], {','},30), font="<system>"}}
    }
    -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
    if (props[key] == "AF-C") then
      return f:column{
        fill = 1, spacing = 2, result,
        FujifilmDelegates.addInfo("AF-C Priority", FujifilmDelegates.metaKeyAfCPriority, props, metaData) }

    elseif (props[key] == "AF-S") then
      return f:column{
        fill = 1, spacing = 2, result,
        FujifilmDelegates.addInfo("AF-S Priority", FujifilmDelegates.metaKeyAfSPriority, props, metaData) }

    elseif key == FujifilmDelegates.metaKeyAfMode and props[key] == "Single Point" then
      return f:column{
        fill = 1, spacing = 2, result,
        FujifilmDelegates.addInfo("AF Area Point Size", FujifilmDelegates.metaKeyAfAreaPointSize, props, metaData) }

    elseif key == FujifilmDelegates.metaKeyAfMode and props[key] == "Zone" then
      return f:column{
        fill = 1, spacing = 2, result,
        FujifilmDelegates.addInfo("AF Area Zone Size", FujifilmDelegates.metaKeyAfAreaZoneSize, props, metaData) }

    elseif key == FujifilmDelegates.metaKeyDriveSpeed then
      return f:column{
        fill = 1, spacing = 2, result,
        FujifilmDelegates.addInfo("Sequence Number", FujifilmDelegates.metaKeySequenceNumber, props, metaData) }

    elseif ((key == FujifilmDelegates.metaKeyAfCSetting) or
            (key == FujifilmDelegates.metaKeyAfCTrackingSensitivity) or
            (key == FujifilmDelegates.metaKeyAfCSpeedTrackingSensitivity) or
            (key == FujifilmDelegates.metaKeyAfCZoneAreaSwitching))
                and FujifilmDelegates.focusMode ~= "AF-C" then
      -- these settings are not relevant for focus modes than AF-C
      return FocusInfo.emptyRow()

    elseif key == FujifilmDelegates.FacesDetected and props[key] == "0"
        or key == FujifilmDelegates.metaKeyPreAf  and props[key] == "Off" then
      -- omit tags with irrelevant values
      return FocusInfo.emptyRow()

    else
      -- add row as composed
      return result
    end
  else
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end
end


--[[
  @@public boolean FujifilmDelegates.modelSupported(string model)
  ----
  Returns whether the given camera model is supported or not
--]]
function FujifilmDelegates.modelSupported(_model)
  -- supports entire X-, GFX-series and FinePix after 2007
  -- so there is not really anything that justifies the effort to write code to exclude ancient models
  return true
end


--[[
  @@public boolean FujifilmDelegates.makerNotesFound(table photo, table metaData)
  ----
  Returns whether the current photo has metadata with makernotes AF information included
--]]
function FujifilmDelegates.makerNotesFound(_photo, metaData)
  local result = ExifUtils.findValue(metaData, FujifilmDelegates.metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Fujifilm",
      string.format("Tag '%s' not found", FujifilmDelegates.metaKeyAfInfoSection))
  end
  return (result ~= nil)
end


--[[
  @@public boolean FujifilmDelegates.manualFocusUsed(table photo, table metaData)
  ----
  Returns whether manual focus has been used on the given photo
--]]
function FujifilmDelegates.manualFocusUsed(_photo, metaData)
  local focusMode, key = ExifUtils.findFirstMatchingValue(metaData, FujifilmDelegates.metaKeyFocusMode)
  FujifilmDelegates.focusMode = focusMode
  Log.logInfo("Fujifilm",
    string.format("Tag '%s' found: %s", key, focusMode))
  return (focusMode == "Manual" or focusMode == "AF-M")
end


--[[
  @@public table function FujifilmDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function FujifilmDelegates.getImageInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local imageInfo
  imageInfo = f:column {
    fill = 1,
    spacing = 2,
    FujifilmDelegates.addInfo("Crop mode", FujifilmDelegates.metaKeyCropMode, props, metaData),
  }
  return imageInfo
end


--[[
  @@public table function FujifilmDelegates.getShootingInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Shooting Information" section
  -- if any, otherwise return an empty column
--]]
function FujifilmDelegates.getShootingInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,

    FujifilmDelegates.addInfo("Image Stabilization", FujifilmDelegates.metaKeyImageStabilization, props, metaData),
    FujifilmDelegates.addInfo("Drive Mode", FujifilmDelegates.metaKeyDriveMode, props, metaData),
    FujifilmDelegates.addInfo("Drive Speed", FujifilmDelegates.metaKeyDriveSpeed, props, metaData),
  }
  return shootingInfo
end


--[[
  @@public table FujifilmDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function FujifilmDelegates.getFocusInfo(_photo, props, metaData)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FujifilmDelegates.addInfo("Focus Mode",                       FujifilmDelegates.metaKeyFocusMode                    , props, metaData),
      FujifilmDelegates.addInfo("AF Mode",                          FujifilmDelegates.metaKeyAfMode                       , props, metaData),
      FujifilmDelegates.addInfo("Focus Warning",                    FujifilmDelegates.metaKeyFocusWarning                 , props, metaData),
      FujifilmDelegates.addInfo("Pre AF",                           FujifilmDelegates.metaKeyPreAf                        , props, metaData),
      FujifilmDelegates.addInfo("Faces Detected",                   FujifilmDelegates.FacesDetected                       , props, metaData),
      FujifilmDelegates.addInfo("Subject Element Types",            FujifilmDelegates.FaceElementTypes                    , props, metaData),
      FujifilmDelegates.addInfo("AF-C Setting",                     FujifilmDelegates.metaKeyAfCSetting                   , props, metaData),
      FujifilmDelegates.addInfo("- Tracking Sensitivity",        FujifilmDelegates.metaKeyAfCTrackingSensitivity       , props, metaData),
      FujifilmDelegates.addInfo("- Speed Tracking Sensitivity",  FujifilmDelegates.metaKeyAfCSpeedTrackingSensitivity  , props, metaData),
      FujifilmDelegates.addInfo("- Zone Area Switching",         FujifilmDelegates.metaKeyAfCZoneAreaSwitching         , props, metaData),
      }
  return focusInfo
end
