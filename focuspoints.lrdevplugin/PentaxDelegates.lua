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

  **Note:
  Unlike other point delegates, this point delegates shows all in-active focus points. I'm
  not sure what the means for the other delegates. Perhaps I'll update them. Perhaps I'll update this file.

  Notes:
  * Back focus button sets AFPointsInFocus to 'None' regardless of point
    selection mode (sucks). AFPointSelected is set correctly with either button.
  * For phase detection AF, the coordinates taken from the point map represent
    the center of each AF point.

  2017.03.29 - roguephysicist: works for Pentax K-50 with both phase and contrast detection
--]]

local LrErrors = import 'LrErrors'
local LrView = import "LrView"

require "Utils"
require "Log"


PentaxDelegates = {}

PentaxDelegates.supportedModels = {
    "k-1 mark ii", "k-1", "k-3 ii", "k-3", "k-3_relative",
    "k-5 ii s", "k-5 ii", "k-5",
    "k-7", "k-30", "k-50", "k-70", "k-500",
    "k-r", "k-s1", "k-s2", "k-x",
    "k10d", "k20d", "k100d super", "k100d",
    "k110d", "k200d", "kp",
    "_a_ist d", "_a_ist ds", "_a_ist ds2"
}

PentaxDelegates.focusPointsDetected = false

PentaxDelegates.metaKeyAfInfoSection = "Pentax Version"

function PentaxDelegates.getAfPoints(photo, metaData)
  PentaxDelegates.focusPointsDetected = false

  local result
  local focusMode = splitTrim(ExifUtils.findValue(metaData, "Focus Mode"), " ")

  if focusMode then
    if focusMode[1] == "AF-A" or focusMode[1] == "AF-C" or focusMode[1] == "AF-S" then
      result = PentaxDelegates.getAfPointsPhase(photo, metaData)
    elseif focusMode[1] == "Contrast-detect" then
      result = PentaxDelegates.getAfPointsContrast(photo, metaData)
  --[[
    elseif focusMode == "Manual" then
      LrErrors.throwUserError("Manual focus: no useful focusing information found.")
    else
      LrErrors.throwUserError("Could not determine the focus mode of the camera.")
    end
  --]]
    else
      result = nil
    end
  return result
  end
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
    afPointsSelected = PentaxDelegates.fixCenter(afPointsSelected)
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

  local focusPointsMap, focusPointDimens = PointsUtils.readIntoTable(DefaultDelegates.cameraMake,
                                                           DefaultDelegates.cameraModel .. ".txt")

  if (focusPointsMap == nil) then
    -- model not supported
    return
  end

  for key,value in pairs(focusPointsMap) do
    local pointsMap = focusPointsMap[key]
    local x = pointsMap[1]
    local y = pointsMap[2]
    local width
    local height
    if (#pointsMap > 2) then
      width = pointsMap[3]
      height = pointsMap[4]
    else
      width  = focusPointDimens[1]
      height = focusPointDimens[2]
    end

    local pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE
    local isInFocus = arrayKeyOf(afPointsInFocus, key) ~= nil
    local isSelected = arrayKeyOf(afPointsSelected, key) ~= nil
    if isInFocus and isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS
      PentaxDelegates.focusPointsDetected = true
    elseif isInFocus then
      pointType = DefaultDelegates.POINTTYPE_AF_INFOCUS
      PentaxDelegates.focusPointsDetected = true
    elseif isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED
      PentaxDelegates.focusPointsDetected = true
    end

    table.insert(result.points, {
      pointType = pointType,
      x = x,
      y = y,
      width = width,
      height = height
    })

  end
  return result
end

--[[
  Function to get the autofocus points and focus size of the camera when shot in
  liveview mode returns typical points table
--]]
function PentaxDelegates.getAfPointsContrast(photo, metaData)
  -- local imageSize = ExifUtils.findFirstMatchingValue(metaData, { "Default Crop Size" })
  -- imageSize = splitTrim(imageSize, " ")
    -- Can image size be obtained from lightroom directly? Or is accessing the metadata faster?
    -- !!! DefaultCropSize not found in most test files !?!?
  local w, h = parseDimens(photo:getFormattedMetadata("croppedDimensions"))
  local imageSize = {w, h}
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  local contrastAfMode = ExifUtils.findFirstMatchingValue(metaData, { "AF Point Selected" })
    contrastAfMode = splitTrim(contrastAfMode, ";") -- pentax separates with ';'
  local faceDetectSize = ExifUtils.findFirstMatchingValue(metaData, { "Face Detect Frame Size" })
    faceDetectSize = splitTrim(faceDetectSize, " ")
  local facesDetected = ExifUtils.findFirstMatchingValue(metaData, { "Faces Detected" })
    facesDetected = tonumber(facesDetected)

  if contrastAfMode then
    if (contrastAfMode[1] == "Face Detect AF" and facesDetected > 0) then
-- #FIXME   or (contrastAfMode[1] == "Auto"           and facesDetected > 0)then
      local faces = {}
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

        PentaxDelegates.focusPointsDetected = true
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
    elseif (contrastAfMode[1] == "Face Detect AF" and facesDetected == 0) then
      LrErrors.throwUserError(getPhotoFileName(photo) .. "Face Detect AF mode enabled, but no faces detected.")
    else -- 'Automatic Tracking AF', 'Fixed Center', 'AF Select'
      local contrastDetectArea = ExifUtils.findFirstMatchingValue(metaData, { "Contrast Detect AF Area" })
        contrastDetectArea = splitTrim(contrastDetectArea, " ")

      local afAreaXPosition = (contrastDetectArea[1]+0.5*contrastDetectArea[3])*imageSize[1]/faceDetectSize[1]
      local afAreaYPosition = (contrastDetectArea[2]+0.5*contrastDetectArea[4])*imageSize[2]/faceDetectSize[2]
      local afAreaWidth = contrastDetectArea[3]*imageSize[1]/faceDetectSize[1]
      local afAreaHeight = contrastDetectArea[4]*imageSize[2]/faceDetectSize[2]

      if (afAreaWidth ~= 0) and (afAreaHeight ~= 0) then
        PentaxDelegates.focusPointsDetected = true
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
    end
  end
  return result
end


function PentaxDelegates.fixCenter(points)
  for k,v in pairs(points) do
    if v == 'Center (vertical)' or v == 'Center (horizontal)' or v == 'Fixed Center' then
      points[k] = 'Center'
    end
  end
  return points
end


--[[
  @@public boolean PentaxDelegates.modelSupported(model)
  ----
  Checks whether the camera model is supported or not
--]]
function PentaxDelegates.modelSupported(currentModel)
  local m = string.match(string.lower(currentModel), "pentax (.+)")
  for _, model in ipairs(PentaxDelegates.supportedModels) do
    if m == model then
      return true
    end
  end
  return false
end


--[[
  @@public table PentaxDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function PentaxDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()
  
  -- Check if the current camera model is supported
  if not PentaxDelegates.modelSupported(DefaultDelegates.cameraModel) then
    -- if not, finish this section with an error message
    return FocusInfo.errorMessage("Camera model not supported")
  end

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, PentaxDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(PentaxDelegates.focusPointsDetected),
      f:row {f:static_text {title = "Details not yet implemented", font="<system>"}}
      }
  return focusInfo
end
