#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\RuleConditionEvaluator.ahk
#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\Core\DirectHotkeyRuntime.ahk

receiverPid := 0
integrationExitCode := 0
resultPath := A_Temp "\direct-hotkey-output-result-" A_TickCount "-"
    . Format("{:08X}", Random(0, 0xFFFFFFFF)) ".txt"
readyPath := resultPath ".ready"

try {
    expectedCount := 50
    receiverPath := A_ScriptDir
        . "\..\fixtures\direct-hotkey-output-receiver.ahk"
    receiverCommand := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut "
        . Chr(34) receiverPath Chr(34) " "
        . Chr(34) resultPath Chr(34) " "
        . Chr(34) readyPath Chr(34) " " expectedCount
    Run(receiverCommand, , "Hide", &receiverPid)
    WaitForFile(readyPath, 5000,
        "The complex-shortcut receiver did not become ready.")

    app := OutputIntegrationTestApp()
    runtime := DirectHotkeyRuntime(app)
    integrationSpec := RuleSpec.Normalize(Map(
        "id", "complex-output-stress",
        "display", Map("source", "F23",
            "target", "Ctrl + Shift + Alt + F24"),
        "from", Map("key", Map("name", "F23"), "repeat", "ignore"),
        "timing", Map("held_threshold_ms", 1),
        "to_if_held_down", [Map("type", "send",
            "value", "^+!{F24}")]))
    integrationDescriptor := RuleCompiler.Compile(integrationSpec)
    runtime.Rules[integrationDescriptor.Id] := integrationDescriptor

    Loop expectedCount {
        AssertTrue(runtime.OnDown(integrationDescriptor.Id),
            "A complex-output stress cycle rejected source down.")
        releaseCallback := ObjBindMethod(runtime, "OnUp",
            integrationDescriptor.Id)
        repeatCallback := (*) => runtime.HandleDown(
            integrationDescriptor.Id, true, true)
        SetTimer(releaseCallback, -5)
        SetTimer(repeatCallback, 1)
        try AssertTrue(runtime.OnHeld(integrationDescriptor.Id),
            "A complex-output stress cycle rejected its held action.")
        finally SetTimer(repeatCallback, 0)
        cycleDeadline := A_TickCount + 1000
        while runtime.Active.Has(integrationDescriptor.Id)
                && A_TickCount < cycleDeadline
            Sleep(1)
        if runtime.Active.Has(integrationDescriptor.Id)
            runtime.OnUp(integrationDescriptor.Id)
        AssertTrue(!runtime.Active.Has(integrationDescriptor.Id),
            "A complex-output stress cycle left active source state.")
    }

    if ProcessWaitClose(receiverPid, 30)
        throw Error("The complex-shortcut receiver did not exit.")
    receiverPid := 0
    integrationResultText := Trim(FileRead(resultPath, "UTF-8"))
    AssertEqual(String(expectedCount), integrationResultText,
        "Windows did not receive every complete complex shortcut.")
    AssertEqual(expectedCount, CountTraceEvent(app.Events, "rule_held"),
        "The runtime trace did not record every held action.")
    AssertEqual(expectedCount, CountTraceEvent(app.Events, "rule_released"),
        "The runtime trace did not record every source release.")
    FileAppend("PASS direct-hotkey-output-integration`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    integrationExitCode := 1
} finally {
    if receiverPid && ProcessExist(receiverPid)
        try ProcessClose(receiverPid)
    if FileExist(readyPath)
        try FileDelete(readyPath)
    if FileExist(resultPath)
        try FileDelete(resultPath)
}
ExitApp(integrationExitCode)

WaitForFile(path, timeoutMs, errorMessage) {
    deadline := A_TickCount + timeoutMs
    while !FileExist(path) && A_TickCount < deadline
        Sleep(10)
    if !FileExist(path)
        throw Error(errorMessage)
    return true
}

CountTraceEvent(events, eventName) {
    count := 0
    for event in events
        if event.Event == eventName
            count++
    return count
}

AssertTrue(value, message) {
    if !value
        throw Error(message)
}

AssertEqual(expected, actual, message) {
    if expected != actual
        throw Error(message " Expected=" expected " Actual=" actual)
}

class OutputIntegrationTestApp {
    __New() {
        this.ContextService := DirectContextService()
        this.Events := []
    }

    TraceEvent(category, eventName, fields := "") {
        this.Events.Push({Category: category, Event: eventName, Fields: fields})
        return true
    }
}
