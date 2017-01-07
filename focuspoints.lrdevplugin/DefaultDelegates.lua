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
DefaultDelegates.metaKeyAfPointUsed = { "AF Points Used", "AF Points Selected", "Primary AF Point" }


--[[
-- metaData - the metadata as read by exiftool
-- focusPoints - table containing px locations of the focus points
--]]
function DefaultDelegates.getDefaultAfPoints(photo, metaData)
  local focusPoint = nil
  for key,keyword in pairs(DefaultDelegates.metaKeyAfPointUsed) do
    focusPoint = ExifUtils.findValue(metaData, keyword)
    if focusPoint ~= "(none)" and focusPoint ~= nil then
      log(keyword .. " -> " .. focusPoint)
      break
    end
  end

  if focusPoint == "(none)" or focusPoint == nil then
    LrErrors.throwUserError("Unable to find any AF point info within the file.")
    return nil, nil
  end

  if DefaultDelegates.focusPointsMap[focusPoint] == nil then
    LrErrors.throwUserError("The AF-Point " .. focusPoint .. " could not be found within the file.")
    return nil, nil
  end

  -- TODO: The addition of the dimension should be removed once all config files have been
  -- updated to reflect the center of the focus points
  local x = DefaultDelegates.focusPointsMap[focusPoint][1] + (.5 * DefaultDelegates.focusPointDimen[1])
  local y = DefaultDelegates.focusPointsMap[focusPoint][2] + (.5 * DefaultDelegates.focusPointDimen[2])

  return x, y
end

--[[
  -- method figures out the orientation the photo was shot at by looking at the metadata
  -- returns 90, 270, or 0 (in trigonometric sense)
--]]
function DefaultDelegates.getShotOrientation(photo, metaData)
  local dimens = photo:getFormattedMetadata("dimensions")
  local orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping

  local metaOrientation = ExifUtils.findValue(metaData, "Orientation")
  if string.match(metaOrientation, "90 CCW") and orgPhotoW < orgPhotoH then
    return 90     -- 90 CCW   = 90 trigo
  elseif string.match(metaOrientation, "270 CCW") and orgPhotoW < orgPhotoH then
    return 270    -- 270 CCW  = 270 trigo
  elseif string.match(metaOrientation, "90") and orgPhotoW < orgPhotoH then
    return 270    -- 90 CW    = 270 trigo
  elseif string.match(metaOrientation, "270") and orgPhotoW < orgPhotoH then
    return 90     -- 270 CCW  = 90 trigo
  end

  return 0
end
