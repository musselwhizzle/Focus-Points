Focus Points
=======

A plugin for Lightroom to show which focus point was active when the picture was taken. (Currently not working on windows. Hopefully that'll be fixed in a matter of days)

<img src="screens/sample_1.jpg" alt="Screenshot" style="width: 200px;"/>



Supported Cameras
--------
* Canon cameras with support for AF-Points position and size from the Exif fields when possible
* Nikon D7200
* Nikon D800
* Fuji cameras with support for face recognition when possible - Should work with all recent X bodies (X-T2, X-T1, X-T10, X-Pro2, X-Pro1, X-A3, X-A2, X-A1, X-A10, X-E2S, X-E2, X-E1, X100T, X30, X70, etc)
* Olympus cameras where 'AF Point Selected' appears in Metadata (Should work on recent E-* bodies)


Installing
--------
1. Use the green button in this webpage called "Clone or download".
2. Extract the zip and (optionally) rename the folder from "focuspoints.lrdevplugin" to "focuspoints.lrplugin"
3. Move this folder to where you'd normally kept your Lightroom plugins.
4. Open Lightroom and go to File -> Plug-in Manager. Then click the "Add" button and select the folder
5. Once installed, in Library mode with a photo selected go to "Library -> Plug-in Extras -> Focus Point"
<img src="screens/plugin_extra.png" alt="Screenshot" style="width: 200px;"/>

Supported AF-Points
--------
Currently, 5 types of AF-points will be displayed :

* <img src="screens/af_selected_infocus.png" alt="AF selected in focus" style="width: 20px;"/> The AF-Point is selected and in focus
* <img src="screens/af_selected.png" alt="AF selected" style="width: 20px;"/> The AF-Point is selected
* <img src="screens/af_infocus.png" alt="AF in focus" style="width: 20px;"/> The AF-Point is in focus
* <img src="screens/af_inactive.png" alt="AF selected in focus" style="width: 20px;"/> The AF-Point is inactive
* <img src="screens/face.png" alt="AF selected in focus" style="width: 20px;"/> A face was detected by the camera at this position

Please note that not all cameras save the needed information in the Exifs of the photo. Thus, the accuracy of the displayed points will greatly depend on whether or not your camera supports it.

Adding your own camera
--------
If you wish to contribute, this should be as painless as possible. You will need to map all of your camera's focus points to pixel coordinates. Refer to the "focus_points/nikon corporation/nikon d7200.txt" as an example.
```
-- 1st column
B1 = {810, 1550}
C1 = {810, 1865}
D1 = {810, 2210}

-- an so on
```
The best way I found to do this was to set up a ruler/tape measure, get out my camera and I took a photo at each of the focus points lining it up exactly with the 1-inch mark. I then imported those pictures into Lightroom and ran this plugin so I could see the metadata. From the metadata, I could see the focus points name. I then took the image into photoshop and measured from the top left corner of the image to the center of the focus point. I compared the preview from the camera to my photoshop selection and got as close as possible. Once you have done all of that, add the file to "focus_points/{camera_maker}/{camera_model}.txt" using all lowercase. Then all is done.

If 2 or more cameras share a common points mapping, then PointsRendererFactory will need to be updated to know this. For example, the D7200 and D7100 could share a common focus points map (I don't know). If they do, PointsRendererFactory can be updated in code. I would prefer not see copying and pasting of focus point files such as "nikon d7200.txt" and "nikon d7100.txt" containing the exact same info.

If adding a camera which does not needed mapped because the focus point is given dynamically (like Fuji) or is a pattern (like A7Rii), create a new {ModelName}Delegate.getDefaultAfPoints(photo, metaData) for the camera and dynamically return the correct x,y point for the selected autofocus. Update PointsRendererFactory to set this delegate method on the Renderer.


Known Issues
--------
1. Not currently working on Windows. Should be fixed soon.
2. Lightroom has a bug where lrPhoto:getDevelopSettings()["Orientation"] always returns nil. Lightroom does not
track if you have rotated the photo in development. As such, if the photo was rotated, the focus point could be
wrong. The code attempts to resolve this, but it's only an attempt.
3. Not compatible if photo was edited in Photoshop. If the photo has been edited in Photoshop, the metadata in the photo telling the focus point was deleted. Perhaps in the future I can update the code to look for the original file and get the focus point from that.


TODOs
--------
 * check for "normal" to make sure the width is bigger than the height. if not, prompt
  the user to ask which way the photo was rotated
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

