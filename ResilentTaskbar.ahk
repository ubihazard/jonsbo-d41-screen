#Requires AutoHotkey v2.0+
#SingleInstance Ignore

; Keep (force) taskbar on top of all windows.

Delay := 1000
DllCall("SetThreadDpiAwarenessContext", "ptr", -4, "ptr") ; requires Creators update on 10

; Alt + T to trigger manually (for debugging)
;Alt & T::ForceTaskbar()
SetTimer(ForceTaskbar, Delay)

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

ForceTaskbar() {
    monitors := GetMonitorInfo()
    if (monitors.Length < 1) {
        return
    }

    primary := 1
    windows := WinGetList()
    for id in windows {
        try {
            class := WinGetClass(id)
            WinGetClientPos(&xpos, &ypos, &w, &h, "ahk_id " . id)
        }
        ; Force taskbar on top
        if (class == "Shell_TrayWnd") {
            ;MouseGetPos(&x, &y)
            pos := GetCursorPos(), x := pos[1], y := pos[2]
            if ((x >= monitors[primary].Left && x < monitors[primary].Right)
            &&  (y >= monitors[primary].Bottom - 1)) {
                ;MsgBox(x . "," . y . "; " . w . "x" . h . " | " . GetFullScreen() . " | " . GetDND())
                try {
                    ;WinSetAlwaysOnTop(1, "ahk_class " . class)
                    WinMoveTop("ahk_class " . class)
                    WinActivate("ahk_class " . class)
                }
            }
        }
    }
}
