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
global DefaultIcons := {}

; 初始化默认图标映射
InitDefaultIcons()

InitDefaultIcons() {
    global DefaultIcons
    
    ; 预定义一些常见的文件类型图标 (shell32.dll图标索引)
    DefaultIcons["txt"] := 70
    DefaultIcons["doc"] := 1
    DefaultIcons["docx"] := 1
    DefaultIcons["xls"] := 1
    DefaultIcons["xlsx"] := 1
    DefaultIcons["ppt"] := 1
    DefaultIcons["pptx"] := 1
    DefaultIcons["pdf"] := 1
    DefaultIcons["jpg"] := 71
    DefaultIcons["jpeg"] := 71
    DefaultIcons["png"] := 71
    DefaultIcons["gif"] := 71
    DefaultIcons["bmp"] := 71
    DefaultIcons["ico"] := 71
    DefaultIcons["mp3"] := 108
    DefaultIcons["mp4"] := 109
    DefaultIcons["avi"] := 109
    DefaultIcons["mkv"] := 109
    DefaultIcons["zip"] := 174
    DefaultIcons["rar"] := 174
    DefaultIcons["7z"] := 174
    DefaultIcons["exe"] := 2
    DefaultIcons["msi"] := 2
    DefaultIcons["bat"] := 156
    DefaultIcons["cmd"] := 156
    DefaultIcons["reg"] := 68
    DefaultIcons["ini"] := 70
    DefaultIcons["cfg"] := 70
    DefaultIcons["log"] := 70
    DefaultIcons["folder"] := 4  ; 文件夹图标
    DefaultIcons["default"] := 1  ; 默认文件图标
}

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
        
        ; 标签按钮 - 自定义样式
        if (A_LoopField = CurrentTabName) {
            ; 活跃标签 - 白色背景
            Gui, Add, Button, x%TabX% y%TabY% w%TabWidth% h%TabHeight% gSwitchToTab vTabButton%TabIndex% Background%TabActiveColor% +0x8000, %A_LoopField%
            CurrentTabIndex := TabIndex
        } else {
            ; 非活跃标签 - 灰色背景
            Gui, Add, Button, x%TabX% y%TabY% w%TabWidth% h%TabHeight% gSwitchToTab vTabButton%TabIndex% Background%TabInactiveColor% +0x8000, %A_LoopField%
        }
        
        TabButtons[TabIndex] := A_LoopField
        TabNames[A_LoopField] := TabIndex
    }
    
    ; "+" 新建标签按钮
    NewTabX := TabStartX + TabIndex * (TabWidth + 2)
    if (NewTabX < 400) {
        Gui, Add, Button, x%NewTabX% y6 w30 h28 gCreateNewTab vNewTabBtn Background%TabInactiveColor% +0x8000, +
    }

    ; 右侧控制按钮区域
    ControlsX := 430
    
    ; 固定按钮 📌
    Gui, Add, Button, x%ControlsX% y6 w30 h28 gTogglePin vPinBtn Background%TabInactiveColor% +0x8000, % (IsPinned ? "📍" : "📌")
    
    ; 关闭按钮 ✕
    CloseX := ControlsX + 35
    Gui, Add, Button, x%CloseX% y6 w30 h28 gCloseWindow vCloseBtn BackgroundRed +0x8000, ✕

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

; 创建快捷方式函数（修改支持文件夹）
CreateShortcut(targetPath, shortcutPath) {
    try {
        shell := ComObjCreate("WScript.Shell")
        sc := shell.CreateShortcut(shortcutPath)
        sc.TargetPath := targetPath
        
        ; 设置工作目录
        if (FileExist(targetPath "\.")) {
            ; 如果是文件夹，设置父目录为工作目录
            SplitPath, targetPath, , workingDir
            sc.WorkingDirectory := workingDir
        } else {
            ; 如果是文件，设置文件所在目录为工作目录
            SplitPath, targetPath, , workingDir
            if FileExist(workingDir)
                sc.WorkingDirectory := workingDir
        }
        
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

; 创建网页快捷方式函数
CreateWebShortcut(name, url, shortcutPath) {
    try {
        ; 创建网页快捷方式文件内容
        content := "[InternetShortcut]`nURL=" . url . "`nIconFile=C:\Windows\System32\shell32.dll`nIconIndex=13"
        
        ; 写入文件
        FileAppend, %content%, %shortcutPath%
        return true
    } catch e {
        return false
    }
}

; ========================
; 标签切换事件
; ========================
SwitchToTab:
    ; 从控制变量名中提取标签索引
    RegExMatch(A_GuiControl, "TabButton(\d+)", match)
    tabIndex := match1
    if (tabIndex) {
        SwitchTab(tabIndex)
    }
return

; 标签切换函数
SwitchTab(tabIndex) {
    global TabButtons, CurrentTabName, CurrentTabIndex
    if (TabButtons.HasKey(tabIndex)) {
        CurrentTabName := TabButtons[tabIndex]
        CurrentTabIndex := tabIndex
        ; 加载新标签的文件内容
        LoadFiles(CurrentTabName)
        ; 更新按钮视觉状态
        UpdateTabVisuals()
    }
}

; 更新标签按钮视觉状态
UpdateTabVisuals() {
    global TabButtons, CurrentTabIndex, TabActiveColor, TabInactiveColor
    
    ; 更新所有标签按钮的背景色
    Loop, % TabButtons.MaxIndex() {
        tabIndex := A_Index
        if (A_Index = CurrentTabIndex) {
            ; 活跃标签 - 白色背景
            GuiControl, +Background%TabActiveColor%, TabButton%tabIndex%
        } else {
            ; 非活跃标签 - 灰色背景
            GuiControl, +Background%TabInactiveColor%, TabButton%tabIndex%
        }
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

        ; 检查是否是网页快捷方式
        SplitPath, path, , , ext
        if (ext = "url") {
            OpenWebShortcut(path)
            if (!IsPinned)
                Gui, Destroy
            return
        }

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

; 打开网页快捷方式
OpenWebShortcut(urlFilePath) {
    IniRead, url, %urlFilePath%, InternetShortcut, URL
    
    ; 检查是否包含参数占位符
    if InStr(url, "{query}") {
        InputBox, query, 输入参数, 请输入搜索内容或参数:
        if (ErrorLevel = 0 && query != "") {
            ; 对查询内容进行URL编码
            encodedQuery := UrlEncode(query)
            url := StrReplace(url, "{query}", encodedQuery)
        } else {
            return
        }
    }
    
    Run, %url%
}

; URL编码函数
UrlEncode(str) {
    encodedStr := ""
    Loop, Parse, str
    {
        char := A_LoopField
        if RegExMatch(char, "[A-Za-z0-9\-_.~]")
            encodedStr .= char
        else {
            ; 获取字符的UTF-8编码
            VarSetCapacity(utf8, 4)
            len := DllCall("WideCharToMultiByte", "UInt", 65001, "UInt", 0, "Str", char, "Int", 1, "Ptr", &utf8, "Int", 4, "Ptr", 0, "Ptr", 0)
            Loop, %len%
                encodedStr .= "%" . Format("{:02X}", NumGet(utf8, A_Index-1, "UChar"))
        }
    }
    return encodedStr
}

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
; 加载文件 - 改进版本
; ========================
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
    
    ; 收集所有文件
    Loop, Files, %folder%\*
    {
        filesToLoadIcons.Push(A_LoopFileFullPath)
    }

    ; 如果没有文件，直接返回
    if (filesToLoadIcons.MaxIndex() = 0) {
        return
    }

    ; 第一步：立即加载前5个文件的图标和名称
    immediateLoadCount := Min(5, filesToLoadIcons.MaxIndex())
    
    Loop, %immediateLoadCount%
    {
        filePath := filesToLoadIcons[A_Index]
        iconIndex := GetIconIndex(filePath)
        
        SplitPath, filePath, name
        LV_Add("Icon" iconIndex, name, filePath)
    }
    
    ; 第二步：添加剩余文件（暂时不加载图标）
    Loop, % filesToLoadIcons.MaxIndex() - immediateLoadCount
    {
        index := immediateLoadCount + A_Index
        filePath := filesToLoadIcons[index]
        SplitPath, filePath, name
        LV_Add("", name, filePath)
    }
    
    ; 第三步：启动异步加载剩余图标
    if (filesToLoadIcons.MaxIndex() > immediateLoadCount) {
        currentIconIndex := immediateLoadCount + 1
        SetTimer, LoadIcons, 10
    }
}

; 异步加载图标的函数 - 改进版本
LoadIcons:
    global filesToLoadIcons, currentIconIndex
    
    ; 每次处理3个图标，平衡速度和响应性
    batchSize := 3
    
    Loop, %batchSize% {
        if (currentIconIndex > filesToLoadIcons.MaxIndex()) {
            SetTimer, LoadIcons, Off
            return
        }

        filePath := filesToLoadIcons[currentIconIndex]
        iconIndex := GetIconIndex(filePath)

        ; 更新 ListView
        LV_Modify(currentIconIndex, "Icon" iconIndex)

        currentIconIndex++
    }
return

; ========================
; 改进的图标获取函数
; ========================
GetIconIndex(filePath) {
    global IL, IconCache, DefaultIcons
    
    ; 构建缓存键
    cacheKey := filePath
    
    ; 如果缓存中存在，直接返回
    if IconCache.HasKey(cacheKey) {
        return IconCache[cacheKey]
    }
    
    iconIndex := 0
    targetPath := ""
    SplitPath, filePath, fileName, fileDir, ext, nameNoExt
    
    ; 处理不同类型的文件
    if (ext = "lnk") {
        ; 快捷方式：获取目标路径和图标
        iconIndex := GetShortcutIcon(filePath)
    } else if (ext = "url") {
        ; 网页快捷方式
        iconIndex := GetUrlIcon(filePath)
    } else if (FileExist(filePath "\.")) {
        ; 文件夹
        iconIndex := IL_Add(IL, "C:\Windows\System32\shell32.dll", DefaultIcons["folder"])
    } else {
        ; 普通文件
        iconIndex := GetFileIcon(filePath, ext)
    }
    
    ; 如果获取失败，使用默认图标
    if (iconIndex <= 0) {
        if DefaultIcons.HasKey(ext) {
            iconIndex := IL_Add(IL, "C:\Windows\System32\shell32.dll", DefaultIcons[ext])
        } else {
            iconIndex := IL_Add(IL, "C:\Windows\System32\shell32.dll", DefaultIcons["default"])
        }
    }
    
    ; 缓存结果
    IconCache[cacheKey] := iconIndex
    return iconIndex
}

; 获取快捷方式图标
GetShortcutIcon(lnkPath) {
    global IL
    
    try {
        shell := ComObjCreate("WScript.Shell")
        sc := shell.CreateShortcut(lnkPath)
        
        targetPath := sc.TargetPath
        iconLocation := sc.IconLocation
        
        ; 优先使用自定义图标位置
        if (iconLocation != "") {
            ; 解析图标位置 "路径,索引"
            iconParts := StrSplit(iconLocation, ",")
            iconFile := iconParts[1]
            iconIndex := iconParts.Length() > 1 ? iconParts[2] : 0
            
            if FileExist(iconFile) {
                return IL_Add(IL, iconFile, iconIndex)
            }
        }
        
        ; 使用目标文件的图标
        if FileExist(targetPath) {
            SplitPath, targetPath, , , targetExt
            
            ; 检查目标是否是图片文件，如果是则使用缩略图
            if (IsImageFile(targetExt)) {
                thumbnailIndex := GetImageThumbnail(targetPath)
                if (thumbnailIndex > 0) {
                    return thumbnailIndex
                }
            }
            
            return GetFileIcon(targetPath, targetExt)
        }
        
    } catch e {
        ; 忽略错误，使用默认图标
    }
    
    return 0
}

; 获取URL快捷方式图标
GetUrlIcon(urlPath) {
    global IL
    
    try {
        ; 尝试读取自定义图标
        IniRead, iconFile, %urlPath%, InternetShortcut, IconFile
        IniRead, iconIndex, %urlPath%, InternetShortcut, IconIndex, 0
        
        if (iconFile != "ERROR" && FileExist(iconFile)) {
            return IL_Add(IL, iconFile, iconIndex)
        }
        
    } catch e {
        ; 忽略错误
    }
    
    ; 使用默认浏览器图标
    return IL_Add(IL, "C:\Windows\System32\shell32.dll", 13)
}

; 获取普通文件图标
GetFileIcon(filePath, ext) {
    global IL, DefaultIcons
    
    ; 检查是否是图片文件，如果是则优先使用缩略图
    if (IsImageFile(ext)) {
        thumbnailIndex := GetImageThumbnail(filePath)
        if (thumbnailIndex > 0) {
            return thumbnailIndex
        }
    }
    
    ; EXE文件尝试提取自身图标
    if (ext = "exe" || ext = "ico") {
        iconIndex := IL_Add(IL, filePath, 0)
        if (iconIndex > 0)
            return iconIndex
    }
    
    ; DLL文件尝试提取图标
    if (ext = "dll") {
        iconIndex := IL_Add(IL, filePath, 0)
        if (iconIndex > 0)
            return iconIndex
    }
    
    ; 使用系统关联的图标（通过注册表）
    iconIndex := GetSystemFileIcon(filePath, ext)
    if (iconIndex > 0)
        return iconIndex
    
    ; 使用预定义的默认图标
    if DefaultIcons.HasKey(ext) {
        return IL_Add(IL, "C:\Windows\System32\shell32.dll", DefaultIcons[ext])
    }
    
    return 0
}

; 检查是否是图片文件
IsImageFile(ext) {
    StringLower, ext, ext
    imageExts := "jpg,jpeg,png,gif,bmp,tiff,tif,webp,ico"
    if InStr(imageExts, ext)
        return true
    return false
}

; 获取图片缩略图
GetImageThumbnail(imagePath) {
    global IL
    
    try {
        ; 简化方法：直接尝试从图片文件获取图标
        iconIndex := IL_Add(IL, imagePath, 0)
        if (iconIndex > 0) {
            return iconIndex
        }
    } catch e {
        ; 忽略错误
    }
    
    return 0
}

; 通过系统关联获取文件图标
GetSystemFileIcon(filePath, ext) {
    global IL
    
    if (ext = "")
        return 0
    
    try {
        ; 通过SHGetFileInfo获取系统图标
        VarSetCapacity(SHFILEINFO, 352, 0)
        
        ; SHGFI_ICON = 0x100, SHGFI_SMALLICON = 0x1, SHGFI_USEFILEATTRIBUTES = 0x10
        hIcon := DllCall("shell32\SHGetFileInfoW"
            , "WStr", filePath
            , "UInt", 0
            , "Ptr", &SHFILEINFO
            , "UInt", 352
            , "UInt", 0x111
            , "Ptr") ; SHGFI_ICON | SHGFI_SMALLICON | SHGFI_USEFILEATTRIBUTES
        
        if (hIcon) {
            hIcon := NumGet(SHFILEINFO, 0, "Ptr")
            if (hIcon) {
                iconIndex := IL_Add(IL, "HICON:" . hIcon)
                DllCall("DestroyIcon", "Ptr", hIcon)
                return iconIndex
            }
        }
        
    } catch e {
        ; 忽略错误
    }
    
    return 0
}

; ========================
; 添加文件（快捷方式）修改支持文件夹
; ========================
MenuAddFiles:
    folder := BaseFolder "\" CurrentTabName

    ; 弹出多文件选择对话框，支持文件夹
    FileSelectFile, files, M, , 选择文件或文件夹, 所有文件 (*.*)
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
; 添加文件夹快捷方式
; ========================
MenuAddFolder:
    folder := BaseFolder "\" CurrentTabName
    
    FileSelectFolder, selectedFolder, , 0, 选择文件夹
    if (ErrorLevel)
        return
    
    SplitPath, selectedFolder, name
    lnkPath := folder "\" name ".lnk"
    CreateShortcut(selectedFolder, lnkPath)
    
    ; 重新加载文件列表
    LoadFiles(CurrentTabName)
return

; ========================
; 添加网页快捷方式
; ========================
MenuAddWeb:
    folder := BaseFolder "\" CurrentTabName
    
    ; 输入网页名称
    InputBox, webName, 添加网页快捷方式, 请输入快捷方式名称:
    if (ErrorLevel || webName = "")
        return
    
    ; 输入网页地址
    InputBox, webUrl, 添加网页快捷方式, 请输入网页地址:`n`n提示: 可以使用 {query} 作为参数占位符`n例如: https://www.google.com/search?q={query}, 网页地址
    if (ErrorLevel || webUrl = "")
        return
    
    ; 创建网页快捷方式
    urlPath := folder "\" webName ".url"
    CreateWebShortcut(webName, webUrl, urlPath)
    
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
        Menu, BlankMenu, Add, 添加文件夹（快捷方式）, MenuAddFolder
        Menu, BlankMenu, Add, 添加网页快捷方式, MenuAddWeb
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

; ========================
; 辅助函数
; ========================

; 获取最小值
Min(a, b) {
    return a < b ? a : b
}

; 解析快捷方式目标（保留原有功能）
GetShortcutTarget(path) {
    try {
        shell := ComObjCreate("WScript.Shell")
        sc := shell.CreateShortcut(path)
        return sc.TargetPath
    } catch e {
        return ""
    }
}