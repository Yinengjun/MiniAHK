#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

; ------------------------
; 全局开关变量
; ------------------------
global MinimizeWindow := true

; ------------------------
; 热键绑定
; ------------------------

; Alt + A -> 最小化除当前窗口外的所有窗口
!a::
if (!MinimizeWindow || !MasterSwitch)
    return
Send, #{Home}
return

; Alt + M -> 最小化当前活动窗口
!m::
if (!MinimizeWindow || !MasterSwitch)
    return
WinMinimize, A
return
