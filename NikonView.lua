local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

require "ExifUtils"

NikonView = {}

--[[
-- targetPhoto - the selected catalog photo
-- metaData - the Exif metaData string extracted from the image
-- developSettings - the result of targetPhoto:getDevelopSettings()
-- photoW, photoH - the width and height that the photo is going to display as. 
--                So the 6000x4000 may only display at 600x400
--]]
function NikonView.createView(targetPhoto, metaData, developSettings, photoW, photoH)
  
  local focusPoint = NikonView.getAutoFocusPoint(metaData)
  local x = NikonView.focusPoints[focusPoint][1]
  local y = NikonView.focusPoints[focusPoint][2]
  
  local adjustedX = photoW/6000 * x;
  local adjustedY = photoH/4000 * y;
  
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
NikonView.focusPoints.B1 = {820, 1550}
NikonView.focusPoints.C1 = {820, 1880}
NikonView.focusPoints.D1 = {820, 2210}

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
