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

--[[ the factory will set these delegate methods with the appropriate function depending upon the camera --]]
DefaultPointRenderer.funcGetAFPixels = nil
DefaultPointRenderer.funcGetShotOrientation = nil
DefaultPointRenderer.focusPointDimen = nil

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

  local pX, pY = DefaultPointRenderer.funcGetAFPixels(targetPhoto, metaData)
  local x = pX
  local y = pY

  local shotOrientation = DefaultPointRenderer.funcGetShotOrientation(targetPhoto, metaData)

  --[[ lightroom does not report if a photo has been rotated. code below
        make sure the rotation matches the expected width and height --]]
  local isRotated = false
  if (shotOrientation == 90) then
    x = orgPhotoW - y - focusPointDimen[1]
    y = pX
    isRotated = true
  elseif (shotOrientation == 270) then
    x = pY
    y = orgPhotoH - pX - focusPointDimen[1]
    isRotated = true
  end
  -- TODO: check for "normal" to make sure the width is bigger than the height. if not, prompt
  -- the user to ask which way the photo was rotated

  if isRotated then
    log( "rotated" )
  end

  log( "orig x: " .. x .. ", y: " .. y )

  -- indicate the center for a given operation
  local x0
  local y0

  log( "photoDisplayW: " .. photoDisplayW .. ", photoDisplayH: " .. photoDisplayH .. ", croppedPhotoW: " .. croppedPhotoW .. ", croppedPhotoH: " .. croppedPhotoH )
  log( "cropLeft: " .. developSettings["CropLeft"] .. ", cropRight:" .. developSettings["CropRight"] )
  log( "cropTop: " .. developSettings["CropTop"] .. ", cropBottom: " .. developSettings["CropBottom"] )

  -- rotate
  local radRotation = math.rad(developSettings["CropAngle"])

  if 0 ~= radRotation then
    x0 = orgPhotoW / 2
    y0 = orgPhotoH / 2

    -- theta is angle from the center of the image to the focus point, before rotation
    local theta = -math.atan( (y-y0) / (x-x0) )

    -- radius is the distance from the center of the image to the focus point
    local radius = -((y-y0) / math.sin( theta ))

    -- newTheta is the current theta plus the image rotation
    local newTheta = theta + radRotation

    log( "deg: " .. developSettings["CropAngle"] .. ", rad: " .. radRotation .. ", theta: " .. theta .. ", radius: " .. radius .. ", newTheta: " .. newTheta )

    -- build the right triangle for the post-rotation focus point
    local opposite = radius * math.sin( newTheta )
    local adjacent = radius * math.cos( newTheta )

    log( "opposite: " .. opposite .. ", adjacent: " .. adjacent )

    -- adjust the focus point for the rotation
    x = (x0 + adjacent)
    y = (y0 - opposite)

    log( "rotated x: " .. x .. ", y: " .. y )
  end

  -- offset from center of image to center of crop
  local xCL = developSettings["CropLeft"] * orgPhotoW
  local xCR = developSettings["CropRight"] * orgPhotoW
  local yCT = developSettings["CropTop"] * orgPhotoH
  local yCB = developSettings["CropBottom"] * orgPhotoH
  log( "xCL: " .. xCL .. ", xCR: " .. xCR .. ", yCT: " .. yCT .. ", yCB: " .. yCB )

  x0 = orgPhotoW / 2
  y0 = orgPhotoH / 2
  xC = (xCL + xCR) / 2
  yC = (yCB + yCT) / 2
  log( "x0: " .. x0 .. ", y0: " .. y0 .. ", xC: " .. xC .. ", yC: " .. yC )

  x = x - (xC - x0)
  y = y - (yC - y0)

  log( "offset x: " .. x .. ", y: " .. y )

  -- crop
  local leftCropAmount = (orgPhotoW - croppedPhotoW) / 2
  local topCropAmount = (orgPhotoH - croppedPhotoH) / 2

  log( "leftCropAmount: " .. leftCropAmount .. ", topCropAmount: " .. topCropAmount )

  x = x - leftCropAmount
  y = y - topCropAmount

  log( "cropped x: " .. x .. ", y: " .. y )

  -- scale
  x0 = croppedPhotoW / 2
  y0 = croppedPhotoH / 2
  local xFromCenter = x0 - x
  local yFromCenter = y0 - y
  local xScaleFactor = (photoDisplayW/croppedPhotoW)
  local yScaleFactor = (photoDisplayH/croppedPhotoH)

  x = (x0 * xScaleFactor) - (xFromCenter * xScaleFactor)
  y = (y0 * yScaleFactor) - (yFromCenter * yScaleFactor)

  log( "scaled x: " .. x .. ", y: " .. y )

  -- done!
  if (x > photoDisplayW) or (x < 0) or (y > photoDisplayH) or (y < 0) then
    LrErrors.throwUserError("Sorry, something went wrong rendering the AF point.  Please submit logs.")
  end

  return DefaultPointRenderer.buildView(x, y, isRotated)
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

