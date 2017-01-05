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

--[[ The default focus box images with the rotational step as well as x and y offsets to the anchor point --]]
-- DefaultPointRenderer.focusBoxImage = { ["template"] = "bin/imgs/focus_box_%s.png", ["angleStep"] = 90, ["anchorX"] = 20, ["anchorY"] = 20 }
DefaultPointRenderer.focusBoxImage = { ["nameTemplate"] = "bin/imgs/focus_point_%s.png", ["angleStep"] = 5, ["anchorX"] = 23, ["anchorY"] = 23 }

--[[
-- targetPhoto - the selected catalog photo
-- photoDisplayWidth, photoDisplayHeight - the width and height that the photo view is going to display as.
--]]
function DefaultPointRenderer.createView(targetPhoto, photoDisplayWidth, photoDisplayHeight)
  local developSettings = targetPhoto:getDevelopSettings()
  local metaData = ExifUtils.readMetaData(targetPhoto)

  local originalWidth, originalHeight = parseDimens(targetPhoto:getFormattedMetadata("dimensions"))
  local croppedWidth, croppedHeight = parseDimens(targetPhoto:getFormattedMetadata("croppedDimensions"))
  local cropAngle = math.rad(developSettings["CropAngle"])
  local cropLeft = developSettings["CropLeft"]
  local cropTop = developSettings["CropTop"]

  local shotOrientation = DefaultPointRenderer.funcGetShotOrientation(targetPhoto, metaData)
  log("Shot orientation: " .. shotOrientation)

  local originalX, originalY = DefaultPointRenderer.funcGetAFPixels(targetPhoto, metaData)

  log( "cL: " .. cropLeft .. ", cT: " .. cropTop .. ", cAngle: " .. math.deg(cropAngle) .. "°")

  local x = originalX
  local y = originalY

  --[[ lightroom does not report if a photo has been rotated. code below
        make sure the rotation matches the expected width and height --]]
  local additionalRotation = 0
  if shotOrientation == 90 then
    x = originalY
    y = originalHeight - originalX
    cropLeft = developSettings["CropTop"]
    cropTop = 1 - developSettings["CropRight"]
    additionalRotation = math.pi / 2
  elseif shotOrientation == 270 then
    x = originalWidth - originalY
    y = originalX
    cropLeft = 1 - developSettings["CropBottom"]
    cropTop = developSettings["CropLeft"]
    additionalRotation = -math.pi / 2
  end

  log("shotOrientation: " .. shotOrientation .. "°, totalRotation: " .. math.deg(cropAngle + additionalRotation) .. "°")

  -- Rotation around 0,0
  local rX = x * math.cos(cropAngle) + y * math.sin(cropAngle)
  local rY = -x * math.sin(cropAngle) + y * math.cos(cropAngle)

  -- Rotation of top left corner
  local oX = cropLeft * originalWidth
  local oY = cropTop * originalHeight
  local roX = oX * math.cos(cropAngle) + oY * math.sin(cropAngle)
  local roY = -oX * math.sin(cropAngle) + oY * math.cos(cropAngle)

  -- Translation so the top left corner become the origin
  local tX = rX - roX
  local tY = rY - roY

  -- Let's resize everything to match the view
  tX = tX * photoDisplayWidth / croppedWidth
  tY = tY * photoDisplayHeight / croppedHeight

  return DefaultPointRenderer.buildView(tX, tY, cropAngle + additionalRotation)
end

--[[
-- Creates a view with the focus box placed and rotated at the right place
-- As Lightroom does not allow for rotating icons, we get the rotated image for the corresponding files
-- focusPointX, focusPointY - the center of the AF box
-- rotation - the rotation angle of the cropped image
--]]
function DefaultPointRenderer.buildView(focusPointX, focusPointY, rotation)
  local viewFactory = LrView.osFactory()

  local focusBoxImage = DefaultPointRenderer.focusBoxImage

  local fileName = focusBoxImage["nameTemplate"]
  if focusBoxImage["angleStep"] ~= nil and focusBoxImage["angleStep"] ~= 0 then
    local fileRotationSuffix = (focusBoxImage["angleStep"] * math.floor(0.5 + (math.deg(rotation) % 360) / focusBoxImage["angleStep"])) % 360
    fileName = string.format(fileName, fileRotationSuffix)
  end
  log("focusPointFileName: " .. fileName .. "")

  local myBox = viewFactory:picture {
    value = _PLUGIN:resourceId(fileName)
  }

  local boxView = viewFactory:view {
    myBox,
    margin_left = focusPointX - focusBoxImage["anchorX"],
    margin_top = focusPointY - focusBoxImage["anchorY"],
  }

  return boxView
end
