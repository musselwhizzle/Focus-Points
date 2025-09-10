; Script Information ===========================================================
; Name .........: Focus-Points Hotkey
; Description ..: Hotkey assignments for Focus-Points plugin for Lightroom
; AHK Version ..: 2.0.10 (Unicode 64-bit) - Oct 2023
; OS Version ...: Windows 11
; Author .......: Karsten Gieselmann
; Filename .....: Focus-Points Hotkey.ahk
; ==============================================================================

SendMode("Input")           ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir(A_ScriptDir)  ; Ensures a consistent starting directory.

; ------------------------------------------------------------------------------
;Shortcuts for Lightroom (Deutsch)
; ------------------------------------------------------------------------------

#HotIf WinActive("Lightroom Classic")
{
  NumpadMult::  MenuSelect(, , "Datei", "Plug-in-Extras", "` ` ` Show Focus Point")
  NumpadDiv::   MenuSelect(, , "Datei", "Plug-in-Extras", "` ` ` Show Metadata")

; ACHTUNG !!!
; Bis inkl. LR 14.4 hieß der relevante Menüpunkt im Datei-Menü "Zusatzmoduloptionen":
; https://community.adobe.com/t5/lightroom-classic-bugs/p-wrong-translation-in-lrc-14-5-german-ui-zusatzmoduloptionen-gt-plug-in-extras/idc-p/15463601#M62763
;
; Sollte Adobe diese Änderung wieder rückgängig machen, ist das Script entsprechend anzupassen:
;
; NumpadMult::  MenuSelect(, , "Datei", "Zusatzmoduloptionen", "` ` ` Show Focus Point")
; NumpadDiv::   MenuSelect(, , "Datei", "Zusatzmoduloptionen", "` ` ` Show Metadata")

}
