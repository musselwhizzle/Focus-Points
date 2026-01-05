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
  FujifilmDelegates.lua

  Purpose of this module:
  A collection of delegate functions to be passed into the DefaultPointRenderer when
  the camera is Fuji:

  - funcModelSupported:    Does this plugin support the camera model?
  - funcMakerNotesFound:   Does the photo metadata include maker notes?
  - funcManualFocusUsed:   Was the current photo taken using manual focus?
  - funcGetAfPoints:       Provide data for visualizing focus points, faces etc.
  - funcGetImageInfo:      Provide specific information to be added to the 'Image Information' section.
  - funcGetShootingInfo:   Provide specific information to be added to the 'Shooting Information' section.
  - funcGetFocusInfo:      Provide the information to be entered into the 'Focus Information' section.
------------------------------------------------------------------------------]]
local FujifilmDelegates = {}

-- Imported LR namespaces
local LrStringUtils        = import  'LrStringUtils'
local LrView               = import  'LrView'

-- Required Lua definitions
local DefaultDelegates     = require 'DefaultDelegates'
local DefaultPointRenderer = require 'DefaultPointRenderer'
local ExifUtils            = require 'ExifUtils'
local FocusInfo            = require 'FocusInfo'
local Log                  = require 'Log'
local _strict              = require 'strict'
local Utils                = require 'Utils'

-- Tag indicating that makernotes / AF section exists
-- Note: The very first Fujifilm makernotes entry is "Version", but using a text-based approach
--       to read ExifTool output this term is too generic. "Internal Serial Number" is a better choice.
local metaKeyAfInfoSection               = "Internal Serial Number"

-- AF-relevant tags
local metaKeyExifImageWidth              = "Exif Image Width"
local metaKeyExifImageHeight             = "Exif Image Height"
local metaKeyFocusMode                   = {"Focus Mode 2", "Focus Mode" }
local metaKeyAfMode                      = {"AF Area Mode", "AF Mode" }
local metaKeyAfAreaPointSize             = "AF Area Point Size"
local metaKeyAfAreaZoneSize              = "AF Area Zone Size"
local metaKeyFocusPixel                  = "Focus Pixel"
local metaKeyAfSPriority                 = "AF-S Priority"
local metaKeyAfCPriority                 = "AF-C Priority"
local metaKeyFocusWarning                = "Focus Warning"
local FacesDetected                      = "Faces Detected"
local FacesPositions                     = "Faces Positions"
local FaceElementTypes                   = "Face Element Types"
local FaceElementPositions               = "Face Element Positions"
local metaKeyPreAf                       = "Pre AF"
local metaKeyAfCSetting                  = "AF-C Setting"
local metaKeyAfCTrackingSensitivity      = "AF-C Tracking Sensitivity"
local metaKeyAfCSpeedTrackingSensitivity = "AF-C Speed Tracking Sensitivity"
local metaKeyAfCZoneAreaSwitching        = "AF-C Zone Area Switching"

-- Image and Shooting Information relevant tags
local metaKeyCropMode                    = "Crop Mode"
local metaKeyDriveMode                   = "Drive Mode"
local metaKeyDriveSpeed                  = "Drive Speed"
local metaKeySequenceNumber              = "Sequence Number"
local metaKeyImageStabilization          = "Image Stabilization"

--[[----------------------------------------------------------------------------
  public table
  getAfPoints(table photo, table metadata)

  Retrieve the autofocus points from the metadata of the photo.
------------------------------------------------------------------------------]]
function FujifilmDelegates.getAfPoints(photo, metadata)

  -- Search EXIF for the focus point key
  local focusPoint = ExifUtils.findValue(metadata, metaKeyFocusPixel)
  if focusPoint then
    Log.logInfo("Fujifilm",
      string.format("Focus point tag '%s' found", metaKeyFocusPixel, focusPoint))
  else
    Log.logError("Fujifilm",
      string.format("Focus point tag '%s' not found", metaKeyFocusPixel))
    return nil
  end

  local x, y
  local values = Utils.split(focusPoint, " ")
  if values then
    x = LrStringUtils.trimWhitespace(values[1])
    y = LrStringUtils.trimWhitespace(values[2])
  end
  if x == nil or y == nil then
    Log.logError("Fujifilm", "Error at extracting x/y positions from focus point tag")
    return nil
  end

  --[[
     The ExifImageWidth and ExifImageHeight values in the Exif IFD section define the coordinate system
     to which FocusPixel relates. For RAF files, these values indicate the dimensions of the embedded
     JPEG image. This information may be lost during the processing or conversion of the RAF image to DNG.
  --]]
  local imageWidth  = ExifUtils.findValue(metadata, metaKeyExifImageWidth)
  local imageHeight = ExifUtils.findValue(metadata, metaKeyExifImageHeight)
  if imageWidth == nil or imageHeight == nil then
    Log.logError("Fujifilm",
      string.format("No valid information on image width/height. Relevant tags '%s' / '%s' not found",
        metaKeyExifImageWidth, metaKeyExifImageHeight))
    Log.logWarn("Fujifilm", FocusInfo.msgImageFileNotOoc)
    FocusInfo.makerNotesFound = false
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo, metadata)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  Log.logInfo("Fujifilm", "AF points detected at [" .. math.floor(x * xScale) .. ", " .. math.floor(y * yScale) .. "]")

  -- the only real focus point is this - the below code just checks for visualization frames
  FocusInfo.focusPointsDetected = true
  local result = DefaultPointRenderer.createFocusFrame(x*xScale, y*yScale)

  -- Let see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metadata, FacesDetected)
  if detectedFaces ~= nil and detectedFaces ~= "0" then
    local coordinatesStr = ExifUtils.findValue(metadata, FacesPositions)
    if coordinatesStr ~= nil then
      local coordinatesTable = Utils.split(coordinatesStr, " ")
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
  local coordinatesStr = ExifUtils.findValue(metadata, FaceElementPositions)
  if coordinatesStr ~= nil then
    local coordinatesTable = Utils.split(coordinatesStr, " ")
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
  local cropsizeStr = ExifUtils.findValue(metadata,  "Crop Size")
  local croptopleftStr = ExifUtils.findValue(metadata, "Crop Top Left")
  if cropsizeStr ~= nil then
    local cropsizeTable = Utils.split(cropsizeStr, " ")
    if cropsizeTable ~= nil then
      if croptopleftStr ~= nil then
        local croptopleftTable = Utils.split(croptopleftStr, " ")
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

--[[----------------------------------------------------------------------------
  private table
  addInfo(string title, string key, table props, table metadata)

  Generate a row element to be added to the current view container.
------------------------------------------------------------------------------]]
local function addInfo(title, key, props, metadata)
  local f = LrView.osFactory()

  -- Helper function to create and populate the property corresponding to metadata key
  local function populateInfo(key)
    local value
    if type(key) == "string" then
      value = ExifUtils.findValue(metadata, key)
    else
      -- type(key) == "table"
      value = ExifUtils.findFirstMatchingValue(metadata, key)
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

    -- wrap values as required
    if key == metaKeyImageStabilization then props[key] = Utils.wrapText(props[key], {';'}, FocusInfo.maxValueLen) end
    if key == FaceElementTypes          then props[key] = Utils.wrapText(props[key], {','}, FocusInfo.maxValueLen) end

    -- compose the row to be added
    local result = FocusInfo.addRow(title, props[key])

    -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
    if (props[key] == "AF-C") then
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("AF-C Priority", metaKeyAfCPriority, props, metadata) }

    elseif (props[key] == "AF-S") then
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("AF-S Priority", metaKeyAfSPriority, props, metadata) }

    elseif key == metaKeyAfMode and props[key] == "Single Point" then
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("AF Area Point Size", metaKeyAfAreaPointSize, props, metadata) }

    elseif key == metaKeyAfMode and props[key] == "Zone" then
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("AF Area Zone Size", metaKeyAfAreaZoneSize, props, metadata) }

    elseif key == metaKeyDriveSpeed then
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("Sequence Number", metaKeySequenceNumber, props, metadata) }

    elseif ((key == metaKeyAfCSetting) or
            (key == metaKeyAfCTrackingSensitivity) or
            (key == metaKeyAfCSpeedTrackingSensitivity) or
            (key == metaKeyAfCZoneAreaSwitching))
        and (props[metaKeyFocusMode] ~= "AF-C") then
      -- these settings are not relevant for focus modes other than AF-C -> skip them!
      return FocusInfo.emptyRow()

    elseif key == FacesDetected and props[key] == "0"
        or key == metaKeyPreAf  and props[key] == "Off" then
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

--[[----------------------------------------------------------------------------
  public boolean
  modelSupported(string model)

  Indicate whether the given camera model is supported or not.
------------------------------------------------------------------------------]]
function FujifilmDelegates.modelSupported(_model)
  -- supports entire X-, GFX-series and FinePix after 2007
  -- so there is not really anything that justifies the effort to write code to exclude ancient models
  return true
end

--[[----------------------------------------------------------------------------
  public boolean
  makerNotesFound(table photo, table metadata)

  Check if the metadata for the current photo includes a 'Makernotes' section.
------------------------------------------------------------------------------]]
function FujifilmDelegates.makerNotesFound(photo, metadata)

  local function getExtension(filename)
    return filename:match("^.+%.([^%.]+)$")
  end

  -- 1. Check if makernotes section exists
  if not ExifUtils.findValue(metadata, metaKeyAfInfoSection) then
    Log.logWarn("Fujifilm",
      string.format("Tag '%s' not found", metaKeyAfInfoSection))
    return false
  end
  --[[
    2. Check if photo is a DNG file
    The coordinates of the 'focus pixel' tag on Fuji correspond to the dimensions of the embedded
    JPG preview image in the RAF file. These are recorded in the ExifImageWidth/ExifImageHeight fields
    in the Exif IFD section.
    Unfortunately, the information in these two tags can easily be lost when processing the RAF image
    in applications such as e.g. Topaz Photo AI or DxO PhotoLab. The tags are missing completely in the
    DNG file returned by DxO PL. It's even worse for Topaz Photo AI: the tags are retained in the DNG file,
    but they contain invalid information:(RAF image dimensions), which leads to an incorrect focus point display.
    As a consequence, treat DNG files as files w/o makernotes section in the context of focus point coordinates.
  --]]
  local ext = getExtension(Utils.getPhotoFileName(photo))
  if ext:upper() == "DNG" then
    Log.logWarn("Fujifilm",
      string.format("Fuji DNG files do not contain valid information on image width/height",
        metaKeyExifImageWidth, metaKeyExifImageHeight))
    return false
  end
  return true
end

--[[----------------------------------------------------------------------------
  public boolean
  manualFocusUsed(table photo, table metadata)

  Indicate whether the photo was taken using manual focus.
------------------------------------------------------------------------------]]
function FujifilmDelegates.manualFocusUsed(_photo, metadata)
  local focusMode, key = ExifUtils.findFirstMatchingValue(metadata, metaKeyFocusMode)
  Log.logInfo("Fujifilm",
    string.format("Tag '%s' found: %s", key, focusMode))
  local focusPoint = ExifUtils.findValue(metadata, metaKeyFocusPixel)
  return (focusMode == "Manual" or focusMode == "AF-M") and not focusPoint
end

--[[----------------------------------------------------------------------------
  public table
  function getImageInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Image Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function FujifilmDelegates.getImageInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local imageInfo
  imageInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Crop mode", metaKeyCropMode, props, metadata),
  }
  return imageInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getShootingInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Shooting Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function FujifilmDelegates.getShootingInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,

    addInfo("Image Stabilization", metaKeyImageStabilization, props, metadata),
    addInfo("Drive Mode", metaKeyDriveMode, props, metadata),
    addInfo("Drive Speed", metaKeyDriveSpeed, props, metadata),
  }
  return shootingInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getFocusInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to fetch the items in the 'Focus Information'
  section (which is entirely maker-specific).
------------------------------------------------------------------------------]]
function FujifilmDelegates.getFocusInfo(_photo, props, metadata)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      addInfo("Focus Mode",                    metaKeyFocusMode                    , props, metadata),
      addInfo("AF Mode",                       metaKeyAfMode                       , props, metadata),
      addInfo("Focus Warning",                 metaKeyFocusWarning                 , props, metadata),
      addInfo("Pre AF",                        metaKeyPreAf                        , props, metadata),
      addInfo("Faces Detected",                FacesDetected                       , props, metadata),
      addInfo("Subject Element Types",         FaceElementTypes                    , props, metadata),
      addInfo("AF-C Setting",                  metaKeyAfCSetting                   , props, metadata),
      addInfo("- Tracking Sensitivity",        metaKeyAfCTrackingSensitivity       , props, metadata),
      addInfo("- Speed Tracking Sensitivity",  metaKeyAfCSpeedTrackingSensitivity  , props, metadata),
      addInfo("- Zone Area Switching",         metaKeyAfCZoneAreaSwitching         , props, metadata),
      }
  return focusInfo
end

return FujifilmDelegates -- ok
