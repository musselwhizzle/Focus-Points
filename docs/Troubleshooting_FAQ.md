# Troubleshooting / FAQ
<br>

<b>The plugin window exceeds the dimensions of my screen. What can I do?</b><br>
Typically, this issue occurs on Windows with display scaling set to 150% or higher. Go to plugin preferences and select the same or similar value under "Scaling". 

<b>I'm getting an error messages "Focus info missing from file". What's wrong?</b><br>
The selected photo is not a JPG or RAW original file out of camera. Focus information, along with many other camera specific settings is stored in so-called _makernotes_ which is a maker-specific area in EXIF metadata. Lightroom does not read or keep makernotes when importing files. So, whenever a separate image file is created from the original file (e.g. by exporting it to another application like Photoshop), there is a risk that makernotes will not be present in this file and the plugin does not have the required inputs to work.   
For more details and concrete examples, see [Scope and Limitations](Focus%20Points.md#scope-and-limitations).  

<b>I'm getting an error messages "No focus points detected". Whyat's wrong?</b><br>
Typically, you will get this message for manually focused shots. If autofocus was used, but no focus point could be detected, then for some reason the camera did not write focus point information to metadata. The camera settings and focus information might help to figure what might have happened.

<b>I'm getting an error messages "Camera model not supported". What's wrong?</b><br>
The selected photo has been taken with a camera that the plugin cannot handle. 
