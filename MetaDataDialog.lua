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
    title = "Will place information here",
  }
  
  local scrollView = viewFactory:scrolled_view {
    myText, 
    width = appWidth * .7,
    height = appHeight *.7,
  }
  
  MetaDataDialog.contents = scrollView
  MetaDataDialog.textView = myText
  
end