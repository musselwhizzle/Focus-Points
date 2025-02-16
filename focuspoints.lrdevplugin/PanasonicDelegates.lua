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

local LrErrors = import 'LrErrors'
local LrView = import "LrView"
require "Utils"

PanasonicDelegates = {}

PanasonicDelegates.focusPointsDetected = false

PanasonicDelegates.metaKeyAfInfoSection = "Panasonic Exif Version"

--[[
-- metaData - the metadata as read by exiftool
--]]
function PanasonicDelegates.getAfPoints(photo, metaData)
  -- find selected AF point
  PanasonicDelegates.focusPointsDetected = false
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Position" })
  if focusPoint == nil then
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
  PanasonicDelegates.focusPointsDetected = true
  return result
end


--[[
  @@public table PanasonicDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function PanasonicDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, PanasonicDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(PanasonicDelegates.focusPointsDetected),
      f:row {f:static_text {title = "View details not yet implemented", font="<system>"}}
      }
  return focusInfo
end
