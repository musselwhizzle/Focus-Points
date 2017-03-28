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
    center = { fileTemplate = "assets/imgs/center/red/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/red/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/red/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_infocus = {
    center = { fileTemplate = "assets/imgs/center/red/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/red/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/black/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/black/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_selected = {
    corner = { fileTemplate = "assets/imgs/corner/red/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_inactive = {
    corner = { fileTemplate = "assets/imgs/corner/grey/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/grey/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  face = {
    corner = { fileTemplate = "assets/imgs/corner/yellow/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/yellow/small_%s.png", anchorX = 23, anchorY = 23 },
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
  local focusPointsTable = split(focusPoint, ",")
  
  local selectedPoint = ExifUtils.findFirstMatchingValue(metaData, DefaultDelegates.metaKeyAfPointSelected)
  local selectedPointsTable = split(selectedPoint, ",")
  
  -- if we dont have any focus points, check for liveview modes.
  if (focusPoint == nil and selectedPoint == nil) then
    local liveViewResults = DefaultDelegates.getLiveViewAfPoints(photo, metaData)
    if (liveViewResults == nil) then
      -- give up. can't find focus point information
      LrErrors.throwUserError("Could not find Auto Focus data within the file.")
      return nil
    else 
      return liveViewResults
    end
  end
  
  -- fail out if no focus points found
  if (focusPoint == nil and selectedPoint == nil) then
    -- give up. can't find focus point information
      LrErrors.throwUserError("Could not find Auto Focus data within the file.")
      return nil
  end
  
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
    }
  }
  
  -- add the infocus points
  if (focusPointsTable ~= nil) then 
    DefaultDelegates.addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS, focusPointsTable)
  end 
  
  -- add the selected points
  if (selectedPointsTable ~= nil) then 
    DefaultDelegates.addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_SELECTED, selectedPointsTable)
  end 
  
  return result
  
end

--[[
  @private
  Method to loop over the extracted focus point table and add it to the result table which will be returned by this delegate
  @result - the result table 
  @focusPointType - the type of focus point it is. Values such as DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS
  @focusPointTable - the table of the focus points to add to the result
--]]
function DefaultDelegates.addFocusPointsToResult(result, focusPointType, focusPointTable)
  if (focusPointTable ~= nil) then 
    for key,value in pairs(focusPointTable) do
      local focusPointName = DefaultDelegates.normalizeFocusPointName(value)
      if DefaultDelegates.focusPointsMap[focusPointName] == nil then
        LrErrors.throwUserError("The AF-Point " .. focusPointName .. " could not be found within the file.")
        return nil
      end
      
      local x = DefaultDelegates.focusPointsMap[focusPointName][1] + (.5 * DefaultDelegates.focusPointDimen[1])
      local y = DefaultDelegates.focusPointsMap[focusPointName][2] + (.5 * DefaultDelegates.focusPointDimen[2])
      
      table.insert(result.points, {
          pointType = focusPointType,
          x = x,
          y = y,
          width = DefaultDelegates.focusPointDimen[1],
          height = DefaultDelegates.focusPointDimen[2]
        })
    end
  end
end

--[[
  @private
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
  @private
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
