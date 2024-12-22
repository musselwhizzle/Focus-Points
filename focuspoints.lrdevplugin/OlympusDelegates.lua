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
  the camera is Olympus

  Assume that focus point metadata look like:

    AF Areas                        : (118,32)-(137,49)
    AF Point Selected               : (50%,15%) (50%,15%)

    Where:
        AF Point Selected appears to be % of photo from upper left corner (X%, Y%)
        AF Areas appears to be focus box as coordinates relative to 0..255 from upper left corner (x,y)

  2017-01-06 - MJ - Test for 'AF Point Selected' in Metadata, assume it's good if found
                    Add basic errorhandling if not found
  2017-01-07 - MJ Use 'AF Areas' tag to size focus box
                    Note that on cameras where it is possible to change the size of the focus box,
                    I.E - E-M1, the metadata doesn't show the true size, so all focus boxes will be
                    the same size.
  2017-01-07 - MJ Fix math bug in rotated images

TODO: Verify math by comparing focus point locations with in-camera views.

--]]

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "Utils"

OlympusDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function OlympusDelegates.getAfPoints(photo, metaData)
  -- find selected AF point
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Selected" })
  if focusPoint == nil then
    LrErrors.throwUserError("Unsupported Olympus Camera or 'AF Point Selected' metadata tag not found.")
    return nil
  end

  local focusX, focusY = string.match(focusPoint, "%((%d+)%%,(%d+)")
  if focusX == nil or focusY == nil then
      LrErrors.throwUserError("Focus point not found in 'AF Point Selected' metadata tag")
      return nil
  end
  logDebug("Olympus", "Focus %: " .. focusX .. "," ..  focusY .. "," .. focusPoint)

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  if orgPhotoWidth == nil or orgPhotoHeight == nil then
      LrErrors.throwUserError("Metadata has no Dimensions")
      return nil
  end
  logDebug("Olympus", "Focus px: " .. tonumber(orgPhotoWidth) * tonumber(focusX)/100 .. "," .. tonumber(orgPhotoHeight) * tonumber(focusY)/100)

  local x = tonumber(orgPhotoWidth) * tonumber(focusX) / 100
  local y = tonumber(orgPhotoHeight) * tonumber(focusY) / 100
  logDebug("Olympus", "FocusXY: " .. x .. ", " .. y)

  -- determine size of bounding box of AF area in image pixels
  local afArea = ExifUtils.findFirstMatchingValue(metaData, { "AF Areas" })
  local afAreaX1, afAreaY1, afAreaX2, afAreaY2 = string.match(afArea, "%((%d+),(%d+)%)%-%((%d+),(%d+)%)" )
  local afAreaWidth = 300
  local afAreaHeight = 300

  if afAreaX1 ~= nil and afAreaY1 ~= nil and afAreaX2 ~= nil and afAreaY2 ~= nil then
      afAreaWidth = math.abs(tonumber(afAreaX2) - tonumber(afAreaX1)) * tonumber(orgPhotoWidth) / 255
      afAreaHeight = math.abs(tonumber(afAreaY2) - tonumber(afAreaY1)) * tonumber(orgPhotoHeight) / 255
  end
  logDebug("Olympus", "Focus Area: " .. afArea .. ", " .. afAreaX1 .. ", " .. afAreaY1 .. ", " .. afAreaX2 .. ", " .. afAreaY2 .. ", " .. afAreaWidth .. ", " .. afAreaHeight )

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS,
        x = x,
        y = y,
        width = afAreaWidth,
        height = afAreaHeight
      }
    }
  }

  return result
end
