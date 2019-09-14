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
  the camera is Sony
--]]

local LrStringUtils = import "LrStringUtils"
require "Utils"

-- Sony says PDAF covers approximately 68% of the sensor
-- a7r3 images are 7952x5304 pixels, 3:2
-- sensor is 42 MP, 68% of which is 28,680,637.44
-- Focal Plane AF Point Area value is "640 428"
-- 640 * 428 * 10^2 == 27,392,000
-- 6400x4280, margins - left/right 776, top/bottom 512

local pdafScale = 10 -- this is a guess
local focusLocationSize = 120
local pdafPointSize = 85

SonyDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function SonyDelegates.getAfPoints(photo, metaData)
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, { "Focus Location" })
  if focusPoint == nil then
    return nil
  end
  local values = split(focusPoint, " ")
  local imageWidth = LrStringUtils.trimWhitespace(values[1])
  local imageHeight = LrStringUtils.trimWhitespace(values[2])
  local x = LrStringUtils.trimWhitespace(values[3])
  local y = LrStringUtils.trimWhitespace(values[4])
  if imageWidth == nil or imageHeight == nil or x == nil or y == nil then
    return nil
  end

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local xScale = orgPhotoWidth / imageWidth
  local yScale = orgPhotoHeight / imageHeight

  logInfo("Sony", "Focus location at [" .. math.floor(x * xScale) .. ", " .. math.floor(y * yScale) .. "]")

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS,
        x = x * xScale,
        y = y * yScale,
        width = focusLocationSize * xScale,
        height = focusLocationSize * yScale
      }
    }
  }

  -- Let's see if we used any PDAF points
  local numPdafPointsStr = ExifUtils.findFirstMatchingValue(metaData, { "Focal Plane AF Points Used" })
  if numPdafPointsStr == nil then
    return result
  end
  local numPdafPoints = LrStringUtils.trimWhitespace(numPdafPointsStr)
  if numPdafPoints == nil then
    return result
  end
  logDebug("Sony", "PDAF AF points used: " .. numPdafPoints)

  local pdafDimensionsStr = ExifUtils.findFirstMatchingValue(metaData, { "Focal Plane AF Point Area" })
  if pdafDimensionsStr == nil then
    return result
  end
  local pdafDimensions = split(pdafDimensionsStr, " ")
  local pdafWidth = LrStringUtils.trimWhitespace(pdafDimensions[1])
  local pdafHeight = LrStringUtils.trimWhitespace(pdafDimensions[2])
  if pdafWidth == nil or pdafHeight == nil then
    return result
  end
  logDebug("Sony", "PDAF AF area dimentions: " .. pdafWidth .. "x" .. pdafHeight)
  logDebug("Sony", "PDAF scale: " .. pdafScale)
  local pdafScaledWidth = pdafWidth * pdafScale
  logDebug("Sony", "PDAF scaled width: " .. pdafScaledWidth)
  local pdafScaledHeight = pdafHeight * pdafScale
  logDebug("Sony", "PDAF scaled height: " .. pdafScaledHeight)
  local pdafXOffset = (imageWidth - pdafScaledWidth) / 2
  logDebug("Sony", "PDAF x offset: " .. pdafXOffset)
  local pdafYOffset = (imageHeight - pdafScaledHeight) / 2
  logDebug("Sony", "PDAF y offset: " .. pdafYOffset)

  -- show the PDAF area
  table.insert(result.points, {
    pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE,
    x = pdafXOffset + (pdafScaledWidth / 2),
    y = pdafYOffset + (pdafScaledHeight / 2),
    width = pdafScaledWidth,
    height = pdafScaledHeight
  })

  for i=1, numPdafPoints do
    local pdafPointStr = ExifUtils.findFirstMatchingValue(metaData, { "Focal Plane AF Point Location " .. i })
    if pdafPointStr == nil then
      return result
    end
    local pdafPoint = split(pdafPointStr, " ")
    local x = LrStringUtils.trimWhitespace(pdafPoint[1])
    local y = LrStringUtils.trimWhitespace(pdafPoint[2])
    if x == nil or y == nil then
      return result
    end
    logDebug("Sony", "PDAF unscaled point at [" .. x .. ", " .. y .. "]")
    local pdafX = (pdafXOffset + (x * pdafScale)) * xScale
    local pdafY = (pdafYOffset + (y * pdafScale)) * yScale
    logInfo("Sony", "PDAF point at [" .. math.floor(pdafX) .. ", " .. math.floor(pdafY) .. "]")
    table.insert(result.points, {
      pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE,
      x = pdafX,
      y = pdafY,
      width = pdafPointSize * xScale,
      height = pdafPointSize * yScale
    })
  end

  return result
end
