#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\UI\UiScaleService.ahk

try {
    UiScaleAssert(UiScaleService.NormalizePercent(125) == 125,
        "A supported interface scale was rejected.")
    UiScaleAssert(UiScaleService.NormalizePercent("150%") == 150,
        "A percentage-form interface scale was rejected.")
    for invalidValue in [0, 99, 120, 201, "invalid", ""]
        UiScaleAssert(UiScaleService.NormalizePercent(invalidValue) == 100,
            "An unsupported interface scale did not use the safe default.")

    UiScaleService.Configure(125)
    UiScaleAssert(UiScaleService.GetPercent() == 125
            && UiScaleService.Scale(80) == 100
            && UiScaleService.ToDesign(100) == 80,
        "Interface scale geometry conversion is inconsistent.")
    scaledOptions := UiScaleService.ScaleShowOptions(
        "Center x120 y80 w640 h480 NoActivate")
    UiScaleAssert(InStr(scaledOptions, "x120")
            && InStr(scaledOptions, "y80")
            && InStr(scaledOptions, "w800")
            && InStr(scaledOptions, "h600"),
        "Window sizing scaled screen coordinates or missed dimensions.")
    FileAppend("PASS interface scale service`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
} finally {
    UiScaleService.Configure(100)
}
ExitApp(0)

UiScaleAssert(condition, message) {
    if !condition
        throw Error(message)
}
