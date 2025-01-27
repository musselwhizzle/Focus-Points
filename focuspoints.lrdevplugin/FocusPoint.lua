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
local LrApplicationView = import 'LrApplicationView'
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
    local errorMsg = nil
    local photoView = nil
    local dialogScope = nil
    local rendererTable = nil
    local switchedToLibrary = nil

    -- only on WIN (issue #199):
    -- when launched in Develop module switch to Library to enforce that a preview of the image is available
    -- must switch to loupe view because only in this view previews will be rendered
    -- perform module switch as early as possible to give Library time to create a preview if none exists
    if WIN_ENV then
      local moduleName = LrApplicationView.getCurrentModuleName()
      if moduleName == "develop" then
        LrApplicationView.switchToModule("library")
        LrApplicationView.showView("loupe")
        switchedToLibrary = true
        LrTasks.sleep(2.5)  -- timing-specific; might need to be increased on certain systems. Perhaps make it configurable?
      end
    end

    -- throw up this dialog as soon as possible as it blocks input which keeps the plugin from potentially launching
    -- twice if clicked on really quickly
    -- let the renderer build the view now and show progress dialog
    LrFunctionContext.callWithContext("innerContext", function(dialogContext)
      dialogScope = LrDialogs.showModalProgressDialog {
        title = "Loading Data",
        caption = "Calculating Focus Point",
        width = 200,
        cannotCancel = false,
        functionContext = dialogContext,
      }
      dialogScope:setIndeterminate()

      if (targetPhoto:checkPhotoAvailability()) then
        local photoW, photoH = FocusPointDialog.calculatePhotoDimens(targetPhoto)
        rendererTable = PointsRendererFactory.createRenderer(targetPhoto)
        if (rendererTable ~= nil) then
          photoView = rendererTable.createView(targetPhoto, photoW, photoH)
          if photoView == nil then
            errorMsg = "No Focus-Point information found"
          end
        else
          errorMsg = "Unmapped points renderer"
        end
      else
        errorMsg = "Photo is not available. Make sure hard drives are attached and try again"
      end
    end)
    LrTasks.sleep(0) -- this actually closes the dialog. go figure.

    -- by displaying the error outside of the dialogContext, it allows the progress dialog to close
    if (errorMsg ~= nil) then
      LrDialogs.message(errorMsg, nil, nil)
      return
    end

    if (dialogScope:isCanceled() or photoView == nil) then
      return
    end

    -- display the contents
    LrDialogs.presentModalDialog {
      title = "Focus Point Viewer",
      cancelVerb = "< exclude >",
      actionVerb = "OK",
      contents = FocusPointDialog.createDialog(targetPhoto, photoView)
    }
    rendererTable.cleanup()

    if WIN_ENV and switchedToLibrary then
      LrApplicationView.switchToModule("develop")
    end

  end)
end

LrTasks.startAsyncTask(showDialog)



