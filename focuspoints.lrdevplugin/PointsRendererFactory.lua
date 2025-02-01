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
  Factory for creating the focus point renderer and getting the focus points.
--]]

require "DefaultPointRenderer"
require "PointsUtils"
require "DefaultDelegates"
require "CanonDelegates"
require "FujifilmDelegates"
require "NikonDelegates"
require "OlympusDelegates"
require "PanasonicDelegates"
require "AppleDelegates"
require "PentaxDelegates"
require "NikonDuplicates"
require "SonyDelegates"
require "SonyRX10M4Delegates"

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

  -- normalize the camera names. Pentax can be called multiple things
  if (string.find(cameraMake, "ricoh imaging company", 1, true)
          or string.find(cameraMake, "pentax", 1, true)
          -- since K-3, tested with K-3, K-1, K-1 Mark II. cameraMake is too unspecific, therefor we test against cameraModel as well
          or (string.find(cameraMake, "ricoh", 1, true) and string.find(cameraModel, "pentax", 1, true))) then
    cameraMake = "pentax"
  end

  if (string.find(cameraMake, "nikon", 1, true)) then
    cameraMake = "nikon corporation"
  end

  -- some cameras have the same mapping as other camera
  -- check the cameraModel and switch it to a known map if it's a duplicate
  if (cameraMake == "nikon corporation") then
    local duplicateModel = NikonDuplicates[cameraModel]
    if (duplicateModel ~= nil) then
      cameraModel = duplicateModel
    end
  end

  logInfo("PointsRenderFactory", "Camera Make (after map): " .. cameraMake)
  logInfo("PointsRenderFactory", "Camera Model (after map): " .. cameraModel)

  if (cameraMake == "fujifilm") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = FujifilmDelegates.getAfPoints
  elseif (cameraMake == "canon") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = CanonDelegates.getAfPoints
  elseif (cameraMake == "apple") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = AppleDelegates.getAfPoints
  elseif (cameraMake == "sony") then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    if (cameraModel == "DSC-RX10M4") then
    	DefaultPointRenderer.funcGetAfPoints = SonyRX10M4Delegates.getAfPoints
    else DefaultPointRenderer.funcGetAfPoints = SonyDelegates.getAfPoints
    end
  elseif (cameraMake == "nikon corporation") then
    local pointsMap, pointDimen = PointsRendererFactory.getFocusPoints(photo, cameraMake, cameraModel)
    DefaultDelegates.focusPointsMap = pointsMap
    DefaultDelegates.focusPointDimen = pointDimen
    DefaultPointRenderer.funcGetAfPoints = NikonDelegates.getAfPoints
  elseif (string.find(cameraMake, "olympus", 1, true)) then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = OlympusDelegates.getAfPoints
  elseif (string.find(cameraMake, "om digital solutions", 1, true)) then  -- to support new camera maker OMDS (OM-1, OM-5), ref #162, 168
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = OlympusDelegates.getAfPoints   -- for OM-1, same logic applies as for Olympus cameras
  elseif (string.find(cameraMake, "panasonic", 1, true)) then
    DefaultDelegates.focusPointsMap = nil     -- unused
    DefaultDelegates.focusPointDimen = nil    -- unused
    DefaultPointRenderer.funcGetAfPoints = PanasonicDelegates.getAfPoints
  elseif (cameraMake == "pentax") then
    local pointsMap, pointDimen = PointsRendererFactory.getFocusPoints(photo, cameraMake, cameraModel)
    PentaxDelegates.focusPointsMap = pointsMap
    PentaxDelegates.focusPointDimen = pointDimen
    DefaultPointRenderer.funcGetAfPoints = PentaxDelegates.getAfPoints
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
