^+v::
{
    global PastePureText   ; 让这个变量和入口文件的全局变量连接
    if (!PastePureText)
        return
        
    ; 备份剪贴板
    ClipSaved := ClipboardAll
    ; 将剪贴板内容改为纯文本
    Clipboard := Clipboard
    ; 等待剪贴板完成
    ClipWait, 0.5
    ; 粘贴
    Send ^v
    ; 等待粘贴完成
    Sleep 100
    ; 恢复剪贴板
    Clipboard := ClipSaved
    ; 释放变量占用
    VarSetCapacity(ClipSaved, 0)
    ; 播放提示音
    ; SoundBeep, 700, 150
	DllCall("user32.dll\MessageBeep", "UInt", 0xFFFFFFFF)
    return
}
