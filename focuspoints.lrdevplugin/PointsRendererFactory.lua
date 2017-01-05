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
local LrErrors = import 'LrErrors'

PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(photo)
  local cameraMake = PointsRendererFactory.getCameraMake(photo)
  local cameraModel = PointsRendererFactory.getCameraModel(photo)
  
  -- change the metadata names here
  if (cameraMake == "ricoh imaging company, ltd." and cameraModel == "pentax k-1") then
    DefaultDelegates.metaKeyAfPointUsed = "AF Points Selected"
  elseif (cameraMake == "canon") then
    DefaultDelegates.metaKeyAfPointUsed = "AF Points In Focus"
  end
  
  if (cameraMake == "fujifilm") then
      DefaultPointRenderer.funcGetAFPixels = FujiDelegates.getFujiAfPoints
      DefaultPointRenderer.focusPointDimen = {1,1} -- this is wrong. it's probably more like 300,250
  else 
    local pointsMap, pointDimen = PointsRendererFactory.getFocusPoints(photo)
    DefaultDelegates.focusPointsMap = pointsMap
    DefaultPointRenderer.funcGetAFPixels = DefaultDelegates.getDefaultAfPoints
    DefaultPointRenderer.focusPointDimen = pointDimen
  end
  
  
  DefaultPointRenderer.funcGetShotOrientation = DefaultDelegates.getShotOrientation
  return DefaultPointRenderer
end

function PointsRendererFactory.getFocusPoints(photo)
  local cameraMake = PointsRendererFactory.getCameraMake(photo)
  local cameraModel = PointsRendererFactory.getCameraModel(photo)
  
  local focusPoints, focusPointDimens =  PointsUtils.readIntoTable(cameraMake, cameraModel .. ".txt")
  
  if (focusPoints == nil) then
    return "No (or incorrect) mapping found at: \n" .. string.lower(cameraMake) .. "/" .. string.lower(cameraModel) .. ".txt"
  else 
    return focusPoints, focusPointDimens
  end
end

function PointsRendererFactory.getCameraMake(photo)
  return string.lower(photo:getFormattedMetadata("cameraMake"))
end

function PointsRendererFactory.getCameraModel(photo)
  return string.lower(photo:getFormattedMetadata("cameraModel"))
end