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

  2025 capricorn - fundamentally revised

       - added K-3iii (which required some upfront work to identify and decode the AFInfo tags for exiftool)
         (link to be inserted)
       - added CAF point details (which required some upfront work to identify and decode the AFInfo tags for exiftool)
         https://exiftool.org/TagNames/Pentax.html#CAFPointInfo
       - for quite a few models, eg. KP, K-70, K-S1, K-S2 identified and initiated necessary the changes in exiftool
         to display proper AFPointsSelected and AFPointsInFocus information.
       - added the two recent Ricoh GR models (since they share the same metadata 'Pentax' versions)
--]]

local LrView = import  'LrView'
local Utils  = require 'Utils'
local Log    = require 'Log'

PentaxDelegates = {}

-- List of supported models is sorted by date / Pentax version
-- to potentially support handling of changes in tag usage across models / Pentax versions
PentaxDelegates.supportedModels = {
    "*ist d", "*ist ds", "*ist ds2", "k10d", "k100d", "k110d", "k100d super",   -- Pentax version unknown
    "k20d", "k200d",                                                            -- Pentax version 4
    "k-x", "k-7",                                                               -- Pentax version 5
    "k-r", "k-5",                                                               -- Pentax version 7
    "k-01",                                                                     -- Pentax version 9
    "k-5 ii", "k-5 ii s", "k-30", "k-50", "k-500",                              -- Pentax version 10
    "k-3", "k-s1", "k-s2", "k-3 ii",                                            -- Pentax version 11
    "k-70", "k-1", "kp", "k-1 mark ii",                                         -- Pentax version 12
    "gr iii",                                                                   -- Pentax version 13
    "k-3 mark iii", "gr iii hdf", "gr iiix",                                    -- Pentax version 14
    "k-3 mark iii monochrome", "gr iiix hdf", "gr iv"                           -- Pentax version 15
}

-- Tag indicating that makernotes / AF section exists
-- Note: There is a "Pentax Version" tag, but it does not exist for pre-2008 models.
--       "PictureMode" is exists for all Pentax models.
PentaxDelegates.metaKeyAfInfoSection        = "Picture Mode"

-- AF-relevant tags
PentaxDelegates.metaKeyPentaxVersion        = "Pentax Version"
PentaxDelegates.metaKeyFocusMode            = "Focus Mode"
PentaxDelegates.metaKeyContrastDetect       = "Contrast-detect"
PentaxDelegates.metaKeyAfPointsSelected     = "AF Points Selected"
PentaxDelegates.metaKeyAfPointSelected      = "AF Point Selected"
PentaxDelegates.metaKeyAfPointsInFocus      = "AF Points In Focus"
PentaxDelegates.metaKeyAfPoints             = "AF Points"
PentaxDelegates.metaKeyMaxNumAfPoints       = "Max Num AF Points"
PentaxDelegates.metaKeyAfSelectionMode      = "AF Selection Mode"
PentaxDelegates.metaKeyContrastDetectAfArea = "Contrast Detect AF Area"
PentaxDelegates.metaKeyCAfGridSize          = "CAF Grid Size"
PentaxDelegates.metaKeyCAfPointsSelected    = "CAF Points Selected"
PentaxDelegates.metaKeyCAfPointsInFocus     = "CAF Points In Focus"
PentaxDelegates.metaKeyFaceDetectFrameSize  = "Face Detect Frame Size"
PentaxDelegates.metaKeyFacesDetected        = "Faces Detected"
PentaxDelegates.metaKeyFaceInfoK3III        = "Face Info K3 III"
PentaxDelegates.metaKeyAfInfo               = "AF Info"
PentaxDelegates.metaKeySubjectRecognition   = "Subject Recognition"
PentaxDelegates.metaKeyAFHold               = "AFC Hold"
PentaxDelegates.metaKeyFocusSensitivity     = "AFC Sensitivity"
PentaxDelegates.metaKeyAFPointTracking      = "AFC Point Tracking"
PentaxDelegates.metaKeyFirstFrameActionAFC  = "First Frame Action In AFC"
PentaxDelegates.metaKeyActionAFCContinuous  = "Action In AFC Cont"


-- Image and Shooting Information relevant tags
PentaxDelegates.metaKeyExposureProgram      = "Exposure Program"
PentaxDelegates.metaKeyPictureMode          = "Picture Mode"
PentaxDelegates.metaKeyDriveMode            = "Drive Mode"
PentaxDelegates.metaKeyShotNumber           = "Shot Number"
PentaxDelegates.metaKeyShakeReduction       = "Shake Reduction"

-- Relevant metadata values
PentaxDelegates.metaValueFaceDetection      = "Face Detection"


function modelHasK3iiiAfInfo(model)
  -- returns true for models launched after 2019 which have AFInfo data structure in metadata
  return (model == "pentax k-3 mark iii")
      or (model == "pentax k-3 mark iii monochrome")
      or (model == "ricoh gr iii")
      or (model == "ricoh gr iii hdf")
      or (model == "ricoh gr iiix")
      or (model == "ricoh gr iiix hdf")
      or (model == "ricoh gr iv")
end

--[[
  @@public table PentaxDelegates.getAFPoints(table photo, table metaData)
  ----
  Top level function to get the autofocus points for 'photo' from 'metadata'
  -- photo:    the photo LR object
  -- metaData: the metadata as read by exiftool
  -- returns a table of focus points with basic properties (pointType, center coordinates, width, height)
--]]
function PentaxDelegates.getAfPoints(photo, metaData)

  local result
  local focusMode = Utils.splitTrim(ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFocusMode), " ")

  if not focusMode then
    -- focus mode is essential information to control processing of AF info
    Log.logError("Pentax",
     string.format("Focus mode tag '%s' not found", PentaxDelegates.metaKeyFocusMode))
    FocusInfo.severeErrorEncountered = true
    return nil
  end

  if modelHasK3iiiAfInfo(DefaultDelegates.cameraModel) then
    -- for models launched after 2019 the handling of AF points is different
    result = getK3iiiAfPoints(photo, metaData)
  else
    if focusMode[1] == "AF-A" or focusMode[1] == "AF-C" or focusMode[1] == "AF-S" then
      -- Phase Detect AF modes
      result = getAfPointsPhase(photo, metaData)
    else
      -- for all other modes assume Contrast AF (Live View)
      result = getAfPointsContrast(photo, metaData)
    end
  end

  return result
end


--[[
  @@table getK3iiiAfPoints(table photo, table metaData)
  ----
  Function to get the autofocus points for models launched after 2019
  These models have an AFInfo block that covers both PDAF and CAF information:
  @Todo Insert link to exiftool page
  Used for K-3 iii, K-3 iii mono, GR iii, GR iiix
  -- photo:    the photo LR object
  -- metaData: the metadata as read by exiftool
  -- returns a table of focus points with basic properties (pointType, center coordinates, width, height)
--]]
function getK3iiiAfPoints(photo, metaData)

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- Make sure imageSize dimensions are in horizontal shotOrientation and thus
  -- same as FaceDetectArea and ContrastDetectArea
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  local imageSize = {orgPhotoWidth, orgPhotoHeight}

  -- Fetch afInfo from metadata and store as table
  local afInfo = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfInfo)
  if afInfo then
    Log.logInfo("Pentax",string.format(
      "Tag '%s' found: %s", PentaxDelegates.metaKeyAfInfo, afInfo))
    afInfo = Utils.splitTrim(afInfo, " ")
  else
    Log.logError("Pentax","No AF information found")
    return nil
  end

  -- 4th entry of AFInfo header gives the number of focus points/areas stored in AFInfo table
  local N = afInfo[4]

  -- Process the entries in table one by one
  for i=1, N do

    -- AFInfo data structure consists of (1+N) x 7 words, where N is the number of areas stored
    -- 7 words of header information, followed by Nx7 words for each area:
    local afFrameWidth    = tonumber(afInfo[7*i+1])
    local afFrameHeight   = tonumber(afInfo[7*i+2])
    local afAreaXPosition = tonumber(afInfo[7*i+3])
    local afAreaYPosition = tonumber(afInfo[7*i+4])
    local afAreaWidth     = tonumber(afInfo[7*i+5])
    local afAreaHeight    = tonumber(afInfo[7*i+6])
    local afAreaStatus    = tonumber(afInfo[7*i+7])

    -- check if dimensions are given - if none use PDAF point default dimensions
    if (afAreaWidth == 0) and (afAreaHeight == 0) then
      -- @TODO These are the hardcoded dimensions for K-3 iii PDAF points !!!
      afAreaWidth  = 30
      afAreaHeight = 20
    end

    if afAreaWidth * afAreaHeight == 0 then
      -- undefined constellation: either both values are zero, or none of them
      Log.logError("Pentax",string.format(
        "Inconsistent AF information encountered: afAreaWidth=%s, afAreaHeight=%s"), afAreaWidth, afAreaHeight)
      return nil
    end

    -- scale coordinates and dimensions
    afAreaXPosition = afAreaXPosition * imageSize[1] / afFrameWidth
    afAreaYPosition = afAreaYPosition * imageSize[2] / afFrameHeight
    afAreaWidth     = afAreaWidth     * imageSize[1] / afFrameWidth
    afAreaHeight    = afAreaHeight    * imageSize[2] / afFrameHeight

    -- determine the type of focus point/area and set corresponding visualization
    local pointType
    if     (afAreaStatus == 3) then
      -- peripheral point not in focus
      pointType = DefaultDelegates.POINTTYPE_AF_INACTIVE

    elseif (afAreaStatus == 11) or (afAreaStatus == 27) then
      -- user-selected point not in focus
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED

    elseif (afAreaStatus == 7) or (afAreaStatus == 15) or (afAreaStatus == 31) then
      -- area in focus
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
      FocusInfo.focusPointsDetected = true

    else
      Log.logError("Pentax",string.format(
       "Unexpected AF information encountered: focus point status code %s"), afAreaStatus)
      return nil
    end

    -- insert the focus point/area in the table used for rendering
    table.insert(result.points, {
      pointType = pointType,
      x = afAreaXPosition,
      y = afAreaYPosition,
      width  = afAreaWidth * 0.965,    -- enforce a little space between neighboring points
      height = afAreaHeight * 0.95,
    })

    local afSelectionMode = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfSelectionMode)
    if afSelectionMode and afSelectionMode == PentaxDelegates.metaValueFaceDetection then  -- #TODO ???

      -- Fetch faceInfo from metadata and store as table
      local faceInfo = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFaceInfoK3III)
      if faceInfo then
        faceInfo = Utils.splitTrim(faceInfo, " ")
      else
        Log.logError("Pentax","Face information expected but not found")
        return nil
      end

      -- Decode the FaceInfoK3III area according to https://exiftool.org/TagNames/Pentax.html#FaceInfoK3III

      -- 7th entry of AFInfo header gives the number of focus points/areas stored in AFInfo table
      local faceFrameWidth  = tonumber(faceInfo[1])
      local faceFrameHeigth = tonumber(faceInfo[2])
      local numFacesSet1    = tonumber(faceInfo[7])
      local numFacesSet2    = tonumber(faceInfo[9])

      -- Define how detailed the detected faces shall be visualized
      local numFaces = numFacesSet1+numFacesSet2
      local k
      if numFaces <= 4 then k = 4      -- render all elements (face/eyes) for up to 4 persons
                       else k = 1 end  -- render only the faces if more than 4 persons

      -- Process entries in table one by one
      for i=1, numFaces do
        -- 4 potential detection elements
        for j=1, k do
          local faceXPosition = tonumber(faceInfo[10 + (i-1)*20 + (j-1)*4 + 1])
          local faceYPosition = tonumber(faceInfo[10 + (i-1)*20 + (j-1)*4 + 2])
          local faceWidth     = tonumber(faceInfo[10 + (i-1)*20 + (j-1)*4 + 3])
          local faceHeight    = tonumber(faceInfo[10 + (i-1)*20 + (j-1)*4 + 4])

          -- scale coordinates and dimensions
          faceXPosition = faceXPosition * imageSize[1] / faceFrameWidth
          faceYPosition = faceYPosition * imageSize[2] / faceFrameHeigth
          faceWidth     = faceWidth     * imageSize[1] / faceFrameWidth
          faceHeight    = faceHeight    * imageSize[2] / faceFrameHeigth

          local pointType = DefaultDelegates.POINTTYPE_FACE

          --[[ for analysis purposes use a different color for set 2
          if i > numFacesSet1 then
            pointType = DefaultDelegates.POINTTYPE_TEST
          end
          -- ]]

          if faceWidth * faceHeight ~= 0 then
            table.insert(result.points, {
              pointType = pointType,
              x      = faceXPosition + faceWidth/2,
              y      = faceYPosition + faceHeight/2,
              width  = faceWidth,
              height = faceHeight,
            })
          end
        end
      end
    end
  end

  if not FocusInfo.focusPointsDetected then
    Log.logWarn("Pentax",string.format(
      "Tag '%s' does not contain any in-focus points/areas", PentaxDelegates.metaKeyAfInfo))
  end

  return result
end


--[[
  @@table getAfPointsPhase(table photo, table metaData)
  ----
  Function to get the phase detect autofocus points for models launched before 2019
  -- photo:    the photo LR object
  -- metaData: the metadata as read by exiftool
  -- returns a table of focus points with basic properties (pointType, center coordinates, width, height)
--]]
function getAfPointsPhase(photo, metaData)

  local afPointsSelected, afPointSelected

  afPointsSelected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfPointsSelected)
  if not afPointsSelected then
    afPointSelected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfPointSelected)
  end

  -- AFPointsSelected - list of user selected focus points for models launched between 2013..2018:
  -- K-70, KP, K-1, K-1 ii, K-3, K-3 ii
  if afPointsSelected == nil then
    afPointsSelected = {}
  else
    afPointsSelected = Utils.splitTrim(afPointsSelected, ",") -- comma separated!
    afPointsSelected = PentaxDelegates.fixCenter(afPointsSelected)
  end

  -- AFPointSelected - one or two values, giving the AF select mode and selected AF point
  -- for non-single point modes the AF point represents the center of the selection
  -- for models launched before 2013:
  -- *ist Dx, K10D/100D/110D, .. , K-7, K-5 II(s), K-30, K-500, K-50
  if afPointSelected == nil then
    afPointSelected = {}
  else
    afPointSelected = Utils.splitTrim(afPointSelected, ";") -- semicolon separated
    afPointSelected = PentaxDelegates.fixCenter(afPointSelected)
  end

  -- AFPointsInFocus: list of focus points used by the camera to focus the image
  local afPointsInFocus = ExifUtils.findValue(metaData,PentaxDelegates.metaKeyAfPointsInFocus)
  if afPointsInFocus == nil then
    afPointsInFocus = {}
  else
    afPointsInFocus = Utils.splitTrim(afPointsInFocus, ",") -- comma separated!
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
    Log.logError("Pentax",string.format(
     "Mapping file %s not found or incorrect"), DefaultDelegates.cameraModel .. ".txt")
    FocusInfo.severeErrorEncountered = true
    return nil
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
  for key, _ in pairs(focusPointsMap) do
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
    local isInFocus  = Utils.arrayKeyOf(afPointsInFocus, key)  ~= nil
    local isSelected = Utils.arrayKeyOf(afPointsSelected, key) ~= nil or
                       Utils.arrayKeyOf(afPointSelected, key)  ~= nil
    if isInFocus and isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
      FocusInfo.focusPointsDetected = true
    elseif isInFocus then
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
      FocusInfo.focusPointsDetected = true
    elseif isSelected then
      pointType = DefaultDelegates.POINTTYPE_AF_SELECTED
    end

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
  @@table getAfPointsContrast(table photo, table metaData)
  ----
  Function to get the autofocus points and focus size of the camera when shot in Live View mode
  -- photo:    the photo LR object
  -- metaData: the metadata as read by exiftool
  -- returns a table of focus points with basic properties (pointType, center coordinates, width, height)
--]]
function getAfPointsContrast(photo, metaData)

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
  if contrastDetectArea then contrastDetectArea = Utils.splitTrim(contrastDetectArea, " ") end

  local faceDetectSize = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFaceDetectFrameSize)
  if faceDetectSize then faceDetectSize = Utils.splitTrim(faceDetectSize, " ") end

  -- Have any faces been detected?
  local facesDetected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFacesDetected)
  if facesDetected then
    facesDetected = tonumber(facesDetected)
  else
    facesDetected = 0
  end

  if facesDetected > 0 and faceDetectSize then
    local faces = {}
    for f=1, facesDetected do

      local facePosition = ExifUtils.findValue(metaData, "Face " .. f .. " Position")
      local faceSize     = ExifUtils.findValue(metaData, "Face " .. f .. " Size")

      if facePosition and faceSize then
        facePosition = Utils.splitTrim(facePosition, " ")
        faceSize = Utils.splitTrim(faceSize, " ")
        faces[f] = {facePosition, faceSize}

        -- Calculate px coordinates for full size image
        local afAreaXPosition = faces[f][1][1] * imageSize[1] / faceDetectSize[1]
        local afAreaYPosition = faces[f][1][2] * imageSize[2] / faceDetectSize[2]
        local afAreaWidth     = faces[f][2][1] * imageSize[1] / faceDetectSize[1]
        local afAreaHeight    = faces[f][2][2] * imageSize[2] / faceDetectSize[2]

        FocusInfo.focusPointsDetected = true
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
        FocusInfo.severeErrorEncountered = true
        return nil
      end

      -- parse information on selected and in focus points
      local cafPointsSelected = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyCAfPointsSelected)
      local cafPointsInFocus  = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyCAfPointsInFocus)
      if not cafPointsSelected then
        Log.logError("Pentax","Invalid CAF information: 'CAF Points Selected' tag does not exist ")
        FocusInfo.severeErrorEncountered = true
        return nil
      end
      if not cafPointsInFocus then
        Log.logError("Pentax","Invalid CAF information: 'CAF Points In Focus' tag does not exist ")
        FocusInfo.severeErrorEncountered = true
        return nil
      end

      local cafPointsSelectedTable = Utils.split(cafPointsSelected, ",")
      local cafPointsInFocusTable  = Utils.split(cafPointsInFocus,  ",")
      if not cafPointsSelectedTable then
        Log.logError("Pentax","Invalid format: 'CAF Points Selected': '" .. cafPointsSelected .. "'")
        FocusInfo.severeErrorEncountered = true
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
        if cafPointsInFocusTable and Utils.arrayKeyOf(cafPointsInFocusTable, value) then
          afPointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
          FocusInfo.focusPointsDetected = true
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
        FocusInfo.focusPointsDetected = true
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
    FocusInfo.severeErrorEncountered = true
    return nil
  end

  return result
end


function PentaxDelegates.fixCenter(points)
-- helper function to unify the various names for center point
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
      if modelHasK3iiiAfInfo(DefaultDelegates.cameraModel) then
        props[key] = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfSelectionMode)
      else
        props[key] = PentaxDelegates.focusingArea(value)
      end

    elseif not value then
      props[key] = ExifUtils.metaValueNA

    elseif (key == PentaxDelegates.metaKeyPictureMode) then
      -- extract 'mode' part of PictureMode tag by removing the trailing 'EV steps' portion
      local pictureMode = Utils.splitTrim(value,  ";")
      local exposureProgram = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyExposureProgram)
      if string.lower(pictureMode[1]) ~= string.lower(exposureProgram) then
        props[key] = escape(pictureMode[1])
      else
        -- in case PictureMode is a duplicate of ExposureProgram we skip this entry
        props[key] = ExifUtils.metaValueNA
      end

    elseif (key == PentaxDelegates.metaKeyDriveMode) then
      -- just take the basic mode and skip all the trailing details after ";"
      props[key] = PentaxDelegates.getDriveMode(value)

    elseif (key == PentaxDelegates.metaKeyMaxNumAfPoints) then
      -- this tag determines whether camera setting "AF Area Restriction" is ON or OFF
      local k3iii = "pentax k-3 mark iii"
      if (string.sub(DefaultDelegates.cameraModel, 1, #k3iii) == k3iii ) then
        -- only for K-3 III and K-3 III Mono
        if value ~= "101" then
          props[key] = "Off"
        else
          props[key] = "On"
        end
      else
        -- otherwise, skip this entry
        props[key] = ExifUtils.metaValueNA
      end
    else
      props[key] = value
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if not props[key] or Utils.arrayKeyOf({"N/A"}, props[key]) then
    -- we won't display any "empty" entries - return empty row
    return FocusInfo.emptyRow()
  end

  -- compose the row to be added
  local result = FocusInfo.addRow(title, props[key])

  -- tags that are only relevant in Continuous (AF-C) mode
  if (key == PentaxDelegates.metaKeyAFHold          )
  or (key == PentaxDelegates.metaKeyFocusSensitivity)
  or (key == PentaxDelegates.metaKeyAFPointTracking ) then

    if not props[PentaxDelegates.metaKeyFocusMode]:match("^AF%-C") then
      return FocusInfo.emptyRow()
    end

  -- tags that are only relevant in AFC and Continuous mode
  elseif (key == PentaxDelegates.metaKeyFirstFrameActionAFC)
      or (key == PentaxDelegates.metaKeyActionAFCContinuous) then

    if not (props[PentaxDelegates.metaKeyFocusMode]:match("^AF%-C") and
            props[PentaxDelegates.metaKeyDriveMode]:match("^Continuous")) then
      return FocusInfo.emptyRow()
    end

  -- tags that are only relevant in PDAF modes
  elseif (key == PentaxDelegates.metaKeySubjectRecognition) then
    if not props[PentaxDelegates.metaKeyFocusMode]:match("^AF%-") then
      return FocusInfo.emptyRow()
    end

  elseif (key == PentaxDelegates.metaKeyDriveMode) then
    if props[PentaxDelegates.metaKeyDriveMode]:match("^Continuous") then
      return f:column{
        fill = 1, spacing = 2, result,
        PentaxDelegates.addInfo("Shot Number" , PentaxDelegates.metaKeyShotNumber , props, metaData)
      }
    end
  end
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

  local value = Utils.splitTrim(AFPointSelected,  ";")
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
  @@public string PentaxDelegates.getDriveMode(string driveModeValue)
  ----
  Extract the desired portions from DriveMode tag and format properly
--]]
function PentaxDelegates.getDriveMode(driveModeValue)
  local result
  local v0 = Utils.get_nth_Word(driveModeValue, 1, ";")
  local v1 = Utils.get_nth_Word(driveModeValue, 2, ";")
  local v2 = Utils.get_nth_Word(driveModeValue, 3, ";")
  local v3 = Utils.get_nth_Word(driveModeValue, 4, ";")

  local _brand, model = string.match(string.lower(DefaultDelegates.cameraModel), "^(%a+)%s+(.*)")

  if v0 == "Continuous" then
    if Utils.arrayKeyOf({"k-3", "k-3 ii", "k-1", "kp", "k-1 mark ii", "k-3 mark iii", "k-3 mark iii monochrome"}, model) then
      result = "Continuous (High)"
    elseif not Utils.arrayKeyOf({"*ist d", "*ist ds", "*ist ds2", "k10d", "k100d", "k110d", "k100d super", "k20d"},model) then
      result = "Continuous (Hi)"
    end
  elseif v0 == "Continuous Low" then
    result = "Continuous (Low)"
  else
    result = v0
  end
  if v1 ~= "No Timer"        then result = result .. "; " .. v1 end
  if v2 ~= "Shutter Button"  then result = result .. "; " .. v2 end
  if v3 ~= "Single Exposure" then result = result .. "; " .. v3 end

  return Utils.wrapText(result, {";"}, FocusInfo.maxValueLen)
end


--[[
  @@public boolean PentaxDelegates.modelSupported(string)
  ----
  Returns whether the given camera model is supported or not
--]]
function PentaxDelegates.modelSupported(currentModel)
  local brand, model = string.match(string.lower(currentModel), "^(%a+)%s+(.*)")
  for _, m in ipairs(PentaxDelegates.supportedModels) do
    if (brand == "pentax" or brand == "ricoh") and (m == model) then
      return true
    end
  end
  return false
end


--[[
  @@public boolean PentaxDelegates.makerNotesFound(table, table)
  ----
  Returns whether the current photo has metadata with makernotes AF information included
--]]
function PentaxDelegates.makerNotesFound(_photo, metaData)
  local result = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Pentax",
      string.format("Tag '%s' not found", PentaxDelegates.metaKeyAfInfoSection))
  end
  return result ~= nil
end


--[[
  @@public boolean PentaxDelegates.manualFocusUsed(table, table)
  ----
  Returns whether manual focus has been used on the given photo
--]]
function PentaxDelegates.manualFocusUsed(_photo, metaData)
  local focusMode = ExifUtils.findValue(metaData, PentaxDelegates.metaKeyFocusMode)
  Log.logInfo("Pentax",
    string.format("Focus mode tag '%s' found: %s",PentaxDelegates.metaKeyFocusMode, focusMode))
--return (Utils.splitTrim(focusMode, " ") == "Manual")
  return focusMode == "Manual"
end


--[[
  @@public table function PentaxDelegates.getShootingInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Shooting Information" section
  -- if any, otherwise return an empty column
--]]
function PentaxDelegates.getShootingInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    PentaxDelegates.addInfo("Picture Mode"           , PentaxDelegates.metaKeyPictureMode          , props, metaData),
    PentaxDelegates.addInfo("Shake Reduction"        , PentaxDelegates.metaKeyShakeReduction       , props, metaData),
    PentaxDelegates.addInfo("Drive Mode"             , PentaxDelegates.metaKeyDriveMode            , props, metaData),
  }
  return shootingInfo
end


--[[
  @@public table PentaxDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function PentaxDelegates.getFocusInfo(_photo, props, metaData)
  local f = LrView.osFactory()

  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      PentaxDelegates.addInfo("Focus Mode",           PentaxDelegates.metaKeyFocusMode          , props, metaData),
      PentaxDelegates.addInfo("Focusing Area",        PentaxDelegates.metaKeyAfPointSelected    , props, metaData),
      PentaxDelegates.addInfo("AF Area Restriction",  PentaxDelegates.metaKeyMaxNumAfPoints     , props, metaData),
      PentaxDelegates.addInfo("1st Frame Action",     PentaxDelegates.metaKeyFirstFrameActionAFC, props, metaData),
      PentaxDelegates.addInfo("Action Continuous",    PentaxDelegates.metaKeyActionAFCContinuous, props, metaData),
      PentaxDelegates.addInfo("AF Hold",              PentaxDelegates.metaKeyAFHold             , props, metaData),
      PentaxDelegates.addInfo("AF Point Tracking",    PentaxDelegates.metaKeyAFPointTracking    , props, metaData),
      PentaxDelegates.addInfo("Focus Sensitivity",    PentaxDelegates.metaKeyFocusSensitivity   , props, metaData),
      PentaxDelegates.addInfo("Subject Recognition",  PentaxDelegates.metaKeySubjectRecognition , props, metaData),
      }

  return focusInfo
end


return PentaxDelegates
