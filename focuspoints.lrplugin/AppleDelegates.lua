----[[
--  Copyright 2016 Whizzbang Inc
--
--  Licensed under the Apache License, Version 2.0 (the "License");
--  you may not use this file except in compliance with the License.
--  You may obtain a copy of the License at
--
--     http://www.apache.org/licenses/LICENSE-2.0
--
--  Unless required by applicable law or agreed to in writing, software
--  distributed under the License is distributed on an "AS IS" BASIS,
--  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
--  See the License for the specific language governing permissions and
--  limitations under the License.
----]]

--[[----------------------------------------------------------------------------
  AppleDelegates.lua

  Purpose of this module:
  A collection of delegate functions to be passed into the DefaultPointRenderer
  when the camera is Apple (iPhone, iPad):

  - funcModelSupported:    Does this plugin support the camera model?
  - funcMakerNotesFound:   Does the photo metadata include maker notes?
  - funcManualFocusUsed:   Was the current photo taken using manual focus?
  - funcGetAfPoints:       Provide data for visualizing focus points, faces etc.
  - funcGetImageInfo:      Provide specific information to be added to the 'Image Information' section.
  - funcGetShootingInfo:   Provide specific information to be added to the 'Shooting Information' section.
  - funcGetFocusInfo:      Provide the information to be entered into the 'Focus Information' section.
------------------------------------------------------------------------------]]
local AppleDelegates = {}

-- Imported LR namespaces
local LrView                = import  'LrView'

-- Required Lua definitions
local DefaultDelegates      = require 'DefaultDelegates'
local DefaultPointRenderer  = require 'DefaultPointRenderer'
local ExifUtils             = require 'ExifUtils'
local FocusInfo             = require 'FocusInfo'
local Log                   = require 'Log'
local _strict               = require 'strict'
local Utils                 = require 'Utils'

-- Tag indicating that makernotes / AF section exists
local metaKeyAfInfoSection        = "Maker Note Version"

-- AF-relevant tags
local metaKeySubjectArea          = "Subject Area"
local metaKeyFocusDistanceRange   = "Focus Distance Range"
local metaKeyAfPerformance        = "AF Performance"
local metaKeyAfStable             = "AF Stable"
local metaKeyAfConfidence         = "AF Confidence"
local metaKeyAfMeasuredDepth      = "AF Measured Depth"
local metaKeyImageWidth           = "Image Width"
local metaKeyImageHeight          = "Image Height"
local metaKeyExifImageWidth       = "Exif Image Width"
local metaKeyExifImageHeight      = "Exif Image Height"

-- Image and Shooting Information relevant tags
local metaKeyCameraType           = "Camera Type"
local metaKeyImageCaptureType     = "Image Capture Type"
local metaKeyOISMode              = "OIS Mode"

--[[----------------------------------------------------------------------------
  public table
  getAfPoints(table photo, table metadata)

  Retrieve the autofocus points from the metadata of the photo.
------------------------------------------------------------------------------]]
function AppleDelegates.getAfPoints(photo, metadata)

  local result = {
    pointTemplates = DefaultDelegates.pointTemplates,
    points = {
    }
  }

  FocusInfo.focusPointsDetected = ExifUtils.decodeXmpMWGRegions(result, metadata)

  if not FocusInfo.focusPointsDetected then
    -- Only we we don't have a focus area yet - avoid double focus frames!

    -- For Apple iPhone, these three tags need to be present to calculate proper focus point:
    local subjectAreaStr  = ExifUtils.findValue(metadata, metaKeySubjectArea)
    local exifImageWidth  = ExifUtils.findValue(metadata, metaKeyExifImageWidth)
    local exifImageHeight = ExifUtils.findValue(metadata, metaKeyExifImageHeight)

    if not (exifImageWidth and exifImageHeight) then
      Log.logError("Apple",
        string.format("Required tags '%s' / '%s' not found.",
          metaKeyExifImageWidth, metaKeyExifImageHeight))
      Log.logWarn("Apple", FocusInfo.msgImageFileNotOoc)
      FocusInfo.makerNotesFound = false
      return nil
    end

    -- Determining size and proper orientation can be tricky for iPhones
    -- for RAWs, there is only ExifImageWidth/ExifImageHeight and the (proper) "Orientation"
    -- for JPGs, orientation is baked in ImageWidth/ImageHeight, i.e. for a capture in portrait format
    --           the values are reversed wrt to ExifImageWidth/ExifImageHeight.
    --           "Orientation" tag is always "Horizontal (normal)"
    -- So, to determine proper scaling factors, we better fetch consistent information from Lightroom
    local originalWidth, originalHeight,
          cropWidth, cropHeight = DefaultPointRenderer.getNormalizedDimensions(photo, metadata)
    local xScale = cropWidth  / originalWidth
    local yScale = cropHeight / originalHeight

    -- Do we have a subject area tag to convert into a focus point?
    if subjectAreaStr then

      Log.logInfo("Apple",
        string.format("Focus point tag '%s' found: '%s'",
          metaKeySubjectArea, subjectAreaStr))

      local subjectArea = Utils.split(subjectAreaStr, ", ")
      if subjectArea and #subjectArea == 4 then
        local x = subjectArea[1] * xScale
        local y = subjectArea[2] * yScale
        local w = subjectArea[3] * xScale
        local h = subjectArea[4] * yScale

        if w > 0 and h > 0 then
          table.insert(result.points, {
            pointType = DefaultDelegates.POINTTYPE_AF_FOCUS_BOX,
            x = x,
            y = y,
            width = w,
            height = h
          })

          Log.logInfo("Apple",
            string.format("Focus point detected at [x=%s, y=%s, w=%s, h=%s]",
            math.floor(x), math.floor(y), math.floor(w), math.floor(h)))

          FocusInfo.focusPointsDetected = true

        else
          Log.logWarn("Apple",
           string.format("Unexpected format for '%s' tag: %s",
           metaKeySubjectArea, subjectAreaStr))
        end
      else
        Log.logWarn("Apple",
          string.format("Unexpected format for '%s' tag: %s",
          metaKeySubjectArea, subjectAreaStr))
      end
    else
      Log.logWarn("Apple",
        string.format("'%s' tag not found.", metaKeySubjectArea))
    end
  end
  return result
end

--[[----------------------------------------------------------------------------
  private table
  addInfo(string title, string key, table props, table metadata)

  Generate a row element to be added to the current view container.
------------------------------------------------------------------------------]]
local function addInfo(title, key, props, metadata)

  -- Helper function to create and populate the property corresponding to metadata key
  local function populateInfo(key)
    local value
    if type(key) == "string" then
      value = ExifUtils.findValue(metadata, key)
    else
      -- type(key) == "table"
      value = ExifUtils.findFirstMatchingValue(metadata, key)
    end
    if (value == nil) then
      props[key] = ExifUtils.metaValueNA
    else
      -- everything else is the default case!
      props[key] = value
    end
  end

  -- Avoid issues with implicite followers that do not exist for all models
  if not key then return nil end

  -- Create and populate property with designated value
  populateInfo(key)

  -- Check if there is (meaningful) content to add
  if props[key] and props[key] ~= ExifUtils.metaValueNA then
    -- compose the row to be added
    return FocusInfo.addRow(title, props[key])
  else
    -- we won't display any "N/A" entries - return empty row
    return FocusInfo.emptyRow()
  end
end

--[[----------------------------------------------------------------------------
  public boolean
  modelSupported(string model)

  Indicate whether the given camera model is supported or not.
------------------------------------------------------------------------------]]
function AppleDelegates.modelSupported(_model)
  -- #TODO no test samples could not be found for iPhone 4 and older models
  -- so, for the time being assume it's always "true"
  return true
end

--[[----------------------------------------------------------------------------
  public boolean
  makerNotesFound(table photo, table metadata)

  Check if the metadata for the current photo includes a 'Makernotes' section.
------------------------------------------------------------------------------]]
function AppleDelegates.makerNotesFound(photo, metadata)

  local tag, result
  local model = photo:getFormattedMetadata("cameraModel")
  local generation = tonumber(string.match(model, "^iPhone%s+(%d+)"))

  if generation >= 6 then
    -- 'Maker Note' tag exists only in iPhone 6 and later models
    tag = metaKeyAfInfoSection
  else
    -- at least iPhone 5 has 'Subject Area' tag in EXIF:EXIFIfd section
    tag = metaKeySubjectArea
  end

  result = ExifUtils.findValue(metadata, tag)
  if not result then
    Log.logWarn("Apple",
      string.format("Tag '%s' not found", tag))
  end

  return (result ~= nil)
end

--[[----------------------------------------------------------------------------
  public boolean
  manualFocusUsed(table photo, table metadata)

  Indicate whether the photo was taken using manual focus.
------------------------------------------------------------------------------]]
function AppleDelegates.manualFocusUsed(_photo, _metadata)
  -- #TODO Apple supports tag 'ImageCaptureType' that can be '11 = Manual Focus'
  -- #TODO what does that mean for the plugin imaplementation ??
  return false
end

--[[----------------------------------------------------------------------------
  public table
  function getImageInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Image Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function AppleDelegates.getImageInfo(_photo, _props, _metadata)
  local imageInfo
  return imageInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getShootingInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to append maker-specific entries to the
  'Shooting Information' section, if applicable; otherwise, returns an empty column.
------------------------------------------------------------------------------]]
function AppleDelegates.getShootingInfo(_photo, props, metadata)
  local f = LrView.osFactory()
  local shootingInfo
  -- append maker specific entries to the "Shooting Information" section
  shootingInfo = f:column {
    fill = 1,
    spacing = 2,
    addInfo("Image Capture Type", metaKeyImageCaptureType, props, metadata),
    addInfo("OIS Mode"          , metaKeyOISMode         , props, metadata),
    addInfo("CameraType"        , metaKeyCameraType      , props, metadata),
  }
  return shootingInfo
end

--[[----------------------------------------------------------------------------
  public table
  function getFocusInfo(table photo, table props, table metadata)

  Called by FocusInfo.createInfoView to fetch the items in the 'Focus Information'
  section (which is entirely maker-specific).
------------------------------------------------------------------------------]]
function AppleDelegates.getFocusInfo(_photo, props, metadata)
  local f = LrView.osFactory()

  -- Create the "Focus Information" section
  local focusInfo = f:column {
      fill = 1,
      spacing = 2,
--    addInfo("Focus Distance Range", metaKeyFocusDistanceRange, props, metadata),
--    addInfo("AF Measured Depth"  , metaKeyAfMeasuredDepth    , props, metadata),
      addInfo("AF Stable"     , metaKeyAfStable      , props, metadata),
--    addInfo("AF Confidence"      , metaKeyAfConfidence       , props, metadata),
--    addInfo("AF Performance"     , metaKeyAfPerformance      , props, metadata),
  }
  return focusInfo
end

return AppleDelegates -- ok
