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
a = require "affine"

DefaultPointRenderer = {}

--[[ the factory will set these delegate methods with the appropriate function depending upon the camera --]]
DefaultPointRenderer.funcGetAfPoints = nil
DefaultPointRenderer.funcGetShotOrientation = nil

--[[
-- Returns a LrView.osFactory():view containg all needed icons to draw the points returned by DefaultPointRenderer.funcGetAfPoints
-- photo - the selected catalog photo
-- photoDisplayWidth, photoDisplayHeight - the width and height that the photo view is going to display as.
--]]
function DefaultPointRenderer.createView(photo, photoDisplayWidth, photoDisplayHeight)
  local developSettings = photo:getDevelopSettings()
  local metaData = ExifUtils.readMetaDataAsTable(photo)

  local lrRotation, lrMirroring = DefaultPointRenderer.getLightroomGridTransformation(photo)
  local exifRotation = DefaultPointRenderer.funcGetShotOrientation(photo, metaData)

  local originalWidth, originalHeight = parseDimens(photo:getFormattedMetadata("dimensions"))
  local cropWidth, cropHeight = parseDimens(photo:getFormattedMetadata("croppedDimensions"))
  if lrRotation == math.pi/2 or lrRotation == -math.pi/2 then
    -- In case the image has been rotated by the user in the grid view, LR inverts width and height but does NOT change cropLeft and cropTop...
    -- In this methods, width and height refer to the original width and height
    local tmp = originalHeight
    originalHeight = originalWidth
    originalWidth = tmp

    tmp = cropHeight
    cropHeight = cropWidth
    cropWidth = tmp
  end
  local cropRotation = math.rad(developSettings["CropAngle"])
  local cropLeft = developSettings["CropLeft"]
  local cropTop = developSettings["CropTop"]

  log("DPR | originalDimensions: " .. originalWidth .. " x " .. originalHeight .. ", cropDimensions: " .. cropWidth .. " x " .. cropHeight .. ", displayDimensions: " .. photoDisplayWidth .. " x " .. photoDisplayHeight)
  log("DPR | exifRotation: " .. math.deg(exifRotation) .. "°, lrRotation: " .. math.deg(lrRotation) .. "°, lrMirroring: " .. lrMirroring)
  log("DPR | cropRotation: " .. math.deg(cropRotation) .. "°, cropLeft: " .. cropLeft .. ", cropTop: " .. cropTop)


  -- Calculating transformations
  local cropTransformation = a.rotate(-cropRotation) * a.trans(-cropLeft * originalWidth, -cropTop * originalHeight)

  local lrRotationTransformation
  local lrMirroringTransformation
  local displayScalingTransformation
  if lrRotation == math.pi/2 then
    lrRotationTransformation = a.trans(0, photoDisplayHeight) * a.rotate(-lrRotation)
    displayScalingTransformation = a.scale(photoDisplayHeight / cropWidth, photoDisplayWidth / cropHeight)
  elseif lrRotation == -math.pi/2 then
    lrRotationTransformation = a.trans(photoDisplayWidth, 0) * a.rotate(-lrRotation)
    displayScalingTransformation = a.scale(photoDisplayHeight / cropWidth, photoDisplayWidth / cropHeight)
  elseif lrRotation == math.pi then
    lrRotationTransformation = a.trans(photoDisplayWidth, photoDisplayHeight) * a.rotate(-lrRotation)
    displayScalingTransformation = a.scale(photoDisplayWidth / cropWidth, photoDisplayHeight / cropHeight)
  else
    lrRotationTransformation = a.trans(0, 0)
    displayScalingTransformation = a.scale(photoDisplayWidth / cropWidth, photoDisplayHeight / cropHeight)
  end

  if lrMirroring == -1 then
    lrMirroringTransformation = a.trans(photoDisplayWidth, 0) * a.scale(-1, 1)
  else
    lrMirroringTransformation = a.scale(1, 1)
  end

  local resultingTransformation = lrMirroringTransformation * (lrRotationTransformation * (displayScalingTransformation * cropTransformation))

  local pointsTable = DefaultPointRenderer.funcGetAfPoints(photo, metaData)
  if pointsTable == nil then
    return nil
  end

  -- Looping through the af-points and drawing them depending on their nature
  local viewsTable = {
    place = "overlapping"
  }

  for key, point in pairs(pointsTable.points) do
    local template = pointsTable.pointTemplates[point.pointType]
    if template == nil then
      LrErrors.throwUserError("Point template " .. point.pointType .. " could not be found.")
      return nil
    end

    -- Inserting center icon view
    local x, y = resultingTransformation(point.x, point.y)
    log("DPR | point.x: " .. point.x .. ", point.y: " .. point.y .. ", x: " .. x .. ", y: " .. y .. "")
    if template.center ~= nil then
      table.insert(viewsTable, DefaultPointRenderer.createPointView(x, y, cropRotation + lrRotation, lrMirroring, template.center.fileTemplate, template.center.anchorX, template.center.anchorY, template.angleStep))
    end

    -- Inserting corner icon views
    if template.corner ~= nil then
      -- Top Left, 0°
      local tlX, tlY = resultingTransformation(point.x - point.width/2, point.y - point.height/2)
      -- Top Right, -90°
      local trX, trY = resultingTransformation(point.x + point.width/2, point.y - point.height/2)
       -- Bottom Right, -180°
      local brX, brY = resultingTransformation(point.x + point.width/2, point.y + point.height/2)
       -- Bottom Left, -270°
      local blX, blY = resultingTransformation(point.x - point.width/2, point.y + point.height/2)

      -- Distance between tl and br corners in pixels on display
      local dist = math.sqrt((tlX - brX)^2 + (tlY - brY)^2)
      if dist > 25 then
        local cornerTemplate = template.corner
        if template.corner_small ~= nil and dist <= 100 then  -- should the distance between the corners be pretty small we switch to a small template if existinging
          cornerTemplate = template.corner_small
        end

        table.insert(viewsTable, DefaultPointRenderer.createPointView(tlX, tlY, cropRotation + lrRotation,                lrMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
        table.insert(viewsTable, DefaultPointRenderer.createPointView(trX, trY, cropRotation + lrRotation - math.pi/2,    lrMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
        table.insert(viewsTable, DefaultPointRenderer.createPointView(brX, brY, cropRotation + lrRotation - math.pi,      lrMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
        table.insert(viewsTable, DefaultPointRenderer.createPointView(blX, blY, cropRotation + lrRotation - 3*math.pi/2,  lrMirroring, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
      end
    end
  end

  return LrView.osFactory():view(viewsTable)
end

--[[
-- Creates a view with the focus box placed and rotated at the right place
-- As Lightroom does not allow for rotating icons, we get the rotated image from the corresponding file
-- x, y - the center of the icon to be drawn
-- rotation - the rotation angle of the icon in radian
-- horizontalMirroring - false or true
-- iconFileTemplate - the file path of the icon file to be used. %s will be replaced by the rotation angle module angleStep
-- anchorX, anchorY - the position in pixels of the anchor point in the image file
-- angleStep - the angle stepping in degrees used for the icon files. If angleStep = 10 and rotation = 26.7°, then "%s" will be replaced by "30"
--]]
function DefaultPointRenderer.createPointView(x, y, rotation, horizontalMirroring, iconFileTemplate, anchorX, anchorY, angleStep)
  local fileRotationStr = ""
  local fileMirroringStr = ""

  if angleStep ~= nil and angleStep ~= 0 then
    fileRotationStr = (angleStep * math.floor(0.5 + (math.deg(rotation) % 360) / angleStep)) % 360
  end

  if horizontalMirroring == -1 then
    fileMirroringStr = "-mirrored"
  end

  local fileName = string.format(iconFileTemplate, fileRotationStr .. fileMirroringStr)
log(fileName)
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
-- Takes a LrPhoto and returns the rotation and horizontal mirroring that the use has set in Lightroom (generaly in grid mode)
-- photo - the LrPhoto to calculate the values from
-- returns:
-- - rotation in rad in trigonometric sense
-- - horizontal mirroring (0 -> none, -1 -> yes)
--]]
function DefaultPointRenderer.getLightroomGridTransformation(photo)
  local lrRotation = photo:getRawMetadata("orientation")
  if lrRotation == nil or lrRotation == "AB" then
    return 0, 0
  elseif lrRotation == "BC" then
    return -math.pi/2, 0
  elseif lrRotation == "CD" then
    return math.pi, 0
  elseif lrRotation == "DA" then
    return math.pi/2, 0

  -- Same with horizontal mirroring
  elseif lrRotation == "BA" then
    return 0, -1
  elseif lrRotation == "CB" then
    return -math.pi/2, -1
  elseif lrRotation == "DC" then
    return math.pi, -1
  elseif lrRotation == "AD" then
    return math.pi/2, -1
  end

  log("DPR | We should never get there with an lrRotation = " .. lrRotation)
  return 0, 0
end
