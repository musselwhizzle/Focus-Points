--[[
  Copyright 2016 JWhizzbang Inc

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
local LrView      = import "LrView"
local LrPrefs     = import "LrPrefs"
local LrShell     = import "LrShell"
local LrTasks     = import "LrTasks"
local LrColor     = import "LrColor"
local LrFileUtils = import "LrFileUtils"
local LrDialogs   = import "LrDialogs"
local LrHttp      = import "LrHttp"

local bind = LrView.bind

require "Log"

FocusPointPrefs = {}

FocusPointPrefs.displayScaleFactor = 0

-- Scaling values for size of 'pixel focus' box, relative to focus point window size
FocusPointPrefs.focusBoxSize = { 0, 0.04, 0.1 }

-- Indices to access scaling values in focusBoxSize table
FocusPointPrefs.focusBoxSizeSmall  = 1
FocusPointPrefs.focusBoxSizeMedium = 2
FocusPointPrefs.focusBoxSizeLarge  = 3
FocusPointPrefs.initfocusBoxSize   = FocusPointPrefs.focusBoxSizeMedium

FocusPointPrefs.latestReleaseURL   = "https://github.com/musselwhizzle/Focus-Points/releases/latest"
FocusPointPrefs.latestVersionFile  = "https://raw.githubusercontent.com/musselwhizzle/Focus-Points/master/focuspoints.lrplugin/Version.txt"

--[[
  @@public void FocusPointPrefs.InitializePrefs()
  ----
  Initialize preferences at first run after installation of plugin
--]]
function FocusPointPrefs.InitializePrefs(prefs)
  if not prefs.screenScaling      then	prefs.screenScaling   = 0 end
  if not prefs.focusBoxSize       then	prefs.focusBoxSize    = FocusPointPrefs.focusBoxSize[FocusPointPrefs.initfocusBoxSize] end
  if not prefs.focusBoxColor      then	prefs.focusBoxColor   = "red"    end
  if not prefs.loggingLevel       then	prefs.loggingLevel    = "AUTO"   end
  if not prefs.tagLang            then	prefs.tagLang         = "" end
  if not prefs.tagFormat          then	prefs.tagFormat       = "" end
  if not prefs.tagGroups          then	prefs.tagGroups       = "" end
  if prefs.checkForUpdates == nil then	prefs.checkForUpdates = true     end   -- here we need a nil pointer check!!
  -- get the latest plugin version for update checks
  FocusPointPrefs.getLatestVersion()
end


--[[ #TODO Documentation!
--]]
function FocusPointPrefs.setDisplayScaleFactor()
  local prefs = LrPrefs.prefsForPlugin( nil )
  if WIN_ENV then
    if prefs.screenScaling ~= 0 then
      FocusPointPrefs.displayScaleFactor = prefs.screenScaling
    else
      FocusPointPrefs.displayScaleFactor = getWinScalingFactor()
    end
  else
    -- just to be safe, normally, this branch should never be executed
    FocusPointPrefs.displayScaleFactor = 1.0
  end
end


--[[ #TODO Documentation!
--]]
function FocusPointPrefs.getDisplayScaleFactor()
  if FocusPointPrefs.displayScaleFactor == 0 then
    FocusPointPrefs.setDisplayScaleFactor()
  end
  return FocusPointPrefs.displayScaleFactor
end


--[[ #TODO Documentation!
--]]
function FocusPointPrefs.getTagOptions()
  local prefs = LrPrefs.prefsForPlugin( nil )
  return prefs.tagLang .. " " .. prefs.tagFormat .. " " .. prefs.tagGroups
end

--[[
  @@public void FocusPointPrefs.getLatestVersion()
  ----
  Retrieves the version number of the latest plug-in release. Result is stored in global
  variable 'prefs.latestVersion' for further use by the routines that deal with updates
--]]
function FocusPointPrefs.getLatestVersion()
  local prefs = LrPrefs.prefsForPlugin( nil )
  -- Need to execute this as a collaborative task
  LrTasks.startAsyncTask(function()
    local latestVersionNumber = LrHttp.get(FocusPointPrefs.latestVersionFile)
    if latestVersionNumber then
      prefs.latestVersion = string.match(latestVersionNumber, "v%d+%.%d+%.%d+")
    end
  end)
end


--[[
  @@public string FocusPointPrefs.latestVersion()
  ----
  Returns the version number of the latest plug-in release as a string eg. 'v3.5.12'
--]]
function FocusPointPrefs.latestVersion()
  local prefs = LrPrefs.prefsForPlugin( nil )
  if prefs.latestVersion then
    return prefs.latestVersion
  else
    return ""
  end
end


--[[
  @@public boolean FocusPointPrefs.updateAvailable()
  Checks whether an updated version of the plug-in is available
  Returns true if so, otherwise false
--]]
function FocusPointPrefs.updateAvailable()
  local prefs = LrPrefs.prefsForPlugin( nil )
  local Info = require 'Info.lua'
  local result

  if prefs.latestVersion then
    local major, minor, revision = prefs.latestVersion:match("v(%d+)%.(%d+)%.(%d+)")
    if major and minor and revision then
      -- we have a valid version number from the URL
      local pluginVersion = Info.VERSION
      if tonumber(major) > pluginVersion.major then
        result = true
      elseif tonumber(major) == pluginVersion.major then
        if  tonumber(minor) > pluginVersion.minor then
          result = true
        elseif tonumber(minor) == pluginVersion.minor then
          result = tonumber(revision) > pluginVersion.revision
        end
      end
    else
      Log.logWarn("Utils", "Update check failed, no valid combination of major, minor and revision number")
    end
  else
    Log.logWarn("Utils", "Update check failed, unable to retrieve version info from website")
  end
  return result
end


--[[
  @@public table FocusPointPrefs.genSectionsForBottomOfDialog( table viewFactory, p )
  -- Called by Lightroom's Plugin Manager when loading the plugin; creates the plugin page with preferences
--]]
function FocusPointPrefs.genSectionsForBottomOfDialog( viewFactory, p )
  local prefs = LrPrefs.prefsForPlugin( nil )

  -- Set the defaults
  FocusPointPrefs.InitializePrefs(prefs)

  -- Check for updates
  local updateMessage
  if FocusPointPrefs.updateAvailable() then
    updateMessage =
      viewFactory:row {
        viewFactory:static_text {title = "Update available!", text_color=LrColor("red")},
        viewFactory:spacer{fill_horizontal = 1},
        viewFactory:push_button {
          title = "Open URL",
          action = function() LrHttp.openUrlInBrowser( FocusPointPrefs.latestReleaseURL ) end,
        },
      }
  else
    updateMessage = viewFactory:static_text{ title = "" }
  end

  -- Width of the drop-down lists in px, to make the naming aligned across rows
  local dropDownWidth = LrView.share('-Medium-')

  local scalingSection = {}
  if WIN_ENV then
    scalingSection = {
      title = "Screen Scaling",
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "Scaling",
          value = bind ("screenScaling"),
          width = dropDownWidth,
          items = {
            { title = "Auto", value = 0    },
            { title = "100%", value = 1.0  },
            { title = "125%", value = 0.8  },
            { title = "150%", value = 0.67 },
            { title = "175%", value = 0.57 },
            { title = "200%", value = 0.5  },
            { title = "250%", value = 0.4  },
          }
        },
        viewFactory:static_text {
          title = 'Select "Auto" for same display scale factor as on Windows OS (Display Settings -> Scale)'
        }
      },
    }
  end

  return {
    scalingSection,
    {
      title = "Viewing Options",
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "focusBoxColor",
          value = bind ("focusBoxColor"),
          width = dropDownWidth,
          items = {
            { title = "Red",   value = "red" },
            { title = "Green", value = "green" },
            { title = "Blue",  value = "blue" },
          }
        },
        viewFactory:static_text {
          title = 'Color for in-focus points',
        },
      },
      viewFactory:row {
        bind_to_object = prefs,
        viewFactory:popup_menu {
          title = "focusBoxSize",
          value = bind ("focusBoxSize"),
          width = dropDownWidth,
          items = {
            { title = "Small",  value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeSmall ] },
            { title = "Medium", value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeMedium] },
            { title = "Large",  value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeLarge ] },
          }
        },
        viewFactory:static_text {
          title = "  Size of focus box for 'focus pixel' points ",
        },
      },
    },
    {
      title = "Metadata Tag Options",
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "tagLang",
          value = bind ("tagLang"),
          width = dropDownWidth,
          items = {
            { title = "English", value = "" },
            { title = "Czech", value = "-lang cs" },
            { title = "German", value = "-lang de" },
            { title = "Canadian English", value = "-lang en_ca" },
            { title = "British English", value = "-lang en_gb" },
            { title = "Spanish", value = "-lang es" },
            { title = "Finnish", value = "-lang fi" },
            { title = "French", value = "-lang fr" },
            { title = "Italian", value = "-lang it" },
            { title = "Japanese", value = "-lang ja" },
            { title = "Korean", value = "-lang ko" },
            { title = "Dutch", value = "-lang nl" },
            { title = "Polish", value = "-lang pl" },
            { title = "Russian", value = "-lang ru" },
            { title = "Slovak", value = "-lang sk" },
            { title = "Swedish", value = "-lang sv" },
            { title = "Turkish", value = "-lang tr" },
            { title = "Simplified Chinese", value = "-lang zh_cn" },
            { title = "Traditional Chinese", value = "-lang zh_tw" },
          }
        },
        viewFactory:static_text {
          title = 'Tag Language',
        },
      },
      viewFactory:row {
        bind_to_object = prefs,
        viewFactory:popup_menu {
          title = "tagFormat",
          value = bind ("tagFormat"),
          width = dropDownWidth,
          items = {
            { title = "Long",  value = "" },
            { title = "Short",  value = "-short" },
          }
        },
        viewFactory:static_text {
          title = " Tag Format",
        },
      },
      viewFactory:row {
        bind_to_object = prefs,
        viewFactory:popup_menu {
          title = "tagGroups",
          value = bind ("tagGroups"),
          width = dropDownWidth,
          items = {
            { title = "None",  value = "" },
            { title = "0 (Information Type)",  value = "-G0" },
            { title = "1 (Specific Location)",  value = "-G1" },
            { title = "2 (Category)",  value = "-G2" },
            { title = "3 (Document Number)",  value = "-G3" },
            { title = "4 (Instance Number)",  value = "-G4" },
            { title = "5 (Metadata Path)",  value = "-G5" },
            { title = "6 (EXIF/TIFF Format)",  value = "-G6" },
            { title = "7 (Tag ID)",  value = "-G7" },
          }
        },
        viewFactory:static_text {
          title = " Show tag groups",
        },
      },
    },
    {
      title = "Logging",
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "Logging level",
          value = bind ('loggingLevel'),
          width = dropDownWidth,
          items = {
            { title = "Full",  value = "FULL" },
            { title = "Debug", value = "DEBUG" },
            { title = "Auto",  value = "AUTO" },
            { title = "Info",  value = "INFO" },
            { title = "Warn",  value = "WARN" },
            { title = "Error", value = "ERROR" },
            { title = "None",  value = "NONE" },
          }
        },
        viewFactory:static_text {
          title = 'Level of information to be logged (Recommended: "Auto")'
        },
        viewFactory:static_text {
          title = 'Plugin log:',
          alignment = 'right',
          fill_horizontal = 1,
        },
        viewFactory:push_button {
          title = "Show file",
          action = function()
            local logFileName = Log.getFileName()
            if LrFileUtils.exists(logFileName)then
              LrShell.revealInShell(logFileName)
            else
              LrDialogs.message('No log file written. Set logging level other than "None".')
            end
          end,
        },
      },
    },
    {
      title = "Updates",
      bind_to_object = prefs,
      spacing = viewFactory:control_spacing(),
      viewFactory:row {
        viewFactory:checkbox {
          title = 'Display message when updates are available',
          value = bind('checkForUpdates')
        },
        viewFactory:spacer{fill_horizontal = 1},
        updateMessage,
      },
    },
    {
      title = "Acknowledgements",
      viewFactory:row {
        fill_horizontal = 1,
        viewFactory:column {
          fill_horizontal = 1,
          viewFactory:static_text {
            font = "<system/bold>",
            title = 'ImageMagick Studio LLC'
          },
          viewFactory:spacer{ height = 5 },
          viewFactory:static_text {
            title = 'This plugin uses ImageMagick mogrify'
          }
        },
        viewFactory:column {
          viewFactory:static_text {
            title = "https://imagemagick.org/index.php"
          },
        },
      },
      viewFactory:spacer{fill_horizontal = 1},
      viewFactory:row {
        fill_horizontal = 1,
        viewFactory:column {
          fill_horizontal = 1,
          viewFactory:static_text {
            font = "<system/bold>",
            title = 'ExifTool'
          },
          viewFactory:spacer{ height = 5 },
          viewFactory:static_text {
            title = "This plugin relies on Phil Harvey's ExifTool to read and decode metadata"
          }
        },
        viewFactory:column {
          viewFactory:static_text {
            title = "https://exiftool.org/"
          },
        },
      },
    }
  }
end
