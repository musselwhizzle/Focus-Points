--[[
  Copyright 2016 Joshua Musselwhite, Whizzbang Inc

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
          local column1, column1CharWidth, column2, column2CharWidth, lineCount = splitForColumns(metaData)

          dialogScope:done()
          MetaDataDialog.create(column1, column1CharWidth, column2, column2CharWidth, lineCount)
          --MetaDataDialog.labels.title = "Foo"
          --MetaDataDialog.data.title = metaData
          --MetaDataDialog.labels.title = column1
          --MetaDataDialog.data.title = column2
        end)

      LrTasks.sleep(0)
      LrDialogs.presentModalDialog {
        title = "Metadata display",
        resizable = true,
        cancelVerb = "< exclude >",
        actionVerb = "OK",
        contents = MetaDataDialog.contents
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
  local labelsCharWidth = 0
  local valuesCharWidth = 0
  local lineCount = 0
  for k in pairs(parts) do
    local l = parts[k].key
    local v = parts[k].value
    if (l == nill) then l = "" end
    if (v == nill) then v = "" end
    l = LrStringUtils.trimWhitespace(l)
    v = LrStringUtils.trimWhitespace(v)

    labels = labels .. l .. "\r\n"
    values = values .. v .. "\r"
    labelsCharWidth = math.max(labelsCharWidth, string.len(l))
    valuesCharWidth = math.max(valuesCharWidth, string.len(v))
    lineCount = lineCount + 1
  end
  return labels, labelsCharWidth, values, valuesCharWidth, lineCount

end

function createParts(metaData)
  local parts = {}
  local num = 0;
  for i in string.gmatch(metaData, "[^\\\n]+") do
    log("i = " .. i)
    p = splitText(i, ":")
    if (p ~= nill) then
      parts[num] = p
      num = num+1
    end
  end
  return parts
end
