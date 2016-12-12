local LrSystemInfo = import 'LrSystemInfo'
local LrApplication = import 'LrApplication'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

UiDialog = {}
UiDialog.catalogPhoto = nil
UiDialog.myText = nil
UiDialog.column = nil
UiDialog.focusView = nil

function UiDialog.createDialog(targetPhoto) 
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local viewFactory = LrView.osFactory()
  local myPhoto = viewFactory:catalog_photo {
    width = appWidth - 200, 
    height = appHeight - 200,
    photo = targetPhoto,
    background_color = LrColor("magenta")
  }
  local myText = viewFactory:static_text {
    width = appWidth - 200, 
    title = "Will place information here",
  }
      
  local column = viewFactory:column {
    myPhoto, myText,
  }
  
  local myBox = viewFactory:catalog_photo {
    width = 200, 
    height = 200,
    photo = targetPhoto,
    frame_width = 10,
    background_color = LrColor("red"),
  }
  
  local boxView = viewFactory:view {
      myBox, 
      margin_left = 40,
      margin_top = 30,
    }
  
  local myView = viewFactory:view {
    column, boxView , 
    place = 'overlapping', 
  }
  

  UiDialog.catalogPhoto = myPhoto
  UiDialog.myText = myText
  UiDialog.display = myView
  UiDialog.focusIcon = myBox
  UiDialog.focusView = boxView

end