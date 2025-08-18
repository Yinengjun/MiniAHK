; -*- coding: UTF-8 -*-

#NoEnv                      ; 不检查空变量
#SingleInstance Force        ; 强制单实例运行
#Persistent                  ; 保持常驻内存
SetWorkingDir %A_ScriptDir%  ; 设置工作目录为脚本所在目录
ConfigFile = %A_ScriptDir%\config.ini  ; 配置文件路径

; ========================
; 全局功能开关
; ========================
global PastePureText
global WindowOnTop
global WindowCenter
global AltMove
global MinimizeWindow
global BorderlessWindow
global SwitchProgramWindows
global MasterSwitch  ; 总开关
;global QuickWorkbench   := true

; ========================
; 初始化
; ========================
InitConfig()

InitConfig() {
    global ConfigFile
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, MasterSwitch

    ; 如果配置文件不存在，则生成默认配置
    if !FileExist(ConfigFile)
    {
        IniWrite, 1, %ConfigFile%, Settings, PastePureText
        IniWrite, 1, %ConfigFile%, Settings, WindowOnTop
        IniWrite, 1, %ConfigFile%, Settings, WindowCenter
        IniWrite, 1, %ConfigFile%, Settings, AltMove
        IniWrite, 1, %ConfigFile%, Settings, MinimizeWindow
        IniWrite, 1, %ConfigFile%, Settings, BorderlessWindow
        IniWrite, 1, %ConfigFile%, Settings, SwitchProgramWindows
        IniWrite, 1, %ConfigFile%, Settings, MasterSwitch
    }

    ; 读取配置
    IniRead, PastePureText, %ConfigFile%, Settings, PastePureText, 1
    PastePureText := (PastePureText = 1)

    IniRead, WindowOnTop, %ConfigFile%, Settings, WindowOnTop, 1
    WindowOnTop := (WindowOnTop = 1)

    IniRead, WindowCenter, %ConfigFile%, Settings, WindowCenter, 1
    WindowCenter := (WindowCenter = 1)

    IniRead, AltMove, %ConfigFile%, Settings, AltMove, 1
    AltMove := (AltMove = 1)

    IniRead, MinimizeWindow, %ConfigFile%, Settings, MinimizeWindow, 1
    MinimizeWindow := (MinimizeWindow = 1)

    IniRead, BorderlessWindow, %ConfigFile%, Settings, BorderlessWindow, 1
    BorderlessWindow := (BorderlessWindow = 1)

    IniRead, SwitchProgramWindows, %ConfigFile%, Settings, SwitchProgramWindows, 1
    SwitchProgramWindows := (SwitchProgramWindows = 1)

    IniRead, MasterSwitch, %ConfigFile%, Settings, MasterSwitch, 1
    MasterSwitch := (MasterSwitch = 1)
}

; ========================
; 保存配置函数
; ========================
SaveConfig() {
    global ConfigFile
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, MasterSwitch

    IniWrite, % PastePureText ? 1 : 0, %ConfigFile%, Settings, PastePureText
    IniWrite, % WindowOnTop ? 1 : 0, %ConfigFile%, Settings, WindowOnTop
    IniWrite, % WindowCenter ? 1 : 0, %ConfigFile%, Settings, WindowCenter
    IniWrite, % AltMove ? 1 : 0, %ConfigFile%, Settings, AltMove
    IniWrite, % MinimizeWindow ? 1 : 0, %ConfigFile%, Settings, MinimizeWindow
    IniWrite, % BorderlessWindow ? 1 : 0, %ConfigFile%, Settings, BorderlessWindow
    IniWrite, % SwitchProgramWindows ? 1 : 0, %ConfigFile%, Settings, SwitchProgramWindows
    IniWrite, % MasterSwitch ? 1 : 0, %ConfigFile%, Settings, MasterSwitch
}

; ========================
; 托盘菜单
; ========================
Menu, Tray, NoStandard
Menu, Tray, Add, 总开关, Toggle_MasterSwitch
Menu, Tray, Add
Menu, Tray, Add, 粘贴纯文本 (Ctrl+Shift+V), Toggle_PastePureText
Menu, Tray, Add, 窗口置顶 (Ctrl+Shift+E), Toggle_WindowOnTop
Menu, Tray, Add, 窗口居中 (Alt+C), Toggle_WindowCenter
Menu, Tray, Add, 移动窗口 (Alt+左键), Toggle_AltMove
;Menu, Tray, Add, QuickWorkbench (Alt+Q), Toggle_QuickWorkbench
Menu, Tray, Add, 最小化窗口 (Alt+A / Alt+M), Toggle_MinimizeWindow
Menu, Tray, Add, 无边框化窗口 (Alt+B), Toggle_BorderlessWindow
Menu, Tray, Add, 切换程序窗口 (Ctrl+Alt+鼠标滚轮), Toggle_SwitchProgramWindows

Menu, Tray, Add
Menu, Tray, Add, 重启程序, RestartScript
Menu, Tray, Add, 退出, ExitScript

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
#Include %A_ScriptDir%\MinimizeWindow.ahk
#Include %A_ScriptDir%\BorderlessWindow.ahk
#Include %A_ScriptDir%\SwitchProgramWindows.ahk

return  ; 主线程到此结束，等待事件

; ========================
; 更新托盘菜单复选框状态
; ========================
UpdateMenu() {
    global
    ; 总开关
    if (MasterSwitch)
        Menu, Tray, Check, 总开关
    else
        Menu, Tray, UnCheck, 总开关

    ; 子功能（受 MasterSwitch 控制）
    if (MasterSwitch && PastePureText)
        Menu, Tray, Check, 粘贴纯文本 (Ctrl+Shift+V)
    else
        Menu, Tray, UnCheck, 粘贴纯文本 (Ctrl+Shift+V)

    if (MasterSwitch && WindowOnTop)
        Menu, Tray, Check, 窗口置顶 (Ctrl+Shift+E)
    else
        Menu, Tray, UnCheck, 窗口置顶 (Ctrl+Shift+E)

    if (MasterSwitch && WindowCenter)
        Menu, Tray, Check, 窗口居中 (Alt+C)
    else
        Menu, Tray, UnCheck, 窗口居中 (Alt+C)

    if (MasterSwitch && AltMove)
        Menu, Tray, Check, 移动窗口 (Alt+左键)
    else
        Menu, Tray, UnCheck, 移动窗口 (Alt+左键)

;    if (MasterSwitch && QuickWorkbench)
;        Menu, Tray, Check, QuickWorkbench (Alt+Q)
;    else
;        Menu, Tray, UnCheck, QuickWorkbench (Alt+Q)

    if (MasterSwitch && MinimizeWindow)
        Menu, Tray, Check, 最小化窗口 (Alt+A / Alt+M)
    else
        Menu, Tray, UnCheck, 最小化窗口 (Alt+A / Alt+M)

    if (MasterSwitch && BorderlessWindow)
        Menu, Tray, Check, 无边框化窗口 (Alt+B)
    else
        Menu, Tray, UnCheck, 无边框化窗口 (Alt+B)

    if (MasterSwitch && SwitchProgramWindows)
        Menu, Tray, Check, 切换程序窗口 (Ctrl+Alt+鼠标滚轮)
    else
        Menu, Tray, UnCheck, 切换程序窗口 (Ctrl+Alt+鼠标滚轮)   

    SaveConfig() 

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

Toggle_MinimizeWindow:
    MinimizeWindow := !MinimizeWindow
    UpdateMenu()
return

Toggle_BorderlessWindow:
    BorderlessWindow := !BorderlessWindow
    UpdateMenu()
return

Toggle_SwitchProgramWindows:
    SwitchProgramWindows := !SwitchProgramWindows
    UpdateMenu()
return

; ========================
; 程序控制
; ========================
RestartScript:
    Reload
return

ExitScript:
    ExitApp
