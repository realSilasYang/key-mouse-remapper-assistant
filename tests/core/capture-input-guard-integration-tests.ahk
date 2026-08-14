#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Input\CaptureInputGuard.ahk

receiverPid := 0
guard := ""
forwardedPackets := []
exitCode := 0
timingOutputPath := A_Args.Length ? String(A_Args[1]) : ""
token := A_TickCount "-" Format("{:08X}", Random(0, 0xFFFFFFFF))
resultPath := A_Temp "\capture-input-guard-result-" token ".txt"
violationPath := resultPath ".violation"
readyPath := resultPath ".ready"

try {
    receiverPath := A_ScriptDir
        . "\..\fixtures\capture-input-guard-receiver.ahk"
    receiverCommand := Chr(34) A_AhkPath Chr(34) " /ErrorStdOut "
        . Chr(34) receiverPath Chr(34) " "
        . Chr(34) resultPath Chr(34) " "
        . Chr(34) violationPath Chr(34) " "
        . Chr(34) readyPath Chr(34)
    Run(receiverCommand, , "Hide", &receiverPid)
    GuardIntegrationWaitForFile(readyPath, 5000,
        "The competing global-hotkey receiver did not become ready.")

    guard := CaptureInputGuardProcess(A_AhkPath,
        A_ScriptDir "\..\..\src\Input\CaptureInputGuardWorker.ahk",
        GuardIntegrationReceivePacket)
    startTick := A_TickCount
    GuardIntegrationAssert(guard.Start(),
        "The dedicated low-level capture guard process did not start.")
    startElapsed := A_TickCount - startTick
    GuardIntegrationSendKey(0x41) ; A
    GuardIntegrationSendKey(0x2C) ; PrintScreen
    GuardIntegrationSendKey(0x70) ; F1
    GuardIntegrationSendKey(0x72) ; F3
    GuardIntegrationSendKey(0x85) ; F22, including its terminating key-up
    GuardIntegrationSendKey(0x87) ; F24
    GuardIntegrationSendChord(0x5B, 0x86) ; LWin + F23
    GuardIntegrationSendKey(0x5B) ; LWin by itself
    GuardIntegrationSendChord(0x12, 0x09) ; Alt + Tab
    GuardIntegrationSendKey(0xAD) ; Volume_Mute
    GuardIntegrationSendKey(0xA6) ; Browser_Back
    GuardIntegrationSendMiddleButton()
    GuardIntegrationSendWheelUp()
    GuardIntegrationWaitForPackets(10, 5000)
    GuardIntegrationAssert(!FileExist(resultPath)
            && !FileExist(violationPath),
        "A competing global shortcut received input during capture.")
    GuardIntegrationAssert(GuardIntegrationHasKeyboardPacket(0x2C)
            && GuardIntegrationHasKeyboardPacket(0x70)
            && GuardIntegrationHasKeyboardPacket(0x72)
            && GuardIntegrationHasMousePacket(0x0207)
            && forwardedPackets.Length >= 20,
        "The guard swallowed input without forwarding it to the recorder.")

    stopTick := A_TickCount
    GuardIntegrationAssert(guard.Stop(),
        "The dedicated low-level capture guard process did not stop.")
    stopElapsed := A_TickCount - stopTick
    GuardIntegrationSendKey(0x84) ; F21 was never pressed during capture
    GuardIntegrationWaitForFile(resultPath, 5000,
        "The competing global shortcut did not recover after capture.")
    resultContent := GuardIntegrationReadFileWhenAvailable(resultPath, 5000)
    GuardIntegrationAssert(Trim(resultContent)
            == "plain-f21" && !FileExist(violationPath),
        "The competing global-hotkey receiver observed an invalid sequence.")
    if ProcessWaitClose(receiverPid, 5)
        throw Error("The competing global-hotkey receiver did not exit.")
    receiverPid := 0
    if timingOutputPath != ""
        FileAppend(startElapsed "|" stopElapsed, timingOutputPath,
            "UTF-8-RAW")
    FileAppend("PASS capture input guard integration (start=" startElapsed
        "ms, stop=" stopElapsed "ms)`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    exitCode := 1
} finally {
    if IsObject(guard)
        try guard.Stop()
    if receiverPid && ProcessExist(receiverPid)
        try ProcessClose(receiverPid)
    for path in [readyPath, violationPath, resultPath]
        if FileExist(path)
            try FileDelete(path)
}
ExitApp(exitCode)

GuardIntegrationSendKey(virtualKey) {
    DllCall("user32\keybd_event", "UChar", virtualKey, "UChar", 0,
        "UInt", 0, "UPtr", 0)
    DllCall("user32\keybd_event", "UChar", virtualKey, "UChar", 0,
        "UInt", 0x0002, "UPtr", 0)
}

GuardIntegrationSendChord(modifierVirtualKey, keyVirtualKey) {
    DllCall("user32\keybd_event", "UChar", modifierVirtualKey,
        "UChar", 0, "UInt", 0, "UPtr", 0)
    GuardIntegrationSendKey(keyVirtualKey)
    DllCall("user32\keybd_event", "UChar", modifierVirtualKey,
        "UChar", 0, "UInt", 0x0002, "UPtr", 0)
}

GuardIntegrationSendMiddleButton() {
    DllCall("user32\mouse_event", "UInt", 0x0020, "UInt", 0,
        "UInt", 0, "UInt", 0, "UPtr", 0)
    DllCall("user32\mouse_event", "UInt", 0x0040, "UInt", 0,
        "UInt", 0, "UInt", 0, "UPtr", 0)
}

GuardIntegrationSendWheelUp() {
    DllCall("user32\mouse_event", "UInt", 0x0800, "UInt", 0,
        "UInt", 0, "UInt", 120, "UPtr", 0)
}

GuardIntegrationWaitForFile(path, timeoutMs, errorMessage) {
    deadline := A_TickCount + timeoutMs
    while !FileExist(path) && A_TickCount < deadline
        Sleep(10)
    if !FileExist(path)
        throw Error(errorMessage)
    return true
}

GuardIntegrationReadFileWhenAvailable(path, timeoutMs) {
    deadline := A_TickCount + timeoutMs
    loop {
        try return FileRead(path, "UTF-8")
        catch {
            if A_TickCount >= deadline
                throw Error("The integration result file remained locked.")
            Sleep(10)
        }
    }
}

GuardIntegrationAssert(value, message) {
    if !value
        throw Error(message)
}

GuardIntegrationReceivePacket(packet) {
    global forwardedPackets
    forwardedPackets.Push(packet)
}

GuardIntegrationWaitForPackets(minimumCount, timeoutMs) {
    global forwardedPackets
    deadline := A_TickCount + timeoutMs
    while forwardedPackets.Length < minimumCount && A_TickCount < deadline
        Sleep(10)
    GuardIntegrationAssert(forwardedPackets.Length >= minimumCount,
        "The capture guard did not forward every intercepted input event.")
}

GuardIntegrationHasKeyboardPacket(virtualKey) {
    global forwardedPackets
    for packet in forwardedPackets
        if packet.Kind == "keyboard" && packet.VK == virtualKey
            return true
    return false
}

GuardIntegrationHasMousePacket(message) {
    global forwardedPackets
    for packet in forwardedPackets
        if packet.Kind == "mouse" && packet.Message == message
            return true
    return false
}
