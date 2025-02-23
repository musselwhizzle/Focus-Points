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

FujifilmDelegates = {}

-- To trigger display whether focus points have been detected or not
FujifilmDelegates.focusPointsDetected = false

-- Tag that indicates that makernotes / AF section is present
FujifilmDelegates.metaKeyAfInfoSection               = "Fuji Flash Mode"

-- AF relevant tags
FujifilmDelegates.metaKeyFocusMode                   = {"Focus Mode 2", "Focus Mode" }
FujifilmDelegates.metaKeyAfMode                      = {"AF Area Mode", "AF Mode" }
FujifilmDelegates.metaKeyAfSPriority                 = "AF-S Priority"
FujifilmDelegates.metaKeyAfCPriority                 = "AF-C Priority"
FujifilmDelegates.metaKeyFocusWarning                = "Focus Warning"
FujifilmDelegates.FacesDetected                      = "Faces Detected"
FujifilmDelegates.FaceElementTypes                   = "Face Element Types"
FujifilmDelegates.metaKeyPreAf                       = "Pre AF"
FujifilmDelegates.metaKeyAfCSetting                  = "AF-C Setting"
FujifilmDelegates.metaKeyAfCTrackingSensitivity      = "AF-C Tracking Sensitivity"
FujifilmDelegates.metaKeyAfCSpeedTrackingSensitivity = "AF-C Speed Tracking Sensitivity"
FujifilmDelegates.metaKeyAfCZoneAreaSwitching        = "AF-C Zone Area Switching"

-- Image and Camera Settings relevant tags
FujifilmDelegates.metaKeyCropMode                    = "Crop Mode"
FujifilmDelegates.metaKeyDriveMode                   = "Drive Mode"
FujifilmDelegates.metaKeyDriveSpeed                  = "Drive Speed"
FujifilmDelegates.metaKeySequenceNumber              = "Sequence Number"
FujifilmDelegates.metaKeyImageStabilization          = "Image Stabilization"

-- relevant metadata values
FujifilmDelegates.metaValueNA                        = "N/A"


--[[
  @@public table FujiFilmDelegates.getAfPoints(table photo, table metaData)
  ----
  Get the autofocus points from metadata
--]]
function FujifilmDelegates.getAfPoints(photo, metaData)
  FujifilmDelegates.focusPointsDetected = false

  local focusPoint = ExifUtils.findValue(metaData, "Focus Pixel")
  if focusPoint == nil then
    return nil
  end
  local values = split(focusPoint, " ")
  local x = LrStringUtils.trimWhitespace(values[1])
  local y = LrStringUtils.trimWhitespace(values[2])
  if x == nil or y == nil then
    return nil
  end

  local imageWidth = ExifUtils.findValue(metaData, "Exif Image Width")
  local imageHeight = ExifUtils.findValue(metaData, "Exif Image Height")
  if imageWidth == nil or imageHeight == nil then
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  logInfo("Fujifilm", "AF points detected at [" .. math.floor(x * xScale) .. ", " .. math.floor(y * yScale) .. "]")

  -- the only real focus point is this - the below code just checks for visualization frames
  FujifilmDelegates.focusPointsDetected = true
  local result = DefaultPointRenderer.createFocusPixelBox(x*xScale, y*yScale)


  -- Let see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metaData, "Faces Detected")
  if detectedFaces ~= nil and detectedFaces ~= "0" then
    local coordinatesStr = ExifUtils.findValue(metaData, "Face Positions")
    if coordinatesStr ~= nil then
      local coordinatesTable = split(coordinatesStr, " ")
      for i=1, detectedFaces, 1 do
        local x1 = coordinatesTable[4 * (i-1) + 1] * xScale
        local y1 = coordinatesTable[4 * (i-1) + 2] * yScale
        local x2 = coordinatesTable[4 * (i-1) + 3] * xScale
        local y2 = coordinatesTable[4 * (i-1) + 4] * yScale
        logInfo("Fujifilm", "Face detected at [" .. math.floor((x1 + x2) / 2) .. ", " .. math.floor((y1 + y2) / 2) .. "]")
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
  Modified by Andy Lawrence AKA Greybeard to add visual representation of Fujifilm subject tracking
  Requires Exiftool minimum version 12.44
  (23rd August 2022)
--]]
  -- Subject detection
  local coordinatesStr = ExifUtils.findValue(metaData, "Face Element Positions")
  if coordinatesStr ~= nil then
    local coordinatesTable = split(coordinatesStr, " ")
    if coordinatesTable ~= nil then
      local objectCount = #(coordinatesTable) / 4
      for i=1, objectCount, 1 do
        local x1 = coordinatesTable[4 * (i-1) + 1] * xScale
        local y1 = coordinatesTable[4 * (i-1) + 2] * yScale
        local x2 = coordinatesTable[4 * (i-1) + 3] * xScale
        local y2 = coordinatesTable[4 * (i-1) + 4] * yScale
        logInfo("Fujifilm", "Face detected at [" .. math.floor((x1 + x2) / 2) .. ", " .. math.floor((y1 + y2) / 2) .. "]")
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
          logInfo("Fujifilm", "Crop area at [" .. math.floor((x1 + x2) / 2) .. ", " .. math.floor((y1 + y2) / 2) .. "]")
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


-- ========================================================================================================================

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
      props[key] = FujifilmDelegates.metaValueNA
    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- create and populate property with designated value
  populateInfo(key)

  -- compose the row to be added
  local result = f:row {fill = 1,
                   f:column{f:static_text{title = title .. ":", font="<system>"}},
                   f:spacer{fill_horizontal = 1},
                   f:column{
                     f:static_text{
                       title = wrapText(props[key], ",",30),
                       font="<system>"
                     }
                   }
                 }
  -- decide if and how to add it
  if (props[key] == FujifilmDelegates.metaValueNA) then
    -- we won't display any "N/A" entries - return a empty row (that will get ignored by LrView)
    return f:row{}
  elseif (props[key] == "AF-C") then
    return f:column{
      fill = 1, spacing = 2, result,
      FujifilmDelegates.addInfo("AF-C Priority", FujifilmDelegates.metaKeyAfCPriority, props, metaData) }
  elseif (props[key] == "AF-S") then
    return f:column{
      fill = 1, spacing = 2, result,
      FujifilmDelegates.addInfo("AF-S Priority", FujifilmDelegates.metaKeyAfSPriority, props, metaData) }
  elseif (key == FujifilmDelegates.metaKeyDriveSpeed) then
    return f:column{
      fill = 1, spacing = 2, result,
      FujifilmDelegates.addInfo("Sequence Number", FujifilmDelegates.metaKeySequenceNumber, props, metaData) }
  else
    -- add row as composed
    return result
  end
end


--[[
  @@public table function FujifilmDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function FujifilmDelegates.getImageInfo(photo, props, metaData)
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
  @@public table function FujifilmDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function FujifilmDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  cameraInfo = f:column {
    fill = 1,
    spacing = 2,

    FujifilmDelegates.addInfo("Image Stabilization", FujifilmDelegates.metaKeyImageStabilization, props, metaData),
    FujifilmDelegates.addInfo("Drive Mode", FujifilmDelegates.metaKeyDriveMode, props, metaData),
    FujifilmDelegates.addInfo("Drive Speed", FujifilmDelegates.metaKeyDriveSpeed, props, metaData),
  }
  return cameraInfo
end


--[[
  @@public table FujifilmDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function FujifilmDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, FujifilmDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(FujifilmDelegates.focusPointsDetected),
      FujifilmDelegates.addInfo("Focus Mode",                       FujifilmDelegates.metaKeyFocusMode                    , props, metaData),
      FujifilmDelegates.addInfo("AF Mode",                          FujifilmDelegates.metaKeyAfMode                       , props, metaData),
      FujifilmDelegates.addInfo("Focus Warning",                    FujifilmDelegates.metaKeyFocusWarning                 , props, metaData),
      FujifilmDelegates.addInfo("Pre AF",                           FujifilmDelegates.metaKeyPreAf                        , props, metaData),
      FujifilmDelegates.addInfo("Faces Detected",                   FujifilmDelegates.FacesDetected                       , props, metaData),
      FujifilmDelegates.addInfo("Subject Element Types",            FujifilmDelegates.FaceElementTypes                    , props, metaData),
      FujifilmDelegates.addInfo("AF-C Setting",                     FujifilmDelegates.metaKeyAfCSetting                   , props, metaData),
      FujifilmDelegates.addInfo("AF-C Tracking Sensitivity",        FujifilmDelegates.metaKeyAfCTrackingSensitivity       , props, metaData),
      FujifilmDelegates.addInfo("AF-C Speed Tracking Sensitivity",  FujifilmDelegates.metaKeyAfCSpeedTrackingSensitivity  , props, metaData),
      FujifilmDelegates.addInfo("AF-C Zone Area Switching",         FujifilmDelegates.metaKeyAfCZoneAreaSwitching         , props, metaData),
      }
  return focusInfo
end
