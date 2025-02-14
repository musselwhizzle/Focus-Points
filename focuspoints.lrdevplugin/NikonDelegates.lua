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

local LrErrors = import 'LrErrors'
local LrView = import 'LrView'
local LrColor = import 'LrColor'


require "Utils"

NikonDelegates = {}

NikonDelegates.focusPointsDetected = false

-- relevant Metadata tag names
NikonDelegates.metaKeyPhaseDetectAF      = "Phase Detect AF"
NikonDelegates.metaKeyAfInfoVersion      = "AF Info 2 Version"
NikonDelegates.metaKeyAfAreaMode         = "AF Area Mode"
NikonDelegates.metaKeyAfPointsUsed       = "AF Points Used"
NikonDelegates.metaKeyAfPointsSelected   = "AF Points Selected"
NikonDelegates.metaKeyAfPointsInFocus    = "AF Points In Focus"
NikonDelegates.metaKeyCropHiSpeed        = "Crop Hi Speed"
NikonDelegates.metaKeyCropArea           = "Crop Area"
NikonDelegates.metaKeyFocusMode          = "Focus Mode"
NikonDelegates.metaKeyFocusResult        = "Focus Result"
NikonDelegates.metaKeyAfAreaMode         = "AF Area Mode"
NikonDelegates.metaKeySubjectDetection   = "Subject Detection"
NikonDelegates.metaKeyAfCropHiSpeed      = "Crop Hi Speed"
NikonDelegates.metaKeyContrastDetect     = "Contrast Detect AF"
NikonDelegates.metaKeyPhaseDetect        = "Phase Detect AF"
NikonDelegates.metaKeyFocusDistance      = "Focus Distance"
NikonDelegates.metaKeyDepthOfField       = "Depth Of Field"
NikonDelegates.metaKeyHyperfocalDistance = "Hyperfocal Distance"
NikonDelegates.metaKeyAfCPriority        = "AF-C Priority Sel"
NikonDelegates.metaKeyAfSPriority        = " AF-S Priority Sel"
NikonDelegates.metaKeyShootingMode       = "Shooting Mode"

NikonDelegates.metaValueNA               = "N/A"


--[[
  @@public table NikonDelegates.getAfPoints(table photo, table metaData)
  ----
  Top level function to get the autofocus points from metadata
  Check for presence of Contrast AF data first. If not found go back to EXIF and fetch PDAF data
--]]
function NikonDelegates.getAfPoints(photo, metaData)
  -- look for CAF information first
  local result = NikonDelegates.getCAfPoints(metaData)
  if (result == nil) then
     -- if CAF is not present, check PDAF information
    result = NikonDelegates.getPDAfPoints(metaData)
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
  local afAreaXPosition = ExifUtils.findValue(metaData, "AF Area X Position")
  local afAreaYPosition = ExifUtils.findValue(metaData, "AF Area Y Position")
  local afAreaWidth     = ExifUtils.findValue(metaData, "AF Area Width")
  local afAreaHeight    = ExifUtils.findValue(metaData, "AF Area Height")

  -- if any of these is nil then this is not complete information to proceed with
  if (afAreaXPosition == nil) or (afAreaYPosition == nil) or (afAreaWidth == nil) or (afAreaHeight == nil) then
    return nil
  end

  -- otherwise, simply pass on the focus area coordinates from metadata
  NikonDelegates.focusPointsDetected = true
  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_USED,
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

  -- helper function to check whether a string is contained in a table (of strings)
  local function contains(tbl, value)
    if (tbl ~= nil) then
      for _, v in ipairs(tbl) do
        if v == value then
          return true
        end
      end
    end
    return false
  end

  -- if the photo has been taken by a DSLR but with Contrast AF we can immediately return
  local phaseDetectAF = ExifUtils.findValue(metaData, NikonDelegates.metaKeyPhaseDetectAF)
  if (phaseDetectAF ~= nil) and (string.lower(phaseDetectAF)) == "off" then
    return nil
  end

  -- extract the relevant tags from metadata
  local afInfoVersion    = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfInfoVersion)
  local afPointsInFocus  = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPointsInFocus)
  local afPointsUsed     = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPointsUsed)
  local afPointsSelected = ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfPointsSelected)

  local focusPointsTable, afAreaMode, pointMode

  -- According to AFInfo version and AFAreaMode, fetch the right focus point(s) to display
  if (afInfoVersion ~= "0101") then
    -- AFPointsUsed is what NX Studio uses for all Nikon DSLR and Mirrorless cameras
    focusPointsTable = split(afPointsUsed,  ",")
  else
    -- for whatever reason, the logic for D5, D500, D7500, D850 differs from all other models
    afAreaMode = NikonDelegates.getAfAreaMode(metaData)
    -- depending on the AFAreaMode, choose the relevant AFPoint tag that NX Studio uses to display focus points
    if contains({"single", "group", "dynamic" }, afAreaMode) then
      focusPointsTable = split(afPointsSelected, ",")
    elseif contains({"3D-tracking", "auto" }, afAreaMode) then
      if (afPointsInFocus ~= nil) then
        focusPointsTable = split(afPointsInFocus,  ",")
      else
        focusPointsTable = split(afPointsSelected,  ",")
      end
    else
      -- Sanity check
      LrErrors.throwUserError("Internal error: unknow AF Area Mode: " .. afAreaMode )
    end
  end

  -- if PDAF points have been found, read the mapping file
  -- @! Outsource this piece of code to a separate function?
  if (focusPointsTable ~= nil) then
    if (DefaultDelegates.cameraModel == "nikon d780") then
      -- special case: this camera uses two different PDAF coordinate systems, 51- and 81-point!
      pointMode = ExifUtils.findValue(metaData, NikonDelegates.metaKeyPhaseDetect)
      if (pointMode == "On (51-point)") or (pointMode == "On (81-point)") then
        -- appendix number to mapping file name
        pointMode = "-" .. string.sub(pointMode, 5, 6)
      else
        LrErrors.throwUserError("Invalid Phase Detect AF mode: \n" .. pointmode)
      end
    else
      -- mapping file name is camera model name w/o any appendix
      pointMode = ""
    end

    DefaultDelegates.focusPointsMap,
    DefaultDelegates.focusPointDimen = PointsUtils.readIntoTable(DefaultDelegates.cameraMake,
    DefaultDelegates.cameraModel .. pointMode .. ".txt")

    if (DefaultDelegates.focusPointsMap == nil) then
      LrErrors.throwUserError("No (or incorrect) mapping found at: \n"
                              .. DefaultDelegates.cameraMake .. "/"
                              .. DefaultDelegates.cameraModel .. pointMode .. ".txt")
    end
  else
    -- can't find PDAF focus point information, return and check CAF
    return nil
  end

  -- from the mapping file we know all the relevant focus points for this photo,
  -- so we will create the visual representation of the layout as an accompanying overlay
  local inactivePointsTable = {}
  if (string.sub(DefaultDelegates.cameraModel, 1, 7) == "nikon d") and (pointMode ~= "-81") then
    -- however, we only do this for DSLRs to visualize the limited AF point coverage of the frame
    for key, _ in pairs(DefaultDelegates.focusPointsMap) do
      if (not contains(focusPointsTable, key)) then
        table.insert(inactivePointsTable, key)
      end
    end
  end

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {}
  }

  -- add the active focus points
  if (focusPointsTable ~= nil) then
    NikonDelegates.addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_USED, focusPointsTable)
    NikonDelegates.focusPointsDetected = true
  end

  -- add the inactive points
  if (inactivePointsTable ~= nil) then
    NikonDelegates.addFocusPointsToResult(result, DefaultDelegates.POINTTYPE_AF_INACTIVE, inactivePointsTable)
  end

  -- apply crop dimensions to focus point coordinates if photo has been cropped in camera
  NikonDelegates.applyPDAfCrop(result, metaData)

  return result

end


--[[
  @@public void NikonDelegates.addFocusPointsToResult(table result, string focusPointType, table focusPointTable)
  ----
  Transfer focus points from focusPointTable to the result table and mark them as focusPointType
--]]
function NikonDelegates.addFocusPointsToResult(result, focusPointType, focusPointTable)
  if (focusPointTable ~= nil) then
    for _,value in pairs(focusPointTable) do
      local focusPointName = NikonDelegates.normalizeFocusPointName(value)
      if DefaultDelegates.focusPointsMap[focusPointName] == nil then
        LrErrors.throwUserError("The AF-Point " .. focusPointName .. " could not be found within the file.")
        return nil
      end

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


--[[
  @@public string NikonDelegates.normalizeFocusPointName(string focusPoint)
  ----
  Removes the word "(Center)" from the center focus points.
  This function is a remnant of the original implementation which used PrimaryAFPoint tag.
  We don't use this tag anymore, anyway keeping (and using) this function does no harm
--]]
function NikonDelegates.normalizeFocusPointName(focusPoint)
  local focusPointin = focusPoint
  if ((focusPoint ~= nil) and (focusPoint ~= "")) then
    if (string.find(focusPoint, "Center") ~= nil) then
      focusPoint = string.sub(focusPoint, 1, 2)
    end
    logDebug("NikonDelegates", "focusPoint: " .. focusPointin .. ", normalized: " .. focusPoint)
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

  if (cropHiSpeed ~= nil) then
    -- perform string comparisons in lower case
    cropHiSpeed = string.lower(cropHiSpeed)
    -- check if image has been taken in crop mode
    if ((string.sub(cropHiSpeed, 1,3) == "off") or (string.find(cropHiSpeed, "uncropped"))) then
      -- photo taken in native format - nothing to do
      return
    else
      -- get crop dimensions
      local cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight = NikonDelegates.getCropType(cropHiSpeed)
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

  if (cropHiSpeed ~= nil) then
    -- perform string comparisons in lower case
    cropHiSpeed = string.lower(cropHiSpeed)
    -- check if image has been taken in crop mode
    if ((string.sub(cropHiSpeed, 1,3) == "off") or (string.find(cropHiSpeed, "uncropped"))) then
      -- photo taken in native format - nothing to do
      return
    else
      -- get crop dimensions
      local cropType, nativeWidth, nativeHeight, croppedWidth, croppedHeight = NikonDelegates.getCropType(cropHiSpeed)
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

-- ========================================================================================================================

--[[
  @@public table NikonDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
function NikonDelegates.addInfo(title, key, props, metaData)
  local f = LrView.osFactory()

  -- Creates and populates the property corresponding to metadata key
  local function populateInfo(key)
    local result = ExifUtils.findValue(metaData, key)
    if (result == nil) then
      props[key] = NikonDelegates.metaValueNA
    elseif (key == NikonDelegates.metaKeyAfCropHiSpeed) then
      props[key] = NikonDelegates.getCropType(result)
    else
      props[key] = result
    end
  end

  -- create and populate property with designated value
  populateInfo(key)

  -- compose the row to be added
  local result = f:row {
                   f:column{f:static_text{title = title .. ":", font="<system>"}},
                   f:spacer{fill_horizontal = 1},
                   f:column{f:static_text{title = props[key], font="<system>"}}}
  -- decide if and how to add it
  if (props[key] == NikonDelegates.metaValueNA) then
    -- we won't display any "N/A" entries - return a empty row (that will get ignored by LrView)
    return f:row{}
  elseif (props[key] == "AF-C") then
    return f:column{
      fill = 1, spacing = 2, result,
      NikonDelegates.addInfo("AF-C Priority", NikonDelegates.metaKeyAfCPriority, props, metaData) }
  elseif (props[key] == "AF-S") then
    return f:column{
      fill = 1, spacing = 2, result,
      NikonDelegates.addInfo("AF-S Priority", NikonDelegates.metaKeyAfSPriority, props, metaData) }
  else
    -- add row as composed
    return result
  end
end

--[[
  @@public table function NikonDelegates.getImageInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Image Information" section
  -- if any, otherwise return an empty column
--]]
function NikonDelegates.getImageInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local imageInfo
  if true then
    imageInfo = f:column {
      fill = 1,
      spacing = 2,
      NikonDelegates.addInfo("Crop mode", NikonDelegates.metaKeyAfCropHiSpeed, props, metaData),
    }
  else
    imageInfo = f:column{}
  end
  return imageInfo
end

--[[
  @@public table function NikonDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function NikonDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  if true then
    cameraInfo = f:column {
      fill = 1,
      spacing = 2,
      NikonDelegates.addInfo("Shooting mode", NikonDelegates.metaKeyShootingMode, props, metaData),
    }
  else
    cameraInfo = f:column{}
  end
  return cameraInfo
end

--[[
  @@public table NikonDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function NikonDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- helper function to add information whether focus points have been found or not
  local function addFocusPointsStatus()
    if (NikonDelegates.focusPointsDetected) then
      return f:row {f:static_text {title = "Focus points detected", text_color=LrColor(0, 100, 0), font="<system>"}}
    else
      return f:row {f:static_text {title = "No focus points detected", text_color=LrColor("red"), font="<system/bold>"}}
    end
  end

    -- first check if makernotes AF section is present in metadata
  if (ExifUtils.findValue(metaData, NikonDelegates.metaKeyAfInfoVersion) == nil) then
    -- if not we can immediately stop
    return f:column{f:static_text{ title = "Focus info missing from file!", text_color=LrColor("red"), font="<system/bold>"}}
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      addFocusPointsStatus(),
      NikonDelegates.addInfo("Focus Mode",            NikonDelegates.metaKeyFocusMode,          props, metaData),
      NikonDelegates.addInfo("Focus Result",          NikonDelegates.metaKeyFocusResult,        props, metaData),
      NikonDelegates.addInfo("AF Area Mode",          NikonDelegates.metaKeyAfAreaMode,         props, metaData),
      NikonDelegates.addInfo("Subject Detection",     NikonDelegates.metaKeySubjectDetection,   props, metaData),
      NikonDelegates.addInfo("Phase Detect",          NikonDelegates.metaKeyPhaseDetect,        props, metaData),
      NikonDelegates.addInfo("Contrast Detect",       NikonDelegates.metaKeyContrastDetect,     props, metaData),
      NikonDelegates.addInfo("Focus Distance",        NikonDelegates.metaKeyFocusDistance,      props, metaData),
      NikonDelegates.addInfo("Depth of Field",        NikonDelegates.metaKeyDepthOfField,       props, metaData),
      NikonDelegates.addInfo("Hyperfocal Distance",   NikonDelegates.metaKeyHyperfocalDistance, props, metaData),
      }
  return focusInfo
end
