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

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "Utils"

AppleDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function AppleDelegates.getAfPoints(photo, metaData)

  local imageWidth = ExifUtils.findFirstMatchingValue(metaData, { "Image Width", "Exif Image Width" })
  local imageHeight = ExifUtils.findFirstMatchingValue(metaData, { "Image Height", "Exif Image Height" })

  if imageWidth == nil or imageHeight == nil then
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  local subjectArea = split(ExifUtils.findFirstMatchingValue(metaData, { "Subject Area" }), " ")
  if subjectArea == nil then
    LrErrors.throwUserError("Could not find Subject Area data within the image.")
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
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS,
        x = x,
        y = y,
        width = w,
        height = h
      })
  end

  return result
end
