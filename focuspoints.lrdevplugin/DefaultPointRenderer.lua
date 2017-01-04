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
local LrErrors = import 'LrErrors'

require "ExifUtils"

DefaultPointRenderer = {}
DefaultPointRenderer.funcGetAFPixels = nil
DefaultPointRenderer.funcGetShotOrientation = nil
DefaultPointRenderer.focusPointDimen = {300, 250}

--[[
-- targetPhoto - the selected catalog photo
-- photoDisplayW, photoDisplayH - the width and height that the photo view is going to display as.
--]]
function DefaultPointRenderer.createView(targetPhoto, photoDisplayW, photoDisplayH)
  local focusPointDimen = DefaultPointRenderer.focusPointDimen 
  local developSettings = targetPhoto:getDevelopSettings()
  local metaData = readMetaData(targetPhoto)
  local dimens = targetPhoto:getFormattedMetadata("dimensions")
  orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping
  local croppedDimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local croppedPhotoW, croppedPhotoH = parseDimens(croppedDimens) -- cropped size of the photo
  
  local pX, pY = DefaultPointRenderer.funcGetAFPixels(metaData)
  local x = pX
  local y = pY
  
  local leftCropAmount = developSettings["CropLeft"] * orgPhotoW
  local topCropAmount = developSettings["CropTop"] * orgPhotoH
  local shotOrientation = DefaultPointRenderer.funcGetShotOrientation(targetPhoto, metaData)
  
  --[[ lightroom does not report if a photo has been rotated. code below 
        make sure the rotation matches the expected width and height --]]
  local isRotated = false
  if (shotOrientation == 90) then
    x = orgPhotoW - y - focusPointDimen[1]
    y = pX
    leftCropAmount = (1- developSettings["CropBottom"]) * orgPhotoW
    topCropAmount = developSettings["CropLeft"] * orgPhotoH
    isRotated = true
  elseif (shotOrientation == 270) then
    x = pY
    y = orgPhotoH - pX - focusPointDimen[1]
    leftCropAmount = developSettings["CropTop"] * orgPhotoW
    topCropAmount = (1-developSettings["CropRight"]) * orgPhotoH
    isRotated = true
  end
  -- TODO: check for "normal" to make sure the width is bigger than the height. if not, prompt
  -- the user to ask which way the photo was rotated
  -- TODO: take into account rotation during crop
  
  local radRotation = math.rad(developSettings["CropAngle"])
  local xx = math.cos(radRotation) * (x - orgPhotoW/2) - math.sin(radRotation) * (y - orgPhotoH/2) + orgPhotoW/2
  local yy = math.sin(radRotation) * (x - orgPhotoW/2) + math.cos(radRotation) * (y - orgPhotoH/2) + orgPhotoH/2
  
  -- xrot=cos(θ)⋅(x−cx)−sin(θ)⋅(y−cy)+cx
  log( "x: " .. x .. ", xx: " .. xx .. ", y: " .. y .. ", yy: " .. yy)
  local deltaX = xx - x
  local deltaY = yy - y
  
  x = x - leftCropAmount + deltaX
  y = y - topCropAmount + deltaY
  
  local displayRatioW = photoDisplayW/croppedPhotoW
  local displayRatioH = photoDisplayH/croppedPhotoH
  local adjustedX = displayRatioW * x
  local adjustedY = displayRatioH * y
  
  return DefaultPointRenderer.buildView(adjustedX, adjustedY, isRotated)
  
end

function DefaultPointRenderer.buildView(focusPointX, focusPointY, isRotated)
  local viewFactory = LrView.osFactory()
  local focusAsset
  if (isRotated) then 
    focusAsset = "bin/imgs/focus_box_vert.png"
  else 
    focusAsset = "bin/imgs/focus_box_hor.png"
  end
  
  local myBox = viewFactory:picture {
    value = _PLUGIN:resourceId(focusAsset),
  }
  
  local boxView = viewFactory:view {
    myBox, 
    margin_left = focusPointX,
    margin_top = focusPointY,
  }
  
  return boxView
  
end

