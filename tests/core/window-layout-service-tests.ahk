#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Config\WindowLayoutService.ahk

layoutDirectory := A_Temp "\key-mouse-remapper-layout-test-"
    . DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
layoutPath := layoutDirectory "\window-layout.ini"
try {
    service := WindowLayoutService(layoutPath, 1040, 650, 1040, 620)
    defaults := service.Load()
    WindowLayoutAssert(defaults.Width == 1040 && defaults.Height == 650,
        "Missing window layout did not use the configured defaults.")

    saved := service.Save({Width: 1480, Height: 820})
    reloaded := WindowLayoutService(layoutPath, 1040, 650, 1040, 620).Load()
    WindowLayoutAssert(saved.Width == 1480 && saved.Height == 820
            && reloaded.Width == 1480 && reloaded.Height == 820,
        "A custom main-window size did not round-trip.")

    invalid := service.Normalize({Width: 800, Height: "not-a-number"})
    WindowLayoutAssert(invalid.Width == 1040 && invalid.Height == 650,
        "Invalid dimensions were not isolated to their safe defaults.")

    layoutFile := FileOpen(layoutPath, "w", "UTF-8-RAW")
    layoutFile.Write("[MainWindow]`r`nWidth=1600`r`nHeight=999999`r`n")
    layoutFile.Close()
    partiallyValid := service.Load()
    WindowLayoutAssert(partiallyValid.Width == 1600
            && partiallyValid.Height == 650,
        "One corrupt layout field discarded a valid sibling field.")
    FileAppend("PASS window layout service`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
} finally {
    if FileExist(layoutPath)
        try FileDelete(layoutPath)
    if DirExist(layoutDirectory)
        try DirDelete(layoutDirectory)
}
ExitApp(0)

WindowLayoutAssert(value, message) {
    if !value
        throw Error(message)
}
