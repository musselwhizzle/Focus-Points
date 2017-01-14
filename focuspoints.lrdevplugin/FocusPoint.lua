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
local LrColor = import 'LrColor'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrErrors = import 'LrErrors'

require "FocusPointDialog"
require "PointsRendererFactory"

local function showDialog()
  LrFunctionContext.callWithContext("showDialog", function(context)

    local catalog = LrApplication.activeCatalog()
    local targetPhoto = catalog:getTargetPhoto()

    LrTasks.startAsyncTask(function(context)
      if (targetPhoto:checkPhotoAvailability() == false) then
        LrDialogs.message("Photo is not available. Make sure hard drives are attached and try again", nil, nil)
        return
      end

      local photoW, photoH = FocusPointDialog.calculatePhotoDimens(targetPhoto)
      local rendererTable = PointsRendererFactory.createRenderer(targetPhoto)
      if (rendererTable == nil) then
        LrDialogs.message("Unmapped points renderer.", nil, nil)
        return
      end

      -- let the renderer build the view now and show progress dialog
      LrFunctionContext.callWithContext("innerContext", function(dialogContext)
        local dialogScope = LrDialogs.showModalProgressDialog {
          title = "Loading Data",
          caption = "Calculating Focus Point",
          width = 200,
          cannotCancel = false,
          functionContext = dialogContext,
        }
        dialogScope:setIndeterminate()
        -- not local overlay. Need the scope outside for the dialog box below
        overlay = rendererTable.createView(targetPhoto, photoW, photoH)
      end)


      -- display the contents
      LrDialogs.presentModalDialog {
        title = "Focus Point Viewer",
        cancelVerb = "< exclude >",
        actionVerb = "OK",
        contents = FocusPointDialog.createDialog(targetPhoto, overlay)
      }
    end)
  end)
end

showDialog()



