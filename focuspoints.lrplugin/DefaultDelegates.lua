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
  A collection of delegate functions to be passed into the DefaultPointRenderer.
--]]

DefaultDelegates = {}

DefaultDelegates.metaData             = nil

DefaultDelegates.cameraMake           = nil
DefaultDelegates.cameraModel          = nil

DefaultDelegates.POINTTYPE_AF_FOCUS_PIXEL       = "af_focus_pixel"        -- Small box around focus point pixel
DefaultDelegates.POINTTYPE_AF_FOCUS_PIXEL_BOX   = "af_focus_pixel_box"    -- Medium/large box with center dot
DefaultDelegates.POINTTYPE_AF_FOCUS_BOX         = "af_focus_box"          -- Box according to EXIF subject area
DefaultDelegates.POINTTYPE_AF_FOCUS_BOX_DOT     = "af_focus_box_dot"      -- same, but with center dot
DefaultDelegates.POINTTYPE_AF_FOCUS_BOX_PRIMARY = "af_focus_box_primary"  -- same, but with black center dot
DefaultDelegates.POINTTYPE_AF_SELECTED          = "af_selected"           -- AF-point is selected but not in focus
DefaultDelegates.POINTTYPE_AF_INACTIVE          = "af_inactive"           -- AF-point is inactive
DefaultDelegates.POINTTYPE_FACE                 = "face"                  -- Face has been detected
DefaultDelegates.POINTTYPE_CROP                 = "crop"                 -- Crop has been detected
DefaultDelegates.POINTTYPE_TEST                 = "test"                 -- for testing purposes
DefaultDelegates.pointTemplates = {
-- #TODO the point templates need a cleanup once the different maker needs are clear!
  af_focus_pixel = {
    corner = { fileTemplate = "assets/imgs/corner/%s/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/%s/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_focus_pixel_box = {
    center = { fileTemplate = "assets/imgs/center/%s/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/%s/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/%s/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/%s/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_focus_box = {
    corner = { fileTemplate = "assets/imgs/corner/%s/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/%s/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_focus_box_dot = {
    center = { fileTemplate = "assets/imgs/center/%s/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/%s/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/%s/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/%s/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_focus_box_primary = {
    center = { fileTemplate = "assets/imgs/center/white/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/white/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/%s/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/%s/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_selected = {
    corner = { fileTemplate = "assets/imgs/corner/white/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/white/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_inactive = {
    corner = { fileTemplate = "assets/imgs/corner/grey/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/grey/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  face = {
    corner = { fileTemplate = "assets/imgs/corner/yellow/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/yellow/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  crop = {
    corner = { fileTemplate = "assets/imgs/corner/black/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/black/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  test = {
    corner = { fileTemplate = "assets/imgs/corner/orange/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/orange/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
}

return DefaultDelegates
