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

  local originalWidth, originalHeight = parseDimens(photo:getFormattedMetadata("dimensions"))
  local croppedWidth, croppedHeight = parseDimens(photo:getFormattedMetadata("croppedDimensions"))
  local cropAngle = math.rad(developSettings["CropAngle"])
  local cropLeft = developSettings["CropLeft"]
  local cropTop = developSettings["CropTop"]
  log( "cL: " .. cropLeft .. ", cT: " .. cropTop .. ", cAngle: " .. math.deg(cropAngle) .. "°")

  local shotOrientation = DefaultPointRenderer.funcGetShotOrientation(photo, metaData)
  log("Shot orientation: " .. shotOrientation)

  local pointsTable = DefaultPointRenderer.funcGetAfPoints(photo, metaData)
  if pointsTable == nil then
    return nil
  end

  -- Looping through the af-points and drawing them depending on their nature
  local viewsTable = {
    place = "overlapping"
  }

  for key, point in pairs(pointsTable.points) do
    local originalX = point.x
    local originalY = point.y

    local x = originalX
    local y = originalY

    --[[ lightroom does not report if a photo has been rotated. Code below
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
    --]]

    log("shotOrientation: " .. shotOrientation .. "°, totalRotation: " .. math.deg(cropAngle + additionalRotation) .. "°")

    local template = pointsTable.pointTemplates[point.pointType]
    if template == nil then
      LrErrors.throwUserError("Point template " .. point.pointType .. " could not be found.")
      return nil
    end

    -- Inserting center icon view
    local cX, cY
    if template.center ~= nil then
      cX, cY = transformCoordinates(x, y, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
      table.insert(viewsTable, DefaultPointRenderer.createPointView(cX, cY, cropAngle + additionalRotation, template.center.fileTemplate, template.center.anchorX, template.center.anchorY, template.angleStep))
    end

    -- Inserting corner icon views
    if template.corner ~= nil then
      -- Top Left, 0°
      local offsetX, offsetY = transformCoordinates(-point.width/2, -point.height/2, 0, 0, additionalRotation, 1, 1)
      local tlX, tlY = transformCoordinates(x + offsetX, y + offsetY, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
      -- Top Right, -90°
      offsetX, offsetY = transformCoordinates(point.width/2, -point.height/2, 0, 0, additionalRotation, 1, 1)
      local trX, trY = transformCoordinates(x + offsetX, y + offsetY, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
      -- Bottom Right, -180°
      offsetX, offsetY = transformCoordinates(point.width/2, point.height/2, 0, 0, additionalRotation, 1, 1)
      local brX, brY = transformCoordinates(x + offsetX, y + offsetY, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
      -- Bottom Left, -270°
      offsetX, offsetY = transformCoordinates(-point.width/2, point.height/2, 0, 0, additionalRotation, 1, 1)
      local blX, blY = transformCoordinates(x + offsetX, y + offsetY, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)

      -- Distance between tl and br corners in pixels on display
      local dist = math.sqrt((tlX - brX)^2 + (tlY - brY)^2)
      if dist > 25 then
        local cornerTemplate = template.corner
        if template.corner_small ~= nil and dist <= 100 then  -- should the distance between the corners be pretty small we switch to a small template if existinging
          cornerTemplate = template.corner_small
        end

        table.insert(viewsTable, DefaultPointRenderer.createPointView(tlX, tlY, cropAngle + additionalRotation, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
        table.insert(viewsTable, DefaultPointRenderer.createPointView(trX, trY, cropAngle + additionalRotation - math.pi/2, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
        table.insert(viewsTable, DefaultPointRenderer.createPointView(brX, brY, cropAngle + additionalRotation - math.pi, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
        table.insert(viewsTable, DefaultPointRenderer.createPointView(blX, blY, cropAngle + additionalRotation - 3*math.pi/2, cornerTemplate.fileTemplate, cornerTemplate.anchorX, cornerTemplate.anchorY, template.angleStep))
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
-- iconFileTemplate - the file path of the icon file to be used. %s will be replaced by the rotation angle module angleStep
-- anchorX, anchorY - the position in pixels of the anchor point in the image file
-- angleStep - the angle stepping in degrees used for the icon files. If angleStep = 10 and rotation = 26.7°, then "%s" will be replaced by "30"
--]]
function DefaultPointRenderer.createPointView(x, y, rotation, iconFileTemplate, anchorX, anchorY, angleStep)
  local fileName = iconFileTemplate
  if angleStep ~= nil and angleStep ~= 0 then
    local fileRotationSuffix = (angleStep * math.floor(0.5 + (math.deg(rotation) % 360) / angleStep)) % 360
    fileName = string.format(fileName, fileRotationSuffix)
  end

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
