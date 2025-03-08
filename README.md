Focus Points
=======

A plugin for Lightroom Classic (LrC on Windows, macOS) to 
- Show which focus point was active when the picture was taken.
- Display the entire (EXIF) metadata of the selected image


For details on scope and limitations as well as comprehensive operating instructions see [User Documentation](docs/Focus%20Points.md).

<img src="screens/screen1.png" alt="Screenshot" style="width: 200px;"/>

Current Release
--------
## V2.5.0, xx April 2025

xxx

For history of versions and changes see [changelog.](docs/changelog.md)

[Download release](https://github.com/musselwhizzle/Focus-Points/releases/tag/v2.1.0)


Supported Cameras
--------
**Supported cameras:**

* Canon
  * Mirrorless: entire R-series
  * DSLR: all EOS models after 2004 (starting with EOS-1D Mark II)
  * Compact: Powershot models after 2004

 
* Nikon
  * Mirrorless: entire Z-series
  * DSLR: all D models with 39 or more autofocus points (from D3/D300 in 2007 to D6/D780 in 2020)
  * Compact: CoolPix models not supported

  
* Sony
  * Full-frame: α7, α9, α1 bodies beginning 2018 (with α7 III / α7R III) 
  * APS-C: α6100, α6300, α6400, α6500, α6600, α6700, ..
  * Compact: RX series, beginning 2015 (with RX10 II and RX100 IV)
  * Face detection frames
  

* Fuji
  * X-series (from X100 in 2011 up to X-H2S today)
  * GFX-series
  * Face and subject detection frames


* Olympus / OM System
  * DSLR: E-5, E-420, E-520, E-620
  * Mirrorless: entire E-M series, OM-1, OM-3, OM-5
  * Face detection frames


* Panasonic
  * Mirrorless: entire LUMIX G and S series
  * Compact: FZ, TZ/ZS, LX series - all models after 2008
  * Face detection frames
  

* Apple
  * iPhone (starting from at least iPhone 5)
  * Face/pet detection frames (visualizing "Person & Pets" information from Apple's Photos App)


* Pentax 
  * Display of focus points and supported models are unchanged with respect to previous plugin versions
  * Display of basic image information and camera settings
  * Pending (upcoming release): Review/revision of focus point logic. Display of advanced camera settings and focus information 



Installing
--------
**Installation steps**
1. Download the _**source code.zip**_ file from [latest release](https://github.com/musselwhizzle/Focus-Points/releases/latest).
2. Move this folder to where you'd normally kept your Lightroom plugins.<br>Hint: if you don't know this folder, the Plugin Manager will show you (see next step) 
3. Open Lightroom and go to File -> Plug-in Manager. Then click the "Add" button and select the folder
4. Once installed, select one or more photos and invoke the plugin via  
Library -> Plug-in Extras -> Focus Point, or  
File -> Plug-in Extras -> Focus Point


<img src="screens/plugin_extra.png" alt="Screenshot" style="width: 200px;"/>

Supported AF-Points
--------
Currently, the following types of AF-points and visualization frames will be displayed :

* <img src="screens/af_selected.png" alt="AF selected" style="width: 20px;"/> Active AF-Point
* <img src="screens/af_inactive.png" alt="AF selected in focus" style="width: 20px;"/> Inactive AF-Point
* <img src="screens/face.png" alt="AF selected in focus" style="width: 20px;"/> A face or subject was detected by the camera at this position
* <img src="screens/face.png" alt="AF selected in focus" style="width: 20px;"/> Part of the image used by the camera in 'crop mode'.

Please note that not all cameras save the needed information to support these features in the Exifs of the photo. E.g. Canon and Nikon do not store any information on detect faces or subjects, hence there are no detection frames for these cameras.  


Metadata viewer
--------
The plugin also features a metadata viewer with live search. This comes in handy eg. for viewing any information that is not visible in the info sections of the focus point windows. The information is fetched directly from the image file on disk so that this gives the full picture of metadata written by the camera:

<img src="screens/metadata1.jpg" alt="Screenshot" style="width: 200px;"/>         <img src="screens/metadata2.jpg" alt="Screenshot" style="width: 200px;"/>

<!--
Adding your own camera
--------
It's very likely your camera is already supported. So try the plugin first before doing anything. :)

If your camera reports its focus points dynamically, adding support for you camera should be easy. Simply update or create a new CameraDelegate which extracts the focus points. Update the PointsRendererFactory so it knows about this new camera.

If your camera does not report its focus points dynamically, such as in the case of Nikons, this should be as painless as possible. You will need to map all of your camera's focus points to pixel coordinates. Refer to the "focus_points/nikon corporation/nikon d7200.txt" as an example.
```
-- 1st column
B1 = {810, 1550}
C1 = {810, 1865}
D1 = {810, 2210}

-- an so on
```
The best way I found to do this was to set up a ruler/tape measure, get out my camera and I took a photo at each of the focus points lining it up exactly with the 1-inch mark. I then imported those pictures into Lightroom and ran this plugin so I could see the metadata. From the metadata, I could see the focus points name. I then took the image into photoshop and measured from the top left corner of the image to the top left corner of the focus point. I compared the preview from the camera to my photoshop selection and got as close as possible. Once you have done all of that, add the file to "focus_points/{camera_maker}/{camera_model}.txt" using all lowercase. Then all is done.

The camera model must only contain characters valid on all supported file systems. If a character is not valid (for example '\*' in the model "PENTAX \*ist D") it must be mapped to a valid character combination.
The mapping is done in PointsUtils.readFromFile(): '\*' -> '\_a\_'. 

If 2 or more cameras share a common points mapping, simplying add that to the list of known duplicate as in the NikonDuplicates file. With this, both Nikon D7100 and Nikon D7200 will share the same mapping file. 


Known Issues
--------
1. Not compatible if photo was edited in Photoshop. 3rd party tools often remove the necessary metadata from the image. 
-->

Contributing as a Developer
--------
Please see the [Contributing.md](Contributing.md) file before being any new work.

Special Thanks
--------
There's been a lot of man-hours put into this effort so far. All volunteer. So help me in thanking the individuals who has worked hard on this. First off, thanks for Phil Harvey for providing the 3rd party library ExifTool. The following is a list of the individual contributors on this project. These guys have fixed bugs, added camera support, added face detection, added support for your iphone, and many other cool features. (If you are a dev and I've missed you, please feel free to update this file or add your real name):

rderimay, philmoz, project802, jandhollander, DeziderMesko, StefLedof, roguephysicist, ropma, capricorn8 (Karsten Gieselmann)

<a href="https://github.com/musselwhizzle/Focus-Points/graphs/contributors">Full list can be seen here.</a>

License
--------

    Copyright 2016 Whizzbang Inc.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

