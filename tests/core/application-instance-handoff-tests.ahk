#Requires AutoHotkey v2.0 64-bit
#SingleInstance Off
#Warn All, StdOut

#Include ..\..\src\Core\DirectRuntimeSupport.ahk

probe := ""
revisionFixtureRoot := ""
try {
    revision := ReadApplicationSourceRevision(A_ScriptFullPath)
    InstanceHandoffAssert(revision.Modified > 0 && revision.Size > 0,
        "The source revision could not be read.")
    InstanceHandoffAssert(ApplicationSourceRevisionMatches(revision,
            {Modified: revision.Modified, Size: revision.Size}),
        "Equal source revisions did not match.")
    InstanceHandoffAssert(!ApplicationSourceRevisionMatches(revision,
            {Modified: revision.Modified, Size: revision.Size + 1}),
        "Different source revisions matched.")
    forcedTakeoverRevision := BuildForcedApplicationTakeoverRevision(
        revision)
    InstanceHandoffAssert(ApplicationSourceRevisionIsValid(
            forcedTakeoverRevision)
            && !ApplicationSourceRevisionMatches(revision,
                forcedTakeoverRevision),
        "A direct source launch did not produce a distinct takeover revision.")
    InstanceHandoffAssert(!ApplicationSourceReloadRequired(revision,
            revision, revision),
        "Equal startup, disk and request revisions required a reload.")
    InstanceHandoffAssert(ApplicationSourceReloadRequired(revision,
            revision, {Modified: revision.Modified, Size: revision.Size + 1}),
        "A changed launcher revision did not require a reload.")
    InstanceHandoffAssert(ApplicationSourceReloadRequired(revision,
            {Modified: revision.Modified, Size: revision.Size + 1}, revision),
        "A changed disk revision did not require a reload.")

    mutexName := "Local\KMRA-instance-test-"
        . DllCall("kernel32\GetCurrentProcessId", "UInt") "-" A_TickCount
    firstMutex := AcquireApplicationMutex(&firstMutexExisted, mutexName)
    secondMutex := AcquireApplicationMutex(&secondMutexExisted, mutexName)
    InstanceHandoffAssert(firstMutex && !firstMutexExisted
            && secondMutex && secondMutexExisted,
        "The single-instance mutex was not created and reopened reliably.")
    ReleaseApplicationMutexHandle(secondMutex)
    secondMutex := 0
    ReleaseApplicationMutexHandle(firstMutex)
    firstMutex := 0

    revisionFixtureRoot := A_Temp "\kmr-source-revision-"
        . DllCall("kernel32\GetCurrentProcessId", "UInt")
    DirCreate(revisionFixtureRoot "\app")
    DirCreate(revisionFixtureRoot "\src")
    revisionEntryPath := revisionFixtureRoot "\entry.ahk"
    revisionIncludePath := revisionFixtureRoot "\app\Included.ahk"
    revisionSourcePath := revisionFixtureRoot "\src\Runtime.ahk"
    FileAppend("#Requires AutoHotkey v2.0`n", revisionEntryPath, "UTF-8")
    FileAppend("value := 1001`n", revisionIncludePath, "UTF-8")
    FileAppend("runtime := true`n", revisionSourcePath, "UTF-8")
    treeRevisionBefore := ReadApplicationSourceRevision(revisionEntryPath)
    FileDelete(revisionIncludePath)
    FileAppend("value := 2002`n", revisionIncludePath, "UTF-8")
    treeRevisionAfter := ReadApplicationSourceRevision(revisionEntryPath)
    InstanceHandoffAssert(!ApplicationSourceRevisionMatches(
            treeRevisionBefore, treeRevisionAfter),
        "An equal-length included source edit did not change the application revision.")

    probe := InstanceEndpointProbe()
    probe.Gui.Title := "键鼠重映射小助手"
    probe.Gui.Show("Hide w320 h200")
    InstanceHandoffAssert(!DllCall("user32\IsWindowVisible", "Ptr",
            probe.Gui.Hwnd, "Int"),
        "The handoff probe did not start hidden.")
    probe.Message := GetApplicationShowMessage()
    probe.Callback := ObjBindMethod(probe, "OnShowRequest")
    OnMessage(probe.Message, probe.Callback)
    InstanceHandoffAssert(RegisterApplicationMainWindow(probe.Gui.Hwnd),
        "The hidden application endpoint could not be registered.")
    legacyScriptWindow := FindLegacyApplicationScriptWindow(
        A_ScriptFullPath)
    legacyProcessId := GetWindowProcessId(legacyScriptWindow)
    InstanceHandoffAssert(legacyScriptWindow
            && legacyProcessId == DllCall(
                "kernel32\GetCurrentProcessId", "UInt")
            && FindLegacyApplicationGui(legacyProcessId) == probe.Gui.Hwnd,
        "The protocol-free legacy application endpoint was not identified by exact script path.")

    requestRevision := {Modified: 20260804010101, Size: 45678}
    response := ShowExistingApplicationWindow(probe.Gui.Hwnd,
        requestRevision)
    InstanceHandoffAssert(response == 1 && probe.RequestCount == 1
            && probe.Modified == requestRevision.Modified
            && probe.Size == requestRevision.Size
            && DllCall("user32\IsWindowVisible", "Ptr", probe.Gui.Hwnd,
                "Int"),
        "A hidden instance did not render through its in-process show request.")
    probe.Gui.Hide()
    probe.Response := 0
    probe.ShowOnRequest := false
    failedResponse := ShowExistingApplicationWindow(probe.Gui.Hwnd,
        requestRevision)
    InstanceHandoffAssert(!failedResponse && probe.RequestCount == 2
            && !DllCall("user32\IsWindowVisible", "Ptr",
                probe.Gui.Hwnd, "Int"),
        "A failed current-instance protocol request exposed the GUI directly.")
    probe.Response := 2
    takeoverResponse := ShowExistingApplicationWindow(probe.Gui.Hwnd,
        {Modified: requestRevision.Modified + 1,
            Size: requestRevision.Size + 1})
    InstanceHandoffAssert(takeoverResponse == 2
            && probe.RequestCount == 3
            && !DllCall("user32\IsWindowVisible", "Ptr",
                probe.Gui.Hwnd, "Int"),
        "A changed source launch did not request instance takeover.")
    InstanceHandoffAssert(!WaitForApplicationProcessExit(
            DllCall("kernel32\GetCurrentProcessId", "UInt"), 0)
            && WaitForApplicationProcessExit(0, 0),
        "Application exit waiting did not honor process state.")
    FileAppend("PASS application instance handoff`n", "*")
} catch as testError {
    FileAppend(testError.Message "`n" testError.Stack "`n", "**")
    ExitApp(1)
} finally {
    if IsObject(probe) {
        if probe.Message && IsObject(probe.Callback)
            try OnMessage(probe.Message, probe.Callback, 0)
        try UnregisterApplicationMainWindow(probe.Gui.Hwnd)
        try probe.Gui.Destroy()
    }
    if IsSet(secondMutex) && secondMutex
        try ReleaseApplicationMutexHandle(secondMutex)
    if IsSet(firstMutex) && firstMutex
        try ReleaseApplicationMutexHandle(firstMutex)
    if revisionFixtureRoot != "" && DirExist(revisionFixtureRoot)
        try DirDelete(revisionFixtureRoot, true)
}
ExitApp(0)

InstanceHandoffAssert(value, message) {
    if !value
        throw Error(message)
}

class InstanceEndpointProbe {
    __New() {
        this.Gui := Gui("+ToolWindow", "instance endpoint probe")
        this.Message := 0
        this.Callback := ""
        this.RequestCount := 0
        this.Modified := 0
        this.Size := 0
        this.Response := 1
        this.ShowOnRequest := true
    }

    OnShowRequest(modified, size, message, hwnd) {
        if hwnd != this.Gui.Hwnd
            return 0
        this.RequestCount++
        this.Modified := modified
        this.Size := size
        if this.ShowOnRequest
            this.Gui.Show("NoActivate")
        return this.Response
    }
}
