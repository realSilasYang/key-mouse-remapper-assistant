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

testRoot := A_Temp "\key-mouse-remapper-assistant-fonts-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF))

try {
    assetDirectory := LocalizationService.GetUiFontAssetDirectory()
    for assetName in ["NotoSans-Variable.ttf", "NotoSansCJK.ttc"]
        AssertTrue(FileExist(assetDirectory "\" assetName),
            "缺少随包字体：" assetName)

    LocalizationService.Configure("zh-CN", "auto")
    AssertEqual("Noto Sans CJK SC", LocalizationService.GetUiFontName(),
        "中文没有使用随包 Noto Sans CJK SC")
    AssertEqual("Microsoft YaHei UI",
        LocalizationService.GetLanguageSystemUiFontName(),
        "中文系统界面字体不应随内容字体变化")
    LocalizationService.Configure("en-US", "auto")
    AssertEqual("Noto Sans", LocalizationService.GetUiFontName(),
        "英文没有使用随包 Noto Sans")
    AssertEqual("Segoe UI",
        LocalizationService.GetLanguageSystemUiFontName(),
        "英文系统界面字体错误")
    LocalizationService.Configure("ja-JP", "auto")
    AssertEqual("Noto Sans CJK JP", LocalizationService.GetUiFontName(),
        "日文没有使用随包 Noto Sans CJK JP")
    AssertEqual("Yu Gothic UI",
        LocalizationService.GetLanguageSystemUiFontName(),
        "日文系统界面字体错误")
    LocalizationService.Configure("ko-KR", "auto")
    AssertEqual("Noto Sans CJK KR", LocalizationService.GetUiFontName(),
        "韩文没有使用随包 Noto Sans CJK KR")
    AssertEqual("Malgun Gothic",
        LocalizationService.GetLanguageSystemUiFontName(),
        "韩文系统界面字体错误")
    AssertEqual("Noto Sans",
        LocalizationService.NormalizeUiFont("noto sans"),
        "字体名称没有按已安装名称保留大小写")

    DirCreate(testRoot)
    retryAsset := "NotoSans-Variable.ttf"
    AssertTrue(!LocalizationService.LoadPrivateUiFontAsset(retryAsset,
        testRoot), "不存在的字体资源没有失败")
    FileCopy(assetDirectory "\NotoSans-Variable.ttf",
        testRoot "\" retryAsset)
    AssertTrue(!LocalizationService.LoadPrivateUiFontAsset(retryAsset,
        testRoot), "失败缓存没有阻止重复磁盘探测")
    LocalizationService.RefreshInstalledUiFontNames()
    AssertTrue(LocalizationService.LoadPrivateUiFontAsset(retryAsset,
        testRoot), "字体刷新后没有重试补回的资源")
    WriteTestSuccess("ui-font-service")
} finally {
    LocalizationService.ShutdownUiFonts()
    AssertEqual(0, LocalizationService.GetLoadedPrivateUiFontResourceCount(),
        "退出清理后仍保留私有字体资源")
    if DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)
