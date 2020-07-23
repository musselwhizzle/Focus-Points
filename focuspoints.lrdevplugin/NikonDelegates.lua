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
  the camera is Nikon
--]]

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "NikonDuplicates"
require "Utils"

NikonDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function NikonDelegates.getAfPoints(photo, metaData)
  local cameraModel = string.lower(photo:getFormattedMetadata("cameraModel"))
  cameraModel = string.lower(cameraModel)

  -- z models, try to use AF Area properties first
  if string.find(cameraModel, "nikon z", 1, true) then
    local imageWidth = ExifUtils.findFirstMatchingValue(metaData, { "AF Image Width", "Image Width", "Exif Image Width" })
    local imageHeight = ExifUtils.findFirstMatchingValue(metaData, { "AF Image Height", "Image Width", "Exif Image Height" })
    if imageWidth == nil or imageHeight == nil then
      logError("NikonDelegates", "Could not find image dimensions data within the file.")
      LrErrors.throwUserError("Could not find image dimensions data within the file.")
      return nil
    end

    local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
    local xScale = orgPhotoWidth / imageWidth
    local yScale = orgPhotoHeight / imageHeight

    local afPointWidth = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Width" })
    local afPointHeight = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Height" })
    if afPointWidth == nil or afPointHeight == nil then
      local afPoints = ExifUtils.findFirstMatchingValue(metaData, { "AF Points Used" })
      if afPoints == nil then
        logError("NikonDelegates", "Could not find AF area dimensions data within the file.")
        LrErrors.throwUserError("Could not find AF area dimensions data within the file.")
        return nil
      end
      -- fall back to default for PDAF points
      return DefaultDelegates.getAfPoints(photo, metaData)
    end

    local afAreaXPosition = ExifUtils.findFirstMatchingValue(metaData, { "AF Area X Position" })
    local afAreaYPosition = ExifUtils.findFirstMatchingValue(metaData, { "AF Area Y Position" })
    if afAreaXPosition == nil or afAreaYPosition == nil then
      local afPoints = ExifUtils.findFirstMatchingValue(metaData, { "AF Points Used" })
      if afPoints == nil then
        logError("NikonDelegates", "Could not find AF area point data within the file.")
        LrErrors.throwUserError("Could not find AF area point data within the file.")
        return nil
      end
      -- fall back to default for PDAF points
      return DefaultDelegates.getAfPoints(photo, metaData)
    end

    local result = {
      pointTemplates = DefaultDelegates.pointTemplates,
      points = {
      }
    }
    
    local width = afPointWidth * xScale
    local height = afPointHeight * yScale
    local x = afAreaXPosition * xScale
    local y = afAreaYPosition * yScale
    local pointType = DefaultDelegates.POINTTYPE_AF_SELECTED
    if width > 0 and height > 0 then
      table.insert(result.points, {
        pointType = pointType,
        x = x,
        y = y,
        width = width,
        height = height
      })
    end
    return result
  end

  -- non z-models, use defaults
  return DefaultDelegates.getAfPoints(photo, metaData)
end
