; -*- coding: UTF-8 -*-

#NoEnv                      ; 不检查空变量
#SingleInstance Force        ; 强制单实例运行
#Persistent                  ; 保持常驻内存
SetWorkingDir %A_ScriptDir%  ; 设置工作目录为脚本所在目录
ConfigFile = %A_ScriptDir%\config.ini  ; 配置文件路径

global PresetSection := "WindowSizePresets"  ; WindowSize.ahk 所需的全局变量
global g_ScaleStep := 0.05                   ; WindowScaling.ahk 所需的全局变量
global MWB_Sensitivity := 10                   ; ModifyWindowBorders.ahk 所需的全局变量(鼠标移动敏感度)

; ========================
; 全局变量声明
; ========================
global PastePureText, WindowOnTop, WindowCenter, AltMove
global MinimizeWindow, WindowToTray, BorderlessWindow, SwitchProgramWindows, WindowSize
global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
global ModifyWindowBorders
global AutoStart
global MasterSwitch  ; 总开关
global AltMoveExcludeProcesses, AltMoveExcludeClasses
global SettingsGuiVisible := false
global CurrentTab := 1
global g_IsExiting := false
global WindowToTrayMenuTitle := "已隐藏窗口"
global WindowToTrayMenuEmptyLabel := "（无）"
global WindowToTrayMenuRestoreAllLabel := "恢复全部"
global WindowToTrayUntitledLabel := "无标题"

; GUI 控件变量（必须声明为全局）
global TabControl
global MasterSwitchCheck
global PastePureTextCheck, WindowOnTopCheck, WindowCenterCheck, AltMoveCheck
global MinimizeWindowCheck, WindowToTrayCheck, BorderlessWindowCheck, SwitchProgramWindowsCheck
global WindowSizeCheck, PreventHibernationCheck, ReconstructionWindowCheck
global EnsureNumLockCheck, WindowScalingCheck, ModifyWindowBordersCheck
global AltMoveExcludeProcessesEdit, AltMoveExcludeClassesEdit

; ========================
; 功能模块配置
; ========================
global FeatureModules := {}

InitFeatureModules() {
    global FeatureModules
    
    FeatureModules := []
    FeatureModules.Push({var: "PastePureText",        name: "粘贴纯文本",           hotkey: "Ctrl+Shift+V",      default: 1, script: "PastePureText.ahk"})
    FeatureModules.Push({var: "WindowOnTop",          name: "窗口置顶",             hotkey: "Ctrl+Shift+E",      default: 1, script: "WindowOnTop.ahk"})
    FeatureModules.Push({var: "WindowCenter",         name: "窗口居中",             hotkey: "Alt+C",             default: 1, script: "WindowCenter.ahk"})
    FeatureModules.Push({var: "AltMove",              name: "移动窗口",             hotkey: "Alt+左键",          default: 1, script: "AltMove.ahk"})
    FeatureModules.Push({var: "MinimizeWindow",       name: "最小化窗口",           hotkey: "Alt+A/M",           default: 1, script: "MinimizeWindow.ahk"})
    FeatureModules.Push({var: "WindowToTray",         name: "窗口收入托盘",         hotkey: "Alt+X / Ctrl+Shift+X", default: 1, script: "WindowToTray.ahk"})
    FeatureModules.Push({var: "EnsureNumLock",        name: "确保启用Num Lock",     hotkey: "",                  default: 1, script: ""})
    FeatureModules.Push({var: "BorderlessWindow",     name: "无边框化窗口",         hotkey: "Alt+B",             default: 1, script: "BorderlessWindow.ahk"})
    FeatureModules.Push({var: "SwitchProgramWindows", name: "切换程序窗口",         hotkey: "Ctrl+Alt+滚轮",     default: 1, script: "SwitchProgramWindows.ahk"})
    FeatureModules.Push({var: "WindowSize",           name: "修改窗口尺寸",         hotkey: "Alt+Z",             default: 1, script: "WindowSize.ahk"})
    FeatureModules.Push({var: "PreventHibernation",   name: "防止休眠",             hotkey: "",                  default: 0, script: "PreventHibernation.ahk"})
    FeatureModules.Push({var: "ReconstructionWindow", name: "重构窗口",             hotkey: "Alt+T",             default: 1, script: "ReconstructionWindow.ahk"})
    FeatureModules.Push({var: "WindowScaling",        name: "窗口缩放",             hotkey: "Ctrl+Shift+滚轮",   default: 1, script: "WindowScaling.ahk"})
    FeatureModules.Push({var: "ModifyWindowBorders",  name: "修改窗口边框",         hotkey: "Alt+右键",          default: 1, script: "ModifyWindowBorders.ahk"})
}

; ========================
; 初始化
; ========================
InitFeatureModules()
InitConfig()
EnsureNumLock_Init()
WindowToTray_Init()
CreateTrayMenu()
OnExit, ScriptOnExit

; ========================
; 配置操作
; ========================
InitConfig() {
    global ConfigFile, FeatureModules, MasterSwitch
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, WindowToTray, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    global AutoStart
    global AltMoveExcludeProcesses, AltMoveExcludeClasses
    
    if !FileExist(ConfigFile) {
        IniWrite, 1, %ConfigFile%, Settings, MasterSwitch
        for index, module in FeatureModules {
            varName := module.var
            defaultVal := module.default
            IniWrite, %defaultVal%, %ConfigFile%, Settings, %varName%
        }
        IniWrite, 0, %ConfigFile%, Settings, AutoStart
    }
    
    IniRead, MasterSwitch, %ConfigFile%, Settings, MasterSwitch, 1
    MasterSwitch := (MasterSwitch = 1)
    
    for index, module in FeatureModules {
        varName := module.var
        defaultVal := module.default
        IniRead, value, %ConfigFile%, Settings, %varName%, %defaultVal%
        %varName% := (value = 1)
    }

    IniRead, AutoStart, %ConfigFile%, Settings, AutoStart, 0
    AutoStart := (AutoStart = 1)

    IniRead, AltMoveExcludeProcesses, %ConfigFile%, Settings, AltMoveExcludeProcesses,
    IniRead, AltMoveExcludeClasses, %ConfigFile%, Settings, AltMoveExcludeClasses,
    
    SetPreventHibernation(PreventHibernation)
}

SaveConfig() {
    global ConfigFile, FeatureModules, MasterSwitch
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, WindowToTray, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    global AutoStart
    global AltMoveExcludeProcesses, AltMoveExcludeClasses
    
    IniWrite, % MasterSwitch ? 1 : 0, %ConfigFile%, Settings, MasterSwitch
    
    for index, module in FeatureModules {
        varName := module.var
        value := %varName%
        saveVal := value ? 1 : 0
        IniWrite, %saveVal%, %ConfigFile%, Settings, %varName%
    }

    IniWrite, %AltMoveExcludeProcesses%, %ConfigFile%, Settings, AltMoveExcludeProcesses
    IniWrite, %AltMoveExcludeClasses%, %ConfigFile%, Settings, AltMoveExcludeClasses
}

; ========================
; 托盘菜单
; ========================
CreateTrayMenu() {
    global FeatureModules, WindowToTrayMenuTitle
    global MasterSwitch, WindowToTray
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders

    Menu, Tray, DeleteAll
    Menu, Tray, NoStandard
    Menu, Tray, Add, 设置, ShowSettingsWindow
    Menu, Tray, Add
    Menu, Tray, Add, 总开关, ToggleMasterSwitch
    Menu, Tray, % MasterSwitch ? "Check" : "UnCheck", 总开关
    Menu, Tray, Add

    for index, module in FeatureModules {
        menuText := module.name
        if (module.hotkey != "")
            menuText .= " (" . module.hotkey . ")"
        Menu, Tray, Add, %menuText%, ToggleFeature
        varName := module.var
        value := %varName%
        Menu, Tray, % (MasterSwitch && value) ? "Check" : "UnCheck", %menuText%
    }

    if (MasterSwitch && WindowToTray) {
        WindowToTray_RebuildMenu()
        Menu, Tray, Add
        Menu, Tray, Add, %WindowToTrayMenuTitle%, :WindowToTrayMenu
    }

    Menu, Tray, Add
    Menu, Tray, Add, 重启程序, RestartScript
    Menu, Tray, Add, 退出, ExitScript
}

ToggleFeature:
    ToggleFeatureByMenu(A_ThisMenuItem)
return

ToggleFeatureByMenu(menuItem) {
    global FeatureModules
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, WindowToTray, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    
    for index, module in FeatureModules {
        checkText := module.name
        if (module.hotkey != "")
            checkText .= " (" . module.hotkey . ")"
        
        if (menuItem = checkText) {
            varName := module.var
            %varName% := !%varName%
            
            if (varName = "PreventHibernation") {
                value := %varName%
                SetPreventHibernation(value)
            }
            
            UpdateMenu()
            break
        }
    }
}

ToggleMasterSwitch:
    MasterSwitch := !MasterSwitch
    UpdateMenu()
return

; ========================
; 更新菜单
; ========================
UpdateMenu() {
    global MasterSwitch, WindowToTray, PreventHibernation

    ; 关闭WindowToTray时恢复所有隐藏窗口
    if (!MasterSwitch || !WindowToTray)
        WindowToTray_RestoreAllWindows(true)

    if (!MasterSwitch && PreventHibernation) {
        PreventHibernation := false
        SetPreventHibernation(false)
    }

    CreateTrayMenu()
    SaveConfig()

    if (SettingsGuiVisible)
        UpdateSettingsUI()
}

; ========================
; 设置窗口
; ========================
ShowSettingsWindow() {
    global SettingsGuiVisible, FeatureModules
    global TabControl, MasterSwitchCheck
    
    if (SettingsGuiVisible) {
        Gui, Settings:Show
        return
    }
    
    SettingsGuiVisible := true
    
    Gui, Settings:New, +Resize, 程序设置
    Gui, Settings:Font, s10
    
    Gui, Settings:Add, Tab3, x10 y10 w500 h350 vTabControl gTabChange, 基本设置|高级设置|关于
    
    Gui, Settings:Tab, 基本设置
    
    Gui, Settings:Add, GroupBox, x20 y40 w480 h50, 总开关
    Gui, Settings:Add, Checkbox, x30 y60 w100 h20 vMasterSwitchCheck gMasterSwitchChange, 启用所有功能
    
    ; 自动计算布局
    totalModules := FeatureModules.Length()
    colCount := 2  ; 两列布局
    rowHeight := 25
    groupBoxHeight := Ceil(totalModules / colCount) * rowHeight + 30
    
    Gui, Settings:Add, GroupBox, x20 y100 w480 h%groupBoxHeight%, 功能模块
    
    ; 自动排列功能开关
    for index, module in FeatureModules {
        col := Mod(index - 1, colCount) + 1
        row := Ceil(index / colCount)
        
        xPos := (col = 1) ? 30 : 270
        yPos := 100 + (row * rowHeight)
        
        checkText := module.name
        if (module.hotkey != "")
            checkText .= " (" . module.hotkey . ")"
        
        varName := module.var . "Check"
        handlerName := module.var . "Change"
        
        Gui, Settings:Add, Checkbox, x%xPos% y%yPos% w200 h20 v%varName% g%handlerName%, %checkText%
    }
    
    Gui, Settings:Tab, 高级设置
    Gui, Settings:Add, GroupBox, x20 y40 w480 h90, 开机自启动
    Gui, Settings:Add, Checkbox, x30 y70 vAutoStart gAutoStartChanged, 开机自启动
    Gui, Settings:Add, Button, x300 y66 w110 h24 gOpenStartupFolder, 打开启动文件夹

    Gui, Settings:Add, GroupBox, x20 y140 w480 h160, Alt+左键避让
    Gui, Settings:Add, Text, x30 y165 w460 h20, 排除进程名（逗号分隔，如 game.exe, steam.exe）
    Gui, Settings:Add, Edit, x30 y190 w460 h20 vAltMoveExcludeProcessesEdit gAltMoveExcludeChanged
    Gui, Settings:Add, Text, x30 y220 w460 h20, 排除窗口类名（逗号分隔，如 UnityWndClass, UnrealWindow）
    Gui, Settings:Add, Edit, x30 y245 w460 h20 vAltMoveExcludeClassesEdit gAltMoveExcludeChanged
    Gui, Settings:Add, Button, x30 y270 w140 h24 gAltMovePickWindow, 选定当前窗口
    
    Gui, Settings:Tab, 关于
    Gui, Settings:Add, Text, x20 y40 w480 h30 +Center, Windows Optimization for AHK
    Gui, Settings:Add, Text, x20 y80 w480 h200 +Wrap +Center, 版本：1.0`n`n作者：Yi
    
    UpdateSettingsUI()
    Gui, Settings:Show, w520 h410
    
    return
    
    SettingsGuiClose:
    SettingsGuiEscape:
        Gui, Settings:Destroy
        SettingsGuiVisible := false
    return
}

MasterSwitchChange:
    Gui, Settings:Submit, NoHide
    MasterSwitch := MasterSwitchCheck
    UpdateSettingsUI()
    UpdateMenu()
return

PastePureTextChange:
WindowOnTopChange:
WindowCenterChange:
AltMoveChange:
MinimizeWindowChange:
WindowToTrayChange:
EnsureNumLockChange:
BorderlessWindowChange:
SwitchProgramWindowsChange:
WindowSizeChange:
PreventHibernationChange:
ReconstructionWindowChange:
WindowScalingChange:
ModifyWindowBordersChange:
    HandleFeatureChange(A_ThisLabel)
return

AltMoveExcludeChanged:
    global AltMoveExcludeProcesses, AltMoveExcludeClasses
    global AltMoveExcludeProcessesEdit, AltMoveExcludeClassesEdit
    Gui, Settings:Submit, NoHide
    AltMoveExcludeProcesses := AltMoveExcludeProcessesEdit
    AltMoveExcludeClasses := AltMoveExcludeClassesEdit
    SaveConfig()
return

AltMovePickWindow:
    global SettingsGuiVisible
    global AltMoveExcludeProcesses, AltMoveExcludeClasses
    global AltMoveExcludeProcessesEdit, AltMoveExcludeClassesEdit

    Gui, Settings:Hide
    SettingsGuiVisible := false
    ToolTip, 请点击要避让的窗口
    Sleep, 200
    KeyWait, LButton, D
    KeyWait, LButton
    ToolTip

    CoordMode, Mouse, Screen
    MouseGetPos, , , targetHwnd
    if (targetHwnd) {
        WinGet, processName, ProcessName, ahk_id %targetHwnd%
        WinGetClass, className, ahk_id %targetHwnd%

        AltMoveExcludeProcesses := AltMove_AppendList(AltMoveExcludeProcesses, processName)
        AltMoveExcludeClasses := AltMove_AppendList(AltMoveExcludeClasses, className)

        GuiControl, Settings:, AltMoveExcludeProcessesEdit, %AltMoveExcludeProcesses%
        GuiControl, Settings:, AltMoveExcludeClassesEdit, %AltMoveExcludeClasses%
        SaveConfig()
    }

    Gui, Settings:Show
    SettingsGuiVisible := true
return

HandleFeatureChange(label) {
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, WindowToTray, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders

    global PastePureTextCheck, WindowOnTopCheck, WindowCenterCheck, AltMoveCheck
    global MinimizeWindowCheck, WindowToTrayCheck, BorderlessWindowCheck, SwitchProgramWindowsCheck
    global WindowSizeCheck, PreventHibernationCheck, ReconstructionWindowCheck
    global EnsureNumLockCheck, WindowScalingCheck, ModifyWindowBordersCheck
    
    varName := SubStr(label, 1, StrLen(label) - 6)
    checkVarName := varName . "Check"
    
    Gui, Settings:Submit, NoHide
    %varName% := %checkVarName%
    
    if (varName = "PreventHibernation") {
        value := %varName%
        SetPreventHibernation(value)
    }
    
    UpdateMenu()
}

TabChange:
    Gui, Settings:Submit, NoHide
    CurrentTab := TabControl
return

UpdateSettingsUI() {
    global MasterSwitch, FeatureModules, MasterSwitchCheck
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, WindowToTray, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    global AutoStart
    global AltMoveExcludeProcesses, AltMoveExcludeClasses
    global AltMoveExcludeProcessesEdit, AltMoveExcludeClassesEdit
    
    global PastePureTextCheck, WindowOnTopCheck, WindowCenterCheck, AltMoveCheck
    global MinimizeWindowCheck, WindowToTrayCheck, BorderlessWindowCheck, SwitchProgramWindowsCheck
    global WindowSizeCheck, PreventHibernationCheck, ReconstructionWindowCheck
    global EnsureNumLockCheck, WindowScalingCheck, ModifyWindowBordersCheck
    
    GuiControl, Settings:, MasterSwitchCheck, %MasterSwitch%
    EnableState := MasterSwitch ? "Enable" : "Disable"
    
    for index, module in FeatureModules {
        varName := module.var
        checkVarName := varName . "Check"
        value := %varName%
        displayValue := (MasterSwitch && value)
        
        GuiControl, Settings:, %checkVarName%, %displayValue%
        GuiControl, Settings:%EnableState%, %checkVarName%
    }

    UpdateAutoStartUI()

    GuiControl, Settings:, AltMoveExcludeProcessesEdit, %AltMoveExcludeProcesses%
    GuiControl, Settings:, AltMoveExcludeClassesEdit, %AltMoveExcludeClasses%
}

AltMove_AppendList(list, value) {
    if (value = "")
        return list

    if (AltMove_ValueInList(list, value))
        return list

    if (list = "")
        return value

    return list . ", " . value
}

AltMove_ValueInList(list, value) {
    if (list = "")
        return false

    StringLower, listLower, list
    StringLower, valueLower, value

    for index, item in StrSplit(listLower, ",") {
        token := Trim(item)
        if (token = "")
            continue
        if (token = valueLower)
            return true
    }

    return false
}

AutoStartChanged:
    global AutoStart
    oldAutoStart := AutoStart
    Gui, Settings:Submit, NoHide
    newAutoStart := AutoStart
    SaveAutoStartConfig(newAutoStart)
    ApplyAutoStartSettings(oldAutoStart, newAutoStart)
    UpdateAutoStartUI()
return

UpdateAutoStartUI() {
    global AutoStart
    GuiControl, Settings:, AutoStart, %AutoStart%
}

SaveAutoStartConfig(autoStartValue) {
    global ConfigFile
    IniWrite, % autoStartValue ? 1 : 0, %ConfigFile%, Settings, AutoStart
}

ApplyAutoStartSettings(oldAutoStart, newAutoStart) {
    if (newAutoStart && !oldAutoStart) {
        if (!CreateAutoStartShortcut())
            MsgBox, 48, 提示, 创建开机自启动快捷方式失败。
    } else if (!newAutoStart && oldAutoStart) {
        DeleteAutoStartShortcut()
    }
}

GetAutoStartShortcutName() {
    name := RegExReplace(A_ScriptName, "\.(ahk|exe)$")
    return name . ".lnk"
}

GetAutoStartShortcutPath() {
    return A_Startup . "\" . GetAutoStartShortcutName()
}

CreateAutoStartShortcut() {
    shortcutPath := GetAutoStartShortcutPath()
    FileCreateShortcut, %A_ScriptFullPath%, %shortcutPath%
    if ErrorLevel
        return false
    return true
}

DeleteAutoStartShortcut() {
    shortcutPath := GetAutoStartShortcutPath()
    FileDelete, %shortcutPath%
    if ErrorLevel
        return false
    return true
}

CheckAutoStartShortcut() {
    shortcutPath := GetAutoStartShortcutPath()
    return FileExist(shortcutPath)
}

OpenStartupFolder:
    Run, explorer "%A_Startup%"
return

; ========================
; 引入模块
; ========================
#Include %A_ScriptDir%\PastePureText.ahk
#Include %A_ScriptDir%\WindowOnTop.ahk
#Include %A_ScriptDir%\WindowCenter.ahk
#Include %A_ScriptDir%\AltMove.ahk
#Include %A_ScriptDir%\MinimizeWindow.ahk
#Include %A_ScriptDir%\WindowToTray.ahk
#Include %A_ScriptDir%\BorderlessWindow.ahk
#Include %A_ScriptDir%\SwitchProgramWindows.ahk
#Include %A_ScriptDir%\WindowSize.ahk
#Include %A_ScriptDir%\PreventHibernation.ahk
#Include %A_ScriptDir%\ReconstructionWindow.ahk
#Include %A_ScriptDir%\WindowScaling.ahk
#Include %A_ScriptDir%\ModifyWindowBorders.ahk

return

; ========================
; NumLock 功能
; ========================
EnsureNumLock_Init() {
    EnsureNumLock_Check()
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
    SetTimer, DoRestart, -1
return

DoRestart:
    g_IsExiting := true
    WindowToTray_RestoreAllWindows(false)
    Reload
return

ExitScript:
    SetTimer, DoExit, -1
return

DoExit:
    g_IsExiting := true
    WindowToTray_RestoreAllWindows(false)
    ExitApp
return

ScriptOnExit:
    if (g_IsExiting) {
        ExitApp
        return
    }

    g_IsExiting := true
    WindowToTray_RestoreAllWindows(false)
    ExitApp
return
