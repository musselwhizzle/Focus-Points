return {
  -- http://notebook.kulchenko.com/zerobrane/debugging-lightroom-plugins-zerobrane-studio-ide
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