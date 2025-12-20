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

local LrView = import 'LrView'

require "Utils"
require "Log"
require "FocusPointPrefs"

FocusPointDialog = {}

FocusPointDialog.PhotoWidth  = 0
FocusPointDialog.PhotoHeight = 0
FocusPointDialog.AppWidth    = 0
FocusPointDialog.AppHeight   = 0

FocusPointDialog.currentPhoto = nil


function FocusPointDialog.calculatePhotoDimens(photo)

  -- Retrieve photo dimensions
  local dimens = photo:getFormattedMetadata("croppedDimensions")
  local w, h = parseDimens(dimens)
  Log.logInfo("FocusPointDialog", string.format(
    "Image: %s (%s x %s)", photo:getFormattedMetadata('fileName'), w, h))

  -- Store for use with drawing variable sized focus boxes around 'focus pixels'
  FocusPointDialog.PhotoWidth  = w
  FocusPointDialog.PhotoHeight = h

  local windowSize = FocusPointPrefs.getWindowSize()
  local contentWidth  = FocusPointDialog.AppWidth  * windowSize
  local contentHeight = FocusPointDialog.AppHeight * windowSize

  if WIN_ENV then
    local scalingLevel = FocusPointPrefs.getDisplayScaleFactor()
    contentWidth  = contentWidth  * scalingLevel
    contentHeight = contentHeight * scalingLevel
  end
  
  local photoWidth
  local photoHeight
  if (w > h) then
    photoWidth = math.min(  (w), contentWidth)
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

  return math.floor(photoWidth), math.floor(photoHeight)

end


function FocusPointDialog.createDialog(_photo, photoView, infoView, kbdShortcutInput)
  local f = LrView.osFactory()

  return f:view {
    f:column {
       f:row {
         kbdShortcutInput,
       },
       f:row {
         f:column { photoView },
         f:column { fill_vertical = 1, infoView },
       }
    }
  }
end
