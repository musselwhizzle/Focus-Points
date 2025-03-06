--[[
  Copyright Karsten Gieselmann (capricorn8)

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
local LrPrefs   = import "LrPrefs"

require "DefaultPointRenderer"
require "Log"


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

FocusInfo.msgImageNotOoc            = "Image file does not seem be straight out of camera."

local prefs = LrPrefs.prefsForPlugin( nil )


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
    imageInfo = FocusInfo.emptyRow()
  end

  -- get maker specific camera settings information, if any
  local cameraInfo
  if (DefaultPointRenderer.funcGetCameraInfo ~= nil) then
    cameraInfo = DefaultPointRenderer.funcGetCameraInfo(photo, props, DefaultDelegates.metaData)
  else
    cameraInfo = FocusInfo.emptyRow()
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
  @@public table FocusInfo.emptyRow()
  ----
  Creates an "empty row" that is really empty - f:row{} is not
--]]
function FocusInfo.emptyRow()
  local f = LrView.osFactory()
  return f:control_spacing{}
end


--[[
  @@public table FocusInfo.errorMessage(string errorMessage)
  ----
  Creates static text error message text to be added to the current section
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
  local result
  result = ExifUtils.findValue(metaData, afInfoSectionKey)
  if not result then
    return FocusInfo.errorMessage("Focus info missing from file")
  end
  return nil
end


--[[
  @@ public table FocusInfo.FocusPointsStatus(focusPointsDeteced)
  -- Returns a static text element with a message stating whether focus points have been found or not
--]]
function FocusInfo.FocusPointsStatus(focusPointsDeteced)
  local f = LrView.osFactory()
  if focusPointsDeteced then
    return f:row {f:static_text {title = "Focus points detected", text_color=LrColor(0, 0.66, 0), font="<system/bold>"}}
  elseif FocusPointDialog.errorsEncountered then
    return f:row {f:static_text {title = "Errors encountered", text_color=LrColor("red"), font="<system/bold>"}}
  else
    return f:row {f:static_text {title = "No focus points detected", text_color=LrColor("red"), font="<system/bold>"}}
  end
end


--[[
  @@ public table FocusInfo.pluginStatus()
  ----
  In case errors or warnings have been encountered, add a separate group element with a status message and a button
  to open the log file at the bottom of the information column
--]]
function FocusInfo.pluginStatus()
  local f = LrView.osFactory()

  -- Compose status message
  local statusMsg
  if Log.errorsEncountered then
    statusMsg = f:static_text {title = "Errors encountered", text_color=LrColor("red"), font="<system>"}
  elseif Log.warningsEncountered then
    statusMsg = f:static_text {title = "Warnings encountered", text_color=LrColor("orange"), font="<system>"}
  else
    if (prefs.loggingLevel ~= "AUTO") and (prefs.loggingLevel ~= "NONE") and Log.fileExists() then
      -- if user wants an extended log this should be easily accessible
      statusMsg = f:static_text {title = "Debug information collected", font="<system>"}
    else
      -- displaying a "success" status message during normal operation might be distracting ...
      return FocusInfo.emptyRow()
    end
  end

  if prefs.loggingLevel == "NONE" then
    return
      f:column { fill = 1, spacing = 2,
          f:group_box {title = "Plug-in status:  ", fill = 1, font = "<system/bold>",
              f:row {statusMsg},
              f:row{
                f:static_text {title = 'Turn on logging "Auto" for more details', font="<system>"}
              },
          },
      }
  else
    -- Return the 'status' group element with "check log" button
    return
      f:column { fill = 1, spacing = 2,
          f:group_box {title = "Plug-in status:  ", fill = 1, font = "<system/bold>",
              f:row {
                statusMsg,
                f:spacer{fill_horizontal = 1},
                f:push_button {
                  title = "Check log",
                  font = "<system>",
                  action = function() openFileInApp(Log.getFileName()) end,
                },
              },
          },
      }
  end
end

--[[
  @@ public table FocusInfo.addInfo(title, key, photo, props)
  ----
  Generate row element to be added to the current view container:
  - creates a property to store the value corresponding to "key"
  - compose row, with "[Title]:" on the left, following "props[key]" right aligned
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

    -- check if there is (meaningful) content to add
  if props[key] and props[key] ~= FocusInfo.metaValueNA then
    -- compose the row to be added
    local result = f:row {
      f:column{f:static_text{title = title .. ":", font="<system>"}},
      f:spacer{fill_horizontal = 1},
      f:column{f:static_text{title = props[key], font="<system>"}}
    }
    -- add row as composed
    return result
  else
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end
end


--[[
  @@ public table FocusInfo.createInfoView(photo, props)
  ----
  Creates the content of information column view container
--]]
function FocusInfo.createInfoView(photo, props)
  local f = LrView.osFactory()

  local imageInfo, cameraInfo, focusInfo = FocusInfo.getMakerInfo(photo, props)

  local defaultInfo =
  f:column{ fill_vertical = 1,
      f:column { fill = 1, spacing = 2,
          f:group_box { title = "Image information:  ", fill = 1, font = "<system/bold>",
              f:column {fill = 1, spacing = 2,
                  FocusInfo.addInfo("Filename", FocusInfo.metaKeyFileName, photo, props),
                  FocusInfo.addInfo("Captured on", FocusInfo.metaKeyDateTimeOriginal, photo, props),
                  FocusInfo.addInfo("Original size", FocusInfo.metaKeyDimensions, photo, props),
                  FocusInfo.addInfo("Current size", FocusInfo.metaKeyCroppedDimensions, photo, props),
                  imageInfo
              },
          },
          f:spacer { height = 20 },
          f:group_box { title = "Camera settings:  ", fill = 1, font = "<system/bold>",
              f:column {fill = 1, fill_vertical = 0, spacing = 2,
                  FocusInfo.addInfo("Camera", FocusInfo.metaKeyCameraModel, photo, props),
                  FocusInfo.addInfo("Lens", FocusInfo.metaKeyLens, photo, props),
                  FocusInfo.addInfo("FocalLength", FocusInfo.metaKeyFocalLength, photo, props),
                  FocusInfo.addInfo("Exposure", FocusInfo.metaKeyExposure, photo, props),
                  FocusInfo.addInfo("ISO", FocusInfo.metaKeyIsoSpeedRating, photo, props),
                  FocusInfo.addInfo("Exposure Bias", FocusInfo.metaKeyExposureBias, photo, props),
                  FocusInfo.addInfo("Exposure Program", FocusInfo.metaKeyExposureProgram, photo, props),
                  FocusInfo.addInfo("Metering Mode", FocusInfo.metaKeyMeteringMode, photo, props),
                  cameraInfo
             },
          },
          f:spacer { height = 20 },
          f:group_box { title = "Focus information:  ", fill = 1, font = "<system/bold>",
                       focusInfo
          },
      },
      f:spacer { height = 20 },
      f:spacer { fill_vertical = 100 },
      FocusInfo.pluginStatus(),
  }
  return defaultInfo
end
