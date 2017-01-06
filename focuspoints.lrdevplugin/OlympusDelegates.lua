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

--[[
  A collection of delegate functions to be passed into the DefaultPointRenderer when
  the camera is Olympus
  E-M1, E-M1 II metadata is like:
  
    AF Areas                        : (118,32)-(137,49)
    AF Point Selected               : (50%,15%) (50%,15%)

    Where:
        AF Point Selected appears to be % of photo from upper left corner (X%, Y%)
        AF Areas appears to be focus box as coordinates relative to 0..255 from upper left corner (x,y)
        
        
  2017-01-05 - MJ - E-M1 family only
  
--]]

local LrStringUtils = import "LrStringUtils"
require "Utils"

OlympusDelegates = {}

--[[
-- metaData - the metadata as read by exiftool
--]]
function OlympusDelegates.getOlympusAfPoints(photo, metaData)
    local cameraModel = photo:getFormattedMetadata("cameraModel")
    
  if (cameraModel == "E-M1") or (cameraModel == "E-M1MarkII" )then
    local focusPoint = ExifUtils.findValue(metaData, "AF Point Selected")
    local focusX, focusY = string.match(focusPoint, "%((%d+)%%,(%d+)")
    if focusX == nil or focusY == nil then return nil end
    log ("Focus %: " .. focusX .. "," ..  focusY .. "," .. focusPoint  )
  
    local dimens = photo:getFormattedMetadata("dimensions")
    orgPhotoW, orgPhotoH = parseDimens(dimens)
    if orgPhotoW == nil or orgPhotoH == nil then return nil end
    log ( "orgPhotoW: " .. orgPhotoW .. " orgPhotoH: ".. orgPhotoH )
  
    log ( "Focus px: " .. tonumber(orgPhotoW) * tonumber(focusX)/100 .. "," .. tonumber(orgPhotoH) * tonumber(focusY)/100)
 
    if orgPhotoW >= orgPhotoH then
        return  tonumber(orgPhotoW) * tonumber(focusX)/100, tonumber(orgPhotoH) * tonumber(focusY)/100
    else
        return  tonumber(orgPhotoW) * tonumber(focusY)/100, tonumber(orgPhotoH) * tonumber(focusX)/100
    end
    
  end
end
