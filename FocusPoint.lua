local LrSystemInfo = import 'LrSystemInfo'
local LrFunctionContext = import 'LrFunctionContext'
local LrApplication = import 'LrApplication'
local LrDialogs = import 'LrDialogs'
local LrView = import 'LrView'
local LrColor = import 'LrColor'
local LrTasks = import 'LrTasks'
local LrFileUtils = import 'LrFileUtils'
local LrPathUtils = import 'LrPathUtils'

require "FocusPointDialog"
require "PointsRendererFactory"

local function showDialog()
  LrFunctionContext.callWithContext("showDialog", function(context)
      
      local catalog = LrApplication.activeCatalog()
      local targetPhoto = catalog:getTargetPhoto()
      
      LrTasks.startAsyncTask(function(context) 
        if (targetPhoto:checkPhotoAvailability() == false) then
          LrDialogs.message("Photo is not available. Make sure hard drives are attached and try again", nil, nil)
          return
        end
          
          
        local photoW, photoH = FocusPointDialog.calculatePhotoDimens(targetPhoto)
        local rendererTable = PointsRendererFactory.createRenderer("Nikon")
        if (rendererTable == nil) then
          LrDialogs.message("Unknown camera type. Can not display", nil, nil)
          return
        end
        local focusPoints = PointsRendererFactory.getFocusPoints("Nikon")
        if (focusPoints == nil) then
          LrDialogs.message("Unknown focus points. Can not display", nil, nil)
          return
        end
        local focusPointDimens = PointsRendererFactory.getFocusPointDimens("Nikon")
        if (focusPoints == nil) then
          LrDialogs.message("Unknown focus point dimensions. Can not display", nil, nil)
          return
        end
        local overlay = rendererTable.createView(targetPhoto, photoW, photoH, focusPoints, focusPointDimens)
        FocusPointDialog.createDialog(targetPhoto, overlay)
        
        -- display the contents
        LrDialogs.presentModalDialog {
          title = "My Picture Viewer Dialog",
          cancelVerb = "< exclude >",
          actionVerb = "OK",
          contents = FocusPointDialog.display
        }
      end)
    end
  )
  
end

showDialog()



