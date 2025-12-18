--[[
  Copyright 2019 Whizzbang Inc, ropma

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

local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'
local LrPrefs = import "LrPrefs"

require "Utils"
require "Log"


MogrifyUtils = { }    -- class

local fileName
local mogrifyPath
local resizeParams

local prefs = LrPrefs.prefsForPlugin( nil )

-- Map base colors for focus box to specific color tones to be used by Mogrify
MogrifyUtils.colorMap = {
  red     = "red",
  green   = "green1",
  blue    = "blue",
  yellow  = "yellow",
  white   = "white",
  grey    = "grey",
  black   = "black",
  orange  = "orange",
}

--[[
-- Call mogrify with 'params'
-- Raises a LrError in case of an execution error
--]]
local function mogrifyExecute(photo, params, script)
  if mogrifyPath == nil then
    mogrifyPath = LrPathUtils.child( _PLUGIN.path, "bin" )
    mogrifyPath = LrPathUtils.child( mogrifyPath, "ImageMagick" )
    mogrifyPath = LrPathUtils.child(mogrifyPath, "magick.exe")
  end

  local scriptName
  local cmdline = '\"' .. mogrifyPath .. '\" '
  if script then
    scriptName = createMagickScript(photo, params)
    cmdline = cmdline .. '-script ' .. '\"' .. scriptName .. '\"'
  else
    cmdline = cmdline .. 'mogrify ' .. params
  end
  Log.logDebug("Mogrify", cmdline )
  local rc = LrTasks.execute( '\"' .. cmdline .. '\"' )
  if rc ~= 0 then
    Log.logError("Mogrify", 'Error calling: ' .. cmdline .. ", return code " .. rc)
    LrErrors.throwUserError(string.format(
     "%s\n\nFATAL error calling 'mogrify.exe' (rc=%s)\nPlease check logfile",
      getPhotoFileName(photo), rc))
  end
  if script then
    if prefs.loggingLevel ~= "DEBUG" then
      -- keep temporary script file for log level DEBUG
      if LrFileUtils.exists(scriptName) and not LrFileUtils.delete(scriptName) then
        Log.logWarn("Mogrify", "Error deleting mogrify script file " .. scriptName)
      end
    end
  end

end


--[[
-- Export the catalog photo to disk
-- photo: Lr catalog photo
-- xSize: width in pixel of the create temporary photo
-- ySize: height in pixel of the create temporary photo
--
-- requestJpegThumbnail treats the size as minimum value, thus the image on the disk maybe larger
--
-- Note: in LrC 14 (at least on WIN) this function fails on the first call for an image.
-- Analysis and proposal for a fix by John R. Ellis (LR SDK luminary on Adobe forums):
--
-- requestJpegThumbnail() appears to call the callback synchronously if the requested thumbnail
-- is in an internal cache. Otherwise, it returns immediately and calls the callback asynchronously
-- after the thumbnail is generated and loaded into the cache, which could take anywhere from
-- 0.01 seconds to a couple seconds if the photo has to be re-rendered.
-- In order to make sure the thumbnail has been written to file before proceeding with the next
-- steps, exportToDisk() should busy wait until the callback is invoked.
-- photo:getRawMetadata() has to be executed outside the callback, because this method "yields"
-- which is not allowed in a no-yielding context (asynchronous call of callback)
--]]
local function exportToDisk(photo, xSize, ySize)
  local done = false
  local orgPath = photo:getRawMetadata("path")
  local _thumb = photo:requestJpegThumbnail(xSize, ySize, function(data, _errorMsg)
    if data == nil then
      local errorText = "FATAL error: Lightroom preview for image not available"
      Log.logError('Mogrify', errorText)
      LrErrors.throwUserError(
        string.format("%s\n\n%s", getPhotoFileName(photo), errorText))
    else
      local leafName = LrPathUtils.leafName( orgPath )
      local leafWOExt = LrPathUtils.removeExtension( leafName )
      local tempPath = LrPathUtils.getStandardFilePath( "temp" )
      fileName = LrPathUtils.child( tempPath, leafWOExt .. "-fpoints.jpg" )
      local success, errorCode = pcall(function()
        local localFile = io.open(fileName, "w+b")
        if localFile then
          localFile:write(data)
          localFile:close()
        end
      end)
      if not success then
        local errorText = string.format("FATAL error creating image file for Mogrify at %s (rc=%s)",
                                        fileName, errorCode)
        Log.logError('Mogrify', errorText)
        LrErrors.throwUserError(
          string.format("%s\n\n%s", getPhotoFileName(photo), errorText))
      else
        Log.logInfo('Mogrify', "Image exported to " .. fileName )
      end
    end
    done = true
  end)
  while not done do LrTasks.sleep(0.2) end  -- busy wait for async callback to complete
end

--[[
-- Resize the disk image to the given ize
-- xSize: width in pixel
-- ySize: height in pixel
-- Note: This was a separate call to Mogrify earlier.
-- Now it's executed along with the draw commands to save one extra call and a little bit of runtime
--]]
local function mogrifyResize(_photo, xSize, ySize)
  resizeParams = '-resize ' .. math.floor(xSize) .. 'x' .. math.floor(ySize) .. ' '
end


--[[
-- Get color and strokewith from the icon name
--]]
local function mapIconToStrokewidthAndColor(name)
  -- strokewidth:
  local sw = 2
  if string.match(name, 'fat') == 'fat' then
    sw = 3
  end
  -- color:
  -- if filename contains color placeholder, fill with user-defined color setting
  local nameWithColor = string.format(name, prefs.focusBoxColor, "0")
  local color = string.match(nameWithColor, 'assets/imgs/corner/(%a+)/.*')
  if not color then
    color = string.match(nameWithColor, 'assets/imgs/center/(%a+)/.*')
  end
  -- map base color to Mogrify specific tone
  color = MogrifyUtils.colorMap[color]
  return sw, color
end

--[[
-- Build the mogrify draw parameters base on the focuspointsTable
--]]
local function buildDrawParams(focuspointsTable)
  local para
  local sw
  local color
  local params = '-fill none '

  if (focuspointsTable ~= nil) then
    for i, fpPoint in ipairs(focuspointsTable) do
      if fpPoint.template.center ~= nil then
        sw, color = mapIconToStrokewidthAndColor(fpPoint.template.center.fileTemplate)
        local x = math.floor(tonumber(fpPoint.points.center.x))
        local y = math.floor(tonumber(fpPoint.points.center.y))
        para = '-stroke ' .. color .. ' -fill ' .. color .. ' -draw \"circle ' ..x .. ',' .. y .. ' ' .. x+3 .. ',' .. y  .. '\" -fill none '
        Log.logDebug("Mogrify", "Building command line: " .. '[' .. i .. '] ' .. para )
        params = params .. para
      end
      if fpPoint.template.corner ~= nil then
        sw, color = mapIconToStrokewidthAndColor(fpPoint.template.corner.fileTemplate)
        para = '-strokewidth ' .. sw .. ' -stroke ' .. color .. ' '
        local tlx = math.floor(tonumber(fpPoint.points.tl.x))
        local tly = math.floor(tonumber(fpPoint.points.tl.y))
        local brx = math.floor(tonumber(fpPoint.points.br.x))
        local bry = math.floor(tonumber(fpPoint.points.br.y))
        -- normalize
        if tlx > brx and ( fpPoint.rotation == 0 or fpPoint.rotation == 360) then
          local x = tlx
          tlx = brx
          brx = x
        end
        if fpPoint.rotation == 0 or fpPoint.rotation == 360 then
          para = para .. '-draw \"roundRectangle ' .. tlx .. ',' .. tly .. ' ' .. brx .. ',' .. bry .. ' 1,1\" '
        else
          local trx = math.floor(tonumber(fpPoint.points.tr.x))
          local try = math.floor(tonumber(fpPoint.points.tr.y))
          local blx = math.floor(tonumber(fpPoint.points.bl.x))
          local bly = math.floor(tonumber(fpPoint.points.bl.y))
          para = para .. '-draw \"polyline ' .. trx .. ',' .. try .. ' ' .. tlx .. ',' .. tly .. ' '
                  .. blx .. ',' .. bly .. ' ' .. brx .. ',' .. bry .. ' ' .. trx .. ',' .. try .. '\" '
        end
        Log.logDebug("Mogrify", "Building command line: " .. '[' .. i .. '] ' .. para .. ' ' .. fpPoint.template.corner.fileTemplate)
        params = params .. para
      end
    end
    return params
  else
    return nil
  end
end


--[[
-- Create a temprory disk impage for the given Lightroom catalog photo.
-- photo: Lr catalog photo
-- xSize: width in pixel of the create temporary photo
-- ySize: height in pixel of the create temporary photo
--]]
function MogrifyUtils.createDiskImage(photo, xSize, ySize)
  exportToDisk (photo, xSize, ySize)
  mogrifyResize(photo, xSize, ySize)
  return fileName
end


--[[
-- Draw the focus poins bases on focuspointsTable (see 'DefaultPointRenderer.prepareRendering' for adescription of the table)
--]]
function MogrifyUtils.drawFocusPoints(photo, focuspointsTable)
  local params = buildDrawParams(focuspointsTable)
  if params ~= nil then
    params = resizeParams .. params
    Log.logInfo("Mogrify", "Resizing image, drawing focus points and visualization frames")
    mogrifyExecute(photo, params, true)
  else
    Log.logInfo("Mogrify", "Nothing to draw - no focus points or visualization frames found")
  end
end


--[[
-- Creates a temporay script file for Magick. Returns the name of the temp file
--]]
function createMagickScript(photo, params)
  local scriptName = getTempFileName()

  local success, _errorCode = pcall(function()
    local file = io.open(scriptName, "w")
    if file then
      file:write('-read \"' .. fileName .. '\"', "\n")
      file:write(params, "\n")
      file:write('-write \"' .. fileName .. '\"', "\n")
      file:close()
    end
  end)
  if not success then
    local errorText = 'FATAL error creating script file ' .. scriptName
    Log.logError('Mogrify', errorText)
    LrErrors.throwUserError(
      string.format("%s\n\n%s", getPhotoFileName(photo), errorText))
  end
  return scriptName
end


--[[
-- Deletes the temporary file (created by 'MogrifyUtils.exportToDisk')
--]]
function MogrifyUtils.cleanup()
  if LrFileUtils.exists(fileName) then
    local _resultOK, errorMsg = LrFileUtils.delete( fileName )
    if errorMsg ~= nil then
      Log.logWarn('Mogrify', "Error deleting mogrify temp file " .. fileName .. ": " .. errorMsg)
    end
  end
end
