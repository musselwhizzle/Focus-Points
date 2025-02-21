Change history and planned improvements
=======

## V2.5.0, February 2025
New features and changes:
 
* Improved user interface
  * Multi-image processing: select multiple images in Lightroom before starting the plugin
  * Side-by-side presentation of camera settings and autofocus details to support assessment of focus results
    * Autofocus details currently implemented for Nikon, Canon, Fuji, Olympus
    * Sony, Panasonic, Pentax and Apple will follow in the next release(s) 
  * User can choose focus box color and for focus 'pixel' points also box size
  

* exiftool 13.20
 

* Comprehensive user documentation


Supported cameras:

* Nikon
  * Mirrorless: entire Z-series
  * DSLR: all D models with 39 or more autofocus points (from D3/D300 in 2007 to D6/D780 in 2020)

  
* Canon
  * Mirrorless: entire R-series
  * DSLR: all EOS models after 2004 (starting with EOS-1D Mark II)
  * Powershot models after 2004

 
* Fuji
  * X-series (from X100 in 2011 up to X-H2S today)
  * GFX-series


* Olympus / OM System
  * DSLR: E-5, E-420, E-520, E-620
  * Mirrorless: entire E-M series, OM-1, OM-3, OM-5
  

* Sony, Pentax, Panasonic, Apple 
  * Display of focus points and supported models are unchanged with respect to previous plugin versions
  * Display of basic image information and camera settings
  * Upcoming releases: Review of focus point logic. Display of advanced camera settings and focus information 


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


Future Improvements
--------

### 2.x Adding support for further cameras

* add recent / popular Nikon DSLR models (D850 etc.)
* verify (and if needed fix) and document support of recent models (priority on Canon and Sony)
* all supported brands and models: add face detection as far as EXIF data support this (e.g. this is not supported for Nikon Z)
   
### 3.0 Improved focus point display
* Add relevant shooting settings and autofocus parameters to have all relevant data in one place to assess the focusing result for an image. E.g.:
  * camera and lens ID
  * focal length, exposure, aperture, ISO
  * focus mode, focus distance, hyperfocal distance, DoF
  
