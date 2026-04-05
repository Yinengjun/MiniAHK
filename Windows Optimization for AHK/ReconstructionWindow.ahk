; =========================
; ReconstructionWindow.ahk
; （仅供主脚本 #Include 引入）
; =========================

CoordMode, Mouse, Screen

; 全局变量声明
global ReconstructionWindow
global x1, y1, x2, y2, xm, ym, w, h
global dragging, borderWidth, hwndOverlay

; -------------------------
; 热键：Alt+T 启动重构窗口模式
; -------------------------
#If (ReconstructionWindow && MasterSwitch)
!t::Gosub, StartReconstruction
#If

; -------------------------
; 主流程
; -------------------------
StartReconstruction:
    CoordMode, Mouse, Screen

    ; 获取屏幕工作区
    SysGet, MonitorWorkArea, MonitorWorkArea, 1
    screenW := MonitorWorkAreaRight - MonitorWorkAreaLeft
    screenH := MonitorWorkAreaBottom - MonitorWorkAreaTop
    
    ; 创建全屏遮罩层（阻止鼠标交互，不要 -E0x20）
    Gui, Overlay:New, +AlwaysOnTop -Caption +ToolWindow +LastFound -DPIScale
    Gui, Overlay:Color, 000000
    Gui, Overlay:Show, x0 y0 w%screenW% h%screenH%, Overlay
    Gui, Overlay:+LastFound
    hwndOverlay := WinExist()
    WinSet, Transparent, 100, ahk_id %hwndOverlay%
    
    ; 创建边框 GUI（4条红色边框）
    Gui, BorderTop:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 -DPIScale
    Gui, BorderTop:Color, FF0000
    Gui, BorderBottom:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 -DPIScale
    Gui, BorderBottom:Color, FF0000
    Gui, BorderLeft:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 -DPIScale
    Gui, BorderLeft:Color, FF0000
    Gui, BorderRight:New, +AlwaysOnTop -Caption +ToolWindow +LastFound +E0x20 -DPIScale
    Gui, BorderRight:Color, FF0000
    
    ; 等待鼠标左键按下
    KeyWait, LButton, D
    MouseGetPos, x1, y1
    
    dragging := true
    borderWidth := 2
    SetTimer, UpdateBorder, 10
    
    ; 等待左键释放
    KeyWait, LButton
    dragging := false
    SetTimer, UpdateBorder, Off
    
    ; 获取终点
    MouseGetPos, x2, y2
    
    ; 计算矩形
    x := (x1<x2) ? x1 : x2
    y := (y1<y2) ? y1 : y2
    w := Abs(x2 - x1)
    h := Abs(y2 - y1)
    
    ; 销毁 GUI
    Gui, Overlay:Destroy
    Gui, BorderTop:Destroy
    Gui, BorderBottom:Destroy
    Gui, BorderLeft:Destroy
    Gui, BorderRight:Destroy
    
    ; 调整当前活动窗口
    WinGet, hwndWin, ID, A
    if (hwndWin && w > 10 && h > 10)
        WinMove, ahk_id %hwndWin%, , x, y, w, h
return

; -------------------------
; 更新边框显示
; -------------------------
UpdateBorder:
    if (dragging) {
        CoordMode, Mouse, Screen
        MouseGetPos, xm, ym
        x := (x1<xm) ? x1 : xm
        y := (y1<ym) ? y1 : ym
        w := Abs(xm - x1)
        h := Abs(ym - y1)

        if (w < borderWidth*2)
            w := borderWidth*2
        if (h < borderWidth*2)
            h := borderWidth*2
        
        ; 上边框
        Gui, BorderTop:Show, x%x% y%y% w%w% h%borderWidth%
        ; 下边框
        bottomY := y + h - borderWidth
        Gui, BorderBottom:Show, x%x% y%bottomY% w%w% h%borderWidth%
        ; 左边框
        Gui, BorderLeft:Show, x%x% y%y% w%borderWidth% h%h%
        ; 右边框
        rightX := x + w - borderWidth
        Gui, BorderRight:Show, x%rightX% y%y% w%borderWidth% h%h%
    }
return

; -------------------------
; ESC键取消操作
; -------------------------
~Esc::
if (dragging) {
    dragging := false
    SetTimer, UpdateBorder, Off
    Gui, Overlay:Destroy
    Gui, BorderTop:Destroy
    Gui, BorderBottom:Destroy
    Gui, BorderLeft:Destroy
    Gui, BorderRight:Destroy
}
return
