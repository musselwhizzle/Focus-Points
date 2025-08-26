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

local LrView  = import "LrView"
local LrColor = import "LrColor"
local LrPrefs = import "LrPrefs"
local LrHttp  = import "LrHttp"
local LrTasks = import "LrTasks"

require "DefaultPointRenderer"
require "Log"


FocusInfo = {}

FocusInfo.cameraMakerSupported      = false
FocusInfo.cameraModelSupported      = false
FocusInfo.makerNotesFound           = false
FocusInfo.manualFocusUsed           = false
FocusInfo.focusPointsDetected       = false
FocusInfo.severeErrorEncountered    = false

FocusInfo.metaKeyFileName           = "fileName"
FocusInfo.metaKeyDimensions         = "dimensions"
FocusInfo.metaKeyCroppedDimensions  = "croppedDimensions"
FocusInfo.metaKeyDateTimeOriginal   = "dateTimeOriginal"
FocusInfo.metaKeyCameraMake         = "cameraMake"
FocusInfo.metaKeyCameraModel        = "cameraModel"
FocusInfo.metaKeyLens               = "lens"
FocusInfo.metaKeyFocalLength        = "focalLength"
FocusInfo.metaKeyFocalLength35mm    = "focalLength35mm"
FocusInfo.metaKeyExposure           = "exposure"
FocusInfo.metaKeyIsoSpeedRating     = "isoSpeedRating"
FocusInfo.metaKeyExposureBias       = "exposureBias"
FocusInfo.metaKeyExposureProgram    = "exposureProgram"
FocusInfo.metaKeyMeteringMode       = "meteringMode"
FocusInfo.metaValueNA               = "N/A"

FocusInfo.msgImageFileNotOoc        = "Image file was not created in-camera but modified by an application"

FocusInfo.statusFocusPointsDetected    = 1
FocusInfo.statusNoFocusPointsRecorded  = 2
FocusInfo.statusManualFocusUsed        = 3
FocusInfo.statusMakerNotesNotFound     = 4
FocusInfo.statusModelNotSupported      = 5
FocusInfo.statusMakerNotSupported      = 6
FocusInfo.statusSevereErrorEncountered = 7
FocusInfo.statusUndefined              = 255

FocusInfo.status = {
    {  message = "Focus points detected",
       color   = LrColor(0, 0.66, 0),
       tooltip = "Metadata information about focus points is found and visualized." ,
       link    = "" },
    {  message = "No focus points recorded",
       color   = LrColor("orange"),
       tooltip = "Camera has not recorded information on points in focus." ,
       link    = "#No-focus-points-recorded" },
    {  message = "Manual focus, no AF points recorded",
       color   = LrColor("orange"),
       tooltip = "The photo was taken with manual focus (MF), so there is no autofocus (AF) information in the metadata.",
       link    = "#Manual-focus-no-AF-points-recorded" },
    {  message = "Focus info missing from file",
       tooltip = "The photo lacks the metadata needed to process and visualize focus information." ,
       color   = LrColor("red"),
       link    = "#Focus-info-missing-from-file" },
    {  message = "Camera model not supported",
       color   = LrColor("red"),
       tooltip = "The photo was taken by a camera that the plugin cannot handle." ,
       link    = "#Camera-model-not-supported" },
    {  message = "Camera maker not supported",
       color   = LrColor("red"),
       tooltip = "The photo was taken with a camera from a manufacturer that the plugin cannot handle.",
       link    = "#Camera-maker-not-supported" },
    {  message = "Severe error encountered",
       color   = LrColor("red"),
       tooltip = "Something unexpected happened. Check log file." ,
       link    = "#Severe-error-encountered" },
}


local prefs = LrPrefs.prefsForPlugin( nil )

local linkSymbol = string.char(0xF0, 0x9F, 0x94, 0x97)

--[[
  @@public table, table, table FocusInfo.getMakerInfo(table photo, table props)
   ----
   For each of the three view sections (image, settings, focus) collect maker specific information:
   - specific information on image and camera settings will be appended to generic information
   - focus information will be completely filled as there is no generic focus information
   Result:  imageInfo, cameraInfo, focusInfo
--]]
function FocusInfo.getMakerInfo(photo, props)

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
    focusInfo = FocusInfo.emptyRow()
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
  @@ public int FocusInfo.getStatusCode()
  ----
  Determines the "result' of the focus points visualization process
  Returns a numeric status code
--]]
function FocusInfo.getStatusCode()
  local statusCode
  if         FocusInfo.severeErrorEncountered then statusCode = FocusInfo.statusSevereErrorEncountered
  elseif not FocusInfo.cameraMakerSupported   then statusCode = FocusInfo.statusMakerNotSupported
  elseif not FocusInfo.cameraModelSupported   then statusCode = FocusInfo.statusModelNotSupported
  elseif not FocusInfo.makerNotesFound        then statusCode = FocusInfo.statusMakerNotesNotFound
  elseif     FocusInfo.focusPointsDetected    then statusCode = FocusInfo.statusFocusPointsDetected
  elseif     FocusInfo.manualFocusUsed        then statusCode = FocusInfo.statusManualFocusUsed
  else                                             statusCode = FocusInfo.statusNoFocusPointsRecorded
  end
  return statusCode
end


--[[
  @@ public table FocusInfo.statusMessage(int statusCode)
  -- Returns a view element with a message stating whether focus points have been found or not or if errors have occured
  -- error messages will be in red color, warnings in orange color, sucess message in green
  -- in case of errors or warnings the message text will include a clickable link
  -- to open the corresponding section in the troubleshooting section of the user manual
--]]
function FocusInfo.statusMessage(statusCode)
  local f = LrView.osFactory()

  if FocusInfo.status[statusCode].link == "" then
    -- simple message, no link
    return f:row {
      f:static_text {
        title      = FocusInfo.status[statusCode].message,
        text_color = FocusInfo.status[statusCode].color,
        tooltip    = FocusInfo.status[statusCode].tooltip,
      }
    }
  else
    return f:row {
      f:static_text {
        title      = FocusInfo.status[statusCode].message,
        text_color = FocusInfo.status[statusCode].color,
        tooltip    = FocusInfo.status[statusCode].tooltip
                     .. "\nClick " .. linkSymbol .. " to open troubleshooting information",
      },
      f:static_text {
        title = linkSymbol,
        text_color = LrColor(0, 0.25, 1),
        tooltip = "Open troubleshooting information",
        immediate = true,
        mouse_down = function(_view)
          LrTasks.startAsyncTask(function()
            LrHttp.openUrlInBrowser(FocusPointPrefs.urlTroubleShooting .. FocusInfo.status[statusCode].link)
          end)
        end,
      },
    }
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

  -- Compose update available message, if applicable
  local updateMessage
  if prefs.checkForUpdates and FocusPointPrefs.updateAvailable() then
    updateMessage =
      f:row {
        f:static_text {
          title = "Update available " .. string.char(0xF0, 0x9F, 0x94, 0x97),
          text_color=LrColor("blue"), font="<system>",
          tooltip = "Click to open update release notes",
          immediate = true,
          mouse_down = function(_view)
            LrTasks.startAsyncTask(function()
              LrHttp.openUrlInBrowser( FocusPointPrefs.latestReleaseURL )
            end)
          end,
        },
        f:spacer{fill_horizontal = 1},
        f:push_button {
          title = "Open URL",
          font = "<system>",
          action = function() LrHttp.openUrlInBrowser( FocusPointPrefs.latestReleaseURL ) end,
        },
      }
    else
      updateMessage = FocusInfo.emptyRow()
  end

  -- Compose status message
  local statusMsg
  if Log.errorsEncountered then
    statusMsg = f:static_text {title = "Errors encountered", text_color=LrColor("red"), font="<system>"}
  elseif Log.warningsEncountered then
    statusMsg = f:static_text {title = "Warnings encountered", text_color=LrColor("orange"), font="<system>"}
  else
    if (prefs.loggingLevel ~= "AUTO") and (prefs.loggingLevel ~= "NONE") and Log.fileExists() then
      -- if user wants an extended log this should be easily accessible
      statusMsg = f:static_text {title = "Logging information collected", font="<system>"}
    else
      if prefs.checkForUpdates and FocusPointPrefs.updateAvailable() then
        return
          f:column { fill = 1, spacing = 2,
              f:group_box {title = "Plug-in status:  ", fill = 1, font = "<system/bold>",
                 updateMessage,
              },
          }
      else
        return FocusInfo.emptyRow()
      end
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
             updateMessage,
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
              updateMessage,
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

  -- Check if there is (meaningful) content to add
  if not props[key] or props[key] == OlympusDelegates.metaValueNA then
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end

  -- return the row to be added
  return f:row {
      f:column { f:static_text { title = title .. ":", font = "<system>" } },
      f:spacer { fill_horizontal = 1 },
      f:column { f:static_text { title = props[key], font = "<system>" } }
  }
end

--[[
  @@ public table FocusInfo.createInfoView(photo, props)
  ----
  Creates the content of information column view container
--]]
function FocusInfo.createInfoView(photo, props)
  local f = LrView.osFactory()

  local imageInfo, cameraInfo, focusInfo = FocusInfo.getMakerInfo(photo, props)

  -- for manually focused images there will be only a summary message
  local statusCode = FocusInfo.getStatusCode()
  if statusCode >= FocusInfo.statusManualFocusUsed then
    focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.statusMessage(statusCode),
    }
  else
    focusInfo = f:column {
      fill = 1,
      spacing = 2,
      FocusInfo.statusMessage(statusCode),
      focusInfo,
    }
  end

  local infoView = f:column{ fill_vertical = 1,

      f:column { fill = 1, spacing = 2,
          f:group_box { title = "Image Information", fill = 1, font = "<system/bold>",
              f:column {fill = 1, spacing = 2,
                  FocusInfo.addInfo("Filename"         , FocusInfo.metaKeyFileName, photo, props),
                  FocusInfo.addInfo("Capture Date/Time", FocusInfo.metaKeyDateTimeOriginal, photo, props),
                  FocusInfo.addInfo("Original Size"    , FocusInfo.metaKeyDimensions, photo, props),
                  FocusInfo.addInfo("Current Size"     , FocusInfo.metaKeyCroppedDimensions, photo, props),
                  imageInfo
              },
          },
          f:spacer { height = 20 },
          f:group_box { title = "Camera Settings", fill = 1, font = "<system/bold>",
              f:column {fill = 1, fill_vertical = 0, spacing = 2,
                  FocusInfo.addInfo("Make"             , FocusInfo.metaKeyCameraMake, photo, props),
                  FocusInfo.addInfo("Model"            , FocusInfo.metaKeyCameraModel, photo, props),
                  FocusInfo.addInfo("Lens"             , FocusInfo.metaKeyLens, photo, props),
                  FocusInfo.addInfo("Focal Length"     , FocusInfo.metaKeyFocalLength, photo, props),
--                FocusInfo.addInfo("Focal Length 35mm", FocusInfo.metaKeyFocalLength35mm, photo, props),
                  FocusInfo.addInfo("Exposure"         , FocusInfo.metaKeyExposure, photo, props),
                  FocusInfo.addInfo("ISO"              , FocusInfo.metaKeyIsoSpeedRating, photo, props),
                  FocusInfo.addInfo("Exposure Bias"    , FocusInfo.metaKeyExposureBias, photo, props),
                  FocusInfo.addInfo("Exposure Program" , FocusInfo.metaKeyExposureProgram, photo, props),
                  FocusInfo.addInfo("Metering Mode"    , FocusInfo.metaKeyMeteringMode, photo, props),
                  cameraInfo
             },
          },
          f:spacer { height = 20 },
          f:group_box { title = "Focus Information", fill = 1, font = "<system/bold>",
              focusInfo
          },
      },
      f:spacer { height = 20 },
      f:spacer { fill_vertical = 100 },
      FocusInfo.pluginStatus(),
  }
  return infoView
end
