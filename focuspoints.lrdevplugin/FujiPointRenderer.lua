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

FujiPointRenderer = {}
FujiPointRenderer.metaOrientation90 = "90"
FujiPointRenderer.metaOrientation270 = "270"
FujiPointRenderer.metaOrientation = "Orientation"
FujiPointRenderer.metaFocusPixel = "Focus Pixel"

--[[
-- targetPhoto - the selected catalog photo
-- photoDisplayW, photoDisplayH - the width and height that the photo view is going to display as.
-- focusPoints - table containing app of the map focus points needed
-- focusPointDimen - table of dimension for the focus point. e.g. 300px x 200px is how big the D7200 focus point is
--]]
function FujiPointRenderer.createView(targetPhoto, photoDisplayW, photoDisplayH, focusPoints, focusPointDimen)
  local developSettings = targetPhoto:getDevelopSettings()
  local metaData = readMetaData(targetPhoto)
  local dimens = targetPhoto:getFormattedMetadata("dimensions")
  orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping
  local croppedDimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local croppedPhotoW, croppedPhotoH = parseDimens(croppedDimens) -- cropped size of the photo
  
  local focusPoint = FujiPointRenderer.getAutoFocusPoint(metaData)
  local x = focusPoint[1]
  local y = focusPoint[2]
  
  local leftCropAmount = developSettings["CropLeft"] * orgPhotoW
  local topCropAmount = developSettings["CropTop"] * orgPhotoH
  local metaOrientation = FujiPointRenderer.getOrientation(metaData)
  
  --[[ lightroom does not report if a photo has been rotated. code below 
        make sure the rotation matches the expected width and height --]]
  local isRotated = false
  if (string.match(metaOrientation, FujiPointRenderer.metaOrientation90) and orgPhotoW < orgPhotoH) then
    x = orgPhotoW - y - focusPointDimen[1]
    y = focusPoint[1]
    leftCropAmount = (1- developSettings["CropBottom"]) * orgPhotoW
    topCropAmount = developSettings["CropLeft"] * orgPhotoH
    isRotated = true
  elseif (string.match(metaOrientation, FujiPointRenderer.metaOrientation270) and orgPhotoW < orgPhotoH) then
    x = focusPoint[2]
    y = orgPhotoH - focusPoint[1] - focusPointDimen[1]
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
  
  return FujiPointRenderer.buildView(adjustedX, adjustedY, isRotated)
  
end

function FujiPointRenderer.buildView(focusPointX, focusPointY, isRotated)
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


function FujiPointRenderer.getAutoFocusPoint(metaData)
  local focusPointUsed = ExifUtils.findValue(metaData, FujiPointRenderer.metaFocusPixel)
  log ("Focus Pixel: ".. focusPointUsed)
  return FujiPointRenderer.mysplit(focusPointUsed)
end

function FujiPointRenderer.getOrientation(metaData)
  local orientation = ExifUtils.findValue(metaData, FujiPointRenderer.metaOrientation)
  return orientation
end

function FujiPointRenderer.mysplit(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end
