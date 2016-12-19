require "DefaultPointRenderer"
require "CameraNikonD7200"

PointsRendererFactory = {}

function PointsRendererFactory.createRenderer(cameraStr)
  return DefaultPointRenderer
end

function PointsRendererFactory.getFocusPoints(cameraStr)
  if (cameraStr == "Nikon") then
    return CameraNikonD7200.focusPoints
  else 
    return nil
  end
end

function PointsRendererFactory.getFocusPointDimens(cameraStr)
  if (cameraStr == "Nikon") then
    return CameraNikonD7200.focusPointDimens
  else 
    return nil
  end
end 