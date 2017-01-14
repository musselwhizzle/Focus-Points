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

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "Utils"

PanasonicDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function PanasonicDelegates.getAfPoints(photo, metaData)
  -- find selected AF point
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Position" })
  if focusPoint == nil then
    LrErrors.throwUserError("Unsupported Panasonic Camera or 'AF Point Position' metadata tag not found.")
    return nil
  end

  local focusX, focusY = string.match(focusPoint, "0(%.%d+) 0(%.%d+)")
  if focusX == nil or focusY == nil then
      LrErrors.throwUserError("Focus point not found in 'AF Point Position' metadata tag")
      return nil
  end
  logDebug("Panasonic", "Focus %: " .. focusX .. "," ..  focusY .. "," .. focusPoint)

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  if orgPhotoWidth == nil or orgPhotoHeight == nil then
      LrErrors.throwUserError("Metadata has no Dimensions")
      return nil
  end
  logDebug("Panasonic", "Focus px: " .. tonumber(orgPhotoWidth) * tonumber(focusX) .. "," .. tonumber(orgPhotoHeight) * tonumber(focusY))

  -- determine x,y location of center of focus point in image pixels
  local x = tonumber(orgPhotoWidth) * tonumber(focusX)
  local y = tonumber(orgPhotoHeight) * tonumber(focusY)
  logDebug("Panasonic", "FocusXY: " .. x .. ", " .. y)

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS,
        x = x,
        y = y,
        width = 300,
        height = 300
      }
    }
  }

  return result
end
