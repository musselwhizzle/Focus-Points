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

  Assume that focus point metadata look like:

    AF Point Position               : 0.5 0.5


    Where:
        AF Point Position appears to be location of AF point from upper left corner (X%, Y%)

  2017-01-06 - MJ - Test for 'AF Point Position' in Metadata, assume it's good if found
                    Add basic errorhandling if not found
--]]

local LrView   = import 'LrView'

require "Utils"
require "Log"


PanasonicDelegates = {}

-- To trigger display whether focus points have been detected or not
PanasonicDelegates.focusPointsDetected = false

-- Tag which indicates that makernotes / AF section is present
PanasonicDelegates.metaKeyAfInfoSection = "Panasonic Exif Version"

-- AF relevant tags
PanasonicDelegates.metaKeyAfFocusMode                 = "Focus Mode"
PanasonicDelegates.metaKeyAfAreaMode                  = "AF Area Mode"
PanasonicDelegates.metaKeyAfPointPosition             = "AF Point Position"
PanasonicDelegates.metaKeyAFAreaSize                  = "AF Area Size"
PanasonicDelegates.metaKeyAfSubjectDetection          = "AF Subject Detection"
PanasonicDelegates.metaKeyAfFacesDetected             = "Faces Detected"
PanasonicDelegates.metaKeyAfNumFacePositions          = "Num Face Positions"
PanasonicDelegates.metaKeyAfFacePosition              = "Face %s Position"

-- Image and Camera Settings relevant tags
PanasonicDelegates.metaKeyShootingMode                = "Shooting Mode"
PanasonicDelegates.metaKeyImageStabilization          = "Image Stabilization"
PanasonicDelegates.metaKeyBurstMode                   = "Burst Mode"
PanasonicDelegates.metaKeySequenceNumber              = "Sequence Number"

-- relevant metadata values
PanasonicDelegates.metaValueNA                        = "n/a"
PanasonicDelegates.metaValueOn                        = "On"
PanasonicDelegates.metaValueOff                       = "Off"
PanasonicDelegates.metaKeyAfPointPositionPattern      = "0(%.%d+) 0(%.%d+)"
PanasonicDelegates.metaKeyAfAreaSizePattern           = "([%d%.]+)%s+([%d%.]+)"

--[[
  @@public table PanasonicDelegates.getAfPoints(table photo, table metaData)
  ----
  Get the autofocus points from metadata
--]]
function PanasonicDelegates.getAfPoints(photo, metaData)
  
  PanasonicDelegates.focusPointsDetected = false
  
  local focusPoint = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAfPointPosition)
  if focusPoint then
    Log.logInfo("Panasonic",
      string.format("Focus point tag '%s' found: '%s'",
        PanasonicDelegates.metaKeyAfPointPosition, focusPoint))
  else
    -- no focus points found - handled on upper layers
    Log.logWarn("Panasonic",
      string.format("Focus point tag '%s' not found", PanasonicDelegates.metaKeyAfPointPosition))
    return nil
  end

  local focusX, focusY = string.match(focusPoint, PanasonicDelegates.metaKeyAfPointPositionPattern)
  if not (focusX and focusY) then
    Log.logError("Panasonic",
      string.format('Could not extract (x,y) coordinates from "%s" tag', PanasonicDelegates.metaKeyAfPointPosition))
    return nil
  end

  -- determine x,y location of center of focus point in image pixels
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local x = tonumber(orgPhotoWidth)  * tonumber(focusX)
  local y = tonumber(orgPhotoHeight) * tonumber(focusY)
  Log.logInfo("Panasonic", string.format("Focus point detected at [x=%s, y=%s]", x, y))

  PanasonicDelegates.focusPointsDetected = true
  local result = {
      pointTemplates = DefaultDelegates.pointTemplates,
      points = {
      }
    }

  -- Let's see if AF area size is given
  local afAreaSize = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAFAreaSize)
  if afAreaSize then
    local areaSizeX, areaSizeY = string.match(afAreaSize, PanasonicDelegates.metaKeyAfAreaSizePattern)
    if not (areaSizeX and areaSizeY) then
      Log.logWarn("Panasonic",
        string.format('Could not extract (x,y) coordinates from "%s" tag', PanasonicDelegates.metaKeyAfPointPosition))
    else
      areaSizeX = tonumber(areaSizeX) * tonumber(orgPhotoWidth)
      areaSizeY = tonumber(areaSizeY) * tonumber(orgPhotoHeight)
      Log.logInfo("Panasonic", "AF Area detected, w=" .. areaSizeX .. ", h=" .. areaSizeY .. "]")

      table.insert(result.points, {
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX_DOT,
        x = x,
        y = y,
        width  = areaSizeX,
        height = areaSizeY,
      })
    end
  else
    local result = DefaultPointRenderer.createFocusFrame(x, y)
  end

  -- Let's see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAfNumFacePositions)
  if detectedFaces and detectedFaces > "0" then
    for i=1, detectedFaces, 1 do
      local currFaceTag = string.format(PanasonicDelegates.metaKeyAfFacePosition, i)
      local coordinatesStr = ExifUtils.findValue(metaData, currFaceTag)
      if coordinatesStr then
        -- format as per https://exiftool.org/TagNames/Panasonic.html:
        -- X/Y coordinates of the face center and width/height of face.
        -- Coordinates are relative to an image twice the size of the thumbnail, or 320 pixels wide
        local thumbwidth  = 320
        local thumbheight = 320 * tonumber(orgPhotoHeight) / tonumber(orgPhotoWidth)
        local xScale = tonumber(orgPhotoWidth)  / thumbwidth
        local yScale = tonumber(orgPhotoHeight) / thumbheight
        local coordinatesTable = split(coordinatesStr, " ")
          local x = coordinatesTable[1] * xScale
          local y = coordinatesTable[2] * yScale
          local w = coordinatesTable[3] * xScale
          local h = coordinatesTable[4] * yScale
          Log.logInfo("Panasonic", "Face detected at [" .. x .. ", " .. y .. "]")
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
  @@public table PanasonicDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
function PanasonicDelegates.addInfo(title, key, props, metaData)
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
    if not value then
      props[key] = PanasonicDelegates.metaValueNA
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
  if props[key] and props[key] ~= PanasonicDelegates.metaValueNA then
    -- compose the row to be added
    local result = f:row {
      f:column{f:static_text{title = title .. ":", font="<system>"}},
      f:spacer{fill_horizontal = 1},
      f:column{f:static_text{title = wrapText(props[key], ",",30), font="<system>"}}
    }
    -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
    if (key == PanasonicDelegates.metaKeyBurstMode) and (props[key] == PanasonicDelegates.metaValueOn) then
      return f:column{
        fill = 1, spacing = 2, result,
        PanasonicDelegates.addInfo("Sequence Number", PanasonicDelegates.metaKeySequenceNumber, props, metaData)
      }
    elseif (key == PanasonicDelegates.metaKeyAfSubjectDetection) then
      local faceDetection = string.find(string.lower(props[key]), "face")
      if faceDetection then
        return f:column{
          fill = 1, spacing = 2, result,
          PanasonicDelegates.addInfo("Faces Detected", PanasonicDelegates.metaKeyAfFacesDetected, props, metaData)
        }
      end
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
  @@public table function PanasonicDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function PanasonicDelegates.getImageInfo(photo, props, metaData)
  local imageInfo
  return imageInfo
end


--[[
  @@public table function PanasonicDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function PanasonicDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  cameraInfo = f:column {
    fill = 1,
    spacing = 2,
    PanasonicDelegates.addInfo("Image Stabilization", PanasonicDelegates.metaKeyImageStabilization, props, metaData),
    PanasonicDelegates.addInfo("Burst Mode"         , PanasonicDelegates.metaKeyBurstMode         , props, metaData),
  }
  return cameraInfo
end


--[[
  @@public table PanasonicDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function PanasonicDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, PanasonicDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(PanasonicDelegates.focusPointsDetected),
      PanasonicDelegates.addInfo("Focus Mode",        PanasonicDelegates.metaKeyAfFocusMode       , props, metaData),
      PanasonicDelegates.addInfo("AF Area Mode",      PanasonicDelegates.metaKeyAfAreaMode        , props, metaData),
      PanasonicDelegates.addInfo("Subject Detection", PanasonicDelegates.metaKeyAfSubjectDetection, props, metaData),
      }
  return focusInfo
end
