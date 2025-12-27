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

--[[----------------------------------------------------------------------------
  OlympusDelegates.lua

  Purpose of this module:
  A collection of delegate functions to be passed into the DefaultPointRenderer when
  the camera is Olympus or OM Digital Solutions

  - funcModelSupported:    Does this plugin support the camera model?
  - funcMakerNotesFound:   Does the photo metadata include maker notes?
  - funcManualFocusUsed:   Was the current photo taken using manual focus?
  - funcGetAfPoints:       Provide data for visualizing focus points, faces etc.
  - funcGetImageInfo:      Provide specific information to be added to the 'Image Information' section.
  - funcGetShootingInfo:   Provide specific information to be added to the 'Shooting Information' section.
  - funcGetFocusInfo:      Provide the information to be entered into the 'Focus Information' section.
------------------------------------------------------------------------------]]
local OlympusDelegates = {}

-- Imported LR namespaces
local LrView               = import  'LrView'

-- Required Lua definitions
local DefaultDelegates     = require 'DefaultDelegates'
local DefaultPointRenderer = require 'DefaultPointRenderer'
local ExifUtils            = require 'ExifUtils'
local FocusInfo            = require 'FocusInfo'
local Log                  = require 'Log'
local _strict              = require 'strict'
local Utils                = require 'Utils'

-- Tag indicating that makernotes / AF section exists
local metaKeyAfInfoSection            = "Camera Settings Version"

-- AF-relevant tags
local metaKeyFocusMode                = "Focus Mode"
local metaKeyCafSensitivity           = "CAF Sensitivity"
local metaKeyAfSearch                 = "AF Search"
local metaKeySubjectTrackingMode      = "AI Subject Tracking Mode"
local metaKeyFocusDistance            = "Focus Distance"
local metaKeyDepthOfField             = "Depth Of Field"
local metaKeyHyperfocalDistance       = "Hyperfocal Distance"
local metaKeyReleasePriority          = "Release Priority"
local metaKeyAfPointDetails           = "AF Point Details"
local metaKeyAfPointSelected          = "AF Point Selected"
local metaKeyAfAreas                  = "AF Areas"
local metaKeyFocusProcess             = "Focus Process"

local metaKeyAFFrameSize              = "AF Frame Size"
local metaKeyAFFocusArea              = "AF Focus Area"
local metaKeyAFSelectedArea           = "AF Selected Area"
local metaKeySubjectDetectFrameSize   = "Subject Detect Frame Size"
local metaKeySubjectDetectArea        = "Subject Detect Area"
local metaKeySubjectDetectDetail      = "Subject Detect Detail"
local metaKeySubjectDetectStatus      = "Subject Detect Status"

local metaKeyFacesDetected            = "Faces Detected"
local metaKeyFaceDetectArea           = "Face Detect Area"
local metaKeyFaceDetectFrameCrop      = "Face Detect Frame Crop"
local metaKeyFaceDetectFrameSize      = "Face Detect Frame Size"
local metaKeyMaxFaces                 = "Max Faces"
local metaKeyAfEyePriority            = "Eye Priority"

-- Image and Shooting Information relevant tags
local metaKeyDriveMode                = "Drive Mode"
local metaKeyStackedImage             = "Stacked Image Custom"
local metaKeyImageStabilization       = "Image Stabilization"
local metaKeyDigitalZoomRatio         = "Digital Zoom Ratio"
local metaKeyBodyFirmwareVersion      = "Body Firmware Version"

-- Relevant metadata values
local metaKeyAfPointSelectedPattern   = "%((%d+)%%,(%d+)"
local metaKeyAfAreaPattern            = "%((%d+),(%d+)%)%-%((%d+),(%d+)%)"
local areaDetectStatus                = ""
local makerOlympus                    = "olympus"
local makerOMDS                       = "om digital solutions"

local facesDetected

-- Forward references
local getOMDSAfPoints, getOlympusAfPoints, addFaces, findValue

--[[----------------------------------------------------------------------------
  public table
  getAfPoints(table photo, table metadata)

  Top level function used to retrieve the autofocus points from the metadata
  of the photo. Gets the actual work done by getOMDS/getOlympusAfPoints.
------------------------------------------------------------------------------]]
function OlympusDelegates.getAfPoints(photo, metadata)
  local pointsTable

  -- OM Digital Solution cameras support advanced metadata structures to detect focus areas/points
  local cameraMake = string.lower(photo:getFormattedMetadata("cameraMake"))
  if cameraMake == makerOMDS then
    pointsTable = getOMDSAfPoints(photo, metadata)
  else
    pointsTable = getOlympusAfPoints(photo, metadata)
  end

  return pointsTable
end

--[[----------------------------------------------------------------------------
  private table
  getOMDSAfPoints(table photo, table metadata)

  Get autofocus point, AF target area and subject detection frames from OMDS specific metadata:
  https://exiftool.org/TagNames/Olympus.html#AFTargetInfo
  https://exiftool.org/TagNames/Olympus.html#SubjectDetectInfo
------------------------------------------------------------------------------]]
function getOMDSAfPoints(photo, metadata)

  -- Table to insert the detected elements for visualization
  local pointsTable = { pointTemplates = DefaultDelegates.pointTemplates, points = {} }

  -- Get photo dimensions for proper scaling of focus point
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  local function isSubjectDetection()
  -- returns true if the photo has been captured using subject tracking
    return Utils.get_nth_Word(
      ExifUtils.findValue(metadata, metaKeySubjectTrackingMode),1,";")  ~= "Off"
  end

  local function isFaceDetection()
  -- returns true if the photo has been captured using subject tracking
    return string.find(
      ExifUtils.findValue(metadata, metaKeyFocusMode),"Face Detect")
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

    -- @TODO Needs a comment to explain this
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
  local subjectDetectFrameSize = findValue(metadata, metaKeySubjectDetectFrameSize)
  if subjectDetectFrameSize and (subjectDetectFrameSize[1] ~= "0 0") then

    local subjectDetectArea   = findValue(metadata, metaKeySubjectDetectArea)
    local subjectDetectDetail = findValue(metadata, metaKeySubjectDetectDetail)

    subjectDetectFrameSize = Utils.split(subjectDetectFrameSize, " ")
    subjectDetectArea      = Utils.split(subjectDetectArea     , " ")
    subjectDetectDetail    = Utils.split(subjectDetectDetail   , " ")

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
  local afFrameSize    = findValue(metadata, metaKeyAFFrameSize)
  local afFocusArea    = findValue(metadata, metaKeyAFFocusArea)
  local afSelectedArea = findValue(metadata, metaKeyAFSelectedArea)
  if afSelectedArea == "8 0 624 479" then afSelectedArea = "8 8 624 464" end   -- looks better!!

  if afFrameSize and (afFrameSize ~= "0 0") then

    local areasIdentical = (afFocusArea == afSelectedArea)

    afFrameSize    = Utils.split(afFrameSize   , " ")
    afFocusArea    = Utils.split(afFocusArea   , " ")
    afSelectedArea = Utils.split(afSelectedArea, " ")

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

    local focusPoint = findValue(metadata, metaKeyAfPointSelected)
    if focusPoint and (focusPoint ~= "") and (focusPoint ~= "0 0") and (focusPoint ~= "undef undef undef undef") then

      -- extract (x,y) point values (rational numbers in range 0..1)
      local focusX = Utils.get_nth_Word(focusPoint, 1, " ")
      local focusY = Utils.get_nth_Word(focusPoint, 2, " ")

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
         metaKeyAFFocusArea, metaKeyAfPointSelected))
      local afSearch = findValue(metadata, metaKeyAfSearch)
      if afSearch and afSearch ~= "Ready" then
        Log.logWarn("Olympus", "Autofocus operations not successful, no confirmation received (green light or beep)")
      end
    end
  end

  -- Add face detection frames to the table, if any. The resulting number of yellow boxes might look confusing,
  -- but on OM-1 II there's no other way to display this information
  if pointsTable then
    addFaces(photo, metadata, pointsTable)
  end

  -- Return table of the different elements to be visualized
  return pointsTable
end

--[[----------------------------------------------------------------------------
  private table
  getOlympusAfPoints(table photo, table metadata)

  #TODO proper doc to be done
  Get the autofocus point from Olympus metadata:
  - position represented by AFPointSelected tag
------------------------------------------------------------------------------]]
function getOlympusAfPoints(photo, metadata)

  local focusPoint, focusAreas
  local pointsTable = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- Get photo dimensions for proper scaling
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  -- Look for focus point information: available on MFT and E-system models starting with E-420
  focusPoint = findValue(metadata, metaKeyAfPointSelected)

  if focusPoint and (focusPoint ~= "") and (focusPoint ~= "0 0") and (focusPoint ~= "undef undef undef undef") then

    local focusX, focusY
    if string.find(focusPoint, "%%") then
      -- for some reason, exiftool.config has not been considered -> parse standard format for this tag
      Log.logWarn("Olympus", string.format(
        "Exiftool.config not found. Use standard format for '%s'", metaKeyAfPointSelected))
      focusX, focusY = string.match(focusPoint, metaKeyAfPointSelectedPattern)
      if not (focusX and focusY) then
        Log.logError("Olympus", "Error at extracting x/y positions from focus point tag")
        return nil
      else
        focusX = tonumber(focusX) / 100
        focusY = tonumber(focusY) / 100
      end
    else
      -- extract (x,y) point values (rational numbers in range 0..1)
      focusX = Utils.get_nth_Word(focusPoint, 1, " ")
      focusY = Utils.get_nth_Word(focusPoint, 2, " ")
    end

    if not (focusX and focusY) then
      Log.logError("Olympus",
        string.format('Could not extract (x,y) coordinates from "%s" tag', metaKeyAfPointPosition))
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
    focusAreas = ExifUtils.findValue(metadata, metaKeyAfAreas)
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
          local xTL, yTL, xBR, yBR = string.match(afAreas[i], metaKeyAfAreaPattern)
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
            metaKeyAfAreas, focusAreas))
      end

    else
      -- at least one tag must have information to continue
      Log.logWarn("Olympus",
        string.format("Neither '%s' nor '%s' found",
          metaKeyAfPointSelected, metaKeyAfAreas))
    end
  end

  -- If not focus points have been found, check status of AF operations
  if not FocusInfo.focusPointsDetected then
    local afSearch = findValue(metadata, metaKeyAfSearch)
    if afSearch and afSearch ~= "Ready" then
      Log.logWarn("Olympus", "Autofocus operations not successful, no confirmation received (green light or beep)")
    end
  end

  -- Add face detection frames, if any
  if pointsTable then
    addFaces(photo, metadata, pointsTable)
  end

  return pointsTable
end

--[[----------------------------------------------------------------------------
  private void
  addFaces(table photo, table metadata, table pointsTable)

  Add the face detection frames to the table with the focus points and areas.
  The table must not be set to nil; it needs to be initialised by the caller.
------------------------------------------------------------------------------]]
function addFaces(photo, metadata, pointsTable)

  facesDetected = false

  -- Sanity check
  if not pointsTable then return end

  -- Get photo dimensions for proper scaling of focus point
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  -- Let's see if we have detected faces - need to check the tag 'Faces Detected' (format: "a b c")
  -- (a, b, c) are the numbers of detected faces in each of the 2 supported sets of face detect area
  local detectedFaces = Utils.split(ExifUtils.findValue(metadata, metaKeyFacesDetected), " ")
  local maxFaces      = Utils.split(ExifUtils.findValue(metadata, metaKeyMaxFaces), " ")

  local faceDetectArea
  if detectedFaces and ((detectedFaces[1] ~= "0") or (detectedFaces[2] ~= "0")) then
    -- Faces have been detected for this image, let's get the details

    local faceDetectFrameCrop = ExifUtils.findValue(metadata, metaKeyFaceDetectFrameCrop)
    if faceDetectFrameCrop then
      faceDetectFrameCrop = Utils.split(faceDetectFrameCrop, " ")
    end

    local faceDetectFrameSize = ExifUtils.findValue(metadata, metaKeyFaceDetectFrameSize)
    if faceDetectFrameSize then
      faceDetectFrameSize = Utils.split(faceDetectFrameSize, " ")
    end

    faceDetectArea = ExifUtils.findValue(metadata, metaKeyFaceDetectArea)
    if string.find(faceDetectArea, "Binary data") then
      -- for some reason, exiftool.config has not been considered -> extra call to exiftool to read binary data
      Log.logWarn("Olympus", string.format(
        "Exiftool.config not found. Need extra call to ExifTool to retrieve binary data for '%s'",
        metaKeyFaceDetectArea))
      faceDetectArea = ExifUtils.getBinaryValue(photo, metaKeyFaceDetectArea)
    end

    if faceDetectArea then
      faceDetectArea = Utils.split(faceDetectArea, " ")

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

            facesDetected = true
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

--[[----------------------------------------------------------------------------
  private string
  findValue(metadata, key)

  Helper function that looks up a tag name (key) in the metadata and logs whether
  or not it was found. It returns the tag value, or nil if the tag doesn't exist.
------------------------------------------------------------------------------]]
function findValue(metadata, key)
  local value = ExifUtils.findValue(metadata, key)
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

--[[----------------------------------------------------------------------------
  private string
  getFaceDetectInfo(table metadata)

  Extract face detection information from the compound 'AFPointDetails' tag.
------------------------------------------------------------------------------]]
local function getFaceDetectInfo(metadata)
  local afPointDetails = ExifUtils.findValue(metadata, metaKeyAfPointDetails)
  if afPointDetails then
    afPointDetails = Utils.splitTrim(afPointDetails, ";")
    if #afPointDetails >= 4 then
      return afPointDetails[2] .. "; " .. afPointDetails[4]
    else
      return nil
    end
  else
    return nil
  end
end

--[[----------------------------------------------------------------------------
  private string
  getFocusMode(string focusModeValue)

  Extract the relevant details from the compound 'FocusMode' tag.
------------------------------------------------------------------------------]]
local function getFocusMode(focusModeValue)

  local f = Utils.splitTrim(focusModeValue:gsub(", Imager AF", ""), ";,")
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

--[[----------------------------------------------------------------------------
  private table
  addInfo(string title, string key, table props, table metadata)

  Generate a row element to be added to the current view container.
------------------------------------------------------------------------------]]
local function addInfo(title, key, props, metadata)
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
  local value = ExifUtils.findValue(metadata, key)

    if not value then
      props[key] = ExifUtils.metaValueNA

    elseif (key == metaKeyFocusMode) then
      -- special case: Focus Mode. Add MF if selected in settings
        props[key] = getFocusMode(value)

    elseif (title == "Release Priority") then
      -- special case: AFPointDetails. Extract ReleasePriority portion
      if value then
        props[key] = Utils.get_nth_Word(value, 7, ";")
      end

    elseif (title == "Eye Priority") then
      -- special case: AFPointDetails. Extract EyePriority portion
      if value then
        props[key] = Utils.get_nth_Word(value, 4, ";")
        if not facesDetected then
          props[key] = ExifUtils.metaValueNA
        end
      end

    elseif (key == metaKeyDigitalZoomRatio) then
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
  if not props[key] or Utils.arrayKeyOf({"N/A", "Off", "No"}, props[key]) then
    -- we won't display any "empty" entries - return empty row
    return FocusInfo.emptyRow()
  end

  if key == metaKeyDriveMode then props[key] = Utils.wrapText(props[key], {';'}, FocusInfo.maxValueLen) end
  if key == metaKeyStackedImage and props[key] == "No" then
    return FocusInfo.emptyRow()
  end

  if key == metaKeyFacesDetected then
    local faceDetect = props[metaKeyFacesDetected]
    if faceDetect ~= "0 0 0" then
    -- use this value as main indicator for Face Detection;
    -- information in FocusMode and AFPointDetails is not consistent (for one image and across models)
      local faceDetectInfo = getFaceDetectInfo(metadata)
      if faceDetectInfo then
        props[metaKeyFacesDetected] = getFaceDetectInfo(metadata)
      else
        return FocusInfo.emptyRow()
      end
    else
      return FocusInfo.emptyRow()
    end
  end

  if key == metaKeySubjectTrackingMode then
    if string.sub(props[key],1, 3) == "Off" then
      -- do not display this entry if setting was not enabled
      return FocusInfo.emptyRow()
    end
  end

  -- compose the row to be added
  local result = FocusInfo.addRow(title, props[key])

  -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
  if key == metaKeyFocusMode then
    local focusMode = props[key]:match("^(.-[- ]AF)")
    if focusMode == "S-AF" or focusMode == "Single AF" then
      return f:column{fill = 1, spacing = 2, result,
  --    addInfo("Eye Priority",     metaKeyAfPointDetails, props, metadata),
        addInfo("Release Priority", metaKeyAfPointDetails, props, metadata),
        addInfo("AF Search",        metaKeyAfSearch,       props, metadata),
      }
    elseif focusMode == "C-AF" or focusMode == "Continuous AF" then
      return f:column{fill = 1, spacing = 2, result,
  --    addInfo("Eye Priority",     metaKeyAfPointDetails, props, metadata),
        addInfo("Release Priority", metaKeyAfPointDetails, props, metadata),
        addInfo("CAF Sensitivity",  metaKeyCafSensitivity, props, metadata),
        addInfo("AF Search",        metaKeyAfSearch,       props, metadata),
      }
    end

  else
    -- add row as composed
    return result
  end
end

--[[----------------------------------------------------------------------------
  public boolean
  modelSupported(string model)

  Indicate whether the given camera model is supported or not.
------------------------------------------------------------------------------]]
function OlympusDelegates.modelSupported(_model)
  return true
end

--[[----------------------------------------------------------------------------
  public boolean
  makerNotesFound(table photo, table metadata)

  Check if the metadata for the current photo includes a 'Makernotes' section.
------------------------------------------------------------------------------]]
function OlympusDelegates.makerNotesFound(_photo, metadata)
  local result = ExifUtils.findValue(metadata, metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Olympus",
      string.format("Tag '%s' not found", metaKeyAfInfoSection))
  end
  return result ~= nil
end

--[[----------------------------------------------------------------------------
  public boolean
  manualFocusUsed(table photo, table metadata)

  Indicate whether the photo was taken using manual focus.
------------------------------------------------------------------------------]]
function OlympusDelegates.manualFocusUsed(_photo, metadata)
  local focusMode = ExifUtils.findValue(metadata, metaKeyFocusMode)
  Log.logInfo("Olympus",
    string.format("Tag '%s' found: %s",
      metaKeyFocusMode, focusMode))
  if focusMode and (focusMode == "MF; MF" or focusMode == "MF") then
    return true
  end
  return false
end

--[[----------------------------------------------------------------------------
  public table
  function getImageInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Image Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function OlympusDelegates.getImageInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local imageInfo
  imageInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Digital Zoom", metaKeyDigitalZoomRatio, props, metadata),
  }
  return imageInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getShootingInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Shooting Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function OlympusDelegates.getShootingInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Drive Mode",            metaKeyDriveMode,           props, metadata),
    addInfo("Image Stabilization",   metaKeyImageStabilization,  props, metadata),
    addInfo("Stacked Image",         metaKeyStackedImage,        props, metadata),
    addInfo("Body Firmware Version", metaKeyBodyFirmwareVersion, props, metadata),
  }
  return shootingInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getFocusInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to fetch the items in the 'Focus Information'
  section (which is entirely maker-specific).
------------------------------------------------------------------------------]]
function OlympusDelegates.getFocusInfo(_photo, props, metadata)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {fill = 1, spacing = 2,
      addInfo("Focus Mode",         metaKeyFocusMode,           props, metadata),
      addInfo("Face Detection",     metaKeyFacesDetected,       props, metadata),
      addInfo("Subject Detection",  metaKeySubjectTrackingMode, props, metadata),
      FocusInfo.addSpace(),
      FocusInfo.addSeparator(),
      FocusInfo.addSpace(),
      addInfo("Focus Distance",     metaKeyFocusDistance,       props, metadata),
      addInfo("Depth of Field",     metaKeyDepthOfField,        props, metadata),
      addInfo("Hyperfocal Distance",metaKeyHyperfocalDistance,  props, metadata),
      }
  return focusInfo
end

return OlympusDelegates -- ok
