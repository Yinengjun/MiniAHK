#NoEnv
#SingleInstance force

; ------------------------
; 模块开关变量
; ------------------------
global AltMove
global hwnd := 0
global hook := 0
global dragging := false
global x0 := 0, y0 := 0
global wx := 0, wy := 0
global ww := 0, wh := 0

; ------------------------
; Alt + 左键拖动窗口
; ------------------------
#If (AltMove && MasterSwitch)
!LButton::
{
    if (dragging)  ; 已经在拖动中，不重复安装钩子
        return

    CoordMode, Mouse, Screen
    MouseGetPos, x0, y0, hwnd
    if !hwnd
        return

    WinGetPos, wx, wy, ww, wh, ahk_id %hwnd%

    ; 安装鼠标钩子
    hook := SetMouseHook()
    dragging := true
}
return

~LButton Up::
~Alt Up::
{
    if (dragging) {
        RemoveMouseHook(hook)
        hook := 0
        dragging := false
    }
}
return

#If  ; 结束 #If 块，使后面的热键不受影响

; ------------------------
; 钩子函数
; ------------------------
SetMouseHook() {
    return DllCall("SetWindowsHookEx", "int", 14, "ptr", RegisterCallback("MouseProc", "Fast"), "ptr", 0, "uint", 0, "ptr")
}

RemoveMouseHook(h) {
    DllCall("UnhookWindowsHookEx", "ptr", h)
}

MouseProc(nCode, wParam, lParam) {
    global hwnd, x0, y0, wx, wy, ww, wh, dragging

    if (nCode >= 0) {
        if (wParam = 0x200) {  ; WM_MOUSEMOVE
            mouseX := NumGet(lParam + 0, "Int")
            mouseY := NumGet(lParam + 4, "Int")

            ; 计算新的窗口位置并移动
            new_wx := wx + (mouseX - x0)
            new_wy := wy + (mouseY - y0)
            DllCall("MoveWindow", "ptr", hwnd, "int", new_wx, "int", new_wy, "int", ww, "int", wh, "int", False)
        }
    }
    return DllCall("CallNextHookEx", "ptr", 0, "int", nCode, "ptr", wParam, "ptr", lParam)
}