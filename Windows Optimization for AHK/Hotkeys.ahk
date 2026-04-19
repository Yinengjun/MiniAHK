; -*- coding: UTF-8 -*-
; ================================================================
; Hotkeys.ahk - 热键注册与配置管理（方案 A：Action 表 + 动态注册 + 统一 #If 闸门）
; ================================================================
;
; 约定：
;   - 每个"可配置热键"是一个 Action。Action 绑定到一个命名标签。
;   - 可配置 Action 在 #If IsHotkeyEnabled(A_ThisHotkey) 闸门下注册。
;   - "内部" Action（AltMove 释放、Esc 取消）无闸门，常驻。
;   - AltMove 的释放监听键由触发键解析派生，同步更新。
;
; INI 布局（config.ini）：
;   [Hotkeys]
;   <ActionId>=<AHK 原生热键串>
;
; ================================================================

; ------------------------------------------------------------
; 全局状态
; ------------------------------------------------------------
global g_Actions := []                  ; 全部 Action 定义
global g_ActionById := {}               ; id → Action
global g_HotkeyToFeature := {}          ; 运行时：AHK键串 → feature变量名
global g_ActionCurrentKey := {}         ; 运行时：ActionId → 当前AHK键串
global g_AltMoveReleaseKeys := []       ; AltMove 当前注册的释放监听键（便于撤销）
global g_HotkeyCaptureTargetId := ""    ; 捕获对话框当前编辑的 ActionId
global g_HotkeyTabBuilt := false        ; 标签页是否已构建

; ------------------------------------------------------------
; 预声明 GUI 变量为 super-global（AHK v1 要求控件的 v 变量必须是 global/static）
; ------------------------------------------------------------
; 快捷键标签页的显示变量（每个 Action 一个）
global HKRow_AltMove_Drag_Key := ""
global HKRow_BorderlessWindow_Toggle_Key := ""
global HKRow_MinimizeWindow_Others_Key := ""
global HKRow_MinimizeWindow_Current_Key := ""
global HKRow_MinimizeWindow_Wheel_Key := ""
global HKRow_ModifyWindowBorders_Start_Key := ""
global HKRow_PastePureText_Paste_Key := ""
global HKRow_PeekDesktop_Toggle_Key := ""
global HKRow_ReconstructionWindow_Start_Key := ""
global HKRow_SwitchProgramWindows_Prev_Key := ""
global HKRow_SwitchProgramWindows_Next_Key := ""
global HKRow_WindowCenter_Apply_Key := ""
global HKRow_WindowOnTop_Toggle_Key := ""
global HKRow_WindowScaling_Up_Key := ""
global HKRow_WindowScaling_Down_Key := ""
global HKRow_WindowSize_Menu_Key := ""
global HKRow_WindowToTray_Hide_Key := ""
global HKRow_WindowToTray_ShowMenu_Key := ""

; 捕获对话框的控件变量
global HKCapCtrl := 0
global HKCapAlt := 0
global HKCapShift := 0
global HKCapWin := 0
global HKCapMainKey := ""

; ------------------------------------------------------------
; Action 表定义
; ------------------------------------------------------------
InitActionTable() {
    global g_Actions, g_ActionById
    g_Actions := []

    Push_Action("AltMove_Drag",              "AltMove",              "!LButton",      "AltMove_Start",              "拖动窗口触发",   "mouse",  true)
    Push_Action("WindowScaling_Up",          "WindowScaling",        "^+WheelUp",     "WindowScaling_Up",           "放大窗口",       "wheel",  true)
    Push_Action("WindowScaling_Down",        "WindowScaling",        "^+WheelDown",   "WindowScaling_Down",         "缩小窗口",       "wheel",  true)
    Push_Action("WindowSize_Menu",           "WindowSize",           "!z",            "WindowSize_Menu",            "打开尺寸菜单",   "key",    true)
    Push_Action("WindowCenter_Apply",        "WindowCenter",         "!c",            "WindowCenter_Apply",         "窗口居中",       "key",    true)
    Push_Action("WindowOnTop_Toggle",        "WindowOnTop",          "^+e",           "WindowOnTop_Toggle",         "切换窗口置顶",   "key",    true)
    Push_Action("MinimizeWindow_Others",     "MinimizeWindow",       "!a",            "MinimizeWindow_Others",      "最小化其他窗口", "key",    true)
    Push_Action("MinimizeWindow_Current",    "MinimizeWindow",       "!m",            "MinimizeWindow_Current",     "最小化当前窗口", "key",    true)
    Push_Action("MinimizeWindow_Wheel",      "MinimizeWindow",       "!WheelDown",    "MinimizeWindow_Wheel",       "滚轮最小化",     "wheel",  true)
    Push_Action("WindowToTray_Hide",         "WindowToTray",         "!x",            "WindowToTray_Hide",          "隐藏窗口到托盘", "key",    true)
    Push_Action("WindowToTray_ShowMenu",     "WindowToTray",         "^+x",           "WindowToTray_ShowMenu",      "显示托盘菜单",   "key",    true)
    Push_Action("BorderlessWindow_Toggle",   "BorderlessWindow",     "!b",            "BorderlessWindow_Toggle",    "切换无边框",     "key",    true)
    Push_Action("ModifyWindowBorders_Start", "ModifyWindowBorders",  "Alt & RButton", "ModifyWindowBorders_Start",  "修改边框启动",   "combo",  false) ; 锁定
    Push_Action("ReconstructionWindow_Start","ReconstructionWindow", "!t",            "ReconstructionWindow_Start", "开始重构窗口",   "key",    true)
    Push_Action("SwitchProgramWindows_Prev", "SwitchProgramWindows", "^!WheelUp",     "SwitchProgramWindows_Prev",  "上一个程序窗口", "wheel",  true)
    Push_Action("SwitchProgramWindows_Next", "SwitchProgramWindows", "^!WheelDown",   "SwitchProgramWindows_Next",  "下一个程序窗口", "wheel",  true)
    Push_Action("PeekDesktop_Toggle",        "PeekDesktop",          "!d",            "PeekDesktop_Trigger",        "临时访问桌面",   "key",    true)
    Push_Action("PastePureText_Paste",       "PastePureText",        "^+v",           "PastePureText_Paste",        "粘贴纯文本",     "key",    true)

    g_ActionById := {}
    for i, a in g_Actions
        g_ActionById[a.id] := a
}

Push_Action(id, feature, defaultKey, label, displayName, category, configurable) {
    global g_Actions
    g_Actions.Push({id:id, feature:feature, defaultKey:defaultKey, label:label, displayName:displayName, category:category, configurable:configurable})
}

; ------------------------------------------------------------
; #If 统一闸门
;   - 可配置 Action 均在此条件下注册
;   - feature="" 的 Action 视为 internal，默认放行
;   - AltMove 特例：再检查 AltMove_IsAllowed()
; ------------------------------------------------------------
IsHotkeyEnabled(hk) {
    global g_HotkeyToFeature, MasterSwitch
    global AltMove, BorderlessWindow, MinimizeWindow, ModifyWindowBorders
    global PastePureText, PeekDesktop, ReconstructionWindow
    global SwitchProgramWindows, WindowCenter, WindowOnTop
    global WindowScaling, WindowSize, WindowToTray
    if (!MasterSwitch)
        return false
    feature := g_HotkeyToFeature[hk]
    if (feature = "")
        return true
    if (!%feature%)
        return false
    if (feature = "AltMove") {
        if (!AltMove_IsAllowed())
            return false
    }
    return true
}

; ------------------------------------------------------------
; 启动注册
; ------------------------------------------------------------
HotkeyRegister_InitAll() {
    global g_Actions, g_HotkeyToFeature, g_ActionCurrentKey, ConfigFile

    g_HotkeyToFeature := {}
    g_ActionCurrentKey := {}

    for i, a in g_Actions {
        IniRead, key, %ConfigFile%, Hotkeys, % a.id, % a.defaultKey
        if (key = "" || key = "ERROR")
            key := a.defaultKey
        HotkeyRegister_Apply(a, key)
    }

    HotkeySyncAltMoveReleases()
    HotkeyRegister_RegisterInternal()
}

; 应用单个 Action 的绑定（仅注册，不改配置、不做冲突检查）
HotkeyRegister_Apply(action, key) {
    global g_HotkeyToFeature, g_ActionCurrentKey

    if (key = "")
        return

    ; 可配置动作走闸门，否则清空
    Hotkey, If, IsHotkeyEnabled(A_ThisHotkey)
    g_HotkeyToFeature[key] := action.feature

    try {
        Hotkey, %key%, % action.label, On UseErrorLevel
    } catch e {
        ; 注册失败（非法键名等），留给上层提示
    }

    g_ActionCurrentKey[action.id] := key
}

; 撤销单个 Action 的当前绑定
HotkeyRegister_Unapply(action) {
    global g_HotkeyToFeature, g_ActionCurrentKey

    oldKey := g_ActionCurrentKey[action.id]
    if (oldKey = "")
        return

    Hotkey, If, IsHotkeyEnabled(A_ThisHotkey)
    try Hotkey, %oldKey%, , Off UseErrorLevel

    g_HotkeyToFeature.Delete(oldKey)
    g_ActionCurrentKey.Delete(action.id)
}

; 修改单个 Action 的绑定（含冲突处理、落盘、联动）
; 返回 "ok" / "conflict:<其他ActionId>" / "invalid"
HotkeyRegister_Change(actionId, newKey, overrideConflict := false) {
    global g_ActionById, g_ActionCurrentKey, g_HotkeyToFeature, ConfigFile

    action := g_ActionById[actionId]
    if (!action)
        return "invalid"

    newKey := HotkeyCanonicalize(newKey)
    if (newKey = "")
        return "invalid"

    ; 冲突？
    conflictId := HotkeyFindConflict(newKey, actionId)
    if (conflictId != "" && !overrideConflict)
        return "conflict:" . conflictId

    ; 若覆盖冲突，先把冲突动作降级为未绑定
    if (conflictId != "" && overrideConflict) {
        other := g_ActionById[conflictId]
        HotkeyRegister_Unapply(other)
        IniDelete, %ConfigFile%, Hotkeys, % other.id
    }

    ; 撤销自身旧绑定，注册新绑定
    HotkeyRegister_Unapply(action)
    HotkeyRegister_Apply(action, newKey)

    IniWrite, %newKey%, %ConfigFile%, Hotkeys, % action.id

    ; AltMove 需同步释放监听
    if (action.id = "AltMove_Drag")
        HotkeySyncAltMoveReleases()

    return "ok"
}

HotkeyRegister_ResetOne(actionId) {
    global g_ActionById
    a := g_ActionById[actionId]
    if (!a)
        return
    HotkeyRegister_Change(actionId, a.defaultKey, true)
}

HotkeyRegister_ResetAll() {
    global g_Actions
    for i, a in g_Actions
        HotkeyRegister_ResetOne(a.id)
}

; 冲突扫描：返回已占用该 key 的 ActionId；无冲突返回 ""
HotkeyFindConflict(key, ignoreActionId) {
    global g_ActionCurrentKey
    key := HotkeyCanonicalize(key)
    for id, existingKey in g_ActionCurrentKey {
        if (id = ignoreActionId)
            continue
        if (HotkeyCanonicalize(existingKey) = key)
            return id
    }
    return ""
}

; ------------------------------------------------------------
; 内部键（常驻）
; ------------------------------------------------------------
HotkeyRegister_RegisterInternal() {
    Hotkey, If  ; 无条件
    try Hotkey, ~Esc, ReconstructionWindow_Cancel, On UseErrorLevel
}

; AltMove 的释放监听：根据当前触发键派生 ~<主键> Up 与 ~<修饰键> Up
HotkeySyncAltMoveReleases() {
    global g_AltMoveReleaseKeys, g_ActionCurrentKey

    ; 撤销旧的
    Hotkey, If
    if (IsObject(g_AltMoveReleaseKeys)) {
        for i, k in g_AltMoveReleaseKeys {
            try Hotkey, %k%, , Off UseErrorLevel
        }
    }
    g_AltMoveReleaseKeys := []

    triggerKey := g_ActionCurrentKey["AltMove_Drag"]
    if (triggerKey = "")
        return

    parts := HotkeyParse(triggerKey)
    if (parts.main = "" || parts.custom)
        return

    ; 主键释放
    mainUp := "~" . parts.main . " Up"
    try {
        Hotkey, %mainUp%, AltMove_End, On UseErrorLevel
        if (!ErrorLevel)
            g_AltMoveReleaseKeys.Push(mainUp)
    }

    ; 修饰键释放（取第一个）
    modName := HotkeyFirstModifierName(parts)
    if (modName != "") {
        modUp := "~" . modName . " Up"
        try {
            Hotkey, %modUp%, AltMove_End, On UseErrorLevel
            if (!ErrorLevel)
                g_AltMoveReleaseKeys.Push(modUp)
        }
    }
}

HotkeyFirstModifierName(parts) {
    if (parts.alt)   return "Alt"
    if (parts.ctrl)  return "Control"
    if (parts.shift) return "Shift"
    if (parts.win)   return "LWin"
    return ""
}

; ------------------------------------------------------------
; 热键串解析 / 格式化 / 显示
; ------------------------------------------------------------
HotkeyParse(spec) {
    parts := {ctrl:0, alt:0, shift:0, win:0, passthrough:0, main:"", custom:0, prefix:"", raw:spec}

    s := Trim(spec)
    if (s = "")
        return parts

    ; 自定义组合 "X & Y"
    if (InStr(s, " & ")) {
        parts.custom := 1
        p := InStr(s, " & ")
        parts.prefix := Trim(SubStr(s, 1, p - 1))
        parts.main := Trim(SubStr(s, p + 3))
        return parts
    }

    ; 穿透前缀
    if (SubStr(s, 1, 1) = "~") {
        parts.passthrough := 1
        s := SubStr(s, 2)
    }

    ; 修饰符
    Loop {
        if (s = "")
            break
        ch := SubStr(s, 1, 1)
        if (ch = "^") {
            parts.ctrl := 1
            s := SubStr(s, 2)
        } else if (ch = "!") {
            parts.alt := 1
            s := SubStr(s, 2)
        } else if (ch = "+") {
            parts.shift := 1
            s := SubStr(s, 2)
        } else if (ch = "#") {
            parts.win := 1
            s := SubStr(s, 2)
        } else {
            break
        }
    }

    parts.main := s
    return parts
}

HotkeyFormat(parts) {
    mCustom := parts.custom, mPassthrough := parts.passthrough
    mCtrl := parts.ctrl, mAlt := parts.alt, mShift := parts.shift, mWin := parts.win
    mMain := parts.main, mPrefix := parts.prefix
    if (mCustom)
        return mPrefix . " & " . mMain
    s := ""
    if (mPassthrough)
        s .= "~"
    if (mCtrl)
        s .= "^"
    if (mAlt)
        s .= "!"
    if (mShift)
        s .= "+"
    if (mWin)
        s .= "#"
    s .= mMain
    return s
}

HotkeyCanonicalize(spec) {
    parts := HotkeyParse(spec)
    mMain := parts.main, mCustom := parts.custom
    if (mMain = "" && !mCustom)
        return ""
    return HotkeyFormat(parts)
}

; 中文友好显示
HotkeyDisplay(spec) {
    parts := HotkeyParse(spec)
    mCustom := parts.custom, mCtrl := parts.ctrl, mAlt := parts.alt
    mShift := parts.shift, mWin := parts.win, mMain := parts.main, mPrefix := parts.prefix
    if (mCustom)
        return HotkeyKeyDisplay(mPrefix) . "+" . HotkeyKeyDisplay(mMain)

    disp := ""
    if (mCtrl)
        disp .= "Ctrl+"
    if (mAlt)
        disp .= "Alt+"
    if (mShift)
        disp .= "Shift+"
    if (mWin)
        disp .= "Win+"
    disp .= HotkeyKeyDisplay(mMain)
    return disp
}

HotkeyKeyDisplay(key) {
    static map := ""
    if (map = "") {
        map := {"LButton":"鼠标左键", "RButton":"鼠标右键", "MButton":"鼠标中键"
            , "XButton1":"鼠标侧键1", "XButton2":"鼠标侧键2"
            , "WheelUp":"滚轮上", "WheelDown":"滚轮下"
            , "WheelLeft":"滚轮左", "WheelRight":"滚轮右"
            , "Space":"空格", "Tab":"Tab", "Enter":"Enter", "Esc":"Esc"
            , "Backspace":"Backspace", "BS":"Backspace"
            , "Del":"Delete", "Delete":"Delete", "Ins":"Insert", "Insert":"Insert"
            , "Up":"↑", "Down":"↓", "Left":"←", "Right":"→"
            , "Home":"Home", "End":"End", "PgUp":"PageUp", "PgDn":"PageDown"
            , "Alt":"Alt", "Control":"Ctrl", "Shift":"Shift", "LWin":"Win"}
    }
    if (key = "")
        return ""
    v := map[key]
    if (v != "")
        return v
    ; 单字符大写
    if (StrLen(key) = 1) {
        StringUpper, out, key
        return out
    }
    return key
}

; ------------------------------------------------------------
; 主键下拉选项（显示串 → AHK键名 的双向映射）
; ------------------------------------------------------------
HotkeyMainKeyOptions() {
    static items := "", labelToKey := "", keyToLabel := ""
    if (items != "")
        return {items:items, labelToKey:labelToKey, keyToLabel:keyToLabel}

    labelToKey := {}
    keyToLabel := {}
    arr := []

    ; 字母
    Loop, 26 {
        c := Chr(Asc("a") + A_Index - 1)
        d := Chr(Asc("A") + A_Index - 1)
        HKAddOption(arr, labelToKey, keyToLabel, d, c)
    }
    ; 数字
    Loop, 10 {
        n := A_Index - 1
        HKAddOption(arr, labelToKey, keyToLabel, "数字 " . n, "" . n)
    }
    ; 功能键
    Loop, 24 {
        f := "F" . A_Index
        HKAddOption(arr, labelToKey, keyToLabel, f, f)
    }
    ; 鼠标
    HKAddOption(arr, labelToKey, keyToLabel, "鼠标左键 (LButton)", "LButton")
    HKAddOption(arr, labelToKey, keyToLabel, "鼠标右键 (RButton)", "RButton")
    HKAddOption(arr, labelToKey, keyToLabel, "鼠标中键 (MButton)", "MButton")
    HKAddOption(arr, labelToKey, keyToLabel, "鼠标侧键1 (XButton1)", "XButton1")
    HKAddOption(arr, labelToKey, keyToLabel, "鼠标侧键2 (XButton2)", "XButton2")
    ; 滚轮
    HKAddOption(arr, labelToKey, keyToLabel, "滚轮上 (WheelUp)", "WheelUp")
    HKAddOption(arr, labelToKey, keyToLabel, "滚轮下 (WheelDown)", "WheelDown")
    HKAddOption(arr, labelToKey, keyToLabel, "滚轮左 (WheelLeft)", "WheelLeft")
    HKAddOption(arr, labelToKey, keyToLabel, "滚轮右 (WheelRight)", "WheelRight")
    ; 编辑
    HKAddOption(arr, labelToKey, keyToLabel, "空格 (Space)", "Space")
    HKAddOption(arr, labelToKey, keyToLabel, "Tab", "Tab")
    HKAddOption(arr, labelToKey, keyToLabel, "Enter", "Enter")
    HKAddOption(arr, labelToKey, keyToLabel, "Esc", "Esc")
    HKAddOption(arr, labelToKey, keyToLabel, "Backspace", "Backspace")
    HKAddOption(arr, labelToKey, keyToLabel, "Delete", "Delete")
    HKAddOption(arr, labelToKey, keyToLabel, "Insert", "Insert")
    ; 方向
    HKAddOption(arr, labelToKey, keyToLabel, "↑ (Up)", "Up")
    HKAddOption(arr, labelToKey, keyToLabel, "↓ (Down)", "Down")
    HKAddOption(arr, labelToKey, keyToLabel, "← (Left)", "Left")
    HKAddOption(arr, labelToKey, keyToLabel, "→ (Right)", "Right")
    HKAddOption(arr, labelToKey, keyToLabel, "Home", "Home")
    HKAddOption(arr, labelToKey, keyToLabel, "End", "End")
    HKAddOption(arr, labelToKey, keyToLabel, "PageUp (PgUp)", "PgUp")
    HKAddOption(arr, labelToKey, keyToLabel, "PageDown (PgDn)", "PgDn")

    items := ""
    for i, v in arr {
        if (i > 1)
            items .= "|"
        items .= v
    }
    return {items:items, labelToKey:labelToKey, keyToLabel:keyToLabel}
}

HKAddOption(ByRef arr, ByRef labelToKey, ByRef keyToLabel, label, key) {
    arr.Push(label)
    labelToKey[label] := key
    keyToLabel[key] := label
}

; ------------------------------------------------------------
; 设置 GUI - 快捷键标签页
; ------------------------------------------------------------
BuildHotkeyTab() {
    global g_Actions, g_HotkeyTabBuilt, FeatureModules
    Gui, Settings:Tab, 快捷键

    xGroup := 20
    wGroup := 480
    xName := 30
    wName := 130
    xKey  := 165
    wKey  := 200
    xBtn1 := 370
    xBtn2 := 430
    rowH  := 22
    padTop := 18
    padBot := 4
    gapGroup := 4

    y := 36
    for fi, m in FeatureModules {
        groupActions := []
        for ai, a in g_Actions {
            if (a.feature = m.var)
                groupActions.Push(a)
        }
        if (groupActions.Length() = 0)
            continue

        if (groupActions.Length() = 1) {
            a := groupActions[1]
            Gui, Settings:Add, Text, x%xName% y%y% w%wName% h18, % m.name

            keyCtrlVar := "HKRow_" . a.id . "_Key"
            Gui, Settings:Add, Text, x%xKey% y%y% w%wKey% h18 v%keyCtrlVar%, % HotkeyDisplay(a.defaultKey)

            if (a.configurable) {
                editLabel := "HKEdit_" . a.id
                resetLabel := "HKReset_" . a.id
                yBtn := y - 2
                Gui, Settings:Add, Button, x%xBtn1% y%yBtn% w50 h20 g%editLabel%, 修改
                Gui, Settings:Add, Button, x%xBtn2% y%yBtn% w50 h20 g%resetLabel%, 重置
            } else {
                Gui, Settings:Add, Text, x%xBtn1% y%y% w110 h18, （不可修改）
            }

            y += rowH + gapGroup
            continue
        }

        hGroup := padTop + groupActions.Length() * rowH + padBot
        Gui, Settings:Add, GroupBox, x%xGroup% y%y% w%wGroup% h%hGroup%, % m.name

        yRow := y + padTop
        for ai, a in groupActions {
            Gui, Settings:Add, Text, x%xName% y%yRow% w%wName% h18, % a.displayName

            keyCtrlVar := "HKRow_" . a.id . "_Key"
            Gui, Settings:Add, Text, x%xKey% y%yRow% w%wKey% h18 v%keyCtrlVar%, % HotkeyDisplay(a.defaultKey)

            if (a.configurable) {
                editLabel := "HKEdit_" . a.id
                resetLabel := "HKReset_" . a.id
                yBtn := yRow - 2
                Gui, Settings:Add, Button, x%xBtn1% y%yBtn% w50 h20 g%editLabel%, 修改
                Gui, Settings:Add, Button, x%xBtn2% y%yBtn% w50 h20 g%resetLabel%, 重置
            } else {
                Gui, Settings:Add, Text, x%xBtn1% y%yRow% w110 h18, （不可修改）
            }

            yRow += rowH
        }

        y += hGroup + gapGroup
    }

    y += 6
    Gui, Settings:Add, Button, x30 y%y% w140 h24 gHKResetAll, 全部恢复默认
    Gui, Settings:Add, Button, x180 y%y% w140 h24 gHKReloadScript, 重启以应用新绑定

    g_HotkeyTabBuilt := true
    UpdateHotkeyTabUI()
}

UpdateHotkeyTabUI() {
    global g_Actions, g_ActionCurrentKey, g_HotkeyTabBuilt
    if (!g_HotkeyTabBuilt)
        return
    for i, a in g_Actions {
        k := g_ActionCurrentKey[a.id]
        if (k = "")
            k := a.defaultKey
        ctrlVar := "HKRow_" . a.id . "_Key"
        GuiControl, Settings:, %ctrlVar%, % HotkeyDisplay(k)
    }
}

; ------------------------------------------------------------
; 捕获对话框
; ------------------------------------------------------------
HotkeyCapture_Show(actionId) {
    global g_HotkeyCaptureTargetId, g_ActionById, g_ActionCurrentKey
    global HKCapCtrl, HKCapAlt, HKCapShift, HKCapWin, HKCapMainKey

    a := g_ActionById[actionId]
    if (!a || !a.configurable)
        return
    g_HotkeyCaptureTargetId := actionId

    key := g_ActionCurrentKey[actionId]
    if (key = "")
        key := a.defaultKey
    parts := HotkeyParse(key)

    opts := HotkeyMainKeyOptions()
    items := opts.items

    try Gui, HKCap:Destroy
    Gui, HKCap:New, +AlwaysOnTop +OwnDialogs +LabelHKCap, 设置快捷键
    Gui, HKCap:Font, s10
    Gui, HKCap:Margin, 14, 12

    Gui, HKCap:Add, GroupBox, w360 h64 Section, 修饰键
    Gui, HKCap:Add, Checkbox, xs+12 ys+22 vHKCapCtrl, Ctrl
    Gui, HKCap:Add, Checkbox, x+16   ys+22 vHKCapAlt, Alt
    Gui, HKCap:Add, Checkbox, x+16   ys+22 vHKCapShift, Shift
    Gui, HKCap:Add, Checkbox, x+16   ys+22 vHKCapWin, Win

    Gui, HKCap:Add, Text, xm y+14, 主键：
    labelForCurrent := ""
    if (parts.main != "") {
        labelForCurrent := opts.keyToLabel[parts.main]
    }
    chooseStr := ""
    if (labelForCurrent != "")
        chooseStr := "|" . labelForCurrent  ; AHK 的 "||" 语法：Choose 默认项
    Gui, HKCap:Add, DropDownList, xm w360 vHKCapMainKey, % ReplaceDefaultInList(items, labelForCurrent)

    Gui, HKCap:Add, Button, xm y+14 w90 h26 Default gHKCapOK, 确定
    Gui, HKCap:Add, Button, x+10 w90 h26 gHKCapResetDefault, 重置默认
    Gui, HKCap:Add, Button, x+10 w90 h26 gHKCapCancel, 取消

    ; 预填修饰
    GuiControl, HKCap:, HKCapCtrl,  % parts.ctrl
    GuiControl, HKCap:, HKCapAlt,   % parts.alt
    GuiControl, HKCap:, HKCapShift, % parts.shift
    GuiControl, HKCap:, HKCapWin,   % parts.win

    Gui, HKCap:Show
}

ReplaceDefaultInList(items, chosenLabel) {
    ; 把 chosenLabel 放到开头使其成为默认选项：AHK DropDownList 以 "||" 标记默认项
    if (chosenLabel = "")
        return items
    ; 移除 chosenLabel（避免重复）再放到最前
    newItems := chosenLabel . "||"
    for i, tok in StrSplit(items, "|") {
        if (tok = chosenLabel)
            continue
        newItems .= tok . "|"
    }
    return RTrim(newItems, "|")
}

HKCapCollectParts() {
    bCtrl := 0, bAlt := 0, bShift := 0, bWin := 0, sMain := ""
    GuiControlGet, bCtrl,  HKCap:, HKCapCtrl
    GuiControlGet, bAlt,   HKCap:, HKCapAlt
    GuiControlGet, bShift, HKCap:, HKCapShift
    GuiControlGet, bWin,   HKCap:, HKCapWin
    GuiControlGet, sMain,  HKCap:, HKCapMainKey
    opts := HotkeyMainKeyOptions()
    mainKey := opts.labelToKey[sMain]
    parts := {ctrl:(bCtrl = 1) ? 1 : 0
            , alt:(bAlt = 1) ? 1 : 0
            , shift:(bShift = 1) ? 1 : 0
            , win:(bWin = 1) ? 1 : 0
            , passthrough:0, custom:0, prefix:"", raw:""
            , main: mainKey != "" ? mainKey : ""}
    return parts
}

HKCapOK:
    HKCapHandleOK()
return

HKCapHandleOK() {
    global g_HotkeyCaptureTargetId, g_ActionById
    parts := HKCapCollectParts()
    if (parts.main = "") {
        MsgBox, 0x40030, 提示, 请选择主键。
        return
    }
    newKey := HotkeyFormat(parts)
    result := HotkeyRegister_Change(g_HotkeyCaptureTargetId, newKey)
    if (result = "ok") {
        Gui, HKCap:Destroy
        UpdateHotkeyTabUI()
        RefreshTrayHotkeyLabels()
        CreateTrayMenu()
        return
    }
    if (SubStr(result, 1, 9) = "conflict:") {
        otherId := SubStr(result, 10)
        other := g_ActionById[otherId]
        otherName := other ? other.displayName : otherId
        MsgBox, 0x40034, 冲突, % "该组合已被 [" . otherName . "] 使用，是否替换？"
        IfMsgBox Yes
        {
            result2 := HotkeyRegister_Change(g_HotkeyCaptureTargetId, newKey, true)
            if (result2 = "ok") {
                Gui, HKCap:Destroy
                UpdateHotkeyTabUI()
                RefreshTrayHotkeyLabels()
                CreateTrayMenu()
                return
            }
        }
        return
    }
    MsgBox, 0x40030, 提示, 无法注册该组合（键名非法或被系统占用）。
}

HKCapResetDefault:
    HKCapResetDefaultHandle()
return

HKCapResetDefaultHandle() {
    global g_HotkeyCaptureTargetId, g_ActionById
    a := g_ActionById[g_HotkeyCaptureTargetId]
    if (!a)
        return
    HotkeyRegister_ResetOne(a.id)
    Gui, HKCap:Destroy
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
}

HKCapCancel:
HKCapClose:
HKCapEscape:
    Gui, HKCap:Destroy
return

; ------------------------------------------------------------
; 托盘菜单热键显示：聚合每个 Feature 下的所有 Action 当前键
; ------------------------------------------------------------
RefreshTrayHotkeyLabels() {
    global FeatureModules, g_Actions, g_ActionCurrentKey
    for i, m in FeatureModules {
        parts := []
        for j, a in g_Actions {
            if (a.feature != m.var)
                continue
            k := g_ActionCurrentKey[a.id]
            if (k = "")
                k := a.defaultKey
            parts.Push(HotkeyDisplay(k))
        }
        m.hotkey := JoinArray(parts, " / ")
    }
}

JoinArray(arr, sep) {
    s := ""
    for i, v in arr {
        if (i > 1)
            s .= sep
        s .= v
    }
    return s
}

; ------------------------------------------------------------
; 快捷键标签页：按钮事件（所有可配置 Action 的 Edit/Reset）
; 通过命名约定：HKEdit_<ActionId> / HKReset_<ActionId>
; 这些标签在 BuildHotkeyTab 时通过 gHKEdit_<id> 引用，由下方 catch-all 分派
; ------------------------------------------------------------
; 使用 AHK 的"动态 goto"替代：为每个 Action 生成一个标签是静态需要的。
; 因此我们在 Actions 表加入时同时在脚本中以静态方式提供这些标签。
; ---- 具体标签在本文件末尾集中定义 ----

; ============================================================
; 静态标签：每个 Action 的 Edit/Reset 事件分派
; ============================================================

HKEdit_AltMove_Drag:
    HotkeyCapture_Show("AltMove_Drag")
return
HKReset_AltMove_Drag:
    HotkeyRegister_ResetOne("AltMove_Drag")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_BorderlessWindow_Toggle:
    HotkeyCapture_Show("BorderlessWindow_Toggle")
return
HKReset_BorderlessWindow_Toggle:
    HotkeyRegister_ResetOne("BorderlessWindow_Toggle")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_MinimizeWindow_Others:
    HotkeyCapture_Show("MinimizeWindow_Others")
return
HKReset_MinimizeWindow_Others:
    HotkeyRegister_ResetOne("MinimizeWindow_Others")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_MinimizeWindow_Current:
    HotkeyCapture_Show("MinimizeWindow_Current")
return
HKReset_MinimizeWindow_Current:
    HotkeyRegister_ResetOne("MinimizeWindow_Current")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_MinimizeWindow_Wheel:
    HotkeyCapture_Show("MinimizeWindow_Wheel")
return
HKReset_MinimizeWindow_Wheel:
    HotkeyRegister_ResetOne("MinimizeWindow_Wheel")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_PastePureText_Paste:
    HotkeyCapture_Show("PastePureText_Paste")
return
HKReset_PastePureText_Paste:
    HotkeyRegister_ResetOne("PastePureText_Paste")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_PeekDesktop_Toggle:
    HotkeyCapture_Show("PeekDesktop_Toggle")
return
HKReset_PeekDesktop_Toggle:
    HotkeyRegister_ResetOne("PeekDesktop_Toggle")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_ReconstructionWindow_Start:
    HotkeyCapture_Show("ReconstructionWindow_Start")
return
HKReset_ReconstructionWindow_Start:
    HotkeyRegister_ResetOne("ReconstructionWindow_Start")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_SwitchProgramWindows_Prev:
    HotkeyCapture_Show("SwitchProgramWindows_Prev")
return
HKReset_SwitchProgramWindows_Prev:
    HotkeyRegister_ResetOne("SwitchProgramWindows_Prev")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_SwitchProgramWindows_Next:
    HotkeyCapture_Show("SwitchProgramWindows_Next")
return
HKReset_SwitchProgramWindows_Next:
    HotkeyRegister_ResetOne("SwitchProgramWindows_Next")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowCenter_Apply:
    HotkeyCapture_Show("WindowCenter_Apply")
return
HKReset_WindowCenter_Apply:
    HotkeyRegister_ResetOne("WindowCenter_Apply")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowOnTop_Toggle:
    HotkeyCapture_Show("WindowOnTop_Toggle")
return
HKReset_WindowOnTop_Toggle:
    HotkeyRegister_ResetOne("WindowOnTop_Toggle")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowScaling_Up:
    HotkeyCapture_Show("WindowScaling_Up")
return
HKReset_WindowScaling_Up:
    HotkeyRegister_ResetOne("WindowScaling_Up")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowScaling_Down:
    HotkeyCapture_Show("WindowScaling_Down")
return
HKReset_WindowScaling_Down:
    HotkeyRegister_ResetOne("WindowScaling_Down")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowSize_Menu:
    HotkeyCapture_Show("WindowSize_Menu")
return
HKReset_WindowSize_Menu:
    HotkeyRegister_ResetOne("WindowSize_Menu")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowToTray_Hide:
    HotkeyCapture_Show("WindowToTray_Hide")
return
HKReset_WindowToTray_Hide:
    HotkeyRegister_ResetOne("WindowToTray_Hide")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKEdit_WindowToTray_ShowMenu:
    HotkeyCapture_Show("WindowToTray_ShowMenu")
return
HKReset_WindowToTray_ShowMenu:
    HotkeyRegister_ResetOne("WindowToTray_ShowMenu")
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKResetAll:
    HotkeyRegister_ResetAll()
    UpdateHotkeyTabUI()
    RefreshTrayHotkeyLabels()
    CreateTrayMenu()
return

HKReloadScript:
    Reload
return
