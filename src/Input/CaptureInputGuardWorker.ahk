#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#NoTrayIcon
#Warn All, StdOut

#Include CaptureInputGuard.ahk

if A_Args.Length == 1 && A_Args[1] == "--syntax-check"
    ExitApp()
if !CaptureInputGuardWorker.TryRun(A_Args)
    ExitApp(2)
ExitApp()
