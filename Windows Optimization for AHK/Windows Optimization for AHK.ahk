; -*- coding: UTF-8 -*-

#NoEnv                      ; 不检查空变量
#SingleInstance Force        ; 强制单实例运行
#Persistent                  ; 保持常驻内存
SetWorkingDir %A_ScriptDir%  ; 设置工作目录为脚本所在目录
ConfigFile = %A_ScriptDir%\config.ini  ; 配置文件路径

global PresetSection := "WindowSizePresets"  ; WindowSize.ahk 所需的全局变量

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
global WindowSize
global PreventHibernation
global ReconstructionWindow
global EnsureNumLock
global MasterSwitch  ; 总开关
;global QuickWorkbench   := true

; ========================
; 设置窗口相关变量
; ========================
global SettingsGuiVisible := false
global CurrentTab := 1

; ========================
; 初始化
; ========================
InitConfig()
EnsureNumLock_Init()

InitConfig() {
    global ConfigFile
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock
    global MasterSwitch

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
        IniWrite, 1, %ConfigFile%, Settings, WindowSize
        IniWrite, 0, %ConfigFile%, Settings, PreventHibernation
        IniWrite, 1, %ConfigFile%, Settings, ReconstructionWindow
        IniWrite, 1, %ConfigFile%, Settings, EnsureNumLock
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

    IniRead, WindowSize, %ConfigFile%, Settings, WindowSize, 1
    WindowSize := (WindowSize = 1)

    IniRead, PreventHibernation, %ConfigFile%, Settings, PreventHibernation, 0
    PreventHibernation := (PreventHibernation = 1)

    ; 立即同步到PreventHibernation
    SetPreventHibernation(PreventHibernation)

    IniRead, ReconstructionWindow, %ConfigFile%, Settings, ReconstructionWindow, 1
    ReconstructionWindow := (ReconstructionWindow = 1)

    IniRead, EnsureNumLock, %ConfigFile%, Settings, EnsureNumLock, 1
    EnsureNumLock := (EnsureNumLock = 1)

    IniRead, MasterSwitch, %ConfigFile%, Settings, MasterSwitch, 1
    MasterSwitch := (MasterSwitch = 1)
}

; ========================
; 保存配置函数
; ========================
SaveConfig() {
    global ConfigFile
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock
    global MasterSwitch

    IniWrite, % PastePureText ? 1 : 0, %ConfigFile%, Settings, PastePureText
    IniWrite, % WindowOnTop ? 1 : 0, %ConfigFile%, Settings, WindowOnTop
    IniWrite, % WindowCenter ? 1 : 0, %ConfigFile%, Settings, WindowCenter
    IniWrite, % AltMove ? 1 : 0, %ConfigFile%, Settings, AltMove
    IniWrite, % MinimizeWindow ? 1 : 0, %ConfigFile%, Settings, MinimizeWindow
    IniWrite, % BorderlessWindow ? 1 : 0, %ConfigFile%, Settings, BorderlessWindow
    IniWrite, % SwitchProgramWindows ? 1 : 0, %ConfigFile%, Settings, SwitchProgramWindows
    IniWrite, % WindowSize ? 1 : 0, %ConfigFile%, Settings, WindowSize
    IniWrite, % PreventHibernation ? 1 : 0, %ConfigFile%, Settings, PreventHibernation
    IniWrite, % ReconstructionWindow ? 1 : 0, %ConfigFile%, Settings, ReconstructionWindow
    IniWrite, % EnsureNumLock ? 1 : 0, %ConfigFile%, Settings, EnsureNumLock
    IniWrite, % MasterSwitch ? 1 : 0, %ConfigFile%, Settings, MasterSwitch
}

; ========================
; 托盘菜单
; ========================
Menu, Tray, NoStandard
Menu, Tray, Add, 设置, ShowSettingsWindow
Menu, Tray, Add
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
Menu, Tray, Add, 修改窗口尺寸 (Alt+Z), Toggle_WindowSize
Menu, Tray, Add, 重构窗口 (Alt+T), Toggle_ReconstructionWindow
Menu, Tray, Add, 防止休眠, Toggle_PreventHibernation
Menu, Tray, Add, 确保启用Num Lock, Toggle_EnsureNumLock

Menu, Tray, Add
Menu, Tray, Add, 重启程序, RestartScript
Menu, Tray, Add, 退出, ExitScript

; 初始化菜单状态
UpdateMenu()

; ========================
; 托盘图标双击事件（打开设置窗口）
; ========================
OnMessage(0x404, "AHK_NOTIFYICON")
AHK_NOTIFYICON(wParam, lParam, msg, hwnd) {
    if (lParam = 0x203) { ; WM_LBUTTONDBLCLK
        ShowSettingsWindow()
    }
}

; ========================
; 设置窗口
; ========================
ShowSettingsWindow() {
    global SettingsGuiVisible, CurrentTab
    
    if (SettingsGuiVisible) {
        Gui, Settings:Show
        return
    }
    
    SettingsGuiVisible := true
    
    ; 创建设置窗口
    Gui, Settings:New, +Resize +MaximizeBox +MinimizeBox, 程序设置
    Gui, Settings:Font, s10
    
    ; 标签页控件
    Gui, Settings:Add, Tab3, x10 y10 w500 h350 vTabControl gTabChange, 基本设置|高级设置|关于
    
    ; ========================
    ; 基本设置标签页
    ; ========================
    Gui, Settings:Tab, 基本设置
    
    ; 总开关
    Gui, Settings:Add, GroupBox, x20 y40 w480 h50, 总开关
    Gui, Settings:Add, Checkbox, x30 y60 w100 h20 vMasterSwitchCheck gMasterSwitchChange, 启用所有功能
    
    ; 功能开关组
    Gui, Settings:Add, GroupBox, x20 y100 w480 h240, 功能模块
    
    ; 第一列
    Gui, Settings:Add, Checkbox, x30 y120 w200 h20 vPastePureTextCheck gPastePureTextChange, 粘贴纯文本 (Ctrl+Shift+V)
    Gui, Settings:Add, Checkbox, x30 y145 w200 h20 vWindowOnTopCheck gWindowOnTopChange, 窗口置顶 (Ctrl+Shift+E)
    Gui, Settings:Add, Checkbox, x30 y170 w200 h20 vWindowCenterCheck gWindowCenterChange, 窗口居中 (Alt+C)
    Gui, Settings:Add, Checkbox, x30 y195 w200 h20 vAltMoveCheck gAltMoveChange, 移动窗口 (Alt+左键)
    Gui, Settings:Add, Checkbox, x30 y220 w200 h20 vMinimizeWindowCheck gMinimizeWindowChange, 最小化窗口 (Alt+A/M)
    
    ; 第二列
    Gui, Settings:Add, Checkbox, x270 y120 w200 h20 vBorderlessWindowCheck gBorderlessWindowChange, 无边框化窗口 (Alt+B)
    Gui, Settings:Add, Checkbox, x270 y145 w200 h20 vSwitchProgramWindowsCheck gSwitchProgramWindowsChange, 切换程序窗口
    Gui, Settings:Add, Checkbox, x270 y170 w200 h20 vWindowSizeCheck gWindowSizeChange, 修改窗口尺寸 (Alt+Z)
    Gui, Settings:Add, Checkbox, x270 y195 w200 h20 vPreventHibernationCheck gPreventHibernationChange, 防止休眠
    Gui, Settings:Add, Checkbox, x270 y220 w200 h20 vReconstructionWindowCheck gReconstructionWindowChange, 重构窗口 (Alt+T)
    Gui, Settings:Add, Checkbox, x30 y250 w200 h20 vEnsureNumLockCheck gEnsureNumLockChange, 确保启用Num Lock

    ; 功能说明
    Gui, Settings:Add, Text, x30 y250 w440 h80 +Wrap, 提示：`n• 总开关关闭时，所有功能将被禁用`n• 快捷键功能需要对应的功能模块启用才能生效`n• 防止休眠功能会阻止系统自动进入休眠状态`n• 双击托盘图标可快速打开此设置窗口
    
    ; ========================
    ; 高级设置标签页
    ; ========================
    Gui, Settings:Tab, 高级设置
    Gui, Settings:Add, Text, x20 y40 w480 h50 +Center, 高级设置功能
    Gui, Settings:Add, Text, x20 y100 w480 h100 +Wrap +Center, 更多高级配置选项，`n如快捷键自定义、窗口尺寸预设等功能。
    
    ; ========================
    ; 关于标签页
    ; ========================
    Gui, Settings:Tab, 关于
    Gui, Settings:Add, Text, x20 y40 w480 h30 +Center, Windows Optimization for AHK
    Gui, Settings:Add, Text, x20 y80 w480 h200 +Wrap +Center, 版本：1.0`n`n这是一个集成多种功能的AutoHotkey脚本。`n`n功能包括：`n• 纯文本粘贴`n• 窗口置顶与居中`n• 窗口移动与调整`n• 无边框窗口`n• 程序窗口切换`n• 防止系统休眠`n`n作者：Yi`n更新日期：2025年

    ; 更新界面状态
    UpdateSettingsUI()
    
    ; 显示窗口
    Gui, Settings:Show, w520 h410
    
    return
    
    SettingsGuiClose:
    SettingsGuiEscape:
        Gui, Settings:Destroy
        SettingsGuiVisible := false
    return
}

; ========================
; 标签页切换事件
; ========================
TabChange:
    Gui, Settings:Submit, NoHide
    CurrentTab := TabControl
return

; ========================
; 更新设置界面状态
; ========================
UpdateSettingsUI() {
    global MasterSwitch, PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize, PreventHibernation
    
    ; 更新复选框状态
    GuiControl, Settings:, MasterSwitchCheck, %MasterSwitch%
    
    ; 子功能复选框状态（受总开关影响）
    GuiControl, Settings:, PastePureTextCheck, % (MasterSwitch && PastePureText)
    GuiControl, Settings:, WindowOnTopCheck, % (MasterSwitch && WindowOnTop)
    GuiControl, Settings:, WindowCenterCheck, % (MasterSwitch && WindowCenter)
    GuiControl, Settings:, AltMoveCheck, % (MasterSwitch && AltMove)
    GuiControl, Settings:, MinimizeWindowCheck, % (MasterSwitch && MinimizeWindow)
    GuiControl, Settings:, BorderlessWindowCheck, % (MasterSwitch && BorderlessWindow)
    GuiControl, Settings:, SwitchProgramWindowsCheck, % (MasterSwitch && SwitchProgramWindows)
    GuiControl, Settings:, WindowSizeCheck, % (MasterSwitch && WindowSize)
    GuiControl, Settings:, PreventHibernationCheck, % (MasterSwitch && PreventHibernation)
    GuiControl, Settings:, ReconstructionWindowCheck, % (MasterSwitch && ReconstructionWindow)
    GuiControl, Settings:, EnsureNumLockCheck, % (MasterSwitch && EnsureNumLock)
    
    ; 根据总开关状态启用/禁用子功能控件
    EnableState := MasterSwitch ? "Enable" : "Disable"
    GuiControl, Settings:%EnableState%, PastePureTextCheck
    GuiControl, Settings:%EnableState%, WindowOnTopCheck
    GuiControl, Settings:%EnableState%, WindowCenterCheck
    GuiControl, Settings:%EnableState%, AltMoveCheck
    GuiControl, Settings:%EnableState%, MinimizeWindowCheck
    GuiControl, Settings:%EnableState%, BorderlessWindowCheck
    GuiControl, Settings:%EnableState%, SwitchProgramWindowsCheck
    GuiControl, Settings:%EnableState%, WindowSizeCheck
    GuiControl, Settings:%EnableState%, PreventHibernationCheck
    GuiControl, Settings:%EnableState%, ReconstructionWindowCheck
    GuiControl, Settings:%EnableState%, EnsureNumLockCheck
}

; ========================
; 设置窗口事件处理
; ========================
MasterSwitchChange:
    Gui, Settings:Submit, NoHide
    MasterSwitch := MasterSwitchCheck
    UpdateSettingsUI()
    UpdateMenu()
    SaveConfig()
return

PastePureTextChange:
    Gui, Settings:Submit, NoHide
    PastePureText := PastePureTextCheck
    UpdateMenu()
    SaveConfig()
return

WindowOnTopChange:
    Gui, Settings:Submit, NoHide
    WindowOnTop := WindowOnTopCheck
    UpdateMenu()
    SaveConfig()
return

WindowCenterChange:
    Gui, Settings:Submit, NoHide
    WindowCenter := WindowCenterCheck
    UpdateMenu()
    SaveConfig()
return

AltMoveChange:
    Gui, Settings:Submit, NoHide
    AltMove := AltMoveCheck
    UpdateMenu()
    SaveConfig()
return

MinimizeWindowChange:
    Gui, Settings:Submit, NoHide
    MinimizeWindow := MinimizeWindowCheck
    UpdateMenu()
    SaveConfig()
return

BorderlessWindowChange:
    Gui, Settings:Submit, NoHide
    BorderlessWindow := BorderlessWindowCheck
    UpdateMenu()
    SaveConfig()
return

SwitchProgramWindowsChange:
    Gui, Settings:Submit, NoHide
    SwitchProgramWindows := SwitchProgramWindowsCheck
    UpdateMenu()
    SaveConfig()
return

WindowSizeChange:
    Gui, Settings:Submit, NoHide
    WindowSize := WindowSizeCheck
    UpdateMenu()
    SaveConfig()
return

PreventHibernationChange:
    Gui, Settings:Submit, NoHide
    PreventHibernation := PreventHibernationCheck
    UpdateMenu()
    SetPreventHibernation(PreventHibernation)
    SaveConfig()
return

ReconstructionWindowChange:
    Gui, Settings:Submit, NoHide
    ReconstructionWindow := ReconstructionWindowCheck
    UpdateMenu()
    SaveConfig()
return

EnsureNumLockChange:
    Gui, Settings:Submit, NoHide
    EnsureNumLock := EnsureNumLockCheck
    UpdateMenu()
    SaveConfig()
return

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
#Include %A_ScriptDir%\WindowSize.ahk
#Include %A_ScriptDir%\PreventHibernation.ahk
#Include %A_ScriptDir%\ReconstructionWindow.ahk

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

    if (MasterSwitch && WindowSize)
        Menu, Tray, Check, 修改窗口尺寸 (Alt+Z)
    else
        Menu, Tray, UnCheck, 修改窗口尺寸 (Alt+Z)

    if (MasterSwitch && ReconstructionWindow)
        Menu, Tray, Check, 重构窗口 (Alt+T)
    else
        Menu, Tray, UnCheck, 重构窗口 (Alt+T)

    ; 防止休眠菜单复选状态
    if (MasterSwitch && PreventHibernation)
        Menu, Tray, Check, 防止休眠
    else
        Menu, Tray, UnCheck, 防止休眠

    ; ===== 响应式同步防休眠状态 =====
    ; 如果总开关关闭，则强制关闭防休眠
    if (!MasterSwitch && PreventHibernation) {
        PreventHibernation := false
        SetPreventHibernation(false)
    }

    if (MasterSwitch && EnsureNumLock)
        Menu, Tray, Check, 确保启用Num Lock
    else
        Menu, Tray, UnCheck, 确保启用Num Lock
        
    SaveConfig()

    ; 如果设置窗口打开，同步更新界面
    if (SettingsGuiVisible) {
        UpdateSettingsUI()
    }
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

Toggle_WindowSize:
    WindowSize := !WindowSize
    UpdateMenu()
return

Toggle_ReconstructionWindow:
    ReconstructionWindow := !ReconstructionWindow
    UpdateMenu()
return

Toggle_PreventHibernation:
    PreventHibernation := !PreventHibernation
    UpdateMenu()
    
    ; 调用子脚本接口，让防休眠立即生效
    SetPreventHibernation(PreventHibernation)
return

Toggle_EnsureNumLock:
    EnsureNumLock := !EnsureNumLock
    UpdateMenu()
return

; ========================
; 小功能
; ========================
; 确保启用 NumLock
EnsureNumLock_Init() {
    ; 启动时立即检查一次
    EnsureNumLock_Check()
    ; 每 10 分钟检查一次
    SetTimer, EnsureNumLock_Check, 600000
}

EnsureNumLock_Check() {
    global EnsureNumLock, MasterSwitch
    if (MasterSwitch && EnsureNumLock) {
        if !GetKeyState("NumLock", "T")
            SetNumLockState, On
    }
}

; ========================
; 程序控制
; ========================
RestartScript:
    Reload
return

ExitScript:
    ExitApp
    