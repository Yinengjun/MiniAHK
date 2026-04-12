; Alt+D temporary desktop access

global PeekDesktop

global DP_MinimizeUsed := false
global DP_WaitRestore := false

#If (PeekDesktop && MasterSwitch)

!d::
    PeekDesktop_Toggle()
return

#If

PeekDesktop_ModeMonitor:
    PeekDesktop_CheckDeferredRestore()
return

PeekDesktop_Toggle() {
    global DP_WaitRestore, DP_MinimizeUsed

    if (DP_WaitRestore) {
        PeekDesktop_RestoreMinimized()
        DP_WaitRestore := false
        SetTimer, PeekDesktop_ModeMonitor, Off
        return
    }

    if (DP_MinimizeUsed) {
        PeekDesktop_RestoreMinimized()
        return
    }

    PeekDesktop_StartMinimize()
    PeekDesktop_ArmDeferredRestore()
}

PeekDesktop_Cleanup(forceRestore := true) {
    global DP_WaitRestore, DP_MinimizeUsed

    SetTimer, PeekDesktop_ModeMonitor, Off

    if (forceRestore && (DP_MinimizeUsed || DP_WaitRestore))
        PeekDesktop_RestoreMinimized()

    DP_WaitRestore := false

    if (!forceRestore)
        DP_MinimizeUsed := false
}

PeekDesktop_StartMinimize() {
    global DP_MinimizeUsed, DP_WaitRestore

    DP_WaitRestore := false
    SetTimer, PeekDesktop_ModeMonitor, Off

    WinMinimizeAll
    DP_MinimizeUsed := true
}

PeekDesktop_RestoreMinimized() {
    global DP_MinimizeUsed

    if (!DP_MinimizeUsed)
        return

    WinMinimizeAllUndo
    DP_MinimizeUsed := false
}

PeekDesktop_ArmDeferredRestore() {
    global DP_MinimizeUsed, DP_WaitRestore

    if (!DP_MinimizeUsed)
        return

    DP_WaitRestore := true
    SetTimer, PeekDesktop_ModeMonitor, 120
}

PeekDesktop_CheckDeferredRestore() {
    global DP_WaitRestore

    if (!DP_WaitRestore) {
        SetTimer, PeekDesktop_ModeMonitor, Off
        return
    }

    WinGet, activeHwnd, ID, A
    if (!activeHwnd)
        return

    if (PeekDesktop_IsDesktopContext(activeHwnd))
        return

    PeekDesktop_RestoreMinimized()
    DP_WaitRestore := false
    SetTimer, PeekDesktop_ModeMonitor, Off
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
