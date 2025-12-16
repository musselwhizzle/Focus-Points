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

local LrApplication         = import  'LrApplication'
local LrBinding             = import  'LrBinding'
local LrColor               = import  'LrColor'
local LrDialogs             = import  'LrDialogs'
local LrFunctionContext     = import  'LrFunctionContext'
local LrHttp                = import  'LrHttp'
local LrPrefs               = import  'LrPrefs'
local LrSystemInfo          = import  'LrSystemInfo'
local LrTasks               = import  'LrTasks'
local LrView                = import  'LrView'
local FocusInfo             = require 'FocusInfo'
local FocusPointDialog      = require 'FocusPointDialog'
local FocusPointPrefs       = require 'FocusPointPrefs'
local Log                   = require 'Log'
local PointsRendererFactory = require 'PointsRendererFactory'
local Utf8                  = require 'Utf8'


local function showDialog()

  LrFunctionContext.callWithContext("showDialog", function(context)

    local catalog = LrApplication.activeCatalog()
    local current
    local errorMsg
    local photoView, infoView
    local dialogScope
    local rendererTable
    local switchedToLibrary
    local userResponse
    local exitPlugin
    local prefs = LrPrefs.prefsForPlugin( nil )
    local props = LrBinding.makePropertyTable(context)
    local LR5 = (LrApplication.versionTable().major == 5) -- or true -- simulate running on LR5

    -- special Unicode characters used as replacement for icons
    local utfRightPointingTriangle = string.char(0xe2, 0x96, 0xb6)
    local utfLeftPointingTriangle  = string.char(0xe2, 0x97, 0x80)
    local utfLinkSymbol            = string.char(0xF0, 0x9F, 0x94, 0x97)
    local utfWhiteHeavyCheckMark   = string.char(0xE2, 0x9C, 0x85)
    local utfHeavyCheckMark        = string.char(0xE2, 0x9C, 0x94)
    local utfCrossMark             = string.char(0xE2, 0x9D, 0x8C)
    local utfKeycapDigitOne        = string.char(0x31, 0xef, 0xb8, 0x8f, 0xe2, 0x83, 0xa3)
    local utfKeycapDigitTwo        = string.char(0x32, 0xef, 0xb8, 0x8f, 0xe2, 0x83, 0xa3)
    local utfKeycapDigitThree      = string.char(0x33, 0xef, 0xb8, 0x8f, 0xe2, 0x83, 0xa3)
    local utfKeycapDigitFour       = string.char(0x34, 0xef, 0xb8, 0x8f, 0xe2, 0x83, 0xa3)
    local utfKeycapDigitFive       = string.char(0x35, 0xef, 0xb8, 0x8f, 0xe2, 0x83, 0xa3)
    local utfBlackLargeSquare      = string.char(0xe2, 0xac, 0x9b)
    local utfRedLargeSquare        = string.char(0xf0, 0x9f, 0x9f, 0xa5)
    local utfYellowLargeSquare     = string.char(0xf0, 0x9f, 0x9f, 0xa8)
    local utfGreenLargeSquare      = string.char(0xf0, 0x9f, 0x9f, 0xa9)
    local utfBlueLargeSquare       = string.char(0xf0, 0x9f, 0x9f, 0xa6)
    local utfPurpleLargeSquare     = string.char(0xf0, 0x9f, 0x9f, 0xaa)
    local buttonNextImage          = "Next image " .. utfRightPointingTriangle
    local buttonPreviousImage      =  utfLeftPointingTriangle .. " Previous image"
    local taggingSymbols = {
      checkMark   = { WIN = utfHeavyCheckMark,   MAC = utfWhiteHeavyCheckMark },
      crossMark   = { WIN = utfCrossMark,        MAC = utfCrossMark           },
      digitOne    = { WIN = "1",                 MAC = utfKeycapDigitOne      },
      digitTwo    = { WIN = "2",                 MAC = utfKeycapDigitTwo      },
      digitThree  = { WIN = "3",                 MAC = utfKeycapDigitThree    },
      digitFour   = { WIN = "4",                 MAC = utfKeycapDigitFour     },
      digitFive   = { WIN = "5",                 MAC = utfKeycapDigitFive     },
      colorRed    = { WIN = utfBlackLargeSquare, MAC = utfRedLargeSquare      },
      colorYellow = { WIN = utfBlackLargeSquare, MAC = utfYellowLargeSquare   },
      colorGreen  = { WIN = utfBlackLargeSquare, MAC = utfGreenLargeSquare    },
      colorBlue   = { WIN = utfBlackLargeSquare, MAC = utfBlueLargeSquare     },
      colorPurple = { WIN = utfBlackLargeSquare, MAC = utfPurpleLargeSquare   },
    }
    local function taggingSymbol(key, overridePlatform)
      local platform = WIN_ENV and "WIN" or "MAC"
      local os = overridePlatform or platform
      local entry = taggingSymbols[key]
      if not entry then return "#" end
      return entry[os]
    end
    local LrSelection
    if not LR5 then
      LrSelection = import "LrSelection"
    end
    -- Get the active photo plus additionally selected photos
    local targetPhoto    = catalog:getTargetPhoto()
    local selectedPhotos = catalog:getTargetPhotos()
    local function getPositionInSelection(targetPhoto, selectedPhotos)
      -- Find the index 'current' of the target photo in set of selectedPhotos
      for i, photo in ipairs(selectedPhotos) do
        if photo == targetPhoto then
         current = i
         break
        end
      end
      return current
    end
    local function needSyncWithFilmStrip()
      local result = false
      local activePhoto = catalog:getTargetPhoto()
      if targetPhoto ~= activePhoto then
        -- plugin and film strip are out of sync (e.g. after a shift-digit shortcut operation)
        -- -> make the film strip's photo the 'next' one for the plugin
        targetPhoto = activePhoto
        result = true
      end
      return result
    end
    local function nextPhoto()
      -- Advance to the next photo of user selection or film strip (if only a single image was selected)
      local function nextPhotoOfSelection()
        current = (current % #selectedPhotos) + 1
        targetPhoto = selectedPhotos[current]
      end
      local function nextPhotoOfFilmStrip()
        local activePhoto = catalog:getTargetPhoto()
        if targetPhoto ~= activePhoto then
          -- plugin and film strip are out of sync (e.g. after a shift-digit shortcut operation)
          -- -> make the film strip's photo the 'next' one for the plugin
          targetPhoto = activePhoto
        else
          -- Advance to the next photo in film strip
          LrSelection.nextPhoto()
          targetPhoto = catalog:getTargetPhoto()
--[[
          -- at the end of film strip jump to first photo on 'next'
          if targetPhoto == activePhoto then
            -- end of film strip -> jump to start
            LrSelection.selectFirstPhoto()
            targetPhoto = catalog:getTargetPhoto()
          end
--]]
        end
      end
      if #selectedPhotos > 1 then
        nextPhotoOfSelection()
      elseif not LR5 then
        nextPhotoOfFilmStrip()
      end
    end
    local function previousPhoto()
      -- Advance to the previous photo of user selection or film strip (if only a single image was selected)
      local function previousPhotoOfSelection()
        current = (current - 2) % #selectedPhotos + 1
        targetPhoto = selectedPhotos[current]
      end
      local function previousPhotoOfFilmStrip()
        local activePhoto = catalog:getTargetPhoto()
        if targetPhoto ~= activePhoto then
          -- plugin and film strip are out of sync (e.g. after a shift-digit shortcut operation)
          -- -> make the film strip's photo the 'next' one for the plugin
          targetPhoto = activePhoto
        else
          -- Advance to the previous photo in film strip
          LrSelection.previousPhoto()
          targetPhoto = catalog:getTargetPhoto()
        end
      end
      if #selectedPhotos > 1 then
        previousPhotoOfSelection()
      elseif not LR5 then
        previousPhotoOfFilmStrip()
      end
    end
    -- To avoid nil pointer errors in case of "dirty" installation (copy new over old files)
    FocusPointPrefs.InitializePrefs(prefs)
    -- Initialize logging, log system level information
    Log.initialize()

    -- Set scale factor for sizing of dialog window
    if WIN_ENV then
      FocusPointPrefs.setDisplayScaleFactor()

    end

    -- Retrieve dimensions of application window before opening the progress window to workaround LR5 SDK issue
    FocusPointDialog.AppWidth, FocusPointDialog.AppHeight = LrSystemInfo.appWindowSize()

    -- Log applicaton level information (includes scale factor and app window size)
    Log.appInfo()
    -- only on WIN (issue #199):
    -- if launched in Develop module switch to Library to enforce that a preview of the image is available
    -- must switch to loupe view because only in this view previews will be rendered
    -- perform module switch as early as possible to give Library time to create a preview if none exists
    if WIN_ENV and not LR5 then
      local done
      LrTasks.startAsyncTask(function()
        local LrApplicationView = import 'LrApplicationView'
        local moduleName = LrApplicationView.getCurrentModuleName()
        if moduleName == "develop" then
          LrApplicationView.switchToModule("library")
          LrApplicationView.showView("loupe")
          switchedToLibrary = true
        end
        done = true
      end)
      -- wait for async task to end
      while not done do LrTasks.sleep(0.2) end
    end

    -- Find the index 'current' of the target photo in set of selectedPhotos
    current = getPositionInSelection(targetPhoto, selectedPhotos)
    -- throw up this dialog as soon as possible as it blocks input which keeps the plugin from potentially launching
    -- twice if clicked on really quickly
    -- let the renderer build the view now and show progress dialog
    repeat

      -- Get logging ready for next photo
      Log.logInfo("FocusPoint", string.rep("=", 72))
      Log.resetErrorsWarnings()

      -- Save link to current photo, eg. as supplementary information in user messages
      FocusPointDialog.currentPhoto = targetPhoto

      -- Make the current photo the only selected one:
      -- otherwise potential flagging operations will apply to all selected photos
      catalog:setSelectedPhotos(targetPhoto, {})
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
        userResponse = LrDialogs.confirm(errorMsg, Utils.getPhotoFileName(), "Continue", "Stop")
        if userResponse == "cancel" then
          -- Stop plugin operation
          return
        else
          -- just skip the main window, continue with next image or retry for the current
          skipMainWindow = true
        end
      end

      if skipMainWindow then
        -- A fatal error has occured for the current image, "Exit" the plugin operation or
        -- "Continue" to next image (in multi-image mode) or repeat (single-image mode)
        nextPhoto()
      else

        -- Open main window
        Log.logInfo("FocusPoint", "Present dialog and information")



        local f = LrView.osFactory()
        local function kbdShortcutHandler()

        local previewText  = ""
        props.shortcutText = ""
          return f:edit_field {
          value = LrView.bind('shortcutText', props),
          width  = 1, height = 1,   -- set tiny dimensions to make the field invisible
          border_enabled = false, -- optionally suppress borders
          immediate = true,
          validate = function(view, text)
          --[[
            Use the validate() function to interpret user keystrokes as shortcuts
            BUT, attention: for each keystoke, validate() is called twice!!
            1. "Preview" validation - non-committal check, to preview the proposed change of text
            2. "Commit"  validation - actual update, to commit the change in the UI
            3. Having two phases is pointless, because 'text' is the same and function result doesn't make a difference
            => need to detect "Preview" vs "Commit" and skip one if this, otherwise shortcuts will be executed twice
                   e.g. 'next' will go the next but one, 'previous' to the penultimate image.
              --]]
            if text == previewText then
              -- call for "Commit" validation -> exit (because shortcut has already been processed in "Preview")
              Log.logDebug("FocusPoint",
                string.format("kbdHandler: Commit called with '%s'. Preview '%s'", text, previewText))
              previewText = ""  -- reset for next Preview
              return true
            else
              -- call for "Preview" validation -> save text and process
              Log.logDebug("FocusPoint",
                  string.format("kbdHandler: Preview called with '%s'. Preview '%s'", text, previewText))
              previewText = text
            end
              -- Get the most recently entered character
              local char = Utf8.last_char(text)
              Log.logDebug("FocusPoint", string.format("kbdHandler: c = '%s'", char))
              if not char or char == "" then return false end
              --------------------------------------------------------------------------------------
              -- Parse character and perform designated operation if it is a shortcut
              -- Tagging operations: flagging / rating / coloring
              -- Note: this is not supported for LR5 (no LrSelection before SDK 6.0)
              --
              -- IMPORTANT:
              -- Do this before parsing other shortcut characters, to prioritize flagging!
              -- E.g. on German-Swiss keyboards, Shift-1 produces '+' which collides with 'next'.
              -- There are other options for the 'next' keyboard shortcut, but not for Shift-1.
              --
              -- ATTENTION:
              -- Shift-digit combinations must not be used when the plugin is run on a single photo !!!
              -- The triggered action causes LR to shift the selection focus to the next photo in the
              -- film strip, while the plugin remains on the photo that was selected at the start.
              --------------------------------------------------------------------------------------
              if prefs.taggingControls and not LR5 then

                -- Pick photo
                if string.find(FocusPointPrefs.kbdShortcutsPick, char, 1, true) then
                  LrSelection.flagAsPick()

                -- Pick photo and advance to next
                elseif string.find(FocusPointPrefs.kbdShortcutsPickNext, char, 1, true) then
                  LrSelection.flagAsPick()
                  LrDialogs.stopModalWithResult(view, "next")

                -- Reject photo
                elseif string.find(FocusPointPrefs.kbdShortcutsReject, char, 1, true) then
                  if LrSelection.getFlag() ~= -1 then   -- reject
                  LrSelection.flagAsReject()
                  end
                  return

                -- Reject photo and advance to next
                elseif string.find(FocusPointPrefs.kbdShortcutsRejectNext, char, 1, true) then
                  if LrSelection.getFlag() ~= -1 then   -- reject
                  LrSelection.flagAsReject()
                  end
                  LrDialogs.stopModalWithResult(view, "next")
                -- Unflag photo
                elseif string.find(FocusPointPrefs.kbdShortcutsUnflag, char, 1, true) then
                LrSelection.removeFlag()
                  return
                -- Unflag photo and advance to next
                elseif string.find(FocusPointPrefs.kbdShortcutsUnflagNext, char, 1, true) then
                  LrSelection.removeFlag()
                  LrDialogs.stopModalWithResult(view, "next")
                end

                -- Input of digits (unshifted/shifted top row keys) depends on intl keyboard layout!
                local digit, shifted = KeyboardLayout.mapTypedCharToDigit(char, prefs.keyboardLayout)
                Log.logDebug("FocusPoint",
                  string.format(
                    "Map char to digit: char '%s', digit '%s', shifted '%s' ", char, digit, shifted))
                if digit then
                  if digit <= 5 then
                    -- Rating
                      LrSelection.setRating(digit)
                  else
                    -- Coloring
                    if     digit == 6 then LrSelection.toggleRedLabel()
                    elseif digit == 7 then LrSelection.toggleYellowLabel()
                    elseif digit == 8 then LrSelection.toggleGreenLabel()
                    elseif digit == 9 then LrSelection.toggleBlueLabel()
                end
                  end
                  if shifted then
                    LrDialogs.stopModalWithResult(view, "next")
                  elseif needSyncWithFilmStrip() then
                    LrDialogs.stopModalWithResult(view, "sync")
                  else
                    return
                end
                end
                end
              --------------------------------------------------------------------------------------
              -- Parse character and perform designated operation if it is a shortcut
              -- Basic operations: Next, Previous, User Manual, Troubleshooting, Check Log, Close
              --------------------------------------------------------------------------------------
              -- Next image
              if string.find(FocusPointPrefs.kbdShortcutsNext, char, 1, true) then
                LrDialogs.stopModalWithResult(view, "next")
              -- Previous image
              elseif string.find(FocusPointPrefs.kbdShortcutsPrev, char, 1, true) then
                LrDialogs.stopModalWithResult(view, "previous")
              -- open user manual
              elseif string.find(FocusPointPrefs.kbdShortcutsUserManual, char, 1, true) then
                LrTasks.startAsyncTask(function() LrHttp.openUrlInBrowser(FocusPointPrefs.urlUserManual) end)

              -- troubleshooting
              elseif string.find(FocusPointPrefs.kbdShortcutsTroubleShooting, char, 1, true) then
                local statusCode = FocusInfo.getStatusCode()
                if statusCode > 1 then
                  LrTasks.startAsyncTask(function()
                    LrHttp.openUrlInBrowser(FocusPointPrefs.urlTroubleShooting .. FocusInfo.status[statusCode].link)
                  end)
                end
              -- check log
              elseif string.find(FocusPointPrefs.kbdShortcutsCheckLog, char, 1, true) then
                if prefs.loggingLevel ~= "NONE" then
                  Utils.openFileInApp(Log.getFileName())
                end

              -- Close
              elseif string.find(FocusPointPrefs.kbdShortcutsClose, char, 1, true)
              or (MAC_ENV and char == ".") then
                LrDialogs.stopModalWithResult(view, "ok")
              end
            end,
          }
            end
        local function fileNameDisplay()
          local s
          if #selectedPhotos > 1 then
            s = Utils.getPhotoFileName(targetPhoto) .. " (" .. current .. "/" .. #selectedPhotos .. ")"
          else
            s = Utils.getPhotoFileName(targetPhoto)
          end
          return s
        end
        local function navigationControls()
        props.clicked = false
          return f:row {
            margin = 0,
            spacing = 0,     -- removes uniform spacing; we control it manually
            f:push_button {
              title = buttonPreviousImage,
              tooltip = "Load previous image from selection (-, <)",
              enabled = #selectedPhotos > 1 or not LR5,
              action = function(button)
                -- Prevent multiple executions - known LrC SDK quirk!
                if props.clicked then return end
                props.clicked = true
                LrDialogs.stopModalWithResult(button, "previous")
              end
          },
            f:spacer { width = 15 }, -- space before the file name
          f:static_text{
              title = fileNameDisplay(),
            },

            f:spacer { width = 5 }, -- space before the next button
            f:push_button {
              title = buttonNextImage,
              tooltip = "Load next image from selection (Space bar, +)",
              enabled = #selectedPhotos > 1 or not LR5,
              margin = 0,
            action = function(button)
                -- Prevent multiple executions - known LrC SDK quirk!
                if props.clicked then return end
                props.clicked = true
                -- set index to next image, wrap around at end of list
                LrDialogs.stopModalWithResult(button, "next")
              end
            },
          }
        end
        local function taggingControls()
          local function setRating (rating)
            if rating == LrSelection.getRating() then
              -- clear existing rating
              rating = 0
            end
            LrSelection.setRating(rating)
          end

          if not prefs.taggingControls or LR5 then
            return f:spacer{width = 10}
          end
          return f:row{
            spacing = 0,
            --------------------------------------------------------------------
            -- Flagging controls
            --------------------------------------------------------------------
            f:static_text {
              title = taggingSymbol("checkMark"),
              text_color = LrColor(0, 0.66, 0),
              font = "<system/bold>",
              tooltip = "Flag as Pick (P)",
              mouse_down = function()
                if LrSelection.getFlag() == 1 then   -- pick
                  LrSelection.removeFlag()
                else
                  LrSelection.flagAsPick()
                end
              end,
            },
            f:static_text {
              title = taggingSymbol("crossMark"),
              text_color = LrColor("red"),
              font = "<system/bold>",
              tooltip = "Set as Rejected (X)",
              mouse_down = function()
                if LrSelection.getFlag() == -1 then  -- reject
                  LrSelection.removeFlag()
                else
                  LrSelection.flagAsReject()
                end
              end,
            },
            --------------------------------------------------------------------
            -- Rating controls
            --------------------------------------------------------------------
            f:spacer { width = 10 },
            f:static_text {
              title = taggingSymbol("digitOne"),
              tooltip = "Set rating (1)",
              mouse_down = function() setRating(1) end,
            },
            f:static_text {
              title = taggingSymbol("digitTwo"),
              tooltip = "Set rating (2)",
              mouse_down = function() setRating(2) end,
            },
            f:static_text {
              title = taggingSymbol("digitThree"),
              tooltip = "Set rating (3)",
              mouse_down = function() setRating(3) end,
            },
            f:static_text {
              title = taggingSymbol("digitFour"),
              tooltip = "Set rating (4)",
              mouse_down = function() setRating(4) end,
            },
            f:static_text {
              title = taggingSymbol("digitFive"),
              tooltip = "Set rating (5)",
              mouse_down = function() setRating(5) end,
            },
            --------------------------------------------------------------------
            -- Color controls
            --------------------------------------------------------------------
            f:spacer { width = 10 },
            f:static_text {
              title = taggingSymbol("colorRed"),
              text_color = LrColor(240/255, 80/255, 80/255),
              tooltip = "Set red label (6)",
              mouse_down = function()
                LrSelection.toggleRedLabel()
              end,
            },
            f:static_text {
              title = taggingSymbol("colorYellow"),
              text_color = LrColor(240/255, 230/255, 0),
              tooltip = "Set yellow label (7)",
              mouse_down = function()
                LrSelection.toggleYellowLabel()
              end,
            },
            f:static_text {
              title = taggingSymbol("colorGreen"),
              text_color = LrColor(90/255, 200/255, 75/255),
              tooltip = "Set green label (8)",
              mouse_down = function()
                LrSelection.toggleGreenLabel()
              end,
            },
            f:static_text {
              title = taggingSymbol("colorBlue"),
              text_color = LrColor(70/255, 135/255, 230/255),
              tooltip = "Set blue label (9)",
              mouse_down = function()
                LrSelection.toggleBlueLabel()
              end,
            },
            f:static_text {
              title = taggingSymbol("colorPurple"),
              text_color = LrColor(120/255, 80/255, 255/255),
              tooltip = "Set purple label",
              mouse_down = function()
                LrSelection.togglePurpleLabel()
              end,
            },
          }
        end
        local function miscControls()
          return f:row{
            spacing = 0,
            f:picture {
              value = _PLUGIN:resourceId("assets/icons/kofi.png")
            },
            f:spacer { width = 5 },
            f:static_text {
              title = "Buy me a coffee! " .. utfLinkSymbol,
              text_color = LrColor("blue"),
              tooltip = "Click to make a donation on Ko-fi",
              immediate = true,
              mouse_down = function(_view)
                LrTasks.startAsyncTask(function() LrHttp.openUrlInBrowser(FocusPointPrefs.urlKofi) end)
              end,
            },
          f:spacer { width = 20 },
          f:spacer{fill_horizontal = 1},
          f:static_text {
            title = "User Manual " .. utfLinkSymbol,
            text_color = LrColor("blue"),
              tooltip = "Click to open user documentation (M)",
            immediate = true,
            mouse_down = function(_view)
              LrTasks.startAsyncTask(function() LrHttp.openUrlInBrowser(FocusPointPrefs.urlUserManual) end)
            end,
          },
          }
        end
        userResponse = LrDialogs.presentModalDialog {
          title = "Focus-Points (Version " .. Utils.getPluginVersion() .. ")",
          contents = FocusPointDialog.createDialog(targetPhoto, photoView, infoView, kbdShortcutHandler()),
          accessoryView = f:row {
            margin_left = 0,
            spacing = 0,     -- removes uniform spacing; we control it manually
            navigationControls(),
            f:spacer { width = 20 },
            taggingControls(),
            f:spacer { width = 20 },
            miscControls(),
            f:spacer { width = 5 },    -- space before 'Close' button
        },
          actionVerb = "Close",
          cancelVerb = "< exclude >",
        }
        if userResponse == "next" then
          nextPhoto()
        elseif userResponse == "previous" then
          previousPhoto()
        end

        -- Clean up
        rendererTable.cleanup()

        -- Close the windows if user clicked <Exit> button or pressed <Esc>
        exitPlugin = (userResponse == "ok") or (userResponse == "cancel")
      end

      -- Clean log for next photo if in AUTO mode
      if not exitPlugin and prefs.loggingLevel == "AUTO" then
        Log.initialize()
        Log.appInfo()
      end
    until exitPlugin

    -- Restore the original selection pf photos when the plugin was started
    if #selectedPhotos > 1 and not LR5 then
      catalog:setSelectedPhotos(targetPhoto, selectedPhotos)
    end
    -- Return to Develop modul if the plugin has been started from there
    if WIN_ENV and switchedToLibrary then
      import 'LrApplicationView'.switchToModule("develop")
    end

  end)
end

LrTasks.startAsyncTask(showDialog)
