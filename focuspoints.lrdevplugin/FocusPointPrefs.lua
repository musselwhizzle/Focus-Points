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
local LrDialogs = import "LrDialogs"

local bind = LrView.bind

FocusPointPrefs = {}

function FocusPointPrefs.genSectionsForBottomOfDialog( viewFactory, p )
  local prefs = LrPrefs.prefsForPlugin( nil )
  local enableMogrifySettings =  true

  -- on windows platform the usage of mogrify is mandatory as overlay rendering of focus frames does not work
  if (WIN_ENV) then
   prefs.mogrifyUsage = true
   enableMogrifySettings = false
  end
  
  if prefs.mogrifyPath == nil or prefs.mogrifyPath == '' then
    prefs.mogrifyPath = "mogrify.exe" 
  end 

  return {
  {
    title = "Logging",
    viewFactory:row {
      bind_to_object = prefs,
      spacing = viewFactory:control_spacing(),
      viewFactory:popup_menu {
        title = "Logging level",
        value = bind 'loggingLevel',
        items = {
          { title = "None", value = "NONE"},
          { title = "Error", value = "ERROR"},
          { title = "Warn", value = "WARN"},
          { title = "Info", value = "INFO"},
          { title = "Debug", value = "DEBUG"},
        }
      },
    },
  },
  {
    title = "Options",
    viewFactory:row {
      bind_to_object = prefs,
      spacing = viewFactory:control_spacing(),
      viewFactory:checkbox {
        fill = 1,
        title = "Use Mogrify for Focus Point rendering. Mandatory on Windows platforms.",
        enabled = enableMogrifySettings,
        value = bind 'mogrifyUsage',
      },
    },
    viewFactory:row {
      spacing = viewFactory:control_spacing(),
      viewFactory:column {
        spacing = viewFactory:control_spacing(),
        viewFactory:static_text {
          title = 'mogrify:',
        }
      },
      viewFactory:column {
        spacing = viewFactory:control_spacing(),
        bind_to_object = prefs,
        viewFactory:edit_field {
          fill = 1,
          width_in_chars = 60,
          value = bind 'mogrifyPath',
        },
      },
      viewFactory:column {
        spacing = viewFactory:control_spacing(),
        viewFactory:push_button {
          title = "Browse",
          enable = true,
          action = function ()
            local path = LrDialogs.runOpenPanel(
              { title = "Select Mogrify Executable" },
              { canChooseFiles = true },
              { canChooseDirectories = false },
              { canCreateDirectories = false },
              { allowsMultipleSelection = false },
              { fileTypes = '*.EXE' } )
            if path then
              prefs.mogrifyPath = path[1]
            end
          end
        },
      },
    },
  },
  }
end
