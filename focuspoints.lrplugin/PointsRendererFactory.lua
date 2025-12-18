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

require 'AppleDelegates'
require 'CanonDelegates'
require 'DefaultDelegates'
require 'DefaultPointRenderer'
require 'ExifUtils'
require 'FujifilmDelegates'
require 'Log'
require 'NikonDelegates'
require 'NikonDuplicates'
require 'OlympusDelegates'
require 'PanasonicDelegates'
require 'PentaxDelegates'
require 'PointsUtils'
require 'SonyDelegates'


PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(photo)

  local cameraMake = photo:getFormattedMetadata("cameraMake")
  local cameraModel = photo:getFormattedMetadata("cameraModel")

  if (cameraMake == nil or cameraModel == nil) then
    -- we map both to unknown and deal with the consequences on upper levels
    cameraMake  = "unknown"
    cameraModel = "unknown"
    Log.logError("PointsRendererFactory", "Unknown camera make / model")
  else
    cameraMake = string.lower(cameraMake)
    cameraModel = string.lower(cameraModel)
  end

  local mapped
  Log.logInfo("PointsRendererFactory", "Camera Make: " .. cameraMake)
  Log.logInfo("PointsRendererFactory", "Camera Model: " .. cameraModel)

  -- normalize the camera names. Pentax can be called multiple things
  if (string.find(cameraMake, "ricoh imaging company", 1, true)
          or (string.find(cameraMake, "pentax", 1, true) and cameraMake ~= "pentax")
          -- since K-3, tested with K-3, K-1, K-1 Mark II. cameraMake is too unspecific, therefor we test against cameraModel as well
          or (string.find(cameraMake, "ricoh", 1, true))) then -- @FIXME and string.find(cameraModel, "pentax", 1, true))) then
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
  if string.find(cameraMake, "om digital solutions", 1, true)
  or string.find(cameraMake, "olympus", 1, true) then
    cameraMake = "olympus"
    mapped = true
  end

  if mapped then
    Log.logDebug("PointsRendererFactory", "Camera Make (after map): " .. cameraMake)
    Log.logDebug("PointsRendererFactory", "Camera Model (after map): " .. cameraModel)
  end

  -- for use in make specific Delegates, to avoid repeatedly normalization
  DefaultDelegates.cameraMake  = cameraMake
  DefaultDelegates.cameraModel = cameraModel

  -- initialize the function pointers for handling the current image (in a series)
  if (cameraMake == "apple") then
    DefaultPointRenderer.funcModelSupported  = AppleDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = AppleDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = AppleDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = AppleDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = nil
    DefaultPointRenderer.funcGetShootingInfo = AppleDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = AppleDelegates.getFocusInfo

  elseif (cameraMake == "canon") then
    DefaultPointRenderer.funcModelSupported  = CanonDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = CanonDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = CanonDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = CanonDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = CanonDelegates.getImageInfo
    DefaultPointRenderer.funcGetShootingInfo = CanonDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = CanonDelegates.getFocusInfo

  elseif (cameraMake == "fujifilm") then
    DefaultPointRenderer.funcModelSupported  = FujifilmDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = FujifilmDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = FujifilmDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = FujifilmDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = FujifilmDelegates.getImageInfo 
    DefaultPointRenderer.funcGetShootingInfo = FujifilmDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = FujifilmDelegates.getFocusInfo 
                                                                              
  elseif (cameraMake == "nikon corporation"  ) then
    DefaultPointRenderer.funcModelSupported  = NikonDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = NikonDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = NikonDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = NikonDelegates.getAfPoints     
    DefaultPointRenderer.funcGetImageInfo    = NikonDelegates.getImageInfo    
    DefaultPointRenderer.funcGetShootingInfo = NikonDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = NikonDelegates.getFocusInfo    

  elseif (cameraMake == "olympus") then
    DefaultPointRenderer.funcModelSupported  = OlympusDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = OlympusDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = OlympusDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = OlympusDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = OlympusDelegates.getImageInfo
    DefaultPointRenderer.funcGetShootingInfo = OlympusDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = OlympusDelegates.getFocusInfo

  elseif (string.find(cameraMake, "panasonic", 1, true)) then
    DefaultPointRenderer.funcModelSupported  = PanasonicDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = PanasonicDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = PanasonicDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = PanasonicDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = nil
    DefaultPointRenderer.funcGetShootingInfo = PanasonicDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = PanasonicDelegates.getFocusInfo

  elseif (cameraMake == "pentax") then
    DefaultPointRenderer.funcModelSupported  = PentaxDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = PentaxDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = PentaxDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = PentaxDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = nil
    DefaultPointRenderer.funcGetShootingInfo = PentaxDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = PentaxDelegates.getFocusInfo

  elseif (cameraMake == "sony") then
    DefaultPointRenderer.funcModelSupported  = SonyDelegates.modelSupported
    DefaultPointRenderer.funcMakerNotesFound = SonyDelegates.makerNotesFound
    DefaultPointRenderer.funcManualFocusUsed = SonyDelegates.manualFocusUsed
    DefaultPointRenderer.funcGetAfPoints     = SonyDelegates.getAfPoints
    DefaultPointRenderer.funcGetImageInfo    = SonyDelegates.getImageInfo
    DefaultPointRenderer.funcGetShootingInfo = SonyDelegates.getShootingInfo
    DefaultPointRenderer.funcGetFocusInfo    = SonyDelegates.getFocusInfo

  else
    -- Unknown camera maker
    DefaultPointRenderer.funcModelSupported  = nil
    DefaultPointRenderer.funcMakerNotesFound = nil
    DefaultPointRenderer.funcManualFocusUsed = nil
    DefaultPointRenderer.funcGetAfPoints     = nil
    DefaultPointRenderer.funcGetImageInfo    = nil
    DefaultPointRenderer.funcGetShootingInfo   = nil
    DefaultPointRenderer.funcGetFocusInfo    = nil
  end

  DefaultDelegates.metaData = ExifUtils.readMetaDataAsTable(photo)

  return DefaultPointRenderer
end
