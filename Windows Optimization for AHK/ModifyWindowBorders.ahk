; 窗口边框编辑器 - AutoHotkey v1
; Alt + 鼠标右键进入编辑模式，通过鼠标移动调整窗口边框
; 受 global ModifyWindowBorders 控制

#NoEnv
#MaxHotkeysPerInterval 99000000
#HotkeyInterval 99000000
#KeyHistory 0
ListLines Off
SetDefaultMouseSpeed, 0
SetMouseDelay, -1
SetKeyDelay, -1
SetWinDelay, -1
SetControlDelay, -1

; 全局变量
global ModifyWindowBorders := true  ; 功能开关，主程序控制
global MWB_EditMode := false
global MWB_StartX := 0
global MWB_StartY := 0
global MWB_TargetWindow := 0
global MWB_WindowX := 0
global MWB_WindowY := 0
global MWB_WindowW := 0
global MWB_WindowH := 0
global MWB_EditDirection := ""
global MWB_Sensitivity := 10  ; 鼠标移动敏感度

; 预览相关变量
global MWB_PreviewMode := false  ; 是否使用预览模式（左/上边框时启用）
global MWB_PreviewX := 0
global MWB_PreviewY := 0
global MWB_PreviewW := 0
global MWB_PreviewH := 0
global MWB_PreviewHwnd := 0  ; 保存预览窗口句柄

; 屏幕边界信息
global MWB_ScreenLeft := 0
global MWB_ScreenTop := 0
global MWB_ScreenRight := 0
global MWB_ScreenBottom := 0

; Alt + 鼠标右键开始编辑
#If (ModifyWindowBorders && MasterSwitch)
Alt & RButton::
    if (!MWB_EditMode) {
        MWB_StartEditMode()
    }
return
#If

; 开始编辑模式
MWB_StartEditMode() {
    global
    CoordMode, Mouse, Screen
    CoordMode, ToolTip, Screen
    
    ; 获取鼠标位置
    MouseGetPos, MWB_StartX, MWB_StartY, MWB_TargetWindow
    
    ; 检查是否有有效窗口
    if (MWB_TargetWindow = 0) {
        return
    }
    
    ; 获取当前屏幕的工作区域（排除任务栏等）
    SysGet, WorkArea, MonitorWorkArea
    MWB_ScreenLeft := WorkAreaLeft
    MWB_ScreenTop := WorkAreaTop
    MWB_ScreenRight := WorkAreaRight
    MWB_ScreenBottom := WorkAreaBottom
    
    ; 如果获取工作区域失败，使用完整屏幕尺寸
    if (MWB_ScreenRight = 0 || MWB_ScreenBottom = 0) {
        SysGet, ScreenWidth, 78  ; SM_CXSCREEN
        SysGet, ScreenHeight, 79 ; SM_CYSCREEN
        MWB_ScreenLeft := 0
        MWB_ScreenTop := 0
        MWB_ScreenRight := ScreenWidth
        MWB_ScreenBottom := ScreenHeight
    }
    
    ; 获取窗口信息
    WinGetPos, MWB_WindowX, MWB_WindowY, MWB_WindowW, MWB_WindowH, ahk_id %MWB_TargetWindow%
    
    ; 检查窗口是否在屏幕范围内
    if (MWB_WindowX >= MWB_ScreenRight || MWB_WindowY >= MWB_ScreenBottom 
        || MWB_WindowX + MWB_WindowW <= MWB_ScreenLeft || MWB_WindowY + MWB_WindowH <= MWB_ScreenTop) {
        ToolTip, 目标窗口超出屏幕范围！, %MWB_StartX%, %MWB_StartY%
        SetTimer, MWB_ClearToolTip, -2000
        return
    }
    
    ; 设置编辑模式
    MWB_EditMode := true
    MWB_EditDirection := ""
    MWB_PreviewMode := false
    
    ; 开始监听鼠标移动
    SetTimer, MWB_CheckMouseMovement, 10
    SetTimer, MWB_CheckExitCondition, 10
    
    ; 显示提示
    ToolTip, 编辑模式：移动鼠标调整窗口边框, %MWB_StartX%, %MWB_StartY%
}

; 检查鼠标移动
MWB_CheckMouseMovement:
    if (!MWB_EditMode) {
        return
    }
    CoordMode, Mouse, Screen
    MouseGetPos, MWB_CurrentX, MWB_CurrentY
    
    ; 计算移动距离
    MWB_DeltaX := MWB_CurrentX - MWB_StartX
    MWB_DeltaY := MWB_CurrentY - MWB_StartY
    
    ; 只有移动距离超过敏感度才响应
    if (Abs(MWB_DeltaX) < MWB_Sensitivity && Abs(MWB_DeltaY) < MWB_Sensitivity) {
        return
    }
    
    ; 确定编辑方向（一次只能编辑一边）
    if (MWB_EditDirection = "") {
        if (Abs(MWB_DeltaX) > Abs(MWB_DeltaY)) {
            MWB_EditDirection := (MWB_DeltaX > 0) ? "Right" : "Left"
        } else {
            MWB_EditDirection := (MWB_DeltaY > 0) ? "Down" : "Up"
        }
    }
    
    ; 根据方向调整窗口
    MWB_ResizeWindow(MWB_DeltaX, MWB_DeltaY)
return

; 创建预览窗口
MWB_CreatePreviewWindow() {
    global
    
    ; 销毁旧的预览框（如果存在）
    if (MWB_PreviewHwnd) {
        Gui, MWBPreview:Destroy
        MWB_PreviewHwnd := 0
    }
    
    ; 创建半透明预览框
    Gui, MWBPreview:New, +AlwaysOnTop +ToolWindow -Caption +E0x20 +Owner +HwndMWB_PreviewHwnd
    Gui, MWBPreview:Color, 0080FF  ; 蓝色预览框
    Gui, MWBPreview:Show, x%MWB_WindowX% y%MWB_WindowY% w%MWB_WindowW% h%MWB_WindowH% NA
    
    ; 设置透明度（修复问题1：使用窗口句柄）
    WinSet, Transparent, 80, ahk_id %MWB_PreviewHwnd%
    
    ; 初始化预览位置
    MWB_PreviewX := MWB_WindowX
    MWB_PreviewY := MWB_WindowY
    MWB_PreviewW := MWB_WindowW
    MWB_PreviewH := MWB_WindowH
}

; 更新预览框
MWB_UpdatePreview(DeltaX, DeltaY) {
    global
    
    NewX := MWB_WindowX
    NewY := MWB_WindowY
    NewW := MWB_WindowW
    NewH := MWB_WindowH
    
    ; 根据编辑方向调整预览框
    if (MWB_EditDirection = "Left") {
        ; 左边向左延长
        NewX := MWB_WindowX + DeltaX
        NewW := MWB_WindowW - DeltaX
        if (NewW < 100) {
            NewW := 100
            NewX := MWB_WindowX + MWB_WindowW - 100
        }
        ; 检查左边界
        if (NewX < MWB_ScreenLeft) {
            NewW := NewW - (MWB_ScreenLeft - NewX)
            NewX := MWB_ScreenLeft
            if (NewW < 100) {
                NewW := 100
            }
        }
    } else if (MWB_EditDirection = "Up") {
        ; 上边向上延长
        NewY := MWB_WindowY + DeltaY
        NewH := MWB_WindowH - DeltaY
        if (NewH < 100) {
            NewH := 100
            NewY := MWB_WindowY + MWB_WindowH - 100
        }
        ; 检查上边界
        if (NewY < MWB_ScreenTop) {
            NewH := NewH - (MWB_ScreenTop - NewY)
            NewY := MWB_ScreenTop
            if (NewH < 100) {
                NewH := 100
            }
        }
    }
    
    ; 保存预览值
    MWB_PreviewX := NewX
    MWB_PreviewY := NewY
    MWB_PreviewW := NewW
    MWB_PreviewH := NewH
    
    ; 更新预览框位置和大小
    Gui, MWBPreview:Show, x%NewX% y%NewY% w%NewW% h%NewH% NA
    
    ; 更新提示信息
    DirectionText := ""
    BoundaryWarning := ""
    
    if (MWB_EditDirection = "Left") {
        DirectionText := "← 左边框 [预览]"
        if (NewX <= MWB_ScreenLeft) {
            BoundaryWarning := " [已达左边界]"
        }
    } else if (MWB_EditDirection = "Up") {
        DirectionText := "↑ 上边框 [预览]"
        if (NewY <= MWB_ScreenTop) {
            BoundaryWarning := " [已达上边界]"
        }
    }
    
    ToolTip, 编辑模式：%DirectionText% (%NewW%x%NewH%)%BoundaryWarning%`n松开鼠标应用更改, %MWB_StartX%, %MWB_StartY%
}

; 调整窗口大小（右/下边框实时调整）
MWB_ResizeWindow(DeltaX, DeltaY) {
    global
    
    NewX := MWB_WindowX
    NewY := MWB_WindowY
    NewW := MWB_WindowW
    NewH := MWB_WindowH
    MinW := 100
    MinH := 100
    AnchorRight := MWB_WindowX + MWB_WindowW
    AnchorBottom := MWB_WindowY + MWB_WindowH
    
    ; 根据编辑方向调整窗口
    if (MWB_EditDirection = "Right") {
        ; 右边向右延长
        NewW := MWB_WindowW + DeltaX
        if (NewW < MinW)
            NewW := MinW  ; 最小宽度
        ; 检查右边界
        if (NewX + NewW > MWB_ScreenRight) {
            NewW := MWB_ScreenRight - NewX
        }
    } else if (MWB_EditDirection = "Left") {
        ; 左边向左延长（锚定右侧）
        NewX := MWB_WindowX + DeltaX
        NewW := AnchorRight - NewX
        if (NewW < MinW) {
            NewW := MinW
            NewX := AnchorRight - MinW
        }
        if (NewX < MWB_ScreenLeft) {
            NewX := MWB_ScreenLeft
            NewW := AnchorRight - NewX
            if (NewW < MinW) {
                NewW := MinW
                NewX := AnchorRight - MinW
            }
        }
    } else if (MWB_EditDirection = "Down") {
        ; 下边向下延长
        NewH := MWB_WindowH + DeltaY
        if (NewH < MinH)
            NewH := MinH  ; 最小高度
        ; 检查下边界
        if (NewY + NewH > MWB_ScreenBottom) {
            NewH := MWB_ScreenBottom - NewY
        }
    } else if (MWB_EditDirection = "Up") {
        ; 上边向上延长（锚定下侧）
        NewY := MWB_WindowY + DeltaY
        NewH := AnchorBottom - NewY
        if (NewH < MinH) {
            NewH := MinH
            NewY := AnchorBottom - MinH
        }
        if (NewY < MWB_ScreenTop) {
            NewY := MWB_ScreenTop
            NewH := AnchorBottom - NewY
            if (NewH < MinH) {
                NewH := MinH
                NewY := AnchorBottom - MinH
            }
        }
    }
    
    ; 最终边界检查
    if (NewX + NewW > MWB_ScreenRight) {
        NewW := MWB_ScreenRight - NewX
        if (NewW < MinW)
            NewW := MinW
    }
    if (NewY + NewH > MWB_ScreenBottom) {
        NewH := MWB_ScreenBottom - NewY
        if (NewH < MinH)
            NewH := MinH
    }
    
    ; 应用窗口变化
    WinMove, ahk_id %MWB_TargetWindow%, , %NewX%, %NewY%, %NewW%, %NewH%
    
    ; 更新提示信息
    DirectionText := ""
    BoundaryWarning := ""
    
    if (MWB_EditDirection = "Right") {
        DirectionText := "右边框 →"
        if (NewX + NewW >= MWB_ScreenRight) {
            BoundaryWarning := " [已达右边界]"
        }
    } else if (MWB_EditDirection = "Left") {
        DirectionText := "← 左边框"
        if (NewX <= MWB_ScreenLeft) {
            BoundaryWarning := " [已达左边界]"
        }
    } else if (MWB_EditDirection = "Down") {
        DirectionText := "下边框 ↓"
        if (NewY + NewH >= MWB_ScreenBottom) {
            BoundaryWarning := " [已达下边界]"
        }
    } else if (MWB_EditDirection = "Up") {
        DirectionText := "↑ 上边框"
        if (NewY <= MWB_ScreenTop) {
            BoundaryWarning := " [已达上边界]"
        }
    }
    
    ToolTip, 编辑模式：%DirectionText% (%NewW%x%NewH%)%BoundaryWarning%, %MWB_StartX%, %MWB_StartY%
}

; 检查退出条件
MWB_CheckExitCondition:
    if (!MWB_EditMode) {
        return
    }
    
    ; 检查Alt键是否松开
    if (!GetKeyState("Alt", "P")) {
        MWB_ExitEditMode()
        return
    }
    
    ; 检查右键是否松开
    if (!GetKeyState("RButton", "P")) {
        MWB_ExitEditMode()
        return
    }
return

; 退出编辑模式
MWB_ExitEditMode() {
    global
    
    ; 销毁预览窗口（如果存在）
    if (MWB_PreviewHwnd) {
        Gui, MWBPreview:Destroy
        MWB_PreviewHwnd := 0
    }
    
    MWB_EditMode := false
    MWB_EditDirection := ""
    MWB_TargetWindow := 0
    MWB_PreviewMode := false
    
    ; 停止定时器
    SetTimer, MWB_CheckMouseMovement, Off
    SetTimer, MWB_CheckExitCondition, Off
    
    ; 修复问题2：确保清除ToolTip，使用一次性定时器
    ToolTip
    SetTimer, MWB_ClearToolTip, -100
}

; 清除提示信息的定时器
MWB_ClearToolTip:
    ToolTip
return

; 程序退出时清理
MWB_Cleanup:
    if (MWB_PreviewHwnd) {
        Gui, MWBPreview:Destroy
        MWB_PreviewHwnd := 0
    }
    MWB_ExitEditMode()
return
