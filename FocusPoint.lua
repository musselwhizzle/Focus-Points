local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

require "UiDialog"
require "Utils"

local function showDialog()
  LrFunctionContext.callWithContext("showDialog", function(context)
      
      local catalog = LrApplication.activeCatalog()
      local targetPhoto = catalog:getTargetPhoto()
      UiDialog.createDialog(targetPhoto)
     
      LrTasks.startAsyncTask(function(context)
          developSettings = targetPhoto:getDevelopSettings()
          UiDialog.myText.title = "CropLight " .. developSettings["CropLeft"] ..",CropRight" .. developSettings["CropRight"] .. ", CropBottom " .. developSettings["CropBottom"] .. ", CropTop " .. developSettings["CropTop"]
          
          UiDialog.focusView.margin_left = 300 -- doesn't set. i guess it's only during creation
          
          local path = targetPhoto:getRawMetadata("path")
          UiDialog.myText.title = path
          
          local metaDataFile = LrPathUtils.removeExtension(path)
          metaDataFile = metaDataFile .. "-metadata.txt"
          
          
          local exiftool = LrPathUtils.child( _PLUGIN.path, "bin" )
          exiftool = LrPathUtils.child(exiftool, "exiftool")
          exiftool = LrPathUtils.child(exiftool, "exiftool")
        
          local cmd = exiftool .. " -a -u -g1 '" .. path .. "' > '" .. metaDataFile .. "'";
          
          
          LrTasks.execute(cmd)
          fileInfo = LrFileUtils.readFile(metaDataFile)
          LrFileUtils.delete(metaDataFile)
          UiDialog.myText.title = fileInfo
          
          
      end
      )
      
      
      LrDialogs.presentModalDialog {
        title = "My Picture Viewer Dialog",
        contents = UiDialog.display
      }
      
    end
  )
  
end

showDialog()