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

local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import "LrStringUtils"

require "MetaDataDialog"
require "ExifUtils"
require "Utils"

local function showDialog()
  LrFunctionContext.callWithContext("showDialog", function(context)

  local catalog = LrApplication.activeCatalog()
  local targetPhoto = catalog:getTargetPhoto()

  LrTasks.startAsyncTask(function(context)
    --https://forums.adobe.com/thread/359790
    LrFunctionContext.callWithContext("function", function(dialogContext)
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
      LrDialogs.presentModalDialog {
        title = "Metadata display",
        resizable = true,
        cancelVerb = "< exclude >",
        actionVerb = "OK",
        contents = MetaDataDialog.create(column1, column2, column1Length, column2Length, numLines)
      }

    end)
  end)
end)
end
showDialog()

function splitForColumns(metaData)
  local parts = createParts(metaData)
  local labels = ""
  local values = ""
  local maxLabelsLength = 0
  local maxValuesLength = 0
  local numOfLines = 0;
  for k in pairs(parts) do
    local l = parts[k].key
    
    local v = parts[k].value
    if l == nil then l = "" end
    if v == nil then v = "" end
    l = LrStringUtils.trimWhitespace(l)
    v = LrStringUtils.trimWhitespace(v)
    
    maxLabelsLength = math.max(maxLabelsLength, string.len(l))
    maxValuesLength = math.max(maxValuesLength, string.len(v))
    numOfLines = numOfLines + 1
    
    --logDebug("ShowMetadata", "l: " .. l)
    --logDebug("ShowMetadata", "v: " .. v)
    
    labels = labels .. l .. "\r"
    values = values .. v .. "\r"
  end
  return labels, values, maxLabelsLength, maxValuesLength, numOfLines
  
end

function createParts(metaData)
  local parts = {}
  local num = 1;
  for i in string.gmatch(metaData, "[^\\\n]+") do 
    logDebug("ShowMetadata", "i = " .. i)
    p = stringToKeyValue(i, ":")
    if p ~= nil then
      parts[num] = p
      num = num+1
    end
  end
  return parts
end
