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

require "FocusPointDialog"
require "PointsRendererFactory"

FocusPoints = {}

function FocusPoints.showDialog()
  LrFunctionContext.callWithContext("showDialog", function(context)

    local catalog = LrApplication.activeCatalog()
    local targetPhoto = catalog:getTargetPhoto()

    -- set overlay to nil, if errors during render, this can be checked to prevent showing the final dialog
    local overlay = nil

    -- let the renderer build the view now and show progress dialog
    LrFunctionContext.callWithContext("innerContext", function(dialogContext)
      -- Save LrProgressScope for checking if 'cancelled'
      FocusPoints.dialogScope = LrDialogs.showModalProgressDialog {
        title = "Loading Data",
        caption = "Calculating Focus Point",
        width = 200,
        cannotCancel = false,
        functionContext = dialogContext,
      }
      FocusPoints.dialogScope:setIndeterminate()
                                    
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

      -- Save overlay for next dialog display
      overlay = rendererTable.createView(targetPhoto, photoW, photoH)
                                    
      FocusPoints.dialogScope:done()
    end)

    LrTasks.sleep(0)
    if not FocusPoints.dialogScope:isCanceled() and overlay ~= nil then
      -- display the contents
      LrDialogs.presentModalDialog {
        title = "Focus Point Viewer",
        cancelVerb = "< exclude >",
        actionVerb = "OK",
        contents = FocusPointDialog.createDialog(targetPhoto, overlay)
      }
    end
  end)
end

LrTasks.startAsyncTask(FocusPoints.showDialog)
