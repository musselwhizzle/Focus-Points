local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'
local LrStringUtils = import "LrStringUtils"

require "MetaDataDialog"
require "Utils"

local function showDialog()
  LrFunctionContext.callWithContext("showDialog", function(context)
  
  MetaDataDialog.create()
  local catalog = LrApplication.activeCatalog()
  local targetPhoto = catalog:getTargetPhoto()
  
  LrTasks.startAsyncTask(function(context)
    --https://forums.adobe.com/thread/359790
    LrFunctionContext.callWithContext("a function", function(dialogContext)
      local dialogScope = LrDialogs.showModalProgressDialog {
        title = "Loading Data",
        caption = "Reading Metadata", 
        width = 200,
        cannotCancel = false,
        functionContext = dialogContext, 
      }
      dialogScope:setIndeterminate()
  
      local metaData = readMetaData(targetPhoto)
      metaData = filterInput(metaData)
      local column1, column2 = splitForColumns(metaData)
      
      dialogScope:done() -- dialog is persisting behind the view dialog. it doesn't dismiss. urgh
      dialogScope:cancel()
      MetaDataDialog.labels.title = column1
      MetaDataDialog.data.title = column2
      --MetaDataDialog.labels.title = "parts: "  .. parts[1].key
      end
    )
    
    LrDialogs.presentModalDialog {
      title = "Metadata display",
      resizable = true, 
      cancelVerb = "< exclude >",
      actionVerb = "OK",
      contents = MetaDataDialog.contents
    }
    
    end 
  )
  
  
end)
end
showDialog()

function splitForColumns(metaData)
  local parts = createParts(metaData)
  local labels = ""
  local values = ""
  for k in pairs(parts) do
    local l = parts[k].key
    local v = parts[k].value
    if (l == nill) then l = "" end
    if (v == nill) then v = "" end
    l = LrStringUtils.trimWhitespace(l)
    v = LrStringUtils.trimWhitespace(v)
    
    labels = labels .. l .. "\r"
    values = values .. v .. "\r"
  end
  return labels, values
  
end

function createParts(metaData)
  local parts = {}
  local num = 0;
  for i in string.gmatch(metaData, "[^\\\n]+") do 
    log("i = " .. i)
    p = splitText(i, ":")
    if (p ~= nill) then
      parts[num] = p
      num = num+1
    end
  end
  return parts
end