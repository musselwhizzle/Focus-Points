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

local LrApplication     = import 'LrApplication'
local LrDialogs         = import 'LrDialogs'
local LrFileUtils       = import 'LrFileUtils'
local LrFunctionContext = import 'LrFunctionContext'
local LrPrefs           = import  'LrPrefs'
local LrStringUtils     = import  'LrStringUtils'
local LrTasks           = import 'LrTasks'
local ExifUtils         = require 'ExifUtils'
local FocusPointPrefs   = require 'FocusPointPrefs'
local Log               = require 'Log'
local MetadataDialog    = require 'MetadataDialog'
local Utils             = require 'Utils'


--[[
  @@public void function showDialog()
  ----
  Display dialog to browse metadata and search for specific tags
--]]
local function showDialog()

--  Debug.pauseIfAsked()

  LrFunctionContext.callWithContext("showDialog", function(_context)

    local catalog = LrApplication.activeCatalog()
    local targetPhoto = catalog:getTargetPhoto()

    -- To avoid nil pointer errors in case of "dirty" installation (copy over old files)
    FocusPointPrefs.InitializePrefs(LrPrefs.prefsForPlugin(nil))

    -- Initialize logging
    Log.initialize()

    -- Set scale factor for sizing of dialog window
    if WIN_ENV then
      FocusPointPrefs.setDisplayScaleFactor()
      Log.logInfo("System", "Display scaling level " ..
              math.floor(100/FocusPointPrefs.getDisplayScaleFactor() + 0.5) .. "%")
    end

    Log.logInfo("Metadata", string.rep("=", 72))
    Log.logInfo("Metadata", "Image: " .. targetPhoto:getRawMetadata("path"))


    LrTasks.startAsyncTask(function(_context)
      --https://forums.adobe.com/thread/359790

      LrFunctionContext.callWithContext("function", function(_dialogContext)
        local column1, column2, column1Length, column2Length, numLines

          LrFunctionContext.callWithContext("function2", function(dialogContext2)
            local dialogScope = LrDialogs.showModalProgressDialog {
              title = "Loading Data",
              caption = "Reading Metadata",
              width = 200,
              cannotCancel = false,
              functionContext = dialogContext2,
            }
            dialogScope:setIndeterminate()

            local metaData = ExifUtils.readMetaData(targetPhoto)
            metaData = ExifUtils.filterInput(metaData)
            column1, column2, column1Length, column2Length, numLines = splitForColumns(metaData)

            dialogScope:done()
          end)

        LrTasks.sleep(0)

        local result = MetadataDialog.showDialog(targetPhoto, column1, column2, column1Length, column2Length, numLines)

        -- Check whether dialog has been left by pressing "Open as text"
        if result == "other" then
          -- if so, open metadata file in default application (and keep it)
          Utils.openFileInApp(ExifUtils.getMetaDataFile())
        else
          -- otherwise remove the temp file
          LrFileUtils.delete(metaDataFile)
        end
      end)
    end)
  end)
end


--[[
  @@public table, table, int, int, int, function splitForColumns(table metaData)
  ----
  Post-process the metadata table with labels and values
  to pass each column as a string to the scrolled view element of the dialog.
  Returns labels, values, maxLabelLength, maxValueLength, numOfLines
--]]
function splitForColumns(metaData)

  local parts = createParts(metaData)
  local labels = ""
  local values = ""
  local maxLabelLength = 0
  local maxValueLength = 0
  local numOfLines = 0
  local limitValueLength = 255  -- to avoid super-long value strings that whill slow down display

  for k in pairs(parts) do
    local l = parts[k].label
    local v = parts[k].value
    if not l then l = "" end
    if not v then v = "" end

    -- limit length of a displayed value string, indicate spillover by dots
    -- the original entry can still be examined by opening the metadata txt file in editor
    if string.len(v) > limitValueLength then
       v = LrStringUtils.truncate(v, limitValueLength) .. "[...]"
    end

    maxLabelLength = math.max(maxLabelLength, string.len(l))
    maxValueLength = math.max(maxValueLength, string.len(v))
    numOfLines = numOfLines + 1

    labels = labels .. l .. "\r"
    values = values .. v .. "\r"
  end

  Log.logDebug("ShowMetadata", "splitForColumns: Labels: " .. labels)
  Log.logDebug("ShowMetadata", "splitForColumns: Values: " .. values)
  Log.logDebug("ShowMetadata", "splitForColumns: maxLabelLength: " .. maxLabelLength)
  Log.logDebug("ShowMetadata", "splitForColumns: maxValueLength: " .. maxValueLength)
  Log.logDebug("ShowMetadata", "splitForColumns: numOfLines: " .. numOfLines)

  return labels, values, maxLabelLength, maxValueLength, numOfLines

end


--[[
  @@public table function splitForColumns(table metaData)
  ----
  Parses ExifTool's text output to fill a table with two columns, representing the labels and values
  Returns table with two columns label/value
--]]
function createParts(metaData)
  local parts = {}
  local num = 1;

  local function createPart(label, value)
    local p = {}
    p.label = LrStringUtils.trimWhitespace(label)
    p.value = LrStringUtils.trimWhitespace(value)
    Log.logFull("ShowMetadata", "Parsed '" .. p.label .. "' = '" .. p.value .. "'")
    return p
  end

  for label, value in string.gmatch(metaData, "([^\:]+)\:([^\r\n]*)\r?\n") do
    parts[num] = createPart(label, value)
    num = num+1
  end
  return parts
end


LrTasks.startAsyncTask( showDialog )
