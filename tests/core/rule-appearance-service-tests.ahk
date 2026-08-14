#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\UiThemeService.ahk
#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Config\RuleAppearanceService.ahk

appearanceDirectory := A_Temp "\key-mouse-remapper-appearance-test-"
    . DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
appearancePath := appearanceDirectory "\rule-appearance.json"
try {
    service := RuleAppearanceService(appearancePath)
    RuleAppearanceAssert(service.Load().Count == 0,
        "Missing appearance settings did not load as an empty map.")

    expectedDark := Map(
        "sage", "496B59", "mist", "41647D", "lavender", "62567D",
        "rose", "7A5060", "amber", "76633F", "teal", "3F6D70",
        "pearl", "5D5E58")
    expectedLight := Map(
        "sage", "D8EBDD", "mist", "D9E9F5", "lavender", "E5DDF3",
        "rose", "F1DDE2", "amber", "F2E5C8", "teal", "D5EBEA",
        "pearl", "E4E5E1")
    UiThemeService.Configure("dark")
    for key, color in expectedDark
        RuleAppearanceAssert(RuleColorPalette.Color(key) == color,
            "A dark sequence-dot preset changed: " key ".")
    UiThemeService.Configure("light")
    for key, color in expectedLight
        RuleAppearanceAssert(RuleColorPalette.Color(key) == color,
            "A light sequence-dot preset changed: " key ".")

    saved := service.Save(Map(
        "rule-a", "SAGE", "rule-b", "mist",
        "invalid-rule", "not-a-preset", "", "rose"))
    RuleAppearanceAssert(saved.Count == 2 && saved["rule-a"] == "sage"
            && saved["rule-b"] == "mist",
        "Appearance normalization retained invalid entries.")
    reloaded := RuleAppearanceService(appearancePath).Load()
    RuleAppearanceAssert(reloaded.Count == 2
            && reloaded["rule-a"] == "sage"
            && reloaded["rule-b"] == "mist",
        "Sequence-dot colors did not round-trip through JSON.")

    invalidFile := FileOpen(appearancePath, "w", "UTF-8-RAW")
    invalidFile.Write("{`"version`":1,`"colors`":[]}")
    invalidFile.Close()
    RuleAppearanceAssertThrows(() => service.Load(),
        "An invalid colors container was silently accepted.")
    FileAppend("PASS rule appearance service`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
} finally {
    if FileExist(appearancePath)
        try FileDelete(appearancePath)
    if DirExist(appearanceDirectory)
        try DirDelete(appearanceDirectory)
}
ExitApp(0)

RuleAppearanceAssert(value, message) {
    if !value
        throw Error(message)
}

RuleAppearanceAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}
