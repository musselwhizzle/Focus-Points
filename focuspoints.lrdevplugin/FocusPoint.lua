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
local LrApplicationView = import 'LrApplicationView'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrBinding = import "LrBinding"

require "FocusPointDialog"
require "FocusInfo"
require "PointsRendererFactory"


local function showDialog()

  LrFunctionContext.callWithContext("showDialog", function(context)

    local catalog = LrApplication.activeCatalog()
    local targetPhoto = catalog:getTargetPhoto()
    local selectedPhotos = catalog:getTargetPhotos()
    local current
    local errorMsg
    local photoView, infoView
    local dialogScope
    local rendererTable
    local switchedToLibrary
    local userResponse
    local props = LrBinding.makePropertyTable(context)

    -- Find the index 'current' of the target photo in set of selectedPhotos
    for i, photo in ipairs(selectedPhotos) do
       if photo == targetPhoto then
         current = i
         break
       end
    end

    -- only on WIN (issue #199):
    -- if launched in Develop module switch to Library to enforce that a preview of the image is available
    -- must switch to loupe view because only in this view previews will be rendered
    -- perform module switch as early as possible to give Library time to create a preview if none exists
    if WIN_ENV then
      local moduleName = LrApplicationView.getCurrentModuleName()
      if moduleName == "develop" then
        LrApplicationView.switchToModule("library")
        LrApplicationView.showView("loupe")
        switchedToLibrary = true
        LrTasks.sleep(0)  -- timing-specific; might need to be increased on certain systems. tbe
      end
    end

    -- throw up this dialog as soon as possible as it blocks input which keeps the plugin from potentially launching
    -- twice if clicked on really quickly
    -- let the renderer build the view now and show progress dialog
    repeat

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
            photoView = rendererTable.createPhotoView(targetPhoto, photoW, photoH)
            infoView  = FocusInfo.createInfoView (targetPhoto, props)
            if (photoView == nil) or (infoView == nil) then
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

      -- very basic implementation of a dialog to support moving to next/prev image
      -- this is actually abusing the standard 3 button standard layout (OK, Cancel, other) for custom actions
      -- function first! to allow for Nikon mass testing for V2.2 - clean and more sophisticated design to be implemented later
      -- problem: any ThrowUserError() message will stop and exit the plugin
      if (#selectedPhotos == 1) then
        -- single photo operation
        userResponse = LrDialogs.presentModalDialog {
          title = "Focus Points of " ..  targetPhoto:getRawMetadata("path") .. ")",
          cancelVerb = "< exclude >",
          actionVerb = "OK",
          contents = FocusPointDialog.createDialog(targetPhoto, photoView, infoView)
        }
      else
        -- operate on a series of selected photos
        local f = LrView.osFactory()

        userResponse = LrDialogs.presentModalDialog {
          title = "Focus Points of " ..  targetPhoto:getRawMetadata("path") .. " (" .. current .. "/" .. #selectedPhotos .. ")",
          contents = FocusPointDialog.createDialog(targetPhoto, photoView, infoView),
          accessoryView = f:row {
            spacing = 0,     -- removes uniform spacing; we control it manually
            f:push_button {
              title = "⯇ Previous image",
              action = function(button)
                -- set index to previous image, wrap around at beginning of list
                current =  (current - 2) % #selectedPhotos + 1
                LrDialogs.stopModalWithResult(button, "previous")
              end
            },
            f:spacer { width = 20 },    -- space before the next button
            f:push_button {
              title = "Next image ⯈",
              action = function(button)
                -- set index to next image, wrap around at end of list
                current = (current % #selectedPhotos) + 1
                LrDialogs.stopModalWithResult(button, "next")
              end
            },
          },
          actionVerb = "Exit",
          cancelVerb = "< exclude >",
        }
        -- Proceed to selected photo
        targetPhoto = selectedPhotos[current]
      end

     rendererTable.cleanup()

     -- Funnily, using the right side of the expression directly with until doesn't work !??
     local done = (userResponse == "ok") or (userResponse == "cancel")

    until done

    if WIN_ENV and switchedToLibrary then
      LrApplicationView.switchToModule("develop")
    end

  end)
end

LrTasks.startAsyncTask(showDialog)
