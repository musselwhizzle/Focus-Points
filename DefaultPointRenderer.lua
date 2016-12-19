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
  This object is responsible for creating the focus point icon and figuring out where to place it. 
  This logic should be universally reuseable, but if it's not, this object can be replaced in the 
  PointsRendererFactory. 
--]]

local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

require "ExifUtils"

DefaultPointRenderer = {}
DefaultPointRenderer.metaOrientation90 = "90"
DefaultPointRenderer.metaOrientation270 = "270"
DefaultPointRenderer.metaAFUsed = "AF Points Used"
DefaultPointRenderer.metaOrientation = "Orientation"

--[[
-- targetPhoto - the selected catalog photo
-- photoDisplayW, photoDisplayH - the width and height that the photo view is going to display as.
-- focusPoints - table containing app of the map focus points needed
-- focusPointDimen - table of dimension for the focus point. e.g. 300px x 200px is how big the D7200 focus point is
--]]
function DefaultPointRenderer.createView(targetPhoto, photoDisplayW, photoDisplayH, focusPoints, focusPointDimen)
  local developSettings = targetPhoto:getDevelopSettings()
  local metaData = readMetaData(targetPhoto)
  local dimens = targetPhoto:getFormattedMetadata("dimensions")
  orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping
  local croppedDimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local croppedPhotoW, croppedPhotoH = parseDimens(croppedDimens) -- cropped size of the photo
  
  local focusPoint = DefaultPointRenderer.getAutoFocusPoint(metaData)
  local x = focusPoints[focusPoint][1]
  local y = focusPoints[focusPoint][2]
  
  local leftCropAmount = developSettings["CropLeft"] * orgPhotoW
  local topCropAmount = developSettings["CropTop"] * orgPhotoH
  local metaOrientation = DefaultPointRenderer.getOrientation(metaData)
  
  --[[ lightroom does not report if a photo has been rotated. code below 
        make sure the rotation matches the expected width and height --]]
  if (string.match(metaOrientation, DefaultPointRenderer.metaOrientation90) and orgPhotoW < orgPhotoH) then
    x = orgPhotoW - y - focusPointDimen[1]
    y = focusPoints[focusPoint][1]
    leftCropAmount = (1- developSettings["CropBottom"]) * orgPhotoW
    topCropAmount = developSettings["CropLeft"] * orgPhotoH
    
  elseif (string.match(metaOrientation, DefaultPointRenderer.metaOrientation270) and orgPhotoW < orgPhotoH) then
    x = focusPoints[focusPoint][2]
    y = orgPhotoH - focusPoints[focusPoint][1] - focusPointDimen[1]
    leftCropAmount = developSettings["CropTop"] * orgPhotoW
    topCropAmount = (1-developSettings["CropRight"]) * orgPhotoH
    
  end
  -- TODO: check for "normal" to make sure the width is bigger than the height. if not, prompt
  -- the user to ask which way the photo was rotated
  
  x = x - leftCropAmount
  y = y - topCropAmount
  
  local displayRatioW = photoDisplayW/croppedPhotoW
  local displayRatioH = photoDisplayH/croppedPhotoH
  local adjustedX = displayRatioW * x
  local adjustedY = displayRatioH * y
  
  return DefaultPointRenderer.buildView(targetPhoto, adjustedX, adjustedY)
  
end

function DefaultPointRenderer.buildView(targetPhoto, focusPointX, focusPointY) 
  local viewFactory = LrView.osFactory()
  local myBox = viewFactory:picture {
    value = _PLUGIN:resourceId("bin/imgs/focus_point0.png"),
  }
  
  local boxView = viewFactory:view {
    myBox, 
    margin_left = focusPointX,
    margin_top = focusPointY,
  }
  
  return boxView
  
end


function DefaultPointRenderer.getAutoFocusPoint(metaData)
  local focusPointUsed = ExifUtils.findValue(metaData, DefaultPointRenderer.metaAFUsed)
  return focusPointUsed
end

function DefaultPointRenderer.getOrientation(metaData)
  local orientation = ExifUtils.findValue(metaData, DefaultPointRenderer.metaOrientation)
  return orientation
end
