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
  the camera is Panasonic
--]]

-- Imported LR namespaces
local LrView                   = import  'LrView'

-- Required Lua definitions
local DefaultDelegates         = require 'DefaultDelegates'
local DefaultPointRenderer     = require 'DefaultPointRenderer'
local ExifUtils                = require 'ExifUtils'
local FocusInfo                = require 'FocusInfo'
local Log                      = require 'Log'
local Utils                    = require 'Utils'

-- This module
local PanasonicDelegates = {}

-- Tag indicating that makernotes / AF section exists
local metaKeyAfInfoSection               = "Panasonic Exif Version"

-- AF-relevant tags
local metaKeyFocusMode                   = "Focus Mode"
local metaKeyAfAreaMode                  = "AF Area Mode"
local metaKeyAfPointPosition             = "AF Point Position"
local metaKeyAFAreaSize                  = "AF Area Size"
local metaKeyAfSubjectDetection          = "AF Subject Detection"
local metaKeyAfFacesDetected             = "Faces Detected"
local metaKeyAfNumFacePositions          = "Num Face Positions"
local metaKeyAfFacePosition              = "Face %s Position"

-- Image and Shooting Information relevant tags
local metaKeyShootingMode                = "Shooting Mode"
local metaKeyImageStabilization          = "Image Stabilization"
local metaKeyBurstMode                   = "Burst Mode"
local metaKeySequenceNumber              = "Sequence Number"

-- Relevant metadata values
local metaValueOn                        = "On"
local metaValueOff                       = "Off"
local metaKeyAfPointPositionPattern      = "0(%.%d+) 0(%.%d+)"
local metaKeyAfAreaSizePattern           = "([%d%.]+)%s+([%d%.]+)"

--[[
  @@public table getAfPoints(table photo, table metadata)
  ----
  Get the autofocus points from metadata
--]]
function PanasonicDelegates.getAfPoints(photo, metadata)

  local result = {
      pointTemplates = DefaultDelegates.pointTemplates,
      points = {
      }
    }

  -- Get photo dimensions for proper scaling
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  local focusPoint = ExifUtils.findValue(metadata, metaKeyAfPointPosition)
  if focusPoint then
    Log.logInfo("Panasonic",
      string.format("Tag '%s' found: '%s'",
        metaKeyAfPointPosition, focusPoint))
  else
    -- no focus points found - handled on upper layers
    Log.logWarn("Panasonic",
      string.format("Tag '%s' not found", metaKeyAfPointPosition))
    return nil
  end

  -- extract (x,y) point values (rational numbers in range 0..1)
  local focusX = Utils.get_nth_Word(focusPoint, 1, " ")
  local focusY = Utils.get_nth_Word(focusPoint, 2, " ")
  if not (focusX and focusY) then
    Log.logError("Panasonic",
      string.format('Could not extract (x,y) coordinates from "%s" tag', metaKeyAfPointPosition))
    return nil
  end

  -- transform the values into (integer) pixels
  local x = math.floor(tonumber(orgPhotoWidth)  * tonumber(focusX))
  local y = math.floor(tonumber(orgPhotoHeight) * tonumber(focusY))

  Log.logInfo("Panasonic", string.format("Focus point detected at [x=%s, y=%s]", x, y))

  FocusInfo.focusPointsDetected = true

  -- Let's see if AF area size is given
  local afAreaSize = ExifUtils.findValue(metadata, metaKeyAFAreaSize)
  if afAreaSize then
    local areaSizeX, areaSizeY = string.match(afAreaSize, metaKeyAfAreaSizePattern)
    if not (areaSizeX and areaSizeY) then
      Log.logWarn("Panasonic",
        string.format('Could not extract (x,y) coordinates from "%s" tag', metaKeyAfPointPosition))
    else
      areaSizeX = tostring (math.floor(tonumber(areaSizeX) * tonumber(orgPhotoWidth)))
      areaSizeY = tostring (math.floor(tonumber(areaSizeY) * tonumber(orgPhotoHeight)))
      Log.logInfo("Panasonic", "AF Area detected, w=[" .. areaSizeX .. ", h=" .. areaSizeY .. "]")

      table.insert(result.points, {
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
        x = x,
        y = y,
        width  = areaSizeX,
        height = areaSizeY,
      })
    end
  else
    result = DefaultPointRenderer.createFocusFrame(x, y)
  end

  -- Let's see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metadata, metaKeyAfNumFacePositions)
  if detectedFaces and detectedFaces > "0" then
    for i=1, detectedFaces, 1 do
      local currFaceTag = string.format(metaKeyAfFacePosition, i)
      local coordinatesStr = ExifUtils.findValue(metadata, currFaceTag)
      if coordinatesStr then
        -- format as per https://exiftool.org/TagNames/Panasonic.html:
        -- X/Y coordinates of the face center and width/height of face.
        -- Coordinates are relative to an image twice the size of the thumbnail, or 320 pixels wide
        local thumbwidth  = 320
        local thumbheight = 320 * tonumber(orgPhotoHeight) / tonumber(orgPhotoWidth)
        local xScale = tonumber(orgPhotoWidth)  / thumbwidth
        local yScale = tonumber(orgPhotoHeight) / thumbheight
        local coordinatesTable = Utils.split(coordinatesStr, " ")
          local x = coordinatesTable[1] * xScale
          local y = coordinatesTable[2] * yScale
          local w = coordinatesTable[3] * xScale
          local h = coordinatesTable[4] * yScale
          Log.logInfo("Panasonic",
            "Face detected at [" .. math.floor(x) .. "," .. math.floor(y) .. "]")
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_FACE,
            x = x,
            y = y,
            width  = w,
            height = h,
          })
        end
    end
  end

  return result
end

--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table addInfo(string title, string key, table props, table metadata)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
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
    if not value then
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

    -- compose the row to be added
    local result = FocusInfo.addRow(title, props[key])

    -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
    if (key == metaKeyBurstMode) and (props[key] == metaValueOn) then
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("Sequence Number", metaKeySequenceNumber, props, metadata)
      }

    elseif (key == metaKeyAfFacesDetected and props[key] == "0") then
      -- if no faces have been detected, we will skip this entry
      return FocusInfo.emptyRow()

--[[
    elseif (key == metaKeyAfSubjectDetection) and
           string.find(string.lower(props[key]), "face") then
       return f:column{
         fill = 1, spacing = 2, result,
         addInfo("Faces Detected", metaKeyAfFacesDetected, props, metadata)
       }
--]]
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
  @@public boolean modelSupported(string model)
  ----
  Returns whether the given camera model is supported or not
--]]
function PanasonicDelegates.modelSupported(_model)
  -- #TODO For this to work precisely, would need to identify compact cameras before 2008
  return true
end

--[[
  @@public boolean makerNotesFound(table photo, table metadata)
  ----
  Returns whether the current photo has metadata with makernotes AF information included
--]]
function PanasonicDelegates.makerNotesFound(_photo, metadata)
  local result = ExifUtils.findValue(metadata, metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Panasonic",
      string.format("Tag '%s' not found", metaKeyAfInfoSection))
  end
  return (result ~= nil)
end

--[[
  @@public boolean manualFocusUsed(table photo, table metadata)
  ----
  Returns whether manual focus has been used on the given photo
--]]
function PanasonicDelegates.manualFocusUsed(_photo, metadata)
  local focusMode = ExifUtils.findValue(metadata, metaKeyFocusMode)
  return (focusMode == "Manual")
end

--[[
  @@public table function getImageInfo(table photo, table props, table metadata)
  ----
  Called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  if any, otherwise return an empty column
--]]
function PanasonicDelegates.getImageInfo(_photo, _props, _metadata)
  local imageInfo
  return imageInfo
end

--[[
  @@public table function getShootingInfo(table photo, table props, table metadata)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Shooting Information" section
  -- if any, otherwise return an empty column
--]]
function PanasonicDelegates.getShootingInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Image Stabilization", metaKeyImageStabilization, props, metadata),
    addInfo("Burst Mode"         , metaKeyBurstMode         , props, metadata),
  }
  return shootingInfo
end

--[[
  @@public table getFocusInfo(table photo, table info, table metadata)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function PanasonicDelegates.getFocusInfo(_photo, props, metadata)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      addInfo("Focus Mode",        metaKeyFocusMode         , props, metadata),
      addInfo("AF Area Mode",      metaKeyAfAreaMode        , props, metadata),
      addInfo("Subject Detection", metaKeyAfSubjectDetection, props, metadata),
      addInfo("Faces Detected",    metaKeyAfFacesDetected   , props, metadata)
      }
  return focusInfo
end

return PanasonicDelegates
