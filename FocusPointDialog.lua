local LrSystemInfo = import 'LrSystemInfo'
local LrApplication = import 'LrApplication'
local LrView = import 'LrView'
local LrColor = import 'LrColor'

FocusPointDialog = {}
FocusPointDialog.myText = nil
FocusPointDialog.display = nil

function FocusPointDialog.calculatePhotoDimens(targetPhoto)
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local dimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local w, h = parseDimens(dimens)
  local viewFactory = LrView.osFactory()
  local contentW = appWidth * .7
  local contentH = appHeight * .7
  
  local photoW
  local photoH
  if (w > h) then
    photoW = math.min(w, contentW)
    photoH = h/w * photoW
  else 
    photoH = math.min(h, contentH)
    photoW = w/h * photoH
  end
  return photoW, photoH
  
end

function FocusPointDialog.createDialog(targetPhoto, overlayView) 
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local photoW, photoH = FocusPointDialog.calculatePhotoDimens(targetPhoto)
  
  local viewFactory = LrView.osFactory()
  local myPhoto = viewFactory:catalog_photo {
    width = photoW, 
    height = photoH,
    photo = targetPhoto,
    background_color = LrColor("magenta")
  }
  local myText = viewFactory:static_text {
    title = "Will place information here",
  }
      
  local column = viewFactory:column {
    myPhoto, myText,
  }
  
  local myView = viewFactory:view {
    column, overlayView, 
    place = 'overlapping', 
  }
  
  FocusPointDialog.myText = myText
  FocusPointDialog.display = myView

end