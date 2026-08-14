#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

if A_Args.Length != 3
    ExitApp(2)

resultPath := A_Args[1]
violationPath := A_Args[2]
readyPath := A_Args[3]

Hotkey("F24", ReceiveAllowedShortcut)
Hotkey("F21", ReceiveAllowedShortcut)
Hotkey("A", ReceiveBlockedOrdinaryKey)
Hotkey("PrintScreen", ReceiveBlockedPrintScreen)
Hotkey("F1", ReceiveBlockedF1)
Hotkey("F3", ReceiveBlockedF3)
Hotkey("F22 up", ReceiveBlockedTerminatingKeyUp)
Hotkey("#F23", ReceiveBlockedShortcut)
Hotkey("LWin", ReceiveBlockedWindowsKey)
Hotkey("!Tab", ReceiveBlockedSystemCombination)
Hotkey("Volume_Mute", ReceiveBlockedSystemKey)
Hotkey("Browser_Back", ReceiveBlockedBrowserKey)
Hotkey("MButton", ReceiveBlockedMouseButton)
Hotkey("WheelUp", ReceiveBlockedWheel)
Sleep(50)
FileAppend("ready", readyPath, "UTF-8-RAW")
SetTimer(ReceiverTimedOut, -10000)
return

ReceiveAllowedShortcut(*) {
    global resultPath
    FileAppend("plain-f21", resultPath, "UTF-8-RAW")
    ExitApp(0)
}

ReceiveBlockedShortcut(*) {
    global violationPath
    FileAppend("win-f23", violationPath, "UTF-8-RAW")
}

ReceiveBlockedWindowsKey(*) {
    global violationPath
    FileAppend("windows-key", violationPath, "UTF-8-RAW")
}

ReceiveBlockedSystemCombination(*) {
    global violationPath
    FileAppend("alt-tab", violationPath, "UTF-8-RAW")
}

ReceiveBlockedOrdinaryKey(*) {
    global violationPath
    FileAppend("ordinary-a", violationPath, "UTF-8-RAW")
}

ReceiveBlockedPrintScreen(*) {
    global violationPath
    FileAppend("print-screen", violationPath, "UTF-8-RAW")
}

ReceiveBlockedF1(*) {
    global violationPath
    FileAppend("f1", violationPath, "UTF-8-RAW")
}

ReceiveBlockedF3(*) {
    global violationPath
    FileAppend("f3", violationPath, "UTF-8-RAW")
}

ReceiveBlockedTerminatingKeyUp(*) {
    global violationPath
    FileAppend("terminating-f22-up", violationPath, "UTF-8-RAW")
}

ReceiveBlockedSystemKey(*) {
    global violationPath
    FileAppend("volume-mute", violationPath, "UTF-8-RAW")
}

ReceiveBlockedBrowserKey(*) {
    global violationPath
    FileAppend("browser-back", violationPath, "UTF-8-RAW")
}

ReceiveBlockedMouseButton(*) {
    global violationPath
    FileAppend("middle-button", violationPath, "UTF-8-RAW")
}

ReceiveBlockedWheel(*) {
    global violationPath
    FileAppend("wheel-up", violationPath, "UTF-8-RAW")
}

ReceiverTimedOut(*) => ExitApp(3)
