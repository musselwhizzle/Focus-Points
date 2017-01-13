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

function MetaDataDialog.create(column1, column2, column1Length, column2Length, numLines)
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local viewFactory = LrView.osFactory()
  
  -- these props are needed on windows. on mac, they make the columns a bit larger than needed 
  if (MAC_ENV) then
    column1Length = nil
    column2Length = nil
  end
  
  local myText = viewFactory:static_text {
    title = column1,
    selectable = true, 
    width_in_chars = column1Length,
    height_in_lines = numLines, 
    wrap = false,
  }
  
  local myText2 = viewFactory:static_text {
    title = column2,
    selectable = true, 
    width_in_chars = column2Length,
    height_in_lines = numLines, 
    wrap = false,
  }
  
  local row = viewFactory:row {
    myText, myText2, 
    margin_left = 5, 
  }
  
  local scrollView = viewFactory:scrolled_view {
    row, 
    width = appWidth * .7,
    height = appHeight *.7,
  }
  
  return scrollView
  
end