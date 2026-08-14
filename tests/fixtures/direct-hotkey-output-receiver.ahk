#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

if A_Args.Length != 3
    ExitApp(2)

resultPath := A_Args[1]
readyPath := A_Args[2]
expectedCount := Integer(A_Args[3])
receivedCount := 0
completed := false
hotkeyId := 1
hotkeyMessage := 0x0312
hotkeyCallback := ReceiveComplexShortcut

; Register the chord with Windows itself so the integration test does not
; depend on AutoHotkey hook input-level filtering in a second process.
if !DllCall("user32\RegisterHotKey", "Ptr", 0, "Int", hotkeyId,
        "UInt", 0x0001 | 0x0002 | 0x0004 | 0x4000,
        "UInt", 0x87, "Int")
    ExitApp(4)
OnMessage(hotkeyMessage, hotkeyCallback)
OnExit(CleanupReceiver)
FileAppend("ready", readyPath, "UTF-8-RAW")
SetTimer(ReceiverTimedOut, -30000)
return

ReceiveComplexShortcut(*) {
    global receivedCount, expectedCount, completed, resultPath
    receivedCount++
    if receivedCount < expectedCount
        return
    completed := true
    FileAppend(String(receivedCount), resultPath, "UTF-8-RAW")
    ExitApp(0)
}

ReceiverTimedOut(*) {
    global receivedCount, completed, resultPath
    if !completed
        FileAppend("timeout:" receivedCount, resultPath, "UTF-8-RAW")
    ExitApp(3)
}

CleanupReceiver(*) {
    global hotkeyId, hotkeyMessage, hotkeyCallback
    try OnMessage(hotkeyMessage, hotkeyCallback, 0)
    try DllCall("user32\UnregisterHotKey", "Ptr", 0, "Int", hotkeyId,
        "Int")
}
