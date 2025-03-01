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
  the camera is Apple (iPhone, iPad)
--]]

local LrView = import "LrView"

require "Utils"
require "Log"


AppleDelegates = {}

-- To trigger display whether focus points have been detected or not
AppleDelegates.focusPointsDetected = false

-- Tag which indicates that makernotes / AF section is present
AppleDelegates.metaKeyMakerNotVersion      = "Maker Note Version"

-- AF-relevant tags
AppleDelegates.metaKeySubjectArea          = "Subject Area"
AppleDelegates.metaKeyFocusDistanceRange   = "Focus Distance Range"
AppleDelegates.metaKeyAfPerformance        = "AF Performance"
AppleDelegates.metaKeyAfStable             = "AF Stable"
AppleDelegates.metaKeyAfConfidence         = "AF Confidence"
AppleDelegates.metaKeyAfMeasuredDepth      = "AF Measured Depth"
AppleDelegates.metaKeyImageWidth           = "Image Width"
AppleDelegates.metaKeyImageHeight          = "Image Height"
AppleDelegates.metaKeyExifImageWidth       = "Exif Image Width"
AppleDelegates.metaKeyExifImageHeight      = "Exif Image Height"

-- Camera Settings relevant tags
AppleDelegates.metaKeyCameraType           = "Camera Type"
AppleDelegates.metaKeyImageCaptureType     = "Image Capture Type"
AppleDelegates.metaKeyOISMode              = "OIS Mode"


--[[
  @@public table AppleDelegates.getAfPoints(table photo, table metaData)
  ----
  Get the autofocus points from metadata
--]]
function AppleDelegates.getAfPoints(photo, metaData)

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
    }
  }

  AppleDelegates.focusPointsDetected = ExifUtils.decodeXmpMWGRegions(result, metaData)

  if not AppleDelegates.focusPointsDetected then
    -- Only we we don't have a focus area yet - avoid double focus frames!

    -- For Apple iPhone, these three tags need to be present to calculate proper focus point:
    local subjectAreaStr  = ExifUtils.findValue(metaData, AppleDelegates.metaKeySubjectArea)
    local exifImageWidth  = ExifUtils.findValue(metaData, AppleDelegates.metaKeyExifImageWidth)
    local exifImageHeight = ExifUtils.findValue(metaData, AppleDelegates.metaKeyExifImageHeight)

    if not (exifImageWidth and exifImageHeight) then
      Log.logError("Apple",
        string.format("Relevant tags  '%s' / '%s' tag not found. %s",
          AppleDelegates.metaKeyExifImageWidth, AppleDelegates.metaKeyExifImageHeight, FocusInfo.msgImageNotOoc))
      return nil
    end

    -- Determining size and proper orientation can be tricky for iPhones
    -- for RAWs, there is only ExifImageWidth/ExifImageHeight and the (proper) "Orientation"
    -- for JPGs, orientation is baked in ImageWidth/ImageHeight, i.e. for a capture in portrait format
    --           the values are reversed wrt to ExifImageWidth/ExifImageHeight.
    --           "Orientation" tag is always "Horizontal (normal)"
    -- So, to determine proper scaling factors, we better fetch consistent information from Lightroom
    local originalWidth, originalHeight, cropWidth, cropHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
    local xScale = cropWidth  / originalWidth
    local yScale = cropHeight / originalHeight

    -- Do we have a subject area tag to convert into a focus point?
    if subjectAreaStr then

      Log.logInfo("Apple",
        string.format("'%s' tag found: '%s'",
          AppleDelegates.metaKeySubjectArea, subjectAreaStr))

      local subjectArea = split(subjectAreaStr, ", ")
      local x = subjectArea[1] * xScale
      local y = subjectArea[2] * yScale
      local w = subjectArea[3] * xScale
      local h = subjectArea[4] * yScale

      if w > 0 and h > 0 then
        table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
            x = x,
            y = y,
            width = w,
            height = h
          })
      end

      Log.logInfo("Apple",
        string.format("Focus point detected at [x=%s, y=%s, w=%s, h=%s]",
        math.floor(x), math.floor(y), math.floor(w), math.floor(h)))

      AppleDelegates.focusPointsDetected = true
    else
      Log.logWarn("Apple",
        string.format("'%s' tag not found.", AppleDelegates.metaKeySubjectArea))
    end
  end
  return result
end



--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table AppleDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
function AppleDelegates.addInfo(title, key, props, metaData)
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
      props[key] = AppleDelegates.metaValueNA
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
  if props[key] and props[key] ~= AppleDelegates.metaValueNA then
    -- compose the row to be added
    local result = f:row {
      f:column{f:static_text{title = title .. ":", font="<system>"}},
      f:spacer{fill_horizontal = 1},
      f:column{f:static_text{title = props[key], font="<system>"}}
    }
    -- add row as composed
    return result
  else
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end
end


--[[
  @@public table function AppleDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function AppleDelegates.getImageInfo(photo, props, metaData)
  local imageInfo
  return imageInfo
end


--[[
  @@public table function AppleDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function AppleDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  cameraInfo = f:column {
    fill = 1,
    spacing = 2,
    AppleDelegates.addInfo("Image Capture Type", AppleDelegates.metaKeyImageCaptureType, props, metaData),
    AppleDelegates.addInfo("OIS Mode"          , AppleDelegates.metaKeyOISMode         , props, metaData),
    AppleDelegates.addInfo("CameraType"        , AppleDelegates.metaKeyCameraType      , props, metaData),
  }
  return cameraInfo
end


--[[
  @@public table AppleDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function AppleDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(AppleDelegates.focusPointsDetected),
      AppleDelegates.addInfo("Focus Distance Range", AppleDelegates.metaKeyFocusDistanceRange, props, metaData),
--      AppleDelegates.addInfo("AF Measured Depth"   , AppleDelegates.metaKeyAfMeasuredDepth     , props, metaData),
      AppleDelegates.addInfo("AF Stable"           , AppleDelegates.metaKeyAfStable            , props, metaData),
--    AppleDelegates.addInfo("AF Confidence"       , AppleDelegates.metaKeyAfConfidence        , props, metaData),
--    AppleDelegates.addInfo("AF Performance"      , AppleDelegates.metaKeyAfPerformance       , props, metaData),
  }
  return focusInfo
end
