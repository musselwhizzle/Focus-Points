local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

require "ExifUtils"

NikonView = {}

--[[
-- targetPhoto - the selected catalog photo
-- metaData - the Exif metaData string extracted from the image
-- developSettings - the result of targetPhoto:getDevelopSettings()
-- photoDisplayW, photoDisplayH - the width and height that the photo is going to display as. 
--                So the 6000x4000 may only display at 600x400
--]]
function NikonView.createView(targetPhoto, metaData, developSettings, photoDisplayW, photoDisplayH)
  local dimens = targetPhoto:getFormattedMetadata("dimensions")
  orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping
  local croppedDimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local croppedPhotoW, croppedPhotoH = parseDimens(croppedDimens) -- cropped size of the photo
  
  local focusPoint = NikonView.getAutoFocusPoint(metaData)
  local x = NikonView.focusPoints[focusPoint][1]
  local y = NikonView.focusPoints[focusPoint][2]
  
  local leftCropAmount = developSettings["CropLeft"] * orgPhotoW
  local topCropAmount = developSettings["CropTop"] * orgPhotoH
  x = x - leftCropAmount
  y = y - topCropAmount
  
  local displayRatioW = photoDisplayW/croppedPhotoW
  local displayRatioH = photoDisplayH/croppedPhotoH
  local adjustedX = displayRatioW * x
  local adjustedY = displayRatioH * y
  
  return NikonView.buildView(targetPhoto, adjustedX, adjustedY)
  
end

function NikonView.buildView(targetPhoto, focusPointX, focusPointY) 
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


function NikonView.getAutoFocusPoint(metaData)
  local focusPointUsed = ExifUtils.findValue(metaData, "AF Points Used")
  log("focusPointUsed: " .. focusPointUsed)
  return focusPointUsed
end

NikonView.focusPointDimen = {300, 250}
NikonView.focusPoints = {}

-- 1st column
NikonView.focusPoints.B1 = {810, 1550} -- verified in LR
NikonView.focusPoints.C1 = {810, 1865} -- verified in LR
NikonView.focusPoints.D1 = {810, 2210} -- verified in LR

-- 2nd column
NikonView.focusPoints.A1 = {1205, 1220}
NikonView.focusPoints.B2 = {1205, 1550}
NikonView.focusPoints.C2 = {1205, 1880}
NikonView.focusPoints.D2 = {1205, 2210}
NikonView.focusPoints.E1 = {1205, 2540}

-- 3rd column
NikonView.focusPoints.A2 = {1590, 1220}
NikonView.focusPoints.B3 = {1590, 1550}
NikonView.focusPoints.C3 = {1590, 1880}
NikonView.focusPoints.D3 = {1590, 2210}
NikonView.focusPoints.E2 = {1590, 2540}

-- 4th column
NikonView.focusPoints.A3 = {1975, 1220}
NikonView.focusPoints.B4 = {1975, 1550}
NikonView.focusPoints.C4 = {1975, 1880}
NikonView.focusPoints.D4 = {1975, 2210}
NikonView.focusPoints.E3 = {1975, 2540}

-- 5th column
NikonView.focusPoints.A4 = {2430, 1090}
NikonView.focusPoints.B5 = {2430, 1470}
NikonView.focusPoints.C5 = {2430, 1880}
NikonView.focusPoints.D5 = {2430, 2270}
NikonView.focusPoints.E4 = {2430, 2630}

-- 6th column
NikonView.focusPoints.A5 = {2840, 1090}
NikonView.focusPoints.B6 = {2840, 1470}
NikonView.focusPoints.C6 = {2840, 1880}
NikonView.focusPoints.D6 = {2840, 2270}
NikonView.focusPoints.E5 = {2840, 2630}


-- 7th column
NikonView.focusPoints.A6 = {3250, 1085}
NikonView.focusPoints.B7 = {3250, 1475}
NikonView.focusPoints.C7 = {3250, 1880}
NikonView.focusPoints.D7 = {3250, 2270}
NikonView.focusPoints.E6 = {3250, 2640}
