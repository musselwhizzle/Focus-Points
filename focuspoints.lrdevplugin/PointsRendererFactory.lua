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
  Factory for creating the focus point renderer and getting the focus points.
--]]

require "DefaultPointRenderer"
require "PointsUtils"
require "DefaultDelegates"
require "FujiDelegates"
require "OlympusDelegates"

local LrErrors = import 'LrErrors'

PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(photo)
  local cameraMake = photo:getFormattedMetadata("cameraMake")
  local cameraModel = photo:getFormattedMetadata("cameraModel")
  
  log ("cameraMake: " .. cameraMake)
  log ("cameraModel: " .. cameraModel)
  

  if (cameraMake == nil or cameraModel == nil) then
    LrErrors.throwUserError("File doesn't contain camera maker or model")
  end

  cameraMake = string.lower(cameraMake)
  cameraModel = string.lower(cameraModel)

  if (cameraMake == "fujifilm") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAFPixels = FujiDelegates.getFujiAfPoints
  elseif (string.find(cameraMake, "olympus", 1, true)) then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAFPixels = OlympusDelegates.getOlympusAfPoints    
  else
    local pointsMap, pointDimen = PointsRendererFactory.getFocusPoints(photo)
    DefaultDelegates.focusPointsMap = pointsMap
    DefaultDelegates.focusPointDimen = pointDimen
    DefaultPointRenderer.funcGetAFPixels = DefaultDelegates.getDefaultAfPoints
  end

  DefaultPointRenderer.funcGetShotOrientation = DefaultDelegates.getShotOrientation

  return DefaultPointRenderer
end

function PointsRendererFactory.getFocusPoints(photo)
  local cameraMake = string.lower(photo:getFormattedMetadata("cameraMake"))
  local cameraModel = string.lower(photo:getFormattedMetadata("cameraModel"))

  local focusPoints, focusPointDimens = PointsUtils.readIntoTable(cameraMake, cameraModel .. ".txt")

  if (focusPoints == nil) then
    return "No (or incorrect) mapping found at: \n" .. cameraMake .. "/" .. cameraModel .. ".txt"
  else
    return focusPoints, focusPointDimens
  end
end
