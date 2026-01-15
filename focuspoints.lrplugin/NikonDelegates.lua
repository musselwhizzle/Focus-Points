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
  NikonDelegates.lua

  Purpose of this module:
  A collection of delegate functions to be passed into the DefaultPointRenderer when
  the camera is Nikon:

  - funcModelSupported:    Does this plugin support the camera model?
  - funcMakerNotesFound:   Does the photo metadata include maker notes?
  - funcManualFocusUsed:   Was the current photo taken using manual focus?
  - funcGetAfPoints:       Provide data for visualizing focus points, faces etc.
  - funcGetImageInfo:      Provide specific information to be added to the 'Image Information' section.
  - funcGetShootingInfo:   Provide specific information to be added to the 'Shooting Information' section.
  - funcGetFocusInfo:      Provide the information to be entered into the 'Focus Information' section.
------------------------------------------------------------------------------]]
local NikonDelegates = {}

-- Imported LR namespaces
local LrView           = import  'LrView'

-- Required Lua definitions
local DefaultDelegates = require 'DefaultDelegates'
local ExifUtils        = require 'ExifUtils'
local FocusInfo        = require 'FocusInfo'
local Log              = require 'Log'
local PointsUtils      = require 'PointsUtils'
local strict           = require 'strict'
local Utils            = require 'Utils'

local supportedModels = {
    "d3", "d3s", "d3x", "d4", "d4s", "d5", "d5s", "d6", "df",
    "d300", "d300s", "d500", "d600", "d610", "d700", "d750", "d780", "d780", "d800", "d800e", "d810", "d850",
    "d5200", "d5300", "d5500", "d5600", "d7000", "d7100", "d7200", "d7500",
    "z 5", "z5_2", "z 6", "z 6_2", "z6_3", "z 7", "z 7_2", "z 8", "z 9", "z 30", "z 50", "z50_2", "z f", "z fc",
}

-- Tag indicating that makernotes / AF section exists
local metaKeyAfInfoSection           = "AF Info 2 Version"

-- AF-relevant tags
local metaKeyAfInfoVersion           = "AF Info 2 Version"
local metaKeyAfAreaXPosition         = "AF Area X Position"
local metaKeyAfAreaYPosition         = "AF Area Y Position"
local metaKeyAfAreaWidth             = "AF Area Width"
local metaKeyAfAreaHeight            = "AF Area Height"
local metaKeyAfAreaMode              = "AF Area Mode"
local metaKeyAfPointsUsed            = "AF Points Used"
local metaKeyAfPointsSelected        = "AF Points Selected"
local metaKeyAfPointsInFocus         = "AF Points In Focus"
local metaKeyAfPrimaryPoint          = "Primary AF Point"
local metaKeyFocusMode               = "Focus Mode"
local metaKeyFocusResult             = "Focus Result"
local metaKeyFocusPointSchema        = "Focus Point Schema"
local metaKeySubjectDetection        = "Subject Detection"
local metaKeyNumberOfFocusPoints     = "Number Of Focus Points"
local metaKeySubjectMotion           = "Subject Motion"
local metaKey3DTrackingFaceDetection = "Three-D Tracking Face Detection"
local metaKey3DTrackingWatchArea     = "Three-D Tracking Watch Area"
local metaKeyAfActivation            = "AF Activation"
local metaKeyAfDetectionMethod       = "AF Detection Method"
local metaKeyFocusDistance           = "Focus Distance"
local metaKeyDepthOfField            = "Depth Of Field"
local metaKeyHyperfocalDistance      = "Hyperfocal Distance"
local metaKeyAfCPriority             = { "AF-C Priority Sel", "AF-C Priority Selection" }
local metaKeyAfSPriority             = { "AF-S Priority Sel", "AF-S Priority Selection" }

-- Image and Camera Settings relevant tags
local metaKeyCropHiSpeed             = "Crop Hi Speed"
local metaKeyShootingMode            = "Shooting Mode"

-- Forward references
local getPDAfPoints, getCAfPoints, applyPDAfCrop, applyCAFCrop,
getCropType, addFocusPointsToResult, normalizeFocusPointName

--[[----------------------------------------------------------------------------
  public table
  getAfPoints(table photo, table metadata)

  Retrieve the autofocus points from the metadata of the photo.
  Top level function. Check for presence of Contrast AF data first.
  If not found go back to EXIF and fetch PDAF data
------------------------------------------------------------------------------]]
function NikonDelegates.getAfPoints(_photo, metadata)

  local result = getCAfPoints(metadata)
  if not result then
     -- if CAF is not present, check PDAF information
    result = getPDAfPoints(metadata)
  end
  if not result then
    Log.logWarn("Nikon", "Did neither find information on CAF, nor on PDAF points")
  end
  return result
end

--[[----------------------------------------------------------------------------
  private table getCAfPoints(table metadata)

  Retrieve the autofocus points used when the photo was captured using Contrast AF.
  - Main use case for mirrorless models (Z line)
  - when shot in liveview mode on DSLRs (D line)
  Returns points table
------------------------------------------------------------------------------]]
function getCAfPoints(metadata)

  local afAreaXPosition = ExifUtils.findValue(metadata, metaKeyAfAreaXPosition)
  local afAreaYPosition = ExifUtils.findValue(metadata, metaKeyAfAreaYPosition)
  local afAreaWidth     = ExifUtils.findValue(metadata, metaKeyAfAreaWidth)
  local afAreaHeight    = ExifUtils.findValue(metadata, metaKeyAfAreaHeight)

  -- if any of these is nil then this is not complete information to proceed with
  if not (afAreaXPosition and afAreaYPosition and afAreaWidth and afAreaHeight) then
    -- we don't log this as a warning, because autofocus might not have used CAF points
    Log.logInfo("Nikon",
      string.format("No CAF information found - tags '%s', '%s', '%s', '%s' empty or partly empty",
      metaKeyAfAreaXPosition, metaKeyAfAreaYPosition,
      metaKeyAfAreaWidth, metaKeyAfAreaHeight))
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
  applyCAFCrop(result, metadata)

  return result
end

--[[----------------------------------------------------------------------------
  private table getPDAfPoints(table metadata)

  Retrieve the autofocus points used when the photo was captured using Phase Detect AF.
  - Main use case for DSLRs (D line)
  - Occurs also for Mirrorless (Z line) but less frequently
  Returns points table
------------------------------------------------------------------------------]]
function getPDAfPoints(metadata)

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

  local function getAfAreaMode(metadata)
    -- Get the value of AFAreaMode tag and simplify it for easier handling
    -- Required only for AFInfoVersion 0101 (D5, D500, D7500, D850)
    local afAreaMode = ExifUtils.findValue(metadata, metaKeyAfAreaMode)
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

  -- extract the relevant tags from metadata
  local afInfoVersion    = ExifUtils.findValue(metadata, metaKeyAfInfoVersion)
  local afPointsInFocus  = ExifUtils.findValue(metadata, metaKeyAfPointsInFocus)
  local afPointsUsed     = ExifUtils.findValue(metadata, metaKeyAfPointsUsed)
  local afPointsSelected = ExifUtils.findValue(metadata, metaKeyAfPointsSelected)
  local afPrimaryPoint   = ExifUtils.findValue(metadata, metaKeyAfPrimaryPoint)

  local primaryPoint, focusPointsTable
  local afAreaMode = getAfAreaMode(metadata)

  -- According to AFInfo version and AFAreaMode, fetch the right focus point(s) to display
  if (afInfoVersion ~= "0101") then
    -- AFPointsUsed is what NX Studio uses for all Nikon DSLR and Mirrorless cameras
    focusPointsTable = Utils.split(afPointsUsed,  ",")
    logKeyStatus(metaKeyAfPointsUsed, afPointsUsed)
  else
    -- for whatever reason, the logic for D5, D500, D7500, D850 differs from all other models
    -- depending on the AFAreaMode, choose the relevant AFPoint tag that NX Studio uses to display focus points
    if afAreaMode and Utils.arrayKeyOf({"single", "group", "dynamic" }, afAreaMode) then
      focusPointsTable = Utils.split(afPointsSelected, ",")
      logKeyStatus(metaKeyAfPointsSelected, afPointsSelected)
    elseif Utils.arrayKeyOf({"3D-tracking", "auto" }, afAreaMode) then
      if afPointsInFocus then
        focusPointsTable = Utils.split(afPointsInFocus,  ",")
        logKeyStatus(metaKeyAfPointsInFocus, afPointsInFocus)
      else
        focusPointsTable = Utils.split(afPointsSelected,  ",")
        logKeyStatus(metaKeyAfPointsSelected, afPointsSelected)
      end
    else
      Log.logError("Nikon", "Unexpected AF Area Mode: " .. afAreaMode)
      return nil
    end
  end

  -- Store PrimaryAFPoint separately from other focus points (except for 'group area')
  if afPrimaryPoint and (afAreaMode and (afAreaMode ~= "group")) then
    primaryPoint = Utils.split(normalizeFocusPointName(afPrimaryPoint),  ",")
  end

  -- if PDAF points have been found, read the mapping file
  -- @! Outsource this piece of code to a separate function?
  local fpSchema
  if focusPointsTable or primaryPoint then
    if (DefaultDelegates.cameraModel == "nikon d780") then
      -- special case: this camera uses two different PDAF coordinate systems, 51- and 81-point!
      local focusPointSchema = ExifUtils.findValue(metadata, metaKeyFocusPointSchema)
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
      if not ((focusPointsTable and Utils.arrayKeyOf(focusPointsTable, key)) or
              (primaryPoint     and Utils.arrayKeyOf(primaryPoint,     key))) then
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
    if addFocusPointsToResult(result, pointType, primaryPoint) then
      FocusInfo.focusPointsDetected = true
    else
      return nil
    end
  end

  -- Add the active focus points
  if focusPointsTable then
    if addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_FOCUS_BOX, focusPointsTable) then
      FocusInfo.focusPointsDetected = true
    else
      return nil
    end
  end

  -- Add the inactive points
  if inactivePointsTable then
    addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_INACTIVE, inactivePointsTable)
  end

  -- Apply crop dimensions to focus point coordinates if photo has been cropped in camera
  applyPDAfCrop(result, metadata)

  return result
end

--[[----------------------------------------------------------------------------
  private string, int, int, int, int, int, int
  getCropType(string cropHiSpeedValue)

  Extract cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight,
  crop_x0, crop_y0 values from cropHiSpeed tag.
------------------------------------------------------------------------------]]
function getCropType(cropHiSpeedValue)
  return string.match(
    cropHiSpeedValue,"(.+) %((%d+)x(%d+) cropped to (%d+)x(%d+) at pixel (%d+),(%d+)%)")
end

--[[----------------------------------------------------------------------------
  private void
  applyCAFCrop((table focusPoints, table metadata)

  Consider the changed dimensions of the original photo if it was not taken in
  its native format (e.g. an FX crop with a DX camera or a 16:9 crop), and if
  focus information is present in the CAF format.
  Cropping is achieved by transforming the focus point coordinates, which are
  relative to the native format.
  The CropHiSpeed tag has all the relevant information to do this
------------------------------------------------------------------------------]]
function applyCAFCrop(focusPoints, metadata)

  local cropHiSpeed = ExifUtils.findValue(metadata, metaKeyCropHiSpeed)

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
      local _cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight = getCropType(cropHiSpeed)
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

--[[----------------------------------------------------------------------------
  private void
  applyPDAFCrop((table focusPoints, table metadata)

  Consider the changed dimensions of the original photo if it was not taken in
  its native format (e.g. an FX crop with a DX camera or a 16:9 crop), and if
  focus information is present in the PDAF format.
  Cropping is achieved by transforming the focus point coordinates, which are
  relative to the native format.
  The CropHiSpeed tag has all the relevant information to do this
------------------------------------------------------------------------------]]
function applyPDAfCrop(focusPoints, metadata)

  local cropHiSpeed = ExifUtils.findValue(metadata, metaKeyCropHiSpeed)

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
      local _cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight = getCropType(cropHiSpeed)
      -- apply crop transformation on all entries in focusPointsMap
     for _, point in pairs(focusPoints.points) do
        point.x = point.x - (nativeWidth  - croppedWidth ) / 2
        point.y = point.y - (nativeHeight - croppedHeight) / 2
      end
    end
  end
end

--[[----------------------------------------------------------------------------
  private string
  normalizeFocusPointName(string focusPoint)

  Remove the word "(Center)" from the center focus points.
------------------------------------------------------------------------------]]
function normalizeFocusPointName(focusPoint)
  local focusPointin = focusPoint
  if focusPoint and focusPoint ~= "" then
    if string.find(focusPoint, "Center") then
      focusPoint = string.sub(focusPoint, 1, 2)
    end
    Log.logFull("Nikon", "focusPoint: " .. focusPointin .. ", normalized: " .. focusPoint)
  end
  return focusPoint
end

--[[----------------------------------------------------------------------------
  private boolean
  addFocusPointsToResult(table result, string focusPointType, table focusPointTable)

  Add the focus point coordinates/dimensions found to the table of focus points
  to be rendered in the next step.
------------------------------------------------------------------------------]]
function addFocusPointsToResult(result, focusPointType, focusPointTable)
  if focusPointTable then
    for _,value in pairs(focusPointTable) do
      local focusPointName = normalizeFocusPointName(value)
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

--[[----------------------------------------------------------------------------
  private table
  addInfo(string title, string key, table props, table metadata)

  Generate a row element to be added to the current view container.
------------------------------------------------------------------------------]]
local function addInfo(title, key, props, metadata)
  local f = LrView.osFactory()

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  local function populateInfo(key)
    local value = ExifUtils.findValue(metadata, key)
    if not value then
      props[key] = ExifUtils.metaValueNA
    elseif (key == metaKeyCropHiSpeed) then
      props[key] = getCropType(value)
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
      local _afPriorityValue, afPriorityKey = ExifUtils.findFirstMatchingValue( metadata, metaKeyAfCPriority)
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("AF-C Priority", afPriorityKey, props, metadata) }

    elseif (props[key] == "AF-S") then
      -- first, figure out which of the two tags is relevant for this camera
      local _afPriorityValue, afPriorityKey = ExifUtils.findFirstMatchingValue( metadata, metaKeyAfSPriority)
      return f:column{
        fill = 1, spacing = 2, result,
        addInfo("AF-S Priority", afPriorityKey, props, metadata) }

    else
      -- add row as composed
      return result
    end

  else
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end
end

--[[----------------------------------------------------------------------------
  public boolean
  modelSupported(string model)

  Indicate whether the given camera model is supported or not.
------------------------------------------------------------------------------]]
function NikonDelegates.modelSupported(currentModel)
  local m = string.match(string.lower(currentModel), "nikon (.+)")
  for _, model in ipairs(supportedModels) do
    if m == model then
      return true
    end
  end
  return false
end

--[[----------------------------------------------------------------------------
  public boolean
  makerNotesFound(table photo, table metadata)

  Check if the metadata for the current photo includes a 'Makernotes' section.
------------------------------------------------------------------------------]]
function NikonDelegates.makerNotesFound(_photo, metadata)
  local result = ExifUtils.findValue(metadata, metaKeyAfInfoSection)
  if not result then
    Log.logWarn("Nikon",
      string.format("Tag '%s' not found", metaKeyAfInfoSection))
  end
  return (result ~= nil)
end

--[[----------------------------------------------------------------------------
  public boolean
  manualFocusUsed(table photo, table metadata)

  Indicate whether the photo was taken using manual focus.
------------------------------------------------------------------------------]]
function NikonDelegates.manualFocusUsed(_photo, metadata)
  local focusMode = ExifUtils.findValue(metadata, metaKeyFocusMode)
  Log.logInfo("Nikon",
    string.format("Tag '%s' found: %s",
      metaKeyFocusMode, focusMode))
  return (focusMode == "Manual")
end

--[[----------------------------------------------------------------------------
  public table
  function getImageInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Image Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function NikonDelegates.getImageInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local imageInfo
  imageInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Crop Mode", metaKeyCropHiSpeed, props, metadata),
  }
  return imageInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getShootingInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Shooting Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function NikonDelegates.getShootingInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Shooting Mode", metaKeyShootingMode, props, metadata),
  }
  return shootingInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getFocusInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to fetch the items in the 'Focus Information'
  section (which is entirely maker-specific).
------------------------------------------------------------------------------]]
function NikonDelegates.getFocusInfo(_photo, props, metadata)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      addInfo("Focus Mode",             metaKeyFocusMode,           props, metadata),
      addInfo("Focus Result",           metaKeyFocusResult,         props, metadata),
      addInfo("AF Area Mode",           metaKeyAfAreaMode,          props, metadata),
      addInfo("AF Detection Method",    metaKeyAfDetectionMethod,   props, metadata),
      addInfo("Subject Detection",      metaKeySubjectDetection,    props, metadata),
      addInfo("Subject Motion",         metaKeySubjectMotion,       props, metadata),
      addInfo("3D-Tracking Watch Area", metaKey3DTrackingWatchArea, props, metadata),
      addInfo("AF Activation",          metaKeyAfActivation,        props, metadata),
      addInfo("Number of Focus Points", metaKeyNumberOfFocusPoints, props, metadata),
      FocusInfo.addSpace(),
      FocusInfo.addSeparator(),
      FocusInfo.addSpace(),
      addInfo("Focus Distance",         metaKeyFocusDistance,       props, metadata),
      addInfo("Depth of Field",         metaKeyDepthOfField,        props, metadata),
      addInfo("Hyperfocal Distance",    metaKeyHyperfocalDistance,  props, metadata),
      }
  return focusInfo
end

return NikonDelegates -- ok
