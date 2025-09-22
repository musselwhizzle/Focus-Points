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
  the camera is Olympus or OM Digital Solutions
--]]

local LrView   = import 'LrView'

require "FocusPointPrefs"
require "FocusPointDialog"
require "Utils"
require "Log"


OlympusDelegates = {}

-- Tag indicating that makernotes / AF section exists
OlympusDelegates.metaKeyAfInfoSection            = "Camera Settings Version"

-- AF-relevant tags
OlympusDelegates.metaKeyFocusMode                = "Focus Mode"
OlympusDelegates.metaKeyCafSensitivity           = "CAF Sensitivity"
OlympusDelegates.metaKeyAfSearch                 = "AF Search"
OlympusDelegates.metaKeySubjectTrackingMode      = "AI Subject Tracking Mode"
OlympusDelegates.metaKeyFocusDistance            = "Focus Distance"
OlympusDelegates.metaKeyDepthOfField             = "Depth Of Field"
OlympusDelegates.metaKeyHyperfocalDistance       = "Hyperfocal Distance"
OlympusDelegates.metaKeyReleasePriority          = "Release Priority"
OlympusDelegates.metaKeyAfPointDetails           = "AF Point Details"
OlympusDelegates.metaKeyAfPointSelected          = "AF Point Selected"
OlympusDelegates.metaKeyAfAreas                  = "AF Areas"
OlympusDelegates.metaKeyFocusProcess             = "Focus Process"

OlympusDelegates.metaKeyAFFrameSize              = "AF Frame Size"
OlympusDelegates.metaKeyAFFocusArea              = "AF Focus Area"
OlympusDelegates.metaKeyAFSelectedArea           = "AF Selected Area"
OlympusDelegates.metaKeySubjectDetectFrameSize   = "Subject Detect Frame Size"
OlympusDelegates.metaKeySubjectDetectArea        = "Subject Detect Area"
OlympusDelegates.metaKeySubjectDetectDetail      = "Subject Detect Detail"
OlympusDelegates.metaKeySubjectDetectStatus      = "Subject Detect Status"

OlympusDelegates.metaKeyFacesDetected            = "Faces Detected"
OlympusDelegates.metaKeyFaceDetectArea           = "Face Detect Area"
OlympusDelegates.metaKeyFaceDetectFrameCrop      = "Face Detect Frame Crop"
OlympusDelegates.metaKeyFaceDetectFrameSize      = "Face Detect Frame Size"
OlympusDelegates.metaKeyMaxFaces                 = "Max Faces"
OlympusDelegates.metaKeyAfEyePriority            = "Eye Priority"

-- Image and Shooting Information relevant tags
OlympusDelegates.metaKeyDriveMode                = "Drive Mode"
OlympusDelegates.metaKeyStackedImage             = "Stacked Image Custom"
OlympusDelegates.metaKeyImageStabilization       = "Image Stabilization"
OlympusDelegates.metaKeyDigitalZoomRatio         = "Digital Zoom Ratio"

-- Relevant metadata values
OlympusDelegates.metaKeyAfPointSelectedPattern   = "%((%d+)%%,(%d+)"
OlympusDelegates.metaKeyAfAreaPattern            = "%((%d+),(%d+)%)%-%((%d+),(%d+)%)"
OlympusDelegates.areaDetectStatus                = ""
OlympusDelegates.makerOlympus                    = "olympus"
OlympusDelegates.makerOMDS                       = "om digital solutions"


function findValue(metaData, key)
  local value = ExifUtils.findValue(metaData, key)
  if value then
    Log.logInfo("Olympus",
      string.format("Tag '%s' found: '%s'",key, value))
    return value
  else
    -- no focus points found - handled on upper layers
    Log.logInfo("Olympus",
      string.format("Tag '%s' not found", key))
    return nil
  end
end


--[[
  @@public table OlympusDelegates.getAfPoints(table photo, table metaData)
  ----
  Top level function to get the autofocus points from metadata
--]]
function OlympusDelegates.getAfPoints(photo, metaData)
  local pointsTable

  -- OM Digital Solution cameras support advanced metadata structures to detect focus areas/points
  local cameraMake = string.lower(photo:getFormattedMetadata("cameraMake"))
  if cameraMake == OlympusDelegates.makerOMDS then
    pointsTable = getOMDSAfPoints(photo, metaData)
  else
    pointsTable = getOlympusAfPoints(photo, metaData)
  end

  return pointsTable
end


--[[
  @@public table OlympusDelegates.getOMDSAfPoints(table photo, table metaData)
  ----
  Get autofocus point, AF target area and subject detection frames from OMDS specific metadata:
  https://exiftool.org/TagNames/Olympus.html#AFTargetInfo
  https://exiftool.org/TagNames/Olympus.html#SubjectDetectInfo
--]]
function getOMDSAfPoints(photo, metaData)

  -- Table to insert the detected elements for visualization
  local pointsTable = { pointTemplates = DefaultDelegates.pointTemplates, points = {} }

  -- Get photo dimensions for proper scaling of focus point
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  local function isSubjectDetection()
  -- returns true if the photo has been captured using subject tracking
    return get_nth_Word(
      ExifUtils.findValue(metaData, OlympusDelegates.metaKeySubjectTrackingMode),1,";")  ~= "Off"
  end

  local function isFaceDetection()
  -- returns true if the photo has been captured using subject tracking
    return string.find(
      ExifUtils.findValue(metaData, OlympusDelegates.metaKeyFocusMode),"Face Detect")
  end

  local function addFrame(xDimens, yDimens, xTL, yTL, width, height, scale, frameType, logText)
  -- adds a detection frame with top left corner at (xTL,yTL) to the list of focus points

    -- scale dimensions of detection frame area to image size
    local xScale = tonumber(orgPhotoWidth)  / (tonumber(xDimens))
    local yScale = tonumber(orgPhotoHeight) / (tonumber(yDimens))

    local x,y, w, h, d
    w = width  * xScale
    h = height * yScale
    x = xTL * xScale + w/2
    y = yTL * yScale + h/2

    -- @FIXME Needs a comment to explain this
    if scale > 1 then d = 30 else d = 0 end

    if w > 0 and h > 0 then
      Log.logInfo("Olympus", string.format(
       "%s at [x=%s, y=%s, w=%s, h=%s]", logText,
       math.floor(x), math.floor(y), math.floor(w), math.floor(h)))
      table.insert(pointsTable.points, {
        pointType = frameType,
        x = x,
        y = y,
        width  = w + d,
        height = h + d,
      })
     end
  end

  -- Process SubjectDetectInfo
  local hasSubjectDetectArea   = false
  local hasSubjectDetectDetail = false
  local subjectDetectFrameSize = findValue(metaData, OlympusDelegates.metaKeySubjectDetectFrameSize)
  if subjectDetectFrameSize and (subjectDetectFrameSize[1] ~= "0 0") then

    local subjectDetectArea   = findValue(metaData, OlympusDelegates.metaKeySubjectDetectArea)
    local subjectDetectDetail = findValue(metaData, OlympusDelegates.metaKeySubjectDetectDetail)

    subjectDetectFrameSize = split(subjectDetectFrameSize, " ")
    subjectDetectArea      = split(subjectDetectArea     , " ")
    subjectDetectDetail    = split(subjectDetectDetail   , " ")

    if subjectDetectArea[3] ~= "0" and subjectDetectArea[4] ~= "0" then
      -- area has width and heigth -> add frame to visualize detected subject
      addFrame(subjectDetectFrameSize[1], subjectDetectFrameSize[2],
               subjectDetectArea[1], subjectDetectArea[2], subjectDetectArea[3], subjectDetectArea[4],
               1.2, -- scale slightly bigger to avoid potential overlap with focus frame
               DefaultDelegates.POINTTYPE_FACE, "Subject detected")
      hasSubjectDetectArea = true
    end

    if subjectDetectDetail[3] ~= "0" and subjectDetectDetail[4] ~= "0" then
      -- area has width and heigth -> add frame to visualize detected subject detail
      addFrame(subjectDetectFrameSize[1], subjectDetectFrameSize[2],
               subjectDetectDetail[1], subjectDetectDetail[2], subjectDetectDetail[3], subjectDetectDetail[4],
               1.2, -- scale slightly bigger to avoid potential overlap with focus frame
               DefaultDelegates.POINTTYPE_FACE, "Subject detail detected")
      hasSubjectDetectDetail = true
    end
  end

  -- Process AFTargetInfo
  local afFrameSize    = findValue(metaData, OlympusDelegates.metaKeyAFFrameSize)
  local afFocusArea    = findValue(metaData, OlympusDelegates.metaKeyAFFocusArea)
  local afSelectedArea = findValue(metaData, OlympusDelegates.metaKeyAFSelectedArea)
  if afSelectedArea == "8 0 624 479" then afSelectedArea = "8 8 624 464" end   -- looks better!!

  if afFrameSize and (afFrameSize ~= "0 0") then

    local areasIdentical = (afFocusArea == afSelectedArea)

    afFrameSize    = split(afFrameSize   , " ")
    afFocusArea    = split(afFocusArea   , " ")
    afSelectedArea = split(afSelectedArea, " ")

    if afSelectedArea[3] ~= "0" and afSelectedArea[4] ~= "0" then
      -- #TODO review comment
      -- (status == "Subject Detected, No Detail" or status == "No Detection") then
      -- we will only look at this information for those cases where SubjectDetectInfo has max. one element
      -- -> as per experience from extensive testing there's not more than two meaningful detect elements
      --    the third is usually same or very similar to one of the two detect frames

      local scale = 1.2
      if areasIdentical then
        -- if focus area and selected area are identical in size, slightly enlarge selected area
        if afSelectedArea[3] / afFrameSize[1] > 1/scale or
           afSelectedArea[4] / afFrameSize[2] > 1/scale then
           -- avoid enlarging an area so that it potentially exceeds frame dimensions
          scale = 1
        end
      end

      -- if neither Subject nor Face Detection in ON, afSelectArea corresponds to the user selected AF area
      if not (isSubjectDetection() or isFaceDetection()) then
        -- draw white selection frame around user selected AF area
        if afSelectedArea[3] ~= "0" and afSelectedArea[4] ~= "0" then
          addFrame(afFrameSize[1], afFrameSize[2],
                   afSelectedArea[1], afSelectedArea[2],afSelectedArea[3], afSelectedArea[4], scale,
                   DefaultDelegates.POINTTYPE_AF_SELECTED, "Selected AF area")
        end
      elseif not hasSubjectDetectArea then
        -- use AFSelectArea as supplementary subject detect information
        if afSelectedArea[3] ~= "0" and afSelectedArea[4] ~= "0" then
          addFrame(afFrameSize[1], afFrameSize[2],
                   afSelectedArea[1], afSelectedArea[2],afSelectedArea[3], afSelectedArea[4], scale,
             DefaultDelegates.POINTTYPE_FACE, "Subject detected")
        end
      else
      end
    end

    -- draw frame around focus area (whose center is identical to AFPointSelected)
    if afFocusArea[3] ~= "0" and afFocusArea[4] ~= "0" then
      addFrame(afFrameSize[1], afFrameSize[2],
               afFocusArea[1], afFocusArea[2], afFocusArea[3], afFocusArea[4], 1,
               DefaultDelegates.POINTTYPE_AF_FOCUS_BOX, "Focus area")
      FocusInfo.focusPointsDetected = true
    end
  end

  -- if FocusArea is empty, fall back to the old Olympus method - AfPointSelected
  if not FocusInfo.focusPointsDetected then

    local focusPoint = findValue(metaData, OlympusDelegates.metaKeyAfPointSelected)
    if focusPoint and (focusPoint ~= "") and (focusPoint ~= "0 0") and (focusPoint ~= "undef undef undef undef") then

      -- extract (x,y) point values (rational numbers in range 0..1)
      local focusX = get_nth_Word(focusPoint, 1, " ")
      local focusY = get_nth_Word(focusPoint, 2, " ")

      -- transform the values into pixels
      local x = math.floor(tonumber(orgPhotoWidth)  * tonumber(focusX))
      local y = math.floor(tonumber(orgPhotoHeight) * tonumber(focusY))

      Log.logInfo("Olympus", string.format("Focus point detected at [x=%s, y=%s]", x, y))
      FocusInfo.focusPointsDetected = true

      -- return the focus point, visualized according to the plugin settings
      local point = DefaultPointRenderer.createFocusFrame(x, y)
      table.insert(pointsTable.points, point.points[1])

    else
      Log.logWarn("Olympus",
       string.format("Neither '%s' nor '%s' contain valid information about focus points",
         OlympusDelegates.metaKeyAFFocusArea, OlympusDelegates.metaKeyAfPointSelected))
      local afSearch = findValue(metaData, OlympusDelegates.metaKeyAfSearch)
      if afSearch and afSearch ~= "Ready" then
        Log.logWarn("Olympus", "Autofocus operations not successful, no confirmation received (green light or beep)")
      end
    end
  end

  -- Add face detection frames to the table, if any. The resulting number of yellow boxes might look confusing,
  -- but on OM-1 II there's no other way to display this information
  if pointsTable then
    OlympusDelegates.addFaces(photo, metaData, pointsTable)
  end

  -- Return table of the different elements to be visualized
  return pointsTable
end


--[[
  @@public table OlympusDelegates.getOlympusAfPoints(table photo, table metaData)
  ----
  #FIXME proper doc to be done
  Get the autofocus point from Olympus metadata:
  - position represented by AFPointSelected tag
--]]
function getOlympusAfPoints(photo, metaData)

  local focusPoint, focusAreas
  local pointsTable = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- Get photo dimensions for proper scaling
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  -- Look for focus point information: available on MFT and E-system models starting with E-420
  focusPoint = findValue(metaData, OlympusDelegates.metaKeyAfPointSelected)

  if focusPoint and (focusPoint ~= "") and (focusPoint ~= "0 0") and (focusPoint ~= "undef undef undef undef") then

    local focusX, focusY
    if string.find(focusPoint, "%%") then
      -- for some reason, exiftool.config has not been considered -> parse standard format for this tag
      Log.logWarn("Olympus", string.format(
        "Exiftool.config not found. Use standard format for '%s'", OlympusDelegates.metaKeyAfPointSelected))
      focusX, focusY = string.match(focusPoint, OlympusDelegates.metaKeyAfPointSelectedPattern)
      if not (focusX and focusY) then
        Log.logError("Olympus", "Error at extracting x/y positions from focus point tag")
        return nil
      else
        focusX = tonumber(focusX) / 100
        focusY = tonumber(focusY) / 100
      end
    else
      -- extract (x,y) point values (rational numbers in range 0..1)
      focusX = get_nth_Word(focusPoint, 1, " ")
      focusY = get_nth_Word(focusPoint, 2, " ")
    end

    if not (focusX and focusY) then
      Log.logError("Olympus",
        string.format('Could not extract (x,y) coordinates from "%s" tag', Olympus.metaKeyAfPointPosition))
      return nil
    end

    -- transform the values into (integer) pixels
    local x = math.floor(tonumber(orgPhotoWidth)  * tonumber(focusX))
    local y = math.floor(tonumber(orgPhotoHeight) * tonumber(focusY))

    Log.logInfo("Olympus", string.format("Focus point detected at [x=%s, y=%s]", x, y))

    FocusInfo.focusPointsDetected = true

    -- return the focus point, visualized according to the plugin settings
    pointsTable = DefaultPointRenderer.createFocusFrame(x, y)

  else
    -- Look for focus areas information: available for all MFT and E-system models
    focusAreas = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyAfAreas)
    if focusAreas then

      if string.lower(focusAreas) ~= "none" then

        local function split_exact(str, delimiter)
          local result = {}
          local from = 1
          local delim_from, delim_to = string.find(str, delimiter, from)
          while delim_from do
            local part = string.sub(str, from, delim_from - 1)
            table.insert(result, part)
            from = delim_to + 1
            delim_from, delim_to = string.find(str, delimiter, from)
          end
          table.insert(result, string.sub(str, from))
          return result
        end

        local afAreas = split_exact(focusAreas, ", ")

        -- loop over all elements in table
        for i = 1, #afAreas, 1 do

          -- extract coordinates of top-left and bottom-right corner points (coordinates range from 0 to 255)
          local xTL, yTL, xBR, yBR = string.match(afAreas[i], OlympusDelegates.metaKeyAfAreaPattern)
          if not (xTL and yTL and xBR and yBR) then
            Log.logError("Olympus", "Error at extracting (x,y) position of focus area: ".. afAreas[i])
          else
            -- transform the byte values 0..255 into pixel coordinates
            xTL = tostring(math.floor(tonumber(orgPhotoWidth)   * tonumber(xTL)/256))
            yTL = tostring(math.floor(tonumber(orgPhotoHeight)  * tonumber(yTL)/256))
            xBR = tostring(math.floor(tonumber(orgPhotoWidth)   * tonumber(xBR)/256))
            yBR = tostring(math.floor(tonumber(orgPhotoHeight)  * tonumber(yBR)/256))

            if (xTL < xBR) and (yTL < yBR) then

              FocusInfo.focusPointsDetected = true
              Log.logInfo("Olympus", string.format(
               "Focus area detected at [x1=%s, y1=%s, x2=%s, y2=%s]", xTL, yTL,xBR, yBR))

              table.insert(pointsTable.points, {
                pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
                x = xTL + (xBR - xTL)/2,
                y = yTL + (yBR - yTL)/2,
                width  = xBR - xTL,
                height = yBR - yTL,
              })
            else
              Log.logError("Olympus", string.format(
               "Invalid focus area detected at [x1=%s, y1=%s, x2=%s, y2=%s]", xTL, yTL,xBR, yBR))
            end
          end
        end

      else
        Log.logWarn("Olympus",
          string.format("Tag '%s' has no information on focus areas",
            OlympusDelegates.metaKeyAfAreas, focusAreas))
      end

    else
      -- at least one tag must have information to continue
      Log.logWarn("Olympus",
        string.format("Neither '%s' nor '%s' found",
          OlympusDelegates.metaKeyAfPointSelected, OlympusDelegates.metaKeyAfAreas))
    end
  end

  -- If not focus points have been found, check status of AF operations
  if not FocusInfo.focusPointsDetected then
    local afSearch = findValue(metaData, OlympusDelegates.metaKeyAfSearch)
    if afSearch and afSearch ~= "Ready" then
      Log.logWarn("Olympus", "Autofocus operations not successful, no confirmation received (green light or beep)")
    end
  end

  -- Add face detection frames, if any
  if pointsTable then
    OlympusDelegates.addFaces(photo, metaData, pointsTable)
  end

  return pointsTable
end


--[[
  @@public void OlympusDelegates.addFaces(table photo, table metaData, table pointsTable)
  ----
  Add face detection frames to table with focus points/areas (which must not be nil!)
--]]
function OlympusDelegates.addFaces(photo, metaData, pointsTable)

  OlympusDelegates.facesDetected = false

  -- Sanity check
  if not pointsTable then return end

  -- Get photo dimensions for proper scaling of focus point
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  -- Let's see if we have detected faces - need to check the tag 'Faces Detected' (format: "a b c")
  -- (a, b, c) are the numbers of detected faces in each of the 2 supported sets of face detect area
  local detectedFaces = split(ExifUtils.findValue(metaData, OlympusDelegates.metaKeyFacesDetected), " ")
  local maxFaces      = split(ExifUtils.findValue(metaData, OlympusDelegates.metaKeyMaxFaces), " ")

  local faceDetectArea
  if detectedFaces and ((detectedFaces[1] ~= "0") or (detectedFaces[2] ~= "0")) then
    -- Faces have been detected for this image, let's get the details

    local faceDetectFrameCrop = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyFaceDetectFrameCrop)
    if faceDetectFrameCrop then
      faceDetectFrameCrop = split(faceDetectFrameCrop, " ")
    end

    local faceDetectFrameSize = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyFaceDetectFrameSize)
    if faceDetectFrameSize then
      faceDetectFrameSize = split(faceDetectFrameSize, " ")
    end

    faceDetectArea = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyFaceDetectArea)
    if string.find(faceDetectArea, "Binary data") then
      -- for some reason, exiftool.config has not been considered -> extra call to exiftool to read binary data
      Log.logWarn("Olympus", string.format(
        "Exiftool.config not found. Need extra call to ExifTool to retrieve binary data for '%s'",
        OlympusDelegates.metaKeyFaceDetectArea))
      faceDetectArea = ExifUtils.getBinaryValue(photo, OlympusDelegates.metaKeyFaceDetectArea)
    end

    if faceDetectArea then
      faceDetectArea = split (faceDetectArea, " ")

      -- Loop over FaceDetectArea to construct the face detect face frames
      -- Format of FaceDetectArea:
      -- 3 sets x 8 (=MaxFaces) tuples (x,y,h,r) where:
      -- 'x' and 'y' give the coordinates, 'h' the size and 'r' the rotation angle of the face detect square
      -- FaceDetectFrameCrop (x,y,w,h) gives x/y offset and width/height of the cropped face detect frame
      local x,y, w, h
      for i=1, 3, 1 do
        if (detectedFaces[i] ~= "0") then
          local xScale = tonumber(orgPhotoWidth)  / (tonumber(faceDetectFrameSize[(i-1)*2+1]))
          local yScale = tonumber(orgPhotoHeight) / (tonumber(faceDetectFrameSize[(i-1)*2+2]))
          local k
          for j=1, detectedFaces[i], 1 do
            if i == 1 then k=(j-1)*4 else k = maxFaces[i-1]*4 + (j-1)*4 end
            x = (faceDetectArea[k+1] - faceDetectFrameCrop[(i-1)*4 + 1]) * xScale
            y = (faceDetectArea[k+2] - faceDetectFrameCrop[(i-1)*4 + 2]) * yScale
            w = (faceDetectArea[k+3]                                   ) * xScale
            h = (faceDetectArea[k+3]                                   ) * yScale

            OlympusDelegates.facesDetected = true
            Log.logInfo("Olympus", "Face detected at [" .. x .. ", " .. y .. "]")
            table.insert(pointsTable.points, {
              pointType = DefaultDelegates.POINTTYPE_FACE,
              x = x,
              y = y,
              width  = w,
              height = h,
            })
          end
        end
      end
    else
      Log.logError("Olympus", "Error at extracting x/y positions from focus point tag")
      return
    end
  end
end


--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table OlympusDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Create view element for adding an item to the info section; creates and populates the corresponding view property
--]]
function OlympusDelegates.addInfo(title, key, props, metaData)
  local f = LrView.osFactory()

  local function escape(text)
    if text then
      return string.gsub(text, "&",  "＆")
    else
      return nil
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Creates and populates the property corresponding to metadata key
  local function populateInfo(key)
  local value = ExifUtils.findValue(metaData, key)

    if not value then
      props[key] = ExifUtils.metaValueNA

    elseif (key == OlympusDelegates.metaKeyFocusMode) then
      -- special case: Focus Mode. Add MF if selected in settings
        props[key] = OlympusDelegates.getFocusMode(value)

    elseif (title == "Release Priority") then
      -- special case: AFPointDetails. Extract ReleasePriority portion
      if value then
        props[key] = get_nth_Word(value, 7, ";")
      end

    elseif (title == "Eye Priority") then
      -- special case: AFPointDetails. Extract EyePriority portion
      if value then
        props[key] = get_nth_Word(value, 4, ";")
        if not OlympusDelegates.facesDetected then
          props[key] = ExifUtils.metaValueNA
        end
      end

    elseif (key == OlympusDelegates.metaKeyDigitalZoomRatio) then
      if (value ~= "0") and (value ~= "1")  then
        props[key] = value .. "x"
      else
        props[key] = ExifUtils.metaValueNA
      end

    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if not props[key] or arrayKeyOf({"N/A", "Off", "No"}, props[key]) then
    -- we won't display any "empty" entries - return empty row
    return FocusInfo.emptyRow()
  end

  if key == OlympusDelegates.metaKeyStackedImage and props[key] == "No" then
    return FocusInfo.emptyRow()
  end

  if key == OlympusDelegates.metaKeyFacesDetected then
    local facesDetected = props[OlympusDelegates.metaKeyFacesDetected]
    if facesDetected ~= "0 0 0" then
    -- use this value as main indicator for Face Detection;
    -- information in FocusMode and AFPointDetails is not consistent (for one image and across models)
      local faceDetectInfo = OlympusDelegates.getFaceDetectInfo(metaData)
      if faceDetectInfo then
        props[OlympusDelegates.metaKeyFacesDetected] = OlympusDelegates.getFaceDetectInfo(metaData)
      else
        return FocusInfo.emptyRow()
      end
    else
      return FocusInfo.emptyRow()
    end
  end

  if key == OlympusDelegates.metaKeySubjectTrackingMode then
    if string.sub(props[key],1, 3) == "Off" then
      -- do not display this entry if setting was not enabled
      return FocusInfo.emptyRow()
    end
  end

  -- compose the row to be added
  local result = FocusInfo.addRow(title, props[key])

  -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
  if key == OlympusDelegates.metaKeyFocusMode then
    local focusMode = props[key]:match("^(.-[- ]AF)")
    if focusMode == "S-AF" or focusMode == "Single AF" then
      return f:column{fill = 1, spacing = 2, result,
  --    OlympusDelegates.addInfo("Eye Priority",     OlympusDelegates.metaKeyAfPointDetails, props, metaData),
        OlympusDelegates.addInfo("Release Priority", OlympusDelegates.metaKeyAfPointDetails, props, metaData),
        OlympusDelegates.addInfo("AF Search",        OlympusDelegates.metaKeyAfSearch,       props, metaData),
      }
    elseif focusMode == "C-AF" or focusMode == "Continuous AF" then
      return f:column{fill = 1, spacing = 2, result,
  --    OlympusDelegates.addInfo("Eye Priority",     OlympusDelegates.metaKeyAfPointDetails, props, metaData),
        OlympusDelegates.addInfo("Release Priority", OlympusDelegates.metaKeyAfPointDetails, props, metaData),
        OlympusDelegates.addInfo("CAF Sensitivity",  OlympusDelegates.metaKeyCafSensitivity, props, metaData),
        OlympusDelegates.addInfo("AF Search",        OlympusDelegates.metaKeyAfSearch,       props, metaData),
      }
    end

  else
    -- add row as composed
    return result
  end
end


--[[
  #TODO
  ----
  #TODO
--]]
function OlympusDelegates.getFaceDetectInfo(metaData)
  local afPointDetails = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyAfPointDetails)
  if afPointDetails then
    afPointDetails = splitTrim(afPointDetails, ";")
    if #afPointDetails >= 4 then
      return afPointDetails[2] .. "; " .. afPointDetails[4]
    else
      return nil
    end
  else
    return nil
  end
end

--[[
  @@public string OlympusDelegates.getFocusMode(string focusModeValue)
  ----
  Extract the desired focus mode details from a string all kinds of information
--]]
function OlympusDelegates.getFocusMode(focusModeValue)

  local f = splitTrim(focusModeValue:gsub(", Imager AF", ""), ";,")
  if f and #f > 1 then
    local m = f[2]
    if (m == "MF") then
      --MF
      return m
    elseif (m == "S-AF") or (m == "C-AF") then
      if (#f >= 3) and (f[3] == "MF") then
        m = m .. "+" .. f[3]     -- C-AF+M bzw S-AF+M
        f[3] = f[4]
        f[4] = f[5]
      end
    else
      m = f[2]                   -- Starry Sky AF
    end
    if (#f >= 3) then
      if (f[3] == "Live View Magnification Frame") then
        m = m .. " (Live View Magnification)"
      else
        -- do not use 'Face Detect' bit since it's not consistently used across all models
      end
    end
    return m
  else
    return f[1]
  end
end


--[[
  @@public boolean OlympusDelegates.modelSupported(string)
  ----
  Returns whether the given camera model is supported or not
--]]
function OlympusDelegates.modelSupported(_model)
  return true
end


--[[
  @@public boolean OlympusDelegates.makerNotesFound(table, table)
  ----
  Returns whether the current photo has metadata with makernotes AF information included
--]]
function OlympusDelegates.makerNotesFound(_photo, metaData)
  local result = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Olympus",
      string.format("Tag '%s' not found", OlympusDelegates.metaKeyAfInfoSection))
  end
  return result ~= nil
end


--[[
  @@public boolean OlympusDelegates.manualFocusUsed(table, table)
  ----
  Returns whether manual focus has been used on the given photo
--]]
function OlympusDelegates.manualFocusUsed(_photo, metaData)
  local focusMode = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyFocusMode)
  Log.logInfo("Olympus",
    string.format("Tag '%s' found: %s",
      OlympusDelegates.metaKeyFocusMode, focusMode))
  if focusMode and (focusMode == "MF; MF" or focusMode == "MF") then
    return true
  end
  return false
end


--[[
  @@public table function OlympusDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function OlympusDelegates.getImageInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local imageInfo
  imageInfo = f:column {
    fill = 1,
    spacing = 2,
    OlympusDelegates.addInfo("Digital Zoom", OlympusDelegates.metaKeyDigitalZoomRatio, props, metaData),
  }
  return imageInfo
end

--[[
  @@public table function OlympusDelegates.getShootingInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Shooting Information" section
  -- if any, otherwise return an empty column
--]]
function OlympusDelegates.getShootingInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    OlympusDelegates.addInfo("Drive Mode",            OlympusDelegates.metaKeyDriveMode,           props, metaData),
    OlympusDelegates.addInfo("Image Stabilization",   OlympusDelegates.metaKeyImageStabilization,  props, metaData),
    OlympusDelegates.addInfo("Stacked Image",         OlympusDelegates.metaKeyStackedImage,        props, metaData),
  }
  return shootingInfo
end


--[[
  @@public table OlympusDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function OlympusDelegates.getFocusInfo(_photo, props, metaData)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {fill = 1, spacing = 2,
      OlympusDelegates.addInfo("Focus Mode",         OlympusDelegates.metaKeyFocusMode,           props, metaData),
      OlympusDelegates.addInfo("Face Detection",     OlympusDelegates.metaKeyFacesDetected,       props, metaData),
      OlympusDelegates.addInfo("Subject Detection",  OlympusDelegates.metaKeySubjectTrackingMode, props, metaData),
      FocusInfo.addSpace(),
      FocusInfo.addSeparator(),
      FocusInfo.addSpace(),
      OlympusDelegates.addInfo("Focus Distance",     OlympusDelegates.metaKeyFocusDistance,       props, metaData),
      OlympusDelegates.addInfo("Depth of Field",     OlympusDelegates.metaKeyDepthOfField,        props, metaData),
      OlympusDelegates.addInfo("Hyperfocal Distance",OlympusDelegates.metaKeyHyperfocalDistance,  props, metaData),
      }
  return focusInfo
end
