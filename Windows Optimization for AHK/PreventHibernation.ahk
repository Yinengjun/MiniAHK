; PreventHibernation.ahk
#Persistent
#SingleInstance Force

global PreventHibernation := false  ; 默认关闭

return

; ===== 接口函数 =====
SetPreventHibernation(state) {
    global PreventHibernation
    PreventHibernation := state

    if (PreventHibernation && MasterSwitch) {
        KeepAwake()
    } else {
        AllowSleep()
    }
}

KeepAwake() {
    DllCall("SetThreadExecutionState", "UInt", 0x80000001 | 0x00000002)
}

AllowSleep() {
    DllCall("SetThreadExecutionState", "UInt", 0x80000000)
}
