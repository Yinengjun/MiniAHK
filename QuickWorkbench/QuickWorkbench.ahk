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

; UI 颜色配置
NavBarColor := 0xF0F0F0      ; 导航栏背景色 (浅灰)
TabActiveColor := 0xFFFFFF   ; 活跃标签背景色 (白色)
TabInactiveColor := 0xE0E0E0 ; 非活跃标签背景色 (灰色)
BorderColor := 0xC0C0C0      ; 边框颜色
TextColor := 0x333333        ; 文字颜色

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
Menu, Tray, Add, 重启程序, RestartScript
Menu, Tray, Add, 退出, ExitScript
return

; ========================
; 全局变量声明和初始化
; ========================
global GUI_LOCK := false
global IsPinned := false
global CurrentTabName := ""
global TabButtons := {}
global TabNames := {}
global CurrentTabIndex := 1
global IL
global IconCache := {}
global filesToLoadIcons := []
global currentIconIndex := 1

ShowLauncher:
    ; 防止快速连续触发
    if (GUI_LOCK)
        return
    GUI_LOCK := true

    ; 如果窗口已经存在且可见，激活它
    IfWinExist, 快捷工作台
    {
        WinActivate, 快捷工作台
        GUI_LOCK := false
        return
    }

    ; 暂停自动关闭计时器
    SetTimer, AutoClose, Off

    ; 销毁旧窗口和旧 ImageList
    Gui, Destroy
    ;if (IL) {
    ;    IL_Destroy(IL)
    ;    Sleep, 20  ; 给资源释放一点时间
    ;}

    Gui, +AlwaysOnTop -Caption +ToolWindow +LastFound
    Gui, Margin, 0, 0
    Gui, Font, s9, Microsoft YaHei UI

    ; 创建导航栏背景
    Gui, Add, Progress, x0 y0 w500 h40 Background%NavBarColor% Disabled

    ; 获取子文件夹列表
    Tabs := ""
    TabCount := 0
    Loop, Files, %BaseFolder%\*, D
    {
        Tabs .= (Tabs = "" ? "" : "|") A_LoopFileName
        TabCount++
    }

    ; 标签容器设置
    TabStartX := 10
    TabWidth := 80
    TabHeight := 28
    
    ; 重置标签数据
    TabButtons := {}
    TabNames := {}
    
    ; 绘制标签按钮
    TabIndex := 0
    Loop, Parse, Tabs, |
    {
        if (A_LoopField = "")
            continue
        
        TabIndex++
        TabX := TabStartX + (TabIndex - 1) * (TabWidth + 2)
        TabY := 6
        
        ; 设置当前标签（如果没有设置或第一个标签）
        if (CurrentTabName = "" && TabIndex = 1) {
            CurrentTabName := A_LoopField
            CurrentTabIndex := TabIndex
        }
        
        ; 根据是否为当前标签决定背景色
        if (A_LoopField = CurrentTabName) {
            Gui, Add, Progress, x%TabX% y%TabY% w%TabWidth% h%TabHeight% Background%TabActiveColor% Disabled
            CurrentTabIndex := TabIndex
        } else {
            Gui, Add, Progress, x%TabX% y%TabY% w%TabWidth% h%TabHeight% Background%TabInactiveColor% Disabled
        }
        
        ; 标签文字 - 使用居中样式
        Gui, Add, Text, x%TabX% y%TabY% w%TabWidth% h%TabHeight% +0x200 +0x1 BackgroundTrans c%TextColor% gSwitchToTab%TabIndex% vTabText%TabIndex%, %A_LoopField%
        
        TabButtons[TabIndex] := A_LoopField
        TabNames[A_LoopField] := TabIndex
    }
    
    ; "+" 新建标签按钮
    NewTabX := TabStartX + TabIndex * (TabWidth + 2)
    if (NewTabX < 400) {
        Gui, Add, Progress, x%NewTabX% y6 w30 h28 Background%TabInactiveColor% Disabled
        Gui, Add, Text, x%NewTabX% y6 w30 h28 +0x200 +0x1 BackgroundTrans c%TextColor% gCreateNewTab vNewTabBtn, +
    }

    ; 右侧控制按钮区域
    ControlsX := 430
    
    ; 固定按钮 📌
    Gui, Add, Progress, x%ControlsX% y6 w30 h28 Background%TabInactiveColor% Disabled
    Gui, Add, Text, x%ControlsX% y6 w30 h28 +0x200 +0x1 BackgroundTrans c%TextColor% gTogglePin vPinBtn, % (IsPinned ? "📍" : "📌")
    
    ; 关闭按钮 ✕
    CloseX := ControlsX + 35
    Gui, Add, Progress, x%CloseX% y6 w30 h28 BackgroundRed Disabled
    Gui, Add, Text, x%CloseX% y6 w30 h28 +0x200 +0x1 BackgroundTrans cWhite gCloseWindow vCloseBtn, ✕

    ; 导航栏分割线
    Gui, Add, Progress, x0 y40 w500 h1 Background%BorderColor% Disabled

    ; 主内容区域背景
    Gui, Add, Progress, x0 y41 w500 h319 BackgroundWhite Disabled

    ; ListView 显示文件
    Gui, Add, ListView, x10 y50 w480 h300 Icon AltSubmit gOpenFile vFileList, 名称|路径
    LV_ModifyCol(2, 0) ; 隐藏路径列

    ; 初始化 ImageList
    IL := IL_Create(40,1,1)
    LV_SetImageList(IL)

    ; 加载当前标签的文件
    LoadFiles(CurrentTabName)

    ; 窗口显示到鼠标中心
    CoordMode, Mouse, Screen
    MouseGetPos, mx, my
    w := 500, h := 360
    x := mx - w//2, y := my - h//2
    Gui, Show, x%x% y%y% w%w% h%h%, 快捷工作台

    ; 重启自动关闭计时器
    SetTimer, AutoClose, 100

    ; 解除锁
    GUI_LOCK := false
return

; 创建快捷方式函数
CreateShortcut(targetPath, shortcutPath) {
    try {
        shell := ComObjCreate("WScript.Shell")
        sc := shell.CreateShortcut(shortcutPath)
        sc.TargetPath := targetPath
        
        ; 设置工作目录
        SplitPath, targetPath, , workingDir
        if FileExist(workingDir)
            sc.WorkingDirectory := workingDir
        
        ; 如果是可执行文件，尝试提取图标
        SplitPath, targetPath, , , ext
        if (ext = "exe")
            sc.IconLocation := targetPath ",0"
        
        sc.Save()
        return true
    } catch e {
        return false
    }
}

; ========================
; 标签切换事件
; ========================
SwitchToTab1:
    SwitchTab(1)
return
SwitchToTab2:
    SwitchTab(2)
return
SwitchToTab3:
    SwitchTab(3)
return
SwitchToTab4:
    SwitchTab(4)
return
SwitchToTab5:
    SwitchTab(5)
return
SwitchToTab6:
    SwitchTab(6)
return
SwitchToTab7:
    SwitchTab(7)
return
SwitchToTab8:
    SwitchTab(8)
return

; 标签切换函数
SwitchTab(tabIndex) {
    global TabButtons, CurrentTabName, CurrentTabIndex
    if (TabButtons.HasKey(tabIndex)) {
        CurrentTabName := TabButtons[tabIndex]
        CurrentTabIndex := tabIndex
        LoadFiles(CurrentTabName)
        ; 这里可以添加标签视觉状态更新，但需要重绘整个界面
        ; 为简化，我们只更新文件列表
    }
}

; ========================
; 新建标签
; ========================
CreateNewTab:
    InputBox, newName, 新建子文件夹, 请输入文件夹名称:
    if (ErrorLevel = 0 and newName != "")
    {
        FileCreateDir, %BaseFolder%\%newName%
        ; 设置新创建的文件夹为当前标签
        CurrentTabName := newName
        GoSub, ShowLauncher  ; 重绘界面
    }
return

; ========================
; 双击打开
; ========================
OpenFile:
    if (A_GuiEvent = "DoubleClick") {
        Row := A_EventInfo

        ; 双击空白处
        if (Row = 0) {
            folder := BaseFolder "\" CurrentTabName
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
; 关闭窗口
; ========================
CloseWindow:
    Gui, Destroy
    SetTimer, AutoClose, Off
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
global IconCache := {}
global filesToLoadIcons := []
global currentIconIndex := 1

LoadFiles(subdir) {
    global BaseFolder, IL, IconCache, filesToLoadIcons, currentIconIndex
    
    SetTimer, LoadIcons, Off
    LV_Delete()
    
    if (IL)
        IL_Destroy(IL)
    
    IL := IL_Create(40,1,1)
    LV_SetImageList(IL)

    folder := BaseFolder "\" subdir
    if !FileExist(folder)
        return
        
    filesToLoadIcons := []
    
    ; 步骤1：快速填充列表，并把所有文件路径存入列表
    Loop, Files, %folder%\*
    {
        filesToLoadIcons.InsertAt(A_Index, A_LoopFileFullPath)
    }

    ; 如果没有文件，直接返回
    if (filesToLoadIcons.MaxIndex() = 0) {
        return
    }

    ; 步骤2：立即加载并显示第一个图标
    firstFilePath := filesToLoadIcons[1]
    firstIconIndex := GetIconIndex(firstFilePath)
    
    SplitPath, firstFilePath, name
    LV_Add("Icon" firstIconIndex, name, firstFilePath)
    
    ; 步骤3：填充剩余的项目，不带图标
    Loop, % filesToLoadIcons.MaxIndex() - 1
    {
        index := A_Index + 1
        filePath := filesToLoadIcons[index]
        SplitPath, filePath, name
        LV_Add("", name, filePath)
    }
    
    ; 步骤4：启动异步加载其余图标的定时器
    currentIconIndex := 2
    SetTimer, LoadIcons, 1
}

; 异步加载图标的函数
LoadIcons:
    global BaseFolder, IL, IconCache, filesToLoadIcons, currentIconIndex
    
    if (currentIconIndex > filesToLoadIcons.MaxIndex()) {
        SetTimer, LoadIcons, Off
        return
    }

    filePath := filesToLoadIcons[currentIconIndex]
    
    iconIndex := GetIconIndex(filePath)
    
    ; 更新 ListView
    LV_Modify(currentIconIndex, "Icon" iconIndex)
    
    currentIconIndex++
return

; 新增辅助函数：获取图标索引（处理快捷方式和缓存）
GetIconIndex(filePath) {
    global IL, IconCache
    
    targetPath := ""
    if (SubStr(filePath, -3) = ".lnk") {
        target := GetShortcutTarget(filePath)
        if (FileExist(target))
            targetPath := target
        else
            targetPath := filePath
    } else {
        targetPath := filePath
    }
    
    if IconCache.HasKey(targetPath) {
        return IconCache[targetPath]
    } else {
        iconIndex := IL_Add(IL, targetPath, 0)
        IconCache[targetPath] := iconIndex
        return iconIndex
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
    folder := BaseFolder "\" CurrentTabName

    ; 弹出多文件选择对话框
    FileSelectFile, files, M, , 选择文件, 所有文件 (*.*)
    if (ErrorLevel)
        return

    ; 支持多文件
    StringSplit, fileArray, files, `n
    firstFile := fileArray1
    
    if (fileArray0 = 1) {
        ; 只选择了一个文件
        SplitPath, firstFile, name, dir, ext, name_no_ext, drive
        target := folder "\" name

        if (ext = "lnk") {
            ; 已经是快捷方式，直接复制
            FileCopy, %firstFile%, %target%, 1
        } else {
            ; 生成快捷方式
            lnkPath := folder "\" name_no_ext ".lnk"
            CreateShortcut(firstFile, lnkPath)
        }
    } else {
        ; 选择了多个文件
        baseDir := firstFile
        Loop, % fileArray0 - 1 {
            currentIndex := A_Index + 1
            file := baseDir "\" fileArray%currentIndex%
            SplitPath, file, name, dir, ext, name_no_ext, drive
            target := folder "\" name

            if (ext = "lnk") {
                ; 已经是快捷方式，直接复制
                FileCopy, %file%, %target%, 1
            } else {
                ; 生成快捷方式
                lnkPath := folder "\" name_no_ext ".lnk"
                CreateShortcut(file, lnkPath)
            }
        }
    }

    ; 重新加载文件列表
    LoadFiles(CurrentTabName)
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
        folder := BaseFolder "\" CurrentTabName
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
    folder := BaseFolder "\" CurrentTabName
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

RestartScript:
    Reload
return

ExitScript:
    ExitApp
