--[[
  Copyright 2016 JWhizzbang Inc

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
local LrView = import "LrView"
local LrPrefs = import "LrPrefs"
local LrShell = import "LrShell"

local bind = LrView.bind

require "Utils"

FocusPointPrefs = {}

-- Scaling values for size of 'pixel focus' box, relative to focus point window size
FocusPointPrefs.focusBoxSize = { 0, 0.04, 0.1 }

-- Indices to access scaling values in focusBoxSize table
FocusPointPrefs.focusBoxSizeSmall =  1
FocusPointPrefs.focusBoxSizeMedium = 2
FocusPointPrefs.focusBoxSizeLarge =  3
FocusPointPrefs.initfocusBoxSize  =  FocusPointPrefs.focusBoxSizeMedium


function FocusPointPrefs.genSectionsForBottomOfDialog( viewFactory, p )
  local prefs = LrPrefs.prefsForPlugin( nil )

  -- Initialize settings on first run after installation of plugin
  if not prefs.screenScaling then	prefs.screenScaling = 1.0     end
  if not prefs.focusBoxSize  then	prefs.focusBoxSize  = FocusPointPrefs.focusBoxSize[FocusPointPrefs.initfocusBoxSize] end
  if not prefs.focusBoxColor then	prefs.focusBoxColor = "red"    end
  if not prefs.loggingLevel  then	prefs.loggingLevel  = "NONE"   end

  return {
    {
      title = "Screen Scaling (only for Windows)",
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "Scaling",
          value = bind 'screenScaling',
          items = {
            { title = "100%", value = 1.0  },
            { title = "115%", value = 0.87 },
            { title = "125%", value = 0.8  },
            { title = "150%", value = 0.67 },
            { title = "175%", value = 0.57 },
            { title = "200%", value = 0.5  },
          }
        },
      },
    },
    {
      title = "Viewing Options",
      viewFactory:row {
        bind_to_object = prefs,
        viewFactory:popup_menu {
          title = "focusBoxSize",
          value = bind "focusBoxSize",
          width = 65,
          items = {
            { title = "Small",  value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeSmall ] },
            { title = "Medium", value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeMedium] },
            { title = "Large",  value = FocusPointPrefs.focusBoxSize[FocusPointPrefs.focusBoxSizeLarge ] },
          }
        },
        viewFactory:static_text {
          title = " Size of focus box for 'focus pixel' points ",
          -- alignment = 'left',
        },
      },
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "focusBoxColor",
          value = bind "focusBoxColor",
          width = 65,
          items = {
            { title = "Red",   value = "red" },
            { title = "Green", value = "green" },
            { title = "Blue",  value = "blue" },
          }
        },
        viewFactory:static_text {
          title = 'Color for in-focus points',
          -- alignment = 'left',
        },
      }
    },
    {
      title = "Logging",
      viewFactory:row {
        bind_to_object = prefs,
        spacing = viewFactory:control_spacing(),
        viewFactory:popup_menu {
          title = "Logging level",
          value = bind 'loggingLevel',
          items = {
            { title = "None", value = "NONE" },
            { title = "Error", value = "ERROR" },
            { title = "Warn", value = "WARN" },
            { title = "Info", value = "INFO" },
            { title = "Debug", value = "DEBUG" },
          }
        },
        viewFactory:static_text {
          title = 'Plugin log:',
          alignment = 'right',
          fill_horizontal = 1,
        },
        viewFactory:push_button {
          title = "Show file",
          action = function()
            LrShell.revealInShell(getlogFileName())
          end,
        },
      },
    },
    {
      title = "Acknowledgements",
      viewFactory:row {
        fill_horizontal = 1,
        viewFactory:column {
          fill_horizontal = 1,
--          spacing = viewFactory:control_spacing(),
          viewFactory:static_text {
            font = "<system/bold>",
            title = 'ImageMagick Studio LLC'
          },
          viewFactory:spacer{ height = 5 },
          viewFactory:static_text {
            title = 'This plugin uses ImageMagick mogrify'
          }
        },
        viewFactory:column {
          viewFactory:static_text {
            title = "https://imagemagick.org/index.php"
          },
        },
      },
      viewFactory:spacer{fill_horizontal = 1},
      viewFactory:row {
        fill_horizontal = 1,
        viewFactory:column {
          fill_horizontal = 1,
--          spacing = viewFactory:control_spacing(),
          viewFactory:static_text {
            font = "<system/bold>",
            title = 'ExifTool'
          },
          viewFactory:spacer{ height = 5 },
          viewFactory:static_text {
            title = "This plugin relies on Phil Harvey's ExifTool to read and decode metadata"
          }
        },
        viewFactory:column {
          viewFactory:static_text {
            title = "https://exiftool.org/"
          },
        },
      },
    }
  }
end
