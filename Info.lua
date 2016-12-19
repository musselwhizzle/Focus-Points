return {
  -- http://notebook.kulchenko.com/zerobrane/debugging-lightroom-plugins-zerobrane-studio-ide
  -- tail -f ~/Documents/libraryLogger.log
	LrSdkVersion = 6.0,
  LrSdkMinimumVersion = 6.0,

	LrToolkitIdentifier = 'com.thewhizzbang.focuspoint',
	LrPluginName = "Focus Point",
	
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

}

--[[ 
KNOWN BUGS: 
 1. LrPhoto.getDevelopmentSettings()["Orientation"] return nill. I have no way of knowing if the photo
        was rotated in development mode
 2. Orientation must be determined from the metadata. The metdata does not tell me if the camera was upside down
        e.g. rotation of 180 degrees. It only tells me normal, 90, or 270
--]]