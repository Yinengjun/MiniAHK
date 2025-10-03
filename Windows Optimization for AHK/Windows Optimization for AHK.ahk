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
global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
global ModifyWindowBorders
global MasterSwitch  ; 总开关
global SettingsGuiVisible := false
global CurrentTab := 1

; GUI 控件变量（必须声明为全局）
global TabControl
global MasterSwitchCheck
global PastePureTextCheck, WindowOnTopCheck, WindowCenterCheck, AltMoveCheck
global MinimizeWindowCheck, BorderlessWindowCheck, SwitchProgramWindowsCheck
global WindowSizeCheck, PreventHibernationCheck, ReconstructionWindowCheck
global EnsureNumLockCheck, WindowScalingCheck, ModifyWindowBordersCheck

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
CreateTrayMenu()

; ========================
; 配置操作
; ========================
InitConfig() {
    global ConfigFile, FeatureModules, MasterSwitch
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    
    if !FileExist(ConfigFile) {
        IniWrite, 1, %ConfigFile%, Settings, MasterSwitch
        for index, module in FeatureModules {
            varName := module.var
            defaultVal := module.default
            IniWrite, %defaultVal%, %ConfigFile%, Settings, %varName%
        }
    }
    
    IniRead, MasterSwitch, %ConfigFile%, Settings, MasterSwitch, 1
    MasterSwitch := (MasterSwitch = 1)
    
    for index, module in FeatureModules {
        varName := module.var
        defaultVal := module.default
        IniRead, value, %ConfigFile%, Settings, %varName%, %defaultVal%
        %varName% := (value = 1)
    }
    
    SetPreventHibernation(PreventHibernation)
}

SaveConfig() {
    global ConfigFile, FeatureModules, MasterSwitch
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    
    IniWrite, % MasterSwitch ? 1 : 0, %ConfigFile%, Settings, MasterSwitch
    
    for index, module in FeatureModules {
        varName := module.var
        value := %varName%
        saveVal := value ? 1 : 0
        IniWrite, %saveVal%, %ConfigFile%, Settings, %varName%
    }
}

; ========================
; 托盘菜单
; ========================
CreateTrayMenu() {
    global FeatureModules
    
    Menu, Tray, NoStandard
    Menu, Tray, Add, 设置, ShowSettingsWindow
    Menu, Tray, Add
    Menu, Tray, Add, 总开关, ToggleMasterSwitch
    Menu, Tray, Add
    
    for index, module in FeatureModules {
        menuText := module.name
        if (module.hotkey != "")
            menuText .= " (" . module.hotkey . ")"
        Menu, Tray, Add, %menuText%, ToggleFeature
    }
    
    Menu, Tray, Add
    Menu, Tray, Add, 重启程序, RestartScript
    Menu, Tray, Add, 退出, ExitScript
    
    UpdateMenu()
}

ToggleFeature:
    ToggleFeatureByMenu(A_ThisMenuItem)
return

ToggleFeatureByMenu(menuItem) {
    global FeatureModules
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
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
    global FeatureModules, MasterSwitch
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global ModifyWindowBorders
    
    Menu, Tray, % MasterSwitch ? "Check" : "UnCheck", 总开关
    
    for index, module in FeatureModules {
        menuText := module.name
        if (module.hotkey != "")
            menuText .= " (" . module.hotkey . ")"
        
        varName := module.var
        value := %varName%
        Menu, Tray, % (MasterSwitch && value) ? "Check" : "UnCheck", %menuText%
    }
    
    if (!MasterSwitch && PreventHibernation) {
        PreventHibernation := false
        SetPreventHibernation(false)
    }
    
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
    Gui, Settings:Add, Text, x20 y40 w480 h200 +Wrap +Center, 高级设置功能`n`n更多配置选项
    
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

HandleFeatureChange(label) {
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global PastePureTextCheck, WindowOnTopCheck, WindowCenterCheck, AltMoveCheck
    global MinimizeWindowCheck, BorderlessWindowCheck, SwitchProgramWindowsCheck
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
    global MasterSwitch, FeatureModules
    global PastePureText, WindowOnTop, WindowCenter, AltMove
    global MinimizeWindow, BorderlessWindow, SwitchProgramWindows, WindowSize
    global PreventHibernation, ReconstructionWindow, EnsureNumLock, WindowScaling
    global MasterSwitchCheck
    global PastePureTextCheck, WindowOnTopCheck, WindowCenterCheck, AltMoveCheck
    global MinimizeWindowCheck, BorderlessWindowCheck, SwitchProgramWindowsCheck
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
}

; ========================
; 引入模块
; ========================
#Include %A_ScriptDir%\PastePureText.ahk
#Include %A_ScriptDir%\WindowOnTop.ahk
#Include %A_ScriptDir%\WindowCenter.ahk
#Include %A_ScriptDir%\AltMove.ahk
#Include %A_ScriptDir%\MinimizeWindow.ahk
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
    Reload
return

ExitScript:
    ExitApp
return
