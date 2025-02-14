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
  the camera is Olympus

  Assume that focus point metadata look like:

    AF Areas                        : (118,32)-(137,49)
    AF Point Selected               : (50%,15%) (50%,15%)

    Where:
        AF Point Selected appears to be % of photo from upper left corner (X%, Y%)
        AF Areas appears to be focus box as coordinates relative to 0..255 from upper left corner (x,y)

  2017-01-06 - MJ - Test for 'AF Point Selected' in Metadata, assume it's good if found
                    Add basic errorhandling if not found
  2017-01-07 - MJ Use 'AF Areas' tag to size focus box
                    Note that on cameras where it is possible to change the size of the focus box,
                    I.E - E-M1, the metadata doesn't show the true size, so all focus boxes will be
                    the same size.
  2017-01-07 - MJ Fix math bug in rotated images

TODO: Verify math by comparing focus point locations with in-camera views.

--]]

local LrErrors = import 'LrErrors'
local LrView = import 'LrView'
local LrColor = import 'LrColor'


require "Utils"

OlympusDelegates = {}

OlympusDelegates.focusPointsDetected = false

-- relevant Metadata tag names
OlympusDelegates.metaKeyFocusMode           = "Focus Mode"
OlympusDelegates.metaKeyAfSearch            = "AF Search"
OlympusDelegates.metaKeySubjectTrackingMode = "AI Subject Tracking Mode"
OlympusDelegates.metaKeyDriveMode           = "Drive Mode"
OlympusDelegates.metaKeyImageStabilization  = "Image Stabilization"
OlympusDelegates.metaKeyFocusDistance       = "Focus Distance"
OlympusDelegates.metaKeyDepthOfField        = "Depth Of Field"
OlympusDelegates.metaKeyHyperfocalDistance  = "Hyperfocal Distance"
OlympusDelegates.metaKeyReleasePriority     = "Release Priority"
OlympusDelegates.metaKeyAfPointDetails      = "AF Point Details"

OlympusDelegates.metaValueNA                = "N/A"


--[[
-- metaData - the metadata as read by exiftool
--]]
function OlympusDelegates.getAfPoints(photo, metaData)
  -- find selected AF point
  local focusPoint = ExifUtils.findValue(metaData, "AF Point Selected")
  if focusPoint == nil then
    -- expected information missing - handle on upper layers
    return nil
  end

  local focusX, focusY = string.match(focusPoint, "%((%d+)%%,(%d+)")
  if focusX == nil or focusY == nil then
    return nil
  end
  logDebug("Olympus", "Focus %: " .. focusX .. "," ..  focusY .. "," .. focusPoint)

  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)
  if orgPhotoWidth == nil or orgPhotoHeight == nil then
      LrErrors.throwUserError("Metadata has no Dimensions")
      return nil
  end
  logDebug("Olympus", "Focus px: " .. tonumber(orgPhotoWidth) * tonumber(focusX)/100 .. "," .. tonumber(orgPhotoHeight) * tonumber(focusY)/100)

  local x = tonumber(orgPhotoWidth) * tonumber(focusX) / 100
  local y = tonumber(orgPhotoHeight) * tonumber(focusY) / 100
  logDebug("Olympus", "FocusXY: " .. x .. ", " .. y)

  -- determine size of bounding box of AF area in image pixels
  local afArea = ExifUtils.findValue(metaData, "AF Areas" )
  local afAreaX1, afAreaY1, afAreaX2, afAreaY2 = string.match(afArea, "%((%d+),(%d+)%)%-%((%d+),(%d+)%)" )
  local afAreaWidth = 300
  local afAreaHeight = 300

  if afAreaX1 ~= nil and afAreaY1 ~= nil and afAreaX2 ~= nil and afAreaY2 ~= nil then
      afAreaWidth = math.abs(tonumber(afAreaX2) - tonumber(afAreaX1)) * tonumber(orgPhotoWidth) / 255
      afAreaHeight = math.abs(tonumber(afAreaY2) - tonumber(afAreaY1)) * tonumber(orgPhotoHeight) / 255
  end

  afAreaWidth = math.abs(0) * tonumber(orgPhotoWidth) / 255
  afAreaHeight = math.abs(0) * tonumber(orgPhotoHeight) / 255

  logDebug("Olympus", "Focus Area: " .. afArea .. ", " .. afAreaX1 .. ", " .. afAreaY1 .. ", " .. afAreaX2 .. ", " .. afAreaY2 .. ", " .. afAreaWidth .. ", " .. afAreaHeight )

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
      {
        pointType = DefaultDelegates.POINTTYPE_AF_SELECTED,
        x = x,
        y = y,
        width = afAreaWidth,
        height = afAreaHeight
      }
    }
  }

  OlympusDelegates.focusPointsDetected = true
  return result
end

-- ========================================================================================================================

--[[
  @@public table OlympusDelegates.addInfo(string title, string key, table props, table metaData)
  ----
  Creates the view element for an item to add to a info section and creates/populates the corresponding property
--]]
  function OlympusDelegates.addInfo(title, key, props, metaData)
    local f = LrView.osFactory()

    -- Creates and populates the property corresponding to metadata key
    local function populateInfo(key)
      local value = ExifUtils.findValue(metaData, key)

      if (value == nil) then
        props[key] = OlympusDelegates.metaValueNA

      elseif (key == OlympusDelegates.metaKeyFocusMode) then
        -- special case: Focus Mode. Add MF if selected in settings
          props[key] = OlympusDelegates.getFocusMode(value)

      elseif (key == OlympusDelegates.metaKeyAfPointDetails) then
        -- special case: AFPointDetails. Extract ReleasePriority portion
        if (value ~= nil) then
            props[key] = get_nth_word(value, 7, ";")
        end

      else
        -- everything else is the default case!
        props[key] = value
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
    if (props[key] == OlympusDelegates.metaValueNA) then
      -- we won't display any "N/A" entries - return a empty row (that will get ignored by LrView)
      return f:row{}
    elseif string.sub(props[key], 3, 4) == "AF" then
      return f:column{fill = 1, spacing = 2, result,
        OlympusDelegates.addInfo("Release Priority", OlympusDelegates.metaKeyAfPointDetails, props, metaData) }
    else
      -- add row as composed
      return result
    end
  end

function OlympusDelegates.getFocusMode(focusModeValue)

  local f = splitTrim(focusModeValue:gsub(", Imager AF", ""), ";,")
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
      m = m .. " (Live View)"
    else
      m = m .. " (" .. f[3] .. ")"
    end
   end
  return m
end


--[[
  @@public table function NikonDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function OlympusDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  if true then
    cameraInfo = f:column {
      fill = 1,
      spacing = 2,
      OlympusDelegates.addInfo("Drive Mode",            OlympusDelegates.metaKeyDriveMode,           props, metaData),
      OlympusDelegates.addInfo("Image Stabilization",   OlympusDelegates.metaKeyImageStabilization,  props, metaData),
    }
  else
    cameraInfo = f:column{}
  end
  return cameraInfo
end


--[[
  public table getFocuInfo(table photo, table props, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function OlympusDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- helper function to add information whether focus points have been found or not
  local function addFocusPointsStatus()
    if (OlympusDelegates.focusPointsDetected) then
      return f:row {f:static_text {title = "Focus points detected", text_color=LrColor(0, 100, 0), font="<system>"}}
    else
      return f:row {f:static_text {title = "No focus points detected", text_color=LrColor("red"), font="<system/bold>"}}
    end
  end

  -- first check if makernotes AF section is present in metadata
  if (ExifUtils.findValue(metaData, "Focus Info Version") == nil) then
    -- if not we can immediately stop
    return f:column{f:static_text{ title = "Focus info missing from file!", text_color=LrColor("red"), font="<system/bold>"}}
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      addFocusPointsStatus(),
      OlympusDelegates.addInfo("Focus Mode",            OlympusDelegates.metaKeyFocusMode,           props, metaData),
      OlympusDelegates.addInfo("AF Search",             OlympusDelegates.metaKeyAfSearch,            props, metaData),
      OlympusDelegates.addInfo("Subject Tracking",      OlympusDelegates.metaKeySubjectTrackingMode, props, metaData),
      OlympusDelegates.addInfo("Focus Distance",        OlympusDelegates.metaKeyFocusDistance,       props, metaData),
      OlympusDelegates.addInfo("Depth of Field",        OlympusDelegates.metaKeyDepthOfField,        props, metaData),
      OlympusDelegates.addInfo("Hyperfocal Distance",   OlympusDelegates.metaKeyHyperfocalDistance,  props, metaData),
      }
  return focusInfo
end
