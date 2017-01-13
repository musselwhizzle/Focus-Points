--[[
  Copyright 2016 Joshua Musselwhite, Whizzbang Inc

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

local LrStringUtils = import "LrStringUtils"
require "Utils"

CanonDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function CanonDelegates.getAfPoints(photo, metaData)
  local cameraModel = string.lower(photo:getFormattedMetadata("cameraModel"))

  local imageWidth
  local imageHeight

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

  local afPointsSelected = ExifUtils.findFirstMatchingValue(metaData, { "AF Points Selected", "AF Points In Focus" })
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

  for key,value in pairs(afAreaXPositions) do
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
    if isInFocus and isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS
    elseif isInFocus then
      pointType = DefaultDelegates.POINTTYPE_AF_INFOCUS
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
