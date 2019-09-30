--[[

MIT License

Copyright (c) 2019 ropma

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

--]]

local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrErrors = import 'LrErrors'
local LrTasks = import 'LrTasks'
local LrPrefs = import "LrPrefs"

local prefs = LrPrefs.prefsForPlugin( nil )
local fileName

MogrifyUtils = { }    -- class

-- local helper functions

--[[
-- Call mogirfy with 'params'
-- Raises a LrError in case of an execution error 
--]]
local function mogrifyExecute(params)
  local cmdline = '\"' .. prefs.mogrifyPath .. '\" ' .. params 
  logDebug('mogrifyExecute', cmdline ) 
  local stat = LrTasks.execute( '\"' .. cmdline .. '\"' )
  if stat ~= 0 then
    logError('mogrifyDraw', 'Error calling: ' .. cmdline ) 
    LrErrors.throwUserError("Error calling 'mogirfy.exe' Please check plugin configuration")
  end
end

--[[
-- Export the catalog photo to disk
-- photo: Lr catalog photo
-- xSize: width in pixel of the create temporary photo
-- ySize: height in pixel of the create temporary photo
-- 
-- requestJpegThumbnail treats the size as minimum value, thus the image on the disk maybe larger
--]]
local function exportToDisk(photo, xSize, ySize)
  local thumb = photo:requestJpegThumbnail(xSize, ySize, function(data, errorMsg)
    if data == nil then
      LrErrors.throwUserError("Export to disk failed. No thumbnail data received.")
      logError('exportToDisk', 'No thumbnail data')
    else
      local orgPath = photo:getRawMetadata("path")
      local leafName = LrPathUtils.leafName( orgPath )
      local leafWOExt = LrPathUtils.removeExtension( leafName )
      local tempPath = LrPathUtils.getStandardFilePath( "temp" )
      fileName = LrPathUtils.child( tempPath, leafWOExt .. "-fpoints.jpg" )
      logDebug('exportToDisk', "filename = " .. fileName ) 

      local localFile = io.open(fileName, "w+b")
      localFile:write(data)
      localFile:close()
    end
  end)
end

--[[
-- Resize the disk image to the given ize
-- xSize: width in pixel
-- ySize: height in pixel
--]]
local function mogrifyResize(xSize, ySize)
  local params = '-resize ' .. xSize .. 'x' .. ySize .. ' ' .. fileName
  logDebug('mogrifyResize', params )
  mogrifyExecute(params)
end

--[[
-- Get color and strokewith from the icon name
--]]
local function mapIconToStrokewidthAndColor(name)
  local sw = 2
  local color = string.match(name, 'assets/imgs/corner/(%a+)/.*')
  if string.match(name, 'fat') == 'fat' then
    sw = 3
  end
  return sw, color
end

--[[
-- Build the mogirfy draw parameters base on the focuspointsTable
--]]
local function buildDrawParams(focuspointsTable)
  local para = nil
  local sw = nil
  local color = red
  
  local params = '-fill none '
  for i, fpPoint in ipairs(focuspointsTable) do
    if fpPoint.template.center ~= nil then
      local x = math.floor(tonumber(fpPoint.points.center.x)) 
      local y = math.floor(tonumber(fpPoint.points.center.y))
      para = '-stroke red -fill red -draw \"circle ' ..x .. ',' .. y .. ' ' .. x+3 .. ',' .. y  .. '\" -fill none '
      logDebug('buildCmdLine', '[' .. i .. '] ' .. para ) 
      params = params .. para
    end
    if fpPoint.template.corner ~= nil then
      sw, color = mapIconToStrokewidthAndColor(fpPoint.template.corner.fileTemplate)
      para = '-strokewidth ' .. sw .. ' -stroke ' .. color .. ' '
      local tlx = math.floor(tonumber(fpPoint.points.tl.x)) 
      local tly = math.floor(tonumber(fpPoint.points.tl.y))
      local brx = math.floor(tonumber(fpPoint.points.br.x))
      local bry = math.floor(tonumber(fpPoint.points.br.y))
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
      logDebug('buildCmdLine', '[' .. i .. '] ' .. para .. ' ' .. fpPoint.template.corner.fileTemplate) 
      params = params .. para
    end
  end
  params = params .. fileName
  return params
end

--[[
-- Create a temprory disk impage for the given Lightroom catalog photo. 
-- photo: Lr catalog photo
-- xSize: width in pixel of the create temporary photo
-- ySize: height in pixel of the create temporary photo
--]]
function MogrifyUtils.createDiskImage(photo, xSize, ySize)
  logInfo('MogrifyUtils.createDiskImage', photo:getFormattedMetadata( 'fileName' ) .. ' ' .. xSize .. ' ' .. ySize ) 
  exportToDisk(photo, xSize, ySize)
  mogrifyResize(xSize, ySize)
  return fileName
end


--[[ 
-- Draw the focus poins bases on focuspointsTable (see 'DefaultPointRenderer.prepareRendering' for adescription of the table)
--]]
function MogrifyUtils.drawFocusPoints(focuspointsTable)
  local params = buildDrawParams(focuspointsTable)  
  mogrifyExecute(params)
end

--[[ 
-- Deletes the temporary file (created by 'MogrifyUtils.exportToDisk') 
-- Raises a LrError in case that the deletion fails
--]]
function MogrifyUtils.cleanup()
  if fileName ~= nil then
    resultOK, errorMsg  = LrFileUtils.delete( fileName )
    if errorMsg ~= nil then
      logError('MogrifyUtils.cleanup', errMsg)
      LrErrors.throwUserError("Deletion of temporary file failed: " ..  errMsg)
    end
  end
end