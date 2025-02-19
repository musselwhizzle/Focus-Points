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

-- Tag which indicates that makernotes / AF section is present
AppleDelegates.metaKeyAfInfoSection      = "Live Photo Video Index"

--[[
-- metaData - the metadata as read by exiftool
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
  local imageWidth = ExifUtils.findFirstMatchingValue(metaData, { "Exif Image Width" })
  local imageHeight = ExifUtils.findFirstMatchingValue(metaData, { "Exif Image Height" })

  if not imageWidth and not imageHeight then
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  local subjectArea = split(ExifUtils.findFirstMatchingValue(metaData, { "Subject Area" }), " ")
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


--[[
  @@public table AppleDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function AppleDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, AppleDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(AppleDelegates.focusPointsDetected),
      f:row {f:static_text {title = "Details not yet implemented", font="<system>"}}
      }
  return focusInfo
end
