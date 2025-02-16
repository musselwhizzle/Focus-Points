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
local LrView = import 'LrView'
local LrPrefs = import 'LrPrefs'

require "Utils"

FocusPointDialog = {}

FocusPointDialog.PhotoWidth  = 0
FocusPointDialog.PhotoHeight = 0


local prefs = LrPrefs.prefsForPlugin( nil )

function FocusPointDialog.getFocusPointDimens(targetPhoto)
  return FocusPointDialog.PhotoWidth * prefs.focusBoxSize,
         FocusPointDialog.PhotoWidth * prefs.focusBoxSize
end


function FocusPointDialog.calculatePhotoDimens(targetPhoto)
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local dimens = targetPhoto:getFormattedMetadata("croppedDimensions")
  local w, h = parseDimens(dimens)

  -- store for use with drawing variable sized focus boxes around 'focus pixels'
  FocusPointDialog.PhotoWidth  = w
  FocusPointDialog.PhotoHeight = h

  local contentWidth = appWidth * .75
  local contentHeight = appHeight * .75

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

function FocusPointDialog.createDialog(targetPhoto, photoView, infoView)
  -- local photoWidth, photoHeight = FocusPointDialog.calculatePhotoDimens(targetPhoto)
  local myView
  local f = LrView.osFactory()

  -- view for photo with focus point visualization
  local column1 = f:column {
    photoView
  }

  -- view for textual information on image, camera settings and AF information
  if infoView ~= nil then
    local column2 = f:column {
      infoView,
    }
    local row = f:row {
      column1, column2
    }
    myView = f:view {
      row,
    }
  else
    -- if infoView is not (yet) supported for a specific make, only include the photoView
    myView = f:view {
      column1,
    }
  end

  return myView

end
