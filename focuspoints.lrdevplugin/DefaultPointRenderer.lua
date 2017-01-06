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
-- photo - the selected catalog photo
-- photoDisplayWidth, photoDisplayHeight - the width and height that the photo view is going to display as.
--]]
function DefaultPointRenderer.createView(photo, photoDisplayWidth, photoDisplayHeight)
  local developSettings = photo:getDevelopSettings()
  local metaData = ExifUtils.readMetaData(photo)

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
  local viewsTable = {}
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

    log("shotOrientation: " .. shotOrientation .. "°, totalRotation: " .. math.deg(cropAngle + additionalRotation) .. "°")

    local template = pointsTable.pointTemplates[point.pointType]
    if template == nil then
      LrErrors.throwUserError("Point template " .. point.pointType .. " could not be found.")
    else
      -- Inserting center icon view
      if template.center ~= nil then
        local cX, cY = transformCoordinates(x, y, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
        table.insert(viewsTable, DefaultPointRenderer.createPointView(cX, cY, cropAngle + additionalRotation, template.center.fileTemplate, template.center.anchorX, template.center.anchorY, template.angleStep))
      end

      -- Inserting corner icon views
      if template.corner ~= nil then
        -- Top Left, 0°
        local tlX, tlY = transformCoordinates(x - point.width/2, y - point.height/2, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
        -- Top Right, -90°
        local trX, trY = transformCoordinates(x + point.width/2, y - point.height/2, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
        -- Bottom Right, -180°
        local brX, brY = transformCoordinates(x + point.width/2, y + point.height/2, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)
        -- Bottom Left, -270°
        local blX, blY = transformCoordinates(x - point.width/2, y + point.height/2, cropLeft * originalWidth, cropTop * originalHeight, cropAngle, photoDisplayWidth / croppedWidth, photoDisplayHeight / croppedHeight)

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
  end

  local f = LrView.osFactory()
  viewsTable.place = "overlapping"

  return f:view(viewsTable)
end

--[[
-- Creates a view with the focus box placed and rotated at the right place
-- As Lightroom does not allow for rotating icons, we get the rotated image for the corresponding files
-- x, y - the center of the AF box
-- rotation - the rotation angle of the cropped image
--]]
function DefaultPointRenderer.createPointView(x, y, rotation, fileTemplate, anchorX, anchorY, angleStep)
  local fileName = fileTemplate
  if angleStep ~= nil and angleStep ~= 0 then
    local fileRotationSuffix = (angleStep * math.floor(0.5 + (math.deg(rotation) % 360) / angleStep)) % 360
    fileName = string.format(fileName, fileRotationSuffix)
  end
  log("focusPointFileName: " .. fileName .. "")

  local f = LrView.osFactory()

  local view = f:view {
    f:picture {
      value = _PLUGIN:resourceId(fileName)
    },
    margin_left = x - anchorX,
    margin_top = y - anchorY,
  }

  return view
end
