; Alt+D temporary desktop access

global PeekDesktop

global PD_MinimizeUsed := false
global PD_MinimizedWindows := []
global PD_NewWindows := []
global PD_GraceEnd := 0

PeekDesktop_Trigger:
    if (!PeekDesktop || !MasterSwitch)
        return
    PeekDesktop_Toggle()
return

PeekDesktop_ModeMonitor:
    PeekDesktop_CheckDeferredRestore()
return

PeekDesktop_DelayedRestore:
    PeekDesktop_RestoreMinimized()
return

PeekDesktop_Toggle() {
    global PD_MinimizeUsed
    if (PD_MinimizeUsed) {
        PeekDesktop_RestoreMinimized()
        return
    }
    PeekDesktop_StartMinimize()
    PeekDesktop_ArmDeferredRestore()
}

PeekDesktop_Cleanup(forceRestore := true) {
    global PD_MinimizeUsed
    SetTimer, PeekDesktop_ModeMonitor, Off
    SetTimer, PeekDesktop_DelayedRestore, Off
    if (forceRestore && PD_MinimizeUsed)
        PeekDesktop_RestoreMinimized()
    if (!forceRestore)
        PD_MinimizeUsed := false
}

PeekDesktop_StartMinimize() {
    global PD_MinimizeUsed, PD_MinimizedWindows, PD_NewWindows, PD_GraceEnd
    PD_MinimizeUsed := false
    PD_MinimizedWindows := []
    PD_NewWindows := []
    SetTimer, PeekDesktop_ModeMonitor, Off
    SetTimer, PeekDesktop_DelayedRestore, Off

    WinGet, windows, List
    Loop, %windows% {
        hwnd := windows%A_Index%
        WinGet, style, Style, ahk_id %hwnd%
        if (style & 0x10000000) {
            if (!PeekDesktop_IsDesktopContext(hwnd))
                PD_MinimizedWindows.Push(hwnd)
        }
    }

    WinMinimizeAll
    Sleep, 100

    PeekDesktop_FocusDesktop()
    Sleep, 50

    WinGet, activeHwnd, ID, A
    if (activeHwnd && !PeekDesktop_IsDesktopContext(activeHwnd))
        PeekDesktop_FocusDesktop()

    PD_GraceEnd := A_TickCount + 500
    PD_MinimizeUsed := true
}

PeekDesktop_RestoreMinimized() {
    global PD_MinimizeUsed, PD_MinimizedWindows, PD_NewWindows
    if (!PD_MinimizeUsed)
        return

    SetTimer, PeekDesktop_ModeMonitor, Off
    SetTimer, PeekDesktop_DelayedRestore, Off
    WinGet, activeBeforeRestore, ID, A
    WinMinimizeAllUndo
    if (activeBeforeRestore && !PeekDesktop_IsDesktopContext(activeBeforeRestore))
        WinActivate, ahk_id %activeBeforeRestore%

    PD_MinimizeUsed := false
    PD_MinimizedWindows := []
    PD_NewWindows := []
}

PeekDesktop_ArmDeferredRestore() {
    global PD_MinimizeUsed
    if (!PD_MinimizeUsed)
        return
    SetTimer, PeekDesktop_ModeMonitor, 200
}

PeekDesktop_CheckDeferredRestore() {
    global PD_MinimizeUsed, PD_MinimizedWindows, PD_NewWindows, PD_GraceEnd
    if (!PD_MinimizeUsed) {
        SetTimer, PeekDesktop_ModeMonitor, Off
        return
    }

    if (A_TickCount < PD_GraceEnd)
        return

    WinGet, activeHwnd, ID, A
    if (!activeHwnd)
        return

    if (PeekDesktop_IsDesktopContext(activeHwnd)) {
        if (PD_NewWindows.Length() > 0)
            PeekDesktop_RestoreMinimized()
        return
    }

    isOldWindow := false
    for i, hwnd in PD_MinimizedWindows {
        if (hwnd = activeHwnd) {
            isOldWindow := true
            break
        }
    }

    if (isOldWindow) {
        PeekDesktop_RestoreMinimized()
        return
    }

    isNewWindow := false
    for i, hwnd in PD_NewWindows {
        if (hwnd = activeHwnd) {
            isNewWindow := true
            break
        }
    }

    if (!isNewWindow) {
        PD_NewWindows.Push(activeHwnd)
        SetTimer, PeekDesktop_DelayedRestore
    }
}

PeekDesktop_FocusDesktop() {
    WinGet, workerwList, List, ahk_class WorkerW
    Loop, %workerwList% {
        hwnd := workerwList%A_Index%
        WinGet, controls, ControlList, ahk_id %hwnd%
        if (InStr(controls, "SHELLDLL_DefView")) {
            WinActivate, ahk_id %hwnd%
            return
        }
    }
    WinActivate, ahk_class Progman
}

PeekDesktop_IsDesktopContext(hwnd) {
    WinGetClass, className, ahk_id %hwnd%

    if (className = "Progman")
        return true
    if (className = "WorkerW")
        return true
    if (className = "Shell_TrayWnd")
        return true
    if (className = "Shell_SecondaryTrayWnd")
        return true
    if (className = "DV2ControlHost")
        return true
    if (className = "#32768")
        return true

    return false
}