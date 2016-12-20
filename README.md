Focus Points
=======

A plugin for Lightroom to show which focus point was active when the picture was taken

<img src="screens/sample.png" alt="Screenshot" style="width: 200px;"/>



Installing
--------
1. Use the green button in this webpage called "Clone or download". 
2. Extract the zip and (optionally) rename the folder from "focuspoints.lrdevplugin" to "focuspoints.lrplugin" 
3. Move this folder to where you'd normally kept your Lightroom plugins.
4. Open Lightroom and go to File -> Plug-in Manager. Then click the "Add" button and select the folder


Adding your own camera
--------
If you wish to contribute, this should be as painless as possible. You will need to map all of your camera's focus points to pixel coordinates. Refer to the "focus_points/nikon/D7200.lua" as an example. 
```
-- 1st column
B1 = {810, 1550}
C1 = {810, 1865}
D1 = {810, 2210}

-- an so on
```
The best way I found to do this was to set up a rule, get out my camera and I took a photo at each of the focus points. I think imported those pictures into Lightroom and ran this plugin so I could see the metadata. From the metadata, I could see the focus points name. I think took the image into photoshop and measured from the top left corner of the image to where the focus point was. I compared the preview from the camera to my photoshop selection and got as close as possible. Once you have done all of that, add the file to "focus_points/{camera_maker}/{camera_model}.lua". PointsRendererFactory will need to be updated to account for the new camera. Then all is done. 


Known Issues
--------
1. Lightroom does not allow for resizing of images or dynamically creating a box with a frame. As such, 
the focus point image can not be the exact size as your cameras. It can only estimate. 
2. Lightroom has a bug where lrPhoto:getDevelopSettings()["Orientation"] always returns nil. Lightroom does not
track if you have rotated the photo in development. As such, if the photo was rotated, the focus point could be 
wrong. The code attempts to resolve this, but it's only an attempt. 


TODOs
--------
 * check for "normal" to make sure the width is bigger than the height. if not, prompt
  the user to ask which way the photo was rotated
 * adjust point for rotation of crop
 * update the "MetaData" for an alphabetized order
 * show ExifTool license in plugin 


License
--------

    Copyright 2016 Joshua Musselwhite, Whizzbang Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

