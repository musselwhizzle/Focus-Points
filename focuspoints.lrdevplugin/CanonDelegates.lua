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
  the camera is Canon
--]]

local LrView = import "LrView"
require "Utils"

CanonDelegates = {}

-- To trigger display whether focus points have been detected or not
CanonDelegates.focusPointsDetected = false

-- Tag which indicates that makernotes / AF section is present
CanonDelegates.metaKeyAfInfoSection         = "Canon Firmware Version"

-- AF relevant metadata tag names
CanonDelegates.metaKeyFocusMode             = "Focus Mode"
CanonDelegates.metaKeyAfAreaMode            = "AF Area Mode"
CanonDelegates.metaKeyOneShotAfRelease      = "One Shot AF Release"
CanonDelegates.metaKeySubjectToDetect       = "Subject To Detect"
CanonDelegates.metaKeyEyeDetection          = "Eye Detection"
CanonDelegates.AfTrackingSensitivity        = "AF Tracking Sensitivity"
CanonDelegates.AfAccelDecelTracking         = "AF Accel Decel Tracking"
CanonDelegates.AfPointSwitching             = "AF Point Switching"
CanonDelegates.AIServoFirstImage            = "AI Servo First Image"
CanonDelegates.AIServoSecondImage           = "AI Servo Second Image"

CanonDelegates.metaKeyFocusDistanceUpper    = "Focus Distance Upper"
CanonDelegates.metaKeyFocusDistanceLower    = "Focus Distance Lower"
CanonDelegates.metaKeyDepthOfField          = "Depth Of Field"
CanonDelegates.metaKeyHyperfocalDistance    = "Hyperfocal Distance"

-- relevant metadata values
CanonDelegates.metaValueNA                  = "N/A"
CanonDelegates.metaValueOneShotAf           = "One-shot AF"

--[[
-- metaData - the metadata as read by exiftool
--]]
function CanonDelegates.getAfPoints(photo, metaData)
  local cameraModel = string.lower(photo:getFormattedMetadata("cameraModel"))

  local imageWidth
  local imageHeight

  CanonDelegates.focusPointsDetected = false

  if cameraModel == "canon eos 5d" then   -- For some reason for this camera, the AF Image Width/Height has to be replaced by Canon Image Width/Height
    imageWidth = ExifUtils.findFirstMatchingValue(metaData, { "Canon Image Width", "Exif Image Width" })
    imageHeight = ExifUtils.findFirstMatchingValue(metaData, { "Canon Image Height", "Exif Image Height" })
  else
    imageWidth = ExifUtils.findFirstMatchingValue(metaData, { "AF Image Width", "Exif Image Width" })
    imageHeight = ExifUtils.findFirstMatchingValue(metaData, { "AF Image Height", "Exif Image Height" })
  end
  if imageWidth == nil or imageHeight == nil then
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  local afPointWidth = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Width" })
  local afPointHeight = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Height" })
  local afPointWidths = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Widths" })
  local afPointHeights = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Heights" })

  if (afPointWidth == nil and afPointWidths == nil) or (afPointHeight == nil and afPointHeights == nil) then
    return nil
  end
  if afPointWidths == nil then
    afPointWidths = {}
  else
    afPointWidths = split(afPointWidths, " ")
  end
  if afPointHeights == nil then
    afPointHeights = {}
  else
    afPointHeights = split(afPointHeights, " ")
  end

  local afAreaXPositions = ExifUtils.findFirstMatchingValue(metaData, { "AF Area X Positions" })
  local afAreaYPositions = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Y Positions" })
  if afAreaXPositions == nil or afAreaYPositions == nil then
    return nil
  end

  afAreaXPositions = split(afAreaXPositions, " ")
  afAreaYPositions = split(afAreaYPositions, " ")

  local afPointsSelected -- = ExifUtils.findFirstMatchingValue(metaData, { "AF Points Selected" }) DPP doesn't display these!
  if afPointsSelected == nil then
    afPointsSelected = {}
  else
    afPointsSelected = split(afPointsSelected, ",")
  end

  local afPointsInFocus = ExifUtils.findFirstMatchingValue(metaData, { "AF Points In Focus" })
  if afPointsInFocus == nil then
    afPointsInFocus = {}
  else
    afPointsInFocus = split(afPointsInFocus, ",")
  end

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
    }
  }
  
  -- it seems Canon Point and Shoot cameras are reversed on the y-axis
  local exifCameraType = ExifUtils.findFirstMatchingValue(metaData, { "Camera Type" })
  if (exifCameraType == nil) then
    exifCameraType = ""
  end
  
  local yDirection = -1
  if string.lower(exifCameraType) == "compact" then
    yDirection = 1
  end

  for key, _ in pairs(afAreaXPositions) do
    local x = (imageWidth/2 + afAreaXPositions[key]) * xScale     -- On Canon, everithing is referenced from the center,
    local y = (imageHeight/2 + (afAreaYPositions[key] * yDirection)) * yScale
    local width = 0
    local height = 0
    if afPointWidths[key] == nil then
      width = afPointWidth * xScale
    else
      width = afPointWidths[key] * xScale
    end
    if afPointHeights[key] == nil then
      height = afPointHeight * xScale
    else
      height = afPointHeights[key] * xScale
    end
    local pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE
    local isInFocus = arrayKeyOf(afPointsInFocus, tostring(key - 1)) ~= nil     -- 0 index based array by Canon
    local isSelected = arrayKeyOf(afPointsSelected, tostring(key - 1)) ~= nil
--[[ #FIXME
    if isInFocus and isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS
    end
-- ]]
    if isInFocus then
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
      CanonDelegates.focusPointsDetected = true
    elseif isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED
    end

    if width > 0 and height > 0 then
      table.insert(result.points, {
        pointType = pointType,
        x = x,
        y = y,
        width = width,
        height = height
      })
    end
  end
  return result
end


-- ========================================================================================================================

--[[
  @@public table CanonDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
  function CanonDelegates.addInfo(title, key, props, metaData)
    local f = LrView.osFactory()

    -- Creates and populates the property corresponding to metadata key
    local function populateInfo(key)
      local value = ExifUtils.findValue(metaData, key)

      if (value == nil) then
        props[key] = CanonDelegates.metaValueNA
      else
        -- everything else is the default case!
        props[key] = value
      end
    end

    -- create and populate property with designated value
    populateInfo(key)

    -- compose the row to be added
    local result = f:row {
                     f:column{f:static_text{title = title .. ":", font="<system>"}},
                     f:spacer{fill_horizontal = 1},
                     f:column{f:static_text{title = props[key], font="<system>"}}}
    -- decide if and how to add it
    if (props[key] == CanonDelegates.metaValueNA) then
      -- we won't display any "N/A" entries - return a empty row (that will get ignored by LrView)
      return f:row{}
    elseif (props[key] == CanonDelegates.metaValueOneShotAf) then
      return f:column{
        fill = 1, spacing = 2, result,
        CanonDelegates.addInfo("One Shot AF Release", CanonDelegates.metaKeyOneShotAfRelease, props, metaData) }
    else
      -- add row as composed
      return result
    end
  end

--[[
  @@public table CanonDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function CanonDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, CanonDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(CanonDelegates.focusPointsDetected),

      CanonDelegates.addInfo("Focus Mode"               , CanonDelegates.metaKeyFocusMode        , props, metaData),
      CanonDelegates.addInfo("AF Area Mode"             , CanonDelegates.metaKeyAfAreaMode       , props, metaData),
      CanonDelegates.addInfo("One Shot AF Release"      , CanonDelegates.metaKeyOneShotAfRelease , props, metaData),
      CanonDelegates.addInfo("Subject To Detect"        , CanonDelegates.metaKeySubjectToDetect  , props, metaData),
      CanonDelegates.addInfo("Eye Detection"            , CanonDelegates.metaKeyEyeDetection     , props, metaData),
      CanonDelegates.addInfo("AF Tracking Sensitivity"  , CanonDelegates.AfTrackingSensitivity   , props, metaData),
      CanonDelegates.addInfo("AF Accel Decel Tracking"  , CanonDelegates.AfAccelDecelTracking    , props, metaData),
      CanonDelegates.addInfo("AF Point Switching"       , CanonDelegates.AfPointSwitching        , props, metaData),
      CanonDelegates.addInfo("AI Servo First Image"     , CanonDelegates.AIServoFirstImage       , props, metaData),
      CanonDelegates.addInfo("AI Servo Second Image"    , CanonDelegates.AIServoSecondImage      , props, metaData),
      FocusInfo.addSpace(),
      FocusInfo.addSeparator(),
      FocusInfo.addSpace(),
      CanonDelegates.addInfo("Focus Distance (Upper)"   , CanonDelegates.metaKeyFocusDistanceUpper,  props, metaData),
      CanonDelegates.addInfo("Focus Distance (Lower)"   , CanonDelegates.metaKeyFocusDistanceLower,  props, metaData),
      CanonDelegates.addInfo("Depth of Field"           , CanonDelegates.metaKeyDepthOfField,        props, metaData),
      CanonDelegates.addInfo("Hyperfocal Distance"      , CanonDelegates.metaKeyHyperfocalDistance,  props, metaData),

--      CanonDelegates.addInfo("",           CanonDelegates.metaKey.., props, metaData),

      }
  return focusInfo
end
