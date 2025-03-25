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

--[[
  Factory for creating the focus point renderer and getting the focus points.
--]]

require "DefaultPointRenderer"
require "PointsUtils"
require "DefaultDelegates"
require "CanonDelegates"
require "FujifilmDelegates"
require "NikonDelegates"
require "NikonDuplicates"
require "OlympusDelegates"
require "PanasonicDelegates"
require "AppleDelegates"
require "PentaxDelegates"
require "SonyDelegates"
require "ExifUtils"
require "Log"



local LrErrors = import 'LrErrors'

PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(photo)

  local cameraMake = photo:getFormattedMetadata("cameraMake")
  local cameraModel = photo:getFormattedMetadata("cameraModel")

  if (cameraMake == nil or cameraModel == nil) then
    -- we map both to unknown and deal with the consequences on upper levels
    cameraMake  = "unknown"
    cameraModel = "unknown"
    Log.logError("PointsRenderFactory", "Unknown camera make / model")
  else
    cameraMake = string.lower(cameraMake)
    cameraModel = string.lower(cameraModel)
  end

  local mapped
  Log.logInfo("PointsRenderFactory", "Camera Make: " .. cameraMake)
  Log.logInfo("PointsRenderFactory", "Camera Model: " .. cameraModel)

  -- normalize the camera names. Pentax can be called multiple things
  if (string.find(cameraMake, "ricoh imaging company", 1, true)
          or (string.find(cameraMake, "pentax", 1, true) and cameraMake ~= "pentax")
          -- since K-3, tested with K-3, K-1, K-1 Mark II. cameraMake is too unspecific, therefor we test against cameraModel as well
          or (string.find(cameraMake, "ricoh", 1, true) and string.find(cameraModel, "pentax", 1, true))) then
    cameraMake = "pentax"
    mapped = true
  end

  -- Nikon
  if (string.find(cameraMake, "nikon", 1, true)) then
    cameraMake = "nikon corporation"
    -- some cameras have the same mapping as other camera
    -- check the cameraModel and switch it to a known map if it's a duplicate
    local duplicateModel = NikonDuplicates[cameraModel]
    if (duplicateModel ~= nil) then
      cameraModel = duplicateModel
    end
    mapped = true
  end

  -- Olympus and OM Digital share the same exact makernotes structures
  if (string.find(cameraMake, "om digital solutions", 1, true)
          or (string.find(cameraMake, "olympus", 1, true)) and cameraMake ~= "olympus") then
    cameraMake = "olympus"
    mapped = true
  end

  if mapped then
    Log.logDebug("PointsRenderFactory", "Camera Make (after map): " .. cameraMake)
    Log.logDebug("PointsRenderFactory", "Camera Model (after map): " .. cameraModel)
  end

  -- for use in make specific Delegates, to avoid repeatedly normalization
  DefaultDelegates.cameraMake  = cameraMake
  DefaultDelegates.cameraModel = cameraModel

  -- initialize the function pointers for handling the current image (in a series)
  if (cameraMake == "fujifilm") then
    DefaultPointRenderer.funcGetAfPoints   = FujifilmDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = FujifilmDelegates.getImageInfo
    DefaultPointRenderer.funcGetCameraInfo = FujifilmDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = FujifilmDelegates.getFocusInfo

  elseif (cameraMake == "canon") then
    DefaultPointRenderer.funcGetAfPoints   = CanonDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = CanonDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = CanonDelegates.getFocusInfo

  elseif (cameraMake == "apple") then
    DefaultPointRenderer.funcGetAfPoints   = AppleDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = AppleDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = AppleDelegates.getFocusInfo

  elseif (cameraMake == "sony") then
    DefaultPointRenderer.funcGetAfPoints   = SonyDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = SonyDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = SonyDelegates.getFocusInfo

  elseif (cameraMake == "nikon corporation") then
    DefaultPointRenderer.funcGetAfPoints   = NikonDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = NikonDelegates.getImageInfo
    DefaultPointRenderer.funcGetCameraInfo = NikonDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = NikonDelegates.getFocusInfo

  elseif (cameraMake == "olympus") then
    DefaultPointRenderer.funcGetAfPoints   = OlympusDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = OlympusDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = OlympusDelegates.getFocusInfo

  elseif (string.find(cameraMake, "panasonic", 1, true)) then
    DefaultPointRenderer.funcGetAfPoints   = PanasonicDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = PanasonicDelegates.getCameraInfo
    DefaultPointRenderer.funcGetFocusInfo  = PanasonicDelegates.getFocusInfo

  elseif (cameraMake == "pentax") then
    DefaultPointRenderer.funcGetAfPoints   = PentaxDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = nil
    DefaultPointRenderer.funcGetFocusInfo  = PentaxDelegates.getFocusInfo

  else
    -- Unknown camera maker or model
    DefaultPointRenderer.funcGetAfPoints   = DefaultPointRenderer.getAfPointsUnknown
    DefaultPointRenderer.funcGetImageInfo  = nil
    DefaultPointRenderer.funcGetCameraInfo = DefaultPointRenderer.getCameraInfoUnknown
    DefaultPointRenderer.funcGetFocusInfo  = DefaultPointRenderer.getFocusInfoUnknown
  end

  DefaultDelegates.metaData = ExifUtils.readMetaDataAsTable(photo)

  return DefaultPointRenderer
end
