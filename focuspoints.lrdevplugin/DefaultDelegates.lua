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

require "Utils"

DefaultDelegates = {}
DefaultDelegates.cameraMake = nil
DefaultDelegates.cameraModel = nil
DefaultDelegates.metaData = nil

DefaultDelegates.POINTTYPE_AF_FOCUS_BOX = "af_focus_box"                  -- draw simple box around the focus point pixel
DefaultDelegates.POINTTYPE_AF_FOCUS_BOX_CENTER = "af_focus_box_center"    -- same, but with dot in the center
DefaultDelegates.POINTTYPE_AF_SELECTED_INFOCUS = "af_selected_infocus"    -- The AF-point is selected and in focus
DefaultDelegates.POINTTYPE_AF_USED = "af_used"                            -- The AF-point is used to focus image (Nikon)
DefaultDelegates.POINTTYPE_AF_INFOCUS = "af_infocus"                      -- The AF-point is in focus
DefaultDelegates.POINTTYPE_AF_SELECTED = "af_selected"                    -- The AF-point is selected but not in focus
DefaultDelegates.POINTTYPE_AF_INACTIVE = "af_inactive"                    -- The AF-point is inactive
DefaultDelegates.POINTTYPE_FACE = "face"                                  -- A face has been detected
DefaultDelegates.POINTTYPE_CROP = "crop"                                  -- A crop has been detected
DefaultDelegates.pointTemplates = {
  af_focus_box = {
    corner = { fileTemplate = "assets/imgs/corner/red/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_focus_box_center = {
    center = { fileTemplate = "assets/imgs/center/red/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/red/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/red/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_selected_infocus = {
    center = { fileTemplate = "assets/imgs/center/red/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/red/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/red/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_used = {
    corner = { fileTemplate = "assets/imgs/corner/red/normal_fat_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_fat_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_infocus = {
    center = { fileTemplate = "assets/imgs/center/red/normal.png", anchorX = 23, anchorY = 23 },
    center_small = { fileTemplate = "assets/imgs/center/red/small.png", anchorX = 23, anchorY = 23 },
    corner = { fileTemplate = "assets/imgs/corner/black/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/black/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  },
  af_selected = {
    corner = { fileTemplate = "assets/imgs/corner/red/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/red/small_%s.png", anchorX = 23, anchorY = 23 },
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
    corner = { fileTemplate = "assets/imgs/corner/black/normal_%s.png", anchorX = 23, anchorY = 23 },
    corner_small = { fileTemplate = "assets/imgs/corner/black/small_%s.png", anchorX = 23, anchorY = 23 },
    bigToSmallTriggerDist = 100,
    minCornerDist = 10,
    angleStep = 5
  }
}
