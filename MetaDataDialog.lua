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