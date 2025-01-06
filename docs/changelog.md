Change history and planned improvements
=======


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
* recent Nikon Z models after 2021 (exiftool modification required)
* recent and popular Nikon DSLR models (D850 etc.)
* verify (if needed fix) and document support of recent models (priority on Canon and Sony)  
   
### 3.0 Improved focus point display
* Add relevant shooting settings and autofocus parameters to have all relevant data in one place to assess the focusing result for an image. E.g.:
  * camera and lens ID
  * focal length, exposure, aperture, ISO
  * focus mode, focus distance, hyperfocal distance, DoF
  
