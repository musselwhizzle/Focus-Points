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

local LrView   = import "LrView"

require "Utils"
require "Log"


PentaxDelegates = {}

PentaxDelegates.supportedModels = {
    "k-1 mark ii", "k-1", "k-3 mark iii", "k-3 mark iii monochrome", "k-3 ii", "k-3", "kp",
    "k-5 ii s", "k-5 ii", "k-5",
    "k-7", "k-30", "k-50", "k-70", "k-500",
    "k-r", "k-s1", "k-s2", "k-x", "k-01",
    "k10d", "k20d", "k100d super", "k100d", "k110d", "k200d",
    "_a_ist d", "_a_ist ds", "_a_ist ds2"
}

PentaxDelegates.prioritizedModels = {
    "k-1 mark ii", "k-1", "k-3 mark iii", "k-3 ii", "k-3", "kp", "k-70", "k-s1", "k-s2"
}

-- To trigger display whether focus points have been detected or not
PentaxDelegates.focusPointsDetected = false

-- Tag which indicates that makernotes / AF section is present
PentaxDelegates.metaKeyAfInfoSection        = "Pentax Version"

-- AF relevant tags
PentaxDelegates.metaKeyFocusMode            = "Focus Mode"
PentaxDelegates.metaKeyContrastDetect       = "Contrast-detect"
PentaxDelegates.metaKeyAfPointsSelected     = "AF Points Selected"
PentaxDelegates.metaKeyAfPointSelected      = "AF Point Selected"
PentaxDelegates.metaKeyAfPoints             = "AF Points"
PentaxDelegates.metaKeyAfPointsInFocus      = "AF Points In Focus"
PentaxDelegates.metaKeyContrastDetectAfArea = "Contrast Detect AF Area"
PentaxDelegates.metaKeyCAfGridSize          = "CAF Grid Size"
PentaxDelegates.metaKeyCAfPointsSelected    = "CAF Points Selected"
PentaxDelegates.metaKeyCAfPointsInFocus     = "CAF Points In Focus"
PentaxDelegates.metaKeyFaceDetectFrameSize  = "Face Detect Frame Size"
PentaxDelegates.metaKeyFacesDetected        = "Faces Detected"
PentaxDelegates.metaKeyK3iiiAfInfo          = "Pentax_0x040c"

-- Image and Camera Settings relevant tags
PentaxDelegates.metaKeyExposureProgram      = "Exposure Program"
PentaxDelegates.metaKeyPictureMode          = "Picture Mode"
PentaxDelegates.metaKeyDriveMode            = "Drive Mode"
PentaxDelegates.metaKeyShakeReduction       = "Shake Reduction"

-- relevant metadata values
PentaxDelegates.metaValueNA          = "N/A"

-- AF active area that hase been used to take current photo
-- global variable to avoid reading the large AFInfo block for a second time
PentaxDelegates.k3iiiAfActiveArea = ""


function PentaxDelegates.isModelK3iii(model)
-- helper function to check if the camera used is a K-3iii
  return (model == "pentax k-3 mark iii")
      or (model == "pentax k-3 mark iii monochrome")
end


--[[
  @@public table PentaxDelegates.getAFPoints(table photo, table metaData)
  ----
  Top level function to get the autofocus points for 'photo' from 'metadata'
  Returns a table of focus points with basic properties (pointType, center coordinates, width, height)
--]]
function PentaxDelegates.getAfPoints(photo, metaData)
  PentaxDelegates.focusPointsDetected = false

  local result
  local focusMode = splitTrim(ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFocusMode), " ")

  if not focusMode then
    Log.logError("Pentax",
     string.format("Focus mode tag '%s' not found", PentaxDelegates.metaKeyFocusMode))
    return nil
  end

  if focusMode[1] == "Manual" then
    Log.logWarn("Pentax",
     string.format("Manual focus mode, no focus points"))
    return nil
  end

  if PentaxDelegates.isModelK3iii(DefaultDelegates.cameraModel) then
    -- K3-iii has its own AF data structures and logic which is entirely different from all other models
    result = PentaxDelegates.getK3iiiAfPoints(photo, metaData)
  else
    if focusMode[1] == "AF-A" or focusMode[1] == "AF-C" or focusMode[1] == "AF-S" then
      -- Phase Detect AF modes
      result = PentaxDelegates.getAfPointsPhase(photo, metaData)
    else
      -- for all other modes assume Contrast AF
      result = PentaxDelegates.getAfPointsContrast(photo, metaData)
    end
  end

  return result
end


--[[
  @@public table PentaxDelegates.getK3iiiAfPoints(table photo, table metaData)
  ----
  Get the autofocus points for a K3-iii 'photo' from 'metadata'
  #TODO more details!
  Returns a table of focus points with basic properties (pointType, center coordinates, width, height)
--]]
function PentaxDelegates.getK3iiiAfPoints(photo, metaData)

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  local function read_uint16_le(str, pos)
  -- helper function to read the AFInfo byte string by int16u chunks
    local lo, hi = string.byte(str, pos, pos+1)
    return lo + hi * 256
  end

  -- make sure imageSize dimensions are in horizontal shotOrientation and thus
  -- same as FaceDetectArea and ContrastDetectArea
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local imageSize = {orgPhotoWidth, orgPhotoHeight}

  -- Fetch afInfo block from metadata
  local afInfo = ExifUtils.getBinaryValue(photo, PentaxDelegates.metaKeyK3iiiAfInfo)
  if not afInfo then
    Log.logError("Pentax","No AF information for K-3 Mark III found")
    return nil
  end

  -- Read header of AFInfo block
  -- data block consists of (1+n) x 14 bytes, with n=number of focus points stored
  -- each entries of 14 bytes is interpreted as 7 unsigned 16-bit integers, little-endian
  local focusMode         = read_uint16_le(afInfo, 1)
  local afSelectionMode   = read_uint16_le(afInfo, 3)
  local numTotalPoints    = read_uint16_le(afInfo, 5)
  local numSelectedPoints = read_uint16_le(afInfo, 7)

  -- map afSelectionMode code to user manual terminology
  if     afSelectionMode ==    1 then PentaxDelegates.k3iiiAfActiveArea = "Spot"
  elseif afSelectionMode ==    2 then PentaxDelegates.k3iiiAfActiveArea = "Select (5-points)"
  elseif afSelectionMode ==    3 then PentaxDelegates.k3iiiAfActiveArea = "Expanded Area (S)"
  elseif afSelectionMode ==    6 then PentaxDelegates.k3iiiAfActiveArea = "Select (S)"
  elseif afSelectionMode ==    7 then PentaxDelegates.k3iiiAfActiveArea = "Zone Select (21-point)"
  elseif afSelectionMode ==    8 then PentaxDelegates.k3iiiAfActiveArea = "Select XS"
  elseif afSelectionMode ==  255 then PentaxDelegates.k3iiiAfActiveArea = "Auto Area"
  elseif afSelectionMode == 8193 then PentaxDelegates.k3iiiAfActiveArea = "Auto Area"
  elseif afSelectionMode == 8196 then PentaxDelegates.k3iiiAfActiveArea = "Tracking"
  elseif afSelectionMode == 8198 then PentaxDelegates.k3iiiAfActiveArea = "Face Detection"
  elseif afSelectionMode == 8199 then PentaxDelegates.k3iiiAfActiveArea = "Select (S)"
  elseif afSelectionMode == 8200 then PentaxDelegates.k3iiiAfActiveArea = "Select (M)"
  elseif afSelectionMode == 8201 then PentaxDelegates.k3iiiAfActiveArea = "Select (L)"
  elseif afSelectionMode == 8203 then PentaxDelegates.k3iiiAfActiveArea = "Spot"
  end

  -- Process the 'SelectedPoints' entries in table one by one
  for i=1, numSelectedPoints do

    -- read i-th entry from AFInfo block
    local afFrameWidth    = read_uint16_le(afInfo, 14*i + 1)
    local afFrameHeight   = read_uint16_le(afInfo, 14*i + 3)
    local afAreaXPosition = read_uint16_le(afInfo, 14*i + 5)
    local afAreaYPosition = read_uint16_le(afInfo, 14*i + 7)
    local afAreaWidth     = read_uint16_le(afInfo, 14*i + 9)
    local afAreaHeight    = read_uint16_le(afInfo, 14*i + 11)
    local afAreaStatus    = read_uint16_le(afInfo, 14*i + 13)

    -- check if dimensions are given - if not use PDAF point default dimensions
    if (afAreaWidth == 0) and (afAreaHeight == 0) then
      afAreaWidth  = 30
      afAreaHeight = 20
    end

    if afAreaWidth * afAreaHeight == 0 then
      -- undefined: either both values are zero, or none of them
      Log.logError("Pentax",string.format(
        "Inconsistent AF information encountered: afAreaWidth=%s, afAreaHeight=%s"), afAreaWidth, afAreaHeight)
      return nil
    end

    -- scale coordinates and dimensions
    afAreaXPosition = afAreaXPosition * imageSize[1] / afFrameWidth
    afAreaYPosition = afAreaYPosition * imageSize[2] / afFrameHeight
    afAreaWidth     = afAreaWidth     * imageSize[1] / afFrameWidth
    afAreaHeight    = afAreaHeight    * imageSize[2] / afFrameHeight

    -- determine the type of visualization
    local pointType
    if     (afAreaStatus == 3) then
      -- peripheral point not in focus
      pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE

    elseif (afAreaStatus == 11) or (afAreaStatus == 27) then
      -- user-selected point not in focus
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED

    elseif (afAreaStatus == 7) or (afAreaStatus == 15) or (afAreaStatus == 31) then
      -- point not in focus
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
      PentaxDelegates.focusPointsDetected = true

    else
      Log.logError("Pentax",string.format(
       "Unexpected AF information encountered: focus point status code %s"), afAreaStatus)
      return nil
    end

    -- insert the focus point in the table used for rendering
    table.insert(result.points, {
      pointType = pointType,
      x = afAreaXPosition,
      y = afAreaYPosition,
      width = afAreaWidth * 0.965,
      height = afAreaHeight * 0.95,
    })

    if PentaxDelegates.k3iiiAfActiveArea == "Face Detection" then
      -- insert a second frame visualizing the face detection
      table.insert(result.points, {
        pointType = DefaultDelegates.POINTTYPE_FACE,
        x = afAreaXPosition,
        y = afAreaYPosition,
        width = afAreaWidth * 1.0,
        height = afAreaHeight * 1.0,
      })
    end
  end

  return result
end


--[[
-- photo - the photo LR object
-- metaData - the metadata as read by exiftool
--]]
function PentaxDelegates.getAfPointsPhase(photo, metaData)

  local afPointsSelected, afPointSelected

  afPointsSelected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfPointsSelected)
  if not afPointsSelected then
    afPointSelected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfPointSelected)
  end

  -- AFPointsSelected: list of user selected focus points (K-70, KP, K-1 and K-3)
  if afPointsSelected == nil then
    afPointsSelected = {}
  else
    afPointsSelected = splitTrim(afPointsSelected, ",") -- comma separated!
    afPointsSelected = PentaxDelegates.fixCenter(afPointsSelected)
  end

  -- AFPointSelected: list of user selected focus points for all models except K-1 and K-3
  -- #TODO Check if this short list really covers all AF modes!
  if afPointSelected == nil then
    afPointSelected = {}
  else
    afPointSelected = splitTrim(afPointSelected, ";") -- semicolon separated
    afPointSelected = PentaxDelegates.fixCenter(afPointSelected)
  end

  -- AFPointsInFocus: list of focus points used by the camera to focus the image
  local afPointsInFocus = ExifUtils.findValue(metaData,PentaxDelegates.metaKeyAfPointsInFocus)
  if afPointsInFocus == nil then
    afPointsInFocus = {}
  else
    afPointsInFocus = splitTrim(afPointsInFocus, ",") -- comma separated!
    afPointsInFocus = PentaxDelegates.fixCenter(afPointsInFocus)
  end

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- Read coordinates of focus points and dimensions of full size image
  local focusPointsMap, focusPointDimens, fullSizeDimens = PointsUtils.readIntoTable(
          DefaultDelegates.cameraMake,DefaultDelegates.cameraModel .. ".txt")

  if (focusPointsMap == nil) then
    -- model not supported #TODO Can we ever get there?
    return
  end

  -- Calculate scaling factors that are required in case the image is a JPG OOC in low resolution
  local xScale, yScale
  if #fullSizeDimens ~= 0 then  -- #TODO can be removed once all mapping files have been updated to new format!
    local imageWidth, imageHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
    xScale = imageWidth  / fullSizeDimens[1]
    yScale = imageHeight / fullSizeDimens[2]
  else
    xScale = 1
    yScale = 1
  end

  -- Loop over all sensor focus points and mark them for rendering insert them according to their status
  for key, _value in pairs(focusPointsMap) do
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
--[[
    if DefaultDelegates.cameraModel == PentaxDelegates.K3iii then
      -- #TODO in this early stage, use custom handling of focus points for this model
      pointType = DefaultDelegates.POINTTYPE_CROP
      local isSelected = arrayKeyOf(afPointsSelected, key) ~= nil
      if isSelected then
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
        PentaxDelegates.focusPointsDetected = true
      end
    else
--]]
      local isInFocus  = arrayKeyOf(afPointsInFocus, key)  ~= nil
      local isSelected = arrayKeyOf(afPointsSelected, key) ~= nil or
                         arrayKeyOf(afPointSelected, key)  ~= nil
      if isInFocus and isSelected then
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
        PentaxDelegates.focusPointsDetected = true
      elseif isInFocus then
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
        PentaxDelegates.focusPointsDetected = true
      elseif isSelected then
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED
      end
--    end

    -- Insert the focus point in the table used for rendering
    table.insert(result.points, {
      pointType = pointType,
      x = x * xScale,
      y = y * yScale,
      width = width * xScale,
      height = height * yScale
    })

  end
  return result
end


--[[
  Function to get the autofocus points and focus size of the camera when shot in
  liveview mode returns typical points table
--]]
function PentaxDelegates.getAfPointsContrast(photo, metaData)

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- make sure imageSize dimensions are in horizontal shotOrientation and thus
  -- same as FaceDetectArea and ContrastDetectArea
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local imageSize = {orgPhotoWidth, orgPhotoHeight}

  -- ContrastDetectAFArea gives the relevant area of contrast AF, related to FaceDetectFrameSize
  local contrastDetectArea = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyContrastDetectAfArea)
  if contrastDetectArea then contrastDetectArea = splitTrim(contrastDetectArea, " ") end

  local faceDetectSize = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFaceDetectFrameSize)
  if faceDetectSize then faceDetectSize = splitTrim(faceDetectSize, " ") end

  -- Have any faces been detected?
  local facesDetected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFacesDetected)
  if facesDetected then
    facesDetected = tonumber(facesDetected)
  else
    facesDetected = 0
  end

  if facesDetected > 0 and faceDetectSize then
  -- #TODO this needs more testing - based on more test images!
    local faces = {}
    for f=1, facesDetected do

      local facePosition = ExifUtils.findValue(metaData, "Face " .. f .. " Position")
      local faceSize     = ExifUtils.findValue(metaData, "Face " .. f .. " Size")

      if facePosition and faceSize then
        facePosition = splitTrim(facePosition, " ")
        faceSize = splitTrim(faceSize, " ")
        faces[f] = {facePosition, faceSize}

        -- Calculate px coordinates for full size image
        local afAreaXPosition = faces[f][1][1] * imageSize[1] / faceDetectSize[1]
        local afAreaYPosition = faces[f][1][2] * imageSize[2] / faceDetectSize[2]
        local afAreaWidth     = faces[f][2][1] * imageSize[1] / faceDetectSize[1]
        local afAreaHeight    = faces[f][2][2] * imageSize[2] / faceDetectSize[2]

        PentaxDelegates.focusPointsDetected = true
        -- face detection frame
        if afAreaWidth > 0 and afAreaHeight > 0 then
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_FACE,
            x = afAreaXPosition,
            y = afAreaYPosition,
            width = afAreaWidth,
            height = afAreaHeight
          })
          -- focus frame
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
            x = afAreaXPosition,
            y = afAreaYPosition,
            width = afAreaWidth * 0.9,
            height = afAreaHeight  * 0.9
          })
        end
      else
        Log.logError("Pentax", string.format(
          "Inconsistent face detect information. Tags 'Face % Position' and/or 'Face % Size'  missing or empty",
          f, f))
       return result
      end
    end

  elseif contrastDetectArea then

    -- Check if information on selected / in focus CAF points is available
    local cafGridSize = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyCAfGridSize)
    if cafGridSize and cafGridSize ~= "0x0"  then

      -- parse grid size
      local cafGridCols, cafGridRows = cafGridSize:match("^(%d+)x(%d+)$")
      if not (cafGridCols and cafGridRows) then
        Log.logError("Pentax",string.format("Invalid 'CAF Grid Size' tag:" .. cafGridSize))
        return nil
      end

      -- parse information on selected and in focus points
      local cafPointsSelected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyCAfPointsSelected)
      local cafPointsInFocus  = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyCAfPointsInFocus)
      if not cafPointsSelected then
        Log.logError("Pentax","Invalid CAF information: 'CAF Points Selected' tag does not exist ")
        return nil
      end
      if not cafPointsInFocus then
        Log.logError("Pentax","Invalid CAF information: 'CAF Points In Focus' tag does not exist ")
        return nil
      end

      local cafPointsSelectedTable = split(cafPointsSelected, ",")
      local cafPointsInFocusTable  = split(cafPointsInFocus,  ",")
      if not cafPointsSelectedTable then
        Log.logError("Pentax","Invalid format: 'CAF Points Selected': '" .. cafPointsSelected .. "'")
        return nil
      end

      -- dimensions of CAF point grid for the various types of grids used by different models
      local g = "_" .. cafGridSize
      local grid = {
        _7x5    = {offsetX = 80, offsetY = 60, cellWidth = 80, cellHeight = 72},
        _9x5    = {offsetX = 72, offsetY = 80, cellWidth = 64, cellHeight = 64},
        _10x10  = {offsetX = 90, offsetY = 59, cellWidth = 54, cellHeight = 36},
      }

      for _, value in pairs(cafPointsSelectedTable) do
        -- determine the position of the CAF point within the grid
        local cafRow = math.ceil(value / cafGridCols)
        local cafCol = (value - 1) % cafGridCols + 1
        local xPos   = grid[g].offsetX + (cafCol-1) * grid[g].cellWidth  + grid[g].cellWidth  * 0.5
        local yPos   = grid[g].offsetY + (cafRow-1) * grid[g].cellHeight + grid[g].cellHeight * 0.5

        -- scale position and size of CAF point from detect size to image size coordinate system
        local afAreaXPosition = imageSize[1]/faceDetectSize[1] * xPos
        local afAreaYPosition = imageSize[2]/faceDetectSize[2] * yPos
        local afAreaWidth     = imageSize[1]/faceDetectSize[1] * grid[g].cellWidth
        local afAreaHeight    = imageSize[2]/faceDetectSize[2] * grid[g].cellHeight

        local afPointType
        if cafPointsInFocusTable and arrayKeyOf(cafPointsInFocusTable, value) then
          afPointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
          PentaxDelegates.focusPointsDetected = true
        else
          afPointType = DefaultDelegates.POINTTYPE_AF_SELECTED
        end

        if (afAreaWidth ~= 0) and (afAreaHeight ~= 0) then
          if afAreaWidth > 0 and afAreaHeight > 0 then
            table.insert(result.points, {
              pointType = afPointType,
              x = afAreaXPosition,
              y = afAreaYPosition,
              width  = afAreaWidth  * 0.9,
              height = afAreaHeight * 0.9,
            })
          end
        end
      end

      -- scale entire contrast AF area to frame the individual CAF points
      -- if there is any problem in decoding or rendering CAFPointInfo this will help to visually detect the issue
      local afAreaXPosition = imageSize[1]/faceDetectSize[1] * (contrastDetectArea[1] + 0.5*contrastDetectArea[3])
      local afAreaYPosition = imageSize[2]/faceDetectSize[2] * (contrastDetectArea[2] + 0.5*contrastDetectArea[4])
      local afAreaWidth     = imageSize[1]/faceDetectSize[1] *  contrastDetectArea[3]
      local afAreaHeight    = imageSize[2]/faceDetectSize[2] *  contrastDetectArea[4]

      if (afAreaWidth ~= 0) and (afAreaHeight ~= 0) then
        if afAreaWidth > 0 and afAreaHeight > 0 then
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_AF_SELECTED,
            x = afAreaXPosition,
            y = afAreaYPosition,
            width = afAreaWidth * 1.03,
            height = afAreaHeight * 1.03,
          })
        end
      end

    else

      -- scale contrast AF area
      local afAreaXPosition = imageSize[1]/faceDetectSize[1] * (contrastDetectArea[1] + 0.5*contrastDetectArea[3])
      local afAreaYPosition = imageSize[2]/faceDetectSize[2] * (contrastDetectArea[2] + 0.5*contrastDetectArea[4])
      local afAreaWidth     = imageSize[1]/faceDetectSize[1] *  contrastDetectArea[3]
      local afAreaHeight    = imageSize[2]/faceDetectSize[2] *  contrastDetectArea[4]

      -- draw frame corresponding to CAF area as point in focus
      if (afAreaWidth ~= 0) and (afAreaHeight ~= 0) then
        PentaxDelegates.focusPointsDetected = true
        if afAreaWidth > 0 and afAreaHeight > 0 then
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
            x = afAreaXPosition,
            y = afAreaYPosition,
            width = afAreaWidth,
            height = afAreaHeight
          })
        end
      end
    end

  else
    -- if we get here, it's a focus mode that cannot be handled properly
    Log.logError("Pentax",string.format("Unhandled focus mode"))
    return nil
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

--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table PentaxDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Create view element for adding an item to the info section; creates and populates the corresponding view property
--]]
function PentaxDelegates.addInfo(title, key, props, metaData)
  local f = LrView.osFactory()

  local function escape(text)
    if text then
      return string.gsub(text, "&", "&&")
    else
      return nil
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Creates and populates the property corresponding to metadata key
  local function populateInfo(key)
  local value = ExifUtils.findValue(metaData, key)

    if (key == PentaxDelegates.metaKeyAfPointSelected) then
      if PentaxDelegates.isModelK3iii(DefaultDelegates.cameraModel) then
        props[key] = PentaxDelegates.k3iiiAfActiveArea
      else
        props[key] = PentaxDelegates.focusingArea(value)
      end

    elseif not value then
      props[key] = PentaxDelegates.metaValueNA

    elseif (key == PentaxDelegates.metaKeyPictureMode) then
      -- extract 'mode' part of PictureMode tag by removing the trailing 'EV steps' portion
      local pictureMode = splitTrim(value,  ";")
      local exposureProgram = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyExposureProgram)
      if string.lower(pictureMode[1]) ~= string.lower(exposureProgram) then
        props[key] = escape(pictureMode[1])
      else
        -- in case PictureMode is a duplicate of ExposureProgram we skip this entry
        props[key] = PentaxDelegates.metaValueNA
      end

    elseif (key == PentaxDelegates.metaKeyDriveMode) then
      -- just take the basic mode and skip all the trailing details after ";"
      props[key] = splitTrim(value,  ";")[1]

    else
      props[key] = value
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if props[key] and props[key] == PentaxDelegates.metaValueNA then
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end

  -- compose the row to be added
  local result = f:row {
    f:column{f:static_text{title = title .. ":", font="<system>"}},
    f:spacer{fill_horizontal = 1},
    f:column{f:static_text{title = props[key], font="<system>"}}
  }
  -- add row as composed
  return result

end


--[[
  @@public string PentaxDelegates.focusingArea(AFPointSelected)
  ----
  Determines the focusing area (or AF active area) from AFPointSelected tag
  according to the terminology of Pentax user manuals for K-1, K-3, KP, K-70, K-S2, K-S1 models
  Not used for K-3 iii models !!
--]]
function PentaxDelegates.focusingArea(AFPointSelected)

  local value = splitTrim(AFPointSelected,  ";")
  local model = DefaultDelegates.cameraModel
  local result

  if value then
    -- Parse possible values of 'AFPointSelected' according to https://exiftool.org/TagNames/Pentax.html
    if     value[1] == "AF Select" then                         result = "Multiple AF Points"
    elseif value[1] == "Face Detect AF" then                    result = "Face Detection"
    elseif value[1] == "Automatic Tracking AF" then             result = "Tracking"
    elseif value[1] == "Fixed Center" then                      result = "Spot (Center)"
    elseif value[1] == "Auto" then                              result = "Auto (All Points)"
    elseif value[1] == "Auto 2" then                            result = "Auto (All Points)"
    elseif value[1] == "None" then                              result = "Select"
    elseif string.find(value[1], "Zone Select") then result = "Zone Select (9-point)"
    elseif #value == 2 and value[2] ~= "Single Point" then      result = value[2]
    else                                                        result = "Select (1-point)"
    end
  else
    result = "Undefined"
  end
  return result
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
  @@public boolean PentaxDelegates.modelPrioritized(model)
  ----
  Checks whether the camera model is prioritized or not
--]]
function PentaxDelegates.modelPrioritized(currentModel)
  local m = string.match(string.lower(currentModel), "pentax (.+)")
  for _, model in ipairs(PentaxDelegates.prioritizedModels) do
    if m == model then
      return true
    end
  end
  return false
end


--[[
  @@public table function PentaxDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function PentaxDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  cameraInfo = f:column {
    fill = 1,
    spacing = 2,
    PentaxDelegates.addInfo("Drive Mode"             , PentaxDelegates.metaKeyDriveMode            , props, metaData),
    PentaxDelegates.addInfo("Picture Mode"           , PentaxDelegates.metaKeyPictureMode          , props, metaData),
    PentaxDelegates.addInfo("Shake Reduction"        , PentaxDelegates.metaKeyShakeReduction       , props, metaData),
  }
  return cameraInfo
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
      PentaxDelegates.addInfo("Focus Mode",                 PentaxDelegates.metaKeyFocusMode,               props, metaData),
      PentaxDelegates.addInfo("Focusing Area",              PentaxDelegates.metaKeyAfPointSelected,         props, metaData),
      }

  return focusInfo
end
