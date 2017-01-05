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
  A collection of delegate functions to be passed into the DefaultPointRenderer.
--]]

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "Utils"

DefaultDelegates = {}
DefaultDelegates.focusPointsMap = nil
DefaultDelegates.focusPointDimen = nil
DefaultDelegates.metaKeyAfPointUsed = "AF Points Used"


--[[
-- metaData - the metadata as read by exiftool
-- focusPoints - table containing px locations of the focus points
--]]
function DefaultDelegates.getDefaultAfPoints(photo, metaData)
  local focusPoint = ExifUtils.findValue(metaData, DefaultDelegates.metaKeyAfPointUsed)

  -- fallback for Nikon back-button Autofocusing.
  if "(none)" == focusPoint then
    focusPoint = ExifUtils.findValue(metaData, "Primary AF Point")
  end

  if "(none)" == focusPoint or focusPoint == nil then
    LrErrors.throwUserError("Unable to find any AF point info within the file.")
    return nil, nil
  end

  -- TODO: The addition of the dimension should be removed once all config files have been
  -- updated to reflect the center of the focus points
  local x = DefaultDelegates.focusPointsMap[focusPoint][1] + DefaultDelegates.focusPointDimen[1]
  local y = DefaultDelegates.focusPointsMap[focusPoint][2] + DefaultDelegates.focusPointDimen[2]

  return x, y
end

--[[
  -- method figures out the orientation the photo was shot at by looking at the metadata
  -- returns 90, 270, or 0
--]]
function DefaultDelegates.getShotOrientation(photo, metaData)
  local dimens = photo:getFormattedMetadata("dimensions")
  local orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping

  local metaOrientation = ExifUtils.findValue(metaData, "Orientation")
  if (string.match(metaOrientation, "90") and orgPhotoW < orgPhotoH) then
    return 90
  elseif (string.match(metaOrientation, "270") and orgPhotoW < orgPhotoH) then
    return 270
  else
    return 0
  end

end
