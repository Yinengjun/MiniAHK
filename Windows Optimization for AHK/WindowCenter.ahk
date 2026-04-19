; 窗口居中（由主脚本动态注册热键）
WindowCenter_Apply:
    global WindowCenter
    if (!WindowCenter || !MasterSwitch)
        return

    WinGetPos, X, Y, W, H, A
    SysGet, MonitorWorkArea, MonitorWorkArea
    NewX := MonitorWorkAreaLeft + ((MonitorWorkAreaRight - MonitorWorkAreaLeft) - W) // 2
    NewY := MonitorWorkAreaTop + ((MonitorWorkAreaBottom - MonitorWorkAreaTop) - H) // 2
    WinMove, A,, NewX, NewY
return
