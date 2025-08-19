Focus Points
=======

A plugin for Lightroom Classic (LrC on Windows, macOS) to 
- Show which focus point was active when the picture was taken
- Display user-selected autofocus points/area<sup>1,2</sup>
- Visualize faces and subjects detected by the camera<sup>1,3</sup> 
- Display (EXIF) metadata of the selected image


<sup>1</sup> Depending on the presence of metadata. 
<sup>2</sup> Currently supported for Pentax and OM System.      
<sup>3</sup> Currently supported for Fuji, Olympus/OM (subjects, faces) and Sony, Pentax (faces).

To understand the principles of this plugin, how to use it and how to interpret the results, please refer to the [Operating Instructions](docs/Focus%20Points.md). It is recommended that you read chapters 1, 2 and the part of chapter 3 that applies to your camera.

<br>

<img src="screens/ReadMe 1.jpg" alt="Screenshot" style="width: 800px;"/>


<br>

Upcoming Release
--------
## V3.1, September xx, 2025

### New features and changes:

* **Camera support**
  * Pentax:
    * Redesign of Pentax support [#269](https://github.com/musselwhizzle/Focus-Points/issues/269)
    * Visualization of selected and in-focus CAF points (LiveView) [#261](https://github.com/musselwhizzle/Focus-Points/issues/261)
    * Focus point display for Pentax K-3 III (Monochrome) [#262](https://githubcom/musselwhizzle/Focus-Points/issues/262)
    * Detection of multiple faces for Pentax K-3 III [#264](https://github.com/musselwhizzle/Focus-Points/issues/264)
    * Display status of Pentax AF-related camera settings [#270](https://github.com/musselwhizzle/Focus-Points/issues/270)
  * OM System: 
    * Visualization of AF selection (AF target area) [#259](https://github.com/musselwhizzle/Focus-Points/issues/259) 
    * Visualization of subject detection [#260](https://github.com/musselwhizzle/Focus-Points/issues/260) 
  * Olympus: 
    * Support entire Olympus E-series [#267](https://github.com/musselwhizzle/Focus-Points/issues/267)
  * Ricoh: 
    * Support Ricoh GR III / IIIx models [#263](https://github.com/musselwhizzle/Focus-Points/issues/263)


* **User interface**
  * Usability improvements [#266](https://github.com/musselwhizzle/Focus-Points/issues/266)
    * Consistent layout of controls between single and multi-image modes
    * Improved messages and information in case no focus points have been found or errors/warnings occured
    * UI access to user manual
  
   
* **Bugfixes**
  * Metadata table not properly displayed when develop settings are written to image file [#257](https://github.com/musselwhizzle/Focus-Points/issues/257)


* **Other**
  * Support using keyboard shortcuts to launch the plugin [#268](https://github.com/musselwhizzle/Focus-Points/issues/268), [#202](https://github.com/musselwhizzle/Focus-Points/issues/202)
  * User documentation reworked
  * Includes ExifTool 13.34 (Aug. 18, 2025)


**Supported cameras:**  
See below.

For history of versions and changes see [changelog.](docs/changelog.md)

### **[Download release](https://github.com/capricorn8/Focus-Points/releases/latest)**

<br>

Supported Cameras
--------

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
  * Face detection
  

* Fuji
  * Mirroless: X-series (from X100 in 2011 up to X-H2S today), GFX-series
  * Compact: FinePix models after 2007  
  * Face and subject detection


* Olympus / OM System
  * DSLR: entire E-series
  * Mirrorless: entire E-M series, OM-1, OM-3, OM-5
  * Olympus: Face detection
  * OM System: Face and subject detection


* Panasonic
  * Mirrorless: entire LUMIX G and S series
  * Compact: FZ, TZ/ZS, LX series - models after 2008
  * Face detection
  

* Pentax 
  * DSLR: all models with 11 or more autofocus points (from *istD in 2003 to K-3 III Mono in 2023)
  * Face detection
  

* Ricoh
  * GR III, GR IIIx


* Apple
  * iPhone (starting from at least iPhone 5)
  * Face/pet detection frames (visualizing "Person & Pets" information from Apple's Photos App)

<br>

Installation
--------
**Installation steps**
1. Download **source code.zip** from [latest release](https://github.com/capricorn8/Focus-Points/releases/latest) (go to the bottom of that page to find the download link).<br>A file named **Focus-Points-[plugin_version].zip** will be downloaded to your computer.<br>  _MAC users_: According to your macOS preferences the zip file will be automatically unzipped.


2. If needed, unzip this file. Inside the extracted content locate the plugin folder **focuspoints.lrplugin**


3. Move this folder to where you'd normally kept your Lightroom plugins.<br>Hint: if you don't know this location, the Plugin Manager will show you (see next step).<br>
_MAC users_: if you have to navigate into the content of the „adobe lightroom classic.app", use the control-click and choose  „show package content“. 


4. Open Lightroom and go to File -> Plug-in Manager.<br>
_Windows_: Click the "Add" button and select the plugin.<br>
_MAC_: In case of you'd copied the plugin to the default LR-plugin location, the new plugin is already listed - activate it. Otherwise Click on the „Add“ button and select the plugin.

Once installed, select one or more photos and invoke the plugin via
* Library -> Plug-in Extras -> Show Focus Point, or  
* File -> Plug-in Extras -> Show Focus Point

<br>

Supported AF-Points
--------

The plugin uses different colors to visualize AF points, detected faces and objects, and other elements.
The visualization is done by drawing a rectangular frame around the element, although the way this is done differs between Windows and macOS due to the implementation (for a more detailed explanation see [User Interface](docs/Focus%20Points.md#user-interface))


|                                           MAC                                           |                                             WIN                                             |       Color       | Meaning                                                                |
|:---------------------------------------------------------------------------------------:|:-------------------------------------------------------------------------------------------:|:-----------------:|------------------------------------------------------------------------|
|<img src="screens/af_infocus.png" alt="AF selected" style="width: 20px;"/>      |      <img src="screens/af_infocus_win.png" alt="AF selected" style="width: 20px;"/>      |  red<sup>1</sup>  | Active AF-Point. Focus area, dimensions reported by the camera      |
|<img src="screens/af_infocusdot.png" alt="AF selected" style="width: 20px;"/>     |    <img src="screens/af_infocusdot_win.png" alt="AF selected" style="width: 20px;"/>     | red<sup>1,2</sup> | Active AF-Point. Focus location<sup>3</sup>
|<img src="screens/af_selected.png" alt="AF selected in focus" style="width: 29px;"/> | <img src="screens/af_selected_win.png" alt="AF selected in focus" style="width: 29px;"/> |       white       | User-selected AF-Point                                                 
|<img src="screens/af_inactive.png" alt="AF selected in focus" style="width: 20px;"/> | <img src="screens/af_inactive_win.png" alt="AF selected in focus" style="width: 20px;"/> |       gray        | Inactive AF-Point. Part of DSLR AF layout but not used                
|<img src="screens/af_face.png" alt="AF selected in focus" style="width: 20px;"/>   |   <img src="screens/af_face_win.png" alt="AF selected in focus" style="width: 20px;"/>   |      yellow       | Face or subject detected by the camera at this position                
|<img src="screens/af_crop.png" alt="AF selected in focus" style="width: 20px;"/> |   <img src="screens/af_crop_win.png" alt="AF selected in focus" style="width: 20px;"/>   |          black    | Part of the image that is used by the camera in 'crop mode'           |

<sup>1</sup> AF-Point Color can be chosen from red, green, blue in [Configuration and Settings](docs/Focus%20Points.md#22-configuration-and-settings).<br>

<sup>2</sup> 'Focus-pixel' shape and size can be chosen from different options (small box or medium/large with center dot) in [Configuration and Settings](docs/Focus%20Points.md##22-configuration-and-settings).
<sup>3</sup> The red square with a dot inside can have different meanings. Either the square frame around the dot comes from the settings to improve the visibility of the dot. However, the frame can also reflect the dimensions of a focus area that camera reports along with the focus position (which is a pixel). If the distinction is important, select "Small" for the size of the focus box for "focus pixel" points. This will draw a simple small box with no dot inside. This way, the shape with a dot will only be visible for focus pixel points that also have a reported dimension.


On macOS, the focus point display of title photo looks like this:

<img src="screens/ReadMe 2.jpg" alt="Screenshot" style="width: 800px;"/>


Please note that not all cameras save the needed information to support these features in the Exifs of the photo. E.g. Canon and Nikon do not store any information on detect faces or subjects, hence there are no detection frames for these cameras.  

<br>

Metadata viewer
--------
The plugin also features a metadata viewer with live search: 
  
* Library -> Plug-in Extras -> Show Metadata, or  
* File -> Plug-in Extras -> Show Metadata

The Metadata Viewer is useful for viewing information that is not visible in the Info panes of the focus windows. The information is retrieved directly from the image file on disk, giving a complete picture of the metadata written by the camera. Metadata can be filtered by key or value. The filter accepts pattern matching with common 'magic characters':

 | Char  | <div align="left">Meaning</div>                | 
 |:-----:|------------------------------------------------|
 |   .   | any character                                  | 
 |   +   | one or more repetitions of previous character  |
 |   *   | zero or more repetitions of previous character |                                            
 |   ^   | start of line/string                           |
 |   $   | end of line/string                             |              


<img src="screens/metadata1.jpg" alt="Screenshot" style="width: 200px;"/>         <img src="screens/metadata2.jpg" alt="Screenshot" style="width: 200px;"/>         <img src="screens/metadata3.jpg" alt="Screenshot" style="width: 200px;"/>

<br>

Contributing as a Developer
--------
Please see the [Contributing.md](Contributing.md) file before being any new work.

Special Thanks
--------
There's been a lot of man-hours put into this effort so far. All volunteer. So help me in thanking the individuals who have worked hard on this. First off, thanks for Phil Harvey for providing the 3rd party library ExifTool. The following is a list of the individual contributors on this project. These guys have fixed bugs, added camera support, added face detection, added support for your iphone, and many other cool features. (If you are a dev and I've missed you, please feel free to update this file or add your real name):

rderimay, philmoz, project802, jandhollander, DeziderMesko, StefLedof, roguephysicist, ropma, capricorn8 (Karsten Gieselmann)

<a href="https://github.com/musselwhizzle/Focus-Points/graphs/contributors">Full list can be seen here.</a>

Licenses
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

This plugin contains code from AutoHotkey (GPLv2).
See [LICENSE.txt](focuspoints.lrplugin/ahk/License.txt) for details.
