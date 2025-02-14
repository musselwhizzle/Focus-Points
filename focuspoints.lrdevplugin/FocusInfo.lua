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
local LrErrors = import 'LrErrors'

require "DefaultPointRenderer"
a = require "affine"

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
   -- get maker specific information (if implemented)
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
    return f:row{}
  else
    -- add row as composed
    return result
  end
end

--[[
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
