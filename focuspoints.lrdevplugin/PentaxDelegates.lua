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
  A collection of delegate functions to be passed into the DefaultPointRenderer
  for Pentax cameras.

  Notes:
  * Back focus button sets AFPointsInFocus to 'None' regardless of point
    selection mode (sucks). AFPointSelected is set correctly with either button.

  2017.03.29 - roguephysicist: works for Pentax K-50 with both phase and contrast detection
--]]

local LrStringUtils = import "LrStringUtils"
local LrErrors = import 'LrErrors'
require "Utils"

-- LrErrors.throwUserError(result)


PentaxDelegates = {}

PentaxDelegates.focusPointsMap = nil
PentaxDelegates.focusPointDimen = nil
PentaxDelegates.metaKeyFocusMode = {"Focus Mode"}

function PentaxDelegates.getAfPoints(photo, metaData)
  local focusMode = ExifUtils.findFirstMatchingValue(metaData, PentaxDelegates.metaKeyFocusMode)
  if (string.find(focusMode, 'AF%-S') ~= nil) then
    results = PentaxDelegates.getAfPointsPhase(photo, metaData)
  elseif (string.find(focusMode, 'Contrast%-detect') ~= nil) then
    results = PentaxDelegates.getAfPointsContrast(photo, metaData)
  end
  return results
end

--[[
-- photo - the photo LR object
-- metaData - the metadata as read by exiftool
--]]
function PentaxDelegates.getAfPointsPhase(photo, metaData)
  local afPointsSelected = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Selected" })
  if afPointsSelected == nil then
    afPointsSelected = {}
  else
    afPointsSelected = splitTrim(afPointsSelected, ";") -- pentax separates with ';'
  end
  local afPointsInFocus = ExifUtils.findFirstMatchingValue(metaData, { "AF Points In Focus" })
  if afPointsInFocus == nil then
    afPointsInFocus = {}
  else
    afPointsInFocus = splitTrim(afPointsInFocus, ",")
    afPointsInFocus = PentaxDelegates.fixCenter(afPointsInFocus)
  end
    
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  for key,value in pairs(PentaxDelegates.focusPointsMap) do
    local x = PentaxDelegates.focusPointsMap[key][1]
    local y = PentaxDelegates.focusPointsMap[key][2]
    local width = PentaxDelegates.focusPointDimen[1]
    local height = PentaxDelegates.focusPointDimen[2]
    
    local pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE
    local isInFocus = arrayKeyOf(afPointsInFocus, key) ~= nil
    local isSelected = arrayKeyOf(afPointsSelected, key) ~= nil
    if isInFocus and isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS
    elseif isInFocus then
      pointType = DefaultDelegates.POINTTYPE_AF_INFOCUS
    elseif isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED
    end

    if width > 0 and height > 0 then
      table.insert(result.points, {
        pointType = pointType,
        x = x,
        y = y,
        width = width,
        height = height
      })
    end
  end
  return result
end

--[[
  Function to get the autofocus points and focus size of the camera when shot in
  liveview mode returns typical points table
--]]
function PentaxDelegates.getAfPointsContrast(photo, metaData)
  local imageSize = ExifUtils.findFirstMatchingValue(metaData, { "Default Crop Size" })
    imageSize = splitTrim(imageSize, " ")
    -- Can image size be obtained from lightroom directly? Or is accessing the metadata faster?
  
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  local contrastAfMode = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Selected" })
    contrastAfMode = splitTrim(contrastAfMode, ";") -- pentax separates with ';'
  local faceDetectSize = ExifUtils.findFirstMatchingValue(metaData, { "Face Detect Frame Size" })
    faceDetectSize = splitTrim(faceDetectSize, " ")
  
  if contrastAfMode[1] == "Face Detect AF" then 
    local faces = {}
    local facesDetected = ExifUtils.findFirstMatchingValue(metaData, { "Faces Detected" })

    for face=1,facesDetected do
      local facePosition = ExifUtils.findFirstMatchingValue(metaData, { "Face " .. face .. " Position" })
        facePosition = splitTrim(facePosition, " ")
      local faceSize = ExifUtils.findFirstMatchingValue(metaData, { "Face " .. face .. " Size" })
        faceSize = splitTrim(faceSize, " ")
      faces[face] = {facePosition, faceSize}

      local afAreaXPosition = faces[face][1][1]*imageSize[1]/faceDetectSize[1]
      local afAreaYPosition = faces[face][1][2]*imageSize[2]/faceDetectSize[2]
      local afAreaWidth = faces[face][2][1]*imageSize[1]/faceDetectSize[1]
      local afAreaHeight = faces[face][2][2]*imageSize[2]/faceDetectSize[2]

      if afAreaWidth > 0 and afAreaHeight > 0 then
        table.insert(result.points, {
          pointType = DefaultDelegates.POINTTYPE_FACE,
          x = afAreaXPosition,
          y = afAreaYPosition,
          width = afAreaWidth,
          height = afAreaHeight
        })
      end
    end
  else -- 'Automatic Tracking AF', 'Fixed Center', 'AF Select'
    local contrastDetectArea = ExifUtils.findFirstMatchingValue(metaData, { "Contrast Detect AF Area" })
      contrastDetectArea = splitTrim(contrastDetectArea, " ")

    local afAreaXPosition = (contrastDetectArea[1]+0.5*contrastDetectArea[3])*imageSize[1]/faceDetectSize[1]
    local afAreaYPosition = (contrastDetectArea[2]+0.5*contrastDetectArea[4])*imageSize[2]/faceDetectSize[2]
    local afAreaWidth = contrastDetectArea[3]*imageSize[1]/faceDetectSize[1]
    local afAreaHeight = contrastDetectArea[4]*imageSize[2]/faceDetectSize[2]

    if afAreaWidth > 0 and afAreaHeight > 0 then
      table.insert(result.points, {
        pointType = DefaultDelegates.POINTTYPE_FACE,
        x = afAreaXPosition,
        y = afAreaYPosition,
        width = afAreaWidth,
        height = afAreaHeight
      })
    end
  end
  return result
end


function PentaxDelegates.fixCenter(points)
  for k,v in pairs(points) do
    if v == 'Center (vertical)' or v == 'Center (horizontal)' then
      points[k] = 'Center'
    end
  end
  return points
end
