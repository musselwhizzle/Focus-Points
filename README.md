# Focus Points – V3.2 Prelease

### Current version: [V3.2 PRE 4 updated December xx, 2025](https://github.com/capricorn8/Focus-Points/releases/tag/v3.2_pre4)

This document describes the new features and changes in V3.2.<br>
Unless stated otherwise, the latest official version (**V3.1**) of the [README](https://github.com/musselwhizzle/Focus-Points/blob/master/README.md) document continues to serve as an overview of the plugin's features and how they operate.

New features introduced in V3.2: 

- [Tagging (flagging, rating and coloring) of photos within the plugin UI](#tagging-of-photos)&nbsp;&nbsp;[#302](https://github.com/musselwhizzle/Focus-Points/issues/302)
- [Film strip navigation](#film-strip-navigation)&nbsp;&nbsp;[#314](https://github.com/musselwhizzle/Focus-Points/issues/314)
- [Customizable plugin window size](#customizable-plugin-window-size)&nbsp;&nbsp;[#317](https://github.com/musselwhizzle/Focus-Points/issues/317)
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


### Film strip navigation
You no longer need to select the corresponding photos before starting the plugin to display the focus point for multiple photos. When the plugin is opened on a single photo, you can use the navigation controls (`Next image` and `Previous image`), or the corresponding keyboard shortcuts, to advance to the next or previous photo in the film strip. 

Running the plugin on a selection of multiple photos is still possible.


### Customizable plugin window size

V3.2 introduces a "Size of plugin window" option, that is valid for both macOS and Windows*. A new setting has been added to the 'User Interface' menu that allows you to customize the size of the plugin window. You can choose from five options ranging from XXL to S.

In the Focus Point dialog, this setting corresponds to 80% (XXL) to 40% (S), in increments of 10%, of the size of the Lightroom application window used to display the photo. Please note that the text pane to the right of the photo and the bottom row of user controls are not included in this percentage.

<img src="screens/README WindowSize.jpg" alt="Screenshot" style="width: 600px;"/>

In the Metadata Viewer, this setting determines the height or half the width of the dialog window.

* Windows users already had the option to adjust the size of the focus points window using the screen scaling option specific to Windows. This setting remains as it is.



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


### Buy the developer a coffee
Several of you have asked how you can show your appreciation for the work I have done to significantly improve the plugin over the past year or so. If you care about this issue, you can now show your [support via Ko-fi](https://ko-fi.com/focuspoints)*. Simply click the link next to the coffee cup.

*Ko-fi is a well-established service that enables users to support creators through voluntary donations.
Payments are processed securely via PayPal or credit/debit card, and no account or subscription is required.


