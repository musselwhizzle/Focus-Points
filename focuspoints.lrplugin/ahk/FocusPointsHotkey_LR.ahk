; Script Information ===========================================================
; Name .........: Focus-Points Hotkey
; Description ..: Hotkey assignments for Focus-Points plugin for Lightroom 5+6
; AHK Version ..: 2.0.10 (Unicode 64-bit) - Oct 2023
; OS Version ...: Windows 11
; Author .......: Karsten Gieselmann
; Filename .....: FocusPointsHotkey_LR.ahk
; ==============================================================================

SendMode("Input")           ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir(A_ScriptDir)  ; Ensures a consistent starting directory.

; ------------------------------------------------------------------------------
;Shortcuts for Lightroom 5+6 (English)
; ------------------------------------------------------------------------------

#HotIf WinActive("Adobe Photoshop Lightroom")
{
  NumpadMult::  MenuSelect(, , "File", "Plug-in Extras", "` ` ` Show Focus Point")
  NumpadDiv::   MenuSelect(, , "File", "Plug-in Extras", "` ` ` Show Metadata")
}
