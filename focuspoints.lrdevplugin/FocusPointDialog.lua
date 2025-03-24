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
local LrView       = import 'LrView'

require "Utils"
require "Log"


FocusPointDialog = {}

FocusPointDialog.PhotoWidth  = 0
FocusPointDialog.PhotoHeight = 0

FocusPointDialog.currentPhoto = nil
FocusPointDialog.errorsEncountered = nil


function FocusPointDialog.calculatePhotoDimens(photo)
  local appWidth, appHeight = LrSystemInfo.appWindowSize()
  local dimens = photo:getFormattedMetadata("croppedDimensions")
  local w, h = parseDimens(dimens)

  -- store for use with drawing variable sized focus boxes around 'focus pixels'
  FocusPointDialog.PhotoWidth  = w
  FocusPointDialog.PhotoHeight = h

  local contentWidth  = appWidth  * .8
  local contentHeight = appHeight * .8

  if WIN_ENV then
    local scalingLevel = FocusPointPrefs.getDisplayScaleFactor()
    contentWidth  = contentWidth  * scalingLevel
    contentHeight = contentHeight * scalingLevel
  end

  Log.logInfo("FocusPointDialog",
    string.format("Image: %s (%sx%s)", photo:getFormattedMetadata('fileName'), w, h))

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


function FocusPointDialog.createDialog(photo, photoView, infoView)
  local myView
  local f = LrView.osFactory()

  -- view for photo with focus point visualization
  local column1 = f:column {
    photoView
  }

  -- view for textual information on image, camera settings and AF information
  if infoView ~= nil then
    local column2 = f:column { fill_vertical = 1,
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
