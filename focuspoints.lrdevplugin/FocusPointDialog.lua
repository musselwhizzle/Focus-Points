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

local LrSystemInfo = import 'LrSystemInfo'
local LrApplication = import 'LrApplication'
local LrView = import 'LrView'
local LrColor = import 'LrColor'
local LrPrefs = import 'LrPrefs'

require "Utils"

FocusPointDialog = {}
local prefs = LrPrefs.prefsForPlugin( nil )

function FocusPointDialog.calculatePhotoDimens(targetPhoto)
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local dimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local w, h = parseDimens(dimens)
  local contentWidth = appWidth * .7
  local contentHeight = appHeight * .7

  if (WIN_ENV == true) then
    if prefs.screenScaling == nil or prefs.screenScaling == 0 then
   	  prefs.screenScaling = 1
    end
    logDebug('calculatePhotoDimens', prefs.screenScaling ) 
    contentWidth = contentWidth * prefs.screenScaling
    contentHeight = contentHeight * prefs.screenScaling
  end
  
  local photoWidth
  local photoHeight
  if (w > h) then
    photoWidth = math.min(w, contentWidth)
    photoHeight = h/w * photoWidth
    if photoHeight > contentHeight then
        photoHeight = math.min(h, contentHeight)
        photoWidth = w/h * photoHeight
    end
  else
    photoHeight = math.min(h, contentHeight)
    photoWidth = w/h * photoHeight
    if photoWidth > contentWidth then
        photoWidth = math.min(w, contentWidth)
        photoHeight = h/w * photoWidth
    end
  end
  return photoWidth, photoHeight

end

function FocusPointDialog.createDialog(targetPhoto, photoView)
  local photoWidth, photoHeight = FocusPointDialog.calculatePhotoDimens(targetPhoto)
  local myView = nil

  -- temporary for dev'ing
  local developSettings = targetPhoto:getDevelopSettings()
  
  local viewFactory = LrView.osFactory()
  local myText = viewFactory:static_text {
    title = "" -- "CL " .. developSettings["CropLeft"] .. ", CT " .. developSettings["CropTop"] .. ", Angle " .. developSettings["CropAngle"],
  }
      
  local column = viewFactory:column {
    photoView, myText,
  }
  
  myView = viewFactory:view {
    column,  
  }
  return myView
  
end
