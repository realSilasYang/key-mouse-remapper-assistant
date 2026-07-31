#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\TestSupport.ahk
#Include ..\..\src\Localization\EnglishStrings.ahk
#Include ..\..\src\Localization\TraditionalHongKongStrings.ahk
#Include ..\..\src\Localization\TraditionalTaiwanStrings.ahk
#Include ..\..\src\Localization\JapaneseStrings.ahk
#Include ..\..\src\Localization\VietnameseStrings.ahk
#Include ..\..\src\Localization\KoreanStrings.ahk
#Include ..\..\src\Localization\SpanishStrings.ahk
#Include ..\..\src\Localization\FrenchStrings.ahk
#Include ..\..\src\Localization\PortugueseBrazilStrings.ahk
#Include ..\..\src\Localization\RussianStrings.ahk
#Include ..\..\src\Localization\GermanStrings.ahk
#Include ..\..\src\Localization\ItalianStrings.ahk
#Include ..\..\src\Localization\LocalizationService.ahk
#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Config\AppSettingsService.ahk

testRoot := A_Temp "\key-mouse-remapper-assistant-settings-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))
DirCreate(testRoot)
settingsPath := testRoot "\key-mouse-remapper-assistant.ini"

try {
    emptyPathRejected := false
    try AppSettingsService(" `t ")
    catch as emptyPathError
        emptyPathRejected := InStr(emptyPathError.Message, "不能为空") > 0
    AssertTrue(emptyPathRejected, "设置服务接受了空白文件路径")
    relativeService := AppSettingsService("relative-settings.ini")
    AssertEqual(CrossProcessWriteLock.NormalizePath("relative-settings.ini"),
        relativeService.SettingsPath, "设置服务没有固定相对路径的绝对位置")
    service := AppSettingsService(settingsPath)
    defaults := service.Load()
    AssertEqual("", service.LastLoadWarning,
        "设置文件不存在时被错误报告为读取失败")
    AssertEqual("auto", defaults.UiLanguage, "语言默认值错误")
    AssertEqual("auto", defaults.UiFont, "字体默认值错误")
    AssertEqual("auto", defaults.Theme, "主题默认值错误")
    AssertTrue(defaults.EscapeCancelsRecording, "Esc 取消录制默认值错误")
    AssertEqual(1000, defaults.EventBufferCapacity,
        "事件缓冲区默认值错误")
    AssertTrue(defaults.EventViewerAutoScroll, "事件自动跟随默认值错误")

    saved := service.Save({UiLanguage: "en-US", UiFont: "auto",
        Theme: "light",
        EscapeCancelsRecording: false,
        EventBufferCapacity: 2400, EventViewerAutoScroll: false})
    loaded := service.Load()
    AssertEqual("en-US", loaded.UiLanguage, "界面语言没有保存")
    AssertEqual("light", loaded.Theme, "浅色主题没有保存")
    AssertTrue(!loaded.EscapeCancelsRecording, "Esc 录制设置没有保存")
    AssertEqual(2400, loaded.EventBufferCapacity,
        "事件缓冲区设置没有保存")
    AssertTrue(!loaded.EventViewerAutoScroll, "事件自动跟随设置没有保存")
    settingsSnapshot := service.GetSnapshot()
    AssertTrue(!InStr(settingsSnapshot, "ShowMainWindowAtStartup")
            && !InStr(settingsSnapshot, "[General]"),
        "设置文件仍写出已移除的启动窗口选项")
    service.Save({UiLanguage: "zh-CN", UiFont: "auto", Theme: "dark",
        EscapeCancelsRecording: true,
        EventBufferCapacity: 1000,
        EventViewerAutoScroll: true})
    service.WriteSnapshot(settingsSnapshot)
    AssertEqual("en-US", service.Load().UiLanguage, "设置快照无法恢复")
    unicodeSnapshot := ""
    Loop 24000
        unicodeSnapshot .= "界"
    unicodeSnapshotRejected := false
    try service.WriteSnapshot(unicodeSnapshot)
    catch
        unicodeSnapshotRejected := true
    AssertTrue(unicodeSnapshotRejected,
        "超过 UTF-8 字节上限的设置快照仍被写入")

    FileDelete(settingsPath)
    FileAppend("[General]`r`nShowMainWindowAtStartup=1`r`n"
        . "[Appearance]`r`nUiLanguage=zh-CN`r`nUiFont=auto`r`n"
        . "Theme=dark`r`n"
        . "[Events]`r`nEventBufferCapacity=bad`r`n", settingsPath,
        "UTF-8-RAW")
    recoveredSettings := service.Load()
    AssertEqual(1000, recoveredSettings.EventBufferCapacity,
        "无效事件容量没有回退默认值")
    AssertTrue(!recoveredSettings.HasOwnProp("ShowMainWindowAtStartup")
            && recoveredSettings.EscapeCancelsRecording
            && recoveredSettings.EventViewerAutoScroll,
        "旧版设置文件没有忽略启动窗口字段或补齐布尔默认值")

    LocalizationService.Configure("en-US", "auto")
    AssertEqual("Keyboard & Mouse Remapper Assistant", Tr("键鼠重映射小助手"),
        "英文翻译目录没有生效")
    AssertEqual("Noto Sans", LocalizationService.GetUiFontName(),
        "英文默认字体错误")
    AssertEqual("Segoe UI",
        LocalizationService.GetLanguageSystemUiFontName(),
        "英文系统界面字体错误")
    LocalizationService.Configure("zh-CN", "auto")
    AssertEqual("键鼠重映射小助手", Tr("键鼠重映射小助手"),
        "中文原文回退错误")
    AssertEqual("Noto Sans CJK SC", LocalizationService.GetUiFontName(),
        "中文默认字体错误")
    AssertEqual("Microsoft YaHei UI",
        LocalizationService.GetLanguageSystemUiFontName(),
        "中文系统界面字体错误")
    AssertTrue(LocalizationService.GetInstalledUiFontNames().Length > 0,
        "没有枚举出本机内容字体")

    UiThemeService.Configure("light")
    AssertTrue(!UiThemeService.IsDark()
        && UiThemeService.GetPalette().Window == "F1F5F9"
        && UiThemeService.GetPalette().Link == "0969DA"
        && UiThemeService.GetPalette().ReadonlyText == "334155"
        && UiThemeService.GetPalette().CodeVariable == "B45309"
        && UiThemeService.GetPalette().CodeValue == "4D7C0F"
        && UiThemeService.GetPalette().CodeComment == "6B7280",
        "浅色主题调色板错误")
    UiThemeService.Configure("dark")
    AssertTrue(UiThemeService.IsDark()
        && UiThemeService.GetPalette().Window == "1E1E1E"
        && UiThemeService.GetPalette().Link == "4EA1FF"
        && UiThemeService.GetPalette().ReadonlyText == "D8D8D8"
        && UiThemeService.GetPalette().CodeVariable == "D17A2A"
        && UiThemeService.GetPalette().CodeValue == "6A8754"
        && UiThemeService.GetPalette().CodeComment == "858585",
        "深色主题调色板错误")
    AssertEqual("auto", UiThemeService.NormalizeTheme("follow-system"),
        "跟随系统主题别名没有归一化")
    AssertEqual("light", UiThemeService.NormalizeTheme("浅色"),
        "浅色主题中文别名没有归一化")
    AssertEqual("dark", UiThemeService.NormalizeTheme("深色"),
        "深色主题中文别名没有归一化")

    oversizedOutput := FileOpen(settingsPath, "w", "UTF-8-RAW")
    if !IsObject(oversizedOutput)
        throw Error("无法建立超大设置测试文件")
    oversizedChunk := ""
    Loop 1024
        oversizedChunk .= "x"
    Loop 65
        oversizedOutput.Write(oversizedChunk)
    oversizedOutput.Close()
    oversizedDefaults := service.Load()
    AssertEqual("auto", oversizedDefaults.UiLanguage,
        "超大设置文件没有安全回退默认值")
    AssertTrue(InStr(service.LastLoadWarning, "已使用默认设置") > 0,
        "设置读取失败后没有留下可观察警告")
    oversizedSnapshotRejected := false
    try service.GetSnapshot()
    catch
        oversizedSnapshotRejected := true
    AssertTrue(oversizedSnapshotRejected,
        "超大设置文件仍被完整读取为快照")
    WriteTestSuccess("appearance-settings")
} finally {
    LocalizationService.ShutdownUiFonts()
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)
