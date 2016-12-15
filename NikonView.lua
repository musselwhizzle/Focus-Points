local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

NikonView = {}


function NikonView.createView(targetPhoto, metaData, developSettings)
  
  local viewFactory = LrView.osFactory()
  local myBox = viewFactory:catalog_photo {
    width = 200, 
    height = 200,
    photo = targetPhoto,
    frame_width = 10,
    background_color = LrColor("blue"),
  }
  
  local boxView = viewFactory:view {
    myBox, 
    margin_left = 40,
    margin_top = 30,
  }
  
  return boxView
  
end