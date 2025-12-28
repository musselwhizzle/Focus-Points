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

--[[----------------------------------------------------------------------------
  FocusInfo.lua

  Purpose of this module:
  - Build the view structure that contains textual information about the photo
  - Provide helper functions to the delegates modules to create maker specific
    views structures (maker specific Image/Shooting Info extensions, Focus Info)
------------------------------------------------------------------------------]]
local FocusInfo = {}

-- Imported LR namespaces
local LrColor              = import  'LrColor'
local LrHttp               = import  'LrHttp'
local LrPrefs              = import  'LrPrefs'
local LrTasks              = import  'LrTasks'
local LrView               = import  'LrView'

-- Required Lua definitions
local ExifUtils            = require 'ExifUtils'
local FocusPointPrefs      = require 'FocusPointPrefs'
local Log                  = require 'Log'
local _strict              = require 'strict'
local Utf8                 = require 'Utf8'
local Utils                = require 'Utils'

-- Public variables ------------------------------------------------------------

FocusInfo.missingMetadata           = false
FocusInfo.cameraMakerSupported      = false
FocusInfo.cameraModelSupported      = false
FocusInfo.makerNotesFound           = false
FocusInfo.manualFocusUsed           = false
FocusInfo.focusPointsDetected       = false
FocusInfo.severeErrorEncountered    = false

FocusInfo.msgImageFileNotOoc        = "Image file not created in-camera"

FocusInfo.cropMode                  = false

FocusInfo.maxValueLen               = LrPrefs.prefsForPlugin(nil).truncateLimit

-- Local variables -------------------------------------------------------------

-- Data structure to handle display of the focus point display status
local statusFocusPointsDetected     =   1
local statusNoFocusPointsRecorded   =   2
local statusManualFocusUsed         =   3
local statusMakerNotesNotFound      =   4
local statusModelNotSupported       =   5
local statusMakerNotSupported       =   6
local statusMissingMetadata         =   7
local statusSevereErrorEncountered  =   8
local statusUndefined               = 255
local status = {
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
    {  message = "No camera-specific metadata found",
       color   = LrColor("red"),
       tooltip = "The photo lacks camera-specific metadata.",
       link    = "#No-camera-specific-metadata-found" },
    {  message = "Severe error encountered",
       color   = LrColor("red"),
       tooltip = "Something unexpected happened. Check log file." ,
       link    = "#Severe-error-encountered" },
}

-- Keywords for retrieving generic items from Lightroom-stored metadata
local metaKeyFileName               = "fileName"
local metaKeyDimensions             = "dimensions"
local metaKeyCroppedDimensions      = "croppedDimensions"
local metaKeyDateTimeOriginal       = "dateTimeOriginal"
local metaKeyCameraMake             = "cameraMake"
local metaKeyCameraModel            = "cameraModel"
local metaKeyLens                   = "lens"
local metaKeyFocalLength            = "focalLength"
local metaKeyFocalLength35mm        = "focalLength35mm"
local metaKeyExposure               = "exposure"
local metaKeyIsoSpeedRating         = "isoSpeedRating"
local metaKeyExposureBias           = "exposureBias"
local metaKeyExposureProgram        = "exposureProgram"
local metaKeyMeteringMode           = "meteringMode"

-- @TODO Bring together all the special symbols used by the plugin in one central place!
local utfLinkSymbol = string.char(0xF0, 0x9F, 0x94, 0x97)
local utfEllipsis   = string.char(0xE2, 0x80, 0xA6)

--[[----------------------------------------------------------------------------
  public void
  initialize()

  Reset variables that control certain aspects of the info section generation
------------------------------------------------------------------------------]]
function FocusInfo.initialize()
  FocusInfo.focusPointsDetected    = false
  FocusInfo.severeErrorEncountered = false
  FocusInfo.cropMode               = false
end

--[[----------------------------------------------------------------------------
  private table imageInfo, table shootingInfo, table focusInfo
  getMakerInfo(table photo, table props)

  For each of the three Info view sections collect maker specific information:
  - Specific information on 'Image' and 'Shooting' information will be appended
    to the generic information created in this module
  - 'Focus' information which is maker specific per se

  Returns one view container for each section.
------------------------------------------------------------------------------]]
local function getMakerInfo(photo, props, metadata, funcGetMakerInfo)
  local makerInfo
  if funcGetMakerInfo ~= nil then
    makerInfo = funcGetMakerInfo(photo, props, metadata)
  else
    makerInfo = FocusInfo.emptyRow()
  end
  return makerInfo
end

--[[----------------------------------------------------------------------------
  public table
  emptyRow()

  Returns an "empty row" that is really empty - f:row{} is not
------------------------------------------------------------------------------]]
function FocusInfo.emptyRow()
  local f = LrView.osFactory()
  return f:control_spacing{}
end

--[[----------------------------------------------------------------------------
  public table
  addSpace()

  Returns a spacer to provide extra separation between two rows
------------------------------------------------------------------------------]]
function FocusInfo.addSpace()
  local f = LrView.osFactory()
  return f:spacer{height = 2}
end

--[[----------------------------------------------------------------------------
  public table
  addSeparator()

  Returns a separator line between the current entry and the next one
------------------------------------------------------------------------------]]
function FocusInfo.addSeparator()
  local f = LrView.osFactory()
  return f:separator{ fill_horizontal = 1 }
end

--[[----------------------------------------------------------------------------
  public table row
  addRow(key, value)

  Creates a view container for another row to be added to the current section
------------------------------------------------------------------------------]]
function FocusInfo.addRow(key, value)

  -- Truncate value string if it is too long and provide the full text in a tooltip
  local prefs = LrPrefs.prefsForPlugin( nil )
  local tooltip
  if prefs.truncateLongText and Utf8.len(value) > FocusInfo.maxValueLen then
    if string.find(value, "\n") then
      -- do not truncate text that has already been wrapped across multiple lines.
    else
      tooltip = value
      value   = string.sub(value, 1, FocusInfo.maxValueLen-1) .. utfEllipsis
    end
  end

  -- Construct and return the row container
  local f = LrView.osFactory()
  return f:row {
    f:column {
      f:static_text{
        title = key .. ":",
        font="<system>",
        alignment="left",
        mouse_down = function() return true end,
        mouse_up   = function() return true end,
      }
    },
    f:spacer{ fill_horizontal = 1 },
    f:column{
      f:static_text{
        title = value,
        tooltip = tooltip,
        font="<system>",
        alignment="right",
        mouse_down = function() return true end,
        mouse_up   = function() return true end,
      },
    },
  }
end

--[[----------------------------------------------------------------------------
  public int
  getStatusCode()

  Returns the result of the focus points visualization process as a numeric status code.
------------------------------------------------------------------------------]]
local function getStatusCode()
  local statusCode
  if         FocusInfo.severeErrorEncountered then statusCode = statusSevereErrorEncountered
  elseif     FocusInfo.missingMetadata        then statusCode = statusMissingMetadata
  elseif not FocusInfo.cameraMakerSupported   then statusCode = statusMakerNotSupported
  elseif not FocusInfo.cameraModelSupported   then statusCode = statusModelNotSupported
  elseif not FocusInfo.makerNotesFound        then statusCode = statusMakerNotesNotFound
  elseif     FocusInfo.focusPointsDetected    then statusCode = statusFocusPointsDetected
  elseif     FocusInfo.manualFocusUsed        then statusCode = statusManualFocusUsed
  else                                             statusCode = statusNoFocusPointsRecorded
  end
  return statusCode
end

--[[----------------------------------------------------------------------------
  public void
  openTroubleShooting(int statusCode)

  Opens 'Troubleshooting' section of the user manual in case statusCode
  represents an error or a warning.
------------------------------------------------------------------------------]]
function FocusInfo.openTroubleShooting(statusCode)
  if not statusCode then
    statusCode = getStatusCode()
  end
  if statusCode > statusFocusPointsDetected then
    LrTasks.startAsyncTask(function()
      LrHttp.openUrlInBrowser(FocusPointPrefs.urlTroubleShooting .. status[statusCode].link)
    end)
  end
end

--[[----------------------------------------------------------------------------
  private table
  statusMessage(int statusCode)

  Returns a view element containing a message stating whether or not focus points
  have been found, and whether or not errors have occurred.
  Error messages will be red, warnings will be orange and success messages will be green.
  If errors or warnings occur, the message text will include a clickable link
  to the relevant section in the troubleshooting part of the user manual.
------------------------------------------------------------------------------]]
local function statusMessage(statusCode)
  local f = LrView.osFactory()

  if status[statusCode].link == "" then
    -- simple message, no link
    return f:row {
      f:static_text {
        title      = status[statusCode].message,
        text_color = status[statusCode].color,
        tooltip    = status[statusCode].tooltip,
        mouse_down = function() return true end,
        mouse_up   = function() return true end,
      }
    }
  else
    return f:row {
      f:static_text {
        title      = status[statusCode].message,
        text_color = status[statusCode].color,
        tooltip    = status[statusCode].tooltip
                     .. "\nClick " .. utfLinkSymbol .. " to open troubleshooting information or press '?'",
        mouse_down = function() return true end,
        mouse_up   = function() return true end,
      },
      f:static_text {
        title = utfLinkSymbol,
        text_color = LrColor(0, 0.25, 1),
        tooltip = "Open troubleshooting information (?)",
        immediate = true,
        mouse_down = function(_view)
          FocusInfo.openTroubleShooting(statusCode)
        end,
      },
    }
  end
end

--[[----------------------------------------------------------------------------
  private table
  pluginStatus()

  Returns a view container with specific information if
  - errors or warnings have been encountered
  - a log file has been created using a user-defined level other than 'AUTO' or 'NONE'
  - an update of the plugin is available
------------------------------------------------------------------------------]]
local function pluginStatus()
  local f = LrView.osFactory()
  local prefs = LrPrefs.prefsForPlugin( nil )

  -- Compose update available message, if applicable
  local updateMessage
  if prefs.checkForUpdates and FocusPointPrefs.isUpdateAvailable() then
    updateMessage =
      f:row {
        f:static_text {
          title = "Update available " .. utfLinkSymbol,
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
    statusMsg = f:static_text {
                  title = "Errors encountered", text_color=LrColor("red"), font="<system>",
                  mouse_down = function() return true end, mouse_up = function() return true end }
  elseif Log.warningsEncountered then
    statusMsg = f:static_text {
                  title = "Warnings encountered", text_color=LrColor("orange"), font="<system>",
                  mouse_down = function() return true end, mouse_up = function() return true end }
  else
    if (prefs.loggingLevel ~= "AUTO") and (prefs.loggingLevel ~= "NONE") and Log.fileExists() then
      -- if user wants an extended log this should be easily accessible
      statusMsg = f:static_text {
                    title = "Logging information collected", font="<system>",
                    mouse_down = function() return true end, mouse_up = function() return true end }
    else
      if prefs.checkForUpdates and FocusPointPrefs.isUpdateAvailable() then
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
                f:static_text {title = 'Turn on logging "Auto" for more details', font="<system>",
                               mouse_down = function() return true end, mouse_up = function() return true end }
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
                  tooltip = "Click to open log file (L)",
                  font = "<system>",
                  action = function() Utils.openFileInApp(Log.getLogFileName()) end,
                },
              },
              updateMessage,
          },
      }
  end
end

--[[----------------------------------------------------------------------------
  private table row
  addInfo(string title, string key, table props, table metadata)

  Generate row element to be added to the current view container:
  - Create an entry for 'key' in the property table bound to the dialog view container
  - Compose row, with "[Title]:" on the left, following "props[key]" right aligned
------------------------------------------------------------------------------]]
local function addInfo(title, key, photo, props)

  -- Helper function to create the
  local function populateInfo(key, props)
    local result = photo:getFormattedMetadata(key)
    if (result ~= nil) then
      props[key] = result
    else
      props[key] = ExifUtils.metaValueNA
    end
  end

  -- Populate property with designated value
  populateInfo(key, props)

  -- Check if there is (meaningful) content to add
  if not props[key] or props[key] == ExifUtils.metaValueNA then
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end

  if (key == metaKeyFocalLength35mm) and not FocusInfo.cropMode then
    -- we will only display this entry for FF bodies used in DX or APS-C mode
    return FocusInfo.emptyRow()
  end

  -- Return the row to be added
  return FocusInfo.addRow(title, props[key])
end

--[[----------------------------------------------------------------------------
  public table
  createInfoView(photo, props)

  Creates the content of information column view container
------------------------------------------------------------------------------]]
function FocusInfo.createInfoView(photo, props, metadata, funcGetImageInfo, funcGetShootingInfo, funcGetFocusInfo)
  local f = LrView.osFactory()

  local makerImageInfo    = getMakerInfo(photo, props, metadata, funcGetImageInfo)
  local makerShootingInfo = getMakerInfo(photo, props, metadata, funcGetShootingInfo)
  local makerFocusInfo    = getMakerInfo(photo, props, metadata, funcGetFocusInfo)

  -- For manually focused images there will be only a summary message
  local statusCode = getStatusCode()
  if statusCode >= statusManualFocusUsed then
    makerFocusInfo = f:column {
      fill = 1,
      spacing = 2,
      statusMessage(statusCode),
    }
  else
    makerFocusInfo = f:column {
      fill = 1,
      spacing = 2,
      statusMessage(statusCode),
      makerFocusInfo,
    }
  end

  local infoView = f:column{ fill_vertical = 1,

      f:column { fill = 1, spacing = 2,
          f:group_box { title = "Image Information", fill = 1, font = "<system/bold>",
              f:column {fill = 1, spacing = 2,
                  addInfo("Filename"               , metaKeyFileName           , photo, props),
                  addInfo("Capture Date/Time"      , metaKeyDateTimeOriginal   , photo, props),
                  addInfo("Original Size"          , metaKeyDimensions         , photo, props),
                  addInfo("Current Size"           , metaKeyCroppedDimensions  , photo, props),
                  makerImageInfo
              },
          },
          f:spacer { height = 20 },
          f:group_box { title = "Shooting Information", fill = 1, font = "<system/bold>",
              f:column {fill = 1, fill_vertical = 0, spacing = 2,
                  addInfo("Make"                   , metaKeyCameraMake         , photo, props),
                  addInfo("Model"                  , metaKeyCameraModel        , photo, props),
                  addInfo("Lens"                   , metaKeyLens               , photo, props),
                  addInfo("Focal Length"           , metaKeyFocalLength        , photo, props),
                  addInfo("FL Equivalent Crop Mode", metaKeyFocalLength35mm    , photo, props),
                  addInfo("Exposure"               , metaKeyExposure           , photo, props),
                  addInfo("ISO"                    , metaKeyIsoSpeedRating     , photo, props),
                  addInfo("Exposure Bias"          , metaKeyExposureBias       , photo, props),
                  addInfo("Exposure Program"       , metaKeyExposureProgram    , photo, props),
                  addInfo("Metering Mode"          , metaKeyMeteringMode       , photo, props),
                  makerShootingInfo
             },
          },
          f:spacer { height = 20 },
          f:group_box { title = "Focus Information", fill = 1, font = "<system/bold>",
              makerFocusInfo
          },
      },
      f:spacer { height = 20 },
      f:spacer { fill_vertical = 100 },
      pluginStatus(),
  }
  return infoView
end

return FocusInfo -- ok
