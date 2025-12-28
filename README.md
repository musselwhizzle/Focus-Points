# Focus Points – V3.2 Prerelease

### Current version: [V3.2 PRE 4 updated December 28, 2025](https://github.com/musselwhizzle/Focus-Points/releases/tag/v3.2_pre4)

This document describes the new features and changes in V3.2.<br>

Unless stated otherwise, the latest official version (V3.1) of the [README](https://github.com/musselwhizzle/Focus-Points/blob/master/README.md) document continues to serve as an overview of the plugin's features and how they operate. The user manual will be updated to include V3.2 content at the time of its public release.

If you would like to share your feedback or suggestions, please go **[here](https://github.com/musselwhizzle/Focus-Points/discussions/337)**.

New features introduced in V3.2: 

- [Tagging (Flagging, Rating and Coloring) of photos within the pugin UI](#tagging-of-photos)&nbsp;&nbsp;[#302](https://github.com/musselwhizzle/Focus-Points/issues/302) (not for LR5)
- [Filmstrip Navigation](#filmstrip-navigation)&nbsp;&nbsp;[#314](https://github.com/musselwhizzle/Focus-Points/issues/314) (not for LR5)
- [Customizable plugin window size](#customizable-plugin-window-size)&nbsp;&nbsp;[#317](https://github.com/musselwhizzle/Focus-Points/issues/317)
- [Introduction of visible input field for keyboard shortcuts](#introduction-of-visible-input-field-for-keyboard-shortcuts)&nbsp;&nbsp;[#321](https://github.com/musselwhizzle/Focus-Points/issues/321)
- [Long metadata names excessively widen the information area](#display-of-long-metadata-names)&nbsp;&nbsp;[#326](https://github.com/musselwhizzle/Focus-Points/issues/326)
- [Improved sizing of metadata window](#improved-sizing-of-metadata-window)&nbsp;&nbsp;[#333](https://github.com/musselwhizzle/Focus-Points/issues/333)
- [Buy the developer a coffee](#buy-the-developer-a-coffee)&nbsp;&nbsp;[#319](https://github.com/musselwhizzle/Focus-Points/issues/319)

Screenshot of user interface with new tagging controls, shortcut input field and "coffee" link :

<img src="screens/README%20V3.2%20UI.jpg" alt="Screenshot" style="width: 800px;"/>

Screenshot of plugin settings page with new `User Interface` section:

<img src="screens/README V3.2%20Settings.jpg" alt="Screenshot" style="width: 600px;"/>


### Tagging of photos

Users for whom focus point accuracy is critical when selecting shots now have the ability to flag, reject, rate or color images directly within the plugin. The user interface has been updated to include the relevant controls: 

Windows:
<img src="screens/README TaggingControlsWIN.jpg" alt="Screenshot" style="width: 800px;"/>

macOS:
 <img src="screens/README TaggingControlsMAC.jpg" alt="Screenshot" style="width: 800px;"/>

Tagging can be performed using the same logic and [keyboard shortcuts](#keyboard-shortcuts) as in Lightroom. Pressing the Shift key during tagging moves the plugin to the next photo.

**Notes / Restrictions:**

- Although the plugin allows you to set a photo's flag status, rating and color label, these settings are **not** reflected in the plugin's user interface. Any changes to the flag status, rating or color will be acknowledged immediately with a standard message in Lightroom Classic, and these changes will be reflected in the filmstrip for the selected photo. It is recommended that you adjust the sizes of the plugin window and Lightroom's filmstrip when using tagging, so that both are visible at the same time.
<br><br>
- Use of `Shift` + `0`-`9` keyboard shortcuts require that the plugin is aware which international keyboard layout is currently used. This is necessary because the plugin cannot recognize key codes; it can only work with text input. See xxx.<br>
The keyboard layout can be configured in the `User Interface` section. The predefined options cover a large percentage of the available layouts, and more can be added on request. In this specific context, it is important to note that the term 'layout' refers only to the codes produced by the `0`–`9` keys in the top row, and not to the entire keyboard.
<br><br>
<img src="screens/README KeyboardLayoutSettings.jpg" alt="Screenshot" style="width: 600px;"/>
<br><br>
  
- The LR SDK does not support clickable images, so all control elements must be text or text buttons. As the plugin UI displays all Unicode 'star symbol' characters as small, hardly recognizable stars, the rating controls are represented by numbers 1–5 instead.

- The display of tagging controls and related keyboard shortcut operation can be disabled in the plugin settings, under section `User Interface`.  

- Note: Tagging features use the 'LrSelection' namespace, which is only available in SDK version 6.0 and above. Therefore, these features is not available on LR5.7 (which is still in use by a few plugin users!).



### Filmstrip Navigation
You no longer need to select the corresponding photos before starting the plugin to display the focus point for multiple photos.<br> 
The plugin now supports next and previous function when run on a single image (the current one). `Next image` will advance to the next photo in the filmstrip, and `Previous image` will advance to the previous photo in the filmstrip. Unlike with a set of selected photos, there is no wrap-around when the beginning or end of the film strip is reached.

Running the plugin on a selection of multiple photos is still possible.

Note: Filmstrip navigation uses the 'LrSelection' namespace, which is only available in SDK version 6.0 and above. Therefore, this feature is not available on LR5.7.


### Customizable plugin window size

V3.2 introduces a "Size of plugin window" option, that is valid for both macOS and Windows*. A new setting has been added to the 'User Interface' menu that allows you to customize the size of the plugin window. You can choose from five options ranging from XXL to S.

In the Focus Point dialog, this setting corresponds to 80% (XXL) to 40% (S), in increments of 10%, of the size of the Lightroom application window used to display the photo. Please note that the text pane to the right of the photo and the bottom row of user controls are not included in this percentage.

<img src="screens/README WindowSize.jpg" alt="Screenshot" style="width: 600px;"/>

In the Metadata Viewer, this setting determines the height or half the width of the dialog window.

* Windows users already had the option to adjust the size of the focus points window using the screen scaling option specific to Windows. This setting remains as it is.


### Introduction of visible input field for keyboard shortcuts

Due to limitations in the LR SDK, the plugin can only work with text input and cannot recognize key codes. Keyboard shortcuts entered by the user, such as 'P' for 'Set as Pick' or '+' for 'Previous Image', are collected as text in a designated input field. If the character entered corresponds to a defined shortcut, the related action is performed. This works fine as long as the focus is on the input field.

In Windows, only pressing the Tab key or clicking on the photo will remove the focus from the input field. As a result, further keyboard input will not be recognized. Mouse operation does not remove the focus.

On macOS, clicking on any control (button, link text or tagging icon) takes focus away from the input field. With the large number of new controls in V3.2, it is not possible to perform operations using keyboard shortcuts and the mouse simultaneously for the same image.

n V3.1, the text input field for keyboard shortcuts was invisible. The user could not understand why keyboard shortcuts stopped working when focus was removed from the input field by mouse operation. As the LR SDK offers no option to focus on a specific control, the input field must be refocused by the user.

To make this procedure more transparent and intuitive, the text input field is now visible by default:

<img src="screens/README%20TextInputField.jpg" alt="Screenshot" style="width: 600px;"/>

Users who find the new control disturbing can customize its appearance in the plugin settings:

<img src="screens/README%20TextInputSetting.jpg" alt="Screenshot" style="width: 600px;"/>

- Invisible. This is self-explaining
- Small. A narrow input field without labelling
- Regular. An input field that can display a minimum of 10 characters, along with a label containing a link to the 'Keyboard Shortcuts' section of the user manual.

### Keyboard Shortcuts

Several new keyboard shortcuts have been introduced to support photo tagging (flagging, rating, and color labeling). These shortcuts are identical to those used in Lightroom.

Some shortcuts in V3.1 have been changed to avoid collision with Lightroom tagging shortcuts. Previously, 'p' was used for 'preview', 'x' for 'exit', and 'u' for 'user manual'. Instead of 'Exit', the plugin will now close using the 'Close' button (shortcut 'C').


| Action                                      | Keyboard shortcuts |
|---------------------------------------------|--------------------|
| **Navigation**                              |                    | 
| Previous image                              | `-`, `<`           |
| Next image                                  | `+`, `Spacebar`    |
| **Flagging**                                |                    |
| Flag photo as a pick                        | `P`                |
| Flag photo as a pick and go to next photo   | `Shift`+`P`        |
| Flag photo as a reject                      | `X`                |
| Flag photo as a reject and go to next photo | `Shift`+`X`        |
| Unflag photo                                | `U`                |
| Unflag photo and go to next photo           | `Shift`+`U`        |
| **Rating**                                  |                    |
| Set star rating                             | `1`-`5`            |
| Set star rating and go to next photo        | `Shift`+`1`-`5`    |
| **Color**                                   |                    |
| Assign a red label                          | `6`                |
| Assign a yellow label                       | `7`                |
| Assign a green label                        | `8`                |
| Assign a blue label                         | `9`                |
| Assign a color label and go to next photo   | `Shift`+`6`-`9`    |
| **Miscelleanous**                           |                    |
| Open User Manual                            | `M`                |
| Open Troubleshooting Information (Help)     | `?`, `H`           |
| Check Log                                   | `L`                |
| Close                                       | `C `               |


### Display of long metadata names

Some metadata may consist of character strings that are longer than average. This can result in the information area of the dialogue box becoming wider than necessary. This is because most of the space is empty.

For a few selected metadata items, if the character string exceeds a fixed internal length, it is split across multiple lines. However, this approach is not practical for all metadata.

There is a new setting in 'User Interface' that allows you to specify whether long names should be truncated in the display or shown in full in the tooltip. You can choose the truncation limit, which can be set between 10 and 100 characters.

<img src="screens/README%20Truncate%20Setting.jpg" alt="Screenshot" style="width: 600px;"/>

Enabling this setting makes the window content look much tidier:

<img src="screens/README%20Long%20Names.jpg" alt="Screenshot" style="width: 800px;"/>


### Improved sizing of metadata window

In version 3.1, metadata tag names that were significantly longer than 40 characters could result in an unusual display in the metadata viewer.

This has been improved in V3.2:

1. The maximum length of tags displayed is limited to 32 characters.
2. The maximum length of values displayed is limited to 128 characters.
3. Truncated strings are indicated by an ellipsis symbol '...' <br> If this is relevant information, it can still be reviewed by opening the metadata as text.
5. The edit fields for the 'Tag' and 'Value' filters are the same size as in point 1.
6. The heigth of the metadata window is given by the `Size of plugin window` setting S .. XXL
7. The width of the metadata window chosen that the head line (filter entry fields, hint) fits in but minimum 70% of the window height.

<img src="screens/README%20Metadata%20Window.jpg" alt="Screenshot" style="width: 800px;"/>


### Buy the developer a coffee
Several of you have asked how you can show your appreciation for the work I have done to significantly improve the plugin over the past year or so. If you care about this issue, you can now show your [support via Ko-fi](https://ko-fi.com/focuspoints)*. Simply click the link next to the coffee cup.

*Ko-fi is a well-established service that enables users to support creators through voluntary donations.
Payments are processed securely via PayPal or credit/debit card, and no account or subscription is required.


