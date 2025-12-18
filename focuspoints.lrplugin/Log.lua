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


local LrApplication = import 'LrApplication'
local LrPathUtils = import 'LrPathUtils'
local LrFileUtils = import 'LrFileUtils'
local LrLogger = import 'LrLogger'
local LrPrefs = import "LrPrefs"
local LrSystemInfo = import "LrSystemInfo"

require "Info"
require "KeyboardLayout"


Log = {}

Log.logName  = "FocusPoints"
Log.logger    = LrLogger(Log.logName)
Log.logger:enable("logfile")

Log.warningsEncountered = nil
Log.errorsEncountered   = nil

local prefs = LrPrefs.prefsForPlugin( nil )

--[[----------------------------------------------------------------------------
-- Use the SDK's LrLogger infrastructure to log the plugin's execution to the
-- file "FocusPoints.log" in LrC's log folder (see note below).
------------------------------------------------------------------------------]]

--[[
-- Logging functions. You are provided 5 levels of logging. Wisely choose the level of the message you want to report
-- to prevent to much messages.
-- Typical use cases:
--   - logDebug - Informations diagnostically helpful to people (developers, IT, sysadmins, etc.)
--   - logInfo - Informations generally useful to log (service start/stop, configuration assumptions, etc)
--   - logWarn - Informations about an unexpected state that won't generate a problem
--   - logError - An error which is fatal to the operation
-- These methods expects 2 parameters:
--   - group - a logical grouping string (limited to 20 chars and converted to upper case) to make it easier to find the messages you are looking for
--   - message - the message to be logged
-- A call to logDebug("ExifUtils", "Searching for 'AF Point Used'") will result in the following log entry
--    EXIFUTILS | Searching for 'AF Point Used'
-- A call to logWarn("FUJIDELEGATE", "Face recognition algorithm returned an unexcepted value") will result in the following log entry
-- FUJIDELEGATE | Face recognition algorithm returned an unexcepted value
--]]

local function doLog(level, group, message)
  local levels = {
    NONE  = 0,
    ERROR = 1,
    WARN  = 2,
    INFO  = 3,
    AUTO  = 5,  -- AUTO includes ERROR, WARN and INFO entries - if errors or warnings have been encountered
    DEBUG = 7,
    FULL  = 9
  }

  -- Looking for the prefs
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
    Log.logger:error(str)
  elseif level == "WARN" then
    Log.logger:warn(str)
  elseif level == "INFO" then
    Log.logger:info(str)
  else
    Log.logger:debug(str)
  end
end

function Log.logFull(group, message)
  doLog("FULL", group, message)
end

function Log.logDebug(group, message)
  doLog("DEBUG", group, message)
end

function Log.logInfo(group, message)
  doLog("INFO", group, message)
end

function Log.logWarn(group, message)
  doLog("WARN", group, message)
  Log.warningsEncountered = true
end

function Log.logError(group, message)
  doLog("ERROR", group, message)
  Log.errorsEncountered = true
end


--[[
  @@public string Log.getFileName()
  ----
  Retrieves the full path name of the plugin log file. Returns nil if no log file exists.
  LrC 14 logs interface note (Oct 2024):
  We (Adobe) have changed the log file location for the LrLogger interface.
  The timestamps are no longer appended to the folders. The updated locations are:
  Win: C:\Users\<user>\AppData\Local\Adobe\Lightroom\Logs\LrClassicLogs\
  Mac: /Users/<user>/Library/Logs/Adobe/Lightroom/LrClassicLogs/
  Before LrC 14, plugin logfiles have been stored under Documents/LrClassicLogs
  on both WIN and MAC computers.
--]]
function Log.getFileName()
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
  Log.fileName = LrPathUtils.child(userHome, LrPathUtils.child(logFolder, Log.logName .. ".log"))
  return Log.fileName
end


function Log.fileExists()
  return LrFileUtils.exists(Log.getFileName())
end


function Log.delete()
  -- delete / reset log
  local logFileName = Log.getFileName()
  if Log.fileExists() then
    if not LrFileUtils.delete(logFileName) then
      Log.logWarn("Utils", "Error deleting log file " .. logFileName)
    end
  end
end


--[[
  @@public void Log.sysInfo()
  ----
  Output logfile header with system level information. Cqlled during Log.initialize()
--]]
function Log.sysInfo()

  local osName = ""
  if not WIN_ENV then
    osName = "macOS "
  end
  Log.logInfo("System", "'" .. prefs.loggingLevel .. "' logging to " .. Log.getFileName())
  Log.logInfo("System", string.format(
          "Running plugin version %s in Lightroom Classic %s.%s on %s%s",
            getPluginVersion(), LrApplication.versionTable().major, LrApplication.versionTable().minor,
            osName, LrSystemInfo.osVersion()))
  if prefs.keyboardLayout then
    Log.logInfo(
      "System",
      "Keyboard layout (user setting): '" .. KeyboardLayout.layoutById[prefs.keyboardLayout].label .. "'")
  end
end

--[[
  @@public void Log.appInfo()
  ----
  Extend logfile header with application level information. Needs to be called separately.
--]]
function Log.appInfo()

  if FocusPointPrefs.updateAvailable() then
    Log.logInfo("System", "Update to version " .. FocusPointPrefs.latestVersion() .. " available")
  end
  if WIN_ENV then
    Log.logInfo("System", "Display scaling level " ..
            math.floor(100/FocusPointPrefs.getDisplayScaleFactor() + 0.5) .. "%")
  end
  Log.logInfo("System", string.format(
    "Application window size: %s x %s", FocusPointDialog.AppWidth, FocusPointDialog.AppHeight))
end


--[[
  @@public void Log.resetErrorsWarnings()
  ----
  Reset indicator flags for errors/warnings encountered
--]]
function Log.resetErrorsWarnings()
  Log.warningsEncountered = nil
  Log.errorsEncountered   = nil
end


--[[
  @@public void Log.initialize()
  ----
  Initialize/reset log handling for processing of next image
--]]
function Log.initialize()
  Log.delete()
  Log.resetErrorsWarnings()
  Log.sysInfo()
end

