^+e::                          ; Ctrl + Shift + E
global WindowOnTop
if (!WindowOnTop)
    return

WinSet, AlwaysOnTop,, A        ; 切换当前活动窗口置顶状态
; SoundBeep, 500, 150            ; 播放提示音
DllCall("user32.dll\MessageBeep", "UInt", 0xFFFFFFFF)
return                         ;
