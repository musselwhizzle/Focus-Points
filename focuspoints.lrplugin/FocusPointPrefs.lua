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

--[[----------------------------------------------------------------------------
  FocusPointPrefs.lua

  Purpose of this module:
  - Manages the plugin settings (storage, set, get)
  - Central place for important plugin definitions (e.g. keyboard shortcuts, URLs)
  - Provides the plugin settings dialog (called by LrPluginInfoProvider)
------------------------------------------------------------------------------]]
local FocusPointPrefs = {}

-- Imported LR namespaces
local LrApplication   = import  'LrApplication'
local LrColor         = import  'LrColor'
local LrDialogs       = import  'LrDialogs'
local LrFileUtils     = import  'LrFileUtils'
local LrHttp          = import  'LrHttp'
local LrPrefs         = import  'LrPrefs'
local LrShell         = import  'LrShell'
local LrTasks         = import  'LrTasks'
local LrView          = import  'LrView'

-- Required Lua definitions
local Info            = require 'Info'
local KeyboardLayout  = require 'KeyboardLayout'
local Log             = require 'Log'
local _strict         = require 'strict'
local Utils           = require 'Utils'

-- Important plugin definitions and settings -----------------------------------

-- Size options for plugin window
FocusPointPrefs.pluginWindowXXL    = 0.8
FocusPointPrefs.pluginWindowXL     = 0.7
FocusPointPrefs.pluginWindowL      = 0.6
FocusPointPrefs.pluginWindowM      = 0.5
FocusPointPrefs.pluginWindowS      = 0.4

-- Scaling values for size of 'pixel focus' box, relative to focus point window size
FocusPointPrefs.focusBoxSize = { 0, 0.04, 0.1 }

-- Indices to access scaling values in focusBoxSize table
FocusPointPrefs.focusBoxSizeSmall  = 1
FocusPointPrefs.focusBoxSizeMedium = 2
FocusPointPrefs.focusBoxSizeLarge  = 3
FocusPointPrefs.initfocusBoxSize   = FocusPointPrefs.focusBoxSizeMedium

-- Settings for keybopard shortcut input field
FocusPointPrefs.kbdInputInvisible  = 0
FocusPointPrefs.kbdInputSmall      = 1
FocusPointPrefs.kbdInputRegular    = 2

-- URL to handle Update mechanism
FocusPointPrefs.latestReleaseURL   = "https://github.com/musselwhizzle/Focus-Points/releases/latest"
FocusPointPrefs.latestVersionFile  = "https://raw.githubusercontent.com/musselwhizzle/Focus-Points/master/focuspoints.lrplugin/Version.txt"

-- URL definitions
FocusPointPrefs.urlUserManual      = "https://github.com/musselwhizzle/Focus-Points/blob/master/docs/Focus%20Points.md"
FocusPointPrefs.urlUserManual      = "https://github.com/musselwhizzle/Focus-Points/blob/v3.2_pre/docs/Focus%20Points.md"
FocusPointPrefs.urlTroubleShooting = "https://github.com/musselwhizzle/Focus-Points/blob/master/docs/Troubleshooting_FAQ.md"
FocusPointPrefs.urlTroubleShooting = "https://github.com/musselwhizzle/Focus-Points/blob/v3.2_pre/docs/Troubleshooting_FAQ.md"
FocusPointPrefs.urlkbdShortcuts    = "https://github.com/musselwhizzle/Focus-Points/blob/master/docs/Focus%20Points.md#keyboard-shortcuts"
FocusPointPrefs.urlkbdShortcuts    = "https://github.com/musselwhizzle/Focus-Points/blob/v3.2_pre/docs/Focus%20Points.md#keyboard-shortcuts"
FocusPointPrefs.urlTroubleShooting = "https://github.com/musselwhizzle/Focus-Points/blob/master/docs/Troubleshooting_FAQ.md"
FocusPointPrefs.urlTroubleShooting = "https://github.com/musselwhizzle/Focus-Points/blob/v3.2_pre/docs/Troubleshooting_FAQ.md"
FocusPointPrefs.urlKofi            = "https://ko-fi.com/focuspoints"

-- Keyboard shortcut definitions
FocusPointPrefs.kbdShortcutsPrev            = "-<"
FocusPointPrefs.kbdShortcutsNext            = " +"
FocusPointPrefs.kbdShortcutsPick            = "p"
FocusPointPrefs.kbdShortcutsUnflag          = "u"
FocusPointPrefs.kbdShortcutsReject          = "x"
FocusPointPrefs.kbdShortcutsPickNext        = "P"
FocusPointPrefs.kbdShortcutsUnflagNext      = "U"
FocusPointPrefs.kbdShortcutsRejectNext      = "X"
FocusPointPrefs.kbdShortcutsCheckLog        = "lL"
FocusPointPrefs.kbdShortcutsTroubleShooting = "?hH"
FocusPointPrefs.kbdShortcutsUserManual      = "mM"
FocusPointPrefs.kbdShortcutsClose           = "cC"

-- Local variables -------------------------------------------------------------

local isUpdateAvailable
local displayScaleFactor = 0.0
local LR5 = (LrApplication.versionTable().major == 5)
local bind = LrView.bind

--[[----------------------------------------------------------------------------
  public void
  InitializePrefs()

  Initialize preferences at first run after installation of plugin.
  Makes sure that newly introduced settings have a defined value (and are not nil).
------------------------------------------------------------------------------]]
function FocusPointPrefs.InitializePrefs(prefs)
  -- Set any undefined properties to their default values
  if not prefs.screenScaling           then	prefs.screenScaling       = 0 end
  if not prefs.pluginWindowScaling     then prefs.pluginWindowScaling = FocusPointPrefs.pluginWindowL end
  if     prefs.truncateLongText == nil then prefs.truncateLongText    = true     end
  if not prefs.truncateLimit           then prefs.truncateLimit       = 32       end
  if not prefs.focusBoxSize            then	prefs.focusBoxSize        = FocusPointPrefs.focusBoxSize[FocusPointPrefs.initfocusBoxSize] end
  if not prefs.focusBoxColor           then	prefs.focusBoxColor       = "red"    end
  if     prefs.taggingControls  == nil then prefs.taggingControls     = true     end
  if     prefs.keyboardLayout   == nil then prefs.keyboardLayout        = KeyboardLayout.autoDetectLayout end
  if not prefs.processMfInfo    == nil then prefs.processMfInfo       = false    end
  if not prefs.loggingLevel            then	prefs.loggingLevel        = "AUTO"   end
  if not prefs.latestVersion           then	prefs.latestVersion       = _PLUGIN.version end
  if     prefs.checkForUpdates  == nil then	prefs.checkForUpdates     = true     end   -- here we need a nil pointer check!!
  if     prefs.keyboardInput    == nil then prefs.keyboardInput       = FocusPointPrefs.kbdInputReguar
  end
  -- get the latest plugin version for update checks
  FocusPointPrefs.retrieveVersionOfLatestRelease()
end

--[[----------------------------------------------------------------------------
  public float
  getWinScalingFactor()

  Retrieves the Windows DPI scaling level registry key using the REG.EXE command:
  HKEY_CURRENT_USER\Control Panel\Desktop\WindowMetrics, AppliedDPI
  Returns the display scaling factor (100/scale_in_percent)
------------------------------------------------------------------------------]]
local function getWinScalingFactor()
  local output = Utils.getTempFileName()
  local cmd = "reg.exe query \"HKEY_CURRENT_USER\\Control Panel\\Desktop\\WindowMetrics\" -v AppliedDPI >\"" .. output .. "\""
  local result

  -- Query registry value by calling REG.EXE
  local rc = LrTasks.execute(cmd)
  Log.logDebug("Utils", "Retrieving DPI scaling level from Windosws registry using REG.EXE")
  Log.logDebug("Utils", "REG command: " .. cmd .. ", rc=" .. rc)

  -- Read redirected stdout from temp file and find the line that starts with "AppliedDPI"
  local regOutput = LrFileUtils.readFile(output)
  local regOutputStr = "^"
  local dpiValue, scale
  for line in string.gmatch(regOutput, ("[^\r\n]+")) do
    local item = Utils.split(line, " ")
    if item and #item >= 3 then
      if item[1] == "AppliedDPI" and item[2] == "REG_DWORD" then
        dpiValue = item[3]
        scale = math.floor(tonumber(dpiValue) * 100/96 + 0.5)
      end
    end
    regOutputStr = regOutputStr .. line .. "^"
  end
  Log.logDebug("Utils", "REG output: " .. regOutputStr)

  -- Set and log the result
  if dpiValue then
    result = 100 / scale
    Log.logDebug("Utils", string.format("DPI scaling level %s = %sdpi ~ %s%%", dpiValue, tonumber(dpiValue), scale))
  else
    result = 100 / 125
    Log.logWarn("Utils", "Unable to retrieve Windows scaling level, using 125% instead")
  end

  -- Clean up: remove the temp file
  if LrFileUtils.exists(output) and not LrFileUtils.delete(output) then
    Log.logWarn("Utils", "Unable to delete REG output file " .. output)
  end

  return result
end

--[[----------------------------------------------------------------------------
  public void
  setDisplayScaleFactor()

  Sets the displayScaleFactor to the value selected by the user in plugin settings.
  If the 'Auto' option is selected, the Windows system value is retrieved and used.
------------------------------------------------------------------------------]]
function FocusPointPrefs.setDisplayScaleFactor()
  local prefs = LrPrefs.prefsForPlugin( nil )
  if WIN_ENV then
    if prefs.screenScaling ~= 0 then
      displayScaleFactor = prefs.screenScaling
    else
      displayScaleFactor = getWinScalingFactor()
    end
  else
    -- just to be safe, normally, this branch should never be executed
    displayScaleFactor = 1.0
  end
end

--[[----------------------------------------------------------------------------
  public float
  getDisplayScaleFactor()

  Returns the current value of displayScaleFactor. In case of 'Auto' setting,
  the system scaling factor is returned.
------------------------------------------------------------------------------]]
function FocusPointPrefs.getDisplayScaleFactor()
  if displayScaleFactor == 0 then
    FocusPointPrefs.setDisplayScaleFactor()
  end
  return displayScaleFactor
end

--[[----------------------------------------------------------------------------
  public float
  getPluginWindowSize()

  Returns the sizing factor for supported plugin window sizes S..XXL
------------------------------------------------------------------------------]]
function FocusPointPrefs.getPluginWindowSize()
  local prefs = LrPrefs.prefsForPlugin( nil )
  return prefs.pluginWindowScaling
end

--[[----------------------------------------------------------------------------
  public string
  retrieveVersionOfLatestRelease()

  Retrieves the version number of the latest plug-in release. This information
  is stored in a text file 'Version.txt' in the Github plugin folder.
  The result is stored in 'prefs.latestVersion' for use by update-related routines.
------------------------------------------------------------------------------]]
function FocusPointPrefs.retrieveVersionOfLatestRelease()
  local prefs = LrPrefs.prefsForPlugin( nil )
  -- Need to execute this as a collaborative task
  LrTasks.startAsyncTask(function()
    local latestVersionNumber = LrHttp.get(FocusPointPrefs.latestVersionFile)
    if latestVersionNumber then
      prefs.latestVersion = string.match(latestVersionNumber, "v%d+%.%d+%.%d+")
    end
  end)
end

--[[----------------------------------------------------------------------------
  public string
  getlatestVersion()

  Returns the version number of the latest plug-in release as a string eg. 'v3.1.3'
------------------------------------------------------------------------------]]
function FocusPointPrefs.getlatestVersion()
  local prefs = LrPrefs.prefsForPlugin( nil )
  if prefs.latestVersion then
    return prefs.latestVersion
  else
    return ""
  end
end

--[[----------------------------------------------------------------------------
  public boolean
  isUpdateAvailable()

  Checks whether an updated version of the plug-in is available
  Returns true if so, otherwise false
------------------------------------------------------------------------------]]
function FocusPointPrefs.isUpdateAvailable()
  local prefs  = LrPrefs.prefsForPlugin( nil )
  local result = false

  if isUpdateAvailable == nil then
    -- information still empty, so determine its status
    if prefs.latestVersion then
      local major, minor, revision = prefs.latestVersion:match("v(%d+)%.(%d+)%.(%d+)")
      if major and minor and revision then
        -- we have a valid version number from the URL
        local pluginVersion = Info.VERSION
        if tonumber(major) > pluginVersion.major then
          -- new major version available
          result = true
        elseif tonumber(major) == pluginVersion.major then
          if  tonumber(minor) > pluginVersion.minor then
            -- new minor version available
            result = true
          elseif tonumber(minor) == pluginVersion.minor then
            if tonumber(revision) > pluginVersion.revision then
              -- new revision available
              result = true
            elseif tonumber(revision) == pluginVersion.revision then
              -- major, minor versions and revision numbers are the same
              if pluginVersion.build and tonumber(pluginVersion.build) >= 9000 then
                -- release available for local pre-release version
                result = true
              end
            end
          end
        end
      else
        Log.logWarn("Utils", "Update check failed, no valid combination of major, minor and revision number")
      end
    else
      Log.logWarn("Utils", "Update check failed, unable to retrieve version info from website")
    end
    isUpdateAvailable = result
  end
  return isUpdateAvailable
end

--[[----------------------------------------------------------------------------
  public table
  genSectionsForBottomOfDialog( table viewFactory, propertyTable )

  Called by Lightroom's Plugin Manager when the plugin is loaded.
  This creates the bottom section of the dialogue box on the plugin settings page.
  This section contains the plugin-specific settings that the user can modify.
------------------------------------------------------------------------------]]
function FocusPointPrefs.genSectionsForBottomOfDialog( f, _p )
  local prefs = LrPrefs.prefsForPlugin( nil )

  -- Set the defaults
  FocusPointPrefs.InitializePrefs(prefs)

  -- Check for updates
  local updateMessage
  if FocusPointPrefs.isUpdateAvailable() then
    updateMessage =
      f:row {
        f:static_text {title = "Update available!", text_color=LrColor("red")},
        f:spacer{fill_horizontal = 1},
        f:push_button {
          title = "Open URL",
          action = function() LrHttp.openUrlInBrowser( FocusPointPrefs.latestReleaseURL ) end,
        },
      }
  else
    updateMessage = f:static_text{ title = "" }
  end

  -- Width of the drop-down lists in px, to make the naming aligned across rows
  local dropDownWidth = 75

  local function sectionScreenScaling()
    if not WIN_ENV then return {} end
    return {
      title = "Screen Scaling",
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
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
        f:static_text {
          title = 'Select "Auto" for same display scale factor as on Windows OS (Display Settings -> Scale)'
        }
      },
    }
  end
  local function sectionUserInterface()
    local function taggingControlsSetting()
      if LR5 then return f:control_spacing{} end  -- return empty space
      return
        f:row {
          bind_to_object = prefs,
          spacing = f:control_spacing(),
          f:popup_menu {
            title = "taggingControls",
            value = bind ("taggingControls"),
            width = dropDownWidth,
            items = {
              { title = "On",  value = true  },
              { title = "Off", value = false },
            }
          },
          f:static_text {
            title = 'Enable controls for flagging, rating and coloring a photo (mouse and keyboard)'
          },
        }
    end
    local function keyboardLayoutSetting()
      if LR5 then return f:control_spacing{} end  -- return empty space
      return f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "keyboardLayout",
          value = bind ("keyboardLayout"),
          width = dropDownWidth,
          items = KeyboardLayout.buildDropdownItems(),
        },
        f:static_text {
          title = 'Keyboard layout. Required to process shortcuts 0..9 for rating and coloring'
        },
      }
    end
    return {
      title = "User Interface",
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "pluginWindowScaling",
          value = bind ("pluginWindowScaling"),
          width = dropDownWidth,
          items = {
            { title = "XXL", value = FocusPointPrefs.pluginWindowXXL },
            { title = "XL",  value = FocusPointPrefs.pluginWindowXL  },
            { title = "L",   value = FocusPointPrefs.pluginWindowL   },
            { title = "M",   value = FocusPointPrefs.pluginWindowM   },
            { title = "S",   value = FocusPointPrefs.pluginWindowS   },
          }
        },
        f:static_text {
          title = 'Size of plugin window'
        }
      },
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "keyboardInput",
          value = bind ("keyboardInput"),
          width = dropDownWidth,
          items = {
            { title = "Invisible",  value = FocusPointPrefs.kbdInputInvisible },
            { title = "Small",      value = FocusPointPrefs.kbdInputSmall     },
            { title = "Regular",    value = FocusPointPrefs.kbdInputRegular   },
          }
        },
        f:static_text {
            title = 'Appearance of text input field for keyboard shortcuts'
        },
      },
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "truncateLongText",
          value = bind ("truncateLongText"),
          width = dropDownWidth,
          items = {
            { title = "On",  value = true  },
            { title = "Off", value = false },
          },
        },
        f:static_text {
            title = 'Truncate or wrap long metadata value strings after'
        },
        f:edit_field {
          value = bind ("truncateLimit"),
          width_in_chars = 3,
          min = 10,
          max = 100,
          precision = 0,
        },
        f:static_text {
          title = 'characters',
        },
      },

      taggingControlsSetting(),   -- empty for LR5
      keyboardLayoutSetting(),    -- empty for LR5
    }
  end
  local function sectionViewingOptions()
    return
    {
      title = "Viewing Options",
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "focusBoxColor",
          value = bind("focusBoxColor"),
          width = dropDownWidth,
          items = {
            { title = "Red",   value = "red" },
            { title = "Green", value = "green" },
            { title = "Blue",  value = "blue" },
          }
        },
        f:static_text {
          title = 'Color for in-focus points',
        },
      },
      f:row {
        bind_to_object = prefs,
        f:popup_menu {
          title = "focusBoxSize",
          value = bind("focusBoxSize"),
          width = dropDownWidth,
          items = {
            { title = "Small", value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeSmall] },
            { title = "Medium", value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeMedium] },
            { title = "Large", value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeLarge] },
          }
        },
        f:static_text {
          title = "  Size of focus box for 'focus pixel' points ",
        },
      },
    }
  end
  local function sectionProcessingOptions()
    return
    {
      title = "Processing Options",
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "processMfInfo",
          value = bind ("processMfInfo"),
          width = dropDownWidth,
          items = {
            { title = "On",  value = true  },
            { title = "Off", value = false },
          }
        },
        f:static_text {
          title = 'Process focus information for images taken with manual focus (MF)',
        },
      },
    }
  end
  local function sectionLogging()
    return
    {
      title = "Logging",
      f:row {
        bind_to_object = prefs,
        spacing = f:control_spacing(),
        f:popup_menu {
          title = "Logging level",
          value = bind ('loggingLevel'),
          width = dropDownWidth,
          items = {
            { title = "Auto",  value = "AUTO"  },
            { title = "Full",  value = "FULL"  },
            { title = "Debug", value = "DEBUG" },
            { title = "Info",  value = "INFO"  },
            { title = "Warn",  value = "WARN"  },
            { title = "Error", value = "ERROR" },
            { title = "None",  value = "NONE"  },
          }
        },
        f:static_text {
          title = 'Level of information to be logged (Recommended: "Auto")'
        },
        f:static_text {
          title = 'Plugin log:',
          alignment = 'right',
          fill_horizontal = 1,
        },
        f:push_button {
          title = "Show file",
          action = function()
            local logFileName = Log.getLogFileName()
            if LrFileUtils.exists(logFileName)then
              LrShell.revealInShell(logFileName)
            else
              LrDialogs.message('No log file written. Set logging level other than "None".')
            end
          end,
        },
      },
    }
  end
  local function sectionUpdates()
    return
    {
      title = "Updates",
      bind_to_object = prefs,
      spacing = f:control_spacing(),
      f:row {
        f:checkbox {
          title = 'Display message when updates are available',
          value = bind('checkForUpdates')
        },
        f:spacer{fill_horizontal = 1},
        updateMessage,
      },
    }
  end
  local function sectionAcknowledgements()
    return
    {
      title = "Acknowledgements",
      f:row {
        fill_horizontal = 1,
        f:column {
          fill_horizontal = 1,
          f:static_text {
            font = "<system/bold>",
            title = 'ImageMagick Studio LLC'
          },
          f:spacer{ height = 5 },
          f:static_text {
            title = 'This plugin uses ImageMagick mogrify'
          }
        },
        f:column {
          f:static_text {
            title = "https://imagemagick.org/index.php"
          },
        },
      },
      f:spacer{fill_horizontal = 1},
      f:row {
        fill_horizontal = 1,
        f:column {
          fill_horizontal = 1,
          f:static_text {
            font = "<system/bold>",
            title = 'ExifTool'
          },
          f:spacer{ height = 5 },
          f:static_text {
            title = "This plugin relies on Phil Harvey's ExifTool to read and decode metadata"
          }
        },
        f:column {
          f:static_text {
            title = "https://exiftool.org/"
          },
        },
      },
    }
  end

  return {
    sectionScreenScaling(),
    sectionUserInterface(),
    sectionViewingOptions(),
    sectionProcessingOptions(),
    sectionLogging(),
    sectionUpdates(),
    sectionAcknowledgements(),
  }
end

return FocusPointPrefs -- ok
