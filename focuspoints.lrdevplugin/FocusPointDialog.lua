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
local LrApplication = import 'LrApplication'
local LrView = import 'LrView'
local LrColor = import 'LrColor'
require "Utils"

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
  }
  local myText = viewFactory:static_text {
    title = "",
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