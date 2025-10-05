; -*- coding: utf-8 -*-
#NoEnv
#SingleInstance Force
SendMode Input

global SwitchProgramWindows

; Ctrl+Alt+鼠标滚轮
^!WheelUp::
    if (!SwitchProgramWindows || !MasterSwitch)
        return
    SwitchAppWindow("Up")
return

^!WheelDown::
    if (!SwitchProgramWindows || !MasterSwitch)
        return
    SwitchAppWindow("Down")
return

SwitchAppWindow(direction) {
    WinGet, active_id, ID, A
    if !active_id
        return

    ; 获取当前窗口所属进程名
    WinGet, ProcessName, ProcessName, ahk_id %active_id%
    if !ProcessName
        return

    ; 枚举该进程所有窗口
    WinGet, idList, List, ahk_exe %ProcessName%
    if (idList = 0)
        return

    ; 在列表中找到当前窗口的位置
    Loop, %idList%
    {
        this_id := idList%A_Index%
        if (this_id = active_id) {
            currentIndex := A_Index
            break
        }
    }

    if !currentIndex
        return

    ; 计算下一个/上一个窗口索引（循环切换）
    if (direction = "Up")
        newIndex := currentIndex - 1
    else
        newIndex := currentIndex + 1

    if (newIndex < 1)
        newIndex := idList
    else if (newIndex > idList)
        newIndex := 1

    target_id := idList%newIndex%
    if target_id
        WinActivate, ahk_id %target_id%
}
