local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

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
  
      --[[
      local metaData = readMetaData(targetPhoto)
      metaData = filterInput(metaData)
      parts = {}
      for i in string.gmatch(str, "[^\n]+") do 
        p = splitText(i, ":")
        if (p ~= nill) then
          parts[#parts] = p
        end
      end--]]
      
      dialogScope:done() -- dialog is persisting behind the view dialog. it doesn't dismiss. urgh
      dialogScope:cancel()
      MetaDataDialog.textView.title = metaData
      --MetaDataDialog.textView.title = "key = " .. parts[0].key 
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