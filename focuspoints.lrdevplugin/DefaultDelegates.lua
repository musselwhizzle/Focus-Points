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
DefaultDelegates.metaKeyAfPointUsed = { "AF Points Used"}
DefaultDelegates.metaKeyAfPointSelected = { "AF Points Selected", "Primary AF Point" }

DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS = "af_selected_infocus"    -- The AF-point is selected and in focus
DefaultDelegates.POINTTYPE_AF_INFOCUS = "af_infocus"                      -- The AF-point is in focus
DefaultDelegates.POINTTYPE_AF_SELECTED = "af_selected"                    -- The AF-point is selected but not in focus
DefaultDelegates.POINTTYPE_AF_INACTIVE = "af_inactive"                    -- The AF-point is inactive
DefaultDelegates.POINTTYPE_FACE = "face"                                  -- A face has been detected
DefaultDelegates.pointTemplates = {
  af_selected_infocus = {
    center = { fileTemplate = "assets/imgs/focus_point_red-fat_center_%s.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/focus_point_red_center_%s.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/focus_point_red-fat_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_red-fat_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_infocus = {
    center = { fileTemplate = "assets/imgs/focus_point_red-fat_center_%s.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/focus_point_red_center_%s.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/focus_point_black_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_black_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_selected = {
    corner = { fileTemplate = "assets/imgs/focus_point_red_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_red_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_inactive = {
    corner = { fileTemplate = "assets/imgs/focus_point_black_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_black_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  face = {
    corner = { fileTemplate = "assets/imgs/focus_point_yellow_corner_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/focus_point_yellow_corner-small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  }
}

--[[
-- photo - the photo LR object
-- metaData - the metadata as read by exiftool
--]]
function DefaultDelegates.getAfPoints(photo, metaData)
  local focusPoint = ExifUtils.findFirstMatchingValue(metaData, DefaultDelegates.metaKeyAfPointUsed) 
  local afPointType = nil
  if (focusPoint ~= nil) then
    afPointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS
  else 
    focusPoint = ExifUtils.findFirstMatchingValue(metaData, DefaultDelegates.metaKeyAfPointSelected)
    if (focusPoint ~= nil) then
      afPointType = DefaultDelegates.POINTTYPE_AF_SELECTED
    end
  end
  
  -- if we still haven't found a focus point, try getting it from the liveview mode
  if (focusPoint == nil) then
    local liveViewResult = DefaultDelegates.getLiveViewAfPoints(photo, metaData)
    if (liveViewResult == nil) then
      -- give up. can't find focus point information
      LrErrors.throwUserError("Could not find Auto Focus data within the file.")
      return nil
    else 
      return liveViewResult
    end
  end
  
  -- typical AF points have been found
  local result = nil
  focusPoint = DefaultDelegates.normalizeFocusPointName(focusPoint)
  if DefaultDelegates.focusPointsMap[focusPoint] == nil then
    LrErrors.throwUserError("The AF-Point " .. focusPoint .. " could not be found within the file.")
    return nil
  end

  -- TODO: The addition of the dimension should be removed once all config files have been
  -- updated to reflect the center of the focus points
  local x = DefaultDelegates.focusPointsMap[focusPoint][1] + (.5 * DefaultDelegates.focusPointDimen[1])
  local y = DefaultDelegates.focusPointsMap[focusPoint][2] + (.5 * DefaultDelegates.focusPointDimen[2])

  result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = afPointType,
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
  Function to get the autofocus points and focus size of the camera when shot in liveview mode
  returns typical points table
--]]
function DefaultDelegates.getLiveViewAfPoints(photo, metaData)
  local afAreaXPosition = ExifUtils.findFirstMatchingValue(metaData, {"AF Area X Position"})
  local afAreaYPosition = ExifUtils.findFirstMatchingValue(metaData, {"AF Area Y Position"})
  local afAreaWidth = ExifUtils.findFirstMatchingValue(metaData, {"AF Area Width"})
  local afAreaHeight = ExifUtils.findFirstMatchingValue(metaData, {"AF Area Height"})

  if (nil == afAreaXPosition) or (nil == afAreaYPosition) then
    --LrErrors.throwUserError("Unable to find any AF point info within the file.")
    return nil
  end

  if nil == afAreaWidth then
    afAreaWidth = DefaultDelegates.focusPointDimen[1]
  end

  if nil == afAreaHeight then
    afAreaHeight = DefaultDelegates.focusPointDimen[2]
  end

  result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS,
        x = afAreaXPosition,
        y = afAreaYPosition,
        width = afAreaWidth,
        height = afAreaHeight
      }
    }
  }
  
  return result
end

--[[
  At random times, Nikon adds the word "(Center") to it's focus points. Strip all of this 
  out. (Shame on you Nikon)
  @focusPoint - the focus point such as C6 or B1 or E2
  @return - normalized focus point name - C6 (Center) will return as C6
--]]
function DefaultDelegates.normalizeFocusPointName(focusPoint)
  if (string.find(focusPoint, "Center") ~= nil) then
    focusPoint = string.sub(focusPoint, 1, 2)
  end
  return focusPoint
end
