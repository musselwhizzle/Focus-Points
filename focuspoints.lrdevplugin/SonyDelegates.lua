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
  A collection of delegate functions to be passed into the DefaultPointRenderer when
  the camera is Sony
--]]

local LrStringUtils = import "LrStringUtils"
local LrView = import "LrView"
require "Utils"

-- Sony says PDAF covers approximately 68% of the sensor
-- a7r3 images are 7952x5304 pixels, 3:2
-- sensor is 42 MP, 68% of which is 28,680,637.44
-- Focal Plane AF Point Area value is "640 428"
-- 640 * 428 * 10^2 == 27,392,000
-- 6400x4280, margins - left/right 776, top/bottom 512

--[[ old implementation
local pdafScale = 10 -- this is a guess
local focusLocationSize = 120
local pdafPointSize = 85
--]]

SonyDelegates = {}

-- To trigger display whether focus points have been detected or not
SonyDelegates.focusPointsDetected = false

-- Tag that indicates that makernotes / AF section is present
SonyDelegates.metaKeyAfInfoSection = "Sony Model ID"

-- AF relevant tags
SonyDelegates.metaKeyAfFocusMode                 = "Focus Mode"
SonyDelegates.metaKeyAfFocusLocation             = "Focus Location"
SonyDelegates.metaKeyAfFocusPosition2            = "Focus Position 2"
SonyDelegates.metaKeyAfAreaModeSetting           = "AF Area Mode Setting"
SonyDelegates.metaKeyAfAreaMode                  = "AF Area Mode"
SonyDelegates.metaKeyAfTracking                  = "AF Tracking"
SonyDelegates.metaKeyAfFocalPlaneAFPointsUsed    = "Focal Plane AF Points Used"
SonyDelegates.metaKeyAfFocalPlaneAFPointArea     = "Focal Plane AF Point Area"
SonyDelegates.metaKeyAfFocalPlaneAFPointLocation = "Focal Plane AF Point Location %s"
SonyDelegates.metaKeyAfFacesDetected             = "Faces Detected"
SonyDelegates.metaKeyAfFacePosition              = "Face %s Position"
SonyDelegates.metaKeyAfSonyImageWidth            = "Sony Image Width"
SonyDelegates.metaKeyAfSonyImageHeight           = "Sony Image Height"
SonyDelegates.metaKeyAfPointsUsed                = "AF Points Used"

-- Image and Camera Settings relevant tags
SonyDelegates.metaKeySceneMode                   = "Scene Mode"
SonyDelegates.metaKeyImageStabilization          = "Image Stabilization"

-- relevant metadata values
SonyDelegates.metaValueNA                         = "N/A"


--[[
  public table SonyDelegates.getAfPoints(photo, metaData)
  ----
  Get autofocus points and frames for detected face from metadata
--]]
function SonyDelegates.getAfPoints(photo, metaData)
  SonyDelegates.focusPointsDetected = false
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local result

  local focusPoint = ExifUtils.findValue(metaData, SonyDelegates.metaKeyAfFocusLocation)
  if focusPoint then
    local values = split(focusPoint, " ")
    local imageWidth = LrStringUtils.trimWhitespace(values[1])
    local imageHeight = LrStringUtils.trimWhitespace(values[2])
    local pdafPointSize = imageWidth*0.039/2  -- #TODO is 0.039/2 be different for other models?

    if imageWidth and imageHeight then
      if (imageWidth ~= "0") and (imageHeight ~= "0") then
        local xScale = orgPhotoWidth / imageWidth
        local yScale = orgPhotoHeight / imageHeight
        local x = LrStringUtils.trimWhitespace(values[3])
        local y = LrStringUtils.trimWhitespace(values[4])
        local pdafPointSize = imageWidth*0.039/2  -- #TODO is 0.039/2 be different for other models?

        logInfo("Sony", "Focus location at [" .. math.ceil(x * xScale) .. ", " .. math.floor(y * yScale) .. "]")
        SonyDelegates.focusPointsDetected = true
        result = {
          pointTemplates = DefaultDelegates.pointTemplates,
          points = {
            {
              pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
              x = x * xScale, -- - (pdafPointSize/2),
              y = y * yScale, -- - (pdafPointSize/2),
              width  = pdafPointSize,
              height = pdafPointSize
            }
          }
        }
      else
        -- focus location string is "0 0 0 0" -> the focus point is a PDAF point #FIXME but which one exactly?
      end
    end
  end

  -- Let's see if we used any PDAF points
  local numPdafPointsStr = ExifUtils.findValue(metaData, SonyDelegates.metaKeyAfFocalPlaneAFPointsUsed)
  if numPdafPointsStr then

    local numPdafPoints = LrStringUtils.trimWhitespace(numPdafPointsStr)
    if numPdafPoints then
      logDebug("Sony", "PDAF AF points used: " .. numPdafPoints)

      local pdafDimensionsStr = ExifUtils.findValue(metaData, SonyDelegates.metaKeyAfFocalPlaneAFPointArea)
      if pdafDimensionsStr then

        local pdafDimensions = split(pdafDimensionsStr, " ")
        local pdafWidth = LrStringUtils.trimWhitespace(pdafDimensions[1])
        local pdafHeight = LrStringUtils.trimWhitespace(pdafDimensions[2])
        if pdafWidth and pdafHeight then

          for i=1, numPdafPoints do
            local pdafPointStr = ExifUtils.findValue(
                    metaData, string.format(SonyDelegates.metaKeyAfFocalPlaneAFPointLocation, i))
            if pdafPointStr then

              local pdafPoint = split(pdafPointStr, " ")
              local x = LrStringUtils.trimWhitespace(pdafPoint[1])
              local y = LrStringUtils.trimWhitespace(pdafPoint[2])
              if x and y then
                logDebug("Sony", "PDAF unscaled point at [" .. x .. ", " .. y .. "]")
                -- #FIXME Does this really need to be scaled?
                -- #FIXME What else than the original image size could be imageWidth and ImageHeight?
                local imageWidth, imageHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
                local xScale = orgPhotoWidth / imageWidth
                local yScale = orgPhotoHeight / imageHeight
                local pdafX = (imageWidth*x/pdafWidth)*xScale
                local pdafY = (imageHeight*y/pdafHeight)*yScale
                local pdafPointSize = imageWidth*0.039/2  -- #TODO is 0.039/2 be different for other models?
                logInfo("Sony", "PDAF point at [" .. math.floor(pdafX) .. ", " .. math.floor(pdafY) .. "]")
                if not SonyDelegates.focusPointsDetected then
                  -- this is actually the focus point!
                  logInfo("Sony", "Focus location at [" .. math.ceil(x * xScale) .. ", " .. math.floor(y * yScale) .. "]")
                  SonyDelegates.focusPointsDetected = true
                  result = {
                    pointTemplates = DefaultDelegates.pointTemplates,
                    points = {
                      {
                        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
                        x = pdafX,
                        y = pdafY,
                        width = pdafPointSize,
                        height = pdafPointSize
                      }
                    }
                  }
                else
                  -- add the PDAF point as inactive point
                  table.insert(result.points, {
                    pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE,
                    x = pdafX,
                    y = pdafY,
                    width = pdafPointSize,
                    height = pdafPointSize
                  })
                end
              end
            end
          end
        end
      end
    end
  end

  -- Let see if we have detected faces
  local detectedFaces = ExifUtils.findValue(metaData, SonyDelegates.metaKeyAfFacesDetected)
  if detectedFaces and detectedFaces > "0" then
    for i=1, detectedFaces, 1 do
      local currFaceTag = string.format(SonyDelegates.metaKeyAfFacePosition, i)
      local coordinatesStr = ExifUtils.findValue(metaData, currFaceTag)
      if coordinatesStr ~= nil then
        -- format as per https://exiftool.org/TagNames/Sony.html:
        -- scaled to return the top, left, height and width of detected face,
        -- with coordinates relative to the full-sized unrotated image and increasing Y downwards)
        local coordinatesTable = split(coordinatesStr, " ")
        local w = coordinatesTable[3]
        local h = coordinatesTable[4]
        local x = coordinatesTable[2] + w/2
        local y = coordinatesTable[1] + h/2
        logInfo("Sony", "Face detected at [" .. x .. ", " .. y .. "]")
        local face = {
          pointType = DefaultDelegates.POINTTYPE_FACE,
          x = x,
          y = y,
          width  = w,
          height = h,
        }
        if result then
          table.insert(result.points, face)
        else
          -- an image can have detected face but no focus point!
          result = {
            pointTemplates = DefaultDelegates.pointTemplates,
            points = { face }
          }
        end
      end
    end
  end
  return result
end


--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table SonyDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
function SonyDelegates.addInfo(title, key, props, metaData)
  local f = LrView.osFactory()

  -- Helper function to create and populate the property corresponding to metadata key
  local function populateInfo(key)
    local value
    if type(key) == "string" then
      value = ExifUtils.findValue(metaData, key)
    else
      -- type(key) == "table"
      value = ExifUtils.findFirstMatchingValue(metaData, key)
    end
    if (value == nil) then
      props[key] = SonyDelegates.metaValueNA
    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- Helper function to wrap text across multiple rows to fit maximum column length
  local function wrapText(text, max_length)
    local result = ""
    local current_line = ""
    for word in text:gmatch("[^,]+") do
      word = word:gsub("^%s*(.-)%s*$", "%1")  -- Trim whitespace
      if #current_line + #word + 1 > max_length then
        result = result .. current_line .. "\n"
        current_line = word
      else
        if current_line == "" then
          current_line = word
        else
          current_line = current_line .. ", " .. word
        end
      end
    end
    if current_line ~= "" then
      result = result .. current_line
    end
    return result
  end

  -- create and populate property with designated value
  populateInfo(key)

  -- compose the row to be added
  local result = f:row {fill = 1,
                   f:column{f:static_text{title = title .. ":", font="<system>"}},
                   f:spacer{fill_horizontal = 1},
                   f:column{
                     f:static_text{
                       title = wrapText(props[key], 30),
  --                     alignment = "right",
                       font="<system>"}}
                  }
  -- decide if and how to add it
  if (props[key] == SonyDelegates.metaValueNA) then
    return FocusInfo.emptyRow()
--[[
  elseif (key == SonyDelegates.metaKeyBurstMode) and (props[key] == SonyDelegates.metaValueOn) then
    return f:column{
      fill = 1, spacing = 2, result,
      SonyDelegates.addInfo("Sequence Number", SonyDelegates.metaKeySequenceNumber, props, metaData)
    }
--]]
  elseif (key == SonyDelegates.metaKeyAfTracking) and string.find(string.lower(props[key]), "face") then
    return f:column{
      fill = 1, spacing = 2, result,
      SonyDelegates.addInfo("Faces Detected", SonyDelegates.metaKeyAfFacesDetected, props, metaData)
    }
  else
    -- add row as composed
    return result
  end
end


--[[
  @@public table function SonyDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function SonyDelegates.getImageInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local imageInfo
  return imageInfo
end


--[[
  @@public table function SonyDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function SonyDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  cameraInfo = f:column {
    fill = 1,
    spacing = 2,
    SonyDelegates.addInfo("Scene Mode"         , SonyDelegates.metaKeySceneMode         , props, metaData),
    SonyDelegates.addInfo("Image Stabilization", SonyDelegates.metaKeyImageStabilization, props, metaData),
  }
  return cameraInfo
end


--[[
  @@public table SonyDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function SonyDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, SonyDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section

  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(SonyDelegates.focusPointsDetected),
      SonyDelegates.addInfo("Focus Mode"          , SonyDelegates.metaKeyAfFocusMode             , props, metaData),
      SonyDelegates.addInfo("AF Area Mode Setting", SonyDelegates.metaKeyAfAreaModeSetting       , props, metaData),
      SonyDelegates.addInfo("AF Area Mode"        , SonyDelegates.metaKeyAfAreaMode              , props, metaData),
      SonyDelegates.addInfo("AF Tracking"         , SonyDelegates.metaKeyAfTracking              , props, metaData),
--    SonyDelegates.addInfo("PDAF Point Used"     , SonyDelegates.metaKeyAfFocalPlaneAFPointsUsed, props, metaData),
      }
  return focusInfo
end
