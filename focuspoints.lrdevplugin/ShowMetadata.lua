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

  MetaDataDialog.create()
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
          local column1, column2 = splitForColumns(metaData)

          dialogScope:done()
          MetaDataDialog.labels.title = column1
          MetaDataDialog.data.title = column2
          --MetaDataDialog.labels.title = "parts: "  .. parts[1].key
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
  for k in pairs(parts) do
    local l = parts[k].key
    local v = parts[k].value
    if (l == nill) then l = "" end
    if (v == nill) then v = "" end
    l = LrStringUtils.trimWhitespace(l)
    v = LrStringUtils.trimWhitespace(v)

    labels = labels .. l .. "\r"
    values = values .. v .. "\r"
  end
  return labels, values

end

function createParts(metaData)
  local parts = {}
  local num = 0;
  for i in string.gmatch(metaData, "[^\\\n]+") do
    log("i = " .. i)

    p = splitText(i, ":")
    if p ~= nill then
      parts[num] = p
      num = num + 1
    elseif string.sub(i, 1, 4) == "----" then       -- We have a category, lets create the corresponding parts
      parts[num] = { ["key"] = "", ["value"] = "" }
      num = num + 1
      parts[num] = { ["key"] = "----" .. string.upper(i) .. "----", ["value"] = "" }
      num = num + 1
    end
  end
  return parts
end
