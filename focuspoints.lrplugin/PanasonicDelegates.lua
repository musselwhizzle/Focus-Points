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

local LrView = import  'LrView'
local Log    = require 'Log'

PanasonicDelegates = {}

-- Tag indicating that makernotes / AF section exists
PanasonicDelegates.metaKeyAfInfoSection = "Panasonic Exif Version"

-- AF-relevant tags
PanasonicDelegates.metaKeyAfFocusMode                 = "Focus Mode"
PanasonicDelegates.metaKeyAfAreaMode                  = "AF Area Mode"
PanasonicDelegates.metaKeyAfPointPosition             = "AF Point Position"
PanasonicDelegates.metaKeyAFAreaSize                  = "AF Area Size"
PanasonicDelegates.metaKeyAfSubjectDetection          = "AF Subject Detection"
PanasonicDelegates.metaKeyAfFacesDetected             = "Faces Detected"
PanasonicDelegates.metaKeyAfNumFacePositions          = "Num Face Positions"
PanasonicDelegates.metaKeyAfFacePosition              = "Face %s Position"

-- Image and Shooting Information relevant tags
PanasonicDelegates.metaKeyShootingMode                = "Shooting Mode"
PanasonicDelegates.metaKeyImageStabilization          = "Image Stabilization"
PanasonicDelegates.metaKeyBurstMode                   = "Burst Mode"
PanasonicDelegates.metaKeySequenceNumber              = "Sequence Number"

-- Relevant metadata values
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

  local result = {
      pointTemplates = DefaultDelegates.pointTemplates,
      points = {
      }
    }

  -- Get photo dimensions for proper scaling
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  local focusPoint = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAfPointPosition)
  if focusPoint then
    Log.logInfo("Panasonic",
      string.format("Tag '%s' found: '%s'",
        PanasonicDelegates.metaKeyAfPointPosition, focusPoint))
  else
    -- no focus points found - handled on upper layers
    Log.logWarn("Panasonic",
      string.format("Tag '%s' not found", PanasonicDelegates.metaKeyAfPointPosition))
    return nil
  end

  -- extract (x,y) point values (rational numbers in range 0..1)
  local focusX = Utils.get_nth_Word(focusPoint, 1, " ")
  local focusY = Utils.get_nth_Word(focusPoint, 2, " ")
  if not (focusX and focusY) then
    Log.logError("Panasonic",
      string.format('Could not extract (x,y) coordinates from "%s" tag', PanasonicDelegates.metaKeyAfPointPosition))
    return nil
  end

  -- transform the values into (integer) pixels
  local x = math.floor(tonumber(orgPhotoWidth)  * tonumber(focusX))
  local y = math.floor(tonumber(orgPhotoHeight) * tonumber(focusY))

  Log.logInfo("Panasonic", string.format("Focus point detected at [x=%s, y=%s]", x, y))

  FocusInfo.focusPointsDetected = true

  -- Let's see if AF area size is given
  local afAreaSize = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAFAreaSize)
  if afAreaSize then
    local areaSizeX, areaSizeY = string.match(afAreaSize, PanasonicDelegates.metaKeyAfAreaSizePattern)
    if not (areaSizeX and areaSizeY) then
      Log.logWarn("Panasonic",
        string.format('Could not extract (x,y) coordinates from "%s" tag', PanasonicDelegates.metaKeyAfPointPosition))
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
    if (key == PanasonicDelegates.metaKeyBurstMode) and (props[key] == PanasonicDelegates.metaValueOn) then
      return f:column{
        fill = 1, spacing = 2, result,
        PanasonicDelegates.addInfo("Sequence Number", PanasonicDelegates.metaKeySequenceNumber, props, metaData)
      }

    elseif (key == PanasonicDelegates.metaKeyAfFacesDetected and props[key] == "0") then
      -- if no faces have been detected, we will skip this entry
      return FocusInfo.emptyRow()

--[[
    elseif (key == PanasonicDelegates.metaKeyAfSubjectDetection) and
           string.find(string.lower(props[key]), "face") then
       return f:column{
         fill = 1, spacing = 2, result,
         PanasonicDelegates.addInfo("Faces Detected", PanasonicDelegates.metaKeyAfFacesDetected, props, metaData)
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
  @@public boolean PanasonicDelegates.modelSupported(string model)
  ----
  Returns whether the given camera model is supported or not
--]]
function PanasonicDelegates.modelSupported(_model)
  -- #TODO For this to work precisely, would need to identify compact cameras before 2008
  return true
end


--[[
  @@public boolean PanasonicDelegates.makerNotesFound(table photo, table metaData)
  ----
  Returns whether the current photo has metadata with makernotes AF information included
--]]
function PanasonicDelegates.makerNotesFound(_photo, metaData)
  local result = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Panasonic",
      string.format("Tag '%s' not found", PanasonicDelegates.metaKeyAfInfoSection))
  end
  return (result ~= nil)
end


--[[
  @@public boolean PanasonicDelegates.manualFocusUsed(table photo, table metaData)
  ----
  Returns whether manual focus has been used on the given photo
--]]
function PanasonicDelegates.manualFocusUsed(_photo, metaData)
  local focusMode = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFocusMode)
  return (focusMode == "Manual")
end


--[[
  @@public table function PanasonicDelegates.getImageInfo(table photo, table props, table metaData)
  ----
  Called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  if any, otherwise return an empty column
--]]
function PanasonicDelegates.getImageInfo(_photo, _props, _metaData)
  local imageInfo
  return imageInfo
end


--[[
  @@public table function PanasonicDelegates.getShootingInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Shooting Information" section
  -- if any, otherwise return an empty column
--]]
function PanasonicDelegates.getShootingInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    PanasonicDelegates.addInfo("Image Stabilization", PanasonicDelegates.metaKeyImageStabilization, props, metaData),
    PanasonicDelegates.addInfo("Burst Mode"         , PanasonicDelegates.metaKeyBurstMode         , props, metaData),
  }
  return shootingInfo
end


--[[
  @@public table PanasonicDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function PanasonicDelegates.getFocusInfo(_photo, props, metaData)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      PanasonicDelegates.addInfo("Focus Mode",        PanasonicDelegates.metaKeyAfFocusMode       , props, metaData),
      PanasonicDelegates.addInfo("AF Area Mode",      PanasonicDelegates.metaKeyAfAreaMode        , props, metaData),
      PanasonicDelegates.addInfo("Subject Detection", PanasonicDelegates.metaKeyAfSubjectDetection, props, metaData),
      PanasonicDelegates.addInfo("Faces Detected",    PanasonicDelegates.metaKeyAfFacesDetected   , props, metaData)
      }
  return focusInfo
end


return PanasonicDelegates
