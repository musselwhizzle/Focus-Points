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

--[[----------------------------------------------------------------------------
  Log.lua

  Purpose of this module:
  Add a logging facility to the plugin.
  Uses the SDK's LrLogger infrastructure to log defined data during the plugin's
  execution to the file "FocusPoints.log" in LrC's log folder.
------------------------------------------------------------------------------]]
local Log = {}

-- Imported LR namespaces
local LrApplication    = import  'LrApplication'
local LrFileUtils      = import  'LrFileUtils'
local LrLogger         = import  'LrLogger'
local LrPathUtils      = import  'LrPathUtils'
local LrPrefs          = import  'LrPrefs'
local LrSystemInfo     = import  'LrSystemInfo'

-- Required Lua definitions
local GlobalDefs       = require 'GlobalDefs'
local KeyboardLayout   = require 'KeyboardLayout'
local _strict          = require 'strict'

local logName   = "FocusPoints"
local logger    = LrLogger(logName)
logger:enable("logfile")

Log.warningsEncountered = nil
Log.errorsEncountered   = nil

--[[----------------------------------------------------------------------------

  Logging functions. You are provided 5 levels of logging.
  Wisely choose the level of the message you want to report to prevent to much messages.

  Typical use cases:
  - logDebug: Informations diagnostically helpful to people (developers, IT, sysadmins, etc.)
  - logInfo:  Informations generally useful to log (service start/stop, configuration assumptions, etc)
  - logWarn:  Informations about an unexpected state that won't generate a problem
  - logError: An error which is fatal to the operation

  All these methods expects 2 parameters:
  - group:    a logical grouping string (limited to 20 chars and converted to upper case)
              to make it easier to find the messages you are looking for
  - message:  the message to be logged

  Examples:
  A call to logDebug("ExifUtils", "Searching for 'AF Point Used'") will result in the following log entry:
     EXIFUTILS | Searching for 'AF Point Used'
  A call to logWarn("FUJIDELEGATE", "Face recognition algorithm returned an unexcepted value")
  will result in the following log entry:
     FUJIDELEGATE | Face recognition algorithm returned an unexcepted value
------------------------------------------------------------------------------]]

--[[----------------------------------------------------------------------------
  private void
  doLog(int level, string group, string message)

  Writes a 'message' classified by 'level' and 'group' to the log file.
  Messages with a higher 'level' than that set for the 'Logging' user will be ignored.
  E.g. if the 'Logging' setting is ERROR, no WARN or INFO messages will be logged.
------------------------------------------------------------------------------]]
local function doLog(level, group, message)
  local levels = {
    NONE  = 0,
    ERROR = 1,
    WARN  = 2,
    INFO  = 3,
    AUTO  = 5,  -- AUTO includes ERROR, WARN and INFO entries
    DEBUG = 7,
    FULL  = 9
  }

  -- Looking for the prefs
  local prefs = LrPrefs.prefsForPlugin( nil )
  if prefs.loggingLevel == nil or levels[prefs.loggingLevel] == nil then
    prefs.loggingLevel = "AUTO"
  end

  local prefsLevel = levels[prefs.loggingLevel]
  local msgLevel = levels[level]

  if prefsLevel == 0 or msgLevel == nil or msgLevel > prefsLevel then
    -- Unknown message log level or level set in preferences higher
    -- No need to log this one, return
    return
  end

  local str = string.format("%20s | %s", string.upper(string.sub(group, 1, 20)), message)
  if level == "ERROR" then
    logger:error(str)
  elseif level == "WARN" then
    logger:warn(str)
  elseif level == "INFO" then
    logger:info(str)
  else
    logger:debug(str)
  end
end

--[[----------------------------------------------------------------------------
  public void
  logFull(string group, string message)

  Logs a FULL level message classified by 'group'
------------------------------------------------------------------------------]]
function Log.logFull(group, message)
  doLog("FULL", group, message)
end

--[[----------------------------------------------------------------------------
  public void
  logDebug(string group, string message)

  Logs a DEBUG level message classified by 'group'
------------------------------------------------------------------------------]]
function Log.logDebug(group, message)
  doLog("DEBUG", group, message)
end

--[[----------------------------------------------------------------------------
  public void
  logInfo(string group, string message)

  Logs a INFO level message classified by 'group'
------------------------------------------------------------------------------]]
function Log.logInfo(group, message)
  doLog("INFO", group, message)
end

--[[----------------------------------------------------------------------------
  public void
  logWarn(string group, string message)

  Logs a WARN level message classified by 'group'
------------------------------------------------------------------------------]]
function Log.logWarn(group, message)
  doLog("WARN", group, message)
  Log.warningsEncountered = true
end

--[[----------------------------------------------------------------------------
  public void
  logError(string group, string message)

  Logs a ERROR level message classified by 'group'
------------------------------------------------------------------------------]]
function Log.logError(group, message)
  doLog("ERROR", group, message)
  Log.errorsEncountered = true
end

--[[----------------------------------------------------------------------------
  public string
  getLogFileName()

  Retrieves the full path name of the plugin log file.
  Returns nil if no log file exists.

  LrC 14 logs interface note (Oct 2024):
  We (Adobe) have changed the log file location for the LrLogger interface.
  The timestamps are no longer appended to the folders. The updated locations are:
  Win: C:\Users\<user>\AppData\Local\Adobe\Lightroom\Logs\LrClassicLogs\
  Mac: /Users/<user>/Library/Logs/Adobe/Lightroom/LrClassicLogs/
  Before LrC 14, plugin logfiles have been stored under Documents/LrClassicLogs
  on both WIN and MAC computers.
------------------------------------------------------------------------------]]
function Log.getLogFileName()
  local userHome = LrPathUtils.getStandardFilePath("home")
  local logFolder
  if (LrApplication.versionTable().major < 14) then
    if WIN_ENV then
      logFolder = "\\Documents\\LrClassicLogs\\"
    else
      logFolder = "/Documents/LrClassicLogs/"
    end
  else
    if WIN_ENV then
        logFolder = "\\AppData\\Local\\Adobe\\Lightroom\\Logs\\LrClassicLogs\\"
      else
        logFolder = "/Library/Logs/Adobe/Lightroom/LrClassicLogs/"
    end
  end
  Log.fileName = LrPathUtils.child(userHome, LrPathUtils.child(logFolder, logName .. ".log"))
  return Log.fileName
end

--[[----------------------------------------------------------------------------
  public boolean
  fileExists()

  Returns true if a log file exists.
------------------------------------------------------------------------------]]
function Log.fileExists()
  return LrFileUtils.exists(Log.getLogFileName())
end

--[[----------------------------------------------------------------------------
  public void
  delete()

  Delete/reset log file. Called during Log.initialize().
------------------------------------------------------------------------------]]
function Log.delete()
  -- delete / reset log
  local logFileName = Log.getLogFileName()
  if Log.fileExists() then
    if not LrFileUtils.delete(logFileName) then
      Log.logWarn("Utils", "Error deleting log file " .. logFileName)
    end
  end
end

--[[----------------------------------------------------------------------------
  public void
  sysInfo()

  Output logfile header with system level information. Called during Log.initialize()
------------------------------------------------------------------------------]]
function Log.sysInfo()
  local prefs = LrPrefs.prefsForPlugin( nil )
  local osName = ""
  if not WIN_ENV then
    osName = "macOS "
  end
  Log.logInfo("System", "'" .. prefs.loggingLevel .. "' logging to " .. Log.getLogFileName())
  Log.logInfo("System", string.format("Running plugin version %s in Lightroom Classic %s.%s on %s%s",
    GlobalDefs.pluginDetailedVersion, LrApplication.versionTable().major, LrApplication.versionTable().minor,
    osName, LrSystemInfo.osVersion()))
  if prefs.keyboardLayout then
    Log.logInfo(
      "System",
      "Keyboard layout (user setting): '" .. KeyboardLayout.layoutById[prefs.keyboardLayout].label .. "'")
  end
end

--[[----------------------------------------------------------------------------
  public void
  resetErrorsWarnings()

  Reset indicator flags for errors/warnings encountered
------------------------------------------------------------------------------]]
function Log.resetErrorsWarnings()
  Log.warningsEncountered = nil
  Log.errorsEncountered   = nil
end

--[[----------------------------------------------------------------------------
  public void
  initialize()

  Initialize/reset log handling for processing of next image:
  - Delete previous log file
  - Reset indicator flags for errors/warnings encountered
  - Open new logfile and write system info header
------------------------------------------------------------------------------]]
function Log.initialize()
  Log.delete()
  Log.resetErrorsWarnings()
  Log.sysInfo()
end

return Log -- ok
