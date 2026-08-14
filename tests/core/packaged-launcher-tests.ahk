#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Platform\PackagedLauncher.ahk

try {
    testRoot := A_Temp "\KeyMouseRemapperLauncherTest-"
        DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
    DirCreate(testRoot)
    testFile := testRoot "\abc.bin"
    FileAppend("abc", testFile, "UTF-8-RAW")
    LauncherAssertEqual(
        "BA7816BF8F01CFEA414140DE5DAE2223B00361A396177A9CB410FF61F20015AD",
        ComputeFileSha256(testFile), "Packaged runtime hashing is incorrect.")

    parameters := BuildPackagedSourceParameters(
        "C:\Program Files\Remapper\app.ahk", false,
        "C:\Temp Path\application-ready.signal")
    LauncherAssertTrue(InStr(parameters,
        '"C:\Program Files\Remapper\app.ahk" --packaged') == 1,
        "The packaged source path was not quoted.")
    LauncherAssertTrue(InStr(parameters,
        '--update-ready "C:\Temp Path\application-ready.signal"') > 0,
        "The update readiness path was not forwarded to packaged source.")
    LauncherAssertTrue(InStr(BuildPackagedSourceParameters(
        "C:\app.ahk", true), "--startup-validation") > 0,
        "Packaged startup validation was not forwarded.")

    FileAppend("PASS packaged launcher`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
} finally {
    if IsSet(testRoot) && DirExist(testRoot)
        DirDelete(testRoot, true)
}
ExitApp(0)

LauncherAssertTrue(value, message) {
    if !value
        throw Error(message)
}

LauncherAssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected '" expected "', got '" actual "'.")
}
