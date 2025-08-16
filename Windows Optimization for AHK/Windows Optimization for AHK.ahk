; -*- coding: UTF-8 -*-

#NoEnv                      ; 不检查空变量
#SingleInstance Force        ; 强制单实例运行
#Persistent                  ; 保持常驻内存
SetWorkingDir %A_ScriptDir%  ; 设置工作目录为脚本所在目录

; ========================
; 全局功能开关
; ========================
global PastePureText  := true
global WindowOnTop    := true
global WindowCenter   := true
global AltMove        := true
;global QuickWorkbench := true
global MasterSwitch   := true   ; 总开关

; ========================
; 托盘菜单
; ========================
Menu, Tray, NoStandard
Menu, Tray, Add, [Master Switch] (Ctrl+Alt+Q), Toggle_MasterSwitch
Menu, Tray, Add
Menu, Tray, Add, PastePureText (Ctrl+Shift+V), Toggle_PastePureText
Menu, Tray, Add, WindowOnTop (Ctrl+Shift+E), Toggle_WindowOnTop
Menu, Tray, Add, WindowCenter (Alt+C), Toggle_WindowCenter
Menu, Tray, Add, AltMove (Alt+LeftButton), Toggle_AltMove
;Menu, Tray, Add, QuickWorkbench (Alt+Q), Toggle_QuickWorkbench

Menu, Tray, Add
Menu, Tray, Add, Restart Program, RestartScript
Menu, Tray, Add, Exit, ExitScript

; 初始化菜单状态
UpdateMenu()

; ========================
; 引入功能模块
; ========================
#Include %A_ScriptDir%\PastePureText.ahk
#Include %A_ScriptDir%\WindowOnTop.ahk
#Include %A_ScriptDir%\WindowCenter.ahk
#Include %A_ScriptDir%\AltMove.ahk
;#Include %A_ScriptDir%\QuickWorkbench.ahk

return  ; 主线程到此结束，等待事件

; ========================
; 更新托盘菜单复选框状态
; ========================
UpdateMenu() {
    global
    ; 总开关
    if (MasterSwitch)
        Menu, Tray, Check, [Master Switch] (Ctrl+Alt+Q)
    else
        Menu, Tray, UnCheck, [Master Switch] (Ctrl+Alt+Q)

    ; 子功能（受 MasterSwitch 控制）
    if (MasterSwitch && PastePureText)
        Menu, Tray, Check, PastePureText (Ctrl+Shift+V)
    else
        Menu, Tray, UnCheck, PastePureText (Ctrl+Shift+V)

    if (MasterSwitch && WindowOnTop)
        Menu, Tray, Check, WindowOnTop (Ctrl+Shift+E)
    else
        Menu, Tray, UnCheck, WindowOnTop (Ctrl+Shift+E)

    if (MasterSwitch && WindowCenter)
        Menu, Tray, Check, WindowCenter (Alt+C)
    else
        Menu, Tray, UnCheck, WindowCenter (Alt+C)

    if (MasterSwitch && AltMove)
        Menu, Tray, Check, AltMove (Alt+LeftButton)
    else
        Menu, Tray, UnCheck, AltMove (Alt+LeftButton)

;    if (MasterSwitch && QuickWorkbench)
;        Menu, Tray, Check, QuickWorkbench (Alt+Q)
;    else
;        Menu, Tray, UnCheck, QuickWorkbench (Alt+Q)
}

; ========================
; 快捷键：总开关
; ========================
Toggle_MasterSwitch:
    MasterSwitch := !MasterSwitch
    UpdateMenu()
return

; ========================
; 菜单切换事件
; ========================
Toggle_PastePureText:
    PastePureText := !PastePureText
    UpdateMenu()
return

Toggle_WindowOnTop:
    WindowOnTop := !WindowOnTop
    UpdateMenu()
return

Toggle_WindowCenter:
    WindowCenter := !WindowCenter
    UpdateMenu()
return

Toggle_AltMove:
    AltMove := !AltMove
    UpdateMenu()
return

;Toggle_QuickWorkbench:
;    QuickWorkbench := !QuickWorkbench
;    UpdateMenu()
;return

; ========================
; 程序控制
; ========================
RestartScript:
    Reload
return

ExitScript:
    ExitApp
