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
  the camera is Olympus

  Assume that focus point metadata look like:

    AF Areas                        : (118,32)-(137,49)
    AF Point Selected               : (50%,15%) (50%,15%)

    Where:
        AF Point Selected appears to be % of photo from upper left corner (X%, Y%)
        AF Areas appears to be focus box as coordinates relative to 0..255 from upper left corner (x,y)

  2017-01-06 - MJ - Test for 'AF Point Selected' in Metadata, assume it's good if found
                    Add basic errorhandling if not found

TODO: Verify math by comparing focs point locations Olympus OV3 software
TODO: Try using 'AF Areas' instead. This should allow display of properly sized focus box

--]]

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "Utils"

OlympusDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function OlympusDelegates.getAfPoints(photo, metaData)
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
  log ("Focus %: " .. focusX .. "," ..  focusY .. "," .. focusPoint  )

  local orgPhotoWidth, orgPhotoHeight = parseDimens(photo:getFormattedMetadata("dimensions"))
  if orgPhotoWidth == nil or orgPhotoHeight == nil then
      LrErrors.throwUserError("Metadata has no Dimensions")
      return nil
  end
  log ( "Focus px: " .. tonumber(orgPhotoWidth) * tonumber(focusX)/100 .. "," .. tonumber(orgPhotoHeight) * tonumber(focusY)/100)

  -- Is this really necessary when values are percentages ?
  local x = tonumber(orgPhotoWidth) * tonumber(focusX) / 100
  local y = tonumber(orgPhotoHeight) * tonumber(focusY) / 100
  if orgPhotoWidth < orgPhotoHeight then
    x = tonumber(orgPhotoWidth) * tonumber(y) / 100
    y = tonumber(orgPhotoHeight) * tonumber(x) / 100
  end

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = "af_selected_focus",
        x = x,
        y = y,
        width = 300,
        height = 300
      }
    }
  }

  return result
end
