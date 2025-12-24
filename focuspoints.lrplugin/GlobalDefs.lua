--[[
  Copyright Karsten Gieselmann (capricorn8)

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

--[[
  Central place for global variables to support a hierarchical module structure w/o cyclic dependencies
--]]

-- Imported LR namespaces
local LrSystemInfo     = import  'LrSystemInfo'

local GlobalDefs = {}

GlobalDefs.currentPhoto = ""

-- Store LR windows size WxH at time of start
-- Workaround for LR5 SDK issue, which changes appWindowSize to size of progress window
GlobalDefs.appWidth, GlobalDefs.appHeight = LrSystemInfo.appWindowSize()

-- Determines if the plugin is run in develop/debug mode
GlobalDefs.DEBUG = _PLUGIN.path:sub (-12) == ".lrdevplugin"

return GlobalDefs
