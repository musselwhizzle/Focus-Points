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

function MetaDataDialog.create()

  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local viewFactory = LrView.osFactory()
  
  local myText = viewFactory:static_text {
    title = "Will place label here",
    selectable = true, 
  }
  
  local myText2 = viewFactory:static_text {
    title = "Will place data here",
    selectable = true, 
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
  
  MetaDataDialog.contents = scrollView
  MetaDataDialog.labels = myText
  MetaDataDialog.data = myText2
  
end