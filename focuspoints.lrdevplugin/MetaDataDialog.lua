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
local LrStringUtils = import 'LrStringUtils'

MetaDataDialog = {}

function MetaDataDialog.create(values)

  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local v = LrView.osFactory()
  
  local rows = {}
  
  for k in pairs(values) do
    local key = values[k].key
    local value = values[k].value
    if (key == nill) then key = "" end
    if (value == nill) then value = "" end
    key = LrStringUtils.trimWhitespace(key)
    value = LrStringUtils.trimWhitespace(value)
    values[k].title = key .. " = " .. value
  end
  
  local view = v:simple_list {
    items = values,
    width = appWidth * .7,
    height = appHeight * .7,
  }
  
  MetaDataDialog.contents = view
  
end