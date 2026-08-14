HasCommandLineFlag(expectedFlag) {
    for argument in A_Args {
        if argument == expectedFlag
            return true
    }
    return false
}

GetReloadHandoffPid() {
    for argumentIndex, argument in A_Args {
        if StrLower(argument) != "--reload-handoff"
                || argumentIndex >= A_Args.Length
            continue
        try handoffPid := Integer(A_Args[argumentIndex + 1])
        catch
            return 0
        currentPid := DllCall("kernel32\GetCurrentProcessId", "UInt")
        return handoffPid > 0 && handoffPid != currentPid ? handoffPid : 0
    }
    return 0
}

QuoteRuntimeCommandArgument(value) {
    return Chr(34) StrReplace(String(value), Chr(34), Chr(92) Chr(34))
        . Chr(34)
}

BuildReloadValidationCommand(interpreterPath, scriptPath) {
    return QuoteRuntimeCommandArgument(interpreterPath) " /ErrorStdOut "
        . QuoteRuntimeCommandArgument(scriptPath) " --startup-validation"
}

BuildReloadHandoffCommand(currentPid, compiled, interpreterPath, scriptPath) {
    currentPid := Integer(currentPid)
    command := compiled
        ? QuoteRuntimeCommandArgument(scriptPath)
        : QuoteRuntimeCommandArgument(interpreterPath) " "
            . QuoteRuntimeCommandArgument(scriptPath)
    return command " --reload-handoff " currentPid " --show-main"
        . GetReloadForwardedArguments()
}

BuildApplicationElevationCommand(currentPid, compiled, interpreterPath,
        scriptPath, arguments := "") {
    currentPid := Integer(currentPid)
    command := compiled
        ? QuoteRuntimeCommandArgument(scriptPath)
        : QuoteRuntimeCommandArgument(interpreterPath) " "
            . QuoteRuntimeCommandArgument(scriptPath)
    return command . GetElevationForwardedArguments(arguments)
        . " --reload-handoff " currentPid
        . " --elevation-handoff --show-main"
}

GetElevationForwardedArguments(arguments := "") {
    if Type(arguments) != "Array"
        arguments := A_Args
    result := ""
    skipNext := false
    for argument in arguments {
        if skipNext {
            skipNext := false
            continue
        }
        switch StrLower(String(argument)) {
            case "--reload-handoff": skipNext := true
            case "--elevation-handoff", "--show-main": continue
            default: result .= " " QuoteRuntimeCommandArgument(argument)
        }
    }
    return result
}

GetReloadForwardedArguments() {
    arguments := ""
    for argument in A_Args {
        switch StrLower(argument) {
            case "--packaged":
                arguments .= " " QuoteRuntimeCommandArgument(argument)
        }
    }
    return arguments
}

CanonicalizeRuntimePath(filePath) {
    try {
        Loop Files String(filePath), "FD"
            return A_LoopFileFullPath
    }
    return String(filePath)
}

ValidateApplicationUpdateReadyPath(candidatePath, tempRoot := "") {
    if candidatePath == ""
        return ""
    if tempRoot == ""
        tempRoot := A_Temp
    candidatePath := CanonicalizeRuntimePath(candidatePath)
    tempRoot := RTrim(CanonicalizeRuntimePath(tempRoot), "\/")
    if candidatePath == "" || tempRoot == ""
        return ""
    SplitPath(candidatePath, &fileName, &parentDirectory)
    SplitPath(parentDirectory, &parentName)
    if fileName != "application-ready.signal"
            || !RegExMatch(parentName,
                "^keymouseremapperupdateapply-[^-]+-.+$")
            || SubStr(CanonicalizeRuntimePath(parentDirectory), 1,
                StrLen(tempRoot) + 1) != tempRoot "\"
        return ""
    return candidatePath
}

GetApplicationUpdateReadyPath() {
    for argumentIndex, argument in A_Args {
        if StrLower(argument) != "--update-ready"
                || argumentIndex >= A_Args.Length
            continue
        return ValidateApplicationUpdateReadyPath(A_Args[argumentIndex + 1])
    }
    return ""
}

WriteApplicationUpdateReadySignal(readyPath, version) {
    readyPath := ValidateApplicationUpdateReadyPath(readyPath)
    if readyPath == ""
        return false
    temporaryPath := readyPath ".tmp."
        . DllCall("kernel32\GetCurrentProcessId", "UInt")
    try {
        try FileDelete(temporaryPath)
        FileAppend("READY|" version, temporaryPath, "UTF-8")
        FileMove(temporaryPath, readyPath, true)
        return true
    } catch {
        try FileDelete(temporaryPath)
        return false
    }
}

AcquireApplicationMutex(&alreadyExists := false, mutexName := "") {
    if mutexName == ""
        mutexName := "Global\KeyMouseRemapperAssistant.Application"
    ; The handle is used only to keep the named object alive and detect an
    ; existing instance. Requesting MUTEX_ALL_ACCESS makes a normal launch
    ; fail when an elevated instance created the object.
    mutexHandle := DllCall("kernel32\CreateMutexExW", "Ptr", 0,
        "WStr", mutexName, "UInt", 0, "UInt", 0x00100000, "Ptr")
    lastError := DllCall("kernel32\GetLastError", "UInt")
    alreadyExists := mutexHandle && lastError == 183
    return mutexHandle
}

ReadApplicationSourceRevision(scriptPath := "") {
    if scriptPath == ""
        scriptPath := A_ScriptFullPath
    scriptPath := CanonicalizeRuntimePath(scriptPath)
    SplitPath(scriptPath, , &sourceRoot)
    sourcePaths := scriptPath
    for sourceDirectoryName in ["app", "src"] {
        sourceDirectory := sourceRoot "\" sourceDirectoryName
        if !DirExist(sourceDirectory)
            continue
        Loop Files sourceDirectory "\*.ahk", "FR"
            sourcePaths .= "`n" A_LoopFileFullPath
    }
    sourcePaths := Sort(sourcePaths, "D`n")
    latestModified := 0
    fingerprint := 2166136261
    for sourcePath in StrSplit(sourcePaths, "`n") {
        if sourcePath == ""
            continue
        try latestModified := Max(latestModified,
            Integer(FileGetTime(sourcePath, "M")))
        fingerprint := HashApplicationSourceFile(fingerprint, sourcePath,
            sourceRoot)
    }
    return {Modified: latestModified, Size: fingerprint ? fingerprint : 1}
}

HashApplicationSourceFile(fingerprint, sourcePath, sourceRoot := "") {
    relativePath := sourcePath
    if sourceRoot != "" && SubStr(sourcePath, 1, StrLen(sourceRoot) + 1)
            == sourceRoot "\"
        relativePath := SubStr(sourcePath, StrLen(sourceRoot) + 2)
    relativePath := StrLower(StrReplace(relativePath, "/", "\"))
    Loop Parse relativePath
        fingerprint := HashApplicationSourceByte(fingerprint, Ord(A_LoopField))
    fingerprint := HashApplicationSourceByte(fingerprint, 0)
    sourceFile := ""
    try {
        sourceFile := FileOpen(sourcePath, "r")
        if !IsObject(sourceFile)
            throw Error("无法读取应用源码文件。")
        sourceBuffer := Buffer(65536)
        while bytesRead := sourceFile.RawRead(sourceBuffer,
                sourceBuffer.Size) {
            Loop bytesRead
                fingerprint := HashApplicationSourceByte(fingerprint,
                    NumGet(sourceBuffer, A_Index - 1, "UChar"))
        }
    } catch {
        ; 文件正被编辑器短暂替换时仍提供稳定的元数据退化指纹。
        try fallback := FileGetTime(sourcePath, "M") "|"
            . FileGetSize(sourcePath)
        catch
            fallback := sourcePath
        Loop Parse fallback
            fingerprint := HashApplicationSourceByte(fingerprint,
                Ord(A_LoopField))
    } finally {
        if IsObject(sourceFile)
            try sourceFile.Close()
    }
    return HashApplicationSourceByte(fingerprint, 255)
}

HashApplicationSourceByte(fingerprint, byteValue) {
    return ((Integer(fingerprint) ^ (Integer(byteValue) & 0xFF))
        * 16777619) & 0xFFFFFFFF
}

ApplicationSourceRevisionMatches(left, right) {
    return IsObject(left) && IsObject(right)
        && left.HasOwnProp("Modified") && right.HasOwnProp("Modified")
        && left.HasOwnProp("Size") && right.HasOwnProp("Size")
        && Integer(left.Modified) == Integer(right.Modified)
        && Integer(left.Size) == Integer(right.Size)
}

BuildForcedApplicationTakeoverRevision(revision) {
    if !ApplicationSourceRevisionIsValid(revision)
        return revision
    fingerprint := Integer(revision.Size)
    forcedFingerprint := fingerprint >= 0xFFFFFFFF
        ? fingerprint - 1 : fingerprint + 1
    if forcedFingerprint <= 0 || forcedFingerprint == fingerprint
        forcedFingerprint := fingerprint == 1 ? 2 : 1
    return {
        Modified: Integer(revision.Modified),
        Size: forcedFingerprint
    }
}

ApplicationSourceRevisionIsValid(revision) {
    try return IsObject(revision)
        && revision.HasOwnProp("Modified")
        && revision.HasOwnProp("Size")
        && Integer(revision.Modified) > 0
        && Integer(revision.Size) > 0
    catch
        return false
}

ApplicationSourceReloadRequired(startupRevision, diskRevision,
        requestRevision) {
    if !ApplicationSourceRevisionIsValid(startupRevision)
        return false
    return (ApplicationSourceRevisionIsValid(diskRevision)
            && !ApplicationSourceRevisionMatches(startupRevision,
                diskRevision))
        || (ApplicationSourceRevisionIsValid(requestRevision)
            && !ApplicationSourceRevisionMatches(startupRevision,
                requestRevision))
}

GetApplicationShowMessage() {
    static message := DllCall("user32\RegisterWindowMessageW", "WStr",
        "KeyMouseRemapperAssistant.ShowMainWindow.v1", "UInt")
    return message
}

ReleaseApplicationMutexHandle(mutexHandle) {
    if mutexHandle
        try DllCall("kernel32\CloseHandle", "Ptr", mutexHandle, "Int")
}

RegisterApplicationMainWindow(hwnd) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    showMessage := GetApplicationShowMessage()
    if showMessage
        try DllCall("user32\ChangeWindowMessageFilterEx", "Ptr", hwnd,
            "UInt", showMessage, "UInt", 1, "Ptr", 0, "Int")
    return !!DllCall("user32\SetPropW", "Ptr", hwnd,
        "WStr", "KeyMouseRemapperAssistant.MainWindow", "Ptr", 1, "Int")
}

UnregisterApplicationMainWindow(hwnd) {
    if !hwnd || !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    return !!DllCall("user32\RemovePropW", "Ptr", hwnd,
        "WStr", "KeyMouseRemapperAssistant.MainWindow", "Ptr")
}

FindRunningApplicationWindow(timeoutMs := 3000) {
    timeoutMs := Max(0, Integer(timeoutMs))
    previousDetectHidden := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        started := A_TickCount
        Loop {
            for hwnd in WinGetList("ahk_class AutoHotkeyGUI") {
                if DllCall("user32\GetPropW", "Ptr", hwnd,
                        "WStr", "KeyMouseRemapperAssistant.MainWindow",
                        "Ptr")
                    return hwnd
            }
            if timeoutMs <= 0 || A_TickCount - started >= timeoutMs
                return 0
            Sleep(100)
        }
    } finally DetectHiddenWindows(previousDetectHidden)
}

FindLegacyApplicationScriptWindow(scriptPath := "", timeoutMs := 0) {
    if scriptPath == ""
        scriptPath := A_ScriptFullPath
    scriptPath := CanonicalizeRuntimePath(scriptPath)
    expectedPrefix := scriptPath " - AutoHotkey v"
    timeoutMs := Max(0, Integer(timeoutMs))
    previousDetectHidden := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        started := A_TickCount
        Loop {
            for hwnd in WinGetList("ahk_class AutoHotkey") {
                try title := WinGetTitle("ahk_id " hwnd)
                catch
                    continue
                if SubStr(title, 1, StrLen(expectedPrefix)) == expectedPrefix
                    return hwnd
            }
            if timeoutMs <= 0 || A_TickCount - started >= timeoutMs
                return 0
            Sleep(100)
        }
    } finally DetectHiddenWindows(previousDetectHidden)
}

GetWindowProcessId(hwnd) {
    processId := 0
    if hwnd
        DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd,
            "UInt*", &processId, "UInt")
    return processId
}

FindLegacyApplicationGui(processId) {
    if !processId
        return 0
    previousDetectHidden := A_DetectHiddenWindows
    DetectHiddenWindows(true)
    try {
        for hwnd in WinGetList("ahk_pid " processId
                . " ahk_class AutoHotkeyGUI") {
            try title := WinGetTitle("ahk_id " hwnd)
            catch
                continue
            if title == "键鼠重映射小助手"
                return hwnd
        }
    } finally DetectHiddenWindows(previousDetectHidden)
    return 0
}

CloseLegacyApplicationInstance(scriptWindow, timeoutMs := 15000) {
    if !scriptWindow || !DllCall("user32\IsWindow", "Ptr", scriptWindow,
            "Int")
        return false
    processId := GetWindowProcessId(scriptWindow)
    if !processId
        return false
    delivered := 0
    closeResponse := 0
    try delivered := DllCall("user32\SendMessageTimeoutW", "Ptr",
        scriptWindow, "UInt", 0x0010, "UPtr", 0, "Ptr", 0,
        "UInt", 0x0002, "UInt", 3000, "UPtr*", &closeResponse, "Ptr")
    if !delivered
        return false
    started := A_TickCount
    while ProcessExist(processId) {
        if A_TickCount - started >= Max(0, Integer(timeoutMs))
            return false
        Sleep(50)
    }
    return true
}

ShowExistingApplicationWindow(hwnd, sourceRevision := "") {
    if !hwnd
        return false
    if !DllCall("user32\IsWindow", "Ptr", hwnd, "Int")
        return false
    if !IsObject(sourceRevision)
        sourceRevision := ReadApplicationSourceRevision()
    targetPid := 0
    DllCall("user32\GetWindowThreadProcessId", "Ptr", hwnd,
        "UInt*", &targetPid, "UInt")
    if targetPid
        try DllCall("user32\AllowSetForegroundWindow", "UInt", targetPid,
            "Int")
    showMessage := GetApplicationShowMessage()
    showResult := 0
    if showMessage {
        try {
            delivered := DllCall("user32\SendMessageTimeoutW", "Ptr", hwnd,
                "UInt", showMessage, "UPtr", sourceRevision.Modified,
                "Ptr", sourceRevision.Size, "UInt", 0x0002, "UInt", 3000,
                "UPtr*", &showResult, "Ptr")
            if delivered
                return showResult
        }
    }
    ; A failed or unavailable protocol must never expose an unprepared HWND.
    ; The caller can retry after the current instance finishes initialization.
    return false
}

WaitForApplicationProcessExit(processId, timeoutMs := 15000) {
    processId := Integer(processId)
    if !processId
        return true
    started := A_TickCount
    loop {
        if !ProcessExist(processId)
            return true
        if A_TickCount - started >= Max(0, Integer(timeoutMs))
            return false
        Sleep(50)
    }
}

class DirectContextService {
    Build() {
        hwnd := WinExist("A")
        process := ""
        processPath := ""
        title := ""
        windowClass := ""
        if hwnd {
            try process := WinGetProcessName("ahk_id " hwnd)
            try processPath := WinGetProcessPath("ahk_id " hwnd)
            try title := WinGetTitle("ahk_id " hwnd)
            try windowClass := WinGetClass("ahk_id " hwnd)
        }
        foregroundThreadId := hwnd ? DllCall(
            "user32\GetWindowThreadProcessId", "Ptr", hwnd, "Ptr", 0,
            "UInt") : 0
        keyboardLayout := DllCall("user32\GetKeyboardLayout", "UInt",
            foregroundThreadId, "UPtr")
        languageId := keyboardLayout
            ? Format("{:04X}", keyboardLayout & 0xFFFF) : ""
        return Map(
            "application", Map("process", process, "path", processPath),
            "window", Map("title", title, "class", windowClass,
                "hwnd", hwnd),
            "input_source", Map("language_id", languageId),
            "session", Map("state", "active"))
    }
}
