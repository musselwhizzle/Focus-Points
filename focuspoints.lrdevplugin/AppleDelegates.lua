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

local LrErrors = import 'LrErrors'
local LrView = import "LrView"
require "Utils"

AppleDelegates = {}

AppleDelegates.focusPointsDetected = false

-- AF-relevant tags
AppleDelegates.metaKeyAfSubjectArea        = "Subject Area"
AppleDelegates.metaKeyAfFocusDistanceRange = "Focus Distance Range"
AppleDelegates.metaKeyAfPerformance        = "AF Performance"
AppleDelegates.metaKeyAfStable             = "AF Stable"
AppleDelegates.metaKeyAfConfidence         = "AF Confidence"
AppleDelegates.metaKeyAfMeasuredDepth      = "AF Measured Depth"
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

  AppleDelegates.focusPointsDetected = false

--[[ #FIXME
     this kind of query does not guarantee proper results, as there can be multiple occurences
     of ImageWidth and ImageHeight tags in different EXIF sections with different meanings and results
     Only ExifImageWight/Height will deliver exactly what is needed to scale focus coordinates!
  local imageWidth = ExifUtils.findFirstMatchingValue(metaData, { "Image Width", "Exif Image Width" })
  local imageHeight = ExifUtils.findFirstMatchingValue(metaData, { "Image Height", "Exif Image Height" })
--]]
  local imageWidth  = ExifUtils.findValue(metaData, AppleDelegates.metaKeyExifImageWidth)
  local imageHeight = ExifUtils.findValue(metaData, AppleDelegates.metaKeyExifImageHeight)

  if not imageWidth and not imageHeight then
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  local subjectArea = split(ExifUtils.findValue(metaData, AppleDelegates.metaKeyAfSubjectArea), " ")
  if not subjectArea then
    return nil
  end

  local x = subjectArea[1] * xScale
  local y = subjectArea[2] * yScale
  local w = subjectArea[3] * xScale
  local h = subjectArea[4] * yScale
    
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
    }
  }

  if w > 0 and h > 0 then
    table.insert(result.points, {
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
        x = x,
        y = y,
        width = w,
        height = h
      })
  end

  AppleDelegates.focusPointsDetected = true
  return result
end


-- ========================================================================================================================

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


  -- create and populate property with designated value
  populateInfo(key)

  -- compose the row to be added
  local result = f:row {fill = 1,
                   f:column{f:static_text{title = title .. ":", font="<system>"}},
                   f:spacer{fill_horizontal = 1},
                   f:column{
                     f:static_text{
                       title = props[key],
  --                     alignment = "right",
                       font="<system>"}}
                  }
  -- decide if and how to add it
  if (props[key] == AppleDelegates.metaValueNA) then
    return FocusInfo.emptyRow()
  else
  -- add row as composed
    return result
  end
end


--[[
  @@public table function AppleDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function AppleDelegates.getImageInfo(photo, props, metaData)
  local f = LrView.osFactory()
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

  -- for iPhones, there is no characteristic makernotes section tag that is valid for all models

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(AppleDelegates.focusPointsDetected),
      AppleDelegates.addInfo("Focus Distance Range", AppleDelegates.metaKeyAfFocusDistanceRange, props, metaData),
--      AppleDelegates.addInfo("AF Measured Depth"   , AppleDelegates.metaKeyAfMeasuredDepth     , props, metaData),
      AppleDelegates.addInfo("AF Stable"           , AppleDelegates.metaKeyAfStable            , props, metaData),
--    AppleDelegates.addInfo("AF Confidence"       , AppleDelegates.metaKeyAfConfidence        , props, metaData),
--    AppleDelegates.addInfo("AF Performance"      , AppleDelegates.metaKeyAfPerformance       , props, metaData),
  }
  return focusInfo
end
