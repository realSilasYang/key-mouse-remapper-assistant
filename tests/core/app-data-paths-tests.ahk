#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Config\AppDataPaths.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-data-paths-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
previousDirectory := testRoot "\KeyMouseRemapper"
legacyDirectory := testRoot "\ShortcutRemapper"
currentDirectory := testRoot "\KeyMouseRemapperAssistant"

try {
    DirCreate(previousDirectory)
    DirCreate(legacyDirectory)
    FileAppend("previous-settings",
        previousDirectory "\key-mouse-remapper.ini", "UTF-8-RAW")
    FileAppend("previous-history", previousDirectory "\history.dat",
        "UTF-8-RAW")
    FileAppend("previous-variables", previousDirectory "\variables.json",
        "UTF-8-RAW")
    FileAppend("previous-control",
        previousDirectory "\control-requests.json", "UTF-8-RAW")
    FileAppend("previous-startup-health",
        previousDirectory "\startup-health.json", "UTF-8-RAW")
    FileAppend("previous-last-known-good",
        previousDirectory "\last-known-good.json", "UTF-8-RAW")
    FileAppend("previous-output-recovery",
        previousDirectory "\output-recovery.json", "UTF-8-RAW")
    FileAppend("previous-crash-diagnostics",
        previousDirectory "\crash-diagnostics.json", "UTF-8-RAW")
    FileAppend("legacy-settings", legacyDirectory "\key-remapper.ini",
        "UTF-8-RAW")
    FileAppend("legacy-history", legacyDirectory "\history.dat",
        "UTF-8-RAW")
    FileAppend("legacy-notification",
        legacyDirectory "\pending-notification.txt", "UTF-8-RAW")

    paths := KeyMouseRemapperAssistantDataPaths.Resolve(testRoot)
    AssertEqual(currentDirectory "\key-mouse-remapper-assistant.ini", paths.Settings,
        "旧设置没有迁移到新名称")
    AssertEqual("previous-settings", FileRead(paths.Settings, "UTF-8"),
        "没有优先迁移上一产品名的设置")
    AssertEqual("previous-history", FileRead(paths.History, "UTF-8"),
        "没有优先迁移上一产品名的历史")
    AssertEqual("legacy-notification",
        FileRead(paths.Notification, "UTF-8"), "待显示通知没有迁移")
    AssertEqual("previous-variables", FileRead(paths.Variables, "UTF-8"),
        "变量没有从上一产品名迁移")
    AssertEqual(currentDirectory "\startup-health.json",
        paths.StartupHealth, "启动健康状态路径错误")
    AssertEqual(currentDirectory "\last-known-good.json",
        paths.LastKnownGood, "最后正常配置路径错误")
    AssertEqual(currentDirectory "\output-recovery.json",
        paths.OutputRecovery, "输出恢复日志路径错误")
    AssertEqual(currentDirectory "\crash-diagnostics.json",
        paths.CrashDiagnostics, "崩溃诊断日志路径错误")
    AssertEqual("previous-control", FileRead(paths.Control, "UTF-8"),
        "控制队列没有从上一产品名迁移")
    AssertEqual("previous-startup-health",
        FileRead(paths.StartupHealth, "UTF-8"),
        "启动健康状态没有从上一产品名迁移")
    AssertEqual("previous-last-known-good",
        FileRead(paths.LastKnownGood, "UTF-8"),
        "最后正常配置没有从上一产品名迁移")
    AssertEqual("previous-output-recovery",
        FileRead(paths.OutputRecovery, "UTF-8"),
        "输出恢复日志没有从上一产品名迁移")
    AssertEqual("previous-crash-diagnostics",
        FileRead(paths.CrashDiagnostics, "UTF-8"),
        "崩溃诊断没有从上一产品名迁移")

    whitespaceRejected := false
    try KeyMouseRemapperAssistantDataPaths.Resolve(" `t ")
    catch as whitespaceError
        whitespaceRejected := InStr(whitespaceError.Message, "空白") > 0
    AssertTrue(whitespaceRejected, "纯空白应用数据根目录没有被拒绝")
    relativeRejected := false
    try KeyMouseRemapperAssistantDataPaths.Resolve("relative-data")
    catch as relativeError
        relativeRejected := InStr(relativeError.Message, "绝对路径") > 0
    AssertTrue(relativeRejected, "相对应用数据根目录没有被拒绝")
    rootRejected := false
    try KeyMouseRemapperAssistantDataPaths.Resolve(SubStr(testRoot, 1, 3))
    catch as rootError
        rootRejected := InStr(rootError.Message, "根目录") > 0
    AssertTrue(rootRejected, "卷根目录被错误接受为应用数据根目录")
    fileRoot := testRoot "\not-a-directory"
    FileAppend("file", fileRoot, "UTF-8-RAW")
    fileRootRejected := false
    try KeyMouseRemapperAssistantDataPaths.Resolve(fileRoot)
    catch as fileRootError
        fileRootRejected := InStr(fileRootError.Message, "指向了文件") > 0
    AssertTrue(fileRootRejected, "文件路径被错误接受为应用数据根目录")

    FileDelete(paths.Settings)
    FileAppend("current-settings", paths.Settings, "UTF-8-RAW")
    FileDelete(previousDirectory "\key-mouse-remapper.ini")
    FileAppend("changed-previous",
        previousDirectory "\key-mouse-remapper.ini",
        "UTF-8-RAW")
    resolvedAgain := KeyMouseRemapperAssistantDataPaths.Resolve(testRoot)
    AssertEqual("current-settings",
        FileRead(resolvedAgain.Settings, "UTF-8"),
        "迁移覆盖了已存在的新设置")
    WriteTestSuccess("app-data-paths")
} finally {
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)
