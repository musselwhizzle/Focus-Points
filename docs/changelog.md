Change history
=======

## V3.0.2, April 4, 2025

### New features and changes:

* **Bugfixes**
  * ExifTool unable to read metadata on MAC [#235](https://github.com/musselwhizzle/Focus-Points/issues/235)
  * Evaluation of System display scale factor (call to REG.EXE) should not be done on MAC [#240](https://github.com/musselwhizzle/Focus-Points/issues/240)


## V3.0, March 31, 2025

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
  * Sony: unified implementation for Sony Alpha and RX10M4 [#213](https://github.com/musselwhizzle/Focus-Points/issues/213). Fixed coordinates of phase detection focus points [#176](https://github.com/musselwhizzle/Focus-Points/issues/176). Fixed incorrect position of focus point display of in-camera cropped images (1:1, 4:3, 16:9) [#228](https://github.com/musselwhizzle/Focus-Points/issues/228)
  * Face detection frames added for Sony [#222](https://github.com/musselwhizzle/Focus-Points/issues/222), Panasonic [#223](https://github.com/musselwhizzle/Focus-Points/issues/223), Olympus [#219](https://github.com/musselwhizzle/Focus-Points/issues/219), Apple [#218](https://github.com/musselwhizzle/Focus-Points/issues/218). 
  * Face and subjection detection frames added for Fuji [#165](https://github.com/musselwhizzle/Focus-Points/issues/165).
  * Pentax: Fixed a problem that prevented the plugin from recognizing K-3, K-1 and K-1 Mark II [#206](https://github.com/musselwhizzle/Focus-Points/issues/206).
   


* Includes ExifTool 13.25 (Mar. 11, 2025)
 

* Comprehensive user documentation


### Supported cameras:

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


## V2.1.0, January 27, 2025
* Full support of Nikon Z series (except Z50ii and Zf):
  * Z5, Z6, Z6ii, Z6iii (#198 ), Z7, Z7ii, Z8, Z9, Z30, Z50, Z fc - CAF and PDAF focus points
  * Z50ii, Z f - currently only CAF focus points (missing PDAF test files!)
* Includes exiftool 13.15 (required for #198)
* Windows: Fix an issue with blurry images / error message when launched in Develop module #199
  - When launched in Develop module the plugin switches to Library loupe view so that a preview can be generated if none exists. 
  - Plugin returns to Develop after its window has been closed.


## V2.0.0, January 6, 2025
* Fix a problem on Windows, where the plug-in would stop with an error message on every first call of Show Focus Point for an image. (#189)
* Olympus/OM-System: revert to display of center dot (#144) 
  * Issue #144 and related fix was nonsense. For Olympus/OM cameras, the only useful EXIF information related to focus point is AFPointSelected. Drawing a box around this point has no added meaning in terms of focusing, but it helps to recognize / find the point more easily on the image.
* Added support for Nikon Z30, Z fc, Z5, Z6 II, Z7 II (#192, based on existing  implementation for Z50, Z6, Z7)
* Improved log-file handling (#193): the plug-in log file now  
  * can be accessed from Lightroom Plug-in Manager 
  * will be deleted upon each start of Lightroom / plug-in reload
  * has been renamed from "LibraryLogger.log" to "FocusPoints.log" 
* Includes exiftool 13.10 (#188)
* Plug-in updates and releases now follow a numbering scheme to keep track of versions and changes (#190). The plug-in version number can be found on the plug-in page in Lightroom's Plug-in Manager. Numbering starts with V2.0.0
