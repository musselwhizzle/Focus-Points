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

DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS = "af_selected_infocus"    -- The AF-point is selected and in focus
DefaultDelegates.POINTTYPE_AF_INFOCUS = "af_infocus"                      -- The AF-point is in focus
DefaultDelegates.POINTTYPE_AF_SELECTED = "af_selected"                    -- The AF-point is selected but not in focus
DefaultDelegates.POINTTYPE_AF_INACTIVE = "af_inactive"                    -- The AF-point is inactive
DefaultDelegates.POINTTYPE_FACE = "face"                                  -- A face has been detected
DefaultDelegates.pointTemplates = {
  af_selected_infocus = {
    center = { fileTemplate = "assets/imgs/focus_point_red_center_%s.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/focus_point_red_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_red_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    angleStep = 5
  },
  af_infocus = {
    center = { fileTemplate = "assets/imgs/focus_point_red_center_%s.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/focus_point_grey_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_grey_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    angleStep = 5
  },
  af_selected = {
    corner = { fileTemplate = "assets/imgs/focus_point_redgrey_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_redgrey_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    angleStep = 5
  },
  af_inactive = {
    corner = { fileTemplate = "assets/imgs/focus_point_grey_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_grey_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    angleStep = 5
  },
  face = {
    corner = { fileTemplate = "assets/imgs/focus_point_yellow_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_yellow_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    angleStep = 5
  }
}

--[[
-- photo - the photo LR object
-- metaData - the metadata as read by exiftool
--]]
function DefaultDelegates.getAfPoints(photo, metaData)
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, DefaultDelegates.metaKeyAfPointUsed)

  if focusPoint == nil then
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

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS,
        x = x,
        y = y,
        width = DefaultDelegates.focusPointDimen[1],
        height = DefaultDelegates.focusPointDimen[2]
      }
    }
  }

  return result
end

--[[
  -- method figures out the orientation the photo was shot at by looking at the metadata
  -- returns 90, 270, or 0 (in trigonometric sense)
--]]
function DefaultDelegates.getShotOrientation(photo, metaData)
  local dimens = photo:getFormattedMetadata("dimensions")
  local orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping

  local metaOrientation = ExifUtils.findFirstMatchingValue(metaData, { "Orientation" })
  if string.match(metaOrientation, "90 CCW") and orgPhotoW < orgPhotoH then
    return 90     -- 90 CCW   => 90 trigo
  elseif string.match(metaOrientation, "270 CCW") and orgPhotoW < orgPhotoH then
    return 270    -- 270 CCW  => 270 trigo
  elseif string.match(metaOrientation, "90") and orgPhotoW < orgPhotoH then
    return 270    -- 90 CW    => 270 trigo
  elseif string.match(metaOrientation, "270") and orgPhotoW < orgPhotoH then
    return 90     -- 270 CCW  => 90 trigo
  end

  return 0
end
