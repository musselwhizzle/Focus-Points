--[[
  Copyright 2025 Karsten Gieselmann

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
  This object is responsible for creating the textual info view next to focus point display.
--]]

local LrView = import 'LrView'
local LrColor = import 'LrColor'

require "DefaultPointRenderer"

FocusInfo = {}

FocusInfo.metaKeyFileName           = "fileName"
FocusInfo.metaKeyDimensions         = "dimensions"
FocusInfo.metaKeyCroppedDimensions  = "croppedDimensions"
FocusInfo.metaKeyDateTimeOriginal   = "dateTimeOriginal"
FocusInfo.metaKeyCameraModel        = "cameraModel"
FocusInfo.metaKeyLens               = "lens"
FocusInfo.metaKeyFocalLength        = "focalLength"
FocusInfo.metaKeyExposure           = "exposure"
FocusInfo.metaKeyIsoSpeedRating     = "isoSpeedRating"
FocusInfo.metaKeyExposureBias       = "exposureBias"
FocusInfo.metaKeyExposureProgram    = "exposureProgram"
FocusInfo.metaKeyMeteringMode       = "meteringMode"
FocusInfo.metaValueNA               = "N/A"


--[[
  @@public table, table, table FocusInfo.getMakerInfo(table photo, table props)
   ----
   For each of the three view sections (image, settings, focus) collect maker specific information
   Specific information on image and camera settings will be appended, focus information will be completely filled
   Result:  imageInfo, cameraInfo, focusInfo
--]]
function FocusInfo.getMakerInfo(photo, props)
  local f = LrView.osFactory()

  -- get maker specific image information, if any
  local imageInfo
  if (DefaultPointRenderer.funcGetImageInfo ~= nil) then
    imageInfo = DefaultPointRenderer.funcGetImageInfo(photo, props, DefaultDelegates.metaData)
  else
    imageInfo = f:column{}
  end

  -- get maker specific camera settings information, if any
  local cameraInfo
  if (DefaultPointRenderer.funcGetCameraInfo ~= nil) then
    cameraInfo = DefaultPointRenderer.funcGetCameraInfo(photo, props, DefaultDelegates.metaData)
  else
    cameraInfo = f:column{}
  end

  -- get focus information which is always maker specific
  local focusInfo
  if (DefaultPointRenderer.funcGetFocusInfo ~= nil) then
    focusInfo = DefaultPointRenderer.funcGetFocusInfo(photo, props, DefaultDelegates.metaData)
  else
    focusInfo = f:column{f:static_text{title = "Not yet implemented", font="<system>"}}
  end

  return imageInfo, cameraInfo, focusInfo
end

--[[
  @@public table FocusInfo.errorMessage(string errorMessage)
  ----
  Creates an error message text to be added to the current section
--]]
function FocusInfo.errorMessage(message)
  local f = LrView.osFactory()
  return f:column{
    f:static_text{
      title = message,
      text_color=LrColor("red"),
      font="<system/bold>"}
  }
end


--[[
  @@public table FocusInfo.addSpace()
  ----
  Adds a spacer between the current entry and the next one
--]]
function FocusInfo.addSpace()
  local f = LrView.osFactory()
    return f:spacer{height = 2}
end


--[[
  @@public table FocusInfo.addSeparator()
  ----
  Adds a separator line between the current entry and the next one
--]]
function FocusInfo.addSeparator()
  local f = LrView.osFactory()
    return f:separator{ fill_horizontal = 1 }
end


--[[
  @@public table FocusInfo.afInfoMissing(table metaData, string afInfoSectionKey)
  ----
  Checks if AF info section is present in metadata. Returns a view entry with an error message if not
--]]
function FocusInfo.afInfoMissing(metaData, afInfoSectionKey)
  local f = LrView.osFactory()
  local result
  result = ExifUtils.findValue(metaData, afInfoSectionKey)
  if not result then
    return FocusInfo.errorMessage("Focus info missing from file")
  end
  return nil
end

--[[
  @@public table FocusInfo.FocusPointsStatus(boolean focusPointsDeteced)
  ----
  Returns a view entry stating whether focus points have been found or not
--]]
  -- helper function to add information whether focus points have been found or not
function FocusInfo.FocusPointsStatus(focusPointsDeteced)
  local f = LrView.osFactory()
  if focusPointsDeteced then
    return f:row {f:static_text {title = "Focus points detected", text_color=LrColor(0, 100, 0), font="<system/bold>"}}
  else
    return f:row {f:static_text {title = "No focus points detected", text_color=LrColor("red"), font="<system/bold>"}}
  end
end

--[[ #TODO
  -- helper function to simplify adding items row-by-row
--]]
function FocusInfo.addInfo(title, key, photo, props)
  local f = LrView.osFactory()

  local function populateInfo(key, props)
    local result = photo:getFormattedMetadata(key)
    if (result ~= nil) then
      props[key] = result
    else
      props[key] = FocusInfo.metaValueNA
    end
  end

  -- populate property with designated value
  populateInfo(key, props)

  -- compose the row to be added
  local result = f:row {
                   f:column{f:static_text{title = title .. ":", font="<system>"}},
                   f:spacer{fill_horizontal = 1},
                   f:column{f:static_text{title = props[key], font="<system>"}}}

  -- decide if and how to add it
  if (props[key] == FocusInfo.metaValueNA) then
    -- we won't display any "N/A" entries - return "blank"
    return f:control_spacing{}     -- creates an "empty row" that is really empty - f:row{} is not
  else
    -- add row as composed
    return result
  end
end

--[[ #TODO
--]]
function FocusInfo.createInfoView(photo, props)
  local f = LrView.osFactory()

  local imageInfo, cameraInfo, focusInfo = FocusInfo.getMakerInfo(photo, props)

  local defaultInfo = f:column{
    f:spacer { height = 20, fill_horizontal = 1 },
--    f:spacer{fill_horizontal = 1},
    f:group_box { title = "Image information:  ", fill = 1, font="<system/bold>",
        f:column {
            fill = 1,
            spacing = 2,
            FocusInfo.addInfo("Filename",          FocusInfo.metaKeyFileName,          photo, props),
            FocusInfo.addInfo("Captured on",       FocusInfo.metaKeyDateTimeOriginal,  photo, props),
            FocusInfo.addInfo("Original size",     FocusInfo.metaKeyDimensions,        photo, props),
            FocusInfo.addInfo("Current size",      FocusInfo.metaKeyCroppedDimensions, photo, props),
            imageInfo
        },
      },
    f:spacer { height = 20, fill_horizontal = 1 },
    f:group_box { title = "Camera settings:  ", fill = 1, font = "<system/bold>",
        f:column {
            fill = 1,
            spacing = 2,
            FocusInfo.addInfo("Camera",            FocusInfo.metaKeyCameraModel,       photo, props),
            FocusInfo.addInfo("Lens",              FocusInfo.metaKeyLens,              photo, props),
            FocusInfo.addInfo("FocalLength",       FocusInfo.metaKeyFocalLength,       photo, props),
            FocusInfo.addInfo("Exposure",          FocusInfo.metaKeyExposure,          photo, props),
            FocusInfo.addInfo("ISO",               FocusInfo.metaKeyIsoSpeedRating,    photo, props),
            FocusInfo.addInfo("Exposure Bias",     FocusInfo.metaKeyExposureBias,      photo, props),
            FocusInfo.addInfo("Exposure Program",  FocusInfo.metaKeyExposureProgram,   photo, props),
            FocusInfo.addInfo("Metering Mode",     FocusInfo.metaKeyMeteringMode,      photo, props),
            cameraInfo
        },
    },
    f:spacer { height = 20, fill_horizontal = 1 },
    f:group_box { title = "Focus information:  ", fill = 1,  font="<system/bold>",
        focusInfo
    },
  }
  return defaultInfo
end
