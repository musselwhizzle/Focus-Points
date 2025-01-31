Focus Points Plugin for Lightroom Classic
=======

## 1. Scope and Limitations

A plugin for Lightroom Classic (LrC on Windows, MacOS) to 
- show which focus point was active when the picture was taken.
- display (EXIF) metadata of the selected image

**Principle of operation:** 
The plugin uses [exiftool](https://exiftool.org/) to retrieve metadata from the image file. 
Autofocus related information is extracted from EXIF metadata and is processed to visualize the focus points. 
In order for this to work, the plugin requires an image file that still has camera maker specific metadata 
information (_makenotes_) included.

Note: exiftool comes as part of the plugin package and does not need to be installed separately. 

The plugin will not be able to show focus points for images that don't have makernotes included. 
For this it is important to understand that Lightroom does not read or keep makernotes when importing files.
Whenever a separate image file is created from the original, there is a risk that makernotes will not
be present in this file and the plugin does not have the required inputs to work.

Examples, for which focus points cannot be displayed:
- original image edited in Photoshop and returned as PSD or TIF
- original image transferred as TIFF/JPG to a 3rd party editor, e.g. Topaz, NIK, Photomatix, Helicon
- HDR DNG files created in Lightroom

For external applications that take a RAW file as input when started from Lightroom, 
the plugin may work on the resulting file imported into Lightroom, if the application leaves makernotes intact. 

Examples, for which focus point display works on image files created based on original files:  
- DNG files created by DxO PhotoLab, Luminar Neo, Topaz Photo AI
- DNG files created by LrC Enhance, eg. AI Denoise

Other cases where the Focus Points plugin will not be able to display meaningful information:

* the picture has been taken by focusing on the main subject, then panning the camera to get the desire composition   


## 2. Display of Focus Points

## 2.1 Nikon

to be updated after release of V2.2

## 2.2 Canon

## 2.3 Sony

More to follow...
