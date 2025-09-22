# Focus Points


A plugin for Lightroom Classic<sup>1</sup> on Windows and macOS: 
- Show which focus point was active when the picture was taken <sup>2</sup>
- Display user-selected autofocus points/area <sup>3,4</sup>
- Visualize faces and subjects detected by the camera <sup>3,5</sup> 
- Display (EXIF) metadata of the selected image 

<sup>1</sup> LR5.7 and LR6 perpetual licenses and LrC subscriptions.<br>
<sup>2</sup> For Canon, Nikon, Sony, Fuji, Olympus/OM, Panasonic, Pentax, Ricoh, Apple. See full [list of supported cameras](#supported-cameras).<br>
<sup>3</sup> Depending on the presence of metadata. 
<sup>4</sup> Currently supported for Pentax and OM System.      
<sup>5</sup> Currently supported for Fuji, OM System (subjects, faces) and Sony, Olympus, Pentax (faces).<br>


To understand the principles of this plugin, how to use it and how to interpret the results, please refer to the **[User Manual](docs/Focus%20Points.md)**. It is recommended that you read chapters 1, 2 and the part of chapter 3 that applies to your camera.

**[Download plugin package](https://github.com/musselwhizzle/Focus-Points/archive/refs/tags/v3.1_pre.zip)** or see detailed **[installation instructions](#installation)**.

If you have any questions, comments or suggestions for improving this plugin, please share your feedback in **[Focus-Points Discusssions](https://github.com/musselwhizzle/Focus-Points/discussions)**.

<br>

<img src="screens/ReadMe 1.jpg" alt="Screenshot" style="width: 800px;"/>


<br>

## Current Release

### V3.1 updated September 22, 2025

### New features and changes:

* **Camera support**
  * Pentax:
    * Redesign of Pentax support [#269](https://github.com/musselwhizzle/Focus-Points/issues/269)
    * Visualization of selected and in-focus CAF points (LiveView) [#261](https://github.com/musselwhizzle/Focus-Points/issues/261)
    * Focus point display for Pentax K-3 III [#262](https://githubcom/musselwhizzle/Focus-Points/issues/262)
    * Face detection for Pentax K-3 III [#264](https://github.com/musselwhizzle/Focus-Points/issues/264)
    * Display status of Pentax AF-related camera settings [#270](https://github.com/musselwhizzle/Focus-Points/issues/270)
  * Olympus/OM
    * Indicate use of digital zoom factor [#253](https://github.com/musselwhizzle/Focus-Points/issues/253)
  * OM System: 
    * Visualization of AF selection (AF target area) [#259](https://github.com/musselwhizzle/Focus-Points/issues/259) 
    * Visualization of subject detection [#260](https://github.com/musselwhizzle/Focus-Points/issues/260) 
  * Olympus: 
    * Support entire Olympus E-System [#267](https://github.com/musselwhizzle/Focus-Points/issues/267)
  * Nikon
    * Support Nikon Z5 II [#286](https://github.com/musselwhizzle/Focus-Points/issues/286)
  * Ricoh: 
    * Support Ricoh GR III / IIIx / IV models [#263](https://github.com/musselwhizzle/Focus-Points/issues/263)
  * Sony:
    * Visualization of focus points considering `FocusFrameSize` tag on newer α bodies [part of #176](https://github.com/musselwhizzle/Focus-Points/issues/176)   
  * Canon
    * Improved display of Canon focus information [#285](https://github.com/musselwhizzle/Focus-Points/issues/285) 


* **User interface**
  * Usability improvements:
    * Consistent layout of controls in single and multi-image operation modes [#266](https://github.com/musselwhizzle/Focus-Points/issues/266)
    * Improved user interaction when no focus points can be found [#272](https://github.com/musselwhizzle/Focus-Points/issues/272)
    * Keyboard shortcuts for plugin operation  [#271](https://github.com/musselwhizzle/Focus-Points/issues/271)
  * Metadata display:
    * Display effective focal length for images captured in crop mode [#252](https://github.com/musselwhizzle/Focus-Points/issues/252)
 
     
* **Bugfixes**
  * RC1: Focus Point information is shown for Sony Non-AF lens [#287](https://github.com/musselwhizzle/Focus-Points/issues/287)
  * RC1: Keyboard shortcuts to launch the plugin don't work on LR5/6
  * PRE 6: Focus point display shows white space instead of the photo [#254](https://github.com/musselwhizzle/Focus-Points/issues/254)
  * PRE 6: Plugin window very small when run in LR 5 [#284](https://github.com/musselwhizzle/Focus-Points/issues/284)
  * PRE 5: Plugin stops with error message when run in LR 5/6 (VERSION.build) [#282](https://github.com/musselwhizzle/Focus-Points/issues/282) 
  * PRE 5: Plugin stops with error message when run in LR 5 (Could not find namespace: LrApplicationView) [#283](https://github.com/musselwhizzle/Focus-Points/issues/283)
  * Metadata table not properly displayed when develop settings are written to image file [#257](https://github.com/musselwhizzle/Focus-Points/issues/257)


* **Other**
  * Keyboard shortcuts to launch the plugin [#268](https://github.com/musselwhizzle/Focus-Points/issues/268), [#202](https://github.com/musselwhizzle/Focus-Points/issues/202)
  * User documentation reworked
  * Includes ExifTool 13.36 (Sep. 9, 2025)


* **Supported cameras:**
[See here for full list](#supported-cameras).

<br>

## Installation

**Installation steps**

1. Download the [plugin package](https://github.com/musselwhizzle/Focus-Points/archive/refs/tags/v3.1_pre.zip). A file named `Focus-Points-[plugin_version].zip` will be downloaded to your computer.<br>  _MAC users_: According to your macOS preferences the zip file will be automatically unzipped.<br>

2. Unzip the downloaded file. Inside the extracted content locate the plugin folder `focuspoints.lrplugin`<br>

3. Move this folder to where you normally keep your Lightroom plugins.<br>Hint: if you don't know this location, the Plugin Manager will show you (see next step).<br>
_MAC users_: if you have to navigate into the content of the `adobe lightroom classic.app`, use the control-click and choose  `show package content`.<br>

4. Open Lightroom and go to `File → Plug-in Manager`.<br>
_Windows_: Click the `Add` button and select the plugin.<br>
_MAC_: In case of you'd copied the plugin to the default LR-plugin location, the new plugin is already listed - activate it. Otherwise, click on the `Add` button and select the plugin.

Once the plugin has been installed, choose one or more photos and select:
* `Library → Plug-in Extras → Show Focus Point`, or  
* `File → Plug-in Extras → Show Focus Point`

See [How to use a keyboard shortcut to run the plugin](docs/Focus%20Points.md#how-to-use-a-keyboard-shortcut-to-run-the-plugin) to learn how to invoke the plugin using a hotkey.

If you have never used Lightroom plugins before and are looking for some basic information, a video tutorial would be a good place to start. For example, [Plugin Installation (5:16)](https://www.youtube.com/watch?app=desktop&v=dxB4eVcNPuU) or [How to Install & Remove Lightroom Plug-ins (11:30)](https://www.youtube.com/watch?v=DFFA8nKBsJw). 

<br>

## Supported AF Points


The plugin uses different colors to visualize AF points, detected faces, subjects and details. Visualization means that the respecive area is highlighted by a rectangular marker. On Windows this is a solid frame. On macOS, the frame is indicated by corner symbols. The reason for this OS-specific difference is explained in [User Interface](docs/Focus%20Points.md#user-interface).

|                                     MAC                                      |                                       WIN                                        |       Color       | Meaning                                                                               |
|:----------------------------------------------------------------------------:|:--------------------------------------------------------------------------------:|:-----------------:|---------------------------------------------------------------------------------------|
|    <img src="screens/af_infocus.png" alt="infocus" style="width: 20px;"/>    |    <img src="screens/af_infocus_win.png" alt="infocus" style="width: 20px;"/>    |  red<sup>1</sup>  | Active AF point. Focus area, dimensions reported by the camera                        |
| <img src="screens/af_infocusdot.png" alt="infocusdot" style="width: 20px;"/> | <img src="screens/af_infocusdot_win.png" alt="infocusdot" style="width: 20px;"/> | red<sup>1,2</sup> | Active AF point. Focus location<sup>3</sup>, pixel coordinates reported by the camera |
|   <img src="screens/af_selected.png" alt="selected" style="width: 29px;"/>   |   <img src="screens/af_selected_win.png" alt="selected" style="width: 29px;"/>   |       white       | User-selected AF point                                                                |   
|   <img src="screens/af_inactive.png" alt="inactive" style="width: 20px;"/>   |   <img src="screens/af_inactive_win.png" alt="inactive" style="width: 20px;"/>   |       gray        | Inactive AF point. Part of DSLR AF points but not used for the image<sup>3</sup>      |   
|       <img src="screens/af_face.png" alt="face" style="width: 20px;"/>       |       <img src="screens/af_face_win.png" alt="face" style="width: 20px;"/>       |      yellow       | Face or subject detected by the camera in this area                                   |  
|       <img src="screens/af_crop.png" alt="crop" style="width: 20px;"/>       |       <img src="screens/af_crop_win.png" alt="crop" style="width: 20px;"/>       |       black       | Part of the image that is used by the camera in 'crop mode'                           |

<sup>1</sup> AF point color can be chosen from red, green, blue in [Configuration and Settings](docs/Focus%20Points.md#22-configuration-and-settings).<br>
<sup>2</sup> 'Focus-pixel' shape and size can be chosen from different options (small box or medium/large with center dot) in [Configuration and Settings](docs/Focus%20Points.md#22-configuration-and-settings).<br>
<sup>3</sup> The meaning may vary depending on the camera manufacturer. See the camera-specific chapters in the [User Manual](docs/Focus%20Points.md) for a detailed explanation.


On macOS, the focus point display of title photo looks like this:

<img src="screens/ReadMe 2.jpg" alt="Screenshot" style="width: 800px;"/>


Please note that not all cameras store the necessary information to support these features in the photo's metadata. For example, cameras from Canon and Nikon do not store any information on face or subject recognition (at least as far as is known), so visualization is not possible. 

See [chapter 3](docs/Focus%20Points.md#3-display-of-focus-points) of the user manual for detailed information on which types of visualization are supported for which cameras.

<br>

## Metadata viewer

The plugin also features a metadata viewer with live search: 
  
* `Library → Plug-in Extras → Show Metadata`, or  
* `File → Plug-in Extras → Show Metadata`

The Metadata Viewer is useful for viewing information that is neither visible in Lightroom's Metadata panel nor in the Information pane of the focus windows. The information is retrieved directly from the image file on disk, giving a complete picture of the metadata written by the camera. Metadata can be filtered by key or value. The filter accepts pattern matching with common 'magic characters':

 | Char  | <div align="left">Meaning</div>                | 
 |:-----:|------------------------------------------------|
 |   .   | any character                                  | 
 |   +   | one or more repetitions of previous character  |
 |   *   | zero or more repetitions of previous character |                                            
 |   ^   | start of line/string                           |
 |   $   | end of line/string                             |              


<img src="screens/metadata1.jpg" alt="Screenshot" style="width: 200px;"/>         <img src="screens/metadata2.jpg" alt="Screenshot" style="width: 200px;"/>         <img src="screens/metadata3.jpg" alt="Screenshot" style="width: 200px;"/>

<br>

## Supported Cameras

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
  * GR III, GR IIIx, GR IV
  * Face detection


* Apple
  * iPhone (starting from at least iPhone 5)
  * Face/pet detection frames (visualizing "Person & Pets" information from Apple's Photos App)

<br>


## Contributing as a Developer

Please see the [Contributing.md](Contributing.md) file before being any new work.

## Special Thanks

There's been a lot of man-hours put into this effort so far. All volunteer. So help me in thanking the individuals who have worked hard on this. First off, thanks for Phil Harvey for providing the 3rd party library ExifTool. The following is a list of the individual contributors on this project. These guys have fixed bugs, added camera support, added face detection, added support for your iphone, and many other cool features. (If you are a dev, and I've missed you, please feel free to update this file or add your real name):

rderimay, philmoz, project802, jandhollander, DeziderMesko, StefLedof, roguephysicist, ropma, capricorn8 (Karsten Gieselmann)

<a href="https://github.com/musselwhizzle/Focus-Points/graphs/contributors">Full list can be seen here.</a>

## Licenses

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
