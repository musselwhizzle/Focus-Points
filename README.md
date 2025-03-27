Focus Points
=======

A plugin for Lightroom Classic (LrC on Windows, macOS) to 
- Show which focus point was active when the picture was taken.
- Display the entire (EXIF) metadata of the selected image


For details on scope and limitations as well as comprehensive operating instructions see [User Documentation](docs/Focus%20Points.md).

<img src="screens/ReadMe 1.jpg" alt="Screenshot" style="width: 800px;"/>

Current Release
--------
## V3.0, March 28, 2025

### New features and changes:
 
* **Improved user interface**
  * Multi-image processing: select multiple images in Lightroom before starting the plugin [#210](https://github.com/musselwhizzle/Focus-Points/issues/210)
  * Side-by-side presentation of focus point display and camera settings / focus information to support assessment of focus results [#214](https://github.com/musselwhizzle/Focus-Points/issues/214)
    * Focus information implemented for Canon, Nikon, Sony, Fuji, Panasonic, Olympus, Apple
    * Pentax pending
  * User can choose focus box color and for 'focus pixel' points also box size [#215](https://github.com/musselwhizzle/Focus-Points/issues/215)
  * Improved logging to assist the user in understanding why for certain images no focus points can be displayed [#217](https://github.com/musselwhizzle/Focus-Points/issues/217)
  * Automatic sizing of plugin dialog windows according to Windows Display Scale setting [#216](https://github.com/musselwhizzle/Focus-Points/issues/216)
  * Automatic check for updates [#224](https://github.com/musselwhizzle/Focus-Points/issues/224)
  * Metadata Viewer: filtering of both tags and values columns supported  [#221](https://github.com/musselwhizzle/Focus-Points/issues/221)
  

* **Camera specific improvements to focus point detection and display**
  * Nikon: added full support of Mirrorless and all DSLRs with 39 or more autofocus points  [#203](https://github.com/musselwhizzle/Focus-Points/issues/203), [#208](https://github.com/musselwhizzle/Focus-Points/issues/208),  [#209](https://github.com/musselwhizzle/Focus-Points/issues/209), [#211](https://github.com/musselwhizzle/Focus-Points/issues/211), [#212](https://github.com/musselwhizzle/Focus-Points/issues/212).
  * Sony: fixed coordinates of phase detection focus points [#176](https://github.com/musselwhizzle/Focus-Points/issues/176). Unified implementation for Sony Alpha and RX10M4 [#213](https://github.com/musselwhizzle/Focus-Points/issues/213)
  * Face detection frames added for Sony [#222](https://github.com/musselwhizzle/Focus-Points/issues/222), Panasonic [#223](https://github.com/musselwhizzle/Focus-Points/issues/223), Olympus [#219](https://github.com/musselwhizzle/Focus-Points/issues/219), Apple [#218](https://github.com/musselwhizzle/Focus-Points/issues/218). 
  * Face and subjection detection frames added for Fuji [#165](https://github.com/musselwhizzle/Focus-Points/issues/165).
  * Pentax: Fixed a problem that prevented the plugin from recognizing K-3, K-1 and K-1 Mark II [#206](https://github.com/musselwhizzle/Focus-Points/issues/206).
   


* Includes ExifTool 13.25 (Mar. 11, 2025)
 

* Comprehensive user documentation


**Supported cameras:**  
See below.

For history of versions and changes see [changelog.](docs/changelog.md)

**[Download release](https://github.com/musselwhizzle/Focus-Points/releases/latest)**

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

<br>

Installing
--------
**Installation steps**
1. Download the _**source code.zip**_ file from [latest release](https://github.com/musselwhizzle/Focus-Points/releases/latest).
2. Move this folder to where you'd normally kept your Lightroom plugins.<br>Hint: if you don't know this folder, the Plugin Manager will show you (see next step) 
3. Open Lightroom and go to File -> Plug-in Manager. Then click the "Add" button and select the folder

Once installed, select one or more photos and invoke the plugin via
* Library -> Plug-in Extras -> Show Focus Point, or  
* File -> Plug-in Extras -> Show Focus Point

<br>

Supported AF-Points
--------
Currently, the following types of AF-points and visualization frames will be displayed :

* <img src="screens/af_selected.png" alt="AF selected" style="width: 20px;"/> Active AF-Point
* <img src="screens/af_inactive.png" alt="AF selected in focus" style="width: 20px;"/> Inactive AF-Point
* <img src="screens/face.png" alt="AF selected in focus" style="width: 20px;"/> A face or subject was detected by the camera at this position
* <img src="screens/face.png" alt="AF selected in focus" style="width: 20px;"/> Part of the image used by the camera in 'crop mode'.

As different implementations of focus point rendering are required for Windows and macOS, the display of focus points looks different on both operating systems. On macOS, focus points and frames for face/subject detection and crops are indicated by the corners only while on Windows all frames have solid lines. Availabilty of the same method(s) on both platforms (ideally selected by the user) would be desirable, but it's a technical challenge to make the MAC method available on WIN and vice versa.

On macOS, the focus point display of title photo looks like this:

<img src="screens/ReadMe 2.jpg" alt="Screenshot" style="width: 800px;"/>


Please note that not all cameras save the needed information to support these features in the Exifs of the photo. E.g. Canon and Nikon do not store any information on detect faces or subjects, hence there are no detection frames for these cameras.  

<br>

Metadata viewer
--------
The plugin also features a metadata viewer with live search: 
  
* Library -> Plug-in Extras -> Show Metadata, or  
* File -> Plug-in Extras -> Show Metadata

The Metadata Viewer comes in handy for viewing any information that is not visible in the info sections of the focus point windows. The information is fetched directly from the image file on disk so it gives a full picture of metadata written by the camera. Metadata can be filtered by keys or value. The filter accepts pattern matching using commonly known 'magic characters':  

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

