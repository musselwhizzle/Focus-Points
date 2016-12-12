local LrMobdebug = import 'LrMobdebug'
local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

isDebug = true

exiftool = LrPathUtils.child( _PLUGIN.path, "bin" )
exiftool = LrPathUtils.child(exiftool, "exiftool")
exiftool = LrPathUtils.child(exiftool, "exiftool")

function startDebug()
  if isDebug then
    LrMobdebug.start()
  end
end
function getExifCmd(targetPhoto) 
  
  local path = targetPhoto:getRawMetadata("path")
  local metaDataFile = LrPathUtils.removeExtension(path)
  metaDataFile = metaDataFile .. "-metadata.txt"
  
  local cmd = exiftool .. " -a -u -g1 '" .. path .. "' > '" .. metaDataFile .. "'";
  return cmd, metaDataFile
  
end

function readMetaData(targetPhoto)
  local cmd, metaDataFile = getExifCmd(targetPhoto)
  LrTasks.execute(cmd)
  local fileInfo = LrFileUtils.readFile(metaDataFile)
  LrFileUtils.delete(metaDataFile)
  return fileInfo
end

function filterInput(str)
  --local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=-\\[\\]~`]", "?");
  -- FIXME: doesn't strip - or ] correctly
  local result = string.gsub(str, "[^a-zA-Z0-9 ,\\./;'\\<>\\?:\\\"\\{\\}\\|!@#\\$%\\^\\&\\*\\(\\)_\\+\\=\\-\\[\\\n\\\t~`-]", "?");
  return result
end

function splitText(str, delim)
  if str == nill then return nill end
  local index = string.find(str, delim)
  if index == nill then
    return nill
  end
  local r = {}
  r.key = string.sub(str, 0, index-1)
  r.value = string.sub(str, index+1, #str)
  return r
end