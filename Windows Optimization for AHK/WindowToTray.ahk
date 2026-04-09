#NoEnv
SetWorkingDir %A_ScriptDir%

global WindowToTray
global WindowToTrayItems := []

WindowToTray_Init() {
    global WindowToTrayItems
    if (!IsObject(WindowToTrayItems))
        WindowToTrayItems := []
    WindowToTray_RebuildMenu()
    OnMessage(0x404, "WindowToTray_TrayClick")
}

; Ctrl+Shift+X -> 在鼠标位置弹出已隐藏窗口菜单
^+x::
if (!WindowToTray || !MasterSwitch)
    return
Menu, WindowToTrayMenu, Show
return

; Alt + X -> 将当前活动窗口放到托盘
!x::
if (!WindowToTray || !MasterSwitch)
    return
WinGet, hwnd, ID, A
if (!hwnd)
    return
if (hwnd = A_ScriptHwnd)
    return
WinGetTitle, title, ahk_id %hwnd%
if (title = "")
    title := WindowToTray_GetUntitledLabel()
WindowToTray_Add(hwnd, title)
WinHide, ahk_id %hwnd%
return

WindowToTray_NoOp:
return

WindowToTray_Restore:
    hwnd := WindowToTray_GetHwndFromMenuLabel(A_ThisMenuItem)
    if (!hwnd)
        return

    if (!WindowToTray_WindowExists(hwnd)) {
        WindowToTray_Remove(hwnd)
        return
    }

    WindowToTray_ShowWindow(hwnd)
    WindowToTray_Remove(hwnd)
return

WindowToTray_RestoreAll:
    WindowToTray_RestoreAllWindows()
return

WindowToTray_Add(hwnd, title) {
    global WindowToTrayItems
    if (!IsObject(WindowToTrayItems))
        WindowToTrayItems := []

    if (WindowToTray_IndexOf(hwnd))
        return

    safeTitle := WindowToTray_FormatTitle(title, 40)
    if (safeTitle = "")
        safeTitle := WindowToTray_GetUntitledLabel()

    item := { hwnd: hwnd, title: safeTitle }
    WindowToTrayItems.Push(item)
    WindowToTray_RebuildMenu()
}

WindowToTray_Remove(hwnd) {
    global WindowToTrayItems
    if (!IsObject(WindowToTrayItems))
        return

    index := WindowToTray_IndexOf(hwnd)
    if (!index)
        return

    WindowToTrayItems.RemoveAt(index)
    WindowToTray_RebuildMenu()
}

WindowToTray_RestoreAllWindows(activate := true) {
    global WindowToTrayItems
    if (!IsObject(WindowToTrayItems))
        return

    if (WindowToTrayItems.Length() = 0)
        return

    hwnds := []
    for index, item in WindowToTrayItems
        hwnds.Push(item.hwnd)

    for index, hwnd in hwnds {
        if (WindowToTray_WindowExists(hwnd))
            WindowToTray_ShowWindow(hwnd, activate)
        WindowToTray_Remove(hwnd)
    }
}

WindowToTray_RebuildMenu() {
    global WindowToTrayMenuEmptyLabel
    global WindowToTrayMenuRestoreAllLabel
    global WindowToTrayItems

    if (!IsObject(WindowToTrayItems))
        WindowToTrayItems := []

    Menu, WindowToTrayMenu, Add, %WindowToTrayMenuEmptyLabel%, WindowToTray_NoOp
    Menu, WindowToTrayMenu, DeleteAll

    if (WindowToTrayItems.Length() = 0) {
        Menu, WindowToTrayMenu, Add, %WindowToTrayMenuEmptyLabel%, WindowToTray_NoOp
        Menu, WindowToTrayMenu, Disable, %WindowToTrayMenuEmptyLabel%
        return
    }

    Menu, WindowToTrayMenu, Add, %WindowToTrayMenuRestoreAllLabel%, WindowToTray_RestoreAll
    Menu, WindowToTrayMenu, Add

    for index, item in WindowToTrayItems {
        menuLabel := item.title . " (ID:" . item.hwnd . ")"
        Menu, WindowToTrayMenu, Add, %menuLabel%, WindowToTray_Restore
    }
}

WindowToTray_ShowWindow(hwnd, activate := true) {
    prevDetect := A_DetectHiddenWindows
    DetectHiddenWindows, On

    WinShow, ahk_id %hwnd%
    WinRestore, ahk_id %hwnd%
    if (activate)
        WinActivate, ahk_id %hwnd%

    DetectHiddenWindows, %prevDetect%
}

WindowToTray_GetItemByIndex(index) {
    global WindowToTrayItems
    if (!IsObject(WindowToTrayItems))
        return ""

    if (index < 1)
        return ""
    if (index > WindowToTrayItems.Length())
        return ""
    return WindowToTrayItems[index]
}

WindowToTray_IndexOf(hwnd) {
    global WindowToTrayItems
    if (!IsObject(WindowToTrayItems))
        return 0

    for index, item in WindowToTrayItems {
        if (item.hwnd = hwnd)
            return index
    }
    return 0
}

WindowToTray_GetHwndFromMenuLabel(label) {
    if RegExMatch(label, "\(ID:(\d+)\)$", match)
        return match1 + 0
    return 0
}

WindowToTray_WindowExists(hwnd) {
    prevDetect := A_DetectHiddenWindows
    DetectHiddenWindows, On
    exists := WinExist("ahk_id " . hwnd)
    DetectHiddenWindows, %prevDetect%
    return exists
}

WindowToTray_FormatTitle(title, maxLen) {
    title := RegExReplace(title, "[\r\n]+", " ")
    title := Trim(title)
    if (StrLen(title) <= maxLen)
        return title
    return SubStr(title, 1, maxLen - 3) . "..."
}

WindowToTray_GetUntitledLabel() {
    global WindowToTrayUntitledLabel
    if (WindowToTrayUntitledLabel = "")
        return "Untitled"
    return WindowToTrayUntitledLabel
}

; 托盘图标左键单击 -> 弹出已隐藏窗口菜单
WindowToTray_TrayClick(wParam, lParam) {
    global WindowToTray, MasterSwitch
    if (lParam = 0x202) {  ; WM_LBUTTONUP
        if (WindowToTray && MasterSwitch) {
            Menu, WindowToTrayMenu, Show
            return 0
        }
    }
}
