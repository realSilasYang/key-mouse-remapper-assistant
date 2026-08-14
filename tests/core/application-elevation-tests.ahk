#Requires AutoHotkey v2.0 64-bit
#Warn All, StdOut

#Include ..\..\src\Core\DirectRuntimeSupport.ahk

readyPath := A_Temp "\elevation ready.signal"
expected := QuoteRuntimeCommandArgument(A_AhkPath) " "
    . QuoteRuntimeCommandArgument(A_ScriptFullPath) " "
    . QuoteRuntimeCommandArgument("--packaged") " "
    . QuoteRuntimeCommandArgument("--update-ready") " "
    . QuoteRuntimeCommandArgument(readyPath)
    . " --reload-handoff 1234 --elevation-handoff --show-main"
actual := BuildApplicationElevationCommand(1234, false, A_AhkPath,
    A_ScriptFullPath, ["--packaged", "--reload-handoff", "77",
        "--elevation-handoff", "--show-main", "--update-ready", readyPath])
if actual != expected
    throw Error("Elevation handoff arguments are unsafe.`nExpected: "
        expected "`nActual: " actual)

FileAppend("PASS application elevation`n", "*")
