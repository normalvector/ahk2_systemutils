#Requires AutoHotkey v2.0
#SingleInstance Force  ; Ensures only one instance of the script runs

; =============================================
; Settings
; These variables control the behavior of the script, enabling
; and disabling parts of it as needed
; =============================================

; Turns on and off the entire script
global SystemUtilsEnabled := true

; Do we want to use the Pause key to play/pause media?
global PauseKeyEnabled := true

; Do we want to use the mouse wheel left/right to change desktops?
global MouseWheelDesktopsEnabled := true

; Visible names for desktops
global DesktopNames := Map(
    0, "Scratch",
    1, "Browser",
    2, "IDE",
    3, "Main Tool",
    4, "Social",
    5, "Files"
)

; How long to display the desktop label in miliseconds (1000ms=1s)
global DesktopLabelDuration := 250

; =============================================
; VirtualDesktopAccessor.dll
; Configure all of the bindings to the DLL so we're able to swap desktops
; =============================================

; Bind the DLL
SetWorkingDir(A_ScriptDir)
VDA_Path := A_ScriptDir . "\VirtualDesktopAccessor.dll"
hVirtualDesktopAccessor := DllCall("LoadLibrary", "Str", VDA_PATH, "Ptr")

; Bind the functions
GetDesktopCountProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GetDesktopCount", "Ptr")
GoToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GoToDesktopNumber", "Ptr")
GetCurrentDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GetCurrentDesktopNumber", "Ptr")
IsWindowOnCurrentVirtualDesktopProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "IsWindowOnCurrentVirtualDesktop", "Ptr")
IsWindowOnDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "IsWindowOnDesktopNumber", "Ptr")
MoveWindowToDesktopNumberProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "MoveWindowToDesktopNumber", "Ptr")
IsPinnedWindowProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "IsPinnedWindow", "Ptr")
GetDesktopNameProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "GetDesktopName", "Ptr")
SetDesktopNameProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "SetDesktopName", "Ptr")
CreateDesktopProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "CreateDesktop", "Ptr")
RemoveDesktopProc := DllCall("GetProcAddress", "Ptr", hVirtualDesktopAccessor, "AStr", "RemoveDesktop", "Ptr")

; Add after loading the DLL
;if (hVirtualDesktopAccessor) {
;    MsgBox("VirtualDesktopAccessor.dll loaded successfully")
;    desktop_count := DllCall(GetDesktopCountProc, "Int")
;    current_desktop := DllCall(GetCurrentDesktopNumberProc, "Int")
;    MsgBox("Desktop count: " desktop_count "`nCurrent desktop: " current_desktop)
;} else {
;    MsgBox("Failed to load VirtualDesktopAccessor.dll")
;}

; Configure the initial setup
EnsureDesktopCountMatchesMap()

; =============================================
; Pause key
; Use the Pause key on a standard keyboard to play/pause media
; =============================================

*Pause::
{
    ; Check if the script and Pause key are enabled
    if (SystemUtilsEnabled && PauseKeyEnabled) {
        Send("{Media_Play_Pause}")
    }
}

; =============================================
; Virtual Desktops
; Allow control of virtual desktops
; =============================================

; Map the wheel left input to go to previous desktop
WheelLeft::{
    if (SystemUtilsEnabled && MouseWheelDesktopsEnabled && hVirtualDesktopAccessor) {
        GoToPrevDesktop()
    }
}

; Map the wheel right input to go to the next desktop
WheelRight:: {
    if (SystemUtilsEnabled && MouseWheelDesktopsEnabled && hVirtualDesktopAccessor) {
        GoToNextDesktop()
    }
}

;!1:: GoToPrevDesktop()  ; Alt+1 for previous desktop
;!2:: GoToNextDesktop()  ; Alt+2 for next desktop

ShowDesktopLabel(index) {
    global DesktopNames
    global DesktopLabelDuration

    static overlaygui := 0, textControl := 0

    if !IsObject(overlaygui) {
        overlaygui := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
        overlaygui.BackColor := "000000"
        overlaygui.SetFont("s36 Bold", "Segoe UI")
        textControl := overlaygui.Add("Text", "w600 Center cWhite BackgroundTrans")
    }

    label := (index + 1) ": " (DesktopNames.Has(index) ? DesktopNames[index] : "Desktop")
    textControl.Value := label
    overlaygui.Show("AutoSize Center")

    ; Cancel existing timer and start new one
    SetTimer(() => overlaygui.Hide(), 0)
    SetTimer(() => overlaygui.Hide(), -DesktopLabelDuration)
}

EnsureDesktopCountMatchesMap() {
    global DesktopNames, GetDesktopCountProc, CreateDesktopProc

    targetCount := DesktopNames.Count
    currentCount := DllCall(GetDesktopCountProc, "Int")

    ; Create new desktops if needed
    while (currentCount < targetCount) {
        DllCall(CreateDesktopProc)
        currentCount++
    }

    ; NOTE: Safely removing desktops is more complicated and may disrupt the current session.
    ; Safer to just ensure enough exist, not reduce count.
}

GetDesktopCount() {
    global GetDesktopCountProc
    count := DllCall(GetDesktopCountProc, "Int")
    return count
}

GoToDesktopNumber(num) {
    global GoToDesktopNumberProc
    DllCall(GoToDesktopNumberProc, "Int", num, "Int")
    return
}

GoToPrevDesktop() {
    global GetCurrentDesktopNumberProc, GoToDesktopNumberProc
    current := DllCall(GetCurrentDesktopNumberProc, "Int")
    last_desktop := GetDesktopCount() - 1

    ; Change desktop if we're not already at the first one
    if (current > 0) {
        GoToDesktopNumber(current - 1)
        ShowDesktopLabel(current - 1)
    }
    return
}

GoToNextDesktop() {
    global GetCurrentDesktopNumberProc, GoToDesktopNumberProc
    current := DllCall(GetCurrentDesktopNumberProc, "Int")
    last_desktop := GetDesktopCount() - 1

    ; Change desktop if we're not already at the last one
    if (current < last_desktop) {
        GoToDesktopNumber(current + 1)
        ShowDesktopLabel(current + 1)
    }
    return
}