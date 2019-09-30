--[[
  Copyright 2016 Whizzbang Inc

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
local LrApplication = import 'LrApplication'
local LrPrefs = import "LrPrefs"

require "MogrifyUtils"
require "ExifUtils"
a = require "affine"

DefaultPointRenderer = {}

--[[ the factory will set these delegate methods with the appropriate function depending upon the camera --]]
DefaultPointRenderer.funcGetAfPoints = nil

--[[
-- Returns a LrView.osFactory():view containg all needed icons to draw the points returned by DefaultPointRenderer.funcGetAfPoints
-- photo - the selected catalog photo
-- photoDisplayWidth, photoDisplayHeight - the width and height that the photo view is going to display as.
--]]
function DefaultPointRenderer.createView(photo, photoDisplayWidth, photoDisplayHeight)
  local prefs = LrPrefs.prefsForPlugin( nil )
  local fpTable = DefaultPointRenderer.prepareRendering(photo, photoDisplayWidth, photoDisplayHeight)
  local viewFactory = LrView.osFactory()

  local photoView = nil
  local tmpView = nil
  local overlayViews = nil

  if fpTable == nil then
    return photoView
  end
  
  if prefs.mogrifyUsage then
    local fileName = MogrifyUtils.createDiskImage(photo, photoDisplayWidth, photoDisplayHeight)
    MogrifyUtils.drawFocusPoints(fpTable)
    photoView = viewFactory:view {
      viewFactory:picture {
        width  = photoDisplayWidth,
        height = photoDisplayHeight,
        value = fileName, 
      },
    }
  else
    overlayViews = DefaultPointRenderer.createOverlayViews(fpTable, photoDisplayWidth, photoDisplayHeight)

    -- create photo view 
    tmpView = viewFactory:catalog_photo {
      width = photoDisplayWidth, 
      height = photoDisplayHeight,
      photo = photo,
    }
    if (WIN_ENV == false) then
      photoView = viewFactory:view {
        tmpView, overlayViews, 
        place = 'overlapping', 
      }
    else
      -- windows has the z index switched
      photoView = viewFactory:view {
        overlayViews, tmpView, 
        place = 'overlapping', 
      }
    end
  end
  
  return photoView
end

--[[ Prepare raw focus data for rendering: apply crop factor, roation, etc
-- photo - the selected catalog photo
-- photoDisplayWidth, photoDisplayHeight - the width and height that the photo view is going to display as.
-- Returns a table with detailed focus point rendering data
--   points: array with  Center-, TopLeft-, TopRight-, BottonLeft-, BottonRight- point
--   rotation: user + crop rotation
--   userMirroring
--   template: template discribing the focus-point. See DefaultDelegates.lua
--   useSmallIcons
--]]
function DefaultPointRenderer.prepareRendering(photo, photoDisplayWidth, photoDisplayHeight)
  local developSettings = photo:getDevelopSettings()
  local metaData = ExifUtils.readMetaDataAsTable(photo)

  local originalWidth, originalHeight,cropWidth, cropHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local userRotation, userMirroring = DefaultPointRenderer.getUserRotationAndMirroring(photo)

  -- We read the rotation written in the Exif just for logging has it happens that the lightrrom rotation already includes it which is pretty handy
  local exifRotation = DefaultPointRenderer.getShotOrientation(photo, metaData)

  local cropRotation = developSettings["CropAngle"]
  local cropLeft = developSettings["CropLeft"]
  local cropTop = developSettings["CropTop"]

  logDebug("DefaultPointRenderer", "originalDimensions: " .. originalWidth .. " x " .. originalHeight .. ", cropDimensions: " .. cropWidth .. " x " .. cropHeight .. ", displayDimensions: " .. photoDisplayWidth .. " x " .. photoDisplayHeight)
  logDebug("DefaultPointRenderer", "exifRotation: " .. exifRotation .. "°, userRotation: " .. userRotation .. "°, userMirroring: " .. userMirroring)
  logDebug("DefaultPointRenderer", "cropRotation: " .. cropRotation .. "°, cropLeft: " .. cropLeft .. ", cropTop: " .. cropTop)


  -- Calculating transformations
  local cropTransformation = a.rotate(math.rad(-cropRotation)) * a.trans(-cropLeft * originalWidth, -cropTop * originalHeight)

  local userRotationTransformation
  local userMirroringTransformation
  local displayScalingTransformation
  if userRotation == 90 then
    userRotationTransformation = a.trans(0, photoDisplayHeight) * a.rotate(math.rad(-userRotation))
    displayScalingTransformation = a.scale(photoDisplayHeight / cropWidth, photoDisplayWidth / cropHeight)
  elseif userRotation == -90 then
    userRotationTransformation = a.trans(photoDisplayWidth, 0) * a.rotate(math.rad(-userRotation))
    displayScalingTransformation = a.scale(photoDisplayHeight / cropWidth, photoDisplayWidth / cropHeight)
  elseif userRotation == 180 then
    userRotationTransformation = a.trans(photoDisplayWidth, photoDisplayHeight) * a.rotate(math.rad(-userRotation))
    displayScalingTransformation = a.scale(photoDisplayWidth / cropWidth, photoDisplayHeight / cropHeight)
  else
    userRotationTransformation = a.trans(0, 0)
    displayScalingTransformation = a.scale(photoDisplayWidth / cropWidth, photoDisplayHeight / cropHeight)
  end

  if userMirroring == -1 then
    userMirroringTransformation = a.trans(photoDisplayWidth, 0) * a.scale(-1, 1)
  else
    userMirroringTransformation = a.scale(1, 1)
  end

  local resultingTransformation = userMirroringTransformation * (userRotationTransformation * (displayScalingTransformation * cropTransformation))
  local inverseResultingTransformation = a.inverse(resultingTransformation)

  local pointsTable = DefaultPointRenderer.funcGetAfPoints(photo, metaData)
  if pointsTable == nil then
    return nil
  end

  local fpTable = {  }

  for key, point in pairs(pointsTable.points) do
    local template = pointsTable.pointTemplates[point.pointType]
    if template == nil then
      logError("DefaultPointRenderer", "Point template '" .. point.pointType .. "'' could not be found.")
      LrErrors.throwUserError("Point template " .. point.pointType .. " could not be found.")
      return nil
    end

    -- Placing icons
    local x, y = resultingTransformation(point.x, point.y)
    logInfo("DefaultPointRenderer", "Placing point of type '" .. point.pointType .. "' at position [" .. point.x .. ", " .. point.y .. "] -> ([" .. math.floor(x) .. ", " .. math.floor(y) .. "] on display)")

    local useSmallIcons = false
    local pointWidth = point.width
    local pointHeight = point.height

    -- Checking if the distance between corners goes under the value of template.bigToSmallTriggerDist
    -- If so, we switch to small icons (when available)
    local x0, y0 = resultingTransformation(0, 0)
    local xHorizontal, yHorizontal = resultingTransformation(pointWidth, 0)
    local distHorizontal = math.sqrt((xHorizontal - x0)^2 + (yHorizontal - y0)^2)
    local xVertical, yVertical = resultingTransformation(0, pointHeight)
    local distVertical = math.sqrt((xVertical - x0)^2 + (yVertical - y0)^2)

    if template.bigToSmallTriggerDist ~= nil and (distHorizontal < template.bigToSmallTriggerDist or distVertical < template.bigToSmallTriggerDist) then
      useSmallIcons = true
      logDebug("DefaultPointRenderer", "distHorizontal: " .. distHorizontal .. ", distVertical: " .. distVertical .. ", bigToSmallTriggerDist: " .. template.bigToSmallTriggerDist .. " -> useSmallIcons: TRUE")
    else
      logDebug("DefaultPointRenderer", "distHorizontal: " .. distHorizontal .. ", distVertical: " .. distVertical .. ", bigToSmallTriggerDist: " .. template.bigToSmallTriggerDist .. " -> useSmallIcons: FALSE")
    end

    -- Checking if the distance between corners goes under the value of template.minCornerDist
    -- If so, we set pointWidth and/or pointHeight to the corresponding size to garantee this minimum distance
    local pixX0, pixY0 = inverseResultingTransformation(0, 0)
    local pixX1, pixY1 = inverseResultingTransformation(template.minCornerDist, 0)
    local minCornerPhotoDist = math.sqrt((pixX1 - pixX0)^2 + (pixY1 - pixY0)^2)

    if distHorizontal < template.minCornerDist then
      pointWidth = minCornerPhotoDist
    end
    if distVertical < template.minCornerDist then
      pointHeight = minCornerPhotoDist
    end
    logDebug("DefaultPointRenderer", "distHorizontal: " .. distHorizontal .. ", distVertical: " .. distVertical .. ", minCornerDist: " .. template.minCornerDist .. ", minCornerPhotoDist: " .. minCornerPhotoDist)

    -- Top Left, 0°
    local tlX, tlY = resultingTransformation(point.x - pointWidth/2, point.y - pointHeight/2)
    -- Top Right, -90°
    local trX, trY = resultingTransformation(point.x + pointWidth/2, point.y - pointHeight/2)
     -- Bottom Right, -180°
    local brX, brY = resultingTransformation(point.x + pointWidth/2, point.y + pointHeight/2)
     -- Bottom Left, -270°
    local blX, blY = resultingTransformation(point.x - pointWidth/2, point.y + pointHeight/2)

    points = {
      center = { x = x, y = y},
      tl  = { x = tlX, y = tlY },
      tr  = { x = trX, y = trY },
      bl  = { x = blX, y = blY },
      br  = { x = brX, y = brY },
    }

    table.insert(fpTable, { points = points, rotation = cropRotation + userRotation, userMirroring= userMirroring, template = template, useSmallIcons = useSmallIcons})
  end

  return fpTable
end


--[[ Create  overlay views
-- fpTable - table with rendering information for the focus points
-- photoDisplayWidth, photoDisplayHeight - the width and height that the photo view is going to display as.
-- Returns a table with overlay view
--]]
function DefaultPointRenderer.createOverlayViews(fpTable, photoDisplayWidth, photoDisplayHeight)

  local viewsTable = {
    place = "overlapping"
  }

  for key, fpPoint in pairs(fpTable) do
    -- Inserting center icon view
    if fpPoint.template.center ~= nil then
      if fpPoint.points.center.x >= 0 and fpPoint.points.center.x <= photoDisplayWidth and fpPoint.points.center.y >= 0 and fpPoint.points.center.y <= photoDisplayHeight then
        local centerTemplate = fpPoint.template.center
        if fpPoint.useSmallIcons and fpPoint.template.center_small ~= nil then
          centerTemplate = fpPoint.template.center_small
        end    
        table.insert(viewsTable, DefaultPointRenderer.createPointView(fpPoint.points.center.x, fpPoint.points.center.y, fpPoint.rotation, fpPoint.userMirroring, centerTemplate.fileTemplate, centerTemplate.anchorX, centerTemplate.anchorY, centerTemplate.angleStep))
      end  
    end

    -- Inserting corner icon views
    if fpPoint.template.corner ~= nil then
      local cornerTemplate = fpPoint.template.corner
      if fpPoint.useSmallIcons and fpPoint.template.corner_small ~= nil then
        cornerTemplate = fpPoint.template.corner_small
      end
    
      if fpPoint.points.tl.x >= 0 and fpPoint.points.tl.x <= photoDisplayWidth and fpPoint.points.tl.y >= 0 and fpPoint.points.tl.y <= photoDisplayHeight then
        table.insert(viewsTable, DefaultPointRenderer.createPointView(fpPoint.points.tl.x, fpPoint.points.tl.y, fpPoint.rotation, fpPoint.userMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, fpPoint.template.angleStep))
      end
      if fpPoint.points.tr.x >= 0 and fpPoint.points.tr.x <= photoDisplayWidth and fpPoint.points.tr.y >= 0 and fpPoint.points.tr.y <= photoDisplayHeight then
        table.insert(viewsTable, DefaultPointRenderer.createPointView(fpPoint.points.tr.x, fpPoint.points.tr.y, fpPoint.rotation - 90, fpPoint.userMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, fpPoint.template.angleStep))
      end
      if fpPoint.points.br.x >= 0 and fpPoint.points.br.x <= photoDisplayWidth and fpPoint.points.br.y >= 0 and fpPoint.points.br.y <= photoDisplayHeight then
        table.insert(viewsTable, DefaultPointRenderer.createPointView(fpPoint.points.br.x, fpPoint.points.br.y, fpPoint.rotation - 180, fpPoint.userMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, fpPoint.template.angleStep))
      end
      if fpPoint.points.bl.y >= 0 and fpPoint.points.bl.x <= photoDisplayWidth and fpPoint.points.bl.y >= 0 and fpPoint.points.bl.y <= photoDisplayHeight then
        table.insert(viewsTable, DefaultPointRenderer.createPointView(fpPoint.points.bl.x, fpPoint.points.bl.y, fpPoint.rotation - 270, fpPoint.userMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, fpPoint.template.angleStep))
      end
    end
  end

  return LrView.osFactory():view(viewsTable)
end

function DefaultPointRenderer.cleanup()
  local prefs = LrPrefs.prefsForPlugin( nil )
  if prefs.mogrifyUsage then
    MogrifyUtils.cleanup()
  end
end

--[[
-- Creates a view with the focus box placed rotated and mirrored at the right place. As Lightroom does not allow
--   for rotating icons right now nor for drawing, we get the rotated/mirrored image from the corresponding file name template
-- The method replaces the first '%s' in the iconFileTemplate by the passed rotation rounded to angleStep steps
--   and adds "-mirrored" to this if horizontalMirroring == -1
-- x, y - the center of the icon to be drawn
-- rotation - the rotation angle of the icon in degrees
-- horizontalMirroring - 0 or -1
-- iconFileTemplate - the file path of the icon file to be used. %s will be replaced by the rotation angle module angleStep
-- anchorX, anchorY - the position in pixels of the anchor point in the image file
-- angleStep - the angle stepping in degrees used for the icon files. If angleStep = 10 and rotation = 26.7°, then "%s" will be replaced by "30"
--]]
function DefaultPointRenderer.createPointView(x, y, rotation, horizontalMirroring, iconFileTemplate, anchorX, anchorY, angleStep)
  local fileRotationStr = ""

  if angleStep ~= nil and angleStep ~= 0 then
    local closestAngle = (angleStep * math.floor(0.5 + rotation / angleStep)) % 360
    if horizontalMirroring == -1 then
        fileRotationStr = (630 - closestAngle) % 360
    else
        fileRotationStr = closestAngle
    end
  end

  local fileName = string.format(iconFileTemplate, fileRotationStr)
  logDebug("createPointView", "fileName: " .. fileName)

  local viewFactory = LrView.osFactory()

  local view = viewFactory:view {
    viewFactory:picture {
      value = _PLUGIN:resourceId(fileName)
    },
    margin_left = x - anchorX,
    margin_top = y - anchorY,
  }

  return view
end

--[[
-- Takes a LrPhoto and returns the normalized original dimensions and cropped dimensions uninfluenced by the rotation
-- photo - the LrPhoto to calculate the values from
-- returns:
-- - originalWidth, originalHeight - original dimensions in unrotated position
-- - cropWidth, cropHeight - cropped dimensions in unrotated position
--]]
function DefaultPointRenderer.getNormalizedDimensions(photo)
  local originalWidth, originalHeight = parseDimens(photo:getFormattedMetadata("dimensions"))
  local cropWidth, cropHeight = parseDimens(photo:getFormattedMetadata("croppedDimensions"))
  local userRotation, userMirroring = DefaultPointRenderer.getUserRotationAndMirroring(photo)

  if userRotation == 90 or userRotation == -90 then
    -- In case the image has been rotated by the user in the grid view, LR inverts width and height but does NOT change cropLeft and cropTop...
    -- In this methods, width and height refer to the original width and height
    local tmp = originalHeight
    originalHeight = originalWidth
    originalWidth = tmp

    tmp = cropHeight
    cropHeight = cropWidth
    cropWidth = tmp
  end

  return originalWidth, originalHeight, cropWidth, cropHeight
end

--[[
-- Takes a LrPhoto and returns the rotation and horizontal mirroring that the user has choosen  in Lightroom (generaly in grid mode)
-- photo - the LrPhoto to calculate the values from
-- returns:
-- - rotation in degrees in trigonometric sense
-- - horizontal mirroring (0 -> none, -1 -> yes)
--]]
function DefaultPointRenderer.getUserRotationAndMirroring(photo)
  -- LR 5 throws an error even trying to access getRawMetadata("orientation")
  logDebug("DefaultPointRenderer", "LR version: " .. LrApplication.versionTable().major)
  if (LrApplication.versionTable().major < 6) then
    return DefaultPointRenderer.getShotOrientation(photo, ExifUtils.readMetaDataAsTable(photo)), 0
  end

  local userRotation = photo:getRawMetadata("orientation")
  if userRotation == nil then
    logWarn("DefaultPointRenderer", "userRotation = nil, which is unexpected starting with LR6")

    -- Falling back by trying to find the information with exifs.
    -- This is not working when the user rotates or mirrors the image within lightroom
    return DefaultPointRenderer.getShotOrientation(photo, ExifUtils.readMetaDataAsTable(photo)), 0
  elseif userRotation == "AB" then
    return 0, 0
  elseif userRotation == "BC" then
    return -90, 0
  elseif userRotation == "CD" then
    return 180, 0
  elseif userRotation == "DA" then
    return 90, 0

  -- Same with horizontal mirroring
  elseif userRotation == "BA" then
    return 0, -1
  elseif userRotation == "CB" then
    return -90, -1
  elseif userRotation == "DC" then
    return 180, -1
  elseif userRotation == "AD" then
    return 90, -1
  end

  logWarn("DefaultPointRenderer", "We should never get there with an userRotation = " .. userRotation)
  return 0, 0
end

--[[
  -- method figures out the orientation the photo was shot at by looking at the metadata
  -- returns the rotation in degrees in trigonometric sense
--]]
function DefaultPointRenderer.getShotOrientation(photo, metaData)
  local dimens = photo:getFormattedMetadata("dimensions")
  local orgPhotoW, orgPhotoH = parseDimens(dimens) -- original dimension before any cropping

  local metaOrientation = ExifUtils.findFirstMatchingValue(metaData, { "Orientation" })
  if metaOrientation == nil then
    return 0
  end

  if string.match(metaOrientation, "90 CCW") and orgPhotoW < orgPhotoH then
    return 90     -- 90° CCW
  elseif string.match(metaOrientation, "270 CCW") and orgPhotoW < orgPhotoH then
    return -90    -- 270° CCW
  elseif string.match(metaOrientation, "90") and orgPhotoW < orgPhotoH then
    return -90    -- 90° CW
  elseif string.match(metaOrientation, "270") and orgPhotoW < orgPhotoH then
    return 90     -- 270° CCW
  end

  return 0
end
