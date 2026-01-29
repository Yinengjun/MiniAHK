#NoEnv                          ; 避免使用过时的环境变量，保持脚本行为一致
#SingleInstance Force           ; 保证脚本单实例运行，防止重复启动
SetBatchLines, -1               ; 让脚本尽可能快地执行，不做自动延迟
DetectHiddenWindows, On         ; 允许操作隐藏窗口
Menu, Tray, NoStandard          ; 禁用默认托盘菜单，使用自定义项

; ---------- 托盘菜单（右键菜单项） ----------
Menu, Tray, Add, 设置, ShowSettings
Menu, Tray, Add, 关于, ShowAbout
Menu, Tray, Add 
Menu, Tray, Add, 重启程序, RestartApp
Menu, Tray, Add, 退出程序, ExitApp

; ---------- 配置文件路径（单一中央配置） ----------
ConfigFile := A_ScriptDir . "\config.ini"

; ------------------------- 默认配置值 -------------------------
DefaultInterval := 1000                  ; 刷新间隔 (毫秒)，控制网速刷新频率
DefaultGuiWidth := 120                   ; GUI 宽度（像素）
DefaultGuiHeight := 44                   ; GUI 高度（像素）
DefaultFontName := "Segoe UI Variable"   ; 字体名称
DefaultFontSize := 11                    ; 字号
DefaultFontWeight := "Bold"              ; 字体加粗（字符串，用于 Gui, Font）
DefaultBgColorMode := "深色预设"          ; 背景色模式：浅色预设、深色预设、自定义
DefaultBgColor := "0x0B1113"             ; GUI 背景颜色（自定义时使用，0xRRGGBB）
DefaultOnlyText := false                 ; 是否只显示文字（与透明度互斥）
DefaultBgTransparency := 255             ; 背景透明度 (0-255，255为不透明)
DefaultNumRightMargin := 6               ; 数字右侧空白（像素）
DefaultArrowWidth := 24                  ; 箭头宽度（像素）
DefaultPositionCorner := "右下角"         ; 位置角落：右下角、右上角、左下角、左上角
DefaultOffsetX := 15                     ; 横向偏移（像素）
DefaultOffsetY := 10                     ; 纵向偏移（像素）
DefaultLimitOffset := true               ; 限制偏离量设置
DefaultThresh1 := 50*1024                ; 很低速阈值（50 KB/s）
DefaultThresh2 := 500*1024               ; 低速阈值（500 KB/s）
DefaultThresh3 := 2*1024*1024            ; 中速阈值（2 MB/s）
DefaultColorVeryLow := "CFCFCF"          ; 很低速颜色 灰色（6位16进制，BGR或RGB视处理）
DefaultColorLow := "A8D5A2"              ; 低速颜色 浅绿
DefaultColorMed := "7FD3D6"              ; 中速颜色 青色
DefaultColorHigh := "F2C08C"             ; 高速颜色 橙色
DefaultEnableSmoothing := true           ; 是否启用平滑处理（EMA）
DefaultEMAFactor := 0.35                 ; EMA 指数平滑因子，用于平滑网速显示
DefaultConfirmNeeded := 2                ; 防抖确认次数：同一颜色连续出现多少次才真正更新
DefaultAutoRestart := false              ; 保存后自动重启无需二次确认
DefaultMouseThrough := true              ; 鼠标穿透（窗口是否允许鼠标穿透）
DefaultDisplayTarget := "主屏幕"         ; 显示器（主屏幕/显示器N/全部）
DefaultEnsureTopmost := false            ; 是否开启确保置顶的定时重申
DefaultTopmostReassertMin := 10           ; 重申置顶周期，单位：分钟（默认为 10 分钟）

; ---------- 读取配置文件 ----------
LoadConfig()

; ------------------------- GUI 元素位置计算（依赖已加载的配置） -------------------------
NumWidth := GuiWidth - ArrowWidth - NumRightMargin  ; 数字控件宽度计算
UpY := 4                                            ; 上行数字纵坐标（像素）
DownY := 22                                         ; 下行数字纵坐标（像素）
ArrowX := NumWidth                                  ; 箭头横坐标（放在数字右侧）

; ------------------------- 全局变量 -------------------------
global UpNum, UpArrow, DownNum, DownArrow        ; GUI 控件变量（句柄名）

global emaUp := 0, emaDown := 0                   ; 上下行 EMA 平滑值（初始 0）

global pendingUp := "", pendingDown := ""         ; 上下行候选颜色（用于防抖）

global pendingCountUp := 0, pendingCountDown := 0 ; 上下行防抖计数器

global lastColorUp := "", lastColorDown := ""     ; 上下行最后应用颜色（实际显示）

global lastTextUp := "", lastTextDown := ""       ; 上下行最后显示文本（用于减少重绘）

global recv := 0, sent := 0                       ; 当前网速瞬时值（累加每接口）

global q, item, sSent, sRecv, candidateUp, candidateDown ; 临时变量与候选色
global Display                                   ; 目标显示器文本（主屏幕/显示器N/全部）
global hGui                                      ; GUI 窗口句柄
global LimitOffset                               ; 限制偏离量设置

; ---------- 取色器相关全局 ----------
global PickerActive := false
global CurrentPickTarget := ""
global CurrentPickFmt := ""
global hPicker := 0
global PickerLastRGB := "FFFFFF"
global PickerLastBGR := "FFFFFF"
; 这些控件变量在函数中创建，必须声明为全局，避免“control's variable must be global or static”错误
global PickPrev

; ------------------------- 初始化 WMI 接口（用于获取网速数据） -------------------------
global wmi, WmiWarned
WmiWarned := false
wmi := ""   ; 默认空
try
{
    ; 尝试获取 Win32_PerfFormattedData_Tcpip_NetworkInterface 类的数据
    wmi := ComObjGet("winmgmts:{impersonationLevel=impersonate}!//./root/cimv2")
    test := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_NetworkInterface")
}
catch e
{
    try
    {
        ; 如果第一个查询失败，尝试备用类（TCPv4）
        test := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_TCPv4")
    }
    catch e2
    {
        ; 若仍失败，将 wmi 置空以指示不可用
        wmi := ""
    }
}
if (!wmi && !WmiWarned)
{
    WmiWarned := true
    TrayTip, 网速监控, WMI 接口不可用，速度显示可能为 0。可尝试以管理员运行或重启系统。, 5, 1
}

; ------------------------- 创建并显示 GUI -------------------------
CreateGuiAndShow(ColorVeryLow)

; ------------------------- 设置定时器：每 Interval 毫秒调用 UpdateNet -------------------------
SetTimer, UpdateNet, %Interval%
Gosub, UpdateNet   ; 立即执行一次更新

SetTimer, ReassertTopmost, % (EnsureTopmost ? TopmostReassertMin*60000 : 0)

Return              ; 脚本主流程到此挂起，等待事件与定时器

; ========================= 函数 / 子程序定义区 =========================

; ---------- 读取配置文件函数（加载或创建默认配置） ----------
LoadConfig()
{
    global
    
    ; 如果配置文件不存在，创建默认配置文件并写入默认配置
    if (!FileExist(ConfigFile))
        CreateDefaultConfig()
    
    ; 读取配置值并清理格式（优先从配置文件加载，若无则使用 Default* 变量）
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
    IniRead, OnlyText, %ConfigFile%, GUI, OnlyText, %DefaultOnlyText%
    IniRead, BgTransparency, %ConfigFile%, GUI, BgTransparency, %DefaultBgTransparency%
    IniRead, NumRightMargin, %ConfigFile%, GUI, NumRightMargin, %DefaultNumRightMargin%
    IniRead, ArrowWidth, %ConfigFile%, GUI, ArrowWidth, %DefaultArrowWidth%
    IniRead, PositionCorner, %ConfigFile%, Position, Corner, %DefaultPositionCorner%
    IniRead, OffsetX, %ConfigFile%, Position, OffsetX, %DefaultOffsetX%
    IniRead, OffsetY, %ConfigFile%, Position, OffsetY, %DefaultOffsetY%
    IniRead, Display, %ConfigFile%, GUI, Display, %DefaultDisplayTarget%
    IniRead, LimitOffset, %ConfigFile%, Position, LimitOffset, %DefaultLimitOffset%
    
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

    IniRead, EnsureTopmost, %ConfigFile%, Advanced, EnsureTopmost, %DefaultEnsureTopmost%
    IniRead, TopmostReassertMin, %ConfigFile%, Advanced, TopmostReassertMin, %DefaultTopmostReassertMin%

    ; 清理数值中的逗号和空格，确保为纯数字，防止后续运算出错
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
    TopmostReassertMin := RegExReplace(TopmostReassertMin, "[^\d]", "")

    ; 验证和修正数值范围，避免用户或配置文件写入异常值导致界面错位或定时器过快
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
    if (TopmostReassertMin < 1 || TopmostReassertMin > 60)
        TopmostReassertMin := DefaultTopmostReassertMin

    ; 处理背景色预设：若为浅/深预设则覆盖 BgColor
    if (BgColorMode = "浅色预设")
        BgColor := "0xF5F5F5"
    else if (BgColorMode = "深色预设")
        BgColor := "0x0B1113"
    ; 自定义模式直接使用配置中的BgColor值
    
    ; 性能优化：如果不启用平滑，将EMAFactor设为1，这样EMA计算等同于直接赋值，无需额外判断
    if (!EnableSmoothing)
        EMAFactor := 1.0
}

; ---------- 创建默认配置文件（首次运行或重置时使用） ----------
CreateDefaultConfig()
{
    global
    
    ; 将 Default* 写入配置文件，初始化所有节
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
    IniWrite, %DefaultOnlyText%, %ConfigFile%, GUI, OnlyText
    IniWrite, %DefaultBgTransparency%, %ConfigFile%, GUI, BgTransparency
    IniWrite, %DefaultNumRightMargin%, %ConfigFile%, GUI, NumRightMargin
    IniWrite, %DefaultArrowWidth%, %ConfigFile%, GUI, ArrowWidth
    IniWrite, %DefaultPositionCorner%, %ConfigFile%, Position, Corner
    IniWrite, %DefaultOffsetX%, %ConfigFile%, Position, OffsetX
    IniWrite, %DefaultOffsetY%, %ConfigFile%, Position, OffsetY
    IniWrite, %DefaultDisplayTarget%, %ConfigFile%, GUI, Display
    IniWrite, %DefaultLimitOffset%, %ConfigFile%, Position, LimitOffset
    
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

    IniWrite, %DefaultEnsureTopmost%, %ConfigFile%, Advanced, EnsureTopmost
    IniWrite, %DefaultTopmostReassertMin%, %ConfigFile%, Advanced, TopmostReassertMin
}

; ========================= 设置界面（设置窗口） =========================

; ---------- 显示设置窗口（由托盘菜单或其它触发） ----------
ShowSettings:
    ; 销毁旧的设置窗口（如果存在），防止重复创建
    Gui, Settings: Destroy
    
    ; 创建设置窗口，使用 Tab3 控件分组（常规|界面|位置|网速阈值|颜色|高级）
    Gui, Settings: Add, Tab3,, 常规|界面|位置|网速阈值|颜色|高级
    
    ; 常规选项卡
    Gui, Settings: Tab, 常规
    Gui, Settings: Add, Text, x20 y40, 刷新间隔 (毫秒):
    IntervalClean := RegExReplace(Interval, "[^\d-]", "") ; 去掉千分位/空白等
    if (IntervalClean = "")
        IntervalClean := 1000
    Gui, Settings: Add, Edit, x140 y36 w80 vInterval +Number, %IntervalClean%
    Gui, Settings: Add, UpDown, vIntervalUD Range100-5000 +0x80, %IntervalClean% ; +0x80=UDS_NOTHOUSANDS
    
    Gui, Settings: Add, Checkbox, x20 y70 vAutoRestart, 保存后重启不二次确认
    GuiControl, Settings:, AutoRestart, %AutoRestart%

    Gui, Settings: Add, Checkbox, x20 y100 vMouseThrough Checked%MouseThrough%, 鼠标穿透
    GuiControl, Settings:, MouseThrough, %MouseThrough%

    Gui, Settings: Add, Checkbox, x20 y130 vEnsureTopmost gEnsureTopmostChanged, 确保置顶
    Gui, Settings: Add, Text, x220 y128, 重申周期（分钟）:
    Gui, Settings: Add, Edit, x340 y124 w60 vTopmostReassertMin +Number, %TopmostReassertMin%
    Gui, Settings: Add, UpDown, vTopmostReassertMinUD Range1-1440, %TopmostReassertMin%

    GuiControl, Settings:, EnsureTopmost, %EnsureTopmost%
    if (!EnsureTopmost)
    {
        GuiControl, Settings: Disable, TopmostReassertMin
        GuiControl, Settings: Disable, TopmostReassertMinUD
    }
    
    ; 界面选项卡
    Gui, Settings: Tab, 界面
    Gui, Settings: Add, Text, x20 y40, 窗口宽度:
    Gui, Settings: Add, Edit, x100 y36 w50 vGuiWidth, %GuiWidth%
    Gui, Settings: Add, UpDown, vGuiWidthUD Range80-300, %GuiWidth%
    Gui, Settings: Add, Text, x180 y40, 窗口高度:
    Gui, Settings: Add, Edit, x250 y36 w50 vGuiHeight, %GuiHeight%
    Gui, Settings: Add, UpDown, vGuiHeightUD Range30-100, %GuiHeight%
    
    Gui, Settings: Add, Text, x20 y70, 字体名称:
    ; 字体预设列表，方便用户选择常用字体或自定义
    fontPresetList := "Segoe UI Variable|Segoe UI|Microsoft YaHei|Consolas|Cascadia Mono|Cascadia Code|Sarasa Mono SC|SimHei|SimSun|Arial|Times New Roman|自定义"
    Gui, Settings: Add, DropDownList, x100 y66 w160 vFontNamePreset gFontNamePresetChange, %fontPresetList%
    Gui, Settings: Add, Text, x270 y70 vFontNameCustomLabel, 自定义:
    Gui, Settings: Add, Edit, x320 y66 w100 vFontNameCustom, %FontName%
    
    ; 初始化字体预设/自定义显示
    if InStr("|" . fontPresetList . "|", "|" . FontName . "|")
    {
        GuiControl, Settings: ChooseString, FontNamePreset, %FontName%
        GuiControl, Settings: Hide, FontNameCustom
        GuiControl, Settings: Hide, FontNameCustomLabel
    }
    else
    {
        GuiControl, Settings: ChooseString, FontNamePreset, 自定义
        GuiControl, Settings: Show, FontNameCustom
        GuiControl, Settings: Show, FontNameCustomLabel
    }

    Gui, Settings: Add, Text, x20 y100, 字号:
    Gui, Settings: Add, Edit, x60 y96 w40 vFontSize, %FontSize%
    Gui, Settings: Add, UpDown, vFontSizeUD Range8-24, %FontSize%

    Gui, Settings: Add, Text, x120 y100, 字体粗细:
    Gui, Settings: Add, DropDownList, x180 y96 w80 vFontWeight, Normal|Bold||
    GuiControl, Settings: Choose, FontWeight, % (FontWeight = "Bold") ? 2 : 1

    ; 背景色模式 + 自定义色 + 预览
    Gui, Settings: Add, Text, x20 y130, 背景色模式:
    Gui, Settings: Add, DropDownList, x90 y126 w80 gBgColorModeChange vBgColorMode, 浅色预设|深色预设|自定义||
    GuiControl, Settings: Choose, BgColorMode, % (BgColorMode = "浅色预设") ? 1 : (BgColorMode = "深色预设") ? 2 : 3

    Gui, Settings: Add, Text, x180 y130, 自定义背景色:
    Gui, Settings: Add, Edit, x260 y126 w80 vBgColor gBgColorChanged, %BgColor%
    Gui, Settings: Add, Progress, x350 y126 w30 h20 vPrevBgColor +Border, 100
    Gui, Settings: Add, Button, x390 y126 w45 h20 vPickBgBtn gPickBgColor, 取色

    ; 若不是自定义模式则禁用输入框与预览
    if (BgColorMode != "自定义")
    {
        GuiControl, Settings: Disable, BgColor
        GuiControl, Settings: Disable, PrevBgColor
        GuiControl, Settings: Disable, PickBgBtn
    }

    ; 新增：只显示文字（与透明度互斥）
    Gui, Settings: Add, Checkbox, x20 y160 vOnlyText gOnlyTextChanged, 只显示文字
    GuiControl, Settings:, OnlyText, %OnlyText%

    ; 背景透明度（0-255）
    Gui, Settings: Add, Text, x20 y190, 背景透明度 (0-255):
    Gui, Settings: Add, Edit, x150 y186 w50 vBgTransparency, %BgTransparency%
    Gui, Settings: Add, UpDown, vBgTransparencyUD Range0-255, %BgTransparency%
    Gui, Settings: Add, Text, x210 y190, (0=完全透明，255=完全不透明)

    ; 显示器选择（多显示器支持）
    SysGet, mCount, MonitorCount
    dispOpt := "主屏幕|全部"
    Loop, %mCount%
        dispOpt .= "|" . "显示器" . A_Index
    Gui, Settings: Add, Text, x20 y220, 显示器:
    Gui, Settings: Add, DropDownList, x80 y216 w140 vDisplay, %dispOpt%
    ; 初始化选择：若 Display 为空则设置为主屏幕
    if (Display = "")
        Display := "主屏幕"
    GuiControl, Settings: ChooseString, Display, %Display%

    ; 位置选项卡
    Gui, Settings: Tab, 位置
    Gui, Settings: Add, Text, x20 y40, 位置角落:
    Gui, Settings: Add, DropDownList, x100 y36 w100 vPositionCorner, 右下角|右上角|左下角|左上角||
    GuiControl, Settings: Choose, PositionCorner, % (PositionCorner = "右下角") ? 1 : (PositionCorner = "右上角") ? 2 : (PositionCorner = "左下角") ? 3 : 4
    Gui, Settings: Add, Checkbox, x210 y38 vLimitOffset, 限制偏离量
    GuiControl, Settings:, LimitOffset, %LimitOffset%
    
    Gui, Settings: Add, Text, x20 y70, 横向偏移:
    Gui, Settings: Add, Edit, x150 y66 w50 vOffsetX, %OffsetX%
    Gui, Settings: Add, UpDown, vOffsetXUD Range-1000-1000, %OffsetX%
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
    Gui, Settings: Add, Edit, x120 y36 w80 vColorVeryLow gColorEditChanged, %ColorVeryLow%
    Gui, Settings: Add, Progress, x205 y36 w30 h20 vPrevVeryLow +Border, 100
    Gui, Settings: Add, Button, x240 y34 w45 h22 gPickVeryLow, 取色
    
    Gui, Settings: Add, Text, x20 y70, 低速颜色:
    Gui, Settings: Add, Edit, x120 y66 w80 vColorLow gColorEditChanged, %ColorLow%
    Gui, Settings: Add, Progress, x205 y66 w30 h20 vPrevLow +Border, 100
    Gui, Settings: Add, Button, x240 y64 w45 h22 gPickLow, 取色
    
    Gui, Settings: Add, Text, x20 y100, 中速颜色:
    Gui, Settings: Add, Edit, x120 y96 w80 vColorMed gColorEditChanged, %ColorMed%
    Gui, Settings: Add, Progress, x205 y96 w30 h20 vPrevMed +Border, 100
    Gui, Settings: Add, Button, x240 y94 w45 h22 gPickMed, 取色
    
    Gui, Settings: Add, Text, x20 y130, 高速颜色:
    Gui, Settings: Add, Edit, x120 y126 w80 vColorHigh gColorEditChanged, %ColorHigh%
    Gui, Settings: Add, Progress, x205 y126 w30 h20 vPrevHigh +Border, 100
    Gui, Settings: Add, Button, x240 y124 w45 h22 gPickHigh, 取色
    
    ; 高级选项卡
    Gui, Settings: Tab, 高级
    Gui, Settings: Add, Checkbox, x20 y40 vEnableSmoothing, 启用平滑处理
    GuiControl, Settings:, EnableSmoothing, %EnableSmoothing%
    
    Gui, Settings: Add, Text, x20 y70, EMA 平滑因子 (0-1):
    Gui, Settings: Add, Edit, x150 y66 w80 vEMAFactor, %EMAFactor%
    
    Gui, Settings: Add, Text, x20 y100, 防抖确认次数:
    Gui, Settings: Add, Edit, x150 y96 w50 vConfirmNeeded, %ConfirmNeeded%
    Gui, Settings: Add, UpDown, vConfirmNeededUD Range1-10, %ConfirmNeeded%

    ;保存/取消/恢复默认 按钮
    Gui, Settings: Tab
    Gui, Settings: Add, Button, x200 y270 w60 h30 gSaveSettings, 保存
    Gui, Settings: Add, Button, x270 y270 w60 h30 gCloseSettings, 取消
    Gui, Settings: Add, Button, x340 y270 w80 h30 gResetSettings, 恢复默认
    
    ; 初始化颜色预览（函数内部会从控件读取当前颜色并更新 Progress 颜色）
    Gosub, __InitColorPreview

    ; 初始化 OnlyText 与 BgTransparency 的互斥（显示/禁用相应输入框）
    Gosub, OnlyTextChanged

    ; 显示设置窗口
    Gui, Settings: Show, w450 h320, 网速监控设置
Return

; ---------- EnsureTopmost 开关变化回调（设置窗口内） ----------
EnsureTopmostChanged:
    Gui, Settings: Submit, NoHide
    if (EnsureTopmost)
    {
        GuiControl, Settings: Enable, TopmostReassertMin
        GuiControl, Settings: Enable, TopmostReassertMinUD
    }
    else
    {
        GuiControl, Settings: Disable, TopmostReassertMin
        GuiControl, Settings: Disable, TopmostReassertMinUD
    }
Return

; ---------- 初始化/更新颜色预览（供设置窗口使用） ----------
__InitColorPreview:
    Gui, Settings: Submit, NoHide
    UpdateColorPreviews()
Return

ColorEditChanged:
    Gui, Settings: Submit, NoHide
    UpdateColorPreviews()
Return

BgColorChanged:
    Gui, Settings: Submit, NoHide
    UpdateColorPreviews()
Return

; 更新颜色预览控件（将十六进制颜色应用到 Progress 控件作为背景色）
UpdateColorPreviews()
{
    ; 颜色输入为 BGR（不带 0x）可直接用于 Progress 的 c 参数
    global ColorVeryLow, ColorLow, ColorMed, ColorHigh, BgColorMode, BgColor
    GuiControl, Settings: +c%ColorVeryLow%, PrevVeryLow
    GuiControl, Settings: +c%ColorLow%, PrevLow
    GuiControl, Settings: +c%ColorMed%, PrevMed
    GuiControl, Settings: +c%ColorHigh%, PrevHigh

    ; 背景色支持 0xRRGGBB，需要转换为 BGR 且去掉 0x
    if (BgColorMode = "自定义")
    {
        bgr := __RgbOrBgrToBgrNo0x(BgColor)
        GuiControl, Settings: +c%bgr% +Background%bgr%, PrevBgColor
        GuiControl, Settings: Enable, PrevBgColor
    }
    else
    {
        GuiControl, Settings: Disable, PrevBgColor
    }
}

; 将可能的 "0xRRGGBB"(RGB) 或 "RRGGBB"(BGR) 统一转为 "BGR"(无 0x)
__RgbOrBgrToBgrNo0x(c)
{
    s := Trim(c)
    if (SubStr(s,1,2) = "0x" || SubStr(s,1,2) = "0X")
    {
        rgb := SubStr(s,3)
        if (StrLen(rgb) = 6)
        {
            r := SubStr(rgb,1,2), g := SubStr(rgb,3,2), b := SubStr(rgb,5,2)
            return b . g . r
        }
        return "000000"
    }
    if RegExMatch(s, "^[0-9A-Fa-f]{6}$")
        return s
    return "000000"
}

; ---------- 背景色模式变化处理（设置窗口回调） ----------
BgColorModeChange:
    Gui, Settings: Submit, NoHide
    if (BgColorMode = "自定义")
    {
        GuiControl, Settings: Enable, BgColor
        GuiControl, Settings: Enable, PrevBgColor
        GuiControl, Settings: Enable, PickBgBtn
    }
    else
    {
        GuiControl, Settings: Disable, BgColor
        GuiControl, Settings: Disable, PrevBgColor
        GuiControl, Settings: Disable, PickBgBtn
    }
    UpdateColorPreviews()
Return

; ---------- 字体预设选择变化回调（处理自定义字体显示） ----------
FontNamePresetChange:
    Gui, Settings: Submit, NoHide
    if (FontNamePreset = "自定义")
    {
        GuiControl, Settings: Show, FontNameCustom
        GuiControl, Settings: Show, FontNameCustomLabel
    }
    else
    {
        GuiControl, Settings: Hide, FontNameCustom
        GuiControl, Settings: Hide, FontNameCustomLabel
    }
Return

; ---------- 只显示文字 勾选变化（与透明度互斥） ----------
OnlyTextChanged:
    Gui, Settings: Submit, NoHide
    if (OnlyText)
    {
        ; 若勾选“只显示文字”，禁用透明度输入（防止冲突）
        GuiControl, Settings: Disable, BgTransparency
        GuiControl, Settings: Disable, BgTransparencyUD
    }
    else
    {
        GuiControl, Settings: Enable, BgTransparency
        GuiControl, Settings: Enable, BgTransparencyUD
    }
Return

; ---------- 保存设置（将 GUI 中的设置写回配置文件） ----------
SaveSettings:
    Gui, Settings: Submit

    ; 合成字体名称：若选自定义则取自定义输入，否则取预设项
    if (FontNamePreset = "自定义")
        FontName := Trim(FontNameCustom)
    else
        FontName := Trim(FontNamePreset)

    ; 清理输入中的逗号/空格以防止写入错误
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
    EMAFactor := Trim(EMAFactor)
    EnsureTopmost := EnsureTopmost ? EnsureTopmost : 0
    TopmostReassertMin := RegExReplace(TopmostReassertMin, "[^\d]", "")
    LimitOffset := LimitOffset ? 1 : 0

    ; 验证数值范围并设置默认值（防止用户输入导致异常）
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
    if (TopmostReassertMin < 1 || TopmostReassertMin > 60)
        TopmostReassertMin := 10

    ; 约束 EMAFactor 到 [0,1]
    if (EMAFactor = "")
        EMAFactor := 0.35
    else
    {
        if (EMAFactor < 0)
            EMAFactor := 0
        else if (EMAFactor > 1)
            EMAFactor := 1
    }

    ; 颜色合法性校验（6位16进制，不带 0x，BGR）
    if (!IsHex6(ColorVeryLow) || !IsHex6(ColorLow) || !IsHex6(ColorMed) || !IsHex6(ColorHigh))
    {
        MsgBox, 16, 保存失败, 颜色必须为6位16进制（如 CFCFCF）。请检查颜色输入后重试。
        Return
    }

    ; 自定义背景色：规范化为 0xRRGGBB（RGB），若非法提示并返回
    if (BgColorMode = "自定义")
    {
        nBg := NormalizeBgColor(BgColor)
        if (nBg = "")
        {
            MsgBox, 16, 保存失败, 自定义背景色必须为 0xRRGGBB 或 RRGGBB。请检查后重试。
            Return
        }
        BgColor := nBg
    }

    ; 将阈值从 KB/MB 转为字节并保证递增顺序（自动修正并提示一次）
    t1 := Thresh1KB*1024
    t2 := Thresh2KB*1024
    t3 := Thresh3MB*1024*1024
    adj := false
    if (t1 >= t2)
    {
        t2 := t1 + 1024
        Thresh2KB := Ceil(t2/1024.0)
        adj := true
    }
    if (t2 >= t3)
    {
        t3 := t2 + 1024
        Thresh3MB := Ceil(t3/1024.0/1024.0)
        adj := true
    }
    if (adj)
        MsgBox, 48, 已自动调整, 网速阈值已自动调整为递增顺序。保存后生效。

    ; 保存到配置文件（写入最终值）
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
    IniWrite, %OnlyText%, %ConfigFile%, GUI, OnlyText
    IniWrite, %BgTransparency%, %ConfigFile%, GUI, BgTransparency
    IniWrite, %PositionCorner%, %ConfigFile%, Position, Corner
    IniWrite, %OffsetX%, %ConfigFile%, Position, OffsetX
    IniWrite, %OffsetY%, %ConfigFile%, Position, OffsetY
    IniWrite, %Display%, %ConfigFile%, GUI, Display
    IniWrite, %LimitOffset%, %ConfigFile%, Position, LimitOffset
    
    ; 转换阈值单位并保存（使用可能被调整后的 t1/t2/t3）
    IniWrite, % t1, %ConfigFile%, Thresholds, Thresh1
    IniWrite, % t2, %ConfigFile%, Thresholds, Thresh2
    IniWrite, % t3, %ConfigFile%, Thresholds, Thresh3
    
    IniWrite, %ColorVeryLow%, %ConfigFile%, Colors, VeryLow
    IniWrite, %ColorLow%, %ConfigFile%, Colors, Low
    IniWrite, %ColorMed%, %ConfigFile%, Colors, Medium
    IniWrite, %ColorHigh%, %ConfigFile%, Colors, High
    
    IniWrite, %EnableSmoothing%, %ConfigFile%, Advanced, EnableSmoothing
    IniWrite, %EMAFactor%, %ConfigFile%, Advanced, EMAFactor
    IniWrite, %ConfirmNeeded%, %ConfigFile%, Advanced, ConfirmNeeded

    IniWrite, %EnsureTopmost%, %ConfigFile%, Advanced, EnsureTopmost
    IniWrite, %TopmostReassertMin%, %ConfigFile%, Advanced, TopmostReassertMin
    
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

; ---------- 关闭设置窗口（取消） ----------
CloseSettings:
    Gui, Settings: Destroy
Return

; ---------- 重置为默认设置（删除配置文件并写入默认） ----------
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

; ---------- 设置窗口关闭事件（X） ----------
SettingsGuiClose:
    Gui, Settings: Destroy
Return

; ========================= 定时更新核心（主逻辑） =========================

; ---------- 定时更新函数：UpdateNet（每 Interval 毫秒触发） ----------
UpdateNet:
    ; 在每次循环开始时，重置累加值和候选/临时变量
    recv := 0
    sent := 0
    sSent := ""
    sRecv := ""
    candidateUp := ""
    candidateDown := ""

    ; --- 获取网速数据（通过 WMI 累加所有网络接口） ---
    if (wmi)
    {
        try
        {
            ; 尝试查询网络接口统计
            q := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_NetworkInterface")
            if (!q.Count)
                ; 若无数据，则尝试 TCPv4 备用类
                q := wmi.ExecQuery("SELECT BytesReceivedPersec, BytesSentPersec FROM Win32_PerfFormattedData_Tcpip_TCPv4")
            for item in q
            {
                ; 累加每个接口的上传与下载（部分接口可能不存在该属性，使用三元判断）
                recv := recv + (item.BytesReceivedPersec ? item.BytesReceivedPersec : 0)
                sent := sent + (item.BytesSentPersec ? item.BytesSentPersec : 0)
            }
        }
        catch e
        {
            ; 若获取失败，将数值置 0（保持健壮性）
            recv := 0
            sent := 0
        }
    }

    ; --- EMA 平滑处理（性能优化：当 EMAFactor 为 1 时等同直接赋值） ---
    if (emaUp = 0)
        emaUp := sent
    else
        emaUp := emaUp*(1-EMAFactor) + sent*EMAFactor

    if (emaDown = 0)
        emaDown := recv
    else
        emaDown := emaDown*(1-EMAFactor) + recv*EMAFactor

    ; --- 根据 EMA 值决定候选颜色（按阈值分类） ---
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

    ; --- 格式化文本为带单位字符串（用于显示） ---
    sSent := FormatSpeed(emaUp)
    sRecv := FormatSpeed(emaDown)

    ; --- 仅在文本变化时刷新 GUI 文本，减少重绘开销 ---
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

    ; --- 刷新颜色（将 lastColorUp/Down 应用于控件） ---
    GuiControl, +c%lastColorUp%, UpNum
    GuiControl, +c%lastColorUp%, UpArrow
    GuiControl, +c%lastColorDown%, DownNum
    GuiControl, +c%lastColorDown%, DownArrow
Return

; ------------------------- 颜色选择函数 -------------------------
; 根据速度（字节/秒）返回对应颜色（字符串，6位十六进制）
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

; ========================= GUI 创建与显示 =========================

; ---------- 创建 GUI 并显示（初始或重建时调用） ----------
CreateGuiAndShow(hexColor)
{
    global GuiWidth, GuiHeight, FontName, FontSize, FontWeight
    global NumWidth, ArrowWidth, UpY, DownY, ArrowX, BgColor, BgTransparency, OnlyText
    global UpNum, UpArrow, DownNum, DownArrow
    global hGui ; 保存当前 GUI 句柄，供 WinSet 等 API 使用
    global MouseThrough ; 鼠标穿透设置

    ; 获取 GUI 窗口句柄（使用 +Hwnd 语法）
    Gui, +AlwaysOnTop -Caption +ToolWindow +HwndhGui
    Gui, Margin, 0,0
    Gui, Font, s%FontSize% %FontWeight%, %FontName%

    ; 添加控件：上行/下行数字与箭头，使用 BackgroundTrans（文字透明）以配合背景处理
    Gui, Add, Text, x0 y%UpY% w%NumWidth% vUpNum   Right  c%hexColor% BackgroundTrans, 初始化...
    Gui, Add, Text, x%ArrowX% y%UpY% w%ArrowWidth% vUpArrow  Center c%hexColor% BackgroundTrans, ↑
    Gui, Add, Text, x0 y%DownY% w%NumWidth% vDownNum Right  c%hexColor% BackgroundTrans, 初始化...
    Gui, Add, Text, x%ArrowX% y%DownY% w%ArrowWidth% vDownArrow Center c%hexColor% BackgroundTrans, ↓

    ; 设置窗口背景颜色（使用已规范化的 BgColor）
    Gui, Color, %BgColor%

    ; 根据配置定位窗口（支持多显示器或全部虚拟屏）
    PositionGui()

    ; 根据 OnlyText 与 BgTransparency 策略应用透明度/挖空等
    ApplyGuiTransparency()

    ; 应用鼠标穿透设置（通过扩展窗口样式 ExStyle）
    if (MouseThrough)
        WinSet, ExStyle, +0x20, ahk_id %hGui%  ; WS_EX_TRANSPARENT
    else
        WinSet, ExStyle, -0x20, ahk_id %hGui%
}

; ---------- 应用窗口透明策略（两种方案） ----------
ApplyGuiTransparency()
{
    global hGui, BgColor, BgTransparency, OnlyText

    if (OnlyText) {
        ; 方案A：挖空背景，仅显示文字（通过 TransColor 指定被挖空颜色）
        WinSet, Transparent, Off,            ahk_id %hGui%
        WinSet, TransColor, %BgColor% 255,   ahk_id %hGui% ; 将 BgColor 设为透明色
    } else {
        ; 方案B：整窗半透明（包含文字）
        WinSet, TransColor, Off,             ahk_id %hGui%
        WinSet, Transparent, %BgTransparency%, ahk_id %hGui%
    }
}

; ---------- 重申置顶（定时器回调 / 可由 SetTimer 调用） ----------
ReassertTopmost:
    ; 通过保存的窗口句柄 hGui 重新设置 AlwaysOnTop，防止被顶掉
    global hGui
    if (hGui)
    {
        WinSet, AlwaysOnTop, On, ahk_id %hGui%
    }
Return

; ========================= 多显示器支持与定位 =========================

; ---------- 获取目标工作区（支持“全部”或具体显示器） ----------
GetTargetWorkArea(ByRef sx, ByRef sy, ByRef sw, ByRef sh)
{
    global Display
    if (Display = "全部")
    {
        ; Virtual screen（包含所有显示器区域）
        SysGet, vLeft, 76   ; VirtualScreenLeft
        SysGet, vTop, 77    ; VirtualScreenTop
        SysGet, vW, 78      ; VirtualScreenWidth
        SysGet, vH, 79      ; VirtualScreenHeight
        sx := vLeft, sy := vTop, sw := vW, sh := vH
        return
    }
    else if (Display = "主屏幕" || Display = "")
    {
        SysGet, pMon, MonitorPrimary
        idx := pMon
    }
    else
    {
        ; 显示器N：从 "显示器N" 中解析数字
        idx := RegExReplace(Display, "\D", "")
        if (idx = "")
            idx := 1
    }
    ; 获取指定显示器的工作区（去除任务栏等）
    SysGet, wa, MonitorWorkArea, %idx%
    sx := waLeft, sy := waTop, sw := waRight - waLeft, sh := waBottom - waTop
}

; ---------- 根据配置定位GUI（支持选择显示器/全部虚拟屏幕） ----------
PositionGui()
{
    global GuiWidth, GuiHeight, PositionCorner, OffsetX, OffsetY, hGui, LimitOffset
    ; 取目标工作区坐标和宽高
    GetTargetWorkArea(screenX, screenY, screenW, screenH)

    if (PositionCorner = "右下角")
    {
        baseX := screenX + screenW - GuiWidth
        baseY := screenY + screenH - GuiHeight
        x := baseX - OffsetX  ; 横向：正数向右偏移变为负数向左偏移
        y := baseY - OffsetY  ; 纵向：正数向上偏移变为负数向下偏移
    }
    else if (PositionCorner = "右上角")
    {
        baseX := screenX + screenW - GuiWidth
        baseY := screenY
        x := baseX - OffsetX  ; 横向：正数向右偏移变为负数向左偏移
        y := baseY + OffsetY  ; 纵向：正数向上偏移
    }
    else if (PositionCorner = "左下角")
    {
        baseX := screenX
        baseY := screenY + screenH - GuiHeight
        x := baseX + OffsetX  ; 横向：正数向右偏移
        y := baseY - OffsetY  ; 纵向：正数向上偏移变为负数向下偏移
    }
    else ; 左上角
    {
        baseX := screenX
        baseY := screenY
        x := baseX + OffsetX  ; 横向：正数向右偏移
        y := baseY + OffsetY  ; 纵向：正数向上偏移
    }
    
    ; 若启用“限制偏离量”，则将最终位置限制在工作区范围内（不修改配置，仅显示时矫正，防止超出显示器）
    if (LimitOffset)
    {
        maxX := screenX + screenW - GuiWidth
        maxY := screenY + screenH - GuiHeight
        if (x < screenX)
            x := screenX
        if (y < screenY)
            y := screenY
        if (x > maxX)
            x := maxX
        if (y > maxY)
            y := maxY
    }
    
    ; 显示并定位 GUI，不激活窗口（NoActivate）
    Gui, Show, x%x% y%y% w%GuiWidth% h%GuiHeight% NoActivate
}

; ========================= 显示格式化与工具函数 =========================

; ---------- 格式化网速，带单位（返回字符串） ----------
FormatSpeed(val)
{
    ; val 单位为 字节/秒（B/s）
    if (val >= 1048576) ; 大于 1MB/s
        return Round(val/1048576, 2) . " MB/s"
    else if (val >= 1024) ; 大于 1KB/s
        return Round(val/1024, 1) . " KB/s"
    else
        return Round(val, 0) . " B/s"
}

; ---------- 工具函数：检查是否为 6 位十六进制字符串 ----------
IsHex6(s)
{
    return RegExMatch(s, "^[0-9A-Fa-f]{6}$")
}

; ---------- 规范化背景色输入：接受 0xRRGGBB 或 RRGGBB，返回 0xRRGGBB 或空字符串 ----------
NormalizeBgColor(s)
{
    s := Trim(s)
    if (SubStr(s,1,2) = "0x" || SubStr(s,1,2) = "0X")
    {
        if (StrLen(s) = 8)
            return s
        else
            return ""
    }
    else if RegExMatch(s, "^[0-9A-Fa-f]{6}$")
    {
        ; 视为 RRGGBB，补 0x 前缀
        return "0x" . s
    }
    return ""
}

; ========================= 取色器功能实现 =========================
; 通用入口：为指定控件启动取色器
StartColorPicker(targetControl)
{
    ; 跨子程序共享的状态/句柄/缓存值
    global PickerActive, CurrentPickTarget, hPicker, PickerLastRGB
    global PickPrev

    if (PickerActive)
        return

    PickerActive := true
    CurrentPickTarget := targetControl
    PickerLastRGB := "FFFFFF"  ; 最近一次采样的 RGB（RRGGBB）

    ; 避免在按住左键拖动时意外触发确认：等待当前左键释放后再开始
    KeyWait, LButton

    ; ---------- 创建取色器小窗 ----------
    Gui, Picker: Destroy
    Gui, Picker: +AlwaysOnTop -Caption +ToolWindow +HwndhPicker +E0x20
    Gui, Picker: Margin, 8,8
    Gui, Picker: Color, 0xF5F5F5
    Gui, Picker: Font, s10, Segoe UI

    Gui, Picker: Add, Text, x8 y8 c000000, 左键确定 右键取消
    Gui, Picker: Add, Progress, x8 y28 w110 h50 vPickPrev +Border, 100

    CoordMode, Mouse, Screen
    MouseGetPos, mx, my
    px := mx + 20, py := my + 20
    Gui, Picker: Show, x%px% y%py% AutoSize NoActivate

    ; ---------- 绑定交互热键 ----------
    Hotkey, ~LButton Up, __PickerConfirm, On
    Hotkey, ~RButton Up, __PickerCancel, On
    Hotkey, Esc, __PickerCancel, On
    Hotkey, Enter, __PickerConfirm, On
    Hotkey, Space, __PickerConfirm, On

    ; ---------- 启动采样定时器 ----------
    SetTimer, __PickerTick, 30
}

; 取色器定时器：跟随鼠标，实时采样像素颜色并更新 UI
__PickerTick:
    global PickerActive, PickerLastRGB
    if (!PickerActive)
        Return

    CoordMode, Pixel, Screen
    CoordMode, Mouse, Screen

    MouseGetPos, mx, my
    px := mx + 20, py := my + 20
    Gui, Picker: Show, x%px% y%py% NoActivate

    PixelGetColor, colRGB, mx, my, RGB
    colRGB := colRGB & 0xFFFFFF
    hexRGB := Format("{:06X}", colRGB)  ; RRGGBB

    PickerLastRGB := hexRGB

    ; 更新预览块颜色与文本
    GuiControl, Picker: +c%hexRGB% +Background%hexRGB%, PickPrev
Return

; 确认取色：写入 0xRRGGBB
__PickerConfirm:
    global PickerActive, CurrentPickTarget, PickerLastRGB
    if (!PickerActive)
        Return

    val := PickerLastRGB
    GuiControl, Settings:, %CurrentPickTarget%, %val%

    ; 刷新外部设置界面的颜色预览（若存在）
    Gosub, __InitColorPreview

    Gosub, __PickerStop
Return

; 取消取色
__PickerCancel:
    Gosub, __PickerStop
Return

; 停止取色器：收尾
__PickerStop:
    global PickerActive, hPicker
    SetTimer, __PickerTick, Off
    Hotkey, ~LButton Up, Off
    Hotkey, ~RButton Up, Off
    Hotkey, Esc, Off
    Hotkey, Enter, Off
    Hotkey, Space, Off
    Gui, Picker: Destroy
    PickerActive := false
Return

; 取色按钮事件（颜色页/界面页）——统一为 0xRRGGBB
PickVeryLow:
    StartColorPicker("ColorVeryLow")
Return
PickLow:
    StartColorPicker("ColorLow")
Return
PickMed:
    StartColorPicker("ColorMed")
Return
PickHigh:
    StartColorPicker("ColorHigh")
Return
PickBgColor:
    StartColorPicker("BgColor")
Return

; ---------- 显示关于窗口 ----------
ShowAbout:
    ; 销毁旧的关于窗口（如果存在）
    Gui, About: Destroy

    ; 创建关于窗口
    Gui, About: +AlwaysOnTop +ToolWindow +HwndhAbout
    Gui, About: Margin, 20, 20
    Gui, About: Font, s11, Segoe UI Variable

    ; 标题
    Gui, About: Font, s16 Bold
    Gui, About: Add, Text, x20 y20 w400 Center, Display Network Speed

    ; 简介
    Gui, About: Font, s10 Normal
    Gui, About: Add, Text, x20 y50 w400 Center c666666, 网速监控显示工具

    ; 分隔线
    Gui, About: Add, Progress, x20 y80 w400 h2 BackgroundDDDDDD, 100

    ; 版本信息
    Gui, About: Font, s10
    Gui, About: Add, Text, x20 y100, 版本: v1.0.0
    Gui, About: Add, Text, x20 y125, 基于: AutoHotkey v1.1+
    Gui, About: Add, Text, x20 y150, 作者：YI
    Gui, About: Add, Text, x20 y175, 项目地址：
    
    ; 可点击 URL
    Gui, About: Add, Text, x20 y195 w400 c0000FF gOpenProjectURL, https://github.com/YI/DisplayNetworkSpeed

    ; 功能特性标题
    Gui, About: Font, s11 Bold
    Gui, About: Add, Text, x20 y230, 主要功能

    ; 功能特性内容
    Gui, About: Font, s10 Normal
    Gui, About: Add, Text, x30 y255, • 实时网速显示 (WMI接口)
    Gui, About: Add, Text, x30 y275, • 智能颜色编码 (4档阈值)
    Gui, About: Add, Text, x30 y295, • EMA平滑处理
    Gui, About: Add, Text, x30 y315, • 多显示器支持
    Gui, About: Add, Text, x30 y335, • 高度自定义配置

    ; 按钮区域
    Gui, About: Add, Button, x20 y380 w120 h30 gOpenConfigFolder, 打开配置文件夹

    ; 显示关于窗口
    Gui, About: Show, w440 h430, 关于 Display Network Speed
Return

OpenProjectURL:
    Run, https://github.com/YI/DisplayNetworkSpeed
Return

; 打开配置文件夹
OpenConfigFolder:
    Run, explorer "%A_ScriptDir%"
Return

; ========================= 控制命令（托盘菜单绑定） =========================

; ---------- 重启脚本函数 ----------
RestartApp:
    Reload
Return

; ---------- 退出脚本 ----------
ExitApp:
    ExitApp
Return
