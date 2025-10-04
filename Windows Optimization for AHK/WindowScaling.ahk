global WindowScaling := true

global g_ScaleStep := 0.05              ; 缩放步长 (5%)
global g_MinWindowSize := 100            ; 最小窗口尺寸

; 窗口类型排除列表
global g_ExcludedClasses := ["Shell_TrayWnd", "DV2ControlHost", "MsgrIMEWindowClass", "SysShadow"
    , "Progman", "WorkerW", "Shell_SecondaryTrayWnd", "NotifyIconOverflowWindow"
    , "TrayNotifyWnd", "tooltips_class32", "MSTaskSwWClass", "ForegroundStaging"
    , "ApplicationFrameWindow", "Windows.UI.Core.CoreWindow", "ImmersiveLauncher"
    , "ImmersiveBackground", "EdgeUiInputTopWndClass", "NativeHWNDHost"]

#If WindowScaling

; Ctrl+Shift+滚轮向上 - 放大窗口
^+WheelUp::
    HandleWindowScale(1 + g_ScaleStep)
return

; Ctrl+Shift+滚轮向下 - 缩小窗口  
^+WheelDown::
    HandleWindowScale(1 - g_ScaleStep)
return

#If

; 处理窗口缩放请求
HandleWindowScale(scaleFactor) {
    try {
        ; 获取活动窗口信息
        windowInfo := GetActiveWindowInfo()
        if (!windowInfo.isValid) {
            return false
        }
        
        ; 检查窗口是否可以缩放
        if (!IsWindowScalable(windowInfo)) {
            return false
        }
        
        ; 执行缩放
        return ScaleWindow(windowInfo, scaleFactor)
        
    } catch e {
        return false
    }
}

; 获取活动窗口信息
GetActiveWindowInfo() {
    windowInfo := {}
    
    try {
        WinGet, hwnd, ID, A
        if (!hwnd) {
            windowInfo.isValid := false
            return windowInfo
        }
        
        WinGetPos, x, y, width, height, ahk_id %hwnd%
        WinGet, processName, ProcessName, ahk_id %hwnd%
        WinGetClass, class, ahk_id %hwnd%
        WinGetTitle, title, ahk_id %hwnd%
        
        windowInfo.hwnd := hwnd
        windowInfo.x := x
        windowInfo.y := y  
        windowInfo.width := width
        windowInfo.height := height
        windowInfo.processName := processName
        windowInfo.class := class
        windowInfo.title := title
        windowInfo.isValid := true
        
    } catch e {
        windowInfo.isValid := false
    }
    
    return windowInfo
}

; 检查窗口是否可以缩放
IsWindowScalable(windowInfo) {
    ; 检查窗口句柄
    if (!windowInfo.hwnd || !windowInfo.isValid)
        return false
    
    ; 检查窗口尺寸
    if (windowInfo.width <= 0 || windowInfo.height <= 0)
        return false
        
    ; 检查排除列表
    for index, excludedClass in g_ExcludedClasses {
        if (windowInfo.class = excludedClass)
            return false
    }
    
    ; 检查窗口状态
    WinGet, minMax, MinMax, % "ahk_id " . windowInfo.hwnd
    if (minMax = -1) ; 最小化状态
        return false
    
    ; 检查是否为子窗口
    WinGet, style, Style, % "ahk_id " . windowInfo.hwnd
    if (!(style & 0x10000000)) ; WS_VISIBLE
        return false
        
    ; 检查是否为系统进程
    systemProcesses := ["dwm.exe", "winlogon.exe", "csrss.exe", "smss.exe", "wininit.exe"]
    for index, sysProcess in systemProcesses {
        if (windowInfo.processName = sysProcess)
            return false
    }
    
    ; 检查窗口标题是否包含敏感关键词
    sensitiveKeywords := ["安全", "Security", "Task Manager", "任务管理器", "System", "系统"]
    for index, keyword in sensitiveKeywords {
        if (InStr(windowInfo.title, keyword))
            return false
    }
    
    ; 检查是否为全屏窗口（避免误操作游戏等）
    SysGet, screenWidth, 0
    SysGet, screenHeight, 1
    if (windowInfo.width >= screenWidth && windowInfo.height >= screenHeight)
        return false

    return true
}

; 执行窗口缩放
ScaleWindow(windowInfo, scaleFactor) {
    try {
        ; 计算新尺寸
        newWidth := Round(windowInfo.width * scaleFactor)
        newHeight := Round(windowInfo.height * scaleFactor)
        
        ; 尺寸验证
        if (!ValidateNewSize(newWidth, newHeight)) {
            return false
        }
        
        ; 计算新位置（保持中心点不变）
        newX := windowInfo.x + (windowInfo.width - newWidth) // 2
        newY := windowInfo.y + (windowInfo.height - newHeight) // 2
        
        ; 确保窗口在屏幕范围内
        coords := AdjustToScreen(newX, newY, newWidth, newHeight)
        
        ; 应用新的窗口位置和大小
        WinMove, % "ahk_id " . windowInfo.hwnd,, % coords.x, % coords.y, % coords.width, % coords.height
        
        return true
        
    } catch e {
        return false
    }
}

; 验证新窗口尺寸是否有效
ValidateNewSize(width, height) {
    ; 只检查最小尺寸，最大尺寸交给 AdjustToScreen 函数处理
    if (width < g_MinWindowSize || height < g_MinWindowSize)
        return false
        
    return true
}

; 确保调整后窗口位置在屏幕内
AdjustToScreen(x, y, width, height) {
    SysGet, screenX, 76      ; SM_XVIRTUALSCREEN
    SysGet, screenY, 77      ; SM_YVIRTUALSCREEN  
    SysGet, screenWidth, 78  ; SM_CXVIRTUALSCREEN
    SysGet, screenHeight, 79 ; SM_CYVIRTUALSCREEN
    
    ; 调整X坐标
    if (x < screenX)
        x := screenX
    else if (x + width > screenX + screenWidth)
        x := screenX + screenWidth - width
    
    ; 调整Y坐标
    if (y < screenY)
        y := screenY
    else if (y + height > screenY + screenHeight)
        y := screenY + screenHeight - height
    
    return {x: x, y: y, width: width, height: height}
}
