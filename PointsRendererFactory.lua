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
  Factory for creating the focus point renderer and getting the focus points. To expand this plugin to allow for more
  camera, just add more mapped points to the #getFocusPoints() and #getFocusPointDimens() methods
--]]

require "DefaultPointRenderer"
require "CameraNikonD7200"

PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(photo)
  return DefaultPointRenderer
end

function PointsRendererFactory.getFocusPoints(photo)
  local cameraMake = photo:getFormattedMetadata("cameraMake")
  local cameraModel = photo:getFormattedMetadata("cameraModel")
  log("cameraMake: " .. cameraMake .. ", cameraModel: " .. cameraModel)
  if (cameraMake == "NIKON CORPORATION") then
    if (cameraModel == "NIKON D7200") then
      return CameraNikonD7200.focusPoints, CameraNikonD7200.focusPointDimens
    end
  else 
    return nil
  end
end
