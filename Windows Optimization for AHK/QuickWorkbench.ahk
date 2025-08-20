; -*- coding: utf-8 -*-
#NoEnv
#SingleInstance Force

; ========================
; 配置
; ========================
ConfigFile := A_ScriptDir "\Workspace\config.ini"
BaseFolder := A_ScriptDir "\Workspace"
DefaultHotkey := "!q"    ; Alt+Q
HotkeyShow := DefaultHotkey

; ========================
; 初始化
; ========================
; 如果没有 Workspace 就自动生成
If !FileExist(BaseFolder)
    FileCreateDir, %BaseFolder%

; 如果没有配置文件，就生成
If !FileExist(ConfigFile)
{
    IniWrite, %DefaultHotkey%, %ConfigFile%, Hotkey, Show
}
IniRead, HotkeyShow, %ConfigFile%, Hotkey, Show, %DefaultHotkey%

; 注册热键
Hotkey, %HotkeyShow%, ShowLauncher
Menu, Tray, Add, 配置热键, MenuChangeHotkey
Menu, Tray, Default, 配置热键
return

; ========================
; 主界面
; ========================
global GUI_LOCK := false

ShowLauncher:
    ; 防止快速连续触发
    if (GUI_LOCK)
        return
    GUI_LOCK := true

    ; 暂停自动关闭计时器
    SetTimer, AutoClose, Off

    ; 销毁旧窗口和旧 ImageList
    Gui, Destroy
    if (IL) {
        IL_Destroy(IL)
        Sleep, 20  ; 给资源释放一点时间
    }

    Gui, +AlwaysOnTop -Caption +ToolWindow
    Gui, Margin, 10, 10

    ; Tab 标签（子文件夹）
    Tabs := ""
    Loop, Files, %BaseFolder%\*, D
        Tabs .= (Tabs = "" ? "" : "|") A_LoopFileName
    Tabs .= "|+"  ; 最后一个是加号

    Gui, Add, Tab2, x0 y0 w480 h360 vCurrentTab gSwitchTab, %Tabs%
    Gui, Tab

    ; ListView 显示文件
    Gui, Add, ListView, x10 y40 w460 h280 Icon AltSubmit gOpenFile vFileList, 名称|路径
    LV_ModifyCol(2, 0) ; 隐藏路径列

    ; 固定窗口按钮 📌
    Gui, Add, Button, x10 y330 w40 h25 gTogglePin vPinBtn, % (IsPinned ? "📍" : "📌")

    ; 初始化 ImageList
    IL := IL_Create(40,1,1)
    LV_SetImageList(IL)

    ; 加载当前 Tab 的文件
    GuiControlGet, CurrentTab
    LoadFiles(CurrentTab)

    ; 窗口显示到鼠标中心
    CoordMode, Mouse, Screen
    MouseGetPos, mx, my
    w := 500, h := 370
    x := mx - w//2, y := my - h//2
    Gui, Show, x%x% y%y% w%w% h%h%, 快捷工作台

    ; 重启自动关闭计时器
    SetTimer, AutoClose, 100

    ; 解除锁
    GUI_LOCK := false
return

; ========================
; Tab 切换
; ========================
SwitchTab:
    Gui, Submit, NoHide
    if (CurrentTab = "+")
    {
        InputBox, newName, 新建子文件夹, 请输入文件夹名称:
        if (ErrorLevel = 0 and newName != "")
        {
            FileCreateDir, %BaseFolder%\%newName%
            ; 重建窗口
            GoSub, ShowLauncher
        }
    }
    else
        LoadFiles(CurrentTab)
return

; ========================
; 双击打开
; ========================
OpenFile:
    if (A_GuiEvent = "DoubleClick") {
        Row := A_EventInfo

        ; 双击空白处
        if (Row = 0) {
            GuiControlGet, CurrentTab
            folder := BaseFolder "\" CurrentTab
            if FileExist(folder)
                Run, explorer.exe "%folder%"

            ; 清除 ListView 所有选中行
            Loop, % LV_GetCount()
                LV_Modify(A_Index, "D")

            return
        }

        ; 双击文件或快捷方式
        LV_GetText(name, Row, 1)
        LV_GetText(path, Row, 2)

        if (path = "" || !FileExist(path)) {
            MsgBox, 48, 错误, 文件不存在或快捷方式无效：`n%name%
            return
        }

        ; 判断是否是文件夹
        if (FileExist(path "\.")) {
            Run, explorer.exe "%path%"
        } else {
            Run, %path%
        }

        if (!IsPinned)
            Gui, Destroy
    }
return

; ========================
; 固定窗口 📌
; ========================
TogglePin:
    IsPinned := !IsPinned
    if (IsPinned)
        GuiControl,, PinBtn, 📍  ; 固定
    else
        GuiControl,, PinBtn, 📌  ; 未固定
return

; ========================
; 自动关闭
; ========================
AutoClose:
    IfWinNotActive, 快捷工作台
    {
        if (!IsPinned) {
            Gui, Destroy
            SetTimer, AutoClose, Off
        }
    }
return

; ========================
; 加载文件
; ========================
LoadFiles(subdir) {
    global BaseFolder, IL
    LV_Delete()
    if (IL)  ; 防止重复销毁报错
        IL_Destroy(IL)
    IL := IL_Create(40,1,1)
    LV_SetImageList(IL)

    folder := BaseFolder "\" subdir
    if !FileExist(folder)
        return

    Loop, Files, %folder%\*   ; 只取当前目录，不递归
    {
        SplitPath, A_LoopFileFullPath, name

        ; 判断是否是快捷方式
        if (SubStr(A_LoopFileFullPath, -3) = ".lnk") {
            target := GetShortcutTarget(A_LoopFileFullPath)
            if (FileExist(target)) {
                ; 用目标文件的图标，但仍然保留 .lnk 路径
                iconIndex := IL_Add(IL, target, 0)
                LV_Add("Icon" iconIndex, name, A_LoopFileFullPath)
                continue
            }
        }

        ; 普通文件/或解析失败时
        iconIndex := IL_Add(IL, A_LoopFileFullPath, 0)
        LV_Add("Icon" iconIndex, name, A_LoopFileFullPath)
    }
}

; 解析快捷方式目标
GetShortcutTarget(path) {
    shell := ComObjCreate("WScript.Shell")
    sc := shell.CreateShortcut(path)
    return sc.TargetPath
}

; ========================
; 添加文件（快捷方式）
; ========================
MenuAddFiles:
    GuiControlGet, CurrentTab
    folder := BaseFolder "\" CurrentTab

    ; 弹出多文件选择对话框
    FileSelectFile, files, M, , 选择文件, 所有文件 (*.*)
    if (ErrorLevel)
        return

    ; 支持多文件
    Loop, Parse, files, `n
    {
        file := A_LoopField
        SplitPath, file, name, dir, ext, name_no_ext, drive
        target := folder "\" name

        if (ext = "lnk") {
            ; 已经是快捷方式，直接复制
            FileCopy, %file%, %target%, 1
        } else {
            ; 生成快捷方式
            lnkPath := folder "\" name_no_ext ".lnk"
            shell := ComObjCreate("WScript.Shell")
            sc := shell.CreateShortcut(lnkPath)
            sc.TargetPath := file
            sc.Save()
        }
    }

    ; 重新加载文件列表
    LoadFiles(CurrentTab)
return

; ========================
; 右键菜单事件
; ========================
GuiContextMenu:
    ; 判断鼠标位置是否在 ListView 项
    MouseGetPos, mx, my, win, ctrl
    LV_GetNext(0, "Focused")  ; 获取选中行
    Row := LV_GetNext(0, "Focused")
    
    if (Row != 0) {
        ; 在文件上右键
        LV_GetText(name, Row, 1)
        LV_GetText(path, Row, 2)
        Menu, FileMenu, Add, 打开所在文件夹, MenuOpenFolder
        Menu, FileMenu, Add, 删除, MenuDeleteFile
        Menu, FileMenu, Show, %mx% %my%
    } else {
        ; 空白处右键
        GuiControlGet, CurrentTab
        folder := BaseFolder "\" CurrentTab
        Menu, BlankMenu, Add, 打开当前文件夹, MenuOpenCurrentFolder
        Menu, BlankMenu, Add, 添加文件（快捷方式）, MenuAddFiles
        Menu, BlankMenu, Show, %mx% %my%
    }
return

; ========================
; 菜单操作
; ========================
MenuOpenFolder:
    Row := LV_GetNext(0, "Focused")
    LV_GetText(path, Row, 2)
    SplitPath, path, , dir
    Run, explorer.exe "%dir%"
return

MenuDeleteFile:
    Row := LV_GetNext(0, "Focused")
    LV_GetText(path, Row, 2)
    MsgBox, 4,, 确定删除 "%path%" ?
    IfMsgBox, Yes
    {
        FileDelete, %path%
        LV_Delete(Row)
    }
return

MenuOpenCurrentFolder:
    GuiControlGet, CurrentTab
    folder := BaseFolder "\" CurrentTab
    Run, explorer.exe "%folder%"
return

; ========================
; 托盘菜单：修改热键
; ========================
MenuChangeHotkey:
    InputBox, newHotkey, 修改热键, 当前热键是 %HotkeyShow%`n请输入新的热键 (例如 ^!w):
    if (ErrorLevel)
        return
    if (newHotkey != "")
    {
        Hotkey, %HotkeyShow%, Off
        HotkeyShow := newHotkey
        Hotkey, %HotkeyShow%, ShowLauncher
        IniWrite, %HotkeyShow%, %ConfigFile%, Hotkey, Show
        MsgBox, 已修改快捷键为 %HotkeyShow%
    }
return
