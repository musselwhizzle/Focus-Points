Focus Points Plugin for Lightroom Classic
=======

## 1. Scope and Limitations

A plugin for Lightroom Classic (LrC on Windows, macOS) to 
- show which focus point was active when the picture was taken.
- display (EXIF) metadata of the selected image

**Principle of operation:** <br>
The plugin uses [exiftool](https://exiftool.org/) to retrieve metadata from the image file. 
Autofocus related information is extracted from EXIF metadata and is processed to visualize the focus 
points. In order for this to work, the plugin requires an image file that still has camera maker 
specific metadata information (_makenotes_) included.

Note: exiftool comes as part of the plugin package and does not need to be installed separately. 

The plugin will not be able to show focus points for image files that don't have makernotes included.<br> 
For this it is important to understand that Lightroom does not read or keep makernotes when importing files.<br>
Whenever a separate image file is created from the original, there is a risk that makernotes will not
be present in this file and the plugin does not have the required inputs to work.

Examples, for which focus points cannot be displayed:
- original image edited in Photoshop and returned as PSD or TIF
- original image transferred as TIFF/JPG to a 3rd party editor, e.g. Topaz, NIK, Photomatix, Helicon
- HDR DNG files created in Lightroom

For external applications that take a RAW file as input when started from Lightroom, 
the plugin may work on the resulting file imported into Lightroom, if the application leaves makernotes 
intact. 

Examples, for which focus point display works on image files created based on original files:  
- DNG files created by DxO PhotoLab, Luminar Neo, Topaz Photo AI
- DNG files created by LrC Enhance, e.g. AI Denoise

Other cases where the Focus Points plugin will not be able to display meaningful information:

* the picture has been taken by focusing on the main subject, then panning the camera to get the desired composition
<br>
<br>

## 2. Overview and Basic Operation
This secction explains how the plugin is used.

### 2.1 Focus Point Viewer
Once the plugin has been installed, it can be invoked with one or more photos selected:

Library module:<br> 
"Library -> Plug-in Extras -> Focus Point" 

Develop module:<br>
"File -> Plug-in Extras -> Focus Point"<br>
<br>
<br>
<b>User interface (single image operation):</b>

<img src="../screens/BasicOperation1.jpg" alt="User Interface (Single image)" style="width: 800px;"/>

The window is split in two parts. The photo view with visualized focus points and display of selected 
metadata information that is relevant for assessing the photo with respect to focus results.<br>
The metadata section comprises three groups:
- Image information (from LrC)
- Camera settings (from LrC)
- Focus information (from EXIF maker notes)

As both image information and camera settings come from the LrC catalog, this information is present 
for every photo. Focus information is only present for those photos where the corresponding image file
has the full metadata. See [Scope and Limitations](docs/Focus%20Points.md) for more detailed information.

If focus information is present for the photo and focus points have been detected this is indicated by a message 
highlighted in green.

In case focus information is missing or no focus points have been detected (e.g. for manually focused photos)
this will be indicated by a message in red letters:

<img src="../screens/BasicOperation2.jpg" alt="User Interface (Single image)" style="width: 800px;"/>

<img src="../screens/BasicOperation3.jpg" alt="User Interface (Single image)" style="width: 800px;"/>

After the window is closed (by clicking "OK" or pressing <Enter> or <Esc>) the user is back in LrC UI.
<br>
<br>
<b>User interface (multi-image operation):</b>

When run on a selection of photos, the user interface of Focus Point Viewer offers two additional buttons
that enable the user to move forwards and backwards within the series of selected photos.

The window can be closed by clicking "Exit" or pressing <Enter> or <Esc>.

<img src="../screens/BasicOperation4.jpg" alt="User Interface (Multi-image)" style="width: 800px;"/>


### 2.2 Metadata Viewer
to be documented

## 3. Display of Focus Points
The subchapters in this section describe in more detail which focus point features are supported by the plugin for individual camera makers and specific lines or models. This can be different colors for different statuses (e.g. focus point selected, in focus, inactive), or face/subject detection frames. The level to which features can be supported ultimately depends on the availability of corresponding data in EXIF maker notes.

Even if certain data is stored by a camera maker it doesn't mean at the same time that it's "available". 
Makernotes is a proprietary metadata section that contains manufacturer-specific information that is not standardized across different brands. Camera makers can use this information to diagnose camera issues, for instance.

The Focus Points plugin fully relies on what [exiftool](https://exiftool.org/) is able to decode and display. Which in turn doesn't fall from the sky, but it's a collaborative effort by camera owners worlwide that are willing to contribute and [go where no man has gone before](https://exiftool.org/#boldly) and decode the unknown.      

## 3.1 Nikon

to be updated after release of V2.2

## 3.2 Canon

to be updated after release of V2.x

## 3.3 Sony
to be updated after release of V2.x

Plus more chapters for Fuji, Pentax, Olympus, Panasonic and others...

