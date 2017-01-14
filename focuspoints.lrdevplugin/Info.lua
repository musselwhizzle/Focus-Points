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

return {
  -- http://notebook.kulchenko.com/zerobrane/debugging-lightroom-plugins-zerobrane-studio-ide
  -- tail -f ~/Documents/libraryLogger.log
	LrSdkVersion = 5.0,
  LrSdkMinimumVersion = 5.0,

	LrToolkitIdentifier = 'com.thewhizzbang.focuspoint',
	LrPluginName = "Focus Point Viewer",
	
	LrLibraryMenuItems = { 
    {
      title = "Show Focus Point",
      file = "FocusPoint.lua",
      enabledWhen = "photosSelected"  
    }, 
    
    {
      title = "Show Metadata",
      file = "ShowMetadata.lua",
      enabledWhen = "photosSelected"  
    },
  },

	VERSION = { major=0, minor=0, revision=1, build=1, },

  LrPluginInfoProvider = 'FocusPointsInfoProvider.lua',
}

--[[ 
KNOWN BUGS: 
 1. LrPhoto.getDevelopmentSettings()["Orientation"] return nil. I have no way of knowing if the photo
        was rotated in development mode
 2. Orientation must be determined from the metadata. The metdata does not tell me if the camera was upside down
        e.g. rotation of 180 degrees. It only tells me normal, 90, or 270
--]]