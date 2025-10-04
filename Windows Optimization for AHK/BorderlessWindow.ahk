; -----------------------------
; Alt + B 切换当前窗口的无边框化 / 完全复原
; -----------------------------

!b::  ; Alt + B
{
    global BorderlessWindow
    if (!BorderlessWindow)
        return
  
    WinGet, style, Style, A  ; 获取当前活动窗口的样式

    ; 使用窗口的 HWND 作为唯一标识存储尺寸
    WinGet, hwnd, ID, A

    ; 检查窗口是否已经无边框
    if (style & 0xC40000)
    {
        ; 保存原始位置和大小
        WinGetPos, origX, origY, origW, origH, A
        ; 将这些值存到对象中，使用窗口句柄作为键
        if !WinPos
            WinPos := {}  ; 初始化对象
        WinPos[hwnd] := [origX, origY, origW, origH]

        ; 去掉标题栏和边框
        WinSet, Style, -0xC40000, A
        ; 最大化窗口到全屏
        WinMove, A, , 0, 0, %A_ScreenWidth%, %A_ScreenHeight%
    }
    else
    {
        ; 恢复标题栏和边框
        WinSet, Style, +0xC40000, A

        ; 获取保存的原始位置和大小
        if WinPos.HasKey(hwnd)
        {
            pos := WinPos[hwnd]
            WinMove, A, , pos[1], pos[2], pos[3], pos[4]
            WinPos.Delete(hwnd)  ; 删除记录，防止内存占用
        }
    }
}
