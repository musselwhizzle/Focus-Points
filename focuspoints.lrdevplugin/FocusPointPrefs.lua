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

  if prefs.screenScaling == nil then
	prefs.screenScaling = 1.0
  end
  
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
          { title = "100%", value = 1.0},
          { title = "125%", value = 0.8},
          { title = "150%", value = 0.67},
          { title = "175%", value = 0.57},  
          { title = "200%", value = 0.5},
        }
      },
    },
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
    title = "Acknowledgements",
    viewFactory:row {
      fill_horizontal = 1,
      viewFactory:column {
        fill_horizontal = 1,
        spacing = viewFactory:control_spacing(),
        viewFactory:static_text {
          font = "<system/bold>",
          title = 'ImageMagick Studio LLC'
        },
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
  },
  }
end
