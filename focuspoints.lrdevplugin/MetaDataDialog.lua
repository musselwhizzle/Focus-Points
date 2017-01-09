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

MetaDataDialog = {}

--[[
-- Create the MetaDataDialog view and returns it
-- targetPhoto - the LrPhoto to be displayed
-- overlayView - the view containing all the need elements to be drawn over the photo (focus points, etc)
--]]
function MetaDataDialog.createDialog(keywords, values, keywords_max_length, values_max_length, line_count)
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local viewFactory = LrView.osFactory()

  local view = viewFactory:scrolled_view {
    viewFactory:row {
      viewFactory:static_text {
        title = keywords,
        selectable = true,
        width_in_chars = keywords_max_length,
        height_in_lines = line_count,
        wrap = false
      },

      viewFactory:static_text {
        title = values,
        selectable = true,
        width_in_chars = values_max_length,
        height_in_lines = line_count,
        wrap = false
      },

      margin_left = 5,
    },

    width = appWidth * .7,
    height = appHeight *.7,
  }

  return view
end
