#Requires AutoHotkey v2.0 64-bit
#SingleInstance Force
#NoTrayIcon
#Warn All, StdOut

#Include ..\..\src\Core\BoundedFileReader.ahk
#Include ..\..\src\Core\JsonCodec.ahk
#Include ..\..\src\Core\Sha256.ahk
#Include ..\..\src\Core\CrossProcessWriteLock.ahk
#Include ..\..\src\Core\RuleSpec.ahk
#Include ..\..\src\Core\ScriptRuleSpec.ahk
#Include ..\..\src\Core\RuleCompiler.ahk
#Include ..\..\src\Core\ScriptRuleCompiler.ahk
#Include ..\..\src\Core\DirectRuntimeSupport.ahk
#Include ..\..\src\UI\AhkV2Lexer.ahk
#Include ..\..\src\Core\AhkV2ScriptValidator.ahk
#Include ..\..\src\Core\ScriptRuleRuntime.ahk
#Include ..\..\src\Core\MappingCodeRepository.ahk

ExitApp(RunScriptRuleRuntimeTests() ? 0 : 1)

RunScriptRuleRuntimeTests() {
    testRoot := A_Temp "\kmra-script-rule-tests-"
        . DllCall("kernel32\GetCurrentProcessId", "UInt") "-"
        . A_TickCount
    try {
        DirCreate(testRoot)
        markerPath := testRoot "\worker-state.txt"
        escapedMarker := StrReplace(markerPath, Chr(34), Chr(34) Chr(34))
        appendMarkerCode := "AppendMarker(value, path) {`n"
            . "    Loop 8 {`n"
            . "        try {`n"
            . "            file := FileOpen(path, " Chr(34) "a"
                . Chr(34) ", " Chr(34) "UTF-8-RAW" Chr(34) ")`n"
            . "            if IsObject(file) {`n"
            . "                file.Write(value)`n"
            . "                file.Close()`n"
            . "                return true`n"
            . "            }`n"
            . "        }`n"
            . "        Sleep(10)`n"
            . "    }`n"
            . "    return false`n"
            . "}`n"
        code := "#Requires AutoHotkey v2.0`n"
            . "#SingleInstance Force`n"
            . "#NoTrayIcon`n"
            . appendMarkerCode
            . "OnExit((*) => AppendMarker(" Chr(34) "S" Chr(34) ", "
            . Chr(34) escapedMarker Chr(34) "))`n"
            . "AppendMarker(" Chr(34) "R" Chr(34) ", "
            . Chr(34) escapedMarker Chr(34) ")`n"
            . "SetTimer((*) => AppendMarker(A_IsSuspended ? "
            . Chr(34) "P" Chr(34) " : " Chr(34) "R" Chr(34) ", "
            . Chr(34) escapedMarker Chr(34) "), 50)`n"
            . "Persistent`n"
        spec := ScriptRuleSpec.Normalize(Map(
            "id", "独立脚本运行时测试",
            "display", Map("source", "测试脚本",
                "target", "生命周期验证", "scope", "全局"),
            "code", code))
        block := ScriptRuleCompiler.BuildBlock(spec)
        parsed := ScriptRuleCompiler.ParseSpec(block)
        ScriptRuleAssert(parsed["code"] == spec["code"],
            "Script block round-trip changed source code.")
        editedBlock := StrReplace(block, ";  Persistent",
            ";  Persistent " Chr(59) " 允许直接编辑", true, , 1)
        editedSpec := ScriptRuleCompiler.ParseSpec(editedBlock)
        ScriptRuleAssert(InStr(editedSpec["code"], "允许直接编辑"),
            "A directly edited script block was not parsed.")

        app := ScriptRuleTestApp(testRoot)
        runtime := ScriptRuleRuntime(app, testRoot "\runtime")
        signalRuntime := ScriptRuleRuntime(app, testRoot "\signal-runtime")
        confirmationPauseHandle := signalRuntime.CreateSignal(
            "Local\KMRA-capture-pause-" A_TickCount, false)
        confirmationAppliedHandle := signalRuntime.CreateSignal(
            "Local\KMRA-capture-pause-applied-" A_TickCount, false)
        signalRuntime.Workers := Map("unconfirmed", {
            Id: "unconfirmed", PauseHandle: confirmationPauseHandle,
            PauseAppliedHandle: confirmationAppliedHandle})
        originalCapturePauseTimeout := ScriptRuleRuntime
            .CapturePauseConfirmationMilliseconds
        try {
            ScriptRuleRuntime.CapturePauseConfirmationMilliseconds := 1
            ScriptRuleAssert(signalRuntime.SuspendForCapture()
                    && signalRuntime.Suspended
                    && DllCall("kernel32\WaitForSingleObject", "Ptr",
                        confirmationPauseHandle, "UInt", 0, "UInt") == 0,
                "An unconfirmed worker prevented capture suspension.")
            ScriptRuleAssert(app.Events.Length
                    && app.Events[app.Events.Length].Event
                        == "script_capture_pause_unconfirmed",
                "An unconfirmed capture suspension was not diagnosed.")
            DllCall("kernel32\SetEvent", "Ptr", confirmationAppliedHandle,
                "Int")
            ScriptRuleAssert(signalRuntime.ResumeForCapture()
                    && !signalRuntime.Suspended,
                "An unconfirmed capture suspension could not resume.")
            ScriptRuleAssert(app.Events.Length
                    && app.Events[app.Events.Length].Event
                        == "script_capture_resume_unconfirmed",
                "An unconfirmed capture resume was not diagnosed.")
        } finally {
            ScriptRuleRuntime.CapturePauseConfirmationMilliseconds :=
                originalCapturePauseTimeout
            signalRuntime.Workers := Map()
            DllCall("kernel32\CloseHandle", "Ptr", confirmationPauseHandle)
            DllCall("kernel32\CloseHandle", "Ptr",
                confirmationAppliedHandle)
        }
        firstPauseHandle := signalRuntime.CreateSignal(
            "Local\KMRA-suspend-rollback-" A_TickCount, false)
        invalidPauseHandle := signalRuntime.CreateSignal(
            "Local\KMRA-invalid-pause-" A_TickCount, false)
        DllCall("kernel32\CloseHandle", "Ptr", invalidPauseHandle)
        signalRuntime.Workers := Map(
            "first", {Id: "first", PauseHandle: firstPauseHandle},
            "invalid", {Id: "invalid", PauseHandle: invalidPauseHandle})
        ScriptRuleAssertThrows(() => signalRuntime.Suspend(),
            "A partial script suspend failure was hidden.")
        ScriptRuleAssert(!signalRuntime.Suspended
                && DllCall("kernel32\WaitForSingleObject", "Ptr",
                    firstPauseHandle, "UInt", 0, "UInt") == 0x00000102,
            "A partial script suspend was not rolled back.")
        ScriptRuleAssertThrows(() => signalRuntime.SuspendForCapture(),
            "A hard capture-suspend signal failure was hidden.")
        ScriptRuleAssert(!signalRuntime.Suspended
                && DllCall("kernel32\WaitForSingleObject", "Ptr",
                    firstPauseHandle, "UInt", 0, "UInt") == 0x00000102,
            "A partial capture suspend was not rolled back.")
        DllCall("kernel32\SetEvent", "Ptr", firstPauseHandle, "Int")
        signalRuntime.Suspended := true
        ScriptRuleAssertThrows(() => signalRuntime.Resume(),
            "A partial script resume failure was hidden.")
        ScriptRuleAssert(signalRuntime.Suspended
                && DllCall("kernel32\WaitForSingleObject", "Ptr",
                    firstPauseHandle, "UInt", 0, "UInt") == 0,
            "A partial script resume was not rolled back.")
        signalRuntime.Workers := Map()
        DllCall("kernel32\CloseHandle", "Ptr", firstPauseHandle)
        signalRuntime.Shutdown()
        mapping := {Id: spec["id"], Mode: "script", Spec: spec,
            Source: spec["display"]["source"],
            Target: spec["display"]["target"]}
        runtime.ValidateSpec(spec)
        invalidCompatibilityCases := [
            {Name: "func-bind",
                Code: "OnDown(*) {`n}`nFunc('OnDown').Bind('LWin')",
                Expected: "Func"},
            {Name: "has-key",
                Code: "states := {}`nif states.HasKey('LWin')`n    return",
                Expected: "HasKey"},
            {Name: "hotkey-down",
                Code: "OnDown(*) {`n}`nkey := 'LWin'`n"
                    . "Hotkey('*' . key . ' down', OnDown)",
                Expected: "Down 后缀"}
        ]
        for invalidCase in invalidCompatibilityCases {
            validationMessage := ""
            invalidSpec := ScriptRuleSpec.FromCode(
                "invalid-" invalidCase.Name, invalidCase.Code)
            try runtime.ValidateSpec(invalidSpec)
            catch as validationError
                validationMessage := validationError.Message
            ScriptRuleAssert(InStr(validationMessage,
                    invalidCase.Expected),
                "AHK v1 compatibility issue was not rejected: "
                    invalidCase.Name)
        }
        syntaxValidationMessage := ""
        invalidSyntaxSpec := ScriptRuleSpec.FromCode("invalid-syntax",
            "F24::Send(")
        try runtime.ValidateSpec(invalidSyntaxSpec)
        catch as syntaxValidationError
            syntaxValidationMessage := syntaxValidationError.Message
        ScriptRuleAssert(InStr(syntaxValidationMessage, "语法检查"),
            "Invalid AHK v2 syntax was not rejected before application.")
        validV2Spec := ScriptRuleSpec.FromCode("valid-v2-bindings",
            "states := Map()`nkey := 'LWin'`n"
            . "Hotkey('Down', OnDown.Bind('Down'))`n"
            . "Hotkey('*' . key, OnDown.Bind(key))`n"
            . "Hotkey('*' . key . ' Up', OnUp.Bind(key))`n"
            . "SetTimer(OnHeld.Bind(key), -2000)`n"
            . "if states.Has(key)`n    states.Delete(key)`n"
            . "OnDown(key, *) {`n}`nOnUp(key, *) {`n}`n"
            . "OnHeld(key) {`n}")
        runtime.ValidateSpec(validV2Spec)
        compatibilityTextSpec := ScriptRuleSpec.FromCode(
            "compatibility-text-only",
            "; Func('Old').Bind() and states.HasKey('x') are comments`n"
            . "legacyText := 'Func(Old).Bind() states.HasKey(x)'`n"
            . "message := 'Hotkey(`"*LWin down`", callback)'`n"
            . "F24::SendText(message)")
        runtime.ValidateSpec(compatibilityTextSpec)
        burstSpec := ScriptRuleSpec.FromCode("burst-wheel-script",
            "#Requires AutoHotkey v2.0`n"
            . "A_MaxHotkeysPerInterval := 100`n"
            . "A_HotkeyInterval := 500`n"
            . "+WheelUp::Send(" Chr(34) "{WheelLeft}" Chr(34) ")`n"
            . "+WheelDown::Send(" Chr(34) "{WheelRight}" Chr(34) ")")
        runtime.ValidateSpec(burstSpec)
        builtInRepository := MappingCodeRepository(A_ScriptDir
            . "\..\..\键鼠重映射小助手.ahk")
        builtInScriptCount := 0
        for builtInMapping in builtInRepository.Load() {
            if builtInMapping.Mode != "script"
                continue
            runtime.ValidateSpec(builtInMapping.Spec)
            builtInScriptCount++
        }
        suspendedSignalToken := "suspended-apply-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        suspendedObservedName := "Local\KMRA-" suspendedSignalToken
            . "-paused"
        resumedObservedName := "Local\KMRA-" suspendedSignalToken
            . "-resumed"
        suspendedObservedHandle := runtime.CreateSignal(
            suspendedObservedName, false)
        resumedObservedHandle := runtime.CreateSignal(resumedObservedName,
            false)
        suspendedApplyCode := "#Requires AutoHotkey v2.0`n"
            . "#NoTrayIcon`n"
            . "pausedEvent := DllCall('kernel32\OpenEventW', 'UInt', 2, "
            . "'Int', false, 'WStr', '" suspendedObservedName "', 'Ptr')`n"
            . "resumedEvent := DllCall('kernel32\OpenEventW', 'UInt', 2, "
            . "'Int', false, 'WStr', '" resumedObservedName "', 'Ptr')`n"
            . "SetTimer((*) => Suspend(false), -100)`n"
            . "SetTimer((*) => DllCall('kernel32\SetEvent', 'Ptr', "
            . "A_IsSuspended ? pausedEvent : resumedEvent), 50)`n"
            . "Persistent`n"
        suspendedApplySpec := ScriptRuleSpec.FromCode(
            "suspended-apply-script", suspendedApplyCode)
        suspendedApplyMapping := {Id: suspendedApplySpec["id"],
            Mode: "script", Spec: suspendedApplySpec,
            Source: "suspended apply", Target: "test"}
        suspendedApplyRuntime := ScriptRuleRuntime(app,
            testRoot "\suspended-apply-runtime")
        suspendedApplyRuntime.Suspend()
        suspendedApplyRuntime.ApplyMappings([suspendedApplyMapping])
        suspendedApplyWorker := suspendedApplyRuntime.Workers[
            suspendedApplySpec["id"]]
        ScriptRuleAssert(DllCall("kernel32\WaitForSingleObject", "Ptr",
                suspendedApplyWorker.PauseHandle, "UInt", 0, "UInt") == 0,
            "A worker added while suspended did not inherit the pause signal.")
        ScriptRuleAssert(DllCall("kernel32\WaitForSingleObject", "Ptr",
                suspendedObservedHandle, "UInt", 3000, "UInt") == 0,
            "A worker added while suspended did not report its state.")
        suspendedApplyRuntime.Resume()
        ScriptRuleAssert(DllCall("kernel32\WaitForSingleObject", "Ptr",
                resumedObservedHandle, "UInt", 3000, "UInt") == 0,
            "A worker added while suspended did not resume.")
        suspendedApplyRuntime.Shutdown()
        DllCall("kernel32\CloseHandle", "Ptr", suspendedObservedHandle)
        suspendedObservedHandle := 0
        DllCall("kernel32\CloseHandle", "Ptr", resumedObservedHandle)
        resumedObservedHandle := 0
        parentCommand := QuoteRuntimeCommandArgument(A_ComSpec)
            . " /D /C " Chr(34) "ping.exe -n 30 127.0.0.1 >nul"
            . Chr(34)
        Run(parentCommand, testRoot, "Hide", &probeParentPid)
        probeToken := "parent-exit-" A_TickCount "-"
            . Format("{:08X}", Random(0, 0xFFFFFFFF))
        probeStopName := "Local\KMRA-" probeToken "-stop"
        probePauseName := "Local\KMRA-" probeToken "-pause"
        probeReadyName := "Local\KMRA-" probeToken "-ready"
        probeWorker := {Id: "parent-exit-probe",
            Path: testRoot "\parent-exit-probe.ahk",
            StopHandle: runtime.CreateSignal(probeStopName, false),
            PauseHandle: runtime.CreateSignal(probePauseName, false),
            ReadyHandle: runtime.CreateSignal(probeReadyName, false),
            ProcessId: 0}
        probeSpec := ScriptRuleSpec.FromCode("parent-exit-probe",
            "#Requires AutoHotkey v2.0`nPersistent")
        try {
            probeSource := runtime.BuildWorkerSource(probeSpec, probeToken,
                probeStopName, probePauseName, probeReadyName,
                probeParentPid)
            runtime.WriteTextFile(probeWorker.Path, probeSource)
            Run(QuoteRuntimeCommandArgument(A_AhkPath) " "
                . QuoteRuntimeCommandArgument(probeWorker.Path), testRoot,
                "Hide", &probeWorkerPid)
            probeWorker.ProcessId := probeWorkerPid
            ScriptRuleAssert(DllCall("kernel32\WaitForSingleObject", "Ptr",
                    probeWorker.ReadyHandle, "UInt", 3000, "UInt") == 0,
                "Parent-exit probe worker did not become ready.")
            ProcessClose(probeParentPid)
            ProcessWaitClose(probeParentPid, 2)
            ProcessWaitClose(probeWorkerPid, 3)
            ScriptRuleAssert(!ProcessExist(probeWorkerPid),
                "Script worker survived after its parent process exited.")
        } finally {
            if ProcessExist(probeParentPid)
                try ProcessClose(probeParentPid)
            if probeWorker.StopHandle
                try DllCall("kernel32\SetEvent", "Ptr",
                    probeWorker.StopHandle, "Int")
            if probeWorker.ProcessId && ProcessExist(probeWorker.ProcessId)
                try ProcessClose(probeWorker.ProcessId)
            runtime.CloseWorkerHandles(probeWorker)
            if FileExist(probeWorker.Path)
                try FileDelete(probeWorker.Path)
        }
        report := runtime.ApplyMappings([mapping])
        ScriptRuleAssert(report.Workers == 1,
            "Script worker was not started.")
        activeWorker := runtime.Workers[spec["id"]]
        ScriptRuleAssert(!InStr(activeWorker.Path, spec["id"])
                && InStr(activeWorker.Path, "\worker-"),
            "The runtime worker path still exposed the Unicode rule name.")
        ScriptRuleAssert(activeWorker.JobHandle
                && runtime.GetWorkerProcessCount(activeWorker) >= 1,
            "The script worker did not join its managed job.")
        ScriptRuleWaitFor(() => FileExist(markerPath)
            && InStr(FileRead(markerPath), "R"), 3000,
            "Script worker did not execute user source.")
        runtime.Suspend()
        ScriptRuleWaitFor(() => InStr(FileRead(markerPath), "P"), 3000,
            "Script worker did not observe the pause signal.")
        runtime.Resume()
        previousLength := StrLen(ScriptRuleReadFileWhenAvailable(markerPath,
            3000))
        ScriptRuleWaitFor(() => ScriptRuleMarkerEndsWith(markerPath,
            previousLength, "R"), 3000,
            "Script worker did not observe the resume signal.")
        for sourcePath in A_Args {
            if !FileExist(sourcePath)
                throw Error("Script compatibility fixture does not exist: "
                    sourcePath)
            compatibilitySpec := ScriptRuleSpec.FromCode(
                "compatibility-" A_Index, FileRead(sourcePath, "UTF-8"))
            runtime.ValidateSpec(compatibilitySpec)
        }
        runtime.Shutdown()
        ScriptRuleWaitFor(() => InStr(FileRead(markerPath), "S"), 3000,
            "Script worker did not run its exit cleanup.")

        descendantRuntime := ScriptRuleRuntime(app,
            testRoot "\descendant-runtime")
        descendantMarker := testRoot "\descendant-state.txt"
        externalFixture := testRoot "\external-process.ahk"
        FileAppend("#Requires AutoHotkey v2.0`n#SingleInstance Off`n"
            . "#NoTrayIcon`nSleep(30000)`n", externalFixture, "UTF-8-RAW")
        escapedDescendantMarker := StrReplace(descendantMarker,
            Chr(34), Chr(34) Chr(34))
        escapedExternalFixture := StrReplace(externalFixture,
            Chr(34), Chr(34) Chr(34))
        descendantCode := "#Requires AutoHotkey v2.0`n"
            . "#SingleInstance Off`n#NoTrayIcon`n"
            . "isChild := false`n"
            . "for arg in A_Args {`n"
            . "    if arg == '--job-child'`n        isChild := true`n}`n"
            . "if !isChild {`n"
            . "    Run(QuoteForChild(A_AhkPath) Chr(32) "
            . "QuoteForChild(A_ScriptFullPath) ' --job-child')`n"
            . "    Run(QuoteForChild(A_AhkPath) Chr(32) QuoteForChild("
            . Chr(34) escapedExternalFixture Chr(34)
            . "), , 'Hide', &externalPid)`n"
            . "    FileAppend('E:' externalPid '|', "
            . Chr(34) escapedDescendantMarker Chr(34) ")`n}`n"
            . "FileAppend((isChild ? 'C:' : 'P:') "
            . "DllCall('kernel32\GetCurrentProcessId', 'UInt') '|', "
            . Chr(34) escapedDescendantMarker Chr(34) ")`n"
            . "Persistent`n"
            . "QuoteForChild(value) => Chr(34) StrReplace(value, Chr(34), "
            . "Chr(34) Chr(34)) Chr(34)"
        descendantSpec := ScriptRuleSpec.FromCode("descendant-script",
            descendantCode)
        descendantMapping := {Id: descendantSpec["id"], Mode: "script",
            Spec: descendantSpec, Source: "descendant", Target: "test"}
        descendantRuntime.ApplyMappings([descendantMapping])
        ScriptRuleWaitFor(() => FileExist(descendantMarker)
                && InStr(FileRead(descendantMarker), "P:")
                && InStr(FileRead(descendantMarker), "C:")
                && InStr(FileRead(descendantMarker), "E:"), 5000,
            "A child script instance did not execute.")
        descendantWorker := descendantRuntime.Workers[descendantSpec["id"]]
        ScriptRuleAssert(descendantRuntime.GetWorkerProcessCount(
                descendantWorker) >= 2,
            "A child script instance did not join the managed job.")
        descendantPids := []
        descendantText := FileRead(descendantMarker)
        position := 1
        while RegExMatch(descendantText, "[PC]:(\d+)", &pidMatch,
                position) {
            descendantPids.Push(Integer(pidMatch[1]))
            position := pidMatch.Pos(0) + pidMatch.Len(0)
        }
        RegExMatch(descendantText, "E:(\d+)", &externalPidMatch)
        externalPid := Integer(externalPidMatch[1])
        descendantRuntime.Shutdown()
        for descendantPid in descendantPids
            ScriptRuleAssert(!ProcessExist(descendantPid),
                "A child script instance survived managed shutdown.")
        ScriptRuleAssert(ProcessExist(externalPid),
            "Managed shutdown terminated a user-launched program.")
        ProcessClose(externalPid)
        ProcessWaitClose(externalPid, 2)

        blockingRuntime := ScriptRuleRuntime(app,
            testRoot "\blocking-runtime")
        blockingSpec := ScriptRuleSpec.FromCode("blocking-script",
            "#Requires AutoHotkey v2.0`nCritical " Chr(34) "On" Chr(34)
            . "`nSleep(10000)`nPersistent")
        blockingMapping := {Id: blockingSpec["id"], Mode: "script",
            Spec: blockingSpec, Source: "blocking", Target: "test"}
        originalStopTimeout := ScriptRuleRuntime.StopTimeoutMilliseconds
        try {
            ScriptRuleRuntime.StopTimeoutMilliseconds := 150
            blockingRuntime.ApplyMappings([blockingMapping])
            blockingPid := blockingRuntime.Workers[blockingSpec["id"]]
                .ProcessId
            blockingRuntime.Shutdown()
            ScriptRuleAssert(!ProcessExist(blockingPid),
                "An unresponsive script worker survived forced shutdown.")
        } finally {
            ScriptRuleRuntime.StopTimeoutMilliseconds := originalStopTimeout
            try blockingRuntime.Shutdown()
        }
        FileAppend("PASS script rule runtime`n", "*")
        return true
    } catch as testError {
        diagnostic := testError.Message "`n" testError.Stack "`n"
        diagnosticPath := A_Temp "\\kmra-script-runtime-tests-error-"
            . DllCall("kernel32\GetCurrentProcessId", "UInt") ".txt"
        try FileAppend(diagnostic, diagnosticPath, "UTF-8-RAW")
        try FileAppend(diagnostic, "**")
        return false
    } finally {
        if IsSet(runtime)
            try runtime.Shutdown()
        if IsSet(blockingRuntime)
            try blockingRuntime.Shutdown()
        if IsSet(descendantRuntime)
            try descendantRuntime.Shutdown()
        if IsSet(externalPid) && ProcessExist(externalPid)
            try ProcessClose(externalPid)
        if IsSet(signalRuntime)
            try signalRuntime.Shutdown()
        if IsSet(suspendedApplyRuntime)
            try suspendedApplyRuntime.Shutdown()
        if IsSet(suspendedObservedHandle) && suspendedObservedHandle
            try DllCall("kernel32\CloseHandle", "Ptr",
                suspendedObservedHandle)
        if IsSet(resumedObservedHandle) && resumedObservedHandle
            try DllCall("kernel32\CloseHandle", "Ptr",
                resumedObservedHandle)
        if DirExist(testRoot)
            try DirDelete(testRoot, true)
    }
}

ScriptRuleMarkerEndsWith(path, previousLength, suffix) {
    content := FileRead(path)
    return StrLen(content) > previousLength
        && SubStr(content, -StrLen(suffix)) == suffix
}

ScriptRuleReadFileWhenAvailable(path, timeoutMs) {
    content := ""
    ScriptRuleWaitFor(() => ScriptRuleTryReadFile(path, &content),
        timeoutMs, "The script state file remained locked.")
    return content
}

ScriptRuleTryReadFile(path, &content) {
    try {
        content := FileRead(path)
        return true
    } catch {
        return false
    }
}

ScriptRuleWaitFor(predicate, timeoutMs, message) {
    started := A_TickCount
    loop {
        try {
            if predicate.Call()
                return true
        }
        if A_TickCount - started >= timeoutMs
            throw Error(message)
        Sleep(25)
    }
}

ScriptRuleAssert(value, message) {
    if !value
        throw Error(message)
}

ScriptRuleAssertThrows(callback, message) {
    try callback.Call()
    catch
        return true
    throw Error(message)
}

class ScriptRuleTestApp {
    __New(dataDirectory) {
        this.DataDirectory := dataDirectory
        this.InterpreterPath := A_AhkPath
        this.Events := []
    }

    TraceEvent(category, eventName, fields) {
        this.Events.Push({Category: category, Event: eventName,
            Fields: fields})
    }
}
