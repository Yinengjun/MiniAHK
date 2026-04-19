; 切换当前活动窗口置顶状态（由主脚本动态注册热键）
WindowOnTop_Toggle:
    global WindowOnTop
    if (!WindowOnTop || !MasterSwitch)
        return

    WinSet, AlwaysOnTop,, A
    DllCall("user32.dll\MessageBeep", "UInt", 0xFFFFFFFF)
return
