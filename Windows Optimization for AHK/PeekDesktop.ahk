; Alt+D temporary desktop access

global PeekDesktop

global PD_MinimizeUsed := false
global PD_WaitRestore := false

#If (PeekDesktop && MasterSwitch)

!d::
    PeekDesktop_Toggle()
return

#If

PeekDesktop_ModeMonitor:
    PeekDesktop_CheckDeferredRestore()
return

PeekDesktop_Toggle() {
    global PD_WaitRestore, PD_MinimizeUsed

    if (PD_WaitRestore) {
        PeekDesktop_RestoreMinimized()
        PD_WaitRestore := false
        SetTimer, PeekDesktop_ModeMonitor, Off
        return
    }

    if (PD_MinimizeUsed) {
        PeekDesktop_RestoreMinimized()
        return
    }

    PeekDesktop_StartMinimize()
    PeekDesktop_ArmDeferredRestore()
}

PeekDesktop_Cleanup(forceRestore := true) {
    global PD_WaitRestore, PD_MinimizeUsed

    SetTimer, PeekDesktop_ModeMonitor, Off

    if (forceRestore && (PD_MinimizeUsed || PD_WaitRestore))
        PeekDesktop_RestoreMinimized()

    PD_WaitRestore := false

    if (!forceRestore)
        PD_MinimizeUsed := false
}

PeekDesktop_StartMinimize() {
    global PD_MinimizeUsed, PD_WaitRestore

    PD_WaitRestore := false
    SetTimer, PeekDesktop_ModeMonitor, Off

    WinMinimizeAll
    PD_MinimizeUsed := true
}

PeekDesktop_RestoreMinimized() {
    global PD_MinimizeUsed

    if (!PD_MinimizeUsed)
        return

    WinMinimizeAllUndo
    PD_MinimizeUsed := false
}

PeekDesktop_ArmDeferredRestore() {
    global PD_MinimizeUsed, PD_WaitRestore

    if (!PD_MinimizeUsed)
        return

    PD_WaitRestore := true
    SetTimer, PeekDesktop_ModeMonitor, 120
}

PeekDesktop_CheckDeferredRestore() {
    global PD_WaitRestore

    if (!PD_WaitRestore) {
        SetTimer, PeekDesktop_ModeMonitor, Off
        return
    }

    WinGet, activeHwnd, ID, A
    if (!activeHwnd)
        return

    if (PeekDesktop_IsDesktopContext(activeHwnd))
        return

    PeekDesktop_RestoreMinimized()
    PD_WaitRestore := false
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
