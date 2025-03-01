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

  For Olympus (since 2008) and OMDS cameras, focus point metadata looks like this:
  
    AF Point Selected               : (50%,15%) (50%,15%)
    AF Areas                        : (118,32)-(137,49)
  
    Where:
        AF Point Selected appears to be % of photo from upper left corner (X%, Y%)
        AF Areas appears to be focus box as coordinates relative to 0..255 from upper left corner (x,y)

    In contrast to the original implementation AF Areas information will no longer be used, since it
    has no practical relevance. Olympus/OM AF Points do not have a dimension, it's just a pixel.
    For focus 'pixel' points the plugin offers three different box sizes (small, medium, large) for
    better visibility of the focus point.
    
    When using the AF Point Selected values given in percentage format, there can be small deviations of the
    focus point position when compare with Olympus/OM Workspace. This is due to the fact, that the percentage
    string is an exiftool simplification of the actual information which is given as rational number.
    The deviations are the result of rounding errors (0.5% ~ 26px at long edge)
    
    A future version of the plugin may use exiftool in stay-open mode. This would allow to avoid creating and
    searching a complete textual list of metadata and perform targeted queries of the required tags.
--]]

local LrView   = import 'LrView'

require "FocusPointPrefs"
require "FocusPointDialog"
require "Utils"
require "Log"


OlympusDelegates = {}

-- To trigger display whether focus points have been detected or not
OlympusDelegates.focusPointsDetected = false

-- Tag which indicates that makernotes / AF section is present
OlympusDelegates.metaKeyAfInfoSection       = "Focus Info Version"

-- AF relevant tags
OlympusDelegates.metaKeyFocusMode                = "Focus Mode"
OlympusDelegates.metaKeyAfSearch                 = "AF Search"
OlympusDelegates.metaKeySubjectTrackingMode      = "AI Subject Tracking Mode"
OlympusDelegates.metaKeyFocusDistance            = "Focus Distance"
OlympusDelegates.metaKeyDepthOfField             = "Depth Of Field"
OlympusDelegates.metaKeyHyperfocalDistance       = "Hyperfocal Distance"
OlympusDelegates.metaKeyReleasePriority          = "Release Priority"
OlympusDelegates.metaKeyAfPointDetails           = "AF Point Details"
OlympusDelegates.metaKeyAfPointSelected          = "AF Point Selected"

-- Image and Camera Settings relevant tags
OlympusDelegates.metaKeyDriveMode                = "Drive Mode"
OlympusDelegates.metaKeyImageStabilization       = "Image Stabilization"

-- relevant metadata values
OlympusDelegates.metaValueNA                     = "N/A"
OlympusDelegates.metaKeyAfPointSelectedPattern   = "%((%d+)%%,(%d+)"


--[[
  @@public table OlympusDelegates.getAfPoints(table photo, table metaData)
  ----
  Get the autofocus points from metadata
--]]
function OlympusDelegates.getAfPoints(photo, metaData)

   OlympusDelegates.focusPointsDetected = false

  -- Fetch focus point info
  local focusPoint = ExifUtils.findValue(metaData, OlympusDelegates.metaKeyAfPointSelected)
  if focusPoint then
    Log.logInfo("Olympus",
      string.format("Focus point tag '%s' tag found", OlympusDelegates.metaKeyAfPointSelected, focusPoint))
  else
    -- no focus points found - handled on upper layers
    Log.logWarn("Olympus",
      string.format("Focus point tag '%s' tag not found", OlympusDelegates.metaKeyAfPointSelected))
    return nil
  end

  -- Extract the coordinates (in percent of image dimensions)
  local focusX, focusY = string.match(focusPoint, OlympusDelegates.metaKeyAfPointSelectedPattern)
  if not (focusX and focusY) then
    Log.logError("Olympus", "Error at extracting x/y positions from focus point tag")
    return nil
  end
  
  local orgPhotoWidth, orgPhotoHeight = DefaultPointRenderer.getNormalizedDimensions(photo)

  -- Transform the percentage values into pixels 
  local x = tonumber(orgPhotoWidth) * tonumber(focusX) / 100
  local y = tonumber(orgPhotoHeight) * tonumber(focusY) / 100
  Log.logInfo("Olympus", string.format("Focus point detected at [x=%s, y=%s]", x, y))

  OlympusDelegates.focusPointsDetected = true
  return DefaultPointRenderer.createFocusPixelBox(x, y)
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

    if not value then
      props[key] = OlympusDelegates.metaValueNA

    elseif (key == OlympusDelegates.metaKeyFocusMode) then
      -- special case: Focus Mode. Add MF if selected in settings
        props[key] = OlympusDelegates.getFocusMode(value)

    elseif (key == OlympusDelegates.metaKeyAfPointDetails) then
      -- special case: AFPointDetails. Extract ReleasePriority portion
      if value then
          props[key] = get_nth_word(value, 7, ";")
      end

    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if props[key] and props[key] ~= OlympusDelegates.metaValueNA then
    -- compose the row to be added
    local result = f:row {
      f:column{f:static_text{title = title .. ":", font="<system>"}},
      f:spacer{fill_horizontal = 1},
      f:column{f:static_text{title = escape(props[key]), font="<system>"}}
    }
    -- check if the entry to be added has implicite followers (eg. Priority for AF modes)
    if string.sub(props[key], 1, 4) == "S-AF" or string.sub(props[key], 1, 4) == "C-AF" then
      return f:column{fill = 1, spacing = 2, result,
      OlympusDelegates.addInfo("Release Priority", OlympusDelegates.metaKeyAfPointDetails, props, metaData) }
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
  @@public string OlympusDelegates.getFocusMode(string focusModeValue)
  ----
  Extract the desired focus mode details from a string all kinds of information
--]]
function OlympusDelegates.getFocusMode(focusModeValue)

  local f = splitTrim(focusModeValue:gsub(", Imager AF", ""), ";,")
  if #f > 1 then
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
        m = m .. " (" .. f[3] .. ")"
      end
    end
    return m
  else
    return f[1]
  end
end


--[[
  @@public table OlympusDelegates.addSpace()
  ----
  Adds a spacer between the current entry and the next one
--]]
function OlympusDelegates.addSpace()
  local f = LrView.osFactory()
    return f:spacer{height = 2}
end


--[[
  @@public table OlympusDelegates.addSeparator()
  ----
  Adds a separator line between the current entry and the next one
--]]
function OlympusDelegates.addSeparator()
  local f = LrView.osFactory()
    return f:separator{ fill_horizontal = 1 }
end


--[[
  @@public boolean OlympusDelegates.modelSupported(model)
  ----
  Checks whether the camera model is supported or not
--]]
function OlympusDelegates.modelSupported(model)
  local e  = string.match(model, "e%-(%d+)")
  local em = string.match(model, "e%-m(%d+)")
  local om = string.match(model, "om%-(%d+)")
  -- any mirrorless EM/OM or E-5, E-420, E-520, E-620 is supported
  local isSupportedModel = om or em or ((e == "5") or (e=="420") or (e=="520") or (e=="620"))
  if not isSupportedModel then
    Log.logError("Olympus", "Camera model " .. model .. " is not supported")
  end
  return isSupportedModel
end


--[[
  @@public table function OlympusDelegates.getCameraInfo(table photo, table props, table metaData)
  -- called by FocusInfo.createInfoView to append maker specific entries to the "Camera Information" section
  -- if any, otherwise return an empty column
--]]
function OlympusDelegates.getCameraInfo(photo, props, metaData)
  local f = LrView.osFactory()
  local cameraInfo
  -- append maker specific entries to the "Camera Settings" section
  cameraInfo = f:column {
    fill = 1,
    spacing = 2,
    OlympusDelegates.addInfo("Drive Mode",            OlympusDelegates.metaKeyDriveMode,           props, metaData),
    OlympusDelegates.addInfo("Image Stabilization",   OlympusDelegates.metaKeyImageStabilization,  props, metaData),
  }
  return cameraInfo
end


--[[
  @@public table OlympusDelegates.getFocusInfo(table photo, table info, table metaData)
  ----
  Constructs and returns the view to display the items in the "Focus Information" group
--]]
function OlympusDelegates.getFocusInfo(photo, props, metaData)
  local f = LrView.osFactory()

  -- Check if the current camera model is supported
  if not OlympusDelegates.modelSupported(DefaultDelegates.cameraModel) then
    -- if not, finish this section with an error message
    return FocusInfo.errorMessage("Camera model not supported")
  end

    -- Check if makernotes AF section is (still) present in metadata of file
  local errorMessage = FocusInfo.afInfoMissing(metaData, OlympusDelegates.metaKeyAfInfoSection)
  if errorMessage then
    -- if not, finish this section with predefined error message
    return errorMessage
  end

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.FocusPointsStatus(OlympusDelegates.focusPointsDetected),
      OlympusDelegates.addInfo("Focus Mode",            OlympusDelegates.metaKeyFocusMode,           props, metaData),
      OlympusDelegates.addInfo("AF Search",             OlympusDelegates.metaKeyAfSearch,            props, metaData),
      OlympusDelegates.addInfo("Subject Tracking",      OlympusDelegates.metaKeySubjectTrackingMode, props, metaData),
      OlympusDelegates.addSpace(),
      OlympusDelegates.addSeparator(),
      OlympusDelegates.addSpace(),
      OlympusDelegates.addInfo("Focus Distance",        OlympusDelegates.metaKeyFocusDistance,       props, metaData),
      OlympusDelegates.addInfo("Depth of Field",        OlympusDelegates.metaKeyDepthOfField,        props, metaData),
      OlympusDelegates.addInfo("Hyperfocal Distance",   OlympusDelegates.metaKeyHyperfocalDistance,  props, metaData),
      }
  return focusInfo
end
