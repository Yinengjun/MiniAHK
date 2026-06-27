; -*- coding: UTF-8 -*-
; ================================================================
; LockWindowClose.ahk - 锁定窗口
; ================================================================
;
; 功能：通过快捷键“锁定”当前窗口，阻止误触关闭，并提醒用户。
;
; 拦截手段（纯 AHK，不注入 DLL）：
;   1. 禁用系统菜单的 SC_CLOSE —— 使标题栏 × 变灰，点击 ×、系统菜单
;      “关闭”、Alt+F4 均被系统忽略，从而真正阻止关闭。
;   2. Alt+F4 守卫 —— 当前台为被保护窗口时静态拦截 Alt+F4 并提醒
;      （覆盖自绘标题栏程序的键盘关闭路径）。
;   3. 点击提醒 —— 存在被保护窗口时监听左键，用 WM_NCHITTEST 判断
;      是否点在 × 上，是则弹出提醒气泡。
;
; 已知限制：
;   - Chrome / VS Code / Electron 等自绘标题栏程序的关闭按钮位于客户区、
;     不经过系统菜单，故“变灰拦截鼠标点击”对其无效；但 Alt+F4 守卫仍有效。
;   - 程序自身的关闭逻辑（如浏览器 Ctrl+W、应用内“退出”）不在拦截范围内。
;
; 由主脚本通过 #Include 引入，并由 FeatureModules / Action 表统一控制。
; ================================================================

#NoEnv
SetWorkingDir %A_ScriptDir%

global LockClose                          ; 功能开关（主脚本统一管理）
global g_LockCloseItems := []             ; 已锁定窗口列表 [{hwnd, title}]
global g_LockCloseLastNotify := 0         ; 提醒防抖时间戳
; 菜单/标签文案（LockCloseMenuTitle 等）在主脚本顶部统一声明并初始化，
; 因为被 #Include 文件的顶层初始化不在自动执行段内、启动时不会运行。

; ------------------------------------------------------------
; 初始化（由主脚本调用）：复位运行时状态并建好托盘子菜单
; ------------------------------------------------------------
LockClose_Init() {
    global g_LockCloseItems, g_LockCloseLastNotify
    g_LockCloseItems := []
    g_LockCloseLastNotify := 0
    LockClose_RebuildMenu()
}

; ------------------------------------------------------------
; 切换当前活动窗口的锁定状态（由主脚本动态注册热键，默认 Ctrl+Shift+L）
; ------------------------------------------------------------
LockClose_Toggle:
    global LockClose, MasterSwitch
    if (!LockClose || !MasterSwitch)
        return

    WinGet, lc_hwnd, ID, A
    if (!lc_hwnd)
        return
    if (lc_hwnd = A_ScriptHwnd)            ; 不锁定本程序自身窗口
        return
    if (LockClose_IsSystemWindow(lc_hwnd)) ; 不锁定桌面/任务栏
        return

    if (LockClose_IndexOf(lc_hwnd) > 0)
        LockClose_Unprotect(lc_hwnd)
    else
        LockClose_Protect(lc_hwnd)
return

LockClose_Protect(hwnd) {
    if (!LockClose_WindowExists(hwnd))
        return

    LockClose_SetCloseEnabled(hwnd, false)

    WinGetTitle, title, ahk_id %hwnd%
    if (title = "")
        title := LockClose_GetUntitledLabel()

    LockClose_Add(hwnd, title)
    LockClose_ShowTip("🔒 已锁定窗口，将阻止误触关闭`n再次按快捷键或用托盘菜单可解锁")
}

LockClose_Unprotect(hwnd) {
    LockClose_SetCloseEnabled(hwnd, true)
    LockClose_Remove(hwnd)
    LockClose_ShowTip("🔓 已解锁窗口")
}

; ------------------------------------------------------------
; 启用 / 禁用窗口系统菜单的关闭项（SC_CLOSE）
;   enabled=false → MF_GRAYED：× 变灰、点击与 Alt+F4 被系统忽略
;   enabled=true  → MF_ENABLED：恢复正常
; ------------------------------------------------------------
LockClose_SetCloseEnabled(hwnd, enabled) {
    static SC_CLOSE := 0xF060, MF_BYCOMMAND := 0x0, MF_ENABLED := 0x0, MF_GRAYED := 0x1

    hSysMenu := DllCall("user32.dll\GetSystemMenu", "Ptr", hwnd, "Int", false, "Ptr")
    if (!hSysMenu)
        return

    flag := MF_BYCOMMAND | (enabled ? MF_ENABLED : MF_GRAYED)
    DllCall("user32.dll\EnableMenuItem", "Ptr", hSysMenu, "UInt", SC_CLOSE, "UInt", flag)
    DllCall("user32.dll\DrawMenuBar", "Ptr", hwnd)   ; 刷新标题栏 × 的外观
}

; ------------------------------------------------------------
; 提醒：气泡 + 提示音（带防抖，避免连点刷屏）
; ------------------------------------------------------------
LockClose_NotifyBlocked(hwnd := 0) {
    global g_LockCloseLastNotify
    now := A_TickCount
    if (now - g_LockCloseLastNotify < 600)
        return
    g_LockCloseLastNotify := now

    DllCall("user32.dll\MessageBeep", "UInt", 0x30)   ; MB_ICONWARNING
    LockClose_ShowTip("🔒 此窗口已锁定，已阻止关闭`n用解锁快捷键或托盘菜单可解除")
}

LockClose_ShowTip(text) {
    ToolTip, %text%
    SetTimer, LockClose_ClearTip, -2200
}

LockClose_ClearTip:
    ToolTip
return

; ------------------------------------------------------------
; Alt+F4 守卫：仅当前台为被保护窗口时拦截并提醒，否则放行
; （静态 #If，与主脚本的动态热键闸门相互独立）
; ------------------------------------------------------------
#If (LockClose_IsActiveProtected())
!F4::
    LockClose_NotifyBlocked()
return
#If

; ------------------------------------------------------------
; 点击提醒：仅当存在被保护窗口时监听左键（~ 透传，不影响正常点击）
; ------------------------------------------------------------
#If (LockClose_ShouldMonitorClicks())
~LButton::
    LockClose_OnGlobalClick()
return
#If

LockClose_IsActiveProtected() {
    global LockClose, MasterSwitch
    if (!MasterSwitch || !LockClose)
        return false
    WinGet, actHwnd, ID, A
    if (!actHwnd)
        return false
    return (LockClose_IndexOf(actHwnd) > 0)
}

LockClose_ShouldMonitorClicks() {
    global LockClose, MasterSwitch, g_LockCloseItems
    if (!MasterSwitch || !LockClose)
        return false
    return (IsObject(g_LockCloseItems) && g_LockCloseItems.Length() > 0)
}

LockClose_OnGlobalClick() {
    static WM_NCHITTEST := 0x84, HTCLOSE := 20

    MouseGetPos, , , winId
    if (!winId)
        return
    if (LockClose_IndexOf(winId) <= 0)
        return

    ; 取屏幕坐标（不依赖 CoordMode），打包进 lParam 后做非客户区命中测试
    VarSetCapacity(pt, 8, 0)
    DllCall("user32.dll\GetCursorPos", "Ptr", &pt)
    sx := NumGet(pt, 0, "Int")
    sy := NumGet(pt, 4, "Int")
    lParam := (sx & 0xFFFF) | ((sy & 0xFFFF) << 16)

    SendMessage, %WM_NCHITTEST%, 0, %lParam%, , ahk_id %winId%
    if (ErrorLevel = HTCLOSE)
        LockClose_NotifyBlocked(winId)
}

; ------------------------------------------------------------
; 列表管理
; ------------------------------------------------------------
LockClose_Add(hwnd, title) {
    global g_LockCloseItems
    if (!IsObject(g_LockCloseItems))
        g_LockCloseItems := []

    if (LockClose_IndexOf(hwnd))
        return

    safeTitle := LockClose_FormatTitle(title, 40)
    if (safeTitle = "")
        safeTitle := LockClose_GetUntitledLabel()

    g_LockCloseItems.Push({ hwnd: hwnd, title: safeTitle })
    LockClose_RebuildMenu()
}

LockClose_Remove(hwnd) {
    global g_LockCloseItems
    if (!IsObject(g_LockCloseItems))
        return

    index := LockClose_IndexOf(hwnd)
    if (!index)
        return

    g_LockCloseItems.RemoveAt(index)
    LockClose_RebuildMenu()
}

LockClose_IndexOf(hwnd) {
    global g_LockCloseItems
    if (!IsObject(g_LockCloseItems))
        return 0
    for index, item in g_LockCloseItems {
        if (item.hwnd = hwnd)
            return index
    }
    return 0
}

; 清除已不存在的窗口条目（程序自行关闭/崩溃留下的残项）
LockClose_PruneDead() {
    global g_LockCloseItems
    if (!IsObject(g_LockCloseItems) || g_LockCloseItems.Length() = 0)
        return false

    changed := false
    Loop {
        removed := false
        for index, item in g_LockCloseItems {
            if (!LockClose_WindowExists(item.hwnd)) {
                g_LockCloseItems.RemoveAt(index)
                removed := true
                changed := true
                break
            }
        }
    } until (!removed)
    return changed
}

; 解除全部锁定（功能关闭 / 退出 / 重启时调用）：恢复 × 并清空列表
LockClose_RestoreAll() {
    global g_LockCloseItems
    if (!IsObject(g_LockCloseItems))
        return
    if (g_LockCloseItems.Length() = 0)
        return

    hwnds := []
    for index, item in g_LockCloseItems
        hwnds.Push(item.hwnd)

    for index, hwnd in hwnds {
        if (LockClose_WindowExists(hwnd))
            LockClose_SetCloseEnabled(hwnd, true)
    }

    g_LockCloseItems := []
    LockClose_RebuildMenu()
}

; ------------------------------------------------------------
; 托盘子菜单
; ------------------------------------------------------------
LockClose_RebuildMenu() {
    global g_LockCloseItems
    global LockCloseMenuEmptyLabel, LockCloseMenuUnlockAllLabel

    if (!IsObject(g_LockCloseItems))
        g_LockCloseItems := []

    LockClose_PruneDead()

    ; 先确保菜单存在再清空（首次建立时 DeleteAll 不能用于不存在的菜单）
    Menu, LockCloseMenu, Add, %LockCloseMenuEmptyLabel%, LockClose_MenuNoOp
    Menu, LockCloseMenu, DeleteAll

    if (g_LockCloseItems.Length() = 0) {
        Menu, LockCloseMenu, Add, %LockCloseMenuEmptyLabel%, LockClose_MenuNoOp
        Menu, LockCloseMenu, Disable, %LockCloseMenuEmptyLabel%
        return
    }

    Menu, LockCloseMenu, Add, %LockCloseMenuUnlockAllLabel%, LockClose_MenuUnlockAll
    Menu, LockCloseMenu, Add

    for index, item in g_LockCloseItems {
        menuLabel := item.title . " (ID:" . item.hwnd . ")"
        Menu, LockCloseMenu, Add, %menuLabel%, LockClose_MenuUnlock
    }
}

LockClose_MenuNoOp:
return

LockClose_MenuUnlock:
    lc_hwnd := LockClose_GetHwndFromMenuLabel(A_ThisMenuItem)
    if (lc_hwnd)
        LockClose_Unprotect(lc_hwnd)
return

LockClose_MenuUnlockAll:
    LockClose_RestoreAll()
return

; ------------------------------------------------------------
; 辅助
; ------------------------------------------------------------
LockClose_IsSystemWindow(hwnd) {
    WinGetClass, cls, ahk_id %hwnd%
    if (cls = "Progman" || cls = "WorkerW")
        return true
    if (cls = "Shell_TrayWnd" || cls = "Shell_SecondaryTrayWnd")
        return true
    if (cls = "DV2ControlHost")
        return true
    return false
}

LockClose_WindowExists(hwnd) {
    prevDetect := A_DetectHiddenWindows
    DetectHiddenWindows, On
    exists := WinExist("ahk_id " . hwnd)
    DetectHiddenWindows, %prevDetect%
    return exists
}

LockClose_GetHwndFromMenuLabel(label) {
    if RegExMatch(label, "\(ID:(\d+)\)$", match)
        return match1 + 0
    return 0
}

LockClose_FormatTitle(title, maxLen) {
    title := RegExReplace(title, "[\r\n]+", " ")
    title := Trim(title)
    if (StrLen(title) <= maxLen)
        return title
    return SubStr(title, 1, maxLen - 3) . "..."
}

LockClose_GetUntitledLabel() {
    global LockCloseUntitledLabel
    if (LockCloseUntitledLabel = "")
        return "Untitled"
    return LockCloseUntitledLabel
}

#If
