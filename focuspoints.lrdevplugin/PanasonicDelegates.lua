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

TODO: Verify math by comparing focus point locations with in-camera views.

--]]

local LrErrors = import 'LrErrors'
local LrView   = import 'LrView'

require "Utils"

PanasonicDelegates = {}

PanasonicDelegates.focusPointsDetected = false


-- Tag which indicates that makernotes / AF section is present
PanasonicDelegates.metaKeyAfInfoSection = "Panasonic Exif Version"

-- relevant metadata tag names
PanasonicDelegates.metaKeyShootingMode                = "Shooting Mode"
PanasonicDelegates.metaKeyImageStabilization          = "Image Stabilization"
PanasonicDelegates.metaKeyBurstMode                   = "Burst Mode"
PanasonicDelegates.metaKeySequenceNumber              = "Sequence Number"

PanasonicDelegates.metaKeyAfFocusMode                 = "Focus Mode"
PanasonicDelegates.metaKeyAfAreaMode                  = "AF Area Mode"
PanasonicDelegates.metaKeyAfPointPosition             = "AF Point Position"
PanasonicDelegates.metaKeyAfSubjectDetection          = "AF Subject Detection"
PanasonicDelegates.metaKeyAfFacesDetected             = "Faces Detected"
PanasonicDelegates.metaKeyAfNumFacePositions          = "Num Face Positions"
PanasonicDelegates.metaKeyAfFacePosition              = "Face %s Position"

-- relevant metadata values
PanasonicDelegates.metaValueNA                        = "n/a"
PanasonicDelegates.metaValueOn                        = "On"
PanasonicDelegates.metaValueOff                       = "Off"


--[[
  @@public table PanasonicDelegates.getAfPoints(table photo, table metaData)
  ----
  Get the autofocus points from metadata
--]]
function PanasonicDelegates.getAfPoints(photo, metaData)
  -- find selected AF point
  PanasonicDelegates.focusPointsDetected = false
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Position" })
  if focusPoint == nil then
    return nil
  end

  local focusX, focusY = string.match(focusPoint, "0(%.%d+) 0(%.%d+)")
  if focusX == nil or focusY == nil then
      LrErrors.throwUserError(getFileName(photo) .. "Focus point not found in 'AF Point Position' metadata tag")
      return nil
  end
  logDebug("Panasonic", "Focus %: " .. focusX .. "," ..  focusY .. "," .. focusPoint)

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  if orgPhotoWidth == nil or orgPhotoHeight == nil then
      LrErrors.throwUserError(getFileName(photo) .. "Unable to retrieve current photo size from Lightroom")
      return nil
  end
  logDebug("Panasonic", "Focus px: " .. tonumber(orgPhotoWidth) * tonumber(focusX) .. "," .. tonumber(orgPhotoHeight) * tonumber(focusY))

  -- determine x,y location of center of focus point in image pixels
  local x = tonumber(orgPhotoWidth) * tonumber(focusX)
  local y = tonumber(orgPhotoHeight) * tonumber(focusY)
  logDebug("Panasonic", "FocusXY: " .. x .. ", " .. y)

  PanasonicDelegates.focusPointsDetected = true
  local result = DefaultPointRenderer.createFocusPixelBox(x, y)

  -- Let see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metaData, PanasonicDelegates.metaKeyAfNumFacePositions)
  if detectedFaces and detectedFaces > "0" then
    for i=1, detectedFaces, 1 do
      local currFaceTag = string.format(PanasonicDelegates.metaKeyAfFacePosition, i)
      local coordinatesStr = ExifUtils.findValue(metaData, currFaceTag)
      if coordinatesStr ~= nil then
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
          logInfo("Panasonic", "Face detected at [" .. x .. ", " .. y .. "]")
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


-- ========================================================================================================================

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
    if (value == nil) then
      props[key] = PanasonicDelegates.metaValueNA
    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- Helper function to wrap text across multiple rows to fit maximum column length
  local function wrapText(text, max_length)
    local result = ""
    local current_line = ""
    for word in text:gmatch("[^,]+") do
      word = word:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
      if #current_line + #word + 1 > max_length then
        result = result .. current_line .. "\n"
        current_line = word
      else
        if current_line == "" then
          current_line = word
        else
          current_line = current_line .. ", " .. word
        end
      end
    end
    if current_line ~= "" then
      result = result .. current_line
    end
    return result
  end

  -- create and populate property with designated value
  populateInfo(key)

  -- compose the row to be added
  local result = f:row {fill = 1,
                   f:column{f:static_text{title = title .. ":", font="<system>"}},
                   f:spacer{fill_horizontal = 1},
                   f:column{
                     f:static_text{
                       title = wrapText(props[key], 30),
  --                     alignment = "right",
                       font="<system>"}}
                  }
  -- decide if and how to add it
  if (props[key] == PanasonicDelegates.metaValueNA) then
    return f:control_spacing{}     -- creates an "empty row" that is really empty - f:row{} is not
  elseif (key == PanasonicDelegates.metaKeyBurstMode) and (props[key] == PanasonicDelegates.metaValueOn) then
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
end


--[[
  @@public table function PanasonicDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function PanasonicDelegates.getImageInfo(photo, props, metaData)
  local f = LrView.osFactory()
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
