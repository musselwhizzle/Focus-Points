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
  the camera is Nikon
--]]

local LrView = import 'LrView'

require "Utils"
require "Log"


NikonDelegates = {}

NikonDelegates.supportedModels = {
    "d3", "d3s", "d3x", "d4", "d4s", "d5", "d5s", "d6", "df",
    "d300", "d300s", "d500", "d600", "d610", "d700", "d750", "d780", "d780", "d800", "d800e", "d810", "d850",
    "d5200", "d5300", "d5500", "d5600", "d7000", "d7100", "d7200", "d7500",
    "z 5", "z5_2", "z 6", "z 6_2", "z6_3", "z 7", "z 7_2", "z 8", "z 9", "z 30", "z 50", "z50_2", "z f", "z fc",
}

-- Tag indicating that makernotes / AF section exists
NikonDelegates.metaKeyAfInfoSection           = "AF Info 2 Version"

-- AF-relevant tags
NikonDelegates.metaKeyAfInfoVersion           = "AF Info 2 Version"
NikonDelegates.metaKeyAfAreaXPosition         = "AF Area X Position"
NikonDelegates.metaKeyAfAreaYPosition         = "AF Area Y Position"
NikonDelegates.metaKeyAfAreaWidth             = "AF Area Width"
NikonDelegates.metaKeyAfAreaHeight            = "AF Area Height"
NikonDelegates.metaKeyPhaseDetectAF           = "Phase Detect AF"
NikonDelegates.metaKeyAfAreaMode              = "AF Area Mode"
NikonDelegates.metaKeyAfPointsUsed            = "AF Points Used"
NikonDelegates.metaKeyAfPointsSelected        = "AF Points Selected"
NikonDelegates.metaKeyAfPointsInFocus         = "AF Points In Focus"
NikonDelegates.metaKeyAfPrimaryPoint          = "Primary AF Point"
NikonDelegates.metaKeyCropArea                = "Crop Area"
NikonDelegates.metaKeyFocusMode               = "Focus Mode"
NikonDelegates.metaKeyFocusResult             = "Focus Result"
NikonDelegates.metaKeyFocusPointSchema        = "Focus Point Schema"
NikonDelegates.metaKeyAfAreaMode              = "AF Area Mode"
NikonDelegates.metaKeySubjectDetection        = "Subject Detection"
NikonDelegates.metaKeyNumberOfFocusPoints     = "Number Of Focus Points"
NikonDelegates.metaKeyBlockShotAfResponse     = "Block Shot AF Response"
NikonDelegates.metaKeySubjectMotion           = "Subject Motion"
NikonDelegates.metaKey3DTrackingFaceDetection = "Three-D Tracking Face Detection"
NikonDelegates.metaKey3DTrackingWatchArea     = "Three-D Tracking Watch Area"
NikonDelegates.metaKeyAfActivation            = "AF Activation"
NikonDelegates.metaKeyAfDetectionMethod       = "AF Detection Method"
NikonDelegates.metaKeyContrastDetect          = "Contrast Detect AF"
NikonDelegates.metaKeyPhaseDetect             = "Phase Detect AF"
NikonDelegates.metaKeyFocusDistance           = "Focus Distance"
NikonDelegates.metaKeyDepthOfField            = "Depth Of Field"
NikonDelegates.metaKeyHyperfocalDistance      = "Hyperfocal Distance"
NikonDelegates.metaKeyAfCPriority             = { "AF-C Priority Sel", "AF-C Priority Selection" }
NikonDelegates.metaKeyAfSPriority             = { "AF-S Priority Sel", "AF-S Priority Selection" }

-- Image and Camera Settings relevant tags
NikonDelegates.metaKeyCropHiSpeed             = "Crop Hi Speed"
NikonDelegates.metaKeyShootingMode            = "Shooting Mode"


--[[
  @@public table NikonDelegates.getAfPoints(table photo, table metaData)
  ----
  Top level function to get the autofocus points from metadata
  Check for presence of Contrast AF data first. If not found go back to EXIF and fetch PDAF data
--]]
function NikonDelegates.getAfPoints(_photo, metaData)

  local result = NikonDelegates.getCAfPoints(metaData)
  if not result then
     -- if CAF is not present, check PDAF information
    result = NikonDelegates.getPDAfPoints(metaData)
  end
  if not result then
    Log.logWarn("Nikon", "Did neither find information on CAF, nor on PDAF points")
  end
  return result
end


--[[
  @@public table NikonDelegates.getCAfPoints(table metaData)
  ----
  Function to get the autofocus points and focus size of the camera when captured using Contrast AF
  - Main use case for mirrorless models (Z line)
  - when shot in liveview mode on DSLRs (D line)
  returns typical points table
--]]
function NikonDelegates.getCAfPoints(metaData)

  local afAreaXPosition = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfAreaXPosition)
  local afAreaYPosition = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfAreaYPosition)
  local afAreaWidth     = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfAreaWidth)
  local afAreaHeight    = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfAreaHeight)

  -- if any of these is nil then this is not complete information to proceed with
  if not (afAreaXPosition and afAreaYPosition and afAreaWidth and afAreaHeight) then
    -- we don't log this as a warning, because autofocus might not have used CAF points
    Log.logInfo("Nikon",
      string.format("No CAF information found - tags '%s', '%s', '%s', '%s' empty or partly empty",
      NikonDelegates.metaKeyAfAreaXPosition, NikonDelegates.metaKeyAfAreaYPosition,
      NikonDelegates.metaKeyAfAreaWidth, NikonDelegates.metaKeyAfAreaHeight))
    return nil
  end

  -- otherwise, simply pass on the focus area coordinates from metadata
  Log.logInfo("Nikon", string.format("Focus point detected at [x=%s, y=%s, w=%s, h=%s]",
    afAreaXPosition, afAreaYPosition, afAreaWidth, afAreaHeight))

  FocusInfo.focusPointsDetected = true
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
        x = afAreaXPosition,
        y = afAreaYPosition,
        width = afAreaWidth,
        height = afAreaHeight
      }
    }
  }
  -- apply crop dimensions to focus point coordinates if photo has been cropped in camera
  NikonDelegates.applyCAFCrop(result, metaData)

  return result
end


--[[
  @@public table NikonDelegates.getPDAfPoints(table metaData)
  ----
  Function to get the autofocus points and focus size of the camera when captured using Phase Detect AF
  - Main use case for DSLRs (D line)
  - Occurs also for Mirrorless (Z line) but less frequently
  returns typical points table
--]]
function NikonDelegates.getPDAfPoints(metaData)

  local function logKeyStatus(key, value)
    if value then
      Log.logInfo("Nikon",
        string.format("Relevant focus point tag '%s' found: '%s'", key, value))
    else
      -- no focus points found - handled on upper layers
      Log.logInfo("Nikon",
        string.format("No PDAF information found: relevant focus point tag '%s' not found or empty", key))
      return nil
    end
  end

  -- extract the relevant tags from metadata
  local afInfoVersion    = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfInfoVersion)
  local afPointsInFocus  = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPointsInFocus)
  local afPointsUsed     = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPointsUsed)
  local afPointsSelected = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPointsSelected)
  local afPrimaryPoint   = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPrimaryPoint)

  local primaryPoint, focusPointsTable
  local afAreaMode = NikonDelegates.getAfAreaMode(metaData)

  -- According to AFInfo version and AFAreaMode, fetch the right focus point(s) to display
  if (afInfoVersion ~= "0101") then
    -- AFPointsUsed is what NX Studio uses for all Nikon DSLR and Mirrorless cameras
    focusPointsTable = split(afPointsUsed,  ",")
    logKeyStatus(NikonDelegates.metaKeyAfPointsUsed, afPointsUsed)
  else
    -- for whatever reason, the logic for D5, D500, D7500, D850 differs from all other models
    -- depending on the AFAreaMode, choose the relevant AFPoint tag that NX Studio uses to display focus points
    if afAreaMode and arrayKeyOf({"single", "group", "dynamic" }, afAreaMode) then
      focusPointsTable = split(afPointsSelected, ",")
      logKeyStatus(NikonDelegates.metaKeyAfPointsSelected, afPointsSelected)
    elseif arrayKeyOf({"3D-tracking", "auto" }, afAreaMode) then
      if afPointsInFocus then
        focusPointsTable = split(afPointsInFocus,  ",")
        logKeyStatus(NikonDelegates.metaKeyAfPointsInFocus, afPointsInFocus)
      else
        focusPointsTable = split(afPointsSelected,  ",")
        logKeyStatus(NikonDelegates.metaKeyAfPointsSelected, afPointsSelected)
      end
    else
      Log.logError("Nikon", "Unexpected AF Area Mode: " .. afAreaMode)
      return nil
    end
  end

  -- Store PrimaryAFPoint separately from other focus points (except for 'group area')
  if afPrimaryPoint and (afAreaMode and (afAreaMode ~= "group")) then
    primaryPoint = split(NikonDelegates.normalizeFocusPointName(afPrimaryPoint),  ",")
  end

  -- if PDAF points have been found, read the mapping file
  -- @! Outsource this piece of code to a separate function?
  local fpSchema
  if focusPointsTable or primaryPoint then
    if (DefaultDelegates.cameraModel == "nikon d780") then
      -- special case: this camera uses two different PDAF coordinate systems, 51- and 81-point!
      local focusPointSchema = ExifUtils.findValue(metaData, NikonDelegates.metaKeyFocusPointSchema)
      if focusPointSchema and ((focusPointSchema == "51-point") or (focusPointSchema == "81-point")) then
        -- appendix number to mapping file name
        fpSchema = "-" .. string.sub(focusPointSchema, 1, 2)
      else
        Log.logError("Nikon", "Unexpected D780 focus point schema: \n" .. focusPointSchema)
        FocusInfo.severeErrorEncountered = true
        return nil
      end
    else
      -- mapping file name is camera model name w/o any appendix
      fpSchema = ""
    end

    DefaultDelegates.focusPointsMap,
    DefaultDelegates.focusPointDimen = PointsUtils.readIntoTable(DefaultDelegates.cameraMake,
    DefaultDelegates.cameraModel .. fpSchema .. ".txt")
    if not DefaultDelegates.focusPointsMap then
      Log.logError("Nikon", "No (or incorrect) AF point mapping file")
      FocusInfo.severeErrorEncountered = true
      return nil
    end
  else
    -- can't find PDAF focus point information -> return
    return nil
  end

  -- from the mapping file we know all the relevant focus points for this photo,
  -- so we will create the visual representation of the layout as an accompanying overlay
  local inactivePointsTable = {}
  if (string.sub(DefaultDelegates.cameraModel, 1, 7) == "nikon d") and (fpSchema ~= "-81") then
    -- however, we only do this for DSLRs to visualize the limited AF point coverage of the frame
    for key, _ in pairs(DefaultDelegates.focusPointsMap) do
      if not ((focusPointsTable and arrayKeyOf(focusPointsTable, key)) or
              (primaryPoint     and arrayKeyOf(primaryPoint,     key))) then
        table.insert(inactivePointsTable, key)
      end
    end
  end

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- Add the primary focus point
  if primaryPoint then
    local pointType
    if focusPointsTable and #focusPointsTable > 1 then
      -- multiple focus points, emphasize PrimaryAFPoint
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX_DOT
    else
      -- no other focus points, use the standard focus point shape
      pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX
    end
    if NikonDelegates.addFocusPointsToResult(result, pointType, primaryPoint) then
      FocusInfo.focusPointsDetected = true
    else
      return nil
    end
  end

  -- Add the active focus points
  if focusPointsTable then
    if NikonDelegates.addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_FOCUS_BOX, focusPointsTable) then
      FocusInfo.focusPointsDetected = true
    else
      return nil
    end
  end

  -- Add the inactive points
  if inactivePointsTable then
    NikonDelegates.addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_INACTIVE, inactivePointsTable)
  end

  -- Apply crop dimensions to focus point coordinates if photo has been cropped in camera
  NikonDelegates.applyPDAfCrop(result, metaData)

  return result
end


--[[
  @@public bool NikonDelegates.addFocusPointsToResult(table result, string focusPointType, table focusPointTable)
  ----
  Add the focus point coordinates/dimensions found to the table of focus points to be rendered in the next step
--]]
function NikonDelegates.addFocusPointsToResult(result, focusPointType, focusPointTable)
  if focusPointTable then
    for _,value in pairs(focusPointTable) do
      local focusPointName = NikonDelegates.normalizeFocusPointName(value)
      if not DefaultDelegates.focusPointsMap[focusPointName] then
        local errorMsg = "AF-Point " .. focusPointName .. " could not be found in the mapping file."
        Log.logError("Nikon", errorMsg)
        -- continue with next value
        FocusInfo.severeErrorEncountered = true
      else
        local x = DefaultDelegates.focusPointsMap[focusPointName][1]
        local y = DefaultDelegates.focusPointsMap[focusPointName][2]
        local w, h

        -- use AF point specific dimensions for focus box if given
        if (#DefaultDelegates.focusPointsMap[focusPointName] > 2) then
          w = DefaultDelegates.focusPointsMap[focusPointName][3]
          h = DefaultDelegates.focusPointsMap[focusPointName][4]
        else
          w = DefaultDelegates.focusPointDimen[1]
          h = DefaultDelegates.focusPointDimen[2]
        end

        if focusPointType == DefaultDelegates.POINTTYPE_AF_FOCUS_BOX then
          Log.logInfo("Nikon",string.format(
            "Focus point detected at [x=%s, y=%s, w=%s, h=%s]", x, y, w, h))
        end

        table.insert(result.points, {
          pointType = focusPointType,
          x = x,
          y = y,
          width = w,
          height = h
        })
      end
    end
  end
  return true
end


--[[
  @@public string NikonDelegates.normalizeFocusPointName(string focusPoint)
  ----
  Removes the word "(Center)" from the center focus points.
  This function is a remnant of the original implementation which used PrimaryAFPoint tag.
  Actually, we don't use this tag anymore, anyway keeping (and using) this function does no harm
--]]
function NikonDelegates.normalizeFocusPointName(focusPoint)
  local focusPointin = focusPoint
  if focusPoint and focusPoint ~= "" then
    if string.find(focusPoint, "Center") then
      focusPoint = string.sub(focusPoint, 1, 2)
    end
    Log.logFull("Nikon", "focusPoint: " .. focusPointin .. ", normalized: " .. focusPoint)
  end
  return focusPoint
end


--[[
  @@public string NikonDelegates.getAfAreaMode(table metaData)
  ----
  Get the value of AFAreaMode tag and simplify it for easier handling
  Required only for AFInfoVersion 0101 (D5, D500, D7500, D850)
--]]
function NikonDelegates.getAfAreaMode(metaData)
  local afAreaMode = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfAreaMode)
  if afAreaMode then
    local areaMode = string.lower(afAreaMode)
    local mode
    if     (areaMode == "auto-area")                              then mode = "auto"
    elseif (areaMode == "group area")                             then mode = "group"
    elseif (areaMode == "single area")                            then mode = "single"
    elseif (areaMode == "dynamic area (3d-tracking)")             then mode = "3D-tracking"
    elseif (string.sub(areaMode, 1, 12) == "dynamic area") then mode = "dynamic"
    else
      -- other AFAreaMode values are not known for the relevant models
      mode = afAreaMode
    end
    return mode
  else
    return nil
  end
end


--[[
  @@public void NikonDelegates.applyCAFCrop((table focusPoints, table metaData)
  ----
  Function to consider changed dimensions of the original photo if it is was not taken in native format
  (e.g. FX crop with a DX camera, 16:9 crop etc.) and focus information is present in CAF format
  Cropping is considered by transformation of the focus point coordinates (which are relative to native format)
  The CropHiSpeed tag has all the relevant information to do this
--]]
function NikonDelegates.applyCAFCrop(focusPoints, metaData)

  local cropHiSpeed = ExifUtils.findValue(metaData, NikonDelegates.metaKeyCropHiSpeed)

  if cropHiSpeed then
    -- perform string comparisons in lower case
    cropHiSpeed = string.lower(cropHiSpeed)
    -- check if image has been taken in crop mode
    if ((string.sub(cropHiSpeed, 1,3) == "off") or (string.find(cropHiSpeed, "uncropped"))) then
      -- photo taken in native format - nothing to do
      return
    else
      FocusInfo.cropMode = true
      -- get crop dimensions
      local _cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight = NikonDelegates.getCropType(cropHiSpeed)
      -- apply crop transformation on all entries in focusPointsMap
     for _, point in pairs(focusPoints.points) do
        point.x = point.x / nativeWidth  * croppedWidth
        point.y = point.y / nativeHeight * croppedHeight
        point.width  = point.width  * croppedWidth / nativeWidth
        point.height = point.height * croppedHeight / nativeHeight
      end
    end
  end
end


--[[
  @@public void NikonDelegates.applyPDAfCrop((table focusPoints, table metaData)
  ----
  Function to consider changed dimensions of the original photo if it is was not taken in native format
  (e.g. FX crop with a DX camera, 16:9 crop etc.) and focus information is present in PDAF format
  Cropping is considered by transformation of the focus point coordinates (which are relative to native format)
  The CropHiSpeed tag has all the relevant information to do this
--]]
function NikonDelegates.applyPDAfCrop(focusPoints, metaData)

  local cropHiSpeed = ExifUtils.findValue(metaData, NikonDelegates.metaKeyCropHiSpeed)

  if cropHiSpeed then
    -- perform string comparisons in lower case
    cropHiSpeed = string.lower(cropHiSpeed)
    -- check if image has been taken in crop mode
    if ((string.sub(cropHiSpeed, 1,3) == "off") or (string.find(cropHiSpeed, "uncropped"))) then
      -- photo taken in native format - nothing to do
      return
    else
      FocusInfo.cropMode = true
      -- get crop dimensions
      local _cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight = NikonDelegates.getCropType(cropHiSpeed)
      -- apply crop transformation on all entries in focusPointsMap
     for _, point in pairs(focusPoints.points) do
        point.x = point.x - (nativeWidth  - croppedWidth ) / 2
        point.y = point.y - (nativeHeight - croppedHeight) / 2
      end
    end
  end
end


--[[
  @@public string, int, int, int, int, int, int NikonDelegates.getCropType(string cropHiSpeedValue)
  ----
  Extracts cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight, crop_x0, crop_y0 values from cropHiSpeed tag
--]]
function NikonDelegates.getCropType(cropHiSpeedValue)
  return string.match(cropHiSpeedValue,"(.+) %((%d+)x(%d+) cropped to (%d+)x(%d+) at pixel (%d+),(%d+)%)")
end

--[[--------------------------------------------------------------------------------------------------------------------
   Start of section that deals with display of maker specific metadata
----------------------------------------------------------------------------------------------------------------------]]

--[[
  @@public table NikonDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Create view element for adding an item to the info section; creates and populates the corresponding view property
--]]
function NikonDelegates.addInfo(title, key, props, metaData)
  local f = LrView.osFactory()

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  local function populateInfo(key)
    local value = ExifUtils.findValue(metaData, key)
    if not value then
      props[key] = ExifUtils.metaValueNA
    elseif (key == NikonDelegates.metaKeyCropHiSpeed) then
      props[key] = NikonDelegates.getCropType(value)
    else
      props[key] = value
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if props[key] and props[key] ~= ExifUtils.metaValueNA then

    -- compose the row to be added
    local result = FocusInfo.addRow(title, props[key])

    -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
    if (props[key] == "AF-C") then
      -- first, figure out which of the two tags is relevant for this camera
      local _afPriorityValue, afPriorityKey = ExifUtils.findFirstMatchingValue( metaData, NikonDelegates.metaKeyAfCPriority)
      return f:column{
        fill = 1, spacing = 2, result,
        NikonDelegates.addInfo("AF-C Priority", afPriorityKey, props, metaData) }

    elseif (props[key] == "AF-S") then
      -- first, figure out which of the two tags is relevant for this camera
      local _afPriorityValue, afPriorityKey = ExifUtils.findFirstMatchingValue( metaData, NikonDelegates.metaKeyAfSPriority)
      return f:column{
        fill = 1, spacing = 2, result,
        NikonDelegates.addInfo("AF-S Priority", afPriorityKey, props, metaData) }

    else
      -- add row as composed
      return result
    end

  else
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end
end


--[[
  @@public boolean NikonDelegates.modelSupported(string model)
  ----
  Returns whether the given camera model is supported or not
--]]
function NikonDelegates.modelSupported(currentModel)
  local m = string.match(string.lower(currentModel), "nikon (.+)")
  for _, model in ipairs(NikonDelegates.supportedModels) do
    if m == model then
      return true
    end
  end
  return false
end


--[[
  @@public boolean NikonDelegates.makerNotesFound(table photo, table metaData)
  ----
  Returns whether the current photo has metadata with makernotes AF information included
--]]
function NikonDelegates.makerNotesFound(_photo, metaData)
  local result = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Nikon",
      string.format("Tag '%s' not found", NikonDelegates.metaKeyAfInfoSection))
  end
  return (result ~= nil)
end


--[[
  @@public boolean NikonDelegates.manualFocusUsed(table photo, table metaData)
  ----
  Returns whether manual focus has been used on the given photo
--]]
function NikonDelegates.manualFocusUsed(_photo, metaData)
  local focusMode = ExifUtils.findValue(metaData, NikonDelegates.metaKeyFocusMode)
  Log.logInfo("Nikon",
    string.format("Tag '%s' found: %s",
      NikonDelegates.metaKeyFocusMode, focusMode))
  return (focusMode == "Manual")
end


--[[
  @@public table function NikonDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function NikonDelegates.getImageInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local imageInfo
  imageInfo = f:column {
    fill = 1,
    spacing = 2,
    NikonDelegates.addInfo("Crop Mode", NikonDelegates.metaKeyCropHiSpeed, props, metaData),
  }
  return imageInfo
end

--[[
  @@public table function NikonDelegates.getShootingInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Shooting Information" section
  -- if any, otherwise return an empty column
--]]
function NikonDelegates.getShootingInfo(_photo, props, metaData)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    NikonDelegates.addInfo("Shooting Mode", NikonDelegates.metaKeyShootingMode, props, metaData),
  }
  return shootingInfo
end


--[[
  @@public table NikonDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function NikonDelegates.getFocusInfo(_photo, props, metaData)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      NikonDelegates.addInfo("Focus Mode",             NikonDelegates.metaKeyFocusMode,           props, metaData),
      NikonDelegates.addInfo("Focus Result",           NikonDelegates.metaKeyFocusResult,         props, metaData),
      NikonDelegates.addInfo("AF Area Mode",           NikonDelegates.metaKeyAfAreaMode,          props, metaData),
      NikonDelegates.addInfo("AF Detection Method",    NikonDelegates.metaKeyAfDetectionMethod,   props, metaData),
      NikonDelegates.addInfo("Subject Detection",      NikonDelegates.metaKeySubjectDetection,    props, metaData),
      NikonDelegates.addInfo("Subject Motion",         NikonDelegates.metaKeySubjectMotion,       props, metaData),
      NikonDelegates.addInfo("3D-Tracking Watch Area", NikonDelegates.metaKey3DTrackingWatchArea, props, metaData),
      NikonDelegates.addInfo("AF Activation",          NikonDelegates.metaKeyAfActivation,        props, metaData),
      NikonDelegates.addInfo("Number of Focus Points", NikonDelegates.metaKeyNumberOfFocusPoints, props, metaData),
      FocusInfo.addSpace(),
      FocusInfo.addSeparator(),
      FocusInfo.addSpace(),
      NikonDelegates.addInfo("Focus Distance",         NikonDelegates.metaKeyFocusDistance,       props, metaData),
      NikonDelegates.addInfo("Depth of Field",         NikonDelegates.metaKeyDepthOfField,        props, metaData),
      NikonDelegates.addInfo("Hyperfocal Distance",    NikonDelegates.metaKeyHyperfocalDistance,  props, metaData),
      }
  return focusInfo
end
