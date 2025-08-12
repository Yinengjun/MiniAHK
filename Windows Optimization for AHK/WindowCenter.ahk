!c::  ; Alt+C 窗口居中
    WinGetPos, X, Y, W, H, A
    SysGet, MonitorWorkArea, MonitorWorkArea
    NewX := MonitorWorkAreaLeft + ((MonitorWorkAreaRight - MonitorWorkAreaLeft) - W) // 2
    NewY := MonitorWorkAreaTop + ((MonitorWorkAreaBottom - MonitorWorkAreaTop) - H) // 2
    WinMove, A,, NewX, NewY
return
