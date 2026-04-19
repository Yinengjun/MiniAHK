#NoEnv
#SingleInstance Force
SetWorkingDir %A_ScriptDir%

global MinimizeWindow

; 最小化除当前窗口外的所有窗口（由主脚本动态注册热键）
MinimizeWindow_Others:
    if (!MinimizeWindow || !MasterSwitch)
        return
    Send, #{Home}
return

; 最小化当前活动窗口
MinimizeWindow_Current:
    if (!MinimizeWindow || !MasterSwitch)
        return
    WinMinimize, A
return

; 滚轮触发最小化（与 Current 相同行为）
MinimizeWindow_Wheel:
    if (!MinimizeWindow || !MasterSwitch)
        return
    WinMinimize, A
return