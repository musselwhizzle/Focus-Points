local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

require "ExifUtils"

DefaultPointRenderer = {}
DefaultPointRenderer.focusPoints = nil
DefaultPointRenderer.focusPointDimens = nil

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
  log("orgPhotoW: " .. orgPhotoW .. ", orgPhotoH: " .. orgPhotoH)
  log("focusPoint: " .. focusPoint .. ", x: " .. x .. ", y: " .. y)
  
  local leftCropAmount = developSettings["CropLeft"] * orgPhotoW
  local topCropAmount = developSettings["CropTop"] * orgPhotoH
  

  local metaOrientation = DefaultPointRenderer.getOrientation(metaData)
  log ("metaOrientation: " .. metaOrientation)
  
  --[[ lightroom does not report if a photo has been rotated. code below 
        make sure the rotation matches the expected width and height --]]
  if (string.match(metaOrientation, "90") and orgPhotoW < orgPhotoH) then
    x = orgPhotoW - y - focusPointDimen[1]
    y = focusPoints[focusPoint][1]
    leftCropAmount = (1- developSettings["CropBottom"]) * orgPhotoW
    topCropAmount = developSettings["CropLeft"] * orgPhotoH
    
  elseif (string.match(metaOrientation, "270") and orgPhotoW < orgPhotoH) then
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
  local focusPointUsed = ExifUtils.findValue(metaData, "AF Points Used")
  return focusPointUsed
end

function DefaultPointRenderer.getOrientation(metaData)
  local orientation = ExifUtils.findValue(metaData, "Orientation")
  return orientation
end
