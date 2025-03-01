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

local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrStringUtils = import "LrStringUtils"
local LrPrefs = import "LrPrefs"

require "FocusPointPrefs"
require "MetaDataDialog"
require "ExifUtils"
require "Utils"
require "Log"


local function showDialog()

  LrFunctionContext.callWithContext("showDialog", function(context)

  local catalog = LrApplication.activeCatalog()
  local targetPhoto = catalog:getTargetPhoto()

  -- To avoid nil pointer errors in case of "dirty" installation (copy over old files)
  FocusPointPrefs.InitializePrefs(LrPrefs.prefsForPlugin(nil))

  LrTasks.startAsyncTask(function(context)
    --https://forums.adobe.com/thread/359790

    LrFunctionContext.callWithContext("function", function(dialogContext)
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

      local result = showMetadataDialog(column1, column2, column1Length, column2Length, numLines)

      -- Check whether dialog has been left by pressing "Open as text"
      if result == "other" then
        -- if so, open metadata file in default application (and keep it)
        openFileInApp(ExifUtils.getMetaDataFile())
      else
        -- otherwise remove the temp file
        LrFileUtils.delete(metaDataFile)
      end
      --[[
      -- END MOD - Add Metadata filter
      --]]

    end)
  end)
end)
end

showDialog()


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
    if l == nil then l = "" end
    if v == nil then v = "" end

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

function createParts(metaData)
  local parts = {}
  local num = 1;

  local function createPart(label, value)
    local p = {}
    p.label = LrStringUtils.trimWhitespace(label)
    p.value = LrStringUtils.trimWhitespace(value)
    Log.logDebug("ShowMetadata", "Parsed '" .. p.label .. "' = '" .. p.value .. "'")
    return p
  end

  for label, value in string.gmatch(metaData, "([^\:]+)\:([^\r\n]*)\r?\n") do
    parts[num] = createPart(label, value)
    num = num+1
  end
  return parts
end
