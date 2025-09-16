#NoEnv                         ; 避免使用过时的环境变量，保持脚本行为一致
#SingleInstance Force           ; 保证脚本单实例运行，防止重复启动
SetBatchLines, -1               ; 让脚本尽可能快地执行，不做自动延迟
DetectHiddenWindows, On         ; 允许操作隐藏窗口
Menu, Tray, NoStandard           ; 禁用默认托盘菜单

; 添加右键菜单项
Menu, Tray, Add, 设置, ShowSettings   ; 设置
Menu, Tray, Add, 重启程序, RestartApp   ; 重启程序
Menu, Tray, Add, 退出程序, ExitApp   ; 退出程序

; ---------- 配置文件路径 ----------  
ConfigFile := A_ScriptDir . "\config.ini"

; ---------- 默认配置值 ----------  
DefaultInterval := 1000                 ; 刷新间隔 (毫秒)，控制网速刷新频率
DefaultGuiWidth := 120                  ; GUI 宽度
DefaultGuiHeight := 44                  ; GUI 高度
DefaultFontName := "Segoe UI Variable"  ; 字体名称
DefaultFontSize := 11                    ; 字号
DefaultFontWeight := "Bold"              ; 字体加粗
DefaultBgColorMode := "深色预设"         ; 背景色模式：浅色预设、深色预设、自定义
DefaultBgColor := "0x0B1113"            ; GUI 背景颜色（自定义时使用）
DefaultBgTransparency := 254             ; 背景透明度 (0-254，255为只显示文字)
DefaultNumRightMargin := 6               ; 数字右侧空白
DefaultArrowWidth := 24                  ; 箭头宽度
DefaultPositionCorner := "右下角"         ; 位置角落：右下角、右上角、左下角、左上角
DefaultOffsetX := 15                     ; 横向偏移
DefaultOffsetY := 10                     ; 纵向偏移
DefaultThresh1 := 50*1024                ; 很低速：50 KB/s
DefaultThresh2 := 500*1024               ; 低速：500 KB/s
DefaultThresh3 := 2*1024*1024            ; 中速：2 MB/s
DefaultColorVeryLow := "CFCFCF"          ; 灰色
DefaultColorLow := "A8D5A2"              ; 浅绿
DefaultColorMed := "7FD3D6"              ; 青色
DefaultColorHigh := "F2C08C"             ; 橙色
DefaultEnableSmoothing := true           ; 是否启用平滑处理
DefaultEMAFactor := 0.35                 ; EMA 指数平滑因子，用于平滑网速显示
DefaultConfirmNeeded := 2                ; 防抖确认次数：同一颜色连续出现多少次才真正更新
DefaultAutoRestart := false              ; 保存后自动重启不二次确认
DefaultMouseThrough := true              ; 鼠标穿透

; ---------- 读取配置文件 ----------  
LoadConfig()

; ---------- GUI 元素位置计算 ----------  
NumWidth := GuiWidth - ArrowWidth - NumRightMargin  ; 数字控件宽度
UpY := 4                                          ; 上行数字纵坐标
DownY := 22                                       ; 下行数字纵坐标
ArrowX := NumWidth                                ; 箭头横坐标

; ---------- 全局变量 ----------  
global UpNum, UpArrow, DownNum, DownArrow        ; GUI 控件变量
global emaUp := 0, emaDown := 0                 ; 上下行 EMA 平滑值
global pendingUp := "", pendingDown := ""       ; 上下行候选颜色（防抖用）
global pendingCountUp := 0, pendingCountDown := 0 ; 上下行防抖计数
global lastColorUp := "", lastColorDown := ""   ; 上下行最后应用颜色
global lastTextUp := "", lastTextDown := ""     ; 上下行最后显示文本
global recv := 0, sent := 0                     ; 当前网速值
global q, item, sSent, sRecv, candidateUp, candidateDown ; 临时变量

; ---------- 初始化 WMI 接口，用于获取网速数据 ----------  
global wmi
wmi := ""
try
{
    ; 尝试获取 Win32_PerfFormattedData_Tcpip_NetworkInterface 类的数据
    wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!//./root/cimv2")
    test := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_NetworkInterface")
}
catch e
{
    try
        ; 如果失败，尝试 TCPv4 类
        test := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_TCPv4")
    catch e2
        ; 如果仍失败，则 WMI 无法使用
        wmi := ""
}

; ---------- 创建 GUI 并显示 ----------  
CreateGuiAndShow(ColorVeryLow)

; ---------- 设置定时器，每 Interval 毫秒调用 UpdateNet ----------  
SetTimer, UpdateNet, %Interval%
Gosub, UpdateNet
Return

; ---------- 读取配置文件函数 ----------
LoadConfig()
{
    global
    
    ; 如果配置文件不存在，创建默认配置文件
    if (!FileExist(ConfigFile))
        CreateDefaultConfig()
    
    ; 读取配置值并清理格式
    IniRead, Interval, %ConfigFile%, General, Interval, %DefaultInterval%
    IniRead, AutoRestart, %ConfigFile%, General, AutoRestart, %DefaultAutoRestart%
    IniRead, MouseThrough, %configFile%, Settings, MouseThrough, %DefaultMouseThrough%
    IniRead, GuiWidth, %ConfigFile%, GUI, Width, %DefaultGuiWidth%
    IniRead, GuiHeight, %ConfigFile%, GUI, Height, %DefaultGuiHeight%
    IniRead, FontName, %ConfigFile%, GUI, FontName, %DefaultFontName%
    IniRead, FontSize, %ConfigFile%, GUI, FontSize, %DefaultFontSize%
    IniRead, FontWeight, %ConfigFile%, GUI, FontWeight, %DefaultFontWeight%
    IniRead, BgColorMode, %ConfigFile%, GUI, BgColorMode, %DefaultBgColorMode%
    IniRead, BgColor, %ConfigFile%, GUI, BgColor, %DefaultBgColor%
    IniRead, BgTransparency, %ConfigFile%, GUI, BgTransparency, %DefaultBgTransparency%
    IniRead, NumRightMargin, %ConfigFile%, GUI, NumRightMargin, %DefaultNumRightMargin%
    IniRead, ArrowWidth, %ConfigFile%, GUI, ArrowWidth, %DefaultArrowWidth%
    IniRead, PositionCorner, %ConfigFile%, Position, Corner, %DefaultPositionCorner%
    IniRead, OffsetX, %ConfigFile%, Position, OffsetX, %DefaultOffsetX%
    IniRead, OffsetY, %ConfigFile%, Position, OffsetY, %DefaultOffsetY%
    
    IniRead, Thresh1, %ConfigFile%, Thresholds, Thresh1, %DefaultThresh1%
    IniRead, Thresh2, %ConfigFile%, Thresholds, Thresh2, %DefaultThresh2%
    IniRead, Thresh3, %ConfigFile%, Thresholds, Thresh3, %DefaultThresh3%
    
    IniRead, ColorVeryLow, %ConfigFile%, Colors, VeryLow, %DefaultColorVeryLow%
    IniRead, ColorLow, %ConfigFile%, Colors, Low, %DefaultColorLow%
    IniRead, ColorMed, %ConfigFile%, Colors, Medium, %DefaultColorMed%
    IniRead, ColorHigh, %ConfigFile%, Colors, High, %DefaultColorHigh%
    
    IniRead, EnableSmoothing, %ConfigFile%, Advanced, EnableSmoothing, %DefaultEnableSmoothing%
    IniRead, EMAFactor, %ConfigFile%, Advanced, EMAFactor, %DefaultEMAFactor%
    IniRead, ConfirmNeeded, %ConfigFile%, Advanced, ConfirmNeeded, %DefaultConfirmNeeded%
    
    ; 清理数值中的逗号和空格，确保为纯数字
    Interval := RegExReplace(Interval, "[,\s]", "")
    GuiWidth := RegExReplace(GuiWidth, "[,\s]", "")
    GuiHeight := RegExReplace(GuiHeight, "[,\s]", "")
    FontSize := RegExReplace(FontSize, "[,\s]", "")
    BgTransparency := RegExReplace(BgTransparency, "[,\s]", "")
    NumRightMargin := RegExReplace(NumRightMargin, "[,\s]", "")
    ArrowWidth := RegExReplace(ArrowWidth, "[,\s]", "")
    OffsetX := RegExReplace(OffsetX, "[,\s]", "")
    OffsetY := RegExReplace(OffsetY, "[,\s]", "")
    Thresh1 := RegExReplace(Thresh1, "[,\s]", "")
    Thresh2 := RegExReplace(Thresh2, "[,\s]", "")
    Thresh3 := RegExReplace(Thresh3, "[,\s]", "")
    ConfirmNeeded := RegExReplace(ConfirmNeeded, "[,\s]", "")
    
    ; 验证和修正数值范围
    if (Interval < 100 || Interval > 5000)
        Interval := DefaultInterval
    if (GuiWidth < 80 || GuiWidth > 300)
        GuiWidth := DefaultGuiWidth
    if (GuiHeight < 30 || GuiHeight > 100)
        GuiHeight := DefaultGuiHeight
    if (FontSize < 8 || FontSize > 24)
        FontSize := DefaultFontSize
    if (BgTransparency < 0 || BgTransparency > 255)
        BgTransparency := DefaultBgTransparency
    
    ; 处理背景色预设
    if (BgColorMode = "浅色预设")
        BgColor := "0xF5F5F5"
    else if (BgColorMode = "深色预设")
        BgColor := "0x0B1113"
    ; 自定义模式直接使用配置中的BgColor值
    
    ; 性能优化：如果不启用平滑，将EMAFactor设为1，这样EMA计算等同于直接赋值，无需额外判断
    if (!EnableSmoothing)
        EMAFactor := 1.0
}

; ---------- 创建默认配置文件 ----------
CreateDefaultConfig()
{
    global
    
    ; 写入默认配置
    IniWrite, %DefaultInterval%, %ConfigFile%, General, Interval
    IniWrite, %DefaultAutoRestart%, %ConfigFile%, General, AutoRestart
    IniWrite, %DefaultMouseThrough%, %configFile%, Settings, MouseThrough
    IniWrite, %DefaultGuiWidth%, %ConfigFile%, GUI, Width
    IniWrite, %DefaultGuiHeight%, %ConfigFile%, GUI, Height
    IniWrite, %DefaultFontName%, %ConfigFile%, GUI, FontName
    IniWrite, %DefaultFontSize%, %ConfigFile%, GUI, FontSize
    IniWrite, %DefaultFontWeight%, %ConfigFile%, GUI, FontWeight
    IniWrite, %DefaultBgColorMode%, %ConfigFile%, GUI, BgColorMode
    IniWrite, %DefaultBgColor%, %ConfigFile%, GUI, BgColor
    IniWrite, %DefaultBgTransparency%, %ConfigFile%, GUI, BgTransparency
    IniWrite, %DefaultNumRightMargin%, %ConfigFile%, GUI, NumRightMargin
    IniWrite, %DefaultArrowWidth%, %ConfigFile%, GUI, ArrowWidth
    IniWrite, %DefaultPositionCorner%, %ConfigFile%, Position, Corner
    IniWrite, %DefaultOffsetX%, %ConfigFile%, Position, OffsetX
    IniWrite, %DefaultOffsetY%, %ConfigFile%, Position, OffsetY
    
    IniWrite, %DefaultThresh1%, %ConfigFile%, Thresholds, Thresh1
    IniWrite, %DefaultThresh2%, %ConfigFile%, Thresholds, Thresh2
    IniWrite, %DefaultThresh3%, %ConfigFile%, Thresholds, Thresh3
    
    IniWrite, %DefaultColorVeryLow%, %ConfigFile%, Colors, VeryLow
    IniWrite, %DefaultColorLow%, %ConfigFile%, Colors, Low
    IniWrite, %DefaultColorMed%, %ConfigFile%, Colors, Medium
    IniWrite, %DefaultColorHigh%, %ConfigFile%, Colors, High
    
    IniWrite, %DefaultEnableSmoothing%, %ConfigFile%, Advanced, EnableSmoothing
    IniWrite, %DefaultEMAFactor%, %ConfigFile%, Advanced, EMAFactor
    IniWrite, %DefaultConfirmNeeded%, %ConfigFile%, Advanced, ConfirmNeeded
}

; ---------- 显示设置窗口 ----------
ShowSettings:
    ; 销毁旧的设置窗口（如果存在）
    Gui, Settings: Destroy
    
    ; 创建设置窗口
    Gui, Settings: Add, Tab3,, 常规|界面|位置|网速阈值|颜色|高级
    
    ; 常规选项卡
    Gui, Settings: Tab, 常规
    Gui, Settings: Add, Text, x20 y40, 刷新间隔 (毫秒):
    Gui, Settings: Add, Edit, x140 y36 w80 vInterval, %Interval%
    Gui, Settings: Add, UpDown, vIntervalUD Range100-5000, %Interval%
    
    Gui, Settings: Add, Checkbox, x20 y70 vAutoRestart, 保存后重启不二次确认
    GuiControl, Settings:, AutoRestart, %AutoRestart%

    Gui, Settings: Add, Checkbox, x20 y100 vMouseThrough Checked%MouseThrough%, 鼠标穿透
    GuiControl, Settings:, MouseThrough, %MouseThrough%
    
    ; 界面选项卡
    Gui, Settings: Tab, 界面
    Gui, Settings: Add, Text, x20 y40, 窗口宽度:
    Gui, Settings: Add, Edit, x100 y36 w50 vGuiWidth, %GuiWidth%
    Gui, Settings: Add, UpDown, vGuiWidthUD Range80-300, %GuiWidth%
    Gui, Settings: Add, Text, x180 y40, 窗口高度:
    Gui, Settings: Add, Edit, x250 y36 w50 vGuiHeight, %GuiHeight%
    Gui, Settings: Add, UpDown, vGuiHeightUD Range30-100, %GuiHeight%
    
    Gui, Settings: Add, Text, x20 y70, 字体名称:
    Gui, Settings: Add, Edit, x100 y66 w120 vFontName, %FontName%
    Gui, Settings: Add, Text, x240 y70, 字号:
    Gui, Settings: Add, Edit, x270 y66 w30 vFontSize, %FontSize%
    Gui, Settings: Add, UpDown, vFontSizeUD Range8-24, %FontSize%
    
    Gui, Settings: Add, Text, x20 y100, 字体粗细:
    Gui, Settings: Add, DropDownList, x100 y96 w80 vFontWeight, Normal|Bold||
    GuiControl, Settings: Choose, FontWeight, % (FontWeight = "Bold") ? 2 : 1
    
    Gui, Settings: Add, Text, x20 y130, 背景色模式:
    Gui, Settings: Add, DropDownList, x100 y126 w100 gBgColorModeChange vBgColorMode, 浅色预设|深色预设|自定义||
    GuiControl, Settings: Choose, BgColorMode, % (BgColorMode = "浅色预设") ? 1 : (BgColorMode = "深色预设") ? 2 : 3
    
    Gui, Settings: Add, Text, x220 y130, 自定义背景色:
    Gui, Settings: Add, Edit, x320 y126 w80 vBgColor, %BgColor%
    
    Gui, Settings: Add, Text, x20 y160, 背景透明度 (0-255):
    Gui, Settings: Add, Edit, x150 y156 w50 vBgTransparency, %BgTransparency%
    Gui, Settings: Add, UpDown, vBgTransparencyUD Range0-255, %BgTransparency%
    Gui, Settings: Add, Text, x210 y160, (0=完全透明，254=不透明，255=只显示文字)
    
    ; 根据当前模式启用/禁用自定义背景色输入框
    if (BgColorMode != "自定义")
        GuiControl, Settings: Disable, BgColor
    
    ; 位置选项卡
    Gui, Settings: Tab, 位置
    Gui, Settings: Add, Text, x20 y40, 位置角落:
    Gui, Settings: Add, DropDownList, x100 y36 w100 vPositionCorner, 右下角|右上角|左下角|左上角||
    GuiControl, Settings: Choose, PositionCorner, % (PositionCorner = "右下角") ? 1 : (PositionCorner = "右上角") ? 2 : (PositionCorner = "左下角") ? 3 : 4
    
    Gui, Settings: Add, Text, x20 y70, 横向偏移:
    Gui, Settings: Add, Edit, x150 y66 w50 vOffsetX, %OffsetX%
    Gui, Settings: Add, UpDown, vOffsetXUD Range-200-200, %OffsetX%
    Gui, Settings: Add, Text, x210 y70, (正数向右，负数向左)
    
    Gui, Settings: Add, Text, x20 y100, 纵向偏移:
    Gui, Settings: Add, Edit, x150 y96 w50 vOffsetY, %OffsetY%
    Gui, Settings: Add, UpDown, vOffsetYUD Range-200-200, %OffsetY%
    Gui, Settings: Add, Text, x210 y100, (正数向上，负数向下)
    
    ; 网速阈值选项卡
    Gui, Settings: Tab, 网速阈值
    Gui, Settings: Add, Text, x20 y40, 很低速阈值 (KB/s):
    Gui, Settings: Add, Edit, x150 y36 w60 vThresh1KB, % Round(Thresh1/1024)
    Gui, Settings: Add, UpDown, vThresh1KBUD Range1-1000, % Round(Thresh1/1024)
    
    Gui, Settings: Add, Text, x20 y70, 低速阈值 (KB/s):
    Gui, Settings: Add, Edit, x150 y66 w60 vThresh2KB, % Round(Thresh2/1024)
    Gui, Settings: Add, UpDown, vThresh2KBUD Range1-5000, % Round(Thresh2/1024)
    
    Gui, Settings: Add, Text, x20 y100, 中速阈值 (MB/s):
    Gui, Settings: Add, Edit, x150 y96 w60 vThresh3MB, % Round(Thresh3/1024/1024)
    Gui, Settings: Add, UpDown, vThresh3MBUD Range1-100, % Round(Thresh3/1024/1024)
    
    ; 颜色选项卡
    Gui, Settings: Tab, 颜色
    Gui, Settings: Add, Text, x20 y40, 很低速颜色:
    Gui, Settings: Add, Edit, x120 y36 w80 vColorVeryLow, %ColorVeryLow%
    
    Gui, Settings: Add, Text, x20 y70, 低速颜色:
    Gui, Settings: Add, Edit, x120 y66 w80 vColorLow, %ColorLow%
    
    Gui, Settings: Add, Text, x20 y100, 中速颜色:
    Gui, Settings: Add, Edit, x120 y96 w80 vColorMed, %ColorMed%
    
    Gui, Settings: Add, Text, x20 y130, 高速颜色:
    Gui, Settings: Add, Edit, x120 y126 w80 vColorHigh, %ColorHigh%
    
    ; 高级选项卡
    Gui, Settings: Tab, 高级
    Gui, Settings: Add, Checkbox, x20 y40 vEnableSmoothing, 启用平滑处理
    GuiControl, Settings:, EnableSmoothing, %EnableSmoothing%
    
    Gui, Settings: Add, Text, x20 y70, EMA 平滑因子 (0-1):
    Gui, Settings: Add, Edit, x150 y66 w80 vEMAFactor, %EMAFactor%
    
    Gui, Settings: Add, Text, x20 y100, 防抖确认次数:
    Gui, Settings: Add, Edit, x150 y96 w50 vConfirmNeeded, %ConfirmNeeded%
    Gui, Settings: Add, UpDown, vConfirmNeededUD Range1-10, %ConfirmNeeded%
    
    ; 按钮
    Gui, Settings: Tab
    Gui, Settings: Add, Button, x200 y270 w60 h30 gSaveSettings, 保存
    Gui, Settings: Add, Button, x270 y270 w60 h30 gCloseSettings, 取消
    Gui, Settings: Add, Button, x340 y270 w80 h30 gResetSettings, 恢复默认
    
    ; 显示设置窗口
    Gui, Settings: Show, w450 h320, 网速监控设置
Return

; ---------- 背景色模式变化处理 ----------
BgColorModeChange:
    Gui, Settings: Submit, NoHide
    if (BgColorMode = "自定义")
        GuiControl, Settings: Enable, BgColor
    else
        GuiControl, Settings: Disable, BgColor
Return

; ---------- 保存设置 ----------
SaveSettings:
    Gui, Settings: Submit
    
    ; 清理数值中的逗号和空格，确保为纯数字
    Interval := RegExReplace(Interval, "[,\s]", "")
    GuiWidth := RegExReplace(GuiWidth, "[,\s]", "")
    GuiHeight := RegExReplace(GuiHeight, "[,\s]", "")
    FontSize := RegExReplace(FontSize, "[,\s]", "")
    BgTransparency := RegExReplace(BgTransparency, "[,\s]", "")
    OffsetX := RegExReplace(OffsetX, "[,\s]", "")
    OffsetY := RegExReplace(OffsetY, "[,\s]", "")
    Thresh1KB := RegExReplace(Thresh1KB, "[,\s]", "")
    Thresh2KB := RegExReplace(Thresh2KB, "[,\s]", "")
    Thresh3MB := RegExReplace(Thresh3MB, "[,\s]", "")
    ConfirmNeeded := RegExReplace(ConfirmNeeded, "[,\s]", "")
    
    ; 验证数值范围并设置默认值
    if (Interval < 100 || Interval > 5000)
        Interval := 1000
    if (GuiWidth < 80 || GuiWidth > 300)
        GuiWidth := 120
    if (GuiHeight < 30 || GuiHeight > 100)
        GuiHeight := 44
    if (FontSize < 8 || FontSize > 24)
        FontSize := 11
    if (BgTransparency < 0 || BgTransparency > 255)
        BgTransparency := 255
    if (Thresh1KB < 1 || Thresh1KB > 1000)
        Thresh1KB := 50
    if (Thresh2KB < 1 || Thresh2KB > 5000)
        Thresh2KB := 500
    if (Thresh3MB < 1 || Thresh3MB > 100)
        Thresh3MB := 2
    if (ConfirmNeeded < 1 || ConfirmNeeded > 10)
        ConfirmNeeded := 2
    
    ; 保存到配置文件
    IniWrite, %Interval%, %ConfigFile%, General, Interval
    IniWrite, %AutoRestart%, %ConfigFile%, General, AutoRestart
    IniWrite, %MouseThrough%, %configFile%, Settings, MouseThrough
    IniWrite, %GuiWidth%, %ConfigFile%, GUI, Width
    IniWrite, %GuiHeight%, %ConfigFile%, GUI, Height
    IniWrite, %FontName%, %ConfigFile%, GUI, FontName
    IniWrite, %FontSize%, %ConfigFile%, GUI, FontSize
    IniWrite, %FontWeight%, %ConfigFile%, GUI, FontWeight
    IniWrite, %BgColorMode%, %ConfigFile%, GUI, BgColorMode
    IniWrite, %BgColor%, %ConfigFile%, GUI, BgColor
    IniWrite, %BgTransparency%, %ConfigFile%, GUI, BgTransparency
    IniWrite, %PositionCorner%, %ConfigFile%, Position, Corner
    IniWrite, %OffsetX%, %ConfigFile%, Position, OffsetX
    IniWrite, %OffsetY%, %ConfigFile%, Position, OffsetY
    
    ; 转换阈值单位并保存
    IniWrite, % Thresh1KB*1024, %ConfigFile%, Thresholds, Thresh1
    IniWrite, % Thresh2KB*1024, %ConfigFile%, Thresholds, Thresh2
    IniWrite, % Thresh3MB*1024*1024, %ConfigFile%, Thresholds, Thresh3
    
    IniWrite, %ColorVeryLow%, %ConfigFile%, Colors, VeryLow
    IniWrite, %ColorLow%, %ConfigFile%, Colors, Low
    IniWrite, %ColorMed%, %ConfigFile%, Colors, Medium
    IniWrite, %ColorHigh%, %ConfigFile%, Colors, High
    
    IniWrite, %EnableSmoothing%, %ConfigFile%, Advanced, EnableSmoothing
    IniWrite, %EMAFactor%, %ConfigFile%, Advanced, EMAFactor
    IniWrite, %ConfirmNeeded%, %ConfigFile%, Advanced, ConfirmNeeded
    
    ; 根据AutoRestart设置决定是否确认重启
    if (AutoRestart)
    {
        Reload
    }
    else
    {
        MsgBox, 4, 设置已保存, 设置已保存！需要重启程序以应用新设置。是否现在重启？
        IfMsgBox Yes
        {
            Reload
        }
    }
Return

; ---------- 关闭设置窗口 ----------
CloseSettings:
    Gui, Settings: Destroy
Return

; ---------- 重置为默认设置 ----------
ResetSettings:
    MsgBox, 4, 确认重置, 确定要重置所有设置为默认值吗？
    IfMsgBox Yes
    {
        FileDelete, %ConfigFile%
        CreateDefaultConfig()
        Gui, Settings: Destroy
        MsgBox, 设置已重置为默认值！请重启程序以应用新设置。
    }
Return

; ---------- 设置窗口关闭事件 ----------
SettingsGuiClose:
    Gui, Settings: Destroy
Return

; ---------- 定时更新函数 ----------  
UpdateNet:
    ; 重置每次循环的累加值和临时变量
    recv := 0
    sent := 0
    sSent := ""
    sRecv := ""
    candidateUp := ""
    candidateDown := ""

    ; --- 获取网速 ---
    if (wmi)
    {
        try
        {
            ; 查询网络接口
            q := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_NetworkInterface")
            if (!q.Count)
                ; 若无数据，尝试 TCPv4
                q := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_TCPv4")
            for item in q
            {
                ; 累加每个接口的上传下载
                recv := recv + (item.BytesReceivedPersec ? item.BytesReceivedPersec : 0)
                sent := sent + (item.BytesSentPersec ? item.BytesSentPersec : 0)
            }
        }
        catch e
        {
            ; 获取失败则置 0
            recv := 0
            sent := 0
        }
    }

    ; --- EMA 平滑处理（性能优化：EMAFactor为1时等同于直接赋值，无需额外判断） ---
    if (emaUp = 0)
        emaUp := sent
    else
        emaUp := emaUp*(1-EMAFactor) + sent*EMAFactor

    if (emaDown = 0)
        emaDown := recv
    else
        emaDown := emaDown*(1-EMAFactor) + recv*EMAFactor

    ; --- 根据 EMA 值决定候选颜色 ---
    candidateUp := GetColorBySpeed(emaUp)
    candidateDown := GetColorBySpeed(emaDown)

    ; --- 防抖处理：只有连续 ConfirmNeeded 次候选颜色一致，才真正改变显示颜色 ---
    if (candidateUp = pendingUp)
        pendingCountUp := pendingCountUp + 1
    else
    {
        pendingUp := candidateUp
        pendingCountUp := 1
    }
    if (pendingCountUp >= ConfirmNeeded && pendingUp != lastColorUp)
    {
        lastColorUp := pendingUp
        pendingCountUp := 0
    }

    if (candidateDown = pendingDown)
        pendingCountDown := pendingCountDown + 1
    else
    {
        pendingDown := candidateDown
        pendingCountDown := 1
    }
    if (pendingCountDown >= ConfirmNeeded && pendingDown != lastColorDown)
    {
        lastColorDown := pendingDown
        pendingCountDown := 0
    }

    ; --- 格式化文本为带单位字符串 ---
    sSent := FormatSpeed(emaUp)
    sRecv := FormatSpeed(emaDown)

    ; --- 仅在变化时刷新 GUI 文本，减少重绘 ---
    if (sSent != lastTextUp)
    {
        GuiControl,, UpNum, %sSent%
        lastTextUp := sSent
    }
    if (sRecv != lastTextDown)
    {
        GuiControl,, DownNum, %sRecv%
        lastTextDown := sRecv
    }

    ; --- 刷新颜色 ---
    GuiControl, +c%lastColorUp%, UpNum
    GuiControl, +c%lastColorUp%, UpArrow
    GuiControl, +c%lastColorDown%, DownNum
    GuiControl, +c%lastColorDown%, DownArrow
Return

; ---------- 根据速度获取对应颜色 ----------
GetColorBySpeed(val)
{
    global Thresh1, Thresh2, Thresh3
    global ColorVeryLow, ColorLow, ColorMed, ColorHigh

    if (val < Thresh1)
        return ColorVeryLow
    else if (val < Thresh2)
        return ColorLow
    else if (val < Thresh3)
        return ColorMed
    else
        return ColorHigh
}

; ---------- 创建 GUI 并显示 ----------
CreateGuiAndShow(hexColor)
{
    global GuiWidth, GuiHeight, FontName, FontSize, FontWeight
    global NumWidth, ArrowWidth, UpY, DownY, ArrowX, BgColor, BgTransparency
    global UpNum, UpArrow, DownNum, DownArrow
    global hGui  ; 保存当前 GUI 句柄
    global MouseThrough  ; 鼠标穿透设置

    ; 获取句柄（替代 +LastFound）
    Gui, +AlwaysOnTop -Caption +ToolWindow +HwndhGui
    Gui, Margin, 0,0
    Gui, Font, s%FontSize% %FontWeight%, %FontName%

    ; 添加控件（文字透明）
    Gui, Add, Text, x0 y%UpY% w%NumWidth% vUpNum   Right  c%hexColor% BackgroundTrans, 初始化...
    Gui, Add, Text, x%ArrowX% y%UpY% w%ArrowWidth% vUpArrow  Center c%hexColor% BackgroundTrans, ↑
    Gui, Add, Text, x0 y%DownY% w%NumWidth% vDownNum Right  c%hexColor% BackgroundTrans, 初始化...
    Gui, Add, Text, x%ArrowX% y%DownY% w%ArrowWidth% vDownArrow Center c%hexColor% BackgroundTrans, ↓

    Gui, Color, %BgColor%

    ; 显示并定位
    PositionGui()

    ; 应用背景透明策略
    ApplyGuiTransparency()

    ; 应用鼠标穿透
    if (MouseThrough)
        WinSet, ExStyle, +0x20, ahk_id %hGui%
    else
        WinSet, ExStyle, -0x20, ahk_id %hGui%
}

ApplyGuiTransparency()
{
    global hGui, BgColor, BgTransparency

    if (BgTransparency = 255) {
        ; 方案A：挖空背景，只显示文字（推荐用于“纯透明背景”）
        WinSet, Transparent, Off,            ahk_id %hGui%
        WinSet, TransColor, %BgColor% 255,   ahk_id %hGui%
    } else {
        ; 方案B：整窗半透明（含文字），用于做“半透明卡片”效果
        WinSet, TransColor, Off,             ahk_id %hGui%
        WinSet, Transparent, %BgTransparency%, ahk_id %hGui%
    }
}

; ---------- 根据配置定位GUI ----------
PositionGui()
{
    global GuiWidth, GuiHeight, PositionCorner, OffsetX, OffsetY
    
    ; 获取屏幕工作区大小
    SysGet, screenW, 78
    SysGet, screenH, 79
    
    ; 根据角落位置计算基础坐标 - 修正偏移逻辑
    if (PositionCorner = "右下角")
    {
        baseX := screenW - GuiWidth
        baseY := screenH - GuiHeight
        x := baseX - OffsetX  ; 横向：正数向右偏移变为负数向左偏移
        y := baseY - OffsetY  ; 纵向：正数向上偏移变为负数向下偏移
    }
    else if (PositionCorner = "右上角")
    {
        baseX := screenW - GuiWidth
        baseY := 0
        x := baseX - OffsetX  ; 横向：正数向右偏移变为负数向左偏移
        y := baseY + OffsetY  ; 纵向：正数向上偏移
    }
    else if (PositionCorner = "左下角")
    {
        baseX := 0
        baseY := screenH - GuiHeight
        x := baseX + OffsetX  ; 横向：正数向右偏移
        y := baseY - OffsetY  ; 纵向：正数向上偏移变为负数向下偏移
    }
    else ; 左上角
    {
        baseX := 0
        baseY := 0
        x := baseX + OffsetX  ; 横向：正数向右偏移
        y := baseY + OffsetY  ; 纵向：正数向上偏移
    }
    
    ; 显示GUI
    Gui, Show, x%x% y%y% w%GuiWidth% h%GuiHeight% NoActivate
}

; ---------- 格式化网速，带单位 ----------
FormatSpeed(val)
{
    if (val >= 1048576) ; 大于 1MB/s
        return Round(val/1048576, 2) . " MB/s"
    else if (val >= 1024) ; 大于 1KB/s
        return Round(val/1024, 1) . " KB/s"
    else
        return Round(val, 0) . " B/s"
}

; ---------- 重启脚本函数 ----------
RestartApp:
    Reload  ; 重启当前脚本
Return

; ---------- 退出脚本 ----------
ExitApp:
    ExitApp
Return