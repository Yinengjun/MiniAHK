; -*- coding: utf-8 -*-
#NoEnv
#SingleInstance Force
SetBatchLines, -1
ListLines, Off

; ========================
; 配置
; ========================
global ConfigFile := A_ScriptDir "\config.ini"
global PresetSection := "WindowSizePresets"
global Presets := Object()            ; 以数字键为索引：{1:{name:"",w:xxx,h:xxx},2:...}
global MenuItemToIndex := Object()
global AddModeRefill := false
global WindowSize := 1

; ========================
; 热键
; ========================
!z::   ; Alt + Z
    if (!WindowSize)
        return
        
    IniRead, master, %ConfigFile%, Settings, MasterSwitch, 1
    if (master = 0)
        return

    EnsureIniReady()
    LoadPresets()
    ShowPresetMenu()
return

; ========================
; 菜单
; ========================
ShowPresetMenu() {
    global Presets, MenuItemToIndex, WSMenu

    ; 创建/重置菜单
    Menu, WSMenu, Add
    Menu, WSMenu, DeleteAll
    MenuItemToIndex := Object()

    if (GetArrayCount(Presets) > 0) {
        for k, p in Presets {
            item := p.name " (" p.w "x" p.h ")"
            Menu, WSMenu, Add, %item%, WS_MenuHandler
            MenuItemToIndex[item] := k
        }
        Menu, WSMenu, Add
    } else {
        Menu, WSMenu, Add, （暂无预设，请先添加）, WS_MenuHandler
        MenuItemToIndex["（暂无预设，请先添加）"] := -1
        Menu, WSMenu, Add
    }

    Menu, WSMenu, Add, 排序选项, WS_MenuHandler
    Menu, WSMenu, Add, 删除预设, WS_MenuHandler
    Menu, WSMenu, Add, 添加预设, WS_MenuHandler
    Menu, WSMenu, Add, 参考窗口设置预设, WS_MenuHandler

    CoordMode, Mouse, Screen
    MouseGetPos, mx, my

    ; 第一次显示到角落
    Menu, WSMenu, Show, 0, 0
    WinGetPos, wx, wy, ww, wh, ahk_class #32768  ; #32768 是菜单窗口类

    ; 关闭菜单
    Send, {Escape}

    ; 再次显示到居中位置
    x := mx - ww//2
    y := my - wh//2
    Menu, WSMenu, Show, %x%, %y%
}

; 菜单处理
WS_MenuHandler:
    global MenuItemToIndex
    item := A_ThisMenuItem

    if (item = "添加预设") {
        AddModeRefill := false
        OpenAddPresetGUI()
        return
    }
    if (item = "参考窗口设置预设") {
        AddModeRefill := true
        OpenAddPresetGUI()
        return
    }
    if (item = "排序选项") {
        OpenSortGUI()
        return
    }
    if (item = "（暂无预设，请先添加）") {
        AddModeRefill := false
        OpenAddPresetGUI()
        return
    }
    if (item = "删除预设") {
        OpenDeletePresetGUI()
        return
    }

    idx := MenuItemToIndex[item]
    if (idx)
        ApplyPreset(idx)
return

; ========================
; 预设应用/载入/保存
; ========================
ApplyPreset(idx) {
    global Presets
    if (!Presets[idx])
        return
    p := Presets[idx]
    WinGet, hWnd, ID, A
    if !hWnd
        return
    WinGetPos, x, y,,, ahk_id %hWnd%
    WinMove, ahk_id %hWnd%,, x, y, p.w, p.h
}

; 确保配置文件存在
EnsureIniReady() {
    global ConfigFile, PresetSection
    if !FileExist(ConfigFile)
        FileAppend,, %ConfigFile%

    IniRead, cnt, %ConfigFile%, %PresetSection%, Count, 0
    if (cnt = 0) {
        IniWrite, 2, %ConfigFile%, %PresetSection%, Count
        IniWrite, 经典 1280x720|1280|720, %ConfigFile%, %PresetSection%, 1
        IniWrite, 高清 1920x1080|1920|1080, %ConfigFile%, %PresetSection%, 2
    }
}

; 加载预设
LoadPresets() {
    global ConfigFile, PresetSection, Presets
    Presets := Object()
    IniRead, cnt, %ConfigFile%, %PresetSection%, Count, 0
    Loop, %cnt% {
        IniRead, line, %ConfigFile%, %PresetSection%, %A_Index%
        if (line = "")
            continue
        StringSplit, parts, line, |
        if (parts0 >= 3) {
            name := parts1, w := parts2, h := parts3
            if (w+0 > 0 && h+0 > 0)
                Presets[A_Index] := {name:name, w:w+0, h:h+0}
        }
    }
}

; 保存预设
SavePresets() {
    global ConfigFile, PresetSection, Presets
    IniDelete, %ConfigFile%, %PresetSection%
    cnt := GetArrayCount(Presets)
    IniWrite, %cnt%, %ConfigFile%, %PresetSection%, Count
    i := 0
    for k, p in Presets {
        i++
        line := p.name "|" p.w "|" p.h
        IniWrite, %line%, %ConfigFile%, %PresetSection%, %i%
    }
}

; ========================
; 添加预设 GUI
; ========================
OpenAddPresetGUI() {
    global AddModeRefill

    preH := "", preW := ""
    if (AddModeRefill) {
        WinGet, hWnd, ID, A
        if (hWnd) {
            WinGetPos,,, w, h, ahk_id %hWnd%
            preH := h, preW := w
        }
    }

    Gui, AddGui:New, +AlwaysOnTop +OwnDialogs +LabelAddGui
    Gui, AddGui:Margin, 12, 10
    Gui, AddGui:Font, s10

    Gui, AddGui:Add, Text,, 名称：
    Gui, AddGui:Add, Edit, vPresetName w260

    Gui, AddGui:Add, Text,, 长x宽：

    Gui, AddGui:Add, Edit, vPresetH w100, %preH%
    Gui, AddGui:Add, Edit, vPresetW w100 x+10, %preW%  ; x+10 表示稍微间隔

    Gui, AddGui:Add, Button, xm w90 Default gAddGuiSave, 保存
    Gui, AddGui:Add, Button, x+m w90 gAddGuiCancel, 取消

    Gui, AddGui:Show,, 添加预设
}

; 添加预设
AddGuiSave:
    Gui, AddGui:Submit, NoHide
    name := PresetName
    wh   := PresetWH
    wTxt := PresetW
    hTxt := PresetH

    if (wh != "" && (wTxt = "" || hTxt = "")) {
        tmp := RegExReplace(wh, "\s", "")
        if RegExMatch(tmp, "i)^(\d+)[x\*](\d+)$", m) {
            wTxt := m1, hTxt := m2
        }
    }

    if (name = "") {
        MsgBox, 48, 提示, 请输入名称。
        return
    }
    if !(wTxt+0 > 0 && hTxt+0 > 0) {
        MsgBox, 48, 提示, 请填写有效的宽和高。
        return
    }

    w := wTxt+0, h := hTxt+0
    AddOrUpdatePreset(name, w, h)
    SavePresets()
    Gui, AddGui:Destroy
    LoadPresets()
    ShowPresetMenu()
return

; 取消
AddGuiCancel:
AddGuiClose:
    Gui, AddGui:Destroy
return

; 添加或更新预设
AddOrUpdatePreset(name, w, h) {
    global Presets
    for k, p in Presets {
        if (p.name = name) {
            Presets[k].w := w
            Presets[k].h := h
            return
        }
    }
    idx := GetArrayCount(Presets) + 1
    Presets[idx] := {name:name, w:w, h:h}
}

; ========================
; 删除 GUI
; ========================
OpenDeletePresetGUI() {
    global Presets
    Gui, DeleteGui:New, +AlwaysOnTop +OwnDialogs +LabelDeleteGui
    Gui, DeleteGui:Margin, 12, 10
    Gui, DeleteGui:Font, s10

    Gui, DeleteGui:Add, Text,, 请选择要删除的预设：
    items := ""
    for k, p in Presets
        items .= p.name "|"
    StringTrimRight, items, items, 1

    Gui, DeleteGui:Add, DropDownList, vDeleteChoice w260, %items%
    Gui, DeleteGui:Add, Button, xm w90 Default gDeleteGuiApply, 删除
    Gui, DeleteGui:Add, Button, x+m w90 gDeleteGuiCancel, 取消
    Gui, DeleteGui:Show,, 删除预设
}

; 删除预设
DeleteGuiApply:
    Gui, DeleteGui:Submit, NoHide
    global Presets
    idx := 0
    for k, p in Presets {
        if (p.name = DeleteChoice) {
            idx := k
            break
        }
    }
    if (idx) {
        Presets.Delete(idx)
        SavePresets()
        LoadPresets()
    }
    Gui, DeleteGui:Destroy
    ShowPresetMenu()
return

; 取消删除
DeleteGuiCancel:
DeleteGuiClose:
    Gui, DeleteGui:Destroy
return

; ========================
; 排序 GUI
; ========================
OpenSortGUI() {
    Gui, SortGui:New, +AlwaysOnTop +OwnDialogs +LabelSortGui
    Gui, SortGui:Margin, 12, 10
    Gui, SortGui:Font, s10

    Gui, SortGui:Add, Text,, 排序依据：
    Gui, SortGui:Add, DropDownList, vSortKey w200 Choose1, 名称|宽度|高度|面积
    Gui, SortGui:Add, CheckBox, vSortDesc, 倒序（降序）
    Gui, SortGui:Add, Button, xm w90 Default gSortGuiApply, 应用
    Gui, SortGui:Add, Button, x+m w90 gSortGuiCancel, 取消
    Gui, SortGui:Show,, 排序选项
}

; 应用排序
SortGuiApply:
    Gui, SortGui:Submit, NoHide
    DoSortPresets(SortKey, SortDesc)
    SavePresets()
    Gui, SortGui:Destroy
    LoadPresets()
    ShowPresetMenu()
return

; 取消排序
SortGuiCancel:
SortGuiClose:
    Gui, SortGui:Destroy
return

; 排序函数
DoSortPresets(keyLabel, isDesc) {
    global Presets
    arr := Presets
    if (GetArrayCount(arr) <= 1)
        return

    newArr := Object()
    for i, p in arr {
        v := GetKeyValue(p, keyLabel)
        pos := GetArrayCount(newArr) + 1
        for j, q in newArr {
            vq := GetKeyValue(q, keyLabel)
            cmp := CompareValues(v, vq, keyLabel)
            if (!isDesc && cmp < 0) {
                pos := j
                break
            } else if (isDesc && cmp > 0) {
                pos := j
                break
            }
        }
        InsertAt(newArr, pos, p)
    }
    Presets := newArr
}

; 获取预设属性值
GetKeyValue(p, keyLabel) {
    if (keyLabel = "名称")
        return p.name
    else if (keyLabel = "宽度")
        return p.w
    else if (keyLabel = "高度")
        return p.h
    else
        return p.w * p.h
}

; 比较函数
CompareValues(a, b, keyLabel) {
    if (keyLabel = "名称") {
        StringLower, a, a
        StringLower, b, b
        if (a = b)
            return 0
        return (a < b) ? -1 : 1
    } else {
        a += 0, b += 0
        if (a = b)
            return 0
        return (a < b) ? -1 : 1
    }
}

; 插入元素
InsertAt(ByRef arr, pos, val) {
    len := GetArrayCount(arr)
    if (pos < 1)
        pos := 1
    if (pos > len+1) {
        arr[len+1] := val
        return
    }
    Loop, % len - pos + 1 {
        idx := len - A_Index + 1
        arr[idx+1] := arr[idx]
    }
    arr[pos] := val
}

; 获取数组元素个数
GetArrayCount(arr) {
    count := 0
    for k, v in arr
        count++
    return count
}
