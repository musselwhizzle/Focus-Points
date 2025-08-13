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
local LrPrefs = import "LrPrefs"
local LrColor           = import "LrColor"
local LrHttp            = import "LrHttp"

require "FocusPointPrefs"
require "FocusPointDialog"
require "FocusInfo"
require "PointsRendererFactory"
require "Log"


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
    local done
    local prefs = LrPrefs.prefsForPlugin( nil )
    local props = LrBinding.makePropertyTable(context, { clicked = false })

    -- To avoid nil pointer errors in case of "dirty" installation (copy new over old files)
    FocusPointPrefs.InitializePrefs(prefs)
    -- Initialize logging for non-Auto modes
    if prefs.loggingLevel ~= "AUTO" then Log.initialize() end

    -- Set scale factor for sizing of dialog window
    if WIN_ENV then
    FocusPointPrefs.setDisplayScaleFactor()
    Log.logInfo("System", "Display scaling level " ..
           math.floor(100/FocusPointPrefs.getDisplayScaleFactor() + 0.5) .. "%")
    end

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
--        LrTasks.sleep(5)  -- timing-specific; might need to be increased on certain systems. tbe
      end
    end

    -- throw up this dialog as soon as possible as it blocks input which keeps the plugin from potentially launching
    -- twice if clicked on really quickly
    -- let the renderer build the view now and show progress dialog
    repeat

      -- Initialize logging
      if prefs.loggingLevel == "AUTO" then Log.initialize() end
      Log.resetErrorsWarnings()
      Log.logInfo("FocusPoint", string.rep("=", 72))

      -- Save link to current photo, eg. as supplementary information in user messages
      FocusPointDialog.currentPhoto = targetPhoto

      LrFunctionContext.callWithContext("innerContext", function(dialogContext)
        dialogScope = LrDialogs.showModalProgressDialog {
          title = "Loading Data",
          caption = "Calculating Focus Point",
          width = 200,
          cannotCancel = false,
          functionContext = dialogContext,
        }
        dialogScope:setIndeterminate()

        errorMsg = nil
        if (targetPhoto:checkPhotoAvailability()) then
          local photoW, photoH = FocusPointDialog.calculatePhotoDimens(targetPhoto)
          rendererTable = PointsRendererFactory.createRenderer(targetPhoto)

          if rendererTable then
            photoView = rendererTable.createPhotoView(targetPhoto, photoW, photoH)
            infoView  = FocusInfo.createInfoView (targetPhoto, props)
            if not (photoView and infoView) then
              errorMsg = "Internal error: Unable to create main window"
            end
          else
            -- just to have this case covered - normally this condition should not occur
            errorMsg = "Internal error: Unmapped points renderer"
          end
        else
          errorMsg = "Photo is not available. Make sure hard drives are attached and try again"
        end
      end)
      LrTasks.sleep(0) -- this actually closes the dialog. go figure.

      -- "Loading Data" dialog has been canceled
      -- photoView should never be nil in the absence of a fatal error
      local skipMainWindow
      if (dialogScope:isCanceled() or not photoView) then
        skipMainWindow = true
      end

      -- a fatal error has occured for the current image: ask user whether to "Exit" the plugin
      -- or "Continue" with the next image in multi-image mode (which means repeat in single-image mode)
      if errorMsg then
        userResponse = LrDialogs.confirm(msg, getPhotoFileName(), "Continue", "Stop")
        if userResponse == "cancel" then
          -- Stop plugin operation
          return
        else
          -- just skip the main window, continue with next image or retry for the current
          skipMainWindow = true
        end
      end

      if skipMainWindow then
        -- a fatal error has occured for the current image, "Exit" the plugin opreration or
        -- "Continue" to next image (in multi-image mode) or repeat (single-image mode)
        if (#selectedPhotos > 1) then
          -- set index to next image, wrap around at end of list
          current = (current % #selectedPhotos) + 1
          targetPhoto = selectedPhotos[current]
        end
      else

        -- Open main window
        Log.logInfo("FocusPoint", "Present dialog and information")

--        Log.logInfo("Profiling", Debug.profileResults ())

        -- controls to operate on a series of selected photos
          local f = LrView.osFactory()
          local buttonNextImage = "Next image " .. string.char(0xe2, 0x96, 0xb6)
          local buttonPrevImage = string.char(0xe2, 0x97, 0x80) .. " Previous image"

          props.clicked = false
          userResponse = LrDialogs.presentModalDialog {
          title = "Focus-Points (Version " .. getPluginVersion() .. ")",
            contents = FocusPointDialog.createDialog(targetPhoto, photoView, infoView),
            accessoryView = f:row {
              spacing = 0,     -- removes uniform spacing; we control it manually
              f:push_button {
                title = buttonPrevImage,
              action = (function(button)
                  -- Prevent multiple executions - known LrC SDK quirk!
                  if props.clicked then return end
                  props.clicked = true
                  -- set index to previous image, wrap around at beginning of list
                if #selectedPhotos > 1 then
                  current =  (current - 2) % #selectedPhotos + 1
                  LrDialogs.stopModalWithResult(button, "previous")
                end
              end)
            },
            f:spacer { width = 20 },    -- space before the file name
            f:static_text{
              title = getPhotoFileName(targetPhoto) .. " (" .. current .. "/" .. #selectedPhotos .. ")",
              },
              f:spacer { width = 20 },    -- space before the next button
              f:push_button {
                title = buttonNextImage,
                action = function(button)
                  -- Prevent multiple executions - known LrC SDK quirk!
                  if props.clicked then return end
                  props.clicked = true
                  -- set index to next image, wrap around at end of list
                if #selectedPhotos > 1 then
                  current = (current % #selectedPhotos) + 1
                  LrDialogs.stopModalWithResult(button, "next")
                end
              end
              },
            f:spacer{fill_horizontal = 1},
            f:static_text {
              title = "User Manual " .. string.char(0xF0, 0x9F, 0x94, 0x97),
              text_color = LrColor("blue"),
              tooltip = "Click to open user documentation",
              immediate = true,
              mouse_down = function(_view)
                import 'LrTasks'.startAsyncTask(function()
                    LrHttp.openUrlInBrowser("https://github.com/capricorn8/Focus-Points/blob/master/docs/Focus%20Points.md")
                end)
              end,
            },
          f:spacer { width = 20 },    -- space before 'Exit' button
          },
            actionVerb = "Exit",
            cancelVerb = "< exclude >",
          }
          -- Proceed to selected photo
          targetPhoto = selectedPhotos[current]

        -- Clean up
        rendererTable.cleanup()

        -- Close the windows if user clicked <Exit> button or pressed <Esc>
        done = (userResponse == "ok") or (userResponse == "cancel")
      end

    until done

    -- Return to Develop modul if the plugin has been started from there
    if WIN_ENV and switchedToLibrary then
      LrApplicationView.switchToModule("develop")
    end

  end)
end

LrTasks.startAsyncTask(showDialog)
