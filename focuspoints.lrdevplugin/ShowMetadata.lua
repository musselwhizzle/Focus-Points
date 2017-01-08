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

        -- Starting to show progess dialog
        dialogScope:setIndeterminate()

        local jsonMetaData = ExifUtils.readMetaData(targetPhoto)
        local keywords, values, keywords_max_length, values_max_length, line_count = splitForColumns(parseJson(jsonMetaData))

        dialogScope:done()

        -- Note that metaDataView is not local because used below
        metaDataView = MetaDataDialog.createDialog(keywords, values, keywords_max_length, values_max_length, line_count)
      end)

      LrTasks.sleep(0)
      LrDialogs.presentModalDialog {
        title = "Metadata display",
        resizable = true,
        cancelVerb = "< exclude >",
        actionVerb = "OK",
        contents = metaDataView
      }

    end)
  end)
end)
end
showDialog()
