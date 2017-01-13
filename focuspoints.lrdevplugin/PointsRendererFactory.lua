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
require "CanonDelegates"
require "FujifilmDelegates"
require "OlympusDelegates"
require "PanasonicDelegates"
require "NikonDuplicates"

local LrErrors = import 'LrErrors'

PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(photo)
  local cameraMake = photo:getFormattedMetadata("cameraMake")
  local cameraModel = photo:getFormattedMetadata("cameraModel")

  if (cameraMake == nil or cameraModel == nil) then
    LrErrors.throwUserError("File doesn't contain camera maker or model")
  end

  cameraMake = string.lower(cameraMake)
  cameraModel = string.lower(cameraModel)
  
  logInfo("PointsRenderFactory", "Camera Make: " .. cameraMake)
  logInfo("PointsRenderFactory", "Camera Model: " .. cameraModel)
  
  -- some cameras have the same mapping as other camera
  -- check the cameraModel and switch it to a known map if it's a duplicate
  if (cameraMake == "nikon corporation") then
    local duplicateModel = NikonDuplicates[cameraModel]
    if (duplicateModel ~= nil) then
      cameraModel = duplicateModel
    end
  end

  if (cameraMake == "fujifilm") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = FujifilmDelegates.getAfPoints
  elseif (cameraMake == "canon") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = CanonDelegates.getAfPoints
  elseif (string.find(cameraMake, "olympus", 1, true)) then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = OlympusDelegates.getAfPoints
  elseif (string.find(cameraMake, "panasonic", 1, true)) then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = PanasonicDelegates.getAfPoints
  else
    local pointsMap, pointDimen = PointsRendererFactory.getFocusPoints(photo, cameraMake, cameraModel)
    DefaultDelegates.focusPointsMap = pointsMap
    DefaultDelegates.focusPointDimen = pointDimen
    DefaultPointRenderer.funcGetAfPoints = DefaultDelegates.getAfPoints
  end

  return DefaultPointRenderer
end

--[[
  Method to get the focus point maps from the text files. The params 
  passed in may be changed from what the camera reports. For instance, if the camera is a Nikon D7100
  the cameraModel will be passed as "nikon d7200" since they share the same
  focus point map.
  
  cameraMake - make of the camera
  cameraModel - make of the camera
--]]
function PointsRendererFactory.getFocusPoints(photo, cameraMake, cameraModel)
  local focusPoints, focusPointDimens = PointsUtils.readIntoTable(cameraMake, cameraModel .. ".txt")

  if (focusPoints == nil) then
    return "No (or incorrect) mapping found at: \n" .. cameraMake .. "/" .. cameraModel .. ".txt"
  else
    return focusPoints, focusPointDimens
  end
end
