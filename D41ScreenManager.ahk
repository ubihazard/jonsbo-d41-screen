#Requires AutoHotkey v2.0+
#SingleInstance Ignore

; Force sensor panel on D41 screen and move other windows away from it.

Delay := 1000
; D41 screen size values at 125% scaling: 1024x640. They must be adjusted
; if scaling is changed, e.g. 1280x800 at 100% scaling,
; or make a call to `SetThreadDpiAwarenessContext`.
; Screen must be set to landscape (flipped).
D41Width := 1280
D41Height := 800
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr") ; requires Creators update on Windows 10

; Alt + D to trigger manually (for debugging)
;Alt & D::MoveWindows()
SetTimer(MoveWindows, Delay)

; Get monitor information
GetMonitorInfo() {
    monitors := []
    monitorCount := MonitorGetCount()
    loop monitorCount {
        try {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
        } catch Error as err {
            continue
        }
        monitor := {}
        monitor.Left := left
        monitor.Top := top
        monitor.Right := right
        monitor.Bottom := bottom
        monitors.Push(monitor)
    }
    return monitors
}

; Find Jonsbo D41 screen
FindD41(monitors) {
    idx := 0
    wmin := 100000
    hmin := 100000
    loop monitors.Length {
        dw := monitors[A_Index].Right - monitors[A_Index].Left
        dh := monitors[A_Index].Bottom - monitors[A_Index].Top
        if (dw < wmin || dh < hmin) {
            wmin := dw
            hmin := dh
            idx := A_Index
        }
    }
    if (wmin == D41Width && hmin == D41Height) {
        return idx
    }
    return 0
}

; Find the primary screen
FindPrimary(monitors, d41) {
    idx := 0
    if (monitors.Length > 1) {
        if (d41 == 1) {
            idx := 2
        } else {
            idx := 1
        }
    }
    return idx
}

; MouseGetPos() is broken
GetCursorPos() {
    pt := Buffer(8)
    if (DllCall("GetCursorPos", "ptr", pt, "int"))
        return [NumGet(pt, 0, "int"), NumGet(pt, 4, "int")]
    return [0, 0]
}

; Determine fullscreen state
GetFullScreen() {
    state := Buffer(4)
    DllCall("shell32.dll\SHQueryUserNotificationState", "ptr", state, "int")
    return NumGet(state, 0, "int")
}

; Determine "do not disturb" state
GetDND() {
    byte := 82 * 2 ; 82 byte in hex string
    data := RegRead("HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\Cache\DefaultAccount\$$windows.data.notifications.quiethourssettings\Current", "Data")
    if (StrLen(data) > byte)
        return SubStr(data, 1 + byte, 2) == "50" ; 'P'riorityOnly
    return 0
}

MoveWindows() {
    monitors := GetMonitorInfo()
    if (monitors.Length < 1) {
        return
    }
    d41 := FindD41(monitors)
    if (d41 == 0) {
        return
    }
    primary := FindPrimary(monitors, d41)
    windows := WinGetList()
    for id in windows {
        try {
            class := WinGetClass(id)
            proc := WinGetProcessName("ahk_id " . id)
            WinGetClientPos(&xpos, &ypos, &w, &h, "ahk_id " . id)
        } catch Error as err {
            continue
        }
        if (class != "TForm_HWMonitoringSensorPanel") {
            if (class == "Shell_TrayWnd") {
                continue
            }
            ;if (xpos >= monitors[d41].Left || ypos >= monitors[d41].Top) {
            ;    try {title := WinGetTitle("ahk_id " . id)}
            ;    MsgBox(title . ": " . xpos . ", " . ypos)
            ;}
            if (((xpos >= monitors[d41].Left && xpos < monitors[d41].Right)
            ||   (ypos >= monitors[d41].Top  && ypos < monitors[d41].Bottom))
            && primary != 0) {
                try {
                    minmax := WinGetMinMax("ahk_id " . id)
                    if (minmax != 0) {
                        WinRestore("ahk_id " . id)
                    }
                    WinMove(monitors[primary].Left, monitors[primary].Top, , , "ahk_id " . id)
                    if (minmax != 0) {
                        if (minmax > 0) {
                            WinMaximize("ahk_id " . id)
                        } else {
                            WinMinimize("ahk_id " . id)
                        }
                    }
                }
            }
        } else {
            if (xpos != monitors[d41].Left || ypos != monitors[d41].Top) {
                try {
                    WinMove(monitors[d41].Left, monitors[d41].Top, D41Width, D41Height, "ahk_id " . id)
                    WinMoveTop("ahk_id " . id)
                    WinMoveBottom("ahk_class Shell_TrayWnd")
                    WinActivate("ahk_id " . id)
                }
            } else if (primary == 0) {
                try {
                    WinMoveTop("ahk_id " . id)
                    WinActivate("ahk_id " . id)
                }
            }
        }
    }
}
