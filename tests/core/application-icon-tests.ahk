#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\UI\ApplicationIcon.ahk

AssertEqual("realSilasYang.KeyMouseRemapperAssistant",
    GetApplicationUserModelId(),
    "应用身份不是预期的稳定 AppUserModelID")
AssertTrue(ConfigureApplicationShellIdentity(),
    "无法向 Windows 声明显式 AppUserModelID")

appIdPointer := 0
try {
    identityQueryResult := DllCall("shell32\GetCurrentProcessExplicitAppUserModelID",
        "Ptr*", &appIdPointer, "Int")
    AssertTrue(identityQueryResult >= 0 && appIdPointer,
        "无法从当前进程读回显式 AppUserModelID")
    AssertEqual(GetApplicationUserModelId(), StrGet(appIdPointer, "UTF-16"),
        "Windows 读回的 AppUserModelID 与项目身份不一致")
} finally {
    if appIdPointer
        DllCall("ole32\CoTaskMemFree", "Ptr", appIdPointer)
}

iconMetrics := GetApplicationIconMetrics()
AssertEqual(Max(16, DllCall("user32\GetSystemMetrics", "Int", 49, "Int")),
    iconMetrics.Small, "小图标尺寸没有跟随 Windows 系统指标")
AssertEqual(Max(32, DllCall("user32\GetSystemMetrics", "Int", 11, "Int")),
    iconMetrics.Large, "大图标尺寸没有跟随 Windows 系统指标")

testGui := Gui(, "Application icon test")
iconHandles := []
try {
    iconHandles := ApplyApplicationWindowIcon(testGui.Hwnd)
    AssertEqual(2, iconHandles.Length, "项目 ICO 没有同时提供大小窗口图标")
    AssertEqual(iconHandles[1], SendMessage(0x007F, 0, 0, , testGui.Hwnd),
        "窗口的小图标槽没有使用项目 ICO") ; WM_GETICON / ICON_SMALL
    AssertEqual(iconHandles[2], SendMessage(0x007F, 1, 0, , testGui.Hwnd),
        "窗口的大图标槽没有使用项目 ICO") ; WM_GETICON / ICON_BIG
} finally {
    testGui.Destroy()
    ReleaseApplicationWindowIcons(iconHandles)
    AssertEqual(iconHandles.Length, 0,
        "已释放的窗口图标句柄应从资源账本移除")
}

WriteTestSuccess("application-icon")
ExitApp(0)
